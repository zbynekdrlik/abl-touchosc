# ABL TouchOSC Control Surface

A professional TouchOSC control surface for Ableton Live with advanced multi-instance routing capabilities. Control multiple Ableton Live instances from a single interface with automatic track discovery and professional-grade controls.

## 🎯 Key Features

### Multi-Instance Control
- **Selective Connection Routing**: Route different controls to different Ableton instances
- **Automatic Track Discovery**: Tracks are discovered and mapped automatically on startup
- **Dynamic Group Management**: Track groups auto-unfold based on configuration
- **Complete Isolation**: Each instance operates independently without interference

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
- Ableton Live with [AbletonOSC](https://github.com/ideoforms/AbletonOSC) installed
- Network connections configured in TouchOSC

### Installation

1. **Download the TouchOSC template** from the releases page
2. **Import into TouchOSC** via the editor
3. **Configure your connections** in the configuration text control:

```yaml
# Connection mapping
connection_band: 2      # Band controls → Ableton instance on connection 2
connection_master: 3    # Master controls → Ableton instance on connection 3

# Auto-unfold groups
unfold_band: 'Band'     # Unfold 'Band' group in band instance
unfold_master: 'Master' # Unfold 'Master' group in master instance
```

4. **Run the template** - tracks will be discovered automatically after 1 second!

## 📖 User Guide

### Control Layout

Each track group contains:
- **Track Label**: Shows track name or "???" if unmapped
- **Volume Fader**: Professional fader with dB scaling
- **dB Display**: Current volume in dB
- **Level Meter**: Real-time level display
- **Mute Button**: Toggle track mute
- **Pan Control**: Stereo positioning

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

### Advanced Setup

For production use with multiple groups:
1. Duplicate the track group in TouchOSC
2. Rename with your desired identifier
3. Groups will auto-map to available tracks

### Multi-Instance Example

```yaml
# Two separate Ableton instances
connection_band: 2      # Band mix Ableton
connection_master: 3    # Master mix Ableton

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
- **Complete Isolation**: No shared variables between scripts

### Script Versions

| Script | Current Version | Purpose |
|--------|----------------|---------|
| document_script.lua | 2.7.1 | Configuration, logging, auto-refresh |
| group_init.lua | 1.9.6 | Track group management |
| fader_script.lua | 2.3.5 | Volume control with scaling |
| meter_script.lua | 2.2.2 | Level metering with calibration |
| mute_button.lua | 1.8.0 | Mute state management |
| pan_control.lua | 1.3.2 | Pan control with feedback |
| db_label.lua | 1.0.1 | dB value display |
| global_refresh_button.lua | 1.4.0 | Manual refresh trigger |

### Key Technical Features

- **Frame-based Timing**: Reliable startup refresh using frame counting
- **Direct Configuration Reading**: Each script reads config independently
- **Connection Filtering**: OSC messages filtered by connection
- **State Machine Design**: Robust state tracking for all controls
- **Professional dB Scaling**: Exact match to Ableton's fader curve

## 🛠️ Troubleshooting

### Common Issues

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
- Thanks to the TouchOSC and AbletonOSC communities

---

**Current Status**: Production ready with automatic startup refresh and all core controls working perfectly. Ready for scaling to multiple track groups.

For development documentation and future plans, see the [docs](docs/) directory.