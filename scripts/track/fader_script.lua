-- TouchOSC Fader Script with Smoothing
-- Version: 2.2.0 
-- Fixed: Connection routing now reads config directly (scripts are isolated)

-- Version constant
local VERSION = "2.2.0"

-- ===========================
-- CONFIGURATION SECTION
-- ===========================

local SPEED = 0.2                  -- Smoothing speed (0.0 = instant, 1.0 = very slow)
local CURVE = 3                    -- Response curve (1 = linear, >1 = more curve)
local SEND_THRESHOLD = 0.001       -- Minimum change to send OSC (reduce network traffic)
local CATCH_THRESHOLD = 0.02       -- Distance to "catch" incoming value
local UPDATE_RATE = 30             -- Updates per second (lower = less CPU)
local AUTO_RELEASE_TIME = 500      -- Time to wait before auto-releasing (ms)
local TOUCH_DEBOUNCE = 50          -- Debounce time for touch detection (ms)
local DEBUG_MODE = false           -- Enable debug logging

-- ===========================
-- STATE VARIABLES
-- ===========================

local targetValue = 0              -- Current target from Ableton
local displayValue = 0             -- Current displayed value (smoothed)
local lastSentValue = 0            -- Last value sent to Ableton
local lastTouchTime = 0            -- Last time user touched fader
local isUserTouching = false       -- Is user currently touching?
local isCaught = true              -- Has fader "caught" the Ableton value?
local lastUpdateTime = 0           -- For frame rate limiting
local touchStartValue = 0          -- Value when touch began
local hasMoved = false             -- Has user moved fader since touching?

-- ===========================
-- LOGGING
-- ===========================

-- Centralized logging through document script
local function log(message)
    -- Get parent name for context
    local context = "FADER"
    if self.parent and self.parent.name then
        context = "FADER(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development/debugging
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Debug logging (only if DEBUG_MODE is true)
local function debugLog(...)
    if DEBUG_MODE then
        local args = {...}
        local msg = table.concat(args, " ")
        log("[DEBUG] " .. msg)
    end
end

-- ===========================
-- CURVE FUNCTIONS
-- ===========================

-- Convert linear to curved response
local function applyCurve(linear)
    if CURVE == 1 then
        return linear
    end
    
    -- Apply exponential curve
    return math.pow(linear, CURVE)
end

-- Convert curved back to linear
local function removeCurve(curved)
    if CURVE == 1 then
        return curved
    end
    
    -- Remove exponential curve
    return math.pow(curved, 1 / CURVE)
end

-- ===========================
-- SMOOTHING FUNCTIONS
-- ===========================

-- Smooth interpolation between values
local function smoothValue(current, target, speed, deltaTime)
    if speed <= 0 then
        return target
    end
    
    -- Calculate interpolation factor based on speed and deltaTime
    local factor = 1 - math.exp(-deltaTime * (1 - speed) * 10)
    
    -- Interpolate
    return current + (target - current) * factor
end

-- Check if we should "catch" the value
local function shouldCatch(current, target)
    return math.abs(current - target) < CATCH_THRESHOLD
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get connection configuration (read directly from config text)
local function getConnectionIndex()
    -- Check if parent has tag with instance:trackNumber format
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance then
            -- Find configuration object
            local configObj = root:findByName("configuration", true)
            if not configObj or not configObj.values or not configObj.values.text then
                debugLog("Warning: No configuration found, using default connection 1")
                return 1
            end
            
            local configText = configObj.values.text
            local searchKey = "connection_" .. instance .. ":"
            
            -- Parse configuration text
            for line in configText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$")  -- Trim whitespace
                if line:sub(1, #searchKey) == searchKey then
                    local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                    return tonumber(value) or 1
                end
            end
            
            debugLog("Warning: No config for " .. instance .. " - using default (1)")
            return 1
        end
    end
    
    -- Fallback to default
    return 1
end

-- Build connection table for OSC routing
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- ===========================
-- TRACK INFORMATION
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
    -- If parent doesn't have proper tag format, it's not mapped
    if not self.parent or not self.parent.tag then
        return false
    end
    
    -- Check for instance:trackNumber format
    local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and trackNum ~= nil
end

-- ===========================
-- OSC COMMUNICATION
-- ===========================

-- Send volume to Ableton (with connection routing)
local function sendVolume(value)
    local trackNumber = getTrackNumber()
    if not trackNumber then
        return
    end
    
    -- Apply curve before sending
    local curvedValue = applyCurve(value)
    
    -- Get connection for this instance
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send with connection routing
    sendOSC('/live/track/set/volume', trackNumber, curvedValue, connections)
    lastSentValue = value
    
    log(string.format("Volume change for track %d: %.3f", trackNumber, value))
end

-- ===========================
-- TOUCH HANDLING
-- ===========================

-- Called when user touches the fader
local function onTouch()
    -- Safety check: only process if track is mapped
    if not isTrackMapped() then
        -- Reset fader to 0 if track not mapped
        self.values.x = 0
        displayValue = 0
        return
    end
    
    local now = getMillis()
    
    -- Debounce touch events
    if now - lastTouchTime < TOUCH_DEBOUNCE then
        return
    end
    
    isUserTouching = true
    lastTouchTime = now
    touchStartValue = self.values.x
    hasMoved = false
    
    debugLog("Touch started at:", touchStartValue)
end

-- Called when user releases the fader
local function onRelease()
    if not isUserTouching then
        return
    end
    
    isUserTouching = false
    lastTouchTime = getMillis()
    
    -- If user didn't move, treat as a tap to catch
    if not hasMoved then
        isCaught = false
        debugLog("Tap detected - releasing catch")
    end
    
    debugLog("Touch released")
end

-- ===========================
-- UPDATE LOGIC
-- ===========================

-- Main update function
function update()
    -- Safety check: skip update if track not mapped
    if not isTrackMapped() then
        return
    end
    
    local now = getMillis()
    
    -- Frame rate limiting
    if now - lastUpdateTime < (1000 / UPDATE_RATE) then
        return
    end
    
    local deltaTime = (now - lastUpdateTime) / 1000
    lastUpdateTime = now
    
    -- Detect movement
    if isUserTouching and math.abs(self.values.x - touchStartValue) > 0.001 then
        hasMoved = true
    end
    
    -- Handle user interaction
    if isUserTouching and hasMoved then
        -- User is actively moving the fader
        displayValue = self.values.x
        isCaught = true
        
        -- Send if changed enough
        if math.abs(displayValue - lastSentValue) > SEND_THRESHOLD then
            sendVolume(displayValue)
        end
    else
        -- Not touching or hasn't moved
        
        -- Auto-release catch after timeout
        if isCaught and not isUserTouching and (now - lastTouchTime) > AUTO_RELEASE_TIME then
            isCaught = false
            debugLog("Auto-released catch")
        end
        
        -- Smooth to target if not caught
        if not isCaught then
            -- Check if we should catch
            if shouldCatch(displayValue, targetValue) then
                isCaught = true
                displayValue = targetValue
                debugLog("Caught target value:", targetValue)
            else
                -- Smooth towards target
                displayValue = smoothValue(displayValue, targetValue, SPEED, deltaTime)
            end
            
            -- Update visual
            self.values.x = displayValue
        end
    end
end

-- ===========================
-- VALUE CHANGE HANDLERS
-- ===========================

-- Handle fader value changes
function onValueChanged(valueName)
    if valueName == "touch" then
        if self.values.touch then
            onTouch()
        else
            onRelease()
        end
    elseif valueName == "x" then
        -- Only process if we're touching and track is mapped
        if isUserTouching and hasMoved and isTrackMapped() then
            displayValue = self.values.x
            
            -- Send if changed enough
            if math.abs(displayValue - lastSentValue) > SEND_THRESHOLD then
                sendVolume(displayValue)
            end
        end
    end
end

-- ===========================
-- OSC RECEIVE HANDLERS
-- ===========================

-- Handle incoming volume updates from Ableton
function onReceiveOSC(message, connections)
    -- Only process volume messages
    if message[1] ~= '/live/track/get/volume' then
        return false
    end
    
    -- Check if this is our track
    local arguments = message[2]
    if not arguments or #arguments < 2 then
        return false
    end
    
    local msgTrackNumber = arguments[1].value
    local myTrackNumber = getTrackNumber()
    
    if msgTrackNumber ~= myTrackNumber then
        return false
    end
    
    -- Get the volume value
    local newVolume = arguments[2].value
    
    -- Remove curve from Ableton's value
    targetValue = removeCurve(newVolume)
    
    debugLog(string.format("Received volume: %.3f (uncurved: %.3f) for track %d", 
        newVolume, targetValue, msgTrackNumber))
    
    -- Don't update if user is touching
    if not isUserTouching then
        -- Update display if not caught
        if not isCaught then
            displayValue = targetValue
            self.values.x = displayValue
        end
    end
    
    return true
end

-- ===========================
-- PARENT NOTIFICATION
-- ===========================

-- Handle notifications from parent group
function onReceiveNotify(key, value)
    -- Parent might notify us of track changes
    if key == "track_changed" then
        -- Reset state when track changes
        targetValue = 0
        displayValue = 0
        lastSentValue = 0
        isCaught = false
        self.values.x = 0
        debugLog("Track changed - reset fader")
    elseif key == "track_unmapped" then
        -- Disable fader when track is unmapped
        self.values.x = 0
        displayValue = 0
        debugLog("Track unmapped - disabled fader")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Ensure we're starting at 0
    self.values.x = 0
    displayValue = 0
    targetValue = 0
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    -- Set initial interactive state based on track mapping
    if not isTrackMapped() then
        self.color = Color(0.3, 0.3, 0.3, 0.5)
    end
end

-- Initialize on script load
init()
