-- Connection Test Script
-- Version: 1.0.0
-- Purpose: Test which connection index works with Ableton

local VERSION = "1.0.0"
local currentConnection = 1
local testStarted = false

-- Logging
local function log(message)
    local timestamp = os.date("%H:%M:%S")
    local fullMessage = string.format("[ConnTest v%s] %s: %s", VERSION, timestamp, message)
    print(fullMessage)
    root:notify("log_message", fullMessage)
end

-- Create connection table
local function createConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Initialize
function init()
    log("Connection Test Script initialized")
    log("Tap to test connections 1-10")
    self.color = Color(0.8, 0.8, 0.8, 1.0)
    
    -- Set label if button has one
    if self.values and type(self.values) == "table" then
        if self.type == ControlType.LABEL then
            self.values.text = "Tap to Test"
        end
    end
end

-- Test next connection
function testConnection(index)
    local connections = createConnectionTable(index)
    log(string.format("Testing connection %d...", index))
    
    -- Simple ping test
    sendOSC("/live/test", connections)
    -- Also try get song tempo as a simple query
    sendOSC("/live/song/get/tempo", connections)
    
    -- Visual feedback
    self.color = Color(index/10, 1-index/10, 0.5, 1.0)
end

-- Handle taps
function onValueChanged(valueName)
    if valueName == "x" or valueName == "touch" then
        if (valueName == "x" and self.values.x == 1) or 
           (valueName == "touch" and self.values.touch == 1) then
            
            if not testStarted then
                testStarted = true
                log("Starting connection test sequence...")
                currentConnection = 1
            end
            
            testConnection(currentConnection)
            
            currentConnection = currentConnection + 1
            if currentConnection > 10 then
                currentConnection = 1
                log("Completed test cycle. Starting over...")
            end
        end
    end
end

-- Check for responses
function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Log which connection responded
    local connIndex = "unknown"
    if connections then
        for i = 1, 10 do
            if connections[i] then
                connIndex = tostring(i)
                break
            end
        end
    end
    
    log(string.format("*** RESPONSE on connection %s: %s", connIndex, path))
    
    -- Green flash for success
    self.color = Color(0, 1, 0, 1)
    
    return false  -- Let other controls also receive
end