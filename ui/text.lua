local Text = {}

Text.TRACKING = 1

local native = {}
local installed = false

local function graphics()
    return love and love.graphics or nil
end

local function tracking_for(options)
    if options and options.tracking ~= nil then
        return options.tracking
    end

    return Text.TRACKING
end

local function current_font()
    local g = graphics()
    return g and g.getFont and g.getFont() or nil
end

local function native_print()
    local g = graphics()
    return native.print or (g and g.print)
end

local function native_printf()
    local g = graphics()
    return native.printf or (g and g.printf)
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

function Text.chars(text)
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

function Text.width(text, options)
    local font = current_font()
    if not font then
        return 0
    end

    local width = 0
    local chars = Text.chars(text)
    local tracking = tracking_for(options)
    for index, char in ipairs(chars) do
        local ok, char_width = pcall(font.getWidth, font, char)
        if not ok then
            ok, char_width = pcall(font.getWidth, font, "?")
        end

        width = width + (ok and char_width or 0)
        if index < #chars then
            width = width + tracking
        end
    end

    return width
end

local function split_long_word(word, max_width, options)
    local lines = {}
    local current = ""

    for _, char in ipairs(Text.chars(word)) do
        local candidate = current .. char
        if current ~= "" and Text.width(candidate, options) > max_width then
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

function Text.wrap(text, max_width, options)
    local width = max_width or 200
    local lines = {}
    local source = tostring(text or "")

    for paragraph in (source .. "\n"):gmatch("(.-)\n") do
        local current = ""
        local saw_word = false

        for word in paragraph:gmatch("%S+") do
            saw_word = true
            local candidate = current == "" and word or (current .. " " .. word)
            if Text.width(candidate, options) <= width then
                current = candidate
            elseif current ~= "" then
                table.insert(lines, current)
                if Text.width(word, options) <= width then
                    current = word
                else
                    local pieces = split_long_word(word, width, options)
                    for index = 1, #pieces - 1 do
                        table.insert(lines, pieces[index])
                    end
                    current = pieces[#pieces] or ""
                end
            else
                local pieces = split_long_word(word, width, options)
                for index = 1, #pieces - 1 do
                    table.insert(lines, pieces[index])
                end
                current = pieces[#pieces] or ""
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

function Text.truncate(text, max_width, options)
    local source = tostring(text or "")
    if Text.width(source, options) <= max_width then
        return source
    end

    local suffix = (options and options.suffix) or ".."
    local available = math.max(0, (max_width or 0) - Text.width(suffix, options))
    local result = ""

    for _, char in ipairs(Text.chars(source)) do
        local candidate = result .. char
        if Text.width(candidate, options) > available then
            break
        end
        result = candidate
    end

    return result .. suffix
end

function Text.height(text, max_width, options)
    local font = current_font()
    if not font then
        return 12
    end

    return math.max(1, #Text.wrap(text, max_width or 200, options)) * font:getHeight()
end

function Text.line(text, x, y, color, options)
    local font = current_font()
    local print_fn = native_print()
    if not (font and print_fn) then
        return 0
    end

    local g = graphics()
    if color and g and g.setColor then
        g.setColor(color)
    end

    local cursor_x = x
    local tracking = tracking_for(options)
    local characters = Text.chars(text)
    for index, char in ipairs(characters) do
        local ok = pcall(print_fn, char, cursor_x, y)
        local measured_char = char
        if not ok then
            measured_char = "?"
            print_fn(measured_char, cursor_x, y)
        end

        local width_ok, char_width = pcall(font.getWidth, font, measured_char)
        if not width_ok then
            width_ok, char_width = pcall(font.getWidth, font, "?")
        end

        cursor_x = cursor_x + (width_ok and char_width or 0)
        if index < #characters then
            cursor_x = cursor_x + tracking
        end
    end

    return cursor_x - x
end

function Text.draw_line(text, x, y, width, align, color, options)
    local line_width = Text.width(text, options)
    local line_x = x
    local limit = width or 200

    if align == "center" then
        line_x = x + math.floor((limit - line_width) / 2)
    elseif align == "right" then
        line_x = x + limit - line_width
    end

    Text.line(text, line_x, y, color, options)
    return line_width <= limit, line_width
end

function Text.draw(text, x, y, width, align, color, options)
    local limit = width or 200
    local font = current_font()
    local line_height = font and font:getHeight() or 12
    local lines = Text.wrap(text, limit, options)

    for index, line in ipairs(lines) do
        Text.draw_line(line, x, y + (index - 1) * line_height, limit, align, color, options)
    end
end

function Text.print(text, x, y)
    return Text.line(text, x, y)
end

function Text.printf(text, x, y, width, align)
    return Text.draw(text, x, y, width, align or "left")
end

function Text.install(g)
    g = g or graphics()
    if installed or not g then
        return
    end

    native.print = g.print
    native.printf = g.printf
    installed = true

    g.print = function(text, x, y, ...)
        if select("#", ...) > 0 or type(x) ~= "number" or type(y) ~= "number" then
            return native.print(text, x, y, ...)
        end

        return Text.print(text, x, y)
    end

    g.printf = function(text, x, y, width, align, ...)
        if select("#", ...) > 0
            or type(x) ~= "number"
            or type(y) ~= "number"
            or type(width) ~= "number" then
            return native.printf(text, x, y, width, align, ...)
        end

        return Text.printf(text, x, y, width, align)
    end
end

return Text
