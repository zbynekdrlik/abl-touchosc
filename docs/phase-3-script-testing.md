# Phase 3: Script Functionality Testing

## Overview
Phase 3 focuses on systematically testing each script to ensure all functionality works correctly. We'll create test setups for each script type and verify their behavior.

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
- **Test**: Verify helper script reads this correctly

#### 1.2 Logger Text Object
- **Name**: `logger`
- **Type**: Text
- **Size**: Height ~300px
- **Font**: Monospace
- **Test**: Verify it displays log messages

#### 1.3 Helper Script
- **Attach to**: Document root
- **Script**: `helper_script.lua v1.0.9`
- **Test checklist**:
  - [ ] Shows "Helper Script v1.0.9 loaded" in logger
  - [ ] Configuration parsed correctly
  - [ ] Logger functions work (addLog, clearLog)
  - [ ] Connection helper functions available

### 2. Global Refresh Button Test

#### 2.1 Create Button
- **Name**: `refresh_button`
- **Type**: Button
- **Script**: `global_refresh_button.lua v1.1.0`

#### 2.2 Tests
- [ ] Button text auto-sets to "REFRESH ALL"
- [ ] Shows "Refreshing..." when pressed
- [ ] Logger shows "=== GLOBAL REFRESH INITIATED ==="
- [ ] All groups receive refresh notification
- [ ] Button returns to "REFRESH ALL" when done
- [ ] Status label updates (if exists)

### 3. Group Script Testing

#### 3.1 Create Test Groups
Create 4 test groups with different scenarios:

**Group 1: Valid Band Track**
- **Name**: `band_Kick`
- **OSC Receive**: `/live/song/get/track_names` (Connection 1 enabled)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`

**Group 2: Valid Master Track**
- **Name**: `master_VOX 1`
- **OSC Receive**: `/live/song/get/track_names` (Connection 2 enabled)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`

**Group 3: Non-existent Track**
- **Name**: `band_FakeTrack`
- **OSC Receive**: `/live/song/get/track_names` (Connection 1 enabled)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`

**Group 4: Wrong Connection**
- **Name**: `band_VOX 1` (band prefix but track on master)
- **OSC Receive**: `/live/song/get/track_names` (Connection 1 enabled)
- **Status Indicator**: LED named `status_indicator`
- **Script**: `group_init.lua v1.5.1`

#### 3.2 Group Script Tests
For each group, verify:
- [ ] Logger shows "Group init vX.X.X for [group_name]"
- [ ] Status indicator exists and starts red
- [ ] After refresh:
  - [ ] Group 1: Status green, trackNumber set
  - [ ] Group 2: Status green, trackNumber set
  - [ ] Group 3: Status red, trackNumber = -1
  - [ ] Group 4: Status red, trackNumber = -1
- [ ] Logger shows correct mapping results
- [ ] Controls in group enable/disable based on status

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
  - [ ] Sends OSC to correct connection only
  - [ ] OSC format: `/live/track/set/volume [track] [value]`
  - [ ] Smooth movement works
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
- **OSC Receive**: `/live/track/get/send/meter` pattern

#### 5.2 Meter Tests
- [ ] Version logged: "Meter Script v2.0.0 loaded"
- [ ] When group mapped:
  - [ ] Meter responds to correct track only
  - [ ] Filters messages by connection
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
  - [ ] Sends OSC to correct connection
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
  - [ ] Sends OSC to correct connection
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
3. [ ] Add helper script to root
4. [ ] Verify helper loads correctly
5. [ ] Create global refresh button
6. [ ] Create 4 test groups

### Script Testing Phase
For each script type:
1. [ ] Add control to all 4 test groups
2. [ ] Verify version logging
3. [ ] Test with unmapped groups (before refresh)
4. [ ] Press global refresh
5. [ ] Test with mapped groups (1 & 2)
6. [ ] Test with unmapped groups (3 & 4)
7. [ ] Verify OSC routing is correct

### Integration Testing
1. [ ] All controls in mapped groups work together
2. [ ] No interference between groups
3. [ ] Correct connection routing for all
4. [ ] Visual feedback consistent
5. [ ] Logger doesn't overflow

## Expected Log Output

### Initial Load
```
Helper Script v1.0.9 loaded at [time]
Configuration loaded successfully
- Band connection: 1
- Master connection: 2
Group init v1.5.1 for band_Kick
Group init v1.5.1 for master_VOX 1
Group init v1.5.1 for band_FakeTrack
Group init v1.5.1 for band_VOX 1
Global Refresh Button v1.1.0 loaded
Fader Script v2.0.0 loaded
Meter Script v2.0.0 loaded
Mute Button v1.0.0 loaded
Pan Control v1.0.0 loaded
```

### After Global Refresh
```
=== GLOBAL REFRESH INITIATED ===
Refreshing band_Kick
Requesting track names from connection 1
[OSC Response]
Mapped band_Kick -> Track 0
Refreshing master_VOX 1
Requesting track names from connection 2
[OSC Response]
Mapped master_VOX 1 -> Track 3
Refreshing band_FakeTrack
Requesting track names from connection 1
[OSC Response]
No track found for band_FakeTrack
Refreshing band_VOX 1
Requesting track names from connection 1
[OSC Response]
No track found for band_VOX 1
=== GLOBAL REFRESH COMPLETE ===
```

## Common Issues to Check

### 1. Script Loading
- Missing version log → Script not attached
- Multiple version logs → Script attached multiple times
- Errors on load → Syntax or reference issues

### 2. OSC Routing
- Messages to all connections → Missing connection table
- No OSC sent → Group not mapped or safety check failing
- Wrong track controlled → Incorrect trackNumber

### 3. Visual Feedback
- Status stays red → Track name mismatch
- Controls not dimming → Old script version
- Meter not moving → OSC pattern not configured

### 4. Performance
- Slow refresh → Too many groups or network latency
- Logger overflow → Reduce log retention
- Lag on control → Check update() frequency

## Test Result Template

```
Script: [Script Name]
Version: [Version]
Test Date: [Date]
Tester: [Name]

Setup:
- [ ] Script attached correctly
- [ ] Version logged
- [ ] No load errors

Functionality Tests:
- [ ] Unmapped behavior correct
- [ ] Mapped behavior correct
- [ ] OSC routing correct
- [ ] Visual feedback working
- [ ] Integration with group working

Issues Found:
1. [Description]
   - Steps to reproduce
   - Expected vs actual
   - Severity

Performance:
- Response time: [Good/Acceptable/Poor]
- CPU usage: [Low/Medium/High]
- Memory stable: [Yes/No]

Notes:
[Additional observations]
```

## Success Criteria

All scripts must:
1. Load without errors
2. Log correct version
3. Respect group mapping status
4. Route OSC to correct connection
5. Provide appropriate visual feedback
6. Integrate smoothly with other scripts
7. Handle edge cases gracefully

## Next Steps

Once all scripts pass testing:
1. Document any workarounds needed
2. Create user setup guide
3. Plan production deployment
4. Schedule user training

## Appendix: Quick Script Reference

| Script | Version | Purpose | Key Features |
|--------|---------|---------|--------------|
| helper_script.lua | 1.0.9 | Configuration & utilities | Logger, config parsing |
| group_init.lua | 1.5.1 | Track mapping | Auto-discovery, safety |
| global_refresh_button.lua | 1.1.0 | Refresh all groups | Single button refresh |
| fader_script.lua | 2.0.0 | Volume control | Connection-aware, smooth |
| meter_script.lua | 2.0.0 | Level display | Filtered input, colors |
| mute_button.lua | 1.0.0 | Mute toggle | Visual feedback |
| pan_control.lua | 1.0.0 | Pan adjustment | Center detent |