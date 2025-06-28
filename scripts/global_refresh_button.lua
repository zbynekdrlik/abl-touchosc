-- TouchOSC Global Refresh Button Script
-- Version: 1.1.3
-- Phase: 01 - Global refresh for all track groups
-- Fixed: Use document script's log function via notify

local SCRIPT_VERSION = "1.1.3"

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
        
        -- Use document script's refreshAllGroups function
        if refreshAllGroups then
            refreshAllGroups()
        else
            -- Fallback if function not available
            print("=== GLOBAL REFRESH INITIATED ===")
            
            -- Visual feedback
            self.color = Color(1, 1, 0, 1)  -- Yellow while refreshing
            
            -- Find all track groups
            local groups = root:findAllByProperty("tag", "trackGroup", true)
            local count = 0
            
            for _, group in ipairs(groups) do
                group:notify("refresh")
                count = count + 1
            end
            
            print("Sent refresh to " .. count .. " track groups")
            
            -- Reset button color after a moment
            self.color = Color(0.5, 0.5, 0.5, 1)  -- Back to gray
            
            print("=== GLOBAL REFRESH COMPLETE ===")
        end
    end
end

function init()
    print("Global Refresh Button v" .. SCRIPT_VERSION .. " initialized")
    
    -- Safely try to set text
    if self.values and type(self.values) == "table" then
        self.values.text = "REFRESH ALL"
    else
        -- If values isn't what we expect, try direct property
        if self.text then
            self.text = "REFRESH ALL"
        end
    end
end