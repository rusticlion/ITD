return {
    combat = {
        {
            id = "combat.zombie",
            name = "Zombie",
            description = "Baseline Regrowth and headshot-route encounter.",
            encounter_id = "basement.zombie",
            seed = 1101
        },
        {
            id = "combat.bone_demon",
            name = "Bone Demon",
            description = "Baseline caster encounter with Speak Doom and Bonestorm.",
            encounter_id = "basement.bone_demon",
            seed = 2201
        },
        {
            id = "combat.mad_butcher",
            name = "Mad Butcher",
            description = "Baseline boss route puzzle.",
            encounter_id = "basement.mad_butcher",
            seed = 3301
        },
        {
            id = "combat.butcher_pressure",
            name = "Butcher: Pressure",
            description = "Two player wounds and two banked Sadism pips; Upkeep triggers Sadism.",
            encounter_id = "basement.mad_butcher",
            seed = 3302,
            combat_setup = {
                player = {
                    statuses = {
                        dreamer_fore_hand = "wounded",
                        dreamer_back_foot = "wounded"
                    }
                },
                enemy = {
                    slot_charge = {
                        butcher_welding_mask = { 1, 2 }
                    }
                }
            }
        }
    },

    overworld = {
        {
            id = "basement.start",
            name = "Basement: Dark Start",
            description = "Fresh isolated run at the beginning of the dream.",
            room = "data.rooms.basement_1",
            spawn = "start",
            player = {
                facing = "up"
            }
        },
        {
            id = "basement.tools",
            name = "Basement: Tools Found",
            description = "Flashlight and shovel acquired; flashlight equipped.",
            room = "data.rooms.basement_1",
            spawn = "tools",
            player = {
                facing = "up",
                inventory = {
                    flashlight = true,
                    shovel = true
                },
                equipped = "flashlight"
            },
            flags = {
                ["basement.flashlight_found"] = true,
                ["basement.shovel_found"] = true
            },
            room_states = {
                basement_1 = {
                    pipe_shovel = { removed = true }
                }
            }
        },
        {
            id = "basement.hidden_dark",
            name = "Basement: Hidden Chamber",
            description = "All cracks resolved; hidden chamber entered before the lights come on.",
            room = "data.rooms.basement_1",
            spawn = "hidden_dark",
            player = {
                facing = "down",
                inventory = {
                    flashlight = true,
                    shovel = true
                },
                equipped = "flashlight"
            },
            flags = {
                ["basement.flashlight_found"] = true,
                ["basement.shovel_found"] = true,
                ["basement.passage_open"] = true
            },
            encounters = {
                ["basement.zombie"] = { resolved = true, last_outcome = "victory" },
                ["basement.bone_demon"] = { resolved = true, last_outcome = "victory" }
            },
            room_states = {
                basement_1 = {
                    pipe_shovel = { removed = true },
                    crack_zombie = { resolved = true },
                    crack_bone_demon = { resolved = true },
                    crack_passage = { resolved = true }
                }
            }
        },
        {
            id = "basement.boss_ready",
            name = "Basement: Boss Door",
            description = "Murder basement lit, key acquired, and the exit ready for the Butcher beat.",
            room = "data.rooms.basement_1",
            spawn = "boss_ready",
            player = {
                facing = "down",
                inventory = {
                    flashlight = true,
                    shovel = true,
                    rusty_key = true
                },
                equipped = "rusty_key"
            },
            flags = {
                ["basement.flashlight_found"] = true,
                ["basement.shovel_found"] = true,
                ["basement.passage_open"] = true,
                ["basement.lights_on"] = true,
                ["basement.key_found"] = true,
                ["basement.boss_door_unlocked"] = true
            },
            encounters = {
                ["basement.zombie"] = { resolved = true, last_outcome = "victory" },
                ["basement.bone_demon"] = { resolved = true, last_outcome = "victory" }
            },
            room_states = {
                basement_1 = {
                    pipe_shovel = { removed = true },
                    crack_zombie = { resolved = true },
                    crack_bone_demon = { resolved = true },
                    crack_passage = { resolved = true }
                }
            }
        }
    }
}
