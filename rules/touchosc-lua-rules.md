# TouchOSC Lua Critical Rules

## 1. Script Isolation is Absolute
```lua
-- ❌ IMPOSSIBLE - Scripts cannot share variables
_G.sharedVar = 123  -- Won't work
global.data = {}    -- Won't work

-- ❌ IMPOSSIBLE - Scripts cannot call each other's functions
documentScript.getConnectionForInstance()  -- Won't work
otherScript:doSomething()                 -- Won't work

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
    log("Script v" .. VERSION .. " loaded")  -- Use local logging
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

## 11. Local Logging Pattern (CRITICAL)
```lua
-- ✅ CORRECT - Each script has its own local logging function
-- Debug flag - set to 1 to enable logging
local DEBUG = 0  -- Default to off for performance

-- Local logging function
local function log(message)
    if DEBUG == 1 then
        local context = "SCRIPTNAME"
        if self.parent and self.parent.name then
            context = "SCRIPTNAME(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- Usage
function init()
    log("Script v" .. VERSION .. " loaded")
end

-- ❌ WRONG - Don't use notify for logging anymore
root:notify("log_message", context .. ": " .. message)  -- Old pattern

-- Performance optimization
-- The DEBUG check happens immediately, avoiding string operations when disabled
-- Each script controls its own logging independently
```

## 12. Control Type Differences (CRITICAL)
```lua
-- BUTTONS - DO NOT HAVE TEXT PROPERTY!
-- ❌ WRONG - Buttons cannot display text
self.values.text = "MUTED"  -- Will fail on button controls!

-- ✅ CORRECT - Buttons only have visual state
self.values.x = 0  -- Pressed/on state
self.values.x = 1  -- Released/off state

-- Buttons use 'touch' value
function onValueChanged(valueName)
    if valueName == "touch" and self.values.touch == 1 then
        -- Button pressed
    end
end

-- LABELS - Have text but behave differently
-- Labels use 'x' value when interactive
function onValueChanged(valueName)
    if valueName == "x" then
        -- Label tapped
    end
end

-- Labels CAN have text
self.values.text = "Track Name"  -- Works on labels

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
    -- For labels only:
    if self.type == ControlType.LABEL then
        self.values.text = "Hello"
    end
end
```

## 15. Document Script Pattern
Create a main "document script" that handles:
- Configuration parsing
- **Global functionality (like auto-refresh)**
- Helper functions (exposed via globals)
- Coordination between scripts

```lua
-- Document script pattern (v2.8.1+)
local VERSION = "2.8.1"
local DEBUG = 0  -- Local debug flag

local function log(message)
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] Document Script: " .. message)
    end
end

function init()
    log("Script v" .. VERSION .. " loaded")
end

-- Handle coordination messages from other scripts
function onReceiveNotify(action, value)
    if action == "refresh_all_groups" then
        refreshAllGroups()
    end
end
```

## 16. No pcall in TouchOSC
```lua
-- ❌ WRONG - pcall not available
local success, result = pcall(function()
    return self.children[name]
end)

-- ✅ CORRECT - Use direct checks
if self and self.children and self.children[name] then
    local child = self.children[name]
    -- Use child
end
```

## 17. Configuration Reading Pattern (NEW)
Since scripts are isolated, each script that needs configuration must read it directly:

```lua
-- ✅ CORRECT - Read configuration in each script that needs it
local function getConnectionIndex()
    local configObj = root:findByName("configuration", true)
    if not configObj or not configObj.values or not configObj.values.text then
        return 1  -- Default
    end
    
    local configText = configObj.values.text
    -- Parse the text to find what you need
    for line in configText:gmatch("[^\r\n]+") do
        -- Process each line
    end
end

-- ❌ WRONG - Trying to call another script's function
local connection = documentScript.getConnectionForInstance("band")  -- Won't work!
```

## 18. Tag Format Changes (NEW)
When parent scripts change tag formats, child scripts must adapt:

```lua
-- Parent might set tag as "band:39" instead of just "39"
local function getTrackNumber()
    if self.parent and self.parent.tag then
        -- Handle new format
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
        -- Fallback to old format
        return tonumber(self.parent.tag)
    end
    return nil
end
```

## 19. OSC Parameter Order (NEW)
When using variadic parameters with connection tables:

```lua
-- ❌ WRONG - Variadic args don't work well with connection tables
local function sendOSCRouted(path, ...)
    sendOSC(path, ..., connections)  -- This can fail!
end

-- ✅ CORRECT - Explicit parameters
local function sendOSCRouted(path, param1, param2)
    local connections = buildConnectionTable(index)
    sendOSC(path, param1, param2, connections)
end
```

## 20. Button Text Workarounds (CRITICAL)
Since buttons cannot display text, use these patterns:

```lua
-- ❌ WRONG - Trying to show state on button
self.values.text = isMuted and "MUTED" or "MUTE"  -- FAILS!

-- ✅ OPTION 1 - Use separate label for text
local label = self.parent.children.mute_label
if label then
    label.values.text = isMuted and "MUTED" or "MUTE"
end

-- ✅ OPTION 2 - Use only visual state (recommended)
self.values.x = isMuted and 0 or 1  -- Visual feedback only

-- ✅ OPTION 3 - Use color changes (if design allows)
self.color = isMuted and Color(1, 0, 0, 1) or Color(0.5, 0.5, 0.5, 1)

-- ✅ OPTION 4 - Parent group manages companion label
-- In parent group script:
function updateMuteLabel(isMuted)
    local label = self.children.mute_label
    if label then
        label.values.text = isMuted and "MUTED" or "MUTE"
    end
end
```

## Key Gotchas

1. **No global variables** between scripts - use notify()
2. **No shared memory** - each script is sandboxed
3. **No shared functions** - each script must be self-contained
4. **OSC patterns** cannot be scripted - UI only
5. **Connection 0** doesn't exist - use 1-10
6. **Scripts load asynchronously** - can't assume order
7. **update() runs 60fps** - keep it light
8. **Messages have structure** - `message[2][1].value`
9. **Control types differ** - buttons vs labels have different values
10. **Visual changes need delays** - use update() for timing
11. **Local logging only** - each script handles its own logging
12. **No pcall function** - use explicit nil checks
13. **Document script v2.8.1+** for configuration and coordination
14. **Each script reads config** - no shared config functions
15. **Tag formats can change** - handle multiple formats
16. **OSC parameter order matters** - be explicit with connections
17. **BUTTONS DON'T HAVE TEXT** - use visual state or companion labels

## Testing Checklist
- [ ] Test with missing controls
- [ ] Test with disconnected Ableton
- [ ] Test with wrong connection numbers
- [ ] Verify all notify() handlers
- [ ] Check version logging
- [ ] Test visual feedback visibility
- [ ] Verify local logging works with DEBUG=1
- [ ] Test with controls in pagers
- [ ] Confirm no log messages appear with DEBUG=0
- [ ] Test configuration reading in each script
- [ ] Verify tag format handling
- [ ] Check OSC parameter order
- [ ] Verify button scripts don't use text property
- [ ] Test companion labels for button text display
