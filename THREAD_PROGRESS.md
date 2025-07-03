# Thread Progress Tracking

## CRITICAL CURRENT STATE
**⚠️ EXACTLY WHERE WE ARE RIGHT NOW:**
- [ ] Currently working on: REDESIGNING return track implementation
- [ ] Waiting for: Implementation of auto-detection approach
- [ ] Blocked by: Need to implement unified track script approach

## Implementation Status
- Phase: REDESIGN IN PROGRESS
- Step: Architecture redesign based on auto-detection
- Status: PLANNING - Design approach confirmed

## CRITICAL ISSUE IDENTIFIED
The previous implementation has fundamental design flaws:
- ❌ Treats return tracks as separate connection type (`connection_return`)
- ❌ Creates duplicate scripts in `/scripts/return/`
- ❌ NOT TESTED - previous thread incorrectly marked as tested
- ❌ Forces users to use `return_` prefix

## NEW DESIGN APPROACH (CONFIRMED)
**Automatic Track Type Detection:**
1. User creates groups with standard naming: `band_TrackName` or `master_TrackName`
2. Scripts automatically detect if track is regular or return by:
   - Query `/live/song/get/track_names`
   - Query `/live/song/get/return_track_names`
   - Find where the track exists and set type accordingly
3. Scripts use appropriate OSC paths based on detected type:
   - Regular tracks: `/live/track/...`
   - Return tracks: `/live/return/...`
4. Completely transparent to users - they don't need to know track type
5. Only requirement: No duplicate names between tracks and returns

## Benefits of New Approach
- ✅ No special prefixes needed
- ✅ Works with existing templates
- ✅ Uses same connection (band/master) for all tracks
- ✅ Single set of scripts for all track types
- ✅ User-friendly - no need to distinguish track types

## Implementation Plan
1. **Modify `/scripts/track/group_init.lua`**:
   - Add return track name query
   - Implement auto-detection logic
   - Store track type internally
   - Route to correct OSC paths

2. **Update child scripts**:
   - `/scripts/track/fader_script.lua`
   - `/scripts/track/mute_button.lua`
   - `/scripts/track/pan_control.lua`
   - All scripts check parent's track type

3. **Remove old implementation**:
   - Delete entire `/scripts/return/` directory
   - Remove return-specific documentation

4. **Update documentation**:
   - Explain auto-detection
   - Remove `return_` prefix instructions
   - Update examples

## Testing Status Matrix
| Component | Implemented | Unit Tested | Integration Tested | Multi-Instance Tested | 
|-----------|------------|-------------|--------------------|-----------------------|
| AbletonOSC Fork | ✅ v1.0.0 | ❌ | ❌ | ❌ |
| Auto-Detection | ❌ | ❌ | ❌ | ❌ |
| Unified Scripts | ❌ | ❌ | ❌ | ❌ |

## Last User Action
- Date/Time: 2025-07-03 11:15
- Action: Confirmed auto-detection design approach
- Result: Ready to implement unified track scripts
- Next Required: Store state and begin implementation

## Next Steps
1. Implement auto-detection in group_init.lua
2. Update all child scripts to use parent's track type
3. Remove old return track implementation
4. Test with both regular and return tracks
5. Update all documentation

## Implementation Notes
- Track type stored in group's tag or script variable
- Child scripts access parent's track type
- All OSC paths dynamically built based on type
- Maintain backward compatibility for existing templates

## Original Solution Components (TO BE REPLACED)

### 1. AbletonOSC Fork (KEEP THIS)
- Repository: https://github.com/zbynekdrlik/AbletonOSC
- Branch: feature/return-tracks-support
- PR: https://github.com/zbynekdrlik/AbletonOSC/pull/2
- **STATUS: Fork is valid, TouchOSC implementation needs redesign**

### 2. TouchOSC Scripts Created (TO BE REMOVED)
- `scripts/return/` - Entire directory to be deleted
- Wrong approach using separate connection

### 3. Documentation (TO BE UPDATED)
- Remove references to `connection_return`
- Remove `return_` prefix requirement
- Update to explain auto-detection

## Summary of Redesign

The return track support will be reimplemented through:

1. **Keep AbletonOSC fork** - The `/live/return/` endpoints are still needed
2. **Unify track scripts** - Single set of scripts for all track types
3. **Auto-detection** - Scripts automatically determine track type
4. **Transparent to users** - No special naming or configuration needed

This maintains the goal of return track support while fixing the architectural issues.