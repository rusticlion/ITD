local GameState = require("core.gamestate")
local Assets = require("core.assets")
local Engine = require("combat.v2_engine")
local Events = require("combat.events")
local Demo = require("combat.v2_demo")
local Symbols = require("core.symbols")
local SymbolDie = require("core.symbol_die")
local V2AI = require("combat.v2_ai")

local V2Combat = {}
V2Combat.__index = V2Combat

local MARGIN = 8
local RAIL_WIDTH = 152
local GLOBAL_SPINE_WIDTH = 32
local MAIN_GAP = 8
local STRIP_HEIGHT = 130
local DRAWER_HEIGHT = 54
local DRAWER_GAP = 6
local BODY_PART_SLOTS = 6
local CARD_WIDTH = 116
local CARD_HEIGHT = 88
local TITLE_HEIGHT = 16
local TITLE_MARGIN = 10
local BP_LEFT_SECTOR_WIDTH = 44
local CARD_GAP = 8
local DIE_SIZE = 36
local SYMBOL_SIZE = 12
local CREST_SIZE = 24
local HEART_STACK_MAX = 3
local HEART_ICON_SIZE = 24
local HEART_ICON_GAP = 4
local SLOT_PIP_ROW_LIMIT = 3
local SLOT_PIP_GAP = 1
local SLOT_PIP_ROW_GAP = 1
local AUTO_ALLOC_MOVE_DURATION = 0.42
local AUTO_ALLOC_SETTLE_DURATION = 0.14
local HATCH_SWALLOW_DURATION = 0.4
local RESOLUTION_STEP_DURATION = 1.05
local RESOLUTION_REVEAL_TIME = 0.68
local SLOT_EFFECT_DURATION = 1.1
local COMBAT_END_RETURN_DELAY = 2.35
local UI_FONT_PATH = "assets/fonts/dotgothic16/DotGothic16-Regular.ttf"
local TEXT_TRACKING = 1
local OVERLAY_ANIMATION_FPS = 8
local CREST_ORDER = { "Valor", "Shadow" }

local COLORS = {
    bg = { 34 / 255, 32 / 255, 52 / 255, 1 },
    panel = { 44 / 255, 41 / 255, 64 / 255, 0.96 },
    rail = { 26 / 255, 25 / 255, 40 / 255, 0.98 },
    surface = { 38 / 255, 36 / 255, 56 / 255, 0.88 },
    surface_low = { 18 / 255, 17 / 255, 29 / 255, 0.4 },
    surface_high = { 70 / 255, 66 / 255, 96 / 255, 0.72 },
    ink = { 0.96, 0.95, 1, 1 },
    muted = { 0.68, 0.66, 0.78, 1 },
    line = { 0.86, 0.84, 0.94, 0.52 },
    dashed = { 0.58, 0.55, 0.68, 0.58 },
    player = { 0.16, 0.78, 0.61, 1 },
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

local CREST_VISUALS = {
    Valor = {
        symbol = Symbols.STRIKE,
        fill = { 0.58, 0.34, 0.15, 1 },
        line = COLORS.attack
    },
    Shadow = {
        symbol = Symbols.WARD,
        fill = { 0.25, 0.25, 0.38, 1 },
        line = COLORS.defense
    }
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

local function set_color(color)
    love.graphics.setColor(color)
end

local function new_ui_font(size)
    local ok, font = pcall(love.graphics.newFont, UI_FONT_PATH, size)
    if not ok then
        font = love.graphics.newFont(size)
    end

    if font and font.setFilter then
        font:setFilter("nearest", "nearest")
    end

    return font
end

local function point_in_rect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function copy_rect(r)
    if not r then
        return nil
    end

    return rect(r.x, r.y, r.w, r.h)
end

local function centered_rect(r, size)
    if not r then
        return rect(0, 0, size, size)
    end

    return rect(r.x + (r.w - size) / 2, r.y + (r.h - size) / 2, size, size)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function ease_out_cubic(t)
    local clamped = math.max(0, math.min(1, t or 0))
    return 1 - ((1 - clamped) * (1 - clamped) * (1 - clamped))
end

local function contains(list, value)
    for _, existing in ipairs(list or {}) do
        if existing == value then
            return true
        end
    end
    return false
end

local function is_destination_kind(kind)
    return kind == "socket" or kind == "rim" or kind == "slot"
end

local function classify_preview_symbols(symbols, relevant_symbol)
    local used = {}
    local burned = {}
    local relevant = Symbols.normalize(relevant_symbol)

    for _, symbol in ipairs(symbols or {}) do
        if symbol == relevant then
            table.insert(used, symbol)
        elseif symbol ~= Symbols.BLANK then
            table.insert(burned, symbol)
        end
    end

    return used, burned
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

local function utf8_char_size(first_byte)
    if not first_byte or first_byte < 0x80 then
        return 1
    elseif first_byte >= 0xC2 and first_byte <= 0xDF then
        return 2
    elseif first_byte >= 0xE0 and first_byte <= 0xEF then
        return 3
    elseif first_byte >= 0xF0 and first_byte <= 0xF4 then
        return 4
    end

    return 1
end

local function is_utf8_continuation(byte)
    return byte and byte >= 0x80 and byte <= 0xBF
end

local function chars_for_text(text)
    local source = tostring(text or "")
    local chars = {}
    local index = 1

    while index <= #source do
        local size = utf8_char_size(source:byte(index))
        local stop = index + size - 1
        local valid = stop <= #source

        for offset = 1, size - 1 do
            if not is_utf8_continuation(source:byte(index + offset)) then
                valid = false
                break
            end
        end

        if valid then
            table.insert(chars, source:sub(index, stop))
            index = stop + 1
        else
            table.insert(chars, source:sub(index, index))
            index = index + 1
        end
    end

    return chars
end

local function tracked_text_width(text)
    local font = love.graphics.getFont()
    if not font then
        return 0
    end

    local width = 0
    local chars = chars_for_text(text)
    for index, char in ipairs(chars) do
        local ok, char_width = pcall(font.getWidth, font, char)
        if not ok then
            ok, char_width = pcall(font.getWidth, font, "?")
        end
        width = width + (ok and char_width or 0)
        if index < #chars then
            width = width + TEXT_TRACKING
        end
    end

    return width
end

local function split_long_word(word, max_width)
    local lines = {}
    local current = ""

    for _, char in ipairs(chars_for_text(word)) do
        local candidate = current .. char
        if current ~= "" and tracked_text_width(candidate) > max_width then
            table.insert(lines, current)
            current = char
        else
            current = candidate
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end

    return lines
end

local function wrap_tracked_text(text, max_width)
    local width = max_width or 200
    local lines = {}
    local source = tostring(text or "")

    for paragraph in (source .. "\n"):gmatch("(.-)\n") do
        local current = ""
        local saw_word = false

        for word in paragraph:gmatch("%S+") do
            saw_word = true
            local candidate = current == "" and word or (current .. " " .. word)
            if current == "" or tracked_text_width(candidate) <= width then
                current = candidate
            else
                table.insert(lines, current)
                if tracked_text_width(word) <= width then
                    current = word
                else
                    local pieces = split_long_word(word, width)
                    for index = 1, #pieces - 1 do
                        table.insert(lines, pieces[index])
                    end
                    current = pieces[#pieces] or ""
                end
            end
        end

        if saw_word or current ~= "" then
            table.insert(lines, current)
        elseif #lines == 0 then
            table.insert(lines, "")
        end
    end

    return lines
end

local function truncate_tracked_text(text, max_width)
    local source = tostring(text or "")
    if tracked_text_width(source) <= max_width then
        return source
    end

    local suffix = ".."
    local available = math.max(0, (max_width or 0) - tracked_text_width(suffix))
    local result = ""

    for _, char in ipairs(chars_for_text(source)) do
        local candidate = result .. char
        if tracked_text_width(candidate) > available then
            break
        end
        result = candidate
    end

    return result .. suffix
end

local function draw_tracked_line(text, x, y, color)
    local font = love.graphics.getFont()
    local cursor_x = x
    set_color(color or COLORS.ink)

    local characters = chars_for_text(text)
    for index, char in ipairs(characters) do
        local ok = pcall(love.graphics.print, char, cursor_x, y)
        local measured_char = char
        if not ok then
            measured_char = "?"
            love.graphics.print(measured_char, cursor_x, y)
        end

        local width_ok, char_width = pcall(font.getWidth, font, measured_char)
        if not width_ok then
            width_ok, char_width = pcall(font.getWidth, font, "?")
        end
        cursor_x = cursor_x + (width_ok and char_width or 0)
        if index < #characters then
            cursor_x = cursor_x + TEXT_TRACKING
        end
    end
end

local function draw_text(text, x, y, w, align, color)
    local width = w or 200
    local font = love.graphics.getFont()
    local line_height = font and font:getHeight() or 12
    local lines = wrap_tracked_text(text, width)

    for index, line in ipairs(lines) do
        local line_width = tracked_text_width(line)
        local line_x = x
        if align == "center" then
            line_x = x + math.floor((width - line_width) / 2)
        elseif align == "right" then
            line_x = x + width - line_width
        end

        draw_tracked_line(line, line_x, y + (index - 1) * line_height, color)
    end
end

local function draw_single_line_text(text, x, y, w, align, color)
    local width = w or 200
    local line = tostring(text or "")
    local line_width = tracked_text_width(line)
    local line_x = x

    if align == "center" then
        line_x = x + math.floor((width - line_width) / 2)
    elseif align == "right" then
        line_x = x + width - line_width
    end

    draw_tracked_line(line, line_x, y, color)
    return line_width <= width, line_width
end

local function wrapped_text_height(text, w)
    local font = love.graphics.getFont()
    if not font then
        return 12
    end

    return math.max(1, #wrap_tracked_text(text, w or 200)) * font:getHeight()
end

local function draw_wrapped_text(text, x, y, w, align, color, gap)
    draw_text(text, x, y, w, align, color)
    return y + wrapped_text_height(text, w) + (gap or 4)
end

local function draw_status_dot(part, x, y)
    set_color(STATUS_COLORS[part.status or "healthy"] or STATUS_COLORS.healthy)
    love.graphics.circle("fill", x, y, 4)
end

local function draw_hp_badge(value, x, y)
    local total = math.max(1, value or 1)
    for index = 1, total do
        local px = x + (index - 1) * 7
        set_color(COLORS.ink)
        love.graphics.polygon("fill",
            px + 3, y,
            px + 6, y + 3,
            px + 3, y + 6,
            px, y + 3)
    end
end

local function draw_heart_icon(r, active, color)
    local asset_id = active and "heart_point" or "heart_point_depleted"
    if draw_image(asset_id, r) then
        return
    end

    local fill = color or COLORS.player
    local outline = active and COLORS.ink or COLORS.dashed
    local alpha = active and 0.72 or 0.18
    local cx = r.x + r.w / 2
    local top = r.y + 4

    set_color({ fill[1], fill[2], fill[3], alpha })
    love.graphics.circle("fill", r.x + r.w * 0.32, top + 3, r.w * 0.22)
    love.graphics.circle("fill", r.x + r.w * 0.68, top + 3, r.w * 0.22)
    love.graphics.polygon("fill",
        r.x + 2, top + 5,
        r.x + r.w - 2, top + 5,
        cx, r.y + r.h - 2)

    set_color({ outline[1], outline[2], outline[3], active and 0.92 or 0.5 })
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", r.x + r.w * 0.32, top + 3, r.w * 0.22)
    love.graphics.circle("line", r.x + r.w * 0.68, top + 3, r.w * 0.22)
    love.graphics.line(r.x + 2, top + 5, cx, r.y + r.h - 2, r.x + r.w - 2, top + 5)

    if not active then
        set_color({ COLORS.ink[1], COLORS.ink[2], COLORS.ink[3], 0.62 })
        love.graphics.line(r.x + 5, r.y + 4, r.x + 9, r.y + 9)
        love.graphics.line(r.x + 9, r.y + 9, r.x + 6, r.y + 14)
        love.graphics.line(r.x + 11, r.y + 5, r.x + 8, r.y + 10)
        love.graphics.line(r.x + 8, r.y + 10, r.x + 12, r.y + 15)
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

local function draw_symbol_chip(symbol, x, y, w, h)
    local chip = rect(x, y, w, h)
    draw_box(chip, COLORS.surface, symbol_color(symbol), 4)
    draw_text(Symbols.display(symbol), x + 2, y + 7, w - 4, "center", symbol_color(symbol))
end

local function draw_symbol_sprite(symbol, x, y, size, outlined, alpha)
    local normalized = Symbols.normalize(symbol)
    if normalized == Symbols.BLANK then
        return false
    end

    local asset_id = outlined and SYMBOL_OUTLINE_ASSETS[normalized] or SYMBOL_ASSETS[normalized]
    local image = asset_id and Assets.images and Assets.images[asset_id]
    if not image then
        draw_symbol_chip(normalized, x, y, size, size)
        return false
    end

    set_color({ 1, 1, 1, alpha or 1 })
    love.graphics.draw(image, x, y, 0, size / image:getWidth(), size / image:getHeight())
    return true
end

local function draw_hex_chip(r, fill, line, active)
    local inset = 2
    local points = {
        r.x + r.w * 0.5, r.y + inset,
        r.x + r.w - inset, r.y + r.h * 0.26,
        r.x + r.w - inset, r.y + r.h * 0.74,
        r.x + r.w * 0.5, r.y + r.h - inset,
        r.x + inset, r.y + r.h * 0.74,
        r.x + inset, r.y + r.h * 0.26
    }

    local fill_color = fill or COLORS.panel
    if not active then
        fill_color = { fill_color[1], fill_color[2], fill_color[3], 0.38 }
    end

    set_color(fill_color)
    love.graphics.polygon("fill", points)
    set_color(line or COLORS.line)
    love.graphics.setLineWidth(active and 2 or 1)
    love.graphics.polygon("line", points)
end

local function queue_entry_symbol(entry)
    local effect = entry and entry.effect or {}
    if effect.type == "gain_crest" then
        return Symbols.ESSENCE
    elseif effect.type == "add_next_symbol" then
        return effect.symbol or Symbols.STRIKE
    elseif effect.type == "damage_opponent_part" then
        return Symbols.STRIKE
    elseif effect.type == "heal_self" then
        return Symbols.BLOOD
    end

    return Symbols.BLANK
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

local function draw_symbol_cluster(symbols, r, alpha, outlined)
    local visible_symbols = visible_face_symbols(symbols)
    local count = #visible_symbols
    if count == 1 then
        draw_symbol_sprite(visible_symbols[1], r.x + 12, r.y + 12, SYMBOL_SIZE, outlined, alpha)
    elseif count == 2 then
        draw_symbol_sprite(visible_symbols[1], r.x + 7, r.y + 12, SYMBOL_SIZE, outlined, alpha)
        draw_symbol_sprite(visible_symbols[2], r.x + 17, r.y + 12, SYMBOL_SIZE, outlined, alpha)
    elseif count >= 3 then
        draw_symbol_sprite(visible_symbols[1], r.x + 5, r.y + 12, SYMBOL_SIZE, outlined, alpha)
        draw_symbol_sprite(visible_symbols[2], r.x + 12, r.y + 12, SYMBOL_SIZE, outlined, alpha)
        draw_symbol_sprite(visible_symbols[3], r.x + 19, r.y + 12, SYMBOL_SIZE, outlined, alpha)
    end
end

local function draw_burned_symbols(symbols, x, y)
    for index, symbol in ipairs(symbols or {}) do
        local px = x + (index - 1) * (SYMBOL_SIZE + 2)
        draw_symbol_sprite(symbol, px, y, SYMBOL_SIZE, false, 0.42)
        set_color({ COLORS.attack[1], COLORS.attack[2], COLORS.attack[3], 0.78 })
        love.graphics.setLineWidth(1)
        love.graphics.line(px - 1, y + SYMBOL_SIZE + 1, px + SYMBOL_SIZE + 1, y - 1)
    end
end

local function draw_die_face(symbols, r, is_selected)
    local outline = is_selected and COLORS.selected or COLORS.line
    if not draw_image("empty_die", r) then
        draw_box(r, COLORS.surface, outline, 5)
    end

    draw_symbol_cluster(symbols, r, 1, false)

    if is_selected then
        draw_sprite_outline(r, outline, 4)
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

local function face_has_degradation(list, face_index)
    for _, index in ipairs(list or {}) do
        if tonumber(index) == face_index then
            return true
        end
    end

    return false
end

local function draw_crack_overlay(r, level)
    if level == "heavy" then
        set_color({ 0, 0, 0, 0.28 })
        love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4, 4, 4)
        set_color({ COLORS.ink[1], COLORS.ink[2], COLORS.ink[3], 0.82 })
        love.graphics.setLineWidth(2)
        love.graphics.line(r.x + 6, r.y + 7, r.x + r.w - 7, r.y + r.h - 8)
        love.graphics.line(r.x + r.w - 8, r.y + 8, r.x + 8, r.y + r.h - 7)
    elseif level == "light" then
        set_color({ COLORS.essence[1], COLORS.essence[2], COLORS.essence[3], 0.18 })
        love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4, 4, 4)
        set_color({ COLORS.essence[1], COLORS.essence[2], COLORS.essence[3], 0.85 })
        love.graphics.setLineWidth(1)
        love.graphics.line(r.x + r.w - 11, r.y + 7, r.x + r.w - 7, r.y + 14)
        love.graphics.line(r.x + r.w - 7, r.y + 14, r.x + r.w - 12, r.y + 22)
    end
end

local function sorted_face_indexes(list)
    local indexes = {}
    for _, index in ipairs(list or {}) do
        local numeric = tonumber(index)
        if numeric then
            table.insert(indexes, numeric)
        end
    end

    table.sort(indexes)
    return indexes
end

local function durable_face_indexes(die)
    local indexes = {}
    for face_index = 1, 6 do
        if not face_has_degradation(die and die.wound_faces, face_index)
            and not face_has_degradation(die and die.maim_faces, face_index) then
            table.insert(indexes, face_index)
        end
    end

    return indexes
end

local function make_log_line(event, data)
    if event == Events.CREST_EXPENDED then
        return string.format("%s expends %s.", data.combatant.name, data.crest)
    elseif event == Events.SLOT_FED then
        return string.format("%s feeds %s.", data.combatant.name, data.slot.name)
    elseif event == Events.SLOT_RESOLVED then
        return string.format("%s resolves %s.", data.combatant.name, data.slot.name)
    elseif event == Events.SPELLMARK_OPENED then
        return string.format("%s opens %s.", data.combatant.name, data.spellmark.name or "a spellmark")
    elseif event == Events.SPELLMARK_RESOLVED then
        return string.format("%s marks %s.", data.combatant.name, data.part.name)
    elseif event == Events.LATCH_EJECTED then
        return string.format("Latch ejected from %s.", data.part.name)
    elseif event == Events.DAMAGE_DEALT then
        return string.format("%s: %s -> %s.", data.body_part.name, data.status_before, data.status_after)
    elseif event == Events.PART_RESOLVED then
        return string.format("%s ATK %d / DEF %d.", data.part.name, data.strike_count, data.ward_count)
    end
    return nil
end

function V2Combat:enter()
    self.engine = Engine:new()
    self.player, self.enemy = Demo.create_combatants()
    self.engine:add_combatant(self.player)
    self.engine:add_combatant(self.enemy)

    self.card_rects = {}
    self.die_rects = {}
    self.enemy_die_rects = {}
    self.crest_rects = {}
    self.hover = nil
    self.selected_die = nil
    self.drag = nil
    self.auto_allocation = nil
    self.assignment_visibility = setmetatable({}, { __mode = "k" })
    self.slot_activation_effects = {}
    self.hatch_swallow_effects = setmetatable({}, { __mode = "k" })
    self.combat_end = nil
    self.ui_time = 0
    self.title_overflow_warnings = {}
    self.player_can_allocate = false
    self.enemy_response_pending = false
    self.event_visibility_context = nil
    self.log = {}
    self.message = "Drag a die to a rim, socket, or hatch. C confirms."
    self.fonts = {
        title = new_ui_font(24),
        body = new_ui_font(12),
        small = new_ui_font(10),
        tiny = new_ui_font(9)
    }

    self:register_events()
    self.engine:start_combat()
    self:begin_allocation_phase()
end

function V2Combat:register_events()
    local tracked = {
        Events.CREST_EXPENDED,
        Events.SLOT_FED,
        Events.SLOT_RESOLVED,
        Events.SPELLMARK_OPENED,
        Events.SPELLMARK_RESOLVED,
        Events.LATCH_EJECTED,
        Events.PART_RESOLVED,
        Events.DAMAGE_DEALT
    }

    for _, event_name in ipairs(tracked) do
        self.engine:on(event_name, function(data)
            if not self:should_log_event(event_name, data) then
                return
            end

            local line = make_log_line(event_name, data)
            if line then
                table.insert(self.log, 1, line)
                while #self.log > 8 do
                    table.remove(self.log)
                end
            end
        end)
    end

    self.engine:on(Events.SLOT_RESOLVED, function(data)
        if self:should_log_event(Events.SLOT_RESOLVED, data) then
            self:show_slot_activation(data)
        end
    end)
end

function V2Combat:should_log_event(_event_name, data)
    if self.event_visibility_context == "hidden" and data and data.combatant == self.enemy then
        return false
    end

    return true
end

function V2Combat:show_slot_activation(data)
    if not data then
        return
    end

    table.insert(self.slot_activation_effects, {
        part = data.part,
        slot = data.slot,
        target_part = data.effect and data.effect.target_part,
        effect = data.effect,
        elapsed = 0,
        duration = SLOT_EFFECT_DURATION
    })
end

function V2Combat:main_x()
    return MARGIN + GLOBAL_SPINE_WIDTH + MAIN_GAP
end

function V2Combat:rail_rect()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    return rect(width - RAIL_WIDTH - MARGIN, MARGIN, RAIL_WIDTH, height - MARGIN * 2)
end

function V2Combat:global_spine_rect()
    local height = love.graphics.getHeight()
    return rect(MARGIN, MARGIN, GLOBAL_SPINE_WIDTH, height - MARGIN * 2)
end

function V2Combat:main_width()
    local rail = self:rail_rect()
    return rail.x - self:main_x() - MAIN_GAP
end

function V2Combat:enemy_strip_rect()
    return rect(self:main_x(), MARGIN, self:main_width(), STRIP_HEIGHT)
end

function V2Combat:enemy_drawer_rect()
    local enemy_strip = self:enemy_strip_rect()
    return rect(self:main_x(), enemy_strip.y + enemy_strip.h + DRAWER_GAP, self:main_width(), DRAWER_HEIGHT)
end

function V2Combat:player_drawer_rect()
    local player_strip = self:player_strip_rect()
    return rect(self:main_x(), player_strip.y - DRAWER_HEIGHT - DRAWER_GAP, self:main_width(), DRAWER_HEIGHT)
end

function V2Combat:center_rect()
    local enemy_drawer = self:enemy_drawer_rect()
    local player_drawer = self:player_drawer_rect()
    local y = enemy_drawer.y + enemy_drawer.h + DRAWER_GAP
    return rect(self:main_x(), y, self:main_width(), player_drawer.y - y - DRAWER_GAP)
end

function V2Combat:drawer_dice_area(drawer)
    return rect(drawer.x + 96, drawer.y + 9, drawer.w - 196, DIE_SIZE)
end

function V2Combat:drawer_crest_y(drawer, side)
    if side == "enemy" then
        return drawer.y + drawer.h - CREST_SIZE - 3
    end

    return drawer.y + 3
end

function V2Combat:player_strip_rect()
    local height = love.graphics.getHeight()
    return rect(self:main_x(), height - MARGIN - STRIP_HEIGHT, self:main_width(), STRIP_HEIGHT)
end

function V2Combat:layout_cards(combatant, strip, side)
    local total_w = BODY_PART_SLOTS * CARD_WIDTH + (BODY_PART_SLOTS - 1) * CARD_GAP
    local start_x = strip.x + math.floor((strip.w - total_w) / 2)
    local card_w = CARD_WIDTH
    local card_h = CARD_HEIGHT
    local y = strip.y + TITLE_MARGIN + TITLE_HEIGHT
    if side == "player" then
        y = strip.y + strip.h - TITLE_MARGIN - TITLE_HEIGHT - card_h
    end

    for index = 1, BODY_PART_SLOTS do
        local part = (combatant.body_parts or {})[index]
        local x = start_x + (index - 1) * (card_w + CARD_GAP)
        local card = rect(x, y, card_w, card_h)
        local left_x = card.x + 4
        local right_x = card.x + BP_LEFT_SECTOR_WIDTH
        local right_w = card.w - BP_LEFT_SECTOR_WIDTH - 4
        local rim_y = side == "enemy" and (card.y + card.h - 6) or (card.y - DIE_SIZE + 6)
        local rim = rect(left_x + 2, rim_y, DIE_SIZE, DIE_SIZE)
        local socket_y = side == "enemy" and (rim_y - DIE_SIZE) or (card.y + 6)
        local socket = rect(left_x + 2, socket_y, DIE_SIZE, DIE_SIZE)
        local hatch = rect(right_x + math.floor((right_w - DIE_SIZE) / 2), card.y + 24, DIE_SIZE, DIE_SIZE)
        local track = rect(right_x + 2, card.y + 62, right_w - 4, SYMBOL_SIZE * 2 + SLOT_PIP_ROW_GAP)
        local slot_label = rect(right_x + 1, card.y + 7, right_w - 2, 12)
        local label_y = side == "enemy" and (card.y - TITLE_HEIGHT) or (card.y + card.h)
        local label = rect(card.x, label_y, card.w, TITLE_HEIGHT)
        local meta_y = side == "enemy" and (card.y + 10) or (card.y + card.h - 16)
        local meta = rect(left_x + 8, meta_y, 28, 10)

        if part then
            self.card_rects[part] = {
                card = card,
                rim = rim,
                socket = socket,
                hatch = hatch,
                track = track,
                slot_label = slot_label,
                label = label,
                meta = meta,
                side = side,
                combatant = combatant,
                part = part,
                slot_index = index
            }
        else
            table.insert(self.empty_card_rects, {
                card = card,
                label = label,
                side = side,
                slot_index = index
            })
        end
    end
end

function V2Combat:layout()
    self.card_rects = {}
    self.die_rects = {}
    self.enemy_die_rects = {}
    self.crest_rects = {}
    self.enemy_crest_rects = {}
    self.empty_card_rects = {}
    self.drawers = {
        enemy = self:enemy_drawer_rect(),
        player = self:player_drawer_rect()
    }

    self:layout_cards(self.enemy, self:enemy_strip_rect(), "enemy")
    self:layout_cards(self.player, self:player_strip_rect(), "player")

    local function layout_pool_dice(pool, area, rects)
        local total_w = math.max(0, #pool * DIE_SIZE + math.max(0, #pool - 1) * 8)
        local start_x = area.x + math.floor((area.w - total_w) / 2)
        local y = area.y

        for index, die in ipairs(pool) do
            rects[die] = rect(start_x + (index - 1) * (DIE_SIZE + 8), y, DIE_SIZE, DIE_SIZE)
        end
    end

    local enemy_pool = self.engine:get_pool(self.enemy)
    local player_pool = self.engine:get_pool(self.player)

    layout_pool_dice(enemy_pool, self:drawer_dice_area(self.drawers.enemy), self.enemy_die_rects)
    layout_pool_dice(player_pool, self:drawer_dice_area(self.drawers.player), self.die_rects)

    local function layout_crests(combatant, combatant_rects, drawer, side)
        local crest_x = drawer.x + 10
        local crest_y = self:drawer_crest_y(drawer, side)
        local visible_index = 0
        for _, crest in ipairs(CREST_ORDER) do
            if combatant:get_crest_count(crest) > 0 then
                combatant_rects[crest] = rect(crest_x + visible_index * (CREST_SIZE + 7), crest_y, CREST_SIZE, CREST_SIZE)
                visible_index = visible_index + 1
            end
        end
    end

    layout_crests(self.enemy, self.enemy_crest_rects, self.drawers.enemy, "enemy")
    layout_crests(self.player, self.crest_rects, self.drawers.player, "player")

    self.confirm_rect = rect(self.drawers.player.x + self.drawers.player.w - 92, self.drawers.player.y + 3, 84, 48)

    local spine = self:global_spine_rect()
    local heart_stack_h = HEART_STACK_MAX * HEART_ICON_SIZE + (HEART_STACK_MAX - 1) * HEART_ICON_GAP
    local heart_x = spine.x + math.floor((spine.w - HEART_ICON_SIZE) / 2)
    local enemy_heart_y = spine.y + 10
    local player_heart_y = spine.y + spine.h - 10 - heart_stack_h

    local function layout_heart_stack(start_y)
        local rects = {}
        for index = 1, HEART_STACK_MAX do
            rects[index] = rect(heart_x, start_y + (index - 1) * (HEART_ICON_SIZE + HEART_ICON_GAP), HEART_ICON_SIZE, HEART_ICON_SIZE)
        end
        return rects
    end

    self.enemy_heart_rects = layout_heart_stack(enemy_heart_y)
    self.player_heart_rects = layout_heart_stack(player_heart_y)
    self.queue_rect = rect(spine.x + 4, spine.y + math.floor((spine.h - 190) / 2), 24, 190)

    local initiative = tostring(self.engine and self.engine.initiative or "player")
    local initiative_y = spine.y + math.floor((spine.h - 24) / 2)
    if initiative == "enemy" then
        initiative_y = enemy_heart_y + heart_stack_h + 10
    elseif initiative == "player" then
        initiative_y = player_heart_y - 34
    end
    self.initiative_rect = rect(spine.x + 4, initiative_y, 24, 24)
end

function V2Combat:update(dt)
    self:layout()
    local delta = dt or 0
    self.ui_time = (self.ui_time or 0) + delta
    local mx, my = love.mouse.getPosition()

    if self.combat_end then
        self:update_hatch_swallow_effects(delta)
        self:update_slot_activation_effects(delta)
        self:update_combat_end(delta)
        self:update_hover(mx, my)
        return
    end

    if self.drag then
        self.drag.x = mx
        self.drag.y = my
    end
    self:update_auto_allocation(delta)
    self:update_resolution_playback(delta)
    self:update_hatch_swallow_effects(delta)
    self:update_slot_activation_effects(delta)

    if self.engine.state == "COMPLETE" and not self.resolution_playback and not self.auto_allocation then
        self:begin_combat_end()
    end

    self:update_hover(mx, my)
end

function V2Combat:update_slot_activation_effects(dt)
    for index = #(self.slot_activation_effects or {}), 1, -1 do
        local effect = self.slot_activation_effects[index]
        effect.elapsed = (effect.elapsed or 0) + (dt or 0)
        if effect.elapsed >= (effect.duration or SLOT_EFFECT_DURATION) then
            table.remove(self.slot_activation_effects, index)
        end
    end
end

function V2Combat:show_hatch_swallow(part)
    if not part then
        return
    end

    self.hatch_swallow_effects = self.hatch_swallow_effects or setmetatable({}, { __mode = "k" })
    self.hatch_swallow_effects[part] = HATCH_SWALLOW_DURATION
end

function V2Combat:update_hatch_swallow_effects(dt)
    local effects = self.hatch_swallow_effects
    if not effects then
        return
    end

    for part, remaining in pairs(effects) do
        local next_remaining = (remaining or 0) - (dt or 0)
        if next_remaining <= 0 then
            effects[part] = nil
        else
            effects[part] = next_remaining
        end
    end
end

function V2Combat:is_hatch_swallowing(part)
    return part and self.hatch_swallow_effects and self.hatch_swallow_effects[part] ~= nil
end

function V2Combat:hatch_swallow_frame(part)
    local remaining = part and self.hatch_swallow_effects and self.hatch_swallow_effects[part]
    if not remaining then
        return nil
    end

    local progress = 1 - math.max(0, math.min(1, remaining / HATCH_SWALLOW_DURATION))
    if progress < 0.25 then
        return "die-hatch4"
    elseif progress < 0.5 then
        return "die-hatch3"
    elseif progress < 0.75 then
        return "die-hatch2"
    end

    return "die-hatch1"
end

function V2Combat:begin_combat_end()
    if self.combat_end then
        return
    end

    local winner = self.engine and self.engine.winner
    local result = "draw"
    local title = "Combat Ended"
    if winner == self.player then
        result = "win"
        title = "You Win"
    elseif winner == self.enemy then
        result = "lose"
        title = "You Lose"
    end

    self.combat_end = {
        result = result,
        title = title,
        elapsed = 0,
        delay = COMBAT_END_RETURN_DELAY
    }
    self.player_can_allocate = false
    self.enemy_response_pending = false
    self.selected_die = nil
    self.drag = nil
    self.message = title .. ". Returning to the Dream."
end

function V2Combat:update_combat_end(dt)
    self.combat_end.elapsed = (self.combat_end.elapsed or 0) + (dt or 0)
    if self.combat_end.elapsed >= (self.combat_end.delay or COMBAT_END_RETURN_DELAY) then
        self:return_to_overworld()
    end
end

function V2Combat:return_to_overworld()
    GameState.switch(require("states.overworld"))
end

function V2Combat:update_hover(mx, my)
    self.hover = nil

    if not self.drag then
        for die, die_rect in pairs(self.die_rects) do
            if point_in_rect(mx, my, die_rect) then
                self.hover = { kind = "die", die = die, combatant = self.player }
                return
            end
        end

        for die, die_rect in pairs(self.enemy_die_rects) do
            if point_in_rect(mx, my, die_rect) then
                self.hover = { kind = "die", die = die, combatant = self.enemy }
                return
            end
        end
    end

    for crest, crest_rect in pairs(self.crest_rects) do
        if point_in_rect(mx, my, crest_rect) then
            self.hover = { kind = "crest", crest = crest, combatant = self.player }
            return
        end
    end

    for crest, crest_rect in pairs(self.enemy_crest_rects or {}) do
        if point_in_rect(mx, my, crest_rect) then
            self.hover = { kind = "crest", crest = crest, combatant = self.enemy }
            return
        end
    end

    if point_in_rect(mx, my, self.confirm_rect) then
        self.hover = { kind = "confirm" }
        return
    end

    for part, data in pairs(self.card_rects) do
        if point_in_rect(mx, my, data.socket) then
            self.hover = { kind = "socket", part = part, data = data }
            return
        elseif point_in_rect(mx, my, data.rim) then
            self.hover = { kind = "rim", part = part, data = data }
            return
        elseif point_in_rect(mx, my, data.hatch) or point_in_rect(mx, my, data.track) then
            self.hover = { kind = "slot", part = part, data = data }
            return
        elseif point_in_rect(mx, my, data.card) or point_in_rect(mx, my, data.label) then
            self.hover = { kind = "part", part = part, data = data }
            return
        end
    end
end

function V2Combat:selected_valid_destinations()
    local die = self:active_die()
    if not die then
        return nil
    end
    return self.engine:get_valid_destinations(self.player, die)
end

function V2Combat:active_die()
    return self.drag and self.drag.die or self.selected_die
end

function V2Combat:is_valid_destination(kind, part)
    local valid = self:selected_valid_destinations()
    if not valid then
        return false
    end

    if kind == "socket" then
        return contains(valid.sockets, part)
    elseif kind == "rim" then
        return contains(valid.rims, part)
    elseif kind == "slot" then
        return contains(valid.slots, part)
    end

    return false
end

function V2Combat:slot_feed_preview(die, part)
    local effective = self.engine:get_effective_symbols(self.player, die, "slot")
    local slot = part and part.slot
    local cost = slot and slot.cost or {}
    local lit = {}
    local burned = {}
    local hungry = part and (part:has_keyword("Hungry") or (slot and slot.hungry))

    for _, symbol in ipairs(effective or {}) do
        local matched_index = nil

        if symbol ~= Symbols.BLANK then
            for index, required in ipairs(cost) do
                if not (part.slot_charge and part.slot_charge[index]) and not lit[index] then
                    if hungry or required == symbol then
                        matched_index = index
                        break
                    end
                end
            end
        end

        if matched_index then
            lit[matched_index] = symbol
        elseif symbol ~= Symbols.BLANK then
            table.insert(burned, symbol)
        end
    end

    local lit_symbols = {}
    for index, symbol in pairs(lit) do
        table.insert(lit_symbols, {
            index = index,
            symbol = symbol,
            required = cost[index]
        })
    end
    table.sort(lit_symbols, function(a, b) return a.index < b.index end)

    local ordered = {}
    for _, entry in ipairs(lit_symbols) do
        table.insert(ordered, entry.symbol)
    end

    return ordered, burned, lit_symbols
end

function V2Combat:active_die_preview_lines()
    local lines = {}
    local die = self:active_die()
    if not die then
        return lines
    end

    local hover = self.hover
    local preview_destination = hover and is_destination_kind(hover.kind) and hover.kind or nil
    local effective = self.engine:get_effective_symbols(self.player, die, preview_destination)
    table.insert(lines, (self.drag and "Held: " or "Selected: ") .. Symbols.format_face(effective))
    table.insert(lines, "From: " .. (die.source_part and die.source_part.name or "?"))

    if hover and is_destination_kind(hover.kind) then
        local valid = self:is_valid_destination(hover.kind, hover.part)
        table.insert(lines, "")
        if hover.kind == "socket" then
            local used, burned, spellmark = self.engine:classify_destination_symbols(self.player, "socket", hover.part, effective)
            table.insert(lines, (spellmark and "Drop: mark " or "Drop: defend ") .. (hover.part.name or hover.part.id))
            table.insert(lines, "Uses: " .. Symbols.format_face(used))
            if #burned > 0 then
                table.insert(lines, "Burns: " .. Symbols.format_face(burned))
            end
        elseif hover.kind == "rim" then
            local used, burned, spellmark = self.engine:classify_destination_symbols(self.player, "rim", hover.part, effective)
            table.insert(lines, (spellmark and "Drop: mark " or "Drop: attack ") .. (hover.part.name or hover.part.id))
            table.insert(lines, "Uses: " .. Symbols.format_face(used))
            if #burned > 0 then
                table.insert(lines, "Burns: " .. Symbols.format_face(burned))
            end
        elseif hover.kind == "slot" then
            local slot_name = hover.part.slot and hover.part.slot.name or "Slot"
            table.insert(lines, "Drop: feed " .. slot_name)
            local lit, burned = self:slot_feed_preview(die, hover.part)
            table.insert(lines, "Lights: " .. Symbols.format_face(lit))
            if #burned > 0 then
                table.insert(lines, "Burns: " .. Symbols.format_face(burned))
            end
        end

        if not valid then
            table.insert(lines, "Not legal for this die.")
        end
    else
        table.insert(lines, "")
        table.insert(lines, self.drag and "Drop onto a glowing destination." or "Hover a glowing destination, then click to assign.")
    end

    return lines
end

function V2Combat:is_input_locked()
    return self.combat_end ~= nil or self.auto_allocation ~= nil or self.resolution_playback ~= nil or not self.player_can_allocate
end

function V2Combat:begin_allocation_phase()
    self.selected_die = nil
    self.drag = nil
    self.player_can_allocate = false
    self.enemy_response_pending = false

    local initiative = self.engine.initiative or "player"
    if initiative == "player" then
        self:start_auto_allocation(self.enemy, {
            visibility = "visible",
            on_complete = function()
                self.player_can_allocate = true
                self.message = "Enemy allocation complete. Drag a die to respond."
            end
        })
    elseif initiative == "contested" then
        self:start_auto_allocation(self.enemy, {
            visibility = "hidden",
            on_complete = function()
                self.player_can_allocate = true
                self.message = "Enemy commitment hidden. Allocate your dice."
            end
        })
    elseif initiative == "enemy" then
        self.player_can_allocate = true
        self.enemy_response_pending = true
        self.message = "Player commits first. Enemy will respond after confirm."
    else
        self.player_can_allocate = true
        self.message = "Allocate your dice."
    end
end

function V2Combat:find_next_auto_allocation_move(combatant)
    if V2AI.choose_next_allocation then
        return V2AI.choose_next_allocation(self.engine, combatant)
    end

    for _, die in ipairs(self.engine:get_pool(combatant)) do
        local move = V2AI.choose_allocation(self.engine, combatant, die)
        if move then
            return move
        end
    end

    return nil
end

function V2Combat:source_rect_for_die(combatant, die)
    if combatant == self.enemy and self.enemy_die_rects[die] then
        return self.enemy_die_rects[die]
    elseif combatant == self.player and self.die_rects[die] then
        return self.die_rects[die]
    end

    local layout = die and die.source_part and self.card_rects[die.source_part]
    if layout then
        return centered_rect(layout.card, DIE_SIZE)
    end

    return centered_rect(self:center_rect(), DIE_SIZE)
end

function V2Combat:target_rect_for_move(move)
    local layout = move and move.part and self.card_rects[move.part]
    if not layout then
        return centered_rect(self:center_rect(), DIE_SIZE)
    end

    if move.kind == "rim" then
        return layout.rim
    elseif move.kind == "socket" then
        return layout.socket
    elseif move.kind == "slot" then
        return layout.hatch
    end

    return centered_rect(layout.card, DIE_SIZE)
end

function V2Combat:start_auto_allocation(combatant, options)
    options = options or {}
    self:layout()
    self.auto_allocation = {
        combatant = combatant,
        visibility = options.visibility or "visible",
        on_complete = options.on_complete,
        current = nil,
        phase = "idle",
        timer = 0,
        move_count = 0
    }
    self.player_can_allocate = false
    self.message = (combatant.name or "Enemy") .. " is allocating."
    self:start_next_auto_allocation_move()
end

function V2Combat:finish_auto_allocation()
    local sequence = self.auto_allocation
    self.auto_allocation = nil

    if sequence and sequence.on_complete then
        sequence.on_complete()
    else
        self.player_can_allocate = true
    end
end

function V2Combat:start_next_auto_allocation_move()
    local sequence = self.auto_allocation
    if not sequence then
        return
    end

    self:layout()
    local move = self:find_next_auto_allocation_move(sequence.combatant)
    if not move then
        self:finish_auto_allocation()
        return
    end

    sequence.current = {
        move = move,
        die = move.die,
        kind = move.kind,
        part = move.part,
        source = copy_rect(self:source_rect_for_die(sequence.combatant, move.die)),
        target = copy_rect(self:target_rect_for_move(move)),
        elapsed = 0
    }
    sequence.phase = "move"
    sequence.timer = 0
    sequence.move_count = sequence.move_count + 1
end

function V2Combat:assignment_for_move(move)
    if not move or not move.part then
        return nil
    end

    if move.kind == "rim" then
        return self.engine.assignments.rims[move.part]
    elseif move.kind == "socket" then
        return self.engine.assignments.sockets[move.part]
    end

    return nil
end

function V2Combat:commit_auto_allocation_current()
    local sequence = self.auto_allocation
    local current = sequence and sequence.current
    if not current then
        return
    end

    self.event_visibility_context = sequence.visibility
    local ok, reason = self.engine:commit_allocation_move(sequence.combatant, current.move)
    self.event_visibility_context = nil

    if ok then
        if current.move and current.move.kind == "slot" then
            self:show_hatch_swallow(current.move.part)
        end
        local assignment = self:assignment_for_move(current.move)
        if assignment and sequence.visibility == "hidden" then
            self.assignment_visibility[assignment] = "hidden"
        end
        self.message = (sequence.combatant.name or "Enemy") .. " commits a die."
    else
        self.message = "Enemy allocation skipped: " .. tostring(reason)
    end
end

function V2Combat:update_auto_allocation(dt)
    local sequence = self.auto_allocation
    if not sequence then
        return
    end

    if sequence.phase == "move" then
        if not sequence.current then
            return
        end

        sequence.current.elapsed = sequence.current.elapsed + dt
        if sequence.current.elapsed >= AUTO_ALLOC_MOVE_DURATION then
            self:commit_auto_allocation_current()
            sequence.current = nil
            sequence.phase = "settle"
            sequence.timer = AUTO_ALLOC_SETTLE_DURATION
        end
    elseif sequence.phase == "settle" then
        sequence.timer = sequence.timer - dt
        if sequence.timer <= 0 then
            self:start_next_auto_allocation_move()
        end
    end
end

function V2Combat:auto_target_matches(kind, part)
    local current = self.auto_allocation and self.auto_allocation.current
    return current and current.kind == kind and current.part == part
end

function V2Combat:is_assignment_hidden(assignment)
    return assignment and self.assignment_visibility and self.assignment_visibility[assignment] == "hidden"
end

function V2Combat:reveal_hidden_allocations()
    self.assignment_visibility = setmetatable({}, { __mode = "k" })
end

function V2Combat:snapshot_resolution_state()
    local snapshot = {
        statuses = setmetatable({}, { __mode = "k" }),
        hearts = setmetatable({}, { __mode = "k" })
    }

    for _, combatant in ipairs(self.engine.combatants or {}) do
        snapshot.hearts[combatant] = combatant.heart_points
        for _, part in ipairs(combatant.body_parts or {}) do
            snapshot.statuses[part] = part.status
        end
    end

    return snapshot
end

function V2Combat:build_resolution_entries(event_start_index)
    local entries = {}
    local latest_by_part = setmetatable({}, { __mode = "k" })

    for index = event_start_index + 1, #self.engine.event_queue do
        local event = self.engine.event_queue[index]
        local data = event and event.data

        if event and event.type == Events.PART_RESOLVED and data and data.attack then
            local entry = {
                defender = data.defender,
                part = data.part,
                attack = data.attack,
                defense = data.defense,
                strike_count = data.strike_count or 0,
                ward_count = data.ward_count or 0,
                hit = data.hit == true,
                damage = nil,
                elapsed = 0,
                revealed = false
            }
            table.insert(entries, entry)
            latest_by_part[data.part] = entry
        elseif event and event.type == Events.DAMAGE_DEALT and data then
            local entry = latest_by_part[data.body_part]
            if entry then
                entry.damage = data
            end
        end
    end

    return entries
end

function V2Combat:start_resolution_playback(entries, snapshot)
    if not entries or #entries == 0 then
        self:complete_resolution_playback()
        return
    end

    self.resolution_status_overrides = snapshot and snapshot.statuses or setmetatable({}, { __mode = "k" })
    self.resolution_playback = {
        entries = entries,
        index = 1,
        current = entries[1]
    }
    self.player_can_allocate = false
    self.selected_die = nil
    self.drag = nil
    self.message = "Resolution."
end

function V2Combat:reveal_resolution_entry(entry)
    if not entry or entry.revealed then
        return
    end

    entry.revealed = true
    if self.resolution_status_overrides and entry.part then
        self.resolution_status_overrides[entry.part] = nil
    end
end

function V2Combat:complete_resolution_playback()
    self.resolution_playback = nil
    self.resolution_status_overrides = nil

    if self.engine.state == "COMPLETE" then
        self:begin_combat_end()
        return
    end

    self.engine:start_round()
    self:begin_allocation_phase()
end

function V2Combat:skip_resolution_playback()
    if not self.resolution_playback then
        return false
    end

    self:complete_resolution_playback()
    return true
end

function V2Combat:update_resolution_playback(dt)
    local playback = self.resolution_playback
    local current = playback and playback.current
    if not current then
        return
    end

    current.elapsed = current.elapsed + dt
    if current.damage and current.elapsed >= RESOLUTION_STEP_DURATION * RESOLUTION_REVEAL_TIME then
        self:reveal_resolution_entry(current)
    end

    if current.elapsed < RESOLUTION_STEP_DURATION then
        return
    end

    self:reveal_resolution_entry(current)
    playback.index = playback.index + 1
    playback.current = playback.entries[playback.index]

    if playback.current then
        playback.current.elapsed = 0
        self.message = "Resolution."
    else
        self:complete_resolution_playback()
    end
end

function V2Combat:display_status_for_part(part)
    if self.resolution_status_overrides and self.resolution_status_overrides[part] then
        return self.resolution_status_overrides[part]
    end

    return part and part.status
end

function V2Combat:message_for_result(ok, reason)
    if ok then
        self.message = "Assigned."
    else
        self.message = "Invalid: " .. tostring(reason)
    end
end

function V2Combat:try_destination(kind, part)
    if not self.selected_die then
        return
    end

    local ok, reason
    if kind == "socket" then
        ok, reason = self.engine:assign_die_to_socket(self.player, self.selected_die.id, part)
    elseif kind == "rim" then
        ok, reason = self.engine:assign_die_to_rim(self.player, self.selected_die.id, part)
    elseif kind == "slot" then
        ok, reason = self.engine:feed_die_to_slot(self.player, self.selected_die.id, part)
    end

    self:message_for_result(ok, reason)
    if ok then
        if kind == "slot" then
            self:show_hatch_swallow(part)
        end
        self.selected_die = nil
    end
end

function V2Combat:resolve_and_advance_round()
    self:reveal_hidden_allocations()
    local snapshot = self:snapshot_resolution_state()
    local event_start_index = #self.engine.event_queue
    self.engine:resolve_round()

    local entries = self:build_resolution_entries(event_start_index)
    if #entries > 0 then
        self:start_resolution_playback(entries, snapshot)
        return
    end

    self:complete_resolution_playback()
end

function V2Combat:confirm_round()
    if self:skip_resolution_playback() then
        return
    end

    if self:is_input_locked() then
        self.message = "Wait for enemy allocation to finish."
        return
    end

    if self.enemy_response_pending then
        self.enemy_response_pending = false
        self.player_can_allocate = false
        self:start_auto_allocation(self.enemy, {
            visibility = "visible",
            on_complete = function()
                self:resolve_and_advance_round()
            end
        })
        return
    end

    self:resolve_and_advance_round()
end

function V2Combat:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    if self.combat_end then
        self:return_to_overworld()
        return
    end

    if self:skip_resolution_playback() then
        return
    end

    if self:is_input_locked() then
        self.message = "Enemy allocation is still resolving."
        return
    end

    self:update_hover(x, y)
    local hover = self.hover

    if not hover then
        self.selected_die = nil
        return
    end

    if hover.kind == "die" and hover.combatant == self.player then
        self.selected_die = hover.die
        local die_rect = self.die_rects[hover.die]
        self.drag = {
            die = hover.die,
            x = x,
            y = y,
            offset_x = die_rect and (x - die_rect.x) or DIE_SIZE / 2,
            offset_y = die_rect and (y - die_rect.y) or DIE_SIZE / 2
        }
        self.message = "Dragging die from " .. (hover.die.source_part and hover.die.source_part.name or "?") .. "."
    elseif hover.kind == "die" then
        self.selected_die = nil
    elseif hover.kind == "crest" then
        if hover.combatant == self.player then
            local ok, reason = self.engine:expend_crest(self.player, hover.crest)
            self:message_for_result(ok, reason)
        else
            self.selected_die = nil
        end
    elseif hover.kind == "confirm" then
        self:confirm_round()
    elseif hover.kind == "socket" or hover.kind == "rim" or hover.kind == "slot" then
        self:try_destination(hover.kind, hover.part)
    elseif hover.kind == "part" then
        self.selected_die = nil
    end
end

function V2Combat:mousereleased(x, y, button)
    if button ~= 1 or not self.drag then
        return
    end

    if self:is_input_locked() then
        self.drag = nil
        return
    end

    self:update_hover(x, y)
    local hover = self.hover
    local dropped = false

    if hover and is_destination_kind(hover.kind) then
        self:try_destination(hover.kind, hover.part)
        dropped = self.selected_die == nil
    end

    if not dropped and self.selected_die then
        self.message = "Drop canceled. Die remains selected."
    end

    self.drag = nil
    self:update_hover(x, y)
end

function V2Combat:keypressed(key)
    if key == "escape" then
        GameState.switch(require("states.overworld"))
    elseif self.combat_end and (key == "space" or key == "c" or key == "return") then
        self:return_to_overworld()
    elseif self.resolution_playback and (key == "space" or key == "c" or key == "return") then
        self:skip_resolution_playback()
    elseif key == "c" or key == "return" then
        self:confirm_round()
    elseif key == "r" then
        self:enter()
    end
end

function V2Combat:draw_tableau_band(strip, side, combatant)
    love.graphics.setFont(self.fonts.body)
    local accent = side == "enemy" and COLORS.enemy or COLORS.player
    local asset_id = side == "enemy" and "combat_enemy_tableau" or "combat_player_tableau"

    if not draw_image(asset_id, strip) then
        set_color(COLORS.panel)
        love.graphics.rectangle("fill", strip.x, strip.y, strip.w, strip.h, 8, 8)
        set_color({ COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.24 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", strip.x, strip.y, strip.w, strip.h, 8, 8)

        local edge_y = side == "enemy" and (strip.y + strip.h - 1) or strip.y
        set_color({ accent[1], accent[2], accent[3], 0.2 })
        love.graphics.line(strip.x + 12, edge_y, strip.x + strip.w - 12, edge_y)
    end

end

function V2Combat:hover_matches(kind, part)
    return self.hover and self.hover.kind == kind and self.hover.part == part
end

function V2Combat:destination_preview(kind, part)
    local die = self:active_die()
    if not die or not part or not self:hover_matches(kind, part) then
        return nil
    end

    local valid = self:is_valid_destination(kind, part)
    local effective = self.engine:get_effective_symbols(self.player, die, kind)

    if kind == "socket" then
        local used, burned, spellmark = self.engine:classify_destination_symbols(self.player, "socket", part, effective)
        return {
            valid = valid,
            used = used,
            burned = burned,
            spellmark = spellmark
        }
    elseif kind == "rim" then
        local used, burned, spellmark = self.engine:classify_destination_symbols(self.player, "rim", part, effective)
        return {
            valid = valid,
            used = used,
            burned = burned,
            spellmark = spellmark
        }
    elseif kind == "slot" then
        local lit, burned, lit_entries = self:slot_feed_preview(die, part)
        return {
            valid = valid,
            lit = lit,
            lit_entries = lit_entries,
            burned = burned
        }
    end

    return nil
end

function V2Combat:draw_socket_or_rim_preview(kind, part, target_rect)
    local preview = self:destination_preview(kind, part)
    if not preview then
        return
    end

    if not preview.valid then
        draw_sprite_outline(target_rect, COLORS.invalid, 3)
        return
    end

    set_color({ COLORS.ink[1], COLORS.ink[2], COLORS.ink[3], 0.1 })
    love.graphics.rectangle("fill", target_rect.x + 3, target_rect.y + 3, target_rect.w - 6, target_rect.h - 6, 3, 3)
    draw_symbol_cluster(preview.used, target_rect, 0.9, false)

    if #preview.burned > 0 then
        local burn_x = target_rect.x + target_rect.w + 3
        draw_burned_symbols(preview.burned, burn_x, target_rect.y + target_rect.h - SYMBOL_SIZE - 4)
    end
end

function V2Combat:draw_settled_dice_row(side, combatant, area, die_rects, accent)
    local pool = self.engine:get_pool(combatant)
    local current = self.auto_allocation and self.auto_allocation.current
    local hidden = self.auto_allocation
        and self.auto_allocation.combatant == combatant
        and self.auto_allocation.visibility == "hidden"

    if #pool > 0 then
        local guide_asset = side == "enemy" and "die_row_guideline_enemy" or "die_row_guideline_player"
        local guide_y = side == "enemy" and (area.y - 6) or (area.y + area.h + 4)
        local guide = rect(area.x, guide_y, area.w, 4)

        if not draw_image(guide_asset, guide) then
            set_color({ accent[1], accent[2], accent[3], 0.12 })
            love.graphics.rectangle("fill", guide.x, guide.y + 1, guide.w, 2)
            set_color({ accent[1], accent[2], accent[3], 0.34 })
            love.graphics.setLineWidth(1)
            love.graphics.line(guide.x, guide.y + 2, guide.x + guide.w, guide.y + 2)
        end
    end

    for _, die in ipairs(pool) do
        if not (current and current.die == die) and not (self.drag and self.drag.die == die) then
            local die_rect = die_rects[die]
            if die_rect then
                set_color({ 0, 0, 0, 0.18 })
                love.graphics.rectangle("fill", die_rect.x + 3, die_rect.y + die_rect.h + 2, die_rect.w - 6, 3, 2, 2)
                if hidden then
                    draw_die_back(die_rect, accent)
                else
                    draw_die_face(die.effective_symbols or die.symbols, die_rect, self.selected_die == die)
                end
            end
        end
    end
end

function V2Combat:draw_queue_ticker(r)
    if not draw_image("combat_queue_stack", r) then
        draw_box(r, COLORS.surface_low, COLORS.line, 5)
    end

    local entries = self.engine.slot_queue or {}
    local cell_size = 16
    local cell_gap = 4
    local cell_x = r.x + math.floor((r.w - cell_size) / 2)
    local cell_y = r.y + 10
    local max_cells = math.max(1, math.floor((r.h - 20) / (cell_size + cell_gap)))

    for index = 1, math.min(#entries, max_cells, 8) do
        local cell = rect(cell_x, cell_y + (index - 1) * (cell_size + cell_gap), cell_size, cell_size)
        local entry = entries[index]
        if entry then
            draw_symbol_sprite(queue_entry_symbol(entry), cell.x + 2, cell.y + 2, cell_size - 4, false, 0.95)
        end
    end
end

function V2Combat:draw_initiative_badge(r)
    local initiative = tostring(self.engine.initiative or "player")
    local color = COLORS.player
    local label = "P"
    if initiative == "enemy" then
        color = COLORS.enemy
        label = "E"
    elseif initiative == "contested" then
        color = COLORS.essence
        label = "C"
    end

    if not draw_image("combat_initiative_badge", r) then
        draw_box(r, COLORS.surface, color, 5)
    end
    love.graphics.setFont(self.fonts.tiny)
    draw_text(label, r.x + 4, r.y + 6, r.w - 8, "center", color)
end

function V2Combat:draw_heart_stack(combatant, rects, color, side)
    local current = math.max(0, math.min(HEART_STACK_MAX, combatant and combatant.heart_points or 0))
    for index = 1, HEART_STACK_MAX do
        local r = rects and rects[index]
        if r then
            local active = index <= current
            if side == "player" then
                active = index > HEART_STACK_MAX - current
            end
            draw_heart_icon(r, active, color)
        end
    end
end

function V2Combat:draw_crest_chip(combatant, crest, r)
    local count = combatant and combatant:get_crest_count(crest) or 0
    if count <= 0 or not r then
        return
    end

    local active = count > 0
    local hovered = self.hover and self.hover.kind == "crest" and self.hover.crest == crest and self.hover.combatant == combatant
    local visual = CREST_VISUALS[crest] or {
        symbol = Symbols.ESSENCE,
        fill = COLORS.surface,
        line = COLORS.line
    }

    draw_hex_chip(r, visual.fill, hovered and COLORS.selected or (active and visual.line or COLORS.dashed), active)
    draw_symbol_sprite(visual.symbol, r.x + (r.w - SYMBOL_SIZE) / 2, r.y + (r.h - SYMBOL_SIZE) / 2, SYMBOL_SIZE, not active, active and 1 or 0.38)

    if count > 0 then
        local badge = rect(r.x + r.w - 10, r.y + r.h - 11, 13, 11)
        draw_box(badge, COLORS.rail, visual.line, 4)
        love.graphics.setFont(self.fonts.tiny)
        draw_text(tostring(count), badge.x + 1, badge.y + 2, badge.w - 2, "center", COLORS.ink)
    end
end

function V2Combat:draw_global_spine()
    local spine = self:global_spine_rect()
    if not draw_image("combat_spine", spine) then
        draw_box(spine, COLORS.panel, COLORS.line, 7)
    end
    self:draw_heart_stack(self.enemy, self.enemy_heart_rects, COLORS.enemy, "enemy")
    self:draw_heart_stack(self.player, self.player_heart_rects, COLORS.player, "player")
    self:draw_initiative_badge(self.initiative_rect)
    self:draw_queue_ticker(self.queue_rect)
end

function V2Combat:draw_combatant_resource_row(side, combatant, drawer, die_rects, crest_rects)
    local accent = side == "enemy" and COLORS.enemy or COLORS.player
    self:draw_settled_dice_row(side, combatant, self:drawer_dice_area(drawer), die_rects, accent)

    local first_crest = nil
    local last_crest = nil
    for _, crest in ipairs(CREST_ORDER) do
        local crest_rect = crest_rects[crest]
        if crest_rect then
            first_crest = first_crest or crest_rect
            last_crest = crest_rect
        end
    end

    if first_crest and last_crest then
        local strip_rect = rect(
            first_crest.x - 6,
            first_crest.y + math.floor(first_crest.h / 2) - 2,
            last_crest.x + last_crest.w - first_crest.x + 12,
            4)
        local strip_asset = side == "enemy" and "crest_strip_enemy" or "crest_strip_player"
        if not draw_image(strip_asset, strip_rect) then
            set_color({ accent[1], accent[2], accent[3], 0.16 })
            love.graphics.rectangle("fill", strip_rect.x, strip_rect.y, strip_rect.w, strip_rect.h, 2, 2)
            set_color({ accent[1], accent[2], accent[3], 0.36 })
            love.graphics.setLineWidth(1)
            love.graphics.line(strip_rect.x, strip_rect.y + 2, strip_rect.x + strip_rect.w, strip_rect.y + 2)
        end
    end

    for _, crest in ipairs(CREST_ORDER) do
        if crest_rects[crest] then
            self:draw_crest_chip(combatant, crest, crest_rects[crest])
        end
    end
end

function V2Combat:draw_slot_track(part, layout, hatch_outline, display_status)
    local slot = part.slot
    if not slot then
        if not draw_image("die-hatch1", layout.hatch, { 1, 1, 1, 0.35 }) then
            draw_box(layout.hatch, COLORS.surface_low, COLORS.invalid, 3)
        end
        draw_sprite_outline(layout.hatch, COLORS.invalid, 3)
        return
    end

    local hatch_id = "die-hatch1"
    local hungry = part:has_keyword("Hungry") or slot.hungry
    local accepting = hatch_outline == COLORS.valid or hatch_outline == COLORS.enemy
    local hovered = hatch_outline == COLORS.valid and self:hover_matches("slot", part)
    local swallow_frame = self:hatch_swallow_frame(part)
    if swallow_frame then
        hatch_id = swallow_frame
    elseif display_status == "maimed" then
        hatch_id = "die-hatch1"
    elseif accepting and hovered then
        hatch_id = "die-hatch3"
    elseif accepting or hungry then
        hatch_id = "die-hatch2"
    end

    local hatch_tint = display_status == "maimed" and { 1, 1, 1, 0.45 } or nil
    if not draw_image(hatch_id, layout.hatch, hatch_tint) then
        draw_box(layout.hatch, COLORS.surface, hatch_outline or COLORS.line, 3)
    end

    if hatch_outline == COLORS.valid then
        draw_sprite_outline(layout.hatch, COLORS.valid, 3)
    elseif hatch_outline == COLORS.enemy then
        draw_sprite_outline(layout.hatch, COLORS.enemy, 3)
    elseif display_status == "maimed" then
        draw_sprite_outline(layout.hatch, COLORS.invalid, 3)
    end

    local preview = self:destination_preview("slot", part)
    local preview_by_index = {}
    if preview and preview.valid then
        for _, entry in ipairs(preview.lit_entries or {}) do
            preview_by_index[entry.index] = entry
        end
    elseif preview then
        draw_sprite_outline(layout.hatch, COLORS.invalid, 3)
    end

    local cost = slot.cost or {}
    local row_count = #cost > SLOT_PIP_ROW_LIMIT and 2 or 1
    local columns_per_row = math.max(1, math.ceil(#cost / row_count))
    local first_row_y = layout.track.y + math.floor(math.max(0, layout.track.h - (row_count * SYMBOL_SIZE + (row_count - 1) * SLOT_PIP_ROW_GAP)) / 2)
    local last_pip_x = layout.track.x
    local last_pip_y = first_row_y

    for index, symbol in ipairs(cost) do
        local lit = part.slot_charge and part.slot_charge[index]
        local previewed = preview_by_index[index] ~= nil
        local row_index = math.floor((index - 1) / columns_per_row) + 1
        local column_index = ((index - 1) % columns_per_row) + 1
        local row_start_index = (row_index - 1) * columns_per_row + 1
        local pips_in_row = math.min(columns_per_row, #cost - row_start_index + 1)
        local row_width = pips_in_row * SYMBOL_SIZE + math.max(0, pips_in_row - 1) * SLOT_PIP_GAP
        local row_start_x = layout.track.x + math.floor(math.max(0, layout.track.w - row_width) / 2)
        local pip_x = row_start_x + (column_index - 1) * (SYMBOL_SIZE + SLOT_PIP_GAP)
        local pip_y = first_row_y + (row_index - 1) * (SYMBOL_SIZE + SLOT_PIP_ROW_GAP)
        if previewed then
            set_color({ 1, 0.88, 0.35, 0.5 })
            love.graphics.rectangle("fill", pip_x - 1, pip_y - 1, SYMBOL_SIZE + 2, SYMBOL_SIZE + 2, 2, 2)
        end
        draw_symbol_sprite(symbol, pip_x, pip_y, SYMBOL_SIZE, not (lit or previewed), lit and 1 or (previewed and 0.95 or 0.85))
        last_pip_x = pip_x
        last_pip_y = pip_y
    end

    if preview and preview.valid and #preview.burned > 0 then
        draw_burned_symbols(preview.burned, last_pip_x + SYMBOL_SIZE + 4, last_pip_y)
    end

    love.graphics.setFont(self.fonts.tiny)
    draw_text(truncate_tracked_text(slot.name or "Slot", layout.slot_label.w),
        layout.slot_label.x, layout.slot_label.y, layout.slot_label.w, "center", COLORS.muted)
end

function V2Combat:draw_assignment_die(assignment, target_rect)
    if not assignment then
        return
    end

    if self:is_assignment_hidden(assignment) then
        draw_die_back(target_rect, COLORS.enemy)
        return
    end

    draw_die_face(assignment.symbols or assignment.die.symbols, target_rect, false)
    if assignment.burned_symbols and #assignment.burned_symbols > 0 then
        draw_burned_symbols(assignment.burned_symbols, target_rect.x + target_rect.w + 3, target_rect.y + target_rect.h - SYMBOL_SIZE - 4)
    end
end

function V2Combat:destination_has_spellmark(kind, part)
    if not (self.engine and self.engine.get_assignment_spellmark) then
        return false
    end

    for _, combatant in ipairs(self.engine.combatants or {}) do
        local spellmarks = combatant.get_spellmarks and combatant:get_spellmarks() or {}
        for _, pending in ipairs(spellmarks) do
            local target_side = pending.target or pending.target_side or (kind == "rim" and "opponent" or "self")
            local target_combatant = target_side == "opponent" and self.engine:get_opponent(combatant) or combatant
            local owns_part = false
            for _, owned_part in ipairs(target_combatant and target_combatant.body_parts or {}) do
                if owned_part == part then
                    owns_part = true
                    break
                end
            end

            if owns_part and self.engine:get_assignment_spellmark(combatant, kind, part, { Symbols.ESSENCE }) then
                return true
            end
        end
    end

    return false
end

function V2Combat:warn_title_overflow(part, name, width, max_width)
    local key = part and (part.id or part.name) or name
    if not key then
        return
    end

    self.title_overflow_warnings = self.title_overflow_warnings or {}
    if self.title_overflow_warnings[key] then
        return
    end

    self.title_overflow_warnings[key] = true
    print(string.format(
        "[V2Combat] BP title '%s' is %.0fpx wide; title strip allows %.0fpx. Shorten the authored name.",
        tostring(name),
        width or 0,
        max_width or 0))
end

function V2Combat:draw_title_strip(part, layout, color)
    local title = layout and layout.label
    if not title then
        return
    end

    local flip_y = layout.side == "player"
    if not draw_image("bp_title", title, nil, flip_y) then
        draw_box(title, COLORS.surface_low, COLORS.line, 3)
    end

    love.graphics.setFont(self.fonts.small)
    local font = love.graphics.getFont()
    local text_h = font and font:getHeight() or 12
    local text = part.name or part.id or "Part"
    local text_rect = rect(title.x + 4, title.y, title.w - 8, title.h)
    local text_y = text_rect.y + math.floor((text_rect.h - text_h) / 2)
    local fits, width = draw_single_line_text(text, text_rect.x, text_y, text_rect.w, "center", color or COLORS.ink)

    if not fits then
        self:warn_title_overflow(part, text, width, text_rect.w)
    end
end

function V2Combat:draw_card_state_overlays(part, layout, display_status, any_valid, selected_source, source_highlight)
    local card = layout.card
    local time = self.ui_time or 0
    local hovered = self.hover and self.hover.part == part
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

    if self:active_die() then
        if any_valid then
            draw_animated_image("bp_card_valid", card, time)
        elseif hovered then
            draw_animated_image("bp_card_invalid", card, time)
        end
    end

    if source_highlight then
        if not draw_animated_image("bp_card_hover", card, time) then
            draw_sprite_outline(card, COLORS.selected, 2)
        end
    end

    if selected_source then
        if not draw_animated_image("bp_card_selected", card, time) then
            draw_sprite_outline(card, COLORS.selected, 2)
        end
    elseif hovered and not source_highlight then
        draw_animated_image("bp_card_hover", card, time)
    end
end

function V2Combat:draw_socket_or_rim_frame(kind, part, layout, display_status, valid, auto_target)
    local is_socket = kind == "socket"
    local target = is_socket and layout.socket or layout.rim
    local prefix = is_socket and "die_socket" or "die_rim"
    local assignment = is_socket and self.engine.assignments.sockets[part] or self.engine.assignments.rims[part]
    local flip_y = layout.side == "enemy"
    local outline = auto_target and COLORS.enemy or (valid and COLORS.valid or COLORS.dashed)

    if not draw_image(prefix, target, nil, flip_y) then
        draw_box(target, COLORS.surface_low, outline, 3)
    end

    local state_prefix = nil
    local state_color = outline
    if display_status == "maimed" then
        state_prefix = prefix .. "_locked"
        state_color = COLORS.invalid
    elseif assignment then
        state_prefix = prefix .. "_occupied"
        state_color = COLORS.line
    elseif valid or auto_target then
        state_prefix = prefix .. "_valid"
        state_color = outline
    elseif self:destination_has_spellmark(kind, part) then
        state_prefix = prefix .. "_spellmarked"
        state_color = COLORS.essence
    end

    if state_prefix and not draw_animated_image(state_prefix, target, self.ui_time or 0, nil, flip_y) then
        draw_sprite_outline(target, state_color, 3)
    end
end

function V2Combat:draw_part_card(part, layout)
    love.graphics.setFont(self.fonts.small)
    local card = layout.card
    local display_status = self:display_status_for_part(part)
    local source_highlight = self.hover and self.hover.kind == "die" and self.hover.die.source_part == part
    local selected_source = self.selected_die and self.selected_die.source_part == part

    if not draw_image("bp_card", card) then
        draw_box(card, COLORS.panel, COLORS.line, 6)
    end

    local socket_valid = self:is_valid_destination("socket", part)
    local rim_valid = self:is_valid_destination("rim", part)
    local slot_valid = self:is_valid_destination("slot", part)
    local auto_socket_target = self:auto_target_matches("socket", part)
    local auto_rim_target = self:auto_target_matches("rim", part)
    local auto_slot_target = self:auto_target_matches("slot", part)

    local hatch_outline = auto_slot_target and COLORS.enemy or (slot_valid and COLORS.valid or COLORS.line)

    self:draw_card_state_overlays(
        part,
        layout,
        display_status,
        socket_valid or rim_valid or slot_valid or auto_socket_target or auto_rim_target or auto_slot_target,
        selected_source,
        source_highlight)

    draw_hp_badge(part.hp_value or 1, layout.meta.x, layout.meta.y)

    self:draw_socket_or_rim_frame("socket", part, layout, display_status, socket_valid, auto_socket_target)
    self:draw_socket_or_rim_frame("rim", part, layout, display_status, rim_valid, auto_rim_target)

    self:draw_assignment_die(self.engine.assignments.sockets[part], layout.socket)
    self:draw_assignment_die(self.engine.assignments.rims[part], layout.rim)
    self:draw_socket_or_rim_preview("socket", part, layout.socket)
    self:draw_socket_or_rim_preview("rim", part, layout.rim)

    local previous_color = COLORS.line
    if slot_valid then
        previous_color = COLORS.valid
    elseif display_status == "maimed" then
        previous_color = COLORS.invalid
    else
        previous_color = hatch_outline
    end
    self:draw_slot_track(part, layout, previous_color, display_status)

    local label_color = (source_highlight or selected_source) and COLORS.selected or COLORS.ink
    self:draw_title_strip(part, layout, label_color)
end

function V2Combat:draw_empty_card(layout)
    love.graphics.setFont(self.fonts.small)
    if not draw_image("bp_card_empty", layout.card) then
        set_color({ COLORS.surface_low[1], COLORS.surface_low[2], COLORS.surface_low[3], 0.18 })
        love.graphics.rectangle("fill", layout.card.x, layout.card.y, layout.card.w, layout.card.h, 6, 6)
        set_color({ COLORS.dashed[1], COLORS.dashed[2], COLORS.dashed[3], 0.38 })
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", layout.card.x, layout.card.y, layout.card.w, layout.card.h, 6, 6)
    end
    draw_text("empty", layout.card.x, layout.card.y + layout.card.h * 0.42, layout.card.w, "center",
        { COLORS.muted[1], COLORS.muted[2], COLORS.muted[3], 0.52 })
end

function V2Combat:draw_center()
    love.graphics.setFont(self.fonts.body)
    local center = self:center_rect()
    if not draw_image("combat_conduit_field", center) then
        set_color({ COLORS.surface_low[1], COLORS.surface_low[2], COLORS.surface_low[3], 0.32 })
        love.graphics.rectangle("fill", center.x, center.y, center.w, center.h, 8, 8)
        set_color({ COLORS.line[1], COLORS.line[2], COLORS.line[3], 0.12 })
        love.graphics.setLineWidth(1)
        love.graphics.line(center.x + 12, center.y, center.x + center.w - 12, center.y)
        love.graphics.line(center.x + 12, center.y + center.h, center.x + center.w - 12, center.y + center.h)
    end
end

function V2Combat:draw_pool()
    self:draw_combatant_resource_row("enemy", self.enemy, self.drawers.enemy, self.enemy_die_rects, self.enemy_crest_rects)
    self:draw_combatant_resource_row("player", self.player, self.drawers.player, self.die_rects, self.crest_rects)

    local confirm_outline = self.hover and self.hover.kind == "confirm" and COLORS.selected or COLORS.line
    local confirm_asset = self.hover and self.hover.kind == "confirm" and "combat_confirm_chit_hover" or "combat_confirm_chit"
    local drew_confirm_asset = draw_image(confirm_asset, self.confirm_rect)
    if not drew_confirm_asset then
        draw_box(self.confirm_rect, COLORS.surface, confirm_outline, 6)
    elseif self.hover and self.hover.kind == "confirm" then
        draw_sprite_outline(self.confirm_rect, confirm_outline, 6)
    end
    if not drew_confirm_asset then
        love.graphics.setFont(self.fonts.tiny)
        local font = love.graphics.getFont()
        local text_y = self.confirm_rect.y + math.floor((self.confirm_rect.h - (font and font:getHeight() or 12)) / 2)
        draw_text("confirm", self.confirm_rect.x + 4, text_y, self.confirm_rect.w - 8, "center", COLORS.ink)
    end
end

function V2Combat:draw_drag_ghost()
    if not (self.drag and self.drag.die) then
        return
    end

    local r = rect(
        self.drag.x - (self.drag.offset_x or DIE_SIZE / 2),
        self.drag.y - (self.drag.offset_y or DIE_SIZE / 2),
        DIE_SIZE,
        DIE_SIZE)

    draw_die_face(self.drag.die.effective_symbols or self.drag.die.symbols, r, true)
end

function V2Combat:draw_auto_allocation_ghost()
    local sequence = self.auto_allocation
    local current = sequence and sequence.current
    if not current then
        return
    end

    local progress = ease_out_cubic(current.elapsed / AUTO_ALLOC_MOVE_DURATION)
    local r = rect(
        lerp(current.source.x, current.target.x, progress),
        lerp(current.source.y, current.target.y, progress),
        DIE_SIZE,
        DIE_SIZE)

    if sequence.visibility == "hidden" then
        draw_die_back(r, COLORS.enemy)
    else
        local effective = self.engine:get_effective_symbols(sequence.combatant, current.die, current.kind)
        draw_die_face(effective, r, true)
    end
end

function V2Combat:resolution_shake_offset()
    local current = self.resolution_playback and self.resolution_playback.current
    if not (current and current.hit and current.damage) then
        return 0, 0
    end

    local progress = math.max(0, math.min(1, current.elapsed / RESOLUTION_STEP_DURATION))
    if progress < RESOLUTION_REVEAL_TIME then
        return 0, 0
    end

    local remaining = 1 - progress
    local magnitude = 5 * remaining
    local pulse = math.sin(current.elapsed * 82)
    return pulse * magnitude, math.cos(current.elapsed * 67) * magnitude * 0.5
end

function V2Combat:draw_resolution_effects()
    local playback = self.resolution_playback
    local current = playback and playback.current
    if not current then
        return
    end

    local layout = current.part and self.card_rects[current.part]
    if not layout then
        return
    end

    local progress = math.max(0, math.min(1, current.elapsed / RESOLUTION_STEP_DURATION))
    local flash = 0.55 + 0.35 * math.sin(current.elapsed * 18)
    local focus_color = current.hit and COLORS.attack or COLORS.defense
    local card = layout.card

    set_color({ focus_color[1], focus_color[2], focus_color[3], 0.24 + 0.18 * flash })
    love.graphics.rectangle("fill", card.x - 3, card.y - 3, card.w + 6, card.h + 6, 7, 7)
    set_color({ focus_color[1], focus_color[2], focus_color[3], 0.92 })
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", card.x - 4, card.y - 4, card.w + 8, card.h + 8, 7, 7)

    local label_w = 108
    local label_h = current.damage and 48 or 34
    local main_x = self:main_x()
    local main_right = main_x + self:main_width()
    local label_x = math.max(main_x, math.min(card.x + card.w / 2 - label_w / 2, main_right - label_w))
    local label_y = card.y - label_h - 8
    if label_y < MARGIN then
        label_y = card.y + card.h + 8
    end

    draw_box(rect(label_x, label_y, label_w, label_h), COLORS.rail, focus_color, 6)
    love.graphics.setFont(self.fonts.small)
    draw_text("ATK " .. tostring(current.strike_count) .. " / DEF " .. tostring(current.ward_count),
        label_x + 6, label_y + 6, label_w - 12, "center", COLORS.ink)

    local result_text = current.hit and "HIT" or "BLOCK"
    if progress < 0.42 then
        result_text = "..."
    end

    love.graphics.setFont(self.fonts.body)
    draw_text(result_text, label_x + 6, label_y + 20, label_w - 12, "center", focus_color)

    if current.damage and progress >= RESOLUTION_REVEAL_TIME then
        love.graphics.setFont(self.fonts.tiny)
        local status = tostring(current.damage.status_before) .. " -> " .. tostring(current.damage.status_after)
        draw_text(status, label_x + 6, label_y + 36, label_w - 12, "center", COLORS.muted)
    end
end

function V2Combat:draw_slot_activation_effects()
    for _, effect in ipairs(self.slot_activation_effects or {}) do
        local source_layout = effect.part and self.card_rects[effect.part]
        if source_layout then
            local duration = effect.duration or SLOT_EFFECT_DURATION
            local progress = math.max(0, math.min(1, (effect.elapsed or 0) / duration))
            local pulse = 0.55 + 0.35 * math.sin((effect.elapsed or 0) * 22)
            local alpha = (1 - progress) * (0.35 + 0.25 * pulse)
            local slot_name = effect.slot and effect.slot.name or "Slot"
            local card = source_layout.card
            local hatch = source_layout.hatch
            local color = COLORS.essence

            set_color({ color[1], color[2], color[3], alpha })
            love.graphics.rectangle("fill", card.x - 4, card.y - 4, card.w + 8, card.h + 8, 7, 7)
            set_color({ color[1], color[2], color[3], math.min(1, alpha + 0.35) })
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", hatch.x - 3, hatch.y - 3, hatch.w + 6, hatch.h + 6, 4, 4)

            local label_w = 118
            local label_h = 24
            local main_x = self:main_x()
            local main_right = main_x + self:main_width()
            local label_x = math.max(main_x, math.min(card.x + card.w / 2 - label_w / 2, main_right - label_w))
            local label_y = card.y + card.h / 2 - label_h / 2

            draw_box(rect(label_x, label_y, label_w, label_h), {
                COLORS.rail[1],
                COLORS.rail[2],
                COLORS.rail[3],
                0.94 * (1 - progress * 0.25)
            }, color, 6)
            love.graphics.setFont(self.fonts.small)
            draw_text(truncate_tracked_text(slot_name, label_w - 12),
                label_x + 6, label_y + 7, label_w - 12, "center", COLORS.ink)
        end

        local target_layout = effect.target_part and self.card_rects[effect.target_part]
        if target_layout then
            local duration = effect.duration or SLOT_EFFECT_DURATION
            local progress = math.max(0, math.min(1, (effect.elapsed or 0) / duration))
            local alpha = (1 - progress) * 0.42
            local target = target_layout.card
            local color = COLORS.attack

            set_color({ color[1], color[2], color[3], alpha })
            love.graphics.rectangle("fill", target.x - 5, target.y - 5, target.w + 10, target.h + 10, 7, 7)
            set_color({ color[1], color[2], color[3], math.min(1, alpha + 0.42) })
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", target.x - 5, target.y - 5, target.w + 10, target.h + 10, 7, 7)
        end
    end
end

function V2Combat:inspected_die_source()
    if self.drag then
        return nil, nil
    end

    if self.selected_die and self.selected_die.source_part then
        return self.selected_die.source_part, self.selected_die.face_index
    end

    if not self.hover then
        return nil, nil
    end

    if self.hover.kind == "die" and self.hover.die then
        return self.hover.die.source_part, self.hover.die.face_index
    elseif self.hover.kind == "part" or self.hover.kind == "socket" or self.hover.kind == "rim" or self.hover.kind == "slot" then
        return self.hover.part, nil
    end

    return nil, nil
end

function V2Combat:draw_unfolded_die_view(part, current_face_index, x, y, width)
    if not (part and part.die) then
        return y
    end

    love.graphics.setFont(self.fonts.small)
    draw_text("Die", x, y, width, "left", COLORS.ink)
    y = y + 16

    local die_size = DIE_SIZE
    local gap = 6
    local columns = 3
    local grid_w = columns * die_size + (columns - 1) * gap
    local start_x = x + math.floor((width - grid_w) / 2)

    local face_columns = {
        sorted_face_indexes(part.die.wound_faces),
        sorted_face_indexes(part.die.maim_faces),
        durable_face_indexes(part.die)
    }
    local status = self:display_status_for_part(part) or "healthy"

    for column = 1, columns do
        for row = 1, 2 do
            local face_index = face_columns[column] and face_columns[column][row]
            if face_index then
                local die_rect = rect(start_x + (column - 1) * (die_size + gap), y + (row - 1) * (die_size + gap), die_size, die_size)
                local healthy_face = SymbolDie.face_for_status(part.die, face_index, "healthy")
                local is_wound_face = column == 1
                local is_maim_face = column == 2
                local display_face = healthy_face
                local crack_level = nil

                if status == "maimed" and (is_wound_face or is_maim_face) then
                    display_face = { Symbols.BLOOD }
                elseif status == "wounded" and is_wound_face then
                    display_face = { Symbols.BLOOD }
                end

                if status == "healthy" then
                    if is_wound_face then
                        crack_level = "heavy"
                    elseif is_maim_face then
                        crack_level = "light"
                    end
                elseif status == "wounded" and is_maim_face then
                    crack_level = "heavy"
                end

                draw_die_face(display_face, die_rect, current_face_index == face_index)
                draw_crack_overlay(die_rect, crack_level)

                if current_face_index == face_index then
                    draw_sprite_outline(die_rect, COLORS.selected, 4)
                end
            end
        end
    end

    y = y + die_size * 2 + gap + 8
    love.graphics.setFont(self.fonts.tiny)
    draw_text("faces break left to right", x, y, width, "left", COLORS.muted)

    return y + 18
end

function V2Combat:draw_inspector()
    love.graphics.setFont(self.fonts.body)
    local rail = self:rail_rect()
    if not draw_image("combat_inspector_rail", rail) then
        draw_box(rail, COLORS.rail, COLORS.line, 8)
    end
    draw_text("Inspector", rail.x + 14, rail.y + 12, rail.w - 28, "left", COLORS.ink)

    local y = rail.y + 42
    local lines = {}

    if self.drag or self.selected_die then
        lines = self:active_die_preview_lines()
    elseif self.hover then
        if self.hover.kind == "die" then
            local die = self.hover.die
            table.insert(lines, "Die: " .. Symbols.format_face(die.symbols))
            if self.hover.combatant then
                table.insert(lines, "Owner: " .. (self.hover.combatant.name or "?"))
            end
            table.insert(lines, "From: " .. (die.source_part and die.source_part.name or "?"))
            table.insert(lines, "Face: " .. tostring(die.face_index))
        elseif self.hover.kind == "part" or self.hover.kind == "socket" or self.hover.kind == "rim" or self.hover.kind == "slot" then
            local part = self.hover.part
            table.insert(lines, string.format("%s · %s", part.name or part.id or "Part", self:display_status_for_part(part) or "healthy"))
            table.insert(lines, "Heart value: " .. tostring(part.hp_value or 0))
            if part.slot then
                table.insert(lines, "Slot: " .. (part.slot.name or part.slot.id))
                table.insert(lines, "Cost: " .. Symbols.format_face(part.slot.cost))
            end
        elseif self.hover.kind == "crest" then
            local owner = self.hover.combatant and (self.hover.combatant.name or "?") or "?"
            local count = self.hover.combatant and self.hover.combatant:get_crest_count(self.hover.crest) or 0
            table.insert(lines, owner .. " Crest: " .. self.hover.crest .. " x" .. tostring(count))
            if self.hover.crest == "Valor" then
                table.insert(lines, "Spend: next die gains ATK.")
            elseif self.hover.crest == "Shadow" then
                table.insert(lines, "Spend: slots shroud their BP.")
            end
        elseif self.hover.kind == "confirm" then
            table.insert(lines, "Resolve current allocations.")
        end
    else
        table.insert(lines, "Hover a die, card, crest, or slot.")
    end

    for _, line in ipairs(lines) do
        y = draw_wrapped_text(line, rail.x + 14, y, rail.w - 28, "left", COLORS.ink, 6)
    end

    local inspected_part, current_face_index = self:inspected_die_source()
    local beat_rule_y = rail.y + rail.h - 222
    local log_rule_y = rail.y + rail.h - 150
    if inspected_part and y + 108 < beat_rule_y then
        y = y + 4
        self:draw_unfolded_die_view(inspected_part, current_face_index, rail.x + 14, y, rail.w - 28)
    end

    set_color(COLORS.line)
    love.graphics.line(rail.x + 14, beat_rule_y, rail.x + rail.w - 14, beat_rule_y)
    love.graphics.setFont(self.fonts.tiny)
    draw_text("Now", rail.x + 14, beat_rule_y + 10, rail.w - 28, "left", COLORS.muted)
    draw_wrapped_text(self.message or "", rail.x + 14, beat_rule_y + 26, rail.w - 28, "left", COLORS.ink, 2)

    set_color(COLORS.line)
    love.graphics.line(rail.x + 14, log_rule_y, rail.x + rail.w - 14, log_rule_y)
    love.graphics.setFont(self.fonts.body)
    draw_text("Log", rail.x + 14, log_rule_y + 12, rail.w - 28, "left", COLORS.ink)

    y = log_rule_y + 36
    for _, line in ipairs(self.log) do
        y = draw_wrapped_text(line, rail.x + 14, y, rail.w - 28, "left", COLORS.muted, 4)
    end
end

function V2Combat:draw_combat_end_overlay()
    if not self.combat_end then
        return
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local panel_w = 236
    local panel_h = 94
    local panel = rect((width - panel_w) / 2, (height - panel_h) / 2, panel_w, panel_h)
    local color = COLORS.muted

    if self.combat_end.result == "win" then
        color = COLORS.player
    elseif self.combat_end.result == "lose" then
        color = COLORS.enemy
    end

    set_color({ 0, 0, 0, 0.48 })
    love.graphics.rectangle("fill", 0, 0, width, height)
    draw_box(panel, COLORS.rail, color, 8)

    love.graphics.setFont(self.fonts.title)
    draw_text(self.combat_end.title, panel.x + 14, panel.y + 18, panel.w - 28, "center", color)

    local remaining = math.max(0, (self.combat_end.delay or COMBAT_END_RETURN_DELAY) - (self.combat_end.elapsed or 0))
    local dots = string.rep(".", math.floor((self.combat_end.elapsed or 0) * 3) % 4)
    love.graphics.setFont(self.fonts.small)
    draw_text("Returning" .. dots, panel.x + 14, panel.y + 58, panel.w - 28, "center", COLORS.ink)
    love.graphics.setFont(self.fonts.tiny)
    draw_text(string.format("%.1fs", remaining), panel.x + 14, panel.y + 76, panel.w - 28, "center", COLORS.muted)
end

function V2Combat:draw()
    love.graphics.clear(COLORS.bg)
    draw_image("combat_tabletop", rect(0, 0, love.graphics.getWidth(), love.graphics.getHeight()))
    love.graphics.setFont(self.fonts.body)
    self:layout()

    local shake_x, shake_y = self:resolution_shake_offset()
    if love.graphics.push then
        love.graphics.push()
        love.graphics.translate(shake_x, shake_y)
    end

    self:draw_tableau_band(self:enemy_strip_rect(), "enemy", self.enemy)
    self:draw_tableau_band(self:player_strip_rect(), "player", self.player)
    self:draw_center()
    self:draw_pool()

    for _, layout in ipairs(self.empty_card_rects or {}) do
        self:draw_empty_card(layout)
    end

    for _, part in ipairs(self.enemy.body_parts or {}) do
        self:draw_part_card(part, self.card_rects[part])
    end

    for _, part in ipairs(self.player.body_parts or {}) do
        self:draw_part_card(part, self.card_rects[part])
    end

    self:draw_slot_activation_effects()
    self:draw_auto_allocation_ghost()
    self:draw_resolution_effects()
    self:draw_drag_ghost()

    if love.graphics.pop then
        love.graphics.pop()
    end

    self:draw_global_spine()
    self:draw_inspector()
    self:draw_combat_end_overlay()
end

return V2Combat
