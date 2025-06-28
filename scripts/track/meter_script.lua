-- TouchOSC Meter Script (Output Level Display)
-- Version: 2.1.0
-- Added: Centralized logging through document script

-- Version constant
local VERSION = "2.1.0"

-- ===========================
-- CONFIGURATION SECTION
-- ===========================

local METER_SMOOTHING = 0.15       -- Smoothing for meter display (0-1, lower = smoother)
local PEAK_HOLD_TIME = 1500        -- Time to hold peak indicator (ms)
local PEAK_FALL_SPEED = 0.05       -- Speed of peak indicator falling
local UPDATE_RATE = 30             -- Updates per second
local MIN_DB = -70                 -- Minimum dB to display
local MAX_DB = 6                   -- Maximum dB to display
local CLIP_THRESHOLD = 0           -- dB level for clipping indication
local DEBUG_MODE = false           -- Enable debug logging

-- ===========================
-- STATE VARIABLES
-- ===========================

local currentLevel = 0             -- Current smoothed level
local targetLevel = 0              -- Target level from Ableton
local peakLevel = 0                -- Peak level
local peakHoldTimer = 0            -- Timer for peak hold
local lastUpdateTime = 0           -- For frame rate limiting
local isClipping = false           -- Clipping indicator
local lastClipTime = 0             -- When clipping last occurred

-- Reference to document script for connection routing
local documentScript = nil

-- ===========================
-- LOGGING
-- ===========================

-- Centralized logging through document script
local function log(message)
    -- Get parent name for context
    local context = "METER"
    if self.parent and self.parent.name then
        context = "METER(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development/debugging
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Debug logging (only if DEBUG_MODE is true)
local function debugLog(...)
    if DEBUG_MODE then
        local args = {...}
        local msg = table.concat(args, " ")
        log("[DEBUG] " .. msg)
    end
end

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

-- Convert linear level (0-1) to dB
local function linearToDb(linear)
    if linear <= 0 then
        return MIN_DB
    end
    local db = 20 * math.log10(linear)
    return math.max(MIN_DB, math.min(MAX_DB, db))
end

-- Convert dB to linear level (0-1) for display
local function dbToDisplay(db)
    -- Map MIN_DB to MAX_DB to 0-1 range
    local normalized = (db - MIN_DB) / (MAX_DB - MIN_DB)
    return math.max(0, math.min(1, normalized))
end

-- Smooth value changes
local function smoothValue(current, target, smoothing, deltaTime)
    if smoothing <= 0 then
        return target
    end
    
    -- Calculate interpolation factor
    local factor = 1 - math.exp(-deltaTime * (1 - smoothing) * 10)
    
    return current + (target - current) * factor
end

-- ===========================
-- TRACK INFORMATION
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
    -- If parent doesn't have proper tag format, it's not mapped
    if not self.parent or not self.parent.tag then
        return false
    end
    
    -- Check for instance:trackNumber format
    local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and trackNum ~= nil
end

-- Get connection index from parent group
local function getConnectionIndex()
    -- Check if parent has tag with instance:trackNumber format
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance and trackNum then
            -- Get document script reference
            if not documentScript then
                documentScript = root
            end
            
            -- Call the helper function from document script
            if documentScript.getConnectionForInstance then
                return documentScript.getConnectionForInstance(instance)
            end
        end
    end
    
    -- Fallback to default
    return 1
end

-- ===========================
-- VISUAL UPDATES
-- ===========================

-- Update meter display
local function updateMeterDisplay()
    -- Set meter level
    self.values.x = currentLevel
    
    -- Update color based on level
    local db = linearToDb(targetLevel)
    
    if isClipping or db >= CLIP_THRESHOLD then
        -- Red for clipping
        self.color = Color(1, 0, 0, 1)
    elseif db >= -6 then
        -- Yellow for hot
        self.color = Color(1, 0.8, 0, 1)
    elseif db >= -12 then
        -- Green-yellow
        self.color = Color(0.8, 1, 0, 1)
    else
        -- Green for normal
        self.color = Color(0, 1, 0, 1)
    end
    
    -- Update peak indicator if we have one
    if self.children and self.children.peak_indicator then
        -- Position peak indicator
        self.children.peak_indicator.values.x = peakLevel
        
        -- Color based on peak level
        local peakDb = linearToDb(peakLevel)
        if peakDb >= CLIP_THRESHOLD then
            self.children.peak_indicator.color = Color(1, 0, 0, 1)
        elseif peakDb >= -6 then
            self.children.peak_indicator.color = Color(1, 0.8, 0, 1)
        else
            self.children.peak_indicator.color = Color(1, 1, 1, 0.8)
        end
    end
end

-- ===========================
-- UPDATE LOGIC
-- ===========================

-- Main update function
function update()
    -- Safety check: skip update if track not mapped
    if not isTrackMapped() then
        -- Reset meter to 0 if track not mapped
        self.values.x = 0
        currentLevel = 0
        peakLevel = 0
        return
    end
    
    local now = getMillis()
    
    -- Frame rate limiting
    if now - lastUpdateTime < (1000 / UPDATE_RATE) then
        return
    end
    
    local deltaTime = (now - lastUpdateTime) / 1000
    lastUpdateTime = now
    
    -- Smooth meter movement
    currentLevel = smoothValue(currentLevel, targetLevel, METER_SMOOTHING, deltaTime)
    
    -- Update peak level
    if targetLevel > peakLevel then
        peakLevel = targetLevel
        peakHoldTimer = now
    elseif now - peakHoldTimer > PEAK_HOLD_TIME then
        -- Peak falls after hold time
        peakLevel = math.max(targetLevel, peakLevel - PEAK_FALL_SPEED * deltaTime)
    end
    
    -- Clear clipping after a moment
    if isClipping and now - lastClipTime > 500 then
        isClipping = false
    end
    
    -- Update visual
    updateMeterDisplay()
end

-- ===========================
-- OSC RECEIVE HANDLERS
-- ===========================

-- Handle incoming meter data from Ableton
function onReceiveOSC(message, connections)
    -- Only process meter messages
    if message[1] ~= '/live/track/get/output_meter_level' then
        return false
    end
    
    -- Check if this message is from our connection
    local myConnection = getConnectionIndex()
    if not connections[myConnection] then
        return false
    end
    
    -- Check if this is our track
    local arguments = message[2]
    if not arguments or #arguments < 2 then
        return false
    end
    
    local msgTrackNumber = arguments[1].value
    local myTrackNumber = getTrackNumber()
    
    if msgTrackNumber ~= myTrackNumber then
        return false
    end
    
    -- Get the meter level (linear 0-1)
    local newLevel = arguments[2].value
    targetLevel = newLevel
    
    -- Check for clipping
    local db = linearToDb(newLevel)
    if db >= CLIP_THRESHOLD then
        isClipping = true
        lastClipTime = getMillis()
    end
    
    debugLog(string.format("Received level: %.3f (%.1f dB) for track %d", 
        newLevel, db, msgTrackNumber))
    
    return true
end

-- ===========================
-- PARENT NOTIFICATION
-- ===========================

-- Handle notifications from parent group
function onReceiveNotify(key, value)
    -- Parent might notify us of track changes
    if key == "track_changed" then
        -- Reset state when track changes
        targetLevel = 0
        currentLevel = 0
        peakLevel = 0
        isClipping = false
        self.values.x = 0
        debugLog("Track changed - reset meter")
    elseif key == "track_unmapped" then
        -- Disable meter when track is unmapped
        self.values.x = 0
        currentLevel = 0
        debugLog("Track unmapped - disabled meter")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Ensure we're starting at 0
    self.values.x = 0
    currentLevel = 0
    targetLevel = 0
    peakLevel = 0
    
    -- Set meter orientation (assuming vertical)
    self.orientation = Orientation.VERTICAL
    
    -- Initial color
    self.color = Color(0, 1, 0, 1)
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    -- Set initial state based on track mapping
    if not isTrackMapped() then
        self.color = Color(0.3, 0.3, 0.3, 0.5)
    end
end

-- Initialize on script load
init()
