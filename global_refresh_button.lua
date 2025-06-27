-- TouchOSC Global Refresh Button Script
-- Version: 1.1.0
-- Phase: 01 - Global refresh for all track groups

local SCRIPT_VERSION = "1.1.0"

-- Local logger function
local function log(...)
    local timestamp = os.date("%H:%M:%S")
    local args = {...}
    local message = "[" .. timestamp .. "] "
    
    for i, v in ipairs(args) do
        message = message .. tostring(v)
        if i < #args then message = message .. " " end
    end
    
    print(message)
    
    -- Update logger if exists
    local loggerObj = root:findByName("logger")
    if loggerObj and loggerObj.values then
        local currentText = loggerObj.values.text or ""
        local lines = {}
        for line in currentText:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        table.insert(lines, message)
        -- Keep last 20 lines
        while #lines > 20 do
            table.remove(lines, 1)
        end
        loggerObj.values.text = table.concat(lines, "\n")
    end
end

log("Global Refresh Button v" .. SCRIPT_VERSION .. " loaded")

function onValueChanged(valueName)
    if valueName == "touch" and self.values.touch == 1 then
        log("=== GLOBAL REFRESH INITIATED ===")
        
        -- Visual feedback
        self.color = Color(1, 1, 0, 1)  -- Yellow while refreshing
        
        -- Find and update global status if exists
        local statusLabel = root:findByName("global_status")
        if statusLabel then
            statusLabel.values.text = "Refreshing all tracks..."
        end
        
        -- Find all track groups
        local groups = root:findAllByProperty("tag", "trackGroup", true)
        local count = 0
        
        for _, group in ipairs(groups) do
            group:notify("refresh")
            count = count + 1
        end
        
        log("Sent refresh to " .. count .. " track groups")
        
        -- Update status
        if statusLabel then
            statusLabel.values.text = "Refreshed " .. count .. " groups at " .. os.date("%H:%M:%S")
        end
        
        -- Reset button color after a moment
        self.color = Color(0.5, 0.5, 0.5, 1)  -- Back to gray
        
        log("=== GLOBAL REFRESH COMPLETE ===")
    end
end

function init()
    log("Global Refresh Button initialized")
    self.values.text = "REFRESH ALL"
end
