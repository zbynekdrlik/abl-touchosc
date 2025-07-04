-- TouchOSC Vertical Meter Script with Accurate dBFS Calibration
-- Version: 2.4.1
-- Changed: Standardized DEBUG flag (uppercase) and disabled by default

-- Version constant
local VERSION = "2.4.1"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- Debug flag for raw meter values (NOT general debugging)
-- When set to 1, logs raw meter values for calibration purposes
local DEBUG_RAW_VALUES = 0

-- State variables
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local lastMeterValue = 0
local animationActive = false
local animationStartTime = 0
local animationStartValue = 0
local targetValue = 0

-- Calibration table for meter to dB conversion
-- Based on verified measurements from user testing
local METER_DB_CALIBRATION = {
    {0.000, -60.0},   -- Minimum displayed (was -inf, but we show from -60)
    {0.001, -60.0},   -- Very quiet (clamped to -60)
    {0.600, -24.4},   -- VERIFIED by user
    {0.631, -22.0},   -- VERIFIED by user
    {0.842, -6.0},    -- VERIFIED by user
    {1.000, 0.0},     -- Unity (0 dB)
}

-- Visual constants
local MIN_DB = -60  -- Minimum dB to display
local MAX_DB = 6    -- Maximum dB to display
local DB_RANGE = MAX_DB - MIN_DB

-- Animation settings
local ANIMATION_DURATION = 0.3  -- 300ms for smooth animation
local FALL_SPEED_FACTOR = 1.5   -- Falls 1.5x faster than it rises

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "METER"
        if self.parent and self.parent.name then
            context = "METER(" .. self.parent.name .. ")"
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

-- ===========================
-- METER CONVERSION FUNCTIONS
-- ===========================

-- Convert normalized meter value (0-1) to dB using calibration table
local function meterToDB(meter_normalized)
    -- Debug logging for calibration
    if DEBUG_RAW_VALUES == 1 then
        log(string.format("Raw meter: %.3f", meter_normalized))
    end
    
    -- Handle edge cases
    if meter_normalized <= 0 then
        return MIN_DB  -- Return minimum instead of -inf
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
            
            local db_value = point1[2] + (db_range * interpolation_ratio)
            
            -- Clamp to display range
            if db_value < MIN_DB then
                return MIN_DB
            elseif db_value > MAX_DB then
                return MAX_DB
            else
                return db_value
            end
        end
    end
    
    -- Should not reach here, but return 0 as fallback
    return 0
end

-- Convert dB to meter height (0-1) for visual display
local function dbToMeterHeight(db)
    -- Map dB value to 0-1 range for display
    -- MIN_DB (-60) = 0, MAX_DB (6) = 1
    local normalized = (db - MIN_DB) / DB_RANGE
    
    -- Clamp to valid range
    if normalized < 0 then
        return 0
    elseif normalized > 1 then
        return 1
    else
        return normalized
    end
end

-- ===========================
-- VISUAL UPDATE
-- ===========================

local function updateMeterHeight(height)
    -- For radial meter, update the value
    self.values.x = height
    
    -- Update color based on level
    -- Green for normal, yellow for warning, red for hot
    local db = MIN_DB + (height * DB_RANGE)
    
    if db > 0 then
        -- Red for clipping
        self.color = Color(1, 0, 0, 1)
    elseif db > -6 then
        -- Yellow for hot signal
        self.color = Color(1, 1, 0, 1)
    elseif db > -20 then
        -- Green for good signal
        self.color = Color(0, 1, 0, 1)
    else
        -- Dim green for low signal
        self.color = Color(0, 0.5, 0, 1)
    end
end

-- ===========================
-- ANIMATION HANDLING
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
            updateMeterHeight(targetValue)
            lastMeterValue = targetValue
            animationActive = false
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
            updateMeterHeight(currentValue)
        end
    end
end

-- ===========================
-- OSC HANDLER
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Check if we have track info
    if not trackNumber or not trackType then
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
    
    -- Check if this message is for our track
    if arguments[1].value == trackNumber then
        -- Get the meter value
        local meter_value = arguments[2].value
        
        -- Convert to dB
        local db_value = meterToDB(meter_value)
        
        -- Convert to meter height
        local height = dbToMeterHeight(db_value)
        
        -- Start animation to new value
        if height ~= lastMeterValue then
            animationStartTime = os.clock()
            animationStartValue = lastMeterValue
            targetValue = height
            animationActive = true
        end
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    if key == "track_changed" then
        trackNumber = value
        -- Reset meter when track changes
        lastMeterValue = 0
        updateMeterHeight(0)
        animationActive = false
    elseif key == "track_type" then
        trackType = value
    elseif key == "track_unmapped" then
        trackNumber = nil
        trackType = nil
        lastMeterValue = 0
        updateMeterHeight(0)
        animationActive = false
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Script v" .. VERSION .. " loaded")
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    
    -- Set initial visual state
    updateMeterHeight(0)
end

init()