# Return Track Implementation Phases

## Overview
This document outlines the phased approach for implementing return track support in the ABL TouchOSC control surface. Each phase builds upon the previous, with clear validation points and decision gates.

---

## Phase 0: Discovery & Testing ✅
**Status: COMPLETE**  
**Duration: 1 day**  
**Objective: Determine how AbletonOSC exposes return tracks**

### Sub-phases:
#### 0.1 Research & Documentation ✅
- [x] Research AbletonOSC documentation
- [x] Analyze legacy LiveOSC implementation
- [x] Document findings
- [x] Create test plan

#### 0.2 Test Script Development ✅
- [x] Create Python discovery script
- [x] Create TouchOSC test functions
- [x] Document test procedures

#### 0.3 Source Code Analysis ✅
- [x] Analyzed AbletonOSC source documentation
- [x] Confirmed return track support
- [x] Identified extended indexing approach

### Deliverables:
- Research documentation ✅
- Test scripts ✅
- Source code analysis ✅

### Decision: Implementation Approach
**Confirmed: Option A - Extended Indexing**
- Return tracks use the same `/live/track/` API
- Indices continue after regular tracks
- Example: tracks 0-5 (regular), 6-7 (returns), 8 (master)
- Identification via name pattern or missing properties

---

## Phase 1: Core Implementation 🚀
**Duration: 2-3 days**  
**Objective: Implement basic return track discovery and control**

### Sub-phases:
#### 1.1 Track Discovery Extension
- [ ] Modify `group_init.lua` to discover return tracks
- [ ] Implement track type detection
- [ ] Add return track indexing logic
- [ ] Version: 2.0.0 (major change)

```lua
-- Implementation approach
function discoverAllTracks()
    -- Get total track count (includes returns + master)
    local total_tracks = query("/live/song/get/num_tracks")
    
    -- Continue indexing beyond regular track count
    for i = 0, total_tracks - 1 do
        local name = query("/live/track/get/name", i)
        local track_type = detectTrackType(i, name)
        -- Store track with type metadata
    end
end

function detectTrackType(index, name)
    -- Check name patterns
    if string.match(name, "Return") then
        return "return"
    end
    -- Check for master track (usually last)
    if index == total_tracks - 1 then
        return "master"
    end
    -- Default to regular track
    return "regular"
end
```

#### 1.2 Track Type System
- [ ] Create track type enumeration
- [ ] Add type detection function
- [ ] Store track type in group tag
- [ ] Update existing scripts to respect track type

#### 1.3 Basic Control Verification
- [ ] Test volume control on returns
- [ ] Test mute functionality
- [ ] Test meter readings
- [ ] Verify pan control

### Deliverables:
- Updated `group_init.lua` with return support
- Track type detection system
- Basic functionality test results

### Validation:
- [ ] Return tracks discovered automatically
- [ ] Controls work without errors
- [ ] No regression in regular track functionality

---

## Phase 2: Configuration & Routing
**Duration: 2 days**  
**Objective: Enable configuration of return track behavior**

### Sub-phases:
#### 2.1 Configuration Extension
- [ ] Add return track configuration options
- [ ] Document new configuration parameters
- [ ] Update configuration parser

```yaml
# New configuration options
show_returns: true
return_position: 'after_tracks' # or 'separate'
return_color: '#4A90E2'
```

#### 2.2 Connection Routing
- [ ] Ensure multi-connection support for returns
- [ ] Test return tracks with different connections
- [ ] Update connection filtering logic

#### 2.3 Group Management
- [ ] Handle return track groups differently
- [ ] Add visual differentiation options
- [ ] Update auto-unfold logic

### Deliverables:
- Extended configuration system
- Return track routing support
- Configuration documentation

### Validation:
- [ ] Configuration changes take effect
- [ ] Return tracks route correctly
- [ ] Visual differentiation works

---

## Phase 3: Send Level Controls
**Duration: 3 days**  
**Objective: Implement send level controls from regular tracks**

### Sub-phases:
#### 3.1 Send Control Script
- [ ] Create `send_control.lua` script
- [ ] Implement send level adjustment
- [ ] Add visual feedback for send levels
- [ ] Version: 1.0.0

#### 3.2 Send Discovery
- [ ] Detect available sends per track
- [ ] Map sends to return tracks
- [ ] Handle variable send counts

#### 3.3 UI Integration
- [ ] Design send control UI elements
- [ ] Add to track groups
- [ ] Implement pre/post toggle

### Deliverables:
- Send control script
- UI design for sends
- Send routing documentation

### Validation:
- [ ] Send levels adjust correctly
- [ ] Visual feedback accurate
- [ ] No audio glitches

---

## Phase 4: UI/UX Enhancement
**Duration: 2 days**  
**Objective: Polish the user interface for return tracks**

### Sub-phases:
#### 4.1 Visual Design
- [ ] Create return track color scheme
- [ ] Design return track layout
- [ ] Add clear labeling

#### 4.2 TouchOSC Template Update
- [ ] Add return track groups
- [ ] Position appropriately
- [ ] Test different screen sizes

#### 4.3 User Feedback
- [ ] Add return track indicators
- [ ] Improve status displays
- [ ] Create help documentation

### Deliverables:
- Updated TouchOSC template
- Visual design documentation
- User guide updates

### Validation:
- [ ] Clear visual distinction
- [ ] Intuitive layout
- [ ] Positive user feedback

---

## Phase 5: Advanced Features
**Duration: 3 days**  
**Objective: Add professional features for return track control**

### Sub-phases:
#### 5.1 Send Matrix View
- [ ] Create matrix layout option
- [ ] Show all send routings
- [ ] Enable quick send adjustments

#### 5.2 Return Track Soloing
- [ ] Implement solo-in-place
- [ ] Add AFL/PFL options
- [ ] Test with multiple returns

#### 5.3 Automation Support
- [ ] Enable automation recording
- [ ] Add automation indicators
- [ ] Test with Live's automation

### Deliverables:
- Matrix view implementation
- Solo system
- Automation support

### Validation:
- [ ] Matrix view functional
- [ ] Solo works correctly
- [ ] Automation records/plays

---

## Phase 6: Testing & Documentation
**Duration: 2 days**  
**Objective: Comprehensive testing and documentation**

### Sub-phases:
#### 6.1 Integration Testing
- [ ] Test with various Live projects
- [ ] Test with 0-12 return tracks
- [ ] Performance testing
- [ ] Edge case testing

#### 6.2 Documentation Update
- [ ] Update README.md
- [ ] Create return track guide
- [ ] Update technical docs
- [ ] Add troubleshooting section

#### 6.3 Release Preparation
- [ ] Version all scripts
- [ ] Create changelog
- [ ] Prepare release notes
- [ ] Update PR description

### Deliverables:
- Test report
- Complete documentation
- Release package

### Validation:
- [ ] All tests pass
- [ ] Documentation complete
- [ ] User approval

---

## Phase 7: Release & Monitor
**Duration: 1 day**  
**Objective: Release and monitor adoption**

### Sub-phases:
#### 7.1 Release
- [ ] Merge PR to main
- [ ] Tag release version
- [ ] Announce to users

#### 7.2 Monitor
- [ ] Track user feedback
- [ ] Monitor for issues
- [ ] Plan improvements

### Deliverables:
- Released version
- Monitoring plan
- Feedback collection

---

## Risk Mitigation

### Risk 1: ~~AbletonOSC Doesn't Support Returns~~ ✅ RESOLVED
**Resolution:** Source analysis confirms full support via extended indexing

### Risk 2: Performance Impact
**Mitigation:**
- Optimize discovery process
- Cache return track information
- Add option to disable return support

### Risk 3: Complex Configuration
**Mitigation:**
- Provide sensible defaults
- Create setup wizard
- Extensive documentation

---

## Success Criteria

1. **Functional**
   - [ ] Return tracks discovered automatically
   - [ ] All controls work on return tracks
   - [ ] Send levels adjustable
   - [ ] Multi-connection support maintained

2. **Performance**
   - [ ] No noticeable lag
   - [ ] Startup time < 2 seconds
   - [ ] Smooth control response

3. **Usability**
   - [ ] Clear visual design
   - [ ] Intuitive controls
   - [ ] Minimal configuration required
   - [ ] Comprehensive documentation

---

## Timeline Summary

| Phase | Duration | Dependencies | Status |
|-------|----------|--------------|--------|
| 0 | 1 day | None | ✅ COMPLETE |
| 1 | 2-3 days | Phase 0 results | 🚀 STARTING |
| 2 | 2 days | Phase 1 | ⏳ Pending |
| 3 | 3 days | Phase 1 | ⏳ Pending |
| 4 | 2 days | Phase 1-3 | ⏳ Pending |
| 5 | 3 days | Phase 1-4 | ⏳ Pending |
| 6 | 2 days | All phases | ⏳ Pending |
| 7 | 1 day | Phase 6 | ⏳ Pending |

**Total: 15-16 days** (Phase 0 complete)

---

## Next Immediate Steps

1. **Start Phase 1.1:**
   - Open `group_init.lua` 
   - Add extended track discovery logic
   - Implement track type detection
   - Test with sample project

2. **Implementation Details:**
   - Use `/live/song/get/num_tracks` for total count
   - Query each track index for properties
   - Identify return tracks by name or properties
   - Store metadata in group tags

3. **Testing:**
   - Create test project with various track configurations
   - Verify all return tracks are discovered
   - Ensure controls function properly

---

## Notes

- Each phase produces working code
- User can test at any phase
- Rollback possible at phase boundaries
- Documentation updated continuously
- Version numbers increment with each change