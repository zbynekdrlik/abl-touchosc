-- TouchOSC Global Refresh Button
-- Version: 1.5.2
-- Fixed: Version logging respects DEBUG flag
-- Purpose: Single button to refresh all track mappings

local VERSION = "1.5.2"

-- Debug mode
local DEBUG = 0  -- Set to 1 for logging

-- State
local isRefreshing = false
local lastRefreshTime = 0
local REFRESH_COOLDOWN = 1000  -- 1 second cooldown

-- ===========================
-- LOGGING
-- ===========================

local function log(message)
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] REFRESH BUTTON: " .. message)
    end
end

-- ===========================
-- VISUAL FEEDBACK
-- ===========================

local function setButtonState(active)
    if active then
        -- Active/pressed state
        self.color = Color(1.0, 0.5, 0.0, 1.0)  -- Orange
        self.values.x = 1.0
    else
        -- Normal state
        self.color = Color(0.2, 0.2, 0.2, 1.0)  -- Dark gray
        self.values.x = 0.0
    end
end

-- ===========================
-- REFRESH LOGIC
-- ===========================

local function performRefresh()
    -- Check cooldown
    local now = getMillis()
    if now - lastRefreshTime < REFRESH_COOLDOWN then
        log("Refresh on cooldown, please wait...")
        return
    end
    
    if isRefreshing then
        log("Refresh already in progress...")
        return
    end
    
    isRefreshing = true
    lastRefreshTime = now
    setButtonState(true)
    
    log("=== STARTING GLOBAL REFRESH ===")
    
    -- Notify document script to refresh all groups
    if root.documentScript then
        root.documentScript:notify("refresh_all", true)
        log("Sent refresh_all notification to document script")
    else
        log("ERROR: Document script not found!")
    end
    
    -- Reset button after short delay
    local resetTime = now + 500  -- 500ms visual feedback
    
    -- Store reset time for update function
    self.resetTime = resetTime
end

-- ===========================
-- EVENT HANDLERS
-- ===========================

function onValueChanged()
    -- Trigger on button press (not release)
    if self.values.x > 0.5 and self.values.touch then
        performRefresh()
    end
end

function update()
    -- Check if we need to reset button
    if self.resetTime and getMillis() >= self.resetTime then
        setButtonState(false)
        isRefreshing = false
        self.resetTime = nil
        log("Refresh complete")
    end
end

-- ===========================
-- INITIALIZATION
-- ===========================

function init()
    -- Version logging only when DEBUG=1
    if DEBUG == 1 then
        print("[" .. os.date("%H:%M:%S") .. "] REFRESH BUTTON: Script v" .. VERSION .. " loaded")
    end
    
    -- Set initial button state
    setButtonState(false)
    
    -- Set button label if it has text
    if self.values.text ~= nil then
        self.values.text = "REFRESH ALL"
    end
    
    log("Global refresh button ready")
end

init()