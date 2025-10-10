local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Layouts = require("ui.layouts")
local Engine = require("combat.engine")
local Events = require("combat.events")
local Combatant = require("combat.combatant")

local CombatState = {}
CombatState.__index = CombatState

local MAX_ENGINE_STEPS_PER_FRAME = 4

local TECH_CARD_WIDTH = 176
local TECH_CARD_HEIGHT = 72
local TECH_CARD_SPACING = 10
local TECH_CARD_GAP = 20
local TECH_CARD_CORNER_RADIUS = 12
local TECH_FAN_STICKY_MARGIN = 28

local PANEL_CORNER_RADIUS = 14
local PANEL_SPACING = 14
local SELECTED_PANEL_HEIGHT = 96
local DICE_PANEL_HEIGHT = 110

local DIE_TOKEN_SIZE = 64
local DIE_TOKEN_RADIUS = 10
local DIE_TOKEN_SPACING = 14
local DICE_SHELF_HEIGHT = DIE_TOKEN_SIZE + 32

local PROMPT_BUTTON_WIDTH = 220
local PROMPT_BUTTON_HEIGHT = 56
local PROMPT_BUTTON_SPACING = 12
local PROMPT_BUTTON_RADIUS = 12
local PROMPT_PANEL_HEADER = 72
local PROMPT_PANEL_BOTTOM_PADDING = 24

local function point_in_rect(x, y, rect)
    if not rect then
        return false
    end

    return x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function normalize_dice_type(dice_type)
    if not dice_type or dice_type == "" then
        return "d6"
    end

    if type(dice_type) == "number" then
        return "d" .. tostring(dice_type)
    end

    local str = tostring(dice_type)
    if str:match("^d%d+") then
        return str
    end

    return "d" .. str
end

local function format_dice_label(count, dice_type)
    if not count or count <= 0 then
        return nil
    end

    local type_label = normalize_dice_type(dice_type)
    return string.format("%d%s", count, type_label)
end

local function draw_highlight_fill(rect, is_hovered)
    local alpha = is_hovered and 0.32 or 0.18
    love.graphics.setColor(0.18, 0.45, 0.85, alpha)
    love.graphics.rectangle("fill", rect.x - 6, rect.y - 6, rect.w + 12, rect.h + 12, 12, 12)
    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_highlight_outline(rect, is_hovered)
    local alpha = is_hovered and 0.9 or 0.4
    love.graphics.setColor(0.45, 0.8, 1, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x - 6, rect.y - 6, rect.w + 12, rect.h + 12, 12, 12)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function get_player_shelf_rect()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    local shelf_width = math.min(width * 0.36, 360)
    local shelf_height = DICE_SHELF_HEIGHT
    local x = width * 0.08
    local y = height - shelf_height - 120

    return x, y, shelf_width, shelf_height
end

local function get_enemy_shelf_rect()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    local shelf_width = math.min(width * 0.36, 360)
    local shelf_height = DICE_SHELF_HEIGHT
    local x = width - shelf_width - width * 0.08
    local y = height - shelf_height - 120

    return x, y, shelf_width, shelf_height
end

local function draw_die_token(die, is_hovered, is_dragging)
    if not die or not die.rect then
        return
    end

    local rect = die.rect
    local fill = { 0.14, 0.32, 0.55, 0.82 }
    local outline = { 0.58, 0.86, 1, 0.95 }

    if die.assigned then
        fill = { 0.12, 0.34, 0.25, 0.85 }
        outline = { 0.48, 0.88, 0.64, 0.95 }
    elseif die.interactable then
        fill = { 0.18, 0.46, 0.78, 0.9 }
        outline = { 0.62, 0.88, 1, 0.95 }
    else
        fill = { 0.1, 0.24, 0.38, 0.75 }
        outline = { 0.35, 0.6, 0.9, 0.7 }
    end

    if is_hovered or is_dragging then
        outline = { 1, 1, 1, 1 }
    end

    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, DIE_TOKEN_RADIUS, DIE_TOKEN_RADIUS)

    love.graphics.setColor(outline)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, DIE_TOKEN_RADIUS, DIE_TOKEN_RADIUS)
    love.graphics.setLineWidth(1)

    local title = die.label or ""
    local subtitle = die.subtitle or ""

    love.graphics.setColor(1, 1, 1, 0.95)
    love.graphics.printf(title, rect.x + 8, rect.y + 10, rect.w - 16, "center")

    if subtitle ~= "" then
        love.graphics.setColor(0.85, 0.95, 1, 0.88)
        love.graphics.printf(subtitle, rect.x + 8, rect.y + rect.h - 26, rect.w - 16, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_panel_background(x, y, w, h, intensity)
    local base_alpha = intensity or 0.88
    love.graphics.setColor(0.07, 0.1, 0.16, base_alpha)
    love.graphics.rectangle("fill", x, y, w, h, PANEL_CORNER_RADIUS, PANEL_CORNER_RADIUS)
    love.graphics.setColor(0.35, 0.7, 1, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, PANEL_CORNER_RADIUS, PANEL_CORNER_RADIUS)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

local function draw_tech_card(option, is_hovered)
    local rect = option and option.card_rect or nil
    if not rect then
        return
    end

    local fill_alpha = is_hovered and 0.95 or 0.82
    local border_alpha = is_hovered and 1 or 0.55

    love.graphics.setColor(0.11, 0.18, 0.28, fill_alpha)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, TECH_CARD_CORNER_RADIUS, TECH_CARD_CORNER_RADIUS)

    love.graphics.setColor(0.58, 0.86, 1, border_alpha)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, TECH_CARD_CORNER_RADIUS, TECH_CARD_CORNER_RADIUS)
    love.graphics.setLineWidth(1)

    local text_x = rect.x + 14
    local text_width = rect.w - 28

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(option.tech_name or option.metadata and option.metadata.tech_name or "Tech", text_x, rect.y + 8, text_width, "left")

    if option.body_part_name and option.body_part_name ~= "" then
        love.graphics.setColor(0.78, 0.88, 1, 0.9)
        love.graphics.printf(option.body_part_name, text_x, rect.y + 30, text_width, "left")
    end

    if option.summary and option.summary ~= "" then
        love.graphics.setColor(0.85, 0.92, 1, 0.85)
        love.graphics.printf(option.summary, text_x, rect.y + rect.h - 24, text_width, "left")
    end

    if option.selection_index then
        love.graphics.setColor(0.75, 0.85, 1, 0.65)
        love.graphics.printf("#" .. tostring(option.selection_index), rect.x + rect.w - 34, rect.y + 8, 24, "right")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

local function draw_prompt_button(button, is_hovered)
    if not button or not button.rect then
        return
    end

    local rect = button.rect
    local fill = is_hovered and { 0.16, 0.4, 0.72, 0.92 } or { 0.12, 0.26, 0.42, 0.85 }
    local outline = is_hovered and { 0.96, 0.98, 1, 1 } or { 0.58, 0.86, 1, 0.9 }

    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, PROMPT_BUTTON_RADIUS, PROMPT_BUTTON_RADIUS)

    love.graphics.setColor(outline)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, PROMPT_BUTTON_RADIUS, PROMPT_BUTTON_RADIUS)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1, 0.96)
    love.graphics.printf(button.label or "", rect.x + 14, rect.y + 12, rect.w - 28, "center")

    if button.subtitle and button.subtitle ~= "" then
        love.graphics.setColor(0.82, 0.92, 1, 0.85)
        love.graphics.printf(button.subtitle, rect.x + 14, rect.y + rect.h - 26, rect.w - 28, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

local function build_tech_summary(tech)
    if not tech or not tech.actions then
        return ""
    end

    local segments = {}

    for _, action in ipairs(tech.actions) do
        if action.type == "attack_roll" or action.type == "defense_roll" then
            local prefix = action.type == "attack_roll" and "ATK" or "DEF"
            local dice_label = format_dice_label(action.dice_count, action.dice_type)
            if dice_label then
                table.insert(segments, string.format("%s %s", prefix, dice_label))
            end
        end
    end

    return table.concat(segments, "  ")
end

local function collect_dice_lines(tech)
    local lines = {}

    if not tech or not tech.actions then
        return lines
    end

    for _, action in ipairs(tech.actions) do
        if action.type == "attack_roll" or action.type == "defense_roll" then
            local label = action.type == "attack_roll" and "Attack" or "Defense"
            local dice_label = format_dice_label(action.dice_count, action.dice_type)
            local name = action.name or ""

            if dice_label and name ~= "" then
                table.insert(lines, string.format("%s: %s (%s)", label, dice_label, name))
            elseif dice_label then
                table.insert(lines, string.format("%s: %s", label, dice_label))
            elseif name ~= "" then
                table.insert(lines, string.format("%s: %s", label, name))
            end
        end
    end

    return lines
end

local function collect_keyword_list(tech)
    local keywords = {}

    if not tech or not tech.keywords then
        return keywords
    end

    for key, value in pairs(tech.keywords) do
        if type(value) == "boolean" then
            if value then
                table.insert(keywords, key)
            end
        elseif value ~= nil then
            table.insert(keywords, string.format("%s %s", key, tostring(value)))
        end
    end

    table.sort(keywords)

    return keywords
end

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

        view.index = index

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
    self.background_color = { 0.05, 0.06, 0.09, 1 }
    self.mouse_position = { x = 0, y = 0 }
    self.tech_selection_ui = nil
    self.assignment_ui = nil
    self.prompt_ui = nil

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

    self:update_mouse_position()
    self:update_interactive_input()
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

function CombatState:update_mouse_position(x, y)
    if not self.mouse_position then
        self.mouse_position = { x = 0, y = 0 }
    end

    if x and y then
        self.mouse_position.x = x
        self.mouse_position.y = y
        return
    end

    if love and love.mouse and love.mouse.getPosition then
        local mx, my = love.mouse.getPosition()
        self.mouse_position.x = mx
        self.mouse_position.y = my
    end
end

function CombatState:build_tech_selection_context(metadata)
    if not metadata then
        return nil
    end

    local context = {
        metadata = metadata,
        combatant = metadata.combatant,
        options = {},
        option_lookup = {},
        part_entries = {},
        part_lookup = {},
        parts_by_view = {},
        hovered_part_entry = nil,
        hovered_option = nil,
        active_part_entry = nil,
        preview_option = nil,
        mouse_x = self.mouse_position and self.mouse_position.x or 0,
        mouse_y = self.mouse_position and self.mouse_position.y or 0,
        sticky_margin = TECH_FAN_STICKY_MARGIN,
        active = true
    }

    local combatant_view = metadata.combatant and self:get_combatant_view(metadata.combatant) or nil
    context.combatant_view = combatant_view
    context.combatant_index = combatant_view and combatant_view.index or nil

    if combatant_view then
        context.side = Layouts.get_combatant_side(combatant_view, context.combatant_index)
    end

    for option_index, option in ipairs(metadata.options or {}) do
        local tech = option.tech or option
        local body_part = option.body_part or option.source_part or nil
        local part_view = body_part and self:get_body_part_view(body_part) or nil

        local entry = nil
        if body_part then
            entry = context.part_lookup[body_part]
            if not entry then
                entry = { part = body_part, view = part_view, options = {}, rect = nil }
                context.part_lookup[body_part] = entry
                table.insert(context.part_entries, entry)
            end
        else
            entry = context.part_lookup.__fallback
            if not entry then
                entry = { part = nil, view = part_view, options = {}, rect = nil }
                context.part_lookup.__fallback = entry
                table.insert(context.part_entries, entry)
            end
        end

        local card_option = {
            index = option_index,
            selection_index = option.index or option_index,
            tech = tech,
            tech_name = option.tech_name or (tech and (tech.name or tech.id)) or ("Tech " .. option_index),
            body_part = body_part,
            body_part_name = option.body_part_name or (body_part and (body_part.name or body_part.id)) or nil,
            summary = build_tech_summary(tech),
            dice_lines = collect_dice_lines(tech),
            keywords = collect_keyword_list(tech),
            metadata = option,
            card_rect = nil
        }

        table.insert(entry.options, card_option)
        table.insert(context.options, card_option)
        context.option_lookup[card_option.selection_index] = card_option

        if part_view then
            context.parts_by_view[part_view] = entry
        end
    end

    return context
end

local function gather_assignment_actions(tech, desired_type)
    local actions = {}

    if not tech or not tech.actions then
        return actions
    end

    for index, action in ipairs(tech.actions) do
        if action.type == desired_type then
            table.insert(actions, { index = index, action = action })
        end
    end

    return actions
end

function CombatState:sync_assignment_dice(context)
    if not context then
        return
    end

    local combatant = context.combatant
    local tech = combatant and combatant.selected_tech
    local desired_type = context.mode == "attack" and "attack_roll" or "defense_roll"

    context.dice_map = context.dice_map or {}
    local new_order = {}
    local seen = {}

    local assignments = nil
    if self.engine then
        if context.mode == "attack" then
            assignments = self.engine.attack_assignments and self.engine.attack_assignments[combatant]
        else
            assignments = self.engine.defense_assignments and self.engine.defense_assignments[combatant]
        end
    end

    for _, info in ipairs(gather_assignment_actions(tech, desired_type)) do
        local action_index = info.index
        local action = info.action
        local die = context.dice_map[action_index]

        if not die then
            die = {
                rect = { x = 0, y = 0, w = DIE_TOKEN_SIZE, h = DIE_TOKEN_SIZE },
                home = { x = 0, y = 0 }
            }
            context.dice_map[action_index] = die
        end

        die.action = action
        die.action_index = action_index
        die.label = action.name or (context.mode == "attack" and "Attack" or "Defense")
        die.subtitle = format_dice_label(action.dice_count, action.dice_type) or ""
        die.assigned = false
        die.assigned_option = nil
        die.assigned_part_view = nil
        die.interactable = (context.metadata and context.metadata.action_index == action_index)

        if assignments then
            for _, assignment in ipairs(assignments) do
                if assignment.action_index == action_index and assignment.target_part then
                    die.assigned = true
                    die.assigned_option = assignment
                    die.assigned_part_view = self:get_body_part_view(assignment.target_part)
                    break
                end
            end
        end

        die.rect.w = DIE_TOKEN_SIZE
        die.rect.h = DIE_TOKEN_SIZE

        seen[action_index] = true
        table.insert(new_order, die)
    end

    for key, value in pairs(context.dice_map) do
        if not seen[key] then
            context.dice_map[key] = nil
        end
    end

    context.dice = new_order
end

function CombatState:update_assignment_target_rects(context)
    if not context then
        return
    end

    local target_view = context.target_combatant_view
    if not target_view then
        context.target_parts_by_view = {}
        return
    end

    local sprite_size = Layouts.get_sprite_size()
    local index = target_view.index or 1
    local mapping = {}

    for _, entry in ipairs(context.target_entries or {}) do
        local part_view = entry.part_view
        if part_view then
            entry.rect = entry.rect or {}
            local px, py = Layouts.get_body_part_position(target_view, index, part_view)
            entry.rect.x = px
            entry.rect.y = py
            entry.rect.w = sprite_size
            entry.rect.h = sprite_size
            mapping[part_view] = entry
        end
    end

    context.target_parts_by_view = mapping
end

function CombatState:collect_enemy_assignments(context)
    local assignments = {}

    if not (self.engine and context and context.opponent_combatant) then
        return assignments
    end

    local source = nil
    if context.mode == "attack" then
        source = self.engine.attack_assignments and self.engine.attack_assignments[context.opponent_combatant]
    else
        source = self.engine.defense_assignments and self.engine.defense_assignments[context.opponent_combatant]
    end

    if not source then
        return assignments
    end

    local target_view = nil
    if context.mode == "attack" then
        target_view = context.combatant_view
    else
        target_view = context.opponent_view
    end

    if not target_view then
        return assignments
    end

    for _, assignment in ipairs(source) do
        local part = assignment.target_part
        local part_view = self:get_body_part_view(part)
        if part_view then
            table.insert(assignments, {
                action = assignment.action,
                action_index = assignment.action_index,
                part = part,
                part_view = part_view,
                target_view = target_view,
                label = format_dice_label(assignment.action and assignment.action.dice_count, assignment.action and assignment.action.dice_type)
                    or (context.mode == "attack" and "ATK" or "DEF")
            })
        end
    end

    return assignments
end

function CombatState:layout_assignment_dice(context)
    if not context then
        return
    end

    local shelf_x, shelf_y, shelf_w, shelf_h = get_player_shelf_rect()
    context.shelf_rect = { x = shelf_x, y = shelf_y, w = shelf_w, h = shelf_h }

    local sprite_size = Layouts.get_sprite_size()
    local unassigned = {}

    for _, die in ipairs(context.dice or {}) do
        die.rect = die.rect or { x = shelf_x, y = shelf_y, w = DIE_TOKEN_SIZE, h = DIE_TOKEN_SIZE }
        die.rect.w = DIE_TOKEN_SIZE
        die.rect.h = DIE_TOKEN_SIZE

        if die.assigned and die.assigned_part_view and context.target_combatant_view then
            local px, py = Layouts.get_body_part_position(context.target_combatant_view, context.target_combatant_view.index or 1, die.assigned_part_view)
            local cx = px + sprite_size * 0.5 - DIE_TOKEN_SIZE * 0.5
            local cy = py + sprite_size * 0.5 - DIE_TOKEN_SIZE * 0.5

            die.home = die.home or {}
            die.home.x = cx
            die.home.y = cy

            if not (context.dragging and context.dragging.die == die) then
                die.rect.x = cx
                die.rect.y = cy
            end
        else
            table.insert(unassigned, die)
        end
    end

    if #unassigned > 0 then
        local spacing = DIE_TOKEN_SPACING
        local total_width = (#unassigned) * DIE_TOKEN_SIZE + math.max(0, (#unassigned - 1) * spacing)
        local start_x = shelf_x + math.max(0, (shelf_w - total_width) * 0.5)
        local y = shelf_y + (shelf_h - DIE_TOKEN_SIZE) * 0.5

        for index, die in ipairs(unassigned) do
            local target_x = start_x + (index - 1) * (DIE_TOKEN_SIZE + spacing)
            if not (context.dragging and context.dragging.die == die) then
                die.rect.x = target_x
                die.rect.y = y
            end

            die.home = die.home or {}
            die.home.x = target_x
            die.home.y = y
        end
    end

    if context.dragging and context.dragging.die then
        local die = context.dragging.die
        die.rect.x = context.mouse_x - (context.dragging.offset_x or 0)
        die.rect.y = context.mouse_y - (context.dragging.offset_y or 0)
    end
end

function CombatState:evaluate_assignment_hover(context)
    if not context then
        return
    end

    local mx = context.mouse_x or 0
    local my = context.mouse_y or 0

    context.hovered_die = nil
    if not (context.dragging and context.dragging.die) then
        for _, die in ipairs(context.dice or {}) do
            if die.interactable and not die.assigned and point_in_rect(mx, my, die.rect) then
                context.hovered_die = die
                break
            end
        end
    end

    context.hovered_target = nil
    for _, entry in ipairs(context.target_entries or {}) do
        if point_in_rect(mx, my, entry.rect) then
            context.hovered_target = entry
            break
        end
    end

    context.highlight = context.highlight or { parts_by_view = {} }
    context.highlight.parts_by_view = context.target_parts_by_view or {}
    context.highlight.hovered_part_entry = context.hovered_target
end

function CombatState:update_assignment_context(context)
    if not context then
        return
    end

    self:sync_assignment_dice(context)
    self:update_assignment_target_rects(context)
    context.enemy_assignments = self:collect_enemy_assignments(context)

    context.mouse_x = self.mouse_position and self.mouse_position.x or context.mouse_x or 0
    context.mouse_y = self.mouse_position and self.mouse_position.y or context.mouse_y or 0

    self:layout_assignment_dice(context)
    self:evaluate_assignment_hover(context)
end

function CombatState:build_assignment_context(metadata)
    if not metadata then
        return nil
    end

    local mode = metadata.type == "attack_assignment" and "attack" or "defense"
    local combatant = metadata.combatant

    local context = {
        metadata = metadata,
        type = metadata.type,
        mode = mode,
        combatant = combatant,
        combatant_view = combatant and self:get_combatant_view(combatant) or nil,
        opponent_combatant = nil,
        opponent_view = nil,
        target_combatant = nil,
        target_combatant_view = nil,
        options = metadata.options or {},
        target_entries = {},
        dice_map = {},
        dice = {},
        mouse_x = self.mouse_position and self.mouse_position.x or 0,
        mouse_y = self.mouse_position and self.mouse_position.y or 0,
        shelf_rect = nil,
        enemy_assignments = {}
    }

    local opponent = metadata.opponent or (self.engine and self.engine:get_opponent(combatant)) or nil
    context.opponent_combatant = opponent
    context.opponent_view = opponent and self:get_combatant_view(opponent) or nil

    if mode == "attack" then
        context.target_combatant = metadata.opponent or opponent
        context.target_combatant_view = context.target_combatant and self:get_combatant_view(context.target_combatant) or context.opponent_view
    else
        context.target_combatant = combatant
        context.target_combatant_view = context.combatant_view
    end

    for _, option in ipairs(context.options) do
        local part_view = self:get_body_part_view(option.part)
        local entry = {
            option = option,
            part = option.part,
            part_view = part_view,
            rect = nil
        }

        table.insert(context.target_entries, entry)
    end

    self:update_assignment_target_rects(context)
    self:sync_assignment_dice(context)
    context.enemy_assignments = self:collect_enemy_assignments(context)
    self:evaluate_assignment_hover(context)

    return context
end

function CombatState:update_tech_card_layout(context, entry)
    if not context or not entry or not entry.options or #entry.options == 0 then
        return
    end

    local combatant_view = context.combatant_view
    if not combatant_view then
        return
    end

    local part_view = entry.view
    if not part_view then
        return
    end

    local sprite_size = Layouts.get_sprite_size()
    local index = context.combatant_index or combatant_view.index or 1
    local px, py = Layouts.get_body_part_position(combatant_view, index, part_view)
    local side = context.side or Layouts.get_combatant_side(combatant_view, index)
    local direction = (side == "right") and -1 or 1
    local base_x = direction == 1 and (px + sprite_size + TECH_CARD_GAP) or (px - TECH_CARD_GAP - TECH_CARD_WIDTH)

    local count = #entry.options
    local total_height = count * TECH_CARD_HEIGHT + (count - 1) * TECH_CARD_SPACING
    local start_y = py + sprite_size * 0.5 - total_height * 0.5

    for option_index, option in ipairs(entry.options) do
        option.card_rect = option.card_rect or {}
        option.card_rect.x = base_x
        option.card_rect.y = start_y + (option_index - 1) * (TECH_CARD_HEIGHT + TECH_CARD_SPACING)
        option.card_rect.w = TECH_CARD_WIDTH
        option.card_rect.h = TECH_CARD_HEIGHT
    end

    local min_x, min_y, max_x, max_y

    if entry.rect then
        min_x = entry.rect.x
        min_y = entry.rect.y
        max_x = entry.rect.x + entry.rect.w
        max_y = entry.rect.y + entry.rect.h
    end

    for _, option in ipairs(entry.options) do
        local rect = option.card_rect
        if rect then
            if not min_x or rect.x < min_x then
                min_x = rect.x
            end
            if not min_y or rect.y < min_y then
                min_y = rect.y
            end
            local rect_max_x = rect.x + rect.w
            local rect_max_y = rect.y + rect.h
            if not max_x or rect_max_x > max_x then
                max_x = rect_max_x
            end
            if not max_y or rect_max_y > max_y then
                max_y = rect_max_y
            end
        end
    end

    if min_x and min_y and max_x and max_y then
        local margin = context.sticky_margin or TECH_FAN_STICKY_MARGIN
        entry.sticky_bounds = entry.sticky_bounds or {}
        entry.sticky_bounds.x = min_x - margin
        entry.sticky_bounds.y = min_y - margin
        entry.sticky_bounds.w = (max_x - min_x) + margin * 2
        entry.sticky_bounds.h = (max_y - min_y) + margin * 2
    else
        entry.sticky_bounds = nil
    end
end

function CombatState:evaluate_tech_selection_hover(context)
    if not context or not context.active then
        return
    end

    local mx = context.mouse_x or 0
    local my = context.mouse_y or 0
    context.hovered_part_entry = nil
    context.hovered_option = nil

    local combatant_view = context.combatant_view
    local index = context.combatant_index or combatant_view and combatant_view.index or 1
    local sprite_size = Layouts.get_sprite_size()

    for _, entry in ipairs(context.part_entries) do
        local part_view = entry.view
        if combatant_view and part_view then
            entry.rect = entry.rect or {}
            local px, py = Layouts.get_body_part_position(combatant_view, index, part_view)
            entry.rect.x = px
            entry.rect.y = py
            entry.rect.w = sprite_size
            entry.rect.h = sprite_size

            if point_in_rect(mx, my, entry.rect) then
                context.hovered_part_entry = entry
            end
        else
            entry.rect = nil
        end
    end

    local active_entry = context.active_part_entry

    if context.hovered_part_entry then
        active_entry = context.hovered_part_entry
    end

    if active_entry then
        self:update_tech_card_layout(context, active_entry)
    end

    local hovered_option = nil
    local within_card_fan = false

    if active_entry then
        for _, option in ipairs(active_entry.options) do
            if point_in_rect(mx, my, option.card_rect) then
                hovered_option = option
                within_card_fan = true
                break
            end
        end
    end

    local within_sticky_bounds = false
    if active_entry and active_entry.sticky_bounds then
        within_sticky_bounds = point_in_rect(mx, my, active_entry.sticky_bounds)
    end

    if not context.hovered_part_entry and active_entry and not within_card_fan and not within_sticky_bounds then
        active_entry = nil
        hovered_option = nil
    end

    context.active_part_entry = active_entry
    context.hovered_option = hovered_option

    if context.active_part_entry then
        context.preview_option = context.hovered_option or context.active_part_entry.options[1]
    else
        context.preview_option = nil
    end
end

function CombatState:update_interactive_input()
    if not self.engine then
        self.tech_selection_ui = nil
        self.assignment_ui = nil
        self.prompt_ui = nil
        return
    end

    local metadata = self.engine:get_pending_input_metadata()
    if not (self.engine:needs_input() and metadata) then
        self.tech_selection_ui = nil
        self.assignment_ui = nil
        self.prompt_ui = nil
        return
    end

    if metadata.type == "tech_select_phase" then
        self.assignment_ui = nil
        self.prompt_ui = nil

        if not self.tech_selection_ui or self.tech_selection_ui.metadata ~= metadata then
            self.tech_selection_ui = self:build_tech_selection_context(metadata)
        end

        if not self.tech_selection_ui then
            return
        end

        self.tech_selection_ui.mouse_x = self.mouse_position and self.mouse_position.x or 0
        self.tech_selection_ui.mouse_y = self.mouse_position and self.mouse_position.y or 0

        self:evaluate_tech_selection_hover(self.tech_selection_ui)
        return
    end

    if metadata.type == "attack_assignment" or metadata.type == "defense_assignment" then
        self.tech_selection_ui = nil
        self.prompt_ui = nil

        if not self.assignment_ui or self.assignment_ui.metadata ~= metadata then
            self.assignment_ui = self:build_assignment_context(metadata)
            if self.assignment_ui then
                self.assignment_ui.metadata = metadata
            end
        end

        if self.assignment_ui then
            self.assignment_ui.mouse_x = self.mouse_position and self.mouse_position.x or 0
            self.assignment_ui.mouse_y = self.mouse_position and self.mouse_position.y or 0
            self:update_assignment_context(self.assignment_ui)
        end

        return
    end

    if metadata.type == "crest_prompt" or metadata.type == "crest_select" or metadata.type == "crest_target_select" then
        self.tech_selection_ui = nil
        self.assignment_ui = nil

        self.prompt_ui = self:build_prompt_context(metadata)

        if self.prompt_ui then
            self.prompt_ui.metadata = metadata
            self:update_prompt_context(self.prompt_ui)
        end

        return
    end

    self.tech_selection_ui = nil
    self.assignment_ui = nil
    self.prompt_ui = nil
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

local function draw_combatant(combatant, index, selection_context)
    local sprite_size = Layouts.get_sprite_size()
    local name_x, name_y, name_width = Layouts.get_name_region(combatant, index)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(combatant.name or "", name_x, name_y, name_width, "center")

    for _, part in ipairs(combatant.body_parts or {}) do
        local px, py = Layouts.get_body_part_position(combatant, index, part)
        local highlight_entry = nil

        if selection_context and selection_context.parts_by_view then
            highlight_entry = selection_context.parts_by_view[part]
        end

        local rect = nil
        if highlight_entry then
            rect = highlight_entry.rect
            if not rect then
                rect = { x = px, y = py, w = sprite_size, h = sprite_size }
                highlight_entry.rect = rect
            else
                rect.x = px
                rect.y = py
                rect.w = sprite_size
                rect.h = sprite_size
            end

            draw_highlight_fill(rect, selection_context.hovered_part_entry == highlight_entry)
        end

        draw_body_part(part, px, py)

        if highlight_entry then
            draw_highlight_outline(rect, selection_context.hovered_part_entry == highlight_entry)
        end
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

function CombatState:draw_selected_tech_panel(context, preview_option)
    local x, prompt_y, width = Layouts.get_prompt_region()
    local selected_y = prompt_y - (SELECTED_PANEL_HEIGHT + DICE_PANEL_HEIGHT + PANEL_SPACING * 2)

    draw_panel_background(x, selected_y, width, SELECTED_PANEL_HEIGHT)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Selected Tech", x + 16, selected_y + 12, width - 32, "left")

    if preview_option then
        love.graphics.printf(preview_option.tech_name or "", x + 16, selected_y + 36, width - 32, "left")

        local source = preview_option.body_part_name or "Unknown Source"
        love.graphics.setColor(0.82, 0.9, 1, 0.85)
        love.graphics.printf("Source: " .. source, x + 16, selected_y + 56, width - 32, "left")

        if preview_option.keywords and #preview_option.keywords > 0 then
            love.graphics.setColor(0.85, 0.95, 1, 0.85)
            love.graphics.printf("Keywords: " .. table.concat(preview_option.keywords, ", "), x + 16, selected_y + 76, width - 32, "left")
        end
    else
        love.graphics.setColor(0.82, 0.88, 1, 0.8)
        love.graphics.printf("Hover a body part to preview its Techs.", x + 16, selected_y + 40, width - 32, "left")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function CombatState:draw_dice_preview_panel(context, preview_option)
    local x, prompt_y, width = Layouts.get_prompt_region()
    local dice_y = prompt_y - (DICE_PANEL_HEIGHT + PANEL_SPACING)

    draw_panel_background(x, dice_y, width, DICE_PANEL_HEIGHT)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Dice Preview", x + 16, dice_y + 12, width - 32, "left")

    local start_y = dice_y + 40
    if preview_option and preview_option.dice_lines and #preview_option.dice_lines > 0 then
        love.graphics.setColor(0.9, 0.95, 1, 0.9)
        for line_index, line in ipairs(preview_option.dice_lines) do
            love.graphics.printf(line, x + 16, start_y + (line_index - 1) * 22, width - 32, "left")
        end
    elseif preview_option then
        love.graphics.setColor(0.82, 0.9, 1, 0.8)
        love.graphics.printf("No dice generated by this Tech.", x + 16, start_y, width - 32, "left")
    else
        love.graphics.setColor(0.82, 0.88, 1, 0.8)
        love.graphics.printf("Select a Tech to preview its dice.", x + 16, start_y, width - 32, "left")
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function CombatState:build_prompt_context(metadata)
    if not metadata then
        return nil
    end

    local prompt_text = self.engine and self.engine:get_input_prompt() or ""
    local x, anchor_y, width = Layouts.get_prompt_region()

    local built_options = {}
    local layout = "vertical"
    local description = nil

    if metadata.type == "crest_prompt" then
        built_options = {
            { label = "Yes", value = "y" },
            { label = "No", value = "n" }
        }
        layout = "horizontal"
        description = "Choose whether to expend a crest this round."
    elseif metadata.type == "crest_select" then
        for index, option in ipairs(metadata.options or {}) do
            local name = option.name or option.id or ("Option " .. index)
            local count = tonumber(option.count) or 0
            table.insert(built_options, {
                label = name,
                subtitle = string.format("Available: %d", count),
                value = tostring(option.index or index),
                payload = option
            })
        end
        description = "Select a crest to expend."
    elseif metadata.type == "crest_target_select" then
        for index, option in ipairs(metadata.options or {}) do
            local name = option.name or option.id or ("Target " .. index)
            local subtitle_parts = {}
            if option.status and option.status ~= "" then
                local status_text = tostring(option.status)
                status_text = status_text:gsub("^%l", string.upper)
                table.insert(subtitle_parts, status_text)
            end
            local toughness_value = tonumber(option.toughness)
            if toughness_value and toughness_value >= 0 then
                table.insert(subtitle_parts, "Toughness " .. tostring(toughness_value))
            end
            local subtitle = table.concat(subtitle_parts, " • ")
            table.insert(built_options, {
                label = name,
                subtitle = subtitle ~= "" and subtitle or nil,
                value = tostring(option.index or index),
                payload = option
            })
        end
        description = "Select a body part to shroud."
    else
        return nil
    end

    if #built_options == 0 then
        return nil
    end

    local button_height = PROMPT_BUTTON_HEIGHT
    local button_width = math.min(360, width - 64)
    local button_area_height = button_height

    if layout == "horizontal" then
        local available_width = width - 48
        button_width = math.min(PROMPT_BUTTON_WIDTH, (available_width - (#built_options - 1) * PROMPT_BUTTON_SPACING) / #built_options)
        if button_width <= 0 then
            button_width = available_width / math.max(1, #built_options)
        end
        button_area_height = button_height
    else
        button_area_height = #built_options * button_height + (#built_options - 1) * PROMPT_BUTTON_SPACING
    end

    local panel_height = PROMPT_PANEL_HEADER + button_area_height + PROMPT_PANEL_BOTTOM_PADDING
    local panel_y = anchor_y - panel_height - 24
    if panel_y < 40 then
        panel_y = 40
    end

    local context = {
        metadata = metadata,
        prompt_text = prompt_text,
        description = description,
        buttons = {},
        layout = layout,
        panel = { x = x, y = panel_y, w = width, h = panel_height },
        hovered_button = nil
    }

    if layout == "horizontal" then
        local available_width = width - 48
        local total_width = #built_options * button_width + (#built_options - 1) * PROMPT_BUTTON_SPACING
        if total_width > available_width then
            button_width = (available_width - (#built_options - 1) * PROMPT_BUTTON_SPACING) / #built_options
            total_width = #built_options * button_width + (#built_options - 1) * PROMPT_BUTTON_SPACING
        end
        local start_x = x + (width - total_width) * 0.5
        local button_y = context.panel.y + PROMPT_PANEL_HEADER

        for index, option in ipairs(built_options) do
            local bx = start_x + (index - 1) * (button_width + PROMPT_BUTTON_SPACING)
            context.buttons[index] = {
                label = option.label,
                subtitle = option.subtitle,
                value = option.value,
                option = option.payload,
                rect = { x = bx, y = button_y, w = button_width, h = button_height }
            }
        end
    else
        button_width = math.min(380, width - 64)
        local start_x = x + (width - button_width) * 0.5
        local start_y = context.panel.y + PROMPT_PANEL_HEADER

        for index, option in ipairs(built_options) do
            local by = start_y + (index - 1) * (button_height + PROMPT_BUTTON_SPACING)
            context.buttons[index] = {
                label = option.label,
                subtitle = option.subtitle,
                value = option.value,
                option = option.payload,
                rect = { x = start_x, y = by, w = button_width, h = button_height }
            }
        end
    end

    return context
end

function CombatState:update_prompt_context(context)
    if not context then
        return
    end

    local mx = self.mouse_position and self.mouse_position.x or 0
    local my = self.mouse_position and self.mouse_position.y or 0

    context.mouse_x = mx
    context.mouse_y = my
    context.hovered_button = nil

    for _, button in ipairs(context.buttons or {}) do
        if point_in_rect(mx, my, button.rect) then
            context.hovered_button = button
            break
        end
    end
end

function CombatState:draw_prompt_ui(context)
    if not context or not context.panel then
        return
    end

    local panel = context.panel

    draw_panel_background(panel.x, panel.y, panel.w, panel.h)

    love.graphics.setColor(1, 1, 1, 0.96)
    love.graphics.printf(context.prompt_text or "", panel.x + 18, panel.y + 16, panel.w - 36, "center")

    if context.description and context.description ~= "" then
        love.graphics.setColor(0.82, 0.9, 1, 0.85)
        love.graphics.printf(context.description, panel.x + 18, panel.y + 44, panel.w - 36, "center")
    end

    love.graphics.setColor(1, 1, 1, 1)

    for _, button in ipairs(context.buttons or {}) do
        draw_prompt_button(button, context.hovered_button == button)
    end
end

function CombatState:draw_tech_selection_ui(context)
    if not context or not context.active then
        return
    end

    local entry = context.active_part_entry or context.hovered_part_entry
    if entry then
        self:update_tech_card_layout(context, entry)

        for _, option in ipairs(entry.options) do
            draw_tech_card(option, context.hovered_option == option)
        end
    end

    self:draw_selected_tech_panel(context, context.preview_option)
    self:draw_dice_preview_panel(context, context.preview_option)
end

function CombatState:draw_enemy_assignment_tokens(context)
    local assignments = context and context.enemy_assignments or nil
    if not assignments or #assignments == 0 then
        return
    end

    local sprite_size = Layouts.get_sprite_size()
    local counts_by_part = {}

    for _, entry in ipairs(assignments) do
        local part_view = entry.part_view
        local target_view = entry.target_view
        if part_view and target_view then
            local index = target_view.index or 1
            local px, py = Layouts.get_body_part_position(target_view, index, part_view)
            local key = part_view
            counts_by_part[key] = (counts_by_part[key] or 0) + 1
            local stack_index = counts_by_part[key]

            local size = DIE_TOKEN_SIZE * 0.55
            local offset_x = (stack_index - 1) * (size * 0.35)
            local x = px + sprite_size * 0.5 - size * 0.5 + offset_x
            local y = py + sprite_size * 0.5 - size * 0.5 - 8

            love.graphics.setColor(0.82, 0.35, 0.22, 0.82)
            love.graphics.rectangle("fill", x, y, size, size, DIE_TOKEN_RADIUS * 0.8, DIE_TOKEN_RADIUS * 0.8)

            love.graphics.setColor(1, 0.68, 0.42, 0.95)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", x, y, size, size, DIE_TOKEN_RADIUS * 0.8, DIE_TOKEN_RADIUS * 0.8)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 0.95, 0.9, 0.92)
            love.graphics.printf(entry.label or "?", x + 6, y + size * 0.5 - 8, size - 12, "center")
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function CombatState:draw_assignment_ui(context)
    if not context then
        return
    end

    local shelf = context.shelf_rect
    if shelf then
        draw_panel_background(shelf.x, shelf.y, shelf.w, shelf.h, 0.78)

        local header = context.mode == "attack" and "Attack Dice" or "Defense Dice"
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.printf(header, shelf.x + 16, shelf.y + 10, shelf.w - 32, "left")

        love.graphics.setColor(0.82, 0.9, 1, 0.85)
        local instruction = context.mode == "attack" and "Drag a die onto an enemy body part." or "Drag a die onto one of your body parts."
        love.graphics.printf(instruction, shelf.x + 16, shelf.y + shelf.h - 26, shelf.w - 32, "left")
        love.graphics.setColor(1, 1, 1, 1)
    end

    local enemy_x, enemy_y, enemy_w, enemy_h = get_enemy_shelf_rect()
    draw_panel_background(enemy_x, enemy_y, enemy_w, enemy_h, 0.65)
    love.graphics.setColor(1, 0.92, 0.82, 0.9)
    love.graphics.printf("Enemy Dice", enemy_x + 16, enemy_y + 10, enemy_w - 32, "right")
    love.graphics.setColor(0.95, 0.75, 0.55, 0.85)
    love.graphics.printf("Assigning...", enemy_x + 16, enemy_y + enemy_h - 26, enemy_w - 32, "right")
    love.graphics.setColor(1, 1, 1, 1)

    local dragging_die = context.dragging and context.dragging.die or nil

    for _, die in ipairs(context.dice or {}) do
        if die ~= dragging_die then
            draw_die_token(die, context.hovered_die == die, false)
        end
    end

    if dragging_die then
        draw_die_token(dragging_die, true, true)
    end

    self:draw_enemy_assignment_tokens(context)
end

function CombatState:handle_assignment_mousepressed(context, x, y)
    if not context then
        return
    end

    self:update_assignment_context(context)

    for _, die in ipairs(context.dice or {}) do
        if die.interactable and not die.assigned and point_in_rect(x, y, die.rect) then
            context.dragging = {
                die = die,
                offset_x = x - die.rect.x,
                offset_y = y - die.rect.y
            }
            die.rect.x = x - context.dragging.offset_x
            die.rect.y = y - context.dragging.offset_y
            return
        end
    end
end

function CombatState:handle_assignment_mousereleased(context, x, y)
    if not context or not context.dragging or not context.dragging.die then
        return
    end

    local die = context.dragging.die
    context.dragging = nil

    self:update_assignment_context(context)
    local target_entry = context.hovered_target

    if target_entry and target_entry.option and target_entry.option.index then
        die.assigned = true
        die.assigned_part_view = target_entry.part_view
        die.assigned_option = target_entry.option
        self.assignment_ui = nil
        self.engine:provide_input(target_entry.option.index)
        return
    end

    if die.home then
        die.rect.x = die.home.x
        die.rect.y = die.home.y
    end
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

    local selection_context = self.tech_selection_ui
    local assignment_context = self.assignment_ui
    local metadata = nil
    if self.engine:needs_input() then
        metadata = self.engine:get_pending_input_metadata()
    end

    for index, combatant in ipairs(self.ui_state and self.ui_state.combatants or {}) do
        local highlight = nil
        if selection_context and selection_context.combatant_view == combatant then
            highlight = selection_context
        elseif assignment_context and assignment_context.target_combatant_view == combatant then
            highlight = assignment_context.highlight
        end

        draw_combatant(combatant, index, highlight)
    end

    if selection_context and metadata and metadata.type == "tech_select_phase" then
        self:draw_tech_selection_ui(selection_context)
    elseif assignment_context and metadata and (metadata.type == "attack_assignment" or metadata.type == "defense_assignment") then
        self:draw_assignment_ui(assignment_context)
    end

    local x, y, width = Layouts.get_prompt_region()

    if self.engine:needs_input() then
        if metadata and metadata.type == "tech_select_phase" then
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "center")
            love.graphics.setColor(0.82, 0.9, 1, 0.85)
            love.graphics.printf("Click a Tech card to select it.", x, y + 20, width, "center")
            love.graphics.setColor(1, 1, 1, 1)
        elseif metadata and metadata.type == "attack_assignment" then
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "center")
            love.graphics.setColor(0.82, 0.9, 1, 0.85)
            love.graphics.printf("Drag an attack die onto a highlighted enemy body part.", x, y + 20, width, "center")
            love.graphics.setColor(1, 1, 1, 1)
        elseif metadata and metadata.type == "defense_assignment" then
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "center")
            love.graphics.setColor(0.82, 0.9, 1, 0.85)
            love.graphics.printf("Drag a defense die onto one of your body parts.", x, y + 20, width, "center")
            love.graphics.setColor(1, 1, 1, 1)
        elseif metadata and (metadata.type == "crest_prompt" or metadata.type == "crest_select" or metadata.type == "crest_target_select") then
            if self.prompt_ui then
                self:draw_prompt_ui(self.prompt_ui)
            else
                love.graphics.setColor(1, 1, 1, 0.95)
                love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "center")
                love.graphics.setColor(1, 1, 1, 1)
            end
        else
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "center")
            love.graphics.setColor(1, 1, 1, 1)
        end
    else
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.printf("Press ESC to return to the overworld", x, y, width, "center")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function CombatState:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if not (self.engine and self.engine:needs_input()) then
        return
    end

    local metadata = self.engine:get_pending_input_metadata()
    if not metadata then
        return
    end

    self:update_mouse_position(x, y)

    if metadata.type == "tech_select_phase" then
        if not self.tech_selection_ui then
            return
        end

        local context = self.tech_selection_ui
        context.mouse_x = x
        context.mouse_y = y
        self:evaluate_tech_selection_hover(context)

        if context.hovered_option and context.hovered_option.selection_index then
            self.engine:provide_input(context.hovered_option.selection_index)
            self.tech_selection_ui = nil
        end

        return
    end

    if metadata.type == "attack_assignment" or metadata.type == "defense_assignment" then
        if not self.assignment_ui or self.assignment_ui.metadata ~= metadata then
            self.assignment_ui = self:build_assignment_context(metadata)
            if self.assignment_ui then
                self.assignment_ui.metadata = metadata
            end
        end

        if self.assignment_ui then
            self.assignment_ui.mouse_x = x
            self.assignment_ui.mouse_y = y
            self:handle_assignment_mousepressed(self.assignment_ui, x, y)
        end

        return
    end

    if metadata.type == "crest_prompt" or metadata.type == "crest_select" or metadata.type == "crest_target_select" then
        self.prompt_ui = self:build_prompt_context(metadata)

        if self.prompt_ui then
            self.prompt_ui.metadata = metadata
            self:update_prompt_context(self.prompt_ui)
            local hovered = self.prompt_ui.hovered_button
            if hovered and hovered.value then
                self.engine:provide_input(hovered.value)
                self.prompt_ui = nil
            end
        end

        return
    end
end

function CombatState:mousereleased(x, y, button)
    if button ~= 1 then
        return
    end

    if not (self.engine and self.engine:needs_input()) then
        return
    end

    local metadata = self.engine:get_pending_input_metadata()
    if not metadata then
        return
    end

    self:update_mouse_position(x, y)

    if metadata.type == "attack_assignment" or metadata.type == "defense_assignment" then
        if not self.assignment_ui or self.assignment_ui.metadata ~= metadata then
            self.assignment_ui = self:build_assignment_context(metadata)
            if self.assignment_ui then
                self.assignment_ui.metadata = metadata
            end
        end

        if self.assignment_ui then
            self.assignment_ui.mouse_x = x
            self.assignment_ui.mouse_y = y
            self:handle_assignment_mousereleased(self.assignment_ui, x, y)
        end
    end
end

function CombatState:keypressed(key)
    if key == "escape" then
        GameState.switch(require("states.overworld"))
    end
end

return CombatState
