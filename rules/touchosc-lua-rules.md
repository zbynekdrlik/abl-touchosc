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
-- ⚠️ Controls can be in pagers - always use recursive search (true)
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

## 11. Centralized Logging Pattern
```lua
-- ❌ WRONG - Each script implementing its own logger
local function log(msg)
    local logger = root:findByName("logger", true)
    -- Duplicated code everywhere
end

-- ✅ CORRECT - Document script handles all logging
-- In document script:
local function log(message)
    local logMessage = os.date("%H:%M:%S") .. " " .. message
    print(logMessage)  -- Always print to console
    
    -- Store in buffer
    table.insert(logLines, logMessage)
    if #logLines > maxLogLines then
        table.remove(logLines, 1)
    end
    
    -- Update logger control if found
    if logger and logger.values then
        logger.values.text = table.concat(logLines, "\n")
    end
end

-- Other scripts use print() or notify document script
```

## 12. Control Type Differences
```lua
-- Buttons use 'touch' value
function onValueChanged(valueName)
    if valueName == "touch" and self.values.touch == 1 then
        -- Button pressed
    end
end

-- Labels use 'x' value when interactive
function onValueChanged(valueName)
    if valueName == "x" then
        -- Label tapped
    end
end

-- Handle both for flexibility
if valueName == "touch" or valueName == "x" then
    -- Works for both control types
end
```

## 13. Visual Feedback Timing
```lua
-- ❌ WRONG - Too fast to see
self.color = Color(1, 1, 0, 1)  -- Yellow
self.color = Color(0.5, 0.5, 0.5, 1)  -- Gray immediately

-- ✅ CORRECT - Use update() for delayed reset
local colorResetTime = 0
local needsColorReset = false

function onValueChanged(valueName)
    self.color = Color(1, 1, 0, 1)  -- Yellow
    colorResetTime = os.clock() + 0.3  -- 300ms delay
    needsColorReset = true
end

function update()
    if needsColorReset and os.clock() >= colorResetTime then
        self.color = Color(0.5, 0.5, 0.5, 1)  -- Gray
        needsColorReset = false
    end
end
```

## 14. self.values Structure Varies
```lua
-- ❌ WRONG - Assuming structure
for k, v in pairs(self.values) do  -- May error!

-- ✅ CORRECT - Check type first
if self.values and type(self.values) == "table" then
    self.values.text = "Hello"
end
```

## 15. Document Script Pattern
Create a main "document script" that handles:
- Configuration parsing
- Centralized logging
- Helper functions (exposed via globals)
- Coordination between scripts
- Buffering messages before logger is available

```lua
-- Document script pattern
local VERSION = "2.5.8"
local logLines = {}  -- Buffer messages
local logger = nil   -- Found later

function init()
    log("Document Script v" .. VERSION .. " loaded")
    -- Initialize system
end

function onReceiveNotify(action, value)
    if action == "refresh_all_groups" then
        refreshAllGroups()
    end
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
8. **Control types differ** - buttons vs labels have different values
9. **Visual changes need delays** - use update() for timing
10. **Logger might not exist yet** - buffer messages

## Testing Checklist
- [ ] Test with missing controls
- [ ] Test with disconnected Ableton
- [ ] Test with wrong connection numbers
- [ ] Verify all notify() handlers
- [ ] Check version logging
- [ ] Test visual feedback visibility
- [ ] Verify logger updates properly
- [ ] Test with controls in pagers