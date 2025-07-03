# ABL TouchOSC Control Surface

A professional TouchOSC control surface for Ableton Live with advanced multi-instance routing capabilities and full return track support. Control multiple Ableton Live instances from a single interface with automatic track discovery and professional-grade controls.

## 🎯 Key Features

### Multi-Instance Control
- **Selective Connection Routing**: Route different controls to different Ableton instances
- **Automatic Track Discovery**: Tracks are discovered and mapped automatically on startup
- **Dynamic Group Management**: Track groups auto-unfold based on configuration
- **Complete Isolation**: Each instance operates independently without interference

### Return Track Support (NEW!)
- **Full Return Track Control**: Complete support for Ableton Live return tracks
- **All Controls Available**: Volume, mute, pan, and metering for return tracks
- **Automatic Discovery**: Return tracks are mapped by name just like regular tracks
- **Requires**: [Forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support) with return track support

### Professional Controls

#### Volume Fader
- Professional movement scaling with 0.1dB precision
- Double-tap to jump to 0dB
- Exact dB curve matching Ableton's response
- Emergency movement detection for quick adjustments
- State preservation between sessions

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
  - For return track support: Use the [forked version](https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support)
- Network connections configured in TouchOSC

### Installation

1. **For Return Track Support** (optional):
   - Download the [forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support)
   - Replace your existing AbletonOSC installation
   - Restart Ableton Live

2. **Download the TouchOSC template** from the releases page

3. **Import into TouchOSC** via the editor

4. **Configure your connections** in the configuration text control:

```yaml
# Connection mapping
connection_band: 2      # Band controls → Ableton instance on connection 2
connection_master: 3    # Master controls → Ableton instance on connection 3
connection_return: 1    # Return tracks → Ableton instance on connection 1

# Auto-unfold groups
unfold_band: 'Band'     # Unfold 'Band' group in band instance
unfold_master: 'Master' # Unfold 'Master' group in master instance
```

5. **Run the template** - tracks will be discovered automatically after 1 second!

## 📖 User Guide

### Control Layout

Each track group contains:
- **Track Label**: Shows track name or "???" if unmapped
- **Volume Fader**: Professional fader with dB scaling
- **dB Display**: Current volume in dB
- **Level Meter**: Real-time level display
- **Mute Button**: Toggle track mute
- **Pan Control**: Stereo positioning

### Return Track Controls

Return track groups work identically to regular track groups but:
- Use `return_` prefix in group names (e.g., `return_A-Reverb`)
- Map to Ableton's return tracks by exact name matching
- Support all the same controls as regular tracks
- Use the `/live/return/` OSC namespace

### Automatic Features

- **Startup Refresh**: Tracks are discovered automatically 1 second after opening
- **Connection Routing**: Controls automatically route to configured connections
- **State Preservation**: Control positions are maintained between sessions
- **Visual Feedback**: All controls provide immediate visual feedback

### Manual Controls

- **Refresh Button**: Manually trigger track discovery at any time
- **Logger**: View system messages and track assignments

## 🔧 Configuration

### Basic Configuration

The configuration text control accepts these parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
| connection_[instance] | Map instance to connection number | `connection_band: 2` |
| unfold_[instance] | Auto-unfold group name for instance | `unfold_band: 'Band'` |
| unfold | Legacy: unfold on all connections | `unfold: 'Drums'` |

### Return Track Setup

1. Create a group with name `return_YourReturnTrackName`
2. Add the return track scripts to controls:
   - Group: `scripts/return/group_init.lua`
   - Fader: `scripts/return/fader_script.lua`
   - Mute: `scripts/return/mute_button.lua`
   - Pan: `scripts/return/pan_control.lua`
3. Configure connection: `connection_return: 1`

### Multi-Instance Example

```yaml
# Three separate connections
connection_band: 2      # Band mix Ableton
connection_master: 3    # Master mix Ableton
connection_return: 1    # Main Ableton with returns

# Different unfold groups per instance  
unfold_band: 'Band'
unfold_master: 'Master'
```

## 📚 Technical Documentation

### Architecture Overview

The system uses a distributed script architecture:
- **Document Script**: Central configuration and logging
- **Group Scripts**: Track discovery and mapping
- **Control Scripts**: Individual control behavior
- **Return Scripts**: Specialized scripts for return track control
- **Complete Isolation**: No shared variables between scripts

### Script Versions

| Script | Current Version | Purpose |
|--------|----------------|---------|
| document_script.lua | 2.7.1 | Configuration, logging, auto-refresh |
| group_init.lua | 1.9.6 | Track group management |
| return/group_init.lua | 1.0.0 | Return track group management |
| fader_script.lua | 2.3.5 | Volume control with scaling |
| return/fader_script.lua | 1.0.0 | Return track volume control |
| meter_script.lua | 2.2.2 | Level metering with calibration |
| mute_button.lua | 1.8.0 | Mute state management |
| return/mute_button.lua | 1.0.0 | Return track mute control |
| pan_control.lua | 1.3.2 | Pan control with feedback |
| return/pan_control.lua | 1.0.0 | Return track pan control |
| db_label.lua | 1.0.1 | dB value display |
| global_refresh_button.lua | 1.4.0 | Manual refresh trigger |

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

- **Frame-based Timing**: Reliable startup refresh using frame counting
- **Direct Configuration Reading**: Each script reads config independently
- **Connection Filtering**: OSC messages filtered by connection
- **State Machine Design**: Robust state tracking for all controls
- **Professional dB Scaling**: Exact match to Ableton's fader curve
- **Return Track Support**: Full control over Ableton's return tracks

## 🔧 Troubleshooting

### Common Issues

**Return tracks not working:**
- Install the [forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support)
- Check return track names match exactly
- Verify with: `/live/song/get/num_return_tracks`

**Controls not responding:**
- Check connection numbers in configuration
- Verify AbletonOSC is running in Ableton
- Press refresh button to re-discover tracks

**Wrong tracks mapped:**
- Check unfold group names match Ableton
- Ensure tracks are visible in Ableton
- Try manual refresh

**No automatic refresh:**
- Update to latest script versions
- Check logger for startup messages
- Verify document script is attached

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

**Current Status**: Production ready with automatic startup refresh, all core controls working perfectly, and full return track support. Ready for scaling to multiple track groups including returns.

For development documentation and future plans, see the [docs](docs/) directory.