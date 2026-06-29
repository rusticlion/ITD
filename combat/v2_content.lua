local BodyPart = require("combat.bodypart")
local Combatant = require("combat.combatant")
local Crests = require("combat.crests")
local Effects = require("combat.v2_effects")
local Keywords = require("combat.keywords")
local Symbols = require("core.symbols")

local Content = {}

local VALID_TIMINGS = {
    spend = true,
    on_hit = true,
    on_wound_maim = true,
    upkeep = true
}

local VALID_DYNAMIC_COSTS = {
    opponent_damaged_parts = true
}

local PART_KEYWORDS = {
    Armored = true,
    Brittle = true,
    Absorbent = true,
    Hungry = true
}

local SLOT_KEYWORDS = {
    Hungry = true
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

local function add_error(errors, message)
    table.insert(errors, message)
end

local function normalize_faces(faces)
    local normalized = {}
    for index = 1, 6 do
        normalized[index] = Symbols.normalize_face(faces and faces[index] or Symbols.BLANK)
    end
    return normalized
end

local function normalize_die(die)
    die = die or {}

    return {
        faces = normalize_faces(die.faces),
        wound_faces = copy_table(die.wound_faces or { 1, 2 }),
        maim_faces = copy_table(die.maim_faces or { 3, 4 })
    }
end

local function normalize_slot(slot)
    if not slot then
        return nil
    end

    local normalized = copy_table(slot)
    normalized.cost = {}
    normalized.keyword = Keywords.normalize(slot.keyword)
    normalized.keywords = Keywords.normalize_collection(slot.keywords or {})

    for _, symbol in ipairs(slot.cost or {}) do
        table.insert(normalized.cost, Symbols.normalize(symbol))
    end
    normalized.base_cost = copy_table(normalized.cost)

    if Keywords.collection_has(normalized.keywords, "Hungry") or normalized.keyword == "Hungry" then
        normalized.hungry = true
    end

    normalized.timing = (normalized.timing or "spend"):lower()
    return normalized
end

local function validate_dynamic_cost(errors, slot_id, slot)
    local rule = slot.dynamic_cost
    if rule == nil then
        return
    end

    if type(rule) ~= "table" then
        add_error(errors, "slot " .. tostring(slot_id) .. ".dynamic_cost must be a table")
        return
    end

    if not VALID_DYNAMIC_COSTS[rule.type] then
        add_error(errors, "slot " .. tostring(slot_id) .. ".dynamic_cost has invalid type " .. tostring(rule.type))
    end

    local minimum = tonumber(rule.minimum or 1)
    if not minimum or minimum < 1 or math.floor(minimum) ~= minimum then
        add_error(errors, "slot " .. tostring(slot_id) .. ".dynamic_cost.minimum must be a positive integer")
    elseif type(slot.cost) == "table" and minimum > #slot.cost then
        add_error(errors, "slot " .. tostring(slot_id) .. ".dynamic_cost.minimum cannot exceed base cost")
    end

    local per_part = tonumber(rule.per_part or 1)
    if not per_part or per_part < 1 or math.floor(per_part) ~= per_part then
        add_error(errors, "slot " .. tostring(slot_id) .. ".dynamic_cost.per_part must be a positive integer")
    end
end

local function validate_keywords(errors, owner_id, source, allowed)
    for _, message in ipairs(Keywords.validate_collection(source, allowed)) do
        add_error(errors, tostring(owner_id) .. " has " .. message)
    end
end

local function validate_die(errors, part_id, die)
    if type(die) ~= "table" then
        add_error(errors, part_id .. " is missing die data")
        return
    end

    if type(die.faces) ~= "table" then
        add_error(errors, part_id .. " die.faces must be a table")
    end

    for index = 1, 6 do
        if die.faces and die.faces[index] == nil then
            add_error(errors, part_id .. " die.faces[" .. tostring(index) .. "] is missing")
        end
    end

    local face_sets = {}
    local function validate_face_indexes(field)
        local indexes = die[field]
        if type(indexes) ~= "table" then
            add_error(errors, part_id .. " " .. field .. " must define exactly two face indexes")
            return
        end

        if #indexes ~= 2 then
            add_error(errors, part_id .. " " .. field .. " must define exactly two face indexes")
        end

        face_sets[field] = {}
        for _, face_index in ipairs(die[field] or {}) do
            local numeric = tonumber(face_index)
            if not numeric or numeric < 1 or numeric > 6 then
                add_error(errors, part_id .. " " .. field .. " contains invalid face index " .. tostring(face_index))
            elseif face_sets[field][numeric] then
                add_error(errors, part_id .. " " .. field .. " contains duplicate face index " .. tostring(face_index))
            else
                face_sets[field][numeric] = true
            end
        end
    end

    validate_face_indexes("wound_faces")
    validate_face_indexes("maim_faces")

    for index in pairs(face_sets.wound_faces or {}) do
        if face_sets.maim_faces and face_sets.maim_faces[index] then
            add_error(errors, part_id .. " wound_faces and maim_faces both include face index " .. tostring(index))
        end
    end
end

local function validate_slot(errors, slot_id, slot)
    if type(slot) ~= "table" then
        add_error(errors, "slot " .. tostring(slot_id) .. " must be a table")
        return
    end

    if not slot.name then
        add_error(errors, "slot " .. tostring(slot_id) .. " is missing name")
    end

    if type(slot.cost) ~= "table" or #slot.cost == 0 then
        add_error(errors, "slot " .. tostring(slot_id) .. " must define a non-empty cost")
    end

    local timing = (slot.timing or "spend"):lower()
    if not VALID_TIMINGS[timing] then
        add_error(errors, "slot " .. tostring(slot_id) .. " has invalid timing " .. tostring(slot.timing))
    end

    validate_keywords(errors, "slot " .. tostring(slot_id), slot.keyword, SLOT_KEYWORDS)
    validate_keywords(errors, "slot " .. tostring(slot_id), slot.keywords, SLOT_KEYWORDS)
    validate_dynamic_cost(errors, slot_id, slot)
    Effects.validate(slot.effect or { type = "none" }, "slot " .. tostring(slot_id) .. ".effect", errors)
end

function Content.validate(definitions)
    local errors = {}

    if type(definitions) ~= "table" then
        return { "content module must return a table" }
    end

    for slot_id, slot in pairs(definitions.slots or {}) do
        validate_slot(errors, slot_id, slot)
    end

    for part_id, part in pairs(definitions.parts or {}) do
        if not part.id then
            add_error(errors, "part " .. tostring(part_id) .. " is missing id")
        elseif part.id ~= part_id then
            add_error(errors, "part key " .. tostring(part_id) .. " does not match id " .. tostring(part.id))
        end

        if not part.name then
            add_error(errors, part_id .. " is missing name")
        end

        if not part.type then
            add_error(errors, part_id .. " is missing type")
        end

        validate_die(errors, part_id, part.die)
        validate_keywords(errors, part_id, part.keyword, PART_KEYWORDS)
        validate_keywords(errors, part_id, part.keywords, PART_KEYWORDS)

        if type(part.slot) == "string" and not (definitions.slots and definitions.slots[part.slot]) then
            add_error(errors, part_id .. " references unknown slot " .. tostring(part.slot))
        elseif type(part.slot) == "table" then
            validate_slot(errors, part_id .. ".slot", part.slot)
        end
    end

    for loadout_id, loadout in pairs(definitions.loadouts or {}) do
        if type(loadout.parts) ~= "table" or #loadout.parts == 0 then
            add_error(errors, "loadout " .. tostring(loadout_id) .. " must define parts")
        else
            for _, part_id in ipairs(loadout.parts) do
                if not (definitions.parts and definitions.parts[part_id]) then
                    add_error(errors, "loadout " .. tostring(loadout_id) .. " references unknown part " .. tostring(part_id))
                end
            end
        end

        for crest in pairs(loadout.crest_pool or {}) do
            Crests.validate_name(errors, "loadout " .. tostring(loadout_id) .. ".crest_pool", crest)
        end
    end

    return errors
end

function Content.load_module(module_name)
    local definitions = require(module_name)
    local errors = Content.validate(definitions)
    if #errors > 0 then
        error("Invalid v2 combat content in " .. tostring(module_name) .. ":\n - " .. table.concat(errors, "\n - "))
    end
    return definitions
end

function Content.build_part(definitions, part_id)
    local part_def = definitions.parts and definitions.parts[part_id]
    if not part_def then
        error("Unknown body part: " .. tostring(part_id))
    end

    local data = copy_table(part_def)
    data.die = normalize_die(part_def.die)
    data.keyword = Keywords.normalize(part_def.keyword)
    data.keywords = Keywords.normalize_collection(part_def.keywords or {})

    if type(part_def.slot) == "string" then
        data.slot = normalize_slot(definitions.slots[part_def.slot])
    else
        data.slot = normalize_slot(part_def.slot)
    end

    return BodyPart:new(data)
end

function Content.build_combatant(definitions, loadout_id)
    local loadout = definitions.loadouts and definitions.loadouts[loadout_id]
    if not loadout then
        error("Unknown combatant loadout: " .. tostring(loadout_id))
    end

    local combatant = Combatant:new({
        id = loadout.id or loadout_id,
        name = loadout.name or loadout_id,
        is_player = loadout.is_player or false,
        ai_personality = copy_table(loadout.ai_personality or loadout.ai_profile or loadout.ai),
        crest_pool = copy_table(loadout.crest_pool or {}),
        heart_points = loadout.heart_points or 3
    })

    for _, part_id in ipairs(loadout.parts or {}) do
        combatant:add_body_part(Content.build_part(definitions, part_id))
    end

    return combatant
end

return Content
