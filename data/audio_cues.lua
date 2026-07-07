-- The combat sound grammar. Every cue is a placeholder synth patch until a
-- real file lands at assets/sounds/<cue_id>.ogg (or .wav), which overrides
-- the synth automatically. Keep the grammar stable even as the sounds improve:
-- one sound per destination type, one per damage tier, quiet ticks for
-- bookkeeping, ceremony reserved for hearts and venting.
--
-- Layer fields: wave = sine|triangle|square|noise, freq (Hz), optional
-- freq_end (glide target), duration (s), volume (0..1), curve (decay sharpness,
-- higher = snappier).

return {
    -- Dice
    die_settle = {
        volume = 0.35,
        pitch_variance = 0.08,
        layers = {
            { wave = "noise", duration = 0.03, volume = 0.5, curve = 3 },
            { wave = "triangle", freq = 520, duration = 0.05, volume = 0.6, curve = 2.5 }
        }
    },
    die_settle_gunked = {
        volume = 0.4,
        pitch_variance = 0.06,
        layers = {
            { wave = "noise", duration = 0.06, volume = 0.35, curve = 1.5 },
            { wave = "sine", freq = 150, freq_end = 110, duration = 0.1, volume = 0.8, curve = 2 }
        }
    },
    die_pick = {
        volume = 0.3,
        pitch_variance = 0.05,
        layers = {
            { wave = "triangle", freq = 640, freq_end = 720, duration = 0.05, volume = 0.7, curve = 2 }
        }
    },

    -- Destinations: the three motor truths.
    assign_rim = { -- latch-clack: bright, mechanical
        volume = 0.5,
        pitch_variance = 0.05,
        layers = {
            { wave = "square", freq = 860, duration = 0.035, volume = 0.4, curve = 3 },
            { wave = "noise", duration = 0.025, volume = 0.5, curve = 4 }
        }
    },
    assign_socket = { -- dock-thunk: low, solid
        volume = 0.5,
        pitch_variance = 0.05,
        layers = {
            { wave = "sine", freq = 190, freq_end = 120, duration = 0.09, volume = 0.9, curve = 2 },
            { wave = "noise", duration = 0.02, volume = 0.25, curve = 4 }
        }
    },
    slot_feed = { -- swallow-gulp: descending
        volume = 0.5,
        pitch_variance = 0.04,
        layers = {
            { wave = "sine", freq = 440, freq_end = 170, duration = 0.13, volume = 0.8, curve = 1.5 }
        }
    },

    -- Slot bookkeeping
    pip_lit = {
        volume = 0.3,
        pitch_variance = 0.03,
        layers = {
            { wave = "triangle", freq = 980, duration = 0.03, volume = 0.7, curve = 3 }
        }
    },
    burn_off = { -- slightly feel-bad on purpose
        volume = 0.25,
        pitch_variance = 0.04,
        layers = {
            { wave = "triangle", freq = 620, freq_end = 540, duration = 0.08, volume = 0.6, curve = 1.5 }
        }
    },
    slot_armed = {
        volume = 0.5,
        pitch_variance = 0.02,
        layers = {
            { wave = "triangle", freq = 510, freq_end = 800, duration = 0.16, volume = 0.7, curve = 1.2 }
        }
    },
    slot_resolved = {
        volume = 0.5,
        pitch_variance = 0.04,
        layers = {
            { wave = "noise", duration = 0.16, volume = 0.35, curve = 1.8 },
            { wave = "sine", freq = 300, freq_end = 150, duration = 0.18, volume = 0.6, curve = 1.5 }
        }
    },

    -- Damage tiers
    parry_tick = { -- one per matched strike/ward pair in the resolution count
        volume = 0.35,
        pitch_variance = 0.02,
        layers = {
            { wave = "square", freq = 720, duration = 0.04, volume = 0.35, curve = 3 },
            { wave = "noise", duration = 0.02, volume = 0.3, curve = 4 }
        }
    },
    strike_parried = {
        volume = 0.5,
        pitch_variance = 0.05,
        layers = {
            { wave = "square", freq = 620, duration = 0.09, volume = 0.35, curve = 2.5 },
            { wave = "noise", duration = 0.03, volume = 0.4, curve = 4 }
        }
    },
    strike_hit = {
        volume = 0.55,
        pitch_variance = 0.06,
        layers = {
            { wave = "noise", duration = 0.06, volume = 0.5, curve = 2.5 },
            { wave = "sine", freq = 200, freq_end = 90, duration = 0.12, volume = 0.8, curve = 2 }
        }
    },
    wound = {
        volume = 0.6,
        pitch_variance = 0.05,
        layers = {
            { wave = "noise", duration = 0.09, volume = 0.6, curve = 2 },
            { wave = "sine", freq = 160, freq_end = 70, duration = 0.16, volume = 0.9, curve = 1.8 }
        }
    },
    maim = {
        volume = 0.7,
        pitch_variance = 0.04,
        layers = {
            { wave = "noise", duration = 0.14, volume = 0.7, curve = 1.5 },
            { wave = "sine", freq = 120, freq_end = 50, duration = 0.26, volume = 1.0, curve = 1.5 }
        }
    },
    heart_loss = {
        volume = 0.8,
        pitch_variance = 0.02,
        layers = {
            { wave = "sine", freq = 72, freq_end = 40, duration = 0.5, volume = 1.0, curve = 1.2 },
            { wave = "noise", duration = 0.08, volume = 0.3, curve = 2.5 }
        }
    },
    vent = { -- pip shatter: the best-feeling effect in the game
        volume = 0.6,
        pitch_variance = 0.05,
        layers = {
            { wave = "noise", duration = 0.2, volume = 0.55, curve = 1.2 },
            { wave = "sine", freq = 1400, freq_end = 880, duration = 0.12, volume = 0.4, curve = 2 },
            { wave = "triangle", freq = 1900, freq_end = 1200, duration = 0.08, volume = 0.3, curve = 2.5 }
        }
    },

    -- Recovery and resources
    heal = {
        volume = 0.4,
        pitch_variance = 0.03,
        layers = {
            { wave = "sine", freq = 310, freq_end = 520, duration = 0.2, volume = 0.7, curve = 1.2 }
        }
    },
    crest_gain = {
        volume = 0.45,
        pitch_variance = 0.03,
        layers = {
            { wave = "triangle", freq = 780, freq_end = 1040, duration = 0.12, volume = 0.7, curve = 1.5 }
        }
    },
    crest_expend = {
        volume = 0.45,
        pitch_variance = 0.03,
        layers = {
            { wave = "triangle", freq = 1040, freq_end = 700, duration = 0.12, volume = 0.7, curve = 1.5 }
        }
    },
    latch_ejected = {
        volume = 0.45,
        pitch_variance = 0.06,
        layers = {
            { wave = "square", freq = 480, freq_end = 900, duration = 0.1, volume = 0.4, curve = 1.5 }
        }
    },

    -- UI
    invalid = {
        volume = 0.3,
        pitch_variance = 0.02,
        layers = {
            { wave = "square", freq = 110, duration = 0.09, volume = 0.4, curve = 1.5 }
        }
    },

    -- Combat end stings
    victory = {
        volume = 0.55,
        pitch_variance = 0,
        layers = {
            { wave = "sine", freq = 523, duration = 0.55, volume = 0.5, curve = 1.2 },
            { wave = "sine", freq = 659, duration = 0.55, volume = 0.45, curve = 1.2 },
            { wave = "sine", freq = 784, duration = 0.6, volume = 0.4, curve = 1.1 }
        }
    },
    defeat = {
        volume = 0.55,
        pitch_variance = 0,
        layers = {
            { wave = "sine", freq = 220, freq_end = 110, duration = 0.7, volume = 0.6, curve = 1.1 },
            { wave = "sine", freq = 165, freq_end = 82, duration = 0.8, volume = 0.5, curve = 1.1 }
        }
    }
}
