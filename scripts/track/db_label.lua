-- TouchOSC dB Value Label Display
-- Version: 1.3.3
-- Performance: Added early return debug guard for zero overhead when DEBUG != 1
-- Fixed: Added notify handler to request volume when track changes
-- Performance optimized - removed centralized logging, added DEBUG guards
-- Shows the current fader value in dB
-- Multi-connection routing support

-- Version constant
local VERSION = "1.3.3"

-- Debug mode (set to 1 for debug output)
local DEBUG = 0  -- Set to 0 for production (zero overhead)

-- State variable (must be local, not on self)
local lastDB = -math.huge
local hasTrackedStarted = false

-- ===========================
-- DEBUG LOGGING
-- ===========================

local function debug(message)
    -- Performance guard: early return for zero overhead when DEBUG != 1
    if DEBUG ~= 1 then return end
    
    local context = "DB_LABEL"
    if self.parent and self.parent.name then
        context = "DB_LABEL(" .. self.parent.name .. ")"
    end
    
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get connection index
local function getConnectionIndex()
    if self.parent and self.parent.tag then
        local instance = self.parent.tag:match("^(%w+):")
        if instance then
            -- Find configuration
            local configObj = root:findByName("configuration", true)
            if not configObj or not configObj.values or not configObj.values.text then
                return 1
            end
            
            local configText = configObj.values.text
            local searchKey = "connection_" .. instance .. ":"
            
            -- Parse configuration
            for line in configText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$")  -- Trim
                if line:sub(1, #searchKey) == searchKey then
                    local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                    return tonumber(value) or 1
                end
            end
        end
    end
    return 1
end

-- Build connection table
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Get track number and type from parent group
local function getTrackInfo()
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if self.parent and self.parent.tag then
        local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            return tonumber(trackNum), trackType
        end
    end
    return nil, nil
end

-- Check if track is properly mapped
local function isTrackMapped()
    local trackNumber, trackType = getTrackInfo()
    return trackNumber ~= nil
end

-- Request current volume from Ableton
local function requestVolume()
    local trackNumber, trackType = getTrackInfo()
    if trackNumber then
        local connectionIndex = getConnectionIndex()
        local connections = buildConnectionTable(connectionIndex)
        local path = trackType == "return" and "/live/return/get/volume" or "/live/track/get/volume"
        sendOSC(path, trackNumber, connections)
        
        debug("Requested volume for " .. trackType .. " track " .. trackNumber)
        
        -- Start volume listening
        if not hasTrackedStarted then
            local listenPath = trackType == "return" and "/live/return/start_listen/volume" or "/live/track/start_listen/volume"
            sendOSC(listenPath, trackNumber, connections)
            hasTrackedStarted = true
            
            debug("Started volume listener for " .. trackType .. " track " .. trackNumber)
        end
    end
end

-- ===========================
-- dB CONVERSION FUNCTION
-- ===========================

function value2db(vl)
    -- Conversion from linear to decibel scale in track volume
    if vl <= 1 and vl >= 0.4 then
        return 40*vl - 34
    elseif vl < 0.4 and vl >= 0.15 then
        local alpha = 799.503788
        local beta = 12630.61132
        local gamma = 201.871345
        local delta = 399.751894
        return -((delta*vl - gamma)^2 + beta)/alpha
    elseif vl < 0.15 then
        local alpha = 70.
        local beta = 118.426374
        local gamma = 7504./5567.
        local db_value = beta*(vl^(1/gamma)) - alpha
        if db_value <= -70.0 then 
            return -math.huge  -- -inf
        else
            return db_value
        end
    else
        return 0
    end
end

-- Format dB value for display
function formatDB(db_value)
    if db_value == -math.huge or db_value < -70 then
        return "-inf"
    else
        return string.format("%.1f", db_value)
    end
end

-- ===========================
-- OSC HANDLER
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Get track info from parent
    local trackNumber, trackType = getTrackInfo()
    if not trackNumber then
        return false
    end
    
    -- Check if this is a volume message for the correct track type
    local isVolumeMessage = false
    if trackType == "return" and path == '/live/return/get/volume' then
        isVolumeMessage = true
    elseif (trackType == "regular" or trackType == "track") and path == '/live/track/get/volume' then
        isVolumeMessage = true
    end
    
    if not isVolumeMessage then
        return false
    end
    
    -- Check if this message is for our track
    if arguments[1].value == trackNumber then
        -- Get the volume value and convert to dB
        local audio_value = arguments[2].value
        local db_value = value2db(audio_value)
        
        -- Update label text
        self.values.text = formatDB(db_value)
        
        -- Only log significant changes to reduce spam
        if DEBUG == 1 and (not lastDB or math.abs(db_value - lastDB) > 0.5) then
            debug(string.format("%s track %d: %s dB (audio: %.3f)", trackType, trackNumber, formatDB(db_value), audio_value))
            lastDB = db_value
        end
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    debug("Received notify: " .. key .. " = " .. tostring(value))
    
    -- Handle track changes
    if key == "track_changed" then
        -- Clear the display when track changes
        self.values.text = "-inf"
        lastDB = -math.huge
        hasTrackedStarted = false
        debug("Track changed - display reset")
        
        -- Request volume for new track
        requestVolume()
        
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastDB = nil
        hasTrackedStarted = false
        debug("Track unmapped - display shows dash")
        
    elseif key == "control_enabled" then
        -- Show/hide based on track mapping status
        self.values.visible = value
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    print("[" .. os.date("%H:%M:%S") .. "] DB_LABEL: Script v" .. VERSION .. " loaded")
    
    -- Set initial text
    if isTrackMapped() then
        self.values.text = "-inf"
        -- Request initial volume
        requestVolume()
    else
        self.values.text = "-"
    end
    
    debug("Initialized for parent: " .. (self.parent and self.parent.name or "unknown"))
    debug("DEBUG MODE ENABLED")
end

init()
