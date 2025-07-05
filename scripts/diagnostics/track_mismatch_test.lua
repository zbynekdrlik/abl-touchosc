-- TouchOSC Listener Diagnostic Script
-- Version: 1.1.0
-- Purpose: Test AbletonOSC listener behavior

local VERSION = "1.1.0"

-- Configuration
local connectionIndex = 1  -- Adjust if using multiple connections

-- Build connection table
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Log helper
local function log(message)
    print("[" .. os.date("%H:%M:%S") .. "] LISTENER_TEST: " .. message)
end

-- State tracking
local testPhase = "idle"
local maxTracks = 0
local currentTestTrack = 0
local volumeResponses = {}
local activeListeners = {}

function init()
    log("Script v" .. VERSION .. " loaded")
    log("This test will check for cross-wired listeners")
    self.children.status.values.text = "Press to test listeners"
    self.children.status.color = Color.WHITE
end

function onValueChanged(key)
    if key == "x" and self.values.x == 1 then
        if testPhase == "idle" then
            startTest()
        elseif testPhase == "cleanup" then
            cleanupListeners()
        end
    end
end

function startTest()
    log("=== STARTING LISTENER TEST ===")
    testPhase = "get_count"
    self.children.status.values.text = "Getting track count..."
    self.children.status.color = Color.YELLOW
    
    -- Reset state
    volumeResponses = {}
    activeListeners = {}
    currentTestTrack = 0
    
    -- Get track count
    local connections = buildConnectionTable(connectionIndex)
    sendOSC('/live/song/get/num_tracks', connections)
end

function setupListeners()
    testPhase = "setup_listeners"
    self.children.status.values.text = "Setting up listeners..."
    
    local connections = buildConnectionTable(connectionIndex)
    
    -- Set up volume listeners for ALL tracks
    for i = 0, maxTracks - 1 do
        sendOSC('/live/track/start_listen/volume', i, connections)
        activeListeners[i] = true
        log("Started listener on track " .. i)
    end
    
    -- Wait a bit then start testing
    runAfter(function()
        testPhase = "testing"
        testNextTrack()
    end, 1.0)
end

function testNextTrack()
    if currentTestTrack >= maxTracks then
        showResults()
        return
    end
    
    self.children.status.values.text = "Testing track " .. currentTestTrack .. "..."
    
    -- Clear previous responses
    volumeResponses = {}
    
    -- Send a unique volume to this track
    local testVolume = 0.5 + (currentTestTrack * 0.02)
    local connections = buildConnectionTable(connectionIndex)
    
    log("Sending volume " .. string.format("%.3f", testVolume) .. " to track " .. currentTestTrack)
    sendOSC('/live/track/set/volume', currentTestTrack, testVolume, connections)
    
    -- Wait for responses then check
    runAfter(function()
        checkResponses(currentTestTrack, testVolume)
    end, 0.3)
end

function checkResponses(sentTrack, sentVolume)
    log("Responses for track " .. sentTrack .. ":")
    
    local respondingTracks = {}
    for track, volume in pairs(volumeResponses) do
        -- Check if volume matches (within small tolerance)
        if math.abs(volume - sentVolume) < 0.001 then
            table.insert(respondingTracks, track)
            log("  - Track " .. track .. " responded with matching volume")
        end
    end
    
    if #respondingTracks == 0 then
        log("  - NO RESPONSES!")
    elseif #respondingTracks == 1 and respondingTracks[1] == sentTrack then
        log("  - Correct response only")
    else
        log("  - CROSS-WIRED LISTENERS DETECTED!")
    end
    
    -- Move to next track
    currentTestTrack = currentTestTrack + 1
    testNextTrack()
end

function showResults()
    testPhase = "cleanup"
    self.children.status.values.text = "Test complete - press to cleanup"
    self.children.status.color = Color.CYAN
    
    log("=== TEST COMPLETE ===")
    log("Check the log for cross-wired listeners")
    log("Press button again to stop all listeners")
end

function cleanupListeners()
    testPhase = "idle"
    self.children.status.values.text = "Cleaning up..."
    self.children.status.color = Color.YELLOW
    
    local connections = buildConnectionTable(connectionIndex)
    
    -- Stop all listeners
    for track, _ in pairs(activeListeners) do
        sendOSC('/live/track/stop_listen/volume', track, connections)
    end
    
    activeListeners = {}
    
    self.children.status.values.text = "Test complete"
    self.children.status.color = Color.GREEN
    
    log("All listeners stopped")
end

function onReceiveOSC(message, connections)
    local path = message[1]
    local args = message[2]
    
    -- Track count response
    if path == '/live/song/get/num_tracks' then
        maxTracks = args[1].value
        log("Ableton has " .. maxTracks .. " tracks")
        
        -- Start setting up listeners
        setupListeners()
        return
    end
    
    -- Volume response during testing
    if path == '/live/track/get/volume' and testPhase == "testing" then
        local trackNum = args[1].value
        local volume = args[2].value
        
        -- Store this response
        volumeResponses[trackNum] = volume
    end
end

init()
