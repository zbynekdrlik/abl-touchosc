# Changelog

All notable changes to the ABL TouchOSC project are documented here.

## [1.2.0] - 2025-07-03
### Return Track Support Release 🎚️

This release adds complete return track support to ABL TouchOSC using a unified architecture where the same scripts handle both regular and return tracks.

### Major Changes

#### Unified Architecture Implementation
- **No Separate Scripts**: Return tracks use the same scripts as regular tracks
- **Auto-Detection**: Groups automatically detect track type (regular vs return)
- **Single Connection**: Return tracks use the same connection as regular tracks (band/master)
- **Tag-Based Communication**: Parent groups pass track info to children via tags

#### AbletonOSC Fork Updated
- **Repository**: https://github.com/zbynekdrlik/AbletonOSC
- **Branch**: feature/return-tracks-support
- **PR**: https://github.com/zbynekdrlik/AbletonOSC/pull/2
- Fixed "Observer not connected" errors for return tracks
- Added missing listener support for return tracks

#### Script Updates
All scripts updated to support both track types:
- **group_init.lua [1.14.5]**: Auto-detects track type, smart label display
- **fader_script.lua [2.4.1]**: Volume control for both track types
- **meter_script.lua [2.3.1]**: Meter display with return track support
- **mute_button.lua [1.9.1]**: Mute control unified
- **pan_control.lua [1.4.1]**: Pan control unified
- **db_label.lua [1.2.0]**: dB display for both track types
- **db_meter_label.lua [2.5.1]**: Peak meter display unified

#### Bug Fixes
- Fixed script property access errors (parent.trackNumber not available)
- Fixed track label truncation for names with special characters
- Added smart return track prefix handling (A-, B-, etc.)

### Features
- **Full Return Track Control**: Volume, mute, pan, and metering
- **Automatic Discovery**: Return tracks mapped by name matching
- **Smart Track Labels**: Shows first word, skipping return prefixes
- **Complete Integration**: Works with existing multi-instance routing
- **Bidirectional Updates**: All controls update in both directions

### Implementation Details
Groups now use a tag format to communicate track info:
```
"instance:trackNumber:trackType"
Example: "master:0:return"
```

Child scripts parse this tag to determine which OSC paths to use.

### Testing Results
- ✅ Return tracks successfully discovered and mapped
- ✅ All controls working bidirectionally
- ✅ OSC data flow confirmed (logs show meter and dB values)
- ✅ Multi-connection routing supported
- ✅ No script errors

---

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

### Return Track Support
Successfully added return track support using a unified architecture where the same scripts handle both track types through auto-detection.

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
- Send level controls (A-D) for both tracks and returns
- Device parameter mapping
- Scene launching capabilities
- Debug level system for logging
- Submit unified return track approach to upstream AbletonOSC

---

*For detailed version history, see the development phases below.*