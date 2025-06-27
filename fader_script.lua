-- FADER SCRIPT - CONNECTION-AWARE VERSION
-- Version: 2.0.0 (Phase 2 - Connection routing support)
local VERSION = "2.0.0"

-- FINAL PROFESSIONAL FADER - MOVEMENT SMOOTHING SYSTEM
-- DEBUG CONTROL: Set to 1 to enable all logging, 0 to disable completely
local DEBUG = 1

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

-- Connection-aware state
local track_mapped = false
local track_number = nil
local connection_index = nil
local last_disable_check = 0
local DISABLE_CHECK_INTERVAL = 500  -- Check every 500ms

-- DEBUG PRINT FUNCTION
function debugPrint(...)
  if DEBUG == 1 then
    print(...)
  end
end

-- Helper function to check if control should be enabled
function isControlEnabled()
  -- Check parent's track_number property
  track_number = self.parent.track_number
  
  -- If track_number is nil or -1, the track is not mapped
  if track_number == nil or track_number == -1 then
    return false
  end
  
  return true
end

-- Helper function to get connection index
function getConnectionIndex()
  -- Try to get from parent first
  if self.parent.connection_index then
    return self.parent.connection_index
  end
  
  -- Fallback: parse from group name
  local group_name = self.parent.name
  if string.find(group_name, "band_") == 1 then
    return 1
  elseif string.find(group_name, "master_") == 1 then
    return 2
  end
  
  -- Default to connection 1 if unable to determine
  return 1
end

-- Helper function to build connection table
function buildConnectionTable(conn_index)
  if conn_index == 1 then
    return {1}
  elseif conn_index == 2 then
    return {2}
  else
    return {conn_index}
  end
end

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
    debugPrint("*** TOUCH SESSION STARTED - Gradual scaling ready ***")
    debugPrint("Touch start audio:", string.format("%.3f", touch_start_audio), formatDB(value2db(touch_start_audio)))
    return raw_position
  end
  
  if not is_touching and touch_session_active then
    touch_session_active = false
    debugPrint("*** TOUCH SESSION ENDED - Scaling reset ***")
    debugPrint("Total movements processed:", movements_processed)
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
      debugPrint("*** WARNING: Invalid raw position:", raw_position, "- Clamping ***")
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
        
        debugPrint("*** FIRST MOVEMENT CHECK ***")
        debugPrint("Start dB:", formatDB(start_db))
        debugPrint("Would go to:", formatDB(target_db))
        debugPrint("Change would be:", string.format("%.3f", db_change), "dB")
        
        -- Check for emergency movement (large fast movement)
        if abs_movement > EMERGENCY_MOVEMENT_THRESHOLD then
          debugPrint("*** EMERGENCY MOVEMENT DETECTED - No scaling ***")
          emergency_mode_active = true
          last_position = raw_position
          return raw_position
        end
        
        -- If the change would be less than minimum, force it AND activate reaction compensation
        if math.abs(db_change) < MINIMUM_DB_CHANGE then
          debugPrint("*** FORCING MINIMUM 0.1dB CHANGE ***")
          
          -- Determine direction from the movement
          local direction = movement_delta > 0 and 1 or -1
          
          -- Apply minimum change from starting position
          local forced_target_audio = dbChangeToAudioChange(touch_start_audio, direction * MINIMUM_DB_CHANGE)
          local forced_position = use_log_curve and logToLinear(forced_target_audio) or forced_target_audio
          
          debugPrint("Direction:", direction > 0 and "UP" or "DOWN")
          debugPrint("Forced to:", formatDB(start_db + direction * MINIMUM_DB_CHANGE))
          debugPrint("Forced position:", string.format("%.4f", forced_position))
          
          -- Activate reaction compensation only when forcing to 0.1dB
          reaction_compensation_active = true
          reaction_movements_count = 0
          debugPrint("*** REACTION TIME COMPENSATION ACTIVATED ***")
          
          last_position = forced_position
          return forced_position
        else
          -- Movement is already >= 0.1dB, scale it but ensure minimum 0.1dB result
          debugPrint("Change is already >= 0.1dB")
          
          -- Apply initial scaling to this movement
          local scaled_delta = movement_delta * INITIAL_SCALE_FACTOR
          local scaled_position = last_position + scaled_delta
          
          -- Ensure the result is at least 0.1dB change
          local scaled_audio = use_log_curve and linearToLog(scaled_position) or scaled_position
          local scaled_db_change = value2db(scaled_audio) - start_db
          
          if math.abs(scaled_db_change) < MINIMUM_DB_CHANGE then
            debugPrint("Scaled result would be < 0.1dB, forcing to minimum")
            local direction = movement_delta > 0 and 1 or -1
            local forced_target_audio = dbChangeToAudioChange(touch_start_audio, direction * MINIMUM_DB_CHANGE)
            scaled_position = use_log_curve and logToLinear(forced_target_audio) or forced_target_audio
          end
          
          debugPrint("Final position after scaling:", string.format("%.4f", scaled_position))
          last_position = scaled_position
          movements_processed = 1  -- Count this as first processed movement
          return scaled_position
        end
      end
      
      -- CHECK FOR EMERGENCY MOVEMENTS (bypass all scaling)
      if abs_movement > EMERGENCY_MOVEMENT_THRESHOLD then
        debugPrint("*** EMERGENCY MOVEMENT - Bypassing all scaling ***")
        emergency_mode_active = true
        last_position = raw_position
        return raw_position
      end
      
      -- If emergency mode was active but movement is now small, deactivate it
      if emergency_mode_active and abs_movement < EMERGENCY_MOVEMENT_THRESHOLD * 0.5 then
        emergency_mode_active = false
        debugPrint("*** Emergency mode deactivated ***")
      end
      
      -- Skip all scaling if in emergency mode
      if emergency_mode_active then
        last_position = raw_position
        return raw_position
      end
      
      -- REACTION TIME COMPENSATION (only if activated by forcing)
      if reaction_compensation_active and reaction_movements_count < REACTION_MOVEMENTS and not emergency_mode_active then
        reaction_movements_count = reaction_movements_count + 1
        
        debugPrint("*** REACTION TIME COMPENSATION - Movement #" .. reaction_movements_count .. " ***")
        debugPrint("Applying extra slow scaling for precise control")
        
        -- Gradually increase scale factor during reaction compensation (30% to 70%)
        local reaction_progress = (reaction_movements_count - 1) / (REACTION_MOVEMENTS - 1)
        local current_reaction_scale = REACTION_SCALE_FACTOR + (0.7 - REACTION_SCALE_FACTOR) * reaction_progress
        
        -- Apply very slow scaling for reaction time
        local scaled_delta = movement_delta * current_reaction_scale
        local new_position = last_position + scaled_delta
        
        -- Clamp to valid range
        new_position = math.max(0, math.min(1, new_position))
        
        debugPrint("Raw movement:", string.format("%.4f", movement_delta))
        debugPrint("Scaled movement:", string.format("%.4f", scaled_delta))
        debugPrint("Scale factor:", string.format("%.2f", current_reaction_scale), "(", string.format("%.0f", current_reaction_scale * 100), "%)")
        debugPrint("Reaction movements remaining:", REACTION_MOVEMENTS - reaction_movements_count)
        
        if reaction_movements_count >= REACTION_MOVEMENTS then
          reaction_compensation_active = false
          debugPrint("*** REACTION TIME COMPENSATION COMPLETE ***")
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
        
        debugPrint("*** GRADUAL SCALING - Movement #" .. movements_processed .." ***")
        debugPrint("Raw movement:", string.format("%.4f", movement_delta))
        debugPrint("Scaled movement:", string.format("%.4f", scaled_delta))
        debugPrint("Scale factor:", string.format("%.2f", scale_factor), "(", string.format("%.0f", scale_factor * 100), "%)")
        debugPrint("Progress:", string.format("%.1f", progress * 100), "%")
        debugPrint("In linear range:", in_linear_range)
        debugPrint("Movements remaining:", SCALED_MOVEMENTS_COUNT - movements_processed)
        
        last_position = new_position
        return new_position
      else
        -- Full normal movement after gradual scaling is complete
        debugPrint("*** FULL NORMAL MOVEMENT - Gradual scaling complete ***")
        last_position = raw_position
        return raw_position
      end
    end
  end
  
  return raw_position
end

function onReceiveOSC(message, connections)
  -- Check if control is enabled before processing OSC
  if not isControlEnabled() then
    return
  end
  
  local arguments = message[2]
  
  -- Get track number from parent
  local parent_track = self.parent.track_number
  if parent_track == nil or parent_track == -1 then
    return  -- Not mapped
  end
  
  if arguments[1].value == parent_track then
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
        debugPrint("*** OSC UPDATE - Fader:", string.format("%.1f%%", last_osc_x * 100), "Audio:", string.format("%.3f", remote_audio_value))
      else
        debugPrint("*** OSC UPDATE DURING SYNC DELAY - Storing for later ***")
      end
    else
      touched = true
      debugPrint("*** OSC RECEIVED WHILE TOUCHING - Ignoring to prevent jump ***")
    end
  end
end

function update()
  -- Periodically check if control should be enabled/disabled
  local current_time = getMillis()
  if current_time - last_disable_check > DISABLE_CHECK_INTERVAL then
    last_disable_check = current_time
    
    local should_be_enabled = isControlEnabled()
    if should_be_enabled ~= track_mapped then
      track_mapped = should_be_enabled
      
      if not track_mapped then
        -- Disable the fader
        self.enabled = false
        debugPrint("*** FADER DISABLED - Track not mapped ***")
      else
        -- Enable the fader
        self.enabled = true
        connection_index = getConnectionIndex()
        debugPrint("*** FADER ENABLED - Track mapped, Connection:", connection_index)
      end
    end
  end
  
  -- Skip all processing if disabled
  if not track_mapped then
    return
  end
  
  -- Handle double-tap animation (only if enabled)
  if ENABLE_DOUBLE_TAP and double_tap_animation_active then
    if self.values.touch then
      -- Touch detected - cancel animation
      double_tap_animation_active = false
      debugPrint("*** DOUBLE-TAP ANIMATION CANCELLED - Touch detected ***")
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
          debugPrint("*** DOUBLE-TAP ANIMATION COMPLETE (Already at target) ***")
          local final_audio = use_log_curve and linearToLog(double_tap_target_position) or double_tap_target_position
          local connections = buildConnectionTable(connection_index)
          sendOSC('/live/track/set/volume', {self.parent.track_number, final_audio}, connections)
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
          debugPrint("*** DOUBLE-TAP ANIMATION COMPLETE (Snapped to target) ***")
          local final_audio = use_log_curve and linearToLog(double_tap_target_position) or double_tap_target_position
          local connections = buildConnectionTable(connection_index)
          sendOSC('/live/track/set/volume', {self.parent.track_number, final_audio}, connections)
      else
          -- Move towards target with constant speed
          self.values.x = proposed_new_position
          last_position = proposed_new_position
          
          -- Send OSC update
          local new_audio = use_log_curve and linearToLog(proposed_new_position) or proposed_new_position
          local connections = buildConnectionTable(connection_index)
          sendOSC('/live/track/set/volume', {self.parent.track_number, new_audio}, connections)
          
          debugPrint("*** DOUBLE-TAP ANIMATION (Constant Speed) ***")
          -- Progress calculation assuming linear movement
          if double_tap_target_position ~= double_tap_start_position then
            debugPrint("Progress:", string.format("%.1f%%", ((proposed_new_position - double_tap_start_position) / (double_tap_target_position - double_tap_start_position)) * 100))
          else
            debugPrint("Progress: 100% (target is start)")
          end
          debugPrint("Current:", string.format("%.1f%%", proposed_new_position * 100), "Target:", string.format("%.1f%%", double_tap_target_position * 100))
      end
    end
  end
  
  -- Original sync delay code
  if touched and not self.values.touch then
    last = getMillis()
    touched = false
    synced = false
    debugPrint("*** TOUCH RELEASED - Starting sync delay ***")
  end
  
  -- Only sync if not currently touching AND not synced AND not animating
  if not synced and not self.values.touch and not double_tap_animation_active then
    local now = getMillis()
    if (now - last > delay) then
      debugPrint("*** SYNC DELAY COMPLETE - Updating to OSC position ***")
      debugPrint("Jumping from:", string.format("%.1f%%", self.values.x * 100), "to:", string.format("%.1f%%", last_osc_x * 100))
      self.values.x = last_osc_x
      last_position = last_osc_x
      synced = true
    end
  end
  
  -- Reset sync if touching again
  if self.values.touch and not synced then
    synced = true
    debugPrint("*** Touch detected during sync delay - cancelling sync ***")
  end
end

-- MINIMAL DEAD ZONES - REMOVED TO ALLOW DOUBLE-TAP AT -INF
function isInDeadZone(audio_value)
  -- This function is modified to always return false,
  -- effectively removing any "dead zone" that would disable double-tap.
  return false, "No dead zone (double-tap enabled everywhere)" 
end

function onValueChanged()
  -- Check if control is enabled
  if not isControlEnabled() then
    return  -- Don't process if track not mapped
  end
  
  -- Skip processing if animation is active and no touch
  if double_tap_animation_active and not self.values.touch then
    return  -- Let update() handle the animation
  end
  
  -- APPLY FIRST MOVEMENT SCALING
  local raw_fader_position = self.values.x
  
  -- Detect and log suspicious jumps
  if last_raw_position > 0 then
    local raw_jump = math.abs(raw_fader_position - last_raw_position)
    if raw_jump > 0.1 and self.values.touch then  -- 10% jump while touching
      debugPrint("*** SUSPICIOUS JUMP DETECTED ***")
      debugPrint("Last raw position:", string.format("%.4f", last_raw_position))
      debugPrint("New raw position:", string.format("%.4f", raw_fader_position))
      debugPrint("Jump size:", string.format("%.4f", raw_jump), string.format("(%.1f%%)", raw_jump * 100))
      debugPrint("Touch state:", self.values.touch)
      debugPrint("Synced state:", synced)
      debugPrint("Touched flag:", touched)
      debugPrint("Emergency mode:", emergency_mode_active)
      debugPrint("Last OSC position:", string.format("%.4f", last_osc_x))
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
    debugPrint("*** FADER POSITION SCALED ***")
    debugPrint("Raw:", string.format("%.4f", raw_fader_position), "Scaled:", string.format("%.4f", scaled_fader_position))
  end
  
  -- TOUCH BEHAVIOR DEBUG
  if self.values.touch then
    touch_event_count = touch_event_count + 1
  end
  
  -- ENHANCED LOGGING WITH DB VALUES
  debugPrint("=== FADER MOVED ===")
  debugPrint("Fader:", string.format("%.1f%%", scaled_fader_position * 100))
  debugPrint("Audio:", string.format("%.3f", audio_value), string.format("(%.1f%%)", audio_value * 100))
  debugPrint("dB:", formatDB(db_value))
  debugPrint("Touch:", self.values.touch and "TOUCHING" or "RELEASED")
  debugPrint("Track:", self.parent.track_number, "Connection:", connection_index)
  debugPrint("Movements processed:", movements_processed, "/", SCALED_MOVEMENTS_COUNT)
  local scaling_active = (movements_processed <= SCALED_MOVEMENTS_COUNT and touch_session_active)
  debugPrint("Scaling:", scaling_active and "ACTIVE" or "INACTIVE")
  if reaction_compensation_active then
    debugPrint("*** REACTION COMPENSATION ACTIVE ***", reaction_movements_count, "/", REACTION_MOVEMENTS)
  end
  if scaling_active then
    local progress = movements_processed > 0 and (movements_processed - 1) / (SCALED_MOVEMENTS_COUNT - 1) or 0
    local current_scale = INITIAL_SCALE_FACTOR + (FINAL_SCALE_FACTOR - INITIAL_SCALE_FACTOR) * progress
    debugPrint("Current scale factor:", string.format("%.2f", current_scale), "(", string.format("%.0f", current_scale * 100), "%)")
  end
  
  -- DEBUG TOUCH BEHAVIOR ISSUE
  if self.values.touch then
    debugPrint("Touch event #" .. touch_event_count)
    local pos_change = math.abs(scaled_fader_position - last_logged_position)
    if last_logged_position >= 0 then
      debugPrint("Position change:", string.format("%.4f", pos_change))
      if pos_change > 0.01 then
        debugPrint("*** LARGE JUMP DETECTED ***")
      elseif pos_change < 0.0001 then
        debugPrint("*** VERY SMALL MOVEMENT ***")
      end
    end
  end
  last_logged_position = scaled_fader_position
  
  -- Send OSC with connection routing
  local connections = buildConnectionTable(connection_index)
  sendOSC('/live/track/set/volume', {self.parent.track_number, audio_value}, connections)
  
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
      debugPrint("*** DOUBLE-TAP ANIMATION CANCELLED - New touch started ***")
    end
    
    debugPrint("*** TOUCH START - Position:", string.format("%.1f%%", touch_start_position * 100), formatDB(value2db(linearToLog(touch_start_position))))
    
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
    
    debugPrint("*** TOUCH END ***")
    debugPrint("Total events during touch:", touch_event_count)
    debugPrint("Total movement:", string.format("%.4f", total_movement))
    debugPrint("Touch duration:", touch_duration, "ms")
    
    local is_tap = (total_movement < 0.01) and 
                   (touch_duration < 200) and 
                   (not movement_detected or time_since_movement > 100)
    
    if is_tap then
      -- Check if double-tap is enabled
      if not ENABLE_DOUBLE_TAP then
        debugPrint("*** TAP DETECTED - Double-tap disabled ***")
        last_tap_time = 0
        return
      end
      
      -- CHECK MINIMAL DEAD ZONES (now modified to always allow double-tap)
      local in_dead_zone, zone_reason = isInDeadZone(audio_value)
      
      debugPrint("*** VALID TAP DETECTED ***")
      debugPrint("Tap duration:", touch_duration, "ms")
      
      local time_since_last_tap = current_time - last_tap_time
      
      if time_since_last_tap < DOUBLE_TAP_MAX_TIME and time_since_last_tap > DOUBLE_TAP_MIN_TIME then
        debugPrint("*** DOUBLE TAP SUCCESS! ***")
        debugPrint("Time between taps:", time_since_last_tap, "ms")
        
        -- Start animation to 0dB (or Unity gain, which is 0.85 linear for Live's scale)
        if use_log_curve then
          double_tap_target_position = logToLinear(0.85)
        else
          double_tap_target_position = 0.85
        end
        
        double_tap_start_position = self.values.x
        double_tap_animation_active = true
        
        debugPrint("*** STARTING ANIMATION TO 0dB ***")
        debugPrint("From:", string.format("%.1f%%", double_tap_start_position * 100), formatDB(db_value))
        debugPrint("To:", string.format("%.1f%%", double_tap_target_position * 100), "0.0dB")
        
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

-- VERIFICATION
function init()
  print("=== FADER SCRIPT v" .. VERSION .. " loaded ===")
  debugPrint("=== PROFESSIONAL FADER WITH IMMEDIATE 0.1dB RESPONSE ===")
  debugPrint("DEBUG MODE:", DEBUG == 1 and "ENABLED" or "DISABLED")
  debugPrint("Connection-aware features: ENABLED")
  
  -- Initialize connection routing
  track_mapped = isControlEnabled()
  connection_index = getConnectionIndex()
  
  if track_mapped then
    self.enabled = true
    debugPrint("Fader ENABLED - Track:", self.parent.track_number, "Connection:", connection_index)
  else
    self.enabled = false
    debugPrint("Fader DISABLED - Track not mapped")
  end
  
  debugPrint("Gradual movement scaling:", ENABLE_FIRST_MOVEMENT_SCALING and "ENABLED" or "DISABLED")
  if ENABLE_FIRST_MOVEMENT_SCALING then
    debugPrint("- Scaled movements count:", SCALED_MOVEMENTS_COUNT)
    debugPrint("- Initial scale factor:", INITIAL_SCALE_FACTOR, "(", INITIAL_SCALE_FACTOR * 100, "%)")
    debugPrint("- Final scale factor:", FINAL_SCALE_FACTOR, "(", FINAL_SCALE_FACTOR * 100, "%)")
    debugPrint("- Minimum dB change:", MINIMUM_DB_CHANGE, "dB (immediate response)")
    debugPrint("- Reaction compensation:", REACTION_MOVEMENTS, "movements at", REACTION_SCALE_FACTOR * 100, "% to 70% speed")
    debugPrint("- Emergency movement threshold:", EMERGENCY_MOVEMENT_THRESHOLD * 100, "% (bypasses all scaling)")
    debugPrint("- Linear range:", formatDB(value2db(LINEAR_RANGE_START)), "to", formatDB(value2db(LINEAR_RANGE_END)))
    debugPrint("- Extra precision scaling (85%) applied in linear range")
  end
  debugPrint("Dead zones (double-tap disabled):")
  debugPrint("- NONE (Double-tap enabled everywhere including -inf and +6dB)") -- Reflects change
  debugPrint("Double-tap feature:", ENABLE_DOUBLE_TAP and "ENABLED" or "DISABLED")
  if ENABLE_DOUBLE_TAP then
    debugPrint("Double-tap timing:")
    debugPrint("- Maximum time between taps:", DOUBLE_TAP_MAX_TIME, "ms")
    debugPrint("- Minimum time between taps:", DOUBLE_TAP_MIN_TIME, "ms")
    debugPrint("- Animation speed:", DOUBLE_TAP_ANIMATION_SPEED * 100, "% of full range per update (constant speed)") -- Reflects change in interpretation
  end
  debugPrint("")
  debugPrint("Curve verification:")
  local test_50 = linearToLog(0.5)
  debugPrint("50% fader:", string.format("%.3f", test_50), "audio", formatDB(value2db(test_50)))
  debugPrint("Unity position:", string.format("%.1f%%", logToLinear(0.85) * 100), "fader")
  
  -- Initialize scaling variables
  last_position = self.values.x or 0
end

init()