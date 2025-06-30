-- Group Initialization Script
-- Version: 1.12.0
-- Purpose: Track group state management with multi-connection routing and visual communication feedback
-- Connection routing: Uses control name prefixes (band_, master_) to route to different connections
-- Status indicators: Red=unmapped, Green=mapped/idle, Blue/Yellow=active communication

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
    self.values.lastSendTime = 0
    self.values.lastReceiveTime = 0
    self.values.lastMeterValue = 0
    self.values.lastVolumeValue = 0
    
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

-- Monitor child controls for activity
function monitorActivity()
    local group = self.parent
    if not group then return end
    
    local currentTime = getMillis()
    local activityDetected = false
    
    -- Check fader for changes (outgoing data)
    local fader = group:findByName("1 #")
    if fader and fader.values.x then
        local currentValue = fader.values.x
        if self.values.lastFaderValue and math.abs(currentValue - self.values.lastFaderValue) > 0.001 then
            self.values.lastSendTime = currentTime
            activityDetected = true
            debugLog("Fader movement detected")
        end
        self.values.lastFaderValue = currentValue
    end
    
    -- Check meter for changes (incoming data)
    local meter = group:findByName("Meter")
    if meter and meter.values.x then
        local currentValue = meter.values.x
        if self.values.lastMeterValue and math.abs(currentValue - self.values.lastMeterValue) > 0.01 then
            self.values.lastReceiveTime = currentTime
            activityDetected = true
            debugLog("Meter change detected")
        end
        self.values.lastMeterValue = currentValue
    end
    
    -- Also check if fader value changes from external source (volume receive)
    if fader and fader.values.x then
        -- If fader moved but we didn't send it, it's incoming data
        local timeSinceSend = currentTime - self.values.lastSendTime
        if timeSinceSend > 100 and self.values.lastVolumeValue and 
           math.abs(fader.values.x - self.values.lastVolumeValue) > 0.001 then
            self.values.lastReceiveTime = currentTime
            activityDetected = true
            debugLog("Volume receive detected")
        end
        self.values.lastVolumeValue = fader.values.x
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
    local timeSinceSend = currentTime - (self.values.lastSendTime or 0)
    local timeSinceReceive = currentTime - (self.values.lastReceiveTime or 0)
    
    -- Check if mapped
    if self.values.trackIndex and self.values.trackIndex > 0 then
        -- Determine current state based on activity
        if timeSinceSend < 150 then
            -- Recently sent data - blue
            statusIndicator.color = Color(0, 0.5, 1, 1)
        elseif timeSinceReceive < 150 then
            -- Recently received data - yellow
            statusIndicator.color = Color(1, 1, 0, 1)
        elseif timeSinceSend < 500 or timeSinceReceive < 500 then
            -- Fading from active to idle
            local fadeTime = math.min(timeSinceSend, timeSinceReceive) - 150
            local fade = fadeTime / 350  -- 0 to 1 over 350ms
            
            if timeSinceSend < timeSinceReceive then
                -- Fade from blue to green
                statusIndicator.color = Color(0, 0.5 * (1 - fade) + fade, 1 * (1 - fade) + fade * 0, 1)
            else
                -- Fade from yellow to green
                statusIndicator.color = Color(1 * (1 - fade), 1, 0, 1)
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

-- Handle incoming OSC for this group
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

debugLog("Group init script loaded v1.12.0")
