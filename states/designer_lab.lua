local GameState = require("core.gamestate")

local DesignerLab = {}
DesignerLab.__index = DesignerLab
DesignerLab.opaque = true

local COLORS = {
    bg = { 0.055, 0.06, 0.08, 1 },
    panel = { 0.085, 0.09, 0.12, 1 },
    surface = { 0.12, 0.125, 0.16, 1 },
    line = { 0.42, 0.44, 0.52, 1 },
    ink = { 0.95, 0.95, 0.98, 1 },
    muted = { 0.62, 0.63, 0.7, 1 },
    accent = { 0.26, 0.76, 0.62, 1 },
    combat = { 0.96, 0.38, 0.31, 1 },
    overworld = { 0.34, 0.64, 0.98, 1 }
}

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function point_in_rect(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

local function set_color(color)
    love.graphics.setColor(color)
end

local function draw_box(r, fill, line)
    set_color(fill)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, 5, 5)
    set_color(line)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, 5, 5)
end

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

local function summary_text(summary)
    if not summary then
        return "No playtest completed in this lab session."
    end

    return string.format(
        "%s | seed %s | %s rounds | Hearts %s-%s | Slots %s",
        tostring(summary.encounter_id or "encounter"),
        tostring(summary.seed or "?"),
        tostring(summary.rounds or "?"),
        tostring(summary.player_hearts or "?"),
        tostring(summary.enemy_hearts or "?"),
        tostring(summary.slot_activation_count or 0))
end

function DesignerLab:enter()
    self.catalog = require("data.designer_scenarios")
    self.tab = self.tab or "combat"
    self.selected_index = 1
    self.search = ""
    self.search_active = false
    self.rows = {}
    self.tabs = {}
    self.fonts = {
        title = love.graphics.newFont(22),
        heading = love.graphics.newFont(15),
        body = love.graphics.newFont(12),
        small = love.graphics.newFont(10)
    }
end

function DesignerLab:scenarios()
    local query = self.search:lower()
    local filtered = {}
    for _, scenario in ipairs(self.catalog[self.tab] or {}) do
        local haystack = table.concat({
            scenario.id or "",
            scenario.name or "",
            scenario.description or "",
            scenario.encounter_id or "",
            scenario.room or ""
        }, " "):lower()
        if query == "" or haystack:find(query, 1, true) then
            table.insert(filtered, scenario)
        end
    end
    return filtered
end

function DesignerLab:clamp_selection()
    local count = #self:scenarios()
    self.selected_index = math.max(1, math.min(self.selected_index or 1, math.max(1, count)))
end

function DesignerLab:set_tab(tab)
    if self.catalog[tab] then
        self.tab = tab
        self.selected_index = 1
    end
end

function DesignerLab:launch(scenario)
    scenario = scenario or self:scenarios()[self.selected_index]
    if not scenario then
        return
    end

    if self.tab == "combat" then
        GameState.push(require("states.v2_combat"), {
            encounter_id = scenario.encounter_id,
            seed = scenario.seed,
            combat_setup = copy_table(scenario.combat_setup),
            designer_mode = true,
            designer_scenario_id = scenario.id,
            designer_scenario_name = scenario.name
        })
    else
        GameState.push(require("states.designer_overworld"), {
            scenario = copy_table(scenario)
        })
    end
end

function DesignerLab:resume(_, result)
    if result and result.playtest_summary then
        self.last_summary = result.playtest_summary
    end
end

function DesignerLab:keypressed(key)
    if self.search_active then
        if key == "escape" or key == "return" then
            self.search_active = false
        elseif key == "backspace" then
            self.search = self.search:sub(1, -2)
            self.selected_index = 1
        elseif key == "delete" then
            self.search = ""
            self.selected_index = 1
        end
        return
    end

    if key == "/" then
        self.search_active = true
    elseif key == "tab" or key == "left" or key == "right" then
        self:set_tab(self.tab == "combat" and "overworld" or "combat")
    elseif key == "up" or key == "w" then
        self.selected_index = self.selected_index - 1
        self:clamp_selection()
    elseif key == "down" or key == "s" then
        self.selected_index = self.selected_index + 1
        self:clamp_selection()
    elseif key == "return" or key == "space" then
        self:launch()
    elseif key == "escape" then
        GameState.switch(require("states.overworld"))
    end
end

function DesignerLab:textinput(text)
    if self.search_active then
        self.search = self.search .. text
        self.selected_index = 1
    end
end

function DesignerLab:mousepressed(x, y, button)
    if button ~= 1 then
        return
    end

    for tab, tab_rect in pairs(self.tabs or {}) do
        if point_in_rect(x, y, tab_rect) then
            self:set_tab(tab)
            return
        end
    end

    if self.search_rect and point_in_rect(x, y, self.search_rect) then
        self.search_active = true
        return
    end

    for index, row in ipairs(self.rows or {}) do
        if point_in_rect(x, y, row.rect) then
            self.selected_index = index
            self:launch(row.scenario)
            return
        end
    end
end

function DesignerLab:draw()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    love.graphics.clear(COLORS.bg)

    love.graphics.setFont(self.fonts.title)
    set_color(COLORS.ink)
    love.graphics.print("Designer Lab", 28, 22)
    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Isolated combat and Basement checkpoints. Nothing here autosaves.", 28, 52)

    self.tabs = {
        combat = rect(28, 82, 126, 30),
        overworld = rect(162, 82, 126, 30)
    }
    for _, tab in ipairs({ "combat", "overworld" }) do
        local selected = self.tab == tab
        local accent = tab == "combat" and COLORS.combat or COLORS.overworld
        draw_box(self.tabs[tab], selected and COLORS.surface or COLORS.panel, selected and accent or COLORS.line)
        love.graphics.setFont(self.fonts.body)
        set_color(selected and accent or COLORS.muted)
        love.graphics.printf(tab == "combat" and "Combat" or "Basement", self.tabs[tab].x, self.tabs[tab].y + 8, self.tabs[tab].w, "center")
    end

    self.search_rect = rect(width - 282, 82, 254, 30)
    draw_box(self.search_rect, COLORS.panel, self.search_active and COLORS.accent or COLORS.line)
    love.graphics.setFont(self.fonts.body)
    set_color(self.search == "" and COLORS.muted or COLORS.ink)
    love.graphics.print(self.search == "" and "Search  /" or self.search, self.search_rect.x + 10, self.search_rect.y + 8)

    local scenarios = self:scenarios()
    self:clamp_selection()
    self.rows = {}
    local list = rect(28, 126, width - 56, height - 216)
    draw_box(list, COLORS.panel, COLORS.line)
    local row_y = list.y + 10
    for index, scenario in ipairs(scenarios) do
        local row = rect(list.x + 10, row_y, list.w - 20, 54)
        local selected = index == self.selected_index
        local accent = self.tab == "combat" and COLORS.combat or COLORS.overworld
        draw_box(row, selected and COLORS.surface or COLORS.panel, selected and accent or COLORS.line)

        love.graphics.setFont(self.fonts.heading)
        set_color(selected and COLORS.ink or COLORS.muted)
        love.graphics.print(scenario.name or scenario.id, row.x + 12, row.y + 8)
        love.graphics.setFont(self.fonts.small)
        set_color(COLORS.muted)
        love.graphics.print(scenario.description or "", row.x + 12, row.y + 31)
        love.graphics.printf(scenario.encounter_id or scenario.room or "", row.x + row.w - 280, row.y + 20, 266, "right")

        self.rows[index] = {
            rect = row,
            scenario = scenario
        }
        row_y = row_y + 62
    end

    love.graphics.setFont(self.fonts.small)
    set_color(COLORS.muted)
    love.graphics.print("Enter: launch   Tab: switch view   /: search   Esc: game", 28, height - 72)
    love.graphics.printf(summary_text(self.last_summary), 28, height - 46, width - 56, "left")
end

return DesignerLab
