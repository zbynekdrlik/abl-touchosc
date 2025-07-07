-- TouchOSC Interactive Mute Label Script
-- Version: 2.8.6
-- Combined mute button and label with visual indicator for double-click protection

-- Version constant
local VERSION = "2.8.6"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0  -- Production mode

-- State variables
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local isMuted = false

-- Double-click variables
local lastClickTime = 0
local requiresDoubleClick = false
local pendingStateChange = nil
local firstClickTime = 0

-- Visual feedback variables
local feedbackResetTime = 0
local needsFeedbackReset = false

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "MUTE_LABEL"
        if self.parent and self.parent.name then
            context = "MUTE_LABEL(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- FORWARD DECLARATIONS
-- ===========================

local updateLabelText  -- Forward declaration to avoid ordering issues

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

-- Escape special characters in Lua patterns
local function escapePattern(str)
    -- Escape all special pattern characters
    return str:gsub("([%-%^%$%(%)%%%.%[%]%*%+%?])", "%%%1")
end

-- Check if double-click protection is enabled
local function updateDoubleClickConfig()
    if self.parent and self.parent.name then
        local configObj = root:findByName("configuration", true)
        if configObj and configObj.values and configObj.values.text then
            -- Escape special characters in group name for pattern matching
            local escapedName = escapePattern(self.parent.name)
            -- Look for double_click_mute: 'GroupName' (no instance prefix)
            local searchPattern = "double_click_mute:%s*['\"]?" .. escapedName .. "['\"]?"
            requiresDoubleClick = configObj.values.text:match(searchPattern) ~= nil
            log("Double-click required for '" .. self.parent.name .. "': " .. tostring(requiresDoubleClick))
            
            -- Update text to show/hide warning symbol
            updateLabelText()
            return
        end
    end
    requiresDoubleClick = false
    updateLabelText()
end

-- ===========================
-- VISUAL STATE MANAGEMENT
-- ===========================

-- Update label text based on state
updateLabelText = function()
    -- Update text with optional warning symbol
    local prefix = requiresDoubleClick and "⚠ " or ""
    local state = isMuted and "MUTED" or "MUTE"
    self.values.text = prefix .. state
end

local function updateVisualState()
    -- Update background color based on mute state
    if isMuted then
        -- Muted: Dark red background
        self.background = true
        self.color = Color(0.5, 0, 0, 1)  -- Dark red
    else
        -- Unmuted: Orange background (F39420FF)
        self.background = true
        self.color = Color(0.953, 0.580, 0.125, 1)  -- Orange (#F39420)
    end
    
    -- Update text
    updateLabelText()
    
    log("Updated visual state - muted: " .. tostring(isMuted))
end

local function showClickFeedback()
    -- Show yellow feedback for clicks
    self.color = Color(0.8, 0.8, 0, 1)  -- Yellow
    feedbackResetTime = os.clock() + 0.1  -- 100ms feedback
    needsFeedbackReset = true
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
    -- Debug: Log all value changes
    log("onValueChanged called with valueName: " .. tostring(valueName))
    
    -- CRITICAL FIX: Interactive labels use 'touch' value, not 'x'!
    if valueName == "touch" and self.values.touch == true then
        log("Label touched!")
        
        -- Check if track is mapped
        if not trackNumber or not trackType then
            log("No track mapped, ignoring touch")
            return
        end
        
        -- Show click feedback
        showClickFeedback()
        
        -- Handle double-click protection
        if requiresDoubleClick then
            local currentTime = getMillis()
            
            if pendingStateChange == nil then
                -- First click - store pending state
                pendingStateChange = not isMuted  -- What we want to change to
                firstClickTime = currentTime
                lastClickTime = currentTime
                
                log("First click recorded, waiting for double-click")
                return
            else
                -- Check if this is within double-click window
                if currentTime - firstClickTime <= 500 then
                    -- Double-click detected!
                    log("Double-click detected, toggling mute")
                    
                    -- Clear pending state
                    local newMuteState = pendingStateChange
                    pendingStateChange = nil
                    firstClickTime = 0
                    lastClickTime = 0
                    
                    -- Send the mute command
                    sendMuteCommand(newMuteState)
                else
                    -- Too slow - treat as new first click
                    pendingStateChange = not isMuted
                    firstClickTime = currentTime
                    lastClickTime = currentTime
                    
                    log("Too slow, treating as new first click")
                    return
                end
            end
        else
            -- Single-click mode - toggle immediately
            sendMuteCommand(not isMuted)
        end
    end
end

function sendMuteCommand(muteValue)
    -- Get connection configuration
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    
    -- Determine OSC path based on track type
    local path = trackType == "return" and '/live/return/set/mute' or '/live/track/set/mute'
    
    -- Update internal state immediately for responsive UI
    isMuted = muteValue
    updateVisualState()
    
    log("Sending OSC - path: " .. path .. ", track: " .. trackNumber .. ", mute: " .. tostring(muteValue) .. ", connection: " .. connectionIndex)
    
    -- Send OSC message with boolean value
    sendOSC(path, trackNumber, muteValue, connections)
end

-- ===========================
-- UPDATE LOOP
-- ===========================

function update()
    -- Reset color after feedback
    if needsFeedbackReset and os.clock() >= feedbackResetTime then
        needsFeedbackReset = false
        updateVisualState()  -- Restore normal colors
    end
    
    -- Clear pending double-click if timeout
    if pendingStateChange ~= nil and getMillis() - firstClickTime > 500 then
        pendingStateChange = nil
        firstClickTime = 0
        lastClickTime = 0
        log("Double-click timeout, clearing pending state")
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
        updateDoubleClickConfig()
        pendingStateChange = nil  -- Reset double-click state
        firstClickTime = 0
        lastClickTime = 0
    elseif key == "track_type" then
        trackType = value
    elseif key == "track_unmapped" then
        trackNumber = nil
        trackType = nil
        isMuted = false
        updateVisualState()
        requiresDoubleClick = false
        pendingStateChange = nil
        firstClickTime = 0
        lastClickTime = 0
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Script v" .. VERSION .. " loaded")
    
    -- Get initial track info
    trackNumber, trackType = getTrackInfo()
    
    if trackNumber then
        log("Initialized with track " .. trackNumber .. " type " .. trackType)
    else
        log("No track assigned at init")
    end
    
    -- Set label properties
    self.interactive = true  -- Make label clickable
    self.background = true   -- Enable background
    
    updateDoubleClickConfig()
    
    -- Set initial visual state
    updateVisualState()
end

-- Call init
init()
