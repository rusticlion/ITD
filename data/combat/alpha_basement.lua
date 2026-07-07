local Symbols = require("core.symbols")

local S = Symbols.STRIKE
local W = Symbols.WARD
local E = Symbols.ESSENCE
local B = Symbols.BLOOD
local O = Symbols.BLANK

local function die(wound_a, wound_b, maim_a, maim_b, durable_a, durable_b)
    return {
        faces = {
            wound_a,
            wound_b,
            maim_a,
            maim_b,
            durable_a,
            durable_b
        },
        wound_faces = { 1, 2 },
        maim_faces = { 3, 4 }
    }
end

return {
    slots = {
        clarity = {
            id = "clarity",
            name = "Clarity",
            cost = { E },
            timing = "spend",
            effect = {
                type = "add_next_symbol",
                symbol = S
            }
        },
        recuperation = {
            id = "recuperation",
            name = "Recuperation",
            cost = { B, B, B },
            timing = "spend",
            effect = {
                type = "heal_part",
                target = "most_damaged",
                amount = 1
            }
        },
        regenerate = {
            id = "regenerate",
            name = "Regrowth",
            cost = { B },
            timing = "spend",
            effect = {
                type = "heal_part",
                target = "source_part",
                amount = 1
            }
        },
        bite = {
            id = "bite",
            name = "Bite",
            cost = { B, B },
            timing = "spend",
            effect = {
                type = "add_next_symbol",
                symbol = S,
                amount = 2
            }
        },
        speak_doom = {
            id = "speak_doom",
            name = "Speak Doom",
            cost = { E, E, E, E },
            timing = "spend",
            effect = {
                type = "damage_opponent_part",
                target_type = "HEAD",
                amount = 1
            }
        },
        bonestorm = {
            id = "bonestorm",
            name = "Bonestorm",
            cost = { S, S, S, S },
            timing = "spend",
            effect = {
                type = "assign_symbol_to_each_part",
                destination = "rim",
                target = "opponent",
                symbol = S,
                amount = 1
            }
        },
        sadism = {
            id = "sadism",
            name = "Sadism",
            cost = { S, S, S, S },
            dynamic_cost = {
                type = "opponent_damaged_parts",
                minimum = 1,
                per_part = 1
            },
            timing = "spend",
            effect = {
                type = "add_symbol_against_status",
                match = S,
                symbol = S,
                amount = 1,
                destination = "rim",
                target_status = "wounded"
            }
        },
        stitch_up = {
            id = "stitch_up",
            name = "Stitch Up",
            cost = { B, B },
            timing = "spend",
            effect = {
                type = "heal_part",
                target = "part_type",
                target_type = "HEAD",
                amount = 1
            }
        },
        whisper = {
            id = "whisper",
            name = "Whisper",
            cost = { E },
            timing = "spend",
            effect = {
                type = "gain_crest",
                target = "opponent",
                crest = "Madness",
                amount = 1
            }
        },
        feed_the_walls = {
            id = "feed_the_walls",
            name = "Feed the Walls",
            cost = { E, E, E },
            hungry = true,
            timing = "spend",
            effect = {
                type = "gain_crest",
                target = "opponent",
                crest = "Madness",
                amount = 1
            }
        },
        reknit_plaster = {
            id = "reknit_plaster",
            name = "Reknit Plaster",
            cost = { B, B },
            timing = "spend",
            effect = {
                type = "heal_part",
                target = "most_damaged",
                amount = 1
            }
        }
    },

    parts = {
        dreamer_head = {
            id = "dreamer_head",
            name = "Dreamer's Head",
            flavor = "The part of you that knows this is a dream, however dimly.",
            type = "HEAD",
            hp_value = 3,
            die = die(O, W, S, E, E, { E, E }),
            slot = "clarity",
            tags = { "LUCID" }
        },
        dreamer_body = {
            id = "dreamer_body",
            name = "Dreamer's Body",
            flavor = "A sleeping shape that still remembers how to keep breathing.",
            type = "BODY",
            hp_value = 2,
            die = die(W, S, W, { W, S }, { W, W }, { S, S }),
            slot = "recuperation"
        },
        dreamer_fore_hand = {
            id = "dreamer_fore_hand",
            name = "Fore Hand",
            flavor = "The steady hand. The strong arm.",
            type = "ARM",
            hp_value = 1,
            die = die(S, E, S, W, S, S)
        },
        dreamer_back_hand = {
            id = "dreamer_back_hand",
            name = "Back Hand",
            flavor = "The sly hand. The casual motion.",
            type = "ARM",
            hp_value = 1,
            die = die(W, E, W, S, W, W)
        },
        dreamer_front_foot = {
            id = "dreamer_front_foot",
            name = "Front Foot",
            flavor = "You try to put your best foot forward. It works about half the time.",
            type = "LEG",
            hp_value = 1,
            die = die(S, S, S, S, W, W)
        },
        dreamer_back_foot = {
            id = "dreamer_back_foot",
            name = "Back Foot",
            flavor = "",
            type = "LEG",
            hp_value = 1,
            die = die(S, S, W, W, W, W)
        },

        zombie_brain_pan = {
            id = "zombie_brain_pan",
            name = "Brain Pan",
            flavor = "The dead thing behind its eyes has learned to bite.",
            type = "HEAD",
            hp_value = 3,
            die = die(O, W, S, S, { S, W }, { S, S }),
            slot = "bite"
        },
        zombie_rotting_ribcage = {
            id = "zombie_rotting_ribcage",
            name = "Rotting Ribcage",
            flavor = "Its ruined chest closes around every fresh wound.",
            type = "BODY",
            hp_value = 2,
            die = die(O, W, S, W, { W, W }, S),
            slot = "regenerate"
        },
        zombie_right_arm = {
            id = "zombie_right_arm",
            name = "Dead Right Arm",
            flavor = "A heavy arm that keeps remembering how to swing.",
            type = "ARM",
            hp_value = 1,
            die = die(O, W, S, S, S, { S, S }),
            slot = "regenerate"
        },
        zombie_left_arm = {
            id = "zombie_left_arm",
            name = "Dead Left Arm",
            flavor = "The fingers grope toward warmth.",
            type = "ARM",
            hp_value = 1,
            die = die(O, W, S, W, S, { S, W }),
            slot = "regenerate"
        },
        zombie_right_leg = {
            id = "zombie_right_leg",
            name = "Stiff Right Leg",
            flavor = "It drags, catches, and lurches forward again.",
            type = "LEG",
            hp_value = 1,
            die = die(O, W, O, S, W, S),
            slot = "regenerate"
        },
        zombie_left_leg = {
            id = "zombie_left_leg",
            name = "Stiff Left Leg",
            flavor = "The knee bends in several remembered directions.",
            type = "LEG",
            hp_value = 1,
            die = die(O, W, O, S, W, S),
            slot = "regenerate"
        },

        bone_demon_skull = {
            id = "bone_demon_skull",
            name = "Demon Skull",
            flavor = "It speaks with no tongue, and the words still arrive.",
            type = "HEAD",
            hp_value = 1,
            die = die(E, E, W, E, { E, W }, E),
            slot = "speak_doom"
        },
        bone_demon_rib_cage = {
            id = "bone_demon_rib_cage",
            name = "Hollow Ribcage",
            flavor = "A dry cage around the storm waiting inside.",
            type = "BODY",
            hp_value = 2,
            die = die(S, S, W, S, { S, W }, S),
            slot = "bonestorm"
        },
        bone_demon_right_bare_bones = {
            id = "bone_demon_right_bare_bones",
            name = "Bare Bones",
            flavor = "The fingers click together, counting toward the storm.",
            type = "ARM",
            hp_value = 1,
            die = die(O, S, W, S, { S, W }, S)
        },
        bone_demon_left_bare_bones = {
            id = "bone_demon_left_bare_bones",
            name = "Bare Bones",
            flavor = "It points toward each place the bones will strike.",
            type = "ARM",
            hp_value = 1,
            die = die(O, S, W, S, { S, W }, S)
        },
        bone_demon_right_tentacle = {
            id = "bone_demon_right_tentacle",
            name = "Right Tentacle",
            flavor = "A pale cord draws the words up from somewhere below.",
            type = "LEG",
            hp_value = 1,
            die = die(O, E, W, E, { E, W }, E)
        },
        bone_demon_left_tentacle = {
            id = "bone_demon_left_tentacle",
            name = "Left Tentacle",
            flavor = "It knots itself around an invisible syllable.",
            type = "LEG",
            hp_value = 1,
            die = die(O, E, W, E, { E, W }, E)
        },

        butcher_welding_mask = {
            id = "butcher_welding_mask",
            name = "Welding Mask",
            flavor = "A blind iron grin, warm from somebody else's fear.",
            type = "HEAD",
            hp_value = 3,
            die = die(O, S, S, B, { S, E }, S),
            slot = "sadism"
        },
        butcher_broad_shoulders = {
            id = "butcher_broad_shoulders",
            name = "Broad Shoulders",
            flavor = "The whole body stoops to keep the masked head upright.",
            type = "BODY",
            hp_value = 1,
            die = die(O, B, E, B, { B, E }, W),
            slot = "stitch_up"
        },
        butcher_hook_hand = {
            id = "butcher_hook_hand",
            name = "Hook Hand",
            flavor = "It catches first. The pulling comes after.",
            type = "ARM",
            hp_value = 1,
            die = die(O, S, S, E, { S, S, S }, { S, S })
        },
        butcher_cleaver_arm = {
            id = "butcher_cleaver_arm",
            name = "Cleaver Arm",
            flavor = "A practiced weight falls without hesitation.",
            type = "ARM",
            hp_value = 1,
            die = die(O, S, E, S, { S, S }, { S, S })
        },

        -- The Whisperer: what the whispering wall was holding in. It does not
        -- want to break your body; it wants to move in. Wounding its face
        -- burns off the blank and the ward — the whispers only get louder.
        whisperer_mouthless_face = {
            id = "whisperer_mouthless_face",
            name = "Mouthless Face",
            flavor = "It has no mouth, and the whispering never stops.",
            type = "HEAD",
            hp_value = 2,
            die = die(O, W, E, { E, W }, E, { E, E }),
            slot = "whisper",
            keywords = { "Armored" }
        },
        whisperer_plaster_husk = {
            id = "whisperer_plaster_husk",
            name = "Plaster Husk",
            flavor = "Strike the wall and the wall keeps what you gave it.",
            type = "BODY",
            hp_value = 1,
            die = die(B, W, W, { W, E }, { W, W }, W),
            slot = "feed_the_walls",
            keywords = { "Absorbent" }
        },
        whisperer_scratcher = {
            id = "whisperer_scratcher",
            name = "Scratcher",
            flavor = "The scratching you always told yourself was pipes.",
            type = "ARM",
            hp_value = 1,
            die = die(O, { S, S }, S, { S, S }, { S, S, S }, S),
            keywords = { "Brittle" }
        },
        whisperer_skitter_legs = {
            id = "whisperer_skitter_legs",
            name = "Skitter Legs",
            flavor = "Too many joints, all of them patient.",
            type = "LEG",
            hp_value = 1,
            die = die(O, E, W, E, { W, E }, E),
            slot = "reknit_plaster"
        }
    },

    loadouts = {
        player_demo = {
            id = "player",
            name = "Dreamer",
            is_player = true,
            parts = {
                "dreamer_head",
                "dreamer_body",
                "dreamer_fore_hand",
                "dreamer_back_hand",
                "dreamer_front_foot",
                "dreamer_back_foot"
            }
        },
        bone_demon = {
            id = "enemy",
            name = "Bone Demon",
            ai_personality = "bone_caster",
            parts = {
                "bone_demon_skull",
                "bone_demon_rib_cage",
                "bone_demon_right_bare_bones",
                "bone_demon_left_bare_bones",
                "bone_demon_right_tentacle",
                "bone_demon_left_tentacle"
            }
        },
        zombie = {
            id = "enemy",
            name = "Zombie",
            ai_personality = {
                base = "balanced",
                weights = {
                    rim = 27,
                    socket = 18,
                    slot = 20
                },
                symbol_values = {
                    strike = 9,
                    ward = 7,
                    slot = 9
                },
                fill_slot_bonus = 22,
                preferred_slots = {
                    regenerate = 8,
                    bite = 14
                }
            },
            parts = {
                "zombie_brain_pan",
                "zombie_rotting_ribcage",
                "zombie_right_arm",
                "zombie_left_arm",
                "zombie_right_leg",
                "zombie_left_leg"
            }
        },
        mad_butcher = {
            id = "enemy",
            name = "Mad Butcher",
            ai_personality = "mad_butcher",
            parts = {
                "butcher_welding_mask",
                "butcher_broad_shoulders",
                "butcher_hook_hand",
                "butcher_cleaver_arm",
                "zombie_right_leg",
                "zombie_left_leg"
            }
        },
        whisperer = {
            id = "enemy",
            name = "The Whisperer",
            ai_personality = {
                base = "balanced",
                weights = {
                    rim = 22,
                    socket = 38,
                    slot = 30
                },
                symbol_values = {
                    strike = 9,
                    ward = 9,
                    slot = 10
                },
                fill_slot_bonus = 26,
                charged_slot_bonus = 10,
                preferred_slots = {
                    whisper = 20,
                    feed_the_walls = 8,
                    reknit_plaster = 12
                },
                preferred_sockets = {
                    whisperer_plaster_husk = 20,
                    whisperer_skitter_legs = 14
                },
                defend_charged_slot_bonus = 14,
                target_status_bonus = {
                    wounded = 22,
                    healthy = 0
                },
                heal_wounded_slot_bonus = 34
            },
            parts = {
                "whisperer_mouthless_face",
                "whisperer_plaster_husk",
                "whisperer_scratcher",
                "whisperer_skitter_legs"
            }
        },
        enemy_demo = {
            id = "enemy",
            name = "Bone Demon",
            ai_personality = "bone_caster",
            parts = {
                "bone_demon_skull",
                "bone_demon_rib_cage",
                "bone_demon_right_bare_bones",
                "bone_demon_left_bare_bones",
                "bone_demon_right_tentacle",
                "bone_demon_left_tentacle"
            }
        }
    }
}
