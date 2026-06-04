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

-- 启动音频播放器
local bat_path = player_path .. "StartHitKillSoundsPlayer.bat"
Mods.lua.io.popen('"' .. bat_path .. '"'):close()

-- 读取端口配置
local port_handle = Mods.lua.io.open(player_path .. "port.json", "rb")
local port_json = port_handle and port_handle:read("*a")
port_handle:close()
local config = cjson.decode(port_json)

local port = config and config.port or 42213
local host = string.format("http://localhost:%s/", port)

HKS.HitKillSoundsPlayer.host = host

HKS.HitKillSoundsPlayer.check_player_running = function()
    if Managers.backend ~= nil then
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

    if Managers.backend ~= nil then
        Managers.backend:url_request(host, {
            method = "POST",
            body = request_body
        })
    end
end

HKS.HitKillSoundsPlayer.stop_file = function(playing_trackid)
    if Managers.backend ~= nil then
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
