local AI = require("combat.v2_ai")
local Content = require("combat.v2_content")
local Crests = require("combat.crests")
local Effects = require("combat.v2_effects")
local Encounters = require("combat.v2_encounters")
local Engine = require("combat.v2_engine")
local Keywords = require("combat.keywords")

math.randomseed(20260707)

local function assert_true(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

local function deterministic_roller(seed)
    local state = seed
    return function(minimum, maximum)
        state = (state * 48271) % 2147483647
        return minimum + (state % (maximum - minimum + 1))
    end
end

local function build_encounter(seed)
    local player, enemy = Encounters.create_combatants({ encounter_id = "basement.whisperer" })
    local engine = Engine:new({ rng = deterministic_roller(seed or 4401) })
    engine:add_combatant(player)
    engine:add_combatant(enemy)
    return engine, player, enemy
end

-- Content validation and keyword wiring.
local errors = Content.validate(require("data.combat.alpha_basement"))
assert_true(#errors == 0, "alpha_basement validates: " .. table.concat(errors, "; "))
assert_true(#Encounters.validate() == 0, "encounter registry validates")

local engine, player, enemy = build_encounter()
assert_true(enemy.name == "The Whisperer", "whisperer loadout resolves")
assert_true(#enemy.body_parts == 4, "the wall-thing has four parts")

local face = enemy:get_body_part_by_id("whisperer_mouthless_face")
local husk = enemy:get_body_part_by_id("whisperer_plaster_husk")
local scratcher = enemy:get_body_part_by_id("whisperer_scratcher")
local legs = enemy:get_body_part_by_id("whisperer_skitter_legs")
assert_true(Keywords.has(face, "Armored"), "face is Armored")
assert_true(Keywords.has(husk, "Absorbent"), "husk is Absorbent")
assert_true(Keywords.slot_is_hungry(husk), "Feed the Walls is Hungry")
assert_true(Keywords.has(scratcher, "Brittle"), "scratcher is Brittle")
assert_true(legs.slot and legs.slot.id == "reknit_plaster", "legs carry Reknit Plaster")

-- gain_crest opponent targeting: the Whisper lands Madness on the player.
local describe = Effects.describe({ type = "gain_crest", target = "opponent", crest = "Madness" })
assert_true(describe == "Opponent gains 1 Madness crest.", "opponent gain describes correctly: " .. describe)

local result = Effects.execute(engine, { combatant = enemy, slot = face.slot }, {
    type = "gain_crest",
    target = "opponent",
    crest = "Madness",
    amount = 1
})
assert_true(result.recipient == player, "opponent-targeted crest lands on the player")
assert_true(player:get_crest_count("Madness") == 1, "player holds 1 Madness")

-- Seizure threshold.
assert_true(not Crests.is_seized(player), "1 Madness does not seize")
player:add_crest("Madness", 2)
assert_true(Crests.is_seized(player), "3 Madness seizes")

-- Brittle: any damage maims the scratcher outright.
engine:apply_damage(player, enemy, scratcher, { hit = true })
assert_true(scratcher.status == "maimed", "Brittle scratcher maims on first damage")
assert_true(enemy.heart_points == 2, "scratcher maim costs one heart")

-- The pinch: expending Madness wounds a random Healthy part and purges one.
local healthy_before = 0
for _, part in ipairs(player.body_parts) do
    if part.status == "healthy" then
        healthy_before = healthy_before + 1
    end
end

local ok = engine:expend_crest(player, "Madness")
assert_true(ok, "Madness expend succeeds with healthy parts")
assert_true(player:get_crest_count("Madness") == 2, "pinch purges exactly one Madness")

local healthy_after = 0
for _, part in ipairs(player.body_parts) do
    if part.status == "healthy" then
        healthy_after = healthy_after + 1
    end
end
assert_true(healthy_after == healthy_before - 1, "pinch wounds exactly one healthy part")

-- No healthy part, no pinch: you cannot wake what is already broken.
for _, part in ipairs(player.body_parts) do
    if part.status == "healthy" then
        part:set_status("wounded")
    end
end
local blocked, reason = engine:expend_crest(player, "Madness")
assert_true(blocked == false and reason == "no_healthy_part", "pinch refused without a healthy part")
assert_true(player:get_crest_count("Madness") == 2, "refused pinch does not consume the crest")

-- Random allocation returns committable moves (the whispers move the hand).
local engine2, player2 = build_encounter(4402)
engine2:start_combat()
local move = AI.random_allocation(engine2, player2)
assert_true(move ~= nil, "random allocation finds a legal move")
assert_true(engine2:commit_allocation_move(player2, move), "random move commits cleanly")

-- Full AI-vs-AI runs complete without errors inside the round cap.
for seed = 1, 10 do
    local sim_engine, sim_player, sim_enemy = build_encounter(9000 + seed * 13)
    sim_engine:start_combat()
    local rounds = 0
    while sim_engine.state ~= "COMPLETE" and rounds < 30 do
        rounds = rounds + 1
        if Crests.is_seized(sim_enemy) then
            local seized = AI.random_allocation(sim_engine, sim_enemy)
            if seized then
                sim_engine:commit_allocation_move(sim_enemy, seized)
            end
        end
        AI.auto_allocate(sim_engine, sim_enemy)
        if Crests.is_seized(sim_player) then
            local seized = AI.random_allocation(sim_engine, sim_player)
            if seized then
                sim_engine:commit_allocation_move(sim_player, seized)
            end
        end
        AI.auto_allocate(sim_engine, sim_player)
        sim_engine:resolve_round()
        if sim_engine.state ~= "COMPLETE" then
            sim_engine:start_round()
        end
    end
    assert_true(sim_engine.state == "COMPLETE", "whisperer fight completes within cap (seed " .. seed .. ")")
end

print("whisperer/madness smoke test passed.")
