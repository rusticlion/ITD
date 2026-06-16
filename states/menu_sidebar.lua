local GameState = require("core.gamestate")
local Input = require("core.input")

local MenuSidebar = {}
MenuSidebar.__index = MenuSidebar

local COLORS = {
    panel = { 0.06, 0.065, 0.10, 0.97 },
    line = { 0.76, 0.76, 0.88, 0.78 },
    ink = { 0.96, 0.95, 1, 1 },
    muted = { 0.62, 0.61, 0.72, 1 },
    selected = { 0.22, 0.46, 0.56, 1 },
    selected_line = { 0.70, 0.92, 0.96, 1 }
}

local MENU_ITEMS = {
    { id = "inventory", label = "Inventory" },
    { id = "dreamform", label = "Dreamform" },
    { id = "esoterica", label = "Esoterica" },
    { id = "save", label = "Save" },
    { id = "options", label = "Options" },
    { id = "quit", label = "Quit" }
}

local function set_color(color)
    love.graphics.setColor(color)
end

function MenuSidebar:enter(context)
    context = context or {}
    self.world = context.world
    self.items = MENU_ITEMS
    self.selected_index = context.selected_index or 1
    self.item_rects = {}
end

function MenuSidebar:close()
    GameState.pop()
end

function MenuSidebar:open_selected()
    local item = self.items[self.selected_index]
    if not item then
        return
    end

    GameState.push(require("states.menu_screen"), {
        world = self.world,
        screen = item.id,
        title = item.label
    })
end

function MenuSidebar:move_selection(delta)
    local count = #self.items
    self.selected_index = ((self.selected_index - 1 + delta) % count) + 1
end

function MenuSidebar:actionpressed(action)
    if action == "cancel" or action == "menu" then
        self:close()
        return true
    elseif action == "move_up" then
        self:move_selection(-1)
        return true
    elseif action == "move_down" then
        self:move_selection(1)
        return true
    elseif action == "confirm" then
        self:open_selected()
        return true
    end

    return false
end

function MenuSidebar:keypressed(key)
    return self:actionpressed(Input.action_for_key(key))
end

function MenuSidebar:mousepressed(x, y, button)
    if button ~= 1 then
        return false
    end

    for index, rect in ipairs(self.item_rects or {}) do
        if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
            self.selected_index = index
            self:open_selected()
            return true
        end
    end

    return false
end

function MenuSidebar:draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local panel_w = math.min(210, width - 32)
    local item_h = 32
    local panel_h = 48 + #self.items * item_h + 16
    local x = width - panel_w - 18
    local y = 18

    set_color(COLORS.panel)
    love.graphics.rectangle("fill", x, y, panel_w, panel_h, 5, 5)
    set_color(COLORS.line)
    love.graphics.rectangle("line", x, y, panel_w, panel_h, 5, 5)

    set_color(COLORS.ink)
    love.graphics.printf("Menu", x + 16, y + 16, panel_w - 32, "left")

    self.item_rects = {}
    local item_y = y + 48
    for index, item in ipairs(self.items) do
        local rect = { x = x + 12, y = item_y, w = panel_w - 24, h = item_h - 4 }
        self.item_rects[index] = rect

        if index == self.selected_index then
            set_color(COLORS.ink)
            love.graphics.print(">", rect.x + 8, rect.y + 7)
        else
            set_color(COLORS.muted)
        end

        love.graphics.printf(item.label, rect.x + 26, rect.y + 7, rect.w - 34, "left")
        item_y = item_y + item_h
    end
end

return MenuSidebar
