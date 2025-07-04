-- TouchOSC Pan Control Script
-- Version: 1.5.1
-- Changed: Standardized DEBUG flag (uppercase) and disabled by default

-- Version constant
local VERSION = "1.5.1"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0

-- State variables
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local currentPan = 0.5  -- Center (0.5 = center in TouchOSC, 0 = center in Ableton)
local lastOscPan = 0.5
local isTouching = false

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "PAN"
        if self.parent and self.parent.name then
            context = "PAN(" .. self.parent.name .. ")"
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
-- PAN CONVERSION FUNCTIONS
-- ===========================

-- Convert TouchOSC value (0-1) to Ableton pan (-1 to 1)
local function touchOSCToAbletonPan(value)
    -- TouchOSC: 0 = left, 0.5 = center, 1 = right
    -- Ableton: -1 = left, 0 = center, 1 = right
    return (value * 2) - 1
end

-- Convert Ableton pan (-1 to 1) to TouchOSC value (0-1)
local function abletonToTouchOSCPan(value)
    -- Ableton: -1 = left, 0 = center, 1 = right
    -- TouchOSC: 0 = left, 0.5 = center, 1 = right
    return (value + 1) / 2
end

-- ===========================
-- OSC HANDLERS
-- ===========================

-- Send OSC with connection routing
local function sendOSCRouted(path, track, pan)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    sendOSC(path, track, pan, connections)
end

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Check if we have track info
    if not trackNumber or not trackType then
        return false
    end
    
    -- Check if this is a panning message for the correct track type
    local isPanMessage = false
    if trackType == "return" and path == '/live/return/get/panning' then
        isPanMessage = true
    elseif (trackType == "regular" or trackType == "track") and path == '/live/track/get/panning' then
        isPanMessage = true
    end
    
    if not isPanMessage then
        return false
    end
    
    -- Check if this message is for our track
    if arguments[1].value == trackNumber then
        -- Get the panning value from Ableton and convert to TouchOSC range
        local abletonPan = arguments[2].value
        lastOscPan = abletonToTouchOSCPan(abletonPan)
        
        -- Only update if not touching to prevent jumps
        if not isTouching then
            currentPan = lastOscPan
            self.values.x = currentPan
        end
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- USER INTERACTION
-- ===========================

function onValueChanged(valueName)
    -- Handle touch state
    if valueName == "touch" then
        isTouching = self.values.touch
        
        -- Sync with last OSC value when releasing
        if not isTouching then
            currentPan = lastOscPan
            self.values.x = currentPan
        end
    elseif valueName == "x" and isTouching then
        -- Check if track is mapped
        if not trackNumber or not trackType then
            return
        end
        
        -- Update pan value
        currentPan = self.values.x
        
        -- Convert to Ableton range and send
        local abletonPan = touchOSCToAbletonPan(currentPan)
        local path = trackType == "return" and '/live/return/set/panning' or '/live/track/set/panning'
        sendOSCRouted(path, trackNumber, abletonPan)
    end
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    if key == "track_changed" then
        trackNumber = value
        -- Reset to center when track changes
        currentPan = 0.5
        self.values.x = currentPan
    elseif key == "track_type" then
        trackType = value
    elseif key == "track_unmapped" then
        trackNumber = nil
        trackType = nil
        currentPan = 0.5
        self.values.x = currentPan
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Script v" .. VERSION .. " loaded")
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    
    -- Set initial position to center
    self.values.x = currentPan
end

init()