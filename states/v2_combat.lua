local GameState = require("core.gamestate")
local Assets = require("core.assets")
local Engine = require("combat.v2_engine")
local Events = require("combat.events")
local Demo = require("combat.v2_demo")
local Symbols = require("core.symbols")

local V2Combat = {}
V2Combat.__index = V2Combat

local MARGIN = 12
local RAIL_WIDTH = 180
local STRIP_HEIGHT = 130
local CONTROL_HEIGHT = 64
local BODY_PART_SLOTS = 6
local CARD_WIDTH = 116
local CARD_HEIGHT = 88
local CARD_GAP = 8
local DIE_SIZE = 36
local SYMBOL_SIZE = 12

local COLORS = {
    bg = { 0.94, 0.93, 0.89, 1 },
    panel = { 0.98, 0.98, 0.95, 1 },
    rail = { 0.97, 0.97, 0.94, 1 },
    ink = { 0.12, 0.12, 0.12, 1 },
    muted = { 0.42, 0.42, 0.38, 1 },
    line = { 0.72, 0.72, 0.66, 1 },
    dashed = { 0.58, 0.58, 0.54, 1 },
    player = { 0.0, 0.47, 0.36, 1 },
    enemy = { 0.67, 0.18, 0.12, 1 },
    selected = { 0.17, 0.2, 0.92, 1 },
    valid = { 0.0, 0.52, 0.39, 1 },
    invalid = { 0.55, 0.55, 0.55, 0.45 },
    attack = { 0.7, 0.2, 0.15, 1 },
    defense = { 0.12, 0.36, 0.72, 1 },
    essence = { 0.9, 0.62, 0.14, 1 },
    blood = { 0.55, 0.05, 0.08, 1 }
}

local STATUS_COLORS = {
    healthy = { 0.08, 0.55, 0.22, 1 },
    wounded = { 0.86, 0.58, 0.08, 1 },
    maimed = { 0.42, 0.42, 0.42, 1 }
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

local function point_in_rect(x, y, rect)
    return rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
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

local function draw_sprite_outline(r, color, radius)
    set_color(color or COLORS.line)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, radius or 3, radius or 3)
end

local function draw_text(text, x, y, w, align, color)
    set_color(color or COLORS.ink)
    love.graphics.printf(text or "", x, y, w or 200, align or "left")
end

local function wrapped_text_height(text, w)
    local font = love.graphics.getFont()
    if not font then
        return 12
    end

    local line_count = 1
    if font.getWrap then
        local _, wrapped = font:getWrap(text or "", w or 200)
        if type(wrapped) == "table" then
            line_count = math.max(1, #wrapped)
        end
    end

    return line_count * font:getHeight()
end

local function draw_wrapped_text(text, x, y, w, align, color, gap)
    draw_text(text, x, y, w, align, color)
    return y + wrapped_text_height(text, w) + (gap or 4)
end

local function draw_status_dot(part, x, y)
    set_color(STATUS_COLORS[part.status or "healthy"] or STATUS_COLORS.healthy)
    love.graphics.circle("fill", x, y, 4)
end

local function draw_hearts(value, x, y)
    set_color(COLORS.ink)
    love.graphics.print("H " .. tostring(value or 0), x, y)
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

local function draw_damage_decoration(part, card)
    if not part or part.status == "healthy" then
        return
    end

    if part.status == "wounded" then
        set_color({ 0.86, 0.58, 0.08, 0.16 })
        love.graphics.rectangle("fill", card.x + 2, card.y + 2, card.w - 4, card.h - 4)
        set_color({ 0.3, 0.25, 0.2, 0.72 })
        love.graphics.setLineWidth(1)
        love.graphics.line(card.x + card.w - 24, card.y + 12, card.x + card.w - 16, card.y + 21)
        love.graphics.line(card.x + card.w - 16, card.y + 21, card.x + card.w - 22, card.y + 31)
    elseif part.status == "maimed" then
        set_color({ 0.12, 0.12, 0.12, 0.18 })
        love.graphics.rectangle("fill", card.x + 2, card.y + 2, card.w - 4, card.h - 4)
        set_color({ 0.12, 0.12, 0.12, 0.72 })
        love.graphics.setLineWidth(1)
        love.graphics.line(card.x + 12, card.y + 12, card.x + card.w - 12, card.y + card.h - 12)
        love.graphics.line(card.x + card.w - 16, card.y + 14, card.x + 20, card.y + card.h - 16)
    end
end

local function draw_symbol_chip(symbol, x, y, w, h)
    local chip = rect(x, y, w, h)
    draw_box(chip, { 1, 1, 1, 0.9 }, symbol_color(symbol), 4)
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

local function draw_die_face(symbols, r, is_selected)
    local outline = is_selected and COLORS.selected or COLORS.line
    if not draw_image("empty_die", r) then
        draw_box(r, { 1, 1, 1, 0.95 }, outline, 5)
    end

    local visible_symbols = {}
    for _, symbol in ipairs(symbols or { Symbols.BLANK }) do
        local normalized = Symbols.normalize(symbol)
        if normalized and normalized ~= Symbols.BLANK then
            table.insert(visible_symbols, normalized)
        end
    end

    local count = #visible_symbols
    if count == 1 then
        draw_symbol_sprite(visible_symbols[1], r.x + 12, r.y + 12, SYMBOL_SIZE)
    elseif count == 2 then
        draw_symbol_sprite(visible_symbols[1], r.x + 7, r.y + 12, SYMBOL_SIZE)
        draw_symbol_sprite(visible_symbols[2], r.x + 17, r.y + 12, SYMBOL_SIZE)
    elseif count >= 3 then
        draw_symbol_sprite(visible_symbols[1], r.x + 5, r.y + 12, SYMBOL_SIZE)
        draw_symbol_sprite(visible_symbols[2], r.x + 12, r.y + 12, SYMBOL_SIZE)
        draw_symbol_sprite(visible_symbols[3], r.x + 19, r.y + 12, SYMBOL_SIZE)
    end

    if is_selected then
        draw_sprite_outline(r, outline, 4)
    end
end

local function format_part_line(part)
    return string.format("%s · %s", part.name or part.id or "Part", part.status or "healthy")
end

local function make_log_line(event, data)
    if event == Events.CREST_EXPENDED then
        return string.format("%s expends %s.", data.combatant.name, data.crest)
    elseif event == Events.SLOT_FED then
        return string.format("%s feeds %s.", data.combatant.name, data.slot.name)
    elseif event == Events.SLOT_RESOLVED then
        return string.format("%s resolves %s.", data.combatant.name, data.slot.name)
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
    self.crest_rects = {}
    self.hover = nil
    self.selected_die = nil
    self.drag = nil
    self.log = {}
    self.message = "Drag a die to a rim, socket, or hatch. C confirms."
    self.fonts = {
        body = love.graphics.newFont(12),
        small = love.graphics.newFont(10),
        tiny = love.graphics.newFont(9)
    }

    self:register_events()
    self.engine:start_combat()
    self.engine:auto_allocate(self.enemy)
end

function V2Combat:register_events()
    local tracked = {
        Events.CREST_EXPENDED,
        Events.SLOT_FED,
        Events.SLOT_RESOLVED,
        Events.LATCH_EJECTED,
        Events.PART_RESOLVED,
        Events.DAMAGE_DEALT
    }

    for _, event_name in ipairs(tracked) do
        self.engine:on(event_name, function(data)
            local line = make_log_line(event_name, data)
            if line then
                table.insert(self.log, 1, line)
                while #self.log > 8 do
                    table.remove(self.log)
                end
            end
        end)
    end
end

function V2Combat:main_width()
    return love.graphics.getWidth() - RAIL_WIDTH - MARGIN * 3
end

function V2Combat:rail_rect()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    return rect(width - RAIL_WIDTH - MARGIN, MARGIN, RAIL_WIDTH, height - MARGIN * 2)
end

function V2Combat:enemy_strip_rect()
    return rect(MARGIN, MARGIN, self:main_width(), STRIP_HEIGHT)
end

function V2Combat:center_rect()
    local enemy_strip = self:enemy_strip_rect()
    local control = self:control_rect()
    return rect(MARGIN, enemy_strip.y + enemy_strip.h + 10, self:main_width(), control.y - enemy_strip.y - enemy_strip.h - 20)
end

function V2Combat:control_rect()
    local height = love.graphics.getHeight()
    local y = height - MARGIN - STRIP_HEIGHT - 10 - CONTROL_HEIGHT
    return rect(MARGIN, y, self:main_width(), CONTROL_HEIGHT)
end

function V2Combat:player_strip_rect()
    local height = love.graphics.getHeight()
    return rect(MARGIN, height - MARGIN - STRIP_HEIGHT, self:main_width(), STRIP_HEIGHT)
end

function V2Combat:layout_cards(combatant, strip, side)
    local total_w = BODY_PART_SLOTS * CARD_WIDTH + (BODY_PART_SLOTS - 1) * CARD_GAP
    local start_x = strip.x + math.floor((strip.w - total_w) / 2)
    local card_w = CARD_WIDTH
    local card_h = CARD_HEIGHT
    local y = strip.y + (side == "enemy" and 26 or 28)

    for index = 1, BODY_PART_SLOTS do
        local part = (combatant.body_parts or {})[index]
        local x = start_x + (index - 1) * (card_w + CARD_GAP)
        local card = rect(x, y, card_w, card_h)
        local rim_y = side == "enemy" and (card.y + card.h - 6) or (card.y - DIE_SIZE + 6)
        local rim = rect(card.x + 6, rim_y, DIE_SIZE, DIE_SIZE)
        local socket_y = side == "enemy" and (rim_y - DIE_SIZE) or (card.y + 6)
        local socket = rect(card.x + 6, socket_y, DIE_SIZE, DIE_SIZE)
        local hatch = rect(card.x + 64, card.y + 34, DIE_SIZE, DIE_SIZE)
        local track = rect(card.x + 64, card.y + 74, card.w - 68, SYMBOL_SIZE)
        local slot_label = rect(card.x + 58, card.y + 19, card.w - 62, 12)
        local label_y = side == "enemy" and (card.y - 14) or (card.y + card.h + 2)
        local label = rect(card.x, label_y, card.w, 12)
        local meta_y = side == "enemy" and (card.y + 10) or (card.y + card.h - 16)
        local meta = rect(card.x + 12, meta_y, 42, 10)

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
    self.crest_rects = {}
    self.empty_card_rects = {}

    self:layout_cards(self.enemy, self:enemy_strip_rect(), "enemy")
    self:layout_cards(self.player, self:player_strip_rect(), "player")

    local control = self:control_rect()
    local pool_x = control.x + 56
    local pool_y = control.y + 8

    for index, die in ipairs(self.engine:get_pool(self.player)) do
        self.die_rects[die] = rect(pool_x + (index - 1) * (DIE_SIZE + 8), pool_y, DIE_SIZE, DIE_SIZE)
    end

    local crest_x = control.x + control.w - 230
    for index, crest in ipairs({ "Valor", "Shadow" }) do
        self.crest_rects[crest] = rect(crest_x + (index - 1) * 72, pool_y + 6, 64, 30)
    end

    self.confirm_rect = rect(control.x + control.w - 96, control.y + 12, 82, 34)
end

function V2Combat:update(_)
    self:layout()
    local mx, my = love.mouse.getPosition()
    if self.drag then
        self.drag.x = mx
        self.drag.y = my
    end
    self:update_hover(mx, my)
end

function V2Combat:update_hover(mx, my)
    self.hover = nil

    if not self.drag then
        for die, die_rect in pairs(self.die_rects) do
            if point_in_rect(mx, my, die_rect) then
                self.hover = { kind = "die", die = die }
                return
            end
        end
    end

    for crest, crest_rect in pairs(self.crest_rects) do
        if point_in_rect(mx, my, crest_rect) then
            self.hover = { kind = "crest", crest = crest }
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
    if not self.selected_die then
        return nil
    end
    return self.engine:get_valid_destinations(self.player, self.selected_die)
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
    local effective = self.engine:get_effective_symbols(self.player, die)
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
            symbol = symbol
        })
    end
    table.sort(lit_symbols, function(a, b) return a.index < b.index end)

    local ordered = {}
    for _, entry in ipairs(lit_symbols) do
        table.insert(ordered, entry.symbol)
    end

    return ordered, burned
end

function V2Combat:drag_preview_lines()
    local lines = {}
    local drag = self.drag
    if not drag or not drag.die then
        return lines
    end

    local die = drag.die
    local effective = self.engine:get_effective_symbols(self.player, die)
    table.insert(lines, "Held: " .. Symbols.format_face(effective))
    table.insert(lines, "From: " .. (die.source_part and die.source_part.name or "?"))

    local hover = self.hover
    if hover and is_destination_kind(hover.kind) then
        local valid = self:is_valid_destination(hover.kind, hover.part)
        table.insert(lines, "")
        if hover.kind == "socket" then
            table.insert(lines, "Drop: defend " .. (hover.part.name or hover.part.id))
            local used, burned = classify_preview_symbols(effective, Symbols.WARD)
            table.insert(lines, "Uses: " .. Symbols.format_face(used))
            if #burned > 0 then
                table.insert(lines, "Burns: " .. Symbols.format_face(burned))
            end
        elseif hover.kind == "rim" then
            table.insert(lines, "Drop: attack " .. (hover.part.name or hover.part.id))
            local used, burned = classify_preview_symbols(effective, Symbols.STRIKE)
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
        table.insert(lines, "Drop onto a glowing destination.")
    end

    return lines
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
        self.selected_die = nil
    end
end

function V2Combat:confirm_round()
    self.engine:resolve_round()

    if self.engine.state == "COMPLETE" then
        self.message = self.engine.winner and ("Winner: " .. self.engine.winner.name) or "Combat ended."
        return
    end

    self.engine:start_round()
    self.engine:auto_allocate(self.enemy)
    self.selected_die = nil
    self.message = "Next round. Enemy allocation is visible."
end

function V2Combat:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    self:update_hover(x, y)
    local hover = self.hover

    if not hover then
        self.selected_die = nil
        return
    end

    if hover.kind == "die" then
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
    elseif hover.kind == "crest" then
        local ok, reason = self.engine:expend_crest(self.player, hover.crest)
        self:message_for_result(ok, reason)
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
    elseif key == "c" or key == "return" then
        self:confirm_round()
    elseif key == "r" then
        self:enter()
    end
end

function V2Combat:draw_strip(strip, title, combatant)
    love.graphics.setFont(self.fonts.body)
    draw_box(strip, COLORS.panel, COLORS.line, 8)
    draw_hearts(combatant.heart_points or 0, strip.x + strip.w - 72, strip.y + 6)
end

function V2Combat:draw_slot_track(part, layout, hatch_outline)
    local slot = part.slot
    if not slot then
        draw_image("die-hatch4", layout.hatch, { 1, 1, 1, 0.45 })
        return
    end

    local has_charge = false
    for _, charged in pairs(part.slot_charge or {}) do
        if charged then
            has_charge = true
            break
        end
    end

    local hatch_id = "die-hatch1"
    if part.status == "maimed" then
        hatch_id = "die-hatch4"
    elseif hatch_outline == COLORS.valid then
        hatch_id = "die-hatch2"
    elseif has_charge then
        hatch_id = "die-hatch3"
    end

    if not draw_image(hatch_id, layout.hatch) then
        draw_box(layout.hatch, { 1, 1, 1, 0.8 }, hatch_outline or COLORS.line, 3)
    end

    if hatch_outline == COLORS.valid then
        draw_sprite_outline(layout.hatch, COLORS.valid, 3)
    end

    local cost = slot.cost or {}
    for index, symbol in ipairs(cost) do
        local lit = part.slot_charge and part.slot_charge[index]
        draw_symbol_sprite(symbol, layout.track.x + (index - 1) * (SYMBOL_SIZE + 1), layout.track.y, SYMBOL_SIZE, not lit, lit and 1 or 0.85)
    end

    love.graphics.setFont(self.fonts.tiny)
    draw_text(slot.name or "Slot", layout.slot_label.x, layout.slot_label.y, layout.slot_label.w, "center", COLORS.muted)
end

function V2Combat:draw_assignment_die(assignment, target_rect)
    if not assignment then
        return
    end

    draw_die_face(assignment.symbols or assignment.die.symbols, target_rect, false)
end

function V2Combat:draw_part_card(part, layout)
    love.graphics.setFont(self.fonts.small)
    local card = layout.card
    local source_highlight = self.hover and self.hover.kind == "die" and self.hover.die.source_part == part
    local selected_source = self.selected_die and self.selected_die.source_part == part
    local outline = COLORS.line
    if source_highlight or selected_source then
        outline = COLORS.selected
    end

    if not draw_image("bp_card", card) then
        draw_box(card, COLORS.panel, outline, 6)
    end
    draw_damage_decoration(part, card)
    if outline ~= COLORS.line then
        draw_sprite_outline(card, outline, 2)
    end

    draw_hp_badge(part.hp_value or 1, layout.meta.x, layout.meta.y)

    local socket_valid = self:is_valid_destination("socket", part)
    local rim_valid = self:is_valid_destination("rim", part)
    local slot_valid = self:is_valid_destination("slot", part)

    local socket_outline = socket_valid and COLORS.valid or COLORS.dashed
    local rim_outline = rim_valid and COLORS.valid or COLORS.dashed
    local hatch_outline = slot_valid and COLORS.valid or COLORS.line

    if not draw_image("die_socket", layout.socket) then
        draw_box(layout.socket, { 1, 1, 1, 0.35 }, socket_outline, 3)
    end
    if not draw_image("die_rim", layout.rim, nil, layout.side == "enemy") then
        draw_box(layout.rim, { 1, 1, 1, 0.2 }, rim_outline, 3)
    end
    if socket_valid then
        draw_sprite_outline(layout.socket, COLORS.valid, 3)
    end
    if rim_valid then
        draw_sprite_outline(layout.rim, COLORS.valid, 3)
    end

    self:draw_assignment_die(self.engine.assignments.sockets[part], layout.socket)
    self:draw_assignment_die(self.engine.assignments.rims[part], layout.rim)

    local previous_color = COLORS.line
    if slot_valid then
        previous_color = COLORS.valid
    elseif part.status == "maimed" then
        previous_color = COLORS.invalid
    else
        previous_color = hatch_outline
    end
    self:draw_slot_track(part, layout, previous_color)

    love.graphics.setFont(self.fonts.small)
    local label_color = (source_highlight or selected_source) and COLORS.selected or COLORS.ink
    draw_text(part.name or part.id, layout.label.x, layout.label.y, layout.label.w, "center", label_color)
end

function V2Combat:draw_empty_card(layout)
    love.graphics.setFont(self.fonts.small)
    if not draw_image("bp_card", layout.card, { 1, 1, 1, 0.32 }) then
        draw_box(layout.card, { 1, 1, 1, 0.18 }, COLORS.dashed, 6)
    end
    draw_text("empty", layout.card.x, layout.card.y + layout.card.h * 0.42, layout.card.w, "center", COLORS.muted)
end

function V2Combat:draw_center()
    love.graphics.setFont(self.fonts.body)
    local center = self:center_rect()
    draw_box(center, { 0.98, 0.98, 0.95, 1 }, COLORS.line, 8)
    draw_text("center stage", center.x, center.y + center.h * 0.42, center.w, "center", COLORS.muted)
    draw_text("reserved for paper dolls + resolution animation", center.x, center.y + center.h * 0.42 + 18, center.w, "center", COLORS.muted)
    draw_text(self.message or "", center.x + 18, center.y + center.h - 30, center.w - 36, "left", COLORS.ink)
end

function V2Combat:draw_pool()
    love.graphics.setFont(self.fonts.body)
    local control = self:control_rect()
    draw_box(control, COLORS.panel, COLORS.selected, 8)
    draw_text("pool:", control.x + 12, control.y + 20, 50, "left", COLORS.ink)

    for die, die_rect in pairs(self.die_rects) do
        if not (self.drag and self.drag.die == die) then
            draw_die_face(die.effective_symbols or die.symbols, die_rect, self.selected_die == die)
        end
    end

    for crest, crest_rect in pairs(self.crest_rects) do
        local count = self.player:get_crest_count(crest)
        draw_box(crest_rect, { 1, 1, 1, 0.8 }, count > 0 and COLORS.essence or COLORS.dashed, 5)
        draw_text(crest .. " " .. tostring(count), crest_rect.x + 3, crest_rect.y + 8, crest_rect.w - 6, "center", count > 0 and COLORS.ink or COLORS.muted)
    end

    local queue_x = control.x + 300
    local queue_w = math.max(100, self.crest_rects.Valor.x - queue_x - 12)
    draw_text("queue · round " .. tostring(self.engine.current_round) .. " · initiative " .. tostring(self.engine.initiative),
        queue_x, control.y + 20, queue_w, "left", COLORS.muted)

    draw_box(self.confirm_rect, { 1, 1, 1, 0.9 }, COLORS.line, 16)
    draw_text("confirm", self.confirm_rect.x + 4, self.confirm_rect.y + 10, self.confirm_rect.w - 8, "center", COLORS.ink)
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

function V2Combat:draw_inspector()
    love.graphics.setFont(self.fonts.body)
    local rail = self:rail_rect()
    draw_box(rail, COLORS.rail, COLORS.line, 8)
    draw_text("Inspector", rail.x + 14, rail.y + 12, rail.w - 28, "left", COLORS.ink)

    local y = rail.y + 42
    local lines = {}

    if self.drag then
        lines = self:drag_preview_lines()
    elseif self.hover then
        if self.hover.kind == "die" then
            local die = self.hover.die
            table.insert(lines, "Die: " .. Symbols.format_face(die.symbols))
            table.insert(lines, "From: " .. (die.source_part and die.source_part.name or "?"))
            table.insert(lines, "Face: " .. tostring(die.face_index))
        elseif self.hover.kind == "part" or self.hover.kind == "socket" or self.hover.kind == "rim" or self.hover.kind == "slot" then
            local part = self.hover.part
            table.insert(lines, format_part_line(part))
            table.insert(lines, "Heart value: " .. tostring(part.hp_value or 0))
            if part.slot then
                table.insert(lines, "Slot: " .. (part.slot.name or part.slot.id))
                table.insert(lines, "Cost: " .. Symbols.format_face(part.slot.cost))
            end
        elseif self.hover.kind == "crest" then
            table.insert(lines, "Crest: " .. self.hover.crest)
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

    if self.selected_die and not self.drag then
        table.insert(lines, "")
        table.insert(lines, "Selected: " .. Symbols.format_face(self.selected_die.symbols))
        table.insert(lines, "Valid destinations glow green.")
    end

    for _, line in ipairs(lines) do
        y = draw_wrapped_text(line, rail.x + 14, y, rail.w - 28, "left", COLORS.ink, 6)
    end

    set_color(COLORS.line)
    love.graphics.line(rail.x + 14, rail.y + rail.h - 176, rail.x + rail.w - 14, rail.y + rail.h - 176)
    draw_text("Log", rail.x + 14, rail.y + rail.h - 160, rail.w - 28, "left", COLORS.ink)

    y = rail.y + rail.h - 136
    for _, line in ipairs(self.log) do
        y = draw_wrapped_text(line, rail.x + 14, y, rail.w - 28, "left", COLORS.muted, 4)
    end
end

function V2Combat:draw()
    love.graphics.clear(COLORS.bg)
    love.graphics.setFont(self.fonts.body)
    self:layout()

    self:draw_strip(self:enemy_strip_rect(), "enemy strip", self.enemy)
    self:draw_strip(self:player_strip_rect(), "player strip", self.player)

    for _, layout in ipairs(self.empty_card_rects or {}) do
        self:draw_empty_card(layout)
    end

    for _, part in ipairs(self.enemy.body_parts or {}) do
        self:draw_part_card(part, self.card_rects[part])
    end

    for _, part in ipairs(self.player.body_parts or {}) do
        self:draw_part_card(part, self.card_rects[part])
    end

    self:draw_center()
    self:draw_pool()
    self:draw_inspector()
    self:draw_drag_ghost()
end

return V2Combat
