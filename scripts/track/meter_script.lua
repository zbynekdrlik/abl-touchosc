-- TouchOSC Meter Script - Audio Level Display
-- Version: 2.6.2
-- Fixed: Removed parent notification to eliminate lag-causing notification chains
-- Fixed: Direct connection setup like main branch
-- Purpose: Display audio levels from Ableton Live
-- Optimized: Event-driven updates only - no continuous polling!

-- Version constant
local VERSION = "2.6.2"

-- Debug mode
local DEBUG = 0  -- Set to 0 for production (zero overhead)

-- Meter configuration
local METER_MIN_DB = -48.0  -- Minimum dB to display (TouchOSC default)
local METER_MAX_DB = 6.0    -- Maximum dB to display

-- COLOR THRESHOLDS (in dB)
local COLOR_THRESHOLD_YELLOW = -12    -- Above this = yellow (caution)
local COLOR_THRESHOLD_RED = -3        -- Above this = red (clipping warning)

-- COLOR DEFINITIONS (RGBA values 0-1)
local COLOR_GREEN = {0.0, 0.8, 0.0, 1.0}     -- Normal level
local COLOR_YELLOW = {1.0, 0.8, 0.0, 1.0}    -- Caution level  
local COLOR_RED = {1.0, 0.0, 0.0, 1.0}       -- Clipping level

-- Smooth color transitions
local current_color = {COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]}
local color_smoothing = 0.3  -- RESTORED to main branch value for consistency

-- CALIBRATION POINTS (from main branch)
local CALIBRATION_POINTS = {
  {0.0, 0.0},      -- Silent -> 0%
  {0.3945, 0.027}, -- -40dB -> 2.7%
  {0.6839, 0.169}, -- -18dB -> 16.9%
  {0.7629, 0.313}, -- -12dB -> 31.3%
  {0.8399, 0.5},   -- -6dB -> 50%
  {0.9200, 0.729}, -- 0dB -> 72.9%
  {1.0, 1.0}       -- Max -> 100%
}

-- CURVE SETTINGS
local use_log_curve = true
local log_exponent = 0.515

-- State variables
local parentGroup = nil
local trackNumber = nil
local trackType = nil  -- "track" or "return"
local connectionIndex = nil
local connections = nil
local isActive = false
local lastMeterValue = 0

-- ===========================
-- UTILITY FUNCTIONS
-- ===========================

local function debug(...)
    -- Performance guard: early return for zero overhead when DEBUG != 1
    if DEBUG ~= 1 then return end
    
    local args = {...}
    local msg = ""
    for i, v in ipairs(args) do
        if i > 1 then msg = msg .. " " end
        msg = msg .. tostring(v)  -- Convert everything to string
    end
    print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") " .. msg)
end

local function log(message)
    -- FIXED: Respect DEBUG flag for version logging
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] CONTROL(" .. self.name .. ") " .. message)
    end
end

-- ===========================
-- METER CONVERSION FUNCTIONS
-- ===========================

-- Simple linear interpolation between calibration points
function abletonToFaderPosition(normalized)
  if not normalized or normalized <= 0 then
    return 0
  end
  
  if normalized >= 1.0 then
    return 1.0
  end
  
  -- Check for exact calibration matches first
  for _, point in ipairs(CALIBRATION_POINTS) do
    if math.abs(normalized - point[1]) < 0.01 then
      return point[2]
    end
  end
  
  -- Find the two closest points for interpolation
  for i = 1, #CALIBRATION_POINTS - 1 do
    local point1 = CALIBRATION_POINTS[i]
    local point2 = CALIBRATION_POINTS[i + 1]
    
    if normalized >= point1[1] and normalized <= point2[1] then
      -- Linear interpolation
      local ratio = (normalized - point1[1]) / (point2[1] - point1[1])
      local fader_position = point1[2] + ratio * (point2[2] - point1[2])
      return fader_position
    end
  end
  
  -- Fallback
  return normalized
end

-- Convert linear position to logarithmic (must match fader exactly)
function linearToLog(linear_pos)
  if not linear_pos or linear_pos <= 0 then return 0
  elseif linear_pos >= 1 then return 1
  else return math.pow(linear_pos, log_exponent) end
end

-- Convert audio value to dB (EXACT copy from fader script)
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
      return -math.huge  -- -inf
    else
      return db_value_str
    end
  else
    return 0
  end
end

-- Get color based on exact dB calculation from fader position
function getColorForLevel(fader_pos)
  -- Convert fader position to exact dB using fader's math
  local audio_value = linearToLog(fader_pos)
  local actual_db = value2db(audio_value)
  
  if actual_db >= COLOR_THRESHOLD_RED then
    return COLOR_RED
  elseif actual_db >= COLOR_THRESHOLD_YELLOW then
    return COLOR_YELLOW
  else
    return COLOR_GREEN
  end
end

-- Smooth color transitions
function smoothColor(target_color)
  for i = 1, 4 do
    current_color[i] = current_color[i] + (target_color[i] - current_color[i]) * color_smoothing
  end
  return current_color
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
                debug("From parent tag - Track:", trackNumber, "Type:", trackType)
            end
        end
        
        return true
    end
    return false
end

-- ===========================
-- CONNECTION MANAGEMENT
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
    
    debug("Connection index:", connectionIndex)
    return true
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
    
    -- Get our connection index
    local myConnection = connectionIndex or getConnectionIndex()
    
    -- Check if this message is from our connection
    if connections and not connections[myConnection] then
        return false
    end
    
    -- Handle meter level updates based on track type
    local isOurMessage = false
    
    if trackType == "return" then
        isOurMessage = (path == '/live/return/get/output_meter_level')
    else
        isOurMessage = (path == '/live/track/get/output_meter_level')
    end
    
    if isOurMessage then
        -- CRITICAL FIX: AbletonOSC sends a single normalized meter value, not stereo!
        local normalized_meter = args[2].value
        
        -- Convert AbletonOSC normalized value to fader position
        local fader_position = abletonToFaderPosition(normalized_meter)
        
        -- Update meter position
        self.values.x = fader_position
        
        -- Get target color based on fader position
        local target_color = getColorForLevel(fader_position)
        
        -- Apply smoothed color transition
        local smoothed = smoothColor(target_color)
        self.color = Color(smoothed[1], smoothed[2], smoothed[3], smoothed[4])
        
        -- Debug logging (with proper string conversion)
        debug("=== METER UPDATE ===")
        debug("Track Type:", trackType, "Track:", trackNumber, "Connection:", myConnection)
        debug("AbletonOSC normalized:", string.format("%.4f", normalized_meter))
        debug("→ Fader position:", string.format("%.1f%%", fader_position * 100))
        
        -- Calculate actual dB for display
        local audio_value = linearToLog(fader_position)
        local actual_db = value2db(audio_value)
        debug("→ Actual dB:", string.format("%.1f", actual_db))
        debug("→ Color:", actual_db >= COLOR_THRESHOLD_RED and "RED" or
                         actual_db >= COLOR_THRESHOLD_YELLOW and "YELLOW" or "GREEN")
        
        -- Track activity state
        isActive = fader_position > 0.01
        
        -- CRITICAL FIX: REMOVED parent notification that was causing lag!
        -- The db_meter_label receives its own OSC messages directly
        -- No need for notification chains!
        
        lastMeterValue = normalized_meter
        
        return true
    end
    
    return false
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    debug("Received notify:", key, "=", value)
    
    if key == "track_changed" then
        trackNumber = value
        debug("Track number updated to:", trackNumber)
        
        -- FIXED: Setup connections immediately like main branch
        setupConnections()
        
        -- Reset meter when track changes
        self.values.x = 0
        current_color = {COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]}
        self.color = Color(current_color[1], current_color[2], current_color[3], current_color[4])
        lastMeterValue = 0
        
    elseif key == "track_type" then
        trackType = value
        debug("Track type updated to:", trackType)
        
    elseif key == "connection_changed" then
        setupConnections()
        
    elseif key == "track_unmapped" then
        -- Clear display when track is unmapped
        trackNumber = nil
        trackType = nil
        connectionIndex = nil
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
        debug("Warning: No parent group found")
        return
    end
    
    -- FIXED: Setup connections immediately like main branch
    if trackNumber then
        setupConnections()
    end
    
    -- Set initial color to green
    self.color = Color(COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4])
    
    -- Initialize meter to zero
    self.values.x = 0.0
    
    debug("Initialization complete")
    debug("Parent:", parentGroup and parentGroup.name or "none")
    debug("Track:", trackNumber, "Type:", trackType)
    debug("Using calibrated meter conversion")
    debug("Direct OSC updates only - no notification chains!")
end

-- Note: No update() function needed - fully event-driven!
-- The meter only updates when it receives OSC messages

init()