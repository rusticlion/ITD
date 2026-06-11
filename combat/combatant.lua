local BodyPart = require("combat.bodypart")

local Combatant = {}
Combatant.__index = Combatant

function Combatant:new(data)
    local instance = {
        id = data.id,
        name = data.name,
        body_parts = {},
        heart_points = data.heart_points or 3,
        crest_pool = data.crest_pool or {},
        modifiers = {},
        selected_tech = nil,
        is_player = data.is_player or false,
        pending_forced_rerolls = 0,
        attack_bonus_tokens = {},
        pending_next_symbols = {},
        shadow_slot_shroud = false
    }

    local combatant = setmetatable(instance, Combatant)

    if data.body_parts then
        for _, part in ipairs(data.body_parts) do
            combatant:add_body_part(part)
        end
    end

    return combatant
end

function Combatant:add_body_part(part)
    if getmetatable(part) ~= BodyPart then
        part = BodyPart:new(part)
    end

    table.insert(self.body_parts, part)
end

function Combatant:get_body_part_by_id(id)
    for _, part in ipairs(self.body_parts) do
        if part.id == id then
            return part
        end
    end
    return nil
end

function Combatant:get_available_techs()
    local techs = {}

    for _, part in ipairs(self.body_parts) do
        for _, tech in ipairs(part.techs or {}) do
            if type(tech) == "table" then
                table.insert(techs, { tech = tech, source_part = part })
            elseif type(tech) == "string" then
                table.insert(techs, {
                    tech = { id = tech, name = tech, actions = {} },
                    source_part = part
                })
            end
        end
    end

    return techs
end

function Combatant:get_first_healthy_part()
    for _, part in ipairs(self.body_parts) do
        if part.status ~= "maimed" then
            return part
        end
    end

    return nil
end

function Combatant:is_defeated()
    return self.heart_points <= 0
end

function Combatant:add_crest(crest, amount)
    if not crest then
        return 0
    end

    local delta = amount or 1
    self.crest_pool[crest] = (self.crest_pool[crest] or 0) + delta
    return self.crest_pool[crest]
end

function Combatant:remove_crest(crest, amount)
    if not crest then
        return 0
    end

    local current = self.crest_pool[crest] or 0
    local delta = amount or 1
    local remaining = current - delta

    if remaining <= 0 then
        self.crest_pool[crest] = 0
        return 0
    end

    self.crest_pool[crest] = remaining
    return remaining
end

function Combatant:get_crest_count(crest)
    return self.crest_pool[crest] or 0
end

function Combatant:clear_modifiers()
    self.modifiers = {}
end

function Combatant:add_modifier(key, value)
    if not key then
        return
    end

    self.modifiers[key] = (self.modifiers[key] or 0) + (value or 0)
end

function Combatant:get_modifier(key)
    if not key then
        return 0
    end

    return self.modifiers[key] or 0
end

function Combatant:add_next_symbol(symbol)
    if not symbol then
        return
    end

    self.pending_next_symbols = self.pending_next_symbols or {}
    table.insert(self.pending_next_symbols, symbol)
end

function Combatant:get_pending_next_symbols()
    return self.pending_next_symbols or {}
end

function Combatant:consume_pending_next_symbols()
    local symbols = self.pending_next_symbols or {}
    self.pending_next_symbols = {}
    return symbols
end

function Combatant:clear_v2_round_effects()
    self.pending_next_symbols = {}
    self.shadow_slot_shroud = false
end

return Combatant
