-- PAN CONTROL SCRIPT - CONNECTION-AWARE VERSION
-- Version: 1.0.0 (Phase 2 - Connection routing support)
local VERSION = "1.0.0"

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 to enable logging

-- Pan settings
local CENTER_DETENT = true           -- Snap to center when close
local CENTER_THRESHOLD = 0.05        -- How close to center before snapping
local VISUAL_INDICATOR = true        -- Show center line

-- State variables
local last_pan_value = 0
local synced = true
local touched = false

-- Connection-aware state
local track_mapped = false
local track_number = nil
local connection_index = nil
local last_disable_check = 0
local DISABLE_CHECK_INTERVAL = 500  -- Check every 500ms

function debugPrint(...)
  if DEBUG == 1 then
    print(...)
  end
end

-- Helper function to check if control should be enabled
function isControlEnabled()
  -- Check parent's track_number property
  track_number = self.parent.track_number
  
  -- If track_number is nil or -1, the track is not mapped
  if track_number == nil or track_number == -1 then
    return false
  end
  
  return true
end

-- Helper function to get connection index
function getConnectionIndex()
  -- Try to get from parent first
  if self.parent.connection_index then
    return self.parent.connection_index
  end
  
  -- Fallback: parse from group name
  local group_name = self.parent.name
  if string.find(group_name, "band_") == 1 then
    return 1
  elseif string.find(group_name, "master_") == 1 then
    return 2
  end
  
  -- Default to connection 1 if unable to determine
  return 1
end

-- Helper function to build connection table
function buildConnectionTable(conn_index)
  if conn_index == 1 then
    return {1}
  elseif conn_index == 2 then
    return {2}
  else
    return {conn_index}
  end
end

-- Convert UI position (0-1) to pan value (-1 to +1)
function uiToPan(ui_value)
  return (ui_value * 2) - 1
end

-- Convert pan value (-1 to +1) to UI position (0-1)
function panToUI(pan_value)
  return (pan_value + 1) / 2
end

-- Apply center detent if enabled
function applyCenterDetent(pan_value)
  if CENTER_DETENT and math.abs(pan_value) < CENTER_THRESHOLD then
    return 0
  end
  return pan_value
end

-- Format pan value for display
function formatPan(pan_value)
  if pan_value == 0 then
    return "C"
  elseif pan_value < 0 then
    return string.format("L%.0f", math.abs(pan_value) * 100)
  else
    return string.format("R%.0f", pan_value * 100)
  end
end

function onReceiveOSC(message, connections)
  -- Check if control is enabled before processing OSC
  if not isControlEnabled() then
    return
  end
  
  -- Check if message is from the correct connection
  local message_connection = connections and connections[1] or 1
  if message_connection ~= connection_index then
    debugPrint("Ignoring message from connection", message_connection, "- expecting", connection_index)
    return
  end
  
  local arguments = message[2]
  
  -- Get track number from parent
  local parent_track = self.parent.track_number
  if parent_track == nil or parent_track == -1 then
    return  -- Not mapped
  end
  
  -- Check if this message is for our track
  if arguments[1].value == parent_track then
    -- Check for pan updates
    if message[1] == '/live/track/get/panning' and arguments[2] then
      local pan_value = arguments[2].value
      last_pan_value = pan_value
      
      debugPrint("=== PAN UPDATE ===")
      debugPrint("Track:", parent_track, "Connection:", connection_index)
      debugPrint("Pan value:", pan_value, "(" .. formatPan(pan_value) .. ")")
      
      -- Update UI position if not touching
      if not self.values.touch then
        if synced then
          self.values.x = panToUI(pan_value)
          debugPrint("Updated UI position to:", string.format("%.3f", self.values.x))
        end
      else
        touched = true
        debugPrint("Ignoring update - control is being touched")
      end
    end
  end
end

function onValueChanged()
  -- Check if control is enabled
  if not isControlEnabled() then
    return  -- Don't process if track not mapped
  end
  
  -- Get current UI position
  local ui_position = self.values.x
  
  -- Convert to pan value
  local pan_value = uiToPan(ui_position)
  
  -- Apply center detent if touching
  if self.values.touch then
    pan_value = applyCenterDetent(pan_value)
    
    -- Update UI if snapped to center
    if CENTER_DETENT and pan_value == 0 and math.abs(uiToPan(ui_position)) < CENTER_THRESHOLD then
      self.values.x = 0.5  -- Center position
    end
  end
  
  debugPrint("=== PAN CHANGED ===")
  debugPrint("UI Position:", string.format("%.3f", ui_position))
  debugPrint("Pan value:", string.format("%.3f", pan_value), "(" .. formatPan(pan_value) .. ")")
  debugPrint("Touch:", self.values.touch and "YES" or "NO")
  debugPrint("Track:", self.parent.track_number, "Connection:", connection_index)
  
  -- Send OSC with connection routing
  local connections = buildConnectionTable(connection_index)
  sendOSC('/live/track/set/panning', {self.parent.track_number, pan_value}, connections)
end

function update()
  -- Periodically check if control should be enabled/disabled
  local current_time = getMillis()
  if current_time - last_disable_check > DISABLE_CHECK_INTERVAL then
    last_disable_check = current_time
    
    local should_be_enabled = isControlEnabled()
    if should_be_enabled ~= track_mapped then
      track_mapped = should_be_enabled
      
      if not track_mapped then
        -- Disable the control
        self.enabled = false
        self.color = Color(0.1, 0.1, 0.1, 0.5)  -- Dim gray
        debugPrint("*** PAN CONTROL DISABLED - Track not mapped ***")
      else
        -- Enable the control
        self.enabled = true
        self.color = Color(0.5, 0.5, 0.5, 1.0)  -- Normal gray
        connection_index = getConnectionIndex()
        debugPrint("*** PAN CONTROL ENABLED - Track mapped, Connection:", connection_index)
        
        -- Request current pan value
        local connections = buildConnectionTable(connection_index)
        sendOSC('/live/track/get/panning', {self.parent.track_number}, connections)
      end
    end
  end
  
  -- Handle sync after touch release
  if touched and not self.values.touch then
    touched = false
    synced = false
    
    -- Small delay before syncing to remote position
    if not synced then
      local sync_time = getMillis()
      if sync_time > 0 then  -- Simple delay
        self.values.x = panToUI(last_pan_value)
        synced = true
        debugPrint("*** Synced to remote pan position:", last_pan_value)
      end
    end
  end
  
  -- Reset sync if touching again
  if self.values.touch and not synced then
    synced = true
  end
end

-- Initialize
function init()
  print("=== PAN CONTROL SCRIPT v" .. VERSION .. " loaded ===")
  print("Connection-aware features: ENABLED")
  
  -- Initialize connection routing
  track_mapped = isControlEnabled()
  connection_index = getConnectionIndex()
  
  -- Set initial position to center
  self.values.x = 0.5
  
  if track_mapped then
    self.enabled = true
    self.color = Color(0.5, 0.5, 0.5, 1.0)  -- Normal gray
    print("Pan control ENABLED - Track:", self.parent.track_number, "Connection:", connection_index)
    
    -- Request initial pan value
    local connections = buildConnectionTable(connection_index)
    sendOSC('/live/track/get/panning', {self.parent.track_number}, connections)
  else
    self.enabled = false
    self.color = Color(0.1, 0.1, 0.1, 0.5)  -- Dim gray
    print("Pan control DISABLED - Track not mapped")
  end
  
  print("")
  print("Settings:")
  print("- Center detent:", CENTER_DETENT and "ENABLED" or "DISABLED")
  if CENTER_DETENT then
    print("- Center threshold:", CENTER_THRESHOLD * 100, "%")
  end
  print("- Visual indicator:", VISUAL_INDICATOR and "ENABLED" or "DISABLED")
  print("")
  print("Pan values:")
  print("- Left: -1 (L100)")
  print("- Center: 0 (C)")
  print("- Right: +1 (R100)")
end

init()