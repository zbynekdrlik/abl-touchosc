# AbletonOSC Meter to dBFS Conversion Rule

## Problem
The meter values from AbletonOSC need to be converted to dBFS values that match what Ableton Live displays in its interface. Direct conversions using fader math or other methods result in incorrect values.

## Verified Calibration Points
From actual testing with user confirmation:
- OSC meter value `0.600` = `-24.4 dBFS` in Ableton
- OSC meter value `0.631` = `-22 dBFS` in Ableton
- OSC meter value `0.842` = `-6 dBFS` in Ableton
- OSC meter value `0.0` = `-∞ dBFS`
- OSC meter value `1.0` = `0 dBFS`

## AbletonOSC Limitation
**Important**: AbletonOSC appears to stop sending meter updates below approximately 0.578 (around -22.8 dBFS). This means:
- Values below -24.4 dBFS may not be reliably tracked
- The meter may "stick" at the last value before silence
- This is a limitation of AbletonOSC, not our conversion

## Conversion Method

The most accurate method is using a calibration table with verified points and linear interpolation between them:

```lua
local METER_DB_CALIBRATION = {
    {0.000, -math.huge},  -- Silence
    {0.001, -80.0},       -- Very quiet
    {0.600, -24.4},       -- VERIFIED
    {0.631, -22.0},       -- VERIFIED  
    {0.842, -6.0},        -- VERIFIED
    {1.000, 0.0},         -- Unity
}

function meterToDB(meter_normalized)
    -- Find calibration points and interpolate
    for i = 1, #METER_DB_CALIBRATION - 1 do
        local point1 = METER_DB_CALIBRATION[i]
        local point2 = METER_DB_CALIBRATION[i + 1]
        
        if meter_normalized >= point1[1] and meter_normalized <= point2[1] then
            -- Linear interpolation
            local meter_range = point2[1] - point1[1]
            local db_range = point2[2] - point1[2]
            local meter_offset = meter_normalized - point1[1]
            local interpolation_ratio = meter_offset / meter_range
            return point1[2] + (db_range * interpolation_ratio)
        end
    end
end
```

## Why Previous Attempts Failed

1. **Fader conversion** - The fader uses a different scale and curve than the meter
2. **Simple logarithmic** - Pure `20 * log10(x)` doesn't match Ableton's meter scaling
3. **Single-point calibration** - Works only near the calibration point, not across the range
4. **Incorrect calibration values** - Initial calibration points were wrong

## Key Points

1. **Use calibration table**: Multiple verified points ensure accuracy across the range
2. **Linear interpolation**: Smooth transitions between calibration points
3. **Handle edge cases**: Silence (≤ 0.001) and floating-point headroom (> 1.0)
4. **Display format**: Use "dBFS" as the unit (decibels relative to Full Scale)
5. **Understand limitations**: AbletonOSC may not send values below ~-24.4 dBFS

## Testing
Always verify the conversion by comparing:
- TouchOSC display value
- Ableton's meter reading
- They should match within 0.1 dB

## Note
This calibration is specific to AbletonOSC's `/live/track/get/output_meter_level` message. Other meter sources may use different scaling.
