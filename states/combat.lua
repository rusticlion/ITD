local utf8 = require("utf8")

local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Layouts = require("ui.layouts")
local Engine = require("combat.engine")
local Combatant = require("combat.combatant")

local CombatState = {}
CombatState.__index = CombatState

local function create_player_combatant()
    local body_parts = {
        {
            id = "dreamer_head",
            name = "Astral Visage",
            type = "head",
            status = "healthy",
            toughness = 2,
            hp_value = 1,
            techs = {
                {
                    id = "lucid_gaze",
                    name = "Lucid Gaze",
                    actions = {
                        { type = "attack_roll", name = "Lucid Strike", dice_count = 2, dice_type = "d4", damage = 1 },
                        { type = "defense_roll", name = "Astral Veil", dice_count = 1, dice_type = "d4" }
                    }
                }
            }
        },
        {
            id = "dreamer_torso",
            name = "Liminal Core",
            type = "torso",
            status = "healthy",
            toughness = 3,
            hp_value = 1,
            techs = {
                {
                    id = "steady_breath",
                    name = "Steady Breath",
                    actions = {
                        { type = "defense_roll", name = "Composed Guard", dice_count = 1, dice_type = "d6" }
                    }
                }
            }
        },
        {
            id = "dreamer_arm_left",
            name = "Mnemonic Grip",
            type = "arm_left",
            status = "wounded",
            toughness = 2,
            hp_value = 1,
            techs = {
                {
                    id = "memory_shear",
                    name = "Memory Shear",
                    actions = {
                        { type = "attack_roll", name = "Mnemonic Cut", dice_count = 1, dice_type = "d6", damage = 1 }
                    }
                }
            }
        },
        {
            id = "dreamer_arm_right",
            name = "Aether Reach",
            type = "arm_right",
            status = "healthy",
            toughness = 2,
            hp_value = 1,
            techs = {
                {
                    id = "projection",
                    name = "Projection",
                    actions = {
                        { type = "attack_roll", name = "Astral Jab", dice_count = 1, dice_type = "d6", damage = 1 }
                    }
                }
            }
        },
        {
            id = "dreamer_leg_left",
            name = "Gliding Step",
            type = "leg_left",
            status = "healthy",
            toughness = 2,
            hp_value = 1,
            techs = {
                {
                    id = "sidestep",
                    name = "Sidestep",
                    actions = {
                        { type = "defense_roll", name = "Flowing Evasion", dice_count = 1, dice_type = "d6" }
                    }
                }
            }
        },
        {
            id = "dreamer_leg_right",
            name = "Anchoring Stride",
            type = "leg_right",
            status = "healthy",
            toughness = 2,
            hp_value = 1,
            techs = {
                {
                    id = "grounding_kick",
                    name = "Grounding Kick",
                    actions = {
                        { type = "attack_roll", name = "Forceful Kick", dice_count = 1, dice_type = "d6", damage = 1 }
                    }
                }
            }
        }
    }

    return Combatant:new({
        id = "player_demo",
        name = "The Dreamer",
        is_player = true,
        heart_points = 3,
        crest_pool = { Valor = 1, Shadow = 2 },
        body_parts = body_parts
    })
end

local function create_enemy_combatant()
    local body_parts = {
        {
            id = "placeholder",
            name = "Hollow Visor",
            type = "head",
            status = "healthy",
            toughness = 1,
            hp_value = 1,
            techs = {
                {
                    id = "glare",
                    name = "Gloom Glare",
                    actions = {
                        { type = "attack_roll", name = "Piercing Glare", dice_count = 1, dice_type = "d4", damage = 1 }
                    }
                }
            }
        },
        {
            id = "placeholder",
            name = "Threadbare Husk",
            type = "torso",
            status = "wounded",
            toughness = 2,
            hp_value = 1,
            techs = {}
        },
        {
            id = "nightmare_arm_left",
            name = "Raveled Claw",
            type = "arm_left",
            status = "healthy",
            toughness = 1,
            hp_value = 1,
            techs = {
                {
                    id = "snatch",
                    name = "Snatch",
                    actions = {
                        { type = "attack_roll", name = "Snare", dice_count = 1, dice_type = "d6", damage = 1 }
                    }
                }
            }
        },
        {
            id = "nightmare_arm_right",
            name = "Splinter Lash",
            type = "arm_right",
            status = "maimed",
            toughness = 0,
            hp_value = 1,
            techs = {}
        },
        {
            id = "nightmare_leg_left",
            name = "Staggered Limb",
            type = "leg_left",
            status = "healthy",
            toughness = 1,
            hp_value = 1,
            techs = {
                {
                    id = "lurch",
                    name = "Lurch",
                    actions = {
                        { type = "attack_roll", name = "Wild Swing", dice_count = 1, dice_type = "d8", damage = 1 }
                    }
                }
            }
        },
        {
            id = "nightmare_leg_right",
            name = "Drifting Limb",
            type = "leg_right",
            status = "healthy",
            toughness = 1,
            hp_value = 1,
            techs = {}
        }
    }

    return Combatant:new({
        id = "enemy_demo",
        name = "Dream Eater",
        is_enemy = true,
        heart_points = 2,
        crest_pool = { Madness = 1 },
        body_parts = body_parts
    })
end

function CombatState:enter()
    self.engine = Engine:new()
    self.input_buffer = ""
    self.background_color = { 0.05, 0.06, 0.09, 1 }

    local player = create_player_combatant()
    local enemy = create_enemy_combatant()

    self.engine:add_combatant(player)
    self.engine:add_combatant(enemy)
    self.engine:start_combat()
    self.engine:process_state()
end

function CombatState:update(dt)
    if not self.engine then
        return
    end

    if not self.engine:needs_input() then
        self.engine:process_state()
    end
end

local function draw_body_part(part, x, y)
    local sprite_size = Layouts.get_sprite_size()
    local status = part.status or "healthy"
    local asset_base = part.id or "placeholder"
    local asset_id = asset_base .. "_" .. status
    local image = Assets:get(asset_id)

    love.graphics.setColor(1, 1, 1, 1)
    if image then
        love.graphics.draw(image, x, y)
    else
        love.graphics.rectangle("line", x, y, sprite_size, sprite_size)
    end

    local label_y = y + sprite_size + 4
    love.graphics.printf(part.name or part.id or "", x, label_y, sprite_size, "center")

    local status_label = status:gsub("^%l", string.upper)
    love.graphics.printf(status_label, x, label_y + 14, sprite_size, "center")

    love.graphics.printf("T " .. tostring(part.toughness or 0), x, y - 18, sprite_size, "center")
end

local function draw_combatant(combatant, index)
    local sprite_size = Layouts.get_sprite_size()
    local name_x, name_y, name_width = Layouts.get_name_region(combatant, index)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(combatant.name or "", name_x, name_y, name_width, "center")

    for _, part in ipairs(combatant.body_parts or {}) do
        local px, py = Layouts.get_body_part_position(combatant, index, part)
        draw_body_part(part, px, py)
    end

    local heart_x, heart_y = Layouts.get_heart_position(combatant, index)
    love.graphics.print("HP: " .. tostring(combatant.heart_points or 0), heart_x, heart_y)

    local crest_x, crest_y, crest_width = Layouts.get_crest_region(combatant, index)
    local crest_entries = {}
    for crest, count in pairs(combatant.crest_pool or {}) do
        if (count or 0) > 0 then
            table.insert(crest_entries, string.format("%s: %d", crest, count))
        end
    end
    table.sort(crest_entries)

    local crest_text = #crest_entries > 0 and table.concat(crest_entries, "    ") or "No Crests"
    love.graphics.printf("Crests: " .. crest_text, crest_x, crest_y, crest_width, "center")

    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("line", name_x, name_y + sprite_size * 1.6, name_width, sprite_size * 1.6)
    love.graphics.setColor(1, 1, 1, 1)
end

function CombatState:draw()
    if self.background_color then
        love.graphics.clear(self.background_color[1], self.background_color[2], self.background_color[3], self.background_color[4])
    else
        love.graphics.clear(0, 0, 0, 1)
    end

    if not self.engine then
        return
    end

    for index, combatant in ipairs(self.engine.combatants or {}) do
        draw_combatant(combatant, index)
    end

    if self.engine:needs_input() then
        local prompt = self.engine:get_input_prompt()
        local x, y, width = Layouts.get_prompt_region()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(prompt or "", x, y, width, "left")
        love.graphics.printf("> " .. (self.input_buffer or ""), x, y + 18, width, "left")
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.rectangle("line", x - 4, y - 6, width + 8, 36)
        love.graphics.setColor(1, 1, 1, 1)
    else
        local x, y, width = Layouts.get_prompt_region()
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Press ESC to return to the overworld", x, y, width, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function CombatState:keypressed(key)
    if key == "escape" then
        GameState.switch(require("states.overworld"))
        return
    end

    if key == "return" or key == "kpenter" then
        if self.engine and self.engine:needs_input() then
            self.engine:provide_input(self.input_buffer or "")
            self.input_buffer = ""
        end
    elseif key == "backspace" then
        if self.input_buffer and #self.input_buffer > 0 then
            local byteoffset = utf8.offset(self.input_buffer, -1)
            if byteoffset then
                self.input_buffer = self.input_buffer:sub(1, byteoffset - 1)
            else
                self.input_buffer = ""
            end
        end
    end
end

function CombatState:textinput(text)
    if self.engine and self.engine:needs_input() then
        self.input_buffer = (self.input_buffer or "") .. text
    end
end

return CombatState
