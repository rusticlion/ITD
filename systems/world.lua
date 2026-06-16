local Player = require("systems.player")
local Room = require("systems.room")
local Save = require("core.save")

local World = {}
World.__index = World

local DEFAULT_ROOM = "data.rooms.basement_1"
local MESSAGE_DURATION = 4
local DEFAULT_DREAMFORM = {
    head = "part_inst_dreamer_head",
    body = "part_inst_dreamer_body",
    arm_l = "part_inst_dreamer_left_arm",
    arm_r = "part_inst_dreamer_right_arm",
    leg_l = "part_inst_dreamer_left_leg",
    leg_r = "part_inst_dreamer_right_leg"
}
local DEFAULT_PARTS = {
    part_inst_dreamer_head = { def_id = "dreamer_head", status = "healthy", source = "initial" },
    part_inst_dreamer_body = { def_id = "dreamer_body", status = "healthy", source = "initial" },
    part_inst_dreamer_left_arm = { def_id = "dreamer_left_arm", status = "healthy", source = "initial" },
    part_inst_dreamer_right_arm = { def_id = "dreamer_right_arm", status = "healthy", source = "initial" },
    part_inst_dreamer_left_leg = { def_id = "dreamer_left_leg", status = "healthy", source = "initial" },
    part_inst_dreamer_right_leg = { def_id = "dreamer_right_leg", status = "healthy", source = "initial" }
}

local function clamp(value, min_value, max_value)
    return math.max(min_value, math.min(max_value, value))
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

local function recover_status(status)
    if status == "maimed" then
        return "wounded"
    elseif status == "wounded" then
        return "healthy"
    end

    return "healthy"
end

local function normalize_run_state(run)
    run = run or {}
    run.dreamform = run.dreamform or copy_table(DEFAULT_DREAMFORM)
    run.parts = run.parts or {}
    run.discovered_parts = run.discovered_parts or {}
    run.encounters = run.encounters or {}
    run.combat_history = run.combat_history or {}
    run.next_part_instance_index = run.next_part_instance_index or 1

    for slot, instance_id in pairs(DEFAULT_DREAMFORM) do
        run.dreamform[slot] = run.dreamform[slot] or instance_id
    end

    for instance_id, part in pairs(DEFAULT_PARTS) do
        if not run.parts[instance_id] then
            run.parts[instance_id] = copy_table(part)
        end
        run.parts[instance_id].instance_id = instance_id
        run.parts[instance_id].status = run.parts[instance_id].status or "healthy"
        run.discovered_parts[run.parts[instance_id].def_id] = true
    end

    for _, part in pairs(run.parts) do
        if part and part.def_id then
            run.discovered_parts[part.def_id] = true
        end
    end

    return run
end

function World.new(options)
    options = options or {}
    local save_data = copy_table(options.save or {})
    local saved_run = copy_table(save_data.run or {})
    local saved_player = saved_run.player or {}
    local world = {
        room_module = options.room or saved_run.current_room or DEFAULT_ROOM,
        player = Player.new(options.player_x or saved_player.x or 5, options.player_y or saved_player.y or 5),
        inventory = {},
        profile = copy_table(save_data.profile or options.profile or {}),
        run = normalize_run_state(copy_table(options.run or saved_run)),
        on_encounter = options.on_encounter,
        on_dialog = options.on_dialog,
        flags = copy_table(options.flags or saved_run.flags or {}),
        room_states = copy_table(options.room_states or save_data.rooms or {}),
        autosave_enabled = options.autosave ~= false and Save.available(options.save_backend),
        save_path = options.save_path or Save.DEFAULT_PATH,
        save_backend = options.save_backend,
        last_save_reason = nil,
        last_save_error = nil,
        message = nil,
        message_timer = 0,
        camera = { x = 0, y = 0 }
    }

    setmetatable(world, World)
    world:apply_player_state(saved_player)
    world:load_room(world.room_module)
    return world
end

function World:apply_player_state(state)
    state = state or {}
    self.player.facing = state.facing or self.player.facing
    self.player.inventory = copy_table(state.inventory or self.player.inventory or {})
    self.player.equipped = state.equipped
end

function World:load_room(room_module)
    self.room_module = room_module
    self.run.current_room = room_module
    self.room = Room.new(room_module, self)
end

function World:player_save_data()
    return {
        x = self.player.x,
        y = self.player.y,
        facing = self.player.facing,
        inventory = copy_table(self.player.inventory or {}),
        equipped = self.player.equipped
    }
end

function World:save_data()
    local run = copy_table(self.run or {})
    run.current_room = self.room_module
    run.player = self:player_save_data()
    run.flags = copy_table(self.flags or {})

    return {
        save_version = Save.VERSION,
        profile = copy_table(self.profile or {}),
        run = run,
        rooms = copy_table(self.room_states or {})
    }
end

function World:autosave(reason)
    if not self.autosave_enabled then
        return false, "autosave disabled"
    end

    local ok, err = Save.write(self:save_data(), self.save_path, self.save_backend)
    if ok then
        self.last_save_reason = reason
        self.last_save_error = nil
    else
        self.last_save_error = err
        print("Autosave failed: " .. tostring(err))
    end

    return ok, err
end

function World:update(dt)
    self.player:update(dt, self.room)
    if self.room then
        self.room:update(self, dt)
    end

    if self.message_timer > 0 then
        self.message_timer = math.max(0, self.message_timer - (dt or 0))
        if self.message_timer == 0 then
            self.message = nil
        end
    end

    self:update_camera()
end

function World:update_ambient(dt)
    if self.room and self.room.update_ambient then
        self.room:update_ambient(self, dt)
    end

    self:update_camera()
end

function World:update_camera()
    if not (love and love.graphics and self.room) then
        return
    end

    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local map_width = self.room.width * self.room.tile_size
    local map_height = self.room.height * self.room.tile_size
    local px, py = self.player:pixel_position(self.room.tile_size)

    self.camera.x = clamp(px - width / 2, 0, math.max(0, map_width - width))
    self.camera.y = clamp(py - height / 2, 0, math.max(0, map_height - height))
end

function World:draw()
    love.graphics.push()
    love.graphics.translate(-math.floor(self.camera.x), -math.floor(self.camera.y))
    if self.room then
        self.room:draw(self)
    end
    love.graphics.pop()

    self:draw_hud()
end

function World:draw_hud()
    if self.player.equipped then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("[" .. self.player.equipped .. "]", 10, 10)
    end

    if self.message then
        local width = love.graphics.getWidth()
        local height = love.graphics.getHeight()
        local box_height = 54
        love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
        love.graphics.rectangle("fill", 16, height - box_height - 16, width - 32, box_height, 4, 4)
        love.graphics.setColor(0.8, 0.78, 0.88, 1)
        love.graphics.rectangle("line", 16, height - box_height - 16, width - 32, box_height, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(self.message, 28, height - box_height, width - 56, "left")
    end
end

function World:set_message(message)
    if not message then
        return
    end

    self.message = message
    self.message_timer = MESSAGE_DURATION
    print(message)
end

function World:get_flag(flag)
    return self.flags and self.flags[flag] == true
end

function World:set_flag(flag, value)
    if not flag then
        return
    end

    self.flags[flag] = value ~= false
end

function World:has_equipped_bp_tag(tag)
    if not tag then
        return false
    end

    local ok, definitions = pcall(require, "data.combat.v2_demo_parts")
    if not ok or not definitions.parts then
        return false
    end

    for _, instance_id in pairs(self.run.dreamform or {}) do
        local instance = self.run.parts and self.run.parts[instance_id]
        local part_def = instance and definitions.parts[instance.def_id]
        for _, existing in ipairs((part_def and part_def.tags) or instance and instance.tags or {}) do
            if existing == tag then
                return true
            end
        end
    end

    return false
end

function World:handle_result(result)
    if not result then
        self:set_message("There is nothing special here.")
        return
    end

    if result.type == "item" then
        self.player:addItem(result.item)
        self:set_message(result.text or ("Found: " .. tostring(result.item) .. "!"))
        self:autosave("item")
    elseif result.type == "encounter" then
        self:set_message(result.text or ("Encounter: " .. tostring(result.encounter_id)))
        self:start_encounter(result)
    elseif result.type == "dialog" then
        self:start_dialog(result)
    elseif result.type == "passage" then
        self:set_message(result.text or "A passage opens.")
        self:autosave("passage")
    else
        self:set_message(result.text)
    end
end

function World:start_dialog(dialog)
    if self.on_dialog then
        self.on_dialog(dialog, self)
    else
        self:set_message("There is something to say here.")
    end
end

function World:apply_dialog_effect(effect)
    if not effect then
        return
    end

    if effect.type == "set_flag" then
        self:set_flag(effect.flag, effect.value)
    elseif effect.type == "clear_flag" then
        self:set_flag(effect.flag, false)
    elseif effect.type == "give_item" or effect.type == "item" then
        self.player:addItem(effect.item)
    end
end

function World:apply_dialog_result(dialog_result)
    if not (dialog_result and dialog_result.type == "dialog_result") then
        return
    end

    for _, effect in ipairs(dialog_result.effects or {}) do
        self:apply_dialog_effect(effect)
    end

    self:autosave("dialog")

    if dialog_result.result then
        self:handle_result(dialog_result.result)
    end
end

function World:start_encounter(encounter)
    if not encounter then
        return
    end

    local encounter_id = encounter.encounter_id
    local encounter_state = encounter_id and self.run.encounters[encounter_id]
    if encounter_state and encounter_state.resolved then
        self:set_message("The dream here has already gone quiet.")
        return
    end

    if self.on_encounter then
        self.on_encounter(encounter, self)
    end
end

function World:active_part_instance_for_def(def_id)
    if not def_id then
        return nil
    end

    for _, instance_id in pairs(self.run.dreamform or {}) do
        local instance = self.run.parts and self.run.parts[instance_id]
        if instance and instance.def_id == def_id then
            return instance_id, instance
        end
    end

    return nil
end

function World:apply_player_part_statuses(parts)
    local recovered_parts = {}

    for _, part in ipairs(parts or {}) do
        local instance_id = part.instance_id
        local instance = instance_id and self.run.parts[instance_id]

        if not instance then
            instance_id, instance = self:active_part_instance_for_def(part.def_id or part.id)
        end

        if instance then
            local combat_status = part.status or "healthy"
            local recovered_status = recover_status(combat_status)
            instance.last_combat_status = combat_status
            instance.status = recovered_status
            table.insert(recovered_parts, {
                instance_id = instance_id,
                def_id = instance.def_id,
                name = part.name or instance.name or instance.def_id,
                combat_status = combat_status,
                recovered_status = recovered_status
            })
        end
    end

    return recovered_parts
end

function World:add_claimed_part(part, encounter_id)
    local def_id = type(part) == "table" and (part.def_id or part.id) or part
    if not def_id then
        return nil
    end

    local instance_id = "part_inst_" .. tostring(def_id)
    if self.run.parts[instance_id] then
        repeat
            instance_id = "part_inst_" .. tostring(def_id) .. "_" .. tostring(self.run.next_part_instance_index)
            self.run.next_part_instance_index = self.run.next_part_instance_index + 1
        until not self.run.parts[instance_id]
    end

    self.run.parts[instance_id] = {
        instance_id = instance_id,
        def_id = def_id,
        status = type(part) == "table" and (part.status or "healthy") or "healthy",
        name = type(part) == "table" and part.name or nil,
        type = type(part) == "table" and part.type or nil,
        claimed_from = encounter_id
    }
    self.run.discovered_parts = self.run.discovered_parts or {}
    self.run.discovered_parts[def_id] = true

    return instance_id
end

function World:apply_combat_result(result)
    if not (result and result.type == "combat_result") then
        return
    end

    self.last_combat_result = result
    table.insert(self.run.combat_history, {
        encounter_id = result.encounter_id,
        outcome = result.outcome,
        claimable_parts = copy_table(result.claimable_parts or {}),
        claimed_part = copy_table(result.claimed_part)
    })

    local recovered_parts = self:apply_player_part_statuses(result.player_parts)

    local claimed_instance_id
    if result.claimed_part then
        claimed_instance_id = self:add_claimed_part(result.claimed_part, result.encounter_id)
    end

    if result.encounter_id then
        local encounter_state = self.run.encounters[result.encounter_id] or {}
        encounter_state.last_outcome = result.outcome
        encounter_state.resolved = encounter_state.resolved
            or result.outcome == "victory"
            or result.outcome == "scripted"
        encounter_state.claimable_parts = copy_table(result.claimable_parts or {})
        encounter_state.claimed_part = claimed_instance_id or result.claimed_part
        self.run.encounters[result.encounter_id] = encounter_state
    end

    if result.outcome == "victory" then
        self:set_message("Combat won. Your dreamform knits itself back together.")
    elseif result.outcome == "defeat" then
        self:set_message("Combat lost. Your dreamform knits enough to keep going.")
    elseif result.outcome == "fled" then
        self:set_message("You pull away from the fight. Your dreamform steadies.")
    else
        self:set_message("Combat ended. Your dreamform steadies.")
    end

    self:autosave("combat_result")

    return {
        type = "post_combat_summary",
        outcome = result.outcome,
        encounter_id = result.encounter_id,
        recovered_parts = recovered_parts,
        claimable_parts = copy_table(result.claimable_parts or {}),
        claimed_part = result.claimed_part,
        claimed_instance_id = claimed_instance_id
    }
end

function World:interact()
    if not self.room then
        return
    end

    local front_x, front_y = self.player:front_tile()
    local actor = self.room:interactable_at(front_x, front_y)
        or self.room:interactable_at(self.player.x, self.player.y)

    if actor then
        self:handle_result(actor:interact(self, self.player))
    else
        self:set_message("There is nothing special here.")
    end
end

function World:actionpressed(action)
    if action == "confirm" then
        self:interact()
        return true
    elseif action == "move_up" then
        self.player:try_move(0, -1, self.room)
        return true
    elseif action == "move_down" then
        self.player:try_move(0, 1, self.room)
        return true
    elseif action == "move_left" then
        self.player:try_move(-1, 0, self.room)
        return true
    elseif action == "move_right" then
        self.player:try_move(1, 0, self.room)
        return true
    end

    return false
end

function World:keypressed(key)
    if key == "space" or key == "return" then
        self:interact()
        return
    end

    if key == "up" then
        self.player:try_move(0, -1, self.room)
    elseif key == "down" then
        self.player:try_move(0, 1, self.room)
    elseif key == "left" then
        self.player:try_move(-1, 0, self.room)
    elseif key == "right" then
        self.player:try_move(1, 0, self.room)
    end
end

function World:keyreleased(_)
end

return World
