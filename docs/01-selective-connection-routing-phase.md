# TouchOSC Selective Connection Routing - Phase Document (Updated)

## Problem Statement
Currently, all TouchOSC objects broadcast to all configured connections. We need to route specific faders to different Ableton instances:
- Some faders → Ableton "band" instance
- Other faders → Ableton "master" instance

Each Ableton instance runs AbletonOSC on different ports/IPs.

## Current Implementation Status

### ✅ Phase 0: Preparation and Testing Setup - **COMPLETE**
- Helper script v1.0.9 with configuration parsing
- Visual logger functionality
- Connection routing helpers
- Global functions available to all scripts

### ✅ Phase 1: Single Group Test - **COMPLETE & IMPROVED**
- Group initialization script v1.5.1
- Global refresh system implemented
- Safety features: controls disabled when not mapped
- Exact track name matching for safety
- Visual status indicators

### 🚧 Phase 2-7: Pending
- Ready to proceed with full implementation

## Key Learnings & Solutions Implemented

### 1. Script Isolation
- **Issue**: Scripts run in complete isolation, cannot share variables
- **Solution**: Use control properties and notify() for communication

### 2. OSC Routing
- **Issue**: Cannot set OSC receive patterns programmatically
- **Solution**: Must configure in TouchOSC editor UI
- **Implementation**: Groups need `/live/song/get/track_names` pattern

### 3. Color Management
- **Issue**: Direct color table assignment fails
- **Solution**: Must use `Color()` constructor with RGBA values

### 4. Connection Routing
- **Issue**: sendOSC needs proper connection table syntax
- **Solution**: `sendOSC(path, arg, connections)` or `sendOSC(path, connections)`

### 5. Safety & Track Matching
- **Issue**: Fuzzy matching could control wrong tracks
- **Solution**: Exact name matching only, disable controls when unmapped

### 6. Global Refresh
- **Issue**: Individual refresh buttons are poor UX
- **Solution**: Single global refresh button for all groups

## Current Architecture

### System Components
```
Root/Project Page
├── Scripts
│   └── helper_script.lua (v1.0.9)
│
├── Configuration & Monitoring
│   ├── configuration (text object)
│   ├── logger (text object) [optional]
│   └── global_status (text label) [optional]
│
├── Global Controls
│   └── global_refresh_button (with global_refresh_button.lua)
│
└── Track Groups
    ├── band_Hand1 # (with group_init.lua v1.5.1)
    │   ├── status_indicator (LED)
    │   ├── fdr_label [optional]
    │   ├── fader
    │   ├── meter
    │   └── mute button
    ├── master_Vox1 #
    └── ...
```

### Configuration Format
```
# TouchOSC Connection Configuration
connection_band: 1
connection_master: 2
# Future: connection_drums: 3
```

### Script Versions
- **helper_script.lua**: v1.0.9 - Global functions and configuration
- **group_init.lua**: v1.5.1 - Group initialization with safety
- **global_refresh_button.lua**: v1.1.0 - Single refresh for all
- **fader_script.lua**: Existing (to be updated in Phase 2)
- **meter_script.lua**: Existing (to be updated in Phase 2)

## Implementation Guide

### Setting Up From Scratch

#### 1. TouchOSC Configuration
```
Connection 1: Band Ableton
- Host: [Band IP]
- Send Port: [Band Port]
- Receive Port: [Local Port 1]

Connection 2: Master Ableton  
- Host: [Master IP]
- Send Port: [Master Port]
- Receive Port: [Local Port 2]
```

#### 2. Create Configuration Objects
1. **Text object "configuration"**:
   - Font size: ~12-14pt
   - Content:
   ```
   connection_band: 1
   connection_master: 2
   ```

2. **Text object "logger"** (optional but recommended):
   - Height: ~300px (20 lines)
   - Font: Monospace
   - Read-only

3. **Text label "global_status"** (optional):
   - For refresh feedback

#### 3. Add Scripts to Root
1. Select document root
2. Add script: `helper_script.lua`
3. Verify loads with "Helper Script v1.0.9 loaded"

#### 4. Create Global Refresh Button
1. Add button control
2. Name it descriptively (e.g., "REFRESH ALL")
3. Add script: `global_refresh_button.lua`
4. Position prominently

#### 5. Prepare Track Groups
For each group to migrate:

1. **Rename with prefix**:
   - "Hand1 #" → "band_Hand1 #"
   - "Vox1 #" → "master_Vox1 #"

2. **Add status indicator**:
   - Add small LED or label
   - Name it exactly "status_indicator"

3. **Configure OSC receive**:
   - Select group in editor
   - OSC tab → Receive
   - Pattern: `/live/song/get/track_names`
   - Enable appropriate connection(s)

4. **Add group script**:
   - Replace existing script with `group_init.lua`

5. **Optional label**:
   - Name child label "fdr_label" for track name display

### Testing Procedure

#### Initial Test
1. Enter control surface mode
2. Check logger shows all scripts loaded with versions
3. Press global refresh button
4. Verify:
   - Status indicators turn green (found) or red (not found)
   - Controls are enabled (green) or disabled (red)
   - Logger shows track mapping

#### Track Reorder Test
1. Reorder tracks in Ableton
2. Note controls may operate wrong tracks
3. Press global refresh
4. Verify correct control restored

#### Safety Test
1. Rename track in Ableton to non-matching name
2. Press global refresh
3. Verify:
   - Status indicator turns red
   - Controls are disabled (dimmed)
   - Cannot operate fader

## Phase Completion Guide

### ✅ Phase 0 & 1: Complete
- Configuration system working
- Single group tested successfully
- Global refresh implemented
- Safety features verified

### 📋 Phase 2: Single Control Migration
**Goal**: Update fader script for connection awareness

1. Update `fader_script.lua`:
```lua
-- Add connection-aware sending
function onValueChanged(key)
    if key == "x" and self.values.touch then
        local parent = self.parent
        if not parent or not parent.trackNumber then
            return  -- Safety: parent not mapped
        end
        
        -- Get connection from parent
        local connIndex = parent.connectionIndex or 1
        local connections = {}
        for i = 1, 10 do
            connections[i] = (i == connIndex)
        end
        
        -- Send to specific connection
        sendOSC("/live/track/set/volume", 
                parent.trackNumber, self.values.x, connections)
    end
end
```

### 📋 Phase 3: Bidirectional Communication
**Goal**: Add receiving with connection filtering

### 📋 Phase 4: Full Control Set
**Goal**: Update all control scripts (meter, mute, pan, etc.)

### 📋 Phase 5: Production Testing
**Goal**: Test with real performance scenarios

### 📋 Phase 6: Documentation & Training
**Goal**: Create user guide and troubleshooting

### 📋 Phase 7: Full Deployment
**Goal**: Deploy to all TouchOSC devices

## Troubleshooting Guide

### Controls Not Responding
1. Check status indicator color:
   - Red = Track not found
   - Gray = Not initialized
   - Green = Should work
2. Press global refresh
3. Check logger for errors
4. Verify track names match exactly

### OSC Not Received
1. Check group OSC receive pattern
2. Verify connection settings
3. Use OSC monitor in TouchOSC
4. Check Ableton is sending

### Wrong Track Control
1. Track order changed - press refresh
2. Check exact name matching
3. Verify configuration

### Performance Issues
1. Reduce logger text size
2. Disable unused connections
3. Increase refresh interval

## Best Practices

### Naming Conventions
- Groups: `instance_TrackName`
- Status indicators: `status_indicator`
- Labels: `fdr_label`
- Configuration: Lowercase with underscores

### Visual Feedback
- Green: Connected and working
- Yellow: Refreshing/Processing
- Red: Error/Not found
- Orange: Stale data
- Gray: Disabled/Unmapped

### Safety First
- Always disable controls when unmapped
- Use exact name matching
- Clear old values on refresh
- Validate all references

### User Experience
- One global refresh button
- Clear status indicators
- Informative error messages
- Responsive feedback

## Technical Reference

### Key Functions
```lua
-- Build connection table
buildConnectionTable(connectionIndex)

-- Get connection for instance
getConnectionIndex(instance)

-- Parse group name
parseGroupName(name) -- returns instance, trackName

-- Global refresh
refreshAllGroups()

-- Logging
log(...)  -- Visual + console logging
```

### Control Properties Set by Scripts
- `self.tag = "trackGroup"` - Identifies groups
- `self.tag = "band:5"` - Stores instance:trackNumber
- `control.interactive = false` - Disables control

### Required UI Configuration
- OSC receive patterns (cannot set via script)
- Child control names (status_indicator, fdr_label)
- Connection settings in TouchOSC

## Version History
- **v1.0.0-1.0.5**: Helper script development
- **v1.0.6-1.0.9**: Helper script improvements
- **v1.1.0-1.1.2**: Initial group script
- **v1.2.0-1.4.6**: Group script connection handling
- **v1.5.0-1.5.1**: Global refresh and safety features
- **v1.1.0**: Global refresh button

## Next Steps
1. Test current implementation thoroughly
2. Document any new issues in touchosc-lua-rules.md
3. Proceed with Phase 2 control migration
4. Create user documentation
5. Plan production deployment

## Success Metrics
- ✅ Groups map to correct tracks
- ✅ Refresh recovers from reordering
- ✅ Visual feedback is clear
- ✅ Controls disabled when unsafe
- ✅ Single button refresh
- ✅ Performance is acceptable
- 📋 All controls migrated
- 📋 Production tested
- 📋 Users trained
