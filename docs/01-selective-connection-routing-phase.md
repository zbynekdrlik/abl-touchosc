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

2. **Child Control Script Updates (Sending):**
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

3. **Child Control Script Updates (Receiving):**
```lua
function onReceiveOSC(message, connections)
    -- Get expected connection for this control
    local parentTag = self.parent.tag
    local instance, trackNumber = parseParentTag(parentTag)
    local expectedConnection = getConnectionIndex(instance)
    
    -- Only process if message came from expected connection
    if not connections[expectedConnection] then
        return  -- Ignore messages from wrong connection
    end
    
    -- Process the message
    local path = message[1]
    local arguments = message[2]
    
    -- Extract value and update control
    if arguments[1] then
        self.values.x = arguments[1].value
    end
end
```

#### Phase 4: OSC Message Receiving Behavior

**Key Points:**
- `onReceiveOSC(message, connections)` receives ALL incoming OSC messages that match the control's address
- The `connections` parameter is a table of booleans indicating which connection(s) the message came from
- Example: `{true, false, false, ...}` means message came from Connection 1
- Script must filter messages based on the expected connection

**Important:** Controls using GUI OSC message configuration will need to:
1. Either keep GUI receive enabled but add script filtering
2. Or disable GUI receive and handle everything in script

#### Phase 5: Migration from GUI OSC to Script-Based
For controls currently using OSC GUI selector:
1. Keep OSC message address configuration (for matching)
2. Add `onReceiveOSC` function to filter by connection
3. Or completely move to script-based OSC handling

### Benefits of This Approach
✅ **Minimal Changes**: Extends existing architecture rather than replacing it  
✅ **Visual Clarity**: Group names clearly show routing in editor  
✅ **Flexible**: Easy to add more Ableton instances (e.g., "drums_Kick 1")  
✅ **Maintains Features**: Track number discovery still works  
✅ **Centralized Logic**: Routing determined by group name, inherited by children  
✅ **Bidirectional Control**: Both sending and receiving respect connection routing

### Technical Considerations

#### Connection Filtering
- Scripts receive messages from ALL connections
- Must check `connections` parameter to filter
- Connection indices are 1-based
- Can process messages from multiple connections if needed

#### Performance
- Filtering in script adds minimal overhead
- Early return if wrong connection
- No need to parse messages from wrong source

#### Error Handling
```lua
function onReceiveOSC(message, connections)
    -- Validate inputs
    if not message or not connections then return end
    if not self.parent or not self.parent.tag then return end
    
    -- Get expected connection
    local instance = parseInstanceFromParentTag(self.parent.tag)
    local expectedConnection = getConnectionIndex(instance)
    
    -- Filter by connection
    if not connections[expectedConnection] then
        return  -- Wrong connection, ignore
    end
    
    -- Process message...
end
```

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
4. Test bidirectional communication with connection filtering
5. Document script templates for team use
6. Plan full migration schedule

## Example Implementation

### Complete Fader Script with Connection Routing:
```lua
-- Fader script with connection-aware sending and receiving
function onValueChanged(key)
    if key == "x" and self.values.touch then
        -- Get routing info from parent
        local parentTag = self.parent.tag
        local instance, trackNumber = parseParentTag(parentTag)
        local connectionIndex = getConnectionIndex(instance)
        
        -- Build connection table (only send to one connection)
        local connections = {}
        for i = 1, 10 do
            connections[i] = (i == connectionIndex)
        end
        
        -- Send to specific connection
        local address = string.format("/live/track/%d/volume", trackNumber)
        sendOSC(address, {self.values.x}, connections)
    end
end

function onReceiveOSC(message, connections)
    -- Get expected connection
    local parentTag = self.parent.tag
    local instance, trackNumber = parseParentTag(parentTag)
    local expectedConnection = getConnectionIndex(instance)
    
    -- Filter by connection
    if not connections[expectedConnection] then
        return  -- Ignore messages from other connections
    end
    
    -- Process message
    local path = message[1]
    local arguments = message[2]
    
    if arguments[1] then
        self.values.x = arguments[1].value
    end
end

-- Helper functions
function parseParentTag(tag)
    local instance, trackNum = tag:match("([^:]+):(.+)")
    return instance, tonumber(trackNum)
end

function getConnectionIndex(instance)
    if instance == "band" then
        return 1
    elseif instance == "master" then
        return 2
    else
        return 1
    end
end
```