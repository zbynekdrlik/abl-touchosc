-- TouchOSC Pan Control Script
-- Version: 1.4.0
-- Added: Return track support using parent's trackType
-- Fixed: Added logger output using root:notify like other scripts

-- Version constant
local VERSION = "1.4.0"

-- Double-tap configuration
local delay = 300 -- the maximum elapsed time between taps
local last = 0
local touch_on_first = false

-- Color constants
local COLOR_CENTERED = Color(0.39, 0.39, 0.39, 1.0)  -- #646464FF when at center
local COLOR_OFF_CENTER = Color(0.20, 0.76, 0.86, 1.0) -- #34C1DC when out of center

-- ===========================
-- LOGGING
-- ===========================

-- Logging with both logger object and console output
local function log(message)
    local context = "PAN"
    if self.parent and self.parent.name then
        context = "PAN(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update (like meter and fader)
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development/debugging
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
    -- Check if parent has tag with instance:trackNumber format
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance and trackNum then
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
    -- Parent stores track number and type
    if self.parent then
        local trackNumber = self.parent.trackNumber
        local trackType = self.parent.trackType or "regular"  -- Default to regular if not set
        return trackNumber, trackType
    end
    return nil, nil
end

-- ===========================
-- MAIN FUNCTIONS
-- ===========================

-- Handle value changes (touch and movement)
function onValueChanged()
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

-- Update visual color based on pan position
function update()
    local value = self.values.x
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
    elseif trackType == "regular" and path == '/live/track/get/panning' then
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
    
    -- Convert to TouchOSC range (0-1)
    self.values.x = (abletonPan + 1) / 2
    
    return true
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- DO NOT touch self.values.x - preserve current state!
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
end

-- Initialize on script load
init()
