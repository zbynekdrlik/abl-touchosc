# Phase 3: Script Functionality Testing

## Overview
Phase 3 focuses on systematically testing each script to ensure all functionality works correctly. We'll create test setups for each script type and verify their behavior.

## IMPORTANT: Automatic Connection Routing
The entire system uses **automatic connection routing based on group names**:
- Groups named `band_*` automatically use the band connection (from config)
- Groups named `master_*` automatically use the master connection (from config)
- **Enable ALL connections in TouchOSC UI** - the scripts handle filtering!
- This is the core design principle of the selective routing system

## Test Environment Setup

### 1. Root Level Setup

#### 1.1 Configuration Text Object
- **Name**: `configuration`
- **Type**: Text
- **Content**:
```
# TouchOSC Connection Configuration
connection_band: 1
connection_master: 2
```
- **Test**: Verify document script reads this correctly

#### 1.2 Logger Text Object
- **Name**: `logger`
- **Type**: Text
- **Size**: Height ~300px
- **Font**: Monospace
- **Test**: Verify it displays log messages

#### 1.3 Document Script
- **Attach to**: Document root
- **Script**: `document_script.lua v2.5.8`
- **Test checklist**:
  - [ ] Shows "Document Script v2.5.8 loaded" in logger
  - [ ] Configuration parsed correctly
  - [ ] Logger functions work properly
  - [ ] Connection helper functions available

### 2. Global Refresh Button Test

#### 2.1 Create Button
- **Name**: `refresh_button`
- **Type**: Button
- **Script**: `global_refresh_button.lua v1.2.1`

#### 2.2 Tests
- [ ] Button text auto-sets to "REFRESH ALL"
- [ ] Shows "Refreshing..." when pressed
- [ ] Logger shows "=== GLOBAL REFRESH ==="
- [ ] All groups receive refresh notification
- [ ] Button returns to "REFRESH ALL" when done

### 3. Group Script Testing

#### 3.1 Create Test Groups
Create 4 test groups with different scenarios:

**Group 1: Valid Band Track**
- **Name**: `band_Kick`
- **OSC Receive**: `/live/song/get/track_names` (Enable ALL connections)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`
- **Auto-routing**: Will use connection 1 (band)

**Group 2: Valid Master Track**
- **Name**: `master_VOX 1`
- **OSC Receive**: `/live/song/get/track_names` (Enable ALL connections)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`
- **Auto-routing**: Will use connection 2 (master)

**Group 3: Non-existent Track**
- **Name**: `band_FakeTrack`
- **OSC Receive**: `/live/song/get/track_names` (Enable ALL connections)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`
- **Auto-routing**: Will use connection 1 (band)

**Group 4: Wrong Connection Test**
- **Name**: `band_VOX 1` (track exists on master, not band)
- **OSC Receive**: `/live/song/get/track_names` (Enable ALL connections)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`
- **Auto-routing**: Will use connection 1 (band) and NOT find track

#### 3.2 Group Script Tests
For each group, verify:
- [ ] Logger shows "Group init v1.5.1 for [group_name]"
- [ ] Logger shows "Group config - Instance: [band/master], Track: [name], Connection: [1/2]"
- [ ] Status indicator starts red
- [ ] After refresh:
  - [ ] Group 1: Status green (found on connection 1)
  - [ ] Group 2: Status green (found on connection 2)
  - [ ] Group 3: Status red (not found on connection 1)
  - [ ] Group 4: Status red (not found on connection 1, even though exists on 2)
- [ ] Controls in group enable/disable based on mapping status

### 4. Fader Script Testing

#### 4.1 Add Faders to Test Groups
In each test group, add:
- **Name**: `fader`
- **Type**: Fader
- **Script**: `fader_script.lua v2.0.0`

#### 4.2 Fader Tests
- [ ] Version logged: "Fader Script v2.0.0 loaded"
- [ ] When group mapped (green status):
  - [ ] Fader is enabled and responds to touch
  - [ ] Sends OSC to correct connection automatically
  - [ ] OSC format: `/live/track/set/volume [track] [value]`
  - [ ] band_* groups send to connection 1 only
  - [ ] master_* groups send to connection 2 only
- [ ] When group not mapped (red status):
  - [ ] Fader appears dimmed
  - [ ] Does not send OSC when moved
  - [ ] No errors in logger

### 5. Meter Script Testing

#### 5.1 Add Meters to Test Groups
In each test group, add:
- **Name**: `meter`
- **Type**: Group containing:
  - Background rectangle
  - Meter rectangle named `level`
- **Script**: `meter_script.lua v2.0.0` on the group
- **OSC Receive**: `/live/track/get/output_meter_level` (Enable ALL connections)

#### 5.2 Meter Tests
- [ ] Version logged: "Meter Script v2.0.0 loaded"
- [ ] When group mapped:
  - [ ] Meter responds to correct track only
  - [ ] Automatically filters by connection (band=1, master=2)
  - [ ] Ignores meter data from wrong connection
  - [ ] Color changes: green → yellow → red
  - [ ] Smooth decay animation
- [ ] When group not mapped:
  - [ ] Meter appears dimmed (0.3 alpha)
  - [ ] Does not respond to OSC
  - [ ] No errors

### 6. Mute Button Testing

#### 6.1 Add Mute Buttons to Test Groups
In each test group, add:
- **Name**: `mute`
- **Type**: Button
- **Script**: `mute_button.lua v1.0.0`
- **Label**: Set text to "MUTE"

#### 6.2 Mute Button Tests
- [ ] Version logged: "Mute Button v1.0.0 loaded"
- [ ] When group mapped:
  - [ ] Button enabled
  - [ ] Toggles between gray (unmuted) and red (muted)
  - [ ] Sends OSC to correct connection automatically
  - [ ] OSC format: `/live/track/set/mute [track] [0/1]`
- [ ] When group not mapped:
  - [ ] Button appears dimmed
  - [ ] Does not respond to press
  - [ ] No OSC sent

### 7. Pan Control Testing

#### 7.1 Add Pan Controls to Test Groups
In each test group, add:
- **Name**: `pan`
- **Type**: Radial/Knob
- **Script**: `pan_control.lua v1.0.0`

#### 7.2 Pan Control Tests
- [ ] Version logged: "Pan Control v1.0.0 loaded"
- [ ] When group mapped:
  - [ ] Control enabled
  - [ ] Center detent at 0.5
  - [ ] Sends OSC to correct connection automatically
  - [ ] OSC format: `/live/track/set/panning [track] [value]`
  - [ ] Syncs after touch release
- [ ] When group not mapped:
  - [ ] Control appears dimmed
  - [ ] Does not send OSC
  - [ ] No errors

## Test Execution Checklist

### Setup Phase
1. [ ] Create root configuration object
2. [ ] Create logger object
3. [ ] Add document script to root
4. [ ] Verify script loads correctly
5. [ ] Create global refresh button
6. [ ] Create 4 test groups (enable ALL connections)

### Script Testing Phase
For each script type:
1. [ ] Add control to all 4 test groups
2. [ ] Verify version logging
3. [ ] Test with unmapped groups (before refresh)
4. [ ] Press global refresh
5. [ ] Test with mapped groups (1 & 2)
6. [ ] Test with unmapped groups (3 & 4)
7. [ ] Verify automatic OSC routing is correct

### Integration Testing
1. [ ] All controls in mapped groups work together
2. [ ] No interference between groups
3. [ ] Automatic connection routing works correctly
4. [ ] Visual feedback consistent
5. [ ] Logger doesn't overflow

## Expected Log Output

### Initial Load
```
Document Script v2.5.8 loaded
Configuration loaded successfully
- Band connection: 1
- Master connection: 2
Group init v1.5.1 for band_Kick
Group config - Instance: band, Track: Kick, Connection: 1
Group init v1.5.1 for master_VOX 1
Group config - Instance: master, Track: VOX 1, Connection: 2
Group init v1.5.1 for band_FakeTrack
Group config - Instance: band, Track: FakeTrack, Connection: 1
Group init v1.5.1 for band_VOX 1
Group config - Instance: band, Track: VOX 1, Connection: 1
Global Refresh Button v1.2.1 loaded
Fader Script v2.0.0 loaded
Meter Script v2.0.0 loaded
Mute Button v1.0.0 loaded
Pan Control v1.0.0 loaded
```

### After Global Refresh
```
=== GLOBAL REFRESH ===
Refreshing group: band_Kick
Requesting track names for band_Kick
Mapped band_Kick -> Track 0
Refreshing group: master_VOX 1
Requesting track names for master_VOX 1
Mapped master_VOX 1 -> Track 3
Refreshing group: band_FakeTrack
No track found for band_FakeTrack
Refreshing group: band_VOX 1
No track found for band_VOX 1
Refreshed 4 groups
```

## Common Issues to Check

### 1. Script Loading
- Missing version log → Script not attached
- Multiple version logs → Script attached multiple times
- Errors on load → Syntax or reference issues

### 2. Automatic Routing
- Groups respond to wrong connection → Check script version
- No automatic filtering → Ensure scripts are v1.5.1+
- Wrong connection used → Check configuration text

### 3. Visual Feedback
- Status stays red → Track name mismatch
- Controls not dimming → Old script version
- Meter not moving → OSC pattern not configured

### 4. Performance
- Slow refresh → Too many groups or network latency
- Logger overflow → Reduce log retention
- Lag on control → Check update() frequency

## Success Criteria

All scripts must:
1. Load without errors
2. Log correct version
3. **Automatically route based on group name**
4. Respect group mapping status
5. Route OSC to correct connection
6. Provide appropriate visual feedback
7. Integrate smoothly with other scripts
8. Handle edge cases gracefully

## Key Testing Point: Automatic Routing

The most important test is verifying that:
- `band_VOX 1` does NOT find the track (even though VOX 1 exists on master)
- This proves the automatic routing is working correctly
- The group only looks at connection 1 because of the "band_" prefix

## Next Steps

Once all scripts pass testing:
1. Test with single complete track group
2. Scale to full production layout
3. Document any workarounds needed
4. Create user setup guide

## Appendix: Quick Script Reference

| Script | Version | Purpose | Key Features |
|--------|---------|---------|--------------|
| document_script.lua | 2.5.8 | Configuration & logging | Config parsing, central logging |
| group_init.lua | 1.5.1 | Track mapping | Auto-routing by name, safety |
| global_refresh_button.lua | 1.2.1 | Refresh all groups | Single button refresh |
| fader_script.lua | 2.0.0 | Volume control | Connection-aware, smooth |
| meter_script.lua | 2.0.0 | Level display | Auto-filtered input, colors |
| mute_button.lua | 1.0.0 | Mute toggle | Visual feedback |
| pan_control.lua | 1.0.0 | Pan adjustment | Center detent |