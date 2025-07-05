# Track Mismatch Diagnostic

This diagnostic tool helps identify why track 8 is responding as track 10 in your Ableton setup.

## How to use:

1. In TouchOSC, create a new document
2. Add a group with:
   - A button control (name it "button")
   - A label control (name it "status")
3. Copy the script from `scripts/diagnostics/track_mismatch_test.lua` to the group's script
4. Adjust the `connectionIndex` in the script if needed (default is 1)
5. Press the button to run the diagnostic

## What it does:

1. Gets the total track count from Ableton
2. Gets all track names
3. Sends a unique volume value to each track
4. Records which track responds
5. Reports any mismatches

## Expected output:

The script will log:
- All track names with their indices
- Any tracks that respond with the wrong index
- The offset between sent and received track numbers

## Common causes of track mismatches:

1. **Hidden tracks** - Tracks that are hidden in Ableton but still counted
2. **Group tracks** - Grouped tracks might affect numbering
3. **Master track** - Sometimes counted in the index
4. **Return tracks** - If accidentally included in regular track count
5. **AbletonOSC bug** - Issue in the OSC implementation

## What to look for:

If track 8 consistently responds as track 10, check if:
- There are 2 hidden tracks before track 8
- Track 8 is inside a group with 2 tracks
- The Master track is being counted twice
