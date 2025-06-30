-- TouchOSC LUFS Meter Display
-- Version: 1.5.1
-- Diagnostic version to check timing and calibration
-- Multi-connection routing support

-- Version constant
local VERSION = "1.5.1"

-- State variables
local lastLUFS = -60.0
local lastMeterValue = 0
local lastMeterTime = 0
local updateCount = 0
local lufsBuffer = {}  -- Buffer for averaging
local bufferSize = 1   -- NO AVERAGING for diagnostics

-- Debug mode
local DEBUG = 1  -- ALWAYS ON for diagnostics

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
    local context = "LUFS_DIAG"
    if self.parent and self.parent.name then
        context = "LUFS_DIAG(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
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
-- LUFS CALCULATION - FIXED CALIBRATION
-- ===========================

-- Convert meter level to approximate LUFS
function meterToLUFS(meter_normalized)
    -- Use exact same conversion as meter script
    local fader_position = abletonToFaderPosition(meter_normalized)
    local audio_value = linearToLog(fader_position)
    local db_value = value2db(audio_value)
    
    -- FIXED CALIBRATION:
    -- At 0dB fader (meter 0.630), we want -22.2 LUFS
    -- Your test shows meter 0.630 → -19.6 dB
    -- So offset should be: -19.6 - (-22.2) = 2.6 dB
    local lufs_offset = 2.6
    
    local lufs = db_value - lufs_offset
    
    -- Log everything for diagnostics
    log(string.format("CALC: Meter %.3f → Fader %.3f → Audio %.3f → dB %.1f → LUFS %.1f", 
        meter_normalized, fader_position, audio_value, db_value, lufs))
    
    -- Clamp to reasonable LUFS range
    if lufs < -60 then
        lufs = -60
    elseif lufs > 0 then
        lufs = 0
    end
    
    return lufs
end

-- NO AVERAGING for diagnostics
function averageLUFS(new_lufs)
    return new_lufs  -- Direct passthrough
end

-- Format LUFS value for display with unit
function formatLUFS(lufs_value)
    if lufs_value <= -60 then
        return "-60.0 LUFS"
    else
        return string.format("%.1f LUFS", lufs_value)
    end
end

-- ===========================
-- OSC HANDLER WITH TIMING
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
    
    -- Get meter level
    local meter_level = arguments[2].value
    
    -- Track timing
    local currentTime = os.clock() * 1000  -- Convert to milliseconds
    local timeSinceLastUpdate = currentTime - lastMeterTime
    lastMeterTime = currentTime
    updateCount = updateCount + 1
    
    -- Log update frequency
    if updateCount % 10 == 0 then  -- Every 10th update
        log(string.format("UPDATE FREQ: %d updates, last gap: %.0f ms", 
            updateCount, timeSinceLastUpdate))
    end
    
    -- Check if meter value changed
    if math.abs(meter_level - lastMeterValue) > 0.001 then
        log(string.format("METER CHANGE: %.3f → %.3f (Δ%.3f)", 
            lastMeterValue, meter_level, meter_level - lastMeterValue))
        
        -- Also check fader position
        local fader = self.parent and self.parent.children and self.parent.children.fader
        if fader and fader.values then
            log(string.format("FADER POS: %.1f%% (%.3f)", 
                fader.values.x * 100, fader.values.x))
        end
    end
    lastMeterValue = meter_level
    
    -- Calculate LUFS
    local instant_lufs = meterToLUFS(meter_level)
    local averaged_lufs = averageLUFS(instant_lufs)
    
    -- Update display
    self.values.text = formatLUFS(averaged_lufs)
    
    -- Log final value
    log(string.format("DISPLAY: %s", formatLUFS(averaged_lufs)))
    
    return false  -- Don't block other receivers
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    -- This runs at 60fps - we can use it to check update frequency
    -- But don't log here as it would spam the console
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    -- Handle track changes
    if key == "track_changed" then
        -- Clear the display and buffer when track changes
        self.values.text = "-60.0 LUFS"
        lastLUFS = -60.0
        lufsBuffer = {}
        lastMeterValue = 0
        updateCount = 0
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastLUFS = nil
        lufsBuffer = {}
        lastMeterValue = 0
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
    log("Script v" .. VERSION .. " loaded - TIMING DIAGNOSTICS")
    
    -- Set initial text
    if isTrackMapped() then
        self.values.text = "-60.0 LUFS"
    else
        self.values.text = "-"
    end
    
    -- Initialize state
    lufsBuffer = {}
    lastMeterValue = 0
    lastMeterTime = os.clock() * 1000
    updateCount = 0
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
        log("FIXED OFFSET: 2.6 dB (calibrated for -22.2 LUFS at 0dB)")
        log("NO AVERAGING - Direct display")
        log("Monitoring update frequency...")
    end
end

init()