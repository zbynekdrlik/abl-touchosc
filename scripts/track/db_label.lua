-- TouchOSC dB Value Label Display
-- Version: 1.2.1
-- Changed: Removed centralized logging - using local print only

-- Version constant
local VERSION = "1.2.1"

-- State variable (must be local, not on self)
local lastDB = -math.huge

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    -- Get parent name for context
    local context = "DB_LABEL"
    if self.parent and self.parent.name then
        context = "DB_LABEL(" .. self.parent.name .. ")"
    end
    
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
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
        if not lastDB or math.abs(db_value - lastDB) > 0.5 then
            log(string.format("%s track %d: %s dB", trackType, trackNumber, formatDB(db_value)))
            lastDB = db_value
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
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastDB = nil
        log("Track unmapped - display shows dash")
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
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
end

init()