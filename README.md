# Selective Connection Routing for TouchOSC

## Overview
This system enables TouchOSC to route different controls to different Ableton Live instances, allowing complex multi-instance setups where some controls go to a "band" instance and others to a "master" instance.

## Current Status: Phase 3 - Testing ✅

### System Architecture
- **document_script.lua** (v2.5.7) - Main document script handling configuration, logging, and coordination
- **Notify System** - Inter-script communication via notify() calls
- **Recursive Search** - Objects can be placed anywhere (even in pagers)
- **Connection Routing** - Controls route OSC to specific Ableton instances

### What's Working
- ✅ Configuration system via text object (can be placed anywhere)
- ✅ Visual logger for debugging (60-line capacity)
- ✅ Group-based connection routing with safety features
- ✅ Automatic track discovery with exact name matching
- ✅ Global refresh system (single button for all groups)
- ✅ Controls automatically disable when track not found
- ✅ Clear visual status indicators
- ✅ All control scripts now connection-aware (v2.0.0)

### Key Scripts
1. **document_script.lua** (v2.5.7) - Main coordinator script
2. **group_init.lua** (v1.5.1) - Group initialization with safety
3. **global_refresh_button.lua** (v1.1.0) - Single refresh button
4. **Control Scripts** (all v2.0.0) - Fader, meter, mute, pan

## Quick Start

### 1. Setup Configuration
Create a text object named "configuration" (can be anywhere in document):
```
# TouchOSC Connection Configuration
connection_band: 1
connection_master: 2

# Optional: Auto-unfold groups
unfold_band: "Drums"
unfold_master: "Vocals"
```

### 2. Add Document Script
Add `document_script.lua` to document root

### 3. Create Logger (Optional)
Add text object named "logger" for visual debugging (can be in a pager)

### 4. Create Global Refresh
Add a button with `global_refresh_button.lua`

### 5. Setup Groups
- Rename groups with prefix: "band_" or "master_"
- Add status indicator LED named "status_indicator"
- Configure OSC receive: `/live/song/get/track_names`
- Add `group_init.lua` script

### 6. Add Controls
Each control type has connection-aware scripts:
- **fader_script.lua** - Volume control
- **meter_script.lua** - Level display
- **mute_button.lua** - Mute toggle
- **pan_control.lua** - Pan adjustment

### 7. Test
- Press global refresh button
- Green = mapped correctly
- Red = track not found (controls disabled)

## Key Features

### Flexible Object Placement
- Configuration and logger can be anywhere in the document
- Document script uses recursive `findByName()` search
- Objects can be organized in pagers for clean layouts

### Safety Features
- Controls automatically disable when track not found
- Exact name matching prevents wrong track control
- Visual feedback shows connection status
- Track mappings cleared before refresh

### Communication System
- Scripts communicate via notify() system
- No global variables between scripts
- Parent-child property access for data sharing

## Documentation
- [Phase 3 Testing Plan](docs/phase-3-script-testing.md) - Current testing procedures
- [Phase 1&2 Guide](docs/01-selective-connection-routing-phase.md) - Complete implementation
- [TouchOSC Lua Rules](rules/touchosc-lua-rules.md) - Critical development guidelines
- [Implementation Progress](docs/implementation-progress.md) - Status tracking

## Technical Details

### OSC Routing
```lua
-- Connection-specific routing
local connections = createConnectionTable(connectionIndex)
sendOSC('/live/track/set/volume', track, value, connections)
```

### Script Isolation
- Each script runs in its own Lua context
- No shared variables or state
- Communication only via notify() and properties

### Version Requirements
- TouchOSC 1.2.0 or later
- AbletonOSC on both Ableton instances
- Unique receive ports for each connection

## Troubleshooting

### Common Issues
1. **Objects not found** - Check names are exact (case-sensitive)
2. **No track mapping** - Verify exact track names in Ableton
3. **Wrong connection** - Check configuration text
4. **Controls not disabling** - Update to latest script versions

### Debug Steps
1. Check logger for error messages
2. Verify configuration parsed correctly
3. Use test_helper.lua for diagnostics
4. Check OSC monitor in TouchOSC

## Support
See documentation folder for detailed guides and troubleshooting.