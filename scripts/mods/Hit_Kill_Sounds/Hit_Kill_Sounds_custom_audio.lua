-- luacheck: globals get_mod Mods
-- User manifests are DATA, never Lua. Only init() touches disk.
local HKS = get_mod("Hit_Kill_Sounds")
local Custom = {}
local FILESYSTEM_ROOT = "../mods/Hit_Kill_Sounds/UserAudio/"
local PLAYBACK_ROOT = "mods/Hit_Kill_Sounds/UserAudio/"
local MAX_ENTRIES = 20
local MAX_MANIFEST_BYTES = 65536
local initialized = false
local cache = {}
local warnings = {}

local function warn_once(key, message)
    if not warnings[key] then
        warnings[key] = true
        HKS:warning("%s", "[Hit_Kill_Sounds] UserAudio: " .. message)
    end
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lexical containment, including Windows drive/UNC/ADS/device-name rules.
-- Junctions/symlinks are not a supported way of populating UserAudio.
Custom.validate_path = function(path, extension)
    if type(path) ~= "string" then
        return nil, "path"
    end
    path = trim(path):gsub("\\", "/")
    if path == "" or path:sub(1, 1) == "/" or path:find("..", 1, true)
        or path:find('[%c:*?"\'<>|;`$%%(){}=%[%]]') or path:find("//", 1, true)
        or path:sub(-1) == "/" then
        return nil, "path"
    end
    for part in path:gmatch("[^/]+") do
        local stem = (part:match("^([^.]+)") or part):upper()
        if part == "." or part:match("[%.%s]$") or part:match("^%s")
            or stem == "CON" or stem == "PRN" or stem == "AUX" or stem == "NUL"
            or stem:match("^COM%d$") or stem:match("^LPT%d$") then
            return nil, "path"
        end
    end
    if path:lower():sub(-#extension) ~= extension then
        return nil, "extension"
    end
    return path
end

-- Pure parser: probe is injected, receives only already-validated relative paths.
-- Deduplication is case-insensitive within each explicit category (Windows).
Custom.parse_manifest = function(text, kind, probe, report)
    local pools = {normal = {}, headshot = {}, bgm = {}}
    local seen = {normal = {}, headshot = {}, bgm = {}}
    report = report or function() end
    if type(text) ~= "string" then
        return pools
    end
    if #text > MAX_MANIFEST_BYTES then
        report("size", "manifest exceeds 64 KiB; ignored")
        return pools
    end
    text = text:gsub("^\239\187\191", "")
    local line_number = 0
    for raw_line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line_number = line_number + 1
        local line = trim(raw_line)
        if line ~= "" and line:sub(1, 1) ~= "#" then
            local category, path
            if kind == "bgm" then
                category, path = "bgm", line
            else
                category, path = line:match("^([^|]+)|([^|]+)$")
                category = category and trim(category)
            end
            local location = "line " .. line_number .. ": "
            if not category or not pools[category] or (kind ~= "bgm" and category == "bgm") then
                report("category", location .. "expected normal|path or headshot|path")
            else
                local relative, reason = Custom.validate_path(path, kind == "bgm" and ".mp3" or ".wav")
                if not relative then
                    report(reason, location .. "invalid relative path or unsupported extension")
                elseif not seen[category][relative:lower()] then
                    if #pools[category] >= MAX_ENTRIES then
                        report("limit_" .. category, location .. category .. " limit is 20; later entries ignored")
                    else
                        local ok, readable = pcall(probe, relative)
                        if ok and readable == true then
                            seen[category][relative:lower()] = true
                            pools[category][#pools[category] + 1] = PLAYBACK_ROOT .. relative
                        else
                            report("file", location .. "missing, unreadable or invalid audio header: " .. relative)
                        end
                    end
                end
            end
        end
    end
    return pools
end

local function read_file(path, size)
    local lua_io = Mods and Mods.lua and Mods.lua.io
    if not lua_io or type(lua_io.open) ~= "function" then
        return nil
    end
    local ok, handle = pcall(lua_io.open, path, "rb")
    if not ok or not handle then
        return nil
    end
    local read_ok, data = pcall(function()
        return handle:read(size)
    end)
    local close_ok, closed = pcall(function()
        return handle:close()
    end)
    if read_ok and close_ok and closed and type(data) == "string" then
        return data
    end
    return nil
end

local function probe_audio(relative)
    local header = read_file(FILESYSTEM_ROOT .. relative, 12)
    if not header then
        return false
    end
    if relative:lower():sub(-4) == ".wav" then
        return header:sub(1, 4) == "RIFF" and header:sub(9, 12) == "WAVE"
    end
    -- Header sanity only, NOT a promise that every codec variant can be decoded.
    return header:sub(1, 3) == "ID3"
        or (header:byte(1) == 255 and (header:byte(2) or 0) >= 224)
end

Custom.init = function()
    if initialized then
        return
    end
    initialized = true
    for kind, manifest in pairs({hit = "Hit/playlist.txt", kill = "Kill/playlist.txt", bgm = "BGM/tracks.txt"}) do
        local text = read_file(FILESYSTEM_ROOT .. manifest, MAX_MANIFEST_BYTES + 1)
        if not text then
            warn_once(kind .. "_manifest", manifest .. " missing/unreadable; using built-in fallback")
        end
        cache[kind] = Custom.parse_manifest(text, kind, probe_audio, function(reason, message)
            warn_once(kind .. "_" .. reason, manifest .. " " .. message)
        end)
    end
end

local function random_path(pool)
    return pool and #pool > 0 and pool[math.random(#pool)] or nil
end

Custom.sample = function(kind, is_headshot, fallback)
    local pools = cache[kind] or {}
    local path = is_headshot and random_path(pools.headshot) or nil
    if not path then
        if is_headshot then
            warn_once(kind .. "_headshot_empty", kind .. " headshot pool empty; trying Custom normal")
        end
        path = random_path(pools.normal)
    end
    if path then
        return path
    end
    warn_once(kind .. "_normal_empty", kind .. " normal pool empty; using built-in BFV (without extra tail)")
    fallback = fallback or {}
    return (is_headshot and random_path(fallback.headshot)) or random_path(fallback.normal)
end

Custom.get_bgm_paths = function()
    return cache.bgm and cache.bgm.bgm or {}
end

Custom.clear = function()
    cache = {}
    initialized = false
end

HKS.HitKillSoundsCustomAudio = Custom
return Custom
