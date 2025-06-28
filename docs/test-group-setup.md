# Test Group Setup Instructions

## Overview
Create 4 test groups to verify the selective connection routing functionality. Each group will test a different scenario.

## Prerequisites
Ensure you have:
1. Document script (v2.5.8) attached to root
2. Configuration text object with band/master connections defined
3. Logger text object working
4. Global refresh button (v1.2.1) ready

## Test Groups to Create

### Group 1: Valid Band Track - "band_Kick"
1. **Create Group Control**
   - Type: Group
   - Name: `band_Kick`
   - Size: Approximately 200x400 pixels
   - Position: Place in visible area

2. **Add Status Indicator**
   - Type: LED (or small rectangular indicator)
   - Name: `status_indicator`
   - Place at top of group
   - Size: ~20x20 pixels

3. **Configure OSC**
   - Select the group
   - Go to OSC tab
   - Set receive pattern: `/live/song/get/track_names`
   - Enable ONLY Connection 1 (band connection)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

### Group 2: Valid Master Track - "master_VOX 1"
1. **Create Group Control**
   - Type: Group
   - Name: `master_VOX 1`
   - Size: Approximately 200x400 pixels
   - Position: Next to Group 1

2. **Add Status Indicator**
   - Type: LED
   - Name: `status_indicator`
   - Place at top of group
   - Size: ~20x20 pixels

3. **Configure OSC**
   - Select the group
   - Go to OSC tab
   - Set receive pattern: `/live/song/get/track_names`
   - Enable ONLY Connection 2 (master connection)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

### Group 3: Non-existent Track - "band_FakeTrack"
1. **Create Group Control**
   - Type: Group
   - Name: `band_FakeTrack`
   - Size: Approximately 200x400 pixels
   - Position: Below Group 1

2. **Add Status Indicator**
   - Type: LED
   - Name: `status_indicator`
   - Place at top of group
   - Size: ~20x20 pixels

3. **Configure OSC**
   - Select the group
   - Go to OSC tab
   - Set receive pattern: `/live/song/get/track_names`
   - Enable ONLY Connection 1 (band connection)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

### Group 4: Wrong Connection - "band_VOX 1"
1. **Create Group Control**
   - Type: Group
   - Name: `band_VOX 1`
   - Size: Approximately 200x400 pixels
   - Position: Below Group 2

2. **Add Status Indicator**
   - Type: LED
   - Name: `status_indicator`
   - Place at top of group
   - Size: ~20x20 pixels

3. **Configure OSC**
   - Select the group
   - Go to OSC tab
   - Set receive pattern: `/live/song/get/track_names`
   - Enable ONLY Connection 1 (band connection)
   - Note: This tests wrong connection - track exists on master but we're checking band

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

## Visual Layout Suggestion
```
[Configuration]  [Logger.............]
                 [...................]
                 [...................]

[REFRESH ALL]

[band_Kick    ]  [master_VOX 1 ]
[○ status     ]  [○ status     ]
[             ]  [             ]
[             ]  [             ]

[band_FakeTrack] [band_VOX 1   ]
[○ status     ]  [○ status     ]
[             ]  [             ]
[             ]  [             ]
```

## Testing Steps

1. **Initial State Test**
   - Save and run the layout
   - All status indicators should be RED
   - Logger should show group initialization messages
   - Version numbers should be logged

2. **Connection Test**
   - Ensure Ableton is running with:
     - Connection 1: Band project with track named "Kick"
     - Connection 2: Master project with track named "VOX 1"

3. **Refresh Test**
   - Press the REFRESH ALL button
   - Watch the logger for refresh messages
   - Expected results:
     - Group 1 (band_Kick): Status turns GREEN
     - Group 2 (master_VOX 1): Status turns GREEN
     - Group 3 (band_FakeTrack): Status stays RED
     - Group 4 (band_VOX 1): Status stays RED

4. **Verify Logger Output**
   Should see messages like:
   ```
   === GLOBAL REFRESH ===
   Refreshing group: band_Kick
   Requesting track names for band_Kick
   Mapped band_Kick -> Track 0
   Refreshing group: master_VOX 1
   Requesting track names for master_VOX 1
   Mapped master_VOX 1 -> Track 3
   Refreshing group: band_FakeTrack
   No track found for band_FakeTrack
   Refreshing group: band_VOX 1
   No track found for band_VOX 1 on connection 1
   Refreshed 4 groups
   ```

## Next Steps
Once these basic groups are working:
1. Add fader controls to each group
2. Add meter displays
3. Add mute buttons
4. Add pan controls
5. Test each control type with the different group states

## Troubleshooting

### Status indicators don't change color
- Check OSC connections are properly configured
- Verify Ableton projects have the expected track names
- Check logger for error messages

### No initialization messages
- Ensure scripts are attached to the correct controls
- Check script file names match exactly
- Verify scripts are in the correct location

### Groups don't receive refresh
- Check group names match the pattern (prefix_trackname)
- Verify notify system is working
- Check document script is running

## Important Notes
- Group names must follow the pattern: `prefix_trackname`
- Prefixes (band/master) must match configuration
- OSC receive must be configured in the UI (can't be done via script)
- Each group needs its own status_indicator LED