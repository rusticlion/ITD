local Keywords = require("combat.keywords")

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
        instance_id = data.instance_id,
        name = data.name,
        flavor = data.flavor,
        type = data.type,
        status = data.status or "healthy",
        hp_value = data.hp_value or 1,
        tags = data.tags or {},
        die = data.die,
        slot = data.slot,
        keyword = Keywords.normalize(data.keyword),
        keywords = Keywords.normalize_collection(data.keywords or {}),
        slot_charge = {}
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

function BodyPart:is_slot_online()
    return self.slot ~= nil and self.status ~= "maimed"
end

function BodyPart:reset_slot_charge()
    self.slot_charge = {}
end

function BodyPart:vent_slot_charge()
    local had_charge = false

    for _, charged in pairs(self.slot_charge or {}) do
        if charged then
            had_charge = true
            break
        end
    end

    self.slot_charge = {}
    return had_charge
end

function BodyPart:has_keyword(keyword)
    local wanted = Keywords.normalize(keyword)
    if not wanted then
        return false
    end

    if Keywords.normalize(self.keyword) == wanted then
        return true
    end

    if type(self.keywords) == "table" then
        if self.keywords[wanted] then
            return true
        end

        for _, existing in ipairs(self.keywords) do
            if Keywords.normalize(existing) == wanted then
                return true
            end
        end
    end

    return false
end

function BodyPart:regress_damage_state()
    if self.status == "maimed" then
        self.status = "wounded"
        return "wounded"
    elseif self.status == "wounded" then
        self.status = "healthy"
        return "healthy"
    end

    return self.status
end

return BodyPart
