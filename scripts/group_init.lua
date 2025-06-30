-- Group Initialization Script
-- Version: 1.12.1
-- Purpose: Track group state management with multi-connection routing and visual feedback
-- Connection routing: Uses control name prefixes (band_, master_) to route to different connections
-- Status indicators: Red=unmapped, Green=mapped, Blue=fader movement detected

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
    self.values.lastActivityTime = 0
    self.values.lastFaderValue = nil
    
    -- Update label to show unmapped state
    label.values.text = "Not Mapped"
    
    -- Set status indicator to red (unmapped)
    if statusIndicator then
        statusIndicator.color = Color(1, 0, 0, 1)  -- Red with full opacity
        debugLog("Status indicator set to RED (unmapped)")
    end
    
    -- Start monitoring timer
    self.parent:schedule(50, monitorActivity)
    
    debugLog("=== GROUP INIT COMPLETE ===")
end

-- Monitor fader for activity (only thing we can actually detect without modifying other scripts)
function monitorActivity()
    local group = self.parent
    if not group then return end
    
    local currentTime = getMillis()
    
    -- Check fader for changes
    local fader = group:findByName("1 #")
    if fader and fader.values.x then
        local currentValue = fader.values.x
        if self.values.lastFaderValue and math.abs(currentValue - self.values.lastFaderValue) > 0.001 then
            self.values.lastActivityTime = currentTime
            debugLog("Fader movement detected")
        end
        self.values.lastFaderValue = currentValue
    end
    
    -- Update status indicator
    updateStatusIndicator()
    
    -- Schedule next check
    self.parent:schedule(50, monitorActivity)
end

-- Update status indicator based on current state
function updateStatusIndicator()
    local group = self.parent
    if not group then return end
    
    local statusIndicator = group:findByName("Status")
    if not statusIndicator then return end
    
    local currentTime = getMillis()
    local timeSinceActivity = currentTime - (self.values.lastActivityTime or 0)
    
    -- Check if mapped
    if self.values.trackIndex and self.values.trackIndex > 0 then
        -- Mapped - check for recent activity
        if timeSinceActivity < 150 then
            -- Active - blue
            statusIndicator.color = Color(0, 0.5, 1, 1)
        elseif timeSinceActivity < 500 then
            -- Fading from blue to green
            local fade = (timeSinceActivity - 150) / 350  -- 0 to 1 over 350ms
            statusIndicator.color = Color(0, 0.5 * (1 - fade) + fade, 1 * (1 - fade) + fade * 0, 1)
        else
            -- Idle - solid green
            statusIndicator.color = Color(0, 1, 0, 1)
        end
    else
        -- Not mapped - red
        statusIndicator.color = Color(1, 0, 0, 1)
    end
end

-- Handle incoming OSC for this group (called by other scripts)
function processGroupOSC(data)
    if not data then return end
    
    local group = self.parent
    if not group then return end
    
    local label = group:findByName("Hand 1 #")
    
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
    
    -- Update status indicator
    updateStatusIndicator()
end

-- Called by other scripts to notify of incoming data
function notifyIncomingData()
    self.values.lastActivityTime = getMillis()
    self.values.incomingData = true
    debugLog("Incoming data notification received")
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

debugLog("Group init script loaded v1.12.1")
