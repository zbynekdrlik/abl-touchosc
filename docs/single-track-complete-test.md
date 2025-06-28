# Single Track Group Complete Test Setup

## Overview
Create ONE complete track group with all control scripts to verify everything works together before testing multiple scenarios.

## Test Track Selection
We'll use **"band_CG #"** as our test track since:
- It's the actual track name in your band project
- It tests special characters in track names
- It uses Connection 1 (band connection)

## Complete Track Group Setup

### 1. Create the Main Group
1. **Create Group Control**
   - Type: Group
   - Name: `band_CG #`
   - Size: Approximately 200x600 pixels (taller for all controls)
   - Position: Center of layout

2. **Add Status Indicator**
   - Type: LED (or small rectangular indicator)
   - Name: `status_indicator`
   - Position: Top of group
   - Size: ~20x20 pixels
   - Color: Will be controlled by script (red/green)

3. **Configure OSC**
   - Select the group
   - Go to OSC tab
   - Set receive pattern: `/live/song/get/track_names`
   - Enable ONLY Connection 1 (band connection)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

### 2. Add Track Label
- Type: Label
- Name: `track_label`
- Position: Next to status indicator
- Text: "CG #" (without prefix)
- Size: Wide enough for track name

### 3. Add Fader Control
1. **Create Fader**
   - Type: Fader
   - Name: `fader`
   - Position: Below status/label
   - Size: ~40x200 pixels
   - Orientation: Vertical

2. **Attach Script**
   - Select the fader
   - Add script: `fader_script.lua` (v2.0.0)

### 4. Add Meter Display
1. **Create Meter Group**
   - Type: Group
   - Name: `meter`
   - Position: Next to fader
   - Size: ~20x200 pixels

2. **Inside Meter Group Add:**
   - Background rectangle (dark gray)
   - Meter bar named `level` (will change color)

3. **Configure OSC**
   - Select the meter group
   - Go to OSC tab
   - Set receive pattern: `/live/track/get/send/meter`
   - Enable ONLY Connection 1

4. **Attach Script**
   - Select the meter group
   - Add script: `meter_script.lua` (v2.0.0)

### 5. Add Mute Button
1. **Create Button**
   - Type: Button
   - Name: `mute`
   - Position: Below fader
   - Size: ~80x40 pixels
   - Label: "MUTE"

2. **Attach Script**
   - Select the button
   - Add script: `mute_button.lua` (v1.0.0)

### 6. Add Pan Control
1. **Create Knob**
   - Type: Radial/Knob
   - Name: `pan`
   - Position: Below mute button
   - Size: ~80x80 pixels

2. **Attach Script**
   - Select the knob
   - Add script: `pan_control.lua` (v1.0.0)

## Visual Layout
```
[Configuration]  [Logger.............]
                 [...................]
                 [...................]

[REFRESH ALL]

┌─────────────────────┐
│ ○ CG #              │  <- Status LED + Label
├─────────────────────┤
│    ┌───┐ ┌─┐       │
│    │   │ │█│       │  <- Fader + Meter
│    │ ▼ │ │█│       │
│    │   │ │ │       │
│    │   │ │ │       │
│    └───┘ └─┘       │
│                     │
│    [ MUTE ]         │  <- Mute button
│                     │
│      ⭕             │  <- Pan knob
│                     │
└─────────────────────┘
```

## Testing Steps

### 1. Initial State Test
- Save and run the layout
- Logger should show initialization messages for ALL scripts:
  ```
  Document Script v2.5.8 loaded
  Group init v1.5.1 for band_CG #
  Fader Script v2.0.0 loaded for band_CG #
  Meter Script v2.0.0 loaded for band_CG #
  Mute Button v1.0.0 loaded for band_CG #
  Pan Control v1.0.0 loaded for band_CG #
  ```
- Status indicator should be RED
- All controls should appear dimmed/disabled

### 2. Ableton Setup
- Open Ableton with band project
- Ensure Connection 1 is connected
- Verify track named "CG #" exists
- Add some audio to the track for meter testing

### 3. Refresh Test
1. Press the REFRESH ALL button
2. Watch logger for messages:
   ```
   === GLOBAL REFRESH ===
   Refreshing group: band_CG #
   Requesting track names for band_CG #
   Received track names from connection 1
   Found track 'CG #' at index X
   Mapped band_CG # -> Track X
   Refreshed 1 groups
   ```
3. Status indicator should turn GREEN
4. All controls should become enabled

### 4. Control Tests

#### Fader Test
- [ ] Fader is enabled (not dimmed)
- [ ] Moving fader sends OSC: `/live/track/set/volume X [value]`
- [ ] OSC only goes to Connection 1
- [ ] Smooth movement without jumps
- [ ] Logger shows volume changes

#### Meter Test
- [ ] Meter responds to audio level
- [ ] Colors change: green → yellow → red
- [ ] Only responds to track X on connection 1
- [ ] Smooth decay animation
- [ ] No response to other tracks

#### Mute Button Test
- [ ] Button is enabled
- [ ] Press toggles between gray (unmuted) and red (muted)
- [ ] Sends OSC: `/live/track/set/mute X [0/1]`
- [ ] Ableton track mutes/unmutes
- [ ] State persists correctly

#### Pan Control Test
- [ ] Knob is enabled
- [ ] Center position = 0.5
- [ ] Sends OSC: `/live/track/set/panning X [value]`
- [ ] Full range -1 to 1 mapped correctly
- [ ] Syncs with Ableton after release

### 5. Integration Test
- [ ] All controls work simultaneously
- [ ] No interference between controls
- [ ] Logger doesn't overflow
- [ ] Performance is smooth

## Success Criteria
Before moving to multiple groups, this single group must:
1. ✅ Initialize without errors
2. ✅ Show correct version messages
3. ✅ Refresh and find track successfully
4. ✅ Enable/disable based on mapping
5. ✅ Route OSC to correct connection only
6. ✅ All controls function properly
7. ✅ Visual feedback is clear
8. ✅ No performance issues

## Troubleshooting

### Controls don't enable after refresh
- Check track name matches exactly ("CG #")
- Verify Connection 1 is active
- Check status LED is green
- Look for errors in logger

### No OSC output
- Ensure group is mapped (green status)
- Check OSC monitor in TouchOSC
- Verify connection settings

### Meter not responding
- Check OSC receive pattern is set
- Ensure Ableton is sending meter data
- Verify only Connection 1 is enabled

## Next Steps
Only after this single group works perfectly:
1. Create additional test groups for edge cases
2. Test wrong connection scenarios
3. Test non-existent tracks
4. Scale up to full production layout