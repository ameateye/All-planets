-- All Planet Start - Admin UI
-- Admin controls and clock system

-- ============================================================================
-- GUI SYSTEM - ADMIN START BUTTON
-- ============================================================================

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if player then
        create_start_game_button(player)
        create_clock(player)
    end
end)

function create_start_game_button(player)
    if not player.admin or storage.teleport_timer or storage.selection_locked then
        return
    end
    
    if player.gui.screen.start_game_button then
        player.gui.screen.start_game_button.destroy()
    end
    
    local button = player.gui.screen.add{
        type = "button",
        name = "start_game_button",
        caption = "Start Game"
    }
    button.style.minimal_width = 120
    button.style.height = 35
    button.location = {10, 10}
end

function hide_start_game_buttons()
    for _, player in pairs(game.players) do
        if player.gui.screen.start_game_button then
            player.gui.screen.start_game_button.destroy()
        end
    end
end

script.on_event(defines.events.on_gui_click, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    
    if event.element.name == "start_game_button" then
        if not player.admin then
            player.print("Only admins can start the game!")
            return
        end
        
        if storage.teleport_timer or storage.selection_locked then
            player.print("Game has already started!")
            return
        end
        
        start_teleport_countdown()
        hide_start_game_buttons()
        game.print("Admin " .. player.name .. " has started the game!")
    end
end)

-- ============================================================================
-- CLOCK SYSTEM (Adapted from redRafe's rr-clock)
-- ============================================================================

local SECONDS = 60
local MINUTES = 60 * SECONDS
local HOURS = 60 * MINUTES
local DAYS = 24 * HOURS

local function format_time(ticks)
    local floor = math.floor
    local days = floor(ticks / DAYS)
    local hours = floor(ticks / HOURS) % 24
    local minutes = floor(ticks / MINUTES) % 60
    local seconds = floor(ticks / SECONDS) % 60
    
    if days > 0 then
        return string.format("%dd %02d:%02d:%02d", days, hours, minutes, seconds)
    else
        return string.format("%02d:%02d:%02d", hours, minutes, seconds)
    end
end

function create_clock(player)
    if not (player and player.valid) then return end
    
    local frame = player.gui.screen.aps_clock
    if frame then
        frame.destroy()
    end
    
    -- Create frame using redRafe's styling approach
    frame = player.gui.screen.add{
        type = 'frame',
        name = 'aps_clock',
        direction = 'horizontal',
        style = 'quick_bar_slot_window_frame',
    }
    
    -- Set frame properties (adapted from redRafe)
    frame.style.minimal_width = 100
    frame.style.minimal_height = 24
    frame.style.padding = 2
    frame.location = {10, 10}
    
    -- Add time label with redRafe's styling
    local label = frame.add{
        type = 'label',
        name = 'time_label',
        caption = format_time(game.ticks_played)
    }
    label.style.font_color = {r = 255, g = 255, b = 255}
    label.style.horizontal_align = 'center'
end

local function update_clock(player)
    if not (player and player.valid) then return end
    
    local frame = player.gui.screen.aps_clock
    if frame and frame.time_label then
        frame.time_label.caption = format_time(game.ticks_played)
    end
end

-- Update clocks every second
script.on_nth_tick(60, function(event)
    for _, player in pairs(game.players) do
        update_clock(player)
    end
end)