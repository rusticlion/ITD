local Assets = require("core.assets")
local Keywords = require("combat.keywords")
local Symbols = require("core.symbols")
local Text = require("ui.text")

local BPCard = {}

local CARD_WIDTH = 116
local CARD_HEIGHT = 88
local TITLE_HEIGHT = 16
local BP_LEFT_SECTOR_WIDTH = 44
local DIE_SIZE = 36
local SYMBOL_SIZE = 12
local SLOT_PIP_ROW_LIMIT = 3
local SLOT_PIP_GAP = 1
local SLOT_PIP_ROW_GAP = 1
local OVERLAY_ANIMATION_FPS = 8
local UI_FONT_PATH = "assets/fonts/dotgothic16/DotGothic16-Regular.ttf"

local COLORS = {
    panel = { 44 / 255, 41 / 255, 64 / 255, 0.96 },
    surface = { 38 / 255, 36 / 255, 56 / 255, 0.88 },
    surface_low = { 18 / 255, 17 / 255, 29 / 255, 0.4 },
    ink = { 0.96, 0.95, 1, 1 },
    muted = { 0.68, 0.66, 0.78, 1 },
    line = { 0.86, 0.84, 0.94, 0.52 },
    dashed = { 0.58, 0.55, 0.68, 0.58 },
    enemy = { 0.96, 0.35, 0.31, 1 },
    selected = { 0.62, 0.78, 1, 1 },
    valid = { 0.25, 0.88, 0.68, 1 },
    invalid = { 0.48, 0.48, 0.56, 0.48 },
    attack = { 0.98, 0.39, 0.32, 1 },
    defense = { 0.35, 0.63, 1, 1 },
    essence = { 1, 0.79, 0.28, 1 },
    blood = { 0.88, 0.12, 0.22, 1 }
}

local STATUS_COLORS = {
    healthy = { 0.22, 0.76, 0.38, 1 },
    wounded = { 1, 0.68, 0.2, 1 },
    maimed = { 0.68, 0.66, 0.78, 1 }
}

local SYMBOL_ASSETS = {
    [Symbols.STRIKE] = "sword_symbol",
    [Symbols.WARD] = "shield_symbol",
    [Symbols.ESSENCE] = "lightning_symbol",
    [Symbols.BLOOD] = "blood_symbol"
}

local SYMBOL_OUTLINE_ASSETS = {
    [Symbols.STRIKE] = "sword_symbol_outline",
    [Symbols.WARD] = "shield_symbol_outline",
    [Symbols.ESSENCE] = "lightning_symbol_outline",
    [Symbols.BLOOD] = "blood_symbol_outline"
}

local KEYWORD_BADGE_COLORS = {
    Armored = { fill = { 0.13, 0.24, 0.34, 0.96 }, line = COLORS.defense },
    Brittle = { fill = { 0.34, 0.12, 0.18, 0.96 }, line = COLORS.blood },
    Absorbent = { fill = { 0.14, 0.28, 0.23, 0.96 }, line = COLORS.valid },
    Hungry = { fill = { 0.34, 0.27, 0.12, 0.96 }, line = COLORS.essence }
}

local font_cache = {}

local function set_color(color)
    love.graphics.setColor(color)
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function scaled(value, scale)
    return math.floor(value * (scale or 1) + 0.5)
end

local function new_ui_font(size)
    local key = tostring(size)
    if font_cache[key] then
        return font_cache[key]
    end

    local ok, font = pcall(love.graphics.newFont, UI_FONT_PATH, size)
    if not ok then
        font = love.graphics.newFont(size)
    end

    if font and font.setFilter then
        font:setFilter("nearest", "nearest")
    end

    font_cache[key] = font
    return font
end

function BPCard.fonts(scale)
    scale = scale or 1
    return {
        small = new_ui_font(math.max(8, scaled(10, scale))),
        tiny = new_ui_font(math.max(7, scaled(9, scale)))
    }
end

local function draw_box(r, fill, outline, radius)
    set_color(fill or COLORS.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, radius or 6, radius or 6)
    set_color(outline or COLORS.line)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, radius or 6, radius or 6)
end

local function draw_image(id, r, color, flip_y)
    local image = Assets.images and Assets.images[id]
    if not image then
        return false
    end

    set_color(color or { 1, 1, 1, 1 })
    local sx = r.w / image:getWidth()
    local sy = r.h / image:getHeight()
    local y = r.y
    if flip_y then
        y = r.y + r.h
        sy = -sy
    end
    love.graphics.draw(image, r.x, y, 0, sx, sy)
    return true
end

local function animated_asset_id(base_id, time, max_frames)
    local frame_count = 0
    local limit = max_frames or 4

    for index = 1, limit do
        if Assets.images and Assets.images[base_id .. tostring(index)] then
            frame_count = index
        elseif frame_count > 0 then
            break
        end
    end

    if frame_count > 0 then
        local frame = (math.floor((time or 0) * OVERLAY_ANIMATION_FPS) % frame_count) + 1
        return base_id .. tostring(frame)
    end

    if Assets.images and Assets.images[base_id] then
        return base_id
    end

    return nil
end

local function draw_animated_image(base_id, r, time, color, flip_y, max_frames)
    local asset_id = animated_asset_id(base_id, time, max_frames)
    if not asset_id then
        return false
    end

    return draw_image(asset_id, r, color, flip_y)
end

local function draw_sprite_outline(r, color, radius)
    set_color(color or COLORS.line)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, radius or 3, radius or 3)
end

local function truncate_tracked_text(text, max_width, tracking)
    return Text.truncate(text, max_width, { tracking = tracking })
end

local function draw_text(text, x, y, w, align, color, tracking)
    return Text.draw_line(text, x, y, w, align, color, { tracking = tracking })
end

local function symbol_color(symbol)
    if symbol == Symbols.STRIKE then
        return COLORS.attack
    elseif symbol == Symbols.WARD then
        return COLORS.defense
    elseif symbol == Symbols.ESSENCE then
        return COLORS.essence
    elseif symbol == Symbols.BLOOD then
        return COLORS.blood
    end

    return COLORS.muted
end

local function draw_hp_badge(value, x, y, scale)
    local total = math.max(1, value or 1)
    local step = scaled(7, scale)
    for index = 1, total do
        local px = x + (index - 1) * step
        set_color(COLORS.ink)
        love.graphics.polygon("fill",
            px + scaled(3, scale), y,
            px + scaled(6, scale), y + scaled(3, scale),
            px + scaled(3, scale), y + scaled(6, scale),
            px, y + scaled(3, scale))
    end
end

local function draw_keyword_badge(definition, x, y, w, h, options)
    local scale = options.scale or 1
    local colors = KEYWORD_BADGE_COLORS[definition.name] or { fill = COLORS.surface, line = COLORS.line }
    local badge = rect(x, y, w, h)
    if definition.asset and draw_image(definition.asset, badge) then
        return
    end

    draw_box(badge, colors.fill, colors.line, scaled(2, scale))

    love.graphics.setFont((options.fonts and options.fonts.tiny) or BPCard.fonts(scale).tiny)
    local font = love.graphics.getFont()
    local text_h = font and font:getHeight() or h
    local text_y = y + math.floor((h - text_h) / 2) - scaled(1, scale)
    draw_text(definition.short or definition.name:sub(1, 2), x + scaled(1, scale), text_y,
        w - scaled(2, scale), "center", COLORS.ink, 0)
end

local function draw_keyword_badges(part, layout, options)
    local badges = Keywords.badges_for_part(part)
    if #badges == 0 then
        return
    end

    local scale = options.scale or 1
    local badge_w = scaled(13, scale)
    local badge_h = scaled(9, scale)
    local gap = scaled(1, scale)
    local max_per_row = math.max(1, math.floor((layout.meta.w + gap) / (badge_w + gap)))
    local max_badges = max_per_row * 2
    local first_row_y = layout.side == "enemy"
        and (layout.meta.y + layout.meta.h + scaled(2, scale))
        or (layout.meta.y - badge_h - scaled(2, scale))

    for index, definition in ipairs(badges) do
        if index > max_badges then
            break
        end

        local row = math.floor((index - 1) / max_per_row)
        local column = ((index - 1) % max_per_row) + 1
        local remaining = math.min(max_per_row, #badges - row * max_per_row)
        local row_width = remaining * badge_w + math.max(0, remaining - 1) * gap
        local x = layout.meta.x + math.floor((layout.meta.w - row_width) / 2) + (column - 1) * (badge_w + gap)
        local y = layout.side == "enemy"
            and (first_row_y + row * (badge_h + gap))
            or (first_row_y - row * (badge_h + gap))
        draw_keyword_badge(definition, x, y, badge_w, badge_h, options)
    end
end

local function draw_damage_decoration(part, card, display_status)
    local status = display_status or (part and part.status)
    if not part or status == "healthy" then
        return
    end

    if status == "wounded" then
        set_color({ STATUS_COLORS.wounded[1], STATUS_COLORS.wounded[2], STATUS_COLORS.wounded[3], 0.16 })
        love.graphics.rectangle("fill", card.x + 2, card.y + 2, card.w - 4, card.h - 4)
        set_color({ COLORS.essence[1], COLORS.essence[2], COLORS.essence[3], 0.72 })
        love.graphics.setLineWidth(1)
        love.graphics.line(card.x + card.w - 24, card.y + 12, card.x + card.w - 16, card.y + 21)
        love.graphics.line(card.x + card.w - 16, card.y + 21, card.x + card.w - 22, card.y + 31)
    elseif status == "maimed" then
        set_color({ 0, 0, 0, 0.24 })
        love.graphics.rectangle("fill", card.x + 2, card.y + 2, card.w - 4, card.h - 4)
        set_color({ COLORS.ink[1], COLORS.ink[2], COLORS.ink[3], 0.68 })
        love.graphics.setLineWidth(1)
        love.graphics.line(card.x + 12, card.y + 12, card.x + card.w - 12, card.y + card.h - 12)
        love.graphics.line(card.x + card.w - 16, card.y + 14, card.x + 20, card.y + card.h - 16)
    end
end

local function draw_symbol_chip(symbol, x, y, w, h, scale)
    local chip = rect(x, y, w, h)
    draw_box(chip, COLORS.surface, symbol_color(symbol), scaled(4, scale))
    draw_text(Symbols.display(symbol), x + scaled(2, scale), y + scaled(7, scale), w - scaled(4, scale),
        "center", symbol_color(symbol), scaled(Text.TRACKING, scale))
end

local function draw_symbol_sprite(symbol, x, y, size, outlined, alpha, scale)
    local normalized = Symbols.normalize(symbol)
    if normalized == Symbols.BLANK then
        return false
    end

    local asset_id = outlined and SYMBOL_OUTLINE_ASSETS[normalized] or SYMBOL_ASSETS[normalized]
    local image = asset_id and Assets.images and Assets.images[asset_id]
    if not image then
        draw_symbol_chip(normalized, x, y, size, size, scale)
        return false
    end

    set_color({ 1, 1, 1, alpha or 1 })
    love.graphics.draw(image, x, y, 0, size / image:getWidth(), size / image:getHeight())
    return true
end

local function draw_wildcard_pip(x, y, size, lit, previewed)
    local pip_rect = rect(x, y, size, size)
    local tint = lit and { 1, 1, 1, 1 } or (previewed and { 1, 1, 1, 0.9 } or { 1, 1, 1, 0.72 })
    if draw_image("slot_cell_wild", pip_rect, tint) then
        if lit then
            draw_sprite_outline(pip_rect, COLORS.essence, 2)
        elseif previewed then
            draw_sprite_outline(pip_rect, COLORS.valid, 2)
        end
        return
    end

    local cx = x + math.floor(size / 2)
    local cy = y + math.floor(size / 2)
    local radius = math.max(2, math.floor(size / 2) - 3)

    if lit then
        set_color({ COLORS.essence[1], COLORS.essence[2], COLORS.essence[3], 0.82 })
        love.graphics.circle("fill", cx, cy, radius)
        set_color(COLORS.ink)
        love.graphics.circle("line", cx, cy, radius)
    elseif previewed then
        set_color({ COLORS.essence[1], COLORS.essence[2], COLORS.essence[3], 0.28 })
        love.graphics.circle("fill", cx, cy, radius)
        set_color(COLORS.essence)
        love.graphics.circle("line", cx, cy, radius)
    else
        set_color({ COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.62 })
        love.graphics.circle("line", cx, cy, radius)
        set_color({ COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.38 })
        love.graphics.circle("fill", cx, cy, math.max(1, math.floor(radius / 2)))
    end
end

local function draw_burned_symbols(symbols, x, y, scale)
    local symbol_size = scaled(SYMBOL_SIZE, scale)
    for index, symbol in ipairs(symbols or {}) do
        local px = x + (index - 1) * (symbol_size + scaled(2, scale))
        draw_symbol_sprite(symbol, px, y, symbol_size, false, 0.42, scale)
        set_color({ COLORS.attack[1], COLORS.attack[2], COLORS.attack[3], 0.78 })
        love.graphics.setLineWidth(1)
        love.graphics.line(px - 1, y + symbol_size + 1, px + symbol_size + 1, y - 1)
    end
end

local function draw_die_back(r, color)
    if not draw_image("empty_die", r, { 1, 1, 1, 0.82 }) then
        draw_box(r, COLORS.surface_low, color or COLORS.line, 5)
    end

    set_color(color or COLORS.muted)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x + 5, r.y + 5, r.w - 10, r.h - 10, 3, 3)
    love.graphics.line(r.x + 9, r.y + 10, r.x + r.w - 9, r.y + r.h - 10)
    love.graphics.line(r.x + r.w - 9, r.y + 10, r.x + 9, r.y + r.h - 10)
end

local function visible_face_symbols(symbols)
    local visible_symbols = {}
    for _, symbol in ipairs(symbols or { Symbols.BLANK }) do
        local normalized = Symbols.normalize(symbol)
        if normalized and normalized ~= Symbols.BLANK then
            table.insert(visible_symbols, normalized)
        end
    end
    return visible_symbols
end

local function draw_symbol_cluster(symbols, r, alpha, outlined, scale)
    local visible_symbols = visible_face_symbols(symbols)
    local count = #visible_symbols
    local symbol_size = scaled(SYMBOL_SIZE, scale)
    if count == 1 then
        draw_symbol_sprite(visible_symbols[1], r.x + scaled(12, scale), r.y + scaled(12, scale), symbol_size, outlined, alpha, scale)
    elseif count == 2 then
        draw_symbol_sprite(visible_symbols[1], r.x + scaled(7, scale), r.y + scaled(12, scale), symbol_size, outlined, alpha, scale)
        draw_symbol_sprite(visible_symbols[2], r.x + scaled(17, scale), r.y + scaled(12, scale), symbol_size, outlined, alpha, scale)
    elseif count >= 3 then
        draw_symbol_sprite(visible_symbols[1], r.x + scaled(5, scale), r.y + scaled(12, scale), symbol_size, outlined, alpha, scale)
        draw_symbol_sprite(visible_symbols[2], r.x + scaled(12, scale), r.y + scaled(12, scale), symbol_size, outlined, alpha, scale)
        draw_symbol_sprite(visible_symbols[3], r.x + scaled(19, scale), r.y + scaled(12, scale), symbol_size, outlined, alpha, scale)
    end
end

local function draw_die_face(symbols, r, is_selected, scale)
    local outline = is_selected and COLORS.selected or COLORS.line
    if not draw_image("empty_die", r) then
        draw_box(r, COLORS.surface, outline, scaled(5, scale))
    end

    draw_symbol_cluster(symbols, r, 1, false, scale)

    if is_selected then
        draw_sprite_outline(r, outline, scaled(4, scale))
    end
end

function BPCard.draw_die_face(symbols, r, options)
    options = options or {}
    return draw_die_face(symbols, r, options.selected == true, options.scale or 1)
end

local function normalized_nonblank_symbols(symbols)
    local normalized = {}
    for _, symbol in ipairs(symbols or {}) do
        local value = Symbols.normalize(symbol)
        if value and value ~= Symbols.BLANK then
            table.insert(normalized, value)
        end
    end
    return normalized
end

function BPCard.symbol_sequence_width(symbols, size, options)
    options = options or {}
    local scale = options.scale or 1
    local gap = options.gap or scaled(2, scale)
    local normalized = normalized_nonblank_symbols(symbols)

    if #normalized == 0 then
        return size
    end

    return #normalized * size + math.max(0, #normalized - 1) * gap
end

function BPCard.draw_symbol_sequence(symbols, x, y, size, options)
    options = options or {}
    local scale = options.scale or 1
    local gap = options.gap or scaled(2, scale)
    local normalized = normalized_nonblank_symbols(symbols)

    if #normalized == 0 then
        local r = rect(x, y, size, size)
        if not draw_image("empty_die", r, { 1, 1, 1, options.alpha or 0.8 }) then
            draw_box(r, COLORS.surface_low, COLORS.line, scaled(4, scale))
        end
        return size
    end

    for index, symbol in ipairs(normalized) do
        draw_symbol_sprite(symbol, x + (index - 1) * (size + gap), y, size, options.outlined, options.alpha or 1, scale)
    end

    return #normalized * size + math.max(0, #normalized - 1) * gap
end

local function draw_assignment_die(assignment, target_rect, options)
    if not assignment then
        return
    end

    if options.assignment_hidden and options.assignment_hidden(assignment) then
        draw_die_back(target_rect, COLORS.enemy)
        return
    end

    draw_die_face(assignment.symbols or assignment.die.symbols, target_rect, false, options.scale)
    if assignment.burned_symbols and #assignment.burned_symbols > 0 then
        draw_burned_symbols(assignment.burned_symbols,
            target_rect.x + target_rect.w + scaled(3, options.scale),
            target_rect.y + target_rect.h - scaled(SYMBOL_SIZE, options.scale) - scaled(4, options.scale),
            options.scale)
    end
end

local function draw_title_strip(part, layout, options)
    local title = layout and layout.label
    if not title then
        return
    end

    local scale = options.scale or 1
    local flip_y = layout.side == "player"
    if not draw_image("bp_title", title, nil, flip_y) then
        draw_box(title, COLORS.surface_low, COLORS.line, scaled(3, scale))
    end

    love.graphics.setFont((options.fonts and options.fonts.small) or BPCard.fonts(scale).small)
    local font = love.graphics.getFont()
    local text_h = font and font:getHeight() or scaled(12, scale)
    local text = part.name or part.id or "Part"
    local text_rect = rect(title.x + scaled(4, scale), title.y, title.w - scaled(8, scale), title.h)
    local text_y = text_rect.y + math.floor((text_rect.h - text_h) / 2)
    local tracking = scaled(Text.TRACKING, scale)
    local fits, width = draw_text(text, text_rect.x, text_y, text_rect.w, "center", options.label_color or COLORS.ink, tracking)

    if not fits and options.warn_title_overflow then
        options.warn_title_overflow(part, text, width, text_rect.w)
    end
end

local function draw_card_state_overlays(part, layout, options)
    local card = layout.card
    local display_status = options.status or (part and part.status) or "healthy"
    local time = options.time or 0
    local damage_asset = nil

    if display_status == "wounded" then
        damage_asset = "bp_card_wounded"
    elseif display_status == "maimed" then
        damage_asset = "bp_card_maimed"
    end

    if damage_asset then
        if not draw_image(damage_asset, card) then
            draw_damage_decoration(part, card, display_status)
        end
    end

    if options.active_die then
        if options.any_valid then
            draw_animated_image("bp_card_valid", card, time)
        elseif options.hovered then
            draw_animated_image("bp_card_invalid", card, time)
        end
    end

    if options.source_highlight then
        if not draw_animated_image("bp_card_hover", card, time) then
            draw_sprite_outline(card, COLORS.selected, 2)
        end
    end

    if options.selected_source then
        if not draw_animated_image("bp_card_selected", card, time) then
            draw_sprite_outline(card, COLORS.selected, 2)
        end
    elseif options.hovered and not options.source_highlight then
        draw_animated_image("bp_card_hover", card, time)
    end
end

local function draw_socket_or_rim_frame(kind, part, layout, options)
    local is_socket = kind == "socket"
    local target = is_socket and layout.socket or layout.rim
    local prefix = is_socket and "die_socket" or "die_rim"
    local assignment = is_socket and options.socket_assignment or options.rim_assignment
    local flip_y = layout.side == "enemy"
    local valid = is_socket and options.socket_valid or options.rim_valid
    local auto_target = is_socket and options.auto_socket_target or options.auto_rim_target
    local outline = auto_target and COLORS.enemy or (valid and COLORS.valid or COLORS.dashed)
    local scale = options.scale or 1

    if not draw_image(prefix, target, nil, flip_y) then
        draw_box(target, COLORS.surface_low, outline, scaled(3, scale))
    end

    local state_prefix = nil
    local state_color = outline
    if options.status == "maimed" then
        state_prefix = prefix .. "_locked"
        state_color = COLORS.invalid
    elseif assignment then
        state_prefix = prefix .. "_occupied"
        state_color = COLORS.line
    elseif valid or auto_target then
        state_prefix = prefix .. "_valid"
        state_color = outline
    elseif options.destination_has_spellmark and options.destination_has_spellmark(kind, part) then
        state_prefix = prefix .. "_spellmarked"
        state_color = COLORS.essence
    end

    if state_prefix and not draw_animated_image(state_prefix, target, options.time or 0, nil, flip_y) then
        draw_sprite_outline(target, state_color, scaled(3, scale))
    end
end

local function draw_slot_track(part, layout, options)
    local slot = part.slot
    local scale = options.scale or 1
    local symbol_size = scaled(SYMBOL_SIZE, scale)
    local row_gap = scaled(SLOT_PIP_ROW_GAP, scale)
    local pip_gap = scaled(SLOT_PIP_GAP, scale)
    local hatch_outline = options.hatch_outline or COLORS.line

    if not slot then
        if not draw_image("die-hatch1", layout.hatch, { 1, 1, 1, 0.35 }) then
            draw_box(layout.hatch, COLORS.surface_low, COLORS.invalid, scaled(3, scale))
        end
        draw_sprite_outline(layout.hatch, COLORS.invalid, scaled(3, scale))
        return
    end

    local hatch_id = "die-hatch1"
    local hungry = Keywords.slot_is_hungry(part, slot)
    local accepting = hatch_outline == COLORS.valid or hatch_outline == COLORS.enemy
    local hovered = hatch_outline == COLORS.valid and options.hover_matches and options.hover_matches("slot", part)
    local swallow_frame = options.hatch_swallow_frame and options.hatch_swallow_frame(part)
    if swallow_frame then
        hatch_id = swallow_frame
    elseif options.status == "maimed" then
        hatch_id = "die-hatch1"
    elseif accepting and hovered then
        hatch_id = "die-hatch3"
    elseif accepting or hungry then
        hatch_id = "die-hatch2"
    end

    local hatch_tint = options.status == "maimed" and { 1, 1, 1, 0.45 } or nil
    if not draw_image(hatch_id, layout.hatch, hatch_tint) then
        draw_box(layout.hatch, COLORS.surface, hatch_outline or COLORS.line, scaled(3, scale))
    end

    if hatch_outline == COLORS.valid then
        draw_sprite_outline(layout.hatch, COLORS.valid, scaled(3, scale))
    elseif hatch_outline == COLORS.enemy then
        draw_sprite_outline(layout.hatch, COLORS.enemy, scaled(3, scale))
    elseif options.status == "maimed" then
        draw_sprite_outline(layout.hatch, COLORS.invalid, scaled(3, scale))
    end

    local preview = options.destination_preview and options.destination_preview("slot", part)
    local preview_by_index = {}
    if preview and preview.valid then
        for _, entry in ipairs(preview.lit_entries or {}) do
            preview_by_index[entry.index] = entry
        end
    elseif preview then
        draw_sprite_outline(layout.hatch, COLORS.invalid, scaled(3, scale))
    end

    local cost = slot.cost or {}
    local row_count = #cost > SLOT_PIP_ROW_LIMIT and 2 or 1
    local columns_per_row = math.max(1, math.ceil(#cost / row_count))
    local track_content_h = row_count * symbol_size + (row_count - 1) * row_gap
    local first_row_y = layout.track.y + math.floor(math.max(0, layout.track.h - track_content_h) / 2)
    local last_pip_x = layout.track.x
    local last_pip_y = first_row_y

    for index, symbol in ipairs(cost) do
        local lit = part.slot_charge and part.slot_charge[index]
        local previewed = preview_by_index[index] ~= nil
        local row_index = math.floor((index - 1) / columns_per_row) + 1
        local column_index = ((index - 1) % columns_per_row) + 1
        local row_start_index = (row_index - 1) * columns_per_row + 1
        local pips_in_row = math.min(columns_per_row, #cost - row_start_index + 1)
        local row_width = pips_in_row * symbol_size + math.max(0, pips_in_row - 1) * pip_gap
        local row_start_x = layout.track.x + math.floor(math.max(0, layout.track.w - row_width) / 2)
        local pip_x = row_start_x + (column_index - 1) * (symbol_size + pip_gap)
        local pip_y = first_row_y + (row_index - 1) * (symbol_size + row_gap)
        if previewed then
            set_color({ 1, 0.88, 0.35, 0.5 })
            love.graphics.rectangle("fill", pip_x - 1, pip_y - 1, symbol_size + 2, symbol_size + 2, 2, 2)
        end
        if hungry then
            draw_wildcard_pip(pip_x, pip_y, symbol_size, lit, previewed)
        else
            draw_symbol_sprite(symbol, pip_x, pip_y, symbol_size, not (lit or previewed), lit and 1 or (previewed and 0.95 or 0.85), scale)
        end
        last_pip_x = pip_x
        last_pip_y = pip_y
    end

    if preview and preview.valid and #preview.burned > 0 then
        draw_burned_symbols(preview.burned, last_pip_x + symbol_size + scaled(4, scale), last_pip_y, scale)
    end

    love.graphics.setFont((options.fonts and options.fonts.tiny) or BPCard.fonts(scale).tiny)
    draw_text(truncate_tracked_text(slot.name or "Slot", layout.slot_label.w, scaled(Text.TRACKING, scale)),
        layout.slot_label.x, layout.slot_label.y, layout.slot_label.w, "center", COLORS.muted, scaled(Text.TRACKING, scale))
end

function BPCard.total_width(scale)
    return scaled(CARD_WIDTH, scale)
end

function BPCard.total_height(scale)
    scale = scale or 1
    return scaled(DIE_SIZE - 6 + CARD_HEIGHT + TITLE_HEIGHT, scale)
end

function BPCard.layout_at(x, y, side, scale)
    scale = scale or 1
    side = side or "player"

    local card_w = scaled(CARD_WIDTH, scale)
    local card_h = scaled(CARD_HEIGHT, scale)
    local title_h = scaled(TITLE_HEIGHT, scale)
    local die_size = scaled(DIE_SIZE, scale)
    local card_y = y
    if side == "player" then
        card_y = y + scaled(DIE_SIZE - 6, scale)
    elseif side == "enemy" then
        card_y = y + title_h
    end

    local card = rect(x, card_y, card_w, card_h)
    local left_x = card.x + scaled(4, scale)
    local right_x = card.x + scaled(BP_LEFT_SECTOR_WIDTH, scale)
    local right_w = card.w - scaled(BP_LEFT_SECTOR_WIDTH, scale) - scaled(4, scale)
    local rim_y = side == "enemy" and (card.y + card.h - scaled(6, scale)) or (card.y - die_size + scaled(6, scale))
    local socket_y = side == "enemy" and (rim_y - die_size) or (card.y + scaled(6, scale))
    local label_y = side == "enemy" and (card.y - title_h) or (card.y + card.h)
    local meta_y = side == "enemy" and (card.y + scaled(10, scale)) or (card.y + card.h - scaled(16, scale))

    return {
        card = card,
        rim = rect(left_x + scaled(2, scale), rim_y, die_size, die_size),
        socket = rect(left_x + scaled(2, scale), socket_y, die_size, die_size),
        hatch = rect(right_x + math.floor((right_w - die_size) / 2), card.y + scaled(24, scale), die_size, die_size),
        track = rect(right_x + scaled(2, scale), card.y + scaled(62, scale), right_w - scaled(4, scale),
            scaled(SYMBOL_SIZE * 2 + SLOT_PIP_ROW_GAP, scale)),
        slot_label = rect(right_x + scaled(1, scale), card.y + scaled(7, scale), right_w - scaled(2, scale),
            scaled(12, scale)),
        label = rect(card.x, label_y, card.w, title_h),
        meta = rect(left_x + scaled(8, scale), meta_y, scaled(28, scale), scaled(10, scale)),
        side = side,
        scale = scale
    }
end

function BPCard.draw(part, layout, options)
    if not part then
        return BPCard.draw_empty(layout, options)
    end

    options = options or {}
    options.scale = options.scale or layout.scale or (layout.card and layout.card.w / CARD_WIDTH) or 1
    options.status = options.status or part.status or "healthy"

    love.graphics.setFont((options.fonts and options.fonts.small) or BPCard.fonts(options.scale).small)
    if not draw_image("bp_card", layout.card) then
        draw_box(layout.card, COLORS.panel, COLORS.line, scaled(6, options.scale))
    end

    options.hovered = options.hovered or false
    options.any_valid = options.any_valid
        or options.socket_valid
        or options.rim_valid
        or options.slot_valid
        or options.auto_socket_target
        or options.auto_rim_target
        or options.auto_slot_target

    options.hatch_outline = options.auto_slot_target and COLORS.enemy or (options.slot_valid and COLORS.valid or COLORS.line)
    draw_card_state_overlays(part, layout, options)
    draw_hp_badge(part.hp_value or 1, layout.meta.x, layout.meta.y, options.scale)
    draw_keyword_badges(part, layout, options)

    draw_socket_or_rim_frame("socket", part, layout, options)
    draw_socket_or_rim_frame("rim", part, layout, options)

    draw_assignment_die(options.socket_assignment, layout.socket, options)
    draw_assignment_die(options.rim_assignment, layout.rim, options)
    if options.draw_socket_or_rim_preview then
        options.draw_socket_or_rim_preview("socket", part, layout.socket)
        options.draw_socket_or_rim_preview("rim", part, layout.rim)
    end

    if options.status == "maimed" and not options.slot_valid then
        options.hatch_outline = COLORS.invalid
    end
    draw_slot_track(part, layout, options)

    options.label_color = (options.source_highlight or options.selected_source) and COLORS.selected or COLORS.ink
    draw_title_strip(part, layout, options)
end

function BPCard.draw_empty(layout, options)
    options = options or {}
    local scale = options.scale or layout.scale or 1
    love.graphics.setFont((options.fonts and options.fonts.small) or BPCard.fonts(scale).small)
    if not draw_image("bp_card_empty", layout.card) then
        set_color({ COLORS.surface_low[1], COLORS.surface_low[2], COLORS.surface_low[3], 0.18 })
        love.graphics.rectangle("fill", layout.card.x, layout.card.y, layout.card.w, layout.card.h, scaled(6, scale), scaled(6, scale))
        set_color({ COLORS.dashed[1], COLORS.dashed[2], COLORS.dashed[3], 0.38 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", layout.card.x, layout.card.y, layout.card.w, layout.card.h, scaled(6, scale), scaled(6, scale))
    end
    draw_text("empty", layout.card.x, layout.card.y + layout.card.h * 0.42, layout.card.w, "center",
        { COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.52 }, scaled(Text.TRACKING, scale))
end

return BPCard
