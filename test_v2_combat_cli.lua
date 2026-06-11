local Engine = require("combat.v2_engine")
local Events = require("combat.events")
local Symbols = require("core.symbols")
local Demo = require("combat.v2_demo")

math.randomseed(20260611)

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

    engine:on(Events.CREST_EXPENDED, function(data)
        print(string.format("%s expends %s (remaining %d)",
            data.combatant.name,
            data.crest,
            data.remaining or 0))
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
        print(string.format("%s resolves %s",
            data.combatant.name,
            data.slot.name))
    end)

    engine:on(Events.LATCH_EJECTED, function(data)
        print(string.format("Latch on %s is ejected by %s",
            data.part.name,
            data.source and data.source.type or "effect"))
    end)

    engine:on(Events.PART_RESOLVED, function(data)
        print(string.format("%s resolves ATK %d vs DEF %d -> %s",
            data.part.name,
            data.strike_count,
            data.ward_count,
            data.hit and "hit" or "block"))
    end)

    engine:on(Events.DAMAGE_DEALT, function(data)
        print(string.format("%s: %s -> %s",
            data.body_part.name,
            data.status_before,
            data.status_after))
    end)
end

local function run()
    local content_errors = Demo.validate()
    assert_true(#content_errors == 0, table.concat(content_errors, "\n"))

    local player, enemy = Demo.create_combatants()
    local engine = Engine:new()

    log_events(engine)
    engine:add_combatant(player)
    engine:add_combatant(enemy)
    engine:start_combat()

    local enemy_claw = die_for(engine, enemy, "enemy_claw")
    local player_scholar = player:get_body_part_by_id("player_scholar")
    local ok, reason = engine:assign_die_to_rim(enemy, enemy_claw.id, player_scholar)
    assert_true(ok, "enemy claw should latch onto scholar: " .. tostring(reason))

    ok, reason = engine:expend_crest(player, "Shadow")
    assert_true(ok, "Shadow should expend: " .. tostring(reason))

    local scholar_die = die_for(engine, player, "player_scholar")
    ok, reason = engine:feed_die_to_slot(player, scholar_die.id, player_scholar)
    assert_true(ok, "Scholar die should feed Insight: " .. tostring(reason))
    assert_true(engine.assignments.rims[player_scholar] == nil, "Shadow slot trigger should eject the existing latch")
    assert_true(player:get_crest_count("Valor") == 2, "Insight should grant a Valor crest")

    ok, reason = engine:expend_crest(player, "Valor")
    assert_true(ok, "Valor should expend: " .. tostring(reason))

    local cleaver_die = die_for(engine, player, "player_cleaver")
    local enemy_head = enemy:get_body_part_by_id("enemy_head")
    ok, reason = engine:assign_die_to_rim(player, cleaver_die.id, enemy_head)
    assert_true(ok, "Cleaver should attack enemy head: " .. tostring(reason))
    assert_true(Symbols.count(engine.assignments.rims[enemy_head].symbols, Symbols.STRIKE) == 3, "Valor should add one strike to the cleaver die")

    local mixed_die = die_for(engine, player, "player_mixed")
    ok, reason = engine:assign_die_to_rim(player, mixed_die.id, enemy_head)
    assert_true(not ok and reason == "rim_full", "rim capacity should reject a second die")

    local enemy_body = enemy:get_body_part_by_id("enemy_body")
    ok, reason = engine:assign_die_to_rim(player, mixed_die.id, enemy_body)
    assert_true(ok, "Mixed die should be rim-valid because it shows strike: " .. tostring(reason))
    assert_true(#engine.assignments.rims[enemy_body].burned_symbols == 1, "Mixed die should burn its ward on a rim")

    local head_die = die_for(engine, player, "player_head")
    ok, reason = engine:assign_die_to_socket(player, head_die.id, player:get_body_part_by_id("player_head"))
    assert_true(ok, "Head die should defend own head: " .. tostring(reason))

    engine:resolve_round()

    assert_true(enemy_head.status == "wounded", "Enemy head should be wounded")
    assert_true(enemy_body.status == "wounded", "Enemy body should be wounded")
    assert_true(player_scholar.status == "healthy", "Ejected latch should prevent scholar damage")

    engine:start_round()
    local wounded_head_die = die_for(engine, enemy, "enemy_head")
    assert_true(Symbols.has(wounded_head_die.symbols, Symbols.BLOOD), "Wounded head die should roll blood through degradation")
    assert_true(not engine:is_part_untargetable(player_scholar), "Shadow untargetable should clear on upkeep")

    print("\nV2 combat smoke test passed.")
end

run()
