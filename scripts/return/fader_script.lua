-- TouchOSC Return Track Fader Script
-- Version: 1.0.0
-- Based on track fader but adapted for return tracks

-- Version constant
local VERSION = "1.0.0"

-- Configuration
local DEBUG = 0  -- Set to 1 for debug logging
local use_log_curve = true
local log_exponent = 0.515
local delay = 1000  -- Sync delay after touch release

-- State variables
local touched = false
local last_osc_x = 0
local last_osc_audio = 0
local last = 0 
local synced = true

-- Centralized logging
local function log(message)
    local context = "RETURN_FADER"
    if self.parent and self.parent.name then
        context = "RETURN_FADER(" .. self.parent.name .. ")"
    end
    
    root:notify("log_message", context .. ": " .. message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Debug print
function debugPrint(...)
    if DEBUG == 1 then
        local args = {...}
        local msg = table.concat(args, " ")
        log(msg)
    end
end

-- Get connection configuration
local function getConnectionIndex()
    if self.parent and self.parent.tag then
        -- Find configuration object
        local configObj = root:findByName("configuration", true)
        if not configObj or not configObj.values or not configObj.values.text then
            return 1
        end
        
        local configText = configObj.values.text
        local searchKey = "connection_return:"
        
        for line in configText:gmatch("[^\r\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line:sub(1, #searchKey) == searchKey then
                local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                return tonumber(value) or 1
            end
        end
    end
    return 1
end

-- Build connection table
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Get return track number from parent
local function getReturnNumber()
    if self.parent and self.parent.tag then
        local instance, returnNum = self.parent.tag:match("(%w+):(%d+)")
        if returnNum then
            return tonumber(returnNum)
        end
    end
    return nil
end

-- Check if return track is mapped
local function isReturnMapped()
    if not self.parent or not self.parent.tag then
        return false
    end
    local instance, returnNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and returnNum ~= nil
end

-- Curve conversion functions
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

-- dB conversion
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
        return "-∞dB"
    else
        return string.format("%.1fdB", db_value)
    end
end

-- Send OSC with routing
local function sendOSCRouted(path, returnNum, volume)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    sendOSC(path, returnNum, volume, connections)
end

-- Handle incoming OSC
function onReceiveOSC(message, connections)
    local myReturnNumber = getReturnNumber()
    if not myReturnNumber then
        return false
    end
    
    local path = message[1]
    
    -- Check if this is volume data for our return track
    if path == '/live/return/get/volume' then
        local arguments = message[2]
        if arguments and arguments[1] and arguments[1].value == myReturnNumber then
            local remote_audio_value = arguments[2].value
            last_osc_audio = remote_audio_value
            
            if use_log_curve then
                last_osc_x = logToLinear(remote_audio_value)
            else
                last_osc_x = remote_audio_value
            end
            
            -- Only update if not touching
            if not self.values.touch then
                if synced then
                    self.values.x = last_osc_x
                    debugPrint("OSC UPDATE - Fader:", string.format("%.1f%%", last_osc_x * 100))
                end
            else
                touched = true
            end
        end
    end
    
    return false
end

-- Update function for sync delay
function update()
    if touched and not self.values.touch then
        last = getMillis()
        touched = false
        synced = false
        debugPrint("Touch released - starting sync delay")
    end
    
    if not synced and not self.values.touch then
        local now = getMillis()
        if (now - last > delay) then
            self.values.x = last_osc_x
            synced = true
            debugPrint("Sync complete - updated to OSC position")
        end
    end
    
    if self.values.touch and not synced then
        synced = true
    end
end

-- Handle value changes
function onValueChanged()
    if not isReturnMapped() then
        debugPrint("Return track not mapped - ignoring")
        return
    end
    
    local fader_position = self.values.x
    local audio_value = use_log_curve and linearToLog(fader_position) or fader_position
    local db_value = value2db(audio_value)
    
    debugPrint("Fader moved:", string.format("%.1f%%", fader_position * 100), formatDB(db_value))
    
    -- Send OSC
    local returnNumber = getReturnNumber()
    if returnNumber then
        sendOSCRouted('/live/return/set/volume', returnNumber, audio_value)
    end
end

-- Handle notifications from parent
function onReceiveNotify(key, value)
    if key == "return_changed" then
        touched = false
        synced = true
        debugPrint("Return track changed - state reset")
    elseif key == "return_unmapped" then
        debugPrint("Return track unmapped")
    end
end

-- Initialization
function init()
    log("Return fader v" .. VERSION .. " loaded")
    
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    debugPrint("DEBUG MODE:", DEBUG == 1 and "ENABLED" or "DISABLED")
end

init()