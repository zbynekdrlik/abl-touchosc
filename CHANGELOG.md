# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.5.0] - 2025-07-07

### Added
- Double-click mute protection for critical tracks (v2.7.0)
  - Two-control approach: mute_button.lua + mute_display_label.lua
  - Configurable per track group via configuration text
  - Format: `double_click_mute: 'instance_Group Name'` (full group name with instance prefix)
  - Prevents accidental muting on master bus or critical tracks
  - Backward compatible - single-click behavior remains default
  - 500ms double-click window for mute toggle
  - Visual warning indicator (⚠) on display label for protected tracks
  - Works with both regular and return tracks

### Changed
- mute_button.lua updated to v2.7.0 with simplified configuration
  - Production-ready with solid color support in buttons
  - Configuration uses full group names for clarity
- document_script.lua updated to v2.9.0 to support new configuration format
- README updated with comprehensive double-click mute documentation

### Technical Details
- Two-control approach chosen due to TouchOSC limitations:
  - Labels cannot render solid background colors (appear semi-transparent)
  - Buttons provide essential solid color feedback for mute states
  - Display labels provide text and warning symbols
- mute_display_label.lua v1.0.1 added for visual indicators
- Removed experimental mute_label.lua (combined approach didn't work)

## [1.3.0] - 2025-07-06

### Added
- Fader position color indicator for dB labels (v1.5.0)
  - White text when fader is exactly at 0dB (unity gain)
  - Light green text when fader is at any other position
  - Provides quick visual feedback for gain staging
  - Uses TouchOSC's textColor property for label text color
  - No performance impact or regression

### Fixed
- CRITICAL: Restored multi-connection support to meter scripts (regression from v1.2.0)
  - meter_script.lua v2.5.2: Restored connection filtering with performance caching and consistent logging
  - db_meter_label.lua v2.6.2: Restored connection support (minimal changes only)
  - db_label.lua v1.3.2→v1.5.0: Restored connection support and added color indicator
  - Multi-instance routing now works correctly for all meter displays
  - Found that multi-connection support was accidentally removed after v1.2.0 release
- Mute button now sends boolean values to AbletonOSC (v2.1.4)
  - Fixed "Python argument types did not match C++ signature" error
  - Changed from sending integers (0/1) to proper boolean values (true/false)
- Feedback loop prevention when controlling faders from Ableton (v2.5.4)
  - Fixed jumpy/laggy behavior when moving faders in Ableton
  - Added updating_from_osc flag to prevent TouchOSC from echoing received values
  - Bidirectional sync now works smoothly without feedback loops

## [1.2.0] - 2025-06-28

### Added
- Complete support for Ableton Live return tracks
  - All controls (fader, mute, pan, meters) now work with return tracks
  - Automatic detection of track type (regular vs return)
  - Dynamic OSC path routing based on track type
  - Updated all scripts to handle both track types seamlessly

### Changed
- Enhanced track initialization system
  - group_init.lua now queries both regular and return tracks
  - Scripts automatically use correct OSC paths (/live/track vs /live/return)
  - Improved track type detection and storage

### Fixed
- Track mapping now correctly identifies return tracks
- OSC routing properly differentiates between track types
- All controls maintain proper state when switching between track types

## [1.1.0] - 2025-06-27

### Added
- Professional multi-connection support for multiple Ableton Live instances
  - Configuration-based connection routing
  - Support for up to 10 simultaneous connections
  - Each track group can be assigned to different Ableton instances
  - Global refresh broadcasts to all connections
- Enhanced visual feedback system
  - Real-time status indicators for each track
  - Color-coded connection states (green=active, yellow=receiving, red=unmapped)
  - Smooth fade animations for activity indication
- dBFS meter label display with real-time calibration
  - Accurate dBFS readings based on user-verified calibration
  - Toggle between dBFS display and raw meter values for debugging
  - Visual feedback when in debug mode (yellow tint)

### Changed
- Improved script architecture for better performance
  - Optimized message routing
  - Reduced unnecessary processing
  - Better error handling
- Enhanced debug logging system
  - Contextual logging with parent information
  - Standardized debug flags across all scripts
  - More informative log messages

### Fixed
- Connection routing now properly isolates instances
- Status indicators update correctly during all state changes
- Meter calibration matches actual Ableton Live values

## [1.0.0] - 2025-06-27

### Added
- Initial release of the Ableton Live TouchOSC Template
- Professional fader control with movement smoothing system
  - Gradual first movement scaling for precision
  - Immediate 0.1dB response for fine adjustments
  - Emergency movement detection for quick changes
  - Double-tap to unity gain (0dB) functionality
- Complete track control suite
  - Volume fader with dB-accurate positioning
  - Mute button with proper state management
  - Pan control with center detent and double-tap reset
  - VU meter with color-coded level indication
  - dB value label showing current fader position
- Smart track management
  - Automatic track detection and mapping
  - Document-based connection configuration
  - Persistent track assignments
  - Automatic refresh on Ableton Live project changes
- Professional visual design
  - Color-coded controls for easy identification
  - Real-time visual feedback
  - Clean, intuitive layout
  - Consistent styling across all controls

### Technical Features
- Logarithmic curve matching Ableton Live's fader response
- Calibrated meter display with smooth animations
- Proper OSC message handling and routing
- Extensive debug logging capabilities
- Modular script architecture for easy maintenance

[1.5.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.5.0
[1.3.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.3.0
[1.2.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.2.0
[1.1.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.1.0
[1.0.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.0.0