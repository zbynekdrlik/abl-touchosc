# ABL TouchOSC Control Surface

A professional TouchOSC control surface for Ableton Live with advanced multi-instance routing capabilities and full return track support. Control multiple Ableton Live instances from a single interface with automatic track discovery and professional-grade controls.

## 🎯 Key Features

### Multi-Instance Control
- **Selective Connection Routing**: Route different controls to different Ableton instances
- **Automatic Track Discovery**: Tracks are discovered and mapped automatically on startup
- **Dynamic Group Management**: Track groups auto-unfold based on configuration
- **Complete Isolation**: Each instance operates independently without interference

### Return Track Support
- **Unified Architecture**: Same scripts handle both regular and return tracks
- **Automatic Detection**: Groups automatically detect track type
- **Full Control Suite**: Volume, mute, pan, and metering for return tracks
- **Smart Track Labels**: First word display with return prefix handling
- **Requires**: [Forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC) with return tracks support and listener fixes

### Professional Controls

#### Volume Fader
- Professional movement scaling with 0.1dB precision
- Double-tap to jump to 0dB
- Exact dB curve matching Ableton's response
- Emergency movement detection for quick adjustments
- State preservation between sessions
- Feedback loop prevention when controlled from Ableton
- **NEW**: Color indicator on dB label (white at 0dB, light green when moved)

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
- Sends proper boolean values to AbletonOSC
- **NEW**: Configurable double-click protection for critical tracks (v2.2.0)

#### Pan Control
- Smooth panning with visual feedback
- Double-tap to center
- Color indication of pan position

#### dB Value Display
- Shows current fader position in dB
- Displays "-inf" at minimum
- Shows "-" when track unmapped
- **NEW**: Color changes to indicate fader position (v1.5.0)

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

2. **Download the TouchOSC template** from the [releases page](https://github.com/zbynekdrlik/abl-touchosc/releases)

3. **Import into TouchOSC** via the editor

4. **Configure your connections** in the configuration text control:

```yaml
# Connection mapping
connection_band: 2      # Band controls → Ableton instance on connection 2
connection_master: 3    # Master controls → Ableton instance on connection 3

# Auto-unfold groups
unfold_band: 'Band'     # Unfold 'Band' group in band instance
unfold_master: 'Master' # Unfold 'Master' group in master instance

# Double-click mute protection (optional)
double_click_mute_band: 'Band Tracks'    # Require double-click for 'Band Tracks' group
double_click_mute_master: 'Master Bus'   # Require double-click for 'Master Bus' group
```

5. **Run the template** - tracks will be discovered automatically after 1 second!

## 📖 User Guide

### Control Layout

Each track group contains:
- **Track Label**: Shows track name (first word, smart prefix handling)
- **Status Indicator**: Green when mapped, red when unmapped
- **Volume Fader**: Professional fader with dB scaling
- **dB Display**: Current volume in dB with color indication
- **Level Meter**: Real-time level display with peak colors
- **Mute Button**: Toggle track mute (with optional double-click protection)
- **Pan Control**: Stereo positioning

### Double-Click Mute Protection (NEW)

For critical tracks where accidental muting could be disastrous (like master bus or live performance tracks), you can enable double-click protection:

1. **Add configuration** for the groups that need protection:
   ```yaml
   # Require double-click for specific groups
   double_click_mute_band: 'Band Tracks'    # Instance-specific
   double_click_mute_master: 'Master Bus'   # Instance-specific
   double_click_mute: 'Critical Group'      # All instances
   ```

2. **Groups with double-click enabled** require two clicks within 500ms to toggle mute

3. **Groups without configuration** maintain single-click behavior (backward compatible)

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
|-----------|-------------|---------|
| connection_[instance] | Map instance to connection number | `connection_band: 2` |
| unfold_[instance] | Auto-unfold group name for instance | `unfold_band: 'Band'` |
| unfold | Legacy: unfold on all connections | `unfold: 'Drums'` |
| double_click_mute_[instance] | Require double-click for group | `double_click_mute_band: 'Band Tracks'` |
| double_click_mute | Require double-click on all instances | `double_click_mute: 'Master Bus'` |

### Multi-Instance Example

```yaml
# Two separate connections
connection_band: 2      # Band mix Ableton
connection_master: 3    # Master mix Ableton

# Different unfold groups per instance  
unfold_band: 'Band'
unfold_master: 'Master'

# Double-click protection for critical tracks
double_click_mute_band: 'Band Tracks'    # Protect band master group
double_click_mute_master: 'Master Bus'   # Protect master bus
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
|--------|-----------------|---------|
| document_script.lua | 2.9.0 | Configuration, group registry, auto-refresh |
| group_init.lua | 1.16.2 | Track group with auto-detection and registration |
| fader_script.lua | 2.5.4 | Volume control with feedback loop prevention |
| meter_script.lua | 2.5.2 | Level metering with multi-connection support |
| mute_button.lua | 2.2.0 | Mute control with double-click support |
| pan_control.lua | 1.5.1 | Pan control unified |
| db_label.lua | 1.5.0 | dB display with color indicator |
| db_meter_label.lua | 2.6.2 | Peak meter with multi-connection support |
| global_refresh_button.lua | 1.5.1 | Manual refresh trigger |

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
- **Double-Click Detection**: Configurable timing-based double-click for critical tracks

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

**Double-click mute not working:**
- Check configuration syntax exactly matches examples
- Group name must match exactly (case-sensitive)
- Enable DEBUG = 1 in mute_button.lua to see detection logs

**Controls not responding:**
- Check connection numbers in configuration
- Verify AbletonOSC is running in Ableton
- Press refresh button to re-discover tracks

**Performance issues with many tracks:**
- See [Performance Guide](docs/PERFORMANCE.md) for optimization strategies
- Ensure DEBUG = 0 in all scripts for production use

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

**Current Version**: v1.4.0 - Added double-click mute protection for critical tracks.

For additional documentation:
- [Technical Documentation](docs/TECHNICAL.md) - Detailed technical information
- [Performance Guide](docs/PERFORMANCE.md) - Optimization strategies
- [Contributing Guidelines](docs/CONTRIBUTING.md) - How to contribute
