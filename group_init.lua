-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.4.3
-- Phase: 01 - Phase 1: Single Group Test with Refresh
-- Fixed OSC routing to ensure group receives messages

-- Version logging
local SCRIPT_VERSION = "1.4.3"

-- Script-level variables to store group data
local instance = nil
local trackName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local trackNumber = nil

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
    local loggerObj = root:findByName("logger")
    if loggerObj and loggerObj.values then
        local currentText = loggerObj.values.text or ""
        local lines = {}
        for line in currentText:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        table.insert(lines, message)
        -- Keep last 20 lines
        while #lines > 20 do
            table.remove(lines, 1)
        end
        loggerObj.values.text = table.concat(lines, "\n")
    end
end

-- Get connection configuration
local function getConnectionIndex(inst)
    local configObj = root:findByName("configuration")
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

log("Group init v" .. SCRIPT_VERSION .. " for " .. self.name)

function init()
    log("Initializing group: " .. self.name)
    
    -- Set tag programmatically
    self.tag = "trackGroup"
    
    -- Parse group name and store in script variables
    instance, trackName = parseGroupName(self.name)
    connectionIndex = getConnectionIndex(instance)
    lastVerified = getMillis()
    
    log("Group config - Instance: " .. instance .. ", Track: " .. trackName .. ", Connection: " .. connectionIndex)
    
    -- Important: Set OSC receive routing to match our track names request
    -- This ensures this control receives the /live/song/get/track_names response
    if self.properties and self.properties.OSCReceive then
        self.properties.OSCReceive = "/live/song/get/track_names"
        log("Set OSC receive pattern to: /live/song/get/track_names")
    end
    
    -- Initial track discovery
    refreshTrackMapping()
end

function refreshTrackMapping()
    log("Refreshing track mapping for: " .. self.name)
    needsRefresh = true
    
    -- Visual feedback - use Color() function!
    if self.children.status_indicator then
        self.children.status_indicator.color = Color(1, 1, 0, 1)  -- Yellow = refreshing (RGBA)
    end
    
    -- Build connection table for our specific connection
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send track names request to specific connection
    sendOSC('/live/song/get/track_names', connections)
    
    log("Sent track names request to connection " .. connectionIndex)
    log("Waiting for response...")
end

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Debug log ALL incoming OSC messages
    if path then
        local conns = {}
        for i = 1, 10 do
            if connections[i] then table.insert(conns, i) end
        end
        log("DEBUG: Received OSC at " .. self.name .. ": " .. path .. " from connection(s): " .. table.concat(conns, ","))
    end
    
    -- Check if this is track names response
    if path == '/live/song/get/track_names' then
        log("Track names response received!")
        
        -- Log which connections this came from
        for i = 1, 10 do
            if connections[i] then
                log("  From connection " .. i)
            end
        end
        
        -- Only process if it's from our configured connection
        if not connections[connectionIndex] then 
            log("Ignoring - not from our connection (" .. connectionIndex .. ")")
            return true -- Return true to stop further processing
        end
        
        if needsRefresh then
            local arguments = message[2]
            
            if not arguments then
                log("ERROR: No track names in response")
                return true
            end
            
            log("Processing " .. #arguments .. " track names...")
            
            local trackFound = false
            
            for i = 1, #arguments do
                if arguments[i] and arguments[i].value then
                    local trackNameValue = arguments[i].value
                    log("  Track " .. (i-1) .. ": " .. trackNameValue)
                    
                    if trackNameValue == trackName then
                        -- Found our track
                        trackNumber = i - 1
                        lastVerified = getMillis()
                        needsRefresh = false
                        trackFound = true
                        
                        log("FOUND our track '" .. trackName .. "' at index " .. trackNumber .. "!")
                        
                        -- Update status - use Color() function!
                        if self.children.status_indicator then
                            self.children.status_indicator.color = Color(0, 1, 0, 1)  -- Green = OK (RGBA)
                        end
                        
                        -- Store combined info in tag
                        self.tag = instance .. ":" .. trackNumber
                        
                        -- Build connection table for our specific connection
                        local targetConnections = buildConnectionTable(connectionIndex)
                        
                        -- Start listeners - send only to our configured connection
                        sendOSC('/live/track/start_listen/volume', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/output_meter_level', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/mute', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/panning', trackNumber, targetConnections)
                        
                        log("Started listeners for track " .. trackNumber)
                        
                        -- Update label
                        if self.children["fdr_label"] then
                            self.children["fdr_label"].values.text = trackName:match("(%w+)(.*)")
                        end
                        break
                    end
                end
            end
            
            if not trackFound then
                -- Track not found
                log("ERROR: Track not found: " .. trackName)
                
                if self.children["fdr_label"] then
                    self.children["fdr_label"].values.text = "???"
                end
                if self.children.status_indicator then
                    self.children.status_indicator.color = Color(1, 0, 0, 1)  -- Red = Error (RGBA)
                end
            end
            
            return true -- Message processed, stop further processing
        else
            log("Received track names but not in refresh mode - ignoring")
            return true
        end
    end
    
    -- Return false for messages we don't handle to allow further processing
    return false
end

function onNotify(param)
    if param == "refresh" then
        log("Received refresh notification for " .. self.name)
        refreshTrackMapping()
    end
end

function update()
    -- Visual feedback for stale data
    if lastVerified > 0 then
        local age = getMillis() - lastVerified
        if age > 60000 and self.children.status_indicator then  -- 1 minute
            self.children.status_indicator.color = Color(1, 0.5, 0, 1)  -- Orange = Stale (RGBA)
        end
    end
end

log("Group initialization script ready")
log("Selective connection routing is ACTIVE!")
log("Script version " .. SCRIPT_VERSION .. " loaded")