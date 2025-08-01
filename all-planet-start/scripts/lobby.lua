-- All Planet Start - Lobby System
-- Lobby creation, terrain generation, and player spawn handling

local PLATFORM_SIZE = 25
local SQUARE_SIZE = 20
local CANCEL_AREA_SIZE = 15

-- Export constants for other modules
_G.LOBBY_PLATFORM_SIZE = PLATFORM_SIZE
_G.LOBBY_SQUARE_SIZE = SQUARE_SIZE
_G.LOBBY_CANCEL_AREA_SIZE = CANCEL_AREA_SIZE

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
    
    -- Track Nauvis first landing (since surface clearing doesn't work for first player detection)
    storage.nauvis_first_landing = false
    
    -- Don't unlock space locations initially - will unlock them when surfaces are created
    -- This prevents auto-creation of planet surfaces
    local force = game.forces.player
    local space_locations = {"nauvis", "vulcanus", "gleba", "fulgora"}
    for _, location in pairs(space_locations) do
        force.lock_space_location(location)
    end
    
    -- Create and setup lobby surface
    storage.lobby_surface = game.create_surface("lobby", {
        starting_area = "none",
        peaceful_mode = true,
        default_enable_all_autoplace_controls = false,
        autoplace_controls = {},
        cliff_settings = {richness = 0}
    })
    
    storage.lobby_surface.always_day = true
    storage.lobby_surface.show_clouds = false
    storage.lobby_surface.request_to_generate_chunks({0, 0}, 3)
    storage.lobby_surface.force_generate_chunk_requests()
    
    generate_lobby_terrain(storage.lobby_surface)
    storage.lobby_generated = true
    
    -- Clear Nauvis surface
    local nauvis = game.get_surface("nauvis")
    if nauvis then
        nauvis.clear()
    end
end)


-- ============================================================================
-- PLAYER SPAWN AND LOBBY MANAGEMENT
-- ============================================================================

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    
    local spawn_position = storage.lobby_surface.find_non_colliding_position("character", {0, 0}, 0, 1)
    player.teleport(spawn_position, storage.lobby_surface)
    
    player.get_main_inventory().clear()
    player.get_inventory(defines.inventory.character_guns).clear()
    player.get_inventory(defines.inventory.character_ammo).clear()
end)

-- ============================================================================
-- LOBBY TERRAIN GENERATION
-- ============================================================================

function generate_lobby_terrain(surface)
    local tiles = {}
    
    -- Main platform area with void edges
    for x = -32, 32 do
        for y = -32, 32 do
            if x < PLATFORM_SIZE and x > -(PLATFORM_SIZE+1) and y < PLATFORM_SIZE and y > -(PLATFORM_SIZE+1) then
                table.insert(tiles, {name = "space-platform-foundation", position = {x, y}})
            else
                table.insert(tiles, {name = "out-of-map", position = {x, y}})
            end
        end
    end
    
    -- Nauvis terrain square (top, blue)
    for x = -SQUARE_SIZE/2, SQUARE_SIZE/2 do
        for y = -(PLATFORM_SIZE + SQUARE_SIZE - 1), -PLATFORM_SIZE do
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
        for x = PLATFORM_SIZE + pattern.x_range[1], PLATFORM_SIZE + pattern.x_range[2] do
            for y = pattern.y_range[1], pattern.y_range[2] do
                if x <= PLATFORM_SIZE + SQUARE_SIZE - 1 and y >= -SQUARE_SIZE/2 and y <= SQUARE_SIZE/2 then
                    table.insert(tiles, {name = pattern.tile, position = {x, y}})
                end
            end
        end
    end
    
    -- Fulgora terrain square (bottom, purple)
    for x = -SQUARE_SIZE/2, SQUARE_SIZE/2 do
        for y = PLATFORM_SIZE, PLATFORM_SIZE + SQUARE_SIZE - 1 do
            table.insert(tiles, {name = "fulgoran-rock", position = {x, y}})
        end
    end
    
    -- Vulcanus terrain square (left, grey) - with lava border
    for x = -(PLATFORM_SIZE + SQUARE_SIZE - 1), -PLATFORM_SIZE do
        for y = -SQUARE_SIZE/2, SQUARE_SIZE/2 do
            local rel_x = x + PLATFORM_SIZE + SQUARE_SIZE - 1
            local rel_y = y + SQUARE_SIZE/2
            
            -- Lava border except on east edge (connects to platform)
            if rel_x == 0 or rel_y == 0 or rel_y == SQUARE_SIZE then
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
    
    local tiles = {}
    for x = minx-1, maxx do
        for y = miny-1, maxy do
            -- Cancel zone (center platform with hazard concrete)
            if x >= -CANCEL_AREA_SIZE/2 and x <= CANCEL_AREA_SIZE/2 and y >= -CANCEL_AREA_SIZE/2 and y <= CANCEL_AREA_SIZE/2 then
                table.insert(tiles, {name = "refined-hazard-concrete-left", position = {x, y}})
            -- Main platform area
            elseif x < PLATFORM_SIZE and x > -(PLATFORM_SIZE+1) and y < PLATFORM_SIZE and y > -(PLATFORM_SIZE+1) then
                table.insert(tiles, {name = "space-platform-foundation", position = {x, y}})
            -- Planet terrain squares
            elseif x >= -SQUARE_SIZE/2 and x <= SQUARE_SIZE/2 and y >= -(PLATFORM_SIZE + SQUARE_SIZE - 1) and y <= -PLATFORM_SIZE then
                table.insert(tiles, {name = "grass-1", position = {x, y}})
            elseif x >= PLATFORM_SIZE and x <= PLATFORM_SIZE + SQUARE_SIZE - 1 and y >= -SQUARE_SIZE/2 and y <= SQUARE_SIZE/2 then
                -- Gleba pattern (simplified for chunk generation)
                table.insert(tiles, {name = "natural-yumako-soil", position = {x, y}})
            elseif x >= -SQUARE_SIZE/2 and x <= SQUARE_SIZE/2 and y >= PLATFORM_SIZE and y <= PLATFORM_SIZE + SQUARE_SIZE - 1 then
                table.insert(tiles, {name = "fulgoran-rock", position = {x, y}})
            elseif x >= -(PLATFORM_SIZE + SQUARE_SIZE - 1) and x <= -PLATFORM_SIZE and y >= -SQUARE_SIZE/2 and y <= SQUARE_SIZE/2 then
                local rel_x = x + PLATFORM_SIZE + SQUARE_SIZE - 1
                local rel_y = y + SQUARE_SIZE/2
                if rel_x == 0 or rel_y == 0 or rel_y == SQUARE_SIZE then
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
    
    local lobby_area = {
        left_top = {-(PLATFORM_SIZE + SQUARE_SIZE), -(PLATFORM_SIZE + SQUARE_SIZE)},
        right_bottom = {PLATFORM_SIZE + SQUARE_SIZE, PLATFORM_SIZE + SQUARE_SIZE}
    }
    
    -- Re-chart lobby area for all forces to maintain visibility
    for _, force in pairs(game.forces) do
        force.chart(storage.lobby_surface, lobby_area)
    end
end)