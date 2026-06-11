local BodyPart = require("combat.bodypart")
local Combatant = require("combat.combatant")
local Symbols = require("core.symbols")

local Content = {}

local VALID_TIMINGS = {
    spend = true,
    on_hit = true,
    on_wound_maim = true,
    upkeep = true
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

    for _, symbol in ipairs(slot.cost or {}) do
        table.insert(normalized.cost, Symbols.normalize(symbol))
    end

    normalized.timing = (normalized.timing or "spend"):lower()
    return normalized
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

    local function validate_face_indexes(field)
        for _, face_index in ipairs(die[field] or {}) do
            local numeric = tonumber(face_index)
            if not numeric or numeric < 1 or numeric > 6 then
                add_error(errors, part_id .. " " .. field .. " contains invalid face index " .. tostring(face_index))
            end
        end
    end

    validate_face_indexes("wound_faces")
    validate_face_indexes("maim_faces")
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
        crest_pool = copy_table(loadout.crest_pool or {}),
        heart_points = loadout.heart_points or 3
    })

    for _, part_id in ipairs(loadout.parts or {}) do
        combatant:add_body_part(Content.build_part(definitions, part_id))
    end

    return combatant
end

return Content
