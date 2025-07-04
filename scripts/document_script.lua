-- TouchOSC Document Script
-- Version: 2.7.6
-- Fixed: Version logging respects DEBUG flag
-- Purpose: Manage document configuration and logging

local VERSION = "2.7.6"

-- Debug mode (set to 1 to enable logging)
local DEBUG = 0

-- Timer for automatic refresh
local AUTO_REFRESH_DELAY = 1000  -- 1 second after load
local last_refresh_time = 0
local startup_refresh_done = false

-- Configuration state
local configuration = {
    connections = {},
    unfold_tracks = {},
    raw_text = ""
}

-- Logger text object reference  
local loggerText = nil

-- CRITICAL FIX: Default connection must be 1, not 0
local DEFAULT_CONNECTION = 1

-- ===========================
-- LOGGING SYSTEM
-- ===========================

local function log(message)
    -- FIXED: Only log when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] Document Script: " .. message)
    end
end

local function updateLoggerText(message)
    if not loggerText then
        -- Try to find logger text object
        loggerText = root:findByName("logger_text", true)
    end
    
    if loggerText and loggerText.values and loggerText.values.text ~= nil then
        -- Prepend new message with timestamp
        local timestamp = os.date("%H:%M:%S.%03d", os.time())
        local newLine = timestamp .. " | " .. message .. "\n"
        
        -- Get existing text
        local existingText = loggerText.values.text or ""
        
        -- Limit log size (keep last 50 lines)
        local lines = {}
        for line in existingText:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
        
        -- Add new line at beginning
        table.insert(lines, 1, timestamp .. " | " .. message)
        
        -- Keep only last 50 lines
        while #lines > 50 do
            table.remove(lines)
        end
        
        -- Update text
        loggerText.values.text = table.concat(lines, "\n")
    end
end

-- ===========================
-- CONFIGURATION PARSING
-- ===========================

local function parseConfiguration(text)
    configuration.raw_text = text
    configuration.connections = {}
    configuration.unfold_tracks = {}
    
    local connectionCount = 0
    local unfoldCount = 0
    
    -- Parse each line
    for line in text:gmatch("[^\r\n]+") do
        -- Trim whitespace
        line = line:match("^%s*(.-)%s*$")
        
        -- Skip empty lines and comments
        if line ~= "" and not line:match("^#") then
            -- Parse connection_instance: number
            local instance, connection = line:match("^connection_(%w+):%s*(%d+)")
            if instance and connection then
                configuration.connections[instance] = tonumber(connection) or DEFAULT_CONNECTION
                connectionCount = connectionCount + 1
                log("Parsed connection: " .. instance .. " = " .. configuration.connections[instance])
            end
            
            -- Parse unfold_track: name
            local trackName = line:match("^unfold_track:%s*(.+)")
            if trackName then
                -- Clean the track name
                trackName = trackName:match("^%s*(.-)%s*$")
                table.insert(configuration.unfold_tracks, trackName)
                unfoldCount = unfoldCount + 1
                log("Parsed unfold track: " .. trackName)
            end
        end
    end
    
    log("Config parsed - " .. connectionCount .. " connections, " .. unfoldCount .. " unfolds")
    return configuration
end

-- ===========================
-- GROUP MANAGEMENT
-- ===========================

local function findAllGroups()
    local groups = {}
    
    -- Helper function to recursively find groups
    local function searchForGroups(parent)
        if parent.children then
            for i, child in ipairs(parent.children) do
                -- Check if this is a track group (has group_init script)
                if child.children then
                    for j, subchild in ipairs(child.children) do
                        if subchild.name == "group_init" and subchild.script then
                            table.insert(groups, child)
                            break
                        end
                    end
                end
                -- Recursively search children
                searchForGroups(child)
            end
        end
    end
    
    -- Start search from root
    searchForGroups(root)
    
    return groups
end

local function refreshAllGroups()
    log("=== REFRESH ALL GROUPS ===")
    
    local groups = findAllGroups()
    local refreshed = 0
    
    for _, group in ipairs(groups) do
        -- Send refresh notification to group
        group:notify("refresh", true)
        refreshed = refreshed + 1
    end
    
    log("Refreshed " .. refreshed .. " groups")
end

-- ===========================
-- CONTROL VALUE READING
-- ===========================

local function getControlText(control)
    if control and control.values and control.values.text then
        return control.values.text
    end
    return ""
end

-- ===========================
-- OSC HANDLING
-- ===========================

function onReceiveOSC(message, connections)
    -- Document script doesn't process OSC directly
    return false
end

-- ===========================
-- NOTIFY HANDLING
-- ===========================

function onReceiveNotify(key, value)
    if key == "configuration_changed" then
        -- Re-parse configuration
        local configControl = self:findByName("configuration", false)
        if configControl then
            local text = getControlText(configControl)
            parseConfiguration(text)
            log("Configuration updated")
        end
        
    elseif key == "refresh_all" then
        -- Manual refresh triggered
        refreshAllGroups()
        
    elseif key == "log_message" then
        -- Add log message from other scripts
        updateLoggerText(tostring(value))
    end
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    -- Check for automatic startup refresh
    if not startup_refresh_done then
        local now = getMillis()
        if now - last_refresh_time > AUTO_REFRESH_DELAY then
            log("=== AUTOMATIC STARTUP REFRESH ===")
            refreshAllGroups()
            startup_refresh_done = true
        end
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging only when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") Document Script v" .. VERSION)
    end
    
    -- Find configuration control
    local configControl = self:findByName("configuration", false)
    if configControl then
        local text = getControlText(configControl)
        parseConfiguration(text)
        log("Config parsed - " .. #configuration.connections .. " connections, " .. #configuration.unfold_tracks .. " unfolds")
    else
        log("WARNING: No configuration control found!")
    end
    
    -- Register with root for global access
    root.documentScript = self
    root.configuration = configuration
    log("Config registered")
    
    -- Verify registration
    if root.configuration then
        log("Config parsed - " .. #configuration.connections .. " connections, " .. #configuration.unfold_tracks .. " unfolds")
    end
    
    -- Schedule automatic refresh
    last_refresh_time = getMillis()
    log("Ready - automatic refresh scheduled...")
end

init()
