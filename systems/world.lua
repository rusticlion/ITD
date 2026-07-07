local Player = require("systems.player")
local Room = require("systems.room")
local Catalog = require("systems.bodypart_catalog")
local Display = require("core.display")
local Save = require("core.save")
local OverworldCamera = require("systems.overworld_camera")

local World = {}
World.__index = World

local DEFAULT_ROOM = "data.rooms.basement_1"
local MESSAGE_DURATION = 4
local DEFAULT_DREAMFORM = {
    head = "part_inst_dreamer_head",
    body = "part_inst_dreamer_body",
    arm_l = "part_inst_dreamer_fore_hand",
    arm_r = "part_inst_dreamer_back_hand",
    leg_l = "part_inst_dreamer_front_foot",
    leg_r = "part_inst_dreamer_back_foot"
}
local DEFAULT_PARTS = {
    part_inst_dreamer_head = { def_id = "dreamer_head", status = "healthy", source = "initial" },
    part_inst_dreamer_body = { def_id = "dreamer_body", status = "healthy", source = "initial" },
    part_inst_dreamer_fore_hand = { def_id = "dreamer_fore_hand", status = "healthy", source = "initial" },
    part_inst_dreamer_back_hand = { def_id = "dreamer_back_hand", status = "healthy", source = "initial" },
    part_inst_dreamer_front_foot = { def_id = "dreamer_front_foot", status = "healthy", source = "initial" },
    part_inst_dreamer_back_foot = { def_id = "dreamer_back_foot", status = "healthy", source = "initial" }
}
local DREAMFORM_SLOT_TYPES = {
    head = "HEAD",
    body = "BODY",
    arm_l = "ARM",
    arm_r = "ARM",
    leg_l = "LEG",
    leg_r = "LEG"
}
local DREAMFORM_SLOT_ORDER = { "head", "body", "arm_l", "arm_r", "leg_l", "leg_r" }
local MOVE_ACTIONS = {
    move_up = { 0, -1 },
    move_down = { 0, 1 },
    move_left = { -1, 0 },
    move_right = { 1, 0 }
}
local MOVE_KEYS = {
    up = "move_up",
    w = "move_up",
    down = "move_down",
    s = "move_down",
    left = "move_left",
    a = "move_left",
    right = "move_right",
    d = "move_right"
}

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

local function part_def_id(part)
    return type(part) == "table" and (part.def_id or part.id) or part
end

local function part_type(part)
    if type(part) == "table" and part.type then
        return tostring(part.type):upper()
    end

    return nil
end

local function discover_part(run, part)
    local def_id = part_def_id(part)
    if not def_id then
        return
    end

    run.discovered_parts = run.discovered_parts or {}
    run.discovered_parts[def_id] = true
end

local function prune_unequipped_parts(run)
    local equipped = {}
    for _, instance_id in pairs(run.dreamform or {}) do
        if instance_id then
            equipped[instance_id] = true
        end
    end

    for instance_id in pairs(run.parts or {}) do
        if not equipped[instance_id] then
            run.parts[instance_id] = nil
        end
    end
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
        discover_part(run, run.parts[instance_id])
    end

    for _, part in pairs(run.parts) do
        discover_part(run, part)
    end

    prune_unequipped_parts(run)

    return run
end

function World.new(options)
    options = options or {}
    local save_data = copy_table(options.save or {})
    local saved_run = copy_table(save_data.run or {})
    local saved_player = copy_table(options.player
        or (options.run and options.run.player)
        or saved_run.player
        or {})
    local player_x = options.player_x or saved_player.x
    local player_y = options.player_y or saved_player.y
    local spawn_id = options.spawn
    if not spawn_id and (player_x == nil or player_y == nil) then
        spawn_id = "start"
    end
    local world = {
        room_module = options.room or saved_run.current_room or DEFAULT_ROOM,
        player = Player.new(player_x or 1, player_y or 1),
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
        camera = OverworldCamera.new()
    }

    setmetatable(world, World)
    world:apply_player_state(saved_player)
    world:load_room(world.room_module)
    if spawn_id then
        world:place_player_at_spawn(spawn_id)
    end
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
    self:update_camera()
end

function World:set_player_tile(x, y)
    self.player:clear_direction_input()
    self.player.x = x
    self.player.y = y
    self.player.render_x = x
    self.player.render_y = y
    self.player.move_from_x = x
    self.player.move_from_y = y
    self.player.move_to_x = x
    self.player.move_to_y = y
    self.player.moving = false
    self:update_camera()
end

function World:place_player_at_spawn(spawn_id)
    local x, y
    if self.room then
        x, y = self.room:spawn_tile(spawn_id)
    end
    if not (x and y) then
        error(string.format(
            "Room '%s' has no spawn named '%s'.",
            tostring(self.room and self.room.id or self.room_module),
            tostring(spawn_id)
        ))
    end
    if self.room:is_blocked(x, y) then
        error(string.format(
            "Spawn '%s' in room '%s' is blocked at %s,%s.",
            tostring(spawn_id),
            tostring(self.room.id),
            tostring(x),
            tostring(y)
        ))
    end

    self:set_player_tile(x, y)
end

function World:reload_room()
    local room_module = self.room_module
    local player_state = self:player_save_data()
    if type(room_module) == "string" then
        package.loaded[room_module] = nil
    end

    self:load_room(room_module)
    self:set_player_tile(player_state.x, player_state.y)
    self:apply_player_state(player_state)
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

    local px, py = self.player:pixel_position(self.room.tile_size)
    local lock_anchor = self.room:property("camera_lock_anchor")
    local unlock_flag = self.room:property("camera_unlock_flag")
    local camera_locked = lock_anchor ~= nil
        and (unlock_flag == nil or not self:get_flag(unlock_flag))

    if camera_locked then
        px, py = self.room:region_center(lock_anchor, "camera_anchor")
        if not (px and py) then
            error(string.format(
                "Room '%s' camera lock references invalid anchor '%s'.",
                tostring(self.room.id),
                tostring(lock_anchor)
            ))
        end
    end

    if self.camera_tracking_locked ~= camera_locked then
        if self.camera_tracking_locked == true and camera_locked == false then
            local player_x, player_y = self.player:pixel_position(self.room.tile_size)
            self.camera:adopt_follow_target(player_x, player_y)
        else
            self.camera:reset_follow_anchor()
        end
        self.camera_tracking_locked = camera_locked
    end

    self.camera:update(
        self.room,
        px,
        py,
        Display.WIDTH,
        Display.HEIGHT)
end

function World:draw()
    self.camera:attach()
    if self.room then
        self.room:draw(self)
    end
    local px, py = self.player:pixel_position(self.room and self.room.tile_size or 32)
    self.camera:draw_world_guides(self.room, px, py)
    if self.debug_overlay and self.room and self.room.draw_debug_overlay then
        self.room:draw_debug_overlay(self)
    end
    self.camera:detach()

    self:draw_hud()
end

function World:draw_hud()
    if self.player.equipped then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("[" .. self.player.equipped .. "]", 10, 10)
    end

    if self.message then
        local width = Display.WIDTH
        local height = Display.HEIGHT
        local box_height = 54
        love.graphics.setColor(0.05, 0.05, 0.08, 0.92)
        love.graphics.rectangle("fill", 16, height - box_height - 16, width - 32, box_height, 4, 4)
        love.graphics.setColor(0.8, 0.78, 0.88, 1)
        love.graphics.rectangle("line", 16, height - box_height - 16, width - 32, box_height, 4, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(self.message, 28, height - box_height, width - 56, "left")
    end

    if self.camera and self.camera.show_guides then
        local label = self.camera:debug_label()
        love.graphics.setColor(0.04, 0.04, 0.07, 0.9)
        love.graphics.rectangle("fill", Display.WIDTH - 238, 10, 228, 24, 3, 3)
        love.graphics.setColor(0.9, 0.89, 0.98, 1)
        love.graphics.printf(label, Display.WIDTH - 232, 16, 216, "center")
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

    for _, instance_id in pairs(self.run.dreamform or {}) do
        local instance = self.run.parts and self.run.parts[instance_id]
        local part_def = instance and Catalog.part_definition(instance.def_id)
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
        if result.flag then
            self:set_flag(result.flag, true)
        end
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

function World:eligible_dreamform_slots_for_part(part)
    local wanted_type = part_type(part)
    local slots = {}

    for _, slot_id in ipairs(DREAMFORM_SLOT_ORDER) do
        if not wanted_type or DREAMFORM_SLOT_TYPES[slot_id] == wanted_type then
            table.insert(slots, slot_id)
        end
    end

    return slots
end

function World:claim_part_into_slot(part, slot_id, encounter_id)
    local def_id = part_def_id(part)
    if not def_id then
        return nil, "missing_def_id"
    end

    if type(part) == "table" and part.status == "maimed" then
        return nil, "maimed_part_unclaimable"
    end

    local wanted_type = part_type(part)
    local slot_type = slot_id and DREAMFORM_SLOT_TYPES[slot_id]
    if not slot_type then
        return nil, "unknown_slot"
    end

    if wanted_type and wanted_type ~= slot_type then
        return nil, "slot_type_mismatch"
    end

    self.run.parts = self.run.parts or {}
    self.run.dreamform = self.run.dreamform or copy_table(DEFAULT_DREAMFORM)
    self.run.discovered_parts = self.run.discovered_parts or {}
    self.run.next_part_instance_index = self.run.next_part_instance_index or 1

    local replaced_instance_id = self.run.dreamform[slot_id]
    local replaced_part = replaced_instance_id and self.run.parts[replaced_instance_id] and copy_table(self.run.parts[replaced_instance_id])
    if replaced_part then
        replaced_part.instance_id = replaced_instance_id
    end

    if replaced_instance_id then
        self.run.parts[replaced_instance_id] = nil
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
        status = type(part) == "table" and recover_status(part.status) or "healthy",
        name = type(part) == "table" and part.name or nil,
        type = wanted_type,
        claimed_from = encounter_id
    }
    self.run.dreamform[slot_id] = instance_id
    discover_part(self.run, def_id)

    return instance_id, {
        instance_id = instance_id,
        def_id = def_id,
        slot_id = slot_id,
        replaced_instance_id = replaced_instance_id,
        replaced_part = replaced_part
    }
end

function World:add_claimed_part(part, encounter_id, slot_id)
    local slots = self:eligible_dreamform_slots_for_part(part)
    local target_slot = slot_id or slots[1]
    local instance_id = self:claim_part_into_slot(part, target_slot, encounter_id)
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
        claimed_part = copy_table(result.claimed_part),
        claimed_slot = result.claimed_slot,
        replaced_part = copy_table(result.replaced_part)
    })

    local recovered_parts = self:apply_player_part_statuses(result.player_parts)

    local claimed_instance_id
    local claim_summary
    local claim_error
    if result.claimed_part then
        claimed_instance_id, claim_summary = self:claim_part_into_slot(result.claimed_part, result.claimed_slot, result.encounter_id)
        if not claimed_instance_id then
            claim_error = claim_summary
            claim_summary = nil
            print("[World] Claim failed: " .. tostring(claim_error))
        end
    end

    if result.encounter_id then
        local encounter_state = self.run.encounters[result.encounter_id] or {}
        encounter_state.last_outcome = result.outcome
        encounter_state.resolved = encounter_state.resolved
            or result.outcome == "victory"
            or result.outcome == "scripted"
        encounter_state.claimable_parts = copy_table(result.claimable_parts or {})
        encounter_state.claimed_part = claim_summary and copy_table(claim_summary) or nil
        self.run.encounters[result.encounter_id] = encounter_state
    end

    if result.outcome == "victory" then
        if claim_summary then
            self:set_message("Combat won. Your dreamform changes shape.")
        else
            self:set_message("Combat won. Your dreamform knits itself back together.")
        end
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
        claimed_slot = result.claimed_slot,
        claim_summary = copy_table(claim_summary),
        claim_error = claim_error,
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
    local move = MOVE_ACTIONS[action]
    if move then
        self.player:press_direction(action, move[1], move[2])
        return true
    end

    if action == "confirm" then
        self:interact()
        return true
    end

    return false
end

function World:actionreleased(action)
    if MOVE_ACTIONS[action] then
        return self.player:release_direction(action)
    end
    return false
end

function World:keypressed(key)
    if key == "f2" and self.camera then
        local override = self.camera:cycle_debug_override()
        self:update_camera()
        self:set_message(override and ("Camera override: " .. override) or "Camera override cleared.")
        return
    elseif key == "f3" and self.camera then
        self.camera:toggle_guides()
        return
    end

    if key == "space" or key == "return" then
        self:interact()
        return
    end

    local action = MOVE_KEYS[key]
    local move = action and MOVE_ACTIONS[action]
    if move then
        self.player:press_direction(action, move[1], move[2])
    end
end

function World:keyreleased(key)
    local action = MOVE_KEYS[key]
    if action then
        return self.player:release_direction(action)
    end
    return false
end

return World
