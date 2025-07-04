-- TouchOSC Meter dB Display Label
-- Version: 2.6.3
-- Fixed: Version logging respects DEBUG flag
-- Shows exact dB value from meter position with color indication
-- Added: Status indicator integration

local VERSION = "2.6.3"

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 for detailed logging

-- State
local parentGroup = nil
local currentDb = -math.huge
local currentColor = "GREEN"
local lastLoggedDb = nil
local statusIndicator = nil

-- Curve settings (must match meter)
local use_log_curve = true
local log_exponent = 0.515

-- Color thresholds (must match meter)
local COLOR_THRESHOLD_YELLOW = -12
local COLOR_THRESHOLD_RED = -3

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] dBFS: " .. message)
    end
end

-- ===========================
-- CONVERSION FUNCTIONS (from meter)
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
    if db_value == -math.huge or db_value < -70 then
        return "-∞"
    elseif db_value > -0.1 and db_value < 0.1 then
        return "0.0"  -- Clean display for unity
    else
        return string.format("%.1f", db_value)
    end
end

-- Get color name based on dB level
function getColorForDb(db)
    if db >= COLOR_THRESHOLD_RED then
        return "RED"
    elseif db >= COLOR_THRESHOLD_YELLOW then
        return "YELLOW"
    else
        return "GREEN"
    end
end

-- ===========================
-- PARENT GROUP HELPERS
-- ===========================

local function findParentGroup()
    if self.parent and self.parent.name then
        parentGroup = self.parent
        
        -- Find status indicator
        statusIndicator = parentGroup:findByName("status_indicator", false)
        if statusIndicator then
            log("Found status indicator")
        end
        
        return true
    end
    return false
end

-- ===========================
-- DISPLAY UPDATE
-- ===========================

local function updateDisplay(db_value)
    currentDb = db_value
    
    -- Update text
    self.values.text = formatDB(currentDb) .. " dB"
    
    -- Determine color
    local newColor = getColorForDb(currentDb)
    if newColor ~= currentColor then
        currentColor = newColor
        log("Color changed to: " .. currentColor)
    end
    
    -- Update status indicator if available
    if statusIndicator then
        -- Map color to indicator state
        if currentColor == "RED" then
            statusIndicator.values.x = 1.0  -- Full red
            statusIndicator.color = Color(1.0, 0.0, 0.0, 1.0)
        elseif currentColor == "YELLOW" then
            statusIndicator.values.x = 0.5  -- Half yellow
            statusIndicator.color = Color(1.0, 0.8, 0.0, 1.0)
        else
            statusIndicator.values.x = 0.0  -- Empty/green
            statusIndicator.color = Color(0.0, 0.8, 0.0, 1.0)
        end
    end
    
    -- Log significant changes
    if DEBUG == 1 and lastLoggedDb then
        local change = math.abs(currentDb - lastLoggedDb)
        if change > 1.0 or currentDb == -math.huge or lastLoggedDb == -math.huge then
            log(string.format("Level: %s dB (%s)", formatDB(currentDb), currentColor))
            lastLoggedDb = currentDb
        end
    elseif DEBUG == 1 then
        log(string.format("Initial level: %s dB (%s)", formatDB(currentDb), currentColor))
        lastLoggedDb = currentDb
    end
end

-- ===========================
-- NOTIFICATIONS
-- ===========================

function onReceiveNotify(key, value)
    if key == "value_changed" and value == "meter" then
        -- Get meter value directly
        local meter = parentGroup:findByName("meter", false)
        if meter and meter.values and meter.values.x then
            local meterPos = meter.values.x
            
            -- Convert meter position to dB
            local audioValue = linearToLog(meterPos)
            local db = value2db(audioValue)
            
            updateDisplay(db)
        end
        
    elseif key == "track_changed" then
        -- Reset when track changes
        updateDisplay(-math.huge)
        log("Track changed - reset")
        
    elseif key == "track_unmapped" then
        -- Clear when unmapped
        updateDisplay(-math.huge)
        log("Track unmapped - cleared")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging only when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] dBFS: Script v" .. VERSION .. " loaded")
    end
    
    -- Find parent group
    if not findParentGroup() then
        print("[" .. os.date("%H:%M:%S") .. "] dBFS: ERROR - No parent group found")
        return
    end
    
    -- Initialize display
    updateDisplay(-math.huge)
    
    log("Initialized - waiting for meter updates")
end

init()