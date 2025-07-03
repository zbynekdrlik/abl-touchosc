# Return Track Implementation Documentation

## Overview

This document describes the implementation of return track support for AbletonOSC and TouchOSC using a unified architecture where the same scripts handle both regular and return tracks.

## Problem Solved

The original AbletonOSC only exposed regular tracks (`song.tracks`) but completely ignored return tracks (`song.return_tracks`), making it impossible to control Ableton Live's return tracks via OSC.

## Solution Architecture

### 1. AbletonOSC Fork

**Repository**: https://github.com/zbynekdrlik/AbletonOSC  
**Branch**: `feature/return-tracks-support`  
**PR**: https://github.com/zbynekdrlik/AbletonOSC/pull/2

#### Key Fix:
- Added missing listener support for return tracks
- Fixed "Observer not connected" errors
- Return tracks now properly send updates via OSC

### 2. TouchOSC Unified Architecture

**Key Innovation**: Instead of creating separate scripts for return tracks, we extended the existing track scripts to handle both track types automatically.

#### How It Works:

1. **Auto-Detection**: The group script queries both regular and return track names
2. **Tag-Based Communication**: Parent groups store track info in tags: `"instance:trackNumber:trackType"`
3. **Smart Routing**: Child scripts parse the parent tag and automatically use the correct OSC namespace

#### Updated Scripts:

All scripts in `scripts/track/` now support both track types:
- **group_init.lua (v1.14.5)**: Auto-detects track type, smart label display
- **fader_script.lua (v2.4.1)**: Volume control for both types
- **meter_script.lua (v2.3.1)**: Level metering unified
- **mute_button.lua (v1.9.1)**: Mute control unified
- **pan_control.lua (v1.4.1)**: Pan control unified
- **db_label.lua (v1.2.0)**: dB display unified
- **db_meter_label.lua (v2.5.1)**: Peak meter unified

## Implementation Details

### Name-Based Mapping

Return tracks are mapped by exact name matching:
1. TouchOSC group name: `master_A-Reverb`
2. Ableton return track name: `A-Reverb`
3. Group script auto-detects it's a return track

### Auto-Detection Logic

```lua
-- Query both track types
sendOSC('/live/song/get/track_names', connections)
sendOSC('/live/song/get/return_track_names', connections)

-- Map based on where the name is found
if found in track_names then
    trackType = "track"
    self.tag = "master:5:track"
elseif found in return_track_names then
    trackType = "return"
    self.tag = "master:0:return"
end
```

### Child Script Adaptation

```lua
-- Parse parent tag to get track info
local instance, trackNum, trackType = self.parent.tag:match("^(%w+):(%d+):(%w+)$")

-- Use appropriate OSC path
local oscPrefix = trackType == "return" and "/live/return/" or "/live/track/"
sendOSC(oscPrefix .. 'set/volume', trackNumber, value, connections)
```

### Smart Label Display

The track label intelligently handles return track prefixes:
- "A-Reverb" displays as "Reverb"
- "B-Delay" displays as "Delay"  
- Regular tracks display normally

## OSC Message Reference

### Query Messages

```
/live/song/get/num_return_tracks
/live/song/get/return_track_names
/live/return/get/[property] [index]
/live/return/set/[property] [index] [value]
/live/return/start_listen/[property] [index]
/live/return/stop_listen/[property] [index]
```

### Supported Properties

Same as regular tracks:
- volume, mute, panning
- output_meter_level
- name, color
- All other track properties

## Key Advantages

1. **No Code Duplication**: Single set of scripts for both track types
2. **Automatic Detection**: No manual configuration needed
3. **Consistent Interface**: Users work with return tracks exactly like regular tracks
4. **Maintainability**: Updates benefit both track types automatically
5. **Future Proof**: Easy to extend for new track types

## Testing Results

Successfully tested with:
- Ableton Live with return tracks
- All control types working bidirectionally
- Meter data flowing correctly
- Smart label display
- Multi-instance routing

## Known Limitations

1. Requires forked AbletonOSC for listener support
2. Name matching is case-sensitive
3. Return tracks don't support arm/fold operations (Ableton limitation)

## Conclusion

The unified architecture provides a cleaner, more maintainable solution than separate scripts. By teaching the existing scripts to be "track-type aware," we achieved full return track support without code duplication.