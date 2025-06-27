# Deep Verification Checklist - Selective Connection Routing

## Pre-Flight Checks

### TouchOSC Configuration
- [ ] Connection 1 configured (Band Ableton)
  - [ ] Correct IP address
  - [ ] Correct send port (usually 11000)
  - [ ] Unique receive port (e.g., 11001)
- [ ] Connection 2 configured (Master Ableton)  
  - [ ] Correct IP address
  - [ ] Correct send port (usually 11000)
  - [ ] Different receive port (e.g., 11002)
- [ ] Connections tested with OSC monitor

### Ableton Configuration
- [ ] Band instance running AbletonOSC
- [ ] Master instance running AbletonOSC
- [ ] Track names documented exactly
- [ ] Track names include # suffix where needed

## Script Verification

### Helper Script (v1.0.9)
- [ ] Added to document root
- [ ] Version logged on startup: "Helper Script v1.0.9 loaded"
- [ ] Configuration object found and parsed
- [ ] Logger object found (or warning shown)
- [ ] Both connections show in log

### Group Scripts (v1.5.1)
For EACH group:
- [ ] Script shows version: "Group init v1.5.1 for [name]"
- [ ] Group name parsed correctly (instance + track name)
- [ ] Connection index identified
- [ ] Tag set to "trackGroup"
- [ ] Initial state: controls DISABLED

### Global Refresh Button (v1.1.0)
- [ ] Version logged: "Global Refresh Button v1.1.0 loaded"
- [ ] Button text shows "REFRESH ALL"
- [ ] Click triggers refresh for all groups

## Critical UI Configuration

### Per Group Requirements
- [ ] Group name follows pattern: `instance_TrackName`
- [ ] Status indicator exists and named "status_indicator"
- [ ] OSC Receive pattern set: `/live/song/get/track_names`
- [ ] Correct connection(s) enabled for receive
- [ ] Optional: fdr_label for track name display

## Functional Testing

### Initial State Test
- [ ] All status indicators show RED
- [ ] All controls are disabled (dimmed)
- [ ] Faders at position 0
- [ ] No OSC traffic

### Basic Refresh Test
1. Press global refresh button
   - [ ] Logger shows "=== GLOBAL REFRESH INITIATED ==="
   - [ ] Each group shows "Refreshing [name]"
   - [ ] Track mapping messages appear
   - [ ] Logger shows "=== GLOBAL REFRESH COMPLETE ==="

2. Check results:
   - [ ] Matched tracks: GREEN status, controls enabled
   - [ ] Unmatched tracks: RED status, controls disabled
   - [ ] Track numbers stored in parent tag

### Safety Feature Tests

#### Test 1: Exact Name Matching
- [ ] Create track "Bass" in Ableton
- [ ] Group named "band_Bass #" stays RED (no match)
- [ ] Rename track to "Bass #" 
- [ ] Refresh - group turns GREEN

#### Test 2: Control Disabling
- [ ] Find a GREEN group
- [ ] Verify fader moves and sends OSC
- [ ] Rename track in Ableton
- [ ] Refresh - group turns RED
- [ ] Verify fader is disabled (won't move)
- [ ] Verify no OSC sent when trying to move

#### Test 3: Track Reordering
- [ ] Note current fader positions
- [ ] Reorder tracks in Ableton
- [ ] Move a fader (it controls wrong track!)
- [ ] Press refresh
- [ ] Verify faders control correct tracks again

### Connection Routing Tests

#### Test 1: Selective Sending
- [ ] Use OSC monitor on both Ableton instances
- [ ] Move a "band_" fader
- [ ] Verify OSC only goes to Band instance
- [ ] Move a "master_" fader  
- [ ] Verify OSC only goes to Master instance

#### Test 2: Connection Failure
- [ ] Disconnect Band Ableton
- [ ] Press refresh
- [ ] All "band_" groups show RED
- [ ] All "master_" groups still work
- [ ] Reconnect and refresh - all GREEN

## Edge Cases

### Script Isolation Verification
- [ ] Check no variables shared between scripts
- [ ] Verify notify() works between controls
- [ ] Parent properties accessible from children

### Color Management
- [ ] All color assignments use Color() constructor
- [ ] No {r,g,b} table assignments
- [ ] Status colors display correctly

### OSC Edge Cases
- [ ] Empty track name response handled
- [ ] Very long track names handled
- [ ] Special characters in track names
- [ ] Duplicate track names (both get mapped)

## Performance Verification

### Logger Performance
- [ ] Logger limited to 20 lines
- [ ] Old lines removed automatically
- [ ] No lag when logging active

### Refresh Performance
- [ ] Measure time for global refresh
- [ ] Should complete in <500ms for 20 groups
- [ ] No UI freezing during refresh

### Runtime Performance
- [ ] Smooth fader movement
- [ ] No lag in OSC sending
- [ ] Status updates don't impact performance

## Documentation Verification

### Code Documentation
- [ ] All scripts have version constants
- [ ] Key functions have comments
- [ ] Complex logic explained

### User Documentation  
- [ ] Setup guide complete and accurate
- [ ] Troubleshooting covers all issues
- [ ] Examples match actual implementation

## Known Issues Resolution

### Issue 1: Scripts Can't Share Variables
- [ ] Resolved with notify() system
- [ ] Parent/child property sharing
- [ ] Global functions via helper

### Issue 2: OSC Patterns Not Programmable
- [ ] Documented in setup guide
- [ ] UI configuration steps clear
- [ ] Warning in code comments

### Issue 3: Color Assignment Errors
- [ ] All scripts use Color() constructor
- [ ] No direct table assignments
- [ ] Examples in documentation

### Issue 4: Connection Table Syntax
- [ ] All sendOSC calls include connections
- [ ] Helper function for building tables
- [ ] Documented in Lua rules

### Issue 5: Wrong Track Control
- [ ] Exact name matching implemented
- [ ] Safety disabling when unmapped
- [ ] Clear visual feedback

## Phase 2 Readiness

### Current State
- [ ] Phase 1 fully functional
- [ ] All safety features working
- [ ] Performance acceptable
- [ ] Documentation complete

### Ready for Control Updates
- [ ] Fader script update planned
- [ ] Connection routing understood
- [ ] Safety checks identified
- [ ] Testing plan ready

## Sign-Off Checklist

### Technical Lead
- [ ] All scripts at correct versions
- [ ] Safety features verified
- [ ] Performance acceptable
- [ ] Edge cases handled

### User Testing
- [ ] Setup from scratch successful
- [ ] Refresh recovers from errors
- [ ] Visual feedback clear
- [ ] No confusing behaviors

### Documentation
- [ ] Setup guide accurate
- [ ] Troubleshooting complete
- [ ] Lua rules comprehensive
- [ ] Version history updated

## Final Verification
- [ ] System works with both Ableton instances
- [ ] Handles connection failures gracefully
- [ ] Recovers from track changes
- [ ] Safe from accidental wrong control
- [ ] Ready for production use

---

**Phase 1 Status**: COMPLETE ✅
**Ready for Phase 2**: YES ✅