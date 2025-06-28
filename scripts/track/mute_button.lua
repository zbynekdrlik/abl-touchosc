-- mute_button.lua
-- Version: 1.5.2
-- Fixed: Prevent double-toggle with proper state management

local VERSION = "1.5.2"
local debugMode = false

-- State tracking
local currentMuteState = false
local buttonPressedByUser = false
local ignoreStateChange = false

-- Logging
local function log(message)
    local context = "MUTE"
    if self.parent and self.parent.name then
        context = "MUTE(" .. self.parent.name .. ")"
    end
    
    root:notify("log_message", context .. ": " .. message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Get connection configuration
local function getConnectionIndex()
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance then
            local configObj = root:findByName("configuration", true)
            if not configObj or not configObj.values or not configObj.values.text then
                return 1
            end
            
            local configText = configObj.values.text
            local searchKey = "connection_" .. instance .. ":"
            
            for line in configText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$")
                if line:sub(1, #searchKey) == searchKey then
                    local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                    return tonumber(value) or 1
                end
            end
            
            return 1
        end
    end
    return 1
end

-- Build connection table
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Get track number
local function getTrackNumber()
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
    end
    return nil
end

-- Send OSC with routing
local function sendMute(trackNumber, muteState)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    sendOSC("/live/track/set/mute", trackNumber, muteState, connections)
    log("Sent mute " .. (muteState and "ON" or "OFF") .. " for track " .. trackNumber)
end

-- Handle OSC messages
function onReceiveOSC(message, connections)
    local arguments = message[2]
    
    if message[1] == '/live/track/get/mute' then
        local myTrackNumber = getTrackNumber()
        if not myTrackNumber then
            return false
        end
        
        if arguments[1] and arguments[1].value == myTrackNumber then
            -- Get expected connection
            local expectedConnection = getConnectionIndex()
            if connections[expectedConnection] then
                -- Update state
                currentMuteState = arguments[2] and arguments[2].value == true
                
                -- Set flag to ignore this change
                ignoreStateChange = true
                
                -- Update visual
                if currentMuteState then
                    self.values.x = 0  -- Muted = pressed
                else
                    self.values.x = 1  -- Unmuted = released
                end
                
                log("Received mute state: " .. (currentMuteState and "MUTED" or "UNMUTED"))
            end
        end
    end
    
    return false
end

-- Handle value changes
function onValueChanged(key)
    if key == "x" then
        -- Check if this is from OSC update
        if ignoreStateChange then
            ignoreStateChange = false
            return
        end
        
        -- Check if user is touching the button
        if self.values.touch then
            buttonPressedByUser = true
        end
    elseif key == "touch" then
        -- User pressed the button
        if self.values.touch and buttonPressedByUser then
            buttonPressedByUser = false
            
            local trackNumber = getTrackNumber()
            if trackNumber then
                -- Toggle mute state
                local newMuteState = not currentMuteState
                currentMuteState = newMuteState
                sendMute(trackNumber, newMuteState)
            end
        end
    end
end

-- Initialize
function init()
    log("Script v" .. VERSION .. " loaded")
    
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    -- Set initial state
    self.values.x = 1  -- Start unmuted
end

init()