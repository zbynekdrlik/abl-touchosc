-- Track Discovery Debug Script
-- Version: 1.0.0
-- Purpose: Find out exactly what tracks AbletonOSC sees

local VERSION = "1.0.0"
local discovered = false

-- Logging
local function log(msg)
    print(string.format("[TrackDebug %s] %s", VERSION, msg))
end

function init()
    log("Track Discovery Debug initialized")
    log("Tap to discover all tracks")
    self.color = Color(0.8, 0.8, 0.5, 1.0)
    
    -- Disable button's own OSC
    self.sendOSC = false
end

function onValueChanged(valueName)
    if (valueName == "x" and self.values.x == 1) or 
       (valueName == "touch" and self.values.touch == 1) then
        
        log("Starting discovery...")
        discovered = false
        
        -- First get total track count
        log("Querying total track count...")
        sendOSC("/live/song/get/num_tracks")
        
        -- Also try to get specific info
        sendOSC("/live/song/get/num_scenes")
        sendOSC("/live/song/get/num_return_tracks")  -- This might exist
        
        -- Try querying tracks 0-15 to see what exists
        for i = 0, 15 do
            sendOSC("/live/track/get/name", i)
        end
        
        self.color = Color(1, 1, 0, 1)  -- Yellow while testing
    end
end

function onReceiveOSC(message, connections)
    local path = message[1]
    
    if path == "/live/song/get/num_tracks" then
        if message[2] and message[2][1] then
            local count = message[2][1].value
            log(string.format("*** TOTAL TRACKS REPORTED: %d ***", count))
            discovered = true
        end
        return true
        
    elseif path == "/live/song/get/num_scenes" then
        if message[2] and message[2][1] then
            local count = message[2][1].value
            log(string.format("Scenes: %d", count))
        end
        return true
        
    elseif path == "/live/song/get/num_return_tracks" then
        if message[2] and message[2][1] then
            local count = message[2][1].value
            log(string.format("*** RETURN TRACKS: %d ***", count))
        end
        return true
        
    elseif path == "/live/track/get/name" then
        if message[2] and message[2][1] and message[2][2] then
            local index = message[2][1].value
            local name = message[2][2].value
            log(string.format("Track %d: \"%s\"", index, name))
            
            -- Check if this is a return track
            if string.match(name, "Return") or string.match(name, "Master") then
                log(string.format("  ^^^ SPECIAL TRACK FOUND! ^^^"))
            end
        end
        return true
        
    elseif path == "/live/error" then
        if message[2] and message[2][1] then
            local error = message[2][1].value
            -- Only log errors that aren't "out of range"
            if not string.match(error, "out of range") then
                log(string.format("Error: %s", error))
            end
        end
        return true
    end
    
    -- Color feedback
    if discovered then
        self.color = Color(0, 1, 0, 1)  -- Green when done
    end
    
    return false
end