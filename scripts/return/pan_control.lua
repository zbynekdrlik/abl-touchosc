-- TouchOSC Return Track Pan Control Script
-- Version: 1.0.0

-- Version constant
local VERSION = "1.0.0"

-- State
local touched = false
local last_osc_value = 0
local synced = true
local last_touch_release = 0
local sync_delay = 1000

-- Centralized logging
local function log(message)
    local context = "RETURN_PAN"
    if self.parent and self.parent.name then
        context = "RETURN_PAN(" .. self.parent.name .. ")"
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

-- Convert TouchOSC position (0-1) to Ableton pan value (-1 to 1)
local function positionToPan(pos)
    return (pos * 2) - 1
end

-- Convert Ableton pan value (-1 to 1) to TouchOSC position (0-1)
local function panToPosition(pan)
    return (pan + 1) / 2
end

-- Handle incoming OSC
function onReceiveOSC(message, connections)
    local myReturnNumber = getReturnNumber()
    if not myReturnNumber then
        return false
    end
    
    local path = message[1]
    
    -- Check if this is pan data for our return track
    if path == '/live/return/get/panning' then
        local arguments = message[2]
        if arguments and arguments[1] and arguments[1].value == myReturnNumber then
            local pan_value = arguments[2].value
            last_osc_value = panToPosition(pan_value)
            
            -- Only update if not touching
            if not self.values.touch then
                if synced then
                    self.values.x = last_osc_value
                    log(string.format("Pan updated: %.0f%%", pan_value * 100))
                end
            else
                touched = true
            end
        end
    end
    
    return false
end

-- Update function for sync delay
function update()
    if touched and not self.values.touch then
        last_touch_release = getMillis()
        touched = false
        synced = false
    end
    
    if not synced and not self.values.touch then
        local now = getMillis()
        if (now - last_touch_release > sync_delay) then
            self.values.x = last_osc_value
            synced = true
        end
    end
    
    if self.values.touch and not synced then
        synced = true
    end
end

-- Handle value changes
function onValueChanged()
    if not isReturnMapped() then
        return
    end
    
    local position = self.values.x
    local pan_value = positionToPan(position)
    
    -- Send OSC
    local returnNumber = getReturnNumber()
    if returnNumber then
        sendOSCRouted('/live/return/set/panning', returnNumber, pan_value)
        
        if self.values.touch then
            log(string.format("Pan changed: %s%.0f%%", pan_value >= 0 and "+" or "", pan_value * 100))
        end
    end
end

-- Handle notifications
function onReceiveNotify(key, value)
    if key == "return_changed" then
        touched = false
        synced = true
        log("Return track changed - state reset")
    elseif key == "return_unmapped" then
        self.values.x = 0.5  -- Center position
    end
end

-- Initialization
function init()
    log("Return pan control v" .. VERSION .. " loaded")
    self.values.x = 0.5  -- Start centered
end

init()