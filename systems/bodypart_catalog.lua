local Content = require("combat.v2_content")

local Catalog = {}

Catalog.MODULE_NAME = "data.combat.alpha_basement"

Catalog.SLOT_ORDER = {
    { id = "head", label = "Head" },
    { id = "body", label = "Body" },
    { id = "arm_l", label = "Fore Hand" },
    { id = "arm_r", label = "Back Hand" },
    { id = "leg_l", label = "Front Foot" },
    { id = "leg_r", label = "Back Foot" }
}

local definitions_cache = {}

local function module_names()
    local ok, index = pcall(require, "data.combat.content_index")
    if ok and type(index) == "table" and type(index.modules) == "table" and #index.modules > 0 then
        return index.modules
    end

    return { Catalog.MODULE_NAME }
end

local function definitions_for_module(module_name)
    if not definitions_cache[module_name] then
        definitions_cache[module_name] = Content.load_module(module_name)
    end

    return definitions_cache[module_name]
end

local function definitions()
    return definitions_for_module(module_names()[1] or Catalog.MODULE_NAME)
end

local function first_owned_instance(world, def_id)
    local run = world and world.run
    for instance_id, instance in pairs(run and run.parts or {}) do
        if instance and instance.def_id == def_id then
            return instance_id, instance
        end
    end

    return nil, nil
end

local function decorate_part(part, instance_id, instance, slot)
    if not part then
        return nil
    end

    part.def_id = part.id
    part.instance_id = instance_id
    part.status = instance and (instance.status or "healthy") or part.status or "healthy"
    part.source = instance and instance.source or nil
    part.claimed_from = instance and instance.claimed_from or nil
    part.menu_slot = slot
    return part
end

function Catalog.definitions()
    return definitions()
end

function Catalog.module_names()
    return module_names()
end

function Catalog.part_definition(def_id)
    for _, module_name in ipairs(module_names()) do
        local defs = definitions_for_module(module_name)
        if defs.parts and defs.parts[def_id] then
            return defs.parts[def_id], defs, module_name
        end
    end

    return nil, nil, nil
end

function Catalog.build_part(def_id, instance_id, instance, slot)
    if not def_id then
        return nil
    end

    local _, defs = Catalog.part_definition(def_id)
    if not defs then
        error("Unknown body part: " .. tostring(def_id))
    end

    return decorate_part(Content.build_part(defs, def_id), instance_id, instance, slot)
end

function Catalog.part_from_instance(instance_id, instance, slot)
    if not (instance and instance.def_id) then
        return nil
    end

    return Catalog.build_part(instance.def_id, instance_id, instance, slot)
end

function Catalog.active_parts(world)
    local run = world and world.run or {}
    local parts = run.parts or {}
    local active = {}

    for _, slot in ipairs(Catalog.SLOT_ORDER) do
        local instance_id = run.dreamform and run.dreamform[slot.id]
        local instance = instance_id and parts[instance_id]
        active[#active + 1] = {
            slot = slot,
            instance_id = instance_id,
            instance = instance,
            part = Catalog.part_from_instance(instance_id, instance, slot)
        }
    end

    return active
end

function Catalog.active_body_parts(world)
    local parts = {}
    for _, entry in ipairs(Catalog.active_parts(world)) do
        if entry.part then
            table.insert(parts, entry.part)
        end
    end
    return parts
end

function Catalog.discovered_part_ids(world)
    local run = world and world.run or {}
    local discovered = {}

    for def_id, value in pairs(run.discovered_parts or {}) do
        if value then
            discovered[def_id] = true
        end
    end

    for _, instance in pairs(run.parts or {}) do
        if instance and instance.def_id then
            discovered[instance.def_id] = true
        end
    end

    local ids = {}
    for def_id in pairs(discovered) do
        table.insert(ids, def_id)
    end

    table.sort(ids, function(left, right)
        local left_def = Catalog.part_definition(left)
        local right_def = Catalog.part_definition(right)
        local left_name = left_def and left_def.name or left
        local right_name = right_def and right_def.name or right
        if left_name == right_name then
            return left < right
        end
        return left_name < right_name
    end)

    return ids
end

function Catalog.discovered_parts(world)
    local parts = {}

    for _, def_id in ipairs(Catalog.discovered_part_ids(world)) do
        local instance_id, instance = first_owned_instance(world, def_id)
        table.insert(parts, Catalog.build_part(def_id, instance_id, instance))
    end

    return parts
end

return Catalog
