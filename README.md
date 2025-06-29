# ABL TouchOSC Control Surface

A professional TouchOSC control surface for Ableton Live with advanced multi-instance routing capabilities. This project enables sophisticated control of multiple Ableton Live instances through a single TouchOSC interface with intelligent connection management.

## Features

### ✅ Implemented
- **Multi-Connection Routing**: Control multiple Ableton instances (band/master) from one interface
- **Dynamic Track Mapping**: Automatic track discovery and mapping with visual feedback
- **Professional Fader Control**: 
  - Sophisticated movement scaling for precise control
  - Double-tap to 0dB functionality
  - Exact dB curve matching Ableton's faders
- **Accurate Level Metering**: 
  - Calibrated to match Ableton's meter response
  - Color-coded levels (green/yellow/red)
  - Per-connection routing
- **Smart Mute Buttons**: State tracking with feedback loop prevention
- **Pan Controls**: Double-tap to center with visual feedback
- **Automatic Group Unfolding**: Configure which track groups to auto-unfold per connection
- **Visual Design Preservation**: Scripts never alter your carefully designed interface

### 🚧 In Development
- Full production scaling (8 band + 8 master groups)
- Solo and record arm controls
- Send level controls
- Device parameter mapping
- Track color synchronization

## Architecture

### Connection Model
```
TouchOSC Interface
    ├── Band Controls (Connection 2)
    │   └── Controls Ableton Instance 1 (Band)
    └── Master Controls (Connection 3)
        └── Controls Ableton Instance 2 (Master)
```

### Script Architecture
- **Document Script**: Central configuration and logging management
- **Group Scripts**: Track discovery and control management
- **Control Scripts**: Individual fader, meter, mute, pan functionality
- **Complete Script Isolation**: Each script is self-contained with direct config reading

## Installation

1. **Prerequisites**
   - TouchOSC (latest version)
   - Ableton Live with AbletonOSC installed
   - Multiple network connections configured

2. **Setup**
   - Load the TouchOSC file
   - Configure connections in the configuration text:
     ```
     connection_band: 2
     connection_master: 3
     ```
   - Set unfold groups per connection:
     ```
     unfold_band: 'Band'
     unfold_master: 'Master'
     ```

3. **Usage**
   - Press Refresh to discover tracks
   - Groups automatically map to their configured tracks
   - Controls route to the correct Ableton instance

## Technical Details

### Version Management
All scripts follow semantic versioning:
- PATCH: Bug fixes and minor improvements
- MINOR: New features or completing development phases
- MAJOR: Breaking changes or architectural updates

### State Management
- Controls preserve their state between sessions
- No assumptions about default positions
- State changes only from user action or Ableton updates

### Logging System
- Centralized logging through document script
- All scripts report to unified logger
- Debug mode available for troubleshooting

## Development Phases

### ✅ Phase 1: Foundation (Complete)
- Basic OSC communication
- Configuration system
- Track discovery

### ✅ Phase 2: Multi-Connection (Complete)
- Connection routing architecture
- Per-instance track management
- Instance-specific unfolding

### ✅ Phase 3: Control Implementation (Complete)
- Fader with sophisticated scaling
- Calibrated meters
- Mute buttons with state tracking
- Pan controls with visual feedback

### 🚧 Phase 4: Production Scaling
- Multiple track groups
- Performance optimization
- Full project testing

### 📋 Phase 5: Logging Optimization (Planned)
- Debug level implementation
- Concise production logging
- Performance monitoring

### 📋 Phase 6: Advanced Features (Planned)
- Additional control types
- Device control
- Advanced routing options

## Configuration Reference

### Connection Configuration
```
# Map instances to OSC connections
connection_band: 2      # Band controls use connection 2
connection_master: 3    # Master controls use connection 3
```

### Unfold Configuration
```
# Auto-unfold track groups
unfold_band: 'Band'     # Unfold 'Band' group on band connection
unfold_master: 'Master' # Unfold 'Master' group on master connection
unfold: 'Drums'         # Unfold on all connections (legacy)
```

## Script Reference

| Script | Version | Purpose |
|--------|---------|---------|
| document_script.lua | 2.6.0 | Central configuration and logging |
| group_init.lua | 1.9.6 | Track group management |
| fader_script.lua | 2.3.5 | Professional fader control |
| meter_script.lua | 2.2.2 | Calibrated level metering |
| mute_button.lua | 1.8.0 | Mute state management |
| pan_control.lua | 1.3.2 | Pan with visual feedback |
| global_refresh_button.lua | 1.4.0 | Track discovery trigger |

## Contributing

This project follows strict development practices:
- All changes in feature branches
- Comprehensive testing with logs
- Documentation updates with code changes
- Version increment for every change

## License

[License information to be added]

## Support

For issues or questions:
- Check the logs in TouchOSC
- Enable debug mode for detailed information
- Refer to the rules documentation for TouchOSC specifics

---

*Built with precision for professional audio workflows*