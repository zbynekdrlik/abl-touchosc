# Technical Documentation

This document provides detailed technical information about the ABL TouchOSC control surface implementation.

## System Architecture

### Overview
The ABL TouchOSC system uses a distributed script architecture where each control operates independently with its own local logging.

```
TouchOSC Runtime
├── Document Script (Central Management)
│   ├── Configuration Parser
│   └── Auto-Refresh Timer
├── Track Groups
│   ├── Group Script (Track Discovery)
│   └── Controls
│       ├── Fader Script
│       ├── Meter Script
│       ├── Mute Script
│       ├── Pan Script
│       └── dB Label Script
└── Global Controls
    └── Refresh Button Script
```

## Core Components

### Document Script (`document_script.lua`)
**Version:** 2.8.0  
**Purpose:** Central configuration management and automatic refresh

**Key Features:**
- Parses configuration from text control
- Implements automatic startup refresh (1 second delay)
- Frame-based timing for reliability
- Local debug logging

**Configuration Format:**
```yaml
connection_band: 2
connection_master: 3
unfold_band: 'Band'
unfold_master: 'Master'
```

### Group Script (`group_init.lua`)
**Version:** 1.15.0  
**Purpose:** Track discovery and control management

**Key Features:**
- Discovers tracks via AbletonOSC
- Maps tracks to control groups
- Manages control enable/disable states
- Preserves visual design (no color/style changes)

**Tag Format:** `instance:trackNumber:trackType` (e.g., "band:39:regular")

### Control Scripts

#### Fader Script (`fader_script.lua`)
**Version:** 2.5.1  
**Features:**
- Professional movement scaling algorithm
- 0.1dB minimum movement detection
- Double-tap to 0dB functionality
- Emergency movement detection
- Exact dB curve matching Ableton

**Technical Details:**
- Uses logarithmic curve with exponent 0.515
- Implements reaction time compensation
- Frame-based animation for double-tap

#### Meter Script (`meter_script.lua`)
**Version:** 2.4.1  
**Features:**
- Calibrated response matching Ableton
- Color thresholds at -12dB and -3dB
- Connection-specific filtering
- Smooth visual transitions

**Calibration Points:**
```lua
{0.0, 0.0}, {0.3945, 0.027}, {0.6839, 0.169}, 
{0.7629, 0.313}, {0.8399, 0.5}, {0.9200, 0.729}, {1.0, 1.0}
```

#### Mute Button Script (`mute_button.lua`)
**Version:** 2.0.0  
**Features:**
- State tracking with feedback prevention
- Visual-only indication (buttons have no text property)
- Touch detection for immediate response

#### Pan Control Script (`pan_control.lua`)
**Version:** 1.5.0  
**Features:**
- Double-tap to center (0.5)
- Color feedback for position
- Simple, efficient implementation

#### dB Label Script (`db_label.lua`)
**Version:** 1.3.0  
**Features:**
- Real-time dB value display
- Shows "-∞ dBFS" for minimum values
- Shows "-" when track unmapped

#### dB Meter Label Script (`db_meter_label.lua`)
**Version:** 2.6.0  
**Features:**
- Meter level to dBFS conversion
- Calibrated response matching meters
- Shows "-∞ dBFS" for silence

## Communication Architecture

### OSC Message Flow
```
Ableton Live → AbletonOSC → Network → TouchOSC Connection → Script Filter → Control Update
```

### Connection Routing
Each script independently:
1. Reads parent tag to get instance:track:type
2. Looks up connection index from configuration
3. Filters incoming OSC by connection
4. Sends OSC only to configured connection

**Example:**
```lua
local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")
local connectionIndex = getConnectionIndex(instance)
sendOSC(path, trackNum, value, buildConnectionTable(connectionIndex))
```

### Script Communication
Scripts communicate via TouchOSC's notify system:
- `track_changed`: Track mapping updates
- `track_unmapped`: Control disabled
- `control_enabled`: Show/hide controls
- `refresh_all_groups`: Trigger group refresh

## Key Technical Concepts

### Script Isolation
**Critical:** TouchOSC scripts are completely isolated:
- No shared variables between scripts
- No shared functions
- Each script must be self-contained
- Configuration read directly in each script

### State Management
**Principle:** Never change control state based on assumptions:
- Position changes only from user or OSC
- Visual properties never modified by scripts
- State preserved between sessions
- No default position assumptions

### Performance Optimization
- Minimal OSC message processing
- Efficient connection filtering
- Logarithmic calculations cached where possible
- Frame-based timing instead of timers

## Configuration System

### Text Control Parser
Parses key:value pairs with support for:
- Numeric values: `connection_band: 2`
- String values: `unfold_band: 'Band'`
- Comments: Lines starting with #
- Whitespace tolerance

### Configuration Access
Each script reads configuration independently:
```lua
local configObj = root:findByName("configuration", true)
local configText = configObj.values.text
-- Parse configuration...
```

## Logging System

### Local Script Logging
Each script implements its own logging with debug control:
```lua
-- Debug flag - set to 1 to enable logging
local debug = 0  -- Default to off for performance

-- Local logging function
local function log(message)
    if debug == 1 then
        local context = "SCRIPTNAME"
        if self.parent and self.parent.name then
            context = "SCRIPTNAME(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end
```

### Log Format
```
[HH:MM:SS] CONTEXT: Message
```

Example:
```
[06:16:48] FADER(band_CG #): Script v2.5.1 loaded
[06:16:49] GROUP(band_CG #): Mapped to Track 39
```

### Debug Control
- Each script has its own `debug` flag
- Set to 1 to enable logging for that script
- Default is 0 for performance
- Logs appear in TouchOSC console

## Auto-Refresh System

### Implementation
Uses frame counting for reliable timing:
```lua
local STARTUP_DELAY_FRAMES = 60  -- 1 second at 60 FPS

function update()
    if not startupRefreshDone then
        frameCount = frameCount + 1
        if frameCount == STARTUP_DELAY_FRAMES then
            refreshAllGroups()
            startupRefreshDone = true
        end
    end
end
```

### Why Frame-Based?
- More reliable than clock-based timing
- Works consistently across platforms
- Not affected by system load

## Best Practices

### Adding New Controls
1. Copy existing control script as template
2. Update VERSION constant
3. Implement local logging function
4. Implement connection routing
5. Test with multiple connections
6. Document OSC patterns

### Debugging
1. Set `debug = 1` in specific scripts
2. Check console output in TouchOSC
3. Verify version numbers in logs
4. Test connection isolation
5. Monitor performance impact

### Common Pitfalls
- Forgetting buttons don't have text property
- Assuming shared variables work
- Modifying visual properties in scripts
- Not validating property access
- Missing connection filtering

## OSC Reference

### Track Control Messages

**Get Track Info:**
- `/live/track/get/name` - Get track name
- `/live/track/get/volume` - Get volume (0.0-1.0)
- `/live/track/get/panning` - Get pan (-1.0 to 1.0)
- `/live/track/get/mute` - Get mute state
- `/live/track/get/solo` - Get solo state
- `/live/track/get/output_meter_level` - Get meter level

**Set Track Parameters:**
- `/live/track/set/volume` - Set volume
- `/live/track/set/panning` - Set pan
- `/live/track/set/mute` - Toggle mute

**Return Track Messages:**
- `/live/return/get/volume` - Get return volume
- `/live/return/set/volume` - Set return volume
- `/live/return/get/output_meter_level` - Get return meter
- (Similar patterns for other parameters)

**Track Discovery:**
- `/live/song/get/num_tracks` - Get track count
- `/live/song/get/num_return_tracks` - Get return count
- `/live/song/get/track_data` - Get track details

### Message Format
All messages use: `[trackNumber, value]`

Example:
```lua
sendOSC('/live/track/set/volume', 39, 0.85, connections)
```

## Future Enhancements

### Planned Features
- Solo/Record arm controls
- Send level controls (A-D)
- Device parameter mapping
- Scene launching
- Clip control

### Technical Improvements
- Performance profiling
- Memory optimization
- Extended OSC support

---

For development guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md)  
For project overview, see [README.md](../README.md)