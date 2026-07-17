-- luacheck: globals get_mod Mods cjson Managers
local HKS = get_mod("Hit_Kill_Sounds")
HKS.HitKillSoundsPlayer = {}

local binaries_path_handle = Mods.lua.io.popen("cd")
local binaries_path = binaries_path_handle:read()
binaries_path_handle:close()
local mods_path = binaries_path:gsub("binaries", "mods")
mods_path = mods_path:gsub("\\", "/")
local hks_path = mods_path .. "/Hit_Kill_Sounds/"
local player_path = hks_path .. "bin/"
local audio_path = hks_path .. "audio/"

local function file_exists(path)
    local handle = Mods.lua.io.open(path, "rb")

    if handle then
        handle:close()
        return true
    end

    return false
end

local function read_port_config(path)
    local port_handle = Mods.lua.io.open(path, "rb")

    if not port_handle then
        return nil
    end

    local port_json = port_handle:read("*a")
    port_handle:close()

    if not port_json or port_json == "" then
        return nil
    end

    local ok, config = pcall(cjson.decode, port_json)

    if not ok then
        return nil
    end

    return config
end

-- legacy HTTP 播放器。bin 不存在时禁用，避免 N 网发布包加载失败。
local bat_path = player_path .. "StartHitKillSoundsPlayer.bat"
local port_config = read_port_config(player_path .. "port.json")
local legacy_available = file_exists(bat_path) and port_config ~= nil
local host = nil
local player_started = false

if legacy_available then
    local port = port_config and port_config.port or 42213
    host = string.format("http://localhost:%s/", port)
end

local function ensure_player_started()
    if not legacy_available then
        return false
    end

    if player_started then
        return true
    end

    local ok = pcall(function()
        Mods.lua.io.popen('"' .. bat_path .. '"'):close()
    end)

    if not ok then
        return false
    end

    player_started = true
    return true
end

HKS.HitKillSoundsPlayer.host = host
HKS.HitKillSoundsPlayer.legacy_available = legacy_available
HKS.HitKillSoundsPlayer.start_player = ensure_player_started

HKS.HitKillSoundsPlayer.check_player_running = function()
    if not ensure_player_started() then
        return false
    end

    if not host or Managers.backend == nil then
        return false
    end

    local ok = pcall(function()
        Managers.backend:url_request(host, {
            method = "POST",
            body = {
                method = "test",
            }
        })
    end)

    return ok
end

-- 音效播放通道
-- 1: 普通命中音
-- 2: 弱点击中音
-- 3: 普通击杀音
-- 4: 弱点击杀音
local TRACKS = {
    HIT_NORMAL = 1,
    HIT_HEADSHOT = 2,
    KILL_NORMAL = 3,
    KILL_HEADSHOT = 4,
}
HKS.HitKillSoundsPlayer.TRACKS = TRACKS

HKS.HitKillSoundsPlayer.play_file = function(
    path,
    track_id,
    volume
)
    track_id = track_id or TRACKS.HIT_NORMAL

    if not ensure_player_started() or not host or Managers.backend == nil then
        return false
    end

    local request_body = {
        method = "play_file",
        playing_trackid = track_id,
        left_volume = volume / 100,
        right_volume = volume / 100,
        file_path = audio_path .. path
    }

    local ok = pcall(function()
        Managers.backend:url_request(host, {
            method = "POST",
            body = request_body
        })
    end)

    return ok
end

HKS.HitKillSoundsPlayer.stop_file = function(playing_trackid)
    if not player_started or not host or Managers.backend == nil then
        return false
    end

    local ok = pcall(function()
        Managers.backend:url_request(host, {
            method = "POST",
            body = {
                method = "stop_file",
                playing_trackid = playing_trackid
            }
        })
    end)

    return ok
end

return HKS.HitKillSoundsPlayer
