-- All Planet Start - Main Control Script
-- Modular organization for multi-planet start functionality

require("scripts.lobby")
require("scripts.core")
require("scripts.admin")
require("scripts.platform")

-- Centralized tick handler to avoid conflicts between modules
script.on_nth_tick(60, function(event)
    -- Update GUI elements (from admin.lua)
    for _, player in pairs(game.players) do
        update_unified_gui(player)
    end
    
    -- Check space platform schedules (from platform.lua)
    check_platform_schedules()
end)