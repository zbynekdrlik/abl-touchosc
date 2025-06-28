-- mute_button.lua
-- Version: 1.6.2
-- Added: Multi-connection support for receiving

local VERSION = "1.6.2"

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

-- Initialize
log("Script v" .. VERSION .. " loaded (receive with multi-connection)")