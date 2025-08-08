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
    -- Skip intro and disable crashsite
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
    
    -- Track Nauvis first landing
    storage.nauvis_first_landing = false
    
    -- Lock space locations to prevent auto-creation of planet surfaces
    local force = game.forces.player
    local space_locations = {"nauvis", "vulcanus", "gleba", "fulgora"}
    for _, location in pairs(space_locations) do
        force.lock_space_location(location)
    end
    
    -- Create lobby surface with controlled settings
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
    
    -- Clear default Nauvis surface
    local nauvis = game.get_surface("nauvis")
    if nauvis then
        nauvis.clear()
    end
end)


-- ============================================================================
-- PLAYER SPAWN HANDLING
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

function get_lobby_tile(x, y)
    -- Cancel zone (center platform with hazard concrete)
    if x >= -CANCEL_AREA_SIZE/2 and x <= CANCEL_AREA_SIZE/2 and y >= -CANCEL_AREA_SIZE/2 and y <= CANCEL_AREA_SIZE/2 then
        return "refined-hazard-concrete-left"
    -- Main platform area
    elseif x < PLATFORM_SIZE and x > -(PLATFORM_SIZE+1) and y < PLATFORM_SIZE and y > -(PLATFORM_SIZE+1) then
        return "space-platform-foundation"
    -- Nauvis terrain square (top, blue)
    elseif x >= -SQUARE_SIZE/2 and x <= SQUARE_SIZE/2 and y >= -(PLATFORM_SIZE + SQUARE_SIZE - 1) and y <= -PLATFORM_SIZE then
        return "grass-1"
    -- Gleba terrain square (right, green)
    elseif x >= PLATFORM_SIZE and x <= PLATFORM_SIZE + SQUARE_SIZE - 1 and y >= -SQUARE_SIZE/2 and y <= SQUARE_SIZE/2 then
        return "natural-yumako-soil"
    -- Fulgora terrain square (bottom, purple)
    elseif x >= -SQUARE_SIZE/2 and x <= SQUARE_SIZE/2 and y >= PLATFORM_SIZE and y <= PLATFORM_SIZE + SQUARE_SIZE - 1 then
        return "fulgoran-rock"
    -- Vulcanus terrain square (left, grey)
    elseif x >= -(PLATFORM_SIZE + SQUARE_SIZE - 1) and x <= -PLATFORM_SIZE and y >= -SQUARE_SIZE/2 and y <= SQUARE_SIZE/2 then
        local rel_x = x + PLATFORM_SIZE + SQUARE_SIZE - 1
        local rel_y = y + SQUARE_SIZE/2
        if rel_x == 0 or rel_y == 0 or rel_y == SQUARE_SIZE then
            return "lava"
        else
            return "volcanic-soil-light"
        end
    else
        return "out-of-map"
    end
end

function generate_lobby_terrain(surface)
    local tiles = {}
    
    -- Generate for 3 chunks radius (96 tiles each direction)
    for x = -96, 96 do
        for y = -96, 96 do
            table.insert(tiles, {name = get_lobby_tile(x, y), position = {x, y}})
        end
    end
    
    surface.set_tiles(tiles)
end

script.on_event(defines.events.on_chunk_generated, function(event)
    local surface = event.surface
    if surface.name ~= "lobby" then return end
    
    local tiles = {}
    for x = event.area.left_top.x, event.area.right_bottom.x - 1 do
        for y = event.area.left_top.y, event.area.right_bottom.y - 1 do
            table.insert(tiles, {name = get_lobby_tile(x, y), position = {x, y}})
        end
    end
    
    surface.set_tiles(tiles)
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