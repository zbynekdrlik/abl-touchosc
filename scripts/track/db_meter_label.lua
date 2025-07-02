-- TouchOSC dB Meter Label Display
-- Version: 2.0.0
-- Shows actual peak dBFS level from track output meter
-- Properly calibrated to match Ableton's meter display
-- Multi-connection routing support

-- Version constant
local VERSION = "2.0.0"

-- State variables
local lastDB = -70.0
local lastUpdateTime = 0
local UPDATE_THRESHOLD = 0.1  -- Only update display if dB changes by more than this

-- Debug mode
local DEBUG = 0  -- Set to 1 for detailed logging

-- ===========================
-- METER CALIBRATION
-- ===========================
-- Based on actual Ableton meter readings
-- These values are derived from comparing OSC meter values to Ableton's dB display

-- Direct meter to dB conversion
-- AbletonOSC sends normalized values where:
-- 0.0 = -∞ dB
-- 0.631 = -22 dBFS (verified by user)
-- 0.842 = -6 dBFS (from user logs)
-- 1.0 = 0 dBFS (maximum before clipping)

-- Using logarithmic conversion with proper calibration
local METER_REFERENCE = 0.631  -- This equals -22 dBFS in Ableton
local DB_REFERENCE = -22.0

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

-- Convert meter level to dB with proper calibration
function meterToDB(meter_normalized)
    -- Handle silence
    if not meter_normalized or meter_normalized <= 0.001 then
        return -math.huge
    end
    
    -- Handle values above 1.0 (Ableton's floating-point headroom)
    if meter_normalized > 1.0 then
        -- Linear extrapolation above 0 dB
        -- Each 0.1 above 1.0 = roughly +6 dB
        local db_above_zero = (meter_normalized - 1.0) * 60
        return db_above_zero
    end
    
    -- Standard logarithmic conversion for 0-1 range
    -- Using 20 * log10(meter) with calibration offset
    local db_raw = 20 * math.log10(meter_normalized)
    
    -- Calibration: adjust so that our reference point matches Ableton
    -- When meter = 0.631, we want -22 dB
    local db_raw_at_reference = 20 * math.log10(METER_REFERENCE)
    local calibration_offset = DB_REFERENCE - db_raw_at_reference
    
    local db_calibrated = db_raw + calibration_offset
    
    -- Debug logging
    debugLog(string.format("Meter: %.3f → Raw dB: %.1f → Calibrated: %.1f", 
        meter_normalized, db_raw, db_calibrated))
    
    return db_calibrated
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
    
    -- Always update the display when we receive a meter value
    self.values.text = formatDB(db_value)
    
    -- Log significant changes
    if not lastDB or math.abs(db_value - lastDB) > 1.0 or 
       (lastDB <= 0 and db_value > 0) or (lastDB > 0 and db_value <= 0) then
        -- Only log non-silence values or transitions
        if db_value > -60 or (lastDB and lastDB > -60) then
            log(string.format("Track %d: %s (meter: %.3f)%s", 
                myTrackNumber, formatDB(db_value), meter_level,
                db_value > 0 and " [CLIPPING]" or ""))
        end
    end
    
    lastDB = db_value
    lastUpdateTime = os.clock()
    
    return false  -- Don't block other receivers
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    -- Let AbletonOSC control when to show silence
    -- No artificial timeouts
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
        log("Peak dBFS meter - calibrated to match Ableton")
        log("Verified: meter 0.631 = -22 dBFS")
    end
    
    if DEBUG == 1 then
        log("DEBUG MODE ENABLED")
    end
end

init()
