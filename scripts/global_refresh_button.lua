-- TouchOSC Global Refresh Button Script
-- Version: 1.5.1
-- Fixed: Schedule method not available - using time-based update checks
-- Performance optimized - removed centralized logging, time-based updates
-- Added DEBUG guards

local SCRIPT_VERSION = "1.5.1"

-- Debug mode (set to 1 for debug output)
local DEBUG = 0

-- Store last tap time to prevent double triggers
local lastTapTime = 0
local needsColorReset = false
local colorResetTime = 0

-- Debug logging
local function debug(message)
    if DEBUG == 0 then return end
    print("[" .. os.date("%H:%M:%S") .. "] REFRESH BUTTON: " .. message)
end

function onValueChanged(valueName)
    -- Handle both button-style (touch) and label-style (x) touches
    if valueName == "touch" or valueName == "x" then
        -- Prevent double triggers
        local currentTime = os.clock()
        if currentTime - lastTapTime < 0.5 then
            return
        end
        lastTapTime = currentTime
        
        debug("Refresh triggered")
        
        -- Visual feedback - bright yellow
        self.color = Color(1, 1, 0, 1)  -- Yellow while refreshing
        
        -- Schedule color reset using time tracking
        needsColorReset = true
        colorResetTime = currentTime + 0.3  -- Reset color after 300ms
        
        -- Notify document script to refresh all groups
        root:notify("refresh_all_groups")
    end
end

function update()
    -- Check if we need to reset color
    if needsColorReset then
        local currentTime = os.clock()
        if currentTime >= colorResetTime then
            self.color = Color(0.5, 0.5, 0.5, 1)  -- Back to gray
            needsColorReset = false
            debug("Color reset after refresh")
        end
    end
end

function init()
    print("[" .. os.date("%H:%M:%S") .. "] REFRESH BUTTON: Script v" .. SCRIPT_VERSION .. " loaded")
    
    -- Set button text
    if self.values and type(self.values) == "table" and self.values.text ~= nil then
        self.values.text = "REFRESH ALL"
    end
    
    -- Set initial color
    self.color = Color(0.5, 0.5, 0.5, 1)  -- Gray
    
    if DEBUG == 1 then
        debug("Initialized")
    end
end

init()