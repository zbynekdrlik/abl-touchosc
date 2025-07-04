-- TouchOSC Fader Script - Advanced Volume and Send Control
-- Version: 2.5.6
-- Removed: All logger references and centralized logging
-- Optimized: Time-based position sync instead of schedule()
-- Fixed: TouchOSC doesn't have schedule() method
-- Fixed: Removed has_valid_position check - fader works immediately
-- Added: Support for both track volume and send controls
-- Changed: DEBUG = 1 for troubleshooting

-- Version constant
local VERSION = "2.5.6"

-- Debug mode (set to 1 for debug output)
local DEBUG = 1  -- Enable debug for troubleshooting

-- Control type detection
local CONTROL_TYPE = nil  -- Will be "volume" or "send"
local SEND_INDEX = nil    -- For send controls

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

local function debug(...)
    if DEBUG == 0 then return end
    
    local args = {...}
    local msg = table.concat(args, " ")
    print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") " .. msg)
end

local function log(message)
    -- Always log important messages
    local timestamp = os.date("%H:%M:%S")
    print("[" .. timestamp .. "] CONTROL(" .. self.name .. ") " .. message)
end

-- ===========================
-- STATE VARIABLES
-- ===========================

-- Control state
local parentGroup = nil
local connectionIndex = nil
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local connections = nil

-- Position state
local currentAbletonValue = nil
local lastSentValue = nil
local lastReceivedValue = nil
local isInternalUpdate = false
local isUserInteracting = false  -- Track active user interaction

-- Touch state
local isTouched = false
local touchStartTime = 0
local touchReleaseTime = 0
local hasSentTouch = false

-- Timing variables for position sync
local lastPositionSyncTime = 0
local POSITION_SYNC_INTERVAL = 5.0  -- 5 seconds between syncs

-- Send control variables
local sendNames = {}  -- Table to store send names

-- ===========================
-- CONTROL TYPE DETECTION
-- ===========================

local function detectControlType()
    -- Check if this is a send control by name pattern
    if self.name:match("^send_%d+$") then
        CONTROL_TYPE = "send"
        -- Extract send index (0-based for Ableton)
        SEND_INDEX = tonumber(self.name:match("(%d+)")) - 1
        debug("Detected as SEND control, index: " .. SEND_INDEX)
    else
        CONTROL_TYPE = "volume"
        debug("Detected as VOLUME control")
    end
end

-- ===========================
-- DB/LINEAR CONVERSION
-- ===========================

local DB_THRESHOLD = -60.0

local function linearToDb(linear)
    if linear <= 0 then
        return -math.huge
    elseif linear >= 1.0 then
        return 6.0  -- Max at +6 dB
    else
        -- TouchOSC seems to use this formula based on testing
        local db = 20.0 * math.log10(linear)
        -- Clamp to reasonable range
        if db < DB_THRESHOLD then
            return DB_THRESHOLD
        end
        return db
    end
end

local function dbToLinear(db)
    if db <= DB_THRESHOLD then
        return 0.0
    elseif db >= 6.0 then
        return 1.0
    else
        return 10.0 ^ (db / 20.0)
    end
end

-- ===========================
-- PARENT GROUP HELPERS
-- ===========================

local function findParentGroup()
    if self.parent and self.parent.name then
        parentGroup = self.parent
        
        -- Get connection from parent's tag
        if parentGroup.tag then
            local parts = {}
            for part in string.gmatch(parentGroup.tag, "[^:]+") do
                table.insert(parts, part)
            end
            
            if #parts >= 3 then
                trackNumber = tonumber(parts[2])
                trackType = parts[3]
                debug("From parent tag - Track: " .. tostring(trackNumber) .. ", Type: " .. trackType)
            end
        end
        
        return true
    end
    return false
end

-- ===========================
-- CONNECTION MANAGEMENT
-- ===========================

local function setupConnections()
    if not parentGroup then return false end
    
    -- Try to get connection index from parent's script functions
    local success, result = pcall(function()
        if parentGroup.getConnectionIndex then
            return parentGroup:getConnectionIndex()
        elseif _G.getConnectionIndex then
            local instance = parentGroup.name:match("^(%w+)_")
            return _G.getConnectionIndex(instance)
        end
        return nil
    end)
    
    if success and result then
        connectionIndex = result
    else
        -- Try to find connection from document script
        local docScript = root:findByName("document_script", true)
        if docScript and docScript.getConnectionForInstance then
            local instance = parentGroup.name:match("^(%w+)_")
            connectionIndex = docScript:getConnectionForInstance(instance)
        end
    end
    
    if not connectionIndex then
        log("Warning: Could not determine connection index, using default (1)")
        connectionIndex = 1
    end
    
    -- Build connection table
    connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    
    debug("Connection index: " .. connectionIndex)
    return true
end

-- ===========================
-- SEND NAME DISCOVERY
-- ===========================

local function discoverSendNames()
    if CONTROL_TYPE ~= "send" or not connections then
        return
    end
    
    -- Request send names from Ableton
    sendOSC('/live/song/get/return_track_names', connections)
    debug("Requested send names from Ableton")
end

local function updateSendLabel()
    if CONTROL_TYPE ~= "send" or not sendNames[SEND_INDEX + 1] then
        return
    end
    
    -- Find the send label control (sibling with name "send_X_label")
    local labelName = "send_" .. (SEND_INDEX + 1) .. "_label"
    local label = self.parent:findByName(labelName, false)
    
    if label then
        local sendName = sendNames[SEND_INDEX + 1]
        -- Extract just the first word or use full name if short
        local displayName = sendName:match("^(%w+)") or sendName
        if #displayName > 8 then
            displayName = displayName:sub(1, 8)
        end
        label.values.text = displayName
        debug("Updated send label to: " .. displayName)
    end
end

-- ===========================
-- OSC COMMUNICATION
-- ===========================

local function sendFaderPosition(value)
    if not trackNumber or not connections or isInternalUpdate then
        return
    end
    
    -- Debounce rapid changes
    if lastSentValue and math.abs(value - lastSentValue) < 0.001 then
        return
    end
    
    lastSentValue = value
    
    -- Build appropriate OSC path based on control type
    local oscPath
    if CONTROL_TYPE == "send" then
        if trackType == "return" then
            -- Return tracks don't have sends
            debug("Warning: Return tracks don't have sends")
            return
        else
            oscPath = '/live/track/set/send'
        end
    else  -- volume
        if trackType == "return" then
            oscPath = '/live/return/set/volume'
        else
            oscPath = '/live/track/set/volume'
        end
    end
    
    -- Send appropriate message
    if CONTROL_TYPE == "send" then
        sendOSC(oscPath, trackNumber, SEND_INDEX, value, connections)
        debug(string.format("Sent send %d position: %.3f to track %d", SEND_INDEX, value, trackNumber))
    else
        sendOSC(oscPath, trackNumber, value, connections)
        local db = linearToDb(value)
        debug(string.format("Sent volume: %.3f (%.1f dB) to %s %d", value, db, trackType, trackNumber))
    end
end

local function requestCurrentPosition()
    if not trackNumber or not connections then
        return
    end
    
    -- Build appropriate OSC path
    local oscPath
    if CONTROL_TYPE == "send" then
        if trackType == "return" then
            return  -- Return tracks don't have sends
        else
            oscPath = '/live/track/get/send'
        end
    else  -- volume
        if trackType == "return" then
            oscPath = '/live/return/get/volume'
        else
            oscPath = '/live/track/get/volume'
        end
    end
    
    -- Request current value
    if CONTROL_TYPE == "send" then
        sendOSC(oscPath, trackNumber, SEND_INDEX, connections)
        debug("Requested send " .. SEND_INDEX .. " value from track " .. trackNumber)
    else
        sendOSC(oscPath, trackNumber, connections)
        debug("Requested volume from " .. trackType .. " " .. trackNumber)
    end
end

-- ===========================
-- POSITION MANAGEMENT
-- ===========================

local function updateFaderPosition(value, source)
    if source == "ableton" then
        isInternalUpdate = true
        currentAbletonValue = value
        lastReceivedValue = value
        
        -- Only update if user is not touching
        if not isTouched then
            self.values.x = value
            local db = linearToDb(value)
            if CONTROL_TYPE == "send" then
                debug(string.format("Send %d position from Ableton: %.3f", SEND_INDEX, value))
            else
                debug(string.format("Volume from Ableton: %.3f (%.1f dB)", value, db))
            end
        else
            debug("Ignored Ableton update - user is touching")
        end
        
        isInternalUpdate = false
    elseif source == "user" and not isInternalUpdate then
        sendFaderPosition(value)
    end
end

-- ===========================
-- OSC RECEIVE HANDLER
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local args = message[2]
    
    -- Handle return track names for send labels
    if CONTROL_TYPE == "send" and path == '/live/song/get/return_track_names' then
        sendNames = {}
        for i = 1, #args do
            sendNames[i] = args[i].value
            debug("Return track " .. (i-1) .. ": " .. args[i].value)
        end
        updateSendLabel()
        return false
    end
    
    -- Check if message is for our track
    if not trackNumber or #args < 2 then
        return false
    end
    
    local msgTrack = args[1].value
    if msgTrack ~= trackNumber then
        return false
    end
    
    -- Handle send values
    if CONTROL_TYPE == "send" then
        if path == '/live/track/get/send' and #args >= 3 then
            local sendIndex = args[2].value
            local value = args[3].value
            
            if sendIndex == SEND_INDEX then
                updateFaderPosition(value, "ableton")
                return true
            end
        end
    -- Handle volume values
    else
        if (trackType == "return" and path == '/live/return/get/volume') or
           (trackType == "track" and path == '/live/track/get/volume') then
            local value = args[2].value
            updateFaderPosition(value, "ableton")
            return true
        end
    end
    
    return false
end

-- ===========================
-- TOUCH HANDLING
-- ===========================

function onValueChanged(valueName)
    if valueName == "x" and not isInternalUpdate then
        local value = self.values.x
        
        -- Always allow user input, even without Ableton connection
        updateFaderPosition(value, "user")
        
        -- Notify parent group of activity
        if parentGroup and parentGroup.notify then
            parentGroup:notify("value_changed", "fader")
        end
    elseif valueName == "touch" then
        isTouched = self.values.touch
        
        if isTouched then
            touchStartTime = os.clock()
            isUserInteracting = true
            
            -- Send touch on
            if trackNumber and connections and not hasSentTouch then
                local oscPath
                if CONTROL_TYPE == "send" then
                    -- Sends don't have touch parameters in Live's API
                    debug("Send " .. SEND_INDEX .. " touched")
                else
                    if trackType == "return" then
                        oscPath = '/live/return/set/volume/touched'
                    else
                        oscPath = '/live/track/set/volume/touched'
                    end
                    sendOSC(oscPath, trackNumber, true, connections)
                    hasSentTouch = true
                    debug("Sent touch ON")
                end
            end
        else
            touchReleaseTime = os.clock()
            isUserInteracting = false
            local touchDuration = touchReleaseTime - touchStartTime
            
            -- Send touch off
            if trackNumber and connections and hasSentTouch then
                local oscPath
                if CONTROL_TYPE == "send" then
                    debug(string.format("Send %d released (duration: %.2fs)", SEND_INDEX, touchDuration))
                else
                    if trackType == "return" then
                        oscPath = '/live/return/set/volume/touched'
                    else
                        oscPath = '/live/track/set/volume/touched'
                    end
                    sendOSC(oscPath, trackNumber, false, connections)
                    hasSentTouch = false
                    debug(string.format("Sent touch OFF (duration: %.2fs)", touchDuration))
                end
            end
            
            -- Request current position after release
            requestCurrentPosition()
        end
        
        -- Notify parent of activity
        if parentGroup and parentGroup.notify then
            parentGroup:notify("value_changed", "fader_touch")
        end
    end
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    debug("Received notify: " .. key .. " = " .. tostring(value))
    
    if key == "track_changed" then
        trackNumber = value
        debug("Track number updated to: " .. tostring(trackNumber))
        
        -- Request current position and send names
        requestCurrentPosition()
        if CONTROL_TYPE == "send" then
            discoverSendNames()
        end
    elseif key == "track_type" then
        trackType = value
        debug("Track type updated to: " .. tostring(trackType))
    elseif key == "connection_changed" then
        setupConnections()
    elseif key == "track_unmapped" then
        trackNumber = nil
        trackType = nil
        debug("Track unmapped - fader disabled")
    end
end

-- ===========================
-- UPDATE FUNCTION
-- ===========================

function update()
    -- Periodic position sync when not touched
    if not isTouched and trackNumber and connections then
        local now = os.clock()
        if now - lastPositionSyncTime > POSITION_SYNC_INTERVAL then
            requestCurrentPosition()
            lastPositionSyncTime = now
        end
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Fader v" .. VERSION)
    
    -- Detect control type
    detectControlType()
    
    -- Find parent group
    if not findParentGroup() then
        log("Warning: No parent group found")
        return
    end
    
    -- Setup connections
    setupConnections()
    
    -- Set initial visual state
    self.values.x = 0.0
    
    -- Request initial position
    if trackNumber then
        requestCurrentPosition()
        if CONTROL_TYPE == "send" then
            discoverSendNames()
        end
    end
    
    debug("Initialization complete")
    debug("Parent: " .. tostring(parentGroup and parentGroup.name or "none"))
    debug("Track: " .. tostring(trackNumber) .. " Type: " .. tostring(trackType))
end

init()
