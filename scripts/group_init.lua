-- Group Initialization Script
-- Version: 1.11.0
-- Purpose: Track group state management with multi-connection routing and visual communication feedback
-- Connection routing: Uses control name prefixes (band_, master_) to route to different connections
-- Status indicators: Red=unmapped, Green=mapped/idle, Blue/Cyan=active communication

local DEBUG = false

function debugLog(message)
    if DEBUG then
        print("[GroupInit] " .. message)
    end
end

function init()
    debugLog("=== GROUP INIT START ===")
    
    -- Get group and controls
    local group = self.parent
    if not group then
        debugLog("ERROR: No parent group found")
        return
    end
    
    debugLog("Group name: " .. group.name)
    
    -- Find controls
    local label = group:findByName("Hand 1 #")
    local statusIndicator = group:findByName("Status")
    
    if not label then
        debugLog("ERROR: Label 'Hand 1 #' not found")
        return
    end
    
    -- Initialize state
    self.values.trackIndex = -1
    self.values.trackName = ""
    self.values.lastDataTime = 0
    self.values.dataDirection = "none"  -- "send", "receive", or "none"
    
    -- Update label to show unmapped state
    label.values.text = "Not Mapped"
    
    -- Set status indicator to red (unmapped)
    if statusIndicator then
        statusIndicator.color = Color(1, 0, 0, 1)  -- Red with full opacity
        debugLog("Status indicator set to RED (unmapped)")
    end
    
    debugLog("=== GROUP INIT COMPLETE ===")
end

-- Communication activity detection
function onValueChanged(key)
    if key == "x" then  -- Fader movement
        local currentTime = getMillis()
        self.values.lastDataTime = currentTime
        self.values.dataDirection = "send"
        updateStatusIndicator()
    end
end

-- Update status indicator based on current state
function updateStatusIndicator()
    local group = self.parent
    if not group then return end
    
    local statusIndicator = group:findByName("Status")
    if not statusIndicator then return end
    
    local currentTime = getMillis()
    local timeSinceData = currentTime - (self.values.lastDataTime or 0)
    
    -- Check if mapped
    if self.values.trackIndex and self.values.trackIndex > 0 then
        -- Mapped - check for recent activity
        if timeSinceData < 100 then  -- Active in last 100ms
            if self.values.dataDirection == "send" then
                statusIndicator.color = Color(0, 0.7, 1, 1)  -- Light blue for sending
            else
                statusIndicator.color = Color(0, 1, 1, 1)  -- Cyan for receiving
            end
        elseif timeSinceData < 500 then  -- Fading activity
            -- Fade from active color to green
            local fade = (timeSinceData - 100) / 400  -- 0 to 1 over 400ms
            if self.values.dataDirection == "send" then
                statusIndicator.color = Color(0, 0.7 * (1 - fade) + fade, 1 * (1 - fade), 1)
            else
                statusIndicator.color = Color(0, 1, 1 * (1 - fade), 1)
            end
        else
            -- Idle - solid green
            statusIndicator.color = Color(0, 1, 0, 1)
        end
    else
        -- Not mapped - red
        statusIndicator.color = Color(1, 0, 0, 1)
    end
end

-- Called periodically to update status
function update()
    updateStatusIndicator()
end

-- Handle incoming OSC for this group
function processGroupOSC(data)
    if not data then return end
    
    -- Mark as receiving data
    local currentTime = getMillis()
    self.values.lastDataTime = currentTime
    self.values.dataDirection = "receive"
    
    local group = self.parent
    if not group then return end
    
    local label = group:findByName("Hand 1 #")
    local statusIndicator = group:findByName("Status")
    
    -- Update track mapping
    if data.trackIndex then
        self.values.trackIndex = data.trackIndex
        debugLog("Track index set to: " .. data.trackIndex)
    end
    
    if data.trackName then
        self.values.trackName = data.trackName
        if label then
            -- Check if it's a real track (not master/return)
            if data.trackName ~= "" and 
               not string.find(string.lower(data.trackName), "master") and
               not string.find(string.lower(data.trackName), "return") then
                -- Preserve track number prefix if it exists
                local currentText = label.values.text or ""
                local trackNumber = string.match(currentText, "^(%d+)")
                
                if trackNumber then
                    label.values.text = trackNumber .. " " .. data.trackName
                else
                    label.values.text = data.trackName
                end
                debugLog("Label updated to: " .. label.values.text)
            end
        end
    end
    
    -- Update status indicator for activity
    updateStatusIndicator()
end

-- Connection label helper for child controls
function getConnectionLabel()
    local group = self.parent
    if group then
        local groupName = group.name
        if string.find(groupName, "^band_") then
            return "Band"
        elseif string.find(groupName, "^master_") then
            return "Master"
        end
    end
    return nil
end

debugLog("Group init script loaded v1.11.0")
