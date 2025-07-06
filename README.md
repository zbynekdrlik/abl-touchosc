# ABL TouchOSC Control Surface

A professional TouchOSC control surface for Ableton Live with advanced multi-instance routing capabilities and full return track support. Control multiple Ableton Live instances from a single interface with automatic track discovery and professional-grade controls.

## 🎯 Key Features

### Multi-Instance Control
- **Selective Connection Routing**: Route different controls to different Ableton instances
- **Automatic Track Discovery**: Tracks are discovered and mapped automatically on startup
- **Dynamic Group Management**: Track groups auto-unfold based on configuration
- **Complete Isolation**: Each instance operates independently without interference

### Return Track Support (v1.2.0) 🎉
- **Unified Architecture**: Same scripts handle both regular and return tracks
- **Automatic Detection**: Groups automatically detect track type
- **Full Control Suite**: Volume, mute, pan, and metering for return tracks
- **Smart Track Labels**: First word display with return prefix handling
- **Requires**: [Forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC) with return tracks support and listener fixes

### Professional Controls

#### Volume Fader (v2.5.4)
- Professional movement scaling with 0.1dB precision
- Double-tap to jump to 0dB
- Exact dB curve matching Ableton's response
- Emergency movement detection for quick adjustments
- State preservation between sessions
- **Fixed**: Feedback loop prevention when controlled from Ableton

#### Level Meter  
- Precisely calibrated to match Ableton's meters
- Color-coded thresholds:
  - Green: Normal levels
  - Yellow: -12dB warning
  - Red: -3dB peak warning
- Real-time response with connection filtering

#### Mute Button
- Reliable state tracking with feedback prevention
- Visual-only state indication (no text)
- Touch detection for responsive control

#### Pan Control
- Smooth panning with visual feedback
- Double-tap to center
- Color indication of pan position

#### dB Value Display
- Shows current fader position in dB
- Displays "-inf" at minimum
- Shows "-" when track unmapped

## 🚀 Quick Start

### Prerequisites
- TouchOSC (latest version)
- Ableton Live with AbletonOSC installed
  - **Important**: Use the [forked version](https://github.com/zbynekdrlik/AbletonOSC) for return track support and listener fixes
- Network connections configured in TouchOSC

### Installation

1. **Install the forked AbletonOSC** (required for proper operation):
   - Download from: https://github.com/zbynekdrlik/AbletonOSC
   - This fork includes:
     - Return track support
     - Listener cross-wiring fixes (prevents track 5→5,6,7 and track 8→10 issues)
     - Thread-safe listener registration
   - Replace your existing AbletonOSC installation
   - Restart Ableton Live

2. **Download the TouchOSC template** from the releases page

3. **Import into TouchOSC** via the editor

4. **Configure your connections** in the configuration text control:

```yaml
# Connection mapping
connection_band: 2      # Band controls → Ableton instance on connection 2
connection_master: 3    # Master controls → Ableton instance on connection 3

# Auto-unfold groups
unfold_band: 'Band'     # Unfold 'Band' group in band instance
unfold_master: 'Master' # Unfold 'Master' group in master instance
```

5. **Run the template** - tracks will be discovered automatically after 1 second!

## 📖 User Guide

### Control Layout

Each track group contains:
- **Track Label**: Shows track name (first word, smart prefix handling)
- **Status Indicator**: Green when mapped, red when unmapped
- **Volume Fader**: Professional fader with dB scaling
- **dB Display**: Current volume in dB
- **Level Meter**: Real-time level display with peak colors
- **Mute Button**: Toggle track mute
- **Pan Control**: Stereo positioning

### Return Track Setup

Return tracks use the exact same scripts and controls as regular tracks:

1. **Name your group** with the exact return track name:
   - Group name: `master_A-Reverb` (for return track "A-Reverb")
   - Group name: `band_B-Delay` (for return track "B-Delay")

2. **The scripts automatically detect** whether it's a regular or return track

3. **Track labels** intelligently display the first word:
   - "A-Reverb" → shows "Reverb" (skips the A- prefix)
   - "B-Delay" → shows "Delay"
   - "Drums" → shows "Drums" (regular tracks unchanged)

### Automatic Features

- **Startup Refresh**: Tracks are discovered automatically 1 second after opening
- **Track Type Detection**: Scripts automatically detect regular vs return tracks
- **Connection Routing**: Controls automatically route to configured connections
- **State Preservation**: Control positions are maintained between sessions
- **Visual Feedback**: All controls provide immediate visual feedback
- **Feedback Loop Prevention**: Faders won't echo back when controlled from Ableton

### Manual Controls

- **Refresh Button**: Manually trigger track discovery at any time
- **Logger**: View system messages and track assignments

## 🔧 Configuration

### Basic Configuration

The configuration text control accepts these parameters:

| Parameter | Description | Example |
|-----------|-------------|---------||
| connection_[instance] | Map instance to connection number | `connection_band: 2` |
| unfold_[instance] | Auto-unfold group name for instance | `unfold_band: 'Band'` |
| unfold | Legacy: unfold on all connections | `unfold: 'Drums'` |

### Multi-Instance Example

```yaml
# Two separate connections
connection_band: 2      # Band mix Ableton
connection_master: 3    # Master mix Ableton

# Different unfold groups per instance  
unfold_band: 'Band'
unfold_master: 'Master'
```

Both regular tracks and return tracks use the same connection for each instance.

## 📚 Technical Documentation

### Architecture Overview

The system uses a unified script architecture:
- **Document Script**: Central configuration and logging
- **Group Scripts**: Track discovery with auto-detection
- **Control Scripts**: Same scripts handle both track types
- **Tag Communication**: Parent groups pass info via tags
- **Complete Isolation**: No shared variables between scripts

### Script Versions

| Script | Current Version | Purpose |
|--------|----------------|---------||
| document_script.lua | 2.8.7 | Configuration, group registry, auto-refresh |
| group_init.lua | 1.16.2 | Track group with auto-detection and registration |
| fader_script.lua | 2.5.4 | Volume control with feedback loop prevention |
| meter_script.lua | 2.5.2 | Level metering with multi-connection support |
| mute_button.lua | 2.0.1 | Mute control unified |
| pan_control.lua | 1.5.1 | Pan control unified |
| db_label.lua | 1.3.2 | dB display with multi-connection support |
| db_meter_label.lua | 2.6.2 | Peak meter with multi-connection support |
| global_refresh_button.lua | 1.5.1 | Manual refresh trigger |

### Recent Fixes

#### Feedback Loop Prevention (v2.5.4)
- **Issue**: Moving faders in Ableton caused jumpy/laggy behavior
- **Cause**: TouchOSC was echoing received values back to Ableton
- **Fix**: Added `updating_from_osc` flag to prevent sending OSC when updating from received values

#### AbletonOSC Listener Cross-Wiring
- **Issue**: Track 5 updating tracks 5,6,7 and Track 8 responding as Track 10
- **Cause**: Bug in AbletonOSC's listener registration system
- **Fix**: Fork includes thread-safe listener registration and proper track index validation
- **PR**: https://github.com/zbynekdrlik/AbletonOSC/pull/3

### Unified Architecture Details

Groups communicate track information through tags:
```lua
-- Tag format: "instance:trackNumber:trackType"
self.tag = "master:0:return"  -- Return track 0 on master
self.tag = "band:5:track"     -- Regular track 5 on band
```

Child scripts parse the parent tag to determine:
- Which track number to control
- Whether to use `/live/track/` or `/live/return/` OSC paths
- Which connection to use for routing

### Return Track OSC Messages

The forked AbletonOSC adds these endpoints:

**Query Messages:**
- `/live/song/get/num_return_tracks` - Get return track count
- `/live/song/get/return_track_names` - Get return track names
- `/live/song/get/return_track_data` - Get detailed return data

**Control Messages:**
- `/live/return/get/[property] [index]` - Get return track property
- `/live/return/set/[property] [index] [value]` - Set return track property
- `/live/return/start_listen/[property] [index]` - Start property listener
- `/live/return/stop_listen/[property] [index]` - Stop property listener

### Key Technical Features

- **Auto-Detection**: Groups query both track types and map appropriately
- **Unified Scripts**: No code duplication between track types
- **Smart Labels**: Intelligent handling of return track prefixes
- **Frame-based Timing**: Reliable startup refresh using frame counting
- **Direct Configuration Reading**: Each script reads config independently
- **Connection Filtering**: OSC messages filtered by connection
- **State Machine Design**: Robust state tracking for all controls
- **Group Registration**: Groups self-register with document script for reliable refresh
- **Feedback Prevention**: Controls won't echo back when updated from Ableton

## 🔧 Troubleshooting

### Common Issues

**Faders jumpy when controlled from Ableton:**
- Update to fader_script.lua v2.5.4 or later
- This version includes feedback loop prevention

**Wrong tracks responding (e.g., Track 8 moves Track 10):**
- Install the [forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC)
- This is a bug in the original AbletonOSC's listener system
- The fork includes proper thread-safe listener registration

**Return tracks not working:**
- Install the [forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC)
- Check return track names match exactly (including "A-", "B-" prefixes)
- Look for "Mapped to Return Track X" in logs

**Controls not responding:**
- Check connection numbers in configuration
- Verify AbletonOSC is running in Ableton
- Press refresh button to re-discover tracks

**Track label shows wrong text:**
- Update to group_init.lua v1.16.2 or later
- Script now handles return prefixes intelligently

### Debug Mode

Enable detailed logging by modifying script DEBUG constants:
```lua
local DEBUG = 1  -- Set to 1 for verbose logging
```

## 🤝 Contributing

We welcome contributions! Please:
- Create feature branches for all changes
- Update documentation with code changes
- Include version updates in scripts
- Test thoroughly with logging enabled

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed guidelines.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for professional audio workflows
- Inspired by the need for sophisticated multi-instance control
- Return track support added to fill a gap in AbletonOSC
- Thanks to the TouchOSC and AbletonOSC communities

---

**Current Status**: v1.3.1 - Production ready with feedback loop prevention and AbletonOSC listener fixes. All controls tested and working perfectly for both regular and return tracks.

For development documentation and future plans, see the [docs](docs/) directory.