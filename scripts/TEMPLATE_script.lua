-- TouchOSC Script Template
-- Version: 1.0.0
-- Purpose: [Describe what this script does]
-- 
-- Copy this template when creating new scripts to avoid common issues

local VERSION = "1.0.0"
local SCRIPT_NAME = "Script Name"  -- Change this

-- ====================
-- INITIALIZATION
-- ====================
function init()
    -- Always log version on startup
    print(SCRIPT_NAME .. " v" .. VERSION .. " loaded")
    
    -- Set any initial values here
    -- Example: self.color = Color(0.5, 0.5, 0.5, 1)
    
    -- Register with document script if needed
    -- Example: root:notify("register_mycontrol", self)
end

-- ====================
-- VALUE CHANGED HANDLER
-- ====================
function onValueChanged(valueName)
    -- Handle both button (touch) and label (x) touches if needed
    if valueName == "touch" or valueName == "x" then
        -- Your code here
        
        -- For visual feedback that's visible:
        -- self.color = Color(1, 1, 0, 1)
        -- scheduleColorReset(0.3)  -- See update() section
    end
end

-- ====================
-- NOTIFICATION HANDLER
-- ====================
function onReceiveNotify(action, value)
    -- Handle notifications from other scripts
    if action == "some_action" then
        -- Your code here
    end
end

-- ====================
-- OSC RECEIVE HANDLER
-- ====================
function onReceiveOSC(message, connections)
    -- Remember: OSC patterns must be set in UI, not script!
    
    if message[1] == "/your/osc/path" then
        -- Process message
        -- Remember message structure: message[2] contains arguments
        
        return true  -- Stop propagation
    end
    
    return false  -- Allow other controls to process
end

-- ====================
-- UPDATE FUNCTION (60fps)
-- ====================
-- Uncomment if you need timing/animation
--[[
local colorResetTime = 0
local needsColorReset = false

function update()
    -- Example: Delayed color reset
    if needsColorReset and os.clock() >= colorResetTime then
        self.color = Color(0.5, 0.5, 0.5, 1)
        needsColorReset = false
    end
end

function scheduleColorReset(delay)
    colorResetTime = os.clock() + delay
    needsColorReset = true
end
--]]

-- ====================
-- HELPER FUNCTIONS
-- ====================

-- Safe parent access
local function getParentProperty(propertyName)
    if self.parent then
        return self.parent[propertyName]
    end
    return nil
end

-- Connection-aware OSC sending
local function sendToConnection(path, ...)
    local parent = self.parent
    if not parent then return end
    
    -- Get connection from parent or document script
    local connectionIndex = parent.connectionIndex or 1
    
    -- Create connection table
    local connections = {}
    for i = 1, 10 do
        connections[i] = (i == connectionIndex)
    end
    
    -- Send OSC
    sendOSC(path, ..., connections)
end

-- Logging (use document script's log if available)
local function log(message)
    -- Just use print - document script will handle proper logging
    print("[" .. SCRIPT_NAME .. "] " .. message)
end

-- ====================
-- SCRIPT BODY
-- ====================
-- Your main script logic goes here

-- Initialize
init()