local Engine = require("combat.engine")
local Events = require("combat.events")
local Combatant = require("combat.combatant")

math.randomseed(12345)

local engine = Engine:new()

engine:on(Events.ROUND_START, function(data)
    print("\n=== ROUND " .. data.round .. " ===")
end)

engine:on(Events.UPKEEP_PHASE, function(_)
    print("Upkeep Phase")
    for _, combatant in ipairs(engine.combatants) do
        local crest_strings = {}
        for crest, count in pairs(combatant.crest_pool or {}) do
            if count > 0 then
                table.insert(crest_strings, crest .. ":" .. tostring(count))
            end
        end

        local crest_summary = #crest_strings > 0 and table.concat(crest_strings, ", ") or "None"
        local attack_bonus = combatant.get_modifier and combatant:get_modifier("attack_bonus") or 0
        local modifier_summary = attack_bonus > 0 and ("Attack Bonus +" .. attack_bonus) or "No passive bonuses"

        print(string.format(" - %s Crests [%s] | %s", combatant.name, crest_summary, modifier_summary))
    end
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

engine:on(Events.ATTACK_ASSIGN_PHASE, function(_)
    print("\nAttack Assignment Phase")
end)

engine:on(Events.DEFENSE_ASSIGN_PHASE, function(_)
    print("\nDefense Assignment Phase")
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
    local actor_name = data.attacker and data.attacker.name or "Unknown"
    local result = data.result or {}
    local rolls = {}
    for _, value in ipairs(result.rolls or {}) do
        table.insert(rolls, tostring(value))
    end

    local roll_string = #rolls > 0 and table.concat(rolls, ", ") or ""
    local dice_label = result.count and result.type and (result.count .. result.type) or (result.type or "dice")
    local modified_total = data.modified_total or result.total or 0

    if data.defense then
        local body_part_name = data.body_part and data.body_part.name or "target"
        print(string.format("%s defends %s with %s [%s] -> total %d", actor_name, body_part_name, dice_label, roll_string, result.total or 0))
    else
        if modified_total ~= (result.total or 0) then
            print(string.format("%s rolls %s [%s] -> total %d (modified to %d)", actor_name, dice_label, roll_string, result.total or 0, modified_total))
        else
            print(string.format("%s rolls %s [%s] -> total %d", actor_name, dice_label, roll_string, modified_total))
        end
    end
end)

engine:on(Events.CREST_GAINED, function(data)
    local combatant_name = data.combatant and data.combatant.name or "Unknown"
    local crest = data.crest or "?"
    local amount = data.amount or 0
    local total = data.total or amount
    print(string.format("%s gains %d %s crest(s). Total: %d", combatant_name, amount, crest, total))
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
    local valor_surge = {
        id = "valor_surge",
        name = "Valor Surge",
        actions = {
            { type = "gain_crest", crest = "Valor", amount = 1, name = "Rallying Cry" },
            { type = "attack_roll", dice_count = 2, dice_type = "d6", name = "Blade Sweep" },
            { type = "defense_roll", dice_count = 1, dice_type = "d4", name = "Guarded Stance" }
        }
    }

    local crushing_blow = {
        id = "crushing_blow",
        name = "Crushing Blow",
        actions = {
            { type = "attack_roll", dice_count = 1, dice_type = "d8", name = "Heavy Smash" },
            { type = "defense_roll", dice_count = 1, dice_type = "d4", name = "Harden Hide" }
        }
    }

    local player = Combatant:new({ id = "player", name = "Dreamer", is_player = true })
    player:add_body_part({
        id = "player_arm",
        name = "Dreamblade Arm",
        type = "ARM",
        toughness = 2,
        hp_value = 1,
        techs = { valor_surge }
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
            local metadata = engine:get_pending_input_metadata()
            if metadata and metadata.type == "attack_assignment" then
                print(string.format("\n%s is assigning attack (%s) against %s.",
                    metadata.combatant and metadata.combatant.name or "?",
                    metadata.action_label or "attack",
                    metadata.opponent and metadata.opponent.name or "opponent"))
            elseif metadata and metadata.type == "defense_assignment" then
                print(string.format("\n%s is assigning defense (%s).",
                    metadata.combatant and metadata.combatant.name or "?",
                    metadata.action_label or "defense"))
            end

            if metadata and (metadata.type == "attack_assignment" or metadata.type == "defense_assignment") then
                print("Targets:")
                for _, option in ipairs(metadata.options or {}) do
                    local part = option.part
                    local name = part and part.name or option.id or ("Option " .. tostring(option.index))
                    local status = part and part.status or "unknown"
                    local toughness = part and part.toughness or 0
                    print(string.format("%d. %s (Status: %s, Toughness: %d)", option.index, name, status, toughness))
                end
            end

            local input = get_player_input(engine:get_input_prompt())
            engine:provide_input(input)
        end
    end
end

run_test_combat()
