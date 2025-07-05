# AbletonOSC Mute Command Boolean Rule

## Problem
TouchOSC button controls output numeric values (0/1) for their state, but AbletonOSC's mute command expects boolean values (true/false).

## Error Symptom
```
Error handling OSC message: Python argument types in
    None.None(Track, float)
did not match C++ signature:
    None(class TTrackPyHandle, bool)
```

## Solution
Always send boolean values to AbletonOSC mute commands:

```lua
-- ❌ WRONG - Sending numbers
local muteValue = (self.values.x == 0) and 1 or 0
sendOSC(path, trackNumber, muteValue, connections)

-- ✅ CORRECT - Sending boolean
local muteValue = (self.values.x == 0)  -- This evaluates to true/false
sendOSC(path, trackNumber, muteValue, connections)
```

## Key Points

1. **Button state mapping**:
   - `self.values.x = 0` → Button pressed → Send `true` (mute ON)
   - `self.values.x = 1` → Button released → Send `false` (mute OFF)

2. **OSC paths**:
   - Regular tracks: `/live/track/set/mute`
   - Return tracks: `/live/return/set/mute`

3. **Visual feedback**:
   - Set `self.values.x` to control button state
   - Let TouchOSC editor handle colors (don't set `self.color` in script)

## Testing
Verify no type errors in AbletonOSC console when toggling mute buttons.

## Reference
Fixed in mute_button.lua v2.1.4 (2025-07-05)
