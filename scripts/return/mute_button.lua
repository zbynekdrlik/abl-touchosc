-- TouchOSC Return Track Mute Button Script
-- Version: 1.0.0

-- Version constant
local VERSION = "1.0.0"

-- State
local muteState = false

-- Centralized logging
local function log(message)
    local context = "RETURN_MUTE"
    if self.parent and self.parent.name then
        context = "RETURN_MUTE(" .. self.parent.name .. ")"
    end
    
    root:notify("log_message", context .. ": " .. message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Get connection configuration
local function getConnectionIndex()
    if self.parent and self.parent.tag then
        local configObj = root:findByName("configuration", true)
        if not configObj or not configObj.values or not configObj.values.text then
            return 1
        end
        
        local configText = configObj.values.text
        local searchKey = "connection_return:"
        
        for line in configText:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line:sub(1, #searchKey) == searchKey then
                local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                return tonumber(value) or 1
            end
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

-- Get return track number
local function getReturnNumber()
    if self.parent and self.parent.tag then
        local instance, returnNum = self.parent.tag:match("(%w+):(%d+)")
        if returnNum then
            return tonumber(returnNum)
        end
    end
    return nil
end

-- Check if return track is mapped
local function isReturnMapped()
    if not self.parent or not self.parent.tag then
        return false
    end
    local instance, returnNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and returnNum ~= nil
end

-- Send OSC with routing
local function sendOSCRouted(path, returnNum, value)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    sendOSC(path, returnNum, value, connections)
end

-- Update button visual state
local function updateButtonState()
    if muteState then
        -- Muted - bright color
        self.color = Color(1, 0.3, 0.3, 1)  -- Red
    else
        -- Unmuted - dim color
        self.color = Color(0.3, 0.3, 0.3, 1)  -- Dark gray
    end
end

-- Handle incoming OSC
function onReceiveOSC(message, connections)
    local myReturnNumber = getReturnNumber()
    if not myReturnNumber then
        return false
    end
    
    local path = message[1]
    
    -- Check if this is mute data for our return track
    if path == '/live/return/get/mute' then
        local arguments = message[2]
        if arguments and arguments[1] and arguments[1].value == myReturnNumber then
            muteState = arguments[2].value == 1
            updateButtonState()
            self.values.x = muteState and 1 or 0
            log("Mute state updated: " .. (muteState and "ON" or "OFF"))
        end
    end
    
    return false
end

-- Handle button press
function onValueChanged()
    if not isReturnMapped() then
        return
    end
    
    if self.values.x == 1 then  -- Button pressed
        -- Toggle mute state
        muteState = not muteState
        updateButtonState()
        
        -- Send OSC
        local returnNumber = getReturnNumber()
        if returnNumber then
            sendOSCRouted('/live/return/set/mute', returnNumber, muteState and 1 or 0)
            log("Mute toggled: " .. (muteState and "ON" or "OFF"))
        end
    end
end

-- Handle notifications
function onReceiveNotify(key, value)
    if key == "return_changed" then
        muteState = false
        updateButtonState()
        self.values.x = 0
        log("Return track changed - mute state reset")
    elseif key == "return_unmapped" then
        muteState = false
        updateButtonState()
        self.values.x = 0
    end
end

-- Initialization
function init()
    log("Return mute button v" .. VERSION .. " loaded")
    updateButtonState()
end

init()