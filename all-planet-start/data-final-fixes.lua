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
    "planet-discovery-fulgora"
}

-- Remove planet discovery prerequisites from ALL technologies
for _, tech in pairs(data.raw.technology) do
    if tech.prerequisites then
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

-- ============================================================================
-- PLANET SCIENCE PACK DEPENDENCIES
-- ============================================================================

-- Create planet discovery requirements for planet science packs
-- This maintains progression: players can access planets but science requires discovery
utils.add_prerequisites("metallurgic-science-pack", {"planet-discovery-vulcanus"})
utils.add_prerequisites("electromagnetic-science-pack", {"planet-discovery-fulgora"})
utils.add_prerequisites("agricultural-science-pack", {"planet-discovery-gleba"})