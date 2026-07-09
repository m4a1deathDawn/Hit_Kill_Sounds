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

if legacy_available then
    Mods.lua.io.popen('"' .. bat_path .. '"'):close()

    local port = port_config and port_config.port or 42213
    host = string.format("http://localhost:%s/", port)
end

HKS.HitKillSoundsPlayer.host = host
HKS.HitKillSoundsPlayer.legacy_available = legacy_available

HKS.HitKillSoundsPlayer.check_player_running = function()
    if host and Managers.backend ~= nil then
        Managers.backend:url_request(host, {
            method = "POST",
            body = {
                method = "test",
            }
        })
    end
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

    local request_body = {
        method = "play_file",
        playing_trackid = track_id,
        left_volume = volume / 100,
        right_volume = volume / 100,
        file_path = audio_path .. path
    }

    if host and Managers.backend ~= nil then
        Managers.backend:url_request(host, {
            method = "POST",
            body = request_body
        })
    end
end

HKS.HitKillSoundsPlayer.stop_file = function(playing_trackid)
    if host and Managers.backend ~= nil then
        Managers.backend:url_request(host, {
            method = "POST",
            body = {
                method = "stop_file",
                playing_trackid = playing_trackid
            }
        })
    end
end

return HKS.HitKillSoundsPlayer
