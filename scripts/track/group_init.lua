-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.5.3
-- Fixed: Safe iteration over children, proper error handling

-- Version constant
local SCRIPT_VERSION = "1.5.3"

-- Script-level variables to store group data
local instance = nil
local trackName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local trackNumber = nil
local trackMapped = false

-- Local logger function
local function log(...)
    local timestamp = os.date("%H:%M:%S")
    local args = {...}
    local message = "[" .. timestamp .. "] "
    
    for i, v in ipairs(args) do
        message = message .. tostring(v)
        if i < #args then message = message .. " " end
    end
    
    print(message)
    
    -- Update logger if exists
    local loggerObj = root:findByName("logger", true)  -- recursive search
    if loggerObj and loggerObj.values then
        local currentText = loggerObj.values.text or ""
        local lines = {}
        for line in currentText:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        table.insert(lines, message)
        -- Keep last 60 lines to match document script
        while #lines > 60 do
            table.remove(lines, 1)
        end
        loggerObj.values.text = table.concat(lines, "\n")
    end
end

-- Get connection configuration
local function getConnectionIndex(inst)
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        log("Warning: No configuration found, using default connection 1")
        return 1
    end
    
    local configText = configObj.values.text
    local searchKey = "connection_" .. inst .. ":"
    
    for line in configText:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line:sub(1, #searchKey) == searchKey then
            local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
            return tonumber(value) or 1
        end
    end
    
    log("Warning: No config for " .. inst .. " - using default (1)")
    return 1
end

local function buildConnectionTable(connIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connIndex)
    end
    return connections
end

local function parseGroupName(name)
    if name:sub(1, 5) == "band_" then
        return "band", name:sub(6)
    elseif name:sub(1, 7) == "master_" then
        return "master", name:sub(8)
    else
        return "band", name
    end
end

-- Enable/disable all controls in the group
local function setGroupEnabled(enabled)
    -- Check if we have children
    if not self.children then
        return
    end
    
    -- Safe iteration - handle both array-like and object-like structures
    local childCount = 0
    
    -- Try numeric indices first
    local i = 1
    while self.children[i] do
        local child = self.children[i]
        
        -- Skip status indicators and labels
        if child.name ~= "status_indicator" and child.name ~= "track_label" then
            -- Disable interaction
            child.interactive = enabled
            
            -- Visual feedback - dim when disabled
            if child.color then
                if enabled then
                    -- Restore normal appearance
                    child.color = Color(1, 1, 1, 1)
                else
                    -- Dim to show disabled
                    child.color = Color(0.3, 0.3, 0.3, 0.5)
                end
            end
            
            -- For faders specifically, reset to 0 when disabled
            if not enabled and child.values and child.values.x then
                child.values.x = 0
            end
            
            childCount = childCount + 1
        end
        
        i = i + 1
    end
    
    log(self.name .. " controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. childCount .. " controls)")
end

-- Update visual status (minimal - just LED if present)
local function updateStatus(status)
    if self.children and self.children.status_indicator then
        if status == "ok" then
            self.children.status_indicator.color = Color(0, 1, 0, 1)  -- Green
        elseif status == "error" then
            self.children.status_indicator.color = Color(1, 0, 0, 1)  -- Red
        elseif status == "stale" then
            self.children.status_indicator.color = Color(1, 0.5, 0, 1)  -- Orange
        end
    end
end

-- Clear all OSC listeners for safety
local function clearListeners()
    if trackNumber and trackMapped then
        local targetConnections = buildConnectionTable(connectionIndex)
        
        -- Stop all listeners for the old track
        sendOSC('/live/track/stop_listen/volume', trackNumber, targetConnections)
        sendOSC('/live/track/stop_listen/output_meter_level', trackNumber, targetConnections)
        sendOSC('/live/track/stop_listen/mute', trackNumber, targetConnections)
        sendOSC('/live/track/stop_listen/panning', trackNumber, targetConnections)
        
        log("Stopped listeners for track " .. trackNumber)
    end
end

function init()
    -- Version logging moved here
    log("Group init v" .. SCRIPT_VERSION .. " for " .. self.name)
    log("Initializing group: " .. self.name)
    
    -- Set tag programmatically
    self.tag = "trackGroup"
    
    -- Parse group name and store in script variables
    instance, trackName = parseGroupName(self.name)
    connectionIndex = getConnectionIndex(instance)
    
    log("Group config - Instance: " .. instance .. ", Track: " .. trackName .. ", Connection: " .. connectionIndex)
    
    -- SAFETY: Disable all controls until properly mapped
    setGroupEnabled(false)
    
    -- Note: OSC routing must be configured in TouchOSC editor
    log("NOTE: Ensure group has OSC receive pattern: /live/song/get/track_names")
    
    -- Don't do initial refresh - wait for global refresh or manual trigger
    log("Group ready - waiting for refresh")
end

function refreshTrackMapping()
    log("Refreshing " .. self.name)
    
    -- SAFETY: Clear any existing listeners and disable controls
    clearListeners()
    setGroupEnabled(false)
    
    needsRefresh = true
    trackMapped = false
    trackNumber = nil  -- Clear old track number
    
    -- Build connection table for our specific connection
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send track names request to specific connection
    sendOSC('/live/song/get/track_names', connections)
end

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Check if this is track names response
    if path == '/live/song/get/track_names' then
        -- Only process if it's from our configured connection
        if not connections[connectionIndex] then 
            return true
        end
        
        if needsRefresh then
            local arguments = message[2]
            
            if not arguments then
                log("ERROR: No track names in response for " .. self.name)
                updateStatus("error")
                setGroupEnabled(false)  -- Keep disabled
                return true
            end
            
            local trackFound = false
            
            for i = 1, #arguments do
                if arguments[i] and arguments[i].value then
                    local trackNameValue = arguments[i].value
                    
                    -- EXACT match only for safety
                    if trackNameValue == trackName then
                        -- Found our track
                        trackNumber = i - 1
                        lastVerified = getMillis()
                        needsRefresh = false
                        trackFound = true
                        trackMapped = true
                        
                        log("Mapped " .. self.name .. " -> Track " .. trackNumber)
                        
                        updateStatus("ok")
                        setGroupEnabled(true)  -- ENABLE controls now that mapping is correct
                        
                        -- Store combined info in tag
                        self.tag = instance .. ":" .. trackNumber
                        
                        -- Build connection table for our specific connection
                        local targetConnections = buildConnectionTable(connectionIndex)
                        
                        -- Start listeners - send only to our configured connection
                        sendOSC('/live/track/start_listen/volume', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/output_meter_level', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/mute', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/panning', trackNumber, targetConnections)
                        
                        -- Update label if it exists
                        if self.children and self.children.track_label then
                            local displayName = trackName:match("([^#]+)") or trackName
                            displayName = displayName:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
                            self.children.track_label.values.text = displayName
                        end
                        break
                    end
                end
            end
            
            if not trackFound then
                log("ERROR: Track not found: '" .. trackName .. "' for " .. self.name)
                updateStatus("error")
                setGroupEnabled(false)  -- Keep disabled for safety
                trackNumber = nil  -- Clear any old track number
                
                if self.children and self.children.track_label then
                    self.children.track_label.values.text = "???"
                end
            end
            
            return true
        end
    end
    
    return false
end

function onReceiveNotify(action)
    if action == "refresh" or action == "refresh_tracks" then
        refreshTrackMapping()
    elseif action == "clear_mapping" then
        clearListeners()
        trackMapped = false
        trackNumber = nil
    end
end

function update()
    -- Additional safety check - if not mapped, ensure controls stay disabled
    if not trackMapped then
        setGroupEnabled(false)
    end
    
    -- Visual feedback for stale data
    if trackMapped and lastVerified > 0 then
        local age = getMillis() - lastVerified
        if age > 300000 then  -- 5 minutes
            updateStatus("stale")
        end
    end
end