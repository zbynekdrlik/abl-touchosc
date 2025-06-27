# TouchOSC Selective Connection Routing - Phase Document

## Problem Statement
Currently, all TouchOSC objects broadcast to all configured connections. We need to route specific faders to different Ableton instances:
- Some faders → Ableton "band" instance
- Other faders → Ableton "master" instance

Each Ableton instance runs AbletonOSC on different ports/IPs.

## Solution Overview

### Option 1: Per-Control Connection Selection (Recommended)
TouchOSC allows each control to send/receive messages on specific connections (up to 10 connections supported).

**Implementation Steps:**
1. Configure two connections in TouchOSC:
   - Connection 1: Band Ableton (e.g., 192.168.1.100:11000)
   - Connection 2: Master Ableton (e.g., 192.168.1.100:11001)

2. For each control/fader in TouchOSC editor:
   - Band faders: Enable only Connection 1 in message settings
   - Master faders: Enable only Connection 2 in message settings
   - Shared controls: Enable both connections if needed

3. The '∞' symbol in connection settings means "all connections" - avoid using this

### Option 2: Script-Based Routing
Use Lua scripting to control OSC destination programmatically.

**Implementation Steps:**
1. Modify `fader_script.lua` to check fader properties
2. Route messages based on fader name/property
3. Use `sendOSC()` with specific connection index parameter

## Detailed Implementation Plan

### Phase 1: Connection Setup
1. Define connection specifications:
   ```
   Connection 1 - Band:
   - Enabled: ✓
   - Host: [Band Ableton IP]
   - Send Port: [Band Port]
   - Receive Port: [Optional]
   
   Connection 2 - Master:
   - Enabled: ✓
   - Host: [Master Ableton IP]
   - Send Port: [Master Port]
   - Receive Port: [Optional]
   ```

### Phase 2: Object Configuration
1. Identify faders for each connection:
   - List band-specific faders
   - List master-specific faders

2. Configure each control's OSC messages:
   - Open control properties in TouchOSC editor
   - Go to Messages → OSC tab
   - For each message, enable only the appropriate connection(s)
   - Uncheck unwanted connections to prevent cross-communication

### Phase 3: Script Modifications (If using Option 2)
1. Update `fader_script.lua`:
   ```lua
   -- Pseudo-code structure
   function onValueChanged(key)
     local connection = determineConnection(self.name)
     if connection == "band" then
       sendOSC("/live/track/...", {value}, {1}) -- connection 1
     elseif connection == "master" then
       sendOSC("/live/track/...", {value}, {2}) -- connection 2
     end
   end
   ```

2. Create helper functions:
   - `determineConnection()`: Logic to identify target based on control name
   - `getConnectionIndex()`: Map logical names to connection indices (1 or 2)

### Phase 4: Testing Protocol
1. Test individual connections
2. Verify selective routing
3. Monitor both Ableton instances
4. Validate no cross-communication

## Technical Considerations

### TouchOSC Connection Features
- Supports up to 10 simultaneous connections
- Each control's messages can be individually configured for specific connections
- Connection indices start at 1 in scripts
- The sendOSC() function accepts connection index as third parameter

### Naming Conventions
Propose systematic naming:
- Band faders: `band_fader_[function]`
- Master faders: `master_fader_[function]`

### Pros/Cons Analysis

**Option 1 - Per-Control Configuration:**
- ✅ Native TouchOSC feature, no scripting required
- ✅ Visual configuration in editor
- ✅ Easy to see which control uses which connection
- ❌ Manual configuration for each control
- ❌ Changes require editing each control individually

**Option 2 - Script-Based:**
- ✅ Centralized routing logic
- ✅ Easy to change routing rules
- ✅ Can use dynamic conditions
- ❌ Requires Lua scripting knowledge
- ❌ Less visible in editor interface

## Recommendation
Start with Option 1 (Per-Control Connection Selection) as it uses native TouchOSC features and provides clear visual feedback. Consider Option 2 if you need dynamic routing based on runtime conditions.

## Next Steps
1. Confirm IP addresses and ports for both Ableton instances
2. Choose implementation approach
3. Create test layout with minimal faders
4. Configure connections and test routing
5. Scale to full implementation