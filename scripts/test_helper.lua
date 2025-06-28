-- test_helper.lua
-- Version: 1.0.0
-- Simple test helper for Phase 3 script functionality testing
-- Attach this to root for testing utilities

local VERSION = "1.0.0"

function init()
    print("Test Helper v" .. VERSION .. " loaded at " .. os.date("%X"))
    print("=== PHASE 3 TESTING MODE ===")
    
    -- Initial test status
    performStartupChecks()
end

-- Perform startup checks
function performStartupChecks()
    print("\n--- Startup Checks ---")
    
    -- Check for configuration
    local config = root:findByName("configuration", false)
    if config then
        print("✓ Configuration object found")
    else
        print("✗ Configuration object missing!")
    end
    
    -- Check for logger
    local logger = root:findByName("logger", false)
    if logger then
        print("✓ Logger object found")
    else
        print("✗ Logger object missing!")
    end
    
    -- Check for helper script
    local helper = root:findByName("helper", false)
    if helper then
        print("✓ Helper script found")
    else
        print("✗ Helper script not found!")
    end
    
    -- Count groups
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    print("Found " .. #groups .. " track groups:")
    
    local bandCount = 0
    local masterCount = 0
    
    for _, group in ipairs(groups) do
        local name = group.name or "unnamed"
        if name:match("^band_") then
            bandCount = bandCount + 1
            print("  - " .. name .. " (band)")
        elseif name:match("^master_") then
            masterCount = masterCount + 1
            print("  - " .. name .. " (master)")
        else
            print("  - " .. name .. " (no prefix!)")
        end
    end
    
    print("\nSummary:")
    print("  Band groups: " .. bandCount)
    print("  Master groups: " .. masterCount)
end

-- Test all controls in a group
function testGroupControls(groupName)
    print("\n--- Testing Group: " .. groupName .. " ---")
    
    local group = root:findByName(groupName, true)
    if not group then
        print("✗ Group not found: " .. groupName)
        return
    end
    
    -- Check group properties
    print("Group tag: " .. (group.tag or "not set"))
    print("Track number: " .. (group.trackNumber or "not set"))
    
    -- Check for status indicator
    local status = group:findByName("status_indicator", true)
    if status then
        print("✓ Status indicator found")
        local color = status.color
        if color then
            print("  Color: R=" .. color[1] .. " G=" .. color[2] .. " B=" .. color[3])
        end
    else
        print("✗ Status indicator missing!")
    end
    
    -- Check for controls
    local controls = {
        {name = "fader", type = "Fader"},
        {name = "meter", type = "Group"},
        {name = "mute", type = "Button"},
        {name = "pan", type = "Encoder/Radial"}
    }
    
    for _, ctrl in ipairs(controls) do
        local found = group:findByName(ctrl.name, true)
        if found then
            print("✓ " .. ctrl.name .. " found")
        else
            print("✗ " .. ctrl.name .. " missing!")
        end
    end
end

-- Log OSC message for testing
function logOSCMessage(path, ...)
    local args = {...}
    local msg = "OSC: " .. path
    for i, arg in ipairs(args) do
        msg = msg .. " [" .. tostring(arg) .. "]"
    end
    print(msg)
end

-- Test connection routing
function testConnectionRouting()
    print("\n--- Testing Connection Routing ---")
    
    -- Get configuration
    local config = getConfiguration()
    if not config then
        print("✗ Cannot get configuration!")
        return
    end
    
    print("Band connection: " .. (config.connections.band or "not set"))
    print("Master connection: " .. (config.connections.master or "not set"))
    
    -- Test creating connection table
    local bandTable = createConnectionTable(config.connections.band)
    local masterTable = createConnectionTable(config.connections.master)
    
    print("\nBand connection table:")
    for i = 1, 10 do
        if bandTable[i] then
            print("  Connection " .. i .. ": enabled")
        end
    end
    
    print("\nMaster connection table:")
    for i = 1, 10 do
        if masterTable[i] then
            print("  Connection " .. i .. ": enabled")
        end
    end
end

-- Manual test triggers
function onReceiveNotify(action, value)
    if action == "test_group" then
        testGroupControls(value)
    elseif action == "test_connections" then
        testConnectionRouting()
    elseif action == "test_startup" then
        performStartupChecks()
    end
end

-- Provide some global test functions
function testAll()
    print("\n=== RUNNING ALL TESTS ===")
    performStartupChecks()
    testConnectionRouting()
    
    -- Test each group
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    for _, group in ipairs(groups) do
        testGroupControls(group.name)
    end
    
    print("\n=== TESTS COMPLETE ===")
end

-- Make test functions available globally
_G.testHelper = {
    testAll = testAll,
    testGroup = testGroupControls,
    testConnections = testConnectionRouting,
    testStartup = performStartupChecks
}

print("\nTest functions available:")
print("  testHelper.testAll() - Run all tests")
print("  testHelper.testGroup('name') - Test specific group")
print("  testHelper.testConnections() - Test connection setup")
print("  testHelper.testStartup() - Re-run startup checks")