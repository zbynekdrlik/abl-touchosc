# Single Track Group Complete Test Setup

## Overview
Create ONE complete track group with all control scripts to verify everything works together before testing multiple scenarios.

## Test Track Selection
We'll use **"band_CG #"** as our test track since:
- It's the actual track name in your band project
- It tests special characters in track names
- The group name automatically determines it uses Connection 1

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
   - **Enable ALL connections** (the script will filter based on group name!)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

### IMPORTANT: How Connection Routing Works
The entire system is designed so that the **group name determines the connection automatically**:
- Groups named `band_*` use the connection configured for "band" (default: 1)
- Groups named `master_*` use the connection configured for "master" (default: 2)
- The script handles ALL filtering - you don't need to set connections in the UI!

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
   - **Enable ALL connections** (script filters automatically)

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
  Group config - Instance: band, Track: CG #, Connection: 1
  Fader Script v2.0.0 loaded for band_CG #
  Meter Script v2.0.0 loaded for band_CG #
  Mute Button v1.0.0 loaded for band_CG #
  Pan Control v1.0.0 loaded for band_CG #
  ```
- Status indicator should be RED
- All controls should appear dimmed/disabled

### 2. Ableton Setup
- Open Ableton with band project
- Ensure Connection 1 is connected to band project
- Verify track named "CG #" exists
- Add some audio to the track for meter testing

### 3. Refresh Test
1. Press the REFRESH ALL button
2. Watch logger for messages:
   ```
   === GLOBAL REFRESH ===
   Refreshing group: band_CG #
   Requesting track names for band_CG #
   ```
3. The script will:
   - Send request ONLY to connection 1 (determined by "band_" prefix)
   - Ignore any responses from connection 2
   - Find track "CG #" and map it
4. Expected result:
   ```
   Mapped band_CG # -> Track X
   ```
5. Status indicator should turn GREEN
6. All controls should become enabled

### 4. Control Tests

#### Fader Test
- [ ] Fader is enabled (not dimmed)
- [ ] Moving fader sends OSC: `/live/track/set/volume X [value]`
- [ ] OSC only goes to Connection 1 (automatic from group name)
- [ ] Smooth movement without jumps
- [ ] Logger shows volume changes

#### Meter Test
- [ ] Meter responds to audio level
- [ ] Colors change: green → yellow → red
- [ ] Only responds to track X on connection 1
- [ ] Ignores meter data from connection 2
- [ ] Smooth decay animation

#### Mute Button Test
- [ ] Button is enabled
- [ ] Press toggles between gray (unmuted) and red (muted)
- [ ] Sends OSC: `/live/track/set/mute X [0/1]`
- [ ] OSC only goes to Connection 1
- [ ] Ableton track mutes/unmutes

#### Pan Control Test
- [ ] Knob is enabled
- [ ] Center position = 0.5
- [ ] Sends OSC: `/live/track/set/panning X [value]`
- [ ] OSC only goes to Connection 1
- [ ] Full range -1 to 1 mapped correctly

### 5. Connection Isolation Test
To verify the automatic connection routing:
1. Create a track named "CG #" in your master project (connection 2)
2. The band_CG # group should NOT respond to it
3. Only tracks from connection 1 should be recognized

## Success Criteria
Before moving to multiple groups, this single group must:
1. ✅ Initialize without errors
2. ✅ Show correct version messages
3. ✅ Automatically use correct connection based on name
4. ✅ Refresh and find track successfully
5. ✅ Enable/disable based on mapping
6. ✅ Route OSC to correct connection only
7. ✅ All controls function properly
8. ✅ Visual feedback is clear
9. ✅ No performance issues

## Troubleshooting

### Controls don't enable after refresh
- Check track name matches exactly ("CG #")
- Verify Connection 1 is active and connected to band project
- Check status LED is green
- Look for errors in logger

### Group responds to wrong connection
- This should NOT happen with correct scripts
- Check group name starts with "band_" for connection 1
- Verify configuration has `connection_band: 1`
- Check script version is 1.5.1 or higher

### No OSC output
- Ensure group is mapped (green status)
- Check OSC monitor in TouchOSC
- Verify controls are sending to connection 1

## Next Steps
Only after this single group works perfectly:
1. Create a `master_*` group to test connection 2 routing
2. Test wrong connection scenarios
3. Test non-existent tracks
4. Scale up to full production layout