-- TouchOSC dB Meter Label Display
-- Version: 1.1.0
-- Shows actual peak dBFS level from track output meter
-- Handles Ableton's floating-point headroom (can show > 0 dBFS)
-- Multi-connection routing support

-- Version constant
local VERSION = "1.1.0"

-- State variables
local lastDB = -70.0
local lastUpdateTime = 0
local UPDATE_THRESHOLD = 0.1  -- Only update display if dB changes by more than this

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
    local context = "dBFS"
    if self.parent and self.parent.name then
        context = "dBFS(" .. self.parent.name .. ")"
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
  
  -- IMPORTANT: Ableton's floating-point engine can send values > 1.0
  -- when tracks are clipping internally
  if normalized > 1.0 then
    -- Linear extrapolation for values above 100%
    -- If 0.92 = 0dB and 1.0 = +6dB, then values > 1.0 continue linearly
    return 1.0 + (normalized - 1.0)
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
  elseif linear_pos >= 1 then 
    -- For positions > 1 (clipping), maintain linear relationship
    return linear_pos
  else 
    return math.pow(linear_pos, log_exponent) 
  end
end

-- Convert audio value to dB (extended for floating-point headroom)
function value2db(vl)
  if not vl then return -math.huge end
  
  -- Handle values above 1.0 (floating-point headroom)
  if vl > 1.0 then
    -- Linear continuation: if 1.0 = +6dB, extrapolate
    local db_above_unity = (vl - 1.0) * 60  -- Rough approximation
    return 6.0 + db_above_unity
  end
  
  -- Original conversion for values 0-1
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
-- dBFS DISPLAY FORMATTING
-- ===========================

-- Format dBFS value for display with proper unit
function formatDB(db_value)
    if db_value == -math.huge or db_value <= -70 then
        return "-∞ dBFS"
    elseif db_value >= 0 then
        -- Show + for positive values (floating-point headroom)
        return string.format("+%.1f dBFS", db_value)
    else
        return string.format("%.1f dBFS", db_value)
    end
end

-- Convert meter level to dB
function meterToDB(meter_normalized)
    -- Use exact same conversion as meter script
    local fader_position = abletonToFaderPosition(meter_normalized)
    local audio_value = linearToLog(fader_position)
    local db_value = value2db(audio_value)
    
    -- Debug logging
    debugLog(string.format("Meter: %.3f → Fader: %.3f → Audio: %.3f → dB: %.1f", 
        meter_normalized, fader_position, audio_value, db_value))
    
    return db_value
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
    
    -- Get meter level and calculate dB
    local meter_level = arguments[2].value
    local db_value = meterToDB(meter_level)
    
    -- Update display only if change is significant
    if not lastDB or math.abs(db_value - lastDB) > UPDATE_THRESHOLD then
        self.values.text = formatDB(db_value)
        
        -- Log significant changes (including when going above 0 dBFS)
        if not lastDB or math.abs(db_value - lastDB) > 1.0 or 
           (lastDB <= 0 and db_value > 0) or (lastDB > 0 and db_value <= 0) then
            log(string.format("Track %d: %s (meter: %.3f)%s", 
                myTrackNumber, formatDB(db_value), meter_level,
                db_value > 0 and " [CLIPPING]" or ""))
        end
        
        lastDB = db_value
    end
    
    lastUpdateTime = os.clock()
    
    return false  -- Don't block other receivers
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    -- If no meter update for a while, show -∞
    local currentTime = os.clock()
    if currentTime - lastUpdateTime > 2.0 then  -- No update for 2 seconds
        if self.values.text ~= "-∞ dBFS" then
            self.values.text = "-∞ dBFS"
            lastDB = -math.huge
            debugLog("No meter data - showing -∞")
        end
    end
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    -- Handle track changes
    if key == "track_changed" then
        -- Clear the display when track changes
        self.values.text = "-∞ dBFS"
        lastDB = -math.huge
        lastUpdateTime = os.clock()
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastDB = nil
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
        self.values.text = "-∞ dBFS"
    else
        self.values.text = "-"
    end
    
    -- Initialize state
    lastUpdateTime = os.clock()
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
        log("Peak dBFS meter with floating-point headroom")
        log("Range: -∞ to +60 dBFS (Ableton's 32-bit float)")
    end
    
    if DEBUG == 1 then
        log("DEBUG MODE ENABLED")
    end
end

init()
