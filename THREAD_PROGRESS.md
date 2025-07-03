# Thread Progress Tracking

## CRITICAL CURRENT STATE
**⚠️ EXACTLY WHERE WE ARE RIGHT NOW:**
- [x] Group init script updated with auto-detection (v1.14.0)
- [x] Currently testing group auto-detection
- [x] Regular tracks working (go green when mapped)
- [ ] Return tracks NOT working (stay red)
- [ ] Waiting for: Debug logs to diagnose return track issue

## Testing Results So Far

### ✅ What Works:
1. **Regular track detection** - `master_CG #` successfully maps and goes green
2. **OSC patterns** - Group requires explicit patterns (no wildcards)
3. **Track label** - Shows parsed track name from group name

### ❌ What Doesn't Work:
1. **Return track detection** - `master_Repro LR #` stays red, not mapping
2. **TouchOSC wildcards** - `/live/*/get/*` pattern doesn't work

## Key Findings

### TouchOSC Pattern Requirements
- **No wildcard support** in receive patterns
- Must define explicit patterns
- Required patterns for group (6 total):
  ```
  /live/song/get/track_names
  /live/song/get/return_track_names
  /live/track/get/output_meter_level
  /live/track/get/volume
  /live/return/get/output_meter_level
  /live/return/get/volume
  ```

### Current Issue: Return Track Not Mapping
**Symptoms:**
- Regular track `master_CG #` → Maps correctly, goes green
- Return track `master_Repro LR #` → Doesn't map, stays red

**Possible Causes:**
1. **Name mismatch** - Return track name in Ableton might be different
2. **AbletonOSC fork** - Original version might be running instead of fork
3. **OSC response** - `/live/song/get/return_track_names` might be empty
4. **Script parsing** - Special characters in name might cause issues

## Debug Steps Needed

1. **Check exact return track name in Ableton**
   - Often named like "A-Reverb" or "Return A"
   - Must match exactly (case sensitive)

2. **Verify in TouchOSC console:**
   - Outgoing: `/live/song/get/return_track_names`
   - Incoming: Should contain return track names
   - Log messages from script

3. **Verify AbletonOSC fork is installed:**
   - Should be from: https://github.com/zbynekdrlik/AbletonOSC
   - Branch: feature/return-tracks-support

4. **Check for script errors:**
   - Any errors in TouchOSC console
   - Script version message

## Implementation Status
- Phase: TESTING AND DEBUGGING
- Step: Diagnosing return track detection issue
- Status: Regular tracks work, return tracks need fixing

## Code Status

### ✅ Completed:
1. **group_init.lua v1.14.0**:
   - Auto-detection logic implemented
   - Queries both track types
   - Dynamic OSC routing
   - Regular tracks working

### 🔧 Needs Investigation:
- Why return track detection fails
- OSC response for return track names
- Exact name matching logic

### ❌ Pending:
- Child script updates (waiting until group works)
- Old return implementation removal
- Documentation updates

## Last User Action
- Date/Time: 2025-07-03 12:15
- Action: Tested group with regular and return tracks
- Result: Regular works, return doesn't
- Next Required: Check debug logs and exact return track names

## Next Debugging Steps
1. **Enable TouchOSC console logging**
2. **Press refresh on return track group**
3. **Capture:**
   - Exact OSC messages sent/received
   - Script log output
   - Any error messages
4. **Verify exact return track name in Ableton**

## Technical Notes
- Track label comes from group name (not OSC)
- Pattern `(%w+)` in label parsing excludes special chars
- Script should log track type when mapped
- Status indicator: Red = unmapped, Green = mapped

## Questions to Answer
1. What does `/live/song/get/return_track_names` return?
2. Is the return track name exactly `Repro LR #`?
3. Are there any script errors in the console?
4. Is the forked AbletonOSC definitely installed?

Once we resolve the return track detection issue, we can proceed with updating child scripts.