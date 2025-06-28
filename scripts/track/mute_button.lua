-- mute_button.lua
-- Version: 1.6.0
-- Step 1: Simple receive-only version

local VERSION = "1.6.0"

-- Logging
local function log(message)
    local context = "MUTE"
    if self.parent and self.parent.name then
        context = "MUTE(" .. self.parent.name .. ")"
    end
    
    root:notify("log_message", context .. ": " .. message)
    print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
end

-- Get track number from parent
local function getTrackNumber()
    if self.parent and self.parent.tag then
        local instance, trackNum = self.parent.tag:match("(%w+):(%d+)")
        if trackNum then
            return tonumber(trackNum)
        end
    end
    return nil
end

-- Handle incoming OSC
function onReceiveOSC(message, connections)
    local arguments = message[2]
    
    if message[1] == '/live/track/get/mute' then
        local myTrackNumber = getTrackNumber()
        if not myTrackNumber then
            return false
        end
        
        -- Check if this is our track
        if arguments[1] and arguments[1].value == myTrackNumber then
            -- Update button visual state
            if arguments[2].value then
                self.values.x = 0  -- Muted = pressed
            else
                self.values.x = 1  -- Unmuted = released
            end
            
            log("Received mute state: " .. (arguments[2].value and "MUTED" or "UNMUTED"))
        end
    end
    
    return false
end

-- Initialize
log("Script v" .. VERSION .. " loaded (receive-only)")
self.values.x = 1  -- Start unmuted