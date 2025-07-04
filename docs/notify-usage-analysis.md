# Notify Usage Analysis Report - abl-touchosc

## Executive Summary

Based on the analysis of the abl-touchosc repository, the `notify()` function is currently used for **inter-script communication** rather than logging. The recent logging refactor (v2.8.1+) successfully removed all centralized logging via notify, replacing it with local `log()` functions in each script.

**IMPORTANT: No high-frequency notify calls were found. All notify usage is for infrequent events.**

## Current Notify Usage

### 1. Document Script (`document_script.lua` v2.8.1)

**Receives notifications:**
- `register_configuration` - Configuration text object registers itself (once at startup)
- `configuration_updated` - Configuration has been changed (rare user action)
- `refresh_all_groups` - Trigger from global refresh button (user-triggered)

**Sends notifications:**
- `clear_mapping` - To all track groups before refresh (user-triggered)
- `refresh_tracks` - To all track groups to trigger mapping (user-triggered)

**Frequency:** Only during user-triggered refresh or configuration changes.

### 2. Global Refresh Button (`global_refresh_button.lua` v1.5.1)

**Sends notifications:**
- `refresh_all_groups` - To document script when button is touched

**Frequency:** Only when user taps the refresh button.

### 3. Group Init Script (`group_init.lua` v1.15.1)

**Receives notifications:**
- `refresh` or `refresh_tracks` - Triggers track mapping refresh
- `clear_mapping` - Clears OSC listeners and mapping

**Sends notifications:**
- `track_changed` - To child controls (fader, mute, etc.) with track number
- `track_type` - To child controls with track type (regular/return)
- `track_unmapped` - To child controls when track is not found

**Frequency:** Only when:
- Track names are received AND mapping is found (during refresh)
- Track is not found (during refresh)
- Never in response to frequent OSC messages like volume/meter updates

### 4. Control Scripts (Fader, Mute, Pan, Meter, DB Labels)

**All control scripts:**
- Only RECEIVE notify messages
- Never SEND notify messages
- Handle track mapping changes from parent group

**Frequency:** Only receive notifications during track mapping changes.

## High-Frequency Call Analysis

### ✅ No notify() in update() functions
- No scripts call notify in their update() loops

### ✅ No notify() in frequent OSC handlers
- Volume changes: NOT triggering notify
- Meter updates: NOT triggering notify
- Mute changes: NOT triggering notify
- Pan changes: NOT triggering notify

### ✅ No notify() in onValueChanged for frequent events
- Fader movements: NOT triggering notify
- Only button taps trigger notify (refresh button)

## Performance Impact Assessment

**Current notify usage has MINIMAL performance impact:**

1. **Startup:** 1-2 notify calls for configuration registration
2. **User Refresh:** ~10-20 notify calls (depending on track count)
3. **Normal Operation:** 0 notify calls
4. **During Performance:** 0 notify calls

The most frequent scenario is user-triggered refresh, which might send:
- 1 notify to document script
- N notifies to track groups (clear_mapping)
- N notifies to track groups (refresh_tracks)
- N*3 notifies from groups to children (track_changed, track_type, track_unmapped)

For a typical 8-track setup, this is ~40 notify calls, but only when the user manually refreshes.

## Why Notify is Still Needed

### 1. **Configuration Registration**
- The configuration text field needs to register itself with the document script
- This allows dynamic discovery without hardcoding object references

### 2. **Event Broadcasting**
- Global refresh needs to trigger actions across multiple groups simultaneously
- More efficient than polling or direct object manipulation

### 3. **Parent-Child Communication**
- Groups need to inform their child controls about track mapping changes
- Maintains loose coupling between components

### 4. **State Synchronization**
- Ensures all related controls update together when track mappings change
- Prevents inconsistent states across the UI

## Alternatives to Notify

### Option 1: Direct Object References
**Approach:** Store direct references to objects that need communication
```lua
-- In document script
local groups = root:findAllByProperty("tag", "trackGroup", true)
for _, group in ipairs(groups) do
    group.clearMapping()  -- Direct method call
end
```

**Pros:**
- More explicit and traceable
- Potentially faster execution

**Cons:**
- Tighter coupling between scripts
- Requires careful null checking
- May break if object structure changes

### Option 2: Global State Object
**Approach:** Create a shared state object accessible by all scripts
```lua
-- Global state in document script
_G.trackMappings = {
    band = { track = 5, type = "regular" },
    master = { track = 0, type = "return" }
}
```

**Pros:**
- Centralized state management
- Easy to debug state issues

**Cons:**
- Global namespace pollution
- Potential race conditions
- Harder to track state changes

### Option 3: Event Queue System
**Approach:** Implement a custom event queue without using notify
```lua
-- Custom event system
local eventQueue = {}
function postEvent(target, event, data)
    table.insert(eventQueue, {target=target, event=event, data=data})
end
```

**Pros:**
- More control over event processing
- Can add priorities, filtering, etc.

**Cons:**
- Requires implementation of polling mechanism
- More complex than built-in notify

### Option 4: OSC Loopback
**Approach:** Use OSC messages for internal communication
```lua
-- Send internal OSC messages
sendOSC('/touchosc/internal/refresh_group', 'band')
```

**Pros:**
- Leverages existing OSC infrastructure
- Could work across network if needed

**Cons:**
- Overhead of OSC encoding/decoding
- Requires OSC listener setup
- May conflict with actual OSC traffic

## Recommendations

### Keep Notify for Now
The current usage of `notify()` for inter-script communication is appropriate and efficient. The reasons to keep it:

1. **It's Working Well** - No performance issues reported
2. **Clean Architecture** - Maintains loose coupling between components
3. **Built-in Feature** - Using TouchOSC's intended mechanism
4. **Minimal Overhead** - Only used for infrequent events (configuration changes, refresh)
5. **No High-Frequency Usage** - Never called in update loops or frequent OSC handlers

### Future Improvements

1. **Document the Protocol**
   - Create a clear list of all notify messages and their contracts
   - Add this to the project documentation

2. **Add Safety Checks**
   ```lua
   function onReceiveNotify(action, value)
       if not action then return end
       -- Validate expected actions
   end
   ```

3. **Consider Notify Namespacing**
   ```lua
   -- Instead of: notify("refresh_tracks")
   -- Use: notify("group:refresh_tracks")
   ```

4. **Monitor Performance**
   - If performance becomes an issue, implement Option 1 (direct references) for high-frequency operations
   - Keep notify for configuration and infrequent events

## Conclusion

The current implementation uses `notify()` appropriately for event-driven communication between loosely coupled components. The recent logging refactor successfully removed the performance-impacting centralized logging system while preserving the essential inter-script communication mechanisms.

**No high-frequency notify calls were found.** All usage is limited to infrequent, user-triggered events or configuration changes. The performance impact is negligible.

No immediate changes are recommended, but the alternative approaches documented here can be considered if specific performance or architectural needs arise in the future.