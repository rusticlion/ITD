local Keywords = {}

Keywords.ORDER = {
    "Armored",
    "Brittle",
    "Absorbent",
    "Hungry"
}

Keywords.DEFINITIONS = {
    Armored = {
        name = "Armored",
        short = "AR",
        asset = "bp_keyword_armored",
        layer = "rim",
        description = "Only dice showing 2+ ATK may be assigned to this rim."
    },
    Brittle = {
        name = "Brittle",
        short = "BR",
        asset = "bp_keyword_brittle",
        layer = "body",
        description = "Any damage to this Body Part maims it."
    },
    Absorbent = {
        name = "Absorbent",
        short = "AB",
        asset = "bp_keyword_absorbent",
        layer = "socket",
        description = "If attacked and undamaged while its socket holds a die, feed that die to its Slot."
    },
    Hungry = {
        name = "Hungry",
        short = "HU",
        asset = "bp_keyword_hungry",
        layer = "slot",
        description = "This Slot uses wildcard pips; any nonblank symbol can light one."
    }
}

local CANONICAL = {}
for _, name in ipairs(Keywords.ORDER) do
    CANONICAL[name:lower()] = name
end

local function add_unique(list, seen, value)
    local normalized = Keywords.normalize(value)
    if normalized and not seen[normalized] then
        table.insert(list, normalized)
        seen[normalized] = true
    end
end

function Keywords.normalize(keyword)
    if keyword == nil then
        return nil
    end

    local text = tostring(keyword)
    return CANONICAL[text:lower()] or text
end

function Keywords.is_known(keyword)
    local normalized = Keywords.normalize(keyword)
    return normalized ~= nil and Keywords.DEFINITIONS[normalized] ~= nil
end

function Keywords.normalize_collection(source)
    local list = {}
    local seen = {}

    if type(source) == "string" then
        add_unique(list, seen, source)
    elseif type(source) == "table" then
        for _, value in ipairs(source) do
            add_unique(list, seen, value)
        end

        for key, value in pairs(source) do
            if type(key) ~= "number" and value then
                add_unique(list, seen, key)
            end
        end
    end

    return list
end

function Keywords.collection_has(source, keyword)
    local wanted = Keywords.normalize(keyword)
    if not wanted then
        return false
    end

    for _, existing in ipairs(Keywords.normalize_collection(source)) do
        if existing == wanted then
            return true
        end
    end

    return false
end

function Keywords.has(part, keyword)
    if not part then
        return false
    end

    local wanted = Keywords.normalize(keyword)
    if not wanted then
        return false
    end

    if Keywords.normalize(part.keyword) == wanted then
        return true
    end

    return Keywords.collection_has(part.keywords, wanted)
end

function Keywords.slot_is_hungry(part, slot)
    slot = slot or (part and part.slot)
    if Keywords.has(part, "Hungry") then
        return true
    end

    if not slot then
        return false
    end

    return slot.hungry == true
        or Keywords.normalize(slot.keyword) == "Hungry"
        or Keywords.collection_has(slot.keywords, "Hungry")
end

function Keywords.badges_for_part(part)
    local badges = {}
    if not part then
        return badges
    end

    for _, name in ipairs(Keywords.ORDER) do
        local present = Keywords.has(part, name)
        if name == "Hungry" then
            present = present or Keywords.slot_is_hungry(part, part.slot)
        end

        if present then
            table.insert(badges, Keywords.DEFINITIONS[name])
        end
    end

    return badges
end

function Keywords.validate_collection(source, allowed)
    local errors = {}
    for _, keyword in ipairs(Keywords.normalize_collection(source)) do
        if not Keywords.is_known(keyword) then
            table.insert(errors, "unknown keyword " .. tostring(keyword))
        elseif allowed and not allowed[keyword] then
            table.insert(errors, "keyword " .. tostring(keyword) .. " is not valid here")
        end
    end
    return errors
end

return Keywords
