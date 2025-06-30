# TouchOSC Selective Connection Routing - Complete Implementation Guide

## Overview
This feature enables TouchOSC to route different faders to different Ableton Live instances. Some controls go to a "band" instance while others go to a "master" instance, each running AbletonOSC on different ports.

## Current Status: Phase 1 Complete ✅

### What's Working
- ✅ Configuration system via text object
- ✅ Visual logger for debugging
- ✅ Group-based connection routing
- ✅ Automatic track discovery and mapping
- ✅ Global refresh system
- ✅ Safety features (controls disable when unmapped)
- ✅ Visual status indicators

### Script Versions
- **helper_script.lua**: v1.0.9
- **group_init.lua**: v1.5.1
- **global_refresh_button.lua**: v1.1.0
- **fader_script.lua**: Original (needs Phase 2 update)
- **meter_script.lua**: Original (needs Phase 2 update)

## Complete Setup Guide (From Scratch)

### Prerequisites
- TouchOSC Editor
- Two Ableton Live instances with AbletonOSC
- Basic understanding of TouchOSC scripting

### Step 1: TouchOSC Connection Configuration
Configure your connections in TouchOSC:

```
Connection 1: Band Ableton
- Host: [Band Computer IP]
- Send Port: [AbletonOSC Port - typically 11000]
- Receive Port: [Local Port 1 - e.g., 11001]

Connection 2: Master Ableton  
- Host: [Master Computer IP]
- Send Port: [AbletonOSC Port - typically 11000]
- Receive Port: [Local Port 2 - e.g., 11002]
```

**CRITICAL**: Each connection must have a unique receive port!

### Step 2: Create Root Configuration Objects

#### 2.1 Configuration Text Object (REQUIRED)
1. Add a Text object to document root
2. Name it exactly: `configuration`
3. Properties:
   - Font size: 12-14pt
   - Position: Anywhere (can be hidden)
4. Content:
```
# TouchOSC Connection Configuration
connection_band: 1
connection_master: 2
```

#### 2.2 Logger Text Object (RECOMMENDED)
1. Add a Text object to document root
2. Name it exactly: `logger`
3. Properties:
   - Height: ~300px (fits ~20 lines)
   - Font: Monospace recommended
   - Interactive: OFF (read-only)
   - Position: Visible area for debugging

#### 2.3 Global Status Label (OPTIONAL)
1. Add a Label object to document root
2. Name it: `global_status`
3. Use for refresh feedback

### Step 3: Add Helper Script to Root

1. Select document root in editor
2. Add new script
3. Copy entire `helper_script.lua` content
4. Save and verify in control mode:
   - Logger should show: "Helper Script v1.0.9 loaded"
   - Configuration should be parsed

**VERIFICATION**: Check logger shows configuration loaded correctly

### Step 4: Create Global Refresh Button

1. Add a Button control
2. Name it descriptively (e.g., "REFRESH ALL TRACKS")
3. Properties:
   - Size: Large enough to tap easily
   - Color: Distinct (e.g., yellow)
   - Position: Top of interface
4. Add script: Copy entire `global_refresh_button.lua`
5. The button text will auto-set to "REFRESH ALL"

### Step 5: Prepare Track Groups

For EACH track group you want to control:

#### 5.1 Group Naming Convention
Rename groups with instance prefix:
- Band tracks: `band_TrackName`
- Master tracks: `master_TrackName`

Examples:
- "Kick #" → "band_Kick #"
- "VOX 1 #" → "master_VOX 1 #"

**CRITICAL**: The name after prefix must EXACTLY match Ableton track name!

#### 5.2 Add Status Indicator
1. Add an LED or small label inside the group
2. Name it EXACTLY: `status_indicator`
3. Position: Top corner of group
4. This will show:
   - Green = Track mapped correctly
   - Red = Track not found
   - Orange = Data stale (>5 min)

#### 5.3 Configure Group OSC Receive
**CRITICAL - Must be done in editor, cannot be scripted!**

1. Select the group in editor
2. Go to OSC tab
3. In Receive section:
   - Pattern: `/live/song/get/track_names`
   - Enable checkbox for the connection(s) this group uses
   - Band groups: Enable connection 1
   - Master groups: Enable connection 2

#### 5.4 Add Group Script
1. Select the group
2. Remove any existing scripts
3. Add new script
4. Copy entire `group_init.lua` content
5. Save

#### 5.5 Optional Track Label
If you have a label showing track name:
1. Name it exactly: `fdr_label`
2. It will auto-update with track name (without # suffix)

### Step 6: Initial Testing

1. Enter control surface mode
2. Check logger output:
   ```
   Helper Script v1.0.9 loaded
   Configuration loaded correctly
   Group init v1.5.1 for band_Kick #
   Group init v1.5.1 for master_VOX 1 #
   etc...
   ```

3. All groups should show:
   - Status indicators RED (not mapped yet)
   - Controls dimmed/disabled

4. Press global refresh button
5. Logger should show:
   ```
   === GLOBAL REFRESH INITIATED ===
   Refreshing band_Kick #
   Mapped band_Kick # -> Track 0
   Refreshing master_VOX 1 #
   Mapped master_VOX 1 # -> Track 5
   === GLOBAL REFRESH COMPLETE ===
   ```

6. Verify:
   - Green status = track found
   - Red status = track not found
   - Controls enabled only for green status

## Critical Implementation Details

### 1. Script Isolation
Every script runs in complete isolation:
- No shared variables between scripts
- Each script has its own Lua context
- Communication only via:
  - `notify()` function
  - Parent/child properties
  - Control values

### 2. Color Management
```lua
-- CORRECT
self.color = Color(1, 0, 0, 1)  -- Red

-- WRONG - Will fail!
self.color = {1, 0, 0}
```

### 3. OSC Connection Routing
```lua
-- CORRECT - With connection table
local connections = {true, false, false, false, false, false, false, false, false, false}
sendOSC('/live/track/get/volume', trackIndex, connections)

-- WRONG - Sends to ALL connections!
sendOSC('/live/track/get/volume', trackIndex)
```

### 4. OSC Receive Patterns
- MUST be configured in TouchOSC editor UI
- Cannot be set via script
- Groups need `/live/song/get/track_names` pattern

### 5. Safety Features
- Exact track name matching (no fuzzy matching)
- Controls auto-disable when track not found
- Visual feedback for all states
- Track numbers cleared before remapping

## Testing Scenarios

### Test 1: Basic Functionality
1. Start both Ableton instances
2. Load TouchOSC template
3. Press global refresh
4. Verify all tracks map correctly
5. Test fader movement

### Test 2: Track Reordering
1. Reorder tracks in Ableton
2. Note controls may operate wrong tracks
3. Press global refresh
4. Verify correct mapping restored

### Test 3: Safety Features
1. Rename a track in Ableton
2. Press global refresh
3. Verify:
   - Status turns red
   - Controls are disabled
   - Cannot move fader

### Test 4: Connection Failure
1. Disconnect one Ableton instance
2. Press global refresh
3. Groups for that instance should show red
4. Other instance should work normally

## Troubleshooting Guide

### Problem: No groups found on refresh
- Check group names have correct prefix
- Verify `self.tag = "trackGroup"` is set
- Check logger for errors

### Problem: Track not mapping
- Verify EXACT name match (including spaces)
- Check track has # suffix if expected
- Ensure OSC receive pattern configured

### Problem: Wrong connection used
- Check configuration text object
- Verify connection numbers (1-10)
- Check group prefix matches config

### Problem: Controls not disabling
- Update to latest group_init.lua (v1.5.1)
- Check status indicator exists
- Verify safety features in script

### Problem: OSC not received
- Check receive ports are unique
- Verify Ableton sending to correct port
- Use OSC monitor in TouchOSC
- Check group OSC pattern configuration

## Phase 2 Preparation

### Update Fader Script
The fader needs connection awareness:

```lua
function onValueChanged(key)
    if key == "x" and self.values.touch then
        local parent = self.parent
        if not parent or not parent.trackNumber then
            return  -- Safety check
        end
        
        -- Parse connection from parent tag
        local tag = parent.tag or ""
        local instance, trackNum = tag:match("(%w+):(%d+)")
        if not instance or not trackNum then return end
        
        -- Get connection index
        local connIndex = instance == "master" and 2 or 1
        local connections = {}
        for i = 1, 10 do
            connections[i] = (i == connIndex)
        end
        
        -- Send to specific connection
        local audio_value = use_log_curve and linearToLog(self.values.x) or self.values.x
        sendOSC("/live/track/set/volume", tonumber(trackNum), audio_value, connections)
    end
end
```

### Update Meter Script
Similar pattern for meter to filter incoming OSC by connection.

## Best Practices

### 1. Always Test Safety
- Rename tracks to test unmapping
- Reorder to test refresh
- Disconnect to test failures

### 2. Use Visual Feedback
- Status indicators mandatory
- Logger helpful for debugging
- Clear color coding

### 3. Document Track Names
- Keep a list of exact track names
- Note which go to which instance
- Plan for future additions

### 4. Performance Considerations
- Limit logger to 20 lines
- Avoid frequent refreshes
- Disable unused connections

## Version Control

### Current Versions
- helper_script.lua: 1.0.9
- group_init.lua: 1.5.1  
- global_refresh_button.lua: 1.1.0

### Version History
- 1.0.0-1.0.5: Initial helper development
- 1.0.6-1.0.9: Configuration and logging
- 1.1.0-1.4.6: Group script development
- 1.5.0-1.5.1: Safety features and global refresh

### Update Procedure
1. Always increment version in script
2. Log version on startup
3. Update documentation
4. Test before deployment

## Summary Checklist

Setup:
- [ ] TouchOSC connections configured
- [ ] Configuration text object created
- [ ] Helper script added to root
- [ ] Global refresh button created
- [ ] Groups renamed with prefixes
- [ ] Status indicators added
- [ ] OSC receive patterns configured
- [ ] Group scripts added

Testing:
- [ ] All scripts show version on load
- [ ] Configuration parsed correctly
- [ ] Groups map to correct tracks
- [ ] Refresh recovers from reordering
- [ ] Controls disable when unmapped
- [ ] Visual feedback working
- [ ] Both Ableton instances receiving

Ready for Phase 2:
- [ ] Phase 1 fully tested
- [ ] All issues documented
- [ ] Fader update planned
- [ ] Meter update planned