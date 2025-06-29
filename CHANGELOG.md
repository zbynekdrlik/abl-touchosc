# Changelog

All notable changes to the ABL TouchOSC project are documented here.

## [1.1.0] - 2025-06-29
### Enhancement Release

#### Group Script [1.10.0]
- Status indicator now works as opacity replacement (visible only when mapped)
- Track labels preserved - no more "???" when unmapped
- Added connection label support - shows "band" or "master"
- Removed 5-minute stale status check
- Added db_label to notification list

#### dB Label [1.0.2]
- Fixed error "No such property or function: 'lastDB'"
- Changed from `self.lastDB` to local variable (TouchOSC doesn't support custom properties on self)

## [1.0.0] - 2025-06-29
### Production Release 🚀

This is the first production release of ABL TouchOSC with complete multi-instance routing capabilities.

### Features
- **Multi-Connection Routing**: Control multiple Ableton instances from one interface
- **Automatic Startup Refresh**: Tracks discovered automatically after 1 second
- **Professional Controls**: All core track controls implemented
  - Volume Fader with 0.1dB precision and double-tap to 0dB
  - Calibrated Level Meter with color thresholds
  - Mute Button with state tracking
  - Pan Control with double-tap to center
  - dB Value Display
- **Visual Design Preservation**: Scripts never alter your interface design
- **Complete Script Isolation**: Robust architecture with isolated components
- **Comprehensive Documentation**: Production-ready documentation

### Final Script Versions
| Script | Version | Purpose |
|--------|---------|---------|
| document_script.lua | 2.7.1 | Central management + auto refresh |
| group_init.lua | 1.10.0 | Track group management |
| fader_script.lua | 2.3.5 | Professional fader control |
| meter_script.lua | 2.2.2 | Calibrated level metering |
| mute_button.lua | 1.8.0 | Mute state management |
| pan_control.lua | 1.3.2 | Pan with visual feedback |
| db_label.lua | 1.0.2 | dB value display |
| global_refresh_button.lua | 1.4.0 | Manual refresh trigger |

### Testing Confirmed
- Multi-connection routing verified with band_CG # and master_CG #
- Complete isolation between connections
- All controls working as designed
- Performance acceptable for real-time use

---

## Development History

### Phase 4 Started - 2025-06-29

#### Documentation Reorganization
- README.md updated to be feature-focused rather than phase-focused
- Added docs/CONTRIBUTING.md with development guidelines
- Added docs/TECHNICAL.md with comprehensive technical documentation
- Added docs/README.md as documentation index
- Created docs/archive/ for historical documentation

#### dB Label [1.0.1]
- Changed to show dash "-" when track unmapped

#### dB Label [1.0.0] - NEW
- Shows fader value in dB format
- Multi-connection routing support
- Uses exact same dB conversion as fader

### Phase 3 Complete - 2025-06-29

#### Document Script [2.7.1]
- Fixed automatic refresh with frame counting method

#### Document Script [2.7.0]
- Added automatic refresh on startup
- Triggers refresh 1 second after TouchOSC starts

#### All Control Scripts
- Fader [2.3.5]: Professional movement scaling
- Meter [2.2.2]: Exact calibration
- Mute [1.8.0]: State tracking
- Pan [1.3.2]: Visual feedback

### Phase 2 Complete - 2025-06-28
- Multi-connection architecture implemented
- Instance-based routing working
- Configuration system finalized

### Phase 1 Complete - 2025-06-27
- Foundation established
- Basic controls working
- Track discovery functional

## Key Technical Achievements

### Multi-Connection Architecture
Successfully implemented routing to control multiple Ableton instances from one TouchOSC interface with complete isolation.

### Automatic Startup Refresh
Implemented automatic track discovery on TouchOSC startup, eliminating manual refresh requirement.

### Script Isolation
Discovered and solved TouchOSC script isolation challenges, leading to robust architecture.

### State Preservation
Implemented principle that controls never change position based on assumptions.

---

## Future Roadmap

### Planned Enhancements
- Additional track groups for full production scaling
- Solo and record arm controls
- Send level controls (A-D)
- Device parameter mapping
- Scene launching capabilities
- Debug level system for logging

---

*For detailed version history, see the development phases below.*