-- All Planet Start - Platform Travel Restrictions
-- Space platform travel restrictions system

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

-- Global function for control.lua to call
function check_platform_schedules()
    for _, surface in pairs(game.surfaces) do
        if surface.platform then
            check_and_block_platform_schedule(surface.platform)
        end
    end
end

-- Note: Tick handler moved to control.lua to centralize and avoid conflicts

-- Also check when space platform state changes
script.on_event(defines.events.on_space_platform_changed_state, function(event)
    local platform = event.platform
    if not platform then return end
    
    check_and_block_platform_schedule(platform)
end)