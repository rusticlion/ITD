local Engine = require("combat.engine")
local Events = require("combat.events")
local Combatant = require("combat.combatant")

math.randomseed(12345)

local engine = Engine:new()

engine:on(Events.ROUND_START, function(data)
    print("\n=== ROUND " .. data.round .. " ===")
end)

engine:on(Events.TECH_SELECT_PHASE, function(data)
    if data.combatant and data.available_techs then
        print("\nSelect tech for " .. data.combatant.name)
        print("Available techs:")
        for index, tech in ipairs(data.available_techs) do
            print(index .. ". " .. (tech.name or tech.id))
        end
    elseif data.combatants then
        print("\nTech Selection Phase")
    end
end)

engine:on(Events.DAMAGE_DEALT, function(data)
    if data.heart_point_loss then
        print(string.format("%s loses %d Heart Point(s)!", data.target.name, data.heart_point_loss))
        return
    end

    if data.body_part then
        print(string.format("%s takes damage to %s (%s -> %s)",
            data.target.name,
            data.body_part.name,
            data.status_before or "?",
            data.status_after or "?"))
    end
end)

engine:on(Events.DICE_ROLLED, function(data)
    local attacker_name = data.attacker and data.attacker.name or "Unknown"
    local result = data.result or {}
    local rolls = {}
    for _, value in ipairs(result.rolls or {}) do
        table.insert(rolls, tostring(value))
    end

    local roll_string = #rolls > 0 and table.concat(rolls, ", ") or ""
    local dice_label = result.count and result.type and (result.count .. result.type) or (result.type or "dice")

    print(string.format("%s rolls %s [%s] -> total %d", attacker_name, dice_label, roll_string, result.total or 0))
end)

engine:on(Events.COMBAT_END, function(data)
    local winner = engine.winner
    if winner then
        print("\nCombat ends! Winner: " .. winner.name)
    else
        print("\nCombat ends in a draw.")
    end
end)

local function get_player_input(prompt)
    io.write(prompt .. ": ")
    return io.read()
end

local function create_demo_combatants()
    local slash = {
        id = "slash",
        name = "Dreamblade Slash",
        actions = {
            { type = "attack_roll", dice_count = 2, dice_type = "d6" }
        }
    }

    local crushing_blow = {
        id = "crushing_blow",
        name = "Crushing Blow",
        actions = {
            { type = "attack_roll", dice_count = 1, dice_type = "d8" }
        }
    }

    local player = Combatant:new({ id = "player", name = "Dreamer", is_player = true })
    player:add_body_part({
        id = "player_arm",
        name = "Dreamblade Arm",
        type = "ARM",
        toughness = 2,
        hp_value = 1,
        techs = { slash }
    })
    player:add_body_part({
        id = "player_legs",
        name = "Surefooted Legs",
        type = "LEG",
        toughness = 2,
        hp_value = 1,
        techs = {}
    })

    local enemy = Combatant:new({ id = "enemy", name = "Nightmare" })
    enemy:add_body_part({
        id = "enemy_claw",
        name = "Gnarled Claw",
        type = "ARM",
        toughness = 2,
        hp_value = 1,
        techs = { crushing_blow }
    })
    enemy:add_body_part({
        id = "enemy_hide",
        name = "Thick Hide",
        type = "BODY",
        toughness = 3,
        hp_value = 1,
        techs = {}
    })

    return player, enemy
end

local function run_test_combat()
    local player, enemy = create_demo_combatants()
    engine:add_combatant(player)
    engine:add_combatant(enemy)

    engine:start_combat()

    while engine.state ~= "COMPLETE" do
        engine:process_state()

        if engine:needs_input() then
            local input = get_player_input(engine:get_input_prompt())
            engine:provide_input(input)
        end
    end
end

run_test_combat()
