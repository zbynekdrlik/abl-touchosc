-- TouchOSC Refresh Button Script for Individual Groups
-- Version: 1.0.0
-- Simple refresh button that notifies parent group to refresh its track mapping

local SCRIPT_VERSION = "1.0.0"

function onValueChanged(valueName)
    if valueName == "touch" and self.values.touch == 1 then
        -- Visual feedback
        self.color = Color(1, 1, 0, 1)  -- Yellow when pressed
        
        -- Notify parent group to refresh
        if self.parent then
            self.parent:notify("refresh")
            print("[" .. os.date("%H:%M:%S") .. "] Refreshing parent group: " .. (self.parent.name or "unknown"))
        end
        
        -- Reset color
        self.color = Color(0.5, 0.5, 0.5, 1)
    end
end

function init()
    self.values.text = "REFRESH"
    print("[" .. os.date("%H:%M:%S") .. "] Refresh button v" .. SCRIPT_VERSION .. " initialized")
end