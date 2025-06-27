# TouchOSC Selective Connection Routing - Phase Document

## Problem Statement
Currently, all TouchOSC objects broadcast to all configured connections. We need to route specific faders to different Ableton instances:
- Some faders → Ableton "band" instance
- Other faders → Ableton "master" instance

Each Ableton instance runs AbletonOSC on different ports/IPs.

## Current Architecture
- Groups are named same as Ableton tracks (e.g., 'Hand 1 #')
- On initialization, groups find their track number via track name
- Track number is stored in group.tag parameter
- Child scripts inherit parent tag as track number

## Recommended Solution: Prefix-Based Group Naming

### Overview
Extend the current group naming convention to include an Ableton instance prefix:
- Band tracks: `band_Hand 1 #`
- Master tracks: `master_Hand 1 #`

Scripts will parse the group name to determine both:
1. Which connection to use (based on prefix)
2. Which track to control (based on track name after prefix)

### Implementation Details

#### Phase 1: Connection Setup
```
Connection 1 - Band:
- Enabled: ✓
- Host: [Band Ableton IP]
- Send Port: [Band Port]
- Receive Port: [Optional]

Connection 2 - Master:
- Enabled: ✓
- Host: [Master Ableton IP]
- Send Port: [Master Port]
- Receive Port: [Optional]
```

#### Phase 2: Group Naming Convention
Update group names to include instance prefix:
```
Before: 'Hand 1 #'
After:  'band_Hand 1 #' or 'master_Hand 1 #'
```

#### Phase 3: Script Modifications

1. **Parent Group Script Updates:**
```lua
function init()
    -- Parse group name to extract instance and track name
    local fullName = self.name
    local instance, trackName = parseGroupName(fullName)
    
    -- Find track number as before, but search in specific Ableton instance
    local trackNumber = findTrackNumber(trackName, instance)
    
    -- Store both in tag (e.g., "band:3" or "master:5")
    self.tag = instance .. ":" .. trackNumber
end

function parseGroupName(name)
    -- Extract prefix and track name
    if name:sub(1, 5) == "band_" then
        return "band", name:sub(6)
    elseif name:sub(1, 7) == "master_" then
        return "master", name:sub(8)
    else
        -- Default fallback
        return "band", name
    end
end
```

2. **Child Control Script Updates:**
```lua
function onValueChanged()
    -- Parse parent tag to get instance and track number
    local parentTag = self.parent.tag
    local instance, trackNumber = parseParentTag(parentTag)
    
    -- Determine connection index
    local connectionIndex = getConnectionIndex(instance)
    
    -- Send OSC to specific connection
    local address = string.format("/live/track/%d/volume", trackNumber)
    sendOSC(address, {self.values.x}, {connectionIndex})
end

function parseParentTag(tag)
    -- Split "band:3" or "master:5"
    local instance, trackNum = tag:match("([^:]+):(.+)")
    return instance, tonumber(trackNum)
end

function getConnectionIndex(instance)
    if instance == "band" then
        return 1
    elseif instance == "master" then
        return 2
    else
        return 1  -- default
    end
end
```

#### Phase 4: Migration from GUI OSC to Script-Based
For controls currently using OSC GUI selector:
1. Disable OSC message in GUI
2. Add script with appropriate onValueChanged handler
3. Use parent tag to determine routing

### Benefits of This Approach
✅ **Minimal Changes**: Extends existing architecture rather than replacing it  
✅ **Visual Clarity**: Group names clearly show routing in editor  
✅ **Flexible**: Easy to add more Ableton instances (e.g., "drums_Kick 1")  
✅ **Maintains Features**: Track number discovery still works  
✅ **Centralized Logic**: Routing determined by group name, inherited by children  

### Migration Strategy
1. **Test Phase**: Create one test group with new naming
2. **Gradual Migration**: Convert groups one at a time
3. **Backwards Compatible**: Can run old and new groups simultaneously

### Technical Considerations
- Connection indices are 1-based in TouchOSC
- Scripts must handle both sending and receiving on correct connections
- Consider adding connection validation/fallback
- May need to update track discovery to search specific Ableton instance

## Alternative Solutions (Not Recommended)

### Option A: Per-Control Connection Selection
- Configure each control's connections individually in GUI
- ❌ Tedious for many controls
- ❌ No visual indication of routing in group names

### Option B: Separate Layouts
- Create separate TouchOSC layouts for band/master
- ❌ Requires switching between layouts
- ❌ Duplicated development effort

## Next Steps
1. Confirm connection details for both Ableton instances
2. Create test group with new naming convention
3. Update initialization script for track discovery
4. Convert one control from GUI OSC to script-based
5. Test bi-directional communication
6. Document script templates for team use
7. Plan full migration schedule