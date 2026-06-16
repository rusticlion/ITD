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
        is_player = data.is_player or false,
        pending_next_symbols = {},
        allocation_symbol_modifiers = {},
        pending_spellmarks = {},
        shadow_slot_shroud = false,
        ai_personality = data.ai_personality or data.ai_profile or data.ai or "balanced"
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

function Combatant:add_allocation_symbol_modifier(modifier)
    if type(modifier) ~= "table" or not modifier.symbol then
        return
    end

    self.allocation_symbol_modifiers = self.allocation_symbol_modifiers or {}
    table.insert(self.allocation_symbol_modifiers, modifier)
end

function Combatant:get_allocation_symbol_modifiers()
    return self.allocation_symbol_modifiers or {}
end

function Combatant:add_spellmark(spellmark)
    if type(spellmark) ~= "table" then
        return
    end

    self.pending_spellmarks = self.pending_spellmarks or {}
    table.insert(self.pending_spellmarks, spellmark)
end

function Combatant:get_spellmarks()
    return self.pending_spellmarks or {}
end

function Combatant:remove_spellmark(spellmark)
    for index = #(self.pending_spellmarks or {}), 1, -1 do
        if self.pending_spellmarks[index] == spellmark then
            table.remove(self.pending_spellmarks, index)
            return true
        end
    end

    return false
end

function Combatant:clear_v2_round_effects()
    self.pending_next_symbols = {}
    self.allocation_symbol_modifiers = {}
    self.pending_spellmarks = {}
    self.shadow_slot_shroud = false
end

return Combatant
