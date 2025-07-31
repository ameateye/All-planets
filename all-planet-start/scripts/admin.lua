-- All Planet Start - Admin UI
-- Admin controls and clock system

-- ============================================================================
-- TIME FORMATTING (Adapted from redRafe's rr-clock)
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

-- ============================================================================
-- GUI SYSTEM - UNIFIED ADMIN AND CLOCK
-- ============================================================================

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if player then
        create_unified_gui(player)
    end
end)

function create_unified_gui(player)
    if not (player and player.valid) then return end
    
    -- Remove any existing GUI elements
    if player.gui.screen.aps_unified_gui then
        player.gui.screen.aps_unified_gui.destroy()
    end
    
    -- Create unified frame - simple structure like rr-clock
    local frame = player.gui.screen.add{
        type = 'frame',
        name = 'aps_unified_gui',
        direction = 'horizontal',
        style = 'quick_bar_slot_window_frame',
    }
    
    -- Fixed size and position like rr-clock
    frame.style.minimal_width = 220
    frame.style.minimal_height = 40
    frame.style.padding = 4
    frame.location = {10, 10}
    
    -- Store current element for updates (rr-clock pattern)
    if not storage.gui_elements then
        storage.gui_elements = {}
    end
    
    -- Determine what element to create and store reference
    if storage.selection_locked then
        -- In-game: show clock
        storage.gui_elements[player.index] = create_clock_element(frame)
    elseif storage.teleport_timer then
        -- Countdown: show countdown
        storage.gui_elements[player.index] = create_countdown_element(frame)
    elseif player.admin then
        -- Pre-game admin: show start button
        storage.gui_elements[player.index] = create_start_button_element(frame)
    else
        -- Pre-game player: show message
        storage.gui_elements[player.index] = create_message_element(frame)
    end
end

function create_start_button_element(frame)
    local button = frame.add{
        type = "button",
        name = "start_game_button",
        caption = "Start Game"
    }
    button.style.horizontal_align = 'center'
    button.style.vertical_align = 'center'
    button.style.horizontally_stretchable = true
    button.style.vertically_stretchable = true
    return {type = "button", element = button}
end

function create_message_element(frame)
    -- Create a flow container for centering (like rr-clock)
    local flow = frame.add{
        type = 'flow',
        direction = 'horizontal'
    }
    flow.style.horizontal_align = 'center'
    flow.style.vertical_align = 'center'
    flow.style.horizontally_stretchable = true
    flow.style.vertically_stretchable = true
    
    local label = flow.add{
        type = 'label',
        name = 'message_label',
        caption = "Choose planet to start"
    }
    label.style.font_color = {r = 255, g = 255, b = 255}
    return {type = "message", element = label}
end

function create_countdown_element(frame)
    local ticks_left = storage.teleport_timer - game.tick
    local seconds_left = math.ceil(ticks_left / 60)
    
    -- Create a flow container for centering (like rr-clock)
    local flow = frame.add{
        type = 'flow',
        direction = 'horizontal'
    }
    flow.style.horizontal_align = 'center'
    flow.style.vertical_align = 'center'
    flow.style.horizontally_stretchable = true
    flow.style.vertically_stretchable = true
    
    local label = flow.add{
        type = 'label',  
        name = 'countdown_label',
        caption = "Game starts in " .. seconds_left .. " seconds"
    }
    label.style.font_color = {r = 255, g = 255, b = 255}
    return {type = "countdown", element = label}
end

function create_clock_element(frame)
    -- Create a flow container for centering (like rr-clock)
    local flow = frame.add{
        type = 'flow',
        direction = 'horizontal'
    }
    flow.style.horizontal_align = 'center'
    flow.style.vertical_align = 'center'
    flow.style.horizontally_stretchable = true
    flow.style.vertically_stretchable = true
    
    local label = flow.add{
        type = 'label',
        name = 'time_label',
        caption = format_time(game.ticks_played)
    }
    label.style.font_color = {r = 255, g = 255, b = 255}
    return {type = "clock", element = label}
end

function refresh_all_guis()
    for _, player in pairs(game.players) do
        create_unified_gui(player)
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
        refresh_all_guis()  -- Update all GUIs to show countdown
        game.print("Admin " .. player.name .. " has started the game!")
    end
end)


-- Simple update function like rr-clock (global for control.lua)
function update_unified_gui(player)
    if not (player and player.valid) then 
        return 
    end
    
    local gui_data = storage.gui_elements and storage.gui_elements[player.index]
    if not gui_data or not gui_data.element or not gui_data.element.valid then
        create_unified_gui(player)
        return
    end
    
    local element = gui_data.element
    
    -- Update based on element type
    if gui_data.type == "clock" and storage.selection_locked then
        element.caption = format_time(game.ticks_played)
    elseif gui_data.type == "countdown" and storage.teleport_timer then
        local ticks_left = storage.teleport_timer - game.tick
        local seconds_left = math.ceil(ticks_left / 60)
        if seconds_left > 0 then
            element.caption = "Game starts in " .. seconds_left .. " seconds"
        end
    end
    
    -- Check if we need to change GUI state
    local current_state = get_gui_state(player)
    if gui_data.type ~= current_state then
        create_unified_gui(player)
    end
end

function get_gui_state(player)
    if storage.selection_locked then
        return "clock"
    elseif storage.teleport_timer then
        return "countdown"
    elseif player.admin then
        return "button"
    else
        return "message"  
    end
end

-- Note: Tick handler moved to control.lua to centralize and avoid conflicts