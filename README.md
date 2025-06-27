# Selective Connection Routing for TouchOSC

## Overview
This feature enables TouchOSC to route different faders to different Ableton Live instances, allowing for complex multi-instance setups where some controls go to a "band" instance and others to a "master" instance.

## Current Status: Phase 1 Complete ✅

### What's Working
- ✅ Configuration system via text object
- ✅ Visual logger for debugging
- ✅ Group-based connection routing
- ✅ Automatic track discovery and mapping
- ✅ Global refresh system
- ✅ Safety features (controls disable when unmapped)
- ✅ Visual status indicators

### Key Scripts
1. **helper_script.lua** (v1.0.9) - Core routing functions
2. **group_init.lua** (v1.5.1) - Group initialization with safety
3. **global_refresh_button.lua** (v1.1.0) - Single refresh button

## Quick Start

### 1. Setup Configuration
Create a text object named "configuration":
```
connection_band: 1
connection_master: 2
```

### 2. Add Helper Script
Add `helper_script.lua` to document root

### 3. Create Global Refresh
Add a button with `global_refresh_button.lua`

### 4. Setup Groups
- Rename groups with prefix: "band_" or "master_"
- Add status indicator LED named "status_indicator"
- Configure OSC receive: `/live/song/get/track_names`
- Add `group_init.lua` script

### 5. Test
- Press global refresh button
- Green = mapped correctly
- Red = track not found (controls disabled)

## Documentation
- [Phase Documentation](docs/01-selective-connection-routing-phase.md) - Complete implementation guide
- [TouchOSC Lua Rules](docs/touchosc-lua-rules.md) - Critical development guidelines
- [Implementation Progress](docs/implementation-progress.md) - Current status

## Key Learnings
1. Scripts run in complete isolation
2. OSC patterns must be set in UI, not code
3. Use Color() constructor for colors
4. Exact track name matching for safety
5. Global refresh is better UX than individual buttons

## Safety Features
- Controls automatically disable when track not found
- Exact name matching prevents wrong track control
- Visual feedback shows connection status
- Old track numbers cleared before remapping

## Next Steps
- Phase 2: Update individual control scripts
- Phase 3: Production testing
- Phase 4: User documentation
- Phase 5: Full deployment

## Support
See [TouchOSC Lua Rules](docs/touchosc-lua-rules.md) for troubleshooting and development guidelines.
