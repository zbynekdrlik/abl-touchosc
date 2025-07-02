# Thread Progress Tracking

## CRITICAL CURRENT STATE
**⚠️ EXACTLY WHERE WE ARE RIGHT NOW:**
- [ ] Currently working on: Analyzing return track support in AbletonOSC
- [ ] Created new feature branch: feature/return-tracks
- [ ] Initial research complete - documented findings
- [ ] Waiting for: Testing approach to verify return track access methods

## Implementation Status
- Phase: Research & Analysis
- Step: Understanding AbletonOSC's return track implementation
- Status: RESEARCH IN PROGRESS

## Feature: Add Send/Return Track Control
Enable control of Ableton's send/return tracks in addition to regular audio/MIDI tracks.

### Research Findings
1. **AbletonOSC claims support** - Documentation mentions "audio, MIDI, return or master track"
2. **No clear documentation** - How to access return tracks is undocumented
3. **Legacy LiveOSC had explicit support** - Used `/live/return/` namespace
4. **Testing required** - Need to determine actual implementation

### Key Questions
1. Are return tracks indexed after regular tracks?
2. Do they use same `/live/track/` commands?
3. Is there a separate API for return tracks?

## Testing Status Matrix
| Component | Researched | Documented | Implementation | Tested | 
|-----------|------------|------------|----------------|--------|
| Return track analysis | ✅ | ✅ | ❌ | ❌ |
| Access method | 🔄 | ❌ | ❌ | ❌ |
| TouchOSC integration | ❌ | ❌ | ❌ | ❌ |

## Previous Task Completed
- [x] db_meter_label.lua v2.4.0 - Production ready
- [x] PR #7 merged to main
- [x] Feature complete - no more work needed

## Documentation Created
- `docs/return-tracks-analysis.md` - Initial research findings

## Next Steps
1. Set up test environment with AbletonOSC
2. Create test Ableton project with return tracks
3. Test different indexing approaches:
   - Continue indices after regular tracks
   - Check for separate return track commands
   - Query track properties to identify return tracks
4. Document findings
5. Design implementation for TouchOSC

## User Context
User wants to control send/return tracks in Ableton, not just regular tracks. They suspect AbletonOSC doesn't fully implement return track control yet.

## Testing Plan Details

### Test 1: Track Indexing Discovery
```
/live/song/get/num_tracks
/live/song/get/track_names
```
See if return tracks appear in the count and names.

### Test 2: Extended Index Access
If we have 8 regular tracks + 2 returns:
```
/live/track/get/name 8
/live/track/get/name 9
```
Check if indices 8 and 9 access return tracks.

### Test 3: Property Identification
Query track properties to identify return tracks:
```
/live/track/get/has_audio_input [index]
/live/track/get/available_input_routing_types [index]
```

### Test 4: Alternative Commands
Check for undocumented return-specific commands:
```
/live/song/get/return_tracks
/live/song/get/num_return_tracks
/live/return/get/name 0
```

## Research Resources
- AbletonOSC GitHub: https://github.com/ideoforms/AbletonOSC
- Live Object Model docs: Ableton's official API documentation
- Legacy LiveOSC2: Shows how return tracks were handled before
- Forum discussions: Users asking about return track access