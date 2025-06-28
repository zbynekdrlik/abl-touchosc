-- test_helper.lua
-- Version: 1.1.0
-- Simple test helper for Phase 3 script functionality testing
-- Attach this to root for testing utilities
-- Updated: Use centralized logging

local VERSION = "1.1.0"

-- Centralized logging through document script
local function log(message)
    -- Send to document script for logger text update
    root:notify("log_message", "TEST HELPER: " .. message)
    
    -- Also print to console for development/debugging
    print("[" .. os.date("%H:%M:%S") .. "] TEST HELPER: " .. message)
end

function init()
    log("Script v" .. VERSION .. " loaded")
    log("=== PHASE 3 TESTING MODE ===")
    
    -- Initial test status
    performStartupChecks()
end

-- Perform startup checks
function performStartupChecks()
    log("--- Startup Checks ---")
    
    -- Check for configuration
    local config = root:findByName("configuration", false)
    if config then
        log("✓ Configuration object found")
    else
        log("✗ Configuration object missing!")
    end
    
    -- Check for logger
    local logger = root:findByName("logger", false)
    if logger then
        log("✓ Logger object found")
    else
        log("✗ Logger object missing!")
    end
    
    -- Check for document script
    if root.onReceiveNotify then
        log("✓ Document script attached to root")
    else
        log("✗ Document script not found on root!")
    end
    
    -- Count groups
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    log("Found " .. #groups .. " track groups:")
    
    local bandCount = 0
    local masterCount = 0
    
    for _, group in ipairs(groups) do
        local name = group.name or "unnamed"
        if name:match("^band_") then
            bandCount = bandCount + 1
            log("  - " .. name .. " (band)")
        elseif name:match("^master_") then
            masterCount = masterCount + 1
            log("  - " .. name .. " (master)")
        else
            log("  - " .. name .. " (no prefix!)")
        end
    end
    
    log("Summary:")
    log("  Band groups: " .. bandCount)
    log("  Master groups: " .. masterCount)
end

-- Test all controls in a group
function testGroupControls(groupName)
    log("--- Testing Group: " .. groupName .. " ---")
    
    local group = root:findByName(groupName, true)
    if not group then
        log("✗ Group not found: " .. groupName)
        return
    end
    
    -- Check group properties
    log("Group tag: " .. (group.tag or "not set"))
    
    -- Check for status indicator
    local status = group.children and group.children.status_indicator
    if status then
        log("✓ Status indicator found")
        local color = status.color
        if color then
            log("  Color: R=" .. color.r .. " G=" .. color.g .. " B=" .. color.b)
        end
    else
        log("✗ Status indicator missing!")
    end
    
    -- Check for controls
    local controls = {
        {name = "fader", type = "Fader"},
        {name = "meter", type = "Group"},
        {name = "mute", type = "Button"},
        {name = "pan", type = "Encoder/Radial"},
        {name = "track_label", type = "Label"}
    }
    
    for _, ctrl in ipairs(controls) do
        local found = group.children and group.children[ctrl.name]
        if found then
            log("✓ " .. ctrl.name .. " found")
            -- Check if it's interactive
            if found.interactive ~= nil then
                log("  Interactive: " .. tostring(found.interactive))
            end
        else
            log("✗ " .. ctrl.name .. " missing!")
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
    log(msg)
end

-- Test connection routing
function testConnectionRouting()
    log("--- Testing Connection Routing ---")
    
    -- Try to get configuration text
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        log("✗ Cannot get configuration text!")
        return
    end
    
    local configText = configObj.values.text
    log("Configuration text found, parsing...")
    
    -- Parse connections
    local connections = {}
    for line in configText:gmatch("[^\r\n]+") do
        local key, value = line:match("^%s*connection_(%w+):%s*(%d+)%s*$")
        if key and value then
            connections[key] = tonumber(value)
            log("  " .. key .. " -> connection " .. value)
        end
    end
    
    if next(connections) == nil then
        log("✗ No connections found in configuration!")
    else
        log("✓ Found " .. #connections .. " connection mappings")
    end
end

-- Test refresh functionality
function testRefresh()
    log("--- Testing Refresh ---")
    
    -- Find refresh button
    local refreshBtn = root:findByName("global_refresh", true)
    if refreshBtn then
        log("✓ Global refresh button found")
        -- Trigger refresh
        root:notify("refresh_all_groups")
        log("Refresh triggered via notify")
    else
        log("✗ Global refresh button not found!")
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
    elseif action == "test_refresh" then
        testRefresh()
    elseif action == "test_all" then
        testAll()
    end
end

-- Run all tests
function testAll()
    log("=== RUNNING ALL TESTS ===")
    performStartupChecks()
    testConnectionRouting()
    testRefresh()
    
    -- Test each group
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    for _, group in ipairs(groups) do
        testGroupControls(group.name)
    end
    
    log("=== TESTS COMPLETE ===")
end

-- Make test functions available
log("Test Helper Ready - Use notify to trigger tests:")
log("  notify('test_all') - Run all tests")
log("  notify('test_group', 'groupname') - Test specific group")
log("  notify('test_connections') - Test connection setup")
log("  notify('test_startup') - Re-run startup checks")
log("  notify('test_refresh') - Test refresh functionality")
