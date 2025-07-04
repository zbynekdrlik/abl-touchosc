-- TouchOSC Professional Fader with Movement Smoothing
-- Version: 2.5.1
-- Changed: Removed debugPrint, reduced logging significantly

-- Version constant
local VERSION = "2.5.1"

-- ===========================
-- ORIGINAL CONFIGURATION
-- ===========================

-- Debug flag - set to 1 to enable logging
local debug = 0  -- Default to off for performance

-- GRADUAL FIRST MOVEMENT SCALING SETTINGS
local ENABLE_FIRST_MOVEMENT_SCALING = true
local SCALED_MOVEMENTS_COUNT = 10       -- Total movements with scaling (more for gradual transition)
local INITIAL_SCALE_FACTOR = 0.9        -- Starting scale factor (90% speed - minimal reduction)
local FINAL_SCALE_FACTOR = 1.0          -- Ending scale factor (100% speed)
-- Linear range is approximately -6dB to +6dB where the curve is most linear
-- Below -6dB the curve becomes logarithmic and scaling behavior changes
local LINEAR_RANGE_START = 0.7          -- Start of linear range (approximately -6dB)
local LINEAR_RANGE_END = 1.0            -- End of linear range (+6dB)

-- IMMEDIATE 0.1dB RESPONSE SETTINGS
local MINIMUM_DB_CHANGE = 0.1           -- Minimum dB change to apply immediately
local FORCE_MINIMUM_CHANGE = true       -- Enable immediate minimum change feature

-- REACTION TIME COMPENSATION
-- After forcing 0.1dB change, apply slow scaling for next few movements
-- This compensates for the user's finger already being in motion
-- Only activates when first movement was forced to 0.1dB
local REACTION_MOVEMENTS = 3            -- Number of movements after 0.1dB forcing with extra scaling
local REACTION_SCALE_FACTOR = 0.3       -- Slower speed (30%) for reaction time

-- EMERGENCY MOVEMENT DETECTION
local EMERGENCY_MOVEMENT_THRESHOLD = 0.03  -- Movement > 3% is considered emergency

-- DOUBLE-TAP DETECTION SETTINGS
local ENABLE_DOUBLE_TAP = true          -- Set to false to disable double-tap functionality
local DOUBLE_TAP_MAX_TIME = 250         -- Maximum time between taps in milliseconds
local DOUBLE_TAP_MIN_TIME = 50          -- Minimum time between taps to avoid accidental triggers
local DOUBLE_TAP_ANIMATION_SPEED = 0.005 -- Speed of animated movement (0.005 units per update) - CHANGED from 0.05

-- CURVE SETTINGS FOR -6dB AT 50%
local use_log_curve = true
local log_exponent = 0.515

-- OSC SYNC SETTINGS
local delay = 1000                       -- Delay before syncing to OSC position after touch release

-- State variables (do not modify)
local touched = false
local last_osc_x = 0
local last_osc_audio = 0
local last = 0 
local synced = true
local last_raw_position = 0
local touch_session_active = false
local movements_processed = 0
local last_position = 0
local touch_start_audio = 0
local first_movement_done = false
local reaction_compensation_active = false
local reaction_movements_count = 0
local emergency_mode_active = false
local touch_started = false
local touch_start_position = 0
local touch_start_time = 0
local last_tap_time = 0
local movement_detected = false
local last_movement_time = 0
local touch_event_count = 0
local last_logged_position = -1

-- Double-tap animation state
local double_tap_animation_active = false
local double_tap_target_position = 0
local double_tap_start_position = 0

-- ===========================
-- LOCAL LOGGING
-- ===========================

-- Local logging function
local function log(message)
    if debug == 1 then
        local context = "FADER"
        if self.parent and self.parent.name then
            context = "FADER(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get connection configuration (read directly from config text)
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
    -- Parent stores track info in tag as "instance:trackNumber:trackType"
    if self.parent and self.parent.tag then
        local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
        if trackNum and trackType then
            return tonumber(trackNum), trackType
        end
    end
    return nil, nil
end

-- Check if track is properly mapped
local function isTrackMapped()
    local trackNumber, trackType = getTrackInfo()
    return trackNumber ~= nil
end

-- ===========================
-- ORIGINAL FADER FUNCTIONS
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

-- Convert dB change to audio value change
function dbChangeToAudioChange(current_audio, db_change)
  local current_db = value2db(current_audio)
  local target_db = current_db + db_change
  
  -- Find audio value that gives us the target dB
  -- Use binary search for accuracy
  local low = 0
  local high = 1
  local epsilon = 0.0001
  
  while high - low > epsilon do
    local mid = (low + high) / 2
    local mid_db = value2db(mid)
    
    if mid_db < target_db then
      low = mid
    else
      high = mid
    end
  end
  
  return (low + high) / 2
end

-- GRADUAL FIRST MOVEMENT SCALING FUNCTION WITH IMMEDIATE 0.1dB RESPONSE
function applyFirstMovementScaling(raw_position, is_touching)
  if not ENABLE_FIRST_MOVEMENT_SCALING then
    return raw_position
  end
  
  -- Track touch session
  if is_touching and not touch_session_active then
    touch_session_active = true
    movements_processed = 0
    last_position = raw_position
    touch_start_audio = use_log_curve and linearToLog(raw_position) or raw_position
    first_movement_done = false
    reaction_compensation_active = false
    reaction_movements_count = 0
    return raw_position
  end
  
  if not is_touching and touch_session_active then
    touch_session_active = false
    movements_processed = 0
    first_movement_done = false
    reaction_compensation_active = false
    reaction_movements_count = 0
    emergency_mode_active = false
    return raw_position
  end
  
  -- Process movements during touch session
  if is_touching and touch_session_active then
    local movement_delta = raw_position - last_position
    local abs_movement = math.abs(movement_delta)
    
    -- Guard against invalid positions
    if raw_position < 0 or raw_position > 1 then
      raw_position = math.max(0, math.min(1, raw_position))
    end
    
    -- Any movement counts now (removed threshold check)
    if abs_movement > 0 then
      -- HANDLE FIRST MOVEMENT
      if FORCE_MINIMUM_CHANGE and not first_movement_done then
        first_movement_done = true
        
        -- Calculate where we would end up with this movement
        local target_position = raw_position
        local target_audio = use_log_curve and linearToLog(target_position) or target_position
        local start_db = value2db(touch_start_audio)
        local target_db = value2db(target_audio)
        local db_change = target_db - start_db
        
        -- Check for emergency movement (large fast movement)
        if abs_movement > EMERGENCY_MOVEMENT_THRESHOLD then
          emergency_mode_active = true
          last_position = raw_position
          return raw_position
        end
        
        -- If the change would be less than minimum, force it AND activate reaction compensation
        if math.abs(db_change) < MINIMUM_DB_CHANGE then
          -- Determine direction from the movement
          local direction = movement_delta > 0 and 1 or -1
          
          -- Apply minimum change from starting position
          local forced_target_audio = dbChangeToAudioChange(touch_start_audio, direction * MINIMUM_DB_CHANGE)
          local forced_position = use_log_curve and logToLinear(forced_target_audio) or forced_target_audio
          
          -- Activate reaction compensation only when forcing to 0.1dB
          reaction_compensation_active = true
          reaction_movements_count = 0
          
          last_position = forced_position
          return forced_position
        else
          -- Movement is already >= 0.1dB, scale it but ensure minimum 0.1dB result
          -- Apply initial scaling to this movement
          local scaled_delta = movement_delta * INITIAL_SCALE_FACTOR
          local scaled_position = last_position + scaled_delta
          
          -- Ensure the result is at least 0.1dB change
          local scaled_audio = use_log_curve and linearToLog(scaled_position) or scaled_position
          local scaled_db_change = value2db(scaled_audio) - start_db
          
          if math.abs(scaled_db_change) < MINIMUM_DB_CHANGE then
            local direction = movement_delta > 0 and 1 or -1
            local forced_target_audio = dbChangeToAudioChange(touch_start_audio, direction * MINIMUM_DB_CHANGE)
            scaled_position = use_log_curve and logToLinear(forced_target_audio) or forced_target_audio
          end
          
          last_position = scaled_position
          movements_processed = 1  -- Count this as first processed movement
          return scaled_position
        end
      end
      
      -- CHECK FOR EMERGENCY MOVEMENTS (bypass all scaling)
      if abs_movement > EMERGENCY_MOVEMENT_THRESHOLD then
        emergency_mode_active = true
        last_position = raw_position
        return raw_position
      end
      
      -- If emergency mode was active but movement is now small, deactivate it
      if emergency_mode_active and abs_movement < EMERGENCY_MOVEMENT_THRESHOLD * 0.5 then
        emergency_mode_active = false
      end
      
      -- Skip all scaling if in emergency mode
      if emergency_mode_active then
        last_position = raw_position
        return raw_position
      end
      
      -- REACTION TIME COMPENSATION (only if activated by forcing)
      if reaction_compensation_active and reaction_movements_count < REACTION_MOVEMENTS and not emergency_mode_active then
        reaction_movements_count = reaction_movements_count + 1
        
        -- Gradually increase scale factor during reaction compensation (30% to 70%)
        local reaction_progress = (reaction_movements_count - 1) / (REACTION_MOVEMENTS - 1)
        local current_reaction_scale = REACTION_SCALE_FACTOR + (0.7 - REACTION_SCALE_FACTOR) * reaction_progress
        
        -- Apply very slow scaling for reaction time
        local scaled_delta = movement_delta * current_reaction_scale
        local new_position = last_position + scaled_delta
        
        -- Clamp to valid range
        new_position = math.max(0, math.min(1, new_position))
        
        if reaction_movements_count >= REACTION_MOVEMENTS then
          reaction_compensation_active = false
        end
        
        last_position = new_position
        return new_position
      end
      
      -- Apply gradual scaling for specified number of movements
      if movements_processed <= SCALED_MOVEMENTS_COUNT and not reaction_compensation_active and not emergency_mode_active then
        movements_processed = movements_processed + 1
        
        -- Calculate gradual scale factor
        local progress = (movements_processed - 1) / (SCALED_MOVEMENTS_COUNT - 1)  -- 0 to 1
        local base_scale_factor = INITIAL_SCALE_FACTOR + (FINAL_SCALE_FACTOR - INITIAL_SCALE_FACTOR) * progress
        
        -- Check if we're in linear range (approximately -6dB to +6dB)
        local current_audio = use_log_curve and linearToLog(raw_position) or raw_position
        local in_linear_range = current_audio >= LINEAR_RANGE_START and current_audio <= LINEAR_RANGE_END
        
        -- Apply extra precision scaling in linear range
        local scale_factor = in_linear_range and (base_scale_factor * 0.85) or base_scale_factor
        
        -- Apply scaling
        local scaled_delta = movement_delta * scale_factor
        local new_position = last_position + scaled_delta
        
        -- Clamp to valid range
        new_position = math.max(0, math.min(1, new_position))
        
        last_position = new_position
        return new_position
      else
        -- Full normal movement after gradual scaling is complete
        last_position = raw_position
        return raw_position
      end
    end
  end
  
  return raw_position
end

-- MINIMAL DEAD ZONES - REMOVED TO ALLOW DOUBLE-TAP AT -INF
function isInDeadZone(audio_value)
  -- This function is modified to always return false,
  -- effectively removing any "dead zone" that would disable double-tap.
  return false, "No dead zone (double-tap enabled everywhere)" 
end

-- ===========================
-- OSC HANDLERS WITH CONNECTION ROUTING
-- ===========================

function onReceiveOSC(message, connections)
  local arguments = message[2]
  local path = message[1]
  
  -- Get track info from parent
  local trackNumber, trackType = getTrackInfo()
  if not trackNumber then
    return false
  end
  
  -- Check if this message is for us based on path and track type
  local isVolumeMessage = false
  local receivedTrackNumber = nil
  
  if trackType == "return" and path == "/live/return/get/volume" then
    -- Return track volume message
    isVolumeMessage = true
    receivedTrackNumber = arguments[1].value
  elseif (trackType == "regular" or trackType == "track") and path == "/live/track/get/volume" then
    -- Regular track volume message
    isVolumeMessage = true
    receivedTrackNumber = arguments[1].value
  end
  
  -- Process if it's our track
  if isVolumeMessage and receivedTrackNumber == trackNumber then
    local remote_audio_value = arguments[2].value
    last_osc_audio = remote_audio_value
    
    if use_log_curve then
      last_osc_x = logToLinear(remote_audio_value)
    else
      last_osc_x = remote_audio_value
    end
    
    -- Only update if not touching to prevent jumps
    if not self.values.touch then
      -- Don't update if we're in the middle of a sync delay
      if synced then
        self.values.x = last_osc_x
        last_position = last_osc_x
      end
    else
      touched = true
    end
  end
  
  return false  -- Don't block other receivers
end

-- Send OSC with connection routing
local function sendOSCRouted(path, track, volume)
  local connectionIndex = getConnectionIndex()
  local connections = buildConnectionTable(connectionIndex)
  sendOSC(path, track, volume, connections)
end

function update()
  -- Handle double-tap animation (only if enabled)
  if ENABLE_DOUBLE_TAP and double_tap_animation_active then
    if self.values.touch then
      -- Touch detected - cancel animation
      double_tap_animation_active = false
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

      -- If already at target or no distance to cover, stop animation
      if direction == 0 then
          self.values.x = double_tap_target_position
          last_position = double_tap_target_position
          double_tap_animation_active = false
          local final_audio = use_log_curve and linearToLog(double_tap_target_position) or double_tap_target_position
          local trackNumber, trackType = getTrackInfo()
          if trackNumber then
            local path = trackType == "return" and '/live/return/set/volume' or '/live/track/set/volume'
            sendOSCRouted(path, trackNumber, final_audio)
          end
          return
      end

      local step_size = DOUBLE_TAP_ANIMATION_SPEED
      local proposed_new_position = current_pos + (direction * step_size)

      -- Check if the proposed new position overshoots the target
      if (direction > 0 and proposed_new_position >= double_tap_target_position) or
         (direction < 0 and proposed_new_position <= double_tap_target_position) then
          -- Snap to target
          self.values.x = double_tap_target_position
          last_position = double_tap_target_position
          double_tap_animation_active = false
          local final_audio = use_log_curve and linearToLog(double_tap_target_position) or double_tap_target_position
          local trackNumber, trackType = getTrackInfo()
          if trackNumber then
            local path = trackType == "return" and '/live/return/set/volume' or '/live/track/set/volume'
            sendOSCRouted(path, trackNumber, final_audio)
          end
      else
          -- Move towards target with constant speed
          self.values.x = proposed_new_position
          last_position = proposed_new_position
          
          -- Send OSC update
          local new_audio = use_log_curve and linearToLog(proposed_new_position) or proposed_new_position
          local trackNumber, trackType = getTrackInfo()
          if trackNumber then
            local path = trackType == "return" and '/live/return/set/volume' or '/live/track/set/volume'
            sendOSCRouted(path, trackNumber, new_audio)
          end
      end
    end
  end
  
  -- Original sync delay code
  if touched and not self.values.touch then
    last = getMillis()
    touched = false
    synced = false
  end
  
  -- Only sync if not currently touching AND not synced AND not animating
  if not synced and not self.values.touch and not double_tap_animation_active then
    local now = getMillis()
    if (now - last > delay) then
      self.values.x = last_osc_x
      last_position = last_osc_x
      synced = true
    end
  end
  
  -- Reset sync if touching again
  if self.values.touch and not synced then
    synced = true
  end
end

function onValueChanged()
  -- Safety check: only process if track is mapped
  if not isTrackMapped() then
    return
  end
  
  -- Skip processing if animation is active and no touch
  if double_tap_animation_active and not self.values.touch then
    return  -- Let update() handle the animation
  end
  
  -- APPLY FIRST MOVEMENT SCALING
  local raw_fader_position = self.values.x
  
  -- Detect and log suspicious jumps (only if debug enabled)
  if debug == 1 and last_raw_position > 0 then
    local raw_jump = math.abs(raw_fader_position - last_raw_position)
    if raw_jump > 0.1 and self.values.touch then  -- 10% jump while touching
      log("Suspicious jump: " .. string.format("%.4f", raw_jump))
    end
  end
  last_raw_position = raw_fader_position
  
  local scaled_fader_position = applyFirstMovementScaling(raw_fader_position, self.values.touch)
  
  -- Use scaled position for audio calculations
  local audio_value = use_log_curve and linearToLog(scaled_fader_position) or scaled_fader_position
  local current_time = getMillis()
  local db_value = value2db(audio_value)
  
  -- Update fader position if scaling was applied
  if math.abs(scaled_fader_position - raw_fader_position) > 0.0001 then
    self.values.x = scaled_fader_position
  end
  
  -- TOUCH BEHAVIOR DEBUG
  if self.values.touch then
    touch_event_count = touch_event_count + 1
  end
  
  last_logged_position = scaled_fader_position
  
  -- Send OSC with routing based on track type
  local trackNumber, trackType = getTrackInfo()
  if trackNumber then
    local path = trackType == "return" and '/live/return/set/volume' or '/live/track/set/volume'
    sendOSCRouted(path, trackNumber, audio_value)
  end
  
  -- TOUCH DETECTION WITH DEBUG
  if self.values.touch and not touch_started then
    touch_started = true
    touch_start_position = scaled_fader_position
    touch_start_time = current_time
    movement_detected = false
    touch_event_count = 1
    
    -- Cancel any ongoing double-tap animation (if enabled)
    if ENABLE_DOUBLE_TAP and double_tap_animation_active then
      double_tap_animation_active = false
    end
    
  elseif self.values.touch and touch_started then
    local movement = math.abs(scaled_fader_position - touch_start_position)
    if movement > 0.015 then
      movement_detected = true
      last_movement_time = current_time
    end
    
  elseif not self.values.touch and touch_started then
    touch_started = false
    local total_movement = math.abs(scaled_fader_position - touch_start_position)
    local touch_duration = current_time - touch_start_time
    local time_since_movement = current_time - last_movement_time
    
    local is_tap = (total_movement < 0.01) and 
                   (touch_duration < 200) and 
                   (not movement_detected or time_since_movement > 100)
    
    if is_tap then
      -- Check if double-tap is enabled
      if not ENABLE_DOUBLE_TAP then
        last_tap_time = 0
        return
      end
      
      -- CHECK MINIMAL DEAD ZONES (now modified to always allow double-tap)
      local in_dead_zone, zone_reason = isInDeadZone(audio_value)
      
      local time_since_last_tap = current_time - last_tap_time
      
      if time_since_last_tap < DOUBLE_TAP_MAX_TIME and time_since_last_tap > DOUBLE_TAP_MIN_TIME then
        -- Start animation to 0dB (or Unity gain, which is 0.85 linear for Live's scale)
        if use_log_curve then
          double_tap_target_position = logToLinear(0.85)
        else
          double_tap_target_position = 0.85
        end
        
        double_tap_start_position = self.values.x
        double_tap_animation_active = true
        
        last_tap_time = 0
      else
        last_tap_time = current_time
      end
    else
      last_tap_time = 0
    end
    
    touch_event_count = 0
  end
end

-- Handle notifications from parent group
function onReceiveNotify(key, value)
  -- Parent might notify us of track changes
  if key == "track_changed" then
    -- Don't change fader position - just reset internal state
    touched = false
    synced = true
    last_position = self.values.x  -- Keep current position
  elseif key == "track_unmapped" then
    -- Don't change fader position
  end
end

-- VERIFICATION
function init()
  -- Log version
  log("Script v" .. VERSION .. " loaded")
end

init()