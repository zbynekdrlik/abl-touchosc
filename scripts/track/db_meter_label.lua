-- TouchOSC dB Meter Label Display
-- Version: 2.2.1
-- Shows actual peak dBFS level from track output meter
-- Enhanced logging for low values to debug calibration
-- Multi-connection routing support

-- Version constant
local VERSION = "2.2.1"

-- State variables
local lastDB = -70.0
local lastMeterValue = 0

-- Debug mode
local DEBUG = 0  -- Set to 1 for detailed logging

-- ===========================
-- METER CALIBRATION TABLE
-- ===========================
-- Extended calibration table with more points for low values
local METER_DB_CALIBRATION = {
    {0.000, -math.huge},  -- Silence
    {0.001, -80.0},       -- Very quiet
    {0.010, -60.0},       -- 
    {0.050, -46.0},       -- 
    {0.100, -40.0},       -- 
    {0.200, -34.0},       -- 
    {0.300, -30.0},       -- 
    {0.400, -26.5},       -- 
    {0.500, -24.0},       -- 
    {0.631, -22.0},       -- VERIFIED by user
    {0.700, -18.0},       -- 
    {0.750, -14.0},       -- 
    {0.800, -10.0},       -- 
    {0.842, -6.0},        -- VERIFIED by user
    {0.900, -3.0},        -- 
    {0.950, -1.5},        -- 
    {1.000, 0.0},         -- Unity
}

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
-- METER TO DB CONVERSION
-- ===========================

-- Convert meter level to dB using calibration table
function meterToDB(meter_normalized)
    -- Handle nil or negative values
    if not meter_normalized or meter_normalized <= 0 then
        return -math.huge
    end
    
    -- Handle values above 1.0 (Ableton's floating-point headroom)
    if meter_normalized > 1.0 then
        -- Linear extrapolation above 0 dB
        -- Approximately 20 dB per doubling
        local db_above_zero = 20 * math.log10(meter_normalized)
        return db_above_zero
    end
    
    -- Find calibration points for interpolation
    for i = 1, #METER_DB_CALIBRATION - 1 do
        local point1 = METER_DB_CALIBRATION[i]
        local point2 = METER_DB_CALIBRATION[i + 1]
        
        if meter_normalized >= point1[1] and meter_normalized <= point2[1] then
            -- Linear interpolation between calibration points
            local meter_range = point2[1] - point1[1]
            local db_range = point2[2] - point1[2]
            
            -- Handle -inf in interpolation
            if point1[2] == -math.huge then
                -- Special case: interpolating from -inf
                -- Use logarithmic scaling near zero
                return 20 * math.log10(meter_normalized)
            elseif point2[2] == -math.huge then
                -- This shouldn't happen but handle it
                return -math.huge
            else
                -- Normal linear interpolation
                local meter_offset = meter_normalized - point1[1]
                local interpolation_ratio = meter_offset / meter_range
                local db_value = point1[2] + (db_range * interpolation_ratio)
                
                debugLog(string.format("Meter: %.4f → Between %.4f (%.1f dB) and %.4f (%.1f dB) → %.1f dB", 
                    meter_normalized, point1[1], point1[2], point2[1], point2[2], db_value))
                
                return db_value
            end
        end
    end
    
    -- Fallback for values outside calibration range
    if meter_normalized <= METER_DB_CALIBRATION[1][1] then
        return METER_DB_CALIBRATION[1][2]
    else
        return METER_DB_CALIBRATION[#METER_DB_CALIBRATION][2]
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
    
    -- Always update the display for every meter value
    self.values.text = formatDB(db_value)
    
    -- Enhanced logging for debugging low values
    local shouldLog = false
    
    -- Always log if value changed significantly
    if not lastDB or math.abs(db_value - lastDB) > 1.0 then
        shouldLog = true
    end
    
    -- ALWAYS log values below -22 dBFS to debug calibration
    if db_value < -22 and db_value > -math.huge then
        shouldLog = true
    end
    
    -- Also log if meter value changed significantly (helps debug very low values)
    if lastMeterValue and math.abs(meter_level - lastMeterValue) > 0.01 then
        if db_value < -20 then  -- Extra logging for low values
            shouldLog = true
        end
    end
    
    if shouldLog then
        log(string.format("Track %d: %s (meter: %.4f)%s", 
            myTrackNumber, formatDB(db_value), meter_level,
            db_value > 0 and " [CLIPPING]" or ""))
    end
    
    lastDB = db_value
    lastMeterValue = meter_level
    
    return false  -- Don't block other receivers
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    -- No update needed - display updates on OSC messages
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
        lastMeterValue = 0
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastDB = nil
        lastMeterValue = nil
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
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
        log("Peak dBFS meter - v2.2.1 with enhanced low-value logging")
        log("Verified points: 0.631=-22dB, 0.842=-6dB")
        log("Full range: -∞ to +60 dBFS")
        log("Low values (<-22dB) will always be logged for debugging")
    end
    
    if DEBUG == 1 then
        log("DEBUG MODE ENABLED")
    end
end

init()