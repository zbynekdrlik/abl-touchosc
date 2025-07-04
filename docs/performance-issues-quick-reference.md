# Performance Issues Quick Reference

## 🔥 Critical Issues Found (2025-07-03)

### Issue #1: update() Runs Every Frame
**Impact**: SEVERE  
**Location**: All scripts (group_init, fader_script, meter_script)  
**Problem**: Functions run 60-120 times per second even when idle  
**Fix**: Use scheduled updates instead

### Issue #2: Debug Code Always Executes
**Impact**: HIGH  
**Location**: All scripts  
**Problem**: String operations happen even when DEBUG=0  
**Fix**: Early return before expensive operations

### Issue #3: Continuous Monitoring
**Impact**: HIGH  
**Location**: group_init.lua - monitorActivity()  
**Problem**: Checks fader position every frame  
**Fix**: Only monitor on actual changes

### Issue #4: Status Indicator Updates
**Impact**: MEDIUM  
**Location**: group_init.lua - updateStatusIndicator()  
**Problem**: Color calculations every frame  
**Fix**: Cache colors, update only on state change

## 📊 Performance Impact

With 16 tracks:
- 16 × update() in group scripts
- 16 × update() in fader scripts  
- 16 × color calculations
- 16 × activity monitoring
- = **Minimum 32 functions × 60 FPS = 1,920 calls/second!**

## 🚀 Quick Fixes

### 1. Replace update() with Scheduled Updates
```lua
-- BAD (runs every frame)
function update()
    doSomething()
end

-- GOOD (runs every 100ms)
function init()
    self:schedule(100)
end

function onSchedule()
    doSomething()
end
```

### 2. Proper Debug Guards
```lua
-- BAD (string operations always happen)
function debugPrint(...)
    if DEBUG == 1 then
        local msg = table.concat({...}, " ")
        print(msg)
    end
end

-- GOOD (early return)
function debugPrint(...)
    if DEBUG ~= 1 then return end
    local msg = table.concat({...}, " ")
    print(msg)
end
```

### 3. Cache Expensive Operations
```lua
-- BAD (calculate every time)
function update()
    local color = calculateColor(value)
    self.color = color
end

-- GOOD (only when changed)
local lastValue = nil
local cachedColor = nil

function update()
    if value ~= lastValue then
        cachedColor = calculateColor(value)
        lastValue = value
    end
    self.color = cachedColor
end
```

## 🎯 Priority Order

1. **Remove frame-based updates** (biggest impact)
2. **Fix debug code** (easy win)
3. **Cache calculations** (moderate effort)
4. **Batch OSC messages** (advanced)

## 📈 Expected Results

- **Quick fixes**: 50-70% performance improvement
- **Full optimization**: 80-90% improvement
- **Target**: Smooth operation with 32+ tracks

## 🔧 Testing Command

Add this to any script to measure update frequency:
```lua
local updateCount = 0
local lastReport = 0

function update()
    updateCount = updateCount + 1
    local now = getMillis()
    
    if now - lastReport > 1000 then
        print("Updates per second: " .. updateCount)
        updateCount = 0
        lastReport = now
    end
    
    -- Regular update code here
end
```

---

Remember: These issues affect ALL users, not just return track users. The optimization will benefit everyone!