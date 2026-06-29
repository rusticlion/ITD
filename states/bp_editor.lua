local GameState = require("core.gamestate")
local Crests = require("combat.crests")
local Content = require("combat.v2_content")
local Effects = require("combat.v2_effects")
local Symbols = require("core.symbols")

local BPEditor = {}
BPEditor.__index = BPEditor

local TYPES = { "HEAD", "BODY", "ARM", "LEG" }
local TIMINGS = { "spend", "on_hit", "on_wound_maim", "upkeep" }
local EFFECT_TYPES = Effects.EDITOR_ORDER
local EFFECT_LABELS = Effects.EDITOR_LABELS
local DESTINATIONS = { "any", "socket", "rim", "slot" }
local ASSIGN_DESTINATIONS = { "socket", "rim" }
local TARGET_SIDES = { "self", "opponent" }
local HEAL_TARGETS = { "most_damaged", "source_part", "part_type" }
local TARGET_STATUSES = { "healthy", "wounded" }
local SPELLMARK_TARGET_TYPES = { "ANY", "HEAD", "BODY", "ARM", "LEG" }
local SYMBOLS = {
    { id = Symbols.STRIKE, label = "ATK" },
    { id = Symbols.WARD, label = "DEF" },
    { id = Symbols.ESSENCE, label = "ESS" },
    { id = Symbols.BLOOD, label = "BLD" },
    { id = Symbols.BLANK, label = "BLANK" }
}
local BODY_PART_NAME_LIMIT = 15
local SLOT_NAME_LIMIT = 9
local LIST_VISIBLE_ROWS = 15
local LIST_ROW_HEIGHT = 25

local COLORS = {
    bg = { 0.93, 0.92, 0.88, 1 },
    panel = { 0.98, 0.98, 0.95, 1 },
    ink = { 0.12, 0.12, 0.12, 1 },
    muted = { 0.42, 0.42, 0.38, 1 },
    line = { 0.68, 0.68, 0.62, 1 },
    selected = { 0.12, 0.32, 0.82, 1 },
    accent = { 0.0, 0.47, 0.36, 1 },
    danger = { 0.68, 0.18, 0.12, 1 }
}

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function point_in_rect(x, y, r)
    return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
end

local function set_color(color)
    love.graphics.setColor(color)
end

local function draw_box(r, fill, outline, radius)
    set_color(fill or COLORS.panel)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, radius or 4, radius or 4)
    set_color(outline or COLORS.line)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, radius or 4, radius or 4)
end

local function clone(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[key] = clone(child)
    end
    return copy
end

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function normalize_face(face)
    local normalized = Symbols.normalize_face(face)
    if #normalized == 0 then
        return { Symbols.BLANK }
    end
    return normalized
end

local function symbol_label(symbol)
    return Symbols.display(symbol)
end

local function face_label(face)
    return Symbols.format_face(face)
end

local function split_csv(value)
    local tags = {}
    for token in tostring(value or ""):gmatch("[^,]+") do
        local tag = trim(token)
        if tag ~= "" then
            table.insert(tags, tag)
        end
    end
    return tags
end

local function sorted_keys(table_value)
    local keys = {}
    for key in pairs(table_value or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function lua_symbol(symbol)
    local normalized = Symbols.normalize(symbol)
    if normalized == Symbols.STRIKE then
        return "Symbols.STRIKE"
    elseif normalized == Symbols.WARD then
        return "Symbols.WARD"
    elseif normalized == Symbols.ESSENCE then
        return "Symbols.ESSENCE"
    elseif normalized == Symbols.BLOOD then
        return "Symbols.BLOOD"
    end
    return "Symbols.BLANK"
end

local function lua_string(value)
    return string.format("%q", tostring(value or ""))
end

local function lua_face(face)
    local normalized = normalize_face(face)
    if #normalized == 1 then
        return lua_symbol(normalized[1])
    end

    local parts = {}
    for _, symbol in ipairs(normalized) do
        table.insert(parts, lua_symbol(symbol))
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function lua_symbol_list(list)
    local parts = {}
    for _, symbol in ipairs(list or {}) do
        table.insert(parts, lua_symbol(symbol))
    end
    return "{ " .. table.concat(parts, ", ") .. " }"
end

local function is_sequence_effect(effect)
    return type(effect) == "table" and (type(effect.actions) == "table" or type(effect.sequence) == "table")
end

local function wrap_text(text, limit)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local current = ""
    for _, word in ipairs(words) do
        local candidate = current == "" and word or (current .. " " .. word)
        if #candidate > limit and current ~= "" then
            table.insert(lines, current)
            current = word
        else
            current = candidate
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end
    if #lines == 0 then
        table.insert(lines, "")
    end
    return lines
end

local function safe_require(module_name)
    local ok, result = pcall(require, module_name)
    if ok then
        return result
    end
    return nil, result
end

function BPEditor:enter()
    self.fonts = {
        title = love.graphics.newFont(16),
        body = love.graphics.newFont(12),
        small = love.graphics.newFont(10)
    }

    self.parts = {}
    self.part_order = {}
    self.source_slots = {}
    self.search = ""
    self.list_scroll = 0
    self.list_rect = nil
    self.active_field = nil
    self.selected_face = 1
    self.message = "Select a Body Part, edit fields, then copy Lua or note text."
    self.buttons = {}
    self.fields = {}
    self.face_rects = {}

    self:load_database()
    if #self.part_order > 0 then
        self:load_part(self.part_order[1])
    else
        self:new_part()
    end
end

function BPEditor:load_database()
    local modules = {}
    local ok, files = pcall(love.filesystem.getDirectoryItems, "data/combat")
    if ok then
        for _, file in ipairs(files) do
            if file:match("%.lua$") then
                table.insert(modules, "data.combat." .. file:gsub("%.lua$", ""))
            end
        end
    else
        modules = { "data.combat.v2_demo_parts" }
    end

    table.sort(modules)
    for _, module_name in ipairs(modules) do
        local definitions = safe_require(module_name)
        if definitions and type(definitions.parts) == "table" then
            for slot_id, slot in pairs(definitions.slots or {}) do
                self.source_slots[module_name .. ":" .. slot_id] = clone(slot)
            end

            for part_id, part in pairs(definitions.parts or {}) do
                local key = module_name .. ":" .. part_id
                self.parts[key] = {
                    source = module_name,
                    part_id = part_id,
                    part = clone(part),
                    slots = definitions.slots or {}
                }
                table.insert(self.part_order, key)
            end
        end
    end

    table.sort(self.part_order, function(a, b)
        local left = self.parts[a]
        local right = self.parts[b]
        local left_name = left and left.part and left.part.name or a
        local right_name = right and right.part and right.part.name or b
        return left_name < right_name
    end)
end

function BPEditor:blank_part()
    return {
        id = "new_part",
        name = "New Body Part",
        flavor = "",
        type = "ARM",
        hp_value = 1,
        die = {
            faces = {
                Symbols.BLANK,
                Symbols.WARD,
                Symbols.STRIKE,
                Symbols.ESSENCE,
                Symbols.WARD,
                Symbols.STRIKE
            },
            wound_faces = { 1, 2 },
            maim_faces = { 3, 4 }
        },
        tags = {},
        slot = nil
    }
end

function BPEditor:new_part()
    self.current_key = nil
    self.current_source = "new"
    self.current = self:part_to_form(self:blank_part(), {})
    self.selected_face = 1
    self.active_field = "id"
    self.message = "Started a new Body Part."
end

function BPEditor:load_part(key)
    local entry = self.parts[key]
    if not entry then
        return
    end

    self.current_key = key
    self.current_source = entry.source
    self.current = self:part_to_form(entry.part, entry.slots)
    self.selected_face = 1
    self.active_field = nil
    self.message = "Loaded " .. (self.current.name or self.current.id) .. "."
end

function BPEditor:part_to_form(part, slots)
    local slot = nil
    if type(part.slot) == "string" then
        slot = clone(slots and slots[part.slot])
        if slot then
            slot.id = slot.id or part.slot
        end
    elseif type(part.slot) == "table" then
        slot = clone(part.slot)
    end

    local effect = slot and slot.effect or {}
    local effect_type = Effects.editor_type(effect)
    if is_sequence_effect(effect) then
        effect_type = "custom_sequence"
    elseif not Effects.is_known(effect) then
        effect_type = "custom_effect"
    end

    local payload = effect.on_mark or effect.payload or effect.effect or {}
    local default_symbol = effect_type == "open_spellmark" and Symbols.ESSENCE or Symbols.STRIKE
    local effect_destination = effect.destination or (effect_type == "open_spellmark" and "rim" or "any")
    local target_side = effect.target or effect.target_side
    if not target_side and effect_type == "open_spellmark" then
        target_side = effect_destination == "rim" and "opponent" or "self"
    end

    return {
        id = part.id or "",
        name = part.name or "",
        flavor = part.flavor or "",
        type = part.type or "ARM",
        hp_value = tostring(part.hp_value or 1),
        tags = table.concat(part.tags or {}, ", "),
        faces = {
            normalize_face(part.die and part.die.faces and part.die.faces[1]),
            normalize_face(part.die and part.die.faces and part.die.faces[2]),
            normalize_face(part.die and part.die.faces and part.die.faces[3]),
            normalize_face(part.die and part.die.faces and part.die.faces[4]),
            normalize_face(part.die and part.die.faces and part.die.faces[5]),
            normalize_face(part.die and part.die.faces and part.die.faces[6])
        },
        has_slot = slot ~= nil,
        slot_id = slot and (slot.id or "") or "",
        slot_name = slot and (slot.name or "") or "",
        slot_cost = clone(slot and slot.cost or {}),
        slot_dynamic_cost = clone(slot and slot.dynamic_cost),
        slot_timing = slot and (slot.timing or "spend") or "spend",
        effect_type = effect_type,
        raw_effect = clone(effect),
        effect_symbol = effect.symbol or effect.accept_symbol or default_symbol,
        effect_match_symbol = effect.match or effect.match_symbol or effect.source_symbol or Symbols.ESSENCE,
        effect_destination = effect_destination,
        effect_assign_destination = effect.destination or (effect_type == "open_spellmark" and "rim" or "socket"),
        effect_target_side = target_side or "self",
        effect_heal_target = effect.target or "most_damaged",
        effect_target_status = effect.target_status or "wounded",
        effect_crest = effect.crest or "Valor",
        effect_target_type = effect_type == "open_spellmark" and (effect.target_type or effect.part_type or "ANY")
            or (effect.target_type or "HEAD"),
        effect_amount = tostring(effect.amount or payload.amount or 1)
    }
end

function BPEditor:filtered_parts()
    local query = self.search:lower()
    local filtered = {}
    for _, key in ipairs(self.part_order) do
        local entry = self.parts[key]
        local part = entry and entry.part or {}
        local slot = type(part.slot) == "string" and entry and entry.slots and entry.slots[part.slot] or part.slot
        local haystack = table.concat({
            part.id or "",
            part.name or "",
            part.type or "",
            part.flavor or "",
            table.concat(part.tags or {}, " "),
            table.concat(part.keywords or {}, " "),
            slot and slot.id or "",
            slot and slot.name or "",
            slot and Effects.describe(slot.effect) or "",
            entry and entry.source or "",
            entry and (tostring(entry.source or ""):match("([^%.]+)$") or "") or ""
        }, " "):lower()
        if query == "" or haystack:find(query, 1, true) then
            table.insert(filtered, key)
        end
    end
    return filtered
end

function BPEditor:clamp_list_scroll(filtered_count)
    local max_scroll = math.max(0, (filtered_count or 0) - LIST_VISIBLE_ROWS)
    self.list_scroll = clamp(self.list_scroll or 0, 0, max_scroll)
end

function BPEditor:register_button(id, label, r, on_click, selected)
    self.buttons[id] = {
        label = label,
        rect = r,
        on_click = on_click,
        selected = selected
    }
end

function BPEditor:register_field(key, r)
    self.fields[key] = r
end

function BPEditor:draw_button(id)
    local button = self.buttons[id]
    if not button then
        return
    end

    local fill = button.selected and { 0.88, 0.93, 1, 1 } or { 1, 1, 1, 0.9 }
    local line = button.selected and COLORS.selected or COLORS.line
    draw_box(button.rect, fill, line, 4)
    set_color(button.selected and COLORS.selected or COLORS.ink)
    love.graphics.setFont(self.fonts.small)
    love.graphics.printf(button.label, button.rect.x + 4, button.rect.y + 5, button.rect.w - 8, "center")
end

function BPEditor:draw_field(label, key, r)
    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print(label, r.x, r.y - 13)
    draw_box(r, { 1, 1, 1, 0.92 }, self.active_field == key and COLORS.selected or COLORS.line, 3)
    set_color(COLORS.ink)
    local value = tostring(self.current[key] or "")
    love.graphics.printf(value, r.x + 5, r.y + 5, r.w - 10, "left")
    self:register_field(key, r)
end

function BPEditor:draw_name_warning(key, label, limit, x, y, width)
    local value = trim(self.current[key])
    if #value <= limit then
        return
    end

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.danger)
    love.graphics.printf(string.format("%s max %d chars (%d)", label, limit, #value), x, y, width, "left")
end

function BPEditor:draw_wrapped_field(label, key, r)
    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print(label, r.x, r.y - 13)
    draw_box(r, { 1, 1, 1, 0.92 }, self.active_field == key and COLORS.selected or COLORS.line, 3)
    set_color(COLORS.ink)
    local y = r.y + 5
    for _, line in ipairs(wrap_text(self.current[key] or "", 52)) do
        love.graphics.print(line, r.x + 5, y)
        y = y + 12
        if y > r.y + r.h - 10 then
            break
        end
    end
    self:register_field(key, r)
end

function BPEditor:draw_database_panel()
    local panel = rect(10, 10, 238, 520)
    draw_box(panel, COLORS.panel, COLORS.line, 5)
    love.graphics.setFont(self.fonts.title)
    set_color(COLORS.ink)
    love.graphics.print("Body Parts", 22, 20)

    self.current.search = self.search
    self:draw_field("Search", "search", rect(22, 58, 214, 26))

    local y = 98
    local filtered = self:filtered_parts()
    self:clamp_list_scroll(#filtered)
    self.list_rect = rect(22, 98, 214, LIST_VISIBLE_ROWS * LIST_ROW_HEIGHT - 3)

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.printf(tostring(#filtered) .. " / " .. tostring(#self.part_order), 162, 86, 74, "right")

    for row = 1, LIST_VISIBLE_ROWS do
        local key = filtered[(self.list_scroll or 0) + row]
        if not key then
            break
        end
        local entry = self.parts[key]
        local part = entry.part
        local item = rect(22, y, 204, 22)
        local selected = key == self.current_key
        local source_label = tostring(entry.source or ""):match("([^%.]+)$") or ""
        draw_box(item, selected and { 0.88, 0.93, 1, 1 } or { 1, 1, 1, 0.55 }, selected and COLORS.selected or COLORS.line, 3)
        set_color(selected and COLORS.selected or COLORS.ink)
        love.graphics.printf((part.name or part.id or "?") .. " [" .. tostring(part.type or "?") .. "]",
            item.x + 5, item.y + 4, item.w - 68, "left")
        set_color(selected and COLORS.selected or COLORS.muted)
        love.graphics.printf(source_label, item.x + item.w - 64, item.y + 4, 58, "right")
        self:register_button("part_" .. key, "", item, function()
            self:load_part(key)
        end, selected)
        y = y + LIST_ROW_HEIGHT
    end

    if #filtered > LIST_VISIBLE_ROWS then
        local track = rect(230, self.list_rect.y, 6, self.list_rect.h)
        local max_scroll = math.max(1, #filtered - LIST_VISIBLE_ROWS)
        local thumb_h = math.max(24, track.h * (LIST_VISIBLE_ROWS / #filtered))
        local thumb_y = track.y + (track.h - thumb_h) * ((self.list_scroll or 0) / max_scroll)
        draw_box(track, { 1, 1, 1, 0.42 }, COLORS.line, 3)
        draw_box(rect(track.x, thumb_y, track.w, thumb_h), { 0.88, 0.93, 1, 1 }, COLORS.selected, 3)
    end

    self:register_button("new_part", "New", rect(22, 493, 66, 26), function()
        self:new_part()
    end)
    self:register_button("copy_lua", "Copy Lua", rect(96, 493, 66, 26), function()
        self:copy_lua()
    end)
    self:register_button("copy_note", "Copy Note", rect(170, 493, 66, 26), function()
        self:copy_note()
    end)
    self:draw_button("new_part")
    self:draw_button("copy_lua")
    self:draw_button("copy_note")
end

function BPEditor:draw_form_panel()
    local panel = rect(258, 10, 360, 520)
    draw_box(panel, COLORS.panel, COLORS.line, 5)
    love.graphics.setFont(self.fonts.title)
    set_color(COLORS.ink)
    love.graphics.print("Editor", 270, 20)

    self:draw_field("ID", "id", rect(270, 58, 158, 26))
    self:draw_field("Name", "name", rect(440, 58, 166, 26))
    self:draw_name_warning("name", "BP name", BODY_PART_NAME_LIMIT, 440, 86, 166)
    self:draw_wrapped_field("Flavor", "flavor", rect(270, 108, 336, 58))

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Type", 270, 186)
    local x = 270
    for _, part_type in ipairs(TYPES) do
        local button_id = "type_" .. part_type
        self:register_button(button_id, part_type, rect(x, 200, 50, 24), function()
            self.current.type = part_type
        end, self.current.type == part_type)
        self:draw_button(button_id)
        x = x + 56
    end

    self:draw_field("Heart", "hp_value", rect(504, 200, 48, 24))
    self:draw_field("Tags", "tags", rect(270, 252, 336, 26))

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Faces: click a face, then click symbols", 270, 310)

    local labels = {
        { "Wound", COLORS.danger },
        { "Maim", { 0.74, 0.52, 0.1, 1 } },
        { "Durable", COLORS.accent }
    }
    local face_index = 1
    for group = 1, 3 do
        set_color(labels[group][2])
        love.graphics.print(labels[group][1], 270 + (group - 1) * 112, 328)
        for row = 1, 2 do
            local r = rect(270 + (group - 1) * 112, 344 + (row - 1) * 42, 94, 34)
            local selected = self.selected_face == face_index
            draw_box(r, selected and { 0.88, 0.93, 1, 1 } or { 1, 1, 1, 0.78 }, selected and COLORS.selected or COLORS.line, 4)
            set_color(selected and COLORS.selected or COLORS.ink)
            love.graphics.printf(face_label(self.current.faces[face_index]), r.x + 5, r.y + 11, r.w - 10, "center")
            self.face_rects[face_index] = r
            face_index = face_index + 1
        end
    end

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Symbol palette", 270, 444)
    x = 270
    for _, symbol in ipairs(SYMBOLS) do
        local button_id = "face_symbol_" .. symbol.id
        self:register_button(button_id, symbol.label, rect(x, 460, 58, 26), function()
            self:add_symbol_to_face(symbol.id)
        end)
        self:draw_button(button_id)
        x = x + 66
    end

    self:register_button("face_pop", "Pop", rect(270, 494, 58, 26), function()
        self:pop_face_symbol()
    end)
    self:draw_button("face_pop")
end

function BPEditor:draw_slot_panel()
    local panel = rect(628, 10, 322, 520)
    draw_box(panel, COLORS.panel, COLORS.line, 5)
    love.graphics.setFont(self.fonts.title)
    set_color(COLORS.ink)
    love.graphics.print("Slot", 640, 20)

    self:register_button("slot_toggle", self.current.has_slot and "Slot On" or "Slot Off", rect(640, 54, 82, 26), function()
        self.current.has_slot = not self.current.has_slot
        if self.current.has_slot and self.current.slot_name == "" then
            self.current.slot_id = self.current.id .. "_slot"
            self.current.slot_name = "New Slot"
            self.current.slot_cost = { Symbols.ESSENCE }
            self.current.effect_type = "add_next_symbol"
            self.current.effect_symbol = Symbols.STRIKE
        end
    end, self.current.has_slot)
    self:draw_button("slot_toggle")

    if not self.current.has_slot then
        love.graphics.setFont(self.fonts.body)
        set_color(COLORS.muted)
        love.graphics.printf("No slot on this part.", 640, 102, 286, "left")
        self:draw_output_help(640, 430)
        return
    end

    self:draw_field("Slot ID", "slot_id", rect(640, 102, 132, 26))
    self:draw_field("Slot Name", "slot_name", rect(786, 102, 140, 26))
    self:draw_name_warning("slot_name", "Slot", SLOT_NAME_LIMIT, 786, 130, 140)

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Timing", 640, 152)
    local x = 640
    for index, timing in ipairs(TIMINGS) do
        local w = index == 3 and 92 or 58
        local button_id = "timing_" .. timing
        self:register_button(button_id, timing, rect(x, 166, w, 24), function()
            self.current.slot_timing = timing
        end, self.current.slot_timing == timing)
        self:draw_button(button_id)
        x = x + w + 6
    end

    set_color(COLORS.muted)
    love.graphics.print("Cost", 640, 214)
    x = 640
    for _, symbol in ipairs(self.current.slot_cost or {}) do
        draw_box(rect(x, 230, 38, 24), { 1, 1, 1, 0.85 }, COLORS.line, 3)
        set_color(COLORS.ink)
        love.graphics.printf(symbol_label(symbol), x + 2, 236, 34, "center")
        x = x + 42
    end

    x = 640
    for _, symbol in ipairs(SYMBOLS) do
        if symbol.id ~= Symbols.BLANK then
            local button_id = "cost_symbol_" .. symbol.id
            self:register_button(button_id, "+" .. symbol.label, rect(x, 264, 52, 24), function()
                table.insert(self.current.slot_cost, symbol.id)
            end)
            self:draw_button(button_id)
            x = x + 58
        end
    end
    self:register_button("cost_clear", "Clear", rect(640, 294, 58, 24), function()
        self.current.slot_cost = {}
    end)
    self:draw_button("cost_clear")

    self:register_button("cost_fixed", "fixed", rect(704, 294, 50, 24), function()
        self.current.slot_dynamic_cost = nil
    end, self.current.slot_dynamic_cost == nil)
    self:register_button("cost_damaged", "foe dmg", rect(760, 294, 64, 24), function()
        self.current.slot_dynamic_cost = self.current.slot_dynamic_cost or {
            type = "opponent_damaged_parts",
            minimum = 1,
            per_part = 1
        }
    end, self.current.slot_dynamic_cost ~= nil)
    self:draw_button("cost_fixed")
    self:draw_button("cost_damaged")

    if self.current.slot_dynamic_cost then
        local dynamic = self.current.slot_dynamic_cost
        set_color(COLORS.muted)
        love.graphics.print(string.format(
            "Cost -%d per damaged opposing BP (min %d).",
            tonumber(dynamic.per_part) or 1,
            tonumber(dynamic.minimum) or 1), 640, 322)
    end

    set_color(COLORS.muted)
    love.graphics.print("Effect Template", 640, 340)
    x = 640
    local y = 356
    for index, effect_type in ipairs(EFFECT_TYPES) do
        local button_id = "effect_" .. effect_type
        local label = EFFECT_LABELS[effect_type] or effect_type
        local w = effect_type == "none" and 42
            or effect_type == "add_next_symbol" and 42
            or effect_type == "channel_symbol" and 54
            or effect_type == "assign_symbol_to_each_part" and 70
            or effect_type == "open_spellmark" and 58
            or effect_type == "heal_part" and 42
            or effect_type == "add_symbol_against_status" and 50
            or effect_type == "damage_opponent_part" and 64
            or 42
        if x + w > 930 then
            x = 640
            y = y + 30
        end
        self:register_button(button_id, label, rect(x, y, w, 24), function()
            self.current.effect_type = effect_type
            if effect_type == "open_spellmark" then
                self.current.effect_assign_destination = "rim"
                self.current.effect_target_side = "opponent"
                self.current.effect_symbol = Symbols.ESSENCE
                self.current.effect_target_type = "ANY"
            elseif effect_type == "assign_symbol_to_each_part" then
                self.current.effect_assign_destination = "socket"
                self.current.effect_target_side = "self"
                self.current.effect_symbol = Symbols.WARD
            elseif effect_type == "gain_crest" then
                self.current.effect_crest = Crests.ORDER[1] or "Valor"
            end
        end, self.current.effect_type == effect_type)
        self:draw_button(button_id)
        x = x + w + 6
    end

    self:draw_effect_details(640, 416)
end

function BPEditor:draw_effect_details(x, y)
    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    local effect_type = self.current.effect_type
    local text = "No effect."
    if effect_type == "add_next_symbol" then
        local amount = tonumber(self.current.effect_amount) or 1
        text = "Adds " .. tostring(amount) .. " " .. symbol_label(self.current.effect_symbol)
            .. (amount == 1 and "" or " symbols") .. " to the next die assigned."
        local bx = x
        for _, symbol in ipairs(SYMBOLS) do
            if symbol.id ~= Symbols.BLANK then
                local button_id = "effect_symbol_" .. symbol.id
                self:register_button(button_id, symbol.label, rect(bx, y + 28, 52, 22), function()
                    self.current.effect_symbol = symbol.id
                end, self.current.effect_symbol == symbol.id)
                self:draw_button(button_id)
                bx = bx + 58
            end
        end
        self:draw_field("Amount", "effect_amount", rect(x, y + 56, 66, 24))
    elseif effect_type == "channel_symbol" then
        text = "For this allocation, dice showing " .. symbol_label(self.current.effect_match_symbol)
            .. " gain " .. symbol_label(self.current.effect_symbol) .. "."
        local bx = x
        for _, symbol in ipairs(SYMBOLS) do
            if symbol.id ~= Symbols.BLANK then
                local button_id = "effect_match_symbol_" .. symbol.id
                self:register_button(button_id, symbol.label, rect(bx, y + 28, 52, 22), function()
                    self.current.effect_match_symbol = symbol.id
                end, self.current.effect_match_symbol == symbol.id)
                self:draw_button(button_id)
                bx = bx + 58
            end
        end

        bx = x
        for _, symbol in ipairs(SYMBOLS) do
            if symbol.id ~= Symbols.BLANK then
                local button_id = "effect_channel_symbol_" .. symbol.id
                self:register_button(button_id, "+" .. symbol.label, rect(bx, y + 54, 52, 22), function()
                    self.current.effect_symbol = symbol.id
                end, self.current.effect_symbol == symbol.id)
                self:draw_button(button_id)
                bx = bx + 58
            end
        end

        bx = x
        for _, destination in ipairs(DESTINATIONS) do
            local button_id = "effect_channel_destination_" .. destination
            self:register_button(button_id, destination, rect(bx, y + 80, 46, 22), function()
                self.current.effect_destination = destination
            end, (self.current.effect_destination or "any") == destination)
            self:draw_button(button_id)
            bx = bx + 50
        end
        self:draw_field("Amt", "effect_amount", rect(x + 214, y + 80, 54, 22))
    elseif effect_type == "assign_symbol_to_each_part" then
        text = "Auto-assigns " .. symbol_label(self.current.effect_symbol) .. " to matching open destinations."
        local bx = x
        for _, destination in ipairs(ASSIGN_DESTINATIONS) do
            local button_id = "effect_assign_destination_" .. destination
            self:register_button(button_id, destination, rect(bx, y + 28, 56, 22), function()
                self.current.effect_assign_destination = destination
                if destination == "socket" then
                    self.current.effect_symbol = Symbols.WARD
                    self.current.effect_target_side = "self"
                elseif destination == "rim" then
                    self.current.effect_symbol = Symbols.STRIKE
                    self.current.effect_target_side = "opponent"
                end
            end, (self.current.effect_assign_destination or "socket") == destination)
            self:draw_button(button_id)
            bx = bx + 62
        end

        bx = x + 138
        for _, target_side in ipairs(TARGET_SIDES) do
            local button_id = "effect_assign_target_" .. target_side
            self:register_button(button_id, target_side, rect(bx, y + 28, 64, 22), function()
                self.current.effect_target_side = target_side
            end, (self.current.effect_target_side or "self") == target_side)
            self:draw_button(button_id)
            bx = bx + 70
        end

        bx = x
        for _, symbol in ipairs(SYMBOLS) do
            if symbol.id ~= Symbols.BLANK then
                local button_id = "effect_assign_symbol_" .. symbol.id
                self:register_button(button_id, symbol.label, rect(bx, y + 54, 52, 22), function()
                    self.current.effect_symbol = symbol.id
                end, self.current.effect_symbol == symbol.id)
                self:draw_button(button_id)
                bx = bx + 58
            end
        end
        self:draw_field("Amt", "effect_amount", rect(x, y + 82, 54, 22))
    elseif effect_type == "open_spellmark" then
        text = "Essence can mark an existing destination; the mark payload resolves on assignment."
        local bx = x
        for _, destination in ipairs(ASSIGN_DESTINATIONS) do
            local button_id = "effect_spellmark_destination_" .. destination
            self:register_button(button_id, destination, rect(bx, y + 28, 56, 22), function()
                self.current.effect_assign_destination = destination
                self.current.effect_target_side = destination == "rim" and "opponent" or "self"
                self.current.effect_symbol = Symbols.ESSENCE
            end, (self.current.effect_assign_destination or "rim") == destination)
            self:draw_button(button_id)
            bx = bx + 62
        end

        draw_box(rect(x + 138, y + 28, 76, 22), { 1, 1, 1, 0.72 }, COLORS.line, 3)
        set_color(COLORS.muted)
        love.graphics.printf("accept ESS", x + 142, y + 33, 68, "center")

        bx = x
        for _, part_type in ipairs(SPELLMARK_TARGET_TYPES) do
            local button_id = "effect_spellmark_target_type_" .. part_type
            self:register_button(button_id, part_type, rect(bx, y + 56, 50, 22), function()
                self.current.effect_target_type = part_type
            end, self.current.effect_target_type == part_type)
            self:draw_button(button_id)
            bx = bx + 56
        end
        self:draw_field("Dmg", "effect_amount", rect(x, y + 84, 54, 22))
    elseif effect_type == "custom_sequence" then
        local actions = (self.current.raw_effect and (self.current.raw_effect.actions or self.current.raw_effect.sequence)) or {}
        text = "Sequence effect preserved from source (" .. tostring(#actions) .. " actions). Edit in Lua for now."
    elseif effect_type == "custom_effect" then
        text = "Custom effect preserved from source. Edit in Lua for now."
    elseif effect_type == "heal_part" then
        text = self.current.effect_heal_target == "source_part"
                and "Heals the Body Part carrying this Slot."
            or self.current.effect_heal_target == "part_type"
                and ("Heals the allied " .. tostring(self.current.effect_target_type or "HEAD") .. ".")
            or "Heals this combatant's most damaged Body Part."
        local bx = x
        for _, target in ipairs(HEAL_TARGETS) do
            local button_id = "effect_heal_target_" .. target
            local label = target == "source_part" and "this BP"
                or target == "part_type" and "BP type"
                or "most hurt"
            self:register_button(button_id, label, rect(bx, y + 28, 70, 24), function()
                self.current.effect_heal_target = target
            end, (self.current.effect_heal_target or "most_damaged") == target)
            self:draw_button(button_id)
            bx = bx + 76
        end
        if self.current.effect_heal_target == "part_type" then
            bx = x
            for _, part_type in ipairs(TYPES) do
                local button_id = "effect_heal_type_" .. part_type
                self:register_button(button_id, part_type, rect(bx, y + 58, 50, 22), function()
                    self.current.effect_target_type = part_type
                end, self.current.effect_target_type == part_type)
                self:draw_button(button_id)
                bx = bx + 56
            end
        end
        self:draw_field("Amt", "effect_amount", rect(x + 232, y + 28, 54, 24))
    elseif effect_type == "add_symbol_against_status" then
        text = "Matching dice gain a symbol against Body Parts in the chosen state."
        local bx = x
        for _, symbol in ipairs(SYMBOLS) do
            if symbol.id ~= Symbols.BLANK then
                local button_id = "effect_status_match_" .. symbol.id
                self:register_button(button_id, symbol.label, rect(bx, y + 28, 52, 22), function()
                    self.current.effect_match_symbol = symbol.id
                end, self.current.effect_match_symbol == symbol.id)
                self:draw_button(button_id)
                bx = bx + 58
            end
        end

        bx = x
        for _, symbol in ipairs(SYMBOLS) do
            if symbol.id ~= Symbols.BLANK then
                local button_id = "effect_status_add_" .. symbol.id
                self:register_button(button_id, "+" .. symbol.label, rect(bx, y + 54, 52, 22), function()
                    self.current.effect_symbol = symbol.id
                end, self.current.effect_symbol == symbol.id)
                self:draw_button(button_id)
                bx = bx + 58
            end
        end

        bx = x
        for _, status in ipairs(TARGET_STATUSES) do
            local button_id = "effect_target_status_" .. status
            self:register_button(button_id, status, rect(bx, y + 80, 64, 22), function()
                self.current.effect_target_status = status
            end, self.current.effect_target_status == status)
            self:draw_button(button_id)
            bx = bx + 70
        end
        self:draw_field("Amt", "effect_amount", rect(x + 224, y + 80, 54, 22))
    elseif effect_type == "damage_opponent_part" then
        text = "Damages opponent " .. tostring(self.current.effect_target_type or "HEAD") .. " one step."
        local bx = x
        for _, part_type in ipairs(TYPES) do
            local button_id = "effect_target_" .. part_type
            self:register_button(button_id, part_type, rect(bx, y + 28, 50, 22), function()
                self.current.effect_target_type = part_type
            end, self.current.effect_target_type == part_type)
            self:draw_button(button_id)
            bx = bx + 56
        end
        self:draw_field("Amount", "effect_amount", rect(x, y + 62, 66, 24))
    elseif effect_type == "gain_crest" then
        text = "Gains 1 " .. tostring(self.current.effect_crest or "Valor") .. " crest."
        local bx = x
        for _, crest in ipairs(Crests.ORDER) do
            local button_id = "effect_crest_" .. crest
            self:register_button(button_id, crest, rect(bx, y + 28, 72, 24), function()
                self.current.effect_crest = crest
            end, (self.current.effect_crest or "Valor") == crest)
            self:draw_button(button_id)
            bx = bx + 78
        end
        self:draw_field("Amount", "effect_amount", rect(x + 170, y + 28, 66, 24))
    end
    for _, line in ipairs(wrap_text(text, 40)) do
        love.graphics.print(line, x, y)
        y = y + 12
    end
end

function BPEditor:draw_output_help(x, y)
    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Copy buttons export the current form.", x, y)
end

function BPEditor:draw()
    love.graphics.clear(COLORS.bg)
    self.buttons = {}
    self.fields = {}
    self.face_rects = {}

    self:draw_database_panel()
    self:draw_form_panel()
    self:draw_slot_panel()

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.printf(self.message or "", 258, 532, 692, "left")
end

function BPEditor:add_symbol_to_face(symbol)
    local face = self.current.faces[self.selected_face] or { Symbols.BLANK }
    if symbol == Symbols.BLANK then
        self.current.faces[self.selected_face] = { Symbols.BLANK }
        return
    end

    if #face == 1 and face[1] == Symbols.BLANK then
        face = {}
    end

    if #face < 3 then
        table.insert(face, symbol)
    else
        self.message = "Faces are capped at three symbols in this editor."
    end
    self.current.faces[self.selected_face] = face
end

function BPEditor:pop_face_symbol()
    local face = self.current.faces[self.selected_face] or { Symbols.BLANK }
    if #face > 0 then
        table.remove(face)
    end
    if #face == 0 then
        face = { Symbols.BLANK }
    end
    self.current.faces[self.selected_face] = face
end

function BPEditor:build_slot()
    if not self.current.has_slot then
        return nil
    end

    local effect_type = self.current.effect_type or "none"
    local effect = { type = effect_type }
    if effect_type == "add_next_symbol" then
        effect.symbol = self.current.effect_symbol or Symbols.STRIKE
        effect.amount = tonumber(self.current.effect_amount) or 1
    elseif effect_type == "channel_symbol" then
        effect = {
            type = "add_symbol_to_matching_dice",
            match = self.current.effect_match_symbol or Symbols.ESSENCE,
            symbol = self.current.effect_symbol or Symbols.STRIKE,
            amount = tonumber(self.current.effect_amount) or 1,
            duration = "allocation"
        }
        if self.current.effect_destination and self.current.effect_destination ~= "any" then
            effect.destination = self.current.effect_destination
        end
    elseif effect_type == "assign_symbol_to_each_part" then
        local destination = self.current.effect_assign_destination or "socket"
        effect = {
            type = "assign_symbol_to_each_part",
            destination = destination,
            target = self.current.effect_target_side or (destination == "rim" and "opponent" or "self"),
            symbol = self.current.effect_symbol or (destination == "rim" and Symbols.STRIKE or Symbols.WARD),
            amount = tonumber(self.current.effect_amount) or 1
        }
    elseif effect_type == "open_spellmark" then
        local destination = self.current.effect_assign_destination or "rim"
        effect = {
            type = "open_spellmark",
            destination = destination,
            target = destination == "rim" and "opponent" or "self",
            symbol = Symbols.ESSENCE,
            on_mark = {
                type = "damage_marked_part",
                amount = tonumber(self.current.effect_amount) or 1
            }
        }
        if self.current.effect_target_type and self.current.effect_target_type ~= "ANY" then
            effect.target_type = self.current.effect_target_type
        end
    elseif effect_type == "custom_sequence" or effect_type == "custom_effect" then
        effect = clone(self.current.raw_effect or { type = "none" })
    elseif effect_type == "heal_part" then
        effect.target = self.current.effect_heal_target or "most_damaged"
        if effect.target == "part_type" then
            effect.target_type = self.current.effect_target_type or "HEAD"
        end
        effect.amount = tonumber(self.current.effect_amount) or 1
    elseif effect_type == "add_symbol_against_status" then
        effect = {
            type = "add_symbol_against_status",
            match = self.current.effect_match_symbol or Symbols.STRIKE,
            symbol = self.current.effect_symbol or Symbols.STRIKE,
            amount = tonumber(self.current.effect_amount) or 1,
            destination = "rim",
            target_status = self.current.effect_target_status or "wounded",
            duration = "round"
        }
    elseif effect_type == "damage_opponent_part" then
        effect.target_type = self.current.effect_target_type or "HEAD"
        effect.amount = tonumber(self.current.effect_amount) or 1
    elseif effect_type == "gain_crest" then
        effect.crest = self.current.effect_crest or "Valor"
        effect.amount = tonumber(self.current.effect_amount) or 1
    else
        effect = { type = "none" }
    end

    local slot = {
        id = trim(self.current.slot_id),
        name = trim(self.current.slot_name),
        cost = clone(self.current.slot_cost or {}),
        timing = self.current.slot_timing or "spend",
        effect = effect
    }
    if self.current.slot_dynamic_cost then
        slot.dynamic_cost = clone(self.current.slot_dynamic_cost)
    end
    return slot
end

function BPEditor:form_to_part()
    return {
        id = trim(self.current.id),
        name = trim(self.current.name),
        flavor = trim(self.current.flavor),
        type = self.current.type or "ARM",
        hp_value = tonumber(self.current.hp_value) or 1,
        die = {
            faces = clone(self.current.faces),
            wound_faces = { 1, 2 },
            maim_faces = { 3, 4 }
        },
        tags = split_csv(self.current.tags),
        slot = self:build_slot()
    }
end

function BPEditor:validate_current_part()
    local part = self:form_to_part()
    local errors = {}

    if part.id == "" then
        table.insert(errors, "Body Part ID is required")
    end
    if part.name == "" then
        table.insert(errors, "Body Part name is required")
    end
    if part.slot and part.slot.name == "" then
        table.insert(errors, "Slot name is required")
    end

    if part.id ~= "" then
        local definitions = {
            parts = {
                [part.id] = part
            },
            loadouts = {
                preview = {
                    parts = { part.id }
                }
            }
        }

        for _, message in ipairs(Content.validate(definitions)) do
            table.insert(errors, message)
        end
    end

    return errors
end

function BPEditor:lua_effect(effect)
    if not effect or effect.type == "none" then
        return "{ type = \"none\" }"
    elseif is_sequence_effect(effect) then
        local rendered = {}
        for _, action in ipairs(effect.actions or effect.sequence or {}) do
            table.insert(rendered, self:lua_effect(action))
        end
        return "{ actions = { " .. table.concat(rendered, ", ") .. " } }"
    elseif effect.type == "add_next_symbol" then
        return "{ type = \"add_next_symbol\", symbol = " .. lua_symbol(effect.symbol) .. ", amount = " .. tostring(effect.amount or 1) .. " }"
    elseif effect.type == "add_symbol_to_matching_dice" or effect.type == "channel_symbol" then
        local pieces = {
            "type = \"add_symbol_to_matching_dice\"",
            "match = " .. lua_symbol(effect.match or effect.match_symbol or effect.source_symbol or Symbols.ESSENCE),
            "symbol = " .. lua_symbol(effect.symbol or effect.add_symbol or Symbols.STRIKE),
            "amount = " .. tostring(effect.amount or 1),
            "duration = " .. lua_string(effect.duration or "allocation")
        }
        if effect.destination and effect.destination ~= "any" then
            table.insert(pieces, "destination = " .. lua_string(effect.destination))
        end
        return "{ " .. table.concat(pieces, ", ") .. " }"
    elseif effect.type == "assign_symbol_to_each_part" or effect.type == "auto_assign_symbol" then
        return "{ type = \"assign_symbol_to_each_part\", destination = " .. lua_string(effect.destination or "socket")
            .. ", target = " .. lua_string(effect.target or effect.target_side or "self")
            .. ", symbol = " .. lua_symbol(effect.symbol or Symbols.WARD)
            .. ", amount = " .. tostring(effect.amount or 1) .. " }"
    elseif effect.type == "open_spellmark" or effect.type == "spellmark" then
        local pieces = {
            "type = \"open_spellmark\"",
            "destination = " .. lua_string(effect.destination or "rim"),
            "symbol = " .. lua_symbol(effect.symbol or effect.accept_symbol or Symbols.ESSENCE)
        }
        if effect.name or effect.mark_name then
            table.insert(pieces, "name = " .. lua_string(effect.name or effect.mark_name))
        end
        if effect.target or effect.target_side then
            table.insert(pieces, "target = " .. lua_string(effect.target or effect.target_side))
        end
        if effect.target_type or effect.part_type then
            table.insert(pieces, "target_type = " .. lua_string(effect.target_type or effect.part_type))
        end
        if effect.target_part_id then
            table.insert(pieces, "target_part_id = " .. lua_string(effect.target_part_id))
        end
        if effect.single_use == false then
            table.insert(pieces, "single_use = false")
        end
        table.insert(pieces, "on_mark = " .. self:lua_effect(effect.on_mark or effect.payload or effect.effect or { type = "none" }))
        return "{ " .. table.concat(pieces, ", ") .. " }"
    elseif effect.type == "damage_marked_part" or effect.type == "damage_target_part" or effect.type == "damage_assigned_part" then
        return "{ type = \"damage_marked_part\", amount = " .. tostring(effect.amount or 1) .. " }"
    elseif effect.type == "heal_part" then
        local pieces = {
            "type = \"heal_part\"",
            "target = " .. lua_string(effect.target or "most_damaged")
        }
        if effect.target == "part_type" then
            table.insert(pieces, "target_type = " .. lua_string(effect.target_type or "HEAD"))
        end
        table.insert(pieces, "amount = " .. tostring(effect.amount or 1))
        return "{ " .. table.concat(pieces, ", ") .. " }"
    elseif effect.type == "add_symbol_against_status" then
        return "{ type = \"add_symbol_against_status\", match = "
            .. lua_symbol(effect.match or effect.match_symbol or Symbols.STRIKE)
            .. ", symbol = " .. lua_symbol(effect.symbol or Symbols.STRIKE)
            .. ", amount = " .. tostring(effect.amount or 1)
            .. ", destination = " .. lua_string(effect.destination or "rim")
            .. ", target_status = " .. lua_string(effect.target_status or "wounded")
            .. ", duration = " .. lua_string(effect.duration or "round") .. " }"
    elseif effect.type == "damage_opponent_part" then
        return "{ type = \"damage_opponent_part\", target_type = " .. lua_string(effect.target_type or "HEAD") .. ", amount = " .. tostring(effect.amount or 1) .. " }"
    elseif effect.type == "gain_crest" then
        return "{ type = \"gain_crest\", crest = " .. lua_string(effect.crest or "Valor") .. ", amount = " .. tostring(effect.amount or 1) .. " }"
    end
    return "{ type = " .. lua_string(effect.type) .. " }"
end

function BPEditor:lua_slot(slot, indent)
    if not slot then
        return nil
    end

    local i = indent or "            "
    local lines = {
        "{",
        i .. "    id = " .. lua_string(slot.id) .. ",",
        i .. "    name = " .. lua_string(slot.name) .. ",",
        i .. "    cost = " .. lua_symbol_list(slot.cost) .. ","
    }
    if slot.dynamic_cost then
        table.insert(lines, i .. "    dynamic_cost = { type = "
            .. lua_string(slot.dynamic_cost.type or "opponent_damaged_parts")
            .. ", minimum = " .. tostring(slot.dynamic_cost.minimum or 1)
            .. ", per_part = " .. tostring(slot.dynamic_cost.per_part or 1) .. " },")
    end
    table.insert(lines, i .. "    timing = " .. lua_string(slot.timing or "spend") .. ",")
    table.insert(lines, i .. "    effect = " .. self:lua_effect(slot.effect))
    table.insert(lines, i .. "}")
    return table.concat(lines, "\n")
end

function BPEditor:part_lua()
    local part = self:form_to_part()
    local lines = {
        "[" .. lua_string(part.id) .. "] = {",
        "    id = " .. lua_string(part.id) .. ",",
        "    name = " .. lua_string(part.name) .. ",",
        "    flavor = " .. lua_string(part.flavor) .. ",",
        "    type = " .. lua_string(part.type) .. ",",
        "    hp_value = " .. tostring(part.hp_value) .. ",",
        "    die = {",
        "        faces = {"
    }

    for index, face in ipairs(part.die.faces) do
        table.insert(lines, "            " .. lua_face(face) .. (index < 6 and "," or ""))
    end

    table.insert(lines, "        },")
    table.insert(lines, "        wound_faces = { 1, 2 },")
    table.insert(lines, "        maim_faces = { 3, 4 }")
    table.insert(lines, "    },")

    if #part.tags > 0 then
        local tags = {}
        for _, tag in ipairs(part.tags) do
            table.insert(tags, lua_string(tag))
        end
        table.insert(lines, "    tags = { " .. table.concat(tags, ", ") .. " },")
    end

    if part.slot then
        table.insert(lines, "    slot = " .. self:lua_slot(part.slot, "    "))
    else
        table.insert(lines, "    slot = nil")
    end

    table.insert(lines, "}")
    return table.concat(lines, "\n")
end

function BPEditor:effect_note(effect)
    return Effects.describe(effect)
end

local function note_face(face)
    local normalized = normalize_face(face)
    if #normalized == 1 and normalized[1] == Symbols.BLANK then
        return "[ ]"
    end
    return "[" .. Symbols.format_face(normalized) .. "]"
end

function BPEditor:part_note()
    local part = self:form_to_part()
    local slot = part.slot
    local lines = {
        "### " .. part.name,
        "Type: " .. part.type,
        "Heart: " .. tostring(part.hp_value)
    }
    if part.flavor ~= "" then
        table.insert(lines, "Flavor: " .. part.flavor)
    end
    table.insert(lines, "Die:")
    table.insert(lines, "- Wound: " .. note_face(part.die.faces[1]) .. " " .. note_face(part.die.faces[2]))
    table.insert(lines, "- Maim: " .. note_face(part.die.faces[3]) .. " " .. note_face(part.die.faces[4]))
    table.insert(lines, "- Durable: " .. note_face(part.die.faces[5]) .. " " .. note_face(part.die.faces[6]))

    if slot then
        table.insert(lines, "Slot: " .. slot.name)
        local cost_parts = {}
        for _, symbol in ipairs(slot.cost or {}) do
            table.insert(cost_parts, note_face({ symbol }))
        end
        table.insert(lines, "Cost: " .. table.concat(cost_parts, " "))
        if slot.dynamic_cost then
            table.insert(lines, string.format(
                "Dynamic Cost: -%d pip(s) per damaged opposing BP, minimum %d",
                tonumber(slot.dynamic_cost.per_part) or 1,
                tonumber(slot.dynamic_cost.minimum) or 1))
        end
        table.insert(lines, "Timing: " .. tostring(slot.timing or "spend"))
        table.insert(lines, "Effect: " .. self:effect_note(slot.effect))
    else
        table.insert(lines, "Slot: None")
    end

    return table.concat(lines, "\n")
end

function BPEditor:copy_lua()
    local errors = self:validate_current_part()
    if #errors > 0 then
        self.message = "Fix before copying Lua: " .. tostring(errors[1])
        return
    end

    local text = self:part_lua()
    if love.system and love.system.setClipboardText then
        love.system.setClipboardText(text)
        self.message = "Copied Lua definition for " .. (self.current.name or self.current.id) .. "."
    else
        self.message = "Clipboard unavailable in this LOVE build."
    end
end

function BPEditor:copy_note()
    local text = self:part_note()
    if love.system and love.system.setClipboardText then
        love.system.setClipboardText(text)
        self.message = "Copied note text for " .. (self.current.name or self.current.id) .. "."
    else
        self.message = "Clipboard unavailable in this LOVE build."
    end
end

function BPEditor:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    for face_index, face_rect in pairs(self.face_rects or {}) do
        if point_in_rect(x, y, face_rect) then
            self.selected_face = face_index
            self.active_field = nil
            return
        end
    end

    for key, field_rect in pairs(self.fields or {}) do
        if point_in_rect(x, y, field_rect) then
            self.active_field = key
            return
        end
    end

    for _, key in ipairs(sorted_keys(self.buttons)) do
        local button = self.buttons[key]
        if point_in_rect(x, y, button.rect) and button.on_click then
            self.active_field = nil
            button.on_click()
            return
        end
    end

    self.active_field = nil
end

function BPEditor:textinput(text)
    if not self.active_field then
        return
    end

    if self.active_field == "search" then
        self.search = self.search .. text
        self.list_scroll = 0
        return
    end

    self.current[self.active_field] = tostring(self.current[self.active_field] or "") .. text
end

function BPEditor:keypressed(key)
    if key == "escape" then
        GameState.switch(require("states.overworld"))
        return
    elseif key == "tab" then
        self.active_field = nil
        return
    elseif key == "backspace" and self.active_field then
        if self.active_field == "search" then
            self.search = self.search:sub(1, -2)
            self.list_scroll = 0
        else
            local value = tostring(self.current[self.active_field] or "")
            self.current[self.active_field] = value:sub(1, -2)
        end
    elseif key == "delete" and self.active_field == "search" then
        self.search = ""
        self.list_scroll = 0
    elseif key == "/" and not self.active_field then
        self.active_field = "search"
        return
    elseif key == "down" then
        self.list_scroll = (self.list_scroll or 0) + 1
        self:clamp_list_scroll(#self:filtered_parts())
    elseif key == "up" then
        self.list_scroll = (self.list_scroll or 0) - 1
        self:clamp_list_scroll(#self:filtered_parts())
    elseif key == "pagedown" then
        self.list_scroll = (self.list_scroll or 0) + LIST_VISIBLE_ROWS
        self:clamp_list_scroll(#self:filtered_parts())
    elseif key == "pageup" then
        self.list_scroll = (self.list_scroll or 0) - LIST_VISIBLE_ROWS
        self:clamp_list_scroll(#self:filtered_parts())
    elseif key == "return" and (love.keyboard.isDown("lgui") or love.keyboard.isDown("lctrl")) then
        self:copy_lua()
    end
end

function BPEditor:wheelmoved(_, y)
    local mouse_x, mouse_y = love.mouse.getPosition()
    if not point_in_rect(mouse_x, mouse_y, self.list_rect) then
        return
    end

    self.list_scroll = (self.list_scroll or 0) - (y * 3)
    self:clamp_list_scroll(#self:filtered_parts())
end

return BPEditor
