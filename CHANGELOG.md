# Changelog

All notable changes to the TouchOSC Ableton Live Controller will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Mute button now sends boolean values to AbletonOSC (v2.1.4)
  - Fixed "Python argument types did not match C++ signature" error
  - Changed from sending integers (0/1) to proper boolean values (true/false)
  - Added rule documentation in `rules/abletonosc-mute-boolean.md`
- Restored user control of mute button colors (v2.1.0)
  - Removed script color manipulation that was overriding TouchOSC editor settings
  - Colors now fully controlled by user in TouchOSC editor
  - TouchOSC's built-in pressed/released color states work properly
  - Maintains improved code organization from v2.0.x
- Restored missing pan control features (v1.5.3)
  - Color change functionality: gray when centered, cyan when off-center
  - Double-tap to center functionality with 300ms detection window
  - Optimized performance by removing continuous update() calls
  - Color changes now event-driven in onValueChanged()
- Group interactivity bug - meters and labels now remain non-interactive when group is mapped
  - Simplified code to only handle controls that need interactivity changes
  - Removed unnecessary code that was setting non-interactive states
  - Let TouchOSC editor handle non-interactive state for meters/labels
- Refresh All button now properly reassigns groups when tracks are renumbered in Ableton
  - Implemented registration system where groups self-register with document script
  - Fixed issue where refresh would find 0 groups after initial mapping
  - Added proper clearing of track references before reassignment
  - Handles track renumbering when inserting/removing tracks in Ableton

## [2.8.7] - 2025-07-05

### Changed
- document_script.lua: Switched from searching to registration-based group management
- group_init.lua v1.16.2: Groups now self-register with document script on initialization
- fader_script.lua v2.5.3: Added handling for mapping_cleared notification

### Fixed
- Track renumbering refresh issue completely resolved

## [2.8.2] - 2025-07-04

### Removed
- Removed dead configuration_updated handler from document_script.lua
- Config text is read-only at runtime, making the handler unnecessary

## [2.8.1] - 2025-07-04

### Changed
- Removed centralized logging system via notify()
- Each script now has its own local log() function with DEBUG flag
- Improved performance by eliminating inter-script logging communication

### Technical Details
- All scripts updated with local logging functions
- DEBUG flag defaults to 0 (off) for production
- Logging format standardized across all scripts

## [2.5.2] - 2025-06-29

### Fixed
- Fader script debug flag standardization (DEBUG in uppercase)
- Set DEBUG=0 by default for production use

## [2.5.1] - 2025-06-29

### Changed
- Enhanced fader double-tap animation with optimized speed (0.005 units/update)
- Smoother visual transition when double-tapping to unity gain

## [2.5.0] - 2025-06-29

### Added
- Connection-aware OSC routing in fader script
- Dynamic connection index lookup from parent group configuration
- Support for both regular tracks and return tracks

### Changed
- Fader now reads track info directly from parent group tag
- Improved OSC message routing with connection tables

## [2.4.0] - 2025-06-29

### Added
- Smart group initialization with automatic startup refresh
- Connection-based configuration system
- Multiple Ableton instance support (band/master)
- Visual activity indicators for groups

### Changed
- Groups now store track mapping in tag property
- Improved refresh mechanism with proper clearing
- Better error handling for missing tracks

## [2.3.0] - 2025-06-28

### Added
- Professional fader control with movement smoothing
- First movement scaling for precise control
- Emergency movement detection for quick adjustments
- Double-tap to unity gain (0dB) functionality

### Technical Features
- 0.1dB minimum change on first movement
- Reaction time compensation
- Linear range precision (-6dB to +6dB)
- Smooth animation for double-tap

## [2.0.0] - 2025-06-27

### Added
- Complete rewrite with modular architecture
- Document script pattern for configuration management
- Inter-script communication via notify()
- Comprehensive documentation and rules

### Changed
- Migrated from monolithic to modular script structure
- Improved error handling and validation
- Better TouchOSC API compliance

## [1.0.0] - 2025-06-27

### Added
- Initial release
- Basic fader control for Ableton Live
- Volume, pan, mute controls
- VU meter display
- Multi-track support