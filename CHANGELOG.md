# Changelog

All notable changes to the ABL TouchOSC project are documented here.

## [Unreleased]
- Phase 4: Production scaling with multiple groups
- Phase 5: Logging optimization with debug levels
- Phase 6: Advanced controls (solo, sends, devices)

## Phase 4 Started - 2025-06-29

### dB Label [1.0.1]
- Changed to show dash "-" when track unmapped
- Previously showed empty string

### dB Label [1.0.0] - NEW
- Shows fader value in dB format
- Multi-connection routing support
- Uses exact same dB conversion as fader
- Shows "-inf" for minimum values
- Unified logging integration
- Shows dash when track unmapped

## Phase 3 Complete - 2025-06-29

### Document Script [2.7.1]
- Fixed automatic refresh with frame counting method
- More reliable than clock-based timing

### Document Script [2.7.0]
- Added automatic refresh on startup
- Triggers refresh 1 second after TouchOSC starts
- No manual refresh needed when opening project
- Shows "=== AUTOMATIC STARTUP REFRESH ===" in logger

### Document Script [2.6.0]
- Removed print statement from log function
- Now only appends to logger text (no console output)
- Prevents duplicate logging in console

### Mute Button [1.8.0]
- Changed from local print to root:notify for logger output
- Unified logging with other scripts
- Maintains all functionality from v1.7.1

### Pan Control [1.3.2]
- Added logger output using root:notify
- Matches logging pattern of other scripts

### Pan Control [1.3.1]
- Removed x value change on init
- Preserves current pan position

### Pan Control [1.3.0]
- Simplified implementation based on original script
- Removed overcomplicated fader-based code
- Kept double-tap and color feedback
- Added multi-connection support

### Fader Script [2.3.5]
- Never changes position based on assumptions
- Removed automatic position changes in onValueChanged
- Removed position resets in onReceiveNotify
- Preserves fader state between track changes

## Phase 3 Testing - 2025-06-28

### Mute Button [1.7.1]
- Uses local print only (no root notify)
- Perfect state management confirmed
- No text property issues

### Fader Script [2.3.4]
- Removed color changes to preserve visual design
- Group script handles enable/disable
- All sophisticated features working

### Meter Script [2.2.2]
- Fixed debug mode logging
- Removed connection index logging issue
- Calibration perfect

### Group Script [1.9.6]
- Fixed runtime error with pairs() on children
- Track label updates correctly to "???"
- All visual corruption fixed

## Multi-Connection Implementation - 2025-06-28

### Group Script [1.9.0-1.9.5]
- Multiple fixes for visual corruption
- Removed all color/opacity changes
- Only toggles interactivity
- Fixed various runtime errors

### Fader Script [2.3.0-2.3.3]
- Fixed OSC parameter sending
- Added logger verbosity control
- Fixed tag format handling
- Script isolation fixes

### Meter Script [2.2.0-2.2.1]
- Updated for new tag format
- Multi-connection routing added
- Script isolation implementation

### Mute Button [1.2.0-1.7.0]
- Complete rewrite for script isolation
- Removed text property usage (buttons don't have text!)
- Added connection routing
- Multiple bug fixes

### Document Script [2.5.0-2.5.9]
- Added centralized logging
- Handle log_message notifications
- Connection routing helpers
- Configuration management

## Foundation Phase - 2025-06-27

### Initial Scripts
- Document Script v1.0.0-2.4.0: Basic setup and evolution
- Group Script v1.0.0-1.8.0: Track discovery and mapping
- Fader Script v1.0.0-2.1.0: Basic volume control
- Meter Script v1.0.0-2.1.0: Level display
- Global Refresh v1.0.0-1.4.0: Track refresh functionality

## Version Guidelines

### Semantic Versioning
- MAJOR.MINOR.PATCH
- MAJOR: Breaking changes, architectural updates
- MINOR: New features, phase completions
- PATCH: Bug fixes, minor improvements

### Examples from Development
- v1.0.0 → v1.1.0: New phase features
- v1.1.0 → v1.1.1: Bug fix iteration
- v1.9.0 → v2.0.0: Major refactor

## Key Milestones

### Automatic Startup Refresh
Implemented automatic track discovery on TouchOSC startup, eliminating manual refresh requirement.

### Script Isolation Discovery
Learned that TouchOSC scripts are completely isolated and cannot share variables or functions. This led to major refactoring of all scripts.

### Button Text Property Issue
Discovered buttons don't have text property, leading to v1.7.0 of mute button and documentation updates.

### Multi-Connection Architecture
Successfully implemented routing to control multiple Ableton instances from one TouchOSC interface.

### State Preservation
Implemented principle that controls should never change position based on assumptions, only on user action or OSC updates.