-- TouchOSC Global Refresh Button Script
-- Version: 1.3.2
-- Test: Direct notify without console print

local SCRIPT_VERSION = "1.3.2"

-- Store last tap time to prevent double triggers
local lastTapTime = 0
local colorResetTime = 0
local needsColorReset = false

function onValueChanged(valueName)
    -- Handle both button-style (touch) and label-style (x) touches
    if valueName == "touch" or valueName == "x" then
        -- Prevent double triggers
        local currentTime = os.clock()
        if currentTime - lastTapTime < 0.5 then
            return
        end
        lastTapTime = currentTime
        
        -- TEST: Send log message directly without print
        root:notify("log_message", "REFRESH BUTTON: Refresh triggered (v" .. SCRIPT_VERSION .. ")")
        
        -- Visual feedback - bright yellow
        self.color = Color(1, 1, 0, 1)  -- Yellow while refreshing
        
        -- Schedule color reset for later
        colorResetTime = currentTime + 0.3  -- Hold yellow for 300ms
        needsColorReset = true
        
        -- Notify document script to refresh all groups
        root:notify("refresh_all_groups")
    end
end

function update()
    -- Check if we need to reset color
    if needsColorReset and os.clock() >= colorResetTime then
        self.color = Color(0.5, 0.5, 0.5, 1)  -- Back to gray
        needsColorReset = false
    end
end

function init()
    -- TEST: Direct notify for init message
    root:notify("log_message", "REFRESH BUTTON: Script v" .. SCRIPT_VERSION .. " initialized")
    
    -- Set button text
    if self.values and type(self.values) == "table" and self.values.text ~= nil then
        self.values.text = "REFRESH ALL"
    end
    
    -- Set initial color
    self.color = Color(0.5, 0.5, 0.5, 1)  -- Gray
end
