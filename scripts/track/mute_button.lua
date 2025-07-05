-- TouchOSC Mute Button Script
-- Version: 2.1.3
-- Fixed: Force integer values for OSC as TouchOSC converts booleans to floats

-- Version constant
local VERSION = "2.1.3"

-- Debug flag - set to 1 to enable logging
local DEBUG = 1  -- ENABLED FOR DEBUGGING

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
    log("Getting track info from parent...")
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if self.parent and self.parent.tag then
        log("Parent tag: " .. tostring(self.parent.tag))
        local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            log("Parsed track info - number: " .. trackNum .. ", type: " .. trackType)
            return tonumber(trackNum), trackType
        else
            log("Failed to parse parent tag")
        end
    else
        log("No parent or parent tag found")
    end
    return nil, nil
end

-- ===========================
-- VISUAL STATE MANAGEMENT
-- ===========================

local function updateVisualState()
    -- Buttons use values.x for pressed/released state
    -- 0 = pressed/on, 1 = released/off
    -- Let TouchOSC handle the colors based on these states
    local newState = isMuted and 0 or 1
    log("Updating visual state - muted: " .. tostring(isMuted) .. ", x: " .. newState)
    self.values.x = newState
end

-- ===========================
-- OSC HANDLERS
-- ===========================

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
    
    -- Check if this message is for our track and has valid arguments
    if arguments[1] and arguments[1].value == trackNumber and arguments[2] then
        -- Get connection index
        local expectedConnection = getConnectionIndex()
        if connections[expectedConnection] then
            -- Update mute state - handle both boolean and number values
            local muteValue = arguments[2].value
            if type(muteValue) == "boolean" then
                isMuted = muteValue
            else
                -- Convert number to boolean (1 = muted, 0 = unmuted)
                isMuted = (muteValue == 1)
            end
            
            log("Received mute state for track " .. trackNumber .. ": " .. tostring(isMuted))
            updateVisualState()
        end
    end
    
    return false  -- Don't block other receivers
end

-- ===========================
-- USER INTERACTION
-- ===========================

function onValueChanged(valueName)
    -- Handle x value changes (button press/release)
    if valueName == "x" then
        log("X value changed to: " .. self.values.x)
        
        -- Check if track is mapped
        if not trackNumber or not trackType then
            log("No track mapped, ignoring button press")
            return
        end
        
        -- Get connection configuration
        local connectionIndex = getConnectionIndex()
        local connections = buildConnectionTable(connectionIndex)
        
        -- Determine OSC path based on track type
        local path = trackType == "return" and '/live/return/set/mute' or '/live/track/set/mute'
        
        -- IMPORTANT: Invert the x value for mute state
        -- x=0 (pressed) -> send 1 (mute on)
        -- x=1 (released) -> send 0 (mute off)
        local muteValue = (self.values.x == 0) and 1 or 0
        
        -- Update internal state
        isMuted = (muteValue == 1)
        
        log("Sending OSC - path: " .. path .. ", track: " .. trackNumber .. ", mute: " .. muteValue .. ", connection: " .. connectionIndex)
        
        -- Send OSC message with integer value (0 or 1)
        sendOSC(path, trackNumber, muteValue, connections)
    end
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    log("Received notify: " .. key .. " = " .. tostring(value))
    
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
    print("=== MUTE BUTTON INIT START ===")
    log("Script v" .. VERSION .. " loaded")
    
    -- Check parent
    if self.parent then
        log("Parent found: " .. tostring(self.parent.name))
    else
        log("WARNING: No parent found!")
    end
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    
    if trackNumber then
        log("Initialized with track " .. trackNumber .. " type " .. trackType)
    else
        log("No track assigned at init")
    end
    
    -- Set initial visual state
    updateVisualState()
    
    print("=== MUTE BUTTON INIT COMPLETE ===")
end

-- Call init
init()