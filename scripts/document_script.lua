-- TouchOSC Document Script (formerly helper_script.lua)
-- Version: 2.8.6
-- Purpose: Main document script with configuration and track management
-- Changed: Added debug logging to diagnose group finding issue

local VERSION = "2.8.6"
local SCRIPT_NAME = "Document Script"

-- Debug flag - set to 1 to enable logging
local DEBUG = 1  -- TEMPORARILY ENABLED FOR DEBUGGING

-- Configuration storage
local config = {
    connections = {},
    unfold_groups = {}
}

-- Control references (can be in pagers)
local configText = nil

-- Startup tracking
local startupRefreshTime = nil
local frameCount = 0
local STARTUP_DELAY_FRAMES = 60  -- Wait 1 second (60 frames at 60fps)

-- Refresh state tracking
local refreshState = "idle"  -- idle, clearing, waiting, refreshing
local refreshGroups = {}
local refreshWaitStart = 0
local REFRESH_WAIT_TIME = 100  -- 100ms delay between clear and refresh

-- === LOCAL LOGGING FUNCTION ===
local function log(message)
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] " .. SCRIPT_NAME .. ": " .. message)
    end
end

-- === HELPER TO FIND TRACK GROUPS ===
local function findTrackGroups()
    local groups = {}
    local searchCount = 0
    
    -- Function to recursively search for groups
    local function searchControl(control, depth)
        searchCount = searchCount + 1
        
        if control and control.name then
            -- Debug: log what we're checking
            if depth <= 2 then  -- Only log first few levels to avoid spam
                log("Checking control: " .. control.name .. " (depth: " .. depth .. ")")
            end
            
            -- Check if name starts with "band_" or "master_"
            if (control.name:match("^band_") or control.name:match("^master_")) then
                log("Found potential group: " .. control.name .. " - has children: " .. tostring(control.children ~= nil))
                if control.children then
                    table.insert(groups, control)
                    log("Added group: " .. control.name)
                end
            end
        end
        
        -- Recursively search children
        if control and control.children then
            for name, child in pairs(control.children) do
                searchControl(child, depth + 1)
            end
        end
    end
    
    -- Start searching from root
    log("Starting group search from root...")
    searchControl(root, 0)
    log("Search complete. Checked " .. searchCount .. " controls, found " .. #groups .. " groups")
    
    -- Log the names of found groups
    for i, group in ipairs(groups) do
        log("Group " .. i .. ": " .. group.name)
    end
    
    return groups
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
    if action == "register_configuration" then
        -- Configuration text is notifying us
        configText = value
        log("Config registered")
        
        -- Parse the configuration immediately
        parseConfiguration()
        
    elseif action == "refresh_all_groups" then
        -- Global refresh button pressed - start refresh sequence
        startRefreshSequence()
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
    
    -- Find all track groups by name pattern
    refreshGroups = findTrackGroups()
    
    -- Clear all track mappings first
    for _, group in ipairs(refreshGroups) do
        -- Notify group to clear its mapping
        group:notify("clear_mapping")
    end
    
    log("Cleared " .. #refreshGroups .. " groups")
    
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
    
    -- Trigger refresh on all groups
    for _, group in ipairs(refreshGroups) do
        group:notify("refresh_tracks")
    end
    
    log("Refreshed " .. #refreshGroups .. " groups")
    
    -- Update status
    if status then
        status.values.text = "Ready"
    end
    
    -- Reset state
    refreshState = "idle"
    refreshGroups = {}
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