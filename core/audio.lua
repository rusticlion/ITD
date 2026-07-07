-- Audio cue playback keyed by cue id (see data/audio_cues.lua).
-- Until real sound files exist, cues are synthesized on first use — programmer
-- art for the ears. Dropping assets/sounds/<cue_id>.ogg or .wav overrides the
-- synth with no code change. Headless-safe: without love.audio, play() still
-- validates the cue id (and feeds the test hook) but produces no sound.

local Cues = require("data.audio_cues")

local Audio = {
    enabled = true,
    master_volume = 0.8,
    on_play = nil, -- test/debug hook: function(cue_id, opts)
    sources = {},
    warned = {}
}

local SAMPLE_RATE = 44100
local OVERRIDE_DIRECTORY = "assets/sounds/"
local TWO_PI = math.pi * 2

local function audio_available()
    return love and love.audio and love.sound
end

local function warn_once(key, message)
    if not Audio.warned[key] then
        Audio.warned[key] = true
        print("[Audio] " .. message)
    end
end

local function layer_sample(layer, t, phase)
    local wave = layer.wave or "sine"
    if wave == "noise" then
        return math.random() * 2 - 1
    end

    if wave == "square" then
        return math.sin(phase) >= 0 and 1 or -1
    end

    if wave == "triangle" then
        local cycle = (phase / TWO_PI) % 1
        return 4 * math.abs(cycle - 0.5) - 1
    end

    return math.sin(phase)
end

local function synthesize(cue)
    local layers = cue.layers or {}
    local total_duration = 0
    for _, layer in ipairs(layers) do
        total_duration = math.max(total_duration, layer.duration or 0)
    end

    if total_duration <= 0 then
        return nil
    end

    local sample_count = math.floor(total_duration * SAMPLE_RATE)
    local data = love.sound.newSoundData(sample_count, SAMPLE_RATE, 16, 1)
    local attack_samples = math.floor(0.002 * SAMPLE_RATE)
    local phases = {}

    for i = 0, sample_count - 1 do
        local t = i / SAMPLE_RATE
        local sample = 0

        for index, layer in ipairs(layers) do
            local duration = layer.duration or 0
            if t < duration then
                local progress = t / duration
                local freq = layer.freq or 440
                if layer.freq_end then
                    freq = freq + (layer.freq_end - freq) * progress
                end
                -- Integrated phase keeps glides continuous.
                phases[index] = (phases[index] or 0) + TWO_PI * freq / SAMPLE_RATE
                local envelope = (1 - progress) ^ (layer.curve or 2)
                sample = sample + layer_sample(layer, t, phases[index]) * (layer.volume or 0.5) * envelope
            end
        end

        if i < attack_samples then
            sample = sample * (i / attack_samples)
        end

        data:setSample(i, math.max(-1, math.min(sample, 1)))
    end

    return love.audio.newSource(data, "static")
end

local function load_override(cue_id)
    if not (love and love.filesystem) then
        return nil
    end

    for _, extension in ipairs({ ".ogg", ".wav" }) do
        local path = OVERRIDE_DIRECTORY .. cue_id .. extension
        if love.filesystem.getInfo(path) then
            local ok, source = pcall(love.audio.newSource, path, "static")
            if ok then
                return source
            end
            warn_once("override_" .. cue_id, "Failed to load override " .. path)
        end
    end

    return nil
end

local function get_source(cue_id, cue)
    local cached = Audio.sources[cue_id]
    if cached ~= nil then
        return cached or nil -- false caches a failed build
    end

    local source = load_override(cue_id) or synthesize(cue)
    Audio.sources[cue_id] = source or false
    return source
end

-- opts: { pitch = multiplier, volume = multiplier }
-- Returns true when the cue exists (even headless), nil for unknown cues.
function Audio.play(cue_id, opts)
    local cue = Cues[cue_id]
    if not cue then
        warn_once("missing_" .. tostring(cue_id), "Unknown audio cue '" .. tostring(cue_id) .. "'")
        return nil
    end

    if Audio.on_play then
        Audio.on_play(cue_id, opts)
    end

    if not Audio.enabled or not audio_available() then
        return true
    end

    local source = get_source(cue_id, cue)
    if not source then
        return true
    end

    local instance = source:clone()
    local variance = cue.pitch_variance or 0
    local pitch = (opts and opts.pitch or 1) * (1 + (math.random() * 2 - 1) * variance)
    instance:setPitch(math.max(pitch, 0.05))
    instance:setVolume((cue.volume or 0.5) * (opts and opts.volume or 1) * Audio.master_volume)
    instance:play()
    return true
end

function Audio.set_volume(volume)
    Audio.master_volume = math.max(0, math.min(tonumber(volume) or 1, 1))
end

function Audio.set_enabled(enabled)
    Audio.enabled = enabled ~= false
end

-- Authoring aid: surface malformed cue definitions loudly, in the spirit of
-- content validation elsewhere in the project.
function Audio.validate()
    local errors = {}
    for cue_id, cue in pairs(Cues) do
        if type(cue.layers) ~= "table" or #cue.layers == 0 then
            table.insert(errors, cue_id .. ": no layers")
        else
            for index, layer in ipairs(cue.layers) do
                if (layer.duration or 0) <= 0 then
                    table.insert(errors, cue_id .. " layer " .. index .. ": missing duration")
                end
                if layer.wave ~= "noise" and (layer.freq or 0) <= 0 then
                    table.insert(errors, cue_id .. " layer " .. index .. ": missing freq")
                end
            end
        end
    end
    return errors
end

return Audio
