-- TouchOSC Selective Connection Routing Helper Script
-- Version: 1.0.3
-- Phase: 01 - Selective Connection Routing

-- Version logging on startup
local SCRIPT_VERSION = "1.0.3"
print("[helper_script.lua] [" .. os.date("%Y-%m-%d %H:%M:%S") .. "] Script version " .. SCRIPT_VERSION .. " loaded")
print("[helper_script.lua] [" .. os.date("%Y-%m-%d %H:%M:%S") .. "] Selective Connection Routing Phase 0 initialized")

-- Configuration cache
local configCache = {}

-- Parse configuration from text object
function parseConfiguration()
    local configObj = root:findByName("configuration")
    
    if not configObj or not configObj.values or not configObj.values.text then
        print("[helper_script.lua] ERROR: No 'configuration' text object found")
        return false
    end
    
    configCache = {}
    local configText = configObj.values.text
    
    -- Parse each line
    for line in configText:gmatch("[^\r\n]+") do
        -- Trim whitespace
        line = line:match("^%s*(.-)%s*$")
        
        -- Skip empty lines and comments
        if line ~= "" and not line:match("^#") then
            -- Parse key: value
            local key, value = line:match("^([%w_]+):%s*(.+)$")
            if key and value then
                -- Trim whitespace from value
                value = value:match("^%s*(.-)%s*$")
                configCache[key] = value
                print("[helper_script.lua] Config loaded:", key, "=", value)
            else
                print("[helper_script.lua] Warning: Invalid config line:", line)
            end
        end
    end
    
    return true
end

-- Get connection index for an instance
function getConnectionIndex(instance)
    local key = "connection_" .. instance
    local value = configCache[key]
    
    if value then
        local index = tonumber(value) or 1
        print("[helper_script.lua] Connection for", instance, "is", index)
        return index
    else
        print("[helper_script.lua] Warning: No connection config for", instance, "- using default (1)")
        return 1
    end
end

function buildConnectionTable(connectionIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    return connections
end

function parseGroupName(name)
    -- Extract instance prefix and track name
    if name:sub(1, 5) == "band_" then
        return "band", name:sub(6)
    elseif name:sub(1, 7) == "master_" then
        return "master", name:sub(8)
    else
        -- Default to band for backwards compatibility
        return "band", name
    end
end

-- Global refresh function
function refreshAllGroups()
    print("[helper_script.lua] Refreshing all track groups")
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    local count = 0
    for _, group in ipairs(groups) do
        group:notify("refresh")
        count = count + 1
    end
    print("[helper_script.lua] Sent refresh to", count, "groups")
end

-- Status color definitions
STATUS_COLORS = {
    refreshing = {1, 1, 0},     -- Yellow
    ok = {0, 1, 0},             -- Green
    error = {1, 0, 0},          -- Red
    stale = {1, 0.5, 0}         -- Orange
}

-- Helper to update status indicators
function updateStatusIndicator(group, status)
    if not group.children.status_indicator then return end
    
    local color = STATUS_COLORS[status] or {0.5, 0.5, 0.5}
    group.children.status_indicator.color = color
end

-- Configuration validation
function validateConfiguration()
    print("[helper_script.lua] Validating configuration...")
    
    if not parseConfiguration() then
        print("[helper_script.lua] Configuration validation FAILED")
        print("[helper_script.lua] Please create a text object named 'configuration' with format:")
        print("[helper_script.lua]   connection_band: 1")
        print("[helper_script.lua]   connection_master: 2")
        return false
    end
    
    -- Check for required connections
    local required = {"connection_band", "connection_master"}
    local valid = true
    
    for _, key in ipairs(required) do
        if configCache[key] then
            print("[helper_script.lua]", key, "configured as connection", configCache[key])
        else
            print("[helper_script.lua] Warning:", key, "not found in configuration")
            valid = false
        end
    end
    
    if valid then
        print("[helper_script.lua] Configuration validation PASSED")
    else
        print("[helper_script.lua] Configuration incomplete - add missing connection definitions")
    end
    
    return valid
end

-- Initialize
function init()
    print("[helper_script.lua] Helper script initializing...")
    validateConfiguration()
end

-- Update function for auto-refresh (to be implemented in Phase 4)
function update()
    -- Phase 4 will add auto-refresh logic here
end

print("[helper_script.lua] Helper functions loaded successfully")
print("[helper_script.lua] Configuration format:")
print("[helper_script.lua]   connection_band: 1")
print("[helper_script.lua]   connection_master: 2")
print("[helper_script.lua]   # Comments are supported")

-- Run validation immediately
validateConfiguration()
