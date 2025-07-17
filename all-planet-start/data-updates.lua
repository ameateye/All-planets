-- All Planet Start - Data Updates Stage
-- Technology tree modifications for all-planet start mod

local utils = require("utils") --[[@as APS.utils]]

-- ============================================================================
-- FULGORA INTEGRATION - Recycling-based progression
-- ============================================================================

-- Steel and battery production triggered by recycling (like Fulgora)
utils.set_prerequisites("steel-processing", {"recycling"})
utils.set_prerequisites("battery", {"recycling"})
utils.set_trigger("steel-processing", {type = "craft-item", item = "steel-plate", count = 5})
utils.set_trigger("battery", {type = "craft-item", item = "battery", count = 5})

-- Move accumulator recipe to battery tech and remove separate tech
utils.add_recipes("battery", {"accumulator"})
utils.remove_tech("electric-energy-accumulators", true, true)

-- ============================================================================
-- VULCANUS INTEGRATION - Early automation and concrete
-- ============================================================================

-- Make automation-2 more accessible for early assemblers
utils.set_prerequisites("automation-2", {"automation", "automation-science-pack"})
utils.set_packs("automation-2", {"automation-science-pack"}, 50, 15)

-- Early concrete access (remove advanced material processing dependency)
utils.set_packs("concrete", {"automation-science-pack"}, 50, 15)
utils.set_prerequisites("concrete", {"automation-2"})

-- Tungsten carbide requires automation-2 (assemblers) for processing
utils.set_prerequisites("tungsten-carbide", {"automation-2"})

-- ============================================================================
-- OIL PROCESSING OVERHAUL - Custom progression system
-- ============================================================================

-- Custom acid pumping technology for pumpjacks and basic oil processing
data:extend({
    {
        type = "technology",
        name = "acid-pumping",
        icon = "__base__/graphics/technology/oil-gathering.png",
        icon_size = 256,
        effects = {
            {type = "unlock-recipe", recipe = "pumpjack"},
            {type = "unlock-recipe", recipe = "oil-refinery"},
            {type = "unlock-recipe", recipe = "chemical-plant"},
            {type = "unlock-recipe", recipe = "ice-melting"}
        },
        prerequisites = {"steel-processing"},
        research_trigger = {
            type = "craft-item",
            item = "steel-plate",
            count = 50
        },
        order = "d-a-b"
    }
})
utils.remove_recipes("space-platform-thruster", {"ice-melting"})

-- Lubricant triggered by heavy oil production
utils.set_trigger("lubricant", {type = "craft-fluid", fluid = "heavy-oil"})
utils.set_prerequisites("lubricant", {"acid-pumping"})

-- Reorganize oil processing recipes
utils.set_recipes("oil-processing", {"basic-oil-processing", "heavy-oil-cracking", "light-oil-cracking", "solid-fuel-from-petroleum-gas"})
utils.set_recipes("advanced-oil-processing", {"advanced-oil-processing", "solid-fuel-from-heavy-oil", "solid-fuel-from-light-oil"})

-- Bio-lubrication technology for Gleba alternative
data:extend({
    {
        type = "technology", 
        name = "lubrication",
        icon = "__base__/graphics/technology/lubricant.png",
        icon_size = 256,
        effects = {
            {type = "unlock-recipe", recipe = "biolubricant"}
        },
        prerequisites = {"bioflux-processing", "advanced-oil-processing"},
        unit = {
            count = 50,
            ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1}},
            time = 30
        },
        order = "d-e-c"
    }
})

-- Electric engines require lubrication
utils.set_prerequisites("electric-engine", {"lubrication"})

-- ============================================================================
-- ELECTRICAL SYSTEM - Early power infrastructure
-- ============================================================================

-- Medium electric poles available with basic electronics
utils.add_recipes("electronics", {"medium-electric-pole", "iron-stick"})
utils.remove_recipes("electric-energy-distribution-1", {"medium-electric-pole"})

-- ============================================================================
-- GLEBA INTEGRATION - Biology and climate control
-- ============================================================================

-- Early landfill access for terrain modification
utils.set_packs("landfill", {"automation-science-pack"}, 50, 15)

-- Heating tower requires concrete foundation and is more expensive
utils.add_prerequisites("heating-tower", {"concrete"})
utils.set_packs("heating-tower", {"automation-science-pack", "logistic-science-pack"}, 500, 30)

-- Bioflux alternatives for chemical processing (gated by research)
utils.add_prerequisites("plastics", {"bioflux-processing"})
utils.add_prerequisites("sulfur-processing", {"bioflux-processing"})
utils.add_prerequisites("rocket-fuel", {"bioflux-processing"})

-- Move bioflux recipes to appropriate technologies
utils.set_recipes("bioflux-processing", {})
utils.add_recipes("plastics", {"bioplastic"})
utils.add_recipes("sulfur-processing", {"biosulfur"})
utils.add_recipes("rocket-fuel", {"rocket-fuel-from-jelly"})

-- ============================================================================
-- NAUVIS DISCOVERY - Space platform progression
-- ============================================================================

-- Add Nauvis as discoverable planet (for space platform users)
data:extend({
    {
        type = "technology",
        name = "planet-discovery-nauvis",
        icon = "__base__/graphics/icons/nauvis.png",
        icon_size = 64,
        effects = {{
            type = "unlock-space-location",
            space_location = "nauvis",
            use_icon_overlay_constant = true
        }},
        prerequisites = {"space-platform-thruster"},
        unit = {
            count = 1000,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"space-science-pack", 1}
            },
            time = 60
        }
    }
})