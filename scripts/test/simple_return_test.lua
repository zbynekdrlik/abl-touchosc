-- Simple Return Track Test
-- Version: 1.0.0
-- Purpose: Direct test of return track control

local VERSION = "1.0.0"
local TRACK_INDEX = 6  -- Common index for first return track
local CONNECTION = 1   -- Try different values: 1-10

-- Logging
local function log(msg)
    print(string.format("[SimpleReturn %s] %s", VERSION, msg))
end

function init()
    log("Initialized - Assuming Return A at index " .. TRACK_INDEX)
    self.color = Color(0.5, 0.8, 1.0, 1.0)
end

function onValueChanged(valueName)
    if valueName == "x" then
        local value = self.values.x
        log(string.format("Sending volume %.3f to track %d on connection %d", 
            value, TRACK_INDEX, CONNECTION))
        
        -- Direct send without discovery
        local connections = {}
        for i = 1, 10 do connections[i] = (i == CONNECTION) end
        
        sendOSC("/live/track/set/volume", TRACK_INDEX, value, connections)
        
        -- Visual feedback
        self.color = Color(1, 1, 0, 1)  -- Yellow flash
    end
end

function update()
    -- Reset color
    if self.color.r == 1 and self.color.g == 1 then
        self.color = Color(0.5, 0.8, 1.0, 1.0)
    end
end