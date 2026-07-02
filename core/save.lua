local Save = {}

Save.VERSION = 3
Save.DEFAULT_PATH = "saves/slot1.lua"

local function copy_table(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = copy_table(value)
    end
    return copy
end

local function sorted_keys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end

    table.sort(keys, function(a, b)
        local type_a = type(a)
        local type_b = type(b)
        if type_a ~= type_b then
            return type_a < type_b
        end
        return tostring(a) < tostring(b)
    end)

    return keys
end

local function quoted(value)
    return string.format("%q", value)
end

local function encode_value(value, indent, seen)
    local value_type = type(value)
    indent = indent or ""

    if value_type == "nil" then
        return "nil"
    elseif value_type == "string" then
        return quoted(value)
    elseif value_type == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("Cannot serialize non-finite number")
        end
        return tostring(value)
    elseif value_type == "boolean" then
        return tostring(value)
    elseif value_type ~= "table" then
        error("Cannot serialize " .. value_type)
    end

    if seen[value] then
        error("Cannot serialize cyclic table")
    end
    seen[value] = true

    local next_indent = indent .. "    "
    local lines = { "{" }
    for _, key in ipairs(sorted_keys(value)) do
        local encoded_key = "[" .. encode_value(key, "", seen) .. "]"
        local encoded_value = encode_value(value[key], next_indent, seen)
        table.insert(lines, next_indent .. encoded_key .. " = " .. encoded_value .. ",")
    end
    table.insert(lines, indent .. "}")

    seen[value] = nil
    return table.concat(lines, "\n")
end

local function compile_chunk(source, chunk_name)
    if loadstring then
        local fn, err = loadstring(source, chunk_name)
        if fn and setfenv then
            setfenv(fn, {})
        end
        return fn, err
    end

    return load(source, chunk_name, "t", {})
end

local function filesystem(backend)
    if backend then
        return backend
    end

    return love and love.filesystem or nil
end

local function dirname(path)
    return path and path:match("^(.*)/[^/]+$") or nil
end

function Save.new_game()
    return {
        save_version = Save.VERSION,
        profile = {},
        run = {},
        rooms = {}
    }
end

function Save.serialize(data)
    local root = copy_table(data or Save.new_game())
    root.save_version = root.save_version or Save.VERSION
    return "return " .. encode_value(root, "", {})
end

function Save.deserialize(source)
    if type(source) ~= "string" then
        return nil, "save source must be a string"
    end

    local fn, err = compile_chunk(source, "save")
    if not fn then
        return nil, err
    end

    local ok, data = pcall(fn)
    if not ok then
        return nil, data
    end

    if type(data) ~= "table" then
        return nil, "save file did not return a table"
    end

    data.save_version = data.save_version or 0
    if data.save_version ~= Save.VERSION then
        return nil, string.format(
            "unsupported save version %s; expected %s",
            tostring(data.save_version),
            tostring(Save.VERSION)
        )
    end

    data.profile = data.profile or {}
    data.run = data.run or {}
    data.rooms = data.rooms or {}
    return data
end

function Save.load(path, backend)
    path = path or Save.DEFAULT_PATH
    local fs = filesystem(backend)
    if not fs then
        return nil, nil
    end

    if fs.getInfo and not fs.getInfo(path) then
        return nil, nil
    end

    local source, read_err = fs.read(path)
    if not source then
        return nil, read_err or "could not read save file"
    end

    return Save.deserialize(source)
end

function Save.available(backend)
    return filesystem(backend) ~= nil
end

function Save.write(data, path, backend)
    path = path or Save.DEFAULT_PATH
    local fs = filesystem(backend)
    if not fs then
        return false, "love.filesystem is not available"
    end

    local directory = dirname(path)
    if directory and fs.createDirectory then
        local ok, err = fs.createDirectory(directory)
        if ok == false then
            return false, err or ("could not create " .. directory)
        end
    end

    local source = Save.serialize(data)
    local ok, err = fs.write(path, source)
    if ok == false then
        return false, err or "could not write save file"
    end

    return true
end

return Save
