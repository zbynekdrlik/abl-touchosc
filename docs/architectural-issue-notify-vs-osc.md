# Architectural Issue: Notify vs Direct OSC

## Problem Summary

During the optimization branch development, a critical architectural mistake was made: **controls were changed from receiving OSC messages directly to using a notification chain system**. This is causing the lag and performance issues.

## How It Should Work (Main Branch - CORRECT)

```
Ableton → OSC → Meter → Updates itself
Ableton → OSC → DB Label → Updates itself  
Ableton → OSC → DB Meter Label → Updates itself
```

Each control:
1. Receives its own OSC messages
2. Processes them immediately
3. Updates its display directly
4. No dependencies on other controls

## How It Works Now (Optimization Branch - INCORRECT)

```
Ableton → OSC → Meter → Notifies Parent → Parent Notifies All Children → They Update
```

Current flow:
1. Only meter receives OSC
2. Meter notifies parent ("value_changed")
3. Parent forwards to all children
4. Children update based on notification
5. Multiple processing steps = LAG

## Evidence of the Problem

### Meter Script (optimization branch):
```lua
-- Line 246: WRONG - notifying parent
if parentGroup and parentGroup.notify and isActive then
    parentGroup:notify("value_changed", "meter")
end
```

### DB Meter Label (optimization branch):
```lua
-- WRONG - waiting for notification instead of receiving OSC
function onReceiveNotify(key, value)
    if key == "value_changed" and value == "meter" then
        -- Get meter value from sibling
```

### Group Init (optimization branch):
```lua
-- WRONG - forwarding notifications between children
elseif key == "value_changed" then
    for name, control in pairs(childControls) do
        control:notify("sibling_value_changed", value)
    end
```

## What Needs to Be Fixed

### 1. Meter Script
- Keep OSC receiving 
- **REMOVE** parent notification
- Just update itself

### 2. DB Meter Label
- **ADD** onReceiveOSC function
- Listen to same meter OSC messages
- Update itself directly
- **REMOVE** dependency on notifications

### 3. DB Label  
- Verify it receives volume OSC directly
- Should not depend on fader notifications

### 4. Group Init
- **REMOVE** value_changed forwarding
- Only handle control enable/disable
- No value proxying

### 5. All Other Controls
- Ensure each receives its own OSC
- No cross-control notifications for values
- Self-sufficient operation

## Performance Impact

**Main Branch**: 
- Direct path: OSC → Control → Update
- Latency: ~1ms

**Current Optimization Branch**:
- Indirect path: OSC → Control → Parent → All Siblings → Update  
- Latency: ~10-50ms (accumulated)

## Next Steps

1. Create comparison table of OSC handling (main vs optimization)
2. Fix each script to use direct OSC
3. Remove all value-based notifications
4. Test performance improvement

## Key Rule

**Every control must be self-sufficient and receive its own OSC messages directly!**

Notifications should only be used for:
- State changes (track mapped/unmapped)
- User interactions (touch/release)
- NOT for value updates!
