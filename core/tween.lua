-- Lightweight tweens and timers.
-- Each owner (a state, ScreenFX, a juice director) runs its own group and is
-- responsible for calling group:update(dt). No love dependency; safe in CLI tests.

local Tween = {}

Tween.easing = {
    linear = function(t)
        return t
    end,
    out_quad = function(t)
        return 1 - (1 - t) * (1 - t)
    end,
    in_cubic = function(t)
        return t * t * t
    end,
    out_cubic = function(t)
        local u = 1 - t
        return 1 - u * u * u
    end,
    out_back = function(t)
        local c1 = 1.70158
        local u = t - 1
        return 1 + (c1 + 1) * u * u * u + c1 * u * u
    end
}

function Tween.lerp(a, b, t)
    return a + (b - a) * t
end

local Group = {}
Group.__index = Group

function Tween.group()
    return setmetatable({
        items = {},
        pending = nil,
        updating = false
    }, Group)
end

local function add_item(group, item)
    if group.updating then
        group.pending = group.pending or {}
        table.insert(group.pending, item)
    else
        table.insert(group.items, item)
    end
    return item
end

-- Animate numeric fields on target from their current values to props.
-- opts: { ease = "out_cubic", delay = seconds, on_complete = fn }
function Group:to(target, duration, props, opts)
    opts = opts or {}
    local item = {
        kind = "tween",
        target = target,
        duration = math.max(duration or 0, 0),
        delay = math.max(opts.delay or 0, 0),
        elapsed = 0,
        from = nil, -- captured when the delay ends, so late starts see fresh values
        props = props or {},
        ease = Tween.easing[opts.ease or "out_cubic"] or Tween.easing.out_cubic,
        on_complete = opts.on_complete
    }
    return add_item(self, item)
end

function Group:after(delay, fn)
    local item = {
        kind = "timer",
        delay = math.max(delay or 0, 0),
        elapsed = 0,
        fn = fn
    }
    return add_item(self, item)
end

function Group.cancel(item)
    if item then
        item.cancelled = true
    end
end

local function finish_tween(item)
    for key, value in pairs(item.props) do
        item.target[key] = value
    end
    if item.on_complete then
        item.on_complete(item.target)
    end
end

local function step_item(item, dt)
    if item.cancelled then
        return true
    end

    item.elapsed = item.elapsed + dt

    if item.kind == "timer" then
        if item.elapsed >= item.delay then
            if item.fn then
                item.fn()
            end
            return true
        end
        return false
    end

    if item.elapsed < item.delay then
        return false
    end

    if not item.from then
        item.from = {}
        for key in pairs(item.props) do
            item.from[key] = item.target[key] or 0
        end
    end

    local progress = item.elapsed - item.delay
    if progress >= item.duration or item.duration <= 0 then
        finish_tween(item)
        return true
    end

    local t = item.ease(progress / item.duration)
    for key, value in pairs(item.props) do
        item.target[key] = Tween.lerp(item.from[key], value, t)
    end
    return false
end

function Group:update(dt)
    if dt == nil or dt <= 0 then
        return
    end

    self.updating = true
    local survivors = {}
    for _, item in ipairs(self.items) do
        if not step_item(item, dt) then
            table.insert(survivors, item)
        end
    end
    self.items = survivors
    self.updating = false

    if self.pending then
        for _, item in ipairs(self.pending) do
            table.insert(self.items, item)
        end
        self.pending = nil
    end
end

function Group:clear()
    self.items = {}
    self.pending = nil
end

function Group:count()
    return #self.items + (self.pending and #self.pending or 0)
end

return Tween
