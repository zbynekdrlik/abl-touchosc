-- TouchOSC Group Initialization Script with Auto Track Type Detection
-- Version: 1.17.0
-- Changed: Don't send track name queries during refresh - document script handles it

-- Version constant
local SCRIPT_VERSION = "1.17.0"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- Script-level variables to store group data
local instance = nil
local trackName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local trackNumber = nil
local trackMapped = false
local lastEnabledState = nil
local trackType = nil  -- "track" or "return"
local listenersActive = false  -- Track if listeners are active

-- Activity tracking - simplified to only track receiving
local lastReceiveTime = 0

-- Local logging function
local function log(message)
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] GROUP(" .. self.name .. "): " .. message)
    end
end

-- Get connection configuration
local function getConnectionIndex(inst)
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
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

-- Safe child access helper
local function getChild(parent, name)
    if parent and parent.children and parent.children[name] then
        return parent.children[name]
    end
    return nil
end

-- Update status indicator based on activity
local function updateStatusIndicator()
    local indicator = getChild(self, "status_indicator")
    if not indicator then return end
    
    -- Check if mapped
    if trackMapped and trackNumber ~= nil then
        indicator.visible = true
        
        -- Determine current state based on receive activity only
        local currentTime = getMillis()
        local timeSinceReceive = currentTime - lastReceiveTime
        
        if timeSinceReceive < 150 then
            -- Recently received data - yellow
            indicator.color = Color(1, 1, 0, 1)
        elseif timeSinceReceive < 500 then
            -- Fading from yellow to green
            local fadeTime = timeSinceReceive - 150
            local fade = fadeTime / 350  -- 0 to 1 over 350ms
            -- Fade from yellow to green
            indicator.color = Color(1 * (1 - fade), 1, 0, 1)
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

-- Enable/disable interactive controls in the group
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
    
    -- Only set interactivity for controls that need it
    local interactiveControls = {"fader", "mute", "pan"}
    
    for _, name in ipairs(interactiveControls) do
        local child = getChild(self, name)
        if child then
            child.interactive = enabled
        end
    end
    
    -- Update status indicator immediately when enabling/disabling
    updateStatusIndicator()
end

-- Update connection label if it exists
local function updateConnectionLabel()
    local label = getChild(self, "connection_label")
    if label then
        label.values.text = instance  -- Will show "band" or "master"
    end
end

-- Clear all OSC listeners for safety
local function clearListeners()
    if trackNumber ~= nil and trackMapped and listenersActive then
        local targetConnections = buildConnectionTable(connectionIndex)
        
        -- Stop listeners based on track type
        local oscPrefix = trackType == "return" and "/live/return/" or "/live/track/"
        
        sendOSC(oscPrefix .. 'stop_listen/volume', trackNumber, targetConnections)
        sendOSC(oscPrefix .. 'stop_listen/output_meter_level', trackNumber, targetConnections)
        sendOSC(oscPrefix .. 'stop_listen/mute', trackNumber, targetConnections)
        sendOSC(oscPrefix .. 'stop_listen/panning', trackNumber, targetConnections)
        
        listenersActive = false
    end
end

-- Notify specific children about events
local function notifyChildren(event, value)
    -- Notify specific children we know about (fixed db_label -> db)
    local childrenToNotify = {"fader", "mute", "pan", "meter", "db"}
    
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
    log("Script v" .. SCRIPT_VERSION .. " loaded")
    
    -- Register this group with the document script
    root:notify("register_track_group", self)
    
    -- SAFETY: Disable all controls until properly mapped
    setGroupEnabled(false, true)  -- Silent
    
    -- Update connection label if it exists
    updateConnectionLabel()
    
    -- Initialize track label with the first word, skipping return track prefixes
    if self.children and self.children["track_label"] then
        local displayName = trackName
        
        -- Check if track name starts with single letter followed by hyphen (return track prefix)
        -- Pattern: ^%u%- matches uppercase letter followed by hyphen at start
        if trackName:match("^%u%-") then
            -- Skip the prefix (e.g., "A-") and get the rest
            displayName = trackName:sub(3)
        end
        
        -- Now get the first word from the display name
        local firstWord = displayName:match("(%w+)")
        if firstWord then
            self.children["track_label"].values.text = firstWord
        else
            -- Fallback to full name if no word found
            self.children["track_label"].values.text = displayName
        end
    end
    
    -- Initialize status indicator
    updateStatusIndicator()
end

-- Simplified update function - only check for fade animation
function update()
    -- Only update if we're in the fade window (150-500ms after receive)
    local timeSinceReceive = getMillis() - lastReceiveTime
    if timeSinceReceive >= 150 and timeSinceReceive <= 500 then
        updateStatusIndicator()
    end
end

function refreshTrackMapping()
    -- SAFETY: Clear any existing listeners and disable controls
    clearListeners()
    setGroupEnabled(false)
    
    needsRefresh = true
    trackMapped = false
    trackNumber = nil
    trackType = nil
    
    -- Don't query track names - document script will do it centrally
    -- Group will process the response when it arrives via onReceiveOSC
end

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Check for meter or volume data (activity detection)
    if trackMapped and trackNumber ~= nil and trackType then
        local oscPrefix = trackType == "return" and "/live/return/" or "/live/track/"
        
        -- Check for meter data
        if path == oscPrefix .. 'get/output_meter_level' then
            local trackIndex = message[2] and message[2][1] and message[2][1].value
            if trackIndex == trackNumber then
                lastReceiveTime = getMillis()
                updateStatusIndicator()
            end
        -- Check for volume data
        elseif path == oscPrefix .. 'get/volume' then
            local trackIndex = message[2] and message[2][1] and message[2][1].value
            if trackIndex == trackNumber then
                lastReceiveTime = getMillis()
                updateStatusIndicator()
            end
        end
    end
    
    -- Check if this is track names response (regular tracks)
    if path == '/live/song/get/track_names' then
        -- Only process if it's from our configured connection
        if not connections[connectionIndex] then 
            return true
        end
        
        if needsRefresh then
            local arguments = message[2]
            
            if arguments then
                for i = 1, #arguments do
                    if arguments[i] and arguments[i].value then
                        local trackNameValue = arguments[i].value
                        
                        -- EXACT match only for safety
                        if trackNameValue == trackName then
                            -- Found our track as a regular track
                            trackNumber = i - 1
                            trackType = "track"
                            lastVerified = getMillis()
                            trackMapped = true
                            needsRefresh = false  -- Found it, stop searching
                            
                            log("Mapped to track " .. trackNumber)
                            
                            setGroupEnabled(true)
                            
                            -- Store combined info in tag
                            self.tag = instance .. ":" .. trackNumber .. ":track"
                            
                            -- Notify children
                            notifyChildren("track_changed", trackNumber)
                            notifyChildren("track_type", trackType)
                            
                            -- Build connection table for our specific connection
                            local targetConnections = buildConnectionTable(connectionIndex)
                            
                            -- Start listeners for regular track
                            sendOSC('/live/track/start_listen/volume', trackNumber, targetConnections)
                            sendOSC('/live/track/start_listen/output_meter_level', trackNumber, targetConnections)
                            sendOSC('/live/track/start_listen/mute', trackNumber, targetConnections)
                            sendOSC('/live/track/start_listen/panning', trackNumber, targetConnections)
                            
                            listenersActive = true
                            
                            return true
                        end
                    end
                end
            end
        end
    end
    
    -- Check if this is return track names response
    if path == '/live/song/get/return_track_names' then
        -- Only process if it's from our configured connection
        if not connections[connectionIndex] then 
            return true
        end
        
        if needsRefresh then
            local arguments = message[2]
            
            if arguments then
                for i = 1, #arguments do
                    if arguments[i] and arguments[i].value then
                        local returnNameValue = arguments[i].value
                        
                        -- EXACT match only for safety
                        if returnNameValue == trackName then
                            -- Found our track as a return track
                            trackNumber = i - 1
                            trackType = "return"
                            lastVerified = getMillis()
                            trackMapped = true
                            needsRefresh = false
                            
                            log("Mapped to return " .. trackNumber)
                            
                            setGroupEnabled(true)
                            
                            -- Store combined info in tag
                            self.tag = instance .. ":" .. trackNumber .. ":return"
                            
                            -- Notify children
                            notifyChildren("track_changed", trackNumber)
                            notifyChildren("track_type", trackType)
                            
                            -- Build connection table for our specific connection
                            local targetConnections = buildConnectionTable(connectionIndex)
                            
                            -- Start listeners for return track
                            sendOSC('/live/return/start_listen/volume', trackNumber, targetConnections)
                            sendOSC('/live/return/start_listen/output_meter_level', trackNumber, targetConnections)
                            sendOSC('/live/return/start_listen/mute', trackNumber, targetConnections)
                            sendOSC('/live/return/start_listen/panning', trackNumber, targetConnections)
                            
                            listenersActive = true
                            
                            return true
                        end
                    end
                end
            end
            
            -- If we've checked both regular and return tracks and didn't find it
            if needsRefresh then
                log("Track not found: " .. trackName)
                setGroupEnabled(false)
                trackNumber = nil
                trackType = nil
                needsRefresh = false
                
                -- Notify children
                notifyChildren("track_unmapped", nil)
            end
        end
    end
    
    return false
end

function onReceiveNotify(action)
    if action == "refresh" or action == "refresh_tracks" then
        refreshTrackMapping()
    elseif action == "clear_mapping" then
        -- Clear listeners
        clearListeners()
        
        -- Reset state
        trackMapped = false
        trackNumber = nil
        trackType = nil
        listenersActive = false
        
        -- IMPORTANT: Reset tag to prevent stale references
        self.tag = "trackGroup"
        
        -- Notify children that mapping has been cleared
        notifyChildren("mapping_cleared", nil)
        
        -- Disable controls
        setGroupEnabled(false)
        
        -- Update status indicator
        updateStatusIndicator()
        
        log("Mapping cleared")
    end
end

-- Function to get track type (called by children)
function getTrackType()
    return trackType
end