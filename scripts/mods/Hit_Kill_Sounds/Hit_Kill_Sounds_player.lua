-- luacheck: globals get_mod Mods cjson Managers
local HKS = get_mod("Hit_Kill_Sounds")
HKS.HitKillSoundsPlayer = {}

local lua_io = Mods and Mods.lua and Mods.lua.io
local player_path
local audio_path

-- 即使 popen/read/close 或路径转换失败，也要继续加载 SimpleAudio 后端。
local function detect_legacy_path()
    if not lua_io or type(lua_io.popen) ~= "function" then
        return nil
    end

    local open_ok, handle = pcall(lua_io.popen, "cd")
    if not open_ok or not handle then
        return nil
    end

    local read_ok, binaries_path = pcall(function()
        return handle:read()
    end)
    local close_ok, closed = pcall(function()
        return handle:close()
    end)

    if not read_ok or not close_ok or not closed or type(binaries_path) ~= "string" then
        return nil
    end

    local convert_ok, hks_path = pcall(function()
        local normalized_path = binaries_path:gsub("[\r\n]+$", ""):gsub("\\", "/"):gsub("/+$", "")
        local mods_path, replacements = normalized_path:gsub("/[Bb][Ii][Nn][Aa][Rr][Ii][Ee][Ss]$", "/mods", 1)

        if normalized_path == "" or replacements ~= 1 then
            return nil
        end

        return mods_path .. "/Hit_Kill_Sounds/"
    end)

    return convert_ok and hks_path or nil
end

local hks_path = detect_legacy_path()
if hks_path then
    player_path = hks_path .. "bin/"
    audio_path = hks_path .. "audio/"
end

local function file_exists(path)
    if not lua_io or type(lua_io.open) ~= "function" or not path then
        return false
    end

    local open_ok, handle = pcall(lua_io.open, path, "rb")
    if not open_ok or not handle then
        return false
    end

    local close_ok, closed = pcall(function()
        return handle:close()
    end)

    return close_ok and not not closed
end

local function read_port_config(path)
    if not lua_io or type(lua_io.open) ~= "function" or not path then
        return nil
    end

    local open_ok, handle = pcall(lua_io.open, path, "rb")
    if not open_ok or not handle then
        return nil
    end

    local read_ok, port_json = pcall(function()
        return handle:read("*a")
    end)
    local close_ok, closed = pcall(function()
        return handle:close()
    end)

    if not read_ok or not close_ok or not closed or type(port_json) ~= "string" or port_json == "" then
        return nil
    end

    local decode_ok, config = pcall(function()
        return cjson.decode(port_json)
    end)

    if not decode_ok or type(config) ~= "table" then
        return nil
    end

    return config
end

-- legacy HTTP 播放器。路径探测或 bin 不可用时禁用，SimpleAudio 仍可正常加载。
local bat_path = player_path and player_path .. "StartHitKillSoundsPlayer.bat"
local port_config = player_path and read_port_config(player_path .. "port.json")
local legacy_available = bat_path ~= nil and file_exists(bat_path) and port_config ~= nil
local host = nil
local player_started = false

if legacy_available then
    local port = tonumber(port_config.port) or 42213
    host = string.format("http://localhost:%s/", port)
end

local function disable_legacy()
    legacy_available = false
    host = nil
    HKS.HitKillSoundsPlayer.legacy_available = false
    HKS.HitKillSoundsPlayer.host = nil
end

local function ensure_player_started()
    if not legacy_available then
        return false
    end

    if player_started then
        return true
    end

    local ok, started = pcall(function()
        local handle = lua_io.popen('"' .. bat_path .. '"')
        return handle and handle:close()
    end)

    if not ok or not started then
        disable_legacy()
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
