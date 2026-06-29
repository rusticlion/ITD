local Combatant = require("combat.combatant")
local Content = require("combat.v2_content")

local Encounters = {}

Encounters.DEFAULT_ID = "debug.demo"
Encounters.DEFAULT_MODULE = "data.combat.alpha_basement"

local DREAMFORM_SLOT_ORDER = {
    "head",
    "body",
    "arm_l",
    "arm_r",
    "leg_l",
    "leg_r"
}

local FALLBACK_ENCOUNTER = {
    id = Encounters.DEFAULT_ID,
    name = "Debug Bone Demon",
    module = Encounters.DEFAULT_MODULE,
    player_loadout = "player_demo",
    enemy_loadout = "bone_demon"
}

local function copy_table(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = copy_table(value)
    end
    return copy
end

local function encounter_registry()
    local ok, registry = pcall(require, "data.combat.encounters")
    if ok and type(registry) == "table" then
        return registry
    end

    return {}
end

local function normalize_encounter(raw, id)
    local encounter = copy_table(raw or FALLBACK_ENCOUNTER)
    encounter.id = encounter.id or id or Encounters.DEFAULT_ID
    encounter.encounter_id = encounter.encounter_id or encounter.id
    encounter.module = encounter.module or Encounters.DEFAULT_MODULE
    encounter.player_loadout = encounter.player_loadout or "player_demo"
    encounter.enemy_loadout = encounter.enemy_loadout or "enemy_demo"
    return encounter
end

local function build_player_from_run(definitions, run, fallback_loadout)
    if not (run and run.dreamform and run.parts) then
        return Content.build_combatant(definitions, fallback_loadout or "player_demo")
    end

    local combatant = Combatant:new({
        id = "player",
        name = "Dreamer",
        is_player = true,
        crest_pool = copy_table(run.crest_pool or {}),
        heart_points = run.heart_points or 3
    })

    for _, slot in ipairs(DREAMFORM_SLOT_ORDER) do
        local instance_id = run.dreamform[slot]
        local instance = instance_id and run.parts[instance_id]
        if instance and instance.def_id and definitions.parts and definitions.parts[instance.def_id] then
            local part = Content.build_part(definitions, instance.def_id)
            part.instance_id = instance_id
            part.dreamform_slot = slot
            part.status = instance.status or "healthy"
            combatant:add_body_part(part)
        end
    end

    if #combatant.body_parts == 0 then
        return Content.build_combatant(definitions, fallback_loadout or "player_demo")
    end

    return combatant
end

function Encounters.resolve(encounter_id)
    local registry = encounter_registry()
    local id = encounter_id or Encounters.DEFAULT_ID
    local raw = registry[id]
    if not raw and encounter_id ~= nil then
        error("Unknown v2 combat encounter: " .. tostring(encounter_id))
    end

    raw = raw or registry[Encounters.DEFAULT_ID] or FALLBACK_ENCOUNTER
    return normalize_encounter(raw, id)
end

function Encounters.load_definitions(encounter)
    return Content.load_module((encounter and encounter.module) or Encounters.DEFAULT_MODULE)
end

function Encounters.create_combatants(context)
    context = context or {}
    local encounter_id = context.encounter_id or (context.encounter and context.encounter.encounter_id)
    local encounter = Encounters.resolve(encounter_id)
    local definitions = Encounters.load_definitions(encounter)

    context.encounter = encounter

    return
        build_player_from_run(definitions, context.run, encounter.player_loadout),
        Content.build_combatant(definitions, encounter.enemy_loadout)
end

function Encounters.validate()
    local errors = {}

    for encounter_id, encounter in pairs(encounter_registry()) do
        if type(encounter) ~= "table" then
            table.insert(errors, "encounter " .. tostring(encounter_id) .. " must be a table")
        else
            local module_name = encounter.module or Encounters.DEFAULT_MODULE
            local ok, definitions_or_error = pcall(Content.load_module, module_name)
            if not ok then
                table.insert(errors, "encounter " .. tostring(encounter_id) .. " has invalid module " .. tostring(module_name)
                    .. ": " .. tostring(definitions_or_error))
            else
                local definitions = definitions_or_error
                local player_loadout = encounter.player_loadout or "player_demo"
                local enemy_loadout = encounter.enemy_loadout or "enemy_demo"

                if not (definitions.loadouts and definitions.loadouts[player_loadout]) then
                    table.insert(errors, "encounter " .. tostring(encounter_id)
                        .. " references unknown player loadout " .. tostring(player_loadout))
                end
                if not (definitions.loadouts and definitions.loadouts[enemy_loadout]) then
                    table.insert(errors, "encounter " .. tostring(encounter_id)
                        .. " references unknown enemy loadout " .. tostring(enemy_loadout))
                end
            end
        end
    end

    return errors
end

return Encounters
