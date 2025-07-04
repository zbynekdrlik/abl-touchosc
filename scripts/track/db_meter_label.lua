-- TouchOSC dB Meter Label Display
-- Version: 2.8.0
-- FIXED: Removed value_changed fallback - direct OSC only
-- FIXED: Use centralized logging via notify
-- Shows actual peak dBFS level from track output meter
-- Multi-connection routing support

local VERSION = "2.8.0"

-- State variables
local parentGroup = nil
local currentDb = -math.huge
local currentColor = "GREEN"
local lastLoggedDb = nil
local statusIndicator = nil
local lastDB = -70.0
local lastMeterValue = 0

-- Debug mode
local DEBUG = 0  -- Set to 1 for detailed logging

-- Curve settings (must match meter)
local use_log_curve = true
local log_exponent = 0.515

-- Color thresholds (must match meter)
local COLOR_THRESHOLD_YELLOW = -12
local COLOR_THRESHOLD_RED = -3

-- ===========================
-- METER CALIBRATION TABLE
-- ===========================
-- Calibration table based on extensive testing with Ableton Live
-- AbletonOSC uses non-linear scaling with 0.921 = 0 dBFS, 1.0 = +6 dBFS
local METER_DB_CALIBRATION = {
    {0.000, -math.huge},  -- Silence
    {0.001, -100.0},      -- Very quiet
    {0.010, -80.0},       
    {0.050, -70.0},       
    {0.070, -64.7},       -- Verified
    {0.100, -60.0},       
    {0.150, -54.0},       
    {0.200, -50.0},       
    {0.250, -46.0},       
    {0.300, -43.0},       
    {0.350, -40.5},       
    {0.400, -38.5},       
    {0.425, -37.7},       -- Verified
    {0.500, -33.0},       
    {0.539, -29.0},       -- Verified
    {0.600, -24.4},       -- Verified
    {0.631, -22.0},       -- Verified
    {0.674, -18.8},       -- Verified
    {0.700, -16.8},       
    {0.750, -14.0},       
    {0.800, -10.0},       
    {0.842, -6.0},        -- Verified
    {0.900, -3.0},        
    {0.921, 0.0},         -- Verified (unity/0 dBFS)
    {0.950, 2.0},         
    {0.980, 4.0},         
    {1.000, 6.0},         -- Verified (max headroom)
}

-- ===========================
-- LOGGING (FIXED: Use centralized logging)
-- ===========================

local function log(message)
    if DEBUG == 1 then
        -- Add context to identify which control sent the log
        local context = "dBFS"
        if parentGroup and parentGroup.name then
            context = "dBFS(" .. parentGroup.name .. ")"
        end
        
        -- Send to document script for proper logging
        root:notify("log_message", context .. ": " .. message)
        
        -- Also print to console for development/debugging
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get track number and type from parent group
local function getTrackInfo()
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if parentGroup and parentGroup.tag then
        local instance, trackNum, trackType = parentGroup.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            return tonumber(trackNum), trackType
        end
    end
    return nil, nil
end

-- Get connection index for this instance
local function getConnectionIndex()
    -- Default to connection 1 if can't determine
    local defaultConnection = 1
    
    -- Check parent tag for instance name
    if not parentGroup or not parentGroup.tag then
        return defaultConnection
    end
    
    -- Extract instance name from tag
    local instance = parentGroup.tag:match("^(%w+):")
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
    
    -- Handle values above 1.0 (extended range)
    if meter_normalized > 1.0 then
        -- Extrapolate beyond our calibration
        -- We know 1.0 = +6 dBFS, so continue linearly
        local db_above_6 = 6.0 + ((meter_normalized - 1.0) * 20)
        return db_above_6
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
                
                log(string.format("Meter: %.4f → Between %.4f (%.1f dB) and %.4f (%.1f dB) → %.1f dB", 
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

-- Get color name based on dB level
function getColorForDb(db)
    if db >= COLOR_THRESHOLD_RED then
        return "RED"
    elseif db >= COLOR_THRESHOLD_YELLOW then
        return "YELLOW"
    else
        return "GREEN"
    end
end

-- ===========================
-- PARENT GROUP HELPERS
-- ===========================

local function findParentGroup()
    if self.parent and self.parent.name then
        parentGroup = self.parent
        
        -- Find status indicator
        statusIndicator = parentGroup:findByName("status_indicator", false)
        if statusIndicator then
            log("Found status indicator")
        end
        
        return true
    end
    return false
end

-- ===========================
-- DISPLAY UPDATE
-- ===========================

local function updateDisplay(db_value)
    currentDb = db_value
    
    -- Update text
    self.values.text = formatDB(currentDb)
    
    -- Determine color
    local newColor = getColorForDb(currentDb)
    if newColor ~= currentColor then
        currentColor = newColor
        log("Color changed to: " .. currentColor)
    end
    
    -- Update status indicator if available
    if statusIndicator then
        -- Map color to indicator state
        if currentColor == "RED" then
            statusIndicator.values.x = 1.0  -- Full red
            statusIndicator.color = Color(1.0, 0.0, 0.0, 1.0)
        elseif currentColor == "YELLOW" then
            statusIndicator.values.x = 0.5  -- Half yellow
            statusIndicator.color = Color(1.0, 0.8, 0.0, 1.0)
        else
            statusIndicator.values.x = 0.0  -- Empty/green
            statusIndicator.color = Color(0.0, 0.8, 0.0, 1.0)
        end
    end
    
    -- Log significant changes
    if DEBUG == 1 and lastLoggedDb then
        local change = math.abs(currentDb - lastLoggedDb)
        if change > 1.0 or currentDb == -math.huge or lastLoggedDb == -math.huge then
            log(string.format("Level: %s (%s)", formatDB(currentDb), currentColor))
            lastLoggedDb = currentDb
        end
    elseif DEBUG == 1 then
        log(string.format("Initial level: %s (%s)", formatDB(currentDb), currentColor))
        lastLoggedDb = currentDb
    end
end

-- ===========================
-- OSC HANDLER (DIRECT UPDATES ONLY)
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
    
    if msgTrackNumber ~= trackNumber then
        return false
    end
    
    -- Get meter level and calculate dB
    local meter_level = arguments[2].value
    local db_value = meterToDB(meter_level)
    
    -- Update the display immediately for real-time response
    updateDisplay(db_value)
    
    -- Enhanced logging for debugging
    local shouldLog = false
    
    -- Always log if value changed significantly
    if not lastDB or math.abs(db_value - lastDB) > 1.0 then
        shouldLog = true
    end
    
    -- Log clipping
    if db_value > 0 and (not lastDB or lastDB <= 0) then
        shouldLog = true
    end
    
    if shouldLog and DEBUG == 1 then
        log(string.format("%s track %d: %s (meter: %.4f)%s", 
            trackType, trackNumber, formatDB(db_value), meter_level,
            db_value > 0 and " [CLIPPING]" or ""))
    end
    
    lastDB = db_value
    lastMeterValue = meter_level
    
    return false  -- Don't block other receivers
end

-- ===========================
-- NOTIFICATIONS (FIXED: Removed value_changed fallback)
-- ===========================

function onReceiveNotify(key, value)
    -- CRITICAL FIX: Removed value_changed handler - each control receives OSC directly!
    
    if key == "track_changed" then
        -- Reset when track changes
        updateDisplay(-math.huge)
        log("Track changed - reset")
        
    elseif key == "track_unmapped" then
        -- Clear when unmapped
        self.values.text = "-"
        lastDB = nil
        lastMeterValue = nil
        log("Track unmapped - cleared")
        
    elseif key == "control_enabled" then
        -- Show/hide based on track mapping status
        self.values.visible = value
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging
    log("Script v" .. VERSION .. " loaded")
    
    -- Find parent group
    if not findParentGroup() then
        -- Use notify for error logging too
        root:notify("log_message", "dBFS: ERROR - No parent group found")
        print("[" .. os.date("%H:%M:%S") .. "] dBFS: ERROR - No parent group found")
        return
    end
    
    -- Initialize display
    updateDisplay(-math.huge)
    
    log("Initialized - Direct OSC handling only!")
    log("CRITICAL FIX: Removed value_changed fallback")
    log("Peak dBFS meter - accurately calibrated to match Ableton Live")
    log("Range: -∞ to +6 dBFS (32-bit float headroom)")
end

init()
