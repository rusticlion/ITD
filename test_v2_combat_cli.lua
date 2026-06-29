local Engine = require("combat.v2_engine")
local Events = require("combat.events")
local Symbols = require("core.symbols")
local Demo = require("combat.v2_demo")
local V2AI = require("combat.v2_ai")
local V2Encounters = require("combat.v2_encounters")
local BPEditor = require("states.bp_editor")

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

local function deterministic_roller(seed)
    local state = seed
    return function(minimum, maximum)
        state = (state * 48271) % 2147483647
        return minimum + (state % (maximum - minimum + 1))
    end
end

local function seeded_faces(seed)
    local player, enemy = V2Encounters.create_combatants({ encounter_id = "basement.mad_butcher" })
    local engine = Engine:new({ rng = deterministic_roller(seed) })
    engine:add_combatant(player)
    engine:add_combatant(enemy)
    engine:start_combat()

    local faces = {}
    for _, combatant in ipairs({ player, enemy }) do
        for _, die in ipairs(engine:get_pool(combatant)) do
            table.insert(faces, die.face_index)
        end
    end
    return table.concat(faces, ",")
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

local function start_encounter(encounter_id)
    local player, enemy = V2Encounters.create_combatants({ encounter_id = encounter_id })
    local engine = Engine:new()
    engine:add_combatant(player)
    engine:add_combatant(enemy)
    engine:start_combat()
    return engine, player, enemy
end

local function arm_reactive_slot(engine, combatant, part, timing, label, observations, other_part)
    part.slot = {
        id = "test_" .. timing .. "_" .. label,
        name = label,
        cost = { Symbols.ESSENCE },
        timing = timing,
        effect = function(_, entry)
            table.insert(observations, {
                label = label,
                part = entry.part,
                status = entry.part.status,
                other_status = other_part and other_part.status,
                trigger_part = entry.trigger_context and entry.trigger_context.part,
                trigger_status = entry.trigger_context and entry.trigger_context.status_after
            })
            return { type = "test_reaction", label = label }
        end
    }
    engine:trigger_slot(combatant, part, part.slot)
end

local function run()
    assert_true(seeded_faces(90210) == seeded_faces(90210),
        "Engine RNG injection should reproduce the same opening rolls")

    local content_errors = Demo.validate()
    assert_true(#content_errors == 0, table.concat(content_errors, "\n"))

    local engine, player, enemy = start_engine()
    assert_true(#player.body_parts == 6, "baseline Dreamer should have six body parts")
    assert_true(#enemy.body_parts == 6, "Bone Demon should have a complete six-part body")
    assert_true(enemy.ai_personality == "bone_caster", "Bone Demon should use the bone caster AI personality")

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
        "bone_demon_right_tentacle",
        "bone_demon_left_tentacle",
        "bone_demon_right_bare_bones"
    }) do
        local die = die_for(engine2, enemy2, part_id)
        die.symbols = { Symbols.ESSENCE }
    end

    local ai_move = V2AI.choose_next_allocation(engine2, enemy2)
    assert_true(ai_move and ai_move.kind == "slot" and ai_move.part == skull2,
        "bone_caster AI should prioritize charging Speak Doom")

    for _, part_id in ipairs({
        "bone_demon_skull",
        "bone_demon_right_tentacle",
        "bone_demon_left_tentacle",
        "bone_demon_right_bare_bones"
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
        "bone_demon_right_tentacle",
        "bone_demon_left_tentacle",
        "bone_demon_right_bare_bones"
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

    local hit_engine, hit_player, hit_enemy = start_engine()
    local hit_right_arm = hit_player:get_body_part_by_id("dreamer_right_arm")
    local hit_left_arm = hit_player:get_body_part_by_id("dreamer_left_arm")
    local hit_observations = {}
    arm_reactive_slot(hit_engine, hit_player, hit_right_arm, "on_hit", "Right Riposte",
        hit_observations, hit_left_arm)
    arm_reactive_slot(hit_engine, hit_player, hit_left_arm, "on_hit", "Left Riposte",
        hit_observations, hit_right_arm)

    local first_hit_die = die_for(hit_engine, hit_enemy, "bone_demon_right_bare_bones")
    local second_hit_die = die_for(hit_engine, hit_enemy, "bone_demon_left_bare_bones")
    first_hit_die.symbols = { Symbols.STRIKE }
    second_hit_die.symbols = { Symbols.STRIKE }
    ok, reason = hit_engine:assign_die_to_rim(hit_enemy, first_hit_die.id, hit_right_arm)
    assert_true(ok, "First On-Hit regression attack should assign: " .. tostring(reason))
    ok, reason = hit_engine:assign_die_to_rim(hit_enemy, second_hit_die.id, hit_left_arm)
    assert_true(ok, "Second On-Hit regression attack should assign: " .. tostring(reason))
    hit_engine:resolve_round()

    assert_true(#hit_observations == 2, "Each struck part should resolve exactly its own On-Hit entry")
    assert_true(hit_observations[1].part == hit_right_arm and hit_observations[1].status == "wounded",
        "First On-Hit entry should resolve after its owning part takes damage")
    assert_true(hit_observations[1].other_status == "healthy",
        "First hit must not drain the second part's On-Hit entry")
    assert_true(hit_observations[1].trigger_part == hit_right_arm
            and hit_observations[1].trigger_status == "wounded",
        "First On-Hit entry should receive its own completed hit context")
    assert_true(hit_observations[2].part == hit_left_arm and hit_observations[2].status == "wounded",
        "Second On-Hit entry should wait for the second part's damage")
    assert_true(hit_observations[2].trigger_part == hit_left_arm,
        "Second On-Hit entry should receive the second part's trigger context")

    local wound_engine, wound_player, wound_enemy = start_engine()
    local wound_right_arm = wound_player:get_body_part_by_id("dreamer_right_arm")
    local wound_left_arm = wound_player:get_body_part_by_id("dreamer_left_arm")
    local wound_observations = {}
    arm_reactive_slot(wound_engine, wound_player, wound_right_arm, "on_wound_maim", "Right Flinch",
        wound_observations, wound_left_arm)
    arm_reactive_slot(wound_engine, wound_player, wound_left_arm, "on_wound_maim", "Left Flinch",
        wound_observations, wound_right_arm)

    local first_wound_die = die_for(wound_engine, wound_enemy, "bone_demon_right_bare_bones")
    local second_wound_die = die_for(wound_engine, wound_enemy, "bone_demon_left_bare_bones")
    first_wound_die.symbols = { Symbols.STRIKE }
    second_wound_die.symbols = { Symbols.STRIKE }
    ok, reason = wound_engine:assign_die_to_rim(wound_enemy, first_wound_die.id, wound_right_arm)
    assert_true(ok, "First On-Wound regression attack should assign: " .. tostring(reason))
    ok, reason = wound_engine:assign_die_to_rim(wound_enemy, second_wound_die.id, wound_left_arm)
    assert_true(ok, "Second On-Wound regression attack should assign: " .. tostring(reason))
    wound_engine:resolve_round()

    assert_true(#wound_observations == 2,
        "Each wounded part should resolve exactly its own On-Wound/Maim entry")
    assert_true(wound_observations[1].part == wound_right_arm
            and wound_observations[1].other_status == "healthy",
        "First wound must not drain the second part's On-Wound/Maim entry")
    assert_true(wound_observations[2].part == wound_left_arm
            and wound_observations[2].trigger_part == wound_left_arm,
        "Second On-Wound/Maim entry should wait for its own status change")

    local caster_engine, _, caster = start_encounter("basement.bone_demon")
    local caster_skull = caster:get_body_part_by_id("bone_demon_skull")
    local caster_ribcage = caster:get_body_part_by_id("bone_demon_rib_cage")
    local caster_faces = {
        bone_demon_skull = { Symbols.ESSENCE },
        bone_demon_rib_cage = { Symbols.STRIKE },
        bone_demon_right_bare_bones = { Symbols.WARD },
        bone_demon_left_bare_bones = { Symbols.WARD },
        bone_demon_right_tentacle = { Symbols.ESSENCE },
        bone_demon_left_tentacle = { Symbols.STRIKE }
    }

    for part_id, symbols in pairs(caster_faces) do
        die_for(caster_engine, caster, part_id).symbols = symbols
    end

    V2AI.auto_allocate(caster_engine, caster)
    assert_true(caster_engine.assignments.sockets[caster_skull] ~= nil,
        "Bone caster should turtle by warding Speak Doom")
    assert_true(caster_engine.assignments.sockets[caster_ribcage] ~= nil,
        "Bone caster should turtle by warding Bonestorm")
    assert_true(caster_skull.slot_charge[1] and caster_skull.slot_charge[2],
        "Bone caster should feed Essence to Speak Doom")
    assert_true(caster_ribcage.slot_charge[1] and caster_ribcage.slot_charge[2],
        "Bone caster should feed Strike to Bonestorm")

    local caster_rim_count = 0
    for _ in pairs(caster_engine.assignments.rims) do
        caster_rim_count = caster_rim_count + 1
    end
    assert_true(caster_rim_count == 0,
        "Bone caster should not use ritual fuel for direct attacks while its Slots can accept it")

    local mixed_engine, _, mixed_caster = start_encounter("bone_demon")
    local mixed_die = die_for(mixed_engine, mixed_caster, "bone_demon_right_tentacle")
    mixed_die.symbols = { Symbols.ESSENCE, Symbols.WARD }
    local mixed_move = V2AI.choose_allocation(mixed_engine, mixed_caster, mixed_die)
    assert_true(mixed_move and mixed_move.kind == "socket"
            and mixed_move.part == mixed_caster:get_body_part_by_id("bone_demon_skull"),
        "Bone caster should use Ward to turtle even when the same die could feed Essence")

    local storm_engine, storm_player, storm_caster = start_encounter("bone_demon")
    local storm_ribcage = storm_caster:get_body_part_by_id("bone_demon_rib_cage")
    for _, part_id in ipairs({
        "bone_demon_rib_cage",
        "bone_demon_right_bare_bones",
        "bone_demon_left_bare_bones",
        "bone_demon_left_tentacle"
    }) do
        local die = die_for(storm_engine, storm_caster, part_id)
        die.symbols = { Symbols.STRIKE }
        ok, reason = storm_engine:feed_die_to_slot(storm_caster, die.id, storm_ribcage)
        assert_true(ok, "Bonestorm should accept Strike: " .. tostring(reason))
    end

    for _, part in ipairs(storm_player.body_parts) do
        local assignment = storm_engine.assignments.rims[part]
        assert_true(assignment and assignment.virtual,
            "Bonestorm should threaten every open player rim")
        assert_true(Symbols.count(assignment.symbols, Symbols.STRIKE) == 1,
            "Bonestorm should assign exactly one Strike to each player part")
    end

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

    local spellmark_resolution = nil
    engine6:on(Events.PART_RESOLVED, function(data)
        if data.part == marked_skull then
            spellmark_resolution = data
        end
    end)
    engine6:resolve_round()
    assert_true(spellmark_resolution and spellmark_resolution.strike_count == 0,
        "Contest tally should read the effective face and count no Strike on an Essence-only spellmark")
    assert_true(marked_skull.status == "wounded",
        "Essence used by a rim spellmark should not deal a second damage step during contest resolution")

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
    local brittle_rib = enemy8:get_body_part_by_id("bone_demon_right_bare_bones")
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
    local absorbent_attack = die_for(engine10, enemy10, "bone_demon_right_bare_bones")
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

    local zombie_engine, _, zombie = start_encounter("basement.zombie")
    assert_true(#zombie.body_parts == 6, "Zombie should have a complete six-part body")

    local brain_pan = zombie:get_body_part_by_id("zombie_brain_pan")
    local rotting_ribcage = zombie:get_body_part_by_id("zombie_rotting_ribcage")
    local dead_right_arm = zombie:get_body_part_by_id("zombie_right_arm")
    assert_true(brain_pan.hp_value == 3, "Brain Pan should be the three-Heart headshot route")
    assert_true(brain_pan.slot and brain_pan.slot.id == "bite", "Brain Pan should threaten Bite instead of Regrowth")
    assert_true(rotting_ribcage.slot and rotting_ribcage.slot.id == "regenerate",
        "Zombie body parts should carry Regrowth")

    rotting_ribcage.status = "wounded"
    dead_right_arm.status = "wounded"
    local regeneration_feed = die_for(zombie_engine, zombie, "zombie_left_arm")
    regeneration_feed.symbols = { Symbols.BLOOD }

    ok, reason = zombie_engine:feed_die_to_slot(zombie, regeneration_feed.id, dead_right_arm)
    assert_true(ok, "Regrowth should accept Blood: " .. tostring(reason))
    assert_true(dead_right_arm.status == "healthy", "Regrowth should heal its slotted Body Part")
    assert_true(rotting_ribcage.status == "wounded", "Regrowth should not redirect healing to another wounded part")

    local bite_engine, bite_player, biting_zombie = start_encounter("zombie")
    local biting_head = biting_zombie:get_body_part_by_id("zombie_brain_pan")
    local first_blood = die_for(bite_engine, biting_zombie, "zombie_brain_pan")
    local second_blood = die_for(bite_engine, biting_zombie, "zombie_rotting_ribcage")
    local bite_attack = die_for(bite_engine, biting_zombie, "zombie_right_arm")
    local bite_target = bite_player:get_body_part_by_id("dreamer_body")
    first_blood.symbols = { Symbols.BLOOD }
    second_blood.symbols = { Symbols.BLOOD }
    bite_attack.symbols = { Symbols.BLANK }

    ok, reason = bite_engine:feed_die_to_slot(biting_zombie, first_blood.id, biting_head)
    assert_true(ok, "Bite should bank its first Blood: " .. tostring(reason))
    ok, reason = bite_engine:feed_die_to_slot(biting_zombie, second_blood.id, biting_head)
    assert_true(ok, "Bite should trigger on its second Blood: " .. tostring(reason))
    ok, reason = bite_engine:assign_die_to_rim(biting_zombie, bite_attack.id, bite_target)
    assert_true(ok, "Bite should make the next blank die rim-valid: " .. tostring(reason))
    assert_true(Symbols.count(bite_engine.assignments.rims[bite_target].symbols, Symbols.STRIKE) == 2,
        "Bite should add exactly two Strikes")

    local zombie_ai_engine, _, zombie_ai = start_encounter("zombie")
    local wounded_leg = zombie_ai:get_body_part_by_id("zombie_right_leg")
    wounded_leg.status = "wounded"
    for _, die in ipairs(zombie_ai_engine:get_pool(zombie_ai)) do
        die.symbols = { Symbols.BLOOD }
    end

    local zombie_move = V2AI.choose_next_allocation(zombie_ai_engine, zombie_ai)
    assert_true(zombie_move and zombie_move.kind == "slot" and zombie_move.part == wounded_leg,
        "Zombie AI should spend Blood to heal a wounded Regrowth part")

    local hard_kill_engine, hard_kill_player, hard_kill_zombie = start_encounter("zombie")
    local preserved_head = hard_kill_zombie:get_body_part_by_id("zombie_brain_pan")
    local hard_kill_body = hard_kill_zombie:get_body_part_by_id("zombie_rotting_ribcage")
    local hard_kill_arm = hard_kill_zombie:get_body_part_by_id("zombie_left_arm")
    hard_kill_engine:apply_damage(hard_kill_player, hard_kill_zombie, hard_kill_body, { source = "test" })
    hard_kill_engine:apply_damage(hard_kill_player, hard_kill_zombie, hard_kill_body, { source = "test" })
    hard_kill_engine:apply_damage(hard_kill_player, hard_kill_zombie, hard_kill_arm, { source = "test" })
    hard_kill_engine:apply_damage(hard_kill_player, hard_kill_zombie, hard_kill_arm, { source = "test" })
    assert_true(hard_kill_zombie.heart_points == 0, "Maiming the body and one limb should defeat the Zombie")
    assert_true(preserved_head.status == "healthy", "The hard kill should preserve the claimable Brain Pan")

    local butcher_engine, butcher_player, butcher = start_encounter("basement.mad_butcher")
    assert_true(#butcher.body_parts == 6, "Mad Butcher should have a complete six-part body")
    assert_true(butcher.ai_personality == "mad_butcher", "Mad Butcher should use his dedicated AI personality")

    local welding_mask = butcher:get_body_part_by_id("butcher_welding_mask")
    local broad_shoulders = butcher:get_body_part_by_id("butcher_broad_shoulders")
    local hook_hand = butcher:get_body_part_by_id("butcher_hook_hand")
    assert_true(welding_mask.hp_value == 3, "Welding Mask should be the three-Heart fast-kill route")
    assert_true(broad_shoulders.hp_value == 1, "Broad Shoulders should cost one Heart rather than ending the fight")
    assert_true(hook_hand.hp_value == 1, "Butcher arms should support the three-part hard-kill route")
    assert_true(butcher:get_body_part_by_id("zombie_right_leg") ~= nil
            and butcher:get_body_part_by_id("zombie_left_leg") ~= nil,
        "Mad Butcher should literally reuse the Zombie's Regrowth legs")
    assert_true(welding_mask.slot and welding_mask.slot.id == "sadism"
            and #welding_mask.slot.cost == 4,
        "Welding Mask should begin with a four-Strike Sadism track")
    assert_true(broad_shoulders.slot and broad_shoulders.slot.id == "stitch_up",
        "Broad Shoulders should carry the Head-repair slot")

    local butcher_definitions = require("data.combat.alpha_basement")
    local editor = setmetatable({}, BPEditor)
    editor.current = editor:part_to_form(
        butcher_definitions.parts.butcher_welding_mask,
        butcher_definitions.slots)
    local editor_sadism = editor:build_slot()
    assert_true(editor_sadism.dynamic_cost
            and editor_sadism.dynamic_cost.type == "opponent_damaged_parts",
        "BP Editor should preserve Sadism's dynamic cost")
    assert_true(editor_sadism.effect.type == "add_symbol_against_status"
            and editor_sadism.effect.target_status == "wounded",
        "BP Editor should round-trip Sadism's status-conditioned effect")

    editor.current = editor:part_to_form(
        butcher_definitions.parts.butcher_broad_shoulders,
        butcher_definitions.slots)
    local editor_stitch_up = editor:build_slot()
    assert_true(editor_stitch_up.effect.target == "part_type"
            and editor_stitch_up.effect.target_type == "HEAD",
        "BP Editor should round-trip Stitch Up's targeted Head healing")

    local wounded_player_arm = butcher_player:get_body_part_by_id("dreamer_right_arm")
    local maimed_player_leg = butcher_player:get_body_part_by_id("dreamer_left_leg")
    wounded_player_arm.status = "wounded"
    maimed_player_leg.status = "maimed"
    welding_mask.slot_charge[1] = true
    welding_mask.slot_charge[2] = true

    local cost_change = nil
    local sadism_resolved = false
    butcher_engine:on(Events.SLOT_COST_CHANGED, function(data)
        if data.part == welding_mask then
            cost_change = data
        end
    end)
    butcher_engine:on(Events.SLOT_RESOLVED, function(data)
        if data.part == welding_mask then
            sadism_resolved = true
        end
    end)

    butcher_engine:start_round()
    assert_true(cost_change and cost_change.current_length == 2,
        "Two damaged opposing parts should contract Sadism from four pips to two")
    assert_true(sadism_resolved, "Contracting Sadism into its banked charge should trigger it at Upkeep")
    assert_true(next(welding_mask.slot_charge) == nil, "Triggered Sadism should clear its banked charge")

    local sadism_die = die_for(butcher_engine, butcher, "butcher_hook_hand")
    local healthy_player_body = butcher_player:get_body_part_by_id("dreamer_body")
    sadism_die.symbols = { Symbols.STRIKE }
    local wounded_symbols = butcher_engine:get_effective_symbols(
        butcher, sadism_die, "rim", wounded_player_arm)
    local healthy_symbols = butcher_engine:get_effective_symbols(
        butcher, sadism_die, "rim", healthy_player_body)
    assert_true(Symbols.count(wounded_symbols, Symbols.STRIKE) == 2,
        "Sadism should add one Strike against a Wounded opposing Body Part")
    assert_true(Symbols.count(healthy_symbols, Symbols.STRIKE) == 1,
        "Sadism should not add Strike against a Healthy opposing Body Part")

    wounded_player_arm.status = "healthy"
    maimed_player_leg.status = "healthy"
    butcher_engine:start_round()
    assert_true(#welding_mask.slot.cost == 4, "Sadism should expand back to its authored cost when wounds are gone")
    local expired_symbols = butcher_engine:get_effective_symbols(
        butcher, die_for(butcher_engine, butcher, "butcher_hook_hand"), "rim", healthy_player_body)
    assert_true(#expired_symbols >= 1,
        "Starting the next round should roll a usable Hook Hand die after clearing Sadism")
    assert_true(#butcher:get_allocation_symbol_modifiers() == 0,
        "The previous round's Sadism modifier should clear before recomputing its cost")

    local repair_engine, _, repair_butcher = start_encounter("butcher")
    local repair_head = repair_butcher:get_body_part_by_id("butcher_welding_mask")
    local repair_body = repair_butcher:get_body_part_by_id("butcher_broad_shoulders")
    repair_head.status = "wounded"
    repair_body.status = "wounded"
    local first_repair_blood = die_for(repair_engine, repair_butcher, "zombie_right_leg")
    local second_repair_blood = die_for(repair_engine, repair_butcher, "zombie_left_leg")
    first_repair_blood.symbols = { Symbols.BLOOD }
    second_repair_blood.symbols = { Symbols.BLOOD }

    ok, reason = repair_engine:feed_die_to_slot(repair_butcher, first_repair_blood.id, repair_body)
    assert_true(ok, "Stitch Up should bank its first Blood: " .. tostring(reason))
    ok, reason = repair_engine:feed_die_to_slot(repair_butcher, second_repair_blood.id, repair_body)
    assert_true(ok, "Stitch Up should trigger on its second Blood: " .. tostring(reason))
    assert_true(repair_head.status == "healthy", "Stitch Up should repair the allied Head")
    assert_true(repair_body.status == "wounded", "Stitch Up should never heal its own Body")

    local repair_ai_engine, _, repair_ai_butcher = start_encounter("butcher")
    local repair_ai_head = repair_ai_butcher:get_body_part_by_id("butcher_welding_mask")
    local repair_ai_body = repair_ai_butcher:get_body_part_by_id("butcher_broad_shoulders")
    repair_ai_head.status = "wounded"
    for _, die in ipairs(repair_ai_engine:get_pool(repair_ai_butcher)) do
        die.symbols = { Symbols.STRIKE, Symbols.STRIKE, Symbols.STRIKE }
    end
    die_for(repair_ai_engine, repair_ai_butcher, "zombie_right_leg").symbols = { Symbols.BLOOD }
    local repair_move = V2AI.choose_next_allocation(repair_ai_engine, repair_ai_butcher)
    assert_true(repair_move and repair_move.kind == "slot" and repair_move.part == repair_ai_body,
        "Mad Butcher AI should prioritize repairing a Wounded Head")

    local restraint_engine, restraint_player, restraint_butcher = start_encounter("butcher")
    local restraint_head = restraint_butcher:get_body_part_by_id("butcher_welding_mask")
    restraint_head.slot_charge[1] = true
    restraint_head.slot_charge[2] = true
    restraint_head.slot_charge[3] = true
    for _, die in ipairs(restraint_engine:get_pool(restraint_butcher)) do
        die.symbols = { Symbols.BLANK }
    end
    die_for(restraint_engine, restraint_butcher, "butcher_hook_hand").symbols = { Symbols.STRIKE }
    local restraint_move = V2AI.choose_next_allocation(restraint_engine, restraint_butcher)
    assert_true(restraint_move and restraint_move.kind == "rim" and restraint_move.part ~= restraint_head,
        "Mad Butcher AI should not complete Sadism while no opposing Body Part is Wounded")

    local pressure_target = restraint_player:get_body_part_by_id("dreamer_right_arm")
    pressure_target.status = "wounded"
    restraint_head.slot_charge = {}
    for _, die in ipairs(restraint_engine:get_pool(restraint_butcher)) do
        die.symbols = { Symbols.BLANK }
    end
    die_for(restraint_engine, restraint_butcher, "butcher_hook_hand").symbols = {
        Symbols.STRIKE,
        Symbols.STRIKE,
        Symbols.STRIKE
    }
    local pressure_move = V2AI.choose_next_allocation(restraint_engine, restraint_butcher)
    assert_true(pressure_move and pressure_move.kind == "rim" and pressure_move.part == pressure_target,
        "Mad Butcher AI should use concentrated Arm Strikes to finish Wounded parts")

    print("\nV2 combat smoke test passed.")
end

run()
