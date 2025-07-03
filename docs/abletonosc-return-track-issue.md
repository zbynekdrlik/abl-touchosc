# AbletonOSC Return Track Investigation Results

## Critical Finding
**AbletonOSC does NOT properly expose return tracks**, despite the Ableton Live API supporting them.

## Evidence

### 1. User Testing Results
- `/live/song/get/num_tracks` returns only regular track count (9 in user's case)
- Accessing index 9+ results in "Index out of range" error
- Return Track A exists in Ableton but is inaccessible via OSC

### 2. AbletonOSC Source Code Analysis

#### In `song.py` (line 138):
```python
self.osc_server.add_handler("/live/song/get/num_tracks", lambda _: (len(self.song.tracks),))
```
This only counts regular tracks, not return tracks.

#### Missing Implementation:
- No reference to `song.return_tracks` anywhere in the codebase
- No `/live/song/get/num_return_tracks` handler
- No `/live/return/` namespace

### 3. Ableton Live API Support
The Live API DOES support return tracks:
- `song.return_tracks` - List of return tracks
- `song.create_return_track()` - Creates return track
- `song.delete_return_track()` - Deletes return track

From the Live Object Model:
```
type Song
children return_tracks Track
```

## The Problem
AbletonOSC implements `create_return_track` and `delete_return_track` methods but provides NO way to access or control the created return tracks!

## Potential Solutions

### Option 1: Fork and Fix AbletonOSC
Add proper return track support:
```python
# Add to song.py
self.osc_server.add_handler("/live/song/get/num_return_tracks", 
    lambda _: (len(self.song.return_tracks),))

# Add to track.py to handle return tracks
def create_return_track_callback(func, *args):
    def callback(params):
        if params[0] == "*":
            track_indices = list(range(len(self.song.return_tracks)))
        else:
            track_indices = [int(params[0])]
        
        for track_index in track_indices:
            track = self.song.return_tracks[track_index]
            # ... rest of implementation
```

### Option 2: Use Extended Track Indexing
Modify AbletonOSC to include return tracks in the main track list:
```python
# Modified track enumeration
all_tracks = list(self.song.tracks) + list(self.song.return_tracks)
```

### Option 3: Separate Return Track Namespace
Add a new `/live/return/` namespace specifically for return tracks.

### Option 4: Alternative OSC Solutions
- Switch to a different OSC implementation that supports return tracks
- Use Max for Live to create a custom OSC bridge
- Implement a Python script that exposes return tracks properly

## Recommendation
The cleanest solution is Option 1 - fork AbletonOSC and add proper return track support. This would:
1. Maintain backward compatibility
2. Follow the existing API patterns
3. Provide full access to return track functionality

## Next Steps
1. Report this as a bug/feature request to ideoforms/AbletonOSC
2. Create a fork with return track support
3. Consider alternative OSC implementations
4. Temporary workaround: Use Ableton's internal routing instead of return tracks