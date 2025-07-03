-- Return Track Test Fader Script
-- Version: 1.0.1
-- Purpose: Test control of Return Track A with extensive logging

local VERSION = "1.0.1"
local RETURN_TRACK_A_INDEX = nil  -- Will be discovered
local CONNECTION_INDEX = 1  -- Adjust based on your setup
local IS_QUERYING = false
local QUERY_TIMEOUT = 2.0  -- seconds
local lastQueryTime = 0

-- Extensive logging function
local function log(message)
    local timestamp = os.date("%H:%M:%S")
    local fullMessage = string.format("[ReturnTest v%s] %s: %s", VERSION, timestamp, message)
    print(fullMessage)
    
    -- Also send to document script if available
    if root then
        root:notify("log_message", fullMessage)
    end
end

-- Create connection table for OSC routing
local function createConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Send OSC with routing
local function sendOSCRouted(path, ...)
    local connections = createConnectionTable(CONNECTION_INDEX)
    log(string.format("Sending OSC: %s (connection %d)", path, CONNECTION_INDEX))
    sendOSC(path, ..., connections)
end

-- Initialize the fader
function init()
    log("Return Track Test Fader initialized")
    log("Script version " .. VERSION .. " loaded")
    
    -- Debug: Check which connection to use
    local configObj = root:findByName("configuration", true)
    if configObj and configObj.values and configObj.values.text then
        log("Found configuration object")
        -- Try to parse connection info
        local configText = configObj.values.text
        for line in configText:gmatch("[^\r\n]+") do
            if string.match(line, "connection") then
                log("Config line: " .. line)
            end
        end
    else
        log("WARNING: No configuration object found - using default connection 1")
    end
    
    -- Set initial appearance
    self.color = Color(0.5, 0.8, 1.0, 1.0)  -- Light blue for return tracks
    
    -- Debug: Log self info
    log(string.format("Control name: %s, type: %s", self.name or "unknown", tostring(self.type)))
    
    -- Start discovery process
    log("Starting return track discovery...")
    log(string.format("Using connection index: %d", CONNECTION_INDEX))
    
    -- Small delay before starting discovery
    self.discoverDelay = os.clock() + 0.5
end

-- Discover Return Track A index
function discoverReturnTrackA()
    IS_QUERYING = true
    lastQueryTime = os.clock()
    
    -- First, get the total number of tracks
    log("Querying total track count...")
    sendOSCRouted("/live/song/get/num_tracks")
end

-- Handle fader value changes
function onValueChanged(valueName)
    if valueName == "x" then
        local value = self.values.x
        log(string.format("Fader moved to: %.3f", value))
        
        if RETURN_TRACK_A_INDEX then
            -- Send volume change to return track A
            log(string.format("Setting Return Track A (index %d) volume to %.3f", 
                RETURN_TRACK_A_INDEX, value))
            sendOSCRouted("/live/track/set/volume", RETURN_TRACK_A_INDEX, value)
            
            -- Visual feedback
            self.color = Color(1.0, 1.0, 0.0, 1.0)  -- Yellow when active
        else
            log("WARNING: Return Track A index not yet discovered!")
            self.color = Color(1.0, 0.0, 0.0, 1.0)  -- Red for error
        end
    elseif valueName == "touch" then
        -- Double-tap to retry discovery
        if self.values.touch == 1 then
            self.lastTouchTime = self.lastTouchTime or 0
            local now = os.clock()
            if now - self.lastTouchTime < 0.5 then
                log("Double-tap detected - retrying discovery...")
                RETURN_TRACK_A_INDEX = nil
                IS_QUERYING = false
                discoverReturnTrackA()
            end
            self.lastTouchTime = now
        end
    end
end

-- Handle OSC responses
function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Log all received messages for debugging
    log(string.format("Received OSC: %s (from connection %s)", path, tostring(connections)))
    
    -- Debug: Log message structure
    if message[2] and message[2][1] then
        log(string.format("  First value: %s", tostring(message[2][1].value)))
    end
    
    if path == "/live/song/get/num_tracks" then
        local totalTracks = message[2][1].value
        log(string.format("Total tracks in Live set: %d", totalTracks))
        
        -- Now discover each track to find returns
        log("Discovering track types...")
        for i = 0, totalTracks - 1 do
            sendOSCRouted("/live/track/get/name", i)
        end
        return true
        
    elseif path == "/live/track/get/name" then
        local trackIndex = message[2][1].value
        local trackName = message[2][2].value
        
        log(string.format("Track %d: '%s'", trackIndex, trackName))
        
        -- Check if this is Return Track A
        if string.match(trackName, "Return") or string.match(trackName, "A%-Return") then
            if not RETURN_TRACK_A_INDEX then
                RETURN_TRACK_A_INDEX = trackIndex
                log(string.format("*** FOUND RETURN TRACK A at index %d ***", trackIndex))
                
                -- Update visual
                self.color = Color(0.0, 1.0, 0.0, 1.0)  -- Green for success
                
                -- Update label
                if self.children and self.children.label then
                    self.children.label.values.text = string.format("Return A [%d]", trackIndex)
                end
                
                -- Get initial volume
                log("Getting current volume...")
                sendOSCRouted("/live/track/get/volume", RETURN_TRACK_A_INDEX)
                
                -- Subscribe to volume changes
                log("Starting volume observation...")
                sendOSCRouted("/live/track/start_listen/volume", RETURN_TRACK_A_INDEX)
                
                IS_QUERYING = false
            end
        end
        return true
        
    elseif path == "/live/track/get/volume" then
        if message[2] and message[2][1] and message[2][2] then
            local trackIndex = message[2][1].value
            local volume = message[2][2].value
            
            if trackIndex == RETURN_TRACK_A_INDEX then
                log(string.format("Return Track A current volume: %.3f", volume))
                self.values.x = volume
            end
        end
        return true
        
    elseif path == "/live/track/volume" then
        -- Volume update from observation
        if message[2] and message[2][1] and message[2][2] then
            local trackIndex = message[2][1].value
            local volume = message[2][2].value
            
            if trackIndex == RETURN_TRACK_A_INDEX then
                log(string.format("Return Track A volume changed in Live: %.3f", volume))
                self.values.x = volume
            end
        end
        return true
    end
    
    return false
end

-- Update function for visual feedback and timeout
function update()
    -- Delayed discovery start
    if self.discoverDelay and os.clock() >= self.discoverDelay then
        self.discoverDelay = nil
        discoverReturnTrackA()
    end
    
    -- Reset color after visual feedback
    if self.color.r == 1.0 and self.color.g == 1.0 and self.color.b == 0.0 then
        -- Yellow (active) - reset after a moment
        self.color = Color(0.5, 0.8, 1.0, 1.0)  -- Back to light blue
    end
    
    -- Check for query timeout
    if IS_QUERYING and (os.clock() - lastQueryTime) > QUERY_TIMEOUT then
        log("WARNING: Query timeout - no response from Ableton")
        log("Possible issues:")
        log("1. Check OSC receive patterns are set in TouchOSC editor")
        log("2. Verify connection index (current: " .. CONNECTION_INDEX .. ")")
        log("3. Ensure Ableton is running with AbletonOSC")
        IS_QUERYING = false
        self.color = Color(0.8, 0.0, 0.0, 1.0)  -- Dark red for timeout
    end
end

-- Handle notifications
function onReceiveNotify(action, value)
    if action == "refresh_discovery" then
        log("Refreshing return track discovery...")
        RETURN_TRACK_A_INDEX = nil
        discoverReturnTrackA()
    elseif action == "set_connection" then
        CONNECTION_INDEX = value
        log(string.format("Connection index changed to: %d", CONNECTION_INDEX))
    elseif action == "test_direct" then
        -- Test mode: try direct control without discovery
        local testIndex = value or 6  -- Assume return A is at index 6
        log(string.format("TEST MODE: Trying direct control of track %d", testIndex))
        RETURN_TRACK_A_INDEX = testIndex
        self.color = Color(1.0, 0.5, 0.0, 1.0)  -- Orange for test mode
    end
end

-- Log initialization complete
log("Script loaded - waiting for Ableton connection...")
log("TIP: Double-tap fader to retry discovery")
log("TIP: If no response, check:")
log("  1. OSC receive patterns in TouchOSC editor")
log("  2. Connection settings in configuration")
log("  3. AbletonOSC is running in Ableton")