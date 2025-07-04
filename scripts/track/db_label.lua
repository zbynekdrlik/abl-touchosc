-- TouchOSC dB Display Label with Multi-Connection Support
-- Version: 1.3.4
-- Fixed: Version logging respects DEBUG flag
-- Shows current fader position in dB with connection routing

local VERSION = "1.3.4"

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 for detailed logging

-- State
local parentGroup = nil
local currentDb = -math.huge
local lastLoggedDb = nil

-- Curve settings (must match fader)
local use_log_curve = true
local log_exponent = 0.515

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "DB_LABEL"
        if parentGroup and parentGroup.name then
            context = "DB_LABEL(" .. parentGroup.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONVERSION FUNCTIONS
-- ===========================

function linearToLog(linear_pos)
    if not linear_pos or linear_pos <= 0 then return 0
    elseif linear_pos >= 1 then return 1
    else return math.pow(linear_pos, log_exponent) end
end

function value2db(vl)
    if not vl then return -math.huge end
    
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
            return -math.huge
        else
            return db_value_str
        end
    else
        return 0
    end
end

function formatDB(db_value)
    if db_value == -math.huge or db_value < -100 then
        return "-∞"
    else
        return string.format("%.1f", db_value)
    end
end

-- ===========================
-- PARENT GROUP HELPERS
-- ===========================

local function findParentGroup()
    if self.parent and self.parent.name then
        parentGroup = self.parent
        log("Found parent group: " .. parentGroup.name)
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

-- ===========================
-- OSC HANDLING
-- ===========================

function onReceiveOSC(message, connections)
    local path = message[1]
    local arguments = message[2]
    
    -- Get track info from parent
    local trackNumber, trackType = getTrackInfo()
    if not trackNumber then
        return false
    end
    
    -- Check message type based on track type
    local isVolumeMessage = false
    
    if trackType == "return" and path == "/live/return/get/volume" then
        isVolumeMessage = true
    elseif (trackType == "regular" or trackType == "track") and path == "/live/track/get/volume" then
        isVolumeMessage = true
    end
    
    if not isVolumeMessage then
        return false
    end
    
    -- Get our connection
    local myConnection = getConnectionIndex()
    if connections and not connections[myConnection] then
        return false
    end
    
    -- Check track number
    local msgTrackNumber = arguments[1].value
    if msgTrackNumber ~= trackNumber then
        return false
    end
    
    -- Update dB display
    local volumeValue = arguments[2].value
    currentDb = value2db(volumeValue)
    self.values.text = formatDB(currentDb)
    
    -- Log significant changes
    if DEBUG == 1 and lastLoggedDb then
        local change = math.abs(currentDb - lastLoggedDb)
        if change > 0.5 or currentDb == -math.huge or lastLoggedDb == -math.huge then
            log(string.format("Volume: %.3f → %s dB", volumeValue, formatDB(currentDb)))
            lastLoggedDb = currentDb
        end
    elseif DEBUG == 1 then
        log(string.format("Initial volume: %.3f → %s dB", volumeValue, formatDB(currentDb)))
        lastLoggedDb = currentDb
    end
    
    return false
end

-- ===========================
-- NOTIFICATIONS
-- ===========================

function onReceiveNotify(key, value)
    if key == "sibling_value_changed" and value == "fader" then
        -- Fader moved locally - update immediately
        local fader = parentGroup:findByName("fader", false)
        if fader and fader.values and fader.values.x then
            local faderPos = fader.values.x
            local audioValue = use_log_curve and linearToLog(faderPos) or faderPos
            currentDb = value2db(audioValue)
            self.values.text = formatDB(currentDb)
            log("Updated from fader: " .. formatDB(currentDb) .. " dB")
        end
        
    elseif key == "track_changed" then
        -- Reset when track changes
        currentDb = -math.huge
        self.values.text = formatDB(currentDb)
        lastLoggedDb = nil
        log("Track changed - reset to -∞")
        
    elseif key == "track_unmapped" then
        -- Clear when unmapped
        currentDb = -math.huge
        self.values.text = formatDB(currentDb)
        lastLoggedDb = nil
        log("Track unmapped - cleared")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging only when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] DB_LABEL: Script v" .. VERSION .. " loaded")
    end
    
    -- Find parent group
    if not findParentGroup() then
        print("[" .. os.date("%H:%M:%S") .. "] DB_LABEL: ERROR - No parent group found")
        return
    end
    
    -- Initialize display
    self.values.text = formatDB(currentDb)
    
    log("Initialized - ready for updates")
end

init()