-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.13.1
-- Fixed: Runtime error with schedule method

-- Version constant
local SCRIPT_VERSION = "1.13.1"

-- Script-level variables to store group data
local instance = nil
local trackName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local trackNumber = nil
local trackMapped = false
local lastEnabledState = nil  -- Track last state to prevent spam

-- Activity tracking
local lastSendTime = 0
local lastReceiveTime = 0
local lastFaderValue = nil

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

-- Forward declaration for monitorActivity
local monitorActivity

-- Update status indicator based on activity
local function updateStatusIndicator()
    local indicator = getChild(self, "status_indicator")
    if not indicator then return end
    
    local currentTime = getMillis()
    local timeSinceSend = currentTime - lastSendTime
    local timeSinceReceive = currentTime - lastReceiveTime
    
    -- Check if mapped
    if trackMapped and trackNumber then
        indicator.visible = true
        
        -- Determine current state based on activity
        if timeSinceSend < 150 then
            -- Recently sent data - blue
            indicator.color = Color(0, 0.5, 1, 1)
        elseif timeSinceReceive < 150 then
            -- Recently received data - yellow
            indicator.color = Color(1, 1, 0, 1)
        elseif timeSinceSend < 500 or timeSinceReceive < 500 then
            -- Fading from active to idle
            local fadeTime = math.min(timeSinceSend, timeSinceReceive) - 150
            local fade = fadeTime / 350  -- 0 to 1 over 350ms
            
            if timeSinceSend < timeSinceReceive then
                -- Fade from blue to green
                indicator.color = Color(0, 0.5 * (1 - fade) + fade, 1 * (1 - fade) + fade * 0, 1)
            else
                -- Fade from yellow to green
                indicator.color = Color(1 * (1 - fade), 1, 0, 1)
            end
        else
            -- Idle - solid green
            indicator.color = Color(0, 1, 0, 1)
        end
    else
        -- Not mapped - red
        indicator.visible = true
        indicator.color = Color(1, 0, 0, 1)
    end
end

-- Monitor fader for outgoing activity
monitorActivity = function()
    local currentTime = getMillis()
    
    -- Check fader for changes (outgoing data)
    local fader = getChild(self, "fader")
    if fader and fader.values and fader.values.x then
        local currentValue = fader.values.x
        if lastFaderValue and math.abs(currentValue - lastFaderValue) > 0.001 then
            lastSendTime = currentTime
            -- log("Fader movement detected")
        end
        lastFaderValue = currentValue
    end
    
    -- Update status indicator
    updateStatusIndicator()
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
    local controlsToCheck = {"fader", "mute", "pan", "meter", "track_label", "db_label"}
    
    for _, name in ipairs(controlsToCheck) do
        local child = getChild(self, name)
        if child and name ~= "status_indicator" and name ~= "connection_label" then
            -- ONLY CHANGE INTERACTIVITY - NO VISUAL CHANGES!
            child.interactive = enabled
            childCount = childCount + 1
        end
    end
    
    -- Update status indicator
    updateStatusIndicator()
    
    -- Only log if not silent
    if not silent then
        log("controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. childCount .. " controls)")
    end
end

-- Update connection label if it exists
local function updateConnectionLabel()
    local label = getChild(self, "connection_label")
    if label then
        label.values.text = instance  -- Will show "band" or "master"
        log("Connection label set to: " .. instance)
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

-- Notify specific children about events
local function notifyChildren(event, value)
    -- Notify specific children we know about
    local childrenToNotify = {"fader", "mute", "pan", "meter", "db_label"}
    
    for _, name in ipairs(childrenToNotify) do
        local child = getChild(self, name)
        if child and child.notify then
            child:notify(event, value)
        end
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
    
    -- Update connection label if it exists
    updateConnectionLabel()
    
    -- Initialize track label with the expected track name (not ???)
    if self.children and self.children["track_label"] then
        -- Use pattern match that captures only word characters
        local displayName = trackName:match("(%w+)")
        if displayName then
            self.children["track_label"].values.text = displayName
        else
            self.children["track_label"].values.text = trackName
        end
    end
    
    log("Ready - waiting for refresh")
end

-- Use update() function instead of schedule for periodic monitoring
function update()
    -- Monitor activity periodically
    monitorActivity()
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
    
    -- Check for meter or volume data (activity detection)
    if trackMapped and trackNumber then
        if path == '/live/track/meter' then
            local trackIndex = message[2] and message[2].value
            if trackIndex == trackNumber then
                lastReceiveTime = getMillis()
                -- log("Received meter data for track " .. trackIndex)
            end
        elseif path == '/live/track/volume' then
            local trackIndex = message[2] and message[2].value
            if trackIndex == trackNumber then
                lastReceiveTime = getMillis()
                -- log("Received volume data for track " .. trackIndex)
            end
        end
    end
    
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
                setGroupEnabled(false)  -- Keep disabled
                -- Don't change track label - keep showing expected name
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
                        trackFound = true
                        trackMapped = true
                        
                        log("Mapped to Track " .. trackNumber)
                        
                        setGroupEnabled(true)  -- ENABLE controls and show indicator
                        
                        -- Store combined info in tag
                        self.tag = instance .. ":" .. trackNumber
                        
                        -- Notify children using safe method
                        notifyChildren("track_changed", trackNumber)
                        
                        -- Build connection table for our specific connection
                        local targetConnections = buildConnectionTable(connectionIndex)
                        
                        -- Start listeners - send only to our configured connection
                        sendOSC('/live/track/start_listen/volume', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/output_meter_level', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/mute', trackNumber, targetConnections)
                        sendOSC('/live/track/start_listen/panning', trackNumber, targetConnections)
                        
                        break
                    end
                end
            end
            
            -- Handle track not found
            if not trackFound then
                log("ERROR: Track not found: '" .. trackName .. "'")
                setGroupEnabled(false)  -- Keep disabled and hide indicator
                trackNumber = nil  -- Clear any old track number
                
                -- Notify children using safe method
                notifyChildren("track_unmapped", nil)
                
                -- Don't change track label - keep showing expected name
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
