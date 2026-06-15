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

    print("\nV2 combat smoke test passed.")
end

run()
