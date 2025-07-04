-- TouchOSC Fader Script - Advanced Volume and Send Control
-- Version: 2.5.9
-- Added: Double-tap to jump to 0dB functionality
-- Fixed: Added proper dB conversion function
-- Fixed: Use simple connection detection like main branch
-- Optimized: Event-driven updates, no continuous polling

-- Version constant
local VERSION = "2.5.9"

-- Debug mode (set to 1 for debug output)
local DEBUG = 1  -- Enable debug for troubleshooting

-- Control type detection
local CONTROL_TYPE = nil  -- Will be "volume" or "send"
local SEND_INDEX = nil    -- For send controls

-- DOUBLE-TAP DETECTION SETTINGS
local ENABLE_DOUBLE_TAP = true          -- Set to false to disable double-tap functionality
local DOUBLE_TAP_MAX_TIME = 250         -- Maximum time between taps in milliseconds
local DOUBLE_TAP_MIN_TIME = 50          -- Minimum time between taps to avoid accidental triggers
local DOUBLE_TAP_ANIMATION_SPEED = 0.005 -- Speed of animated movement (0.005 units per update)

-- CURVE SETTINGS FOR -6dB AT 50%
local use_log_curve = true
local log_exponent = 0.515

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
local last_osc_x = 0
local last_osc_audio = 0
local synced = true
local touched = false
local last = 0

-- Touch state
local isTouched = false
local touchStartTime = 0
local touchReleaseTime = 0
local hasSentTouch = false
local touch_started = false
local touch_start_position = 0
local touch_start_time = 0
local last_tap_time = 0
local movement_detected = false
local last_movement_time = 0
local touch_event_count = 0

-- Double-tap animation state
local double_tap_animation_active = false
local double_tap_target_position = 0
local double_tap_start_position = 0

-- Timing variables for position sync
local lastPositionSyncTime = 0
local POSITION_SYNC_INTERVAL = 5.0  -- 5 seconds between syncs
local SYNC_DELAY = 1000  -- 1 second delay after touch release

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
-- CURVE CONVERSION FUNCTIONS
-- ===========================

function linearToLog(linear_pos)
  if linear_pos <= 0 then return 0
  elseif linear_pos >= 1 then return 1
  else return math.pow(linear_pos, log_exponent) end
end

function logToLinear(log_pos)
  if log_pos <= 0 then return 0
  elseif log_pos >= 1 then return 1
  else return math.pow(log_pos, 1/log_exponent) end
end

-- YOUR EXISTING DB CONVERSION FUNCTION
function value2db(vl)
  if vl <= 1 and vl >= 0.4 then
    return 40*vl -34
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
    local db_value_str = beta*(vl^(1/gamma)) - alpha
    if db_value_str <= -70.0 then 
      return -math.huge  -- -inf
    else
      return db_value_str
    end
  else
    return 0
  end
end

function formatDB(db_value)
  if db_value == -math.huge or db_value < -100 then
    return "-∞dB"
  else
    return string.format("%.1fdB", db_value)
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
-- CONNECTION MANAGEMENT (Simplified like main branch)
-- ===========================

local function getConnectionIndex()
    -- Default to connection 1 if can't determine
    local defaultConnection = 1
    
    -- Check parent tag for instance name
    if not parentGroup or not parentGroup.tag then
        return defaultConnection
    end
    
    -- Extract instance name from tag
    local instance = parentGroup.tag:match("^(%w+):")
    if not instance then
        return defaultConnection
    end
    
    -- Find and read configuration
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        debug("No configuration found, using default connection")
        return defaultConnection
    end
    
    -- Parse configuration to find connection for this instance
    local configText = configObj.values.text
    local searchKey = "connection_" .. instance .. ":"
    
    for line in configText:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")  -- Trim whitespace
        if line:sub(1, #searchKey) == searchKey then
            local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
            return tonumber(value) or defaultConnection
        end
    end
    
    debug("No connection found for instance:", instance)
    return defaultConnection
end

local function setupConnections()
    connectionIndex = getConnectionIndex()
    
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
    
    -- Convert to audio value for volume
    local audio_value = use_log_curve and linearToLog(value) or value
    
    -- Send appropriate message
    if CONTROL_TYPE == "send" then
        sendOSC(oscPath, trackNumber, SEND_INDEX, audio_value, connections)
        debug(string.format("Sent send %d position: %.3f to track %d", SEND_INDEX, audio_value, trackNumber))
    else
        sendOSC(oscPath, trackNumber, audio_value, connections)
        local db = value2db(audio_value)
        debug(string.format("Sent volume: %.3f (%.1f dB) to %s %d", audio_value, db, trackType, trackNumber))
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
        last_osc_audio = value
        
        if use_log_curve then
            last_osc_x = logToLinear(value)
        else
            last_osc_x = value
        end
        
        -- Only update if user is not touching and we're synced
        if not isTouched and synced then
            self.values.x = last_osc_x
            if CONTROL_TYPE == "send" then
                debug(string.format("Send %d position from Ableton: %.3f", SEND_INDEX, value))
            else
                local db = value2db(value)
                debug(string.format("Volume from Ableton: %.3f (%.1f dB)", value, db))
            end
        else
            debug("Ignored Ableton update - user is touching or not synced")
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
-- TOUCH AND VALUE HANDLING
-- ===========================

function onValueChanged(valueName)
    if valueName == "x" and not isInternalUpdate then
        local fader_position = self.values.x
        local current_time = getMillis()
        
        -- Skip processing if animation is active and no touch
        if double_tap_animation_active and not self.values.touch then
            return  -- Let update() handle the animation
        end
        
        -- Convert position to audio value for sending
        local audio_value = use_log_curve and linearToLog(fader_position) or fader_position
        local db_value = value2db(audio_value)
        
        -- Send the position change
        updateFaderPosition(fader_position, "user")
        
        -- Enhanced logging
        debug("=== FADER MOVED ===")
        debug("Fader:", string.format("%.1f%%", fader_position * 100))
        debug("Audio:", string.format("%.3f", audio_value), string.format("(%.1f%%)", audio_value * 100))
        debug("dB:", formatDB(db_value))
        debug("Touch:", self.values.touch and "TOUCHING" or "RELEASED")
        
        -- Detect movement for double-tap detection
        if touch_started then
            local movement = math.abs(fader_position - touch_start_position)
            if movement > 0.015 then
                movement_detected = true
                last_movement_time = current_time
            end
        end
        
        -- Notify parent group of activity
        if parentGroup and parentGroup.notify then
            parentGroup:notify("value_changed", "fader")
        end
        
    elseif valueName == "touch" then
        isTouched = self.values.touch
        local current_time = getMillis()
        
        if isTouched then
            touch_started = true
            touch_start_position = self.values.x
            touch_start_time = current_time
            movement_detected = false
            touch_event_count = 1
            isUserInteracting = true
            
            -- Cancel any ongoing double-tap animation
            if ENABLE_DOUBLE_TAP and double_tap_animation_active then
                double_tap_animation_active = false
                debug("*** DOUBLE-TAP ANIMATION CANCELLED - New touch started ***")
            end
            
            debug("*** TOUCH START - Position:", string.format("%.1f%%", touch_start_position * 100))
            
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
            -- Touch released
            touch_started = false
            isUserInteracting = false
            touched = true  -- Mark for sync delay
            synced = false
            last = getMillis()
            
            local total_movement = math.abs(self.values.x - touch_start_position)
            local touch_duration = current_time - touch_start_time
            local time_since_movement = current_time - last_movement_time
            
            debug("*** TOUCH END ***")
            debug("Total movement:", string.format("%.4f", total_movement))
            debug("Touch duration:", touch_duration, "ms")
            
            -- Check for tap (minimal movement, short duration)
            local is_tap = (total_movement < 0.01) and 
                           (touch_duration < 200) and 
                           (not movement_detected or time_since_movement > 100)
            
            if is_tap and ENABLE_DOUBLE_TAP then
                debug("*** VALID TAP DETECTED ***")
                
                local time_since_last_tap = current_time - last_tap_time
                
                if time_since_last_tap < DOUBLE_TAP_MAX_TIME and time_since_last_tap > DOUBLE_TAP_MIN_TIME then
                    debug("*** DOUBLE TAP SUCCESS! ***")
                    debug("Time between taps:", time_since_last_tap, "ms")
                    
                    -- Start animation to 0dB (0.85 linear for Live's scale)
                    if use_log_curve then
                        double_tap_target_position = logToLinear(0.85)
                    else
                        double_tap_target_position = 0.85
                    end
                    
                    double_tap_start_position = self.values.x
                    double_tap_animation_active = true
                    
                    debug("*** STARTING ANIMATION TO 0dB ***")
                    debug("From:", string.format("%.1f%%", double_tap_start_position * 100))
                    debug("To:", string.format("%.1f%%", double_tap_target_position * 100), "0.0dB")
                    
                    last_tap_time = 0
                else
                    last_tap_time = current_time
                end
            else
                last_tap_time = 0
            end
            
            -- Send touch off
            if trackNumber and connections and hasSentTouch then
                local oscPath
                if CONTROL_TYPE == "send" then
                    debug(string.format("Send %d released", SEND_INDEX))
                else
                    if trackType == "return" then
                        oscPath = '/live/return/set/volume/touched'
                    else
                        oscPath = '/live/track/set/volume/touched'
                    end
                    sendOSC(oscPath, trackNumber, false, connections)
                    hasSentTouch = false
                    debug("Sent touch OFF")
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
        
        -- Reset state
        touched = false
        synced = true
        
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
    -- Handle double-tap animation
    if ENABLE_DOUBLE_TAP and double_tap_animation_active then
        if self.values.touch then
            -- Touch detected - cancel animation
            double_tap_animation_active = false
            debug("*** DOUBLE-TAP ANIMATION CANCELLED - Touch detected ***")
        else
            -- Continue animation
            local current_pos = self.values.x
            local distance_to_target = double_tap_target_position - current_pos
            
            -- Determine direction
            local direction = 0
            if distance_to_target > 0 then
                direction = 1
            elseif distance_to_target < 0 then
                direction = -1
            end

            -- If already at target, stop animation
            if direction == 0 then
                self.values.x = double_tap_target_position
                double_tap_animation_active = false
                debug("*** DOUBLE-TAP ANIMATION COMPLETE (Already at target) ***")
                sendFaderPosition(double_tap_target_position)
                return
            end

            local step_size = DOUBLE_TAP_ANIMATION_SPEED
            local proposed_new_position = current_pos + (direction * step_size)

            -- Check if the proposed new position overshoots the target
            if (direction > 0 and proposed_new_position >= double_tap_target_position) or
               (direction < 0 and proposed_new_position <= double_tap_target_position) then
                -- Snap to target
                self.values.x = double_tap_target_position
                double_tap_animation_active = false
                debug("*** DOUBLE-TAP ANIMATION COMPLETE (Snapped to target) ***")
                sendFaderPosition(double_tap_target_position)
            else
                -- Move towards target
                self.values.x = proposed_new_position
                sendFaderPosition(proposed_new_position)
                
                debug("*** DOUBLE-TAP ANIMATION ***")
                debug("Current:", string.format("%.1f%%", proposed_new_position * 100), 
                      "Target:", string.format("%.1f%%", double_tap_target_position * 100))
            end
        end
    end
    
    -- Handle sync delay after touch release
    if touched and not self.values.touch and not synced and not double_tap_animation_active then
        local now = getMillis()
        if (now - last > SYNC_DELAY) then
            debug("*** SYNC DELAY COMPLETE - Updating to OSC position ***")
            debug("Jumping from:", string.format("%.1f%%", self.values.x * 100), 
                  "to:", string.format("%.1f%%", last_osc_x * 100))
            self.values.x = last_osc_x
            synced = true
            touched = false
        end
    end
    
    -- Reset sync if touching again
    if self.values.touch and not synced then
        synced = true
        touched = false
        debug("*** Touch detected during sync delay - cancelling sync ***")
    end
    
    -- Periodic position sync when not touched
    if not isTouched and trackNumber and connections and synced then
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
    
    debug("=== FADER WITH DOUBLE-TAP ===")
    debug("Double-tap feature:", ENABLE_DOUBLE_TAP and "ENABLED" or "DISABLED")
    if ENABLE_DOUBLE_TAP then
        debug("Double-tap timing:")
        debug("- Maximum time between taps:", DOUBLE_TAP_MAX_TIME, "ms")
        debug("- Minimum time between taps:", DOUBLE_TAP_MIN_TIME, "ms")
        debug("- Animation speed:", DOUBLE_TAP_ANIMATION_SPEED * 100, "% per update")
    end
    debug("Curve verification:")
    local test_50 = linearToLog(0.5)
    debug("50% fader:", string.format("%.3f", test_50), "audio", formatDB(value2db(test_50)))
    debug("Unity position:", string.format("%.1f%%", logToLinear(0.85) * 100), "fader")
    
    debug("Initialization complete")
    debug("Parent: " .. tostring(parentGroup and parentGroup.name or "none"))
    debug("Track: " .. tostring(trackNumber) .. " Type: " .. tostring(trackType))
end

init()
