local utf8 = require("utf8")

local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Layouts = require("ui.layouts")
local Engine = require("combat.engine")
local Events = require("combat.events")
local Combatant = require("combat.combatant")

local CombatState = {}
CombatState.__index = CombatState

local MAX_ENGINE_STEPS_PER_FRAME = 4

local function clone_crest_pool(source)
    local copy = {}

    if not source then
        return copy
    end

    for crest, count in pairs(source) do
        copy[crest] = count
    end

    return copy
end

local function copy_body_part(part)
    local status = part.status or "healthy"
    local tags = {}

    if part.tags then
        for index, tag in ipairs(part.tags) do
            tags[index] = tag
        end
    end

    local copied = {
        id = part.id,
        name = part.name,
        type = part.type,
        status = status,
        toughness = part.toughness or 0,
        hp_value = part.hp_value or 0,
        techs = part.techs,
        tags = tags,
        layout_slot = part.layout_slot,
        slot = part.slot,
        asset_base = part.id or "placeholder"
    }

    copied.asset_id = (copied.asset_base or "placeholder") .. "_" .. status

    return copied
end

local function build_ui_state(engine)
    local state = {
        combatants = {},
        combatant_lookup = setmetatable({}, { __mode = "k" }),
        part_lookup = setmetatable({}, { __mode = "k" })
    }

    if not engine then
        return state
    end

    for index, combatant in ipairs(engine.combatants or {}) do
        local view = {
            id = combatant.id,
            name = combatant.name,
            is_player = combatant.is_player or false,
            is_enemy = combatant.is_enemy or false,
            heart_points = combatant.heart_points or 0,
            crest_pool = clone_crest_pool(combatant.crest_pool),
            body_parts = {}
        }

        state.combatants[index] = view
        state.combatant_lookup[combatant] = view

        for part_index, part in ipairs(combatant.body_parts or {}) do
            local part_view = copy_body_part(part)
            view.body_parts[part_index] = part_view
            state.part_lookup[part] = part_view
        end
    end

    return state
end

local function update_part_asset_id(part_view)
    if not part_view then
        return
    end

    local base = part_view.asset_base or part_view.id or "placeholder"
    local status = part_view.status or "healthy"
    part_view.asset_id = base .. "_" .. status
end

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
        is_player = false,
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
    self.ui_state = build_ui_state(self.engine)
    self:register_event_listeners()

    self.engine:start_combat()
    self:refresh_ui_state()
    self.engine:process_state()
end

function CombatState:update(dt)
    if not self.engine then
        return
    end

    local steps = 0

    while self.engine and not self.engine:needs_input() and steps < MAX_ENGINE_STEPS_PER_FRAME do
        self.engine:process_state()
        steps = steps + 1
    end
end

function CombatState:refresh_ui_state()
    self.ui_state = build_ui_state(self.engine)
end

function CombatState:get_combatant_view(combatant)
    if not self.ui_state then
        return nil
    end

    local view = self.ui_state.combatant_lookup[combatant]

    if not view then
        self:refresh_ui_state()
        if self.ui_state then
            view = self.ui_state.combatant_lookup[combatant]
        end
    end

    return view
end

function CombatState:get_body_part_view(part)
    if not self.ui_state then
        return nil
    end

    local view = self.ui_state.part_lookup[part]

    if not view then
        self:refresh_ui_state()
        if self.ui_state then
            view = self.ui_state.part_lookup[part]
        end
    end

    return view
end

function CombatState:handle_bp_status_changed(data)
    if not data then
        return
    end

    local part_view = self:get_body_part_view(data.body_part)
    if not part_view then
        return
    end

    part_view.status = data.new_status or data.body_part and data.body_part.status or part_view.status
    part_view.toughness = data.body_part and data.body_part.toughness or part_view.toughness
    part_view.name = data.body_part and data.body_part.name or part_view.name
    update_part_asset_id(part_view)
end

function CombatState:handle_damage_dealt(data)
    if not data then
        return
    end

    local target = data.target
    if not target then
        return
    end

    local target_view = self:get_combatant_view(target)
    if not target_view then
        return
    end

    if target.heart_points ~= nil then
        target_view.heart_points = target.heart_points
    elseif data.heart_point_loss then
        local current = target_view.heart_points or 0
        local updated = math.max(0, current - data.heart_point_loss)
        target_view.heart_points = updated
    end
end

local function update_crest_count(view, crest, new_value)
    if not view or not crest then
        return
    end

    if new_value == nil then
        return
    end

    view.crest_pool = view.crest_pool or {}

    if new_value <= 0 then
        view.crest_pool[crest] = 0
        return
    end

    view.crest_pool[crest] = new_value
end

function CombatState:handle_crest_gained(data)
    if not data then
        return
    end

    local combatant = data.combatant
    local crest = data.crest

    local view = self:get_combatant_view(combatant)
    if not view then
        return
    end

    local total = data.total
    if total == nil and combatant and combatant.get_crest_count then
        total = combatant:get_crest_count(crest)
    end

    update_crest_count(view, crest, total)
end

function CombatState:handle_crest_expended(data)
    if not data then
        return
    end

    local combatant = data.combatant
    local crest = data.crest

    local view = self:get_combatant_view(combatant)
    if not view then
        return
    end

    local remaining = data.remaining
    if remaining == nil and combatant and combatant.get_crest_count then
        remaining = combatant:get_crest_count(crest)
    end

    update_crest_count(view, crest, remaining)
end

function CombatState:register_event_listeners()
    if not self.engine then
        return
    end

    self.engine:on(Events.BP_STATUS_CHANGED, function(data)
        self:handle_bp_status_changed(data)
    end)

    self.engine:on(Events.DAMAGE_DEALT, function(data)
        self:handle_damage_dealt(data)
    end)

    self.engine:on(Events.CREST_GAINED, function(data)
        self:handle_crest_gained(data)
    end)

    self.engine:on(Events.CREST_EXPENDED, function(data)
        self:handle_crest_expended(data)
    end)
end

local function draw_body_part(part, x, y)
    local sprite_size = Layouts.get_sprite_size()
    local status = part.status or "healthy"
    local asset_id = part.asset_id

    if not asset_id then
        local asset_base = part.asset_base or part.id or "placeholder"
        asset_id = asset_base .. "_" .. status
    end

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

    for index, combatant in ipairs(self.ui_state and self.ui_state.combatants or {}) do
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
