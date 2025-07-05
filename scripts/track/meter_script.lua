-- TouchOSC Meter Script with Multi-Connection Support
-- Version: 2.5.1
-- Fixed: Cache connection index to avoid repeated lookups
-- Improved: Performance optimization for multi-connection support

local VERSION = "2.5.1"

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 to see meter values and conversions in console

-- COLOR THRESHOLDS (in dB) - PRESERVED FROM ORIGINAL
local COLOR_THRESHOLD_YELLOW = -12    -- Above this = yellow (caution)
local COLOR_THRESHOLD_RED = -3        -- Above this = red (clipping warning)

-- COLOR DEFINITIONS (RGBA values 0-1) - PRESERVED FROM ORIGINAL
local COLOR_GREEN = {0.0, 0.8, 0.0, 1.0}     -- Normal level
local COLOR_YELLOW = {1.0, 0.8, 0.0, 1.0}    -- Caution level  
local COLOR_RED = {1.0, 0.0, 0.0, 1.0}       -- Clipping level

-- Smooth color transitions - PRESERVED FROM ORIGINAL
local current_color = {COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]}
local color_smoothing = 0.3  -- Smoothing factor (0-1, higher = faster)

-- HARDCODED CALIBRATION BASED ON YOUR EXACT FADER DATA - PRESERVED
local CALIBRATION_POINTS = {
  -- AbletonOSC value -> Fader position (EXACT from your fader_volume logs)
  {0.0, 0.0},      -- Silent -> 0%
  {0.3945, 0.027}, -- -40dB -> 2.7% (EXACT from your fader_volume log!)
  {0.6839, 0.169}, -- -18dB -> 16.9% (EXACT from your fader_volume log!)
  {0.7629, 0.313}, -- -12dB -> 31.3% (EXACT from your fader_volume log!)
  {0.8399, 0.5},   -- -6dB -> 50% (verified working)
  {0.9200, 0.729}, -- 0dB -> 72.9% (verified working)  
  {1.0, 1.0}       -- Max -> 100%
}

-- CURVE SETTINGS - Must exactly match fader curve - PRESERVED
local use_log_curve = true
local log_exponent = 0.515

-- Animation settings (NEW from v2.4.1)
local animationActive = false
local animationStartTime = 0
local animationStartValue = 0
local targetValue = 0
local lastMeterValue = 0
local ANIMATION_DURATION = 0.3  -- 300ms for smooth animation
local FALL_SPEED_FACTOR = 1.5   -- Falls 1.5x faster than it rises

-- CACHED CONNECTION INDEX (Performance optimization)
local cachedConnectionIndex = nil

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        -- Get parent name for context
        local context = "METER"
        if self.parent and self.parent.name then
            context = "METER(" .. self.parent.name .. ")"
        end
        
        -- Print to console (simplified from v2.3.1)
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

function debugPrint(...)
  if DEBUG == 1 then
    local args = {...}
    local msg = table.concat(args, " ")
    log("[DEBUG] " .. msg)
  end
end

-- ===========================
-- MULTI-CONNECTION SUPPORT (OPTIMIZED)
-- ===========================

-- Get track number and type from parent group
local function getTrackInfo()
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if self.parent and self.parent.tag then
        local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            return tonumber(trackNum), trackType
        end
    end
    return nil, nil
end

-- Get connection index by reading configuration (CACHED)
local function getConnectionIndex()
    -- Return cached value if available
    if cachedConnectionIndex then
        return cachedConnectionIndex
    end
    
    -- Default to connection 1 if can't determine
    local defaultConnection = 1
    
    -- Check parent tag for instance name
    if not self.parent or not self.parent.tag then
        cachedConnectionIndex = defaultConnection
        return defaultConnection
    end
    
    -- Extract instance name from tag
    local instance = self.parent.tag:match("^(%w+):")
    if not instance then
        cachedConnectionIndex = defaultConnection
        return defaultConnection
    end
    
    -- Find and read configuration
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        debugPrint("No configuration found, using default connection")
        cachedConnectionIndex = defaultConnection
        return defaultConnection
    end
    
    -- Parse configuration to find connection for this instance
    local configText = configObj.values.text
    for line in configText:gmatch("[^\r\n]+") do
        -- Look for connection_instance: number pattern
        local configInstance, connectionNum = line:match("connection_(%w+):%s*(%d+)")
        if configInstance and configInstance == instance then
            local index = tonumber(connectionNum) or defaultConnection
            cachedConnectionIndex = index
            debugPrint("Cached connection for", instance, ":", index)
            return index
        end
    end
    
    debugPrint("No connection found for instance:", instance)
    cachedConnectionIndex = defaultConnection
    return defaultConnection
end

-- ===========================
-- ORIGINAL METER FUNCTIONS - PRESERVED
-- ===========================

-- Simple linear interpolation between calibration points
function abletonToFaderPosition(normalized)
  if not normalized or normalized <= 0 then
    return 0
  end
  
  if normalized >= 1.0 then
    return 1.0
  end
  
  -- Check for exact calibration matches first
  for _, point in ipairs(CALIBRATION_POINTS) do
    if math.abs(normalized - point[1]) < 0.01 then
      return point[2]
    end
  end
  
  -- Find the two closest points for interpolation
  for i = 1, #CALIBRATION_POINTS - 1 do
    local point1 = CALIBRATION_POINTS[i]
    local point2 = CALIBRATION_POINTS[i + 1]
    
    if normalized >= point1[1] and normalized <= point2[1] then
      -- Linear interpolation
      local ratio = (normalized - point1[1]) / (point2[1] - point1[1])
      local fader_position = point1[2] + ratio * (point2[2] - point1[2])
      return fader_position
    end
  end
  
  -- Fallback
  return normalized
end

-- Convert linear position to logarithmic (must match fader exactly)
function linearToLog(linear_pos)
  if not linear_pos or linear_pos <= 0 then return 0
  elseif linear_pos >= 1 then return 1
  else return math.pow(linear_pos, log_exponent) end
end

-- Convert audio value to dB (EXACT copy from fader script)
function value2db(vl)
  if not vl then return -math.huge end
  
  if vl <= 1 and vl >= 0.4 then
    return 40*vl -34
  elseif vl < 0.4 and vl >= 0.15 then
    local alpha = 799.503788
    local beta = 12630.61132
    local gamma = 201.871345
    local delta = 399.751894
    return -((delta*vl - gamma)^2 + beta)/alpha
  elseif vl < 0.15 then
    local alpha = 70.
    local beta = 118.426374
    local gamma = 7504./5567.
    local db_value_str = beta*(vl^(1/gamma)) - alpha
    if db_value_str <= -70.0 then 
      return -math.huge  -- -inf
    else
      return db_value_str
    end
  else
    return 0
  end
end

-- Get color based on exact dB calculation from fader position
function getColorForLevel(fader_pos)
  -- Convert fader position to exact dB using fader's math
  local audio_value = linearToLog(fader_pos)
  local actual_db = value2db(audio_value)
  
  if actual_db >= COLOR_THRESHOLD_RED then
    return COLOR_RED
  elseif actual_db >= COLOR_THRESHOLD_YELLOW then
    return COLOR_YELLOW
  else
    return COLOR_GREEN
  end
end

-- Smooth color transitions
function smoothColor(target_color)
  for i = 1, 4 do
    current_color[i] = current_color[i] + (target_color[i] - current_color[i]) * color_smoothing
  end
  return current_color
end

-- ===========================
-- ANIMATION HANDLING (NEW)
-- ===========================

function update()
  if animationActive then
    local currentTime = os.clock()
    local elapsed = currentTime - animationStartTime
    
    -- Determine animation duration based on direction
    local duration = ANIMATION_DURATION
    if targetValue < animationStartValue then
      -- Falling - use faster duration
      duration = ANIMATION_DURATION / FALL_SPEED_FACTOR
    end
    
    if elapsed >= duration then
      -- Animation complete
      self.values.x = targetValue
      lastMeterValue = targetValue
      animationActive = false
      
      -- Update color
      local target_color = getColorForLevel(targetValue)
      local smoothed = smoothColor(target_color)
      self.color = Color(smoothed[1], smoothed[2], smoothed[3], smoothed[4])
    else
      -- Calculate interpolated value
      local progress = elapsed / duration
      
      -- Use easing for smoother animation
      -- Ease out for rising, linear for falling
      if targetValue > animationStartValue then
        -- Rising - use ease out
        progress = 1 - math.pow(1 - progress, 2)
      end
      
      local currentValue = animationStartValue + (targetValue - animationStartValue) * progress
      self.values.x = currentValue
      
      -- Update color
      local target_color = getColorForLevel(currentValue)
      local smoothed = smoothColor(target_color)
      self.color = Color(smoothed[1], smoothed[2], smoothed[3], smoothed[4])
    end
  end
end

-- ===========================
-- OSC HANDLING WITH MULTI-CONNECTION (OPTIMIZED)
-- ===========================

function onReceiveOSC(message, connections)
  local path = message[1]
  
  -- Get track info from parent
  local trackNumber, trackType = getTrackInfo()
  if not trackNumber then
    return false
  end
  
  -- Check if this is a meter message for the correct track type
  local isMeterMessage = false
  if trackType == "return" and path == '/live/return/get/output_meter_level' then
    isMeterMessage = true
  elseif (trackType == "regular" or trackType == "track") and path == '/live/track/get/output_meter_level' then
    isMeterMessage = true
  end
  
  if not isMeterMessage then
    return false
  end
  
  -- Get our connection index (CACHED FOR PERFORMANCE)
  local myConnection = getConnectionIndex()
  
  -- Check if this message is from our connection
  if connections and not connections[myConnection] then
    return false
  end
  
  local arguments = message[2]
  if not arguments or #arguments < 2 then
    return false
  end
  
  -- Check if this message is for our track
  local msgTrackNumber = arguments[1].value
  
  if msgTrackNumber ~= trackNumber then
    return false
  end
  
  local normalized_meter = arguments[2].value
  
  -- Convert AbletonOSC normalized value to fader position
  local fader_position = abletonToFaderPosition(normalized_meter)
  
  -- Start animation to new value
  if fader_position ~= lastMeterValue then
    animationStartTime = os.clock()
    animationStartValue = lastMeterValue
    targetValue = fader_position
    animationActive = true
  end
  
  -- Debug logging (reduced frequency)
  if DEBUG == 1 and math.abs(fader_position - lastMeterValue) > 0.01 then
    debugPrint("=== METER UPDATE ===")
    debugPrint("Track Type:", trackType, "Track:", trackNumber, "Connection:", myConnection)
    debugPrint("AbletonOSC normalized:", string.format("%.4f", normalized_meter))
    debugPrint("→ Fader position:", string.format("%.1f%%", fader_position * 100))
    
    -- Calculate actual dB for display
    local audio_value = linearToLog(fader_position)
    local actual_db = value2db(audio_value)
    debugPrint("→ Actual dB:", string.format("%.1f", actual_db))
    debugPrint("→ Color:", actual_db >= COLOR_THRESHOLD_RED and "RED" or
                         actual_db >= COLOR_THRESHOLD_YELLOW and "YELLOW" or "GREEN")
  end
  
  return true  -- Stop propagation
end

-- Handle notifications from parent group
function onReceiveNotify(key, value)
    if key == "track_changed" then
        -- Reset meter when track changes
        self.values.x = 0
        lastMeterValue = 0
        animationActive = false
        current_color = {COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]}
        self.color = Color(current_color[1], current_color[2], current_color[3], current_color[4])
        -- Clear cached connection index as track may have changed instance
        cachedConnectionIndex = nil
        debugPrint("Track changed - reset meter and cleared cache")
    elseif key == "track_unmapped" then
        -- Disable meter when track is unmapped
        self.values.x = 0
        lastMeterValue = 0
        animationActive = false
        -- Clear cached connection index
        cachedConnectionIndex = nil
        debugPrint("Track unmapped - disabled meter and cleared cache")
    end
end

-- Initialize
function init()
  -- Log version
  log("Script v" .. VERSION .. " loaded")
  
  -- Set initial color to green
  self.color = Color(COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4])
  
  -- Initialize meter at minimum
  self.values.x = 0
  lastMeterValue = 0
  
  -- Cache connection index at startup
  getConnectionIndex()
  
  log("=== METER SCRIPT WITH OPTIMIZED MULTI-CONNECTION ===")
  log("Connection caching enabled for performance")
  log("Animation support active")
  
  -- Log parent info
  if self.parent then
    if self.parent.name then
      log("Attached to parent: " .. self.parent.name)
    end
    if self.parent.tag then
      log("Parent tag: " .. tostring(self.parent.tag))
    end
  end
end

init()