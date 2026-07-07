return {
    whispering_wall = {
        start = "entry",
        nodes = {
            entry = {
                branches = {
                    {
                        condition = { flag = "basement.whispering_wall_heard" },
                        next = "repeat_visit"
                    },
                    {
                        next = "first_visit"
                    }
                }
            },
            first_visit = {
                speaker = "Wall",
                text = "Something inside the wall whispers through the plaster.",
                next = "listen_choice"
            },
            listen_choice = {
                speaker = "Wall",
                text = "Put your ear to it?",
                responses = {
                    {
                        label = "Yes",
                        next = "listen"
                    },
                    {
                        label = "No",
                        finish = {
                            effects = {
                                { type = "set_flag", flag = "basement.whispering_wall_refused", value = true }
                            }
                        }
                    }
                }
            },
            listen = {
                speaker = "Wall",
                text = "The whisper says your name, then starts climbing out.",
                finish = {
                    effects = {
                        { type = "set_flag", flag = "basement.whispering_wall_heard", value = true }
                    },
                    result = {
                        type = "encounter",
                        encounter_id = "basement.whisperer",
                        text = "The whisper pulls itself loose."
                    }
                }
            },
            repeat_visit = {
                speaker = "Wall",
                text = "The wall is quiet now, but it remembers the shape of your ear.",
                finish = {
                    effects = {
                        { type = "set_flag", flag = "basement.whispering_wall_revisited", value = true }
                    }
                }
            }
        }
    }
}
