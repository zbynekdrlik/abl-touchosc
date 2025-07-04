-- TouchOSC Mute Button Script
-- Version: 2.0.1
-- Changed: Standardized DEBUG flag (uppercase) and disabled by default

-- Version constant
local VERSION = "2.0.1"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- State variables
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local isMuted = false

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "MUTE"
        if self.parent and self.parent.name then
            context = "MUTE(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get connection configuration
local function getConnectionIndex()
    -- Check if parent has tag with instance:trackNumber:trackType format
    if self.parent and self.parent.tag then
        local instance = self.parent.tag:match("^(%w+):")
        if instance then
            -- Find configuration object
            local configObj = root:findByName("configuration", true)
            if not configObj or not configObj.values or not configObj.values.text then
                return 1
            end
            
            local configText = configObj.values.text
            local searchKey = "connection_" .. instance .. ":"
            
            -- Parse configuration text
            for line in configText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$")  -- Trim whitespace
                if line:sub(1, #searchKey) == searchKey then
                    local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                    return tonumber(value) or 1
                end
            end
            
            return 1
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

-- ===========================
-- VISUAL STATE MANAGEMENT
-- ===========================

local function updateVisualState()
    -- Buttons use values.x for pressed/released state
    -- 0 = pressed/on, 1 = released/off
    if isMuted then
        self.values.x = 0  -- Pressed state (muted)
        self.color = Color(1, 0, 0, 1)  -- Red when muted
    else
        self.values.x = 1  -- Released state (unmuted)
        self.color = Color(0.5, 0.5, 0.5, 1)  -- Gray when unmuted
    end
end

-- ===========================
-- OSC HANDLERS
-- ===========================

-- Send OSC with connection routing
local function sendOSCRouted(path, track, mute)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    sendOSC(path, track, mute, connections)
end

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Check if we have track info
    if not trackNumber or not trackType then
        return false
    end
    
    -- Check if this is a mute message for the correct track type
    local isMuteMessage = false
    if trackType == "return" and path == '/live/return/get/mute' then
        isMuteMessage = true
    elseif (trackType == "regular" or trackType == "track") and path == '/live/track/get/mute' then
        isMuteMessage = true
    end
    
    if not isMuteMessage then
        return false
    end
    
    -- Check if this message is for our track
    if arguments[1].value == trackNumber then
        -- Update mute state (1 = muted, 0 = unmuted in Ableton)
        isMuted = (arguments[2].value == 1)
        updateVisualState()
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- USER INTERACTION
-- ===========================

function onValueChanged(valueName)
    -- Handle touch events
    if valueName == "touch" and self.values.touch == 1 then
        -- Check if track is mapped
        if not trackNumber or not trackType then
            return
        end
        
        -- Toggle mute state
        isMuted = not isMuted
        
        -- Send OSC based on track type
        local path = trackType == "return" and '/live/return/set/mute' or '/live/track/set/mute'
        sendOSCRouted(path, trackNumber, isMuted and 1 or 0)
        
        -- Update visual state immediately for responsiveness
        updateVisualState()
    end
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    if key == "track_changed" then
        trackNumber = value
        -- Reset mute state when track changes
        isMuted = false
        updateVisualState()
    elseif key == "track_type" then
        trackType = value
    elseif key == "track_unmapped" then
        trackNumber = nil
        trackType = nil
        isMuted = false
        updateVisualState()
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Script v" .. VERSION .. " loaded")
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    
    -- Set initial visual state
    updateVisualState()
end

init()