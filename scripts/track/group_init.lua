-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.6.0
-- Fixed: Use color transparency instead of alpha property

-- Version constant
local SCRIPT_VERSION = "1.6.0"

-- Script-level variables to store group data
local instance = nil
local trackName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local trackNumber = nil
local trackMapped = false
local lastEnabledState = nil  -- Track last state to prevent spam

-- Simple logging - just use print like the working scripts
local function log(message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. message)
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
    
    -- Safe iteration with bounds checking
    local i = 1
    local maxIterations = 20  -- Reduced since we know there are ~13 controls
    
    while i <= maxIterations do
        local child = self.children[i]
        if not child then
            break  -- No more children
        end
        
        -- Process all controls except status_indicator
        if child.name ~= "status_indicator" then
            -- Disable interaction
            child.interactive = enabled
            
            -- Visual feedback - use color with transparency
            if child.color then
                local r, g, b = child.color.r, child.color.g, child.color.b
                if enabled then
                    -- Restore full opacity
                    child.color = Color(r, g, b, 1.0)
                else
                    -- Dim with transparency (but don't change values!)
                    child.color = Color(r, g, b, 0.3)
                end
            end
            
            childCount = childCount + 1
        end
        
        i = i + 1
    end
    
    -- Only log if not silent
    if not silent then
        log(self.name .. " controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. childCount .. " controls)")
    end
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
    -- Set tag programmatically
    self.tag = "trackGroup"
    
    -- Parse group name and store in script variables
    instance, trackName = parseGroupName(self.name)
    connectionIndex = getConnectionIndex(instance)
    
    -- Log initialization
    log("Group init v" .. SCRIPT_VERSION .. " for " .. self.name)
    log("Group config - Instance: " .. instance .. ", Track: " .. trackName .. ", Connection: " .. connectionIndex)
    
    -- SAFETY: Disable all controls until properly mapped
    setGroupEnabled(false, true)  -- Silent
    
    -- Set initial status
    updateStatus("error")
    
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
                        
                        -- Update label if it exists - EXACT name only
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
    -- Only check stale data if mapped
    if trackMapped and lastVerified > 0 then
        local age = getMillis() - lastVerified
        if age > 300000 then  -- 5 minutes
            updateStatus("stale")
        end
    end
end