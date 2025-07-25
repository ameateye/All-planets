-- All Planet Start - Control Script
-- Creates a space platform lobby where players spawn and select their starting planet

-- ============================================================================
-- INITIALIZATION AND CONFIGURATION
-- ============================================================================

script.on_init(function()
    -- Skip intro and disable crashsite like Any Planet Start does
    if remote.interfaces.freeplay then
        storage.disable_crashsite = remote.call("freeplay", "get_disable_crashsite")
        storage.skip_intro = remote.call("freeplay", "get_skip_intro")
        
        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", true)
    end
    
    -- Initialize storage variables
    storage.lobby_generated = false
    storage.player_selections = {}
    storage.teleport_timer = nil
    storage.teleport_delay = 10
    storage.selection_locked = false
    
    --Unlock all space locations since this is an all-planet start mod
    local force = game.forces.player
    local space_locations = {"nauvis", "vulcanus", "gleba", "fulgora"}
    for _, location in pairs(space_locations) do
        force.unlock_space_location(location)
    end
end)

script.on_configuration_changed(function(event)
    if event.mod_changes and event.mod_changes["all-planet-start"] then
        -- Initialize storage variables if they don't exist
        storage.player_selections = storage.player_selections or {}
        storage.teleport_timer = storage.teleport_timer or nil
        storage.teleport_delay = storage.teleport_delay or 10
        storage.selection_locked = storage.selection_locked or false
        
        -- Handle existing players
        for _, player in pairs(game.players) do
            handle_player_spawn(player.index)
            create_start_game_button(player)
        end
    end
end)

-- ============================================================================
-- PLAYER SPAWN AND LOBBY MANAGEMENT
-- ============================================================================

script.on_event(defines.events.on_player_created, function(event)
    -- Initialize storage if needed (safety check)
    storage.player_selections = storage.player_selections or {}
    storage.teleport_timer = storage.teleport_timer or nil
    storage.teleport_delay = storage.teleport_delay or 10
    storage.selection_locked = storage.selection_locked or false
    
    handle_player_spawn(event.player_index)
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if player then
        create_start_game_button(player)
    end
end)

function handle_player_spawn(player_index)
    local player = game.get_player(player_index)
    if not player then return end
    
    -- Create lobby surface if needed
    if not storage.lobby_surface then
        storage.lobby_surface = game.create_surface("lobby", {
            starting_area = "none",
            peaceful_mode = true,
            default_enable_all_autoplace_controls = false,
            autoplace_controls = {},
            cliff_settings = {richness = 0}
        })
        
        -- Configure lighting
        storage.lobby_surface.always_day = true
        storage.lobby_surface.show_clouds = false
        
        storage.lobby_surface.request_to_generate_chunks({0, 0}, 3)
        storage.lobby_surface.force_generate_chunk_requests()
    end
    
    -- Generate lobby terrain once
    if not storage.lobby_generated then
        storage.lobby_generated = true
        generate_lobby_terrain(storage.lobby_surface)
    end
    
    -- Teleport player to lobby
    local spawn_position = storage.lobby_surface.find_non_colliding_position("character", {0, 0}, 0, 1)
    player.teleport(spawn_position, storage.lobby_surface)
    
    -- Chart lobby area to remove fog of war
    local platform_size = 25
    local square_size = 20
    local lobby_area = {
        left_top = {-(platform_size + square_size), -(platform_size + square_size)},
        right_bottom = {platform_size + square_size, platform_size + square_size}
    }
    player.force.chart(storage.lobby_surface, lobby_area)
    
    -- Clear Nauvis if not visited
    if not storage.nauvis_visited then
        local nauvis = game.get_surface("nauvis")
        if nauvis then
            nauvis.clear()
        end
    end
    
    -- Create start game button for admins
    create_start_game_button(player)
end

-- ============================================================================
-- LOBBY TERRAIN GENERATION
-- ============================================================================

function generate_lobby_terrain(surface)
    local tiles = {}
    local platform_size = 25
    local square_size = 20
    
    -- Main platform area with void edges
    for x = -32, 32 do
        for y = -32, 32 do
            if x < platform_size and x > -(platform_size+1) and y < platform_size and y > -(platform_size+1) then
                table.insert(tiles, {name = "space-platform-foundation", position = {x, y}})
            else
                table.insert(tiles, {name = "out-of-map", position = {x, y}})
            end
        end
    end
    
    -- Nauvis terrain square (top, blue)
    for x = -square_size/2, square_size/2 do
        for y = -(platform_size + square_size - 1), -platform_size do
            table.insert(tiles, {name = "grass-1", position = {x, y}})
        end
    end
    
    -- Gleba terrain square (right, green) - natural pattern
    local gleba_patterns = {
        {x_range = {0, 6}, y_range = {-10, -5}, tile = "wetland-yumako"},
        {x_range = {7, 12}, y_range = {-8, -2}, tile = "natural-yumako-soil"},
        {x_range = {13, 19}, y_range = {-6, 0}, tile = "lowland-brown-blubber"},
        {x_range = {0, 8}, y_range = {-4, 2}, tile = "natural-jellynut-soil"},
        {x_range = {9, 19}, y_range = {1, 6}, tile = "midland-turquoise-bark"},
        {x_range = {0, 12}, y_range = {3, 10}, tile = "wetland-light-green-slime"},
        {x_range = {13, 19}, y_range = {7, 10}, tile = "lowland-olive-blubber"}
    }
    
    for _, pattern in pairs(gleba_patterns) do
        for x = platform_size + pattern.x_range[1], platform_size + pattern.x_range[2] do
            for y = pattern.y_range[1], pattern.y_range[2] do
                if x <= platform_size + square_size - 1 and y >= -square_size/2 and y <= square_size/2 then
                    table.insert(tiles, {name = pattern.tile, position = {x, y}})
                end
            end
        end
    end
    
    -- Fulgora terrain square (bottom, purple)
    for x = -square_size/2, square_size/2 do
        for y = platform_size, platform_size + square_size - 1 do
            table.insert(tiles, {name = "fulgoran-rock", position = {x, y}})
        end
    end
    
    -- Vulcanus terrain square (left, grey) - with lava border
    for x = -(platform_size + square_size - 1), -platform_size do
        for y = -square_size/2, square_size/2 do
            local rel_x = x + platform_size + square_size - 1
            local rel_y = y + square_size/2
            
            -- Lava border except on east edge (connects to platform)
            if rel_x == 0 or rel_y == 0 or rel_y == square_size then
                table.insert(tiles, {name = "lava", position = {x, y}})
            else
                table.insert(tiles, {name = "volcanic-soil-light", position = {x, y}})
            end
        end
    end
    
    -- Configure surface
    surface.daytime = 0.5
    surface.freeze_daytime = true
    surface.set_tiles(tiles)
end

-- Warptorio-style chunk generation handler for lobby persistence
script.on_event(defines.events.on_chunk_generated, function(event)
    local surface = event.surface
    if surface.name ~= "lobby" then return end
    
    local minx = event.area.left_top.x
    local maxx = event.area.right_bottom.x
    local miny = event.area.left_top.y
    local maxy = event.area.right_bottom.y
    local platform_size = 25
    local square_size = 20
    
    local tiles = {}
    for x = minx-1, maxx do
        for y = miny-1, maxy do
            -- Main platform area
            if x < platform_size and x > -(platform_size+1) and y < platform_size and y > -(platform_size+1) then
                table.insert(tiles, {name = "space-platform-foundation", position = {x, y}})
            -- Planet terrain squares
            elseif x >= -square_size/2 and x <= square_size/2 and y >= -(platform_size + square_size - 1) and y <= -platform_size then
                table.insert(tiles, {name = "grass-1", position = {x, y}})
            elseif x >= platform_size and x <= platform_size + square_size - 1 and y >= -square_size/2 and y <= square_size/2 then
                -- Gleba pattern (simplified for chunk generation)
                table.insert(tiles, {name = "natural-yumako-soil", position = {x, y}})
            elseif x >= -square_size/2 and x <= square_size/2 and y >= platform_size and y <= platform_size + square_size - 1 then
                table.insert(tiles, {name = "fulgoran-rock", position = {x, y}})
            elseif x >= -(platform_size + square_size - 1) and x <= -platform_size and y >= -square_size/2 and y <= square_size/2 then
                local rel_x = x + platform_size + square_size - 1
                local rel_y = y + square_size/2
                if rel_x == 0 or rel_y == 0 or rel_y == square_size then
                    table.insert(tiles, {name = "lava", position = {x, y}})
                else
                    table.insert(tiles, {name = "volcanic-soil-light", position = {x, y}})
                end
            else
                table.insert(tiles, {name = "out-of-map", position = {x, y}})
            end
        end
    end
    
    surface.set_tiles(tiles)
    surface.daytime = 0.5
    surface.freeze_daytime = true
end)

-- Maintain lobby visibility (every 10 seconds)
script.on_nth_tick(600, function(event)
    if not storage.lobby_surface then return end
    
    local platform_size = 25
    local square_size = 20
    local lobby_area = {
        left_top = {-(platform_size + square_size), -(platform_size + square_size)},
        right_bottom = {platform_size + square_size, platform_size + square_size}
    }
    
    -- Re-chart lobby area for all forces to maintain visibility
    for _, force in pairs(game.forces) do
        force.chart(storage.lobby_surface, lobby_area)
    end
end)

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
    local x, y = position.x, position.y
    
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
    
    if storage.selection_locked then
        player.print("Planet selection is locked! Teleportation countdown has ended.")
        return
    end
    
    storage.player_selections[player.index] = planet
    player.color = planet_colors[planet]
    game.print("Player " .. player.name .. " selected " .. planet:gsub("^%l", string.upper) .. "!")
end

script.on_event(defines.events.on_player_changed_position, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.surface or player.surface.name ~= "lobby" then
        return
    end
    
    local planet = detect_planet_area(player.position)
    if planet then
        local current_selection = storage.player_selections[player.index]
        if current_selection ~= planet then
            update_player_selection(player, planet)
        end
    end
end)

-- ============================================================================
-- COUNTDOWN TIMER SYSTEM
-- ============================================================================

function start_teleport_countdown()
    if storage.teleport_timer then return end
    
    storage.teleport_timer = game.tick + (storage.teleport_delay * 60)
    hide_start_game_buttons()
    game.print("Game countdown started! " .. storage.teleport_delay .. " seconds until departure.")
end

function should_announce_time(seconds_left)
    return (seconds_left % 10 == 0 and seconds_left > 0) or (seconds_left >= 1 and seconds_left <= 5)
end

script.on_event(defines.events.on_tick, function(event)
    if not storage.teleport_timer then return end
    
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
    end
end)

-- ============================================================================
-- TELEPORTATION SYSTEM
-- ============================================================================

function teleport_players_to_planets()
    for _, player in pairs(game.players) do
        local selected_planet = storage.player_selections[player.index]
        
        if selected_planet == "nauvis" then
            teleport_to_nauvis(player)
        elseif selected_planet == "vulcanus" then
            teleport_to_vulcanus(player)
        elseif selected_planet == "gleba" then
            teleport_to_gleba(player)
        elseif selected_planet == "fulgora" then
            teleport_to_fulgora(player)
        end
    end
end

function teleport_to_nauvis(player)
    local nauvis = game.get_surface("nauvis")
    if not nauvis then
        nauvis = game.create_surface("nauvis")
    end
    
    nauvis.request_to_generate_chunks({0, 0}, 3)
    nauvis.force_generate_chunk_requests()
    
    local spawn_position = nauvis.find_non_colliding_position("character", {0, 0}, 32, 1) or {0, 0}
    player.teleport(spawn_position, nauvis)
    player.print("Welcome to Nauvis! Say hello to the biters!")
    
    storage.nauvis_visited = true
end

function teleport_to_vulcanus(player)
    local vulcanus = game.planets["vulcanus"].create_surface()
    vulcanus.request_to_generate_chunks({0, 0}, 3)
    vulcanus.force_generate_chunk_requests()
    
    local spawn_position = vulcanus.find_non_colliding_position("character", {0, 0}, 32, 1) or {0, 0}
    player.teleport(spawn_position, vulcanus)
    player.print("Welcome to Vulcanus! Watch out for the lava!")
end

function teleport_to_gleba(player)
    local gleba = game.planets["gleba"].create_surface()
    gleba.request_to_generate_chunks({0, 0}, 3)
    gleba.force_generate_chunk_requests()
    
    local spawn_position = gleba.find_non_colliding_position("character", {0, 0}, 32, 1) or {0, 0}
    player.teleport(spawn_position, gleba)
    player.print("Welcome to Gleba! Beware of the spoilage and pentapods!")
end

function teleport_to_fulgora(player)
    local fulgora = game.planets["fulgora"].create_surface()
    fulgora.request_to_generate_chunks({0, 0}, 3)
    fulgora.force_generate_chunk_requests()
    
    local spawn_position = fulgora.find_non_colliding_position("character", {0, 0}, 32, 1) or {0, 0}
    player.teleport(spawn_position, fulgora)
    player.print("Welcome to Fulgora! Mind the lightning storms!")
end

-- ============================================================================
-- SPACE PLATFORM TRAVEL RESTRICTIONS
-- ============================================================================

-- Planet discovery technology mapping
local planet_discovery_techs = {
    nauvis = "planet-discovery-nauvis",
    vulcanus = "planet-discovery-vulcanus",
    gleba = "planet-discovery-gleba", 
    fulgora = "planet-discovery-fulgora"
}

function is_planet_discovered(force, planet_name)
    local tech_name = planet_discovery_techs[planet_name]
    if not tech_name then return true end -- Unknown planets are allowed
    
    local tech = force.technologies[tech_name]
    return tech and tech.researched
end

function get_platform_owner_force(platform)
    -- Space platforms belong to the force that built them
    return platform.force
end

-- Block adding undiscovered planets to space platform schedules
function check_and_block_platform_schedule(platform)
    if not platform or not platform.schedule or not platform.schedule.records then
        return false
    end
    
    for i, record in pairs(platform.schedule.records) do
        if record.station then
            -- Check if this station is a planet name
            for _, planet in pairs(game.planets) do
                if planet.name == record.station then
                    local force = platform.force
                    local is_discovered = is_planet_discovered(force, planet.name)
                    
                    if not is_discovered then
                        -- Create new schedule without the blocked planet
                        local new_records = {}
                        for j, r in pairs(platform.schedule.records) do
                            if j ~= i then
                                table.insert(new_records, r)
                            end
                        end
                        
                        -- Update schedule
                        local new_schedule = {
                            current = math.max(1, math.min(platform.schedule.current, #new_records)),
                            records = new_records
                        }
                        
                        -- If no records left, clear the schedule entirely
                        if #new_records == 0 then
                            new_schedule = nil
                        end
                        platform.schedule = new_schedule
                        
                        -- Notify players
                        local planet_display = planet.name:gsub("^%l", string.upper)
                        local tech_name = planet_discovery_techs[planet.name]
                        
                        for _, player in pairs(force.players) do
                            if player.valid then
                                player.print("Cannot schedule travel to " .. planet_display .. "! Research " .. tech_name .. " first.")
                            end
                        end
                        
                        return true -- Return true if we blocked something
                    end
                    break
                end
            end
        end
    end
    return false
end

-- Check space platform schedules periodically (no direct schedule change event exists)
script.on_nth_tick(60, function(event) -- Check every second
    for _, surface in pairs(game.surfaces) do
        if surface.platform then
            check_and_block_platform_schedule(surface.platform)
        end
    end
end)

-- Also check when space platform state changes
script.on_event(defines.events.on_space_platform_changed_state, function(event)
    local platform = event.platform
    if not platform then return end
    
    check_and_block_platform_schedule(platform)
end)

-- ============================================================================
-- GUI SYSTEM - ADMIN START BUTTON
-- ============================================================================

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