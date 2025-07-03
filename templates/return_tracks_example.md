# Return Track TouchOSC Template Example

This document explains how to create TouchOSC templates for return track control using the new return track scripts.

## Prerequisites

1. **Forked AbletonOSC** with return track support installed
   - Download from: https://github.com/zbynekdrlik/AbletonOSC/tree/feature/return-tracks-support
   - Replace your existing AbletonOSC installation

2. **TouchOSC** (version 1.2.0 or later)

## Template Structure

### 1. Create a Return Track Group

Create a group control in TouchOSC with:
- **Name**: `return_A-Repro Sala LR` (match your return track name exactly)
- **Script**: `scripts/return/group_init.lua`

### 2. Add Controls to the Group

Inside the group, add these child controls:

#### Volume Fader
- **Type**: Fader
- **Name**: `fader`
- **Script**: `scripts/return/fader_script.lua`
- **Range**: 0.0 to 1.0
- **Orientation**: Vertical

#### Mute Button
- **Type**: Button
- **Name**: `mute`
- **Script**: `scripts/return/mute_button.lua`
- **Mode**: Toggle

#### Pan Control
- **Type**: Fader or Radial
- **Name**: `pan`
- **Script**: `scripts/return/pan_control.lua`
- **Range**: 0.0 to 1.0 (converts to -1 to 1 internally)

#### Track Label
- **Type**: Label
- **Name**: `track_label`
- **Text**: (will be set by script)

#### Status Indicator
- **Type**: Label or LED
- **Name**: `status_indicator`
- **Purpose**: Shows mapping status (red=unmapped, green=mapped)

### 3. Configuration Object

Create a text object named `configuration` with:
```
connection_return: 1
```

### 4. Refresh Button

Create a button that sends notification to refresh mappings:
- **Type**: Button
- **Script**: Notify all groups with `refresh_returns`

## Example Lua for Refresh Button

```lua
function onValueChanged()
    if self.values.x == 1 then
        -- Notify all return groups to refresh
        local groups = root:findAllByProperty("tag", "returnGroup", true)
        for _, group in ipairs(groups) do
            group:notify("refresh_returns")
        end
    end
end
```

## OSC Communication Flow

1. **On Template Load**:
   - Groups are disabled until mapped
   - Status indicators show red

2. **On Refresh**:
   - Sends: `/live/song/get/return_track_names`
   - Receives list of return track names
   - Maps groups to tracks by name matching
   - Enables controls and shows green status

3. **Control Messages**:
   - Volume: `/live/return/set/volume [track_index] [value]`
   - Mute: `/live/return/set/mute [track_index] [0/1]`
   - Pan: `/live/return/set/panning [track_index] [-1 to 1]`

4. **Listeners** (automatic updates from Ableton):
   - `/live/return/get/volume`
   - `/live/return/get/mute`
   - `/live/return/get/panning`
   - `/live/return/get/output_meter_level`

## Multiple Return Tracks

To control multiple return tracks:

1. Duplicate the return track group
2. Rename each group to match return track names:
   - `return_A-Reverb`
   - `return_B-Delay`
   - `return_C-Chorus`

3. The scripts will automatically map based on exact name matching

## Tips

- Return track names must match EXACTLY (case-sensitive)
- Use underscores instead of spaces in group names
- The status indicator helps debug mapping issues
- Check TouchOSC logs if controls aren't responding

## Troubleshooting

1. **Controls stay red/disabled**:
   - Check return track name matches exactly
   - Press refresh button
   - Verify AbletonOSC fork is installed

2. **No response to controls**:
   - Check OSC connection settings
   - Verify correct port (usually 11000)
   - Check connection_return configuration

3. **Values jump around**:
   - This is normal OSC sync behavior
   - Fader has 1-second sync delay after release