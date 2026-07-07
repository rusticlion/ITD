-- AI-vs-AI batch combat simulator. Answers the CombatDesign §10 pacing
-- questions with data: round counts, win rates, heart margins, which enemy
-- parts survive as claimable prizes, and which slots actually fire.
--
-- Run from the repo root:
--   lua tools/simulate_combat.lua                          # all basement.* encounters
--   lua tools/simulate_combat.lua basement.whisperer       # one encounter
--   lua tools/simulate_combat.lua basement.zombie --runs=500 --seed=99
--   lua tools/simulate_combat.lua --player=aggressive
--
-- The player side is driven by an AI profile (default "balanced"), so treat
-- absolute win rates as a floor: humans allocate with full enemy visibility
-- and play better than the scorer. Madness seizures are simulated; crest
-- expends (including the pinch) are not, since the AI has no expend policy yet.

local AI = require("combat.v2_ai")
local Crests = require("combat.crests")
local Encounters = require("combat.v2_encounters")
local Engine = require("combat.v2_engine")
local Events = require("combat.events")

local ROUND_CAP = 30

local function seeded_roller(seed)
    local state = seed % 2147483647
    if state <= 0 then
        state = state + 2147483646
    end
    return function(minimum, maximum)
        state = (state * 48271) % 2147483647
        return minimum + (state % (maximum - minimum + 1))
    end
end

local function parse_args(argv)
    local options = {
        encounters = {},
        runs = 200,
        seed = 20260706,
        player = nil
    }

    for _, value in ipairs(argv or {}) do
        local runs = value:match("^%-%-runs=(%d+)$")
        local seed = value:match("^%-%-seed=(%d+)$")
        local player = value:match("^%-%-player=(.+)$")
        if runs then
            options.runs = tonumber(runs)
        elseif seed then
            options.seed = tonumber(seed)
        elseif player then
            options.player = player
        elseif value:sub(1, 2) ~= "--" then
            table.insert(options.encounters, value)
        else
            error("Unknown option: " .. value)
        end
    end

    if #options.encounters == 0 then
        local registry = require("data.combat.encounters")
        for id in pairs(registry) do
            if id:sub(1, 9) == "basement." then
                table.insert(options.encounters, id)
            end
        end
        table.sort(options.encounters)
    end

    return options
end

local function commit_seizure_move(engine, combatant)
    if not Crests.is_seized(combatant) then
        return
    end

    local move = AI.random_allocation(engine, combatant)
    if move then
        engine:commit_allocation_move(combatant, move)
    end
end

local function run_once(encounter_id, seed, player_profile)
    local context = { encounter_id = encounter_id }
    local player, enemy = Encounters.create_combatants(context)
    if player_profile then
        player.ai_personality = player_profile
    end

    local engine = Engine:new({ rng = seeded_roller(seed) })
    engine:add_combatant(player)
    engine:add_combatant(enemy)

    local stats = {
        slot_fires = {},
        player_damage_taken = 0
    }

    engine:on(Events.SLOT_RESOLVED, function(data)
        local name = data.slot and (data.slot.id or data.slot.name) or "?"
        stats.slot_fires[name] = (stats.slot_fires[name] or 0) + 1
    end)

    engine:on(Events.DAMAGE_DEALT, function(data)
        if data.target == player then
            stats.player_damage_taken = stats.player_damage_taken + 1
        end
    end)

    engine:start_combat()

    local rounds = 0
    while engine.state ~= "COMPLETE" and rounds < ROUND_CAP do
        rounds = rounds + 1
        -- Player initiative: enemy allocates first, then the player responds.
        commit_seizure_move(engine, enemy)
        AI.auto_allocate(engine, enemy)
        commit_seizure_move(engine, player)
        AI.auto_allocate(engine, player)
        engine:resolve_round()

        if engine.state ~= "COMPLETE" then
            engine:start_round()
        end
    end

    stats.rounds = rounds
    stats.timeout = engine.state ~= "COMPLETE"
    stats.player_won = engine.winner == player
    stats.player_hearts = player.heart_points
    stats.enemy_hearts = enemy.heart_points
    stats.player_madness = player:get_crest_count("Madness")

    stats.enemy_parts_maimed = {}
    stats.enemy_parts_total = 0
    for _, part in ipairs(enemy.body_parts) do
        stats.enemy_parts_total = stats.enemy_parts_total + 1
        if part.status == "maimed" then
            table.insert(stats.enemy_parts_maimed, part.id)
        end
    end

    return stats
end

local function percent(count, total)
    if total == 0 then
        return "0%"
    end
    return string.format("%.0f%%", count / total * 100)
end

local function simulate_encounter(encounter_id, options)
    local runs = options.runs
    local totals = {
        wins = 0,
        timeouts = 0,
        rounds = 0,
        round_histogram = {},
        min_rounds = math.huge,
        max_rounds = 0,
        win_hearts = 0,
        player_madness = 0,
        player_damage = 0,
        slot_fires = {},
        maim_counts = {}
    }

    for run = 1, runs do
        local ok, stats = pcall(run_once, encounter_id, options.seed + run * 7919, options.player)
        if not ok then
            error("Simulation error in " .. encounter_id .. " run " .. run .. ": " .. tostring(stats))
        end

        totals.rounds = totals.rounds + stats.rounds
        totals.round_histogram[stats.rounds] = (totals.round_histogram[stats.rounds] or 0) + 1
        totals.min_rounds = math.min(totals.min_rounds, stats.rounds)
        totals.max_rounds = math.max(totals.max_rounds, stats.rounds)
        totals.player_madness = totals.player_madness + stats.player_madness
        totals.player_damage = totals.player_damage + stats.player_damage_taken

        if stats.timeout then
            totals.timeouts = totals.timeouts + 1
        elseif stats.player_won then
            totals.wins = totals.wins + 1
            totals.win_hearts = totals.win_hearts + stats.player_hearts
        end

        for name, count in pairs(stats.slot_fires) do
            totals.slot_fires[name] = (totals.slot_fires[name] or 0) + count
        end

        for _, part_id in ipairs(stats.enemy_parts_maimed) do
            totals.maim_counts[part_id] = (totals.maim_counts[part_id] or 0) + 1
        end
    end

    print(("== %s  (%d runs, player AI: %s)"):format(encounter_id, runs, options.player or "balanced"))
    print(("   player wins %s | timeouts %s | rounds avg %.1f (min %d / max %d)"):format(
        percent(totals.wins, runs),
        percent(totals.timeouts, runs),
        totals.rounds / runs,
        totals.min_rounds == math.huge and 0 or totals.min_rounds,
        totals.max_rounds))

    local histogram = {}
    for round = 1, totals.max_rounds do
        local count = totals.round_histogram[round]
        if count then
            table.insert(histogram, ("r%d:%d"):format(round, count))
        end
    end
    print("   round spread: " .. table.concat(histogram, "  "))

    if totals.wins > 0 then
        print(("   avg hearts on win: %.2f / 3"):format(totals.win_hearts / totals.wins))
    end
    print(("   avg damage steps taken by player: %.2f"):format(totals.player_damage / runs))
    if totals.player_madness > 0 then
        print(("   avg player Madness at end: %.2f"):format(totals.player_madness / runs))
    end

    local slot_lines = {}
    for name, count in pairs(totals.slot_fires) do
        table.insert(slot_lines, ("%s x%.1f"):format(name, count / runs))
    end
    table.sort(slot_lines)
    if #slot_lines > 0 then
        print("   slot fires per run: " .. table.concat(slot_lines, "  "))
    end

    local maim_lines = {}
    for part_id, count in pairs(totals.maim_counts) do
        table.insert(maim_lines, ("%s %s"):format(part_id, percent(count, runs)))
    end
    table.sort(maim_lines)
    if #maim_lines > 0 then
        print("   enemy part maimed (prize destroyed): " .. table.concat(maim_lines, "  "))
    end
    print("")
end

local options = parse_args(arg)
for _, encounter_id in ipairs(options.encounters) do
    simulate_encounter(encounter_id, options)
end
