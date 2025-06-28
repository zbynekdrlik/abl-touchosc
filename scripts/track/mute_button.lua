-- mute_button.lua
-- Version: 1.4.5
-- Fixed: Prevent double-triggering by tracking OSC updates

local VERSION = "1.4.5"
local debugMode = false

-- State tracking
local currentMuteState = false
local lastPressTime = 0
local DEBOUNCE_TIME = 50  -- ms
local updatingFromOSC = false  -- Track when updating from OSC to prevent loops

-- Logging (copied from working fader)
local function log(message)
    -- Get parent name for context
    local context = "MUTE"
    if self.parent and self.parent.name then
        context = "MUTE(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development/debugging
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Debug logging
local function debugLog(message)
    if debugMode then
        log("[DEBUG] " .. message)
    end
end

-- Get connection configuration (copied from fader)
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

-- Get track number from parent group
local function getTrackNumber()
    -- Parent stores combined tag like "band:39"
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

-- Send OSC with connection routing
local function sendOSCRouted(path, track, value)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    -- CRITICAL: Ensure track is sent as number (integer/float in OSC)
    sendOSC(path, tonumber(track), value, connections)
end

-- Handle OSC messages
function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    if path == '/live/track/get/mute' then
        local myTrackNumber = getTrackNumber()
        if not myTrackNumber then
            return false
        end
        
        -- Check if this message is for our track
        -- Handle both FLOAT and STRING track numbers from Ableton
        local msgTrackNumber = nil
        if arguments[1] then
            if type(arguments[1].value) == "number" then
                msgTrackNumber = arguments[1].value
            elseif type(arguments[1].value) == "string" then
                msgTrackNumber = tonumber(arguments[1].value)
            end
        end
        
        if msgTrackNumber == myTrackNumber then
            -- Check if message came from expected connection
            local expectedConnection = getConnectionIndex()
            if connections[expectedConnection] then
                -- Update button state from Ableton's response
                local isMuted = arguments[2] and arguments[2].value
                currentMuteState = isMuted
                
                -- Set flag to prevent triggering onValueChanged
                updatingFromOSC = true
                
                -- FIXED: Correct visual state mapping
                -- When muted (true) → button pressed (x=0)
                -- When unmuted (false) → button released (x=1)
                if isMuted then
                    self.values.x = 0
                else
                    self.values.x = 1
                end
                
                -- Clear flag after a short delay
                self:after(10, function()
                    updatingFromOSC = false
                end)
                
                log("Received mute state for track " .. myTrackNumber .. ": " .. 
                    (isMuted and "MUTED" or "UNMUTED"))
            else
                debugLog("Ignoring mute for track " .. myTrackNumber .. 
                    " from wrong connection")
            end
        end
    end
    
    return false
end

-- Handle button press
function onValueChanged(key)
    -- Ignore changes triggered by OSC updates
    if updatingFromOSC then
        debugLog("Ignoring value change from OSC update")
        return
    end
    
    -- Safety check: only process if track is mapped
    if not isTrackMapped() then
        return
    end
    
    -- Only process touch events (not x value changes)
    if key == "touch" and self.values.touch then
        -- Debounce check
        local now = getMillis()
        if now - lastPressTime < DEBOUNCE_TIME then
            return
        end
        lastPressTime = now
        
        local trackNumber = getTrackNumber()
        if trackNumber then
            -- Toggle mute state
            local newMuteState = not currentMuteState
            currentMuteState = newMuteState  -- Update state immediately
            
            log("Sending mute " .. (newMuteState and "ON" or "OFF") .. 
                " for track " .. trackNumber)
            
            -- Send as boolean with track as number
            sendOSCRouted("/live/track/set/mute", trackNumber, newMuteState)
            
            -- Don't update visual state here - wait for OSC confirmation
        end
    end
end

-- Handle notifications from parent
function onReceiveNotify(key, value)
    if key == "track_changed" then
        -- Reset state when track changes
        currentMuteState = false
        updatingFromOSC = true  -- Prevent triggering
        self.values.x = 1  -- Start unmuted (button released)
        self:after(10, function()
            updatingFromOSC = false
        end)
        debugLog("Track changed - reset mute button")
    elseif key == "track_unmapped" then
        -- Button will be disabled by parent
        debugLog("Track unmapped - mute button disabled")
    end
end

-- Initialize
function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    -- Set initial visual state
    self.values.x = 1  -- Start unmuted (button released)
end

-- Call init directly (like fader does)
init()