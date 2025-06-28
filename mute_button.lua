-- mute_button.lua
-- Version: 1.1.0
-- Mute button control script with multi-connection support

local scriptVersion = "1.1.0"
local debugMode = false

-- Logging helper
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
end

-- Helper to read configuration
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

-- Helper to extract track number from tag
local function extractTrackNumber(tag)
    if not tag then return nil end
    
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

-- Helper to send OSC with connection routing
local function sendOSCRouted(control, path, ...)
    local config = getConfiguration(control)
    if not config then
        log(control, "Cannot send OSC: configuration not found", false)
        return
    end
    
    -- Get parent's instance type
    local _, instance = extractTrackNumber(control.parent.tag)
    local connectionKey = "connection_" .. (instance or "band")
    local connectionNumber = tonumber(config[connectionKey])
    
    if not connectionNumber then
        log(control, "Connection number not found for " .. connectionKey, false)
        return
    end
    
    -- Create connection table
    local connectionTable = {}
    connectionTable[connectionNumber] = true
    
    log(control, "Sending " .. path .. " on connection " .. connectionNumber, true)
    sendOSC(path, {...}, connectionTable)
end

-- Handle OSC messages
function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    if path == '/live/track/get/mute' then
        -- Extract track number from parent tag
        local trackNumber, instance = extractTrackNumber(self.parent.tag)
        if not trackNumber then
            log(self, "No track number in parent tag", true)
            return
        end
        
        -- Check if this message is for our track
        if arguments[1] and arguments[1].value == trackNumber then
            -- Get configuration to check connection
            local config = getConfiguration(self)
            if config then
                local connectionKey = "connection_" .. (instance or "band")
                local expectedConnection = tonumber(config[connectionKey])
                
                -- Check if message came from expected connection
                if expectedConnection and connections[expectedConnection] then
                    -- Update button state (inverted: muted = off, unmuted = on)
                    local isMuted = arguments[2] and arguments[2].value
                    self.values.x = isMuted and 0 or 1
                    
                    log(self, "Track " .. trackNumber .. " mute state: " .. 
                        (isMuted and "MUTED" or "UNMUTED"), true)
                else
                    log(self, "Ignoring mute for track " .. trackNumber .. 
                        " from wrong connection", true)
                end
            end
        end
    end
end

-- Handle button press
function onValueChanged(key)
    if key == "x" then
        -- Only send if user pressed (not from OSC update)
        if self.values.touch then
            local trackNumber = extractTrackNumber(self.parent.tag)
            if trackNumber then
                -- Toggle mute state
                local muteState = self.values.x == 0 and 1 or 0
                log(self, "Sending mute " .. (muteState == 1 and "ON" or "OFF") .. 
                    " for track " .. trackNumber, false)
                sendOSCRouted(self, "/live/track/set/mute", trackNumber, muteState)
            end
        end
    end
end

-- Initialize the script
init()