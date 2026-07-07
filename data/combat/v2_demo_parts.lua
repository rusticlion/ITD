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
        dreamer_right_arm = {
            id = "dreamer_right_arm",
            name = "Dreamer's Right Arm",
            flavor = "A plain hand for grabbing, guarding, and striking in the dark.",
            type = "ARM",
            hp_value = 1,
            die = die(O, W, S, S, S, { S, E })
        },
        dreamer_left_arm = {
            id = "dreamer_left_arm",
            name = "Dreamer's Left Arm",
            flavor = "A plain hand with a little more hesitation than force.",
            type = "ARM",
            hp_value = 1,
            die = die(O, W, W, S, { W, E }, S)
        },
        dreamer_right_leg = {
            id = "dreamer_right_leg",
            name = "Dreamer's Right Leg",
            flavor = "A foot that has not yet learned where it is running.",
            type = "LEG",
            hp_value = 1,
            die = die(O, W, O, S, W, S)
        },
        dreamer_left_leg = {
            id = "dreamer_left_leg",
            name = "Dreamer's Left Leg",
            flavor = "A foot that has not yet learned what follows behind.",
            type = "LEG",
            hp_value = 1,
            die = die(O, W, O, S, W, S)
        },

        bone_demon_skull = {
            id = "bone_demon_skull",
            name = "Bone Skull",
            flavor = "It speaks with no tongue, and the words still arrive.",
            type = "HEAD",
            hp_value = 1,
            die = die(E, S, E, { S, E }, { E, E }, S),
            slot = "speak_doom"
        },
        bone_demon_rib_cage = {
            id = "bone_demon_rib_cage",
            name = "Rib Cage",
            flavor = "A dry cage around nothing at all.",
            type = "BODY",
            hp_value = 1,
            die = die(O, S, E, S, { S, E }, S)
        },
        bone_demon_right_claw = {
            id = "bone_demon_right_claw",
            name = "Right Bone Claw",
            flavor = "The fingers click like counting sticks.",
            type = "ARM",
            hp_value = 1,
            die = die(O, S, S, E, S, { S, S })
        },
        bone_demon_left_claw = {
            id = "bone_demon_left_claw",
            name = "Left Bone Claw",
            flavor = "It points before it cuts.",
            type = "ARM",
            hp_value = 1,
            die = die(O, E, S, E, S, { S, E })
        },
        scholars_head = {
            id = "scholars_head",
            name = "Scholar's Head",
            flavor = "\"The library will endure; it is the universe.\" - Jorge Luis Borges",
            type = "HEAD",
            hp_value = 3,
            die = {
                faces = {
                    { Symbols.ESSENCE, Symbols.ESSENCE },
                    { Symbols.ESSENCE, Symbols.ESSENCE },
                    Symbols.ESSENCE,
                    Symbols.ESSENCE,
                    { Symbols.WARD, Symbols.WARD },
                    Symbols.WARD
                },
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            },
            slot = {
                id = "scholars_head_slot",
                name = "Anticipate",
                cost = { Symbols.ESSENCE },
                timing = "spend",
                effect = { type = "add_next_symbol", symbol = Symbols.WARD }
            }
        },
        ["robot_head"] = {
            id = "robot_head",
            name = "Robot Head",
            flavor = "",
            type = "HEAD",
            hp_value = 2,
            keywords = { "Armored" },
            die = {
                faces = {
                    { Symbols.STRIKE, Symbols.WARD },
                    Symbols.STRIKE,
                    { Symbols.STRIKE, Symbols.WARD },
                    Symbols.WARD,
                    Symbols.ESSENCE,
                    { Symbols.WARD, Symbols.WARD }
                },
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            },
            slot = {
                id = "robot_head_slot",
                name = "Drone",
                cost = { Symbols.STRIKE, Symbols.WARD },
                timing = "spend",
                effect = { type = "assign_symbol_to_each_part", destination = "socket", target = "self", symbol = Symbols.WARD, amount = 1 }
            }
        },
        ["withered_arm"] = {
            id = "withered_arm",
            name = "Withered Arm",
            flavor = "",
            type = "ARM",
            hp_value = 1,
            keywords = { "Brittle" },
            die = {
                faces = {
                    Symbols.ESSENCE,
                    Symbols.ESSENCE,
                    Symbols.STRIKE,
                    Symbols.WARD,
                    Symbols.ESSENCE,
                    Symbols.ESSENCE
                },
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            },
            slot = {
                id = "withered_arm_slot",
                name = "Vengeance",
                cost = { Symbols.BLOOD },
                timing = "spend",
                effect = { type = "add_symbol_to_matching_dice", match = Symbols.ESSENCE, symbol = Symbols.STRIKE, amount = 1 }
            }
        },
        ["gaunt_cloak"] = {
            id = "gaunt_cloak",
            name = "Gaunt Cloak",
            flavor = "",
            type = "BODY",
            hp_value = 2,
            keywords = { "Absorbent" },
            die = {
                faces = {
                    { Symbols.ESSENCE, Symbols.ESSENCE },
                    { Symbols.WARD, Symbols.WARD },
                    Symbols.ESSENCE,
                    Symbols.WARD,
                    Symbols.BLANK,
                    Symbols.BLANK
                },
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            },
            slot = {
                id = "gaunt_cloak_slot",
                name = "Enshroud",
                cost = { Symbols.WARD, Symbols.ESSENCE, Symbols.ESSENCE, Symbols.ESSENCE },
                hungry = true,
                timing = "spend",
                effect = { type = "assign_symbol_to_each_part", destination = "socket", target = "self", symbol = Symbols.WARD, amount = 1 }
            }
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
            ai_personality = "bone_caster",
            parts = {
                "bone_demon_skull",
                "bone_demon_rib_cage",
                "bone_demon_right_claw",
                "bone_demon_left_claw"
            }
        }
    }
}
