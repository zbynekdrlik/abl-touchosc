-- TouchOSC Group Initialization Script with Selective Routing
-- Version: 1.1.4
-- Phase: 01 - Phase 1: Single Group Test with Refresh

-- Version logging
local SCRIPT_VERSION = "1.1.4"

-- Get helper functions from root
local helpers = root.helperFunctions
if not helpers then
    print("[group_init.lua] ERROR: Helper functions not found! Make sure helper_script.lua is loaded first")
    return
end

-- Import functions we need
local log = helpers.log or print
local parseGroupName = helpers.parseGroupName
local getConnectionIndex = helpers.getConnectionIndex
local buildConnectionTable = helpers.buildConnectionTable
local updateStatusIndicator = helpers.updateStatusIndicator

log("Group init v" .. SCRIPT_VERSION .. " for " .. self.name)

function init()
    log("Initializing group: " .. self.name)
    
    -- Set tag programmatically (not via UI)
    self.tag = "trackGroup"
    
    -- Parse group name
    local instance, trackName = parseGroupName(self.name)
    
    -- Store data in script variables
    self.instance = instance
    self.trackName = trackName
    self.connectionIndex = getConnectionIndex(instance)
    self.lastVerified = getMillis()
    
    log("Group config - Instance: " .. instance .. ", Track: " .. trackName .. ", Connection: " .. self.connectionIndex)
    
    -- Initial track discovery
    refreshTrackMapping()
end

function refreshTrackMapping()
    log("Refreshing track mapping for: " .. self.name)
    self.needsRefresh = true
    
    -- Visual feedback
    if self.children.status_indicator then
        self.children.status_indicator.color = {1, 1, 0}  -- Yellow = refreshing
    end
    
    -- Request track names from specific connection
    local connections = buildConnectionTable(self.connectionIndex)
    sendOSC('/live/song/get/track_names', nil, connections)
end

function onReceiveOSC(message, connections)
    -- Filter by connection
    if not connections[self.connectionIndex] then return end
    
    local path = message[1]
    if path == '/live/song/get/track_names' and self.needsRefresh then
        log("Received track names for " .. self.name)
        local arguments = message[2]
        local trackFound = false
        
        for i = 1, #arguments do
            if arguments[i].value == self.trackName then
                -- Found our track
                self.trackNumber = i - 1
                self.lastVerified = getMillis()
                self.needsRefresh = false
                trackFound = true
                
                log("Found track '" .. self.trackName .. "' at index " .. self.trackNumber)
                
                -- Update status
                if self.children.status_indicator then
                    self.children.status_indicator.color = {0, 1, 0}  -- Green = OK
                end
                
                -- Store combined info in tag
                self.tag = self.instance .. ":" .. self.trackNumber
                
                -- Start listeners
                local targetConnections = buildConnectionTable(self.connectionIndex)
                sendOSC('/live/track/start_listen/volume', {self.trackNumber}, targetConnections)
                sendOSC('/live/track/start_listen/output_meter_level', {self.trackNumber}, targetConnections)
                sendOSC('/live/track/start_listen/mute', {self.trackNumber}, targetConnections)
                sendOSC('/live/track/start_listen/panning', {self.trackNumber}, targetConnections)
                
                -- Update label
                if self.children["fdr_label"] then
                    self.children["fdr_label"].values.text = self.trackName:match("(%w+)(.*)")
                end
                break
            end
        end
        
        if not trackFound then
            -- Track not found
            log("ERROR: Track not found: " .. self.trackName)
            if self.children["fdr_label"] then
                self.children["fdr_label"].values.text = "???"
            end
            if self.children.status_indicator then
                self.children.status_indicator.color = {1, 0, 0}  -- Red = Error
            end
        end
    end
end

function onNotify(param)
    if param == "refresh" then
        log("Received refresh notification for " .. self.name)
        refreshTrackMapping()
    end
end

function update()
    -- Visual feedback for stale data
    if self.lastVerified then
        local age = getMillis() - self.lastVerified
        if age > 60000 and self.children.status_indicator then  -- 1 minute
            self.children.status_indicator.color = {1, 0.5, 0}  -- Orange = Stale
        end
    end
end

log("Group initialization script ready")
