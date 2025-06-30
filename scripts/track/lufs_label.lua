-- TouchOSC LUFS Meter Display
-- Version: 1.2.0
-- Shows approximate LUFS based on track output meter level
-- Multi-connection routing support
-- Simplified conversion for better accuracy

-- Version constant
local VERSION = "1.2.0"

-- State variables
local lastLUFS = -60.0
local lufsBuffer = {}  -- Buffer for averaging
local bufferSize = 15  -- Reduced for faster response (~0.25 seconds at 60fps)

-- Debug mode
local DEBUG = 0  -- Set to 1 to see conversion details

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
-- SIMPLIFIED LUFS CALCULATION
-- ===========================

-- Direct conversion from normalized meter value to dB
-- Based on AbletonOSC meter output (0-1 normalized)
function meterToDB(meter_normalized)
    if not meter_normalized or meter_normalized <= 0 then
        return -math.huge
    end
    
    -- AbletonOSC meter is already in a useful scale
    -- We'll use a simpler conversion based on common meter scaling
    -- where 1.0 = 0dB and it follows a logarithmic scale
    
    -- Simple logarithmic conversion
    -- This assumes the meter value is already properly scaled
    local db = 20 * math.log10(meter_normalized)
    
    -- Clamp to reasonable range
    if db < -60 then
        return -60
    elseif db > 6 then
        return 6
    end
    
    return db
end

-- Convert meter level to approximate LUFS
function meterToLUFS(meter_normalized)
    -- Get dB value directly
    local db_value = meterToDB(meter_normalized)
    
    -- For sine wave: LUFS ≈ RMS level
    -- For a sine wave, peak = RMS + 3dB
    -- So if we have peak meter, LUFS ≈ peak - 3dB for sine
    -- For complex material, the offset varies
    
    -- Simple approach: assume meter shows peak, apply offset
    local lufs_offset = 3.0  -- Start with sine wave offset
    
    -- Adjust offset based on level (louder = more compressed typically)
    if db_value >= -6 then
        lufs_offset = 3.0  -- Sine wave or very dynamic
    elseif db_value >= -12 then
        lufs_offset = 6.0  -- Typical music
    elseif db_value >= -20 then
        lufs_offset = 9.0  -- More dynamic range
    else
        lufs_offset = 12.0  -- Very dynamic
    end
    
    local lufs = db_value - lufs_offset
    
    -- Debug logging
    debugLog(string.format("Meter: %.3f, dB: %.1f, offset: %.1f, LUFS: %.1f", 
        meter_normalized, db_value, lufs_offset, lufs))
    
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

-- Format LUFS value for display with unit
function formatLUFS(lufs_value)
    if lufs_value <= -60 then
        return "-60.0 LUFS"
    else
        return string.format("%.1f LUFS", lufs_value)
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
        log(string.format("Track %d: %s (meter: %.3f)", 
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
        self.values.text = "-60.0 LUFS"
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
        self.values.text = "-60.0 LUFS"
    else
        self.values.text = "-"
    end
    
    -- Initialize buffer
    lufsBuffer = {}
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
        log("LUFS calculated from output meter levels")
        log("Using " .. bufferSize .. " sample averaging (faster response)")
        log("Simplified conversion for better accuracy")
    end
    
    if DEBUG == 1 then
        log("DEBUG MODE ENABLED - Conversion details will be logged")
    end
end

init()