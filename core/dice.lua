local Dice = {}

local function parse_die_type(dice_type)
    if type(dice_type) ~= "string" then
        return nil
    end

    local sides = dice_type:lower():match("d(%d+)")
    if not sides then
        return nil
    end

    sides = tonumber(sides)
    if sides and sides > 0 then
        return sides
    end

    return nil
end

function Dice.roll(dice_count, dice_type)
    local count = tonumber(dice_count) or 1
    if count < 1 then
        count = 1
    end

    local sides = parse_die_type(dice_type or "d6")
    if not sides then
        error("Invalid dice type: " .. tostring(dice_type))
    end

    local rolls = {}
    local total = 0

    for _ = 1, count do
        local result = math.random(1, sides)
        table.insert(rolls, result)
        total = total + result
    end

    return {
        total = total,
        rolls = rolls,
        count = count,
        sides = sides,
        type = dice_type or ("d" .. tostring(sides))
    }
end

return Dice
