-- mute_button.lua
-- Version: 2.0.0
-- Performance optimized - removed centralized logging, added DEBUG guards
-- Fixed: Parse parent tag for track info instead of accessing properties
-- Added: Return track support using parent's trackType

local VERSION = "2.0.0"

-- Debug mode (set to 1 for debug output)
local DEBUG = 0

-- Debug logging
local function debug(message)
    if DEBUG == 0 then return end
    
    local context = "MUTE"
    if self.parent and self.parent.name then
        context = "MUTE(" .. self.parent.name .. ")"
    end
    
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Get track number and type from parent group
local function getTrackInfo()
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if self.parent and self.parent.tag then
        local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            return tonumber(trackNum), trackType
        end
    end
    return nil, nil
end

-- Get expected connection index
local function getConnectionIndex()
    if self.parent and self.parent.tag then
        local instance = self.parent.tag:match("^(%w+):")
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
    local path = message[1]
    local arguments = message[2]
    
    -- Get track info from parent
    local trackNumber, trackType = getTrackInfo()
    if not trackNumber then
        return false
    end
    
    -- Check if this is a mute message for the correct track type
    local isMuteMessage = false
    if trackType == "return" and path == '/live/return/get/mute' then
        isMuteMessage = true
    elseif (trackType == "regular" or trackType == "track") and path == '/live/track/get/mute' then
        isMuteMessage = true
    end
    
    if not isMuteMessage then
        return false
    end
    
    -- Check if this is our track
    if arguments[1] and arguments[1].value == trackNumber then
        -- Check if message is from correct connection
        local expectedConnection = getConnectionIndex()
        if connections[expectedConnection] then
            -- Update button visual state
            if arguments[2].value then
                self.values.x = 0  -- Muted = pressed
            else
                self.values.x = 1  -- Unmuted = released
            end
            
            if DEBUG == 1 then
                debug("Received mute state: " .. (arguments[2].value and "MUTED" or "UNMUTED"))
            end
        end
    end
    
    return false
end

-- Handle value changes
function onValueChanged(key)
    if key == "x" then
        local trackNumber, trackType = getTrackInfo()
        if trackNumber then
            -- Send inverted x value as boolean
            -- x=0 (pressed) -> send true (mute on)
            -- x=1 (released) -> send false (mute off)
            local muteState = (self.values.x == 0)
            
            -- Send with connection routing to correct path
            local connectionIndex = getConnectionIndex()
            local connections = buildConnectionTable(connectionIndex)
            local path = trackType == "return" and "/live/return/set/mute" or "/live/track/set/mute"
            
            sendOSC(path, trackNumber, muteState, connections)
            
            if DEBUG == 1 then
                debug("Sent mute " .. (muteState and "ON" or "OFF") .. " for " .. trackType .. " track " .. trackNumber)
            end
        end
    end
end

-- Initialize
print("[" .. os.date("%H:%M:%S") .. "] MUTE: Script v" .. VERSION .. " loaded")