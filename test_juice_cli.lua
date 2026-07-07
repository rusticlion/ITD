local Audio = require("core.audio")
local CombatJuice = require("combat.juice")
local Events = require("combat.events")
local ScreenFX = require("core.screenfx")
local Symbols = require("core.symbols")
local Tween = require("core.tween")

math.randomseed(20260706)

local function assert_true(condition, message)
    if not condition then
        error(message or "assertion failed", 2)
    end
end

local function assert_near(actual, expected, message)
    if math.abs(actual - expected) > 1e-6 then
        error(string.format("%s (expected %s, got %s)", message or "value mismatch", expected, actual), 2)
    end
end

-- Tween: interpolation, completion, ordering, cancellation, nested scheduling.
local group = Tween.group()
local subject = { x = 0 }
local completed = false
group:to(subject, 1, { x = 10 }, {
    ease = "linear",
    on_complete = function()
        completed = true
    end
})
group:update(0.5)
assert_near(subject.x, 5, "linear tween midpoint")
group:update(0.6)
assert_near(subject.x, 10, "tween lands exactly on target")
assert_true(completed, "tween completion callback fired")
assert_true(group:count() == 0, "finished tween removed from group")

local order = {}
group:after(0.2, function() table.insert(order, "second") end)
group:after(0.1, function()
    table.insert(order, "first")
    group:after(0.05, function() table.insert(order, "nested") end)
end)
group:update(0.1)
group:update(0.06)
group:update(0.1)
assert_true(order[1] == "first" and order[2] == "nested" and order[3] == "second",
    "timers fire in delay order, including timers scheduled mid-update")

local cancelled = group:after(0.1, function() error("cancelled timer must not fire") end)
Tween.group().cancel(cancelled)
group:update(0.2)

-- ScreenFX: hit-stop filters dt, juice 0 disables, headless frame calls no-op.
ScreenFX.reset()
ScreenFX.set_juice(1)
assert_near(ScreenFX.update(0.016), 0.016, "no effects passes dt through")
ScreenFX.hitstop(0.1)
assert_true(ScreenFX.is_frozen(), "hitstop freezes")
assert_near(ScreenFX.update(0.06), 0, "frozen frame simulates zero dt")
assert_near(ScreenFX.update(0.06), 0, "still frozen")
assert_near(ScreenFX.update(0.016), 0.016, "dt resumes after hitstop drains")

ScreenFX.set_juice(0)
ScreenFX.hitstop(0.5)
ScreenFX.shake(4, 1)
ScreenFX.flash({ 1, 0, 0 }, 1)
ScreenFX.desaturate(1, 1)
assert_true(not ScreenFX.is_frozen(), "juice 0 disables hitstop")
assert_true(#ScreenFX.shakes == 0 and #ScreenFX.flashes == 0 and ScreenFX.desat == nil,
    "juice 0 disables shake, flash, desaturate")
ScreenFX.begin_frame()
ScreenFX.end_frame()
ScreenFX.set_juice(1)
ScreenFX.reset()

-- Audio: cue table validates, unknown cues warn without erroring.
local cue_errors = Audio.validate()
assert_true(#cue_errors == 0, "audio cues validate: " .. table.concat(cue_errors, "; "))
assert_true(Audio.play("nonexistent_cue") == nil, "unknown cue returns nil")
assert_true(Audio.play("wound") == true, "known cue plays (headless no-op)")

-- CombatJuice: engine events map to the right cues in both timing domains.
local played = {}
Audio.on_play = function(cue_id)
    table.insert(played, cue_id)
end

local function played_count(cue_id)
    local count = 0
    for _, id in ipairs(played) do
        if id == cue_id then
            count = count + 1
        end
    end
    return count
end

local FakeEngine = {
    listeners = {},
    state = "ALLOCATION"
}

function FakeEngine:on(event_type, callback)
    self.listeners[event_type] = self.listeners[event_type] or {}
    table.insert(self.listeners[event_type], callback)
end

function FakeEngine:emit(event_type, data)
    for _, callback in ipairs(self.listeners[event_type] or {}) do
        callback(data)
    end
end

local juice = CombatJuice.new({ engine = FakeEngine })

FakeEngine:emit(Events.ROLL_PHASE, {})
FakeEngine:emit(Events.DICE_ROLLED, { symbols = { Symbols.STRIKE } })
FakeEngine:emit(Events.DICE_ROLLED, { symbols = { Symbols.BLOOD } })
juice:update(1)
assert_true(played_count("die_settle") == 1, "clean die settles dry")
assert_true(played_count("die_settle_gunked") == 1, "gunked die settles wet")

played = {}
FakeEngine:emit(Events.DIE_ASSIGNED, { destination = "rim", burned_symbols = {} })
FakeEngine:emit(Events.DIE_ASSIGNED, { destination = "socket", burned_symbols = { Symbols.STRIKE } })
juice:update(1)
assert_true(played_count("assign_rim") == 1, "rim assignment clacks")
assert_true(played_count("assign_socket") == 1, "socket assignment thunks")
assert_true(played_count("burn_off") == 1, "burned symbols sting")

played = {}
FakeEngine:emit(Events.SLOT_FED, {
    lit = { { index = 1 }, { index = 2 } },
    burned_symbols = {}
})
juice:update(1)
assert_true(played_count("slot_feed") == 1, "feed swallows")
assert_true(played_count("pip_lit") == 2, "each lit pip ticks")

-- Immediate (allocation-time) damage is juiced from the engine event...
played = {}
FakeEngine.state = "ALLOCATION"
FakeEngine:emit(Events.DAMAGE_DEALT, { status_after = "wounded", heart_point_loss = 0 })
assert_true(played_count("wound") == 1, "allocation-time damage juiced immediately")

-- ...but resolution-burst damage is silent until playback reveals it.
played = {}
FakeEngine.state = "RESOLUTION"
FakeEngine:emit(Events.DAMAGE_DEALT, { status_after = "wounded", heart_point_loss = 0 })
assert_true(played_count("wound") == 0, "resolution-burst damage deferred to playback")

ScreenFX.reset()
played = {}
juice:reveal_resolution({
    hit = true,
    strike_count = 2,
    ward_count = 1,
    vented = true,
    damage = { status_after = "maimed", heart_point_loss = 2 }
})
juice:update(1)
assert_true(played_count("strike_hit") == 1, "revealed hit lands")
assert_true(played_count("maim") == 1, "maim crack plays")
assert_true(played_count("vent") == 1, "vent shatter plays")
assert_true(played_count("heart_loss") == 1, "heart loss booms")
assert_true(ScreenFX.is_frozen(), "heart loss triggers hitstop")
ScreenFX.reset()

played = {}
juice:reveal_resolution({ hit = false, strike_count = 2, ward_count = 3 })
assert_true(played_count("strike_parried") == 1, "defended attack clangs")

played = {}
juice:resolution_parry_tick(1)
juice:resolution_parry_tick(2)
assert_true(played_count("parry_tick") == 2, "each matched pair ticks")

-- Resolution-as-counting timeline: drive V2Combat's playback headless and
-- check ticks, reveal, gunk witnessing, and completion ordering.
local V2Combat = require("states.v2_combat")

local completed = false
local fake_state = setmetatable({
    juice = juice,
    resolution_status_overrides = {},
    gunk_ghost_effects = {},
    complete_resolution_playback = function()
        completed = true
    end
}, { __index = V2Combat })

local entry = {
    part = {},
    strike_count = 3,
    ward_count = 2,
    pairs = 2,
    ticks_fired = 0,
    hit = true,
    vented = false,
    damage = { status_before = "healthy", status_after = "wounded", heart_point_loss = 0 },
    elapsed = 0,
    revealed = false
}
fake_state.resolution_playback = { entries = { entry }, index = 1, current = entry }

played = {}
for _ = 1, 20 do
    fake_state:update_resolution_playback(0.1)
end

assert_true(played_count("parry_tick") == 2, "two matched pairs tick during the count")
assert_true(played_count("strike_hit") == 1, "unanswered strike lands once")
assert_true(played_count("wound") == 1, "damage step plays at reveal")
assert_true(entry.revealed, "entry revealed at outcome time")
assert_true(#fake_state.gunk_ghost_effects == 1, "gunk ghosts witness the struck faces")
assert_true(completed, "playback completes after the tail")

Audio.on_play = nil
print("juice smoke test passed.")
