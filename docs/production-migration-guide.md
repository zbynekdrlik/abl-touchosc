# Production Migration Guide

## Step-by-Step Migration for Large TouchOSC Projects

This guide helps you migrate an existing production TouchOSC project with 20+ controls to the new selective connection routing system.

### Prerequisites
- Backup your current TouchOSC file!
- Have both TouchOSC Editor and control surface ready
- Know which tracks should go to which Ableton instance

## Step 1: Replace Document Script

### 1.1 Remove Old Script
1. Open your TouchOSC project in editor
2. Select the document root (click on empty space)
3. Find the existing script in the Scripts section
4. Delete it completely

### 1.2 Add New Document Script
1. With document root still selected
2. Add new script
3. Copy entire content from `scripts/document_script.lua`
4. Save

### 1.3 Verify Functionality Preserved
The new script (v2.0.0) includes:
- ✅ All your existing init() commands
- ✅ Track name requests
- ✅ Playback listener
- ✅ Group unfolding (now configurable!)
- ✅ Plus new configuration system

## Step 2: Create Configuration Objects

### 2.1 Configuration Text Object
1. Add Text object to document root
2. Name exactly: `configuration`
3. Set content:

```
# TouchOSC Connection Configuration
# Update these based on your setup
connection_band: 1
connection_master: 2

# Groups to unfold automatically
unfold: 'BAND Repro grp#'
unfold: 'Vocals Repro grp#'
unfold: 'OUTPUT MATRIX grp#'
```

**Note**: The unfold feature is now configurable! Add any groups you want unfolded.

### 2.2 Logger Text Object (Recommended for setup)
1. Add Text object to document root
2. Name exactly: `logger`
3. Properties:
   - Height: ~300px
   - Font: Monospace
   - Position: Visible during setup (can hide later)

### 2.3 Test Document Script
1. Switch to control mode
2. Logger should show:
```
Document Script v2.0.0 loaded
Parsing configuration...
  Connection: band -> 1
  Connection: master -> 2
  Unfold group: BAND Repro grp#
  Unfold group: Vocals Repro grp#
  Unfold group: OUTPUT MATRIX grp#
Configuration loaded: 3 unfold groups
Stopping all track listeners...
Requesting track names...
Starting playback listener...
Initialization complete
```

## Step 3: Plan Your Migration

### 3.1 Identify Track Groups
Make a list of which tracks go to which instance:

**Band Instance (connection 1):**
- Kick
- Snare
- HiHat
- Bass
- Guitar
- etc...

**Master Instance (connection 2):**
- VOX 1
- VOX 2
- FX Return
- Master Bus
- etc...

### 3.2 Group Naming Strategy
Current group names need prefixes:
- "Kick #" → "band_Kick #"
- "VOX 1 #" → "master_VOX 1 #"

**IMPORTANT**: The name after prefix must EXACTLY match Ableton track name!

## Step 4: Create Global Refresh Button

### 4.1 Add Button
1. Create new Button control
2. Place at top of interface
3. Name: "REFRESH ALL TRACKS"
4. Color: Make it stand out (yellow/orange)

### 4.2 Add Script
1. Select the button
2. Add script
3. Copy content from `scripts/global_refresh_button.lua`
4. Save

## Step 5: Migrate Groups (One at a Time)

For each track group in your project:

### 5.1 Rename Group
1. Select the group
2. Rename with appropriate prefix:
   - Band tracks: Add "band_" prefix
   - Master tracks: Add "master_" prefix

### 5.2 Add Status Indicator
1. Inside the group, add small LED or label
2. Name exactly: `status_indicator`
3. Position: Top corner
4. This shows mapping status (green/red)

### 5.3 Configure OSC Receive
**CRITICAL - Must be done in editor!**
1. Select the group
2. Go to OSC tab
3. In Receive section:
   - Pattern: `/live/song/get/track_names`
   - Enable checkbox for appropriate connection:
     - Band groups: Enable connection 1
     - Master groups: Enable connection 2

### 5.4 Replace Group Script
1. Select the group
2. Delete any existing script
3. Add new script
4. Copy content from `scripts/group_init.lua`
5. Save

### 5.5 Test This Group
1. Switch to control mode
2. Check logger shows group initialization
3. Press global refresh
4. Verify status indicator turns green (if track exists)

## Step 6: Update Control Scripts

### 6.1 Fader Scripts
1. Find all fader controls
2. For each fader:
   - Select it
   - Replace script with content from `scripts/fader_script.lua`
   - Save

### 6.2 Meter Scripts
1. Find all meter/level controls
2. For each meter:
   - Select it
   - Replace script with content from `scripts/meter_script.lua`
   - Save

### 6.3 Button Scripts (Mute/Solo)
1. Find all mute/solo buttons
2. For each button:
   - Select it
   - Replace script with content from `scripts/mute_button.lua`
   - Save

### 6.4 Pan Controls
1. Find all pan knobs/faders
2. For each pan control:
   - Select it
   - Replace script with content from `scripts/pan_control.lua`
   - Save

## Step 7: Testing Protocol

### 7.1 Initial Test
1. Save your TouchOSC file
2. Load in control mode
3. Check logger for any errors
4. Press global refresh button
5. Verify:
   - Green indicators for found tracks
   - Red indicators for missing tracks
   - Controls only enabled for green tracks

### 7.2 Connection Test
1. Move a fader in a "band_" group
2. Verify it affects Band Ableton instance
3. Move a fader in a "master_" group  
4. Verify it affects Master Ableton instance

### 7.3 Safety Test
1. Rename a track in Ableton
2. Press global refresh
3. Verify that group shows red and controls disable

## Step 8: Performance Optimization

### 8.1 Hide Logger (Optional)
Once everything works:
1. Move logger object off-screen or make tiny
2. It still functions but doesn't take space

### 8.2 Adjust Refresh Strategy
- Don't refresh too often (heavy operation)
- Consider adding individual group refresh buttons for frequently changing areas

## Migration Checklist

### Pre-Migration
- [ ] Backup original TouchOSC file
- [ ] List all tracks and target instances
- [ ] Plan group naming strategy

### Document Setup
- [ ] Replace document script with v2.0.0
- [ ] Create configuration text object
- [ ] Add unfold groups to config
- [ ] Create logger (for testing)
- [ ] Verify init functions work

### Global Controls
- [ ] Create global refresh button
- [ ] Test refresh functionality

### Per-Group Migration
For each group:
- [ ] Rename with instance prefix
- [ ] Add status indicator
- [ ] Configure OSC receive pattern
- [ ] Replace group script
- [ ] Update all control scripts
- [ ] Test group functionality

### Final Testing
- [ ] All groups show correct status
- [ ] Faders route to correct instance
- [ ] Safety features work
- [ ] Performance is acceptable
- [ ] Remove/hide logger if desired

## Troubleshooting

### "No configuration found"
- Check text object is named exactly "configuration"
- Verify it's at document root level

### Groups not refreshing
- Check group has correct prefix (band_ or master_)
- Verify OSC receive pattern is set
- Check `self.tag = "trackGroup"` in group script

### Unfolding not working
- Check track names match exactly in config
- Look for typos or extra spaces
- Verify quotes around group names in config

### Wrong instance receiving
- Check configuration connection numbers
- Verify group prefix matches config
- Check OSC receive checkboxes

## Tips for Large Projects

1. **Migrate in sections**: Do 5-10 groups at a time
2. **Test frequently**: Verify each section works before moving on
3. **Use consistent naming**: Makes troubleshooting easier
4. **Document changes**: Keep notes on what you've migrated
5. **Keep backup handy**: Can always revert if needed

## Next Steps

Once migration is complete:
1. Test with full band setup
2. Run through complete show
3. Note any performance issues
4. Consider creating templates for new tracks
