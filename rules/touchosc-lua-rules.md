# TouchOSC Lua Critical Rules

## 1. Script Isolation is Absolute
```lua
-- ❌ IMPOSSIBLE - Scripts cannot share variables
_G.sharedVar = 123  -- Won't work
global.data = {}    -- Won't work

-- ✅ ALLOWED - Communication methods
control:notify("action", value)           -- Send notification
self.parent.propertyName = value         -- Parent/child properties
self.children.childName.values.x = 0.5   -- Access child controls
```

## 2. Inter-Script Communication via notify()
```lua
-- Send notification to any control
root:notify("register_logger", self)
targetControl:notify("refresh_tracks")

-- Receive notifications
function onReceiveNotify(action, value)
    if action == "register_logger" then
        logger = value  -- Store reference
    end
end

-- Practical example: Control registration pattern
function init()
    -- Control registers itself with document script
    root:notify("register_configuration", self)
end
```

## 3. Colors Must Use Constructor
```lua
-- ❌ WRONG
self.color = {1, 0, 0, 1}

-- ✅ CORRECT  
self.color = Color(1, 0, 0, 1)
```

## 4. OSC Connection Routing is Required
```lua
-- ❌ WRONG - Sends to ALL connections
sendOSC('/live/track/set/volume', 0, 0.5)

-- ✅ CORRECT - Specify target connection
local connections = {false, true, false, false, false, false, false, false, false, false}
sendOSC('/live/track/set/volume', 0, 0.5, connections)

-- Helper function
function createConnectionTable(index)
    local connections = {}
    for i = 1, 10 do connections[i] = (i == index) end
    return connections
end
```

## 5. OSC Receive Return Values Matter
```lua
function onReceiveOSC(message, connections)
    if message[1] == '/my/path' then
        -- Process message
        return true   -- ✅ Stop propagation
    end
    return false      -- ✅ Allow other controls to process
end
```

## 6. Always Validate References
```lua
-- ❌ RISKY
self.parent.trackNumber = 5

-- ✅ SAFE
if self.parent then
    self.parent.trackNumber = 5
end

-- ✅ SAFER for chains
local parent = self.parent
if parent and parent.children and parent.children.fader then
    parent.children.fader.values.x = 0.5
end
```

## 7. Control Finding Methods
```lua
-- Find single control (first match)
local ctrl = root:findByName("myControl", true)  -- true = recursive

-- Find multiple controls by property
local groups = root:findAllByProperty("tag", "trackGroup", true)

-- ⚠️ No findAllByName() method exists!
```

## 8. OSC Receive Patterns Must Be Set in UI
- Cannot be set via script
- Must configure in TouchOSC Editor OSC tab
- Each control needs its own pattern configuration

## 9. Version Everything
```lua
local VERSION = "1.2.3"
function init()
    print("MyScript v" .. VERSION .. " loaded")
end
```

## 10. Property Storage Patterns
```lua
-- Store data on parent for children to access
self.trackNumber = 5
self.connectionIndex = 2

-- Child accesses parent data
local trackNum = self.parent and self.parent.trackNumber

-- Document script exposes helper functions
function getConnectionForInstance(instance)
    return config.connections[instance]
end
```

## Key Gotchas

1. **No global variables** between scripts - use notify()
2. **No shared memory** - each script is sandboxed
3. **OSC patterns** cannot be scripted - UI only
4. **Connection 0** doesn't exist - use 1-10
5. **Scripts load asynchronously** - can't assume order
6. **update() runs 60fps** - keep it light
7. **Messages have structure** - `message[2][1].value`

## Testing Checklist
- [ ] Test with missing controls
- [ ] Test with disconnected Ableton
- [ ] Test with wrong connection numbers
- [ ] Verify all notify() handlers
- [ ] Check version logging