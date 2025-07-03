# Return Track Implementation Documentation

## Overview

This document describes the complete implementation of return track support for AbletonOSC and TouchOSC.

## Problem Solved

The original AbletonOSC only exposed regular tracks (`song.tracks`) but completely ignored return tracks (`song.return_tracks`), making it impossible to control Ableton Live's return tracks via OSC.

## Solution Architecture

### 1. AbletonOSC Fork

**Repository**: https://github.com/zbynekdrlik/AbletonOSC  
**Branch**: `feature/return-tracks-support`  
**PR**: https://github.com/zbynekdrlik/AbletonOSC/pull/2

#### Changes Made:

**song.py**:
- Added `/live/song/get/num_return_tracks` - Returns count of return tracks
- Added `/live/song/get/return_track_names` - Returns array of return track names
- Added `/live/song/get/return_track_data` - Returns detailed return track data
- Updated `song_export_structure` to include return tracks

**track.py**:
- Created complete `/live/return/` namespace mirroring `/live/track/` functionality
- Implemented `create_return_track_callback` for return track handling
- Added all property getters/setters for return tracks
- Added mixer controls (volume, panning, sends)
- Added device queries and clip operations
- Added output routing support

### 2. TouchOSC Scripts

**Location**: `scripts/return/`

#### Core Scripts:

**group_init.lua**:
- Main return track group initialization
- Handles mapping return track names to indices
- Manages OSC listeners for all child controls
- Provides visual status indication
- Based on track group_init but uses `/live/return/` namespace

**fader_script.lua**:
- Volume control for return tracks
- Logarithmic curve for proper dB scaling
- Sync delay to prevent jumps
- Sends `/live/return/set/volume`

**mute_button.lua**:
- Mute toggle for return tracks
- Visual state indication
- Sends `/live/return/set/mute`

**pan_control.lua**:
- Panning control (-1 to +1)
- Position conversion for TouchOSC (0-1)
- Sends `/live/return/set/panning`

## OSC Message Reference

### Query Messages

```
/live/song/get/num_return_tracks
Returns: INT32(count)

/live/song/get/return_track_names
Returns: STRING(name1), STRING(name2), ...

/live/song/get/return_track_data [start] [end] [properties...]
Returns: Mixed array of requested properties
```

### Control Messages

```
/live/return/get/[property] [index]
/live/return/set/[property] [index] [value]
/live/return/start_listen/[property] [index]
/live/return/stop_listen/[property] [index]
```

### Supported Properties

**Read/Write**:
- name
- color
- color_index
- mute
- solo
- volume (via mixer_device)
- panning (via mixer_device)

**Read-Only**:
- fired_slot_index
- has_audio_input/output
- has_midi_input/output
- is_visible
- output_meter_level
- output_meter_left/right
- playing_slot_index

## Implementation Details

### Name-Based Mapping

Return tracks are mapped by exact name matching:
1. TouchOSC group name: `return_TrackName`
2. Ableton return track name: `TrackName`
3. Scripts strip the `return_` prefix and match exactly

### Connection Routing

Supports multiple OSC connections:
- Configuration key: `connection_return: [1-10]`
- Each return group can route to different connections
- Maintains isolation between instances

### Status Indication

Visual feedback system:
- **Red**: Not mapped/no matching track
- **Green**: Mapped and idle
- **Blue**: Sending data
- **Yellow**: Receiving data
- Fade transitions between states

## Testing Results

Successfully tested with:
- Ableton Live 11
- Single and multiple return tracks
- All control types (volume, mute, pan)
- Listener updates
- Name-based mapping

## Future Enhancements

1. **Meter visualization** - Add visual meter display
2. **Send controls** - Control sends on return tracks
3. **Device control** - Control devices on return tracks
4. **Dynamic track creation** - Handle track creation/deletion
5. **Upstream contribution** - Submit PR to ideoforms/AbletonOSC

## Known Limitations

1. Return tracks don't support:
   - Arm (not applicable)
   - Fold state (can't be grouped)
   - Input routing (receive-only)

2. Name matching is case-sensitive
3. Requires exact name match (no wildcards)

## Conclusion

This implementation provides complete return track control for TouchOSC, filling a significant gap in the original AbletonOSC. The solution maintains backward compatibility while adding comprehensive new functionality.