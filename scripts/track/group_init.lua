-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.9.5
-- Fixed: Ensure track_label updates even when refresh returns early

-- Version constant
local SCRIPT_VERSION = "1.9.5"

-- Script-level variables to store group data
local instance = nil
local trackName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local trackNumber = nil
local trackMapped = false
local lastEnabledState = nil  -- Track last state to prevent spam

-- Centralized logging through document script
local function log(message)
    -- Add context to identify which control sent the log
    local fullMessage = "CONTROL(" .. self.name .. ") " .. message
    
    -- Send to document script for proper logging
    root:notify("log_message", fullMessage)
    
    -- Also print to console for immediate feedback during development
    print("[" .. os.date("%H:%M:%S") .. "] " .. fullMessage)
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

-- Safe child access helper - no pcall, just direct checks
local function getChild(parent, name)
    if parent and parent.children and parent.children[name] then
        return parent.children[name]
    end
    return nil
end

-- Enable/disable all controls in the group - ONLY INTERACTIVITY
local function setGroupEnabled(enabled, silent)
    -- Skip if state hasn't changed to prevent spam
    if lastEnabledState == enabled then
        return
    end
    
    lastEnabledState = enabled
    
    -- Check if we have children
    if not self.children then
        return
    end
    
    local childCount = 0
    
    -- Only check for controls we know exist
    local controlsToCheck = {"fader", "mute", "pan", "meter", "track_label"}
    
    for _, name in ipairs(controlsToCheck) do
        local child = getChild(self, name)
        if child and name ~= "status_indicator" then
            -- ONLY CHANGE INTERACTIVITY - NO VISUAL CHANGES!
            child.interactive = enabled
            childCount = childCount + 1
        end
    end
    
    -- Only log if not silent
    if not silent then
        log("controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. childCount .. " controls)")
    end
end

-- Update visual status (minimal - just LED if present)
local function updateStatus(status)
    local indicator = getChild(self, "status_indicator")
    if indicator then
        if status == "ok" then
            indicator.color = Color(0, 1, 0, 1)  -- Green
        elseif status == "error" then
            indicator.color = Color(1, 0, 0, 1)  -- Red
        elseif status == "stale" then
            indicator.color = Color(1, 0.5, 0, 1)  -- Orange
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
    -- Set tag programmatically
    self.tag = "trackGroup"
    
    -- Parse group name and store in script variables
    instance, trackName = parseGroupName(self.name)
    connectionIndex = getConnectionIndex(instance)
    
    -- Log initialization
    log("Group init v" .. SCRIPT_VERSION .. " loaded")
    log("Config - Instance: " .. instance .. ", Track: " .. trackName .. ", Connection: " .. connectionIndex)
    
    -- SAFETY: Disable all controls until properly mapped
    setGroupEnabled(false, true)  -- Silent
    
    -- Set initial status
    updateStatus("error")
    
    -- Debug: Check if track_label exists
    if self.children then
        if self.children["track_label"] then
            log("track_label found in init")
            if self.children["track_label"].values and self.children["track_label"].values.text ~= nil then
                log("track_label has values.text property")
            else
                log("WARNING: track_label missing values.text property")
            end
        else
            log("WARNING: track_label not found in children")
            -- List all children for debugging
            local childList = {}
            for name, _ in pairs(self.children) do
                table.insert(childList, name)
            end
            log("Available children: " .. table.concat(childList, ", "))
        end
    else
        log("WARNING: No children found")
    end
    
    log("Ready - waiting for refresh")
end

function refreshTrackMapping()
    log("Refreshing track mapping")
    
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
            needsRefresh = false  -- Clear flag immediately to prevent re-processing
            
            local arguments = message[2]
            
            if not arguments then
                log("ERROR: No track names in response")
                updateStatus("error")
                setGroupEnabled(false)  -- Keep disabled
                
                -- Update label to show error even when no arguments
                if self.children and self.children["track_label"] then
                    self.children["track_label"].values.text = "???"
                    log("track_label set to '???' (no track names)")
                end
                
                return true
            end
            
            local trackFound = false
            
            -- Debug: Log all track names received
            log("Searching for track: '" .. trackName .. "'")
            log("Available tracks:")
            for i = 1, #arguments do
                if arguments[i] and arguments[i].value then
                    log("  Track " .. (i-1) .. ": '" .. arguments[i].value .. "'")
                end
            end
            
            for i = 1, #arguments do
                if arguments[i] and arguments[i].value then
                    local trackNameValue = arguments[i].value
                    
                    -- EXACT match only for safety
                    if trackNameValue == trackName then
                        -- Found our track
                        trackNumber = i - 1
                        lastVerified = getMillis()
                        trackFound = true
                        trackMapped = true
                        
                        log("Mapped to Track " .. trackNumber)
                        
                        updateStatus("ok")
                        setGroupEnabled(true)  -- ENABLE controls now that mapping is correct
                        
                        -- Store combined info in tag
                        self.tag = instance .. ":" .. trackNumber
                        
                        -- Notify all child controls that track is mapped
                        if self.children then
                            for name, child in pairs(self.children) do
                                if child and child.notify then
                                    child:notify("track_changed", trackNumber)
                                end
                            end
                        end
                        
                        -- Build connection table for our specific connection
                        local targetConnections = buildConnectionTable(connectionIndex)
                        
                        -- Start listeners - send only to our configured connection
                        sendOSC('/live/track/start_listen/volume', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/output_meter_level', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/mute', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/panning', trackNumber, targetConnections)
                        
                        -- Update label using direct children access like original
                        if self.children and self.children["track_label"] then
                            -- Use pattern match that captures only word characters like original
                            local displayName = trackName:match("(%w+)")
                            if displayName then
                                log("Setting track_label to: '" .. displayName .. "'")
                                self.children["track_label"].values.text = displayName
                            else
                                log("Setting track_label to full name: '" .. trackName .. "'")
                                self.children["track_label"].values.text = trackName
                            end
                        else
                            log("WARNING: Cannot update track_label - not found")
                        end
                        break
                    end
                end
            end
            
            -- Handle track not found
            if not trackFound then
                log("ERROR: Track not found: '" .. trackName .. "'")
                updateStatus("error")
                setGroupEnabled(false)  -- Keep disabled for safety
                trackNumber = nil  -- Clear any old track number
                
                -- Notify children about unmapping
                if self.children then
                    for name, child in pairs(self.children) do
                        if child and child.notify then
                            child:notify("track_unmapped")
                        end
                    end
                end
                
                -- Update label to show error using direct access
                log("Attempting to set track_label to '???' (track not found)")
                if self.children then
                    if self.children["track_label"] then
                        if self.children["track_label"].values and self.children["track_label"].values.text ~= nil then
                            self.children["track_label"].values.text = "???"
                            log("track_label set to '???' successfully")
                        else
                            log("ERROR: track_label exists but has no values.text property")
                        end
                    else
                        log("ERROR: track_label not found in children")
                    end
                else
                    log("ERROR: No children found on group")
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
    -- Only check stale data if mapped
    if trackMapped and lastVerified > 0 then
        local age = getMillis() - lastVerified
        if age > 300000 then  -- 5 minutes
            updateStatus("stale")
        end
    end
end
