-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.2.5
-- Phase: 01 - Phase 1: Single Group Test with Refresh
-- Working within TouchOSC connection constraints

-- Version logging
local SCRIPT_VERSION = "1.2.5"

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
    log("IMPORTANT: Make sure this group's connections are set to use Connection " .. connectionIndex .. " in the UI")
    
    -- Initial track discovery
    refreshTrackMapping()
end

function refreshTrackMapping()
    log("Refreshing track mapping for: " .. self.name)
    needsRefresh = true
    
    -- Visual feedback
    if self.children.status_indicator then
        self.children.status_indicator.color = {1, 1, 0}  -- Yellow = refreshing
    end
    
    -- Request track names - will use whatever connections are set on this object in the UI
    sendOSC('/live/song/get/track_names')
    log("Sent track names request - waiting for response on connection " .. connectionIndex)
end

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Log which connections this message came from
    if path == '/live/song/get/track_names' then
        local activeConnections = {}
        for i = 1, 10 do
            if connections[i] then
                table.insert(activeConnections, i)
            end
        end
        log("Received track names from connections: " .. table.concat(activeConnections, ", "))
        
        -- Only process if it's from our configured connection
        if not connections[connectionIndex] then 
            log("Ignoring - not from our connection (" .. connectionIndex .. ")")
            return 
        end
        
        if needsRefresh then
            local arguments = message[2]
            
            if not arguments then
                log("ERROR: No track names received")
                return
            end
            
            local trackFound = false
            
            for i = 1, #arguments do
                if arguments[i] and arguments[i].value == trackName then
                    -- Found our track
                    trackNumber = i - 1
                    lastVerified = getMillis()
                    needsRefresh = false
                    trackFound = true
                    
                    log("Found track '" .. trackName .. "' at index " .. trackNumber)
                    
                    -- Update status
                    if self.children.status_indicator then
                        self.children.status_indicator.color = {0, 1, 0}  -- Green = OK
                    end
                    
                    -- Store combined info in tag
                    self.tag = instance .. ":" .. trackNumber
                    
                    -- Start listeners
                    sendOSC('/live/track/start_listen/volume', trackNumber)
                    sendOSC('/live/track/start_listen/output_meter_level', trackNumber)
                    sendOSC('/live/track/start_listen/mute', trackNumber)
                    sendOSC('/live/track/start_listen/panning', trackNumber)
                    
                    -- Update label
                    if self.children["fdr_label"] then
                        self.children["fdr_label"].values.text = trackName:match("(%w+)(.*)")
                    end
                    break
                end
            end
            
            if not trackFound then
                -- Track not found
                log("ERROR: Track not found: " .. trackName)
                log("Available tracks:")
                for i = 1, #arguments do
                    if arguments[i] and arguments[i].value then
                        log("  " .. i-1 .. ": " .. arguments[i].value)
                    end
                end
                
                if self.children["fdr_label"] then
                    self.children["fdr_label"].values.text = "???"
                end
                if self.children.status_indicator then
                    self.children.status_indicator.color = {1, 0, 0}  -- Red = Error
                end
            end
        end
    end
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
            self.children.status_indicator.color = {1, 0.5, 0}  -- Orange = Stale
        end
    end
end

log("Group initialization script ready")
