-- SIMPLE METER SCRIPT WITH HARDCODED CALIBRATION
-- Uses your exact calibration data to directly map AbletonOSC values to fader positions

-- DEBUG MODE
local DEBUG = 0  -- Set to 1 to see meter values and conversions in console

-- COLOR THRESHOLDS (in dB)
local COLOR_THRESHOLD_YELLOW = -12    -- Above this = yellow (caution)
local COLOR_THRESHOLD_RED = -3        -- Above this = red (clipping warning)

-- COLOR DEFINITIONS (RGBA values 0-1)
local COLOR_GREEN = {0.0, 0.8, 0.0, 1.0}     -- Normal level
local COLOR_YELLOW = {1.0, 0.8, 0.0, 1.0}    -- Caution level  
local COLOR_RED = {1.0, 0.0, 0.0, 1.0}       -- Clipping level

-- Smooth color transitions
local current_color = {COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4]}
local color_smoothing = 0.3  -- Smoothing factor (0-1, higher = faster)

-- HARDCODED CALIBRATION BASED ON YOUR EXACT FADER DATA
local CALIBRATION_POINTS = {
  -- AbletonOSC value -> Fader position (EXACT from your fader_volume logs)
  {0.0, 0.0},      -- Silent -> 0%
  {0.3945, 0.027}, -- -40dB -> 2.7% (EXACT from your fader_volume log!)
  {0.6839, 0.169}, -- -18dB -> 16.9% (EXACT from your fader_volume log!)
  {0.7629, 0.313}, -- -12dB -> 31.3% (EXACT from your fader_volume log!)
  {0.8399, 0.5},   -- -6dB -> 50% (verified working)
  {0.9200, 0.729}, -- 0dB -> 72.9% (verified working)  
  {1.0, 1.0}       -- Max -> 100%
}

function debugPrint(...)
  if DEBUG == 1 then
    print(...)
  end
end

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

-- CURVE SETTINGS - Must exactly match fader curve
local use_log_curve = true
local log_exponent = 0.515

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

function onReceiveOSC(message, connections)
  local arguments = message[2]
  
  -- Check if this message is for our track
  if arguments[1].value == tonumber(self.parent.tag) then
    local normalized_meter = arguments[2].value
    
    debugPrint("=== METER UPDATE ===")
    debugPrint("AbletonOSC normalized:", string.format("%.4f", normalized_meter))
    
    -- Convert AbletonOSC normalized value to fader position
    local fader_position = abletonToFaderPosition(normalized_meter)
    
    -- Update meter position
    self.values.x = fader_position
    
    -- Get target color based on fader position
    local target_color = getColorForLevel(fader_position)
    
    -- Apply smoothed color transition
    local smoothed = smoothColor(target_color)
    self.color = Color(smoothed[1], smoothed[2], smoothed[3], smoothed[4])
    
    debugPrint("→ Fader position:", string.format("%.1f%%", fader_position * 100))
    
    -- Calculate actual dB for display
    local audio_value = linearToLog(fader_position)
    local actual_db = value2db(audio_value)
    debugPrint("→ Actual dB:", string.format("%.1f", actual_db))
    debugPrint("→ Color:", actual_db >= COLOR_THRESHOLD_RED and "RED" or
                         actual_db >= COLOR_THRESHOLD_YELLOW and "YELLOW" or "GREEN")
    
    -- Calibration checks
    if math.abs(normalized_meter - 0.3945) < 0.01 then
      debugPrint("*** -40dB CALIBRATION POINT ***")
    elseif math.abs(normalized_meter - 0.6839) < 0.01 then
      debugPrint("*** -18dB CALIBRATION POINT ***")
    elseif math.abs(normalized_meter - 0.7629) < 0.01 then
      debugPrint("*** -12dB CALIBRATION POINT ***")
    elseif math.abs(normalized_meter - 0.8399) < 0.01 then
      debugPrint("*** -6dB CALIBRATION POINT ***")
    elseif math.abs(normalized_meter - 0.9200) < 0.01 then
      debugPrint("*** 0dB CALIBRATION POINT ***")
    end
  end
end

-- Initialize
function init()
  -- Set initial color to green
  self.color = Color(COLOR_GREEN[1], COLOR_GREEN[2], COLOR_GREEN[3], COLOR_GREEN[4])
  
  -- Initialize meter at minimum
  self.values.x = 0
  
  print("=== SIMPLE METER SCRIPT ===")
  print("Using hardcoded calibration points from your tests")
  print("")
  print("Calibration points:")
  for i, point in ipairs(CALIBRATION_POINTS) do
    local ableton_val = point[1]
    local fader_pos = point[2]
    
    if ableton_val == 0.3945 then
      print(string.format("  %.4f → %.1f%% (-40dB) EXACT MATCH", ableton_val, fader_pos * 100))
    elseif ableton_val == 0.6839 then
      print(string.format("  %.4f → %.1f%% (-18dB) EXACT MATCH", ableton_val, fader_pos * 100))
    elseif ableton_val == 0.7629 then
      print(string.format("  %.4f → %.1f%% (-12dB) EXACT MATCH", ableton_val, fader_pos * 100))
    elseif ableton_val == 0.8399 then
      print(string.format("  %.4f → %.1f%% (-6dB) ✓", ableton_val, fader_pos * 100))
    elseif ableton_val == 0.9200 then
      print(string.format("  %.4f → %.1f%% (0dB) ✓", ableton_val, fader_pos * 100))
    else
      print(string.format("  %.4f → %.1f%%", ableton_val, fader_pos * 100))
    end
  end
  print("")
  print("This should work without errors!")
  print("Test with -12dB to see if positioning is correct.")
end

init()