-- mute_button.lua
-- Version: 1.2.0
-- Fixed: Script isolation, configuration reading, visual preservation

local scriptVersion = "1.2.0"
local debugMode = false

-- Logging helper (matches our newer pattern)
local function log(control, message, isDebug)
    if isDebug and not debugMode then return end
    
    local logControl = control.root:findByName("log_display", true)
    if logControl then
        notify(logControl, "log", "[mute_button] " .. message)
    else
        print("[mute_button] " .. message)
    end
end

-- Initialize on script load
function init()
    log(self, "Script version " .. scriptVersion .. " loaded")
    
    -- Log parent group info
    if self.parent and self.parent.tag then
        log(self, "Parent tag: " .. tostring(self.parent.tag))
    end
    
    -- Set initial text (preserve colors, only change text)
    self.values.text = "MUTE"
end

-- Helper to read configuration (self-contained, no external dependencies)
local function getConfiguration(control)
    local configControl = control.root:findByName("configuration", true)
    if not configControl then
        log(control, "Configuration control not found", false)
        return nil
    end
    
    local configText = configControl.values.text
    if not configText or configText == "" then
        log(control, "Configuration text is empty", false)
        return nil
    end
    
    local config = {}
    for line in configText:gmatch("[^\r\n]+") do
        local key, value = line:match("^(%w+):%s*(.+)$")
        if key and value then
            config[key] = value
        end
    end
    
    return config
end

-- Helper to extract track number and instance from tag
local function extractTrackInfo(tag)
    if not tag then return nil, nil end
    
    -- Handle new format "instance:track" (e.g., "band:39")
    local instance, track = tag:match("^(%w+):(%d+)$")
    if track then
        return tonumber(track), instance
    end
    
    -- Handle old format (just number)
    local trackNum = tonumber(tag)
    if trackNum then
        return trackNum, nil
    end
    
    return nil, nil
end

-- Helper to get connection index for instance
local function getConnectionForInstance(control, instance)
    local config = getConfiguration(control)
    if not config then return nil end
    
    local connectionKey = "connection_" .. (instance or "band")
    return tonumber(config[connectionKey])
end

-- Helper to send OSC with connection routing
local function sendOSCRouted(control, path, ...)
    local trackNumber, instance = extractTrackInfo(control.parent.tag)
    if not trackNumber then
        log(control, "Cannot send OSC: no track number", false)
        return
    end
    
    local connectionNumber = getConnectionForInstance(control, instance)
    if not connectionNumber then
        log(control, "Cannot send OSC: connection not found for " .. (instance or "band"), false)
        return
    end
    
    -- Create connection table
    local connectionTable = {}
    connectionTable[connectionNumber] = true
    
    log(control, "Sending " .. path .. " on connection " .. connectionNumber, true)
    sendOSC(path, {...}, connectionTable)
end

-- State tracking
local currentMuteState = false
local lastPressTime = 0
local DEBOUNCE_TIME = 50  -- ms

-- Handle OSC messages
function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    if path == '/live/track/get/mute' then
        -- Extract track info from parent tag
        local trackNumber, instance = extractTrackInfo(self.parent.tag)
        if not trackNumber then
            log(self, "No track number in parent tag", true)
            return
        end
        
        -- Check if this message is for our track
        if arguments[1] and arguments[1].value == trackNumber then
            -- Get expected connection
            local expectedConnection = getConnectionForInstance(self, instance)
            
            -- Check if message came from expected connection
            if expectedConnection and connections[expectedConnection] then
                -- Update button state and text
                local isMuted = arguments[2] and arguments[2].value == 1
                currentMuteState = isMuted
                
                -- Update visual state (x=0 when muted/pressed, x=1 when unmuted)
                self.values.x = isMuted and 0 or 1
                
                -- Update text only (preserve colors)
                self.values.text = isMuted and "MUTED" or "MUTE"
                
                log(self, "Track " .. trackNumber .. " mute state: " .. 
                    (isMuted and "MUTED" or "UNMUTED"), true)
            else
                log(self, "Ignoring mute for track " .. trackNumber .. 
                    " from wrong connection", true)
            end
        end
    end
end

-- Handle button press
function onValueChanged(key)
    if key == "touch" and self.values.touch then
        -- Debounce check
        local now = getMillis()
        if now - lastPressTime < DEBOUNCE_TIME then
            return
        end
        lastPressTime = now
        
        local trackNumber, instance = extractTrackInfo(self.parent.tag)
        if trackNumber then
            -- Toggle mute state
            local newMuteState = not currentMuteState
            local muteValue = newMuteState and 1 or 0
            
            log(self, "Sending mute " .. (newMuteState and "ON" or "OFF") .. 
                " for track " .. trackNumber, false)
            
            sendOSCRouted(self, "/live/track/set/mute", trackNumber, muteValue)
            
            -- Optimistically update text (will be confirmed by OSC response)
            self.values.text = newMuteState and "MUTED" or "MUTE"
        end
    end
end

-- Handle notifications from parent
function onReceiveNotify(key, value)
    if key == "track_changed" then
        -- Reset state when track changes
        currentMuteState = false
        self.values.x = 1
        self.values.text = "MUTE"
        log(self, "Track changed - reset mute button", true)
    elseif key == "track_unmapped" then
        -- Show disabled state when unmapped
        self.values.text = "---"
        log(self, "Track unmapped - disabled mute button", true)
    end
end

-- Initialize the script
init()