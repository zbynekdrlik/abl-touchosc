-- TouchOSC dB Value Label Display
-- Version: 1.4.0
-- Restored: Multi-connection routing support
-- Maintained: All existing functionality

-- Version constant
local VERSION = "1.4.0"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- State variable (must be local, not on self)
local lastDB = -math.huge

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "DB_LABEL"
        if self.parent and self.parent.name then
            context = "DB_LABEL(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

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

-- Get connection index by reading configuration directly (RESTORED)
local function getConnectionIndex()
    -- Default to connection 1 if can't determine
    local defaultConnection = 1
    
    -- Check parent tag for instance name
    if not self.parent or not self.parent.tag then
        return defaultConnection
    end
    
    -- Extract instance name from tag
    local instance = self.parent.tag:match("^(%w+):")
    if not instance then
        return defaultConnection
    end
    
    -- Find and read configuration
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        if DEBUG == 1 then
            log("No configuration found, using default connection")
        end
        return defaultConnection
    end
    
    -- Parse configuration to find connection for this instance
    local configText = configObj.values.text
    for line in configText:gmatch("[^\r\n]+") do
        -- Look for connection_instance: number pattern
        local configInstance, connectionNum = line:match("connection_(%w+):%s*(%d+)")
        if configInstance and configInstance == instance then
            if DEBUG == 1 then
                log("Found connection for " .. instance .. ": " .. connectionNum)
            end
            return tonumber(connectionNum) or defaultConnection
        end
    end
    
    if DEBUG == 1 then
        log("No connection found for instance: " .. instance)
    end
    return defaultConnection
end

-- Check if track is properly mapped
local function isTrackMapped()
    local trackNumber, trackType = getTrackInfo()
    return trackNumber ~= nil
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
-- OSC HANDLER WITH MULTI-CONNECTION
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
    
    -- Get our connection index (MULTI-CONNECTION SUPPORT)
    local myConnection = getConnectionIndex()
    
    -- Check if this message is from our connection
    if connections and not connections[myConnection] then
        return false
    end
    
    -- Check if this message is for our track
    if arguments[1].value == trackNumber then
        -- Get the volume value and convert to dB
        local audio_value = arguments[2].value
        local db_value = value2db(audio_value)
        
        -- Update label text
        self.values.text = formatDB(db_value)
        lastDB = db_value
        
        if DEBUG == 1 then
            log(string.format("%s track %d (conn %d): %.1f dB", 
                trackType, trackNumber, myConnection, db_value))
        end
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    -- Handle track changes
    if key == "track_changed" then
        -- Clear the display when track changes
        self.values.text = "-inf"
        lastDB = -math.huge
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastDB = nil
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
    log("Script v" .. VERSION .. " loaded")
    
    -- Set initial text
    if isTrackMapped() then
        self.values.text = "-inf"
    else
        self.values.text = "-"
    end
    
    if DEBUG == 1 then
        log("=== DB LABEL WITH MULTI-CONNECTION RESTORED ===")
        log("Multi-connection routing enabled")
    end
end

init()
