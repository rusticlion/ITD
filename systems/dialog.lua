local Dialog = {}
Dialog.__index = Dialog

local function copy_list(list)
    local copy = {}
    for _, value in ipairs(list or {}) do
        table.insert(copy, value)
    end
    return copy
end

local function require_if_needed(source)
    if type(source) == "string" then
        return require(source)
    end
    return source or {}
end

local function effect_list(value)
    if not value then
        return {}
    elseif value.type then
        return { value }
    end
    return copy_list(value)
end

local function has_condition_fields(condition)
    return condition
        and (
            condition.flag
            or condition.not_flag
            or condition.has_item
            or condition.equipped_item
            or condition.equipped_bp_tag
            or condition.all
            or condition.any
            or condition.none
        )
end

local function flag_matches(world, flag, expected)
    if not flag then
        return true
    end

    local actual = world and world.get_flag and world:get_flag(flag) or false
    if expected == nil then
        expected = true
    end
    return actual == expected
end

local function condition_matches(condition, context)
    condition = condition or {}
    context = context or {}
    local world = context.world
    local player = world and world.player

    if condition.all then
        for _, nested in ipairs(condition.all or {}) do
            if not condition_matches(nested, context) then
                return false
            end
        end
    end

    if condition.any then
        local matched = false
        for _, nested in ipairs(condition.any or {}) do
            if condition_matches(nested, context) then
                matched = true
                break
            end
        end
        if not matched then
            return false
        end
    end

    if condition.none then
        for _, nested in ipairs(condition.none or {}) do
            if condition_matches(nested, context) then
                return false
            end
        end
    end

    if condition.flag and not flag_matches(world, condition.flag, condition.equals) then
        return false
    end

    if condition.not_flag and not flag_matches(world, condition.not_flag, false) then
        return false
    end

    if condition.has_item and not (player and player:hasItem(condition.has_item)) then
        return false
    end

    if condition.equipped_item and not (player and player.equipped == condition.equipped_item) then
        return false
    end

    if condition.equipped_bp_tag
        and not (world and world.has_equipped_bp_tag and world:has_equipped_bp_tag(condition.equipped_bp_tag)) then
        return false
    end

    return true
end

local function load_tree(source, dialog_id)
    local data = require_if_needed(source)
    if data.nodes then
        return data
    end

    local tree = data[dialog_id]
    if not tree then
        error("Unknown dialog tree: " .. tostring(dialog_id))
    end
    return tree
end

function Dialog.new(source, dialog_id, context)
    local tree = load_tree(source, dialog_id)
    local dialog = {
        id = dialog_id,
        tree = tree,
        nodes = tree.nodes or {},
        node_id = tree.start or "start",
        context = context or {},
        pending_effects = {},
        finished = false,
        result = nil
    }

    return setmetatable(dialog, Dialog)
end

function Dialog:condition_matches(condition)
    return condition_matches(condition, self.context)
end

function Dialog:resolve_node_id(node_id)
    local guard = 0

    while node_id do
        guard = guard + 1
        if guard > 32 then
            error("Dialog branch loop near node " .. tostring(node_id))
        end

        local node = self.nodes[node_id]
        if not node then
            error("Unknown dialog node: " .. tostring(node_id))
        end

        local branch_target = nil
        for _, branch in ipairs(node.branches or {}) do
            local condition = branch.condition or branch.when
            if not condition and has_condition_fields(branch) then
                condition = branch
            end

            if (not condition or self:condition_matches(condition)) and branch.next then
                branch_target = branch.next
                break
            end
        end

        if not branch_target then
            return node_id
        end
        node_id = branch_target
    end

    return nil
end

function Dialog:current_node()
    if self.finished then
        return nil
    end

    local resolved = self:resolve_node_id(self.node_id)
    self.node_id = resolved
    return resolved and self.nodes[resolved] or nil
end

function Dialog:add_effects(effects)
    for _, effect in ipairs(effect_list(effects)) do
        table.insert(self.pending_effects, effect)
    end
end

function Dialog:finish(finish_data)
    finish_data = finish_data or {}
    self:add_effects(finish_data.effects)
    self.finished = true
    self.result = {
        type = "dialog_result",
        dialog_id = self.id,
        effects = copy_list(self.pending_effects),
        result = finish_data.result
    }
    return self.result
end

function Dialog:advance(response_index)
    local node = self:current_node()
    if not node then
        return self:finish()
    end

    if node.responses then
        local response = node.responses[response_index or 1]
        if not response then
            return nil
        end

        self:add_effects(response.effects)
        if response.finish then
            return self:finish(response.finish)
        elseif response.result then
            return self:finish({ result = response.result })
        elseif response.next then
            self.node_id = response.next
            return nil
        end
        return self:finish()
    end

    self:add_effects(node.effects)
    if node.finish then
        return self:finish(node.finish)
    elseif node.result then
        return self:finish({ result = node.result })
    elseif node.next then
        self.node_id = node.next
        return nil
    end

    return self:finish()
end

function Dialog:cancel()
    local node = self:current_node()
    if node and node.responses and #node.responses >= 2 then
        return self:advance(2)
    end
    return nil
end

return Dialog
