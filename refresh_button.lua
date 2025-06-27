-- TouchOSC Refresh Button Script
-- Version: 1.1.0
-- Phase: 01 - Phase 1: Single Group Test

-- Script for refresh button within a group
function onValueChanged(key)
    if key == "x" and self.values.x == 1 then
        print("[refresh_button.lua] Refresh button pressed for", self.parent.name)
        -- Notify parent group to refresh
        self.parent:notify("refresh")
        -- Reset button
        self.values.x = 0
    end
end
