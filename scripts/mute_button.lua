-- TouchOSC Mute Button Script
-- Version: 1.0.0
-- Phase: 01 (Connection-aware) - Checks parent group mapping and routes to correct connection

-- CRITICAL VERSION LOGGING - DO NOT REMOVE
local VERSION = "1.0.0"
print("[" .. os.date("%H:%M:%S") .. "] Mute Button Script v" .. VERSION .. " loaded")

-- ===========================
-- CONFIGURATION SECTION
-- ===========================

local DEBOUNCE_TIME = 50           -- Debounce time in ms to prevent double triggers
local VISUAL_FEEDBACK_TIME = 100   -- Time to show press feedback (ms)
local DEBUG_MODE = false           -- Enable debug logging

-- Colors
local COLOR_MUTED = Color(1, 0.2, 0.2, 1)      -- Red when muted
local COLOR_UNMUTED = Color(0.5, 0.5, 0.5, 1)  -- Gray when unmuted
local COLOR_PRESSED = Color(1, 1, 0, 1)        -- Yellow when pressed
local COLOR_DISABLED = Color(0.3, 0.3, 0.3, 0.5) -- Dim when disabled

-- ===========================
-- STATE VARIABLES
-- ===========================

local isMuted = false              -- Current mute state
local lastPressTime = 0            -- Last time button was pressed
local isPressed = false            -- Visual press state
local pressStartTime = 0           -- When press started (for visual feedback)

-- Reference to document script for connection routing
local documentScript = nil

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
-- DEBUG LOGGING
-- ===========================

local function debugLog(...)
    if DEBUG_MODE then
        print("[MuteButton]", ...)
    end
end

-- ===========================
-- VISUAL UPDATES
-- ===========================

-- Update button appearance based on state
local function updateVisual()
    if not isTrackMapped() then
        -- Disabled appearance
        self.color = COLOR_DISABLED
        self.values.text = "---"
    elseif isPressed then
        -- Pressed appearance
        self.color = COLOR_PRESSED
    elseif isMuted then
        -- Muted appearance
        self.color = COLOR_MUTED
        self.values.text = "MUTED"
    else
        -- Unmuted appearance
        self.color = COLOR_UNMUTED
        self.values.text = "MUTE"
    end
end

-- ===========================
-- OSC COMMUNICATION
-- ===========================

-- Send mute command to Ableton
local function sendMute(muteState)
    local trackNumber = getTrackNumber()
    if not trackNumber then
        return
    end
    
    -- Get connection for this instance
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send mute command (1 = muted, 0 = unmuted)
    local value = muteState and 1 or 0
    sendOSC('/live/track/set/mute', trackNumber, value, connections)
    
    debugLog(string.format("Sent mute: %s to track %d on connection %d", 
        tostring(muteState), trackNumber, connectionIndex))
end

-- ===========================
-- BUTTON HANDLING
-- ===========================

-- Handle button press
local function onPress()
    -- Safety check: only process if track is mapped
    if not isTrackMapped() then
        debugLog("Button press ignored - track not mapped")
        return
    end
    
    local now = getMillis()
    
    -- Debounce check
    if now - lastPressTime < DEBOUNCE_TIME then
        return
    end
    
    lastPressTime = now
    isPressed = true
    pressStartTime = now
    
    -- Toggle mute state
    isMuted = not isMuted
    sendMute(isMuted)
    
    -- Update visual immediately
    updateVisual()
    
    debugLog("Button pressed - mute is now:", isMuted)
end

-- ===========================
-- UPDATE LOGIC
-- ===========================

-- Main update function
function update()
    -- Handle visual feedback timing
    if isPressed then
        local now = getMillis()
        if now - pressStartTime > VISUAL_FEEDBACK_TIME then
            isPressed = false
            updateVisual()
        end
    end
end

-- ===========================
-- VALUE CHANGE HANDLERS
-- ===========================

-- Handle button value changes
function onValueChanged(valueName)
    if valueName == "touch" then
        if self.values.touch then
            onPress()
        end
    elseif valueName == "x" then
        -- Handle button release for visual feedback
        if self.values.x == 0 and isPressed then
            isPressed = false
            updateVisual()
        end
    end
end

-- ===========================
-- OSC RECEIVE HANDLERS
-- ===========================

-- Handle incoming mute state from Ableton
function onReceiveOSC(message, connections)
    -- Only process mute messages
    if message[1] ~= '/live/track/get/mute' then
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
    
    -- Get the mute state (1 = muted, 0 = unmuted)
    local muteValue = arguments[2].value
    isMuted = (muteValue == 1)
    
    debugLog(string.format("Received mute state: %s for track %d", 
        tostring(isMuted), msgTrackNumber))
    
    -- Update visual
    updateVisual()
    
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
        isMuted = false
        isPressed = false
        updateVisual()
        debugLog("Track changed - reset mute button")
    elseif key == "track_unmapped" then
        -- Disable button when track is unmapped
        updateVisual()
        debugLog("Track unmapped - disabled mute button")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Set button type
    self.type = ControlType.BUTTON
    
    -- Initial state
    isMuted = false
    isPressed = false
    
    -- Initial visual
    updateVisual()
    
    -- Log initialization with version
    print("[" .. os.date("%H:%M:%S") .. "] Mute button initialized for parent: " .. 
        (self.parent and self.parent.name or "unknown") .. " (v" .. VERSION .. ")")
end

-- Initialize on script load
init()