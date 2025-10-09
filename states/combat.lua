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

local TECH_CARD_WIDTH = 176
local TECH_CARD_HEIGHT = 72
local TECH_CARD_SPACING = 10
local TECH_CARD_GAP = 20
local TECH_CARD_CORNER_RADIUS = 12

local PANEL_CORNER_RADIUS = 14
local PANEL_SPACING = 14
local SELECTED_PANEL_HEIGHT = 96
local DICE_PANEL_HEIGHT = 110

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
    self.mouse_position = { x = 0, y = 0 }
    self.tech_selection_ui = nil

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

function CombatState:is_text_input_active()
    if not (self.engine and self.engine:needs_input()) then
        return false
    end

    local metadata = self.engine:get_pending_input_metadata()
    if metadata and metadata.type == "tech_select_phase" then
        return false
    end

    return true
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
        preview_option = nil,
        mouse_x = self.mouse_position and self.mouse_position.x or 0,
        mouse_y = self.mouse_position and self.mouse_position.y or 0,
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
        local body_part = option.body_part or (tech and tech._source_part) or nil
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

    if context.hovered_part_entry then
        self:update_tech_card_layout(context, context.hovered_part_entry)

        for _, option in ipairs(context.hovered_part_entry.options) do
            if point_in_rect(mx, my, option.card_rect) then
                context.hovered_option = option
                break
            end
        end

        context.preview_option = context.hovered_option or context.hovered_part_entry.options[1]
    else
        context.preview_option = nil
    end
end

function CombatState:update_interactive_input()
    if not self.engine then
        self.tech_selection_ui = nil
        return
    end

    local metadata = self.engine:get_pending_input_metadata()
    if not (self.engine:needs_input() and metadata and metadata.type == "tech_select_phase") then
        self.tech_selection_ui = nil
        return
    end

    if not self.tech_selection_ui or self.tech_selection_ui.metadata ~= metadata then
        self.tech_selection_ui = self:build_tech_selection_context(metadata)
        self.input_buffer = ""
    end

    if not self.tech_selection_ui then
        return
    end

    self.tech_selection_ui.mouse_x = self.mouse_position and self.mouse_position.x or 0
    self.tech_selection_ui.mouse_y = self.mouse_position and self.mouse_position.y or 0

    self:evaluate_tech_selection_hover(self.tech_selection_ui)
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

function CombatState:draw_tech_selection_ui(context)
    if not context or not context.active then
        return
    end

    if context.hovered_part_entry then
        self:update_tech_card_layout(context, context.hovered_part_entry)

        for _, option in ipairs(context.hovered_part_entry.options) do
            draw_tech_card(option, context.hovered_option == option)
        end
    end

    self:draw_selected_tech_panel(context, context.preview_option)
    self:draw_dice_preview_panel(context, context.preview_option)
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
    local metadata = nil
    if self.engine:needs_input() then
        metadata = self.engine:get_pending_input_metadata()
    end

    for index, combatant in ipairs(self.ui_state and self.ui_state.combatants or {}) do
        local highlight = nil
        if selection_context and selection_context.combatant_view == combatant then
            highlight = selection_context
        end

        draw_combatant(combatant, index, highlight)
    end

    if selection_context and metadata and metadata.type == "tech_select_phase" then
        self:draw_tech_selection_ui(selection_context)
    end

    local x, y, width = Layouts.get_prompt_region()

    if self.engine:needs_input() then
        if metadata and metadata.type == "tech_select_phase" then
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "center")
            love.graphics.setColor(0.82, 0.9, 1, 0.85)
            love.graphics.printf("Click a Tech card to select it.", x, y + 20, width, "center")
            love.graphics.setColor(1, 1, 1, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(self.engine:get_input_prompt() or "", x, y, width, "left")
            love.graphics.printf("> " .. (self.input_buffer or ""), x, y + 18, width, "left")
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.rectangle("line", x - 4, y - 6, width + 8, 36)
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
    if not metadata or metadata.type ~= "tech_select_phase" then
        return
    end

    self:update_mouse_position(x, y)

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
        self.input_buffer = ""
    end
end

function CombatState:keypressed(key)
    if key == "escape" then
        GameState.switch(require("states.overworld"))
        return
    end

    if key == "return" or key == "kpenter" then
        if self:is_text_input_active() then
            self.engine:provide_input(self.input_buffer or "")
            self.input_buffer = ""
        end
    elseif key == "backspace" then
        if self:is_text_input_active() and self.input_buffer and #self.input_buffer > 0 then
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
    if self:is_text_input_active() then
        self.input_buffer = (self.input_buffer or "") .. text
    end
end

return CombatState
