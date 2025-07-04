-- TouchOSC Meter Script with Multi-OSC Support
-- Version: 2.5.1
-- Fixed: Use correct property 'value' instead of 'y' for meter
-- Optimized: Removed update() function - fully event-driven
-- Fixed: Parse parent tag for track info instead of accessing properties
-- Added: Return track support using parent's trackType

-- Version constant
local VERSION = "2.5.1"

-- ===========================
-- DEBUG MODE
-- ===========================

-- Set to 1 to enable debug messages
local DEBUG = 0

-- ===========================
-- PERFORMANCE SETTINGS
-- ===========================

-- Smoothing factor for meter display (0-1, higher = smoother)
local SMOOTHING_FACTOR = 0.7

-- ===========================
-- STATE VARIABLES
-- ===========================

-- Current meter levels
local targetLevel = 0
local smoothedLevel = 0

-- Color state
local currentColor = {r = 0, g = 0, b = 0}

-- Touch state
local hasPendingUpdate = false

-- Track state
local trackNumber = nil
local trackType = nil

-- ===========================
-- DEBUG LOGGING
-- ===========================

local function debug(...)
    if DEBUG == 0 then return end
    
    local args = {...}
    local msg = table.concat(args, " ")
    
    -- Get parent name for context
    local context = "METER"
    if self.parent and self.parent.name then
        context = "METER(" .. self.parent.name .. ")"
    end
    
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. msg)
end

-- ===========================
-- PARENT TAG PARSING
-- ===========================

-- Get track number and type from parent group
local function getTrackInfo()
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if self.parent and self.parent.tag then
        local instance, trackNum, tType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and tType then
            return tonumber(trackNum), tType
        end
    end
    return nil, nil
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get connection index for this instance
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
-- METER PROCESSING
-- ===========================

-- Color gradient calculation
local function levelToColor(level)
    local color = {r = 0, g = 0, b = 0}
    
    if level < 0.7 then
        -- Green to yellow (0.0 to 0.7)
        color.r = level / 0.7
        color.g = 1.0
        color.b = 0
    elseif level < 0.9 then
        -- Yellow to orange (0.7 to 0.9)
        local t = (level - 0.7) / 0.2
        color.r = 1.0
        color.g = 1.0 - (t * 0.5)  -- Fade green from 1.0 to 0.5
        color.b = 0
    else
        -- Orange to red (0.9 to 1.0)
        local t = (level - 0.9) / 0.1
        color.r = 1.0
        color.g = 0.5 - (t * 0.5)  -- Fade green from 0.5 to 0.0
        color.b = 0
    end
    
    return color
end

-- Smooth color transition
local function smoothColor(current, target, factor)
    return {
        r = current.r + (target.r - current.r) * factor,
        g = current.g + (target.g - current.g) * factor,
        b = current.b + (target.b - current.b) * factor
    }
end

-- Update meter display
local function updateMeterDisplay()
    -- Update meter value (meters use 'value' property)
    self.values.value = smoothedLevel
    
    -- Calculate and smooth color
    local targetColor = levelToColor(smoothedLevel)
    currentColor = smoothColor(currentColor, targetColor, 0.3)
    
    -- Apply color
    self.color = Color(currentColor.r, currentColor.g, currentColor.b, 1)
    
    debug(string.format("Updated meter display: %.3f", smoothedLevel))
end

-- ===========================
-- OSC HANDLER
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Check if this is a meter message
    local isMeterMessage = false
    if trackType == "return" and path == '/live/return/get/output_meter_level' then
        isMeterMessage = true
    elseif trackType == "track" and path == '/live/track/get/output_meter_level' then
        isMeterMessage = true
    end
    
    if not isMeterMessage then
        return false
    end
    
    -- Get our connection index
    local myConnection = getConnectionIndex()
    
    -- Check if this message is from our connection
    if connections and not connections[myConnection] then
        debug("Ignoring message from connection", myConnection)
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
    
    -- Get meter level (already normalized 0-1)
    local meter_level = arguments[2].value
    
    -- Clamp to valid range
    targetLevel = math.max(0, math.min(1, meter_level))
    
    -- Apply smoothing immediately
    smoothedLevel = smoothedLevel + (targetLevel - smoothedLevel) * (1 - SMOOTHING_FACTOR)
    
    debug(string.format("Received meter level: %.3f (smoothed: %.3f)", targetLevel, smoothedLevel))
    
    -- Update display immediately if not being touched
    if not self.values.touch then
        updateMeterDisplay()
    else
        -- Mark pending update for when touch is released
        hasPendingUpdate = true
        debug("Touch active - deferring display update")
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- TOUCH HANDLER
-- ===========================

function onValueChanged(valueName)
    if valueName == "touch" and not self.values.touch then
        -- Touch released - process any pending update
        if hasPendingUpdate then
            updateMeterDisplay()
            hasPendingUpdate = false
            debug("Touch released - applying pending update")
        end
    end
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    if key == "track_changed" then
        -- Reset meter when track changes
        targetLevel = 0
        smoothedLevel = 0
        updateMeterDisplay()
        debug("Track changed - meter reset")
    elseif key == "control_enabled" then
        -- Show/hide based on track mapping status
        self.values.visible = value
        if not value then
            -- Reset meter when hidden
            targetLevel = 0
            smoothedLevel = 0
            updateMeterDisplay()
        end
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    print("[" .. os.date("%H:%M:%S") .. "] CONTROL(meter) Meter v" .. VERSION)
    
    -- Get track info from parent
    trackNumber, trackType = getTrackInfo()
    
    if trackNumber then
        debug("Initialized for", trackType, "track", trackNumber)
    else
        debug("WARNING: No track info available from parent")
    end
    
    -- Initialize meter at zero (meters use 'value' property)
    self.values.value = 0
    self.color = Color(0, 1, 0, 1)  -- Start green
    
    -- Initialize state
    targetLevel = 0
    smoothedLevel = 0
    currentColor = {r = 0, g = 1, b = 0}
    
    debug("Smoothing factor:", SMOOTHING_FACTOR)
    debug("Event-driven updates - no continuous polling")
end

init()