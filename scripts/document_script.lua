-- TouchOSC Document Script (formerly helper_script.lua)
-- Version: 2.2.1
-- Purpose: Main document script with configuration, logging, and track management

local VERSION = "2.2.1"
local SCRIPT_NAME = "Document Script"

-- Configuration storage
local config = {
    connections = {},
    unfold_groups = {}
}

-- Logger setup
local logger = nil
local logLines = {}
local maxLogLines = 20

-- === LOGGING FUNCTIONS ===
local function findLogger()
    -- Check if logger was registered
    if logger then
        return logger
    end
    
    -- Simple search at root
    logger = root:findByName("logger")
    return logger
end

local function log(message)
    local logMessage = os.date("%H:%M:%S") .. " " .. message
    
    -- Always print to console as backup
    print(logMessage)
    
    if not logger then
        findLogger()
        if not logger then return end
    end
    
    table.insert(logLines, logMessage)
    
    if #logLines > maxLogLines then
        table.remove(logLines, 1)
    end
    
    logger.values.text = table.concat(logLines, "\n")
end

-- === CONFIGURATION PARSING ===
local function parseConfiguration()
    local configText = root:findByName("configuration")
    if not configText or not configText.values.text then
        log("ERROR: No configuration text object found")
        return false
    end
    
    local text = configText.values.text
    log("Parsing configuration...")
    
    -- Parse connection mappings
    for line in text:gmatch("[^\r\n]+") do
        -- Skip comments and empty lines
        if not line:match("^%s*#") and line:match("%S") then
            -- Parse connection lines
            local key, value = line:match("^%s*connection_(%w+):%s*(%d+)%s*$")
            if key and value then
                config.connections[key] = tonumber(value)
                log("  Connection: " .. key .. " -> " .. value)
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
                log("  Unfold group: " .. unfold_instance .. " -> " .. unfold_group)
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
                log("  Unfold group: all -> " .. unfold_match)
            end
        end
    end
    
    log("Configuration loaded: " .. #config.unfold_groups .. " unfold groups")
    return true
end

-- === GLOBAL HELPER FUNCTIONS ===
function getConnectionForInstance(instance)
    return config.connections[instance]
end

function notifyGroupRefresh(groupName)
    local group = root:findByName(groupName)
    if group then
        group:notify("refresh_tracks")
        log("Refreshing " .. groupName)
    end
end

function refreshAllGroups()
    log("=== GLOBAL REFRESH INITIATED ===")
    
    -- Update status
    local status = root:findByName("global_status")
    if status then
        status.values.text = "Refreshing..."
    end
    
    -- Clear all track mappings first
    local groups = root:findAllByProperty("tag", "trackGroup", true)
    for _, group in ipairs(groups) do
        if group.trackNumber then
            group.trackNumber = nil
        end
    end
    
    -- Trigger refresh on all groups
    for _, group in ipairs(groups) do
        group:notify("refresh_tracks")
        log("Refreshing " .. group.name)
    end
    
    -- Update status
    if status then
        status.values.text = "Ready"
    end
    
    log("=== GLOBAL REFRESH COMPLETE ===")
end

-- === OSC ROUTING HELPER ===
function createConnectionTable(connectionIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    return connections
end

-- === LOGGER REGISTRATION ===
-- Call this from logger's init script
function registerLogger(loggerControl)
    logger = loggerControl
    log("Logger registered from " .. (loggerControl.parent and loggerControl.parent.name or "unknown"))
end

-- === INITIALIZATION ===
function init()
    log(SCRIPT_NAME .. " v" .. VERSION .. " loaded")
    
    -- Parse configuration
    parseConfiguration()
    
    -- Original init commands
    log("Stopping all track listeners...")
    sendOSC('/live/track/stop_listen/*', '*')
    
    log("Requesting track names...")
    sendOSC('/live/song/get/track_names')
    
    log("Starting playback listener...")
    sendOSC('/live/song/start_listen/is_playing')
    
    log("Initialization complete")
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
        
        log("Received track names from " .. (sourceInstance or "unknown") .. " (connection " .. (sourceConnection or "?") .. ")")
        
        for i = 1, #arguments do
            local track_index = i - 1
            local track_name = arguments[i].value
            
            -- Check against configured unfold groups
            for _, unfold_config in ipairs(config.unfold_groups) do
                if track_name == unfold_config.group_name then
                    -- Check if this unfold should apply to this instance
                    if unfold_config.instance == "all" or unfold_config.instance == sourceInstance then
                        log("Unfolding group: " .. track_name .. " (track " .. track_index .. ") on " .. (sourceInstance or "all"))
                        
                        -- Send unfold command only to the source connection
                        local targetConnections = createConnectionTable(sourceConnection)
                        sendOSC('/live/track/set/fold_state', track_index, false, targetConnections)
                    end
                end
            end
        end
    end
    
    -- Pass through to avoid blocking other receivers
    return false
end

-- Initialize on load
init()
