-- TouchOSC Pan Control Script
-- Version: 1.1.0
-- Added: Centralized logging through document script

-- Version constant
local VERSION = "1.1.0"

-- ===========================
-- CONFIGURATION SECTION
-- ===========================

local SMOOTHING_SPEED = 0.15       -- Smoothing speed (0.0 = instant, 1.0 = very slow)
local SEND_THRESHOLD = 0.001       -- Minimum change to send OSC
local CATCH_THRESHOLD = 0.02       -- Distance to "catch" incoming value
local UPDATE_RATE = 30             -- Updates per second
local AUTO_RELEASE_TIME = 500      -- Time to wait before auto-releasing (ms)
local TOUCH_DEBOUNCE = 50          -- Debounce time for touch detection (ms)
local CENTER_SNAP = 0.05           -- Snap to center within this range
local DEBUG_MODE = false           -- Enable debug logging

-- ===========================
-- STATE VARIABLES
-- ===========================

local targetValue = 0.5            -- Current target from Ableton (0.5 = center)
local displayValue = 0.5           -- Current displayed value (smoothed)
local lastSentValue = 0.5          -- Last value sent to Ableton
local lastTouchTime = 0            -- Last time user touched control
local isUserTouching = false       -- Is user currently touching?
local isCaught = true              -- Has control "caught" the Ableton value?
local lastUpdateTime = 0           -- For frame rate limiting
local touchStartValue = 0.5        -- Value when touch began
local hasMoved = false             -- Has user moved control since touching?

-- Reference to document script for connection routing
local documentScript = nil

-- ===========================
-- LOGGING
-- ===========================

-- Centralized logging through document script
local function log(message)
    -- Get parent name for context
    local context = "PAN"
    if self.parent and self.parent.name then
        context = "PAN(" .. self.parent.name .. ")"
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
-- UTILITY FUNCTIONS
-- ===========================

-- Convert TouchOSC value (0-1) to Ableton pan (-1 to 1)
local function touchOSCToAbleton(value)
    return (value * 2) - 1
end

-- Convert Ableton pan (-1 to 1) to TouchOSC value (0-1)
local function abletonToTouchOSC(value)
    return (value + 1) / 2
end

-- Apply center snap
local function applyCenterSnap(value)
    if math.abs(value - 0.5) < CENTER_SNAP then
        return 0.5
    end
    return value
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get the connection index from parent group
local function getConnectionIndex()
    -- Check if parent has tag with instance:trackNumber format
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance and trackNum then
            -- Get document script reference
            if not documentScript then
                documentScript = root
            end
            
            -- Call the helper function from document script
            if documentScript.getConnectionForInstance then
                return documentScript.getConnectionForInstance(instance)
            end
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
-- OSC COMMUNICATION
-- ===========================

-- Send pan to Ableton (with connection routing)
local function sendPan(value)
    local trackNumber = getTrackNumber()
    if not trackNumber then
        return
    end
    
    -- Apply center snap
    local snappedValue = applyCenterSnap(value)
    
    -- Convert to Ableton range
    local abletonValue = touchOSCToAbleton(snappedValue)
    
    -- Get connection for this instance
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send with connection routing
    sendOSC('/live/track/set/panning', trackNumber, abletonValue, connections)
    lastSentValue = value
    
    debugLog(string.format("Sent pan: %.3f (Ableton: %.3f) to track %d on connection %d", 
        value, abletonValue, trackNumber, connectionIndex))
end

-- ===========================
-- TOUCH HANDLING
-- ===========================

-- Called when user touches the control
local function onTouch()
    -- Safety check: only process if track is mapped
    if not isTrackMapped() then
        -- Reset to center if track not mapped
        self.values.x = 0.5
        displayValue = 0.5
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

-- Called when user releases the control
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
        -- User is actively moving the control
        displayValue = self.values.x
        isCaught = true
        
        -- Send if changed enough
        if math.abs(displayValue - lastSentValue) > SEND_THRESHOLD then
            sendPan(displayValue)
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
                displayValue = smoothValue(displayValue, targetValue, SMOOTHING_SPEED, deltaTime)
            end
            
            -- Update visual
            self.values.x = displayValue
        end
    end
end

-- ===========================
-- VALUE CHANGE HANDLERS
-- ===========================

-- Handle control value changes
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
                sendPan(displayValue)
            end
        end
    end
end

-- ===========================
-- OSC RECEIVE HANDLERS
-- ===========================

-- Handle incoming pan updates from Ableton
function onReceiveOSC(message, connections)
    -- Only process pan messages
    if message[1] ~= '/live/track/get/panning' then
        return false
    end
    
    -- Check if this message is from our connection
    local myConnection = getConnectionIndex()
    if not connections[myConnection] then
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
    
    -- Get the pan value (-1 to 1 from Ableton)
    local abletonPan = arguments[2].value
    
    -- Convert to TouchOSC range (0-1)
    targetValue = abletonToTouchOSC(abletonPan)
    
    debugLog(string.format("Received pan: %.3f (TouchOSC: %.3f) for track %d", 
        abletonPan, targetValue, msgTrackNumber))
    
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
        targetValue = 0.5
        displayValue = 0.5
        lastSentValue = 0.5
        isCaught = false
        self.values.x = 0.5
        debugLog("Track changed - reset pan to center")
    elseif key == "track_unmapped" then
        -- Disable control when track is unmapped
        self.values.x = 0.5
        displayValue = 0.5
        debugLog("Track unmapped - disabled pan control")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Ensure we're starting at center
    self.values.x = 0.5
    displayValue = 0.5
    targetValue = 0.5
    
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
