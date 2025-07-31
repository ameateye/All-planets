-- All Planet Start - Core Gameplay
-- Team selection, countdown timer, and teleportation system

-- ============================================================================
-- PLANET SELECTION SYSTEM
-- ============================================================================

local planet_colors = {
    nauvis = {r = 0, g = 0, b = 1},        -- Blue
    gleba = {r = 0, g = 1, b = 0},         -- Green
    vulcanus = {r = 0.5, g = 0.5, b = 0.5}, -- Grey
    fulgora = {r = 0.5, g = 0, b = 1}      -- Purple
}

function detect_planet_area(position)
    local platform_size = 25
    local square_size = 20
    local cancel_area_size = 15  -- Central cancel area
    local x, y = position.x, position.y
    
    -- Check cancel area first (center of platform with hazard concrete)
    if x >= -cancel_area_size/2 and x <= cancel_area_size/2 and y >= -cancel_area_size/2 and y <= cancel_area_size/2 then
        return "cancel"
    end
    
    if x >= -square_size/2 and x <= square_size/2 and y >= -(platform_size + square_size - 1) and y <= -platform_size then
        return "nauvis"
    elseif x >= platform_size and x <= platform_size + square_size - 1 and y >= -square_size/2 and y <= square_size/2 then
        return "gleba"
    elseif x >= -square_size/2 and x <= square_size/2 and y >= platform_size and y <= platform_size + square_size - 1 then
        return "fulgora"
    elseif x >= -(platform_size + square_size - 1) and x <= -platform_size and y >= -square_size/2 and y <= square_size/2 then
        return "vulcanus"
    end
    
    return nil
end

function update_player_selection(player, planet)
    if not player or not planet then return end
    
    storage.player_selections[player.index] = planet
    player.color = planet_colors[planet]
    
    if storage.selection_locked then
        -- Game has started, start personal countdown for late joiner
        player.print("Game has already started! You selected " .. planet:gsub("^%l", string.upper) .. ". Teleporting in 5 seconds...")
        start_personal_teleport_timer(player, planet)
    else
        game.print("Player " .. player.name .. " selected " .. planet:gsub("^%l", string.upper) .. "!")
    end
end

function clear_player_selection(player)
    if not player then return end
    
    local current_selection = storage.player_selections[player.index]
    if current_selection then
        storage.player_selections[player.index] = nil
        player.color = {r = 1, g = 1, b = 1}  -- Reset to white
        
        -- Cancel personal timer if active
        if storage.personal_timers and storage.personal_timers[player.index] then
            storage.personal_timers[player.index] = nil
            player.print("Teleportation cancelled.")
        end
        
        if not storage.selection_locked then
            game.print("Player " .. player.name .. " deselected their planet.")
        end
    end
end

function start_personal_teleport_timer(player, planet)
    if not storage.personal_timers then
        storage.personal_timers = {}
    end
    
    storage.personal_timers[player.index] = {
        end_tick = game.tick + (5 * 60), -- 5 seconds
        planet = planet,
        last_announced = nil
    }
end

script.on_event(defines.events.on_player_changed_position, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.surface or player.surface.name ~= "lobby" then
        return
    end
    
    -- Don't trigger planet selection while in map mode
    if player.render_mode == defines.render_mode.chart or player.render_mode == defines.render_mode.chart_zoomed_in then
        return
    end
    
    local area = detect_planet_area(player.position)
    if area == "cancel" then
        clear_player_selection(player)
    elseif area then
        local current_selection = storage.player_selections[player.index]
        if current_selection ~= area then
            update_player_selection(player, area)
        end
    end
end)

-- ============================================================================
-- COUNTDOWN TIMER SYSTEM
-- ============================================================================

function start_teleport_countdown()
    if storage.teleport_timer then return end
    
    storage.teleport_timer = game.tick + (storage.teleport_delay * 60)
    game.print("Game countdown started! " .. storage.teleport_delay .. " seconds until departure.")
end

function should_announce_time(seconds_left)
    return (seconds_left % 10 == 0 and seconds_left > 0) or (seconds_left >= 1 and seconds_left <= 5)
end

script.on_event(defines.events.on_tick, function(event)
    -- Handle main countdown timer
    if storage.teleport_timer then
        local ticks_left = storage.teleport_timer - game.tick
        local seconds_left = math.ceil(ticks_left / 60)
        
        storage.last_announced_second = storage.last_announced_second or -1
        
        -- Announce countdown
        if ticks_left > 0 and should_announce_time(seconds_left) and seconds_left ~= storage.last_announced_second then
            storage.last_announced_second = seconds_left
            if seconds_left > 5 then
                game.print("Game start in " .. seconds_left .. " seconds...")
            else
                game.print("Game start in " .. seconds_left .. "!")
            end
        end
        
        -- Timer completed
        if ticks_left <= 0 then
            storage.teleport_timer = nil
            storage.selection_locked = true
            storage.last_announced_second = nil
            game.print("Game starts")
            teleport_players_to_planets()
            -- Reset time played to start counting from when players actually start playing
            game.reset_time_played()
        end
    end
    
    -- Handle personal timers for late joiners
    if storage.personal_timers then
        for player_index, timer in pairs(storage.personal_timers) do
            local player = game.get_player(player_index)
            if player and player.valid then
                local ticks_left = timer.end_tick - game.tick
                local seconds_left = math.ceil(ticks_left / 60)
                
                -- Announce personal countdown
                if ticks_left > 0 and seconds_left ~= timer.last_announced and seconds_left <= 5 and seconds_left >= 1 then
                    timer.last_announced = seconds_left
                    player.print("Teleporting in " .. seconds_left .. "!")
                end
                
                -- Personal timer completed
                if ticks_left <= 0 then
                    teleport_player_to_planet(player, timer.planet)
                    storage.personal_timers[player_index] = nil
                end
            else
                -- Clean up invalid player
                storage.personal_timers[player_index] = nil
            end
        end
    end
end)

-- ============================================================================
-- TELEPORTATION SYSTEM
-- ============================================================================

function teleport_players_to_planets()
    for _, player in pairs(game.players) do
        local selected_planet = storage.player_selections[player.index]
        if selected_planet then
            teleport_player_to_planet(player, selected_planet)
        end
    end
end

-- Planet welcome messages
local planet_messages = {
    nauvis = "Welcome to Nauvis! Say hello to the biters!",
    vulcanus = "Welcome to Vulcanus! Watch out for the lava!",
    gleba = "Welcome to Gleba! Beware of the spoilage and pentapods!",
    fulgora = "Welcome to Fulgora! Mind the lightning storms!"
}

function teleport_player_to_planet(player, planet_name)
    -- Check if planet surface already exists
    local existing_surface = game.get_surface(planet_name)
    local is_first_player = (existing_surface == nil)
    
    -- Create planet surface
    local surface = game.planets[planet_name].create_surface()
    
    -- Generate chunks and find spawn position
    surface.request_to_generate_chunks({0, 0}, 3)
    surface.force_generate_chunk_requests()
    
    local spawn_position = surface.find_non_colliding_position("character", {0, 0}, 32, 1) or {0, 0}
    
    -- Handle equipment based on first player status
    if is_first_player then
        -- First player (crash survivor): reduced equipment
        player.insert{name = "pistol", count = 1}
        player.insert{name = "burner-mining-drill", count = 1}
        player.insert{name = "stone-furnace", count = 1}
        player.insert{name = "firearm-magazine", count = 2}
        player.insert{name = "wood", count = 1}
    else
        -- Subsequent players: full standard starting equipment
        player.insert{name = "iron-plate", count = 8}
        player.insert{name = "pistol", count = 1}
        player.insert{name = "firearm-magazine", count = 10}
        player.insert{name = "burner-mining-drill", count = 1}
        player.insert{name = "stone-furnace", count = 1}
        player.insert{name = "wood", count = 1}
    end
    
    -- Teleport player
    player.teleport(spawn_position, surface)
    player.print(planet_messages[planet_name])
    
    -- Legacy compatibility
    if planet_name == "nauvis" then
        storage.nauvis_visited = true
    end
end