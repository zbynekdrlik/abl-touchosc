# Technical Documentation

This document provides detailed technical information about the ABL TouchOSC control surface implementation.

## System Architecture

### Overview
The ABL TouchOSC system uses a distributed script architecture where each control operates independently with its own local logging.

```
TouchOSC Runtime
├── Document Script (Central Management)
│   ├── Configuration Parser
│   ├── Group Registry (Registration System)
│   └── Auto-Refresh Timer
├── Track Groups
│   ├── Group Script (Self-Registration & Track Discovery)
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
**Version:** 2.8.7  
**Purpose:** Central configuration management, group registry, and automatic refresh

**Key Features:**
- Parses configuration from text control
- Maintains registry of track groups (registration system)
- Implements automatic startup refresh (1 second delay)
- Frame-based timing for reliability
- Local debug logging
- 100ms delay between clear and refresh operations

**Group Registration System:**
```lua
-- Groups self-register on initialization
local trackGroups = {}

function onReceiveNotify(action, value)
    if action == "register_track_group" then
        trackGroups[value.name] = value
    end
end
```

**Configuration Format:**
```yaml
connection_band: 2
connection_master: 3
unfold_band: 'Band'
unfold_master: 'Master'
```

### Group Script (`group_init.lua`)
**Version:** 1.16.2  
**Purpose:** Track discovery, control management, and self-registration

**Key Features:**
- Self-registers with document script on init
- Discovers tracks via AbletonOSC (both regular and return tracks)
- Maps tracks to control groups
- Manages control enable/disable states
- Handles clear_mapping and refresh_tracks notifications
- Preserves visual design (no color/style changes)

**Registration on Init:**
```lua
function init()
    -- Register this group with the document script
    root:notify("register_track_group", self)
end
```

**Tag Format:** `instance:trackNumber:trackType` (e.g., "band:39:track", "master:0:return")

### Control Scripts

#### Fader Script (`fader_script.lua`)
**Version:** 2.5.3  
**Features:**
- Professional movement scaling algorithm
- 0.1dB minimum movement detection
- Double-tap to 0dB functionality
- Emergency movement detection
- Exact dB curve matching Ableton
- Handles mapping_cleared notification

**Technical Details:**
- Uses logarithmic curve with exponent 0.515
- Implements reaction time compensation
- Frame-based animation for double-tap
- Cancels animations on mapping clear

#### Meter Script (`meter_script.lua`)
**Version:** 2.4.1  
**Features:**
- Calibrated response matching Ableton
- Color thresholds at -20dB, -6dB, and 0dB
- Connection-specific filtering
- Smooth visual transitions
- Support for both track types

**Calibration Points:**
```lua
{0.000, -60.0},   -- Minimum displayed
{0.600, -24.4},   -- Verified by user
{0.631, -22.0},   -- Verified by user
{0.842, -6.0},    -- Verified by user
{1.000, 0.0},     -- Unity (0 dB)
```

#### Mute Button Script (`mute_button.lua`)
**Version:** 2.0.1  
**Features:**
- State tracking with feedback prevention
- Visual-only indication (buttons have no text property)
- Touch detection for immediate response
- Works with both track types

#### Pan Control Script (`pan_control.lua`)
**Version:** 1.4.1  
**Features:**
- Double-tap to center (0.5)
- Color feedback for position
- Simple, efficient implementation
- Unified for all track types

#### dB Label Script (`db_label.lua`)
**Version:** 1.2.0  
**Features:**
- Real-time dB value display
- Shows "-∞ dBFS" for minimum values
- Shows "-" when track unmapped

#### dB Meter Label Script (`db_meter_label.lua`)
**Version:** 2.5.1  
**Features:**
- Meter level to dBFS conversion
- Calibrated response matching meters
- Shows "-∞ dBFS" for silence

#### Global Refresh Button Script (`global_refresh_button.lua`)
**Version:** 1.5.1  
**Features:**
- Triggers document script refresh
- Visual feedback (yellow during refresh)
- Prevents double-triggers

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
- `register_track_group`: Group registers with document script
- `refresh_all_groups`: Trigger group refresh
- `clear_mapping`: Clear track mappings
- `refresh_tracks`: Re-discover tracks
- `mapping_cleared`: Notify children of cleared mapping
- `track_changed`: Track mapping updates
- `track_unmapped`: Control disabled
- `track_type`: Inform children of track type

## Key Technical Concepts

### Registration System
**New in v2.8.7:** Groups self-register with the document script:
- Avoids issues with TouchOSC's userdata control hierarchy
- Works regardless of tag changes during runtime
- Ensures reliable refresh operations
- No searching required - direct references maintained

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
- Direct group references via registration
- Frame-based timing instead of timers
- Local logging with DEBUG=0 by default

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
local DEBUG = 0  -- Default to off for performance

-- Local logging function
local function log(message)
    if DEBUG == 1 then
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
[06:16:48] FADER(band_CG #): Script v2.5.3 loaded
[06:16:49] GROUP(band_CG #): Registered with document script
[06:16:49] GROUP(band_CG #): Mapped to track 39
```

### Debug Control
- Each script has its own `DEBUG` flag
- Set to 1 to enable logging for that script
- Default is 0 for performance
- Logs appear in TouchOSC console

## Auto-Refresh System

### Implementation
Uses frame counting for reliable timing with two-phase refresh:
```lua
local STARTUP_DELAY_FRAMES = 60  -- 1 second at 60 FPS
local REFRESH_WAIT_TIME = 100    -- 100ms between clear and refresh

function update()
    -- Handle refresh sequence timing
    if refreshState == "waiting" then
        local elapsed = getMillis() - refreshWaitStart
        if elapsed >= REFRESH_WAIT_TIME then
            refreshState = "refreshing"
            completeRefreshSequence()
        end
    end
    
    -- Startup refresh
    if frameCount < STARTUP_DELAY_FRAMES + 10 then
        frameCount = frameCount + 1
        if frameCount == STARTUP_DELAY_FRAMES then
            startRefreshSequence()
        end
    end
end
```

### Refresh Sequence
1. Clear all track mappings
2. Wait 100ms (ensures clean state)
3. Trigger track re-discovery
4. Groups re-map to correct tracks

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
5. Handle parent notifications
6. Test with multiple connections
7. Document OSC patterns

### Debugging
1. Set `DEBUG = 1` in specific scripts
2. Check console output in TouchOSC
3. Verify version numbers in logs
4. Monitor registration messages
5. Test connection isolation
6. Verify refresh sequence

### Common Pitfalls
- Forgetting buttons don't have text property
- Assuming shared variables work
- Modifying visual properties in scripts
- Not handling mapping_cleared notification
- Missing connection filtering
- Not registering groups with document script

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
- `/live/song/get/track_names` - Get track names
- `/live/song/get/return_track_names` - Get return names
- `/live/song/get/num_tracks` - Get track count
- `/live/song/get/num_return_tracks` - Get return count

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
