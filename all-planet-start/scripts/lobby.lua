-- All Planet Start - Lobby System
-- Lobby creation, terrain generation, and player spawn handling

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
    storage.personal_timers = {}
    storage.clock_data = {}
    
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
        storage.personal_timers = storage.personal_timers or {}
        storage.clock_data = storage.clock_data or {}
        
        -- Handle existing players
        for _, player in pairs(game.players) do
            handle_player_spawn(player.index)
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
    
    -- Clear player inventory in lobby (should start with nothing)
    player.get_main_inventory().clear()
    player.get_inventory(defines.inventory.character_guns).clear()
    player.get_inventory(defines.inventory.character_ammo).clear()
    
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
    local cancel_area_size = 15  -- Central cancel area
    for x = minx-1, maxx do
        for y = miny-1, maxy do
            -- Cancel zone (center platform with hazard concrete)
            if x >= -cancel_area_size/2 and x <= cancel_area_size/2 and y >= -cancel_area_size/2 and y <= cancel_area_size/2 then
                table.insert(tiles, {name = "refined-hazard-concrete-left", position = {x, y}})
            -- Main platform area
            elseif x < platform_size and x > -(platform_size+1) and y < platform_size and y > -(platform_size+1) then
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