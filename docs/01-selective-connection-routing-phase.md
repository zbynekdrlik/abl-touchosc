# TouchOSC Selective Connection Routing - Phase Document

## Problem Statement
Currently, all TouchOSC objects broadcast to all configured connections. We need to route specific faders to different Ableton instances:
- Some faders → Ableton "band" instance
- Other faders → Ableton "master" instance

Each Ableton instance runs AbletonOSC on different ports/IPs.

## Solution Overview

### Option 1: Connection Tags (Recommended)
TouchOSC supports connection tags to route messages selectively.

**Implementation Steps:**
1. Configure two connections in TouchOSC:
   - Connection 1: "band" (e.g., 192.168.1.100:11000)
   - Connection 2: "master" (e.g., 192.168.1.100:11001)

2. Tag each connection with unique identifier

3. Modify fader objects to use specific connection tags:
   - Band faders: Use connection tag "band"
   - Master faders: Use connection tag "master"

### Option 2: Script-Based Routing
Use Lua scripting to control OSC destination programmatically.

**Implementation Steps:**
1. Modify `fader_script.lua` to check fader properties
2. Route messages based on fader name/property
3. Use `sendOSC()` with specific connection parameter

## Detailed Implementation Plan

### Phase 1: Connection Setup
1. Define connection specifications:
   ```
   Band Connection:
   - Name: "ABL_Band"
   - IP: [Band Ableton IP]
   - Port: [Band Port]
   - Tag: "band"
   
   Master Connection:
   - Name: "ABL_Master"
   - IP: [Master Ableton IP]
   - Port: [Master Port]
   - Tag: "master"
   ```

### Phase 2: Object Configuration
1. Identify faders for each connection:
   - List band-specific faders
   - List master-specific faders

2. Configure connection settings per object:
   - In TouchOSC editor, set connection tags
   - Or add custom properties to identify routing

### Phase 3: Script Modifications
1. Update `fader_script.lua`:
   ```lua
   -- Pseudo-code structure
   function onValueChanged(key)
     local connection = determineConnection(self.name)
     if connection == "band" then
       sendOSC("/live/track/...", value, 1) -- connection 1
     elseif connection == "master" then
       sendOSC("/live/track/...", value, 2) -- connection 2
     end
   end
   ```

2. Create helper functions:
   - `determineConnection()`: Logic to identify target
   - `getConnectionIndex()`: Map names to connection indices

### Phase 4: Testing Protocol
1. Test individual connections
2. Verify selective routing
3. Monitor both Ableton instances
4. Validate no cross-communication

## Technical Considerations

### TouchOSC Features
- Connection indexing starts at 1
- Scripts can access connection properties
- Objects can have custom properties for routing logic

### Naming Conventions
Propose systematic naming:
- Band faders: `band_fader_[function]`
- Master faders: `master_fader_[function]`

### Error Handling
- Validate connection availability
- Fallback behavior if connection fails
- Debug logging for troubleshooting

## Next Steps
1. Confirm IP addresses and ports for both Ableton instances
2. Decide between connection tags vs script-based routing
3. Create test layout with minimal faders
4. Implement and test routing logic
5. Scale to full implementation