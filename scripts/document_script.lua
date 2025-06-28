-- TouchOSC Document Script (formerly helper_script.lua)
-- Version: 2.5.9
-- Purpose: Main document script with configuration, logging, and track management
-- Added: Handle log_message notifications from other scripts

local VERSION = "2.5.9"
local SCRIPT_NAME = "Document Script"

-- Configuration storage
local config = {
    connections = {},
    unfold_groups = {}
}

-- Control references (can be in pagers)
local logger = nil
local configText = nil
local logLines = {}
local maxLogLines = 60  -- Increased from 20 to 60 for full-height logger

-- === LOGGING FUNCTIONS ===
local function log(message)
    local logMessage = os.date("%H:%M:%S") .. " " .. message
    
    -- Always print to console
    print(logMessage)
    
    -- Store messages
    table.insert(logLines, logMessage)
    if #logLines > maxLogLines then
        table.remove(logLines, 1)
    end
    
    -- Try to find logger if not found yet
    if not logger then
        logger = root:findByName("logger", true)  -- recursive search
    end
    
    -- Update logger if found
    if logger and logger.values then
        logger.values.text = table.concat(logLines, "\n")
    end
end

-- === CONFIGURATION PARSING ===
local function parseConfiguration()
    -- Try to find configuration if not registered yet
    if not configText then
        configText = root:findByName("configuration", true)
    end
    
    if not configText or not configText.values.text then
        return false
    end
    
    local text = configText.values.text
    
    -- Clear old config
    config.connections = {}
    config.unfold_groups = {}
    
    -- Connection and unfold counts
    local connectionCount = 0
    local unfoldCount = 0
    
    -- Parse connection mappings
    for line in text:gmatch("[^\r\n]+") do
        -- Skip comments and empty lines
        if not line:match("^%s*#") and line:match("%S") then
            -- Parse connection lines
            local key, value = line:match("^%s*connection_(%w+):%s*(%d+)%s*$")
            if key and value then
                config.connections[key] = tonumber(value)
                connectionCount = connectionCount + 1
            end
            
            -- Parse unfold groups with connection prefix
            local unfold_instance, unfold_group = line:match("^%s*unfold_(%w+):%s*'([^']+)'%s*$")
            if not unfold_instance then
                unfold_instance, unfold_group = line:match('^%s*unfold_(%w+):%s*"([^"]+)"%s*$')
            end
            if unfold_instance and unfold_group then
                table.insert(config.unfold_groups, {
                    instance = unfold_instance,
                    group_name = unfold_group
                })
                unfoldCount = unfoldCount + 1
            end
            
            -- Legacy format support (no prefix = unfold on all connections)
            local unfold_match = line:match("^%s*unfold:%s*'([^']+)'%s*$")
            if not unfold_match then
                unfold_match = line:match('^%s*unfold:%s*"([^"]+)"%s*$')
            end
            if unfold_match then
                table.insert(config.unfold_groups, {
                    instance = "all",
                    group_name = unfold_match
                })
                unfoldCount = unfoldCount + 1
            end
        end
    end
    
    log("Config: " .. connectionCount .. " connections, " .. unfoldCount .. " unfolds")
    return true
end

-- === NOTIFY HANDLER ===
function onReceiveNotify(action, value)
    if action == "register_logger" then
        -- Logger is notifying us of its existence
        logger = value
        log("Logger registered")
        
        -- Send all buffered messages to logger
        if logger and logger.values then
            logger.values.text = table.concat(logLines, "\n")
        end
        
    elseif action == "register_configuration" then
        -- Configuration text is notifying us
        configText = value
        log("Config registered")
        
        -- Parse the configuration immediately
        parseConfiguration()
        
    elseif action == "configuration_updated" then
        -- Configuration text has been updated - reparse silently
        parseConfiguration()
        
    elseif action == "refresh_all_groups" then
        -- Global refresh button pressed
        refreshAllGroups()
        
    elseif action == "log_message" then
        -- Another script wants to log a message
        if value then
            log(tostring(value))
        end
    end
end

-- === GLOBAL HELPER FUNCTIONS ===
function getConnectionForInstance(instance)
    return config.connections[instance]
end

function refreshAllGroups()
    log("=== GLOBAL REFRESH ===")
    
    -- Update status
    local status = root:findByName("global_status")
    if status then
        status.values.text = "Refreshing..."
    end
    
    -- Find all groups with trackGroup tag
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    
    -- Clear all track mappings first
    for _, group in ipairs(groups) do
        -- Notify group to clear its mapping
        group:notify("clear_mapping")
    end
    
    -- Trigger refresh on all groups
    for _, group in ipairs(groups) do
        group:notify("refresh_tracks")
    end
    
    log("Refreshed " .. #groups .. " groups")
    
    -- Update status
    if status then
        status.values.text = "Ready"
    end
end

-- === OSC ROUTING HELPER ===
function createConnectionTable(connectionIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    return connections
end

-- === INITIALIZATION ===
function init()
    -- Add visual separator for new run
    log("════════════════════════════════════════")
    log("═══ NEW SESSION " .. os.date("%Y-%m-%d %H:%M:%S") .. " ═══")
    log("════════════════════════════════════════")
    
    log(SCRIPT_NAME .. " v" .. VERSION .. " loaded")
    
    -- Try to find logger
    logger = root:findByName("logger", true)
    
    -- Try to parse configuration
    parseConfiguration()
    
    -- Original init commands
    sendOSC('/live/track/stop_listen/*', '*')
    sendOSC('/live/song/get/track_names')
    sendOSC('/live/song/start_listen/is_playing')
    
    log("Ready")
end

-- === OSC RECEIVE HANDLER ===
function onReceiveOSC(message, connections)
    local arguments = message[2]
    
    -- Handle track names for unfolding
    if message[1] == '/live/song/get/track_names' then
        -- Determine which connection this came from
        local sourceConnection = nil
        for i = 1, #connections do
            if connections[i] then
                sourceConnection = i
                break
            end
        end
        
        -- Find which instance this connection belongs to
        local sourceInstance = nil
        for instance, connIndex in pairs(config.connections) do
            if connIndex == sourceConnection then
                sourceInstance = instance
                break
            end
        end
        
        -- Count unfolds for this instance
        local unfoldedCount = 0
        
        for i = 1, #arguments do
            local track_index = i - 1
            local track_name = arguments[i].value
            
            -- Check against configured unfold groups
            for _, unfold_config in ipairs(config.unfold_groups) do
                if track_name == unfold_config.group_name then
                    -- Check if this unfold should apply to this instance
                    if unfold_config.instance == "all" or unfold_config.instance == sourceInstance then
                        -- Only send unfold if we have a known source
                        if sourceConnection and sourceInstance then
                            local targetConnections = createConnectionTable(sourceConnection)
                            sendOSC('/live/track/set/fold_state', track_index, false, targetConnections)
                            unfoldedCount = unfoldedCount + 1
                        end
                    end
                end
            end
        end
        
        -- Log summary instead of details
        if unfoldedCount > 0 then
            log("Unfolded " .. unfoldedCount .. " groups on " .. (sourceInstance or "unknown"))
        end
    end
    
    -- Pass through to avoid blocking other receivers
    return false
end

-- Initialize on load
init()