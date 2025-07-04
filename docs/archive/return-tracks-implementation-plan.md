# Return Track Implementation Plan

## Executive Summary

Based on research, AbletonOSC likely supports return tracks but the implementation is undocumented. We need to determine the access method through testing, then implement support in our TouchOSC control surface.

## Problem Statement

Users need to control send/return tracks in Ableton Live, not just regular audio/MIDI tracks. Return tracks are essential for:
- Reverb sends
- Delay sends  
- Parallel compression
- Other send effects

Current TouchOSC implementation only handles regular tracks.

## Technical Background

### Ableton Live Object Model
```
Song
├── tracks (TrackList) - Regular audio/MIDI tracks
├── return_tracks (TrackList) - Send/return tracks
└── master_track (Track) - Master track
```

### Historical Implementation (LiveOSC2)
```
/live/return/volume [track_id] [volume]
/live/return/mute [track_id] [state]
/live/return/solo [track_id] [state]
/live/return/arm [track_id] [state]
/live/return/panning [track_id] [panning]
/live/return/send [track_id] [send_id] [value]
/live/return/name [track_id] [name]
/live/return/select [track_id]
```

### AbletonOSC (Current - Unknown)
- Documentation mentions support but doesn't explain how
- Likely uses unified `/live/track/` namespace
- Index scheme unknown

## Implementation Approaches

### Approach 1: Extended Track Indexing
Return tracks indexed after regular tracks.

**Example:** 
- Tracks 0-7: Regular tracks
- Tracks 8-9: Return tracks A & B
- Track 10: Master track

**Pros:**
- Simple implementation
- Reuses existing track controls
- No new OSC patterns needed

**Cons:**
- Track indices change when adding/removing tracks
- No clear separation between track types

### Approach 2: Track Type Detection
Query track properties to identify type.

**Detection methods:**
- Check track name pattern (e.g., "A-Return", "B-Return")
- Check for unique properties (input routing availability)
- Check track position relative to master

**Pros:**
- More robust identification
- Works regardless of indexing scheme

**Cons:**
- Requires multiple OSC queries
- More complex implementation

### Approach 3: Hybrid Solution
Combine extended indexing with type detection for robustness.

## Proposed Solution

### Phase 1: Discovery & Testing
1. Create test script to discover return track access
2. Document exact AbletonOSC implementation
3. Verify all track properties work with returns

### Phase 2: Core Implementation
1. Extend track discovery to include return tracks
2. Add return track type identification
3. Update group initialization to handle returns

### Phase 3: UI Integration
1. Create return track groups in TouchOSC
2. Apply consistent styling (different color?)
3. Add send level controls

### Phase 4: Advanced Features
1. Send matrix view (track → return routing)
2. Pre/post fader send toggle
3. Return track input monitoring

## Code Architecture

### Track Type Enumeration
```lua
local TRACK_TYPE = {
    AUDIO = "audio",
    MIDI = "midi", 
    GROUP = "group",
    RETURN = "return",
    MASTER = "master"
}
```

### Extended Track Discovery
```lua
function discoverAllTracks()
    local tracks = {}
    
    -- Discover regular tracks
    local numTracks = queryNumTracks()
    for i = 0, numTracks - 1 do
        tracks[i] = discoverTrack(i)
    end
    
    -- Discover return tracks (if extended indexing)
    local returnStart = numTracks
    while true do
        local track = tryDiscoverTrack(returnStart)
        if not track then break end
        track.type = TRACK_TYPE.RETURN
        tracks[returnStart] = track
        returnStart = returnStart + 1
    end
    
    return tracks
end
```

### Track Type Detection
```lua
function detectTrackType(trackIndex)
    local name = getTrackName(trackIndex)
    
    -- Check name patterns
    if name:match("%-Return$") then
        return TRACK_TYPE.RETURN
    elseif name == "Master" then
        return TRACK_TYPE.MASTER
    end
    
    -- Check properties
    local hasInput = getTrackProperty(trackIndex, "has_audio_input")
    local canArm = getTrackProperty(trackIndex, "can_be_armed")
    
    if hasInput and canArm then
        return TRACK_TYPE.AUDIO
    elseif canArm and not hasInput then
        return TRACK_TYPE.MIDI
    end
    
    return TRACK_TYPE.AUDIO -- default
end
```

## Testing Protocol

### Test Environment Setup
1. Create Ableton project with:
   - 4 Audio tracks
   - 4 MIDI tracks  
   - 2 Group tracks
   - 3 Return tracks (A, B, C)
   - Master track

2. Name tracks clearly:
   - "Audio 1-4"
   - "MIDI 1-4"
   - "Drums", "Synths" (groups)
   - Default return names

### Test Cases

#### TC1: Track Discovery
```
Query: /live/song/get/num_tracks
Expected: ??? (need to test)

Query: /live/song/get/track_names  
Expected: ??? (need to test)
```

#### TC2: Extended Indexing
```
For i = 0 to 20:
    Query: /live/track/get/name [i]
    Log: index, name, error
```

#### TC3: Property Access
```
For each discovered track:
    Query: /live/track/get/volume
    Query: /live/track/get/mute
    Query: /live/track/get/output_meter_level
```

#### TC4: Control Testing
```
For each return track:
    Test: /live/track/set/volume [index] [value]
    Test: /live/track/set/mute [index] [state]
    Verify: Changes reflected in Ableton
```

## UI/UX Considerations

### Visual Differentiation
- Return tracks use different color scheme
- Positioned separately from regular tracks
- Clear "RETURN A/B/C" labeling

### Control Additions
- Send level controls on regular tracks
- Pre/post toggle per send
- Return track input gain

### Layout Options
1. **Integrated View**: Returns appear after regular tracks
2. **Separate Section**: Dedicated return track area
3. **Matrix View**: Grid showing all send routings

## Migration Path

### For Existing Users
1. Update scripts maintain compatibility
2. Return tracks appear automatically if present
3. No configuration changes required

### Configuration Extension
```yaml
# Existing
connection_band: 2
unfold_band: 'Band'

# New options
show_returns: true
return_position: 'after_tracks' # or 'separate'
return_color: '#4A90E2'
```

## Success Criteria

1. **Functional Requirements**
   - All return track controls working
   - Send levels controllable
   - Proper track identification

2. **Performance Requirements**  
   - No degradation in regular track performance
   - Efficient track discovery

3. **Usability Requirements**
   - Clear visual distinction
   - Intuitive control layout
   - Consistent with existing UX

## Risk Mitigation

### Risk: AbletonOSC doesn't support returns
**Mitigation**: Document limitation, consider alternative solutions

### Risk: Performance impact from extra tracks
**Mitigation**: Optimize discovery, cache track types

### Risk: Complex configuration
**Mitigation**: Smart defaults, auto-detection

## Timeline Estimate

- **Phase 1**: 1-2 days (discovery & testing)
- **Phase 2**: 2-3 days (core implementation)
- **Phase 3**: 1-2 days (UI integration)
- **Phase 4**: 2-3 days (advanced features)

**Total**: 6-10 days

## Conclusion

Return track support is essential for professional mixing workflows. While AbletonOSC's implementation is undocumented, systematic testing should reveal the access method. The proposed phased approach minimizes risk while delivering valuable functionality to users.