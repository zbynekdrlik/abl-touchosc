# Technical Documentation

This document provides detailed technical information about the ABL TouchOSC control surface implementation.

## System Architecture

### Overview
The ABL TouchOSC system uses a distributed script architecture where each control operates independently while sharing a common configuration and logging system.

```
TouchOSC Runtime
├── Document Script (Central Management)
│   ├── Configuration Parser
│   ├── Logger System
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
**Version:** 2.7.1  
**Purpose:** Central configuration management, logging, and automatic refresh

**Key Features:**
- Parses configuration from text control
- Provides centralized logging via notify system
- Implements automatic startup refresh (1 second delay)
- Frame-based timing for reliability

**Configuration Format:**
```yaml
connection_band: 2
connection_master: 3
unfold_band: 'Band'
unfold_master: 'Master'
```

### Group Script (`group_init.lua`)
**Version:** 1.9.6  
**Purpose:** Track discovery and control management

**Key Features:**
- Discovers tracks via AbletonOSC
- Maps tracks to control groups
- Manages control enable/disable states
- Preserves visual design (no color/style changes)

**Tag Format:** `instance:trackNumber` (e.g., "band:39")

### Control Scripts

#### Fader Script (`fader_script.lua`)
**Version:** 2.3.5  
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
**Version:** 2.2.2  
**Features:**
- Calibrated response matching Ableton
- Color thresholds at -12dB and -3dB
- Connection-specific filtering
- Smooth visual transitions

**Calibration Points:**
```lua
{-60, 0}, {-50, 0.0168}, {-40, 0.075}, {-30, 0.18}, 
{-20, 0.345}, {-12, 0.486}, {-6, 0.625}, {-3, 0.71},
{0, 0.82}, {3, 0.9}, {6, 1.0}
```

#### Mute Button Script (`mute_button.lua`)
**Version:** 1.8.0  
**Features:**
- State tracking with feedback prevention
- Visual-only indication (buttons have no text property)
- Touch detection for immediate response

#### Pan Control Script (`pan_control.lua`)
**Version:** 1.3.2  
**Features:**
- Double-tap to center (0.5)
- Color feedback for position
- Simple, efficient implementation

#### dB Label Script (`db_label.lua`)
**Version:** 1.0.1  
**Features:**
- Real-time dB value display
- Shows "-inf" for minimum values
- Shows "-" when track unmapped

## Communication Architecture

### OSC Message Flow
```
Ableton Live → AbletonOSC → Network → TouchOSC Connection → Script Filter → Control Update
```

### Connection Routing
Each script independently:
1. Reads parent tag to get instance:track
2. Looks up connection index from configuration
3. Filters incoming OSC by connection
4. Sends OSC only to configured connection

**Example:**
```lua
local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
local connectionIndex = getConnectionIndex(instance)
sendOSC(path, trackNum, value, buildConnectionTable(connectionIndex))
```

### Script Communication
Scripts communicate via TouchOSC's notify system:
- `log_message`: Centralized logging
- `track_changed`: Track mapping updates
- `track_unmapped`: Control disabled
- `control_enabled`: Show/hide controls

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

### Log Levels
Currently uses simple logging, planned debug levels:
- Production: User actions only
- Debug: Detailed technical information

### Log Format
```
HH:MM:SS CONTEXT: Message
```

Example:
```
06:16:48 FADER(band_CG #): Script v2.3.5 loaded
06:16:49 CONTROL(band_CG #) Mapped to Track 39
```

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
3. Implement connection routing
4. Add logging with context
5. Test with multiple connections
6. Document OSC patterns

### Debugging
1. Set `DEBUG = 1` in scripts
2. Check logger output in TouchOSC
3. Use console for detailed logs
4. Verify version numbers in logs
5. Test connection isolation

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

**Set Track Parameters:**
- `/live/track/set/volume` - Set volume
- `/live/track/set/panning` - Set pan
- `/live/track/set/mute` - Toggle mute

**Track Discovery:**
- `/live/song/get/num_tracks` - Get track count
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
- Debug level system
- Performance profiling
- Memory optimization
- Extended OSC support

---

For development guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md)  
For project overview, see [README.md](../README.md)