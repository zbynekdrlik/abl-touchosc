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

## Recommended Solution: Configuration-Based Routing with Prefix Naming

### Overview
1. **Configuration Objects**: Create text objects that define which connection to use for each instance
2. **Group Naming**: Add instance prefix to group names (e.g., `band_Hand 1 #`)
3. **Script Routing**: Scripts read configuration and route messages accordingly

### Architecture Diagram
```
Root/Project Page
├── Configuration Objects
│   ├── connection_band (text: "1")
│   ├── connection_master (text: "2")
│   └── connection_drums (text: "3")  // Future
│
└── Track Groups
    ├── band_Hand 1 # (routes to connection 1)
    ├── band_Hand 2 # (routes to connection 1)
    ├── master_Vox 1 # (routes to connection 2)
    └── master_Vox 2 # (routes to connection 2)
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
   ```

### Phase 1: Single Group Test (Non-Breaking)
**Goal**: Test with one group without affecting others

1. **Duplicate One Group**:
   - Copy existing group (e.g., 'Hand 1 #')
   - Rename to 'band_Hand 1 #'
   - Keep original for comparison

2. **Update Initialization Script** (only in test group):
   ```lua
   function init()
       -- Parse group name
       local instance, trackName = parseGroupName(self.name)
       self.tempInstance = instance
       
       -- Get connection from config
       local connectionIndex = getConnectionIndex(instance)
       local connections = buildConnectionTable(connectionIndex)
       
       -- Request track names from specific connection
       sendOSC('/live/song/get/track_names', nil, connections)
   end
   
   function onReceiveOSC(message, connections)
       -- Filter by connection
       local instance = self.tempInstance or parseGroupName(self.name)
       local expectedConnection = getConnectionIndex(instance)
       
       if not connections[expectedConnection] then
           return  -- Wrong connection
       end
       
       -- [Rest of existing logic with connection-aware sending]
   end
   ```

3. **Test Checklist**:
   - [ ] Group finds correct track number
   - [ ] Initialization only talks to band Ableton
   - [ ] No interference with original groups
   - [ ] Configuration change (text "1" → "2") works

### Phase 2: Single Control Migration
**Goal**: Test one control with script-based routing

1. **Choose Simple Control** (e.g., volume fader in test group)

2. **Migration Steps**:
   - Note current OSC message address
   - Disable GUI "Send" (keep "Receive" for now)
   - Add script sending:
   ```lua
   function onValueChanged(key)
       if key == "x" and self.values.touch then
           local parentTag = self.parent.tag
           local instance, trackNumber = parentTag:match("([^:]+):(.+)")
           
           local connectionIndex = getConnectionIndex(instance)
           local connections = buildConnectionTable(connectionIndex)
           
           sendOSC("/live/track/" .. trackNumber .. "/volume", 
                   {self.values.x}, connections)
       end
   end
   ```

3. **Test**:
   - [ ] Fader sends only to band Ableton
   - [ ] Other faders still work normally
   - [ ] Changing connection_band text changes routing

### Phase 3: Bidirectional Test
**Goal**: Add receiving with connection filtering

1. **Add Receive Script** to same fader:
   ```lua
   function onReceiveOSC(message, connections)
       local parentTag = self.parent.tag
       local instance, trackNumber = parentTag:match("([^:]+):(.+)")
       local expectedConnection = getConnectionIndex(instance)
       
       if not connections[expectedConnection] then
           return  -- Wrong connection
       end
       
       -- Process message
       local path = message[1]
       local expectedPath = "/live/track/" .. trackNumber .. "/volume"
       
       if path == expectedPath and message[2][1] then
           self.values.x = message[2][1].value
       end
   end
   ```

2. **Test**:
   - [ ] Fader receives only from band Ableton
   - [ ] Moving fader in Ableton updates TouchOSC
   - [ ] No cross-talk from master Ableton

### Phase 4: Full Group Migration
**Goal**: Migrate all controls in test group

1. **Create Script Templates** for common controls:
   - Fader script
   - Button script
   - Meter script
   - Label script

2. **Systematic Migration**:
   - List all controls in group
   - Apply appropriate template to each
   - Test each control individually

3. **Group Test**:
   - [ ] All controls route correctly
   - [ ] No performance issues
   - [ ] Configuration changes work

### Phase 5: Second Instance Test
**Goal**: Verify multiple instances work together

1. **Create Master Group**:
   - Copy a different group
   - Rename with 'master_' prefix
   - Apply same migration steps

2. **Cross-Instance Test**:
   - [ ] Band groups only talk to band Ableton
   - [ ] Master groups only talk to master Ableton
   - [ ] Can run both simultaneously
   - [ ] No cross-talk

### Phase 6: Full Rollout
**Goal**: Migrate all groups systematically

1. **Migration Order**:
   - Critical groups first
   - Similar groups in batches
   - Non-critical groups last

2. **Rollback Plan**:
   - Keep original groups disabled but not deleted
   - Can revert by renaming back
   - Document any issues found

## Script Templates

### Parent Group Initialization
```lua
function init()
    local instance, trackName = parseGroupName(self.name)
    self.tempInstance = instance
    
    local connectionIndex = getConnectionIndex(instance)
    local connections = buildConnectionTable(connectionIndex)
    
    sendOSC('/live/song/get/track_names', nil, connections)
end

function onReceiveOSC(message, connections)
    local instance = self.tempInstance or parseGroupName(self.name)
    local expectedConnection = getConnectionIndex(instance)
    
    if not connections[expectedConnection] then return end
    
    local path = message[1]
    if path ~= '/live/song/get/track_names' then return end
    
    local trackName = self.name:match("^%w+_(.+)$") or self.name
    local arguments = message[2]
    
    for i = 1, #arguments do
        if arguments[i].value == trackName then
            local trackNumber = i - 1
            self.tag = instance .. ":" .. trackNumber
            
            local targetConnections = buildConnectionTable(expectedConnection)
            
            -- Start listeners
            sendOSC('/live/track/start_listen/volume', {trackNumber}, targetConnections)
            sendOSC('/live/track/start_listen/output_meter_level', {trackNumber}, targetConnections)
            sendOSC('/live/track/start_listen/mute', {trackNumber}, targetConnections)
            sendOSC('/live/track/start_listen/panning', {trackNumber}, targetConnections)
            
            -- Update label
            self.children["fdr_label"].values.text = arguments[i].value:match("(%w+)(.*)")
            self.tempInstance = nil
            return
        end
    end
    
    self.children["fdr_label"].values.text = "???"
end
```

### Generic Child Control Script
```lua
function onValueChanged(key)
    if key == "[value_key]" then  -- Replace with actual key
        local parentTag = self.parent.tag
        if not parentTag then return end
        
        local instance, trackNumber = parentTag:match("([^:]+):(.+)")
        if not instance or not trackNumber then return end
        
        local connectionIndex = getConnectionIndex(instance)
        local connections = buildConnectionTable(connectionIndex)
        
        sendOSC("/live/track/" .. trackNumber .. "/[parameter]", 
                {self.values[key]}, connections)
    end
end

function onReceiveOSC(message, connections)
    local parentTag = self.parent.tag
    if not parentTag then return end
    
    local instance, trackNumber = parentTag:match("([^:]+):(.+)")
    if not instance or not trackNumber then return end
    
    local expectedConnection = getConnectionIndex(instance)
    if not connections[expectedConnection] then return end
    
    local path = message[1]
    local expectedPath = "/live/track/" .. trackNumber .. "/[parameter]"
    
    if path == expectedPath and message[2][1] then
        self.values.[value_key] = message[2][1].value
    end
end
```

## Testing Strategy

### Connection Test Script
Create a test button that verifies routing:
```lua
function onValueChanged(key)
    if key == "x" and self.values.x == 1 then
        -- Test all configurations
        local instances = {"band", "master"}
        
        for _, instance in ipairs(instances) do
            local connIdx = getConnectionIndex(instance)
            print(instance .. " uses connection " .. connIdx)
            
            -- Send test message
            local connections = buildConnectionTable(connIdx)
            sendOSC("/test/" .. instance, {"ping"}, connections)
        end
    end
end
```

### Debug Helper
Add to any script for troubleshooting:
```lua
function debugConnection(message, connections)
    print("Message from connections:")
    for i, active in ipairs(connections) do
        if active then
            print("  Connection " .. i .. ": Active")
        end
    end
end
```

## Configuration Management

### Best Practices
1. **Naming Convention**: Always use `connection_[instance]` format
2. **Documentation**: Add labels next to config objects explaining purpose
3. **Validation**: Config objects should show red if invalid value
4. **Backup**: Screenshot configuration before major changes

### Advanced Configuration
For complex setups, consider a configuration panel:
```
Configuration Panel
├── Band Section
│   ├── Connection: [1] [2] [3] ...
│   ├── IP: [192.168.1.100]
│   └── Port: [11000]
│
└── Master Section
    ├── Connection: [1] [2] [3] ...
    ├── IP: [192.168.1.101]
    └── Port: [11001]
```

## Success Criteria
- [ ] No manual connection selection per control
- [ ] Visual indication of routing in group names
- [ ] Easy to change connections via config objects
- [ ] No cross-talk between instances
- [ ] Performance comparable to original
- [ ] Can add new instances without code changes

## Risk Mitigation
1. **Test thoroughly** at each phase
2. **Keep backups** of working configuration
3. **Document issues** as they arise
4. **Have rollback plan** ready
5. **Test under real performance conditions**

## Next Steps
1. Review and approve phase document
2. Set up test environment (Phase 0)
3. Begin Phase 1 with single group test
4. Iterate based on findings
5. Proceed through phases systematically