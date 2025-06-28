# ABL TouchOSC - Multi-Instance Ableton Control System

## Overview
A sophisticated TouchOSC template system that enables control of multiple Ableton Live instances simultaneously, with automatic connection routing based on track groups. Controls can target different Ableton instances (e.g., "band" vs "master") automatically.

## Current Status: Phase 3 - Control Testing 🚧

### ✅ What's Working
- **Configuration System** - Text-based configuration for connection mapping
- **Centralized Logging** - Visual logger with 60-line buffer
- **Group Routing** - Automatic connection selection based on group names
- **Track Discovery** - Automatic track mapping with exact name matching
- **Global Refresh** - Single button to refresh all track mappings
- **Safety Features** - Controls auto-disable when tracks not found
- **Fader Control** - Fully working with advanced features (v2.3.3)

### 🚧 In Testing
- Meter display
- Mute buttons
- Pan controls
- Multi-instance isolation

## Key Features

### 1. Automatic Connection Routing
Groups named with prefixes automatically route to specific Ableton instances:
- `band_*` → Band Ableton instance
- `master_*` → Master Ableton instance

### 2. Advanced Fader Features
The fader control includes sophisticated functionality:
- Movement smoothing with gradual scaling
- Immediate 0.1dB minimum response
- Emergency movement detection
- Double-tap to jump to 0dB
- Logarithmic curve (-6dB at 50% position)
- Sync with 1-second delay after release

### 3. Script Architecture
- **Complete Isolation** - Each script is self-contained
- **Notify System** - Inter-script communication via notifications
- **Centralized Logging** - All scripts log through document script
- **Configuration Reading** - Each script reads config independently

## Quick Start Guide

### 1. Configuration Setup
Create a text object named `configuration`:
```
# TouchOSC Connection Configuration
connection_band: 2
connection_master: 3

# Optional: Auto-unfold groups in Ableton
unfold_band: "Drums"
unfold_master: "Vocals"
```

### 2. Core Components
1. **Document Script** - Attach `document_script.lua` (v2.5.9) to root
2. **Logger** - Create text object named `logger` for debug output
3. **Refresh Button** - Add button with `global_refresh_button.lua`

### 3. Track Group Setup
For each track you want to control:
1. Create a group named `band_TrackName` or `master_TrackName`
2. Add LED named `status_indicator` inside
3. Set OSC Receive: `/live/song/get/track_names`
4. Enable ALL connections (1-10)
5. Attach `group_init.lua` (v1.7.0)

### 4. Add Controls
Inside each track group, add:
- **Fader** - Volume control with `fader_script.lua` (v2.3.3)
- **Meter** - Level display with `meter_script.lua` (v2.1.0)
- **Mute** - Mute button with `mute_button.lua` (v1.1.0)
- **Pan** - Pan knob with `pan_control.lua` (v1.1.0)

### 5. Usage
1. Press the global refresh button
2. Green LED = Track found and mapped
3. Red LED = Track not found (controls disabled)

## Script Versions

| Script | Version | Status | Purpose |
|--------|---------|---------|----------|
| document_script.lua | 2.5.9 | ✅ Stable | Configuration & logging |
| group_init.lua | 1.7.0 | ✅ Stable | Track mapping & routing |
| global_refresh_button.lua | 1.4.0 | ✅ Stable | Refresh all groups |
| fader_script.lua | 2.3.3 | ✅ Stable | Volume control |
| meter_script.lua | 2.1.0 | 🚧 Testing | Level display |
| mute_button.lua | 1.1.0 | 🚧 Testing | Mute toggle |
| pan_control.lua | 1.1.0 | 🚧 Testing | Pan adjustment |

## Documentation

### Essential Reading
- [TouchOSC Lua Rules](rules/touchosc-lua-rules.md) - Critical rules and patterns
- [Script Template](docs/touchosc-script-template.md) - Template for new controls
- [Phase 3 Testing](docs/phase-3-script-testing.md) - Current testing procedures

### Guides
- [Phase 1&2 Implementation](docs/01-selective-connection-routing-phase.md)
- [Production Migration](docs/production-migration-guide.md)
- [Verification Checklist](docs/verification-checklist.md)

## Technical Architecture

### Script Isolation
TouchOSC scripts are completely isolated:
- No shared variables or functions
- Each script must be self-contained
- Communication only via `notify()` system
- Configuration read independently by each script

### Connection Routing
```lua
-- Each control determines its target connection
local connectionIndex = getConnectionIndex()  -- Reads config
local connections = buildConnectionTable(connectionIndex)
sendOSC('/live/track/set/volume', track, value, connections)
```

### Tag Format
Groups use `instance:track` format for internal tracking:
- Example: `band:39` means band instance, track 39
- Scripts parse this to extract track number and instance

## Known Issues & Solutions

### Issue: Scripts Can't Share Functions
**Solution**: Each script reads configuration directly
```lua
local configObj = root:findByName("configuration", true)
```

### Issue: OSC Parameter Order
**Solution**: Use explicit parameters instead of varargs
```lua
sendOSC(path, param1, param2, connections)  -- ✅ Good
sendOSC(path, ..., connections)             -- ❌ Bad
```

### Issue: Logger Verbosity
**Solution**: Use debug mode for detailed logs
```lua
local DEBUG = 0  -- Set to 1 for verbose logging
```

## Requirements

- TouchOSC 1.2.0+
- AbletonOSC installed on each Ableton instance
- Unique OSC ports for each connection
- Exact track names matching between TouchOSC and Ableton

## Troubleshooting

1. **Check the logger** - Most issues are logged
2. **Verify track names** - Must match exactly (including spaces/symbols)
3. **Check configuration** - Ensure connection numbers are correct
4. **Enable debug mode** - Set DEBUG = 1 in scripts for detailed logs
5. **Test single track** - Start with one `band_*` group before scaling

## Contributing

When adding new controls:
1. Use the [script template](docs/touchosc-script-template.md)
2. Follow [TouchOSC rules](rules/touchosc-lua-rules.md)
3. Test with both instances
4. Update documentation
5. Increment version numbers

## Support

- Check `/docs` folder for detailed guides
- Review `/rules` for TouchOSC-specific patterns
- See `THREAD_PROGRESS.md` for latest updates