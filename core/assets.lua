local Assets = {
    images = {},
    sources = {},
    directories = {
        "assets/sprites/bodyparts",
        "assets/sprites/combat",
        "assets/sprites/icons",
    }
}

local function loadImage(path)
    local success, result = pcall(love.graphics.newImage, path)
    if not success then
        print(string.format("[Assets] Failed to load image '%s': %s", path, result))
        return nil
    end
    return result
end

function Assets:load()
    self.images = {}
    self.sources = {}

    for _, directory in ipairs(self.directories) do
        local info = love.filesystem.getInfo(directory)
        if info and info.type == "directory" then
            for _, file in ipairs(love.filesystem.getDirectoryItems(directory)) do
                if file:sub(-4):lower() == ".png" then
                    local id = file:sub(1, -5)
                    local path = directory .. "/" .. file
                    local image = loadImage(path)
                    if image then
                        if self.images[id] then
                            print(string.format(
                                "[Assets] Duplicate asset id '%s' at %s; keeping first loaded image from %s.",
                                id,
                                path,
                                self.sources[id] or "unknown"))
                        else
                            self.images[id] = image
                            self.sources[id] = path
                        end
                    end
                end
            end
        else
            print(string.format("[Assets] Directory not found: %s", directory))
        end
    end
end

local function parseStateSuffix(id)
    if type(id) ~= "string" then
        return nil
    end
    return id:match("_(healthy|wounded|maimed)$")
end

function Assets:get(id)
    if not id then
        return nil
    end

    local image = self.images[id]
    if image then
        return image
    end

    local state = parseStateSuffix(id)
    if state then
        local placeholder = "placeholder_" .. state
        image = self.images[placeholder]
        if image then
            return image
        end
    end

    image = self.images["placeholder_default"]
    if image then
        return image
    end

    print(string.format("[Assets] Missing asset for id '%s'", id))
    return nil
end

return Assets
