# Phase 3: Script Functionality Testing - Real Scenario

## Overview
Phase 3 focuses on testing with real track names from the actual setup. We'll test two specific tracks:
- `band_CG #` - A track that exists in the band Ableton instance
- `master_Hand1 #` - A track that exists in the master Ableton instance

## Testing Approach
We'll start by creating and perfecting the `band_CG #` group with all controls, then move to `master_Hand1 #`.

## Test Environment Setup (Already Complete)

### 1. Root Level Setup ✅
- Configuration text object with connections
- Logger text object for centralized logging
- Document script v2.5.9 attached to root
- Global refresh button

## Real Scenario Testing

### Phase 1: Perfect the band_CG # Group

#### 1.1 Create the Band Track Group
1. Create a **Group** control
2. Name it: `band_CG #`
3. Inside the group, add:
   - A **LED** control named `status_indicator`
4. Select the group and:
   - Attach `group_init.lua` (v1.7.0) to it
   - In the OSC tab, set Receive to: `/live/song/get/track_names`
   - **Enable ALL connections** (1-10) in the receive settings

#### 1.2 Expected Initial Behavior
After creating the group and reloading:
- Logger should show: `CONTROL(band_CG #): Group init v1.7.0 for band_CG #`
- Logger should show: `CONTROL(band_CG #): Group config - Instance: band, Track: CG #, Connection: 1`
- Status indicator should be RED (unmapped)

#### 1.3 Test Refresh and Mapping
1. Press the global refresh button
2. Expected logs:
   ```
   === GLOBAL REFRESH ===
   CONTROL(band_CG #): Refreshing group
   CONTROL(band_CG #): Requesting track names
   CONTROL(band_CG #): Mapped band_CG # -> Track [number]
   ```
3. Status indicator should turn GREEN
4. Group should store its track number

### Phase 2: Add and Test Each Control

#### 2.1 Fader Control
1. Inside `band_CG #` group, add:
   - **Name**: `fader`
   - **Type**: Fader (vertical)
   - **Script**: `fader_script.lua` (v2.1.0)

2. Expected behavior:
   - Logger shows: `FADER(band_CG #): Fader Script v2.1.0 loaded`
   - When group is mapped (green):
     - Fader is enabled and bright
     - Moving fader logs: `FADER(band_CG #): Volume change for track [n]: [value]`
     - OSC sent ONLY to connection 1: `/live/track/set/volume [track] [value]`
   - Before mapping (red):
     - Fader appears dimmed (0.3 alpha)
     - Moving fader does nothing

#### 2.2 Meter Display
1. Inside `band_CG #` group, create a sub-group:
   - **Name**: `meter`
   - **Type**: Group
   - Inside meter group:
     - Add a rectangle for background (optional)
     - Add a rectangle named `level` for the meter bar
   - **Script**: `meter_script.lua` (v2.1.0) on the meter group
   - **OSC Receive**: `/live/track/get/output_meter_level` (Enable ALL connections)

2. Expected behavior:
   - Logger shows: `METER(band_CG #): Meter Script v2.1.0 loaded`
   - When group is mapped:
     - Meter responds ONLY to levels from connection 1
     - Level bar animates with audio
     - Colors: green (low) → yellow (medium) → red (high)
     - Smooth decay when signal drops
   - Before mapping:
     - Meter dimmed (0.3 alpha)
     - No response to OSC

#### 2.3 Mute Button
1. Inside `band_CG #` group, add:
   - **Name**: `mute`
   - **Type**: Button
   - **Label**: "MUTE"
   - **Script**: `mute_button.lua` (v1.1.0)

2. Expected behavior:
   - Logger shows: `MUTE(band_CG #): Mute Button v1.1.0 loaded`
   - When group is mapped:
     - Button enabled
     - Press toggles between gray (unmuted) and red (muted)
     - Logs: `MUTE(band_CG #): Mute [ON/OFF] for track [n]`
     - OSC sent to connection 1: `/live/track/set/mute [track] [0/1]`
   - Before mapping:
     - Button dimmed
     - Press does nothing

#### 2.4 Pan Control
1. Inside `band_CG #` group, add:
   - **Name**: `pan`
   - **Type**: Radial/Knob
   - **Script**: `pan_control.lua` (v1.1.0)

2. Expected behavior:
   - Logger shows: `PAN(band_CG #): Pan Control v1.1.0 loaded`
   - When group is mapped:
     - Control enabled
     - Center position = 0.5
     - Logs pan changes
     - OSC sent to connection 1: `/live/track/set/panning [track] [value]`
   - Before mapping:
     - Control dimmed
     - No OSC sent

### Phase 3: Complete Integration Test

Once all controls are added to `band_CG #`:

1. **Initial State Test** (before refresh)
   - All controls should be dimmed
   - Status indicator RED
   - No OSC communication

2. **Refresh and Map Test**
   - Press global refresh
   - Status should turn GREEN
   - All controls should brighten/enable

3. **Functionality Test**
   - Move fader → volume changes in Ableton (band instance only)
   - Meter shows audio levels from band instance only
   - Mute button toggles mute state
   - Pan control adjusts panning

4. **Connection Isolation Test**
   - Verify NO response to OSC from master instance (connection 2)
   - All OSC output goes ONLY to connection 1

### Phase 4: Add master_Hand1 # Group

Only after `band_CG #` is working perfectly:

1. Create `master_Hand1 #` group with same controls
2. This should:
   - Auto-route to connection 2 (master)
   - Find track on master instance
   - Operate completely independently

## Success Criteria for band_CG #

- [ ] Group initializes with correct logging
- [ ] Status indicator shows mapping state
- [ ] All controls log their versions
- [ ] Refresh button successfully maps the track
- [ ] Fader controls volume on band instance only
- [ ] Meter shows levels from band instance only
- [ ] Mute button works correctly
- [ ] Pan control works correctly
- [ ] NO cross-talk with master instance
- [ ] All logs use centralized logging pattern
- [ ] Visual feedback is consistent

## Logging Examples

### Expected Log Sequence
```
16:26:14 CONTROL(band_CG #): Group init v1.7.0 for band_CG #
16:26:14 CONTROL(band_CG #): Group config - Instance: band, Track: CG #, Connection: 1
16:26:14 FADER(band_CG #): Fader Script v2.1.0 loaded
16:26:14 METER(band_CG #): Meter Script v2.1.0 loaded
16:26:14 MUTE(band_CG #): Mute Button v1.1.0 loaded
16:26:14 PAN(band_CG #): Pan Control v1.1.0 loaded
16:26:18 === GLOBAL REFRESH ===
16:26:18 REFRESH BUTTON: Refreshing...
16:26:18 CONTROL(band_CG #): Refreshing group
16:26:18 CONTROL(band_CG #): Requesting track names
16:26:18 CONTROL(band_CG #): Mapped band_CG # -> Track 5
16:26:18 REFRESH BUTTON: Refreshed 1 groups
```

## Common Issues and Solutions

1. **Controls not dimming**: Check script versions (need v2.1.0 for controls)
2. **No logging**: Verify document script is v2.5.9 with log_message handler
3. **Wrong connection**: Check configuration text has correct connection numbers
4. **Track not found**: Verify exact track name match including spaces/special characters

## Next Steps

After successfully testing:
1. Document any issues found
2. Create the `master_Hand1 #` group
3. Test both groups working simultaneously
4. Scale to full production layout