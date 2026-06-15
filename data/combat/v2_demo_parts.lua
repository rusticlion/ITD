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
        moment_of_valor = {
            id = "moment_of_valor",
            name = "Moment of Valor",
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
                type = "heal_self",
                amount = 1
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
        }
    },

    parts = {
        dreamer_head = {
            id = "dreamer_head",
            name = "Dreamer's Head",
            type = "HEAD",
            hp_value = 3,
            die = die(O, W, S, E, E, { E, E }),
            slot = "moment_of_valor",
            tags = { "LUCID" }
        },
        dreamer_body = {
            id = "dreamer_body",
            name = "Dreamer's Body",
            type = "BODY",
            hp_value = 2,
            die = die(W, S, W, { W, S }, { W, W }, { S, S }),
            slot = "recuperation"
        },
        dreamer_right_arm = {
            id = "dreamer_right_arm",
            name = "Dreamer's Right Arm",
            type = "ARM",
            hp_value = 1,
            die = die(O, W, S, S, S, { S, E })
        },
        dreamer_left_arm = {
            id = "dreamer_left_arm",
            name = "Dreamer's Left Arm",
            type = "ARM",
            hp_value = 1,
            die = die(O, W, W, S, { W, E }, S)
        },
        dreamer_right_leg = {
            id = "dreamer_right_leg",
            name = "Dreamer's Right Leg",
            type = "LEG",
            hp_value = 1,
            die = die(O, W, O, S, W, S)
        },
        dreamer_left_leg = {
            id = "dreamer_left_leg",
            name = "Dreamer's Left Leg",
            type = "LEG",
            hp_value = 1,
            die = die(O, W, O, S, W, S)
        },

        bone_demon_skull = {
            id = "bone_demon_skull",
            name = "Bone Skull",
            type = "HEAD",
            hp_value = 1,
            die = die(E, S, E, { S, E }, { E, E }, S),
            slot = "speak_doom"
        },
        bone_demon_rib_cage = {
            id = "bone_demon_rib_cage",
            name = "Rib Cage",
            type = "BODY",
            hp_value = 1,
            die = die(O, S, E, S, { S, E }, S)
        },
        bone_demon_right_claw = {
            id = "bone_demon_right_claw",
            name = "Right Bone Claw",
            type = "ARM",
            hp_value = 1,
            die = die(O, S, S, E, S, { S, S })
        },
        bone_demon_left_claw = {
            id = "bone_demon_left_claw",
            name = "Left Bone Claw",
            type = "ARM",
            hp_value = 1,
            die = die(O, E, S, E, S, { S, E })
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
                "dreamer_right_arm",
                "dreamer_left_arm",
                "dreamer_right_leg",
                "dreamer_left_leg"
            }
        },
        enemy_demo = {
            id = "enemy",
            name = "Bone Demon",
            ai_personality = "doom_caster",
            parts = {
                "bone_demon_skull",
                "bone_demon_rib_cage",
                "bone_demon_right_claw",
                "bone_demon_left_claw"
            }
        }
    }
}
