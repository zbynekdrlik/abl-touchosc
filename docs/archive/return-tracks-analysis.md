# Return Tracks Control Analysis

## Research Summary (2025-07-02)

### Current Findings

#### AbletonOSC Documentation Claims
The AbletonOSC README states:
> "Represents an audio, MIDI, return or master track."

This suggests return tracks should be supported, but the documentation doesn't explain HOW to access them.

#### Key Questions
1. How are return tracks indexed in AbletonOSC?
2. Are they part of the regular track index or separate?
3. What OSC commands work with return tracks?

### Historical Context

#### LiveOSC/LiveOSC2 (Legacy)
The older LiveOSC2 project had explicit support for return tracks with dedicated commands:
- `/live/return/volume (int track_id, [float volume])`
- `/live/return/mute (int track_id, [int state])`
- `/live/return/solo (int track_id, [int state])`
- `/live/return/arm (int track_id, [int state])`
- `/live/return/panning (int track_id, [float panning])`
- `/live/return/send (int track_id, int send_id, [float value])`
- `/live/return/name (int track_id, [string name])`
- `/live/return/crossfader (int track_id, [int state])`
- `/live/return/select (int track_id)`

This clearly shows that return tracks were treated as a separate category with their own namespace.

#### AbletonOSC (Current)
- Claims to support return tracks but documentation is unclear
- Uses unified `/live/track/` commands for all track types
- No explicit `/live/return/` namespace found in documentation

### Technical Investigation Required

1. **Track Indexing**
   - Test if return tracks are indexed after regular tracks
   - Example: If you have 8 tracks + 2 returns, are returns track 8 and 9?
   - Or are they accessed differently?

2. **Track Type Detection**
   - Check if `/live/track/get/has_audio_input` differs for return tracks
   - Look for properties unique to return tracks

3. **Source Code Analysis**
   - Need to examine AbletonOSC's track.py implementation
   - Check how Live's API exposes return_tracks collection

### Ableton Live API Context

From Live API documentation:
- `song.tracks` - Collection of regular tracks
- `song.return_tracks` - Separate collection for return tracks
- `song.master_track` - Single master track

This suggests return tracks are a separate collection in Live's object model.

### Testing Plan

1. **Basic Discovery Test**
   ```
   /live/song/get/num_tracks
   /live/song/get/track_names
   ```
   Check if return track names appear in the list.

2. **Direct Access Test**
   Try accessing return tracks with indices continuing after regular tracks:
   ```
   /live/track/get/name [last_regular_track_index + 1]
   ```

3. **Property Query Test**
   Query all tracks to find unique properties of return tracks.

4. **Alternative Approaches**
   - Check if there's a `/live/song/get/return_track_names`
   - Look for `/live/song/get/num_return_tracks`

### Community Findings

From forum posts:
- Users have asked about return track access in AbletonOSC
- Some suggest looping through tracks to identify return tracks
- No clear documentation found on the correct approach

### Next Steps

1. Set up test environment with AbletonOSC
2. Create Ableton project with regular tracks and return tracks
3. Systematically test different indexing approaches
4. Document the actual implementation
5. Propose solution for TouchOSC integration

## Conclusion

While AbletonOSC claims to support return tracks, the actual implementation details are undocumented. Further testing is required to determine the correct approach for accessing and controlling return tracks.