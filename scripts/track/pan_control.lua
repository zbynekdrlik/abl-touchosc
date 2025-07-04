-- TouchOSC Pan Control with Multi-Connection Support
-- Version: 1.5.1
-- Fixed: Version logging respects DEBUG flag
-- Added: Return track support and proper OSC routing

local VERSION = "1.5.1"

-- DEBUG MODE  
local DEBUG = 0  -- Set to 1 to enable detailed logging

-- State variables
local parentGroup = nil
local trackNumber = nil
local trackType = nil
local connectionIndex = nil
local isInitialized = false
local lastOscValue = 0.5
local isTouching = false
local lastTapTime = 0

-- Double-tap detection
local DOUBLE_TAP_TIME = 400  -- milliseconds

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    -- FIXED: Only log when DEBUG=1
    if DEBUG == 1 then
        local context = "PAN"
        if parentGroup and parentGroup.name then
            context = "PAN(" .. parentGroup.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

local function alwaysLog(message)
    -- For critical messages that should always show
    local context = "PAN"
    if parentGroup and parentGroup.name then
        context = "PAN(" .. parentGroup.name .. ")"
    end
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- ===========================
-- PARENT GROUP HELPERS
-- ===========================

local function findParentGroup()
    if self.parent and self.parent.name then
        parentGroup = self.parent
        return true
    end
    return false
end

-- Get track info from parent's tag
local function getTrackInfo()
    if parentGroup and parentGroup.tag then
        local instance, trackNum, trackType = parentGroup.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            return tonumber(trackNum), trackType
        end
    end
    return nil, nil
end

-- Get connection configuration
local function getConnectionIndex()
    if parentGroup and parentGroup.tag then
        local instance = parentGroup.tag:match("^(%w+):")
        if instance then
            local configObj = root:findByName("configuration", true)
            if configObj and configObj.values and configObj.values.text then
                local configText = configObj.values.text
                for line in configText:gmatch("[^\r\n]+") do
                    local configInstance, connectionNum = line:match("connection_(%w+):%s*(%d+)")
                    if configInstance and configInstance == instance then
                        return tonumber(connectionNum) or 1
                    end
                end
            end
        end
    end
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
-- PAN VALUE CONVERSION
-- ===========================

-- Convert TouchOSC position (0-1) to Ableton pan (-1 to 1)
local function positionToPan(pos)
    return (pos * 2) - 1
end

-- Convert Ableton pan (-1 to 1) to TouchOSC position (0-1)
local function panToPosition(pan)
    return (pan + 1) / 2
end

-- Format pan value for display
local function formatPan(pan)
    local percentage = math.floor(math.abs(pan) * 100 + 0.5)
    if pan < -0.01 then
        return percentage .. "L"
    elseif pan > 0.01 then
        return percentage .. "R"
    else
        return "C"
    end
end

-- ===========================
-- OSC HANDLING
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Get track info
    local trackNum, tType = getTrackInfo()
    if not trackNum then
        return false
    end
    
    -- Check if this is a pan message for our track type
    local isPanMessage = false
    
    if tType == "return" and path == "/live/return/get/panning" then
        isPanMessage = true
    elseif (tType == "regular" or tType == "track") and path == "/live/track/get/panning" then
        isPanMessage = true
    end
    
    if not isPanMessage then
        return false
    end
    
    -- Check connection
    local myConnection = connectionIndex or getConnectionIndex()
    if connections and not connections[myConnection] then
        return false
    end
    
    -- Check track number
    local msgTrackNumber = arguments[1].value
    if msgTrackNumber ~= trackNum then
        return false
    end
    
    -- Update pan position
    local panValue = arguments[2].value
    lastOscValue = panValue
    
    -- Only update visual if not touching
    if not isTouching then
        local position = panToPosition(panValue)
        self.values.x = position
        log(string.format("Received pan position from Ableton: %.2f", panValue))
        
        -- Mark as initialized once we receive first value
        if not isInitialized then
            isInitialized = true
            log("Pan control initialized with Ableton position")
        end
    end
    
    return false
end

-- Send pan value with connection routing
local function sendPan(panValue)
    local trackNum, tType = getTrackInfo()
    if not trackNum then
        return
    end
    
    local conns = buildConnectionTable(connectionIndex or getConnectionIndex())
    local path = tType == "return" and '/live/return/set/panning' or '/live/track/set/panning'
    
    sendOSC(path, trackNum, panValue, conns)
    log(string.format("Sent pan value: %.2f to %s track %d", panValue, tType, trackNum))
end

-- Request current pan position
local function requestPanPosition()
    local trackNum, tType = getTrackInfo()
    if not trackNum then
        return
    end
    
    local conns = buildConnectionTable(connectionIndex or getConnectionIndex())
    local path = tType == "return" and '/live/return/get/panning' or '/live/track/get/panning'
    
    sendOSC(path, trackNum, conns)
    log("Requested pan position from Ableton")
end

-- ===========================
-- VALUE CHANGE HANDLING
-- ===========================

function onValueChanged()
    -- Only process if track is mapped
    local trackNum = getTrackInfo()
    if not trackNum then
        return
    end
    
    -- Get current position
    local position = self.values.x
    local panValue = positionToPan(position)
    
    -- Handle touch state
    if self.values.touch then
        if not isTouching then
            isTouching = true
            log("Touch started")
            
            -- Send touch notification to parent
            if parentGroup then
                parentGroup:notify("child_touched", self.name)
            end
        end
        
        -- Send pan value
        sendPan(panValue)
        
    else
        -- Touch released
        if isTouching then
            isTouching = false
            log("Touch released")
            
            -- Check for double-tap
            local currentTime = getMillis()
            if currentTime - lastTapTime < DOUBLE_TAP_TIME then
                -- Double-tap detected - center pan
                self.values.x = 0.5
                sendPan(0.0)
                alwaysLog("Double-tap detected - pan centered")
                lastTapTime = 0
            else
                lastTapTime = currentTime
            end
            
            -- Send touch release notification
            if parentGroup then
                parentGroup:notify("child_released", self.name)
            end
        end
    end
end

-- ===========================
-- NOTIFICATIONS
-- ===========================

function onReceiveNotify(key, value)
    if key == "track_changed" then
        trackNumber = value
        trackType = nil  -- Will be set by track_type notification
        connectionIndex = getConnectionIndex()
        isInitialized = false
        
        -- Request current pan position
        requestPanPosition()
        log("Track changed - waiting for OSC pan position")
        
    elseif key == "track_type" then
        trackType = value
        log("Track type set to: " .. tostring(trackType))
        
    elseif key == "track_unmapped" then
        trackNumber = nil
        trackType = nil
        isInitialized = false
        self.values.x = 0.5  -- Center position
        log("Track unmapped - reset to center")
        
    elseif key == "connection_changed" then
        connectionIndex = getConnectionIndex()
        log("Connection changed to: " .. connectionIndex)
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging only when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] PAN(" .. (self.parent and self.parent.name or "unknown") .. "): Script v" .. VERSION .. " loaded")
        print("[" .. os.date("%H:%M:%S") .. "] PAN(" .. (self.parent and self.parent.name or "unknown") .. "): Initialized for parent: " .. (self.parent and self.parent.name or "unknown"))
    end
    
    -- Find parent group
    if not findParentGroup() then
        alwaysLog("ERROR: No parent group found")
        return
    end
    
    -- Set initial position to center
    self.values.x = 0.5
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    if trackNumber then
        connectionIndex = getConnectionIndex()
        requestPanPosition()
    end
    
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] PAN(" .. parentGroup.name .. "): Waiting for valid position from Ableton...")
    end
end

init()