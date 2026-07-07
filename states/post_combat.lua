local GameState = require("core.gamestate")
local Display = require("core.display")
local Input = require("core.input")

local PostCombat = {}
PostCombat.__index = PostCombat

local COLORS = {
    scrim = { 0.02, 0.02, 0.04, 0.68 },
    panel = { 0.08, 0.075, 0.12, 0.96 },
    line = { 0.74, 0.70, 0.86, 0.75 },
    ink = { 0.96, 0.94, 1, 1 },
    muted = { 0.66, 0.63, 0.76, 1 },
    good = { 0.37, 0.86, 0.58, 1 },
    warning = { 1, 0.72, 0.32, 1 }
}

local OUTCOME_TITLES = {
    victory = "Dream Won",
    defeat = "Dream Bruised",
    fled = "Dream Escaped",
    draw = "Dream Unsettled",
    scripted = "Dream Shifted"
}

local function set_color(color)
    love.graphics.setColor(color)
end

local function title_for(summary)
    return OUTCOME_TITLES[summary and summary.outcome] or "Combat Ended"
end

local function status_line(part)
    local name = part.name or part.def_id or "Body Part"
    local before = part.combat_status or "healthy"
    local after = part.recovered_status or before
    if before == after then
        return name .. ": " .. after
    end
    return name .. ": " .. before .. " -> " .. after
end

local function part_name(part)
    return part.name or part.def_id or part.id or "Unknown Part"
end

local SLOT_LABELS = {
    head = "Head",
    body = "Body",
    arm_l = "Fore Hand",
    arm_r = "Back Hand",
    leg_l = "Front Foot",
    leg_r = "Back Foot"
}

function PostCombat:enter(summary)
    self.summary = summary or {}
    self.elapsed = 0
end

function PostCombat:update(dt)
    self.elapsed = self.elapsed + (dt or 0)
end

function PostCombat:draw()
    local width = Display.WIDTH
    local height = Display.HEIGHT
    local panel_w = math.min(620, width - 48)
    local panel_h = math.min(310, height - 48)
    local x = math.floor((width - panel_w) / 2)
    local y = math.floor((height - panel_h) / 2)
    local summary = self.summary or {}

    set_color(COLORS.scrim)
    love.graphics.rectangle("fill", 0, 0, width, height)

    set_color(COLORS.panel)
    love.graphics.rectangle("fill", x, y, panel_w, panel_h, 6, 6)
    set_color(COLORS.line)
    love.graphics.rectangle("line", x, y, panel_w, panel_h, 6, 6)

    set_color(COLORS.ink)
    love.graphics.printf(title_for(summary), x + 24, y + 22, panel_w - 48, "center")

    local line_y = y + 62
    set_color(COLORS.muted)
    love.graphics.printf("Encounter: " .. tostring(summary.encounter_id or "unknown"), x + 24, line_y, panel_w - 48, "center")

    line_y = line_y + 34
    set_color(COLORS.ink)
    love.graphics.print("Dreamform recovery", x + 28, line_y)
    line_y = line_y + 22

    local recovered = summary.recovered_parts or {}
    if #recovered == 0 then
        set_color(COLORS.muted)
        love.graphics.print("No body parts changed.", x + 40, line_y)
        line_y = line_y + 20
    else
        for index, part in ipairs(recovered) do
            if index > 4 then
                set_color(COLORS.muted)
                love.graphics.print("...", x + 40, line_y)
                line_y = line_y + 18
                break
            end
            set_color(part.combat_status ~= part.recovered_status and COLORS.good or COLORS.muted)
            love.graphics.print(status_line(part), x + 40, line_y)
            line_y = line_y + 18
        end
    end

    line_y = line_y + 14
    set_color(COLORS.ink)
    love.graphics.print("Dreamform change", x + 28, line_y)
    line_y = line_y + 22

    local claim = summary.claim_summary
    if claim and claim.def_id then
        local claimed = summary.claimed_part or claim
        local slot_label = SLOT_LABELS[summary.claimed_slot or claim.slot_id] or tostring(summary.claimed_slot or claim.slot_id or "slot")
        set_color(COLORS.warning)
        love.graphics.printf(part_name(claimed) .. " took root as " .. slot_label .. ".", x + 40, line_y, panel_w - 80, "left")
        line_y = line_y + 18
        if claim.replaced_part then
            set_color(COLORS.muted)
            love.graphics.printf(part_name(claim.replaced_part) .. " faded away.", x + 40, line_y, panel_w - 80, "left")
        end
    elseif summary.outcome == "victory" then
        set_color(COLORS.muted)
        love.graphics.print("Dreamform left unchanged.", x + 40, line_y)
    else
        set_color(COLORS.muted)
        love.graphics.print("No claim.", x + 40, line_y)
    end

    set_color(COLORS.muted)
    love.graphics.printf("Continue", x + 24, y + panel_h - 34, panel_w - 48, "center")
end

function PostCombat:close()
    GameState.pop()
end

function PostCombat:keypressed(key)
    return self:actionpressed(Input.action_for_key(key))
end

function PostCombat:actionpressed(action)
    if action == "confirm" or action == "cancel" or action == "menu" then
        self:close()
        return true
    end

    return false
end

function PostCombat:mousepressed(_, _, button)
    if button == 1 then
        self:close()
    end
end

return PostCombat
