# Action Plan: Fix Notify Architecture

## Immediate Actions for Next Thread

### 1. Fix Meter Script (meter_script.lua)
```lua
-- REMOVE these lines (~246):
if parentGroup and parentGroup.notify and isActive then
    parentGroup:notify("value_changed", "meter")  -- DELETE
end
```

### 2. Fix DB Meter Label (db_meter_label.lua)
Add complete OSC handling:
```lua
function onReceiveOSC(message, connections)
    local path = message[1]
    local args = message[2]
    
    -- Get track info from parent
    local trackNumber, trackType = getTrackInfo()
    if not trackNumber then return false end
    
    -- Check if this is meter level message
    local isMeterMessage = false
    if trackType == "return" and path == '/live/return/get/output_meter_level' then
        isMeterMessage = true
    elseif trackType == "track" and path == '/live/track/get/output_meter_level' then
        isMeterMessage = true
    end
    
    if isMeterMessage and args[1].value == trackNumber then
        -- Get meter value
        local normalized_meter = args[2].value
        -- Convert and update display
        -- ... (conversion logic)
    end
end
```

### 3. Fix Group Init (group_init.lua)
```lua
-- REMOVE this entire section:
elseif key == "value_changed" then
    -- Forward value changes to relevant controls
    for name, control in pairs(childControls) do
        control:notify("sibling_value_changed", value)  -- DELETE ALL
    end
```

### 4. Create Status Indicator
Since meter can't change color, create new control:
- LED or indicator control
- Receives meter OSC directly
- Changes its own color based on dB level

## Testing After Fixes

1. Meter should update without lag
2. DB meter label should update simultaneously
3. No notification chains for values
4. Status indicator shows color changes

## Expected Result

- **Before**: 50ms+ lag due to notification chain
- **After**: <2ms direct updates
- **User experience**: Smooth, real-time meter like main branch
