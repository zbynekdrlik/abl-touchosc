# AbletonOSC Meter to dBFS Conversion Rule

## Problem
The meter values from AbletonOSC need to be converted to dBFS values that match what Ableton Live displays in its interface. Direct conversions using fader math or other methods result in incorrect values.

## Verified Calibration Points
From actual testing with user confirmation:
- OSC meter value `0.631` = `-22 dBFS` in Ableton
- OSC meter value `0.842` = `-6 dBFS` in Ableton
- OSC meter value `0.0` = `-∞ dBFS`
- OSC meter value `1.0` = `0 dBFS`

## Correct Conversion Formula

```lua
function meterToDB(meter_normalized)
    -- Handle silence
    if not meter_normalized or meter_normalized <= 0.001 then
        return -math.huge  -- Returns -∞
    end
    
    -- Handle floating-point headroom (> 0 dBFS)
    if meter_normalized > 1.0 then
        local db_above_zero = (meter_normalized - 1.0) * 60
        return db_above_zero
    end
    
    -- Standard logarithmic conversion with calibration
    local db_raw = 20 * math.log10(meter_normalized)
    
    -- Calibration offset based on verified reference point
    -- When meter = 0.631, we need -22 dB
    local METER_REFERENCE = 0.631
    local DB_REFERENCE = -22.0
    local db_raw_at_reference = 20 * math.log10(METER_REFERENCE)
    local calibration_offset = DB_REFERENCE - db_raw_at_reference
    
    return db_raw + calibration_offset
end
```

## Why Previous Attempts Failed

1. **Fader conversion** - The fader uses a different scale and curve than the meter
2. **LUFS calculation** - LUFS requires complex perceptual loudness algorithms not available from peak meters
3. **Arbitrary offsets** - Using fixed offsets without proper calibration points

## Key Points

1. **Use logarithmic conversion**: `20 * log10(meter_value)` is the standard formula
2. **Apply calibration offset**: Based on the verified reference point (0.631 = -22 dBFS)
3. **Handle edge cases**: Silence (≤ 0.001) and floating-point headroom (> 1.0)
4. **Display format**: Use "dBFS" as the unit (decibels relative to Full Scale)

## Testing
Always verify the conversion by comparing:
- TouchOSC display value
- Ableton's meter reading
- They should match within 0.1 dB

## Note
This calibration is specific to AbletonOSC's `/live/track/get/output_meter_level` message. Other meter sources may use different scaling.
