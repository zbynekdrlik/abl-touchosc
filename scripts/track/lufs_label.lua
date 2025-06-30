-- TouchOSC LUFS Value Label Display
-- Version: 1.0.0
-- Shows the current fader value in LUFS (Loudness Units relative to Full Scale)
-- Multi-connection routing support

-- Version constant
local VERSION = "1.0.0"

-- State variable (must be local, not on self)
local lastLUFS = -60.0

-- ===========================
-- CENTRALIZED LOGGING
-- ===========================

local function log(message)
    -- Get parent name for context
    local context = "LUFS_LABEL"
    if self.parent and self.parent.name then
        context = "LUFS_LABEL(" .. self.parent.name .. ")"
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

-- ===========================
-- LUFS CALCULATION
-- ===========================

-- Convert dB value to approximate LUFS
-- This is a simplified approximation for real-time display
function dbToLUFS(db_value)
    -- LUFS approximation from fader position
    -- Typical mapping:
    -- 0 dB → -14 LUFS (common streaming target)
    -- -6 dB → -20 LUFS
    -- -12 dB → -26 LUFS
    -- -18 dB → -32 LUFS
    -- -24 dB → -38 LUFS
    -- -30 dB → -44 LUFS
    -- -inf dB → -60 LUFS
    
    if db_value == -math.huge or db_value < -60 then
        return -60.0  -- Minimum LUFS display
    elseif db_value >= 0 then
        -- For positive dB values, scale from -14 to 0 LUFS
        return -14.0 + (db_value * 14.0 / 6.0)  -- Scale 0-6dB to -14-0 LUFS
    else
        -- For negative dB values, use a curve that maps typical levels
        -- This creates a more realistic LUFS response
        local normalized = (db_value + 60) / 60  -- 0 to 1 range
        local lufs = -60.0 + (normalized * 46.0)  -- -60 to -14 LUFS
        
        -- Apply a slight curve for more realistic response
        if db_value > -30 then
            -- Adjust the upper range to be more sensitive
            local adjustment = (db_value + 30) / 30  -- 0 to 1
            lufs = lufs + (adjustment * 4.0)  -- Add up to 4 LUFS
        end
        
        return lufs
    end
end

-- Format LUFS value for display
function formatLUFS(lufs_value)
    if lufs_value <= -60 then
        return "-60.0"  -- Minimum display
    else
        return string.format("%.1f", lufs_value)
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
        -- Get the volume value and convert to LUFS
        local audio_value = arguments[2].value
        local db_value = value2db(audio_value)
        local lufs_value = dbToLUFS(db_value)
        
        -- Update label text
        self.values.text = formatLUFS(lufs_value)
        
        -- Only log significant changes to reduce spam
        if not lastLUFS or math.abs(lufs_value - lastLUFS) > 0.5 then
            log(string.format("Track %d: %s LUFS", myTrackNumber, formatLUFS(lufs_value)))
            lastLUFS = lufs_value
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
        self.values.text = "-60.0"
        lastLUFS = -60.0
        log("Track changed - display reset")
    elseif key == "track_unmapped" then
        -- Show dash when unmapped
        self.values.text = "-"
        lastLUFS = nil
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
        self.values.text = "-60.0"
    else
        self.values.text = "-"
    end
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
end

init()