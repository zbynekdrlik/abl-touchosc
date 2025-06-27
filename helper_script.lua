-- TouchOSC Selective Connection Routing Helper Script
-- Version: 1.0.0
-- Phase: 01 - Selective Connection Routing

-- Version logging on startup
local SCRIPT_VERSION = "1.0.0"
print("[helper_script.lua] [" .. os.date("%Y-%m-%d %H:%M:%S") .. "] Script version " .. SCRIPT_VERSION .. " loaded")
print("[helper_script.lua] [" .. os.date("%Y-%m-%d %H:%M:%S") .. "] Selective Connection Routing Phase 0 initialized")

-- Shared helper functions for connection routing
function getConnectionIndex(instance)
    local configName = "connection_" .. instance
    local configObj = root:findByName(configName)
    
    if configObj and configObj.values.text then
        local index = tonumber(configObj.values.text) or 1
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
    
    local configs = {"connection_band", "connection_master"}
    local valid = true
    
    for _, configName in ipairs(configs) do
        local obj = root:findByName(configName)
        if obj then
            print("[helper_script.lua]", configName, "found with value:", obj.values.text)
        else
            print("[helper_script.lua] ERROR:", configName, "not found!")
            valid = false
        end
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
