# TouchOSC Script Template for Multi-Connection Controls

Based on learnings from the fader script fixes, here's the standard template for controls that need connection routing.

## Template Structure

```lua
-- TouchOSC [Control Name] Script
-- Version: X.Y.Z
-- Purpose: [Brief description]
-- Connection-aware: Yes

-- Version constant
local VERSION = "X.Y.Z"

-- ===========================
-- CONFIGURATION
-- ===========================

local DEBUG = 0  -- Set to 1 for verbose logging

-- [Control-specific configuration here]

-- ===========================
-- STATE VARIABLES
-- ===========================

-- [Control-specific state variables]

-- ===========================
-- CENTRALIZED LOGGING
-- ===========================

-- Centralized logging through document script
local function log(message)
    -- Get parent name for context
    local context = "CONTROLNAME"
    if self.parent and self.parent.name then
        context = "CONTROLNAME(" .. self.parent.name .. ")"
    end
    
    -- Send to document script for logger text update
    root:notify("log_message", context .. ": " .. message)
    
    -- Also print to console for development/debugging
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Debug logging function
local function debugLog(...)
    if DEBUG == 1 then
        local args = {...}
        local msg = table.concat(args, " ")
        log(msg)
    end
end

-- ===========================
-- CONNECTION HELPERS
-- ===========================

-- Get connection configuration (read directly from config text)
local function getConnectionIndex()
    -- Check if parent has tag with instance:trackNumber format
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if instance then
            -- Find configuration object
            local configObj = root:findByName("configuration", true)
            if not configObj or not configObj.values or not configObj.values.text then
                debugLog("Warning: No configuration found, using default connection 1")
                return 1
            end
            
            local configText = configObj.values.text
            local searchKey = "connection_" .. instance .. ":"
            
            -- Parse configuration text
            for line in configText:gmatch("[^\r\n]+") do
                line = line:match("^%s*(.-)%s*$")  -- Trim whitespace
                if line:sub(1, #searchKey) == searchKey then
                    local value = line:sub(#searchKey + 1):match("^%s*(.-)%s*$")
                    return tonumber(value) or 1
                end
            end
            
            debugLog("Warning: No config for " .. instance .. " - using default (1)")
            return 1
        end
    end
    
    -- Fallback to default
    return 1
end

-- Build connection table for OSC routing
local function buildConnectionTable(index)
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == index)
    end
    return connections
end

-- Get track number from parent group
local function getTrackNumber()
    -- Parent stores combined tag like "band:5" or "master:12"
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
        -- Fallback to old format if needed
        return tonumber(self.parent.tag)
    end
    return nil
end

-- Check if track is properly mapped
local function isTrackMapped()
    -- If parent doesn't have proper tag format, it's not mapped
    if not self.parent or not self.parent.tag then
        return false
    end
    
    -- Check for instance:trackNumber format
    local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
    return instance ~= nil and trackNum ~= nil
end

-- Send OSC with connection routing
local function sendOSCRouted(path, ...)
    local connectionIndex = getConnectionIndex()
    local connections = buildConnectionTable(connectionIndex)
    -- Be explicit with parameters to avoid variadic issues
    local args = {...}
    if #args == 1 then
        sendOSC(path, args[1], connections)
    elseif #args == 2 then
        sendOSC(path, args[1], args[2], connections)
    elseif #args == 3 then
        sendOSC(path, args[1], args[2], args[3], connections)
    else
        -- Add more as needed
        sendOSC(path, ..., connections)
    end
end

-- ===========================
-- CONTROL LOGIC
-- ===========================

-- [Control-specific functions here]

-- ===========================
-- OSC HANDLERS
-- ===========================

function onReceiveOSC(message, connections)
    -- Get our track number from parent tag
    local myTrackNumber = getTrackNumber()
    if not myTrackNumber then
        return false
    end
    
    -- Get our connection
    local myConnection = getConnectionIndex()
    
    -- Only process messages from our connection
    if not connections[myConnection] then
        return false
    end
    
    -- Check message format and extract data
    local arguments = message[2]
    if not arguments or #arguments < 1 then
        return false
    end
    
    -- Check if this message is for our track
    local msgTrackNumber = arguments[1].value
    if msgTrackNumber ~= myTrackNumber then
        return false
    end
    
    -- Process the message
    -- [Control-specific processing]
    
    return true  -- We handled it
end

-- ===========================
-- VALUE CHANGE HANDLERS
-- ===========================

function onValueChanged(valueName)
    -- Safety check: only process if track is mapped
    if not isTrackMapped() then
        -- Optionally disable/reset the control
        return
    end
    
    -- [Control-specific value handling]
    
    -- Send OSC if needed
    local trackNumber = getTrackNumber()
    if trackNumber then
        -- Example: sendOSCRouted('/live/track/set/something', trackNumber, value)
        debugLog("Sent update for track " .. trackNumber)
    end
end

-- ===========================
-- PARENT NOTIFICATIONS
-- ===========================

function onReceiveNotify(key, value)
    if key == "track_changed" then
        -- Reset state when track changes
        debugLog("Track changed - resetting state")
        -- [Reset control-specific state]
    elseif key == "track_unmapped" then
        -- Disable when track is unmapped
        debugLog("Track unmapped - disabling")
        -- [Disable control]
    end
end

-- ===========================
-- UPDATE LOOP
-- ===========================

function update()
    -- Safety check: disable visual if not mapped
    if not isTrackMapped() then
        self.color = Color(0.3, 0.3, 0.3, 0.5)  -- Dimmed
    else
        self.color = Color(1, 1, 1, 1)  -- Normal
    end
    
    -- [Control-specific update logic]
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Log version
    log("Script v" .. VERSION .. " loaded")
    
    -- Log parent info
    if self.parent and self.parent.name then
        log("Initialized for parent: " .. self.parent.name)
    end
    
    -- Set initial state based on mapping
    if not isTrackMapped() then
        self.color = Color(0.3, 0.3, 0.3, 0.5)
    end
    
    -- [Control-specific initialization]
end

-- Initialize on load
init()
```

## Key Patterns to Follow

### 1. Always Read Configuration Directly
```lua
-- Each script must read config itself
local configObj = root:findByName("configuration", true)
-- Parse what you need
```

### 2. Handle Tag Format Changes
```lua
-- Parent might use "instance:track" format
local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
```

### 3. Use Explicit OSC Parameters
```lua
-- Avoid variadic with connections
sendOSC(path, param1, param2, connections)
```

### 4. Filter Incoming OSC by Connection
```lua
-- Only process from our connection
if not connections[myConnection] then
    return false
end
```

### 5. Centralized Logging Pattern
```lua
-- Always use notify for logging
root:notify("log_message", context .. ": " .. message)
```

### 6. Debug Mode for Verbosity
```lua
-- Normal logs: only important events
log("Script loaded")

-- Debug logs: detailed operation
debugLog("Processing value:", value)
```

## Common Control Patterns

### Fader
- Needs smoothing/scaling logic
- Sends: `/live/track/set/volume`
- Receives: `/live/track/get/volume`

### Meter
- Needs decay animation
- Receives: `/live/track/get/output_meter_level`
- No send needed

### Button (Mute)
- Toggle state management
- Sends: `/live/track/set/mute`
- Optionally receives: `/live/track/get/mute`

### Knob (Pan)
- Center detent handling
- Sends: `/live/track/set/panning`
- Optionally receives: `/live/track/get/panning`

## Testing Checklist for New Controls

- [ ] Logs version on init
- [ ] Reads configuration correctly
- [ ] Handles parent tag format
- [ ] Filters OSC by connection
- [ ] Sends to correct connection only
- [ ] Dims when track not mapped
- [ ] Enables when track mapped
- [ ] Uses centralized logging
- [ ] Debug logs only in debug mode
- [ ] Handles missing controls gracefully