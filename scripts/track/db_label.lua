-- TouchOSC dB Value Label Display
-- Version: 1.0.0
-- Shows the current fader value in dB
-- Multi-connection routing support

-- Version constant
local VERSION = "1.0.0"

-- ===========================
-- CENTRALIZED LOGGING
-- ===========================

local function log(message)
    -- Get parent name for context
    local context = "DB_LABEL"
    if self.parent and self.parent.name then
        context = "DB_LABEL(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get track number from parent group
local function getTrackNumber()
    -- Parent stores combined tag like "band:5"
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
    end
    return nil
end

-- Check if track is properly mapped
local function isTrackMapped()
    if not self.parent or not self.parent.tag then
        return false
    end
    
    local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and trackNum ~= nil
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
    local arguments = message[2]
    
    -- Get our track number
    local myTrackNumber = getTrackNumber()
    if not myTrackNumber then
        return false
    end
    
    -- Check if this message is for our track
    if arguments[1].value == myTrackNumber then
        -- Get the volume value and convert to dB
        local audio_value = arguments[2].value
        local db_value = value2db(audio_value)
        
        -- Update label text
        self.values.text = formatDB(db_value)
        
        -- Only log significant changes to reduce spam
        if not self.lastDB or math.abs(db_value - self.lastDB) > 0.5 then
            log(string.format("Track %d: %s dB", myTrackNumber, formatDB(db_value)))
            self.lastDB = db_value
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
        self.lastDB = -math.huge
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Clear display when unmapped
        self.values.text = ""
        self.lastDB = nil
        log("Track unmapped - display cleared")
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
        self.values.text = ""
    end
    
    -- Initialize last dB tracking
    self.lastDB = -math.huge
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
end

init()
