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
1. **Configuration Object**: Single text object defines connection mappings
2. **Logger Object**: Text object for visual debugging (optional)
3. **Group Naming**: Add instance prefix to group names (e.g., `band_Hand 1 #`)
4. **Script Routing**: Scripts read configuration and route messages accordingly
5. **Refresh Mechanisms**: Multiple strategies to handle track reordering

### Architecture Diagram
```
Root/Project Page
├── Configuration & Logger Objects
│   ├── configuration (text object with key-value pairs)
│   └── logger (text object for debug output) [optional]
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

### Phase 0: Preparation and Testing Setup ✅
**Goal**: Establish test environment without breaking existing functionality

1. **Configure Connections**:
   - Connection 1: Band Ableton (IP:Port)
   - Connection 2: Master Ableton (IP:Port)
   - Test both connections work independently

2. **Create Configuration Object**:
   ```
   # Create text object named "configuration" with content:
   connection_band: 1
   connection_master: 2
   # Comments are supported
   # Additional connections can be added:
   # connection_drums: 3
   ```

3. **Create Logger Object (Optional)**:
   - Create text object named "logger"
   - Make it tall enough for ~20 lines
   - Shows timestamped debug output

4. **Add Helper Script** (at document root):
   ```lua
   -- helper_script.lua v1.0.5
   -- Provides:
   -- - Configuration parsing from single text object
   -- - Logger functionality with timestamp
   -- - Connection routing helpers
   -- - Status color definitions
   -- - Group refresh functions
   ```

5. **Features Implemented**:
   - Single configuration text object with key-value format
   - Visual logger window (optional but recommended)
   - Global `log()` function for all scripts
   - Validation on startup showing version

### Phase 1: Single Group Test with Refresh
**Goal**: Test with one group including refresh mechanisms

1. **Duplicate One Group**:
   - Copy existing group (e.g., 'Hand 1 #')
   - Rename to 'band_Hand 1 #'
   - Add custom property: tag = "trackGroup"
   - Keep original for comparison

2. **Add Refresh Controls**:
   - Add refresh button to group
   - Add status indicator (label or LED) named 'status_indicator'
   
3. **Update Group Initialization Script**:
   ```lua
   -- group_init.lua v1.1.2
   -- Features:
   -- - Connection-aware initialization
   -- - Visual feedback via status indicator
   -- - Refresh mechanism
   -- - Logger integration
   ```

4. **Add Refresh Button Script**:
   ```lua
   -- refresh_button.lua v1.1.0
   -- Simple button to trigger parent refresh
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
               log("Error: Parent not initialized")
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

## Configuration Format

The configuration text object supports:
- **Key-value pairs**: `connection_name: number`
- **Comments**: Lines starting with `#`
- **Empty lines**: Ignored
- **Whitespace**: Automatically trimmed

Example configuration:
```
# TouchOSC Connection Configuration
# Format: connection_name: number

# Active connections
connection_band: 1
connection_master: 2

# Future connections (commented out)
# connection_drums: 3
# connection_keys: 4
# connection_bass: 5
```

## Logger Functionality

The optional logger text object provides:
- **Visual debugging**: See operations without console access
- **Timestamp format**: `[HH:MM:SS]` for each entry
- **Auto-scrolling**: Shows last 20 entries
- **Global function**: All scripts can use `log()` instead of `print()`
- **Fallback behavior**: Works even without logger object

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
    log("Refreshing:", self.name)
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
        log("Error: No parent")
        return nil 
    end
    
    if not p.trackNumber or not p.connectionIndex then
        log("Error: Parent not initialized")
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
5. Check logger output

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
✅ **Single configuration object** - Easy to manage connections  
✅ **Visual logger** - Debug without console access  
✅ **Robust against track reordering** with refresh mechanisms  
✅ **Visual feedback** shows connection status  
✅ **User control** over refresh timing  
✅ **No hardcoded indices** - uses configuration object  
✅ **Graceful degradation** - works even if refresh fails  
✅ **Performance conscious** - refresh only when needed  

## Risk Mitigation
1. **Always store both name and index**
2. **Validate parent data before use**
3. **Provide manual refresh option**
4. **Visual feedback for all states**
5. **Test thoroughly with track reordering**
6. **Document refresh procedures for users**
7. **Use logger for debugging issues**

## Version History
- **v1.0.0**: Initial helper script
- **v1.0.1**: Immediate validation
- **v1.0.2**: Changed to labels (deprecated)
- **v1.0.3**: Single configuration text object
- **v1.0.4**: Added logger functionality
- **v1.0.5**: Fixed global access issues
- **v1.1.0**: Group initialization script
- **v1.1.1**: Logger integration
- **v1.1.2**: Fixed log function availability

## Next Steps
1. Complete Phase 0 setup and validation ✅
2. Test Phase 1 with single group
3. Iterate based on findings
4. Roll out incrementally through phases
