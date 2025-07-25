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
- **NEW**: Configurable double-click protection for critical tracks (v2.7.0)

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
# IMPORTANT: Each group needs its own line!
double_click_mute: 'band_Band Tracks'    # Require double-click for 'Band Tracks' group
double_click_mute: 'master_Master Bus'   # Require double-click for 'Master Bus' group
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

### Double-Click Mute Protection (NEW in v2.7.0)

For critical tracks where accidental muting could be disastrous (like master bus or live performance tracks), you can enable double-click protection:

#### Template Setup (Two-Control Approach)

The double-click mute feature uses two separate controls for optimal visual feedback:

1. **Mute Button Control**:
   - Type: Button (Toggle mode)
   - Script: `mute_button.lua` (v2.7.0)
   - Colors: ON = Red (muted), OFF = Orange (unmuted)
   - Handles the actual mute logic and double-click detection

2. **Display Label Control**:
   - Type: Label
   - Script: `mute_display_label.lua` (v1.0.1)
   - Position: On or near the button
   - Shows "MUTE" text with warning symbol (⚠) for protected tracks
   - Display-only (non-interactive)

#### Configuration

Add configuration for the groups that need protection:
```yaml
# IMPORTANT: Each group needs its own line in the configuration!
# NEW in v2.7.0: Use the full group name (including instance prefix)

double_click_mute: 'band_Band Tracks'      # Band instance, 'Band Tracks' group
double_click_mute: 'band_Lead Vocals'      # Band instance, 'Lead Vocals' group
double_click_mute: 'master_Master Bus'     # Master instance, 'Master Bus' group
```

#### How It Works

- **Groups with double-click enabled** require two clicks within 500ms to toggle mute
- **Protected tracks show ⚠MUTE⚠** on the display label (visual warning)
- **Groups without configuration** maintain single-click behavior (backward compatible)
- **Button provides solid color feedback** (red when muted, orange when unmuted)

#### Why Two Controls?

TouchOSC labels cannot render solid background colors (they appear semi-transparent), making it difficult to show clear mute states. The two-control approach provides:
- Solid color feedback via button (essential for clear state indication)
- Text display with warning symbols via label (better visibility)

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
| double_click_mute | Require double-click for group (v2.7.0+) | `double_click_mute: 'band_Band Tracks'` |

### Configuration Format Rules

⚠️ **IMPORTANT**: Each configuration entry must be on its own line!

✅ **CORRECT** - Each group on separate line:
```yaml
double_click_mute: 'band_Drums'
double_click_mute: 'band_Bass'
double_click_mute: 'band_Lead Vocal'
```

❌ **INCORRECT** - Multiple groups on one line (will NOT work):
```yaml
double_click_mute: 'band_Drums', 'band_Bass', 'band_Lead Vocal'  # This won't work!
```

### Multi-Instance Example

```yaml
# Two separate connections
connection_band: 2      # Band mix Ableton
connection_master: 3    # Master mix Ableton

# Different unfold groups per instance  
unfold_band: 'Band'
unfold_master: 'Master'

# Double-click protection for critical tracks
# Each group needs its own line!
# NEW: Use full group names (with instance prefix)
double_click_mute: 'band_Band Tracks'    # Protect band master group
double_click_mute: 'band_Drums'          # Protect drums
double_click_mute: 'band_Lead Vocal'     # Protect lead vocals
double_click_mute: 'master_Master Bus'   # Protect master bus
double_click_mute: 'master_Limiter'      # Protect final limiter
```

### Complete Multi-Instance Configuration Example

```yaml
# Four Ableton instances for live show
connection_band: 2
connection_playback: 3
connection_fx: 4
connection_broadcast: 5

# Auto-unfold groups
unfold_band: 'Rhythm Section'
unfold_band: 'Vocals'              # Yes, you can have multiple unfolds per instance
unfold_playback: 'Backing Tracks'
unfold_fx: 'Send Effects'
unfold_broadcast: 'Stream Mix'

# Double-click protection - v2.7.0 format (full group names)
double_click_mute: 'band_Drums'
double_click_mute: 'band_Bass'
double_click_mute: 'band_Lead Vocal'
double_click_mute: 'band_Click Track'

double_click_mute: 'playback_Main Playback'
double_click_mute: 'playback_Timecode'
double_click_mute: 'playback_Video Sync'

double_click_mute: 'fx_Reverb Send'
double_click_mute: 'fx_Delay Send'

double_click_mute: 'broadcast_Stream Master'
double_click_mute: 'broadcast_Broadcast Limiter'
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
| mute_button.lua | 2.7.0 | Mute control with simplified double-click config |
| mute_display_label.lua | 1.0.1 | Display label with warning symbol for protected tracks |
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
- **Double-Click Detection**: Simplified configuration using full group names (v2.7.0)

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
- Check each group is on its own line in configuration
- Group name must match exactly (case-sensitive, including instance prefix)
- NEW in v2.7.0: Use full group name like `double_click_mute: 'band_Drums'`
- Enable DEBUG = 1 in mute_button.lua to see detection logs
- Verify configuration format matches examples exactly

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

**Current Version**: v1.5.0 - Added double-click mute protection with two-control approach.

For additional documentation:
- [Technical Documentation](docs/TECHNICAL.md) - Detailed technical information
- [Performance Guide](docs/PERFORMANCE.md) - Optimization strategies
- [Contributing Guidelines](docs/CONTRIBUTING.md) - How to contribute