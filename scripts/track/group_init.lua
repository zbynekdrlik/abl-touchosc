-- TouchOSC Track Group Controller with Multi-Connection Support
-- Version: 1.16.1
-- Fixed: Version logging respects DEBUG flag
-- Added: Return track support with auto-detection

local VERSION = "1.16.1"

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 to see detailed logs

-- ===========================
-- STATE VARIABLES
-- ===========================

local currentTrackNumber = nil
local currentTrackName = nil
local currentTrackType = nil  -- "track" or "return"
local connectionIndex = nil
local childControls = {}
local isEnabled = false
local instanceName = nil

-- Track discovery state
local discoveryState = {
    regularTracks = {},
    returnTracks = {},
    phase = "idle",  -- "idle", "regular", "return", "complete"
    currentIndex = 0,
    maxTracks = 20,
    maxReturnTracks = 12
}

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    -- FIXED: Only log when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") " .. message)
    end
end

local function alwaysLog(message)
    -- For critical messages that should always show (errors, etc)
    print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") " .. message)
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function round(x)
    return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

-- ===========================
-- CONNECTION MANAGEMENT
-- ===========================

local function getConnectionFromConfig(instance)
    -- Check if root has configuration
    if root.configuration and root.configuration.connections then
        return root.configuration.connections[instance] or 1
    end
    
    -- Fallback: try to read configuration directly
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        log("No configuration found, using default connection")
        return 1
    end
    
    -- Parse configuration
    local configText = configObj.values.text
    for line in configText:gmatch("[^\r\n]+") do
        local configInstance, connectionNum = line:match("connection_(%w+):%s*(%d+)")
        if configInstance and configInstance == instance then
            return tonumber(connectionNum) or 1
        end
    end
    
    return 1  -- Default connection
end

local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- ===========================
-- CHILD CONTROL MANAGEMENT
-- ===========================

local function findChildControls()
    childControls = {}
    
    -- Define control names to find
    local controlNames = {
        "label", "fader", "db", "meter", "mute", "pan", "db_meter_label"
    }
    
    -- Search for each control
    for _, name in ipairs(controlNames) do
        local control = self:findByName(name, false)
        if control then
            childControls[name] = control
            log("Found child control: " .. name)
        end
    end
    
    return #childControls
end

local function setControlsEnabled(enabled)
    isEnabled = enabled
    
    -- Update all child controls
    local count = 0
    for name, control in pairs(childControls) do
        if control.enabled ~= nil then
            control.enabled = enabled
            count = count + 1
        end
    end
    
    log("controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. count .. " controls)")
end

-- ===========================
-- TRACK MANAGEMENT
-- ===========================

local function updateTag()
    -- Store essential info in tag for child controls
    if instanceName and currentTrackNumber and currentTrackType then
        self.tag = instanceName .. ":" .. currentTrackNumber .. ":" .. currentTrackType
        log("Tag updated: " .. self.tag)
    end
end

local function setTrackMapping(trackNumber, trackName, trackType)
    currentTrackNumber = trackNumber
    currentTrackName = trackName
    currentTrackType = trackType or "track"
    
    -- Update our tag
    updateTag()
    
    -- Notify all child controls
    for name, control in pairs(childControls) do
        control:notify("track_changed", trackNumber)
        control:notify("track_type", currentTrackType)
    end
    
    -- Enable controls
    setControlsEnabled(true)
    
    -- Update label
    if childControls.label then
        -- For return tracks, remove A- or B- prefix
        local displayName = trackName
        if currentTrackType == "return" then
            -- Remove A- or B- prefix for cleaner display
            displayName = trackName:gsub("^[A-Z]%-", "")
        end
        childControls.label.values.text = displayName
    end
    
    -- Log the mapping
    local trackTypeDisplay = currentTrackType == "return" and "Return Track" or "Track"
    log("Mapped to " .. trackTypeDisplay .. " " .. trackNumber)
end

local function clearTrackMapping()
    currentTrackNumber = nil
    currentTrackName = nil
    currentTrackType = nil
    
    -- Notify child controls
    for name, control in pairs(childControls) do
        control:notify("track_unmapped", true)
    end
    
    -- Disable controls
    setControlsEnabled(false)
    
    -- Clear label
    if childControls.label then
        childControls.label.values.text = "No Track"
    end
    
    log("Track mapping cleared")
end

-- ===========================
-- TRACK DISCOVERY
-- ===========================

local function startTrackDiscovery()
    log("Starting track discovery...")
    
    -- Reset discovery state
    discoveryState = {
        regularTracks = {},
        returnTracks = {},
        phase = "regular",
        currentIndex = 0,
        maxTracks = 20,
        maxReturnTracks = 12
    }
    
    -- Request first regular track
    local connections = buildConnectionTable(connectionIndex)
    sendOSC('/live/track/get/name', 0, connections)
end

local function findTrackByName(trackName)
    -- First, check if we have discovered tracks
    if #discoveryState.regularTracks == 0 and #discoveryState.returnTracks == 0 then
        log("No tracks discovered yet, starting discovery...")
        startTrackDiscovery()
        return false  -- Will retry after discovery
    end
    
    -- Clean the search name
    local searchName = trim(trackName)
    
    -- Search regular tracks
    for i, track in ipairs(discoveryState.regularTracks) do
        if track.name == searchName then
            setTrackMapping(track.number, track.name, "track")
            return true
        end
    end
    
    -- Search return tracks
    for i, track in ipairs(discoveryState.returnTracks) do
        if track.name == searchName then
            setTrackMapping(track.number, track.name, "return")
            return true
        end
    end
    
    -- Not found
    log("Track not found: " .. searchName)
    clearTrackMapping()
    return false
end

-- ===========================
-- OSC MESSAGE HANDLING
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Check if this message is from our connection
    if connections and not connections[connectionIndex] then
        return
    end
    
    -- Handle track discovery responses
    if discoveryState.phase ~= "idle" then
        if path == '/live/track/get/name' and discoveryState.phase == "regular" then
            local trackNum = arguments[1].value
            local trackName = arguments[2].value
            
            -- Check if we got a valid response
            if trackName and trackName ~= "" then
                table.insert(discoveryState.regularTracks, {
                    number = trackNum,
                    name = trackName
                })
                log("Discovered track " .. trackNum .. ": " .. trackName)
                
                -- Request next track
                discoveryState.currentIndex = trackNum + 1
                if discoveryState.currentIndex < discoveryState.maxTracks then
                    local conns = buildConnectionTable(connectionIndex)
                    sendOSC('/live/track/get/name', discoveryState.currentIndex, conns)
                else
                    -- Move to return track discovery
                    log("Regular track discovery complete, found " .. #discoveryState.regularTracks .. " tracks")
                    discoveryState.phase = "return"
                    discoveryState.currentIndex = 0
                    local conns = buildConnectionTable(connectionIndex)
                    sendOSC('/live/return/get/name', 0, conns)
                end
            else
                -- No more regular tracks, move to return tracks
                log("Regular track discovery complete, found " .. #discoveryState.regularTracks .. " tracks")
                discoveryState.phase = "return"
                discoveryState.currentIndex = 0
                local conns = buildConnectionTable(connectionIndex)
                sendOSC('/live/return/get/name', 0, conns)
            end
            
        elseif path == '/live/return/get/name' and discoveryState.phase == "return" then
            local trackNum = arguments[1].value
            local trackName = arguments[2].value
            
            -- Check if we got a valid response
            if trackName and trackName ~= "" then
                table.insert(discoveryState.returnTracks, {
                    number = trackNum,
                    name = trackName
                })
                log("Discovered return track " .. trackNum .. ": " .. trackName)
                
                -- Request next return track
                discoveryState.currentIndex = trackNum + 1
                if discoveryState.currentIndex < discoveryState.maxReturnTracks then
                    local conns = buildConnectionTable(connectionIndex)
                    sendOSC('/live/return/get/name', discoveryState.currentIndex, conns)
                else
                    -- Discovery complete
                    discoveryState.phase = "complete"
                    log("Track discovery complete!")
                    log("Found " .. #discoveryState.regularTracks .. " regular tracks and " .. #discoveryState.returnTracks .. " return tracks")
                    
                    -- Now try to find our track
                    if self.name ~= instanceName then
                        findTrackByName(self.name)
                    end
                end
            else
                -- No more return tracks
                discoveryState.phase = "complete"
                log("Track discovery complete!")
                log("Found " .. #discoveryState.regularTracks .. " regular tracks and " .. #discoveryState.returnTracks .. " return tracks")
                
                -- Now try to find our track
                if self.name ~= instanceName then
                    findTrackByName(self.name)
                end
            end
        end
    end
    
    return false  -- Don't consume the message
end

-- ===========================
-- NOTIFICATION HANDLING
-- ===========================

function onReceiveNotify(key, value)
    if key == "refresh" then
        log("Refreshing track mapping with auto-detection")
        
        -- Start discovery if not done yet
        if #discoveryState.regularTracks == 0 and #discoveryState.returnTracks == 0 then
            startTrackDiscovery()
        else
            -- Re-find track with existing discovery data
            findTrackByName(self.name)
        end
        
    elseif key == "child_touched" then
        -- Forward to other controls
        for name, control in pairs(childControls) do
            if name ~= value then  -- Don't notify the sender
                control:notify("sibling_touched", value)
            end
        end
        
    elseif key == "child_released" then
        -- Forward to other controls
        for name, control in pairs(childControls) do
            if name ~= value then  -- Don't notify the sender
                control:notify("sibling_released", value)
            end
        end
        
    elseif key == "value_changed" then
        -- Forward value changes to relevant controls
        for name, control in pairs(childControls) do
            control:notify("sibling_value_changed", value)
        end
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging only when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") Group v" .. VERSION .. " loaded")
    end
    
    -- Extract instance name and track name from control name
    -- Format: "instance_Track Name" 
    local underscore_pos = self.name:find("_")
    if underscore_pos then
        instanceName = self.name:sub(1, underscore_pos - 1)
        local trackName = self.name:sub(underscore_pos + 1)
        
        -- Get connection for this instance
        connectionIndex = getConnectionFromConfig(instanceName)
        
        log("Config - Instance: " .. instanceName .. ", Track: " .. trackName .. ", Connection: " .. connectionIndex)
    else
        alwaysLog("ERROR: Invalid group name format: " .. self.name)
        return
    end
    
    -- Find all child controls
    findChildControls()
    
    -- Initially disable all controls
    setControlsEnabled(false)
    
    log("Ready - waiting for refresh")
end

init()