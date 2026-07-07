-- Combat juice director: translates the engine's event stream into sound and
-- screen effects. Decoupled by design — remove this module and combat still
-- plays identically.
--
-- Two timing domains, matching how the combat state presents events:
--   1. Allocation/upkeep events fire in real time and are juiced straight off
--      engine subscriptions (assignments, feeds, crests, immediate slot damage).
--   2. Resolution events fire in a synchronous burst at Confirm, then replay
--      through the state's timed playback. Those are juiced from
--      reveal_resolution(entry), never from the raw engine emission — the
--      engine-time handlers skip anything emitted while engine.state is
--      "RESOLUTION".

local Audio = require("core.audio")
local Events = require("combat.events")
local ScreenFX = require("core.screenfx")
local Symbols = require("core.symbols")
local Tween = require("core.tween")

local CombatJuice = {}
CombatJuice.__index = CombatJuice

local ROLL_STAGGER = 0.045
local PIP_STAGGER = 0.05
local BURN_DELAY = 0.12

local function is_gunked(symbols)
    for _, symbol in ipairs(symbols or {}) do
        if symbol == Symbols.BLOOD then
            return true
        end
    end
    return false
end

local function in_resolution(engine)
    return engine and engine.state == "RESOLUTION"
end

function CombatJuice.new(state)
    local juice = setmetatable({
        state = state,
        engine = state.engine,
        group = Tween.group(),
        roll_index = 0
    }, CombatJuice)

    juice:subscribe()
    return juice
end

function CombatJuice:update(dt)
    self.group:update(dt)
end

function CombatJuice:play_later(delay, cue, opts)
    if delay <= 0 then
        Audio.play(cue, opts)
    else
        self.group:after(delay, function()
            Audio.play(cue, opts)
        end)
    end
end

function CombatJuice:subscribe()
    local engine = self.engine

    engine:on(Events.ROLL_PHASE, function()
        self.roll_index = 0
    end)

    -- Dice settle as a cascade, not a burst; gunked dice land wetter.
    engine:on(Events.DICE_ROLLED, function(data)
        self.roll_index = self.roll_index + 1
        local cue = is_gunked(data.symbols) and "die_settle_gunked" or "die_settle"
        self:play_later((self.roll_index - 1) * ROLL_STAGGER, cue)
    end)

    -- The three destinations are the player's motor vocabulary; each gets its
    -- own sound. Burned symbols get their small sting shortly after the snap.
    engine:on(Events.DIE_ASSIGNED, function(data)
        Audio.play(data.destination == "rim" and "assign_rim" or "assign_socket")
        if #(data.burned_symbols or {}) > 0 then
            self:play_later(BURN_DELAY, "burn_off")
        end
    end)

    engine:on(Events.SLOT_FED, function(data)
        Audio.play("slot_feed")
        for index = 1, #(data.lit or {}) do
            self:play_later(0.08 + (index - 1) * PIP_STAGGER, "pip_lit", {
                pitch = 1 + (index - 1) * 0.06 -- payment counted upward
            })
        end
        if #(data.burned_symbols or {}) > 0 then
            self:play_later(0.08 + #(data.lit or {}) * PIP_STAGGER + BURN_DELAY, "burn_off")
        end
    end)

    engine:on(Events.SLOT_TRIGGERED, function()
        Audio.play("slot_armed")
    end)

    engine:on(Events.SLOT_RESOLVED, function()
        Audio.play("slot_resolved")
    end)

    engine:on(Events.CREST_GAINED, function(data)
        if data and data.crest == "Madness" then
            Audio.play("madness_gain")
        else
            Audio.play("crest_gain")
        end
    end)

    engine:on(Events.CREST_EXPENDED, function(data)
        -- Purging Madness is a pinch, not a purchase: the wound it inflicts
        -- provides the feedback, so the pleasant chime stays silent.
        if not (data and data.crest == "Madness") then
            Audio.play("crest_expend")
        end
    end)

    engine:on(Events.LATCH_EJECTED, function()
        Audio.play("latch_ejected")
    end)

    -- Immediate damage during Allocation (e.g. Speak Doom firing at Spend).
    -- Resolution-phase damage replays through reveal_resolution instead.
    engine:on(Events.DAMAGE_DEALT, function(data)
        if in_resolution(engine) then
            return
        end
        self:damage_feedback(data.status_after, data.heart_point_loss, false)
    end)

    engine:on(Events.SLOT_CHARGE_VENTED, function()
        if in_resolution(engine) then
            return
        end
        self:vent_feedback()
    end)

    engine:on(Events.HEAL_APPLIED, function(data)
        if not data.no_effect then
            Audio.play("heal")
        end
    end)
end

function CombatJuice:vent_feedback()
    Audio.play("vent")
    ScreenFX.shake(1.5, 0.2)
end

function CombatJuice:damage_feedback(status_after, heart_point_loss, vented)
    if status_after == "maimed" then
        Audio.play("maim")
        ScreenFX.shake(2, 0.25)
    elseif status_after == "wounded" then
        Audio.play("wound")
    end

    if vented then
        self.group:after(0.08, function()
            self:vent_feedback()
        end)
    end

    if (heart_point_loss or 0) > 0 then
        -- The rarest, biggest beat: freeze, boom, color drains for a breath.
        Audio.play("heart_loss")
        ScreenFX.hitstop(0.18)
        ScreenFX.flash({ 0.75, 0.1, 0.12 }, 0.3, 0.3)
        ScreenFX.desaturate(0.7, 0.45)
    end
end

-- One tick per matched strike/ward pair during the resolution count; pitch
-- rises with the count so the ear tracks it without watching.
function CombatJuice:resolution_parry_tick(pair_index)
    Audio.play("parry_tick", { pitch = 1 + (pair_index - 1) * 0.06 })
end

-- Called by the combat state as each playback entry is revealed.
function CombatJuice:reveal_resolution(entry)
    if not entry then
        return
    end

    if entry.hit then
        Audio.play("strike_hit")
    elseif (entry.strike_count or 0) > 0 then
        Audio.play("strike_parried")
    end

    local damage = entry.damage
    if damage then
        self:damage_feedback(damage.status_after, damage.heart_point_loss, entry.vented)
    end
end

-- The whispers take a die: an uneasy swell and the color briefly drains.
function CombatJuice:madness_seizure()
    Audio.play("madness_whisper")
    ScreenFX.desaturate(0.45, 0.6)
end

function CombatJuice:die_picked()
    Audio.play("die_pick")
end

function CombatJuice:invalid()
    Audio.play("invalid")
end

function CombatJuice:combat_ended(player_won)
    Audio.play(player_won and "victory" or "defeat")
end

return CombatJuice
