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
- **Requires**: [Forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support) with listener fixes

### Performance Optimizations (v1.3.0) 🚀
- **Reduced CPU Usage**: ~50% reduction through scheduled updates
- **Optimized Update Rates**: Controls update at appropriate frequencies (20-100Hz)
- **Zero Debug Overhead**: No performance impact when DEBUG=0
- **Smoother Response**: Better performance with 16+ tracks
- **Position Stability**: Controls never move without real data (no jumping)

### Professional Controls

#### Volume Fader
- Professional movement scaling with 0.1dB precision
- Double-tap to jump to 0dB
- Exact dB curve matching Ableton's response
- Emergency movement detection for quick adjustments
- State preservation between sessions
- **Fixed**: No position jumping when disconnected

#### Level Meter  
- Precisely calibrated to match Ableton's meters
- Color-coded thresholds:
  - Green: Normal levels
  - Yellow: -12dB warning
  - Red: -3dB peak warning
- Real-time response with connection filtering
- **Optimized**: 20Hz update rate for smooth visuals

#### Mute Button
- Reliable state tracking with feedback prevention
- Visual-only state indication (no text)
- Touch detection for responsive control
- **Note**: Requires OSC receive patterns in template (see Troubleshooting)

#### Pan Control
- Smooth panning with visual feedback
- Double-tap to center
- Color indication of pan position
- **Fixed**: No position jumping when disconnected

#### dB Value Display
- Shows current fader position in dB
- Displays "-inf" at minimum
- Shows "-" when track unmapped
- Continuous updates with volume listener

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
- **dBFS Display**: Peak meter values in dBFS
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
- **Position Stability**: Controls maintain position when disconnected (v1.3.0)

### Manual Controls

- **Refresh Button**: Manually trigger track discovery at any time
- **Logger**: View system messages and track assignments (removed in v1.3.0 - use TouchOSC's built-in log viewer)

## 🔧 Configuration

### Basic Configuration

The configuration text control accepts these parameters:

| Parameter | Description | Example |
|-----------|-------------|---------|
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

### Performance Settings

All scripts have DEBUG mode disabled by default for optimal performance:
```lua
local DEBUG = 0  -- No logging overhead (default)
local DEBUG = 1  -- Enable console logging for troubleshooting
```

## 📚 Technical Documentation

### Architecture Overview

The system uses a unified script architecture:
- **Document Script**: Central configuration and auto-refresh
- **Group Scripts**: Track discovery with auto-detection
- **Control Scripts**: Same scripts handle both track types
- **Tag Communication**: Parent groups pass info via tags
- **Complete Isolation**: No shared variables between scripts
- **Performance Optimized**: Scheduled updates instead of continuous polling

### Script Versions (v1.3.1)

| Script | Current Version | Purpose | Latest Fix |
|--------|----------------|---------|------------|
| document_script.lua | 2.7.4 | Configuration, auto-refresh | - |
| group_init.lua | 1.15.9 | Track group with auto-detection | - |
| fader_script.lua | 2.6.0 | Volume control for all track types | Sync delay removed |
| meter_script.lua | 2.5.6 | Level metering unified | OSC format fix |
| mute_button.lua | 2.0.2 | Mute control unified | Added notify handler |
| pan_control.lua | 1.4.2 | Pan control unified | - |
| db_label.lua | 1.3.2 | dB display unified | Volume listener added |
| db_meter_label.lua | 2.6.1 | Peak meter unified | OSC format fix |
| global_refresh_button.lua | 1.5.1 | Manual refresh trigger | - |

### Performance Improvements (v1.3.0)

**Update Rate Optimization:**
- Group activity monitoring: 60-120Hz → 10Hz (100ms intervals)
- Meter updates: 60-120Hz → 20Hz (50ms intervals)
- Fader sync checking: Continuous → On-demand

**Debug Overhead Elimination:**
- Early return when DEBUG=0 (no string operations)
- Zero performance impact in production mode
- Direct console output when debugging enabled

**Position Stability Fix:**
- Controls track `has_valid_position` flag
- No value processing until Ableton sends initial data
- Prevents jumping to default positions on startup/disconnect

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
- **Scheduled Updates**: Performance-optimized update rates
- **Position Preservation**: Controls never move without real data

## 🔧 Troubleshooting

### Common Issues

**Mute buttons not syncing from Ableton (v1.3.1):**
- The template needs OSC receive patterns configured for mute buttons
- In TouchOSC Editor, select each mute button:
  - Add receive pattern: `/live/track/get/mute` (regular tracks)
  - Add receive pattern: `/live/return/get/mute` (return tracks)
- Save and reload the template
- This is a one-time template configuration

**Controls jumping to wrong positions:**
- Fixed in v1.3.0 - update to latest scripts
- Faders no longer jump to 0 when disconnected
- Pan no longer jumps to full right

**Poor performance with many tracks:**
- Update to v1.3.0 for ~50% CPU reduction
- Ensure DEBUG=0 in all scripts (default)
- Check network connection quality

**Return tracks not working:**
- Install the [forked AbletonOSC](https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support)
- Check return track names match exactly (including "A-", "B-" prefixes)
- Look for "Mapped to Return Track X" in logs

**Controls not responding:**
- Check connection numbers in configuration
- Verify AbletonOSC is running in Ableton
- Press refresh button to re-discover tracks

**Wrong tracks mapped:**
- Ensure exact name matching for groups
- Check both regular and return track names
- Try manual refresh

### Debug Mode

Enable detailed logging by modifying script DEBUG constants:
```lua
local DEBUG = 1  -- Set to 1 for verbose logging
```

**Note**: Debug mode impacts performance. Use only for troubleshooting.

## 🤝 Contributing

We welcome contributions! Please:
- Create feature branches for all changes
- Update documentation with code changes
- Include version updates in scripts
- Test thoroughly with logging enabled
- Profile performance impacts

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for detailed guidelines.

## 📄 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for professional audio workflows
- Inspired by the need for sophisticated multi-instance control
- Return track support added to fill a gap in AbletonOSC
- Performance optimizations based on real-world usage feedback
- Thanks to the TouchOSC and AbletonOSC communities

---

**Current Status**: v1.3.1 - Production ready with full return track support and performance optimizations. All controls stable except mute buttons need OSC patterns configured in template (see Troubleshooting).

For development documentation and future plans, see the [docs](docs/) directory.