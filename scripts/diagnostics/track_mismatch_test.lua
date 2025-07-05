-- TouchOSC Track Mismatch Diagnostic Script
-- Version: 1.0.0
-- Purpose: Diagnose why track 8 sends respond as track 10

local VERSION = "1.0.0"

-- Connection configuration
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
    print("[" .. os.date("%H:%M:%S") .. "] TRACK_DIAG: " .. message)
end

-- State tracking
local trackNames = {}
local volumeRequests = {}
local volumeResponses = {}
local testInProgress = false
local currentTestTrack = 0
local maxTracks = 0

function init()
    log("Script v" .. VERSION .. " loaded")
    log("Press button to start diagnostic")
    self.children.status.values.text = "Ready to test"
    self.children.status.color = Color.WHITE
end

function onValueChanged(key)
    if key == "x" and self.values.x == 1 then
        -- Button pressed, start test
        startDiagnostic()
    end
end

function startDiagnostic()
    log("Starting track diagnostic...")
    self.children.status.values.text = "Getting track count..."
    self.children.status.color = Color.YELLOW
    
    -- Reset state
    trackNames = {}
    volumeRequests = {}
    volumeResponses = {}
    testInProgress = true
    currentTestTrack = 0
    
    -- Get track information
    local connections = buildConnectionTable(connectionIndex)
    sendOSC('/live/song/get/num_tracks', connections)
    sendOSC('/live/song/get/track_names', connections)
end

function testNextTrack()
    if currentTestTrack >= maxTracks then
        -- All tracks tested, show results
        showResults()
        return
    end
    
    self.children.status.values.text = "Testing track " .. currentTestTrack .. "..."
    
    -- Send volume request for this track
    volumeRequests[currentTestTrack] = getMillis()
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send a specific volume value to identify responses
    local testVolume = 0.5 + (currentTestTrack * 0.01)  -- Unique value per track
    sendOSC('/live/track/set/volume', currentTestTrack, testVolume, connections)
    
    -- Move to next track after delay
    currentTestTrack = currentTestTrack + 1
    runAfter(testNextTrack, 0.2)  -- 200ms delay between tests
end

function showResults()
    testInProgress = false
    self.children.status.color = Color.GREEN
    self.children.status.values.text = "Test complete - check logs"
    
    log("=== DIAGNOSTIC RESULTS ===")
    log("Total tracks in Ableton: " .. maxTracks)
    
    -- Show track names
    log("\nTrack Names:")
    for i = 0, maxTracks - 1 do
        local name = trackNames[i] or "[Unknown]"
        log("  Track " .. i .. ": " .. name)
    end
    
    -- Show volume response mismatches
    log("\nVolume Response Analysis:")
    local mismatches = {}
    
    for sentTrack, sentTime in pairs(volumeRequests) do
        local foundResponse = false
        for respTrack, respTime in pairs(volumeResponses) do
            -- Check if response came shortly after request
            if respTime > sentTime and respTime < sentTime + 200 then
                if sentTrack ~= respTrack then
                    table.insert(mismatches, {
                        sent = sentTrack,
                        received = respTrack,
                        offset = respTrack - sentTrack
                    })
                end
                foundResponse = true
                break
            end
        end
        
        if not foundResponse then
            log("  Track " .. sentTrack .. ": NO RESPONSE")
        end
    end
    
    -- Report mismatches
    if #mismatches > 0 then
        log("\nMISMATCHES FOUND:")
        for _, mismatch in ipairs(mismatches) do
            log("  Sent to track " .. mismatch.sent .. 
                " -> Received from track " .. mismatch.received .. 
                " (offset: " .. mismatch.offset .. ")")
        end
    else
        log("\nNo mismatches detected")
    end
    
    log("\n=== END RESULTS ===")
end

function onReceiveOSC(message, connections)
    local path = message[1]
    local args = message[2]
    
    -- Track count response
    if path == '/live/song/get/num_tracks' then
        maxTracks = args[1].value
        log("Ableton reports " .. maxTracks .. " tracks")
        return
    end
    
    -- Track names response
    if path == '/live/song/get/track_names' then
        for i = 1, #args do
            trackNames[i - 1] = args[i].value
        end
        
        -- Start testing tracks
        if testInProgress then
            runAfter(testNextTrack, 0.5)
        end
        return
    end
    
    -- Volume response
    if path == '/live/track/get/volume' and testInProgress then
        local trackNum = args[1].value
        local volume = args[2].value
        
        volumeResponses[trackNum] = getMillis()
        log("Received volume from track " .. trackNum .. ": " .. string.format("%.4f", volume))
    end
end

init()
