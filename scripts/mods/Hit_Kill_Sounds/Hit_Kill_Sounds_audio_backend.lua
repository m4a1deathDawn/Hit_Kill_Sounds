-- luacheck: globals get_mod Managers
local HKS = get_mod("Hit_Kill_Sounds")

local AudioBackend = {}

local player = HKS.HitKillSoundsPlayer
local legacy_play_file = player and player.play_file
local legacy_stop_file = player and player.stop_file
local legacy_check_player_running = player and player.check_player_running
local legacy_tracks = player and player.TRACKS
local legacy_available = player and player.legacy_available == true

local simple_audio = nil
local using_simple_audio = false

-- Lower numbers are higher priority. These values are shared by every event entry point.
AudioBackend.PRIORITY = {
    BOSS = 0,
    HEADSHOT_KILL = 1,
    CF_KILL = 1,
    KILL = 2,
    HEADSHOT_HIT = 3,
    HIT = 4,
}

-- The queue and voice limits are deliberately small. They protect the native player from
-- a same-frame burst without turning short feedback sounds into a long delayed backlog.
local MAX_PENDING_QUEUE = 10
local MAX_PENDING_AGE = 0.12
local MAX_DISPATCH_PER_UPDATE = 2
local MIN_DISPATCH_INTERVAL = 0.03
local MAX_ACTIVE_VOICES = 8
local MAX_ACTIVE_HIT_VOICES = 3
local MAX_ACTIVE_KILL_VOICES = 4
local MAX_VOICE_AGE = 5

local pending_queue = {}
local active_voices = {}
local active_voices_by_track = {}
local fallback_clock = 0
local last_dispatch_time = nil
local logged_simple_playback = false
local logged_legacy_playback = false
local logged_legacy_diagnostic = false

local statistics = {
    queued = 0,
    dispatched = 0,
    dropped = 0,
    dropped_expired = 0,
    dropped_queue_full = 0,
    dropped_capacity = 0,
    playback_failed = 0,
    peak_queue = 0,
    peak_active = 0,
}

local function current_main_time()
    if Managers and Managers.time and Managers.time.time then
        local ok, now = pcall(function()
            return Managers.time:time("main")
        end)

        if ok and type(now) == "number" then
            return now
        end
    end

    return fallback_clock
end

local function show_backend_message(message)
    if HKS.echo then
        HKS:echo(message)
    else
        HKS:info(message)
    end
end

local function log_once(flag_name, message)
    if flag_name == "simple" then
        if logged_simple_playback then
            return
        end

        logged_simple_playback = true
    elseif flag_name == "legacy" then
        if logged_legacy_playback then
            return
        end

        logged_legacy_playback = true
    end

    show_backend_message(message)
end

local function log_legacy_diagnostic_once()
    if logged_legacy_diagnostic then
        return
    end

    logged_legacy_diagnostic = true
    show_backend_message(
        "在安装SimpleAudio和SimpleAssets后，使用的后端不应该为legacy HTTP 播放器，"
            .. "如果仍然为legacy HTTP 播放器，请在评论区反馈"
    )
end

local function simple_audio_path(path)
    if type(path) ~= "string" then
        return path
    end

    local normalized_path = path:gsub("\\", "/")

    if normalized_path:match("^%a:/") or normalized_path:sub(1, 5) == "mods/" then
        return normalized_path
    end

    if normalized_path:sub(1, 16) == "Hit_Kill_Sounds/" then
        return "mods/" .. normalized_path
    end

    return "mods/Hit_Kill_Sounds/audio/" .. normalized_path
end

local function get_simple_audio()
    if simple_audio == nil and get_mod then
        simple_audio = get_mod("SimpleAudio")
    end

    return simple_audio
end

local function refresh_simple_audio()
    simple_audio = get_simple_audio()
    using_simple_audio = simple_audio and type(simple_audio.play_file) == "function" or false

    return using_simple_audio
end

local function normalize_priority(priority)
    priority = tonumber(priority) or AudioBackend.PRIORITY.HIT

    return math.max(0, math.min(4, priority))
end

local function sound_group(sound_kind)
    if type(sound_kind) == "string" and sound_kind:match("^hit") then
        return "hit"
    end

    return "kill"
end

local function default_sound_kind(track_id)
    if legacy_tracks then
        if track_id == legacy_tracks.HIT_HEADSHOT then
            return "hit_headshot"
        elseif track_id == legacy_tracks.HIT_NORMAL then
            return "hit_normal"
        elseif track_id == legacy_tracks.KILL_HEADSHOT then
            return "kill_headshot"
        end
    end

    return "kill_normal"
end

local function remove_active_voice(index)
    local voice = table.remove(active_voices, index)

    if not voice then
        return
    end

    local track_voices = active_voices_by_track[voice.track_id]
    if track_voices then
        for i = #track_voices, 1, -1 do
            if track_voices[i] == voice then
                table.remove(track_voices, i)
                break
            end
        end

        if #track_voices == 0 then
            active_voices_by_track[voice.track_id] = nil
        end
    end
end

local function remove_active_voice_by_id(play_id)
    for i = #active_voices, 1, -1 do
        if active_voices[i].play_id == play_id then
            remove_active_voice(i)
            return
        end
    end
end

local function stop_active_voice(index)
    local voice = active_voices[index]
    local SimpleAudio = get_simple_audio()

    if voice and SimpleAudio and type(SimpleAudio.stop_file) == "function" then
        pcall(SimpleAudio.stop_file, voice.play_id)
    end

    remove_active_voice(index)
end

local function clear_pending_queue()
    for i = #pending_queue, 1, -1 do
        table.remove(pending_queue, i)
    end
end

local function remove_pending_track(track_id)
    for i = #pending_queue, 1, -1 do
        if pending_queue[i].track_id == track_id then
            table.remove(pending_queue, i)
        end
    end
end

local function reset_scheduler_state()
    last_dispatch_time = nil
    fallback_clock = 0
end

local function active_voice_count_for_group(group)
    local count = 0

    for _, voice in ipairs(active_voices) do
        if sound_group(voice.sound_kind) == group then
            count = count + 1
        end
    end

    return count
end

local function active_limit_for_group(group)
    if group == "hit" then
        return MAX_ACTIVE_HIT_VOICES
    end

    return MAX_ACTIVE_KILL_VOICES
end

local function find_active_victim(group, priority)
    local victim_index = nil
    local victim_priority = -1
    local victim_started_at = math.huge

    for i, voice in ipairs(active_voices) do
        if (not group or sound_group(voice.sound_kind) == group) and voice.priority > priority then
            if voice.priority > victim_priority or
                voice.priority == victim_priority and voice.started_at < victim_started_at then
                victim_index = i
                victim_priority = voice.priority
                victim_started_at = voice.started_at
            end
        end
    end

    return victim_index
end

local function make_voice_room(request)
    local group = sound_group(request.sound_kind)
    local group_count = active_voice_count_for_group(group)
    local group_limit = active_limit_for_group(group)

    if group_count >= group_limit then
        local victim_index = find_active_victim(group, request.priority)

        if not victim_index then
            return false, "capacity"
        end

        stop_active_voice(victim_index)
    end

    if #active_voices >= MAX_ACTIVE_VOICES then
        local victim_index = find_active_victim(nil, request.priority)

        if not victim_index then
            return false, "capacity"
        end

        stop_active_voice(victim_index)
    end

    return true
end

local function simple_is_playing(SimpleAudio, play_id)
    if not SimpleAudio or type(SimpleAudio.is_file_playing) ~= "function" then
        return nil
    end

    local ok, playing = pcall(SimpleAudio.is_file_playing, play_id)

    if not ok then
        return nil
    end

    return playing == true
end

local function cleanup_active_voices(now)
    local SimpleAudio = get_simple_audio()

    for i = #active_voices, 1, -1 do
        local voice = active_voices[i]
        local playing = simple_is_playing(SimpleAudio, voice.play_id)

        if playing == false then
            remove_active_voice(i)
        elseif playing == nil and now - voice.started_at >= MAX_VOICE_AGE then
            -- This is only a defensive fallback for an older SimpleAudio build without
            -- is_file_playing. The current API takes the normal branch above.
            stop_active_voice(i)
        end
    end
end

local function update_peak_counts()
    if #pending_queue > statistics.peak_queue then
        statistics.peak_queue = #pending_queue
    end

    if #active_voices > statistics.peak_active then
        statistics.peak_active = #active_voices
    end
end

local function find_pending_victim()
    local victim_index = nil
    local victim_priority = -1
    local victim_is_hit = false
    local victim_created_at = math.huge

    for i, request in ipairs(pending_queue) do
        local is_hit = sound_group(request.sound_kind) == "hit"

        if request.priority > victim_priority or
            request.priority == victim_priority and is_hit and not victim_is_hit or
            request.priority == victim_priority and is_hit == victim_is_hit
                and request.created_at < victim_created_at then
            victim_index = i
            victim_priority = request.priority
            victim_is_hit = is_hit
            victim_created_at = request.created_at
        end
    end

    return victim_index
end

local function find_next_pending_index()
    local selected_index = nil
    local selected_priority = math.huge
    local selected_created_at = math.huge

    for i, request in ipairs(pending_queue) do
        if request.priority < selected_priority or
            request.priority == selected_priority and request.created_at < selected_created_at then
            selected_index = i
            selected_priority = request.priority
            selected_created_at = request.created_at
        end
    end

    return selected_index
end

local function drop_expired_requests(now)
    for i = #pending_queue, 1, -1 do
        if now - pending_queue[i].created_at > MAX_PENDING_AGE then
            table.remove(pending_queue, i)
            statistics.dropped = statistics.dropped + 1
            statistics.dropped_expired = statistics.dropped_expired + 1
        end
    end
end

local function add_active_voice(request, play_id, started_at)
    local voice = {
        play_id = play_id,
        track_id = request.track_id,
        priority = request.priority,
        started_at = started_at,
        path = request.path,
        sound_kind = request.sound_kind,
    }

    table.insert(active_voices, voice)

    local track_voices = active_voices_by_track[request.track_id]
    if not track_voices then
        track_voices = {}
        active_voices_by_track[request.track_id] = track_voices
    end

    table.insert(track_voices, voice)
    update_peak_counts()
end

local function start_simple_voice(request, now)
    local SimpleAudio = get_simple_audio()

    if not SimpleAudio or type(SimpleAudio.play_file) ~= "function" then
        return false, "playback"
    end

    local room_available, room_error = make_voice_room(request)
    if not room_available then
        return false, room_error
    end

    local ok, play_id = pcall(function()
        return SimpleAudio.play_file(request.path, {
            audio_type = "sfx",
            volume = request.volume,
            on_finished = function(finished_play_id)
                remove_active_voice_by_id(finished_play_id)
            end,
        })
    end)

    if not ok or not play_id then
        return false, "playback"
    end

    add_active_voice(request, play_id, now)
    return true
end

local function dispatch_legacy(request)
    if not legacy_available or not legacy_play_file then
        return false
    end

    log_once("legacy", "[Hit_Kill_Sounds] 音频后端：legacy HTTP player")
    log_legacy_diagnostic_once()

    local ok, played = pcall(legacy_play_file, request.legacy_path, request.track_id, request.volume)

    return ok and played ~= false
end

local function dispatch_request(request, now)
    if using_simple_audio then
        local started, reason = start_simple_voice(request, now)

        if started then
            log_once("simple", "[Hit_Kill_Sounds] 音频后端：SimpleAudio")
            return true
        end

        if reason == "capacity" then
            statistics.dropped = statistics.dropped + 1
            statistics.dropped_capacity = statistics.dropped_capacity + 1
            return false
        end

        statistics.playback_failed = statistics.playback_failed + 1

        -- Keep the existing compatibility fallback, but only after a native SimpleAudio
        -- start failure. N网 packages do not have this path and therefore remain SimpleAudio-only.
        if dispatch_legacy(request) then
            return true
        end

        statistics.dropped = statistics.dropped + 1
        return false
    end

    if dispatch_legacy(request) then
        return true
    end

    statistics.dropped = statistics.dropped + 1
    return false
end

AudioBackend.init = function()
    AudioBackend.stop_all()
    refresh_simple_audio()

    if using_simple_audio then
        HKS:info("Hit_Kill_Sounds audio backend: SimpleAudio")
    else
        HKS:info("Hit_Kill_Sounds audio backend: legacy HTTP player")
    end
end

AudioBackend.needs_legacy_player = function()
    refresh_simple_audio()

    return legacy_available and not using_simple_audio
end

AudioBackend.enqueue = function(path, track_id, volume, priority, sound_kind)
    if HKS:get("enabled") == false or type(path) ~= "string" or path == "" then
        return false
    end

    refresh_simple_audio()
    drop_expired_requests(current_main_time())

    if not using_simple_audio and not legacy_available then
        return false
    end

    track_id = track_id or (legacy_tracks and legacy_tracks.HIT_NORMAL)
    if not track_id then
        return false
    end

    volume = tonumber(volume) or 100
    priority = normalize_priority(priority)
    sound_kind = sound_kind or default_sound_kind(track_id)

    local request = {
        path = simple_audio_path(path),
        legacy_path = path,
        track_id = track_id,
        volume = volume,
        priority = priority,
        sound_kind = sound_kind,
        created_at = current_main_time(),
    }

    if #pending_queue >= MAX_PENDING_QUEUE then
        local victim_index = find_pending_victim()
        local victim = victim_index and pending_queue[victim_index]

        if not victim or victim.priority <= request.priority then
            statistics.dropped = statistics.dropped + 1
            statistics.dropped_queue_full = statistics.dropped_queue_full + 1
            return false
        end

        table.remove(pending_queue, victim_index)
        statistics.dropped = statistics.dropped + 1
        statistics.dropped_queue_full = statistics.dropped_queue_full + 1
    end

    table.insert(pending_queue, request)
    statistics.queued = statistics.queued + 1
    update_peak_counts()

    return true
end

-- Keep the public player wrapper for existing callers, while all HKS events use enqueue.
AudioBackend.play_file = AudioBackend.enqueue

AudioBackend.update = function(dt)
    dt = tonumber(dt) or 0
    fallback_clock = fallback_clock + math.max(dt, 0)

    local now = current_main_time()

    if HKS:get("enabled") == false then
        if #pending_queue > 0 or #active_voices > 0 then
            AudioBackend.stop_all()
        end

        return
    end

    cleanup_active_voices(now)
    drop_expired_requests(now)

    if not refresh_simple_audio() and not legacy_available then
        clear_pending_queue()
        return
    end

    local dispatched = 0

    while dispatched < MAX_DISPATCH_PER_UPDATE and #pending_queue > 0 do
        now = current_main_time()

        if last_dispatch_time and now - last_dispatch_time < MIN_DISPATCH_INTERVAL then
            break
        end

        local request_index = find_next_pending_index()
        if not request_index then
            break
        end

        local request = table.remove(pending_queue, request_index)

        if now - request.created_at > MAX_PENDING_AGE then
            statistics.dropped = statistics.dropped + 1
            statistics.dropped_expired = statistics.dropped_expired + 1
        else
            last_dispatch_time = now
            if dispatch_request(request, now) then
                statistics.dispatched = statistics.dispatched + 1
            end
            dispatched = dispatched + 1
        end
    end
end

AudioBackend.stop_file = function(track_id)
    if not track_id then
        AudioBackend.stop_all()
        return
    end

    remove_pending_track(track_id)

    for i = #active_voices, 1, -1 do
        if active_voices[i].track_id == track_id then
            stop_active_voice(i)
        end
    end

    if legacy_available and legacy_stop_file then
        pcall(legacy_stop_file, track_id)
    end
end

AudioBackend.stop_all = function()
    local SimpleAudio = get_simple_audio()

    if SimpleAudio and type(SimpleAudio.stop_file) == "function" then
        for i = #active_voices, 1, -1 do
            pcall(SimpleAudio.stop_file, active_voices[i].play_id)
        end
    end

    for i = #active_voices, 1, -1 do
        remove_active_voice(i)
    end

    clear_pending_queue()

    if legacy_tracks and legacy_available and legacy_stop_file then
        for _, track_id in pairs(legacy_tracks) do
            pcall(legacy_stop_file, track_id)
        end
    end

    reset_scheduler_state()
end

AudioBackend.shutdown = AudioBackend.stop_all
AudioBackend.close = AudioBackend.stop_all

AudioBackend.check_player_running = function()
    if not using_simple_audio and legacy_check_player_running then
        legacy_check_player_running()
    end
end

AudioBackend.get_pending_queue = function()
    return pending_queue
end

AudioBackend.get_active_voices = function()
    return active_voices
end

AudioBackend.get_statistics = function()
    return statistics
end

HKS.HitKillSoundsLegacyPlayer = {
    TRACKS = legacy_tracks,
    available = legacy_available,
    play_file = legacy_play_file,
    stop_file = legacy_stop_file,
    start_player = player and player.start_player,
    check_player_running = legacy_check_player_running,
    host = player and player.host,
}

HKS.HitKillSoundsAudioBackend = AudioBackend
HKS.HitKillSoundsPlayer.play_file = AudioBackend.play_file
HKS.HitKillSoundsPlayer.stop_file = AudioBackend.stop_file
HKS.HitKillSoundsPlayer.stop_all = AudioBackend.stop_all
HKS.HitKillSoundsPlayer.check_player_running = AudioBackend.check_player_running

return AudioBackend
