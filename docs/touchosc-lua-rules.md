# TouchOSC Lua Development Rules & Guidelines

## Critical Concepts

### 1. Script Isolation
**Every script runs in complete isolation**
- Scripts cannot share variables or functions directly
- No global variables exist between scripts
- Each script has its own Lua context
- Scripts can only communicate via:
  - `notify()` function to send messages between controls
  - Parent/child control references
  - Control properties and values

### 2. Script Execution Order
- `init()` runs when entering control surface mode
- `update()` runs every frame
- Callback functions run in response to events
- Scripts on the same control run in the order they appear

## Color Management

### Using Color() Function
```lua
-- CORRECT - Use Color() constructor with RGBA values (0-1)
self.color = Color(1, 0, 0, 1)  -- Red
self.children.status_indicator.color = Color(0, 1, 0, 1)  -- Green

-- WRONG - Direct table assignment
self.color = {1, 0, 0}  -- This will fail!
```

### Common Colors
```lua
-- Status colors with alpha channel
local STATUS_COLORS = {
    green = Color(0, 1, 0, 1),      -- OK/Connected
    yellow = Color(1, 1, 0, 1),     -- Refreshing/Warning
    red = Color(1, 0, 0, 1),        -- Error/Disconnected
    orange = Color(1, 0.5, 0, 1),   -- Stale/Old data
    gray = Color(0.5, 0.5, 0.5, 1), -- Disabled/Inactive
}
```

## OSC Communication

### sendOSC with Connection Routing
```lua
-- CORRECT - Connection table as last parameter
local connections = {true, false, false, false, false, false, false, false, false, false}
sendOSC('/live/track/get/volume', trackIndex, connections)

-- CORRECT - Without arguments
sendOSC('/live/song/get/track_names', connections)

-- WRONG - Old syntax without connections
sendOSC('/live/track/get/volume', trackIndex)  -- This sends to ALL connections!
```

### Building Connection Tables
```lua
-- Helper function to build connection table
local function buildConnectionTable(connectionIndex)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    return connections
end

-- Usage
local connections = buildConnectionTable(2)  -- Only connection 2 will be true
```

### OSC Receive Patterns
- **IMPORTANT**: OSC receive patterns must be configured in TouchOSC editor UI
- Cannot be set programmatically via `self.properties.OSCReceive`
- Groups need their OSC receive pattern set to match expected messages

### onReceiveOSC Callback
```lua
function onReceiveOSC(message, connections)
    -- message structure:
    -- message[1] = path (string)
    -- message[2] = arguments (table of {tag, value} objects)
    
    -- connections is a boolean array showing which connection sent this
    
    -- IMPORTANT: Return values control message flow
    -- Return true = stop processing (message handled)
    -- Return false = continue to other controls
    
    if message[1] == '/my/path' then
        -- Process message
        return true  -- Stop further processing
    end
    
    return false  -- Let other controls process this
end
```

## Property Access Pitfalls

### Control Properties
```lua
-- Properties that may not exist or be accessible:
-- - OSCReceive (cannot be set via script)
-- - Some properties are read-only
-- - Always check if property exists before accessing

-- Safe property access
if self.properties and self.properties.someProperty then
    -- Use property
end
```

### Control References
```lua
-- Always validate control references
local child = self.children.someChild
if child and child.values then
    child.values.x = 0.5
end

-- Check parent exists
if self.parent and self.parent.trackNumber then
    local trackNum = self.parent.trackNumber
end
```

## Inter-Script Communication

### Using notify()
```lua
-- Send notification to another control
targetControl:notify("refresh", optionalValue)

-- Receive notification
function onReceiveNotify(action, value)
    if action == "refresh" then
        -- Handle refresh
    end
end
```

### Parent-Child Data Sharing
```lua
-- Parent stores data in properties
self.trackNumber = 5
self.connectionIndex = 1

-- Child accesses parent data
local parent = self.parent
if parent and parent.trackNumber then
    local track = parent.trackNumber
end
```

## Control Management

### Finding Controls
```lua
-- Find by name (returns first match)
local button = self:findByName("myButton")

-- Find all by property
local groups = root:findAllByProperty("tag", "trackGroup", true)

-- Find with recursive search
local control = root:findByName("deepChild", true)  -- true = recursive
```

### Disabling Controls Safely
```lua
-- Set interactive property
control.interactive = false

-- Visual feedback for disabled state
if control.color then
    control.color = Color(0.3, 0.3, 0.3, 0.5)  -- Dimmed
end

-- Reset fader values when disabling
if control.type == ControlType.FADER and control.values then
    control.values.x = 0
end
```

## Error Handling Best Practices

### Always Validate Before Use
```lua
-- Check all references in chain
function safeGetValue()
    if not self.parent then return nil end
    if not self.parent.children then return nil end
    if not self.parent.children.fader then return nil end
    if not self.parent.children.fader.values then return nil end
    return self.parent.children.fader.values.x
end
```

### Protected Calls
```lua
-- Use pcall for risky operations
local success, result = pcall(function()
    return someRiskyOperation()
end)

if success then
    -- Use result
else
    log("Error:", result)
end
```

## Logging Best Practices

### Console vs Visual Logger
```lua
-- Always use print() for console output
print("Debug message")

-- Create visual logger for user-facing messages
local function log(...)
    -- Print to console first
    print(...)
    
    -- Then update visual logger if it exists
    local logger = root:findByName("logger")
    if logger and logger.values then
        -- Update logger text
    end
end
```

### Version Logging
```lua
-- ALWAYS log version on startup
local SCRIPT_VERSION = "1.5.1"
print("MyScript v" .. SCRIPT_VERSION .. " loaded")
```

## Common Gotchas

### 1. Script Load Order
- Helper scripts should be on root control
- They load before group scripts
- Cannot rely on other scripts being loaded

### 2. Frame Updates
- `update()` runs 60 times per second
- Avoid heavy operations in update()
- Use state flags to control update behavior

### 3. String Matching
```lua
-- Exact matching is safer for track names
if trackName == searchName then  -- Exact
    -- Found
end

-- Avoid pattern matching for critical operations
if trackName:find(searchName) then  -- Risky!
    -- May match wrong track
end
```

### 4. Connection Indices
- TouchOSC connections are 1-indexed (1-10)
- Connection 0 doesn't exist
- Always validate connection index is in range

### 5. Message Arguments
```lua
-- OSC arguments are tables with tag and value
local arg = message[2][1]  -- First argument
if arg then
    local value = arg.value  -- Actual value
    local tag = arg.tag      -- Type tag ('f', 'i', 's', etc.)
end
```

## Safety Guidelines

### 1. Track Mapping Safety
- Always use exact name matching for tracks
- Clear old track numbers before remapping
- Disable controls when track not found
- Stop OSC listeners before remapping

### 2. Connection Safety
- Validate connection index before use
- Handle missing connections gracefully
- Test with connections disabled

### 3. UI Feedback
- Always provide visual status indicators
- Use consistent color coding
- Show clear error states
- Log important operations

## Performance Considerations

### 1. Avoid Repeated Operations
```lua
-- Cache frequently used values
local parent = self.parent  -- Cache reference
if parent then
    -- Use cached reference multiple times
end
```

### 2. Minimize update() Work
```lua
function update()
    -- Use early returns
    if not self.needsUpdate then return end
    
    -- Do work only when needed
    self.needsUpdate = false
end
```

### 3. Batch OSC Messages
```lua
-- Send multiple values at once when possible
-- Instead of multiple sendOSC calls
```

## Testing Checklist

- [ ] Test with Ableton disconnected
- [ ] Test with wrong track names
- [ ] Test with track reordering
- [ ] Test with missing child controls
- [ ] Test with disabled connections
- [ ] Check all error paths
- [ ] Verify visual feedback
- [ ] Check performance with many controls
- [ ] Test script reload scenarios

## Summary of Key Rules

1. **Scripts are isolated** - no shared variables
2. **Use Color() constructor** - not table literals
3. **OSC needs connection tables** - specify routing
4. **Return values matter** in onReceiveOSC
5. **Always validate references** before use
6. **Exact matching for safety** - avoid patterns
7. **Disable controls when unmapped** - prevent errors
8. **Log versions on startup** - track deployments
9. **Visual feedback is critical** - show states
10. **Test error conditions** - not just happy path
