-- TouchOSC Selective Connection Routing Helper Script
-- Version: 1.0.6
-- Phase: 01 - Selective Connection Routing

-- Version logging on startup
local SCRIPT_VERSION = "1.0.6"

-- Logger settings
local MAX_LOG_LINES = 20  -- Maximum lines to keep in logger
local logLines = {}       -- Log buffer

-- Logger function
function log(...)
    local timestamp = os.date("%H:%M:%S")
    local args = {...}
    local message = "[" .. timestamp .. "] "
    
    -- Concatenate all arguments
    for i, v in ipairs(args) do
        message = message .. tostring(v)
        if i < #args then
            message = message .. " "
        end
    end
    
    -- Print to console
    print(message)
    
    -- Add to log buffer
    table.insert(logLines, message)
    
    -- Keep only last MAX_LOG_LINES
    while #logLines > MAX_LOG_LINES do
        table.remove(logLines, 1)
    end
    
    -- Update logger text object
    updateLogger()
end

-- Update logger text object
function updateLogger()
    local loggerObj = root:findByName("logger")
    if loggerObj and loggerObj.values then
        loggerObj.values.text = table.concat(logLines, "\n")
    end
end

-- Clear logger
function clearLogger()
    logLines = {}
    updateLogger()
end

-- Start logging
log("Helper Script v" .. SCRIPT_VERSION .. " loaded")
log("Selective Connection Routing initialized")

-- Configuration cache
local configCache = {}

-- Parse configuration from text object
function parseConfiguration()
    local configObj = root:findByName("configuration")
    
    if not configObj or not configObj.values or not configObj.values.text then
        log("ERROR: No 'configuration' text object found")
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
                log("Config loaded: " .. key .. " = " .. value)
            else
                log("Warning: Invalid config line: " .. line)
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
        log("Connection for " .. instance .. " is " .. index)
        return index
    else
        log("Warning: No config for " .. instance .. " - using default (1)")
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
    log("Refreshing all track groups...")
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    local count = 0
    for _, group in ipairs(groups) do
        group:notify("refresh")
        count = count + 1
    end
    log("Sent refresh to " .. count .. " groups")
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
    log("Validating configuration...")
    
    -- Check for logger
    local loggerObj = root:findByName("logger")
    if not loggerObj then
        print("[helper_script.lua] Note: No 'logger' text object found - logs will only appear in console")
    else
        log("Logger text object found")
    end
    
    if not parseConfiguration() then
        log("Configuration validation FAILED")
        log("Create text object 'configuration' with:")
        log("  connection_band: 1")
        log("  connection_master: 2")
        return false
    end
    
    -- Check for required connections
    local required = {"connection_band", "connection_master"}
    local valid = true
    
    for _, key in ipairs(required) do
        if configCache[key] then
            log(key .. " configured as connection " .. configCache[key])
        else
            log("Warning: " .. key .. " not found")
            valid = false
        end
    end
    
    if valid then
        log("Configuration validation PASSED")
    else
        log("Configuration incomplete")
    end
    
    return valid
end

-- Store functions in root for global access
root.helperFunctions = {
    log = log,
    getConnectionIndex = getConnectionIndex,
    buildConnectionTable = buildConnectionTable,
    parseGroupName = parseGroupName,
    refreshAllGroups = refreshAllGroups,
    updateStatusIndicator = updateStatusIndicator,
    STATUS_COLORS = STATUS_COLORS
}

-- Initialize
function init()
    log("Helper script initializing...")
    validateConfiguration()
end

-- Update function for auto-refresh (to be implemented in Phase 4)
function update()
    -- Phase 4 will add auto-refresh logic here
end

log("Helper functions loaded successfully")
log("Configuration format:")
log("  connection_band: 1")
log("  connection_master: 2")

-- Run validation immediately
validateConfiguration()

-- Note: Helper functions are stored in root.helperFunctions
log("Helper functions available at root.helperFunctions")
