return {
    id = "basement_1",
    width = 10,
    height = 8,
    tilewidth = 32,
    tileheight = 32,
    properties = {
        dream = "basement"
    },
    layers = {
        {
            name = "ground",
            type = "tilelayer",
            data = {
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1},
                {1,1,1,1,1,1,1,1,1,1}
            }
        },
        {
            name = "walls",
            type = "tilelayer",
            data = {
                {1,1,1,1,1,1,1,1,1,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,1,1,1,1,1,1,1,1,1}
            }
        },
        {
            name = "collision",
            type = "tilelayer",
            visible = false,
            data = {
                {1,1,1,1,1,1,1,1,1,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,0,0,0,0,0,0,0,0,1},
                {1,1,1,1,1,1,1,1,1,1}
            }
        },
        {
            name = "actors",
            type = "objectgroup",
            objects = {
                {
                    name = "crack_zombie",
                    type = "crack",
                    tile_x = 2,
                    tile_y = 2,
                    properties = {
                        on_tool_use = {
                            tool = "shovel",
                            type = "encounter",
                            encounter_id = "zombie",
                            message = "You dig through the wall. Something stirs in the dark."
                        }
                    }
                },
                {
                    name = "crack_bone_demon",
                    type = "crack",
                    tile_x = 9,
                    tile_y = 4,
                    properties = {
                        on_tool_use = {
                            tool = "shovel",
                            type = "encounter",
                            encounter_id = "bone_demon",
                            message = "You dig into a hollow behind the wall. Bones click awake."
                        }
                    }
                },
                {
                    name = "crack_passage",
                    type = "crack",
                    tile_x = 5,
                    tile_y = 7,
                    properties = {
                        on_tool_use = {
                            tool = "shovel",
                            type = "passage",
                            target_room = "basement_ritual_room",
                            message = "You dig through the wall. Cold air pours through the opening."
                        }
                    }
                },
                {
                    name = "pipe_shovel",
                    type = "pipe",
                    tile_x = 3,
                    tile_y = 2,
                    properties = {
                        item = "shovel",
                        message = "Found: shovel!",
                        empty_message = "An empty drainage pipe."
                    }
                },
                {
                    name = "whispering_wall",
                    type = "message",
                    tile_x = 7,
                    tile_y = 2,
                    properties = {
                        dialog = "data.dialog.basement",
                        dialog_id = "whispering_wall"
                    }
                }
            }
        }
    }
}
