-- TouchOSC Track Group Initialization Script
-- Version: 1.15.6
-- Fixed: Added back track discovery mechanism (was completely missing!)
-- Optimized: Time-based activity monitoring instead of continuous updates
-- Fixed: Schedule method not available - using time-based update checks
-- Fixed: Parse tag for track info to support both regular and return tracks
-- Added: Return track type support

-- Version constant
local VERSION = "1.15.6"

-- Debug mode (set to 1 for debug output)
local DEBUG = 0

-- Global debounce settings (in seconds)
local GLOBAL_DEBOUNCE_TIME = 0.05    -- 50ms debounce for all controls
local MAPPING_CHANGE_DEBOUNCE = 0.1  -- 100ms debounce for track mapping changes

-- Activity monitoring settings
local INACTIVITY_TIMEOUT = 4         -- 4 seconds until fade starts
local FADE_DURATION = 1              -- 1 second to fade out
local ACTIVITY_CHECK_INTERVAL = 100  -- Check every 100ms
local FADE_ALPHA = 0.6               -- Fade to 60% opacity

-- ===========================
-- DEBUG LOGGING
-- ===========================

local function debug(...)
    if DEBUG == 0 then return end
    
    local args = {...}
    local msg = table.concat(args, " ")
    
    -- Use group name for context
    local context = "GROUP"
    if self.name then
        context = "GROUP(" .. self.name .. ")"
    end
    
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. msg)
end

local function log(message)
    -- Always log important messages
    local context = "CONTROL(" .. self.name .. ")"
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. " " .. message)
end

-- ===========================
-- STATE VARIABLES
-- ===========================

-- Track discovery state
local instance = nil
local trackName = nil
local connectionIndex = nil
local needsRefresh = false
local listenersActive = false

-- Track mapping state
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local trackMapped = false
local lastMappingChangeTime = 0

-- Activity monitoring
local lastActivityTime = 0
local isActive = true
local isFaded = false
local fadeStartTime = 0
local isFadingOut = false
local isFadingIn = false
local lastActivityCheck = 0  -- For time-based checking

-- Child controls
local childControls = {}

-- ===========================
-- PARSE GROUP NAME
-- ===========================

local function parseGroupName(name)
    if name:sub(1, 5) == "band_" then
        return "band", name:sub(6)
    elseif name:sub(1, 7) == "master_" then
        return "master", name:sub(8)
    else
        return "band", name
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

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

-- ===========================
-- DEBOUNCE HELPER
-- ===========================

local function debounce(key, delay)
    local now = os.clock()
    if not _G.debounceTimers then
        _G.debounceTimers = {}
    end
    
    if _G.debounceTimers[key] then
        if now - _G.debounceTimers[key] < delay then
            return true  -- Still in debounce period
        end
    end
    
    _G.debounceTimers[key] = now
    return false  -- Not debounced
end

-- ===========================
-- CHILD CONTROL MANAGEMENT
-- ===========================

local function discoverChildControls()
    childControls = {}
    
    -- Find all relevant child controls
    local controlNames = {"fader", "pan", "meter", "db", "db_meter_label", "mute", "track_label"}
    
    for _, name in ipairs(controlNames) do
        local control = self:findByName(name, false)  -- Non-recursive search
        if control then
            table.insert(childControls, control)
            debug("Found child control:", name)
        end
    end
    
    debug(string.format("Discovered %d child controls", #childControls))
end

local function setGroupEnabled(enabled, silent)
    -- Enable/disable child controls using interactive property
    local childCount = 0
    
    for _, control in ipairs(childControls) do
        if control.name ~= "status_indicator" and control.name ~= "connection_label" then
            control.interactive = enabled
            childCount = childCount + 1
        end
    end
    
    if not silent then
        log("controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. childCount .. " controls)")
    end
end

local function notifyChildren(event, value)
    -- Notify all child controls
    for _, control in ipairs(childControls) do
        if control.notify then
            control:notify(event, value)
        end
    end
end

-- ===========================
-- TRACK DISCOVERY
-- ===========================

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
        debug("Stopped listeners for " .. trackType .. " " .. trackNumber)
    end
end

function refreshTrackMapping()
    log("Refreshing track mapping with auto-detection")
    
    -- Clear any existing listeners and disable controls
    clearListeners()
    setGroupEnabled(false)
    
    needsRefresh = true
    trackMapped = false
    trackNumber = nil
    trackType = nil
    
    -- Build connection table for our specific connection
    local connections = buildConnectionTable(connectionIndex)
    
    -- Query both regular tracks and return tracks
    sendOSC('/live/song/get/track_names', connections)
    sendOSC('/live/song/get/return_track_names', connections)
end

-- ===========================
-- ACTIVITY MONITORING
-- ===========================

function recordActivity()
    if not isActive then
        isActive = true
        isFadingOut = false
        isFadingIn = true
        fadeStartTime = os.clock()
        debug("Activity detected - fading in")
    end
    lastActivityTime = os.clock()
end

function monitorActivity()
    local now = os.clock()
    local timeSinceActivity = now - lastActivityTime
    
    if isActive and timeSinceActivity > INACTIVITY_TIMEOUT then
        -- Start fading out
        isActive = false
        isFadingOut = true
        isFadingIn = false
        fadeStartTime = now
        debug("Inactivity detected - starting fade out")
    end
    
    -- Handle fade animations
    if isFadingOut or isFadingIn then
        local fadeProgress = (now - fadeStartTime) / FADE_DURATION
        fadeProgress = math.min(1, math.max(0, fadeProgress))
        
        local alpha
        if isFadingOut then
            alpha = 1 - (fadeProgress * (1 - FADE_ALPHA))
            if fadeProgress >= 1 then
                isFadingOut = false
                isFaded = true
                alpha = FADE_ALPHA
                debug("Fade out complete")
            end
        else  -- Fading in
            alpha = FADE_ALPHA + (fadeProgress * (1 - FADE_ALPHA))
            if fadeProgress >= 1 then
                isFadingIn = false
                isFaded = false
                alpha = 1
                debug("Fade in complete")
            end
        end
        
        -- Apply fade to all children
        for _, control in ipairs(childControls) do
            local color = control.color
            if color then
                control.color = Color(color.r, color.g, color.b, alpha)
            end
        end
        
        -- Also fade the group background if it has one
        if self.color then
            local color = self.color
            self.color = Color(color.r, color.g, color.b, alpha * 0.5)  -- Group more transparent
        end
    end
end

-- ===========================
-- OSC HANDLER
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Any OSC activity keeps the group active
    recordActivity()
    
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
                            trackMapped = true
                            needsRefresh = false  -- Found it, stop searching
                            
                            log("Mapped to Regular Track " .. trackNumber)
                            
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
                            trackMapped = true
                            needsRefresh = false
                            
                            log("Mapped to Return Track " .. trackNumber)
                            
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
                log("ERROR: Track not found: '" .. trackName .. "' (checked both regular and return tracks)")
                setGroupEnabled(false)
                trackNumber = nil
                trackType = nil
                needsRefresh = false
                
                -- Notify children
                notifyChildren("track_unmapped", nil)
            end
        end
    end
    
    return false  -- Don't consume the message
end

-- ===========================
-- NOTIFY HANDLERS
-- ===========================

function onReceiveNotify(key, value)
    if key == "refresh" or key == "refresh_tracks" or key == "refresh_group" then
        refreshTrackMapping()
    elseif key == "clear_mapping" then
        clearListeners()
        trackMapped = false
        trackNumber = nil
        trackType = nil
        listenersActive = false
    elseif key == "value_changed" then
        -- Child control value changed
        recordActivity()
        
        -- Apply global debounce
        if debounce(self.name .. "_activity", GLOBAL_DEBOUNCE_TIME) then
            debug("Activity debounced")
            return
        end
        
        debug("Control value changed - activity recorded")
    elseif key == "log_message" then
        -- Message for central logger (ignored in optimized version)
        return
    end
end

-- ===========================
-- TOUCH HANDLING
-- ===========================

function onValueChanged(valueName)
    if valueName == "touch" then
        recordActivity()
    end
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    local now = getMillis()
    
    -- Only run activity monitoring at specified intervals
    if (now - lastActivityCheck) >= ACTIVITY_CHECK_INTERVAL then
        monitorActivity()
        lastActivityCheck = now
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Group v" .. VERSION .. " loaded")
    
    -- Parse group name and get configuration
    instance, trackName = parseGroupName(self.name)
    connectionIndex = getConnectionIndex(instance)
    
    log("Config - Instance: " .. instance .. ", Track: " .. trackName .. ", Connection: " .. connectionIndex)
    
    -- Discover child controls
    discoverChildControls()
    
    -- Initialize activity state
    lastActivityTime = os.clock()
    lastActivityCheck = getMillis()
    
    -- SAFETY: Disable all controls until properly mapped
    setGroupEnabled(false, true)  -- Silent
    
    -- Initialize track label with the first word, skipping return track prefixes
    local trackLabel = self:findByName("track_label", false)
    if trackLabel then
        local displayName = trackName
        
        -- Check if track name starts with single letter followed by hyphen (return track prefix)
        if trackName:match("^%u%-") then
            -- Skip the prefix (e.g., "A-") and get the rest
            displayName = trackName:sub(3)
        end
        
        -- Now get the first word from the display name
        local firstWord = displayName:match("(%w+)")
        if firstWord then
            trackLabel.values.text = firstWord
        else
            -- Fallback to full name if no word found
            trackLabel.values.text = displayName
        end
    end
    
    debug("Initialization complete")
    debug("Activity monitoring: " .. ACTIVITY_CHECK_INTERVAL .. "ms intervals")
    debug("Inactivity timeout: " .. INACTIVITY_TIMEOUT .. "s")
    debug("Fade duration: " .. FADE_DURATION .. "s")
    
    log("Ready - waiting for refresh")
end

init()