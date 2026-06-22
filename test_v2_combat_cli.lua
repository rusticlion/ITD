local Engine = require("combat.v2_engine")
local Events = require("combat.events")
local Symbols = require("core.symbols")
local Demo = require("combat.v2_demo")
local V2AI = require("combat.v2_ai")

math.randomseed(20260615)

local function assert_true(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

local function die_for(engine, combatant, part_id)
    for _, die in ipairs(engine:get_pool(combatant)) do
        if die.source_part and die.source_part.id == part_id then
            return die
        end
    end

    return nil
end

local function log_events(engine)
    engine:on(Events.ROUND_START, function(data)
        print("\n== Round " .. tostring(data.round) .. " ==")
    end)

    engine:on(Events.DICE_ROLLED, function(data)
        print(string.format("%s rolls %s from %s",
            data.combatant.name,
            data.formatted,
            data.source_part.name))
    end)

    engine:on(Events.DIE_ASSIGNED, function(data)
        local target = data.part and data.part.name or "?"
        local burned = #data.burned_symbols > 0 and (" burn " .. Symbols.format_face(data.burned_symbols)) or ""
        print(string.format("%s assigns %s to %s %s.%s",
            data.combatant.name,
            Symbols.format_face(data.die.effective_symbols or data.die.symbols),
            data.destination,
            target,
            burned))
    end)

    engine:on(Events.SLOT_FED, function(data)
        print(string.format("%s feeds %s into %s (%s)",
            data.combatant.name,
            Symbols.format_face(data.die.effective_symbols or data.die.symbols),
            data.slot.name,
            data.filled and "filled" or "charging"))
    end)

    engine:on(Events.SLOT_RESOLVED, function(data)
        local target = data.effect and data.effect.target_part
        local target_text = target and (" -> " .. target.name) or ""
        print(string.format("%s resolves %s%s",
            data.combatant.name,
            data.slot.name,
            target_text))
    end)

    engine:on(Events.DAMAGE_DEALT, function(data)
        print(string.format("%s: %s -> %s",
            data.body_part.name,
            data.status_before,
            data.status_after))
    end)
end

local function start_engine()
    local player, enemy = Demo.create_combatants()
    local engine = Engine:new()
    log_events(engine)
    engine:add_combatant(player)
    engine:add_combatant(enemy)
    engine:start_combat()
    return engine, player, enemy
end

local function run()
    local content_errors = Demo.validate()
    assert_true(#content_errors == 0, table.concat(content_errors, "\n"))

    local engine, player, enemy = start_engine()
    assert_true(#player.body_parts == 6, "baseline Dreamer should have six body parts")
    assert_true(#enemy.body_parts == 4, "Bone Demon should have four body parts")
    assert_true(enemy.ai_personality == "doom_caster", "Bone Demon should use the doom caster AI personality")

    local head = player:get_body_part_by_id("dreamer_head")
    local skull = enemy:get_body_part_by_id("bone_demon_skull")
    local head_die = die_for(engine, player, "dreamer_head")
    local leg_die = die_for(engine, player, "dreamer_right_leg")

    head_die.symbols = { Symbols.ESSENCE }
    leg_die.symbols = { Symbols.BLANK }

    local ok, reason = engine:feed_die_to_slot(player, head_die.id, head)
    assert_true(ok, "Moment of Valor should accept Essence: " .. tostring(reason))

    ok, reason = engine:assign_die_to_rim(player, leg_die.id, skull)
    assert_true(ok, "Moment of Valor should make the next blank die rim-valid: " .. tostring(reason))
    assert_true(Symbols.count(engine.assignments.rims[skull].symbols, Symbols.STRIKE) == 1,
        "Moment of Valor should add exactly one Strike")

    local engine2, player2, enemy2 = start_engine()
    local skull2 = enemy2:get_body_part_by_id("bone_demon_skull")
    local player_head2 = player2:get_body_part_by_id("dreamer_head")

    for _, part_id in ipairs({
        "bone_demon_skull",
        "bone_demon_rib_cage",
        "bone_demon_right_claw",
        "bone_demon_left_claw"
    }) do
        local die = die_for(engine2, enemy2, part_id)
        die.symbols = { Symbols.ESSENCE }
    end

    local ai_move = V2AI.choose_next_allocation(engine2, enemy2)
    assert_true(ai_move and ai_move.kind == "slot" and ai_move.part == skull2,
        "doom_caster AI should prioritize charging Speak Doom")

    for _, part_id in ipairs({
        "bone_demon_skull",
        "bone_demon_rib_cage",
        "bone_demon_right_claw",
        "bone_demon_left_claw"
    }) do
        local die = die_for(engine2, enemy2, part_id)
        ok, reason = engine2:feed_die_to_slot(enemy2, die.id, skull2)
        assert_true(ok, "Bone Demon should feed Speak Doom with Essence: " .. tostring(reason))
    end

    assert_true(player_head2.status == "wounded", "Speak Doom should wound the Dreamer's Head")

    local engine3, player3, enemy3 = start_engine()
    local skull3 = enemy3:get_body_part_by_id("bone_demon_skull")
    local player_head3 = player3:get_body_part_by_id("dreamer_head")
    player_head3.status = "wounded"

    for _, part_id in ipairs({
        "bone_demon_skull",
        "bone_demon_rib_cage",
        "bone_demon_right_claw",
        "bone_demon_left_claw"
    }) do
        local die = die_for(engine3, enemy3, part_id)
        die.symbols = { Symbols.ESSENCE }
        ok, reason = engine3:feed_die_to_slot(enemy3, die.id, skull3)
        assert_true(ok, "Speak Doom should be able to charge for a finishing cast: " .. tostring(reason))
    end

    assert_true(player_head3.status == "maimed", "Speak Doom should maim an already wounded Head")
    assert_true(player3.heart_points == 0, "Maiming the Dreamer's Head should deplete baseline Hearts")
    assert_true(engine3.state == "COMPLETE", "A slot-caused defeat should complete combat immediately")
    assert_true(engine3.winner == enemy3, "Bone Demon should win after a lethal Speak Doom")

    local engine4, player4, enemy4 = start_engine()
    local channel_head = player4:get_body_part_by_id("dreamer_head")
    local channel_target = enemy4:get_body_part_by_id("bone_demon_skull")
    channel_head.slot = {
        id = "spellblade",
        name = "Spellblade",
        cost = { Symbols.ESSENCE },
        timing = "spend",
        effect = {
            actions = {
                {
                    type = "add_symbol_to_matching_dice",
                    match = Symbols.ESSENCE,
                    symbol = Symbols.STRIKE,
                    amount = 1,
                    destination = "rim"
                },
                {
                    type = "add_next_symbol",
                    symbol = Symbols.WARD,
                    amount = 1
                }
            }
        }
    }

    local channel_feed = die_for(engine4, player4, "dreamer_head")
    local channel_die = die_for(engine4, player4, "dreamer_body")
    channel_feed.symbols = { Symbols.ESSENCE }
    channel_die.symbols = { Symbols.ESSENCE }

    ok, reason = engine4:feed_die_to_slot(player4, channel_feed.id, channel_head)
    assert_true(ok, "Spellblade should accept Essence: " .. tostring(reason))

    ok, reason = engine4:assign_die_to_rim(player4, channel_die.id, channel_target)
    assert_true(ok, "Spellblade should make an Essence die rim-valid: " .. tostring(reason))
    assert_true(Symbols.count(engine4.assignments.rims[channel_target].symbols, Symbols.STRIKE) == 1,
        "Spellblade should add Strike to Essence dice on rims")
    assert_true(Symbols.count(engine4.assignments.rims[channel_target].added_symbols, Symbols.WARD) == 1,
        "Composed effects should still apply add-next-symbol actions")

    local engine5, player5 = start_engine()
    local field_head = player5:get_body_part_by_id("dreamer_head")
    field_head.slot = {
        id = "force_field",
        name = "Force Field",
        cost = { Symbols.ESSENCE },
        timing = "spend",
        effect = {
            type = "assign_symbol_to_each_part",
            destination = "socket",
            target = "self",
            symbol = Symbols.WARD,
            amount = 1
        }
    }

    local field_feed = die_for(engine5, player5, "dreamer_head")
    field_feed.symbols = { Symbols.ESSENCE }

    ok, reason = engine5:feed_die_to_slot(player5, field_feed.id, field_head)
    assert_true(ok, "Force Field should accept Essence: " .. tostring(reason))

    local socket_count = 0
    for _, part in ipairs(player5.body_parts) do
        local assignment = engine5.assignments.sockets[part]
        assert_true(assignment ~= nil, "Force Field should defend " .. tostring(part.name))
        assert_true(assignment.virtual == true, "Force Field assignments should be marked virtual")
        assert_true(Symbols.count(assignment.symbols, Symbols.WARD) == 1,
            "Force Field should assign exactly one Ward")
        socket_count = socket_count + 1
    end
    assert_true(socket_count == #player5.body_parts, "Force Field should cover every unmaimed player part")

    local engine6, player6, enemy6 = start_engine()
    local mark_head = player6:get_body_part_by_id("dreamer_head")
    local marked_skull = enemy6:get_body_part_by_id("bone_demon_skull")
    local unmarked_rib = enemy6:get_body_part_by_id("bone_demon_rib_cage")
    mark_head.slot = {
        id = "hexing_gaze",
        name = "Hexing Gaze",
        cost = { Symbols.ESSENCE },
        timing = "spend",
        effect = {
            type = "open_spellmark",
            destination = "rim",
            symbol = Symbols.ESSENCE,
            on_mark = {
                type = "damage_marked_part",
                amount = 1
            }
        }
    }

    local mark_feed = die_for(engine6, player6, "dreamer_head")
    local mark_die = die_for(engine6, player6, "dreamer_body")
    local after_mark_die = die_for(engine6, player6, "dreamer_right_arm")
    mark_feed.symbols = { Symbols.ESSENCE }
    mark_die.symbols = { Symbols.ESSENCE }
    after_mark_die.symbols = { Symbols.ESSENCE }

    ok, reason = engine6:assign_die_to_rim(player6, mark_die.id, marked_skull)
    assert_true(not ok and reason == "no_strike", "Essence should not target a rim before a spellmark")

    ok, reason = engine6:feed_die_to_slot(player6, mark_feed.id, mark_head)
    assert_true(ok, "Hexing Gaze should accept Essence: " .. tostring(reason))

    ok, reason = engine6:assign_die_to_rim(player6, mark_die.id, marked_skull)
    assert_true(ok, "Spellmark should let an Essence die assign to an enemy rim: " .. tostring(reason))
    assert_true(engine6.assignments.rims[marked_skull].spellmark ~= nil,
        "Spellmark assignment should retain spellmark metadata")
    assert_true(Symbols.count(engine6.assignments.rims[marked_skull].used_symbols, Symbols.ESSENCE) == 1,
        "Spellmark assignment should use Essence rather than burn it")
    assert_true(Symbols.count(engine6.assignments.rims[marked_skull].symbols, Symbols.STRIKE) == 0,
        "Essence-only spellmark assignment should not add direct Strike pressure")
    assert_true(marked_skull.status == "wounded", "Spellmark payload should damage the marked part")

    ok, reason = engine6:assign_die_to_rim(player6, after_mark_die.id, unmarked_rib)
    assert_true(not ok and reason == "no_strike", "Single-use spellmark should not leave all rims Essence-valid")

    local engine7, player7, enemy7 = start_engine()
    local armored_skull = enemy7:get_body_part_by_id("bone_demon_skull")
    local light_strike_die = die_for(engine7, player7, "dreamer_right_leg")
    local heavy_strike_die = die_for(engine7, player7, "dreamer_right_arm")
    armored_skull.keywords = { "Armored" }
    light_strike_die.symbols = { Symbols.STRIKE }
    heavy_strike_die.symbols = { Symbols.STRIKE, Symbols.STRIKE }

    ok, reason = engine7:assign_die_to_rim(player7, light_strike_die.id, armored_skull)
    assert_true(not ok and reason == "armored_requires_two_strikes",
        "Armored rims should reject one-Strike dice: " .. tostring(reason))

    ok, reason = engine7:assign_die_to_rim(player7, heavy_strike_die.id, armored_skull)
    assert_true(ok, "Armored rims should accept dice showing two Strikes: " .. tostring(reason))

    local engine8, player8, enemy8 = start_engine()
    local brittle_rib = enemy8:get_body_part_by_id("bone_demon_rib_cage")
    local brittle_attack = die_for(engine8, player8, "dreamer_right_leg")
    brittle_rib.keywords = { "Brittle" }
    brittle_attack.symbols = { Symbols.STRIKE }

    ok, reason = engine8:assign_die_to_rim(player8, brittle_attack.id, brittle_rib)
    assert_true(ok, "Brittle test should assign a simple attack: " .. tostring(reason))
    engine8:resolve_round()
    assert_true(brittle_rib.status == "maimed", "Brittle parts should maim from any damage")
    assert_true(enemy8.heart_points == 2, "Brittle maim should still apply normal Heart loss")

    local engine9, player9 = start_engine()
    local hungry_head = player9:get_body_part_by_id("dreamer_head")
    local hungry_feed = die_for(engine9, player9, "dreamer_head")
    hungry_head.slot = {
        id = "hungry_test",
        name = "Hungry Test",
        cost = { Symbols.ESSENCE, Symbols.ESSENCE, Symbols.ESSENCE },
        hungry = true,
        timing = "upkeep",
        effect = { type = "none" }
    }
    hungry_feed.symbols = { Symbols.STRIKE, Symbols.WARD }

    ok, reason = engine9:feed_die_to_slot(player9, hungry_feed.id, hungry_head)
    assert_true(ok, "Hungry slots should accept any nonblank symbols: " .. tostring(reason))
    assert_true(hungry_head.slot_charge[1] == true and hungry_head.slot_charge[2] == true and not hungry_head.slot_charge[3],
        "Hungry slots should light one wildcard pip per ingested symbol")

    local engine10, player10, enemy10 = start_engine()
    local absorbent_body = player10:get_body_part_by_id("dreamer_body")
    local absorbent_defense = die_for(engine10, player10, "dreamer_body")
    local absorbent_attack = die_for(engine10, enemy10, "bone_demon_right_claw")
    absorbent_body.keywords = { "Absorbent" }
    absorbent_body.slot = {
        id = "absorbent_test",
        name = "Absorbent Test",
        cost = { Symbols.WARD, Symbols.WARD },
        timing = "upkeep",
        effect = { type = "none" }
    }
    absorbent_defense.symbols = { Symbols.WARD }
    absorbent_attack.symbols = { Symbols.STRIKE }

    ok, reason = engine10:assign_die_to_rim(enemy10, absorbent_attack.id, absorbent_body)
    assert_true(ok, "Absorbent test should assign an incoming attack: " .. tostring(reason))
    ok, reason = engine10:assign_die_to_socket(player10, absorbent_defense.id, absorbent_body)
    assert_true(ok, "Absorbent test should assign socket defense: " .. tostring(reason))
    engine10:resolve_round()
    assert_true(absorbent_body.status == "healthy", "Absorbent should only fire after a no-damage defense")
    assert_true(absorbent_body.slot_charge[1] == true and not absorbent_body.slot_charge[2],
        "Absorbent should feed the socket die into its Slot")
    assert_true(engine10.assignments.sockets[absorbent_body] == nil,
        "Absorbent should move the socket die out of the socket assignment")

    print("\nV2 combat smoke test passed.")
end

run()
