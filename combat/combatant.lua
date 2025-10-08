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
        selected_tech = nil,
        is_player = data.is_player or false
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
                table.insert(techs, tech)
            elseif type(tech) == "string" then
                table.insert(techs, { id = tech, name = tech, actions = {} })
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

return Combatant
