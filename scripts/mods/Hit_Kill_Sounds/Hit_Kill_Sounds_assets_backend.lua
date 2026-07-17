-- luacheck: globals get_mod
-- luacheck: globals get_mod Mods
local HKS = get_mod("Hit_Kill_Sounds")

local AssetsBackend = {}

local simple_assets = nil
local logged_simple_bf5 = false
local logged_legacy_bf5 = false
local logged_simple_cf = false
local logged_legacy_cf = false

local function show_backend_message(message)
    if HKS.echo then
        HKS:echo(message)
    else
        HKS:info(message)
    end
end

-- 使用当前发布包中实际存在的图标路径。
local BF5_PRIMARY_PATHS = {
    normal = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/BFV/kill_normal.png",
    headshot = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/BFV/kill_headshot.png",
    circle = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/BFV/kill_circle.png",
}

local BF5_EXISTING_PATHS = {
    normal = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/BFV/kill_normal.png",
    headshot = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/BFV/kill_headshot.png",
    circle = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/BFV/kill_circle.png",
}

local function get_simple_assets()
    if simple_assets == nil and get_mod then
        simple_assets = get_mod("SimpleAssets")
    end

    return simple_assets
end

local function log_bf5_simple()
    if logged_simple_bf5 then return end
    logged_simple_bf5 = true
    show_backend_message("[Hit_Kill_Sounds] BF5 图标后端：SimpleAssets")
end

local function log_bf5_legacy()
    if logged_legacy_bf5 then return end
    logged_legacy_bf5 = true

    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host then
        show_backend_message("[Hit_Kill_Sounds] BF5 图标后端：legacy HTTP image loader")
    else
        show_backend_message("[Hit_Kill_Sounds] BF5 图标后端：legacy HTTP 不可用")
    end
end

local function log_cf_simple()
    if logged_simple_cf then return end
    logged_simple_cf = true
    show_backend_message("[Hit_Kill_Sounds] CF 图标后端：SimpleAssets")
end

local function log_cf_legacy()
    if logged_legacy_cf then return end
    logged_legacy_cf = true

    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host then
        show_backend_message("[Hit_Kill_Sounds] CF 图标后端：legacy HTTP image loader")
    else
        show_backend_message("[Hit_Kill_Sounds] CF 图标后端：legacy HTTP 不可用")
    end
end

local function promise_catch(promise, callback)
    if promise and promise.catch then
        promise:catch(callback)
    end
end

local function load_textures(paths, on_done, on_failed)
    local SimpleAssets = get_simple_assets()

    if not SimpleAssets or not SimpleAssets.load_textures then
        if on_failed then on_failed() end
        return
    end

    local ok, promise = pcall(function()
        return SimpleAssets.load_textures(paths)
    end)
    if not ok or not promise or not promise.next then
        if on_failed then on_failed() end
        return
    end

    promise:next(function(results)
        on_done(results)
    end)
    promise_catch(promise, function()
        if on_failed then on_failed() end
    end)
end

local function bf5_path_list(path_map)
    return {
        path_map.normal,
        path_map.headshot,
        path_map.circle,
    }
end

local function apply_bf5_results(path_map, results, textures)
    results = results or {}

    local normal = results[path_map.normal]
    local headshot = results[path_map.headshot]
    local circle = results[path_map.circle]

    if normal and normal.texture then
        textures.normal = normal.texture
    end
    if headshot and headshot.texture then
        textures.headshot = headshot.texture
    end
    if circle and circle.texture then
        textures.circle = circle.texture
    end

    return textures.normal and textures.headshot and textures.circle
end

local function load_bf5_with_paths(path_map, textures, fallback, try_existing_paths)
    load_textures(bf5_path_list(path_map), function(results)
        if apply_bf5_results(path_map, results, textures) then
            log_bf5_simple()
            return
        end

        if try_existing_paths then
            load_bf5_with_paths(BF5_EXISTING_PATHS, textures, fallback, false)
        elseif fallback then
            fallback()
        end
    end, function()
        if try_existing_paths then
            load_bf5_with_paths(BF5_EXISTING_PATHS, textures, fallback, false)
        elseif fallback then
            fallback()
        end
    end)
end

AssetsBackend.load_bf5_icons = function(textures, fallback)
    local function fallback_with_log()
        log_bf5_legacy()
        if fallback then fallback() end
    end

    if not get_simple_assets() then
        fallback_with_log()
        return
    end

    load_bf5_with_paths(BF5_PRIMARY_PATHS, textures, fallback_with_log, false)
end

local CF_ICON_SCAN_MAX = 30
local CF_ICON_FALLBACK_MAX = 6

local function file_exists(path)
    local lua_mods = Mods and Mods.lua
    local lua_io = lua_mods and lua_mods.io

    if not lua_io or not lua_io.open then
        return false
    end

    local handle = lua_io.open(path, "rb")
    if not handle then
        return false
    end

    handle:close()
    return true
end

local function build_cf_paths(base_path)
    local paths = {}
    local found_count = 0

    -- 只请求实际存在的文件；扫描失败时回退到当前发布包的 1-6。
    for i = 1, CF_ICON_SCAN_MAX do
        local relative_path = "../mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/cf/kill" .. i .. ".png"
        if file_exists(relative_path) then
            paths[#paths + 1] = base_path .. "kill" .. i .. ".png"
            found_count = found_count + 1
        end
    end

    if found_count == 0 then
        for i = 1, CF_ICON_FALLBACK_MAX do
            paths[#paths + 1] = base_path .. "kill" .. i .. ".png"
        end
    end

    paths[#paths + 1] = base_path .. "headshot_gold.png"

    return paths
end

local function apply_cf_results(base_path, results, textures, on_loaded)
    results = results or {}

    local max_loaded = 0

    for i = 1, 30 do
        local path = base_path .. "kill" .. i .. ".png"
        local data = results[path]

        if data and data.texture then
            textures[i] = data.texture
            max_loaded = i
        end
    end

    local headshot_path = base_path .. "headshot_gold.png"
    local headshot = results[headshot_path]

    if headshot and headshot.texture then
        textures["headshot_gold"] = headshot.texture
    end

    if on_loaded and max_loaded > 0 then
        on_loaded(max_loaded)
    end

    return max_loaded > 0 or textures["headshot_gold"] ~= nil
end

local function load_cf_with_base(base_path, textures, on_loaded, fallback, try_existing_paths)
    local existing_base_path = "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/cf/"

    load_textures(build_cf_paths(base_path), function(results)
        if apply_cf_results(base_path, results, textures, on_loaded) then
            log_cf_simple()
            return
        end

        if try_existing_paths then
            load_cf_with_base(existing_base_path, textures, on_loaded, fallback, false)
        elseif fallback then
            fallback()
        end
    end, function()
        if try_existing_paths then
            load_cf_with_base(existing_base_path, textures, on_loaded, fallback, false)
        elseif fallback then
            fallback()
        end
    end)
end

AssetsBackend.load_cf_icons = function(textures, on_loaded, fallback)
    local function fallback_with_log()
        log_cf_legacy()
        if fallback then fallback() end
    end

    if not get_simple_assets() then
        fallback_with_log()
        return
    end

    load_cf_with_base(
        "mods/Hit_Kill_Sounds/cartoon_preview/kill_icon/cf/",
        textures,
        on_loaded,
        fallback_with_log,
        false
    )
end

AssetsBackend.init = function()
    simple_assets = get_mod and get_mod("SimpleAssets") or nil

    if simple_assets and simple_assets.load_textures then
        HKS:info("Hit_Kill_Sounds assets backend: SimpleAssets")
    else
        HKS:info("Hit_Kill_Sounds assets backend: legacy HTTP image loader")
    end
end

HKS.HitKillSoundsAssetsBackend = AssetsBackend

return AssetsBackend
