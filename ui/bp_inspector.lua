local Keywords = require("combat.keywords")
local Symbols = require("core.symbols")
local SymbolDie = require("core.symbol_die")
local BPCard = require("ui.bp_card")
local Text = require("ui.text")

local BPInspector = {}

local COLORS = {
    bg = { 0.055, 0.06, 0.09, 0.96 },
    panel = { 0.075, 0.08, 0.12, 1 },
    line = { 0.70, 0.72, 0.84, 0.74 },
    ink = { 0.96, 0.95, 1, 1 },
    muted = { 0.64, 0.63, 0.74, 1 },
    accent = { 0.36, 0.70, 0.76, 1 },
    warning = { 1, 0.72, 0.35, 1 }
}

local function set_color(color)
    love.graphics.setColor(color)
end

local function copy_color(color)
    if not color then
        return nil
    end

    return { color[1], color[2], color[3], color[4] }
end

local function merge_colors(overrides)
    local colors = {}
    for key, value in pairs(COLORS) do
        colors[key] = copy_color(value)
    end

    for key, value in pairs(overrides or {}) do
        colors[key] = copy_color(value)
    end

    return colors
end

local function title_case(value)
    local text = tostring(value or "")
    return (text:gsub("^%l", string.upper))
end

local function format_target(value)
    local text = tostring(value or "target")
    if text == "self" then
        return "each allied"
    elseif text == "opponent" or text == "enemy" then
        return "each opposing"
    end

    return text
end

local function format_destination(value)
    local text = tostring(value or "destination")
    if text == "socket" then
        return "socket"
    elseif text == "rim" then
        return "rim"
    elseif text == "slot" then
        return "slot"
    end

    return text
end

local function slot_cost_text(slot, part)
    local cost = slot and slot.cost or {}
    if Keywords.slot_is_hungry(part, slot) then
        local count = math.max(0, #cost)
        local noun = count == 1 and "wildcard pip" or "wildcard pips"
        return tostring(count) .. " " .. noun
    end

    return Symbols.format_face(cost)
end

function BPInspector.slot_effect_text(effect)
    if type(effect) ~= "table" then
        return "No effect recorded."
    end

    local amount = tonumber(effect.amount) or 1
    local symbol = effect.symbol and Symbols.display(effect.symbol)

    if effect.type == "add_next_symbol" then
        return "Next die gains " .. tostring(symbol or "a symbol") .. "."
    elseif effect.type == "heal_self" then
        if amount == 1 then
            return "Heals this Body Part one step."
        end
        return "Heals this Body Part " .. tostring(amount) .. " steps."
    elseif effect.type == "damage_opponent_part" then
        local target = effect.target_type and tostring(effect.target_type):upper() or "a Body Part"
        if amount == 1 then
            return "Damages the opponent's " .. target .. " one step."
        end
        return "Damages the opponent's " .. target .. " " .. tostring(amount) .. " steps."
    elseif effect.type == "assign_symbol_to_each_part" then
        return "Assigns "
            .. tostring(symbol or "a symbol")
            .. " to "
            .. format_target(effect.target)
            .. " Body Part's "
            .. format_destination(effect.destination)
            .. "."
    elseif effect.type == "add_symbol_to_matching_dice" then
        local match = effect.match and Symbols.display(effect.match) or "matching"
        return "Dice showing " .. tostring(match) .. " gain " .. tostring(symbol or "a symbol") .. "."
    end

    return "Effect: " .. tostring(effect.type or "unknown") .. "."
end

function BPInspector.slot_lines(slot, part)
    if not slot then
        return { "No Slot." }
    end

    local lines = {
        "Slot: " .. tostring(slot.name or slot.id or "Unnamed"),
        "Cost: " .. slot_cost_text(slot, part),
        "Timing: " .. title_case(slot.timing or "spend"),
        "Effect: " .. BPInspector.slot_effect_text(slot.effect)
    }

    return lines
end

function BPInspector.part_lines(part, options)
    options = options or {}
    if not part then
        return { "No Body Part selected." }
    end

    local status = options.status or part.status or "healthy"
    local lines = {
        string.format("%s / %s", part.name or part.id or "Body Part", title_case(status)),
        "Type: " .. tostring(part.type or "unknown") .. " / Heart: " .. tostring(part.hp_value or 0)
    }

    if part.tags and #part.tags > 0 then
        table.insert(lines, "Tags: " .. table.concat(part.tags, ", "))
    end

    local badges = Keywords.badges_for_part(part)
    for _, definition in ipairs(badges) do
        table.insert(lines, tostring(definition.name) .. ": " .. tostring(definition.description))
    end

    if part.slot then
        table.insert(lines, "Slot: " .. tostring(part.slot.name or part.slot.id or "Unnamed"))
        table.insert(lines, "Cost: " .. slot_cost_text(part.slot, part) .. " / Timing: " .. title_case(part.slot.timing or "spend"))
        table.insert(lines, "Effect: " .. BPInspector.slot_effect_text(part.slot.effect))
    else
        table.insert(lines, "Slot: none")
    end

    return lines
end

function BPInspector.flavor(part)
    local text = part and part.flavor
    if text and text ~= "" then
        return text
    end

    return "No dream-memory recorded."
end

function BPInspector.die_face_counts(parts, options)
    options = options or {}
    local counts = {}
    local order = {}

    for _, part in ipairs(parts or {}) do
        local status = options.status or part.status or "healthy"
        for face_index = 1, 6 do
            local label = Symbols.format_face(SymbolDie.face_for_status(part and part.die, face_index, status))
            if not counts[label] then
                counts[label] = 0
                table.insert(order, label)
            end
            counts[label] = counts[label] + 1
        end
    end

    table.sort(order, function(left, right)
        local left_count = counts[left] or 0
        local right_count = counts[right] or 0
        if left_count == right_count then
            return left < right
        end
        return left_count > right_count
    end)

    return counts, order
end

function BPInspector.die_face_count_entries(parts, options)
    options = options or {}
    local entries_by_key = {}
    local entries = {}

    for _, part in ipairs(parts or {}) do
        local status = options.status or part.status or "healthy"
        for face_index = 1, 6 do
            local symbols = SymbolDie.face_for_status(part and part.die, face_index, status)
            local label = Symbols.format_face(symbols)
            local entry = entries_by_key[label]
            if not entry then
                entry = {
                    key = label,
                    symbols = Symbols.copy_face(symbols),
                    count = 0
                }
                entries_by_key[label] = entry
                table.insert(entries, entry)
            end
            entry.count = entry.count + 1
        end
    end

    table.sort(entries, function(left, right)
        if left.count == right.count then
            return left.key < right.key
        end
        return left.count > right.count
    end)

    return entries
end

function BPInspector.die_face_count_lines(parts, options)
    local counts, order = BPInspector.die_face_counts(parts, options)
    local lines = {}

    for _, label in ipairs(order) do
        table.insert(lines, label .. " x" .. tostring(counts[label]))
    end

    if #lines == 0 then
        table.insert(lines, "No dice in current pool.")
    end

    return lines
end

local function draw_box(rect, fill, line, radius)
    set_color(fill)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, radius or 4, radius or 4)
    set_color(line)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, radius or 4, radius or 4)
end

local function draw_wrapped(text, x, y, w, color, gap)
    set_color(color)
    Text.draw(text, x, y, w, "left", color)
    return y + Text.height(text, w) + (gap or 4)
end

local function face_has_degradation(list, face_index)
    for _, index in ipairs(list or {}) do
        if tonumber(index) == face_index then
            return true
        end
    end

    return false
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

local function draw_crack_overlay(r, level, colors)
    if level == "heavy" then
        set_color({ 0, 0, 0, 0.28 })
        love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4, 4, 4)
        set_color({ colors.ink[1], colors.ink[2], colors.ink[3], 0.82 })
        love.graphics.setLineWidth(2)
        love.graphics.line(r.x + 6, r.y + 7, r.x + r.w - 7, r.y + r.h - 8)
        love.graphics.line(r.x + r.w - 8, r.y + 8, r.x + 8, r.y + r.h - 7)
    elseif level == "light" then
        set_color({ colors.accent[1], colors.accent[2], colors.accent[3], 0.18 })
        love.graphics.rectangle("fill", r.x + 2, r.y + 2, r.w - 4, r.h - 4, 4, 4)
        set_color({ colors.accent[1], colors.accent[2], colors.accent[3], 0.85 })
        love.graphics.setLineWidth(1)
        love.graphics.line(r.x + r.w - 11, r.y + 7, r.x + r.w - 7, r.y + 14)
        love.graphics.line(r.x + r.w - 7, r.y + 14, r.x + r.w - 12, r.y + 22)
    end
end

local function draw_die_diagram(part, x, y, w, available_h, colors)
    if not (part and part.die) then
        return y
    end

    local face_gap = 4
    local face_size = math.min(
        32,
        math.floor((w - face_gap * 2) / 3),
        math.floor((available_h - face_gap) / 2))

    if face_size < 12 then
        return y
    end

    local grid_w = face_size * 3 + face_gap * 2
    local grid_h = face_size * 2 + face_gap
    local grid_x = x + math.floor(math.max(0, w - grid_w) / 2)
    local face_columns = {
        sorted_face_indexes(part.die.wound_faces),
        sorted_face_indexes(part.die.maim_faces),
        durable_face_indexes(part.die)
    }

    set_color(colors.line)
    love.graphics.rectangle("line", grid_x - 6, y - 6, grid_w + 12, grid_h + 12, 4, 4)

    for column = 1, 3 do
        for row = 1, 2 do
            local face_index = face_columns[column] and face_columns[column][row]
            if face_index then
                local face_rect = {
                    x = grid_x + (column - 1) * (face_size + face_gap),
                    y = y + (row - 1) * (face_size + face_gap),
                    w = face_size,
                    h = face_size
                }
                local face = SymbolDie.face_for_status(part.die, face_index, "healthy")
                BPCard.draw_die_face(face, face_rect, {
                    scale = face_size / 36
                })

                if column == 1 then
                    draw_crack_overlay(face_rect, "heavy", colors)
                elseif column == 2 then
                    draw_crack_overlay(face_rect, "light", colors)
                end
            end
        end
    end

    return y + grid_h + 12
end

function BPInspector.draw_panel(rect, data, options)
    options = options or {}
    data = data or {}

    local colors = merge_colors(options.colors)
    local padding = options.padding or 14
    local header_hidden = options.hide_header == true
    local default_flavor_h = header_hidden
        and math.min(150, math.floor(rect.h * 0.48))
        or math.min(126, math.floor(rect.h * 0.28))
    local flavor_h = options.flavor_h or default_flavor_h
    local title = data.title or "Inspector"
    local subtitle = data.subtitle
    local lines = data.lines or (data.part and BPInspector.part_lines(data.part)) or {}
    local flavor = data.flavor or (data.part and BPInspector.flavor(data.part))

    draw_box(rect, colors.bg, colors.line, options.radius or 5)

    local y = rect.y + padding
    if not header_hidden then
        set_color(colors.ink)
        Text.draw(title, rect.x + padding, y, rect.w - padding * 2, "left", colors.ink)
        y = y + 24

        if subtitle then
            y = draw_wrapped(subtitle, rect.x + padding, y, rect.w - padding * 2, colors.muted, 8)
        end
    end

    local flavor_rule_y = rect.y + rect.h - flavor_h
    set_color(colors.line)
    love.graphics.line(rect.x + padding, flavor_rule_y, rect.x + rect.w - padding, flavor_rule_y)

    for _, line in ipairs(lines) do
        if y > flavor_rule_y - 22 then
            break
        end
        y = draw_wrapped(line, rect.x + padding, y, rect.w - padding * 2, colors.ink, 6)
    end

    if options.show_die and data.part and data.part.die then
        local available_h = flavor_rule_y - y - 12
        if available_h >= 32 then
            y = draw_die_diagram(data.part, rect.x + padding, y + 4, rect.w - padding * 2, available_h, colors)
        end
    end

    y = flavor_rule_y + 12
    set_color(colors.muted)
    Text.draw("Flavor", rect.x + padding, y, rect.w - padding * 2, "left", colors.muted)
    y = y + 20
    draw_wrapped(flavor or "No dream-memory recorded.", rect.x + padding, y, rect.w - padding * 2, colors.ink, 4)
end

return BPInspector
