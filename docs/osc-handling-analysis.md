# OSC Handling Analysis: Main vs Optimization Branch

## Meter Script

### Main Branch (v2.3.1) ✅
```lua
function onReceiveOSC(message, connections)
    -- Receives: /live/track/get/output_meter_level
    -- Updates: self.values.x directly
    -- NO notify() calls
end
```

### Optimization Branch (v2.6.1) ❌
```lua
function onReceiveOSC(message, connections)
    -- Receives: /live/track/get/output_meter_level
    -- Updates: self.values.x directly
    -- PROBLEM: Notifies parent!
    parentGroup:notify("value_changed", "meter")  -- REMOVE THIS
end
```

## DB Meter Label

### Main Branch ✅
Should receive OSC directly (need to verify)

### Optimization Branch (v2.6.3) ❌
```lua
-- NO onReceiveOSC function!
-- Only has:
function onReceiveNotify(key, value)
    if key == "value_changed" and value == "meter" then
        -- Waits for notification - WRONG!
    end
end
```

**FIX NEEDED**: Add onReceiveOSC to receive meter levels directly

## DB Label

### Main Branch ✅
```lua
function onReceiveOSC(message, connections)
    -- Receives: /live/track/get/volume
    -- Updates: self.values.text directly
end
```

### Optimization Branch (v1.3.4) ✅
Already correct - receives OSC directly

## Status Indicator Issue

The meter control itself cannot change color in TouchOSC. Need to:
1. Add a separate indicator control
2. Have it receive OSC directly
3. Change its color based on dB level

## Group Init

### Optimization Branch (v1.16.1) ❌
```lua
function onReceiveNotify(key, value)
    elseif key == "value_changed" then
        -- Forwards to all children - REMOVE THIS
        for name, control in pairs(childControls) do
            control:notify("sibling_value_changed", value)
        end
    end
end
```

## Summary of Required Changes

1. **meter_script.lua**
   - Remove: `parentGroup:notify("value_changed", "meter")`
   - Keep: Direct OSC updates

2. **db_meter_label.lua**
   - Add: `onReceiveOSC()` function to receive meter levels
   - Remove: Dependency on notifications
   - Copy meter OSC handling logic

3. **group_init.lua**
   - Remove: `value_changed` forwarding
   - Keep: Only structural notifications (track_changed, etc.)

4. **New: status_indicator.lua**
   - Create new control for color indication
   - Receive meter OSC directly
   - Change color based on dB thresholds

## Expected Performance Improvement

- Current: OSC → Meter → Parent → Siblings (50ms+)
- Fixed: OSC → Each Control (1-2ms)
- **Expected improvement: 25-50x faster response**
