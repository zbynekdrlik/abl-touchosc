# TouchOSC Selective Connection Routing - Phase Document

## Problem Statement
Currently, all TouchOSC objects broadcast to all configured connections. We need to route specific faders to different Ableton instances:
- Some faders → Ableton "band" instance
- Other faders → Ableton "master" instance

Each Ableton instance runs AbletonOSC on different ports/IPs.

## Current Architecture
- Groups are named same as Ableton tracks (e.g., 'Hand 1 #')
- On initialization, groups find their track number via track name
- Track number is stored in group.tag parameter
- Child scripts inherit parent tag as track number

## AbletonOSC Capabilities & Limitations

### What AbletonOSC CAN do:
- Track addressing by INDEX only (e.g., `/live/track/0/volume`)
- Get track names via `/live/song/get/track_names`
- Listen for property changes on individual tracks
- Query track properties (name, volume, mute, etc.)
- Bulk data queries via `/live/song/get/track_data`

### What AbletonOSC CANNOT do:
- No track addressing by name
- No automatic track reorder notifications
- No track list change detection
- Only index-based addressing supported

### Track Reordering Challenge
When users reorder tracks in Ableton:
- Track indices change but TouchOSC isn't notified
- Stored track numbers become incorrect
- Faders control wrong tracks

## Recommended Solution: Configuration-Based Routing with Refresh Mechanisms

### Overview
1. **Configuration Objects**: Text objects define which connection to use for each instance
2. **Group Naming**: Add instance prefix to group names (e.g., `band_Hand 1 #`)
3. **Script Routing**: Scripts read configuration and route messages accordingly
4. **Refresh Mechanisms**: Multiple strategies to handle track reordering

### Architecture Diagram
```
Root/Project Page
├── Configuration Objects
│   ├── connection_band (text: "1")
│   ├── connection_master (text: "2")
│   └── connection_drums (text: "3")  // Future
│
├── Global Controls
│   ├── refresh_all_button
│   └── auto_refresh_toggle
│
└── Track Groups
    ├── band_Hand 1 # 
    │   ├── refresh_button
    │   ├── status_indicator
    │   └── [controls...]
    ├── master_Vox 1 #
    │   ├── refresh_button
    │   ├── status_indicator
    │   └── [controls...]
    └── ...
```

## Implementation Phases

### Phase 0: Preparation and Testing Setup
**Goal**: Establish test environment without breaking existing functionality

1. **Configure Connections**:
   - Connection 1: Band Ableton (IP:Port)
   - Connection 2: Master Ableton (IP:Port)
   - Test both connections work independently

2. **Create Configuration Objects**:
   ```lua
   -- Create text objects on project page:
   -- Name: "connection_band", Text: "1"
   -- Name: "connection_master", Text: "2"
   ```

3. **Create Test Helper Script** (at document root):
   ```lua
   -- Shared helper functions
   function getConnectionIndex(instance)
       local configName = "connection_" .. instance
       local configObj = root:findByName(configName)
       
       if configObj and configObj.values.text then
           return tonumber(configObj.values.text) or 1
       else
           print("Warning: No connection config for", instance)
           return 1
       end
   end
   
   function buildConnectionTable(connectionIndex)
       local connections = {}
       for i = 1, 10 do
           connections[i] = (i == connectionIndex)
       end
       return connections
   end
   
   function parseGroupName(name)
       if name:sub(1, 5) == "band_" then
           return "band", name:sub(6)
       elseif name:sub(1, 7) == "master_" then
           return "master", name:sub(8)
       else
           return "band", name  -- default
       end
   end
   
   -- Global refresh function
   function refreshAllGroups()
       local groups = root:findAllByProperty("tag", "trackGroup", true)
       for _, group in ipairs(groups) do
           group:notify("refresh")
       end
   end
   ```

### Phase 1: Single Group Test with Refresh
**Goal**: Test with one group including refresh mechanisms

1. **Duplicate One Group**:
   - Copy existing group (e.g., 'Hand 1 #')
   - Rename to 'band_Hand 1 #'
   - Add custom property: tag = "trackGroup"
   - Keep original for comparison

2. **Add Refresh Controls**:
   - Add refresh button to group
   - Add status indicator (label or LED)
   
3. **Update Initialization Script**:
   ```lua
   function init()
       -- Parse group name
       local instance, trackName = parseGroupName(self.name)
       
       -- Store data in script variables (not just tag)
       self.instance = instance
       self.trackName = trackName
       self.connectionIndex = getConnectionIndex(instance)
       self.lastVerified = getMillis()
       
       -- Initial track discovery
       refreshTrackMapping()
   end
   
   function refreshTrackMapping()
       print("Refreshing track mapping for:", self.name)
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
           local arguments = message[2]
           local trackFound = false
           
           for i = 1, #arguments do
               if arguments[i].value == self.trackName then
                   -- Found our track
                   self.trackNumber = i - 1
                   self.lastVerified = getMillis()
                   self.needsRefresh = false
                   trackFound = true
                   
                   -- Update status
                   if self.children.status_indicator then
                       self.children.status_indicator.color = {0, 1, 0}  -- Green = OK
                   end
                   
                   -- Store in tag for backwards compatibility
                   self.tag = self.instance .. ":" .. self.trackNumber
                   
                   -- Start listeners
                   local targetConnections = buildConnectionTable(self.connectionIndex)
                   sendOSC('/live/track/start_listen/volume', {self.trackNumber}, targetConnections)
                   sendOSC('/live/track/start_listen/output_meter_level', {self.trackNumber}, targetConnections)
                   sendOSC('/live/track/start_listen/mute', {self.trackNumber}, targetConnections)
                   sendOSC('/live/track/start_listen/panning', {self.trackNumber}, targetConnections)
                   
                   -- Update label
                   self.children["fdr_label"].values.text = self.trackName:match("(%w+)(.*)")
                   break
               end
           end
           
           if not trackFound then
               -- Track not found
               self.children["fdr_label"].values.text = "???"
               if self.children.status_indicator then
                   self.children.status_indicator.color = {1, 0, 0}  -- Red = Error
               end
               print("Track not found:", self.trackName)
           end
       end
   end
   
   function onNotify(param)
       if param == "refresh" then
           refreshTrackMapping()
       end
   end
   
   function update()
       -- Visual feedback for stale data
       local age = getMillis() - self.lastVerified
       if age > 60000 and self.children.status_indicator then  -- 1 minute
           self.children.status_indicator.color = {1, 0.5, 0}  -- Orange = Stale
       end
   end
   ```

4. **Add Refresh Button Script**:
   ```lua
   -- In refresh button
   function onValueChanged(key)
       if key == "x" and self.values.x == 1 then
           self.parent:notify("refresh")
           self.values.x = 0  -- Reset button
       end
   end
   ```

### Phase 2: Single Control Migration with Robust Sending
**Goal**: Test one control with connection-aware script

1. **Update Fader Script**:
   ```lua
   function onValueChanged(key)
       if key == "x" and self.values.touch then
           local parent = self.parent
           
           -- Validate parent has required data
           if not parent.trackNumber or not parent.connectionIndex then
               print("Error: Parent not initialized")
               return
           end
           
           -- Build connection table
           local connections = buildConnectionTable(parent.connectionIndex)
           
           -- Send to specific Ableton instance
           sendOSC("/live/track/" .. parent.trackNumber .. "/volume", 
                   {self.values.x}, connections)
       end
   end
   ```

### Phase 3: Bidirectional with Connection Filtering
**Goal**: Add receiving with connection filtering

```lua
function onReceiveOSC(message, connections)
    local parent = self.parent
    
    -- Validate parent
    if not parent.trackNumber or not parent.connectionIndex then return end
    
    -- Filter by connection
    if not connections[parent.connectionIndex] then return end
    
    -- Process message
    local path = message[1]
    local expectedPath = "/live/track/" .. parent.trackNumber .. "/volume"
    
    if path == expectedPath and message[2][1] then
        self.values.x = message[2][1].value
    end
end
```

### Phase 4: Add Auto-Refresh Option
**Goal**: Implement optional automatic refresh

1. **Create Global Auto-Refresh Toggle**:
   ```lua
   -- At document root
   function init()
       self.autoRefreshEnabled = false
       self.autoRefreshInterval = 30  -- seconds
       self.autoRefreshTimer = 0
   end
   
   function update()
       if self.autoRefreshEnabled then
           self.autoRefreshTimer = self.autoRefreshTimer + getFrameDelta()
           if self.autoRefreshTimer > self.autoRefreshInterval then
               refreshAllGroups()
               self.autoRefreshTimer = 0
           end
       end
   end
   ```

### Phase 5: Full Group Migration
**Goal**: Migrate all controls in test group with templates

### Phase 6: Multi-Instance Test
**Goal**: Test band and master groups together

### Phase 7: Full Rollout with Monitoring
**Goal**: Migrate all groups with refresh mechanisms

## Script Templates

### Parent Group with Refresh Support
```lua
function init()
    -- Parse and store info
    local instance, trackName = parseGroupName(self.name)
    self.instance = instance
    self.trackName = trackName
    self.connectionIndex = getConnectionIndex(instance)
    self.trackNumber = nil  -- Will be set by refresh
    self.lastVerified = 0
    
    -- Initial refresh
    refreshTrackMapping()
end

function refreshTrackMapping()
    print("Refreshing:", self.name)
    self.needsRefresh = true
    updateStatusIndicator("refreshing")
    
    local connections = buildConnectionTable(self.connectionIndex)
    sendOSC('/live/song/get/track_names', nil, connections)
end

function updateStatusIndicator(status)
    if not self.children.status_indicator then return end
    
    local colors = {
        refreshing = {1, 1, 0},     -- Yellow
        ok = {0, 1, 0},             -- Green
        error = {1, 0, 0},          -- Red
        stale = {1, 0.5, 0}         -- Orange
    }
    
    self.children.status_indicator.color = colors[status] or {0.5, 0.5, 0.5}
end

function onNotify(param)
    if param == "refresh" then
        refreshTrackMapping()
    end
end

function update()
    -- Check data age
    if self.lastVerified > 0 then
        local age = getMillis() - self.lastVerified
        if age > 60000 then  -- 1 minute
            updateStatusIndicator("stale")
        end
    end
end
```

### Child Control with Parent Validation
```lua
function getParentInfo()
    local p = self.parent
    if not p then 
        print("Error: No parent")
        return nil 
    end
    
    if not p.trackNumber or not p.connectionIndex then
        print("Error: Parent not initialized")
        return nil
    end
    
    return {
        trackNumber = p.trackNumber,
        connectionIndex = p.connectionIndex,
        instance = p.instance
    }
end

function onValueChanged(key)
    if key == "x" and self.values.touch then
        local info = getParentInfo()
        if not info then return end
        
        local connections = buildConnectionTable(info.connectionIndex)
        sendOSC("/live/track/" .. info.trackNumber .. "/volume", 
                {self.values.x}, connections)
    end
end

function onReceiveOSC(message, connections)
    local info = getParentInfo()
    if not info then return end
    
    -- Filter by connection
    if not connections[info.connectionIndex] then return end
    
    -- Process message
    local path = message[1]
    local expectedPath = "/live/track/" .. info.trackNumber .. "/volume"
    
    if path == expectedPath and message[2][1] then
        self.values.x = message[2][1].value
    end
end
```

## Testing Strategy

### Manual Refresh Test
1. Move tracks in Ableton
2. Press refresh button
3. Verify correct track control restored
4. Check status indicators

### Auto-Refresh Test
1. Enable auto-refresh
2. Move tracks in Ableton
3. Wait for refresh cycle
4. Verify automatic recovery

### Stress Test
1. Rapid track reordering
2. Multiple simultaneous refreshes
3. Connection loss/recovery
4. Performance monitoring

## Configuration Management

### Visual Feedback System
- **Green**: Connected and verified
- **Yellow**: Refreshing
- **Orange**: Data may be stale (>1 minute)
- **Red**: Track not found or error

### User Controls
- **Per-group refresh button**: Manual refresh
- **Global refresh button**: Refresh all groups
- **Auto-refresh toggle**: Enable/disable automatic refresh
- **Auto-refresh interval**: Configurable timing

## Benefits of This Approach
✅ **Robust against track reordering** with refresh mechanisms  
✅ **Visual feedback** shows connection status  
✅ **User control** over refresh timing  
✅ **No hardcoded indices** - uses configuration objects  
✅ **Graceful degradation** - works even if refresh fails  
✅ **Performance conscious** - refresh only when needed  

## Risk Mitigation
1. **Always store both name and index**
2. **Validate parent data before use**
3. **Provide manual refresh option**
4. **Visual feedback for all states**
5. **Test thoroughly with track reordering**
6. **Document refresh procedures for users**

## Next Steps
1. Review and approve updated phase document
2. Implement Phase 0 (preparation)
3. Test Phase 1 with single group
4. Iterate based on findings
5. Roll out incrementally through phases