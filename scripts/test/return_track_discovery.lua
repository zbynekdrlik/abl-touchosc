-- Return Track Discovery Test Script
-- Version: 1.0.0
-- Purpose: Discover how AbletonOSC exposes return tracks
-- Usage: Run this in TouchOSC console or adapt for testing

local VERSION = "1.0.0"

-- ===========================
-- TEST CONFIGURATION
-- ===========================

local MAX_TRACKS_TO_TEST = 30  -- Test up to track index 30
local CONNECTION = 1           -- AbletonOSC connection to use

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    print("[ReturnTest] " .. os.date("%H:%M:%S") .. " " .. message)
end

-- ===========================
-- OSC HELPERS
-- ===========================

-- Send OSC query and log response
local function queryOSC(address, ...)
    log("Query: " .. address .. " " .. table.concat({...}, " "))
    -- In actual implementation, send OSC and capture response
    -- This is pseudocode for the pattern
    sendOSC(CONNECTION, address, ...)
end

-- ===========================
-- TEST FUNCTIONS
-- ===========================

-- Test 1: Basic track count and names
local function testTrackDiscovery()
    log("=== TEST 1: Track Discovery ===")
    
    -- Get track count
    queryOSC("/live/song/get/num_tracks")
    -- Expected response: (track_count)
    
    -- Get all track names
    queryOSC("/live/song/get/track_names")
    -- Expected response: (name1, name2, ..., nameN)
    
    -- Check for return-specific commands
    queryOSC("/live/song/get/num_return_tracks")
    -- May fail if not implemented
    
    queryOSC("/live/song/get/return_track_names")
    -- May fail if not implemented
end

-- Test 2: Extended index access
local function testExtendedIndices()
    log("=== TEST 2: Extended Index Access ===")
    
    for i = 0, MAX_TRACKS_TO_TEST do
        -- Try to get track name
        queryOSC("/live/track/get/name", i)
        -- Log: index, name or error
        
        -- If we get a name, check if it's a return track
        -- Return tracks often have names like "A-Return", "B-Return"
    end
end

-- Test 3: Track property identification
local function testTrackProperties()
    log("=== TEST 3: Track Property Identification ===")
    
    -- Properties that might differ for return tracks
    local properties = {
        "has_audio_input",
        "has_audio_output", 
        "has_midi_input",
        "has_midi_output",
        "can_be_armed",
        "is_foldable",
        "is_grouped",
        "available_input_routing_types",
        "available_output_routing_types"
    }
    
    -- Test first 20 tracks
    for i = 0, 19 do
        log("Track " .. i .. " properties:")
        for _, prop in ipairs(properties) do
            queryOSC("/live/track/get/" .. prop, i)
        end
    end
end

-- Test 4: Control functionality
local function testReturnControls()
    log("=== TEST 4: Return Track Controls ===")
    
    -- Once we identify return track indices, test controls
    local returnIndices = {} -- Fill this based on discovery
    
    for _, idx in ipairs(returnIndices) do
        log("Testing return track at index " .. idx)
        
        -- Test volume
        queryOSC("/live/track/get/volume", idx)
        queryOSC("/live/track/set/volume", idx, 0.5)
        queryOSC("/live/track/get/volume", idx)
        
        -- Test mute
        queryOSC("/live/track/get/mute", idx) 
        queryOSC("/live/track/set/mute", idx, 1)
        queryOSC("/live/track/get/mute", idx)
        queryOSC("/live/track/set/mute", idx, 0)
        
        -- Test meter
        queryOSC("/live/track/get/output_meter_level", idx)
    end
end

-- Test 5: Send levels from regular tracks
local function testSendLevels()
    log("=== TEST 5: Send Levels ===")
    
    -- Test send levels from regular tracks to returns
    for track = 0, 7 do  -- First 8 tracks
        for send = 0, 3 do  -- Up to 4 sends
            queryOSC("/live/track/get/send", track, send)
        end
    end
end

-- ===========================
-- ANALYSIS FUNCTIONS
-- ===========================

-- Analyze track name to determine type
local function analyzeTrackName(name)
    if not name then return "unknown" end
    
    if name:match("%-Return$") then
        return "return"
    elseif name:match("^Master$") then
        return "master"
    elseif name:match("%-Group$") then
        return "group"
    else
        return "regular"
    end
end

-- Build track map from responses
local function buildTrackMap(responses)
    local trackMap = {}
    
    -- Parse responses and build map
    -- This would process actual OSC responses
    
    return trackMap
end

-- ===========================
-- MAIN TEST SEQUENCE
-- ===========================

local function runAllTests()
    log("Return Track Discovery Test v" .. VERSION)
    log("Testing with AbletonOSC on connection " .. CONNECTION)
    log("=========================================")
    
    -- Run tests in sequence
    testTrackDiscovery()
    wait(1)  -- Give time for responses
    
    testExtendedIndices()
    wait(2)
    
    testTrackProperties()
    wait(2)
    
    -- Based on discovery, test controls
    testReturnControls()
    wait(1)
    
    testSendLevels()
    
    log("=========================================")
    log("Test sequence complete")
    log("Analyze OSC responses to determine return track access method")
end

-- ===========================
-- MANUAL TEST COMMANDS
-- ===========================

-- Individual test commands for manual testing
local testCommands = {
    -- Basic queries
    {"/live/song/get/num_tracks", "Get track count"},
    {"/live/song/get/track_names", "Get all track names"},
    
    -- Track queries (replace N with track index)
    {"/live/track/get/name N", "Get track N name"},
    {"/live/track/get/has_audio_input N", "Check if track N has audio input"},
    {"/live/track/get/volume N", "Get track N volume"},
    
    -- Potential return track queries
    {"/live/song/get/return_tracks", "Try to get return tracks (may fail)"},
    {"/live/return/get/name 0", "Try legacy return command (may fail)"},
    
    -- Send queries (track N, send S)
    {"/live/track/get/send N S", "Get send S level from track N"},
    {"/live/track/get/sends N", "Get all sends from track N"},
}

-- Print manual test commands
local function printManualCommands()
    log("Manual Test Commands:")
    log("====================")
    for _, cmd in ipairs(testCommands) do
        log(cmd[1] .. " -- " .. cmd[2])
    end
end

-- ===========================
-- DISCOVERY REPORT TEMPLATE
-- ===========================

local reportTemplate = [[
Return Track Discovery Report
============================

Test Date: %s
AbletonOSC Version: (unknown)
Test Script Version: %s

Track Count: %d
Track Names: %s

Return Track Access Method:
[ ] Extended indexing (returns after regular tracks)
[ ] Separate namespace (/live/return/)
[ ] Mixed with regular tracks
[ ] Not accessible

Return Track Indices:
%s

Properties that identify return tracks:
%s

Working OSC Commands:
%s

Notes:
%s
]]

-- ===========================
-- EXPORTS
-- ===========================

return {
    runAllTests = runAllTests,
    testTrackDiscovery = testTrackDiscovery,
    testExtendedIndices = testExtendedIndices,
    testTrackProperties = testTrackProperties,
    testReturnControls = testReturnControls,
    testSendLevels = testSendLevels,
    printManualCommands = printManualCommands,
    VERSION = VERSION
}