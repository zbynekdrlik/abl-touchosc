-- TouchOSC Meter Script - Audio Level Display
-- Version: 2.5.3
-- Purpose: Display audio levels from Ableton Live
-- Fixed: Use 'x' property for horizontal meter (not 'value')
-- Optimized: Event-driven updates only - no continuous polling!
-- Changed: DEBUG = 1 for troubleshooting

-- Version constant
local VERSION = "2.5.3"

-- Debug mode
local DEBUG = 1  -- Enable debug for troubleshooting

-- Meter configuration
local METER_MIN_DB = -48.0  -- Minimum dB to display (TouchOSC default)
local METER_MAX_DB = 6.0    -- Maximum dB to display

-- State variables
local parentGroup = nil
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local connectionIndex = nil
local connections = nil

-- Current levels
local currentLevelL = 0.0
local currentLevelR = 0.0
local currentPeak = 0.0
local isActive = false

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
    print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") " .. message)
end

-- ===========================
-- DB CONVERSION
-- ===========================

local function dbToLinear(db)
    if db <= METER_MIN_DB then
        return 0.0
    elseif db >= METER_MAX_DB then
        return 1.0
    else
        -- Map dB range to 0-1
        local normalized = (db - METER_MIN_DB) / (METER_MAX_DB - METER_MIN_DB)
        return math.max(0.0, math.min(1.0, normalized))
    end
end

local function linearToDb(linear)
    if linear <= 0 then
        return -math.huge
    else
        return 20.0 * math.log10(linear)
    end
end

-- ===========================
-- PARENT GROUP HELPERS
-- ===========================

local function findParentGroup()
    if self.parent and self.parent.name then
        parentGroup = self.parent
        
        -- Get track info from parent's tag
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
        debug("Warning: Could not determine connection index, using default (1)")
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
-- METER UPDATE
-- ===========================

local function updateMeterDisplay()
    -- Calculate combined level (peak of L/R)
    currentPeak = math.max(currentLevelL, currentLevelR)
    
    -- Convert to dB for logging
    local peakDb = linearToDb(currentPeak)
    
    -- Map to meter range
    local meterValue = dbToLinear(peakDb)
    
    -- Update meter display using 'x' property for horizontal meter
    self.values.x = meterValue
    
    -- Only log significant changes
    if DEBUG == 1 and (meterValue > 0.01 or (isActive and meterValue == 0)) then
        debug(string.format("Level: %.1f dB (meter: %.3f)", peakDb, meterValue))
    end
    
    -- Track activity state
    isActive = meterValue > 0.01
end

-- ===========================
-- OSC HANDLERS
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local args = message[2]
    
    -- Check if message is for our track
    if not trackNumber or #args < 2 then
        return false
    end
    
    local msgTrack = args[1].value
    if msgTrack ~= trackNumber then
        return false
    end
    
    -- Handle meter level updates based on track type
    local isOurMessage = false
    
    if trackType == "return" then
        isOurMessage = (path == '/live/return/get/output_meter_level')
    else
        isOurMessage = (path == '/live/track/get/output_meter_level')
    end
    
    if isOurMessage and #args >= 3 then
        -- Extract stereo levels
        currentLevelL = args[2].value
        currentLevelR = args[3].value
        
        -- Update display
        updateMeterDisplay()
        
        -- Notify parent of activity (for group fade feature)
        if parentGroup and parentGroup.notify and isActive then
            parentGroup:notify("value_changed", "meter")
        end
        
        return true
    end
    
    return false
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    debug("Received notify: " .. key .. " = " .. tostring(value))
    
    if key == "track_changed" then
        trackNumber = value
        debug("Track number updated to: " .. tostring(trackNumber))
        
        -- Reset meter when track changes
        currentLevelL = 0.0
        currentLevelR = 0.0
        updateMeterDisplay()
        
    elseif key == "track_type" then
        trackType = value
        debug("Track type updated to: " .. tostring(trackType))
        
    elseif key == "connection_changed" then
        setupConnections()
        
    elseif key == "track_unmapped" then
        -- Clear display when track is unmapped
        trackNumber = nil
        trackType = nil
        currentLevelL = 0.0
        currentLevelR = 0.0
        self.values.x = 0.0
        debug("Track unmapped - meter cleared")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Meter v" .. VERSION)
    
    -- Find parent group
    if not findParentGroup() then
        log("Warning: No parent group found")
        return
    end
    
    -- Setup connections
    setupConnections()
    
    -- Initialize meter to zero
    self.values.x = 0.0
    
    debug("Initialization complete")
    debug("Parent: " .. tostring(parentGroup and parentGroup.name or "none"))
    debug("Track: " .. tostring(trackNumber) .. " Type: " .. tostring(trackType))
    debug("Meter range: " .. METER_MIN_DB .. " to " .. METER_MAX_DB .. " dB")
end

-- Note: No update() function needed - fully event-driven!
-- The meter only updates when it receives OSC messages

init()
