-- TouchOSC LUFS Meter Display
-- Version: 1.1.0
-- Shows approximate LUFS based on track output meter level
-- Multi-connection routing support

-- Version constant
local VERSION = "1.1.0"

-- State variables
local lastLUFS = -60.0
local lufsBuffer = {}  -- Buffer for averaging
local bufferSize = 30  -- Number of samples to average (approximately 0.5 seconds at 60fps)

-- ===========================
-- CENTRALIZED LOGGING
-- ===========================

local function log(message)
    -- Get parent name for context
    local context = "LUFS_METER"
    if self.parent and self.parent.name then
        context = "LUFS_METER(" .. self.parent.name .. ")"
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
-- CALIBRATION (from meter script)
-- ===========================

-- Calibration points from meter script
local CALIBRATION_POINTS = {
    {0.0, 0.0},      -- Silent
    {0.3945, 0.027}, -- -40dB
    {0.6839, 0.169}, -- -18dB
    {0.7629, 0.313}, -- -12dB
    {0.8399, 0.5},   -- -6dB
    {0.9200, 0.729}, -- 0dB
    {1.0, 1.0}       -- Max
}

-- Convert AbletonOSC normalized value to fader position
function abletonToFaderPosition(normalized)
    if not normalized or normalized <= 0 then
        return 0
    end
    
    if normalized >= 1.0 then
        return 1.0
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
    
    return normalized
end

-- ===========================
-- dB CONVERSION (from fader script)
-- ===========================

local log_exponent = 0.515

function linearToLog(linear_pos)
    if not linear_pos or linear_pos <= 0 then return 0
    elseif linear_pos >= 1 then return 1
    else return math.pow(linear_pos, log_exponent) end
end

function value2db(vl)
    if not vl then return -math.huge end
    
    if vl <= 1 and vl >= 0.4 then
        return 40*vl - 34
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
        local db_value = beta*(vl^(1/gamma)) - alpha
        if db_value <= -70.0 then 
            return -math.huge
        else
            return db_value
        end
    else
        return 0
    end
end

-- ===========================
-- LUFS CALCULATION
-- ===========================

-- Convert meter level to approximate LUFS
-- Since we only have peak meter, this is an approximation
function meterToLUFS(meter_normalized)
    -- Convert to fader position and then to dB
    local fader_pos = abletonToFaderPosition(meter_normalized)
    local audio_value = linearToLog(fader_pos)
    local db_value = value2db(audio_value)
    
    -- LUFS approximation from peak meter
    -- Peak to LUFS offset typically ranges from 8-20 dB depending on content
    -- We'll use a dynamic offset based on level
    local lufs_offset
    
    if db_value == -math.huge or db_value < -60 then
        return -60.0  -- Minimum LUFS display
    elseif db_value >= -3 then
        -- Near clipping - assume heavily compressed/limited
        lufs_offset = 8  -- Smaller offset for loud, compressed material
    elseif db_value >= -12 then
        -- Loud material
        lufs_offset = 12
    elseif db_value >= -24 then
        -- Normal material
        lufs_offset = 15
    else
        -- Quiet material - likely more dynamic
        lufs_offset = 18
    end
    
    local lufs = db_value - lufs_offset
    
    -- Clamp to reasonable LUFS range
    if lufs < -60 then
        lufs = -60
    elseif lufs > 0 then
        lufs = 0
    end
    
    return lufs
end

-- Add value to buffer and return averaged LUFS
function averageLUFS(new_lufs)
    -- Add to buffer
    table.insert(lufsBuffer, new_lufs)
    
    -- Remove old values if buffer is too large
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

-- Format LUFS value for display
function formatLUFS(lufs_value)
    if lufs_value <= -60 then
        return "-60.0"
    else
        return string.format("%.1f", lufs_value)
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
    
    -- Get meter level and calculate LUFS
    local meter_level = arguments[2].value
    local instant_lufs = meterToLUFS(meter_level)
    local averaged_lufs = averageLUFS(instant_lufs)
    
    -- Update display
    self.values.text = formatLUFS(averaged_lufs)
    
    -- Only log significant changes to reduce spam
    if not lastLUFS or math.abs(averaged_lufs - lastLUFS) > 1.0 then
        log(string.format("Track %d: %s LUFS (meter: %.3f)", 
            myTrackNumber, formatLUFS(averaged_lufs), meter_level))
        lastLUFS = averaged_lufs
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
        self.values.text = "-60.0"
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
        self.values.text = "-60.0"
    else
        self.values.text = "-"
    end
    
    -- Initialize buffer
    lufsBuffer = {}
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
        log("LUFS calculated from output meter levels")
        log("Using " .. bufferSize .. " sample averaging")
    end
end

init()