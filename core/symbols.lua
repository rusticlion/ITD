local Symbols = {
    STRIKE = "strike",
    WARD = "ward",
    ESSENCE = "essence",
    BLOOD = "blood",
    BLANK = "blank"
}

local ALIASES = {
    s = Symbols.STRIKE,
    strike = Symbols.STRIKE,
    sword = Symbols.STRIKE,
    attack = Symbols.STRIKE,
    atk = Symbols.STRIKE,

    w = Symbols.WARD,
    ward = Symbols.WARD,
    shield = Symbols.WARD,
    defense = Symbols.WARD,
    def = Symbols.WARD,

    e = Symbols.ESSENCE,
    essence = Symbols.ESSENCE,
    magic = Symbols.ESSENCE,
    spark = Symbols.ESSENCE,

    blood = Symbols.BLOOD,
    b = Symbols.BLOOD,

    blank = Symbols.BLANK,
    none = Symbols.BLANK,
    empty = Symbols.BLANK,
    ["-"] = Symbols.BLANK
}

local DISPLAY = {
    [Symbols.STRIKE] = "ATK",
    [Symbols.WARD] = "DEF",
    [Symbols.ESSENCE] = "ESS",
    [Symbols.BLOOD] = "BLD",
    [Symbols.BLANK] = "---"
}

local function copy_list(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

function Symbols.normalize(symbol)
    if symbol == nil then
        return nil
    end

    local lowered = tostring(symbol):lower()
    return ALIASES[lowered] or lowered
end

function Symbols.normalize_face(face)
    local normalized = {}

    if type(face) == "table" then
        for _, symbol in ipairs(face) do
            local value = Symbols.normalize(symbol)
            if value and value ~= Symbols.BLANK then
                table.insert(normalized, value)
            end
        end
    elseif type(face) == "string" then
        local direct = Symbols.normalize(face)
        if direct and direct ~= Symbols.BLANK and ALIASES[face:lower()] then
            table.insert(normalized, direct)
        else
            for token in face:gmatch("[^%s,%+]+") do
                local value = Symbols.normalize(token)
                if value and value ~= Symbols.BLANK then
                    table.insert(normalized, value)
                end
            end
        end
    end

    if #normalized == 0 then
        normalized[1] = Symbols.BLANK
    end

    return normalized
end

function Symbols.copy_face(face)
    return copy_list(face)
end

function Symbols.with_added_symbols(face, added)
    local combined = copy_list(face)
    for _, symbol in ipairs(added or {}) do
        local value = Symbols.normalize(symbol)
        if value and value ~= Symbols.BLANK then
            table.insert(combined, value)
        end
    end

    if #combined == 0 then
        combined[1] = Symbols.BLANK
    end

    return combined
end

function Symbols.count(face, symbol)
    local wanted = Symbols.normalize(symbol)
    local total = 0

    for _, value in ipairs(face or {}) do
        if value == wanted then
            total = total + 1
        end
    end

    return total
end

function Symbols.has(face, symbol)
    return Symbols.count(face, symbol) > 0
end

function Symbols.display(symbol)
    return DISPLAY[Symbols.normalize(symbol)] or tostring(symbol)
end

function Symbols.format_face(face)
    local labels = {}
    for _, symbol in ipairs(face or {}) do
        table.insert(labels, Symbols.display(symbol))
    end

    if #labels == 0 then
        return Symbols.display(Symbols.BLANK)
    end

    return table.concat(labels, "+")
end

return Symbols
