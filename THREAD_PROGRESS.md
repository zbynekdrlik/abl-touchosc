# Thread Progress Tracking

## CRITICAL CURRENT STATE
**⚠️ ABLETONOSC BUG IDENTIFIED - CROSS-WIRED LISTENERS:**
- [x] Issue identified: Multiple tracks receiving same listener events
- [x] Pattern found: Track 5 broadcasts to tracks 5,6,7; Track 8 responds as track 10
- [x] Root cause: AbletonOSC listener system bug (not TouchOSC issue)
- [ ] Next step: Fork AbletonOSC and investigate the bug

## Implementation Status
- Phase: BUG ROOT CAUSE IDENTIFIED
- Status: NEED TO FORK ABLETONOSC
- Branch: feature/track-8-10-mismatch

## Issue Analysis
User logs show clear evidence of AbletonOSC listener cross-wiring:

**Track 5 broadcasting to multiple tracks:**
```
SEND: /live/track/set/volume FLOAT(5) FLOAT(0.7755736)
RECEIVE: /live/track/get/volume FLOAT(5) FLOAT(0.7755736)
RECEIVE: /live/track/get/volume FLOAT(6) FLOAT(0.7755736)
RECEIVE: /live/track/get/volume FLOAT(7) FLOAT(0.7755736)
```

**Track 8 receiving as track 10:**
```
SEND: /live/track/set/volume FLOAT(8) FLOAT(0.7574361)
RECEIVE: /live/track/get/volume FLOAT(10) FLOAT(0.7574361)
```

## Key Findings
1. This is NOT a TouchOSC issue
2. The problem is in AbletonOSC's listener registration/routing
3. No hidden tracks, no group tracks - pure AbletonOSC bug
4. Pattern suggests listeners are being registered to wrong track indices

## Next Steps for User
1. Fork https://github.com/ideoforms/AbletonOSC
2. Share the fork URL so we can investigate
3. We'll look into:
   - `track.py` - how listeners are registered
   - `handler.py` - how messages are routed
   - The start_listen/stop_listen implementation

## Likely Bug Location
Based on the pattern, the bug is probably in how AbletonOSC:
- Registers volume listeners to track objects
- Routes responses back with track indices
- Manages the listener callback registry

## Temporary Workarounds
1. Avoid using tracks that exhibit this behavior
2. Rename tracks in Ableton to work around the issue
3. Use only tracks that respond correctly

## Diagnostic Tools Created
- track_mismatch_test.lua v1.1.0 - Tests for listener cross-wiring
- Located in scripts/diagnostics/

## Previous Issue (RESOLVED)
**Multi-connection support restored in meter scripts:**
- meter_script.lua v2.5.2 ✅
- db_meter_label.lua v2.6.2 ✅
- db_label.lua v1.3.2 ✅
- PR #20 ready for merge
