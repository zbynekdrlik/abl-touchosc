-- MUTE BUTTON SCRIPT - CONNECTION-AWARE VERSION
-- Version: 1.0.0 (Phase 2 - Connection routing support)
local VERSION = "1.0.0"

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 to enable logging

-- COLOR DEFINITIONS
local COLOR_UNMUTED = {0.2, 0.2, 0.2, 1.0}    -- Dark gray when unmuted
local COLOR_MUTED = {1.0, 0.2, 0.2, 1.0}      -- Red when muted
local COLOR_DISABLED = {0.1, 0.1, 0.1, 0.5}   -- Very dark gray when disabled

-- State variables
local mute_state = 0
local last_mute_state = -1

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

-- Update button appearance based on mute state
function updateButtonAppearance()
  if not track_mapped then
    self.color = Color(COLOR_DISABLED[1], COLOR_DISABLED[2], COLOR_DISABLED[3], COLOR_DISABLED[4])
    self.values.x = 0
  else
    if mute_state == 1 then
      self.color = Color(COLOR_MUTED[1], COLOR_MUTED[2], COLOR_MUTED[3], COLOR_MUTED[4])
      self.values.x = 1
    else
      self.color = Color(COLOR_UNMUTED[1], COLOR_UNMUTED[2], COLOR_UNMUTED[3], COLOR_UNMUTED[4])
      self.values.x = 0
    end
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
  
  -- Check if this is a track info message or mute state message
  if arguments[1].value == parent_track then
    -- This could be a mute state update
    if message[1] == '/live/track/get/mute' and arguments[2] then
      mute_state = arguments[2].value
      debugPrint("=== MUTE STATE UPDATE ===")
      debugPrint("Track:", parent_track, "Connection:", connection_index)
      debugPrint("Mute state:", mute_state == 1 and "MUTED" or "UNMUTED")
      
      if mute_state ~= last_mute_state then
        last_mute_state = mute_state
        updateButtonAppearance()
      end
    end
  end
end

function onValueChanged()
  -- Check if control is enabled
  if not isControlEnabled() then
    return  -- Don't process if track not mapped
  end
  
  -- Only respond to button press (not release)
  if self.values.x == 1 then
    -- Toggle mute state
    local new_mute_state = mute_state == 1 and 0 or 1
    
    debugPrint("=== MUTE BUTTON PRESSED ===")
    debugPrint("Track:", self.parent.track_number, "Connection:", connection_index)
    debugPrint("Current state:", mute_state == 1 and "MUTED" or "UNMUTED")
    debugPrint("New state:", new_mute_state == 1 and "MUTED" or "UNMUTED")
    
    -- Send OSC to toggle mute
    local connections = buildConnectionTable(connection_index)
    sendOSC('/live/track/set/mute', {self.parent.track_number, new_mute_state}, connections)
    
    -- Update local state immediately for responsive feedback
    mute_state = new_mute_state
    updateButtonAppearance()
    
    -- Request updated state to confirm
    sendOSC('/live/track/get/mute', {self.parent.track_number}, connections)
  end
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
        -- Disable the button
        self.enabled = false
        updateButtonAppearance()
        debugPrint("*** MUTE BUTTON DISABLED - Track not mapped ***")
      else
        -- Enable the button
        self.enabled = true
        connection_index = getConnectionIndex()
        updateButtonAppearance()
        debugPrint("*** MUTE BUTTON ENABLED - Track mapped, Connection:", connection_index)
        
        -- Request current mute state
        local connections = buildConnectionTable(connection_index)
        sendOSC('/live/track/get/mute', {self.parent.track_number}, connections)
      end
    end
  end
end

-- Initialize
function init()
  print("=== MUTE BUTTON SCRIPT v" .. VERSION .. " loaded ===")
  print("Connection-aware features: ENABLED")
  
  -- Initialize connection routing
  track_mapped = isControlEnabled()
  connection_index = getConnectionIndex()
  
  if track_mapped then
    self.enabled = true
    print("Mute button ENABLED - Track:", self.parent.track_number, "Connection:", connection_index)
    
    -- Request initial mute state
    local connections = buildConnectionTable(connection_index)
    sendOSC('/live/track/get/mute', {self.parent.track_number}, connections)
  else
    self.enabled = false
    print("Mute button DISABLED - Track not mapped")
  end
  
  -- Set initial appearance
  updateButtonAppearance()
  
  print("Colors:")
  print("- Unmuted: Dark gray")
  print("- Muted: Red")
  print("- Disabled: Very dark gray")
end

init()