# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Double-click mute protection for critical tracks (v2.4.0-v2.7.0)
  - Configurable per track group via configuration text
  - Simplified format: `double_click_mute: 'Group Name'` (v2.7.0)
  - Prevents accidental muting on master bus or critical tracks
  - Backward compatible - single-click behavior remains default
  - 500ms double-click window for mute toggle
  - Works with both regular and return tracks
  - Visual feedback maintained during double-click waiting period

### Changed
- mute_button.lua updated through v2.7.0 with simplified configuration
  - Configuration checked with proper pattern escaping for special characters
  - Production-ready with solid color support in buttons
- document_script.lua updated to v2.9.0 to support new configuration format
- README updated with double-click mute documentation

### Experimental (Not Released)
- Interactive mute label tested (v2.8.0-v2.8.6)
  - Attempted to combine button and label functionality
  - Discovered TouchOSC limitation: labels cannot render solid background colors
  - Background colors appear semi-transparent/blended
  - Decision: Continue using buttons for mute controls due to superior visual feedback
  - Label script preserved for reference but not recommended for production

### Technical Notes
- Buttons provide solid color rendering essential for clear visual states
- Labels better suited for display-only elements, not interactive controls
- Double-click protection works perfectly with button controls

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

[1.3.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.3.0
[1.2.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.2.0
[1.1.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.1.0
[1.0.0]: https://github.com/zbynekdrlik/abl-touchosc/releases/tag/v1.0.0
