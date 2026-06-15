local Symbols = require("core.symbols")

local AI = {}

local PROFILES = {
    balanced = {
        weights = {
            rim = 30,
            socket = 22,
            slot = 14
        },
        symbol_values = {
            strike = 9,
            ward = 8,
            slot = 8
        },
        fill_slot_bonus = 18,
        charged_slot_bonus = 5,
        target_status_bonus = {
            wounded = 10,
            healthy = 0
        },
        target_type_bonus = {
            HEAD = 4,
            BODY = 2
        },
        defend_status_bonus = {
            wounded = 12,
            healthy = 0
        },
        defend_charged_slot_bonus = 6,
        preferred_slots = {}
    },

    aggressive = {
        base = "balanced",
        weights = {
            rim = 38,
            socket = 14,
            slot = 12
        },
        symbol_values = {
            strike = 11,
            ward = 6,
            slot = 7
        },
        target_status_bonus = {
            wounded = 16,
            healthy = 0
        }
    },

    doom_caster = {
        base = "balanced",
        weights = {
            rim = 24,
            socket = 16,
            slot = 40
        },
        symbol_values = {
            strike = 8,
            ward = 7,
            slot = 11
        },
        fill_slot_bonus = 36,
        charged_slot_bonus = 14,
        preferred_slots = {
            speak_doom = 32,
            ["Speak Doom"] = 32
        },
        target_type_bonus = {
            HEAD = 8,
            BODY = 3
        },
        target_status_bonus = {
            wounded = 8,
            healthy = 0
        },
        defend_charged_slot_bonus = 14
    }
}

local function copy_list(source)
    local copy = {}
    for index, value in ipairs(source or {}) do
        copy[index] = value
    end
    return copy
end

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

local function merge_table(base, override)
    local merged = copy_table(base or {})

    for key, value in pairs(override or {}) do
        if key ~= "base" and type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = merge_table(merged[key], value)
        elseif key ~= "base" then
            merged[key] = copy_table(value)
        end
    end

    return merged
end

local function resolve_profile(combatant)
    local profile = combatant and combatant.ai_personality or nil

    if type(profile) == "table" then
        local base_name = profile.base or profile.profile or profile.id or "balanced"
        local base = PROFILES[base_name] or PROFILES.balanced
        return merge_table(base, profile)
    end

    local named = PROFILES[profile or "balanced"] or PROFILES.balanced
    if named.base and PROFILES[named.base] then
        return merge_table(PROFILES[named.base], named)
    end

    return copy_table(named)
end

local function slot_charge_count(part)
    local total = 0
    for _, charged in pairs(part and part.slot_charge or {}) do
        if charged then
            total = total + 1
        end
    end
    return total
end

local function slot_feed_match_count(part, symbols)
    local slot = part and part.slot
    local cost = slot and slot.cost or {}
    local to_light = {}
    local hungry = part and (part:has_keyword("Hungry") or (slot and slot.hungry))
    local remaining_before = 0

    for index = 1, #cost do
        if not (part.slot_charge and part.slot_charge[index]) then
            remaining_before = remaining_before + 1
        end
    end

    for _, symbol in ipairs(symbols or {}) do
        if symbol ~= Symbols.BLANK then
            for index, required in ipairs(cost) do
                if not (part.slot_charge and part.slot_charge[index]) and not to_light[index] then
                    if hungry or required == symbol then
                        to_light[index] = true
                        break
                    end
                end
            end
        end
    end

    local lit_count = 0
    for _ in pairs(to_light) do
        lit_count = lit_count + 1
    end

    return lit_count, remaining_before
end

local function part_type_bonus(profile, part)
    local part_type = part and part.type and tostring(part.type):upper()
    return (profile.target_type_bonus and profile.target_type_bonus[part_type]) or 0
end

local function part_status_bonus(table_by_status, part)
    local status = part and part.status or "healthy"
    return (table_by_status and table_by_status[status]) or 0
end

local function preferred_slot_bonus(profile, slot)
    if not slot then
        return 0
    end

    local preferred = profile.preferred_slots or {}
    return preferred[slot.id] or preferred[slot.name] or 0
end

local function score_rim(profile, symbols, target)
    local strikes = Symbols.count(symbols, Symbols.STRIKE)
    if strikes <= 0 then
        return nil
    end

    local weights = profile.weights or {}
    local values = profile.symbol_values or {}
    return (weights.rim or 0)
        + strikes * (values.strike or 0)
        + part_type_bonus(profile, target)
        + part_status_bonus(profile.target_status_bonus, target)
end

local function score_socket(profile, symbols, part)
    local wards = Symbols.count(symbols, Symbols.WARD)
    if wards <= 0 then
        return nil
    end

    local weights = profile.weights or {}
    local values = profile.symbol_values or {}
    return (weights.socket or 0)
        + wards * (values.ward or 0)
        + part_status_bonus(profile.defend_status_bonus, part)
        + slot_charge_count(part) * (profile.defend_charged_slot_bonus or 0)
end

local function score_slot(profile, symbols, part)
    local lit_count, remaining_before = slot_feed_match_count(part, symbols)
    if lit_count <= 0 then
        return nil
    end

    local weights = profile.weights or {}
    local values = profile.symbol_values or {}
    local score = (weights.slot or 0)
        + lit_count * (values.slot or 0)
        + slot_charge_count(part) * (profile.charged_slot_bonus or 0)
        + preferred_slot_bonus(profile, part and part.slot)

    if remaining_before > 0 and lit_count >= remaining_before then
        score = score + (profile.fill_slot_bonus or 0)
    end

    return score
end

local function consider(best, candidate)
    if not candidate or not candidate.score then
        return best
    end

    if not best or candidate.score > best.score then
        return candidate
    end

    return best
end

local function score_die_moves(engine, combatant, die, profile)
    local destinations = engine:get_valid_destinations(combatant, die)
    local symbols = engine:get_effective_symbols(combatant, die)
    local best = nil

    for _, part in ipairs(destinations.slots or {}) do
        best = consider(best, {
            kind = "slot",
            die = die,
            part = part,
            score = score_slot(profile, symbols, part)
        })
    end

    for _, part in ipairs(destinations.rims or {}) do
        best = consider(best, {
            kind = "rim",
            die = die,
            part = part,
            score = score_rim(profile, symbols, part)
        })
    end

    for _, part in ipairs(destinations.sockets or {}) do
        best = consider(best, {
            kind = "socket",
            die = die,
            part = part,
            score = score_socket(profile, symbols, part)
        })
    end

    if best then
        best.score = nil
    end

    return best
end

function AI.choose_allocation(engine, combatant, die_or_id)
    if not (engine and combatant) then
        return nil
    end

    local die = engine:find_die(combatant, die_or_id)
    if not die then
        return nil
    end

    return score_die_moves(engine, combatant, die, resolve_profile(combatant))
end

function AI.choose_next_allocation(engine, combatant)
    if not (engine and combatant) then
        return nil
    end

    local profile = resolve_profile(combatant)
    local best = nil

    for _, die in ipairs(engine:get_pool(combatant)) do
        local destinations = engine:get_valid_destinations(combatant, die)
        local symbols = engine:get_effective_symbols(combatant, die)

        for _, part in ipairs(destinations.slots or {}) do
            best = consider(best, {
                kind = "slot",
                die = die,
                part = part,
                score = score_slot(profile, symbols, part)
            })
        end

        for _, part in ipairs(destinations.rims or {}) do
            best = consider(best, {
                kind = "rim",
                die = die,
                part = part,
                score = score_rim(profile, symbols, part)
            })
        end

        for _, part in ipairs(destinations.sockets or {}) do
            best = consider(best, {
                kind = "socket",
                die = die,
                part = part,
                score = score_socket(profile, symbols, part)
            })
        end
    end

    if best then
        best.score = nil
    end

    return best
end

function AI.auto_allocate(engine, combatant)
    if not (engine and combatant) then
        return
    end

    local guard = 0
    while guard < 24 do
        guard = guard + 1
        local move = AI.choose_next_allocation(engine, combatant)
        if not move then
            return
        end

        local ok = engine:commit_allocation_move(combatant, move)
        if not ok then
            return
        end
    end
end

function AI.get_profile(name)
    return copy_table(PROFILES[name or "balanced"])
end

return AI
