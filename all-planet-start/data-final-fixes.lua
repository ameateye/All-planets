-- All Planet Start - Data Final Fixes
-- Planet discovery dependency removal and final technology adjustments

local utils = require("utils") --[[@as APS.utils]]

-- ============================================================================
-- PLANET DISCOVERY DEPENDENCY REMOVAL
-- ============================================================================

-- All planets are accessible from start, so remove planet discovery dependencies
-- from all technologies
local planet_discoveries = {
    "planet-discovery-vulcanus", 
    "planet-discovery-gleba", 
    "planet-discovery-fulgora", 
    "planet-discovery-nauvis"
}

-- Remove planet discovery prerequisites from ALL technologies except science packs
local science_pack_exclusions = {
    "metallurgic-science-pack",
    "electromagnetic-science-pack", 
    "agricultural-science-pack"
}

for _, tech in pairs(data.raw.technology) do
    -- Skip science pack technologies
    local is_science_pack = false
    for _, exclusion in pairs(science_pack_exclusions) do
        if tech.name == exclusion then
            is_science_pack = true
            break
        end
    end
    
    if tech.prerequisites and not is_science_pack then
        for i = #tech.prerequisites, 1, -1 do
            for _, planet_discovery in pairs(planet_discoveries) do
                if tech.prerequisites[i] == planet_discovery then
                    table.remove(tech.prerequisites, i)
                    break
                end
            end
        end
    end
end