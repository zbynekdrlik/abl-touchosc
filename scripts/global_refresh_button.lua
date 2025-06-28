-- TouchOSC Global Refresh Button Script
-- Version: 1.2.1
-- Notifies document script to perform refresh

local SCRIPT_VERSION = "1.2.1"

-- Store last tap time to prevent double triggers
local lastTapTime = 0

function onValueChanged(valueName)
    -- Handle both button-style (touch) and label-style (x) touches
    if valueName == "touch" or valueName == "x" then
        -- Prevent double triggers
        local currentTime = os.clock()
        if currentTime - lastTapTime < 0.5 then
            return
        end
        lastTapTime = currentTime
        
        -- Visual feedback
        self.color = Color(1, 1, 0, 1)  -- Yellow while refreshing
        
        -- Notify document script to refresh all groups
        root:notify("refresh_all_groups")
        
        -- Reset color after a short delay
        self.color = Color(0.5, 0.5, 0.5, 1)  -- Back to gray
    end
end

function init()
    print("Global Refresh Button v" .. SCRIPT_VERSION .. " initialized")
    
    -- Set button text
    if self.values and type(self.values) == "table" and self.values.text ~= nil then
        self.values.text = "REFRESH ALL"
    end
end