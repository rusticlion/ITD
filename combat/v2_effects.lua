local Crests = require("combat.crests")
local Symbols = require("core.symbols")

local Effects = {}

local PART_TYPES = {
    HEAD = true,
    BODY = true,
    ARM = true,
    LEG = true
}

local VALID_SYMBOLS = {
    [Symbols.STRIKE] = true,
    [Symbols.WARD] = true,
    [Symbols.ESSENCE] = true,
    [Symbols.BLOOD] = true,
    [Symbols.BLANK] = true
}

local DESTINATIONS = {
    any = true,
    socket = true,
    rim = true,
    slot = true
}

local ASSIGN_DESTINATIONS = {
    socket = true,
    rim = true
}

local TARGET_SIDES = {
    self = true,
    opponent = true,
    enemy = true
}

local HEAL_TARGETS = {
    source_part = true,
    most_damaged = true,
    part_type = true
}

local ALIASES = {
    channel_symbol = "add_symbol_to_matching_dice",
    auto_assign_symbol = "assign_symbol_to_each_part",
    spellmark = "open_spellmark",
    damage_target_part = "damage_marked_part",
    damage_assigned_part = "damage_marked_part"
}

Effects.EDITOR_ORDER = {
    "none",
    "add_next_symbol",
    "channel_symbol",
    "assign_symbol_to_each_part",
    "open_spellmark",
    "heal_part",
    "add_symbol_against_status",
    "damage_opponent_part",
    "gain_crest"
}

Effects.EDITOR_LABELS = {
    none = "none",
    add_next_symbol = "next",
    channel_symbol = "channel",
    assign_symbol_to_each_part = "auto assign",
    open_spellmark = "spellmark",
    heal_part = "heal",
    add_symbol_against_status = "status +",
    damage_opponent_part = "damage BP",
    gain_crest = "crest"
}

local function amount_or_default(value, default)
    local numeric = tonumber(value)
    if not numeric or numeric < 1 then
        return default or 1
    end
    return math.floor(numeric)
end

local function normalize_destination(destination)
    local value = destination and tostring(destination):lower()
    if value == "sockets" then
        return "socket"
    elseif value == "rims" then
        return "rim"
    elseif value == "slots" then
        return "slot"
    end
    return value
end

local function display_symbol(symbol, fallback)
    local normalized = Symbols.normalize(symbol or fallback)
    return normalized and Symbols.display(normalized) or "symbol"
end

local function step_word(amount)
    return amount_or_default(amount, 1) == 1 and "step" or "steps"
end

local function target_text(target)
    local value = tostring(target or "self")
    if value == "self" then
        return "allied"
    elseif value == "opponent" or value == "enemy" then
        return "opposing"
    end
    return value
end

local function validate_amount(errors, path, value)
    local numeric = tonumber(value)
    if value ~= nil and (not numeric or numeric < 1 or math.floor(numeric) ~= numeric) then
        table.insert(errors, tostring(path) .. ".amount must be a positive integer")
    end
end

local function validate_symbol(errors, path, value, required)
    if value == nil then
        if required then
            table.insert(errors, tostring(path) .. " is missing a symbol")
        end
        return
    end

    local normalized = Symbols.normalize(value)
    if not normalized or not VALID_SYMBOLS[normalized] then
        table.insert(errors, tostring(path) .. " has invalid symbol " .. tostring(value))
    end
end

local function validate_destination(errors, path, value, allowed)
    if value == nil then
        return
    end

    local normalized = normalize_destination(value)
    local valid = allowed or DESTINATIONS
    if not valid[normalized] then
        table.insert(errors, tostring(path) .. " has invalid destination " .. tostring(value))
    end
end

local function validate_target_side(errors, path, value)
    if value == nil then
        return
    end

    local normalized = tostring(value):lower()
    if not TARGET_SIDES[normalized] then
        table.insert(errors, tostring(path) .. " has invalid target " .. tostring(value))
    end
end

local function validate_part_type(errors, path, value)
    if value == nil then
        return
    end

    local normalized = tostring(value):upper()
    if not PART_TYPES[normalized] then
        table.insert(errors, tostring(path) .. " has invalid Body Part type " .. tostring(value))
    end
end

local function normalize_heal_target(target)
    return target and tostring(target):lower() or "most_damaged"
end

local function validate_heal_target(errors, path, value)
    local normalized = normalize_heal_target(value)
    if not HEAL_TARGETS[normalized] then
        table.insert(errors, tostring(path) .. " has invalid healing target " .. tostring(value))
    end
end

local function is_action_container(effect)
    return type(effect) == "table"
        and (type(effect.actions) == "table" or type(effect.sequence) == "table" or (type(effect[1]) == "table" and effect.type == nil))
end

local DEFINITIONS = {}

DEFINITIONS.none = {
    describe = function()
        return "No effect."
    end,
    execute = function(_, _, effect)
        return { type = effect.type or "none" }
    end
}

DEFINITIONS.gain_crest = {
    describe = function(effect)
        local amount = amount_or_default(effect.amount, 1)
        local crest = Crests.normalize(effect.crest or "Valor")
        return "Gain " .. tostring(amount) .. " " .. tostring(crest) .. " crest" .. (amount == 1 and "." or "s.")
    end,
    validate = function(effect, path, errors)
        Crests.validate_name(errors, path .. ".crest", effect.crest or "Valor")
        validate_amount(errors, path, effect.amount)
    end,
    execute = function(engine, entry, effect)
        local amount = amount_or_default(effect.amount, 1)
        local crest = Crests.normalize(effect.crest or "Valor")
        engine:grant_crest(entry.combatant, crest, amount, { source = "slot", slot = entry.slot })

        return {
            type = "gain_crest",
            crest = crest,
            amount = amount
        }
    end
}

DEFINITIONS.heal_part = {
    describe = function(effect)
        local amount = amount_or_default(effect.amount, 1)
        local target = normalize_heal_target(effect.target)
        local target_text = target == "source_part" and "this Body Part"
            or target == "part_type" and ("the allied " .. tostring(effect.target_type or "Body Part"):upper())
            or "the most damaged allied Body Part"
        return "Heal " .. target_text .. " " .. tostring(amount) .. " " .. step_word(amount) .. "."
    end,
    validate = function(effect, path, errors)
        validate_heal_target(errors, path .. ".target", effect.target)
        if normalize_heal_target(effect.target) == "part_type" then
            validate_part_type(errors, path .. ".target_type", effect.target_type)
            if effect.target_type == nil then
                table.insert(errors, tostring(path) .. ".target_type is required for part_type healing")
            end
        end
        validate_amount(errors, path, effect.amount)
    end,
    execute = function(engine, entry, effect)
        local amount = amount_or_default(effect.amount, 1)
        local target = normalize_heal_target(effect.target)
        local target_part = target == "source_part"
            and entry.part
            or target == "part_type" and engine:find_part_by_type(entry.combatant, effect.target_type)
            or engine:find_most_damaged_part(entry.combatant)

        return {
            type = "heal_part",
            target = target,
            target_part = target_part,
            amount = amount,
            healed = engine:apply_healing(entry.combatant, entry.combatant, target_part, amount, {
                source = "slot",
                slot = entry.slot
            })
        }
    end
}

DEFINITIONS.add_symbol_against_status = {
    describe = function(effect)
        local amount = amount_or_default(effect.amount, 1)
        return "Dice showing "
            .. display_symbol(effect.match or effect.match_symbol, Symbols.STRIKE)
            .. " gain "
            .. tostring(amount)
            .. " "
            .. display_symbol(effect.symbol, Symbols.STRIKE)
            .. " against "
            .. tostring(effect.target_status or "wounded")
            .. " Body Parts."
    end,
    validate = function(effect, path, errors)
        validate_symbol(errors, path .. ".match", effect.match or effect.match_symbol or Symbols.STRIKE)
        validate_symbol(errors, path .. ".symbol", effect.symbol or Symbols.STRIKE)
        validate_destination(errors, path .. ".destination", effect.destination or "rim", ASSIGN_DESTINATIONS)
        validate_amount(errors, path, effect.amount)
        local status = tostring(effect.target_status or "wounded"):lower()
        if status ~= "healthy" and status ~= "wounded" then
            table.insert(errors, tostring(path) .. ".target_status must be healthy or wounded")
        end
    end,
    execute = function(_, entry, effect)
        local symbol = Symbols.normalize(effect.symbol or Symbols.STRIKE)
        local match = Symbols.normalize(effect.match or effect.match_symbol or Symbols.STRIKE)
        local amount = amount_or_default(effect.amount, 1)
        local target_status = tostring(effect.target_status or "wounded"):lower()

        entry.combatant:add_allocation_symbol_modifier({
            match = match,
            symbol = symbol,
            amount = amount,
            destination = effect.destination or "rim",
            target_status = target_status,
            duration = effect.duration or "round",
            source = {
                type = "slot",
                slot = entry.slot,
                part = entry.part
            }
        })

        return {
            type = "add_symbol_against_status",
            match = match,
            symbol = symbol,
            amount = amount,
            destination = normalize_destination(effect.destination or "rim"),
            target_status = target_status,
            duration = effect.duration or "round"
        }
    end
}

DEFINITIONS.add_next_symbol = {
    describe = function(effect)
        local amount = amount_or_default(effect.amount, 1)
        return "Next die gains " .. tostring(amount) .. " " .. display_symbol(effect.symbol, Symbols.STRIKE) .. "."
    end,
    validate = function(effect, path, errors)
        validate_symbol(errors, path .. ".symbol", effect.symbol or Symbols.STRIKE)
        validate_amount(errors, path, effect.amount)
    end,
    execute = function(_, entry, effect)
        local symbol = Symbols.normalize(effect.symbol or Symbols.STRIKE)
        local amount = amount_or_default(effect.amount, 1)

        if entry.combatant and entry.combatant.add_next_symbol then
            for _ = 1, amount do
                entry.combatant:add_next_symbol(symbol)
            end
        end

        return {
            type = "add_next_symbol",
            symbol = symbol,
            amount = amount
        }
    end
}

DEFINITIONS.add_symbol_to_matching_dice = {
    describe = function(effect)
        local destination = effect.destination and (" on " .. tostring(normalize_destination(effect.destination))) or ""
        return "Dice showing "
            .. display_symbol(effect.match or effect.match_symbol or effect.source_symbol, Symbols.ESSENCE)
            .. " gain "
            .. display_symbol(effect.symbol or effect.add_symbol, Symbols.STRIKE)
            .. destination
            .. "."
    end,
    validate = function(effect, path, errors)
        validate_symbol(errors, path .. ".match", effect.match or effect.match_symbol or effect.source_symbol or Symbols.ESSENCE)
        validate_symbol(errors, path .. ".symbol", effect.symbol or effect.add_symbol or Symbols.STRIKE)
        validate_destination(errors, path .. ".destination", effect.destination)
        validate_amount(errors, path, effect.amount)
    end,
    execute = function(_, entry, effect)
        local symbol = Symbols.normalize(effect.symbol or effect.add_symbol or Symbols.STRIKE)
        local match = Symbols.normalize(effect.match or effect.match_symbol or effect.source_symbol or Symbols.ESSENCE)
        local amount = amount_or_default(effect.amount, 1)

        if entry.combatant and entry.combatant.add_allocation_symbol_modifier and symbol then
            entry.combatant:add_allocation_symbol_modifier({
                match = match,
                symbol = symbol,
                amount = amount,
                destination = effect.destination,
                duration = effect.duration or "allocation",
                source = {
                    type = "slot",
                    slot = entry.slot,
                    part = entry.part
                }
            })
        end

        return {
            type = "add_symbol_to_matching_dice",
            match = match,
            symbol = symbol,
            amount = amount,
            destination = normalize_destination(effect.destination),
            duration = effect.duration or "allocation"
        }
    end
}

DEFINITIONS.assign_symbol_to_each_part = {
    describe = function(effect)
        local destination = normalize_destination(effect.destination) or "socket"
        return "Assign "
            .. display_symbol(effect.symbol, destination == "rim" and Symbols.STRIKE or Symbols.WARD)
            .. " to each open "
            .. target_text(effect.target or effect.target_side)
            .. " "
            .. destination
            .. "."
    end,
    validate = function(effect, path, errors)
        validate_destination(errors, path .. ".destination", effect.destination or "socket", ASSIGN_DESTINATIONS)
        validate_target_side(errors, path .. ".target", effect.target or effect.target_side)
        validate_symbol(errors, path .. ".symbol", effect.symbol)
        validate_part_type(errors, path .. ".part_type", effect.part_type)
        validate_amount(errors, path, effect.amount)
    end,
    execute = function(engine, entry, effect)
        return engine:auto_assign_symbols(entry, effect)
    end
}

DEFINITIONS.open_spellmark = {
    describe = function(effect)
        local destination = normalize_destination(effect.destination) or "rim"
        local symbol = display_symbol(effect.symbol or effect.accept_symbol, Symbols.ESSENCE)
        local target_type = effect.target_type or effect.part_type
        local target_text = target_type and (" " .. tostring(target_type):upper()) or ""
        local payload = effect.on_mark or effect.payload or effect.effect
        local payload_text = payload and Effects.describe(payload) or "No payload."
        return "Open a " .. destination .. target_text .. " spellmark accepting " .. symbol .. "; " .. payload_text
    end,
    validate = function(effect, path, errors)
        validate_destination(errors, path .. ".destination", effect.destination or "rim", ASSIGN_DESTINATIONS)
        validate_target_side(errors, path .. ".target", effect.target or effect.target_side)
        validate_symbol(errors, path .. ".symbol", effect.symbol or effect.accept_symbol or Symbols.ESSENCE)
        validate_part_type(errors, path .. ".target_type", effect.target_type or effect.part_type)
        Effects.validate(effect.on_mark or effect.payload or effect.effect or { type = "none" }, path .. ".on_mark", errors)
    end,
    execute = function(engine, entry, effect)
        return engine:open_spellmark(entry, effect)
    end
}

DEFINITIONS.damage_opponent_part = {
    describe = function(effect)
        local amount = amount_or_default(effect.amount, 1)
        local target = effect.target_type and tostring(effect.target_type):upper() or "Body Part"
        return "Damage opponent " .. target .. " " .. tostring(amount) .. " " .. step_word(amount) .. "."
    end,
    validate = function(effect, path, errors)
        validate_part_type(errors, path .. ".target_type", effect.target_type)
        validate_amount(errors, path, effect.amount)
    end,
    execute = function(engine, entry, effect)
        local opponent = engine:get_opponent(entry.combatant)
        local target_part = nil
        local target_type = effect.target_type

        if effect.target_part_id and opponent then
            target_part = opponent:get_body_part_by_id(effect.target_part_id)
        end

        if not target_type and effect.target == "head" then
            target_type = "HEAD"
        end

        if not target_part then
            for _, part in ipairs(opponent and opponent.body_parts or {}) do
                if not target_type or tostring(part.type or ""):upper() == tostring(target_type):upper() then
                    target_part = part
                    break
                end
            end
        end

        local result = {
            type = "damage_opponent_part",
            target_part = target_part,
            amount = amount_or_default(effect.amount, 1),
            damaged = false
        }

        for _ = 1, result.amount do
            if target_part and target_part.status ~= "maimed" then
                result.damaged = engine:apply_damage(entry.combatant, opponent, target_part, {
                    source = "slot",
                    slot = entry.slot,
                    effect = effect
                }) or result.damaged
            end
        end

        return result
    end
}

DEFINITIONS.damage_marked_part = {
    describe = function(effect)
        local amount = amount_or_default(effect.amount, 1)
        return "Damage the marked Body Part " .. tostring(amount) .. " " .. step_word(amount) .. "."
    end,
    validate = function(effect, path, errors)
        validate_amount(errors, path, effect.amount)
    end,
    execute = function()
        return {
            type = "damage_marked_part",
            damaged = false
        }
    end
}

Effects.DEFINITIONS = DEFINITIONS

function Effects.normalize_type(effect_or_type)
    local raw = type(effect_or_type) == "table" and effect_or_type.type or effect_or_type
    if raw == nil then
        return "none"
    end

    local text = tostring(raw):lower()
    return ALIASES[text] or text
end

function Effects.editor_type(effect_or_type)
    local normalized = Effects.normalize_type(effect_or_type)
    if normalized == "add_symbol_to_matching_dice" then
        return "channel_symbol"
    end
    return normalized
end

function Effects.is_known(effect_or_type)
    return DEFINITIONS[Effects.normalize_type(effect_or_type)] ~= nil
end

function Effects.actions(effect)
    if type(effect) ~= "table" then
        return {}
    end

    if type(effect.actions) == "table" then
        return effect.actions
    elseif type(effect.sequence) == "table" then
        return effect.sequence
    elseif type(effect[1]) == "table" and effect.type == nil then
        return effect
    end

    return { effect }
end

function Effects.describe(effect)
    if type(effect) ~= "table" then
        return "No effect."
    end

    local actions = Effects.actions(effect)
    if is_action_container(effect) then
        if #actions == 0 then
            return "No effect."
        elseif #actions == 1 then
            return Effects.describe(actions[1])
        end

        local descriptions = {}
        for _, action in ipairs(actions) do
            table.insert(descriptions, Effects.describe(action))
        end
        return "Sequence: " .. table.concat(descriptions, " ")
    end

    local effect_type = Effects.normalize_type(effect)
    local definition = DEFINITIONS[effect_type]
    if definition and definition.describe then
        return definition.describe(effect)
    end

    return "Unknown effect: " .. tostring(effect.type or "unknown") .. "."
end

function Effects.validate(effect, path, errors)
    errors = errors or {}
    path = path or "effect"

    if effect == nil then
        return errors
    end

    if type(effect) == "function" then
        return errors
    end

    if type(effect) ~= "table" then
        table.insert(errors, tostring(path) .. " must be a table")
        return errors
    end

    local actions = Effects.actions(effect)
    if is_action_container(effect) then
        for index, action in ipairs(actions) do
            Effects.validate(action, path .. ".actions[" .. tostring(index) .. "]", errors)
        end
        return errors
    end

    local effect_type = Effects.normalize_type(effect)
    local definition = DEFINITIONS[effect_type]
    if not definition then
        table.insert(errors, tostring(path) .. " has unknown effect type " .. tostring(effect.type))
        return errors
    end

    if definition.validate then
        definition.validate(effect, path, errors)
    end

    return errors
end

function Effects.execute(engine, entry, effect)
    effect = effect or {}
    local effect_type = Effects.normalize_type(effect)
    local definition = DEFINITIONS[effect_type] or DEFINITIONS.none
    return definition.execute(engine, entry, effect)
end

return Effects
