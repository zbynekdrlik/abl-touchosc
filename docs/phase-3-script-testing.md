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

#### 1.1 Create the Band Track Group ✅
1. Create a **Group** control
2. Name it: `band_CG #`
3. Inside the group, add:
   - A **LED** control named `status_indicator`
4. Select the group and:
   - Attach `group_init.lua` (v1.7.0) to it
   - In the OSC tab, set Receive to: `/live/song/get/track_names`
   - **Enable ALL connections** (1-10) in the receive settings

#### 1.2 Group Behavior ✅
- Status indicator RED initially (unmapped)
- After refresh: Status indicator GREEN
- Group mapped to Track 39
- Controls enabled

#### 1.3 Fader Control ✅
**Status: FULLY WORKING (v2.3.3)**

Issues fixed:
1. **Script isolation** - Fader now reads config directly
2. **Tag format** - Handles "band:39" format correctly
3. **OSC parameters** - Sends both track and volume
4. **Logger spam** - Volume logs only in debug mode

Fader features working:
- Movement smoothing with gradual scaling
- Immediate 0.1dB response
- Reaction time compensation
- Emergency movement detection
- Double-tap to 0dB
- Logarithmic curve (-6dB at 50%)
- OSC sync with delay

### Phase 2: Add and Test Each Control

#### 2.1 Meter Display
1. Inside `band_CG #` group, create a sub-group:
   - **Name**: `meter`
   - **Type**: Group
   - Inside meter group:
     - Add a rectangle for background (optional)
     - Add a rectangle named `level` for the meter bar
   - **Script**: `meter_script.lua` (v2.1.0) on the meter group
   - **OSC Receive**: `/live/track/get/output_meter_level` (Enable ALL connections)

2. Expected behavior:
   - Logger shows: `METER(band_CG #): Script v2.1.0 loaded`
   - When group is mapped:
     - Meter responds ONLY to levels from connection 2
     - Level bar animates with audio
     - Colors: green (low) → yellow (medium) → red (high)
     - Smooth decay when signal drops
   - Before mapping:
     - Meter dimmed (0.3 alpha)
     - No response to OSC

**Note**: Meter script will need same fixes as fader:
- Read configuration directly
- Handle "band:39" tag format
- Filter by connection properly

#### 2.2 Mute Button
1. Inside `band_CG #` group, add:
   - **Name**: `mute`
   - **Type**: Button
   - **Label**: "MUTE"
   - **Script**: `mute_button.lua` (v1.1.0)

2. Expected behavior:
   - Logger shows: `MUTE(band_CG #): Script v1.1.0 loaded`
   - When group is mapped:
     - Button enabled
     - Press toggles between gray (unmuted) and red (muted)
     - Logs: `MUTE(band_CG #): Mute [ON/OFF] for track [n]`
     - OSC sent to connection 2: `/live/track/set/mute [track] [0/1]`
   - Before mapping:
     - Button dimmed
     - Press does nothing

#### 2.3 Pan Control
1. Inside `band_CG #` group, add:
   - **Name**: `pan`
   - **Type**: Radial/Knob
   - **Script**: `pan_control.lua` (v1.1.0)

2. Expected behavior:
   - Logger shows: `PAN(band_CG #): Script v1.1.0 loaded`
   - When group is mapped:
     - Control enabled
     - Center position = 0.5
     - Logs pan changes
     - OSC sent to connection 2: `/live/track/set/panning [track] [value]`
   - Before mapping:
     - Control dimmed
     - No OSC sent

### Phase 3: Complete Integration Test

Once all controls are added to `band_CG #`:

1. **Initial State Test** (before refresh) ✅
   - All controls should be dimmed
   - Status indicator RED
   - No OSC communication

2. **Refresh and Map Test** ✅
   - Press global refresh
   - Status should turn GREEN
   - All controls should brighten/enable

3. **Functionality Test**
   - Move fader → volume changes in Ableton (band instance only) ✅
   - Meter shows audio levels from band instance only
   - Mute button toggles mute state
   - Pan control adjusts panning

4. **Connection Isolation Test** ✅
   - Verify NO response to OSC from master instance (connection 3)
   - All OSC output goes ONLY to connection 2

### Phase 4: Add master_Hand1 # Group

Only after `band_CG #` is working perfectly:

1. Create `master_Hand1 #` group with same controls
2. This should:
   - Auto-route to connection 3 (master)
   - Find track on master instance
   - Operate completely independently

## Critical Configuration Note

Real-world configuration:
```
connection_band: 2
connection_master: 3
```

This differs from typical examples where band=1, master=2.

## Success Criteria for band_CG #

- [x] Group initializes with correct logging
- [x] Status indicator shows mapping state
- [x] All controls log their versions
- [x] Refresh button successfully maps the track
- [x] Fader controls volume on band instance only
- [ ] Meter shows levels from band instance only
- [ ] Mute button works correctly
- [ ] Pan control works correctly
- [x] NO cross-talk with master instance
- [x] All logs use centralized logging pattern
- [x] Visual feedback is consistent

## Known Issues and Solutions

### Script Isolation
- **Issue**: Scripts cannot share functions or variables
- **Solution**: Each script must read configuration directly
- **Pattern**: Use `root:findByName("configuration", true)` in each script

### Tag Format Changes
- **Issue**: Parent uses "instance:track" format, children expect just track number
- **Solution**: Parse tag with pattern matching: `tag:match("(%w+):(%d+)")`

### OSC Parameter Order
- **Issue**: Variadic parameters with connection tables can fail
- **Solution**: Use explicit parameters in sendOSC functions

### Logger Verbosity
- **Issue**: Frequent updates spam the logger
- **Solution**: Use debug mode for verbose logging, normal mode for essential messages only

## Next Steps

1. Complete testing of meter, mute, and pan controls
2. Fix any issues found (likely same pattern as fader fixes)
3. Document any additional workarounds needed
4. Create `master_Hand1 #` group
5. Test full multi-instance functionality
6. Scale to production layout