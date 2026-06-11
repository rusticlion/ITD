local Symbols = require("core.symbols")

local function fixed_face(symbols)
    return {
        symbols,
        symbols,
        symbols,
        symbols,
        symbols,
        symbols
    }
end

return {
    slots = {
        insight = {
            id = "insight",
            name = "Insight",
            cost = { Symbols.ESSENCE },
            timing = "spend",
            effect = {
                type = "gain_crest",
                crest = "Valor",
                amount = 1
            }
        },
        bloodlust = {
            id = "bloodlust",
            name = "Bloodlust",
            cost = { Symbols.STRIKE, Symbols.STRIKE, Symbols.STRIKE },
            timing = "spend",
            effect = {
                type = "add_next_symbol",
                symbol = Symbols.STRIKE
            }
        }
    },

    parts = {
        player_head = {
            id = "player_head",
            name = "Lucid Head",
            type = "HEAD",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.WARD }),
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            }
        },
        player_cleaver = {
            id = "player_cleaver",
            name = "Butcher's Cleaver Arm",
            type = "ARM",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.STRIKE, Symbols.STRIKE }),
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            },
            slot = "bloodlust"
        },
        player_scholar = {
            id = "player_scholar",
            name = "Scholar's Hand",
            type = "ARM",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.ESSENCE }),
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            },
            slot = "insight"
        },
        player_mixed = {
            id = "player_mixed",
            name = "Hedging Palm",
            type = "ARM",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.STRIKE, Symbols.WARD }),
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            }
        },

        enemy_head = {
            id = "enemy_head",
            name = "Glass Head",
            type = "HEAD",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.WARD }),
                wound_faces = { 1, 2, 3, 4, 5, 6 },
                maim_faces = {}
            }
        },
        enemy_body = {
            id = "enemy_body",
            name = "Brittle Body",
            type = "BODY",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.BLANK }),
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            }
        },
        enemy_claw = {
            id = "enemy_claw",
            name = "Gnarled Claw",
            type = "ARM",
            hp_value = 1,
            die = {
                faces = fixed_face({ Symbols.STRIKE }),
                wound_faces = { 1, 2 },
                maim_faces = { 3, 4 }
            }
        }
    },

    loadouts = {
        player_demo = {
            id = "player",
            name = "Dreamer",
            is_player = true,
            crest_pool = {
                Valor = 1,
                Shadow = 1
            },
            parts = {
                "player_head",
                "player_cleaver",
                "player_scholar",
                "player_mixed"
            }
        },
        enemy_demo = {
            id = "enemy",
            name = "Nightmare",
            parts = {
                "enemy_head",
                "enemy_body",
                "enemy_claw"
            }
        }
    }
}
