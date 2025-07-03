-- TouchOSC Return Track Group Initialization Script
-- Version: 1.0.0
-- Based on track group_init.lua but adapted for return tracks

-- Version constant
local SCRIPT_VERSION = "1.0.0"

-- Script-level variables to store group data
local instance = nil
local returnName = nil
local connectionIndex = nil
local lastVerified = 0
local needsRefresh = false
local returnNumber = nil
local returnMapped = false
local lastEnabledState = nil  -- Track last state to prevent spam

-- Activity tracking
local lastSendTime = 0
local lastReceiveTime = 0
local lastFaderValue = nil

-- Centralized logging through document script
local function log(message)
    -- Add context to identify which control sent the log
    local fullMessage = "RETURN_CONTROL(" .. self.name .. ") " .. message
    
    -- Send to document script for proper logging
    root:notify("log_message", fullMessage)
    
    -- Also print to console for immediate feedback during development
    print("[" .. os.date("%H:%M:%S") .. "] " .. fullMessage)
end

-- Get connection configuration
local function getConnectionIndex(inst)
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        log("Warning: No configuration found, using default connection 1")
        return 1
    end
    
    local configText = configObj.values.text
    local searchKey = "connection_" .. inst .. ":"
    
    for line in configText:gmatch("[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")
        if line:sub(1, #searchKey) == searchKey then
            local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
            return tonumber(value) or 1
        end
    end
    
    log("Warning: No config for " .. inst .. " - using default (1)")
    return 1
end

local function buildConnectionTable(connIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connIndex)
    end
    return connections
end

local function parseGroupName(name)
    -- Return tracks use "return_" prefix
    if name:sub(1, 7) == "return_" then
        return "return", name:sub(8)
    else
        return "return", name
    end
end

-- Safe child access helper
local function getChild(parent, name)
    if parent and parent.children and parent.children[name] then
        return parent.children[name]
    end
    return nil
end

-- Forward declaration for monitorActivity
local monitorActivity

-- Update status indicator based on activity
local function updateStatusIndicator()
    local indicator = getChild(self, "status_indicator")
    if not indicator then return end
    
    local currentTime = getMillis()
    local timeSinceSend = currentTime - lastSendTime
    local timeSinceReceive = currentTime - lastReceiveTime
    
    -- Check if mapped
    if returnMapped and returnNumber then
        indicator.visible = true
        
        -- Determine current state based on activity
        if timeSinceSend < 150 then
            -- Recently sent data - blue
            indicator.color = Color(0, 0.5, 1, 1)
        elseif timeSinceReceive < 150 then
            -- Recently received data - yellow
            indicator.color = Color(1, 1, 0, 1)
        elseif timeSinceSend < 500 or timeSinceReceive < 500 then
            -- Fading from active to idle
            local fadeTime = math.min(timeSinceSend, timeSinceReceive) - 150
            local fade = fadeTime / 350  -- 0 to 1 over 350ms
            
            if timeSinceSend < timeSinceReceive then
                -- Fade from blue to green
                indicator.color = Color(0, 0.5 * (1 - fade) + fade, 1 * (1 - fade) + fade * 0, 1)
            else
                -- Fade from yellow to green
                indicator.color = Color(1 * (1 - fade), 1, 0, 1)
            end
        else
            -- Idle - solid green
            indicator.color = Color(0, 1, 0, 1)
        end
    else
        -- Not mapped - red
        indicator.visible = true
        indicator.color = Color(1, 0, 0, 1)
    end
end

-- Monitor fader for outgoing activity
monitorActivity = function()
    local currentTime = getMillis()
    
    -- Check fader for changes (outgoing data)
    local fader = getChild(self, "fader")
    if fader and fader.values and fader.values.x then
        local currentValue = fader.values.x
        if lastFaderValue and math.abs(currentValue - lastFaderValue) > 0.001 then
            lastSendTime = currentTime
        end
        lastFaderValue = currentValue
    end
    
    -- Update status indicator
    updateStatusIndicator()
end

-- Enable/disable all controls in the group - ONLY INTERACTIVITY
local function setGroupEnabled(enabled, silent)
    -- Skip if state hasn't changed to prevent spam
    if lastEnabledState == enabled then
        return
    end
    
    lastEnabledState = enabled
    
    -- Check if we have children
    if not self.children then
        return
    end
    
    local childCount = 0
    
    -- Only check for controls we know exist
    local controlsToCheck = {"fader", "mute", "pan", "meter", "track_label", "db_label"}
    
    for _, name in ipairs(controlsToCheck) do
        local child = getChild(self, name)
        if child and name ~= "status_indicator" and name ~= "connection_label" then
            -- ONLY CHANGE INTERACTIVITY - NO VISUAL CHANGES!
            child.interactive = enabled
            childCount = childCount + 1
        end
    end
    
    -- Update status indicator
    updateStatusIndicator()
    
    -- Only log if not silent
    if not silent then
        log("controls " .. (enabled and "ENABLED" or "DISABLED") .. " (" .. childCount .. " controls)")
    end
end

-- Update connection label if it exists
local function updateConnectionLabel()
    local label = getChild(self, "connection_label")
    if label then
        label.values.text = "RETURN"  -- Fixed label for return tracks
        log("Connection label set to: RETURN")
    end
end

-- Clear all OSC listeners for safety
local function clearListeners()
    if returnNumber and returnMapped then
        local targetConnections = buildConnectionTable(connectionIndex)
        
        -- Stop all listeners for the old return track
        sendOSC('/live/return/stop_listen/volume', returnNumber, targetConnections)
        sendOSC('/live/return/stop_listen/output_meter_level', returnNumber, targetConnections)
        sendOSC('/live/return/stop_listen/mute', returnNumber, targetConnections)
        sendOSC('/live/return/stop_listen/panning', returnNumber, targetConnections)
        
        log("Stopped listeners for return track " .. returnNumber)
    end
end

-- Notify specific children about events
local function notifyChildren(event, value)
    -- Notify specific children we know about
    local childrenToNotify = {"fader", "mute", "pan", "meter", "db_label"}
    
    for _, name in ipairs(childrenToNotify) do
        local child = getChild(self, name)
        if child and child.notify then
            child:notify(event, value)
        end
    end
end

function init()
    -- Set tag programmatically
    self.tag = "returnGroup"
    
    -- Parse group name and store in script variables
    instance, returnName = parseGroupName(self.name)
    connectionIndex = getConnectionIndex(instance)
    
    -- Log initialization
    log("Return group init v" .. SCRIPT_VERSION .. " loaded")
    log("Config - Instance: " .. instance .. ", Return: " .. returnName .. ", Connection: " .. connectionIndex)
    
    -- SAFETY: Disable all controls until properly mapped
    setGroupEnabled(false, true)  -- Silent
    
    -- Update connection label if it exists
    updateConnectionLabel()
    
    -- Initialize track label with the expected return name
    if self.children and self.children["track_label"] then
        -- Use pattern match that captures only word characters
        local displayName = returnName:match("(%w+)")
        if displayName then
            self.children["track_label"].values.text = displayName
        else
            self.children["track_label"].values.text = returnName
        end
    end
    
    log("Ready - waiting for refresh")
end

-- Use update() function instead of schedule for periodic monitoring
function update()
    -- Monitor activity periodically
    monitorActivity()
end

function refreshReturnMapping()
    log("Refreshing return track mapping")
    
    -- SAFETY: Clear any existing listeners and disable controls
    clearListeners()
    setGroupEnabled(false)
    
    needsRefresh = true
    returnMapped = false
    returnNumber = nil  -- Clear old return number
    
    -- Build connection table for our specific connection
    local connections = buildConnectionTable(connectionIndex)
    
    -- Send return track names request to specific connection
    sendOSC('/live/song/get/return_track_names', connections)
end

function onReceiveOSC(message, connections)
    local path = message[1]
    
    -- Check for meter or volume data (activity detection)
    if returnMapped and returnNumber then
        -- Check for meter data
        if path == '/live/return/get/output_meter_level' then
            local returnIndex = message[2] and message[2][1] and message[2][1].value
            if returnIndex == returnNumber then
                lastReceiveTime = getMillis()
            end
        -- Check for volume data
        elseif path == '/live/return/get/volume' then
            local returnIndex = message[2] and message[2][1] and message[2][1].value
            if returnIndex == returnNumber then
                lastReceiveTime = getMillis()
            end
        end
    end
    
    -- Check if this is return track names response
    if path == '/live/song/get/return_track_names' then
        -- Only process if it's from our configured connection
        if not connections[connectionIndex] then 
            return true
        end
        
        if needsRefresh then
            needsRefresh = false  -- Clear flag immediately to prevent re-processing
            
            local arguments = message[2]
            
            if not arguments then
                log("ERROR: No return track names in response")
                setGroupEnabled(false)  -- Keep disabled
                return true
            end
            
            local returnFound = false
            
            for i = 1, #arguments do
                if arguments[i] and arguments[i].value then
                    local returnNameValue = arguments[i].value
                    
                    -- EXACT match only for safety
                    if returnNameValue == returnName then
                        -- Found our return track
                        returnNumber = i - 1
                        lastVerified = getMillis()
                        returnFound = true
                        returnMapped = true
                        
                        log("Mapped to Return Track " .. returnNumber)
                        
                        setGroupEnabled(true)  -- ENABLE controls and show indicator
                        
                        -- Store combined info in tag
                        self.tag = "return:" .. returnNumber
                        
                        -- Notify children using safe method
                        notifyChildren("return_changed", returnNumber)
                        
                        -- Build connection table for our specific connection
                        local targetConnections = buildConnectionTable(connectionIndex)
                        
                        -- Start listeners - send only to our configured connection
                        sendOSC('/live/return/start_listen/volume', returnNumber, targetConnections)
                        sendOSC('/live/return/start_listen/output_meter_level', returnNumber, targetConnections)
                        sendOSC('/live/return/start_listen/mute', returnNumber, targetConnections)
                        sendOSC('/live/return/start_listen/panning', returnNumber, targetConnections)
                        
                        break
                    end
                end
            end
            
            -- Handle return track not found
            if not returnFound then
                log("ERROR: Return track not found: '" .. returnName .. "'")
                setGroupEnabled(false)  -- Keep disabled and hide indicator
                returnNumber = nil  -- Clear any old return number
                
                -- Notify children using safe method
                notifyChildren("return_unmapped", nil)
            end
            
            return true
        end
    end
    
    return false
end

function onReceiveNotify(action)
    if action == "refresh" or action == "refresh_returns" then
        refreshReturnMapping()
    elseif action == "clear_mapping" then
        clearListeners()
        returnMapped = false
        returnNumber = nil
    end
end