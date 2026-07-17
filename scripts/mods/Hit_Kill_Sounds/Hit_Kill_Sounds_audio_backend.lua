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
local simple_play_ids_by_track = {}
local logged_simple_playback = false
local logged_legacy_playback = false
local logged_legacy_diagnostic = false
local using_simple_audio = false

-- 保守的播放限流：避免同一轨道在极短时间内反复 stop/play，
-- 也避免单帧内大量 HTTP/FFI 播放请求。命中路径已有更严格的 0.08s 冷却。
local MAX_PLAYS_PER_FRAME = 3
local MIN_TRACK_INTERVAL = 0.04
local last_play_time_by_track = {}
local last_frame_time = nil
local plays_this_frame = 0

local function current_main_time()
    if Managers and Managers.time then
        return Managers.time:time("main")
    end

    return nil
end

local function playback_allowed(track_id)
    local now = current_main_time()

    if not now then
        return true
    end

    if last_frame_time ~= now then
        last_frame_time = now
        plays_this_frame = 0
    end

    if plays_this_frame >= MAX_PLAYS_PER_FRAME then
        return false
    end

    local last_play_time = last_play_time_by_track[track_id]
    if last_play_time and now - last_play_time < MIN_TRACK_INTERVAL then
        return false
    end

    return true
end

local function record_playback(track_id)
    local now = current_main_time()

    if now then
        last_frame_time = now
        plays_this_frame = plays_this_frame + 1
        last_play_time_by_track[track_id] = now
    end
end

local function reset_playback_state()
    for track_id in pairs(simple_play_ids_by_track) do
        simple_play_ids_by_track[track_id] = nil
    end

    for track_id in pairs(last_play_time_by_track) do
        last_play_time_by_track[track_id] = nil
    end

    last_frame_time = nil
    plays_this_frame = 0
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
        if logged_simple_playback then return end
        logged_simple_playback = true
    elseif flag_name == "legacy" then
        if logged_legacy_playback then return end
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

local function stop_simple_track(track_id)
    local SimpleAudio = get_simple_audio()
    local play_id = simple_play_ids_by_track[track_id]

    if not SimpleAudio or not play_id then
        simple_play_ids_by_track[track_id] = nil
        return
    end

    pcall(SimpleAudio.stop_file, play_id)
    simple_play_ids_by_track[track_id] = nil
end

local function simple_play_file(path, track_id, volume)
    local SimpleAudio = get_simple_audio()

    if not SimpleAudio or not SimpleAudio.play_file then
        return false
    end

    stop_simple_track(track_id)

    local ok, play_id = pcall(function()
        return SimpleAudio.play_file(simple_audio_path(path), {
            audio_type = "sfx",
            volume = volume or 100,
        })
    end)

    if not ok or not play_id then
        return false
    end

    simple_play_ids_by_track[track_id] = play_id
    return true
end

AudioBackend.init = function()
    simple_audio = get_mod and get_mod("SimpleAudio") or nil
    using_simple_audio = simple_audio and simple_audio.play_file ~= nil or false

    if using_simple_audio then
        HKS:info("Hit_Kill_Sounds audio backend: SimpleAudio")
    else
        HKS:info("Hit_Kill_Sounds audio backend: legacy HTTP player")
    end
end

AudioBackend.needs_legacy_player = function()
    if not using_simple_audio then
        simple_audio = get_simple_audio()
        using_simple_audio = simple_audio and simple_audio.play_file ~= nil or false
    end

    return legacy_available and not using_simple_audio
end

AudioBackend.play_file = function(path, track_id, volume)
    if HKS:get("enabled") == false then
        return false
    end

    track_id = track_id or (legacy_tracks and legacy_tracks.HIT_NORMAL)
    volume = volume or 100

    if not track_id or not playback_allowed(track_id) then
        return false
    end

    if simple_play_file(path, track_id, volume) then
        log_once("simple", "[Hit_Kill_Sounds] 音频后端：SimpleAudio")
        record_playback(track_id)
        return true
    end

    if legacy_available and legacy_play_file then
        log_once("legacy", "[Hit_Kill_Sounds] 音频后端：legacy HTTP player")
        log_legacy_diagnostic_once()
        if legacy_play_file(path, track_id, volume) then
            record_playback(track_id)
            return true
        end
    end

    return false
end

AudioBackend.stop_file = function(track_id)
    if track_id then
        stop_simple_track(track_id)
        if legacy_available and legacy_stop_file then
            legacy_stop_file(track_id)
        end
        last_play_time_by_track[track_id] = nil
    else
        if legacy_tracks then
            for _, mapped_track_id in pairs(legacy_tracks) do
                stop_simple_track(mapped_track_id)
                if legacy_available and legacy_stop_file then
                    legacy_stop_file(mapped_track_id)
                end
            end
        end

        reset_playback_state()
    end
end

AudioBackend.stop_all = function()
    if legacy_tracks then
        for _, track_id in pairs(legacy_tracks) do
            AudioBackend.stop_file(track_id)
        end
    end

    reset_playback_state()
end

AudioBackend.check_player_running = function()
    if not using_simple_audio and legacy_check_player_running then
        legacy_check_player_running()
    end
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
