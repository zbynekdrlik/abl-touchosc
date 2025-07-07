-- TouchOSC Mute Display Label Script
-- Version: 1.0.0
-- Display-only label showing MUTE with warning symbol for double-click protection

-- Version constant
local VERSION = "1.0.0"

-- Debug flag - set to 1 to enable logging
local DEBUG = 0  -- Production mode

-- State variables
local requiresDoubleClick = false

-- ===========================
-- LOCAL LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        local context = "MUTE_DISPLAY"
        if self.parent and self.parent.name then
            context = "MUTE_DISPLAY(" .. self.parent.name .. ")"
        end
        print("[" .. os.date("%H:%M:%S") .. "] " .. context .. ": " .. message)
    end
end

-- ===========================
-- CONFIGURATION HELPERS
-- ===========================

-- Escape special characters in Lua patterns
local function escapePattern(str)
    -- Escape all special pattern characters
    return str:gsub("([%-%^%$%(%)%%%.%[%]%*%+%?])", "%%%1")
end

-- Check if double-click protection is enabled
local function updateDoubleClickConfig()
    if self.parent and self.parent.name then
        local configObj = root:findByName("configuration", true)
        if configObj and configObj.values and configObj.values.text then
            -- Escape special characters in group name for pattern matching
            local escapedName = escapePattern(self.parent.name)
            -- Look for double_click_mute: 'GroupName' (no instance prefix)
            local searchPattern = "double_click_mute:%s*['\"]?" .. escapedName .. "['\"]?"
            requiresDoubleClick = configObj.values.text:match(searchPattern) ~= nil
            log("Double-click required for '" .. self.parent.name .. "': " .. tostring(requiresDoubleClick))
            
            -- Update label text
            updateLabelText()
            return
        end
    end
    requiresDoubleClick = false
    updateLabelText()
end

-- ===========================
-- VISUAL STATE MANAGEMENT
-- ===========================

-- Update label text based on protection state
function updateLabelText()
    -- Always show MUTE, add warning symbol if protected
    if requiresDoubleClick then
        self.values.text = "MUTE⚠"
    else
        self.values.text = "MUTE"
    end
    
    log("Updated label text to: " .. self.values.text)
end

-- ===========================
-- NOTIFY HANDLER
-- ===========================

function onReceiveNotify(key, value)
    log("Received notify: " .. key .. " = " .. tostring(value))
    
    -- Update configuration when track changes
    if key == "track_changed" then
        updateDoubleClickConfig()
    elseif key == "track_unmapped" then
        requiresDoubleClick = false
        updateLabelText()
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    log("Script v" .. VERSION .. " loaded")
    
    -- This is a display-only label
    self.interactive = false
    self.background = false
    
    -- Check initial configuration
    updateDoubleClickConfig()
    
    -- Set initial text
    updateLabelText()
end

-- Call init
init()
