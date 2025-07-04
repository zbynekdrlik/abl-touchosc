-- TouchOSC Track Group Initialization Script
-- Version: 1.15.3
-- Fixed: Removed child control handler modification that caused errors
-- Fixed: Schedule method not available - using time-based update checks
-- Optimized: Replaced continuous update() with time-based activity monitoring
-- Fixed: Parse tag for track info to support both regular and return tracks
-- Added: Return track type support
-- Fixed: Debug guard early return for zero overhead

-- Version constant
local VERSION = "1.15.3"

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

-- ===========================
-- STATE VARIABLES
-- ===========================

-- Track mapping state
local trackNumber = nil
local trackType = nil  -- "track" or "return"
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
-- PARSE TAG FOR TRACK INFO
-- ===========================

local function parseTag()
    -- Parse tag in format "instance:trackNumber:trackType"
    if self.tag then
        local instance, trackNum, tType = self.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and tType then
            -- Validate track type
            if tType == "track" or tType == "regular" then
                return tonumber(trackNum), "track"  -- Normalize to "track"
            elseif tType == "return" then
                return tonumber(trackNum), "return"
            end
        end
    end
    return nil, nil
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
-- TRACK MAPPING
-- ===========================

local function updateTrackMapping()
    local newNumber, newType = parseTag()
    
    -- Check if mapping changed
    if newNumber ~= trackNumber or newType ~= trackType then
        -- Apply mapping change debounce
        if debounce(self.name .. "_mapping", MAPPING_CHANGE_DEBOUNCE) then
            debug("Track mapping change debounced")
            return
        end
        
        local oldNumber = trackNumber
        local oldType = trackType
        trackNumber = newNumber
        trackType = newType
        
        if trackNumber then
            debug(string.format("Track mapped: %s track %d", trackType, trackNumber))
            
            -- Enable all child controls
            for _, control in ipairs(childControls) do
                if control.name ~= "mute" then  -- Mute button visibility controlled separately
                    control.values.enabled = true
                end
            end
            
            -- Notify children of track change
            self:notify("track_changed", true)
            self:notify("control_enabled", true)
        else
            debug("Track unmapped")
            
            -- Disable interactive controls
            for _, control in ipairs(childControls) do
                if control.name == "fader" or control.name == "pan" then
                    control.values.enabled = false
                end
            end
            
            -- Notify children
            self:notify("track_unmapped", true)
            self:notify("control_enabled", false)
        end
        
        lastMappingChangeTime = os.clock()
        recordActivity()  -- Track change is activity
    end
end

-- ===========================
-- CHILD CONTROL DISCOVERY
-- ===========================

local function discoverChildControls()
    childControls = {}
    
    -- Find all relevant child controls
    local controlNames = {"fader", "pan", "meter", "db", "db_meter_label", "mute"}
    
    for _, name in ipairs(controlNames) do
        local control = self:findByName(name, false)  -- Non-recursive search
        if control then
            table.insert(childControls, control)
            debug("Found child control:", name)
        end
    end
    
    debug(string.format("Discovered %d child controls", #childControls))
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
    -- Any OSC activity keeps the group active
    recordActivity()
    return false  -- Don't consume the message
end

-- ===========================
-- NOTIFY HANDLERS
-- ===========================

function onReceiveNotify(key, value)
    if key == "value_changed" then
        -- Child control value changed
        recordActivity()
        
        -- Apply global debounce
        if debounce(self.name .. "_activity", GLOBAL_DEBOUNCE_TIME) then
            debug("Activity debounced")
            return
        end
        
        debug("Control value changed - activity recorded")
    elseif key == "refresh_group" then
        -- Refresh request from document script
        debug("Refresh requested")
        updateTrackMapping()
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
    print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") Group v" .. VERSION)
    
    -- Parse initial track mapping
    trackNumber, trackType = parseTag()
    
    if trackNumber then
        debug(string.format("Initial mapping: %s track %d", trackType, trackNumber))
    else
        debug("No initial track mapping")
    end
    
    -- Discover child controls
    discoverChildControls()
    
    -- Initialize activity state
    lastActivityTime = os.clock()
    lastActivityCheck = getMillis()
    
    -- Set initial enabled state
    if trackNumber then
        for _, control in ipairs(childControls) do
            if control.name ~= "mute" then
                control.values.enabled = true
            end
        end
    else
        for _, control in ipairs(childControls) do
            if control.name == "fader" or control.name == "pan" then
                control.values.enabled = false
            end
        end
    end
    
    debug("Initialization complete")
    debug("Activity monitoring: " .. ACTIVITY_CHECK_INTERVAL .. "ms intervals")
    debug("Inactivity timeout: " .. INACTIVITY_TIMEOUT .. "s")
    debug("Fade duration: " .. FADE_DURATION .. "s")
end

init()