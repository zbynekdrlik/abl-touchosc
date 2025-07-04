-- TouchOSC Pan Control Script
-- Version: 1.5.0
-- Performance optimization: Scheduled update() at 10Hz instead of 60Hz
-- Fixed: Prevent ANY position changes when track is not mapped
-- Fixed: Parse parent tag for track info instead of accessing properties
-- Added: Return track support using parent's trackType
-- Removed: Logger output

-- Version constant
local VERSION = "1.5.0"

-- Double-tap configuration
local delay = 300 -- the maximum elapsed time between taps
local last = 0
local touch_on_first = false

-- Color constants
local COLOR_CENTERED = Color(0.39, 0.39, 0.39, 1.0)  -- #646464FF when at center
local COLOR_OFF_CENTER = Color(0.20, 0.76, 0.86, 1.0) -- #34C1DC when out of center

-- CRITICAL: Track whether we have a valid position from Ableton
local has_valid_position = false

-- Performance optimization: Track update timing
local SCHEDULED_UPDATE_INTERVAL = 100 -- 10Hz instead of 60Hz
local last_update_time = 0
local last_x_value = -1 -- Track last value to avoid redundant updates

-- ===========================
-- LOGGING
-- ===========================

-- Simple console logging
local function log(message)
    local context = "PAN"
    if self.parent and self.parent.name then
        context = "PAN(" .. self.parent.name .. ")"
    end
    
    -- Only print to console for development/debugging
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Read configuration directly (following script isolation pattern)
local function readConfiguration()
    local configControl = root:findByName("configuration", true)
    if not configControl then
        log("ERROR: Configuration control not found")
        return nil
    end
    
    local configText = configControl.values.text
    if not configText or configText == "" then
        log("ERROR: Configuration is empty")
        return nil
    end
    
    -- Parse configuration
    local config = {}
    for line in configText:gmatch("[^\r\n]+") do
        local key, value = line:match("^([^:]+):%s*(.+)$")
        if key and value then
            config[key] = tonumber(value) or value
        end
    end
    
    return config
end

-- Get the connection index from parent group
local function getConnectionIndex()
    -- Check if parent has tag with instance:trackNumber:trackType format
    if self.parent and self.parent.tag then
        local instance = self.parent.tag:match("^(%w+):")
        if instance then
            -- Read configuration directly
            local config = readConfiguration()
            if config then
                local connectionKey = "connection_" .. instance
                local connectionIndex = config[connectionKey]
                if connectionIndex then
                    return connectionIndex
                end
            end
        end
    end
    
    -- Fallback to default
    return 1
end

-- Build connection table for OSC routing
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- ===========================
-- TRACK INFORMATION
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
-- MAIN FUNCTIONS
-- ===========================

-- Handle value changes (touch and movement)
function onValueChanged()
    -- CRITICAL FIX: Prevent ANY value changes when track is not mapped
    if not isTrackMapped() then
        log("Track not mapped - ignoring value change completely")
        return
    end
    
    -- CRITICAL FIX: If we haven't received a valid position from Ableton yet, don't process changes
    -- This prevents the pan from jumping to default positions on startup
    if not has_valid_position then
        log("No valid position from Ableton yet - ignoring value change")
        return
    end
    
    local trackNumber, trackType = getTrackInfo()
    if not trackNumber then
        return
    end
    
    -- Double-tap detection
    if self.values.touch then
        touch_on_first = true
    end
    
    if touch_on_first and not self.values.touch then
        local now = getMillis()
        if now - last < delay then
            -- Double-tap detected - center the pan
            self.values.x = 0.5
            last = 0
            touch_on_first = false
            log("Double-tap detected - pan centered")
        else
            last = now
        end
    end
    
    -- Send pan value with connection routing
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    
    -- Convert to Ableton range (-1 to 1)
    local abletonValue = (self.values.x * 2) - 1
    
    -- Send to correct path based on track type
    local path = trackType == "return" and '/live/return/set/panning' or '/live/track/set/panning'
    sendOSC(path, trackNumber, abletonValue, connections)
end

-- Update visual color based on pan position (PERFORMANCE OPTIMIZED)
function update()
    local current_time = getMillis()
    
    -- Performance optimization: Only update at scheduled intervals
    if current_time - last_update_time < SCHEDULED_UPDATE_INTERVAL then
        return
    end
    
    local value = self.values.x
    
    -- Performance optimization: Skip if value hasn't changed
    if value == last_x_value then
        return
    end
    
    -- Update timing and value tracking
    last_update_time = current_time
    last_x_value = value
    
    -- Update color based on position
    if math.abs(value - 0.5) > 0.01 then
        -- Pan is off-center
        self.color = COLOR_OFF_CENTER
    else
        -- Pan is centered
        self.color = COLOR_CENTERED
    end
end

-- Handle incoming pan updates from Ableton
function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Get track info from parent
    local trackNumber, trackType = getTrackInfo()
    if not trackNumber then
        return false
    end
    
    -- Check if this is a pan message for the correct track type
    local isPanMessage = false
    if trackType == "return" and path == '/live/return/get/panning' then
        isPanMessage = true
    elseif (trackType == "regular" or trackType == "track") and path == '/live/track/get/panning' then
        isPanMessage = true
    end
    
    if not isPanMessage then
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
    
    if msgTrackNumber ~= trackNumber then
        return false
    end
    
    -- Get the pan value (-1 to 1 from Ableton)
    local abletonPan = arguments[2].value
    
    -- Mark that we have received a valid position from Ableton
    has_valid_position = true
    
    -- Convert to TouchOSC range (0-1)
    self.values.x = (abletonPan + 1) / 2
    
    log("Received pan position from Ableton: " .. string.format("%.2f", self.values.x))
    
    return true
end

-- Handle notifications from parent group
function onReceiveNotify(key, value)
    -- Parent might notify us of track changes
    if key == "track_changed" then
        -- Track changed but might still be valid - wait for OSC data
        -- Don't reset has_valid_position yet - wait for new OSC data
        log("Track changed - waiting for OSC pan position")
    elseif key == "track_unmapped" then
        -- Track is definitely unmapped - mark as invalid
        has_valid_position = false
        log("Track unmapped - pan frozen at current position")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- CRITICAL: Don't assume we have a valid position on startup
    has_valid_position = false
    
    -- DO NOT touch self.values.x - preserve current state!
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    log("Waiting for valid position from Ableton...")
end

-- Initialize on script load
init()
