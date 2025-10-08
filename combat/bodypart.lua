local BodyPart = {}
BodyPart.__index = BodyPart

local VALID_STATUSES = {
    healthy = true,
    wounded = true,
    maimed = true
}

function BodyPart:new(data)
    local instance = {
        id = data.id,
        name = data.name,
        type = data.type,
        status = data.status or "healthy",
        toughness = data.toughness or 2,
        hp_value = data.hp_value or 1,
        techs = data.techs or {},
        tags = data.tags or {}
    }

    return setmetatable(instance, BodyPart)
end

function BodyPart:has_tag(tag)
    for _, existing in ipairs(self.tags) do
        if existing == tag then
            return true
        end
    end
    return false
end

function BodyPart:set_status(status)
    if not VALID_STATUSES[status] then
        return
    end

    self.status = status
end

function BodyPart:advance_damage_state()
    if self.status == "healthy" then
        self.status = "wounded"
        return "wounded"
    elseif self.status == "wounded" then
        self.status = "maimed"
        return "maimed"
    end

    return self.status
end

return BodyPart
