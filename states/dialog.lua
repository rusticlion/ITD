local Assets = require("core.assets")
local GameState = require("core.gamestate")
local Input = require("core.input")
local Dialog = require("systems.dialog")

local DialogState = {}
DialogState.__index = DialogState

local COLORS = {
    box = { 0.045, 0.045, 0.075, 0.96 },
    box_line = { 0.72, 0.70, 0.84, 0.82 },
    speaker = { 0.10, 0.12, 0.18, 0.98 },
    speaker_line = { 0.55, 0.66, 0.84, 0.86 },
    ink = { 0.96, 0.95, 1, 1 },
    muted = { 0.66, 0.64, 0.75, 1 },
    selected = { 0.28, 0.54, 0.62, 1 },
    selected_line = { 0.68, 0.90, 0.92, 1 }
}

local CONTINUE_PROMPT_SIZE = 12
local CONTINUE_PROMPT_FPS = 4

local function set_color(color)
    love.graphics.setColor(color)
end

local function rect(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

local function draw_box(r, fill, outline, radius)
    set_color(fill)
    love.graphics.rectangle("fill", r.x, r.y, r.w, r.h, radius or 5, radius or 5)
    set_color(outline)
    love.graphics.rectangle("line", r.x, r.y, r.w, r.h, radius or 5, radius or 5)
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

local function animated_asset_id(base_id, time, max_frames)
    local frame_count = 0
    local limit = max_frames or 4

    for index = 1, limit do
        if Assets.images and Assets.images[base_id .. tostring(index)] then
            frame_count = index
        elseif frame_count > 0 then
            break
        end
    end

    if frame_count > 0 then
        local frame = (math.floor((time or 0) * CONTINUE_PROMPT_FPS) % frame_count) + 1
        return base_id .. tostring(frame)
    end

    if Assets.images and Assets.images[base_id] then
        return base_id
    end

    return nil
end

local function draw_animated_image(base_id, r, time, max_frames)
    local asset_id = animated_asset_id(base_id, time, max_frames)
    if not asset_id then
        return false
    end

    return draw_image(asset_id, r)
end

function DialogState:enter(context)
    context = context or {}
    self.world = context.world
    self.dialog = Dialog.new(context.dialog or context.source, context.dialog_id, {
        world = self.world,
        actor = context.actor
    })
    self.selected_response = 1
    self.time = 0
end

function DialogState:update(dt)
    self.time = (self.time or 0) + (dt or 0)

    if self.world and self.world.update_ambient then
        self.world:update_ambient(dt)
    end
end

function DialogState:finish(result)
    GameState.pop(result or (self.dialog and self.dialog.result))
end

function DialogState:advance(response_index)
    local result = self.dialog:advance(response_index)
    self.selected_response = 1
    if result then
        self:finish(result)
    end
end

function DialogState:actionpressed(action)
    local node = self.dialog and self.dialog:current_node()
    if not node then
        self:finish()
        return true
    end

    if node.responses then
        if action == "move_up" or action == "move_left" then
            self.selected_response = 1
            return true
        elseif action == "move_down" or action == "move_right" then
            self.selected_response = math.min(2, #node.responses)
            return true
        elseif action == "confirm" then
            self:advance(self.selected_response)
            return true
        elseif action == "cancel" then
            local result = self.dialog:cancel()
            if result then
                self:finish(result)
            else
                self.selected_response = math.min(2, #node.responses)
            end
            return true
        end
    elseif action == "confirm" then
        self:advance()
        return true
    end

    return action == "menu"
end

function DialogState:keypressed(key)
    return self:actionpressed(Input.action_for_key(key))
end

function DialogState:mousepressed(_, _, button)
    if button == 1 then
        return self:actionpressed("confirm")
    end
    return false
end

function DialogState:draw()
    local node = self.dialog and self.dialog:current_node()
    if not node then
        return
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local margin = 24
    local box_h = 128
    local box_x = margin
    local box_y = height - box_h - margin
    local box_w = width - margin * 2
    local box_rect = rect(box_x, box_y, box_w, box_h)

    if not draw_image("dialog_box_frame", box_rect) then
        draw_box(box_rect, COLORS.box, COLORS.box_line, 5)
    end

    if node.speaker then
        local speaker_w = math.min(220, box_w - 24)
        local speaker_rect = rect(box_x + 16, box_y - 18, speaker_w, 28)
        if not draw_image("dialog_nameplate", speaker_rect) then
            draw_box(speaker_rect, COLORS.speaker, COLORS.speaker_line, 4)
        end
        set_color(COLORS.ink)
        love.graphics.printf(node.speaker, box_x + 28, box_y - 11, speaker_w - 24, "left")
    end

    set_color(COLORS.ink)
    love.graphics.printf(node.text or "", box_x + 24, box_y + 28, box_w - 48, "left")

    if node.responses then
        local response_y = box_y + box_h - 42
        local response_w = math.min(112, (box_w - 64) / 2)
        local has_cursor = Assets.images and Assets.images.dialog_choice_cursor
        for index, response in ipairs(node.responses) do
            if index > 2 then
                break
            end

            local x = box_x + box_w - 24 - (3 - index) * (response_w + 10)
            if index == self.selected_response then
                if has_cursor then
                    draw_image("dialog_choice_cursor", rect(x - 14, response_y + 7, 8, 12))
                elseif not draw_image("dialog_response_selected", rect(x, response_y, response_w, 26)) then
                    draw_box(rect(x, response_y, response_w, 26), COLORS.selected, COLORS.selected_line, 4)
                end
                set_color(COLORS.ink)
            else
                set_color(COLORS.muted)
            end
            love.graphics.printf(response.label or (index == 1 and "Yes" or "No"), x, response_y + 6, response_w, "center")
        end
    else
        local prompt = rect(box_x + box_w - 34, box_y + box_h - 28, CONTINUE_PROMPT_SIZE, CONTINUE_PROMPT_SIZE)
        if not draw_animated_image("dialog_continue", prompt, self.time) then
            set_color(COLORS.muted)
            love.graphics.print("v", prompt.x, prompt.y)
        end
    end
end

return DialogState
