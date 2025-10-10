local Layouts = {}

local SPRITE_SIZE = 128
local DEFAULT_WIDTH = 220

local SLOT_ALIASES = {
    head = "head",
    skull = "head",
    torso = "torso",
    body = "torso",
    chest = "torso",
    core = "torso",
    arm = "arm",
    arm_left = "arm_left",
    left_arm = "arm_left",
    l_arm = "arm_left",
    arm_right = "arm_right",
    right_arm = "arm_right",
    r_arm = "arm_right",
    leg = "leg",
    leg_left = "leg_left",
    left_leg = "leg_left",
    l_leg = "leg_left",
    leg_right = "leg_right",
    right_leg = "leg_right",
    r_leg = "leg_right"
}

local SLOT_OFFSETS = {
    head = { x = 0, y = -SPRITE_SIZE * 1.3 },
    torso = { x = 0, y = -SPRITE_SIZE * 0.1 },
    arm_left = { x = -SPRITE_SIZE * 1.2, y = -SPRITE_SIZE * 0.1 },
    arm_right = { x = SPRITE_SIZE * 1.2, y = -SPRITE_SIZE * 0.1 },
    leg_left = { x = -SPRITE_SIZE * 0.6, y = SPRITE_SIZE * 1.15 },
    leg_right = { x = SPRITE_SIZE * 0.6, y = SPRITE_SIZE * 1.15 }
}

local function clamp_width(width)
    if not width or width <= 0 then
        return DEFAULT_WIDTH
    end
    return width
end

local function resolve_side(combatant, index)
    if combatant and combatant.is_player then
        return "left"
    end

    if combatant and combatant.is_enemy then
        return "right"
    end

    if index == 1 then
        return "left"
    end

    return "right"
end

local function resolve_slot(part)
    if not part then
        return "torso"
    end

    if part.layout_slot then
        return part.layout_slot
    end

    if part.slot then
        return part.slot
    end

    local part_type = part.type
    if type(part_type) == "string" then
        part_type = part_type:lower()
        if SLOT_ALIASES[part_type] then
            local mapped = SLOT_ALIASES[part_type]
            if mapped ~= "arm" and mapped ~= "leg" then
                return mapped
            end

            part_type = mapped
        end
    end

    local id = part.id
    if type(id) == "string" then
        local lowered = id:lower()
        if lowered:find("left", 1, true) then
            if part_type == "arm" then
                return "arm_left"
            elseif part_type == "leg" then
                return "leg_left"
            end
        elseif lowered:find("right", 1, true) then
            if part_type == "arm" then
                return "arm_right"
            elseif part_type == "leg" then
                return "leg_right"
            end
        end
    end

    if part_type == "arm" then
        return "arm_right"
    elseif part_type == "leg" then
        return "leg_right"
    end

    return part_type or "torso"
end

local function get_anchor(side)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    local center_x = width * (side == "right" and 0.72 or 0.28)
    local center_y = height * 0.40

    return center_x, center_y
end

function Layouts.get_combatant_side(combatant, index)
    return resolve_side(combatant, index)
end

function Layouts.get_body_part_position(combatant, index, part)
    local side = resolve_side(combatant, index)
    local slot = resolve_slot(part)
    local anchor_x, anchor_y = get_anchor(side)
    local offset = SLOT_OFFSETS[slot] or SLOT_OFFSETS.torso or { x = 0, y = 0 }

    local x = anchor_x + offset.x - SPRITE_SIZE * 0.5
    local y = anchor_y + offset.y - SPRITE_SIZE * 0.5

    return x, y
end

function Layouts.get_name_region(combatant, index)
    local side = resolve_side(combatant, index)
    local anchor_x, anchor_y = get_anchor(side)
    local width = clamp_width(SPRITE_SIZE * 2.2)
    local x = anchor_x - width * 0.5
    local y = anchor_y - SPRITE_SIZE * 2.1

    return x, y, width
end

function Layouts.get_heart_position(combatant, index)
    local side = resolve_side(combatant, index)
    local anchor_x, anchor_y = get_anchor(side)
    local x = anchor_x - SPRITE_SIZE * 0.7
    local y = anchor_y + SPRITE_SIZE * 1.2

    return x, y
end

function Layouts.get_crest_region(combatant, index)
    local side = resolve_side(combatant, index)
    local anchor_x, anchor_y = get_anchor(side)
    local width = clamp_width(SPRITE_SIZE * 2.4)
    local x = anchor_x - width * 0.5
    local y = anchor_y + SPRITE_SIZE * 1.8

    return x, y, width
end

function Layouts.get_prompt_region()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local region_width = math.min(width * 0.9, 640)
    local x = (width - region_width) * 0.5
    local y = height - 64

    return x, y, region_width
end

function Layouts.get_sprite_size()
    return SPRITE_SIZE
end

return Layouts
