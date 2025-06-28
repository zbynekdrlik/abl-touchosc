# Phase 3: Production Testing Plan

## Overview
Phase 3 focuses on stress-testing the selective connection routing system with real-world production scenarios. This includes multiple track groups, both Ableton instances, performance testing, and stability verification.

## Testing Environment Setup

### Prerequisites
- [ ] Two Ableton Live instances with AbletonOSC
- [ ] TouchOSC with Phase 2 implementation
- [ ] At least 10-15 track groups configured
- [ ] Network connection between devices
- [ ] Test tracks in both Ableton instances

### Test Track Configuration

#### Band Instance (Connection 1)
Suggested test tracks:
1. Kick
2. Snare
3. Hi-Hat
4. Overhead L
5. Overhead R
6. Bass
7. Guitar 1
8. Guitar 2
9. Keys
10. Click

#### Master Instance (Connection 2)
Suggested test tracks:
1. VOX 1
2. VOX 2
3. VOX 3
4. Guitar Solo
5. Keys Solo
6. Band Bus
7. Reverb Return
8. Delay Return
9. Master Bus
10. Talkback

## Test Scenarios

### Test 1: Multi-Group Initialization
**Goal**: Verify system handles 20+ groups correctly

**Steps**:
1. Create 10+ groups for each instance
2. Name groups with proper prefixes (band_/master_)
3. Add all required controls to each group
4. Start TouchOSC and monitor logger

**Expected Results**:
- All scripts load with version numbers
- No memory errors or crashes
- Logger shows all group initializations
- Status indicators all show red (unmapped)

**Pass Criteria**:
- [ ] All 20+ groups initialize without errors
- [ ] Version numbers logged for all scripts
- [ ] No performance degradation on startup

### Test 2: Mass Track Discovery
**Goal**: Test global refresh with many tracks

**Steps**:
1. Ensure both Ableton instances have test tracks
2. Press global refresh button
3. Monitor logger output
4. Check all status indicators

**Expected Results**:
- Refresh completes within 2-3 seconds
- All matching tracks show green status
- Non-matching tracks remain red
- Logger shows mapping results

**Pass Criteria**:
- [ ] Refresh completes in < 5 seconds
- [ ] Correct tracks mapped (verify 5 random)
- [ ] No false positive mappings
- [ ] Logger doesn't overflow

### Test 3: Simultaneous Control Operation
**Goal**: Test multiple faders moving simultaneously

**Steps**:
1. Move 5+ faders from band instance groups
2. Move 5+ faders from master instance groups
3. Monitor both Ableton instances
4. Check for cross-talk or lag

**Expected Results**:
- Each fader controls only its mapped track
- No cross-talk between instances
- Smooth fader movement
- Correct OSC routing

**Pass Criteria**:
- [ ] No cross-instance control
- [ ] Fader movement remains smooth
- [ ] All faders reach correct tracks
- [ ] No OSC message overflow

### Test 4: Connection Failure Recovery
**Goal**: Test behavior when connection is lost

**Steps**:
1. Disconnect band instance network
2. Try to use band controls
3. Press global refresh
4. Reconnect band instance
5. Press global refresh again

**Expected Results**:
- Controls for disconnected instance disable
- Other instance continues working
- Refresh shows appropriate errors
- Recovery after reconnection

**Pass Criteria**:
- [ ] Graceful handling of disconnection
- [ ] Master instance unaffected
- [ ] Clear error indication
- [ ] Full recovery on reconnect

### Test 5: Track Reordering Stress Test
**Goal**: Verify mapping survives major changes

**Steps**:
1. Reorder 50% of tracks in both instances
2. Add 2-3 new tracks
3. Delete 1-2 tracks
4. Press global refresh
5. Test all controls

**Expected Results**:
- Correct remapping after changes
- New tracks ignored (no groups)
- Deleted track groups show red
- All valid mappings work

**Pass Criteria**:
- [ ] Accurate remapping
- [ ] No ghost mappings
- [ ] Deleted tracks handled safely
- [ ] Controls work after remap

### Test 6: Extended Session Testing
**Goal**: Verify stability over time

**Steps**:
1. Run system for 30+ minutes
2. Use controls periodically
3. Monitor for memory leaks
4. Check status indicator timing
5. Note any degradation

**Expected Results**:
- No memory growth
- Consistent performance
- Status indicators update properly
- No script errors over time

**Pass Criteria**:
- [ ] Stable for 30+ minutes
- [ ] No performance degradation
- [ ] Status colors remain accurate
- [ ] No unexpected errors

### Test 7: Meter Performance Test
**Goal**: Verify meters handle high data rate

**Steps**:
1. Play loud music through all tracks
2. Observe all meter displays
3. Check for lag or freezing
4. Monitor CPU usage

**Expected Results**:
- Smooth meter animation
- No visual lag
- Reasonable CPU usage
- All meters update correctly

**Pass Criteria**:
- [ ] Meters update at 60fps
- [ ] No visual stuttering
- [ ] CPU usage < 30%
- [ ] Connection filtering works

### Test 8: Edge Case Testing
**Goal**: Test unusual scenarios

**Steps**:
1. Create group with no controls
2. Create group with wrong prefix
3. Use special characters in track names
4. Test very long track names
5. Rapidly toggle connections

**Expected Results**:
- System handles edge cases gracefully
- No crashes or undefined behavior
- Clear error messages where appropriate
- Recovery without restart

**Pass Criteria**:
- [ ] No crashes on edge cases
- [ ] Appropriate error handling
- [ ] System remains usable
- [ ] Clear user feedback

## Performance Benchmarks

### Startup Time
- Target: < 2 seconds with 20 groups
- Acceptable: < 5 seconds
- Log loading time in milliseconds

### Refresh Time
- Target: < 1 second for 10 tracks
- Acceptable: < 3 seconds for 20 tracks
- Measure from button press to completion

### Fader Response
- Target: < 10ms latency
- Acceptable: < 50ms latency
- Test with rapid movements

### Memory Usage
- Initial: Record on startup
- After 30min: Should be within 10%
- Check for gradual increase

## Test Result Template

```
Test: [Test Name]
Date: [Date]
Tester: [Name]
TouchOSC Version: [Version]
Device: [iPad model/iOS version]

Setup:
- Band tracks: [number]
- Master tracks: [number]
- Total groups: [number]

Results:
- [ ] Pass/Fail: [Overall result]
- [ ] All criteria met: Yes/No
- Performance metrics:
  - Startup time: [X]ms
  - Refresh time: [X]ms
  - Memory start: [X]MB
  - Memory end: [X]MB

Issues Found:
1. [Issue description]
   - Severity: High/Medium/Low
   - Reproducible: Yes/No
   - Workaround: [If any]

Notes:
[Any additional observations]
```

## Automated Test Script

Create a test helper script for automated testing:

```lua
-- test_helper.lua
-- Version: 1.0.0
-- Automated testing utilities

local VERSION = "1.0.0"

function init()
    print("Test Helper v" .. VERSION .. " loaded at " .. os.date("%X"))
end

-- Performance timer
local timers = {}

function startTimer(name)
    timers[name] = os.clock()
    print("Timer started: " .. name)
end

function stopTimer(name)
    if timers[name] then
        local elapsed = os.clock() - timers[name]
        print(string.format("Timer %s: %.3f seconds", name, elapsed))
        timers[name] = nil
        return elapsed
    end
end

-- Memory monitoring
function checkMemory(label)
    collectgarbage("collect")
    local mem = collectgarbage("count")
    print(string.format("Memory %s: %.2f KB", label or "check", mem))
    return mem
end

-- Bulk group creation helper
function createTestGroups(count, prefix)
    startTimer("group_creation")
    -- Note: This would need UI automation
    print(string.format("Please create %d groups with prefix '%s_'", count, prefix))
    stopTimer("group_creation")
end

-- Stress test faders
function stressFaders()
    print("=== FADER STRESS TEST ===")
    startTimer("fader_stress")
    
    -- Simulate rapid fader movements
    -- This would need to trigger actual fader controls
    
    stopTimer("fader_stress")
end

-- Connection test
function testConnections()
    print("=== CONNECTION TEST ===")
    local config = getConfiguration()
    if config then
        print("Band connection: " .. (config.connections.band or "not set"))
        print("Master connection: " .. (config.connections.master or "not set"))
    else
        print("ERROR: No configuration found")
    end
end

-- Export test functions
_G.testHelper = {
    startTimer = startTimer,
    stopTimer = stopTimer,
    checkMemory = checkMemory,
    stressFaders = stressFaders,
    testConnections = testConnections
}

init()
```

## Production Readiness Checklist

### Pre-Production
- [ ] All Phase 3 tests passed
- [ ] Performance benchmarks met
- [ ] No critical issues found
- [ ] Backup of current setup created
- [ ] Rollback plan documented

### Documentation Complete
- [ ] User guide written
- [ ] Troubleshooting guide ready
- [ ] Video tutorial recorded
- [ ] Quick reference created

### Deployment Ready
- [ ] Primary device tested
- [ ] Backup devices tested
- [ ] Network configuration documented
- [ ] Support contact established

### Sign-off
- [ ] Technical testing complete
- [ ] User acceptance received
- [ ] Documentation approved
- [ ] Deployment scheduled

## Known Limitations
1. Maximum practical group limit: ~50
2. Network latency affects response time
3. OSC pattern limitations in TouchOSC
4. No automatic track discovery

## Risk Mitigation
1. **Performance degradation**: Limit to 30 groups initially
2. **Network issues**: Document network requirements
3. **User confusion**: Provide clear visual feedback
4. **Script errors**: Comprehensive error handling

## Success Criteria
- All tests pass with 20+ groups
- Performance remains acceptable
- No data corruption or loss
- User feedback positive
- System stable for extended use

---

## Test Execution Log

### Session 1: [Date]
- Tests completed: 
- Issues found: 
- Time spent: 

### Session 2: [Date]
- Tests completed: 
- Issues found: 
- Time spent: 

### Session 3: [Date]
- Tests completed: 
- Issues found: 
- Time spent: