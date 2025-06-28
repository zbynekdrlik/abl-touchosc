-- mute_button.lua
-- Version: 1.6.4
-- Simplified: React to x changes, send inverted value

local VERSION = "1.6.4"

-- State tracking
local ignoreNextChange = false

-- Logging
local function log(message)
    local context = "MUTE"
    if self.parent and self.parent.name then
        context = "MUTE(" .. self.parent.name .. ")"
    end
    
    root:notify("log_message", context .. ": " .. message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Get track number from parent
local function getTrackNumber()
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
    end
    return nil
end

-- Get expected connection index
local function getConnectionIndex()
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance then
            -- Find configuration
            local configObj = root:findByName("configuration", true)
            if not configObj or not configObj.values or not configObj.values.text then
                return 1
            end
            
            local configText = configObj.values.text
            local searchKey = "connection_" .. instance .. ":"
            
            -- Parse configuration
            for line in configText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$")  -- Trim
                if line:sub(1, #searchKey) == searchKey then
                    local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                    return tonumber(value) or 1
                end
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

-- Handle incoming OSC
function onReceiveOSC(message, connections)
    local arguments = message[2]
    
    if message[1] == '/live/track/get/mute' then
        local myTrackNumber = getTrackNumber()
        if not myTrackNumber then
            return false
        end
        
        -- Check if this is our track
        if arguments[1] and arguments[1].value == myTrackNumber then
            -- Check if message is from correct connection
            local expectedConnection = getConnectionIndex()
            if connections[expectedConnection] then
                -- Set flag to ignore the next value change
                ignoreNextChange = true
                
                -- Update button visual state
                if arguments[2].value then
                    self.values.x = 0  -- Muted = pressed
                else
                    self.values.x = 1  -- Unmuted = released
                end
                
                log("Received mute state: " .. (arguments[2].value and "MUTED" or "UNMUTED"))
            end
        end
    end
    
    return false
end

-- Handle value changes
function onValueChanged(key)
    if key == "x" then
        -- Skip if this was from OSC
        if ignoreNextChange then
            ignoreNextChange = false
            return
        end
        
        -- Only send if user is touching
        if self.values.touch then
            local trackNumber = getTrackNumber()
            if trackNumber then
                -- Send inverted x value as boolean
                -- x=0 (pressed) -> send true (mute on)
                -- x=1 (released) -> send false (mute off)
                local muteState = (self.values.x == 0)
                
                -- Send with connection routing
                local connectionIndex = getConnectionIndex()
                local connections = buildConnectionTable(connectionIndex)
                
                sendOSC("/live/track/set/mute", trackNumber, muteState, connections)
                log("Sent mute " .. (muteState and "ON" or "OFF") .. " for track " .. trackNumber)
            end
        end
    end
end

-- Initialize
log("Script v" .. VERSION .. " loaded")