-- TouchOSC dBFS Meter Label Display (Real-time meter value in dBFS)
-- Version: 2.7.0
-- Restored: Multi-connection routing support
-- Maintained: All existing functionality including debug mode toggle

-- Version constant
local VERSION = "2.7.0"

-- Debug flag for meter value display (NOT general debugging)
-- When set to 1, shows raw meter values for calibration
local DEBUG_METER_VALUES = 0

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- State variables
local trackNumber = nil
local trackType = nil
local lastMeterDB = -math.huge
local lastRawMeter = 0

-- Calibration table for meter to dBFS conversion
-- Based on verified measurements from user testing
local METER_DB_CALIBRATION = {
    {0.000, -math.huge},  -- Silence
    {0.001, -80.0},       -- Very quiet  
    {0.600, -24.4},       -- VERIFIED by user
    {0.631, -22.0},       -- VERIFIED by user
    {0.842, -6.0},        -- VERIFIED by user
    {1.000, 0.0},         -- Unity (0 dBFS)
}

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "dBFS"
        if self.parent and self.parent.name then
            context = "dBFS(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONNECTION HELPERS
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

-- Get connection index by reading configuration directly (RESTORED)
local function getConnectionIndex()
    -- Default to connection 1 if can't determine
    local defaultConnection = 1
    
    -- Check parent tag for instance name
    if not self.parent or not self.parent.tag then
        return defaultConnection
    end
    
    -- Extract instance name from tag
    local instance = self.parent.tag:match("^(%w+):")
    if not instance then
        return defaultConnection
    end
    
    -- Find and read configuration
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        if DEBUG == 1 then
            log("No configuration found, using default connection")
        end
        return defaultConnection
    end
    
    -- Parse configuration to find connection for this instance
    local configText = configObj.values.text
    for line in configText:gmatch("[^\r\n]+") do
        -- Look for connection_instance: number pattern
        local configInstance, connectionNum = line:match("connection_(%w+):%s*(%d+)")
        if configInstance and configInstance == instance then
            if DEBUG == 1 then
                log("Found connection for " .. instance .. ": " .. connectionNum)
            end
            return tonumber(connectionNum) or defaultConnection
        end
    end
    
    if DEBUG == 1 then
        log("No connection found for instance: " .. instance)
    end
    return defaultConnection
end

-- ===========================
-- METER TO dBFS CONVERSION
-- ===========================

-- Convert normalized meter value (0-1) to dBFS using calibration table
local function meterToDB(meter_normalized)
    -- Handle edge cases
    if meter_normalized <= 0 then
        return -math.huge
    elseif meter_normalized >= 1 then
        return 0
    end
    
    -- Find the appropriate calibration points and interpolate
    for i = 1, #METER_DB_CALIBRATION - 1 do
        local point1 = METER_DB_CALIBRATION[i]
        local point2 = METER_DB_CALIBRATION[i + 1]
        
        if meter_normalized >= point1[1] and meter_normalized <= point2[1] then
            -- Linear interpolation between calibration points
            local meter_range = point2[1] - point1[1]
            local db_range = point2[2] - point1[2]
            local meter_offset = meter_normalized - point1[1]
            local interpolation_ratio = meter_offset / meter_range
            
            return point1[2] + (db_range * interpolation_ratio)
        end
    end
    
    -- Should not reach here, but return 0 as fallback
    return 0
end

-- Format dBFS value for display
local function formatDBFS(db_value, raw_meter)
    if DEBUG_METER_VALUES == 1 and raw_meter then
        -- Debug mode: show raw meter value for calibration
        return string.format("%.3f", raw_meter)
    else
        -- Normal mode: show dBFS
        if db_value == -math.huge or db_value < -80 then
            return "-∞ dBFS"
        elseif db_value >= 0 then
            return "0.0 dBFS"  -- Clamp at 0 dBFS
        else
            return string.format("%.1f dBFS", db_value)
        end
    end
end

-- ===========================
-- OSC HANDLER WITH MULTI-CONNECTION
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Get track info from parent
    local trackNum, trackTyp = getTrackInfo()
    if not trackNum then
        return false
    end
    
    -- Store in local variables
    trackNumber = trackNum
    trackType = trackTyp
    
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
    
    -- Get our connection index (MULTI-CONNECTION SUPPORT)
    local myConnection = getConnectionIndex()
    
    -- Check if this message is from our connection
    if connections and not connections[myConnection] then
        return false
    end
    
    -- Check if this message is for our track
    if arguments[1].value == trackNumber then
        -- Get the meter value and convert to dBFS
        local meter_value = arguments[2].value
        lastRawMeter = meter_value
        
        -- Convert to dBFS using calibration table
        local db_value = meterToDB(meter_value)
        lastMeterDB = db_value
        
        -- Update label text
        self.values.text = formatDBFS(db_value, meter_value)
        
        if DEBUG == 1 then
            log(string.format("%s track %d (conn %d): %.3f -> %s", 
                trackType, trackNumber, myConnection, meter_value, formatDBFS(db_value)))
        end
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    -- Handle track changes
    if key == "track_changed" then
        trackNumber = value
        -- Clear the display when track changes
        self.values.text = "-∞ dBFS"
        lastMeterDB = -math.huge
        lastRawMeter = 0
    elseif key == "track_type" then
        trackType = value
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        trackNumber = nil
        trackType = nil
        self.values.text = "-"
        lastMeterDB = nil
        lastRawMeter = 0
    end
end

-- ===========================
-- USER INTERACTION
-- ===========================

function onValueChanged(valueName)
    -- Toggle debug mode when label is tapped
    if valueName == "x" then
        DEBUG_METER_VALUES = 1 - DEBUG_METER_VALUES  -- Toggle between 0 and 1
        
        -- Update display immediately
        if lastMeterDB then
            self.values.text = formatDBFS(lastMeterDB, lastRawMeter)
        end
        
        -- Visual feedback
        if DEBUG_METER_VALUES == 1 then
            self.color = Color(1, 1, 0, 1)  -- Yellow in debug mode
        else
            self.color = Color(1, 1, 1, 1)  -- White in normal mode
        end
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    
    -- Set initial text
    if trackNumber then
        self.values.text = "-∞ dBFS"
    else
        self.values.text = "-"
    end
    
    -- Set initial color
    self.color = Color(1, 1, 1, 1)  -- White
    
    if DEBUG == 1 then
        log("=== dBFS METER WITH MULTI-CONNECTION RESTORED ===")
        log("Multi-connection routing enabled")
    end
end

init()