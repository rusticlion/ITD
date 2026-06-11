local Symbols = require("core.symbols")

local SymbolDie = {}

local function copy_set(list)
    local set = {}
    for _, index in ipairs(list or {}) do
        local numeric = tonumber(index)
        if numeric then
            set[numeric] = true
        end
    end
    return set
end

local function normalize_faces(faces)
    local normalized = {}

    for index = 1, 6 do
        normalized[index] = Symbols.normalize_face(faces and faces[index] or Symbols.BLANK)
    end

    return normalized
end

function SymbolDie.new(data)
    data = data or {}

    return {
        faces = normalize_faces(data.faces),
        wound_faces = copy_set(data.wound_faces),
        maim_faces = copy_set(data.maim_faces)
    }
end

function SymbolDie.face_for_status(die_data, face_index, status)
    local die = SymbolDie.new(die_data)
    local index = tonumber(face_index) or 1
    local current_status = status or "healthy"

    if current_status == "wounded" and die.wound_faces[index] then
        return { Symbols.BLOOD }
    end

    if current_status == "maimed" and (die.wound_faces[index] or die.maim_faces[index]) then
        return { Symbols.BLOOD }
    end

    return Symbols.copy_face(die.faces[index] or { Symbols.BLANK })
end

function SymbolDie.roll(part, rng)
    local roller = rng or math.random
    local face_index = roller(1, 6)

    return {
        face_index = face_index,
        symbols = SymbolDie.face_for_status(part and part.die, face_index, part and part.status),
        source_part = part
    }
end

function SymbolDie.format_face_for_status(die_data, face_index, status)
    return Symbols.format_face(SymbolDie.face_for_status(die_data, face_index, status))
end

return SymbolDie
