-- TouchOSC LUFS Meter Display
-- Version: 1.5.0
-- Shows approximate loudness based on track output meter level
-- Multi-connection routing support

-- Version constant
local VERSION = "1.5.0"

-- State variables
local lastLUFS = -60.0
local lufsBuffer = {}  -- Buffer for averaging
local bufferSize = 5   -- Reduced for more responsive display

-- Debug mode
local DEBUG = 0  -- Set to 1 for detailed logging

-- ===========================
-- CALIBRATION FROM METER SCRIPT
-- ===========================

-- EXACT CALIBRATION POINTS FROM METER SCRIPT
local CALIBRATION_POINTS = {
  {0.0, 0.0},      -- Silent -> 0%
  {0.3945, 0.027}, -- -40dB -> 2.7%
  {0.6839, 0.169}, -- -18dB -> 16.9%
  {0.7629, 0.313}, -- -12dB -> 31.3%
  {0.8399, 0.5},   -- -6dB -> 50%
  {0.9200, 0.729}, -- 0dB -> 72.9%
  {1.0, 1.0}       -- Max -> 100%
}

-- CURVE SETTINGS FROM METER SCRIPT
local use_log_curve = true
local log_exponent = 0.515

-- ===========================
-- CENTRALIZED LOGGING
-- ===========================

local function log(message)
    -- Get parent name for context
    local context = "LOUDNESS"
    if self.parent and self.parent.name then
        context = "LOUDNESS(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

local function debugLog(message)
    if DEBUG == 1 then
        log("[DEBUG] " .. message)
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get track number from parent group
local function getTrackNumber()
    -- Parent stores combined tag like "band:5"
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
    end
    return nil
end

-- Check if track is properly mapped
local function isTrackMapped()
    if not self.parent or not self.parent.tag then
        return false
    end
    
    local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and trackNum ~= nil
end

-- Get connection index for this instance
local function getConnectionIndex()
    -- Default to connection 1 if can't determine
    local defaultConnection = 1
    
    -- Check parent tag for instance name
    if not self.parent or not self.parent.tag then
        return defaultConnection
    end
    
    -- Extract instance name from tag
    local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
    if not instance then
        return defaultConnection
    end
    
    -- Find and read configuration
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        return defaultConnection
    end
    
    -- Parse configuration to find connection for this instance
    local configText = configObj.values.text
    for line in configText:gmatch("[^\r\n]+") do
        -- Look for connection_instance: number pattern
        local configInstance, connectionNum = line:match("connection_(%w+):%s*(%d+)")
        if configInstance and configInstance == instance then
            return tonumber(connectionNum) or defaultConnection
        end
    end
    
    return defaultConnection
end

-- ===========================
-- EXACT CONVERSION FROM METER SCRIPT
-- ===========================

-- Convert AbletonOSC normalized value to fader position
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

-- ===========================
-- LOUDNESS CALCULATION
-- ===========================

-- Convert meter level to approximate loudness
function meterToLoudness(meter_normalized)
    -- Use exact same conversion as meter script
    local fader_position = abletonToFaderPosition(meter_normalized)
    local audio_value = linearToLog(fader_position)
    local db_value = value2db(audio_value)
    
    -- Calibrated offset based on testing:
    -- When meter shows 0.630 → -19.6 dB → true:level shows -22.2 LUFS
    -- Base offset is approximately 2.5 dB
    local loudness_offset
    
    -- Dynamic offset based on level
    if db_value >= -3 then
        loudness_offset = 0.1  -- Very loud, minimal offset
    elseif db_value >= -6 then
        loudness_offset = 0.5  -- Loud signal
    elseif db_value >= -12 then
        loudness_offset = 1.5  -- Moderately loud
    elseif db_value >= -20 then
        loudness_offset = 2.5  -- Normal levels (calibrated)
    elseif db_value >= -30 then
        loudness_offset = 4.0  -- Quieter material
    else
        loudness_offset = 6.0  -- Very quiet
    end
    
    local loudness = db_value - loudness_offset
    
    -- Debug logging
    debugLog(string.format("Meter: %.3f → dB: %.1f → offset: %.1f → Loudness: %.1f", 
        meter_normalized, db_value, loudness_offset, loudness))
    
    -- Clamp to reasonable loudness range
    if loudness < -60 then
        loudness = -60
    elseif loudness > 0 then
        loudness = 0
    end
    
    return loudness
end

-- Smart averaging that handles large jumps
function averageLoudness(new_loudness)
    -- Clear buffer on large jumps or if buffer has very old values
    if #lufsBuffer > 0 then
        local lastValue = lufsBuffer[#lufsBuffer]
        local avgValue = 0
        for _, v in ipairs(lufsBuffer) do
            avgValue = avgValue + v
        end
        avgValue = avgValue / #lufsBuffer
        
        -- Clear if new value is very different from average
        if math.abs(avgValue - new_loudness) > 15 then
            debugLog("Large jump detected, clearing buffer")
            lufsBuffer = {}
        end
    end
    
    -- Add to buffer
    table.insert(lufsBuffer, new_loudness)
    
    -- Keep only recent values
    while #lufsBuffer > bufferSize do
        table.remove(lufsBuffer, 1)
    end
    
    -- Calculate average
    local sum = 0
    for _, value in ipairs(lufsBuffer) do
        sum = sum + value
    end
    
    return sum / #lufsBuffer
end

-- Format loudness value for display
function formatLoudness(loudness_value)
    if loudness_value <= -60 then
        return "-60 LUFS"
    else
        -- Show as integer for cleaner display
        return string.format("%d LUFS", math.floor(loudness_value + 0.5))
    end
end

-- ===========================
-- OSC HANDLER
-- ===========================

function onReceiveOSC(message, connections)
    -- Check if this is a meter message
    if message[1] ~= '/live/track/get/output_meter_level' then
        return false
    end
    
    -- Get our connection index
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
    local myTrackNumber = getTrackNumber()
    
    if not myTrackNumber or msgTrackNumber ~= myTrackNumber then
        return false
    end
    
    -- Get meter level and calculate loudness
    local meter_level = arguments[2].value
    local instant_loudness = meterToLoudness(meter_level)
    local averaged_loudness = averageLoudness(instant_loudness)
    
    -- Update display
    self.values.text = formatLoudness(averaged_loudness)
    
    -- Only log significant changes to reduce spam
    if not lastLUFS or math.abs(averaged_loudness - lastLUFS) > 2.0 then
        log(string.format("Track %d: %s", 
            myTrackNumber, formatLoudness(averaged_loudness)))
        lastLUFS = averaged_loudness
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    -- Handle track changes
    if key == "track_changed" then
        -- Clear the display and buffer when track changes
        self.values.text = "-60 LUFS"
        lastLUFS = -60.0
        lufsBuffer = {}
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastLUFS = nil
        lufsBuffer = {}
        log("Track unmapped - display shows dash")
    elseif key == "control_enabled" then
        -- Show/hide based on track mapping status
        self.values.visible = value
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Set initial text
    if isTrackMapped() then
        self.values.text = "-60 LUFS"
    else
        self.values.text = "-"
    end
    
    -- Initialize buffer
    lufsBuffer = {}
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
        log("Loudness estimate from output meter")
        log("Note: This is an approximation, not true LUFS measurement")
    end
    
    if DEBUG == 1 then
        log("DEBUG MODE ENABLED")
    end
end

init()