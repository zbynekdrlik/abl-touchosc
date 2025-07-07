-- TouchOSC Document Script (formerly helper_script.lua)
-- Version: 2.10.0
-- Purpose: Main document script with configuration and track management
-- Changed: Centralized track names retrieval to prevent duplicate OSC calls

local VERSION = "2.10.0"
local SCRIPT_NAME = "Document Script"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- Configuration storage
local config = {
    connections = {},
    unfold_groups = {}
    -- Note: double_click_mute settings are parsed directly by mute_button.lua
}

-- Control references (can be in pagers)
local configText = nil

-- Store track group references
local trackGroups = {}

-- Startup tracking
local startupRefreshTime = nil
local frameCount = 0
local STARTUP_DELAY_FRAMES = 60  -- Wait 1 second (60 frames at 60fps)

-- Refresh state tracking
local refreshState = "idle"  -- idle, clearing, waiting, refreshing
local refreshWaitStart = 0
local REFRESH_WAIT_TIME = 100  -- 100ms delay between clear and refresh

-- === LOCAL LOGGING FUNCTION ===
local function log(message)
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] " .. SCRIPT_NAME .. ": " .. message)
    end
end

-- === CONFIGURATION PARSING ===
-- Configuration format supports:
-- connection_[instance]: [number] - Connection routing
-- unfold_[instance]: '[group_name]' - Auto-unfold groups
-- double_click_mute_[instance]: '[group_name]' - Double-click mute groups (parsed by mute_button.lua)
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
            
            -- Note: double_click_mute_[instance] configuration is parsed directly by mute_button.lua
        end
    end
    
    log("Config: " .. connectionCount .. " connections, " .. unfoldCount .. " unfolds")
    return true
end

-- === NOTIFY HANDLER ===
function onReceiveNotify(action, value)
    if action == "register_configuration" then
        -- Configuration text is notifying us
        configText = value
        log("Config registered")
        
        -- Parse the configuration immediately
        parseConfiguration()
        
    elseif action == "refresh_all_groups" then
        -- Global refresh button pressed - start refresh sequence
        startRefreshSequence()
    elseif action == "register_track_group" then
        -- Track group is registering itself
        if value and value.name then
            trackGroups[value.name] = value
            log("Registered track group: " .. value.name)
        end
    end
    -- Note: Removed "configuration_updated" handler - config text is read-only at runtime
    -- Note: Removed "log_message" handler - each script logs independently now
end

-- === REFRESH SEQUENCE WITH DELAY ===
function startRefreshSequence()
    log("=== STARTING REFRESH SEQUENCE ===")
    
    -- Update status
    local status = root:findByName("global_status")
    if status then
        status.values.text = "Clearing..."
    end
    
    -- Count groups
    local groupCount = 0
    for name, _ in pairs(trackGroups) do
        groupCount = groupCount + 1
    end
    
    -- Clear all track mappings first
    for name, group in pairs(trackGroups) do
        -- Verify group still exists and is valid
        if group and group.notify then
            group:notify("clear_mapping")
        else
            -- Remove invalid reference
            trackGroups[name] = nil
        end
    end
    
    log("Cleared " .. groupCount .. " groups")
    
    -- Set state to wait before refreshing
    refreshState = "waiting"
    refreshWaitStart = getMillis()
    
    -- Update status
    if status then
        status.values.text = "Waiting..."
    end
end

-- === COMPLETE REFRESH AFTER DELAY ===
function completeRefreshSequence()
    log("=== COMPLETING REFRESH ===")
    
    -- Update status
    local status = root:findByName("global_status")
    if status then
        status.values.text = "Refreshing..."
    end
    
    -- Notify all groups to prepare for refresh
    -- This sets their needsRefresh flag so they'll process incoming track names
    for name, group in pairs(trackGroups) do
        -- Verify group still exists and is valid
        if group and group.notify then
            group:notify("refresh_tracks")
        end
    end
    
    -- Query track names once per connection
    local uniqueConnections = {}
    for instance, connIndex in pairs(config.connections) do
        if not uniqueConnections[connIndex] then
            uniqueConnections[connIndex] = true
            
            -- Build connection table for this specific connection
            local connections = {}
            for i = 1, 10 do
                connections[i] = (i == connIndex)
            end
            
            -- Query both regular and return tracks
            sendOSC('/live/song/get/track_names', connections)
            sendOSC('/live/song/get/return_track_names', connections)
            
            log("Queried connection " .. connIndex)
        end
    end
    
    -- If no connections configured, query connection 1
    if next(uniqueConnections) == nil then
        local connections = {true, false, false, false, false, false, false, false, false, false}
        sendOSC('/live/song/get/track_names', connections)
        sendOSC('/live/song/get/return_track_names', connections)
        log("Queried default connection 1")
    end
    
    -- Update status
    if status then
        status.values.text = "Ready"
    end
    
    -- Reset state
    refreshState = "idle"
end

-- === GLOBAL HELPER FUNCTIONS ===
function getConnectionForInstance(instance)
    return config.connections[instance]
end

function refreshAllGroups()
    -- Deprecated - use startRefreshSequence instead
    startRefreshSequence()
end

-- === OSC ROUTING HELPER ===
function createConnectionTable(connectionIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    return connections
end

-- === UPDATE FUNCTION FOR STARTUP REFRESH AND DELAYED OPERATIONS ===
function update()
    -- Handle refresh sequence timing
    if refreshState == "waiting" then
        local elapsed = getMillis() - refreshWaitStart
        if elapsed >= REFRESH_WAIT_TIME then
            refreshState = "refreshing"
            completeRefreshSequence()
        end
    end
    
    -- Count frames since startup
    if frameCount < STARTUP_DELAY_FRAMES + 10 then
        frameCount = frameCount + 1
        
        -- Perform refresh at the specified frame count
        if frameCount == STARTUP_DELAY_FRAMES then
            log("=== AUTOMATIC STARTUP REFRESH ===")
            startRefreshSequence()
        end
    end
end

-- === INITIALIZATION ===
function init()
    log("Script v" .. VERSION .. " loaded")
    
    -- Clear track groups table
    trackGroups = {}
    
    -- Try to parse configuration
    parseConfiguration()
    
    -- Original init commands
    sendOSC('/live/track/stop_listen/*', '*')
    sendOSC('/live/song/get/track_names')
    sendOSC('/live/song/start_listen/is_playing')
    
    log("Ready - automatic refresh scheduled")
    
    -- Reset frame counter for startup refresh
    frameCount = 0
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