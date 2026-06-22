local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Input = require("core.input")
local BPInspector = require("ui.bp_inspector")
local BPCard = require("ui.bp_card")
local Catalog = require("systems.bodypart_catalog")
local SymbolDie = require("core.symbol_die")
local Text = require("ui.text")

local MenuScreen = {}
MenuScreen.__index = MenuScreen
MenuScreen.opaque = true

local COLORS = {
    bg = { 0.035, 0.04, 0.065, 1 },
    panel = { 0.075, 0.08, 0.12, 1 },
    surface = { 0.105, 0.11, 0.16, 1 },
    surface_low = { 0.055, 0.06, 0.09, 0.96 },
    line = { 0.70, 0.72, 0.84, 0.82 },
    ink = { 0.96, 0.95, 1, 1 },
    muted = { 0.64, 0.63, 0.74, 1 },
    accent = { 0.36, 0.70, 0.76, 1 },
    warning = { 1, 0.72, 0.35, 1 },
    selected = { 0.22, 0.46, 0.56, 1 }
}

local INSPECTOR_COLORS = {
    bg = COLORS.surface_low,
    line = COLORS.line,
    ink = COLORS.ink,
    muted = COLORS.muted,
    accent = COLORS.accent,
    warning = COLORS.warning
}

local function set_color(color)
    love.graphics.setColor(color)
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function title_case(value)
    return (tostring(value or ""):gsub("^%l", string.upper))
end

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function draw_panel(x, y, w, h)
    set_color(COLORS.panel)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)
    set_color(COLORS.line)
    love.graphics.rectangle("line", x, y, w, h, 5, 5)
end

local function draw_box(rect, fill, line, radius)
    set_color(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, radius or 4, radius or 4)
    set_color(line)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, radius or 4, radius or 4)
end

local function draw_image(id, r, color)
    local image = Assets.images and Assets.images[id]
    if not image then
        return false
    end

    set_color(color or { 1, 1, 1, 1 })
    love.graphics.draw(image, r.x, r.y, 0, r.w / image:getWidth(), r.h / image:getHeight())
    return true
end

local function draw_cursor(row_rect, selected)
    if not selected then
        return
    end

    if draw_image("menu_cursor", rect(row_rect.x + 6, row_rect.y + 7, 8, 12)) then
        return
    end

    set_color(COLORS.ink)
    love.graphics.print(">", row_rect.x + 6, row_rect.y + 6)
end

local function list_label(part)
    if not part then
        return "-"
    end

    return part.name or part.id or part.def_id or "Body Part"
end

local function text_width(text)
    return Text.width(text)
end

local function truncate_text(text, max_width)
    return Text.truncate(text, max_width)
end

function MenuScreen:enter(context)
    context = context or {}
    self.world = context.world
    self.screen = context.screen or "inventory"
    self.title = context.title or title_case(self.screen)
    self.status = nil
    self.selected_index = 1
    self.scroll = 0
    self:refresh_content()
end

function MenuScreen:refresh_content()
    if self.screen == "dreamform" then
        self.active_entries = Catalog.active_parts(self.world)
        self.selected_index = clamp(self.selected_index or 1, 1, math.max(1, #self.active_entries))
    elseif self.screen == "esoterica" then
        self.esoterica_parts = Catalog.discovered_parts(self.world)
        self.selected_index = clamp(self.selected_index or 1, 1, math.max(1, #self.esoterica_parts))
        self.scroll = clamp(self.scroll or 0, 0, math.max(0, #self.esoterica_parts - 1))
    end
end

function MenuScreen:close()
    GameState.pop()
end

function MenuScreen:confirm()
    if self.screen == "save" then
        if not self.world then
            self.status = "No active world to save."
            return
        end

        local ok, err = self.world:autosave("manual")
        if ok then
            self.status = "Saved."
        else
            self.status = "Save unavailable: " .. tostring(err)
        end
    elseif self.screen == "options" then
        self.status = "Options are not ready yet."
    elseif self.screen == "quit" then
        self.status = "Title flow is not ready yet."
    end
end

function MenuScreen:move_selection(delta)
    if self.screen ~= "dreamform" and self.screen ~= "esoterica" then
        return false
    end

    self:refresh_content()

    local count = self.screen == "dreamform" and #(self.active_entries or {}) or #(self.esoterica_parts or {})
    if count == 0 then
        return true
    end

    self.selected_index = clamp((self.selected_index or 1) + delta, 1, count)
    return true
end

function MenuScreen:move_dreamform_selection(delta)
    if self.screen ~= "dreamform" then
        return false
    end

    return self:move_selection(delta)
end

function MenuScreen:actionpressed(action)
    if action == "cancel" or action == "menu" then
        self:close()
        return true
    elseif action == "confirm" then
        self:confirm()
        return true
    elseif action == "move_up" then
        if self.screen == "dreamform" then
            return self:move_selection(-1)
        end
        return self:move_selection(-1)
    elseif action == "move_down" then
        if self.screen == "dreamform" then
            return self:move_selection(1)
        end
        return self:move_selection(1)
    elseif action == "move_left" then
        if self.screen == "dreamform" then
            return self:move_dreamform_selection(-1)
        end
    elseif action == "move_right" then
        if self.screen == "dreamform" then
            return self:move_dreamform_selection(1)
        end
    end

    return false
end

function MenuScreen:keypressed(key)
    return self:actionpressed(Input.action_for_key(key))
end

function MenuScreen:draw_inventory(x, y, w)
    local items = sorted_keys(self.world and self.world.player and self.world.player.inventory)
    if #items == 0 then
        set_color(COLORS.muted)
        love.graphics.print("No tools or items.", x, y)
        return
    end

    for index, item in ipairs(items) do
        set_color(COLORS.ink)
        love.graphics.print(title_case(item), x, y + (index - 1) * 24)
    end

    local equipped = self.world and self.world.player and self.world.player.equipped
    if equipped then
        set_color(COLORS.accent)
        love.graphics.printf("Equipped: " .. title_case(equipped), x, y + 168, w, "left")
    end
end

function MenuScreen:selected_dreamform_part()
    local entry = self.active_entries and self.active_entries[self.selected_index or 1]
    return entry and entry.part
end

function MenuScreen:draw_pool_overview(parts, rect, selected_index)
    draw_box(rect, COLORS.surface_low, COLORS.line, 5)

    local pad = 10
    local die_gap = 8
    local strip_h = 38
    local strip_y = rect.y + rect.h - strip_h
    local die_area_y = rect.y + 10
    local die_area_h = math.max(72, strip_y - die_area_y - 8)
    local columns = 3
    local rows = 2
    local cell_w = math.floor((rect.w - pad * 2 - die_gap * (columns - 1)) / columns)
    local cell_h = math.floor((die_area_h - die_gap * (rows - 1)) / rows)
    local face_gap = 4
    local face_size = math.max(16, math.min(
        36,
        math.floor((cell_w - 12 - face_gap * 2) / 3),
        math.floor((cell_h - 8 - face_gap) / 2)))

    for index, part in ipairs(parts or {}) do
        local die_column = (index - 1) % columns
        local die_row = math.floor((index - 1) / columns)
        local cell_x = rect.x + pad + die_column * (cell_w + die_gap)
        local cell_y = die_area_y + die_row * (cell_h + die_gap)
        local grid_w = face_size * 3 + face_gap * 2
        local grid_h = face_size * 2 + face_gap
        local grid_x = cell_x + math.floor(math.max(0, cell_w - grid_w) / 2)
        local grid_y = cell_y + math.floor(math.max(0, cell_h - grid_h) / 2)

        if index == selected_index then
            set_color({ COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 0.18 })
            love.graphics.rectangle("fill", grid_x - 6, grid_y - 6, grid_w + 12, grid_h + 12, 4, 4)
            set_color(COLORS.accent)
            love.graphics.rectangle("line", grid_x - 6, grid_y - 6, grid_w + 12, grid_h + 12, 4, 4)
        end

        for face_index = 1, 6 do
            local column = (face_index - 1) % 3
            local row = math.floor((face_index - 1) / 3)
            local face = SymbolDie.face_for_status(part.die, face_index, part.status)
            BPCard.draw_die_face(face, {
                x = grid_x + column * (face_size + face_gap),
                y = grid_y + row * (face_size + face_gap),
                w = face_size,
                h = face_size
            }, {
                scale = face_size / 36
            })
        end
    end

    set_color(COLORS.line)
    love.graphics.line(rect.x + pad, strip_y, rect.x + rect.w - pad, strip_y)

    local entries = BPInspector.die_face_count_entries(parts)
    local font = love.graphics.getFont()
    local row_h = font and font:getHeight() + 4 or 16
    local symbol_size = 13
    local cursor_x = rect.x + pad
    local cursor_y = strip_y + 6
    local max_x = rect.x + rect.w - pad
    local max_y = rect.y + rect.h - 2

    for _, entry in ipairs(entries) do
        local symbol_w = BPCard.symbol_sequence_width(entry.symbols, symbol_size)
        local count_text = " x " .. tostring(entry.count)
        local item_w = symbol_w + text_width(count_text) + 12
        if cursor_x + item_w > max_x then
            cursor_x = rect.x + pad
            cursor_y = cursor_y + row_h
        end
        if cursor_y + row_h > max_y then
            break
        end

        symbol_w = BPCard.draw_symbol_sequence(entry.symbols, cursor_x, cursor_y + 1, symbol_size)
        set_color(COLORS.ink)
        love.graphics.print(count_text, cursor_x + symbol_w + 4, cursor_y)
        cursor_x = cursor_x + item_w
    end
end

function MenuScreen:draw_dreamform(x, y, w, h)
    self:refresh_content()

    local gap = 18
    local card_gap = 8
    local count = math.max(1, #(self.active_entries or {}))
    local available_for_cards = w - card_gap * math.max(0, count - 1)
    local card_scale = math.min(1, available_for_cards / (BPCard.total_width(1) * count))
    local card_w = BPCard.total_width(card_scale)
    local card_h = BPCard.total_height(card_scale)
    local grid_w = count * card_w + math.max(0, count - 1) * card_gap
    local start_x = x + math.floor(math.max(0, w - grid_w) / 2)
    local row_y = y

    for index, entry in ipairs(self.active_entries or {}) do
        local layout = BPCard.layout_at(
            start_x + (index - 1) * (card_w + card_gap),
            row_y,
            "enemy",
            card_scale)

        if entry.part then
            BPCard.draw(entry.part, layout, {
                selected_source = index == self.selected_index,
                status = entry.part.status
            })
        else
            BPCard.draw_empty(layout)
        end
    end

    local parts = {}
    local selected_pool_index = nil
    for index, entry in ipairs(self.active_entries or {}) do
        if entry.part then
            table.insert(parts, entry.part)
            if index == self.selected_index then
                selected_pool_index = #parts
            end
        end
    end
    local bottom_y = y + card_h + 22
    local bottom_h = math.max(120, h - (bottom_y - y))
    local overview_w = math.floor((w - gap) * 0.52)
    local inspector_w = w - overview_w - gap
    self:draw_pool_overview(parts, {
        x = x,
        y = bottom_y,
        w = overview_w,
        h = bottom_h
    }, selected_pool_index)

    local part = self:selected_dreamform_part()
    BPInspector.draw_panel({
        x = x + overview_w + gap,
        y = bottom_y,
        w = inspector_w,
        h = bottom_h
    }, {
        part = part
    }, {
        colors = INSPECTOR_COLORS,
        hide_header = true
    })
end

function MenuScreen:selected_esoterica_part()
    return self.esoterica_parts and self.esoterica_parts[self.selected_index or 1]
end

function MenuScreen:sync_esoterica_scroll(visible_rows)
    visible_rows = math.max(1, visible_rows or 1)
    local selected = self.selected_index or 1
    self.scroll = self.scroll or 0

    if selected <= self.scroll then
        self.scroll = selected - 1
    elseif selected > self.scroll + visible_rows then
        self.scroll = selected - visible_rows
    end
end

function MenuScreen:draw_esoterica(x, y, w, h)
    self:refresh_content()

    local inspector_w = math.min(292, math.floor(w * 0.34))
    local list_w = math.min(238, math.floor(w * 0.29))
    local gap = 18
    local card_area_w = math.max(BPCard.total_width(1), w - list_w - inspector_w - gap * 2)
    local row_h = 30
    local visible_rows = math.max(1, math.floor((h - 52) / row_h))
    self:sync_esoterica_scroll(visible_rows)

    local list_rect = { x = x, y = y, w = list_w, h = h }
    draw_box(list_rect, COLORS.surface_low, COLORS.line, 5)
    set_color(COLORS.ink)
    love.graphics.printf("Discovered Body Parts", x + 12, y + 10, list_w - 24, "left")

    local start_index = (self.scroll or 0) + 1
    local end_index = math.min(#(self.esoterica_parts or {}), start_index + visible_rows - 1)
    local row_y = y + 42

    for index = start_index, end_index do
        local part = self.esoterica_parts[index]
        local rect = { x = x + 10, y = row_y, w = list_w - 20, h = row_h - 4 }
        if index == self.selected_index then
            draw_cursor(rect, true)
            set_color(COLORS.ink)
        else
            set_color(COLORS.muted)
        end

        local type_text = tostring(part and part.type or "")
        local type_w = 48
        local name_x = rect.x + 24
        love.graphics.print(truncate_text(list_label(part), rect.w - 34 - type_w), name_x, rect.y + 6)
        love.graphics.print(type_text, rect.x + rect.w - type_w, rect.y + 6)
        row_y = row_y + row_h
    end

    if #(self.esoterica_parts or {}) == 0 then
        set_color(COLORS.muted)
        love.graphics.printf("No Body Parts discovered.", x + 12, y + 44, list_w - 24, "left")
    end

    local part = self:selected_esoterica_part()
    local card_scale = math.max(1, math.min(2, math.floor(math.min(
        card_area_w / BPCard.total_width(1),
        h / BPCard.total_height(1)))))
    local rendered_card_w = BPCard.total_width(card_scale)
    local rendered_card_h = BPCard.total_height(card_scale)
    local card_area_x = x + list_w + gap
    local card_x = card_area_x + math.floor(math.max(0, card_area_w - rendered_card_w) / 2)
    local card_y = y + math.floor(math.max(0, h - rendered_card_h) / 2)
    local card_layout = BPCard.layout_at(card_x, card_y, "player", card_scale)
    if part then
        BPCard.draw(part, card_layout, {
            status = part.status,
            scale = card_scale,
            fonts = BPCard.fonts(1)
        })
    else
        BPCard.draw_empty(card_layout, {
            scale = card_scale,
            fonts = BPCard.fonts(1)
        })
    end

    BPInspector.draw_panel({
        x = card_area_x + card_area_w + gap,
        y = y,
        w = inspector_w,
        h = h
    }, {
        part = self:selected_esoterica_part()
    }, {
        colors = INSPECTOR_COLORS,
        hide_header = true,
        show_die = true
    })
end

function MenuScreen:draw_save(x, y, w)
    set_color(COLORS.ink)
    love.graphics.print("Record the current dream state.", x, y)

    if self.status then
        set_color(self.status == "Saved." and COLORS.accent or COLORS.warning)
        love.graphics.printf(self.status, x, y + 48, w, "left")
    end
end

function MenuScreen:draw_placeholder(x, y, w, text)
    set_color(COLORS.muted)
    love.graphics.printf(text, x, y, w, "left")
    if self.status then
        set_color(COLORS.warning)
        love.graphics.printf(self.status, x, y + 56, w, "left")
    end
end

function MenuScreen:draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local margin = 24
    local content_x = margin + 28
    local content_y = 92
    local content_w = width - margin * 2 - 56
    local content_h = height - content_y - margin - 28
    local frame = rect(margin, margin, width - margin * 2, height - margin * 2)

    set_color(COLORS.bg)
    love.graphics.rectangle("fill", 0, 0, width, height)
    local drew_frame = draw_image("menu_full_frame", frame)
    if not drew_frame then
        draw_panel(frame.x, frame.y, frame.w, frame.h)
    end

    set_color(COLORS.ink)
    love.graphics.printf(self.title, margin + 24, margin + 22, width - margin * 2 - 48, "left")
    if not drew_frame then
        set_color(COLORS.line)
        love.graphics.line(margin + 24, margin + 62, width - margin - 24, margin + 62)
    end

    if self.screen == "inventory" then
        self:draw_inventory(content_x, content_y, content_w)
    elseif self.screen == "dreamform" then
        self:draw_dreamform(content_x, content_y, content_w, content_h)
    elseif self.screen == "esoterica" then
        self:draw_esoterica(content_x, content_y, content_w, content_h)
    elseif self.screen == "save" then
        self:draw_save(content_x, content_y, content_w)
    elseif self.screen == "options" then
        self:draw_placeholder(content_x, content_y, content_w, "Options are not ready yet.")
    elseif self.screen == "quit" then
        self:draw_placeholder(content_x, content_y, content_w, "Title flow is not ready yet.")
    end
end

return MenuScreen
