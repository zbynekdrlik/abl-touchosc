# Test Group Setup Instructions

## Overview
Create 4 test groups to verify the selective connection routing functionality. Each group will test a different scenario.

## IMPORTANT: How Connection Routing Works
The entire system is designed so that the **group name determines the connection automatically**:
- Groups named `band_*` use the connection configured for "band" (from configuration)
- Groups named `master_*` use the connection configured for "master" (from configuration)
- **You do NOT need to set specific connections in the UI** - enable all connections and let the script filter!

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
   - **Enable ALL connections** (script will filter to use only connection 1)

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
   - **Enable ALL connections** (script will filter to use only connection 2)

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
   - **Enable ALL connections** (script will look only at connection 1)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

### Group 4: Wrong Connection - "band_VOX 1"
1. **Create Group Control**
   - Type: Group
   - Name: `band_VOX 1`
   - Size: Approximately 200x400 pixels
   - Position: Below Group 2
   - Note: This tests a track that exists on master but we're looking on band

2. **Add Status Indicator**
   - Type: LED
   - Name: `status_indicator`
   - Place at top of group
   - Size: ~20x20 pixels

3. **Configure OSC**
   - Select the group
   - Go to OSC tab
   - Set receive pattern: `/live/song/get/track_names`
   - **Enable ALL connections** (script will only check connection 1)

4. **Attach Group Script**
   - Select the group
   - Add script: `group_init.lua` (v1.5.1)

## How the Automatic Routing Works

For each group, the script will:
1. Parse the group name (e.g., "band_Kick" → instance: "band", track: "Kick")
2. Look up the connection for that instance in configuration
3. Only process OSC messages from that specific connection
4. Ignore messages from all other connections

This means:
- `band_*` groups only see tracks from the band Ableton (connection 1)
- `master_*` groups only see tracks from the master Ableton (connection 2)
- No manual connection filtering needed in TouchOSC UI!

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
   - Logger should show group initialization messages with connection info:
     ```
     Group config - Instance: band, Track: Kick, Connection: 1
     Group config - Instance: master, Track: VOX 1, Connection: 2
     Group config - Instance: band, Track: FakeTrack, Connection: 1
     Group config - Instance: band, Track: VOX 1, Connection: 1
     ```

2. **Connection Test**
   - Ensure Ableton is running with:
     - Connection 1: Band project with track named "Kick"
     - Connection 2: Master project with track named "VOX 1"

3. **Refresh Test**
   - Press the REFRESH ALL button
   - Watch the logger for refresh messages
   - Expected results:
     - Group 1 (band_Kick): Status turns GREEN (found on connection 1)
     - Group 2 (master_VOX 1): Status turns GREEN (found on connection 2)
     - Group 3 (band_FakeTrack): Status stays RED (not found on connection 1)
     - Group 4 (band_VOX 1): Status stays RED (not found on connection 1, even though it exists on connection 2)

4. **Verify Automatic Routing**
   The key test: Group 4 (band_VOX 1) should NOT find the track even though "VOX 1" exists on connection 2, because the "band_" prefix restricts it to only look at connection 1.

## Troubleshooting

### All groups stay red
- Check configuration text has correct connection assignments
- Verify both Ableton projects are connected
- Check OSC receive patterns are set correctly

### Wrong groups turn green
- This indicates the script filtering isn't working
- Verify script version is 1.5.1 or higher
- Check group names follow the exact pattern (prefix_trackname)

### No initialization messages
- Ensure scripts are attached to the groups
- Check script file names match exactly
- Verify scripts are in the correct location

## Important Notes
- Group names MUST follow the pattern: `prefix_trackname`
- Prefixes (band/master) determine which connection is used
- The script handles ALL connection filtering automatically
- You can enable all connections in the UI - the script will filter correctly