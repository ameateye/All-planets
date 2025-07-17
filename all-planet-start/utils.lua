-- All Planet Start - Utility Functions
-- Technology manipulation utilities for data stage modifications

---@class APS.utils
local utils = {}

local technologies = data.raw.technology

-- ============================================================================
-- PREREQUISITE MANAGEMENT
-- ============================================================================

--- Overwrites the prerequisites of a technology.
---@param name string The technology name
---@param prerequisites string[]? List of prerequisite technology names
function utils.set_prerequisites(name, prerequisites)
    local technology = technologies[name]
    if not technology then return end
    technology.prerequisites = prerequisites
end

--- Adds prerequisites to a technology's existing list of prerequisites.
---@param name string The technology name
---@param prerequisites string[] List of prerequisite technology names to add
function utils.add_prerequisites(name, prerequisites)
    local technology = technologies[name]
    if not technology then return end
    
    if not technology.prerequisites then
        technology.prerequisites = prerequisites
        return
    end

    local map = {}
    for _, prerequisite in pairs(technology.prerequisites) do
        map[prerequisite] = true
    end
    for _, prerequisite in pairs(prerequisites) do
        if not map[prerequisite] then
            technology.prerequisites[#technology.prerequisites+1] = prerequisite
        end
    end
end

-- ============================================================================
-- RESEARCH TRIGGER MANAGEMENT
-- ============================================================================

--- Sets the research trigger of a technology and removes the unit if there is one.
---@param name string The technology name
---@param trigger data.TechnologyTrigger The trigger condition
function utils.set_trigger(name, trigger)
    local technology = technologies[name]
    if not technology then return end
    technology.research_trigger = trigger
    technology.unit = nil
end

--- Sets the unit of a technology and removes the research trigger if there is one.
---@param name string The technology name
---@param unit data.TechnologyUnit The research unit definition
function utils.set_unit(name, unit)
    local technology = technologies[name]
    if not technology then return end
    technology.unit = unit
    technology.research_trigger = nil
end

-- ============================================================================
-- RECIPE MANAGEMENT
-- ============================================================================

--- Overwrites the recipes a technology unlocks.
---@param name string The technology name
---@param recipes string[] List of recipe names to unlock
function utils.set_recipes(name, recipes)
    local technology = technologies[name]
    if not technology then return end
    technology.effects = {}
    for i, recipe in pairs(recipes) do
        technology.effects[i] = {
            type = "unlock-recipe",
            recipe = recipe,
        }
    end
end

--- Adds recipes to a technology's unlock list.
---@param name string The technology name
---@param recipes string[] List of recipe names to add
function utils.add_recipes(name, recipes)
    local technology = technologies[name]
    if not technology then return end
    technology.effects = technology.effects or {}
    local len = #technology.effects
    for i = 1, #recipes do
        technology.effects[len + i] = {
            type = "unlock-recipe",
            recipe = recipes[i],
        }
    end
end

--- Removes recipes from a technology's unlock list.
---@param name string The technology name
---@param recipes string[] List of recipe names to remove
function utils.remove_recipes(name, recipes)
    local technology = technologies[name]
    if not technology then return end
    local map = {}
    for _, recipe in pairs(recipes) do
        map[recipe] = true
    end
    local effects = technology.effects
    if not effects then return end
    for i = #effects, 1, -1 do
        if effects[i].recipe and map[effects[i].recipe] then
            table.remove(effects, i)
        end
    end
end

--- Inserts a recipe unlock at a specific position in a technology's unlock list.
---@param name string The technology name
---@param recipe string The recipe name to insert
---@param position uint The position to insert at
function utils.insert_recipe(name, recipe, position)
    local technology = technologies[name]
    if not technology then return end
    technology.effects = technology.effects or {}
    table.insert(technology.effects, position, {
        type = "unlock-recipe",
        recipe = recipe,
    })
end

-- ============================================================================
-- SCIENCE PACK MANAGEMENT
-- ============================================================================

--- Replaces specific properties of a technology's unit with only the ones specified.
--- For technologies without a unit, default ingredients are empty, count is 100, time is 60.
---@param name string The technology name
---@param packs string[]? List of science pack names
---@param count uint? Research count required
---@param time double? Time per research unit in seconds
function utils.set_packs(name, packs, count, time)
    local technology = technologies[name]
    if not technology then return end
    local unit = technology.unit or {}
    unit.count = count or unit.count or 100
    unit.time = time or unit.time or 60
    unit.ingredients = unit.ingredients or {}

    if packs then
        local ingredients = {}
        unit.ingredients = ingredients
        for _, pack in pairs(packs) do
            ingredients[#ingredients+1] = {pack, 1}
        end
    end

    utils.set_unit(name, unit)
end

--- Removes science packs from a technology's unit ingredients.
---@param name string The technology name
---@param packs string[] List of science pack names to remove
function utils.remove_packs(name, packs)
    local technology = technologies[name]
    if not technology or not technology.unit or not technology.unit.ingredients then return end
    local map = {}
    for _, pack in pairs(packs) do
        map[pack] = true
    end
    local ingredients = technology.unit.ingredients
    for i = #ingredients, 1, -1 do
        if map[ingredients[i][1]] then
            table.remove(ingredients, i)
        end
    end
end

-- ============================================================================
-- TECHNOLOGY REMOVAL AND HIDING
-- ============================================================================

--- Removes a technology from the tech tree without deleting it.
---@param name string The technology name
---@param effects boolean Automatically enable the recipes from the technology's recipe unlocks
---@param stitch boolean Stitch together the surrounding prerequisites and dependants in the tech tree
function utils.remove_tech(name, effects, stitch)
    local technology = technologies[name]
    if not technology then return end
    technology.hidden = true

    if effects and technology.effects then
        for _, effect in pairs(technology.effects) do
            if effect.type == "unlock-recipe" then
                local recipe = data.raw.recipe[effect.recipe]
                if recipe then
                    recipe.enabled = true
                end
            end
        end
    end

    for _, tech in pairs(technologies) do
        local prerequisites = tech.prerequisites
        if not prerequisites then goto continue end

        for i = #prerequisites, 1, -1 do
            if prerequisites[i] == name then
                table.remove(prerequisites, i)
                if stitch and technology.prerequisites then
                    for _, prereq in pairs(technology.prerequisites) do
                        prerequisites[#prerequisites+1] = prereq
                    end
                end
                break
            end
        end

        ::continue::
    end

    technology.prerequisites = nil
end

-- ============================================================================
-- MISCELLANEOUS UTILITIES
-- ============================================================================

--- Makes a technology unaffected by the tech cost multiplier map setting.
---@param name string The technology name
function utils.ignore_multiplier(name)
    local technology = technologies[name]
    if not technology then return end
    technology.ignore_tech_cost_multiplier = true
end

return utils