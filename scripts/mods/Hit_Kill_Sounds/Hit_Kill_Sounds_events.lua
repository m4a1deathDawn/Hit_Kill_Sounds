-- luacheck: globals get_mod Mods Managers ScriptUnit CLASS Unit Vector3
local HKS = get_mod("Hit_Kill_Sounds")

HKS.HitKillSoundsEvents = {}
local damage_hooks_initialized = false
local AudioBackend = HKS.HitKillSoundsAudioBackend
local ScoreFeed = HKS.HitKillSoundsScoreFeed
local killstreak_counters = HKS.HitKillSoundsKillstreakCounters or {}
local bf4_feed_counter = killstreak_counters.bf4_feed_counter
local cf_sound_counter = killstreak_counters.cf_sound_counter
local cf_icon_counter = killstreak_counters.cf_icon_counter
local AUDIO_PRIORITY = AudioBackend and AudioBackend.PRIORITY or {
    BOSS = 0,
    HEADSHOT_KILL = 1,
    CF_KILL = 1,
    KILL = 2,
    HEADSHOT_HIT = 3,
    HIT = 4,
}

-- 引入AttackSettings用于攻击结果检测
local AttackSettings = require("scripts/settings/damage/attack_settings")
local DamageSettings = require("scripts/settings/damage/damage_settings")
local damage_types = DamageSettings.damage_types

-- DoT（Damage over Time）damage_type 集合
-- 基于 D:\暗潮mod\scripts\settings\damage\damage_settings.lua line 5 中
-- damage_types 枚举的实证分析；任何在此集合中的 damage_type 都被视为持续伤害
local DOT_DAMAGE_TYPES = {
    [damage_types.bleeding]      = true,  -- 出血（狂热者血咒等）
    [damage_types.burning]       = true,  -- 燃烧（火焰喷射器、燃烧弹）
    [damage_types.toxin]         = true,  -- 中毒（毒药 stat）
    [damage_types.corruption]    = true,  -- 腐化（永久伤害）
    [damage_types.grimoire]      = true,  -- 死灵之书 tick
    [damage_types.warpfire]      = true,  -- 灵能火焰
    [damage_types.electrocution] = true,  -- 触电（链式闪电法杖等）—— §13 bug 修复重点
}

-- §11.B 同伴 attack_type 白名单（仅 Adamant 狗，详见 §11.B.7）
local COMPANION_ATTACK_TYPES = {
    [AttackSettings.attack_types.companion_dog] = true,
}

-- 目标类型检测函数（必须放在 CF 输出消费者之前！
--   Lua 5.4 闭包规则：函数定义时只捕获当前可见的 upvalues。
--   目标判断必须在输出消费者定义前可见。
-- target_setting: "all" | "elite" | "special" | "elite_special_boss"
local function is_target_valid(breed_or_nil, target_setting)
    if not target_setting or target_setting == "all" then
        return true
    end

    if not breed_or_nil then
        return false
    end

    local tags = breed_or_nil.tags or {}

    if target_setting == "elite" then
        return tags.elite == true
    elseif target_setting == "special" then
        return tags.special == true
    elseif target_setting == "elite_special_boss" then
        return tags.elite == true or tags.special == true or tags.monster == true or tags.captain == true or breed_or_nil.is_boss == true
    end

    return true
end

-- §13.B CF 资源探测
-- 默认值基于 2026-07-01 实际资源数，作为 scan 失败兜底：
--   9 个普通音效（killsound_cf_01..09.wav）+ 1 个 boss 音（killsound_cf_boss.wav）
--   6 个普通图标（kill1..6.png）+ 1 个首杀爆头（headshot_gold.png）
local CF_KILL_SOUNDS_MAX = 9    -- 默认 9
local CF_BOSS_SOUND_PATH = "KillSounds/cf/killsound_cf_boss.wav"
local CF_HEADSHOT_SOUND_PATH = "KillSounds/cf/cf_headshot.wav"

-- §13.C 图标资源（key=数字索引 "1"~"30"，特殊 key="headshot_gold"）
local CF_KILL_ICONS_MAX = 6     -- 默认 6
local cf_icon_tex = {}            -- cf_icon_tex[1]..cf_icon_tex[30]，cf_icon_tex["headshot_gold"]

-- 启动时尝试扫描（用户后续补 assets 时自动识别；失败时回退到默认值）
-- 关键：
--   1. DMF Mod 沙箱里裸 io 全局不可用，必须走 Mods.lua.io（参考 player.lua line 4/18）
--   2. Mod 沙箱 cwd 是 binaries 目录（player.lua line 5 `cd` 实证），所以相对路径从 binaries 起算
local function _file_exists(path)
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

-- §21/§23 BF4 文字击杀信息使用自己的目标和有效事件状态。
-- 这里不能读取 CF 音效、CF 图标、BF5 音效或 BF5 图标开关。
local function add_bf4_score_feed(breed_or_nil, is_headshot, bf4_feed_eligible)
    if not bf4_feed_eligible or not ScoreFeed then
        return false
    end

    return ScoreFeed.add_kill(breed_or_nil, is_headshot) == true
end

local function _scan_cf_assets()
    -- 扫描音效：cwd = binaries 目录，audio 在 ../mods/Hit_Kill_Sounds/audio/
    local handle = Mods.lua.io.popen and Mods.lua.io.popen('dir /b "..\\mods\\Hit_Kill_Sounds\\audio\\KillSounds\\cf\\killsound_cf_*.wav" 2>nul')
    if handle then
        for line in handle:lines() do
            -- 跳过 boss 文件
            if not line:match("^killsound_cf_boss%.wav$") then
                local num = tonumber(line:match("^killsound_cf_(%d+)%.wav$"))
                if num and num > CF_KILL_SOUNDS_MAX then
                    CF_KILL_SOUNDS_MAX = num  -- 只在 scan 找到更多时 override
                end
            end
        end
        handle:close()
    end

    -- boss 文件存在性
    if not _file_exists("../mods/Hit_Kill_Sounds/audio/KillSounds/cf/killsound_cf_boss.wav") then
        CF_BOSS_SOUND_PATH = nil  -- 不存在时禁用 boss 音
    end

    -- 首杀爆头文件独立于 killsound_cf_数字.wav 扫描，不计入连杀数量
    if not _file_exists("../mods/Hit_Kill_Sounds/audio/KillSounds/cf/cf_headshot.wav") then
        CF_HEADSHOT_SOUND_PATH = nil
    end
end
_scan_cf_assets()

-- §13.B.4 图标 HTTP 加载（mod 加载阶段）
local function _preload_cf_icons_legacy()
    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.start_player then
        HKS.HitKillSoundsPlayer.start_player()
    end

    if not HKS.HitKillSoundsPlayer or not HKS.HitKillSoundsPlayer.host then return end
    local host = HKS.HitKillSoundsPlayer.host
    local cf_base = "image?path=cartoon_preview/kill_icon/cf/"

    -- 当前发布包只有 1-6；不要在 legacy HTTP 路径中无条件请求 30 个文件。
    for i = 1, CF_KILL_ICONS_MAX do
        local idx = i
        Managers.url_loader:load_texture(host .. cf_base .. "kill" .. idx .. ".png"):next(function(data)
            if data and data.texture then
                cf_icon_tex[idx] = data.texture
                CF_KILL_ICONS_MAX = math.max(CF_KILL_ICONS_MAX, idx)
            end
        end)
    end

    -- 首杀爆头图标（独立 key，不进数字索引）
    Managers.url_loader:load_texture(host .. cf_base .. "headshot_gold.png"):next(function(data)
        if data and data.texture then
            cf_icon_tex["headshot_gold"] = data.texture
        end
    end)
end

local function _preload_cf_icons()
    if HKS.HitKillSoundsAssetsBackend then
        HKS.HitKillSoundsAssetsBackend.load_cf_icons(cf_icon_tex, function(max_loaded)
            CF_KILL_ICONS_MAX = math.max(CF_KILL_ICONS_MAX, max_loaded)
        end, _preload_cf_icons_legacy)
    else
        _preload_cf_icons_legacy()
    end
end

-- §23 三个输出各自维护连杀状态；CF 图标显示状态不承担计数职责。
local cf_icon_state = {
    current_icon = nil,
    icon_show_until = 0,
}

local function is_killstreak_enabled()
    return HKS:get("killstreak_enabled") ~= false
end

local function get_killstreak_reset_time()
    local reset_time = tonumber(HKS:get("cf_killstreak_reset_time")) or 20

    return math.max(reset_time, 0) / 10
end

local function clear_cf_icon_state()
    cf_icon_state.current_icon = nil
    cf_icon_state.icon_show_until = 0
end

local function accept_counter(counter, now, eligible)
    if not counter or not counter.accept then
        return nil
    end

    return counter:accept(now, eligible)
end

local function queue_sound(path, track_id, volume, priority, sound_kind)
    local backend = HKS.HitKillSoundsAudioBackend

    if backend and backend.enqueue then
        return backend.enqueue(path, track_id, volume, priority, sound_kind) == true
    end

    return false
end

local function get_kill_volume(is_headshot)
    if is_headshot then
        return HKS:get("kill_headshot_volume") or HKS:get("kill_volume") or 100
    end

    return HKS:get("kill_volume") or 100
end

local function get_kill_track(is_headshot, use_normal_sound)
    if is_headshot and not use_normal_sound then
        return HKS.HitKillSoundsPlayer.TRACKS.KILL_HEADSHOT
    end

    return HKS.HitKillSoundsPlayer.TRACKS.KILL_NORMAL
end

-- §13.C.4 CF 普通击杀音效播放。sound_streak_count 在击杀事件入口确定后传入，
-- 因此队列调度不会重新读取变化中的连杀状态。
-- 必须放在 CF 音效消费者之前（Lua 5.4 闭包 forward-reference 规则）
local function _cf_play_kill_sound(sound_streak_count, is_headshot)
    if CF_KILL_SOUNDS_MAX == 0 then return end  -- 无资源时不播

    local sound_idx = math.min(sound_streak_count, CF_KILL_SOUNDS_MAX)
    local sound_path = string.format("KillSounds/cf/killsound_cf_%02d.wav", sound_idx)

    local use_normal_sound = is_headshot and HKS:get("kill_headshot_use_normal") == true
    local volume = get_kill_volume(is_headshot)
    local track = get_kill_track(is_headshot, use_normal_sound)
    local sound_kind = is_headshot and "cf_kill_headshot" or "cf_kill"

    queue_sound(sound_path, track, volume, AUDIO_PRIORITY.CF_KILL, sound_kind)
end

local function _cf_play_headshot_special()
    if not CF_HEADSHOT_SOUND_PATH then
        return false
    end

    local track = HKS.HitKillSoundsPlayer.TRACKS.KILL_HEADSHOT
    local played = queue_sound(
        CF_HEADSHOT_SOUND_PATH,
        track,
        get_kill_volume(true),
        AUDIO_PRIORITY.HEADSHOT_KILL,
        "cf_kill_headshot"
    )

    return played == true
end

-- §23 CF 音效和图标分别消费各自计数器在击杀入口确定的序号。
local function _cf_on_sound_kill(is_headshot, sound_streak_count)
    if not sound_streak_count then
        return
    end

    local use_normal_sound = is_headshot and HKS:get("kill_headshot_use_normal") == true
    local is_first_headshot = is_headshot and sound_streak_count == 1

    if is_first_headshot and not use_normal_sound then
        if not _cf_play_headshot_special() then
            -- 特殊资源缺失或后端明确失败时回退到本轮普通 CF 首杀音效。
            _cf_play_kill_sound(sound_streak_count, is_headshot)
        end
    else
        _cf_play_kill_sound(sound_streak_count, is_headshot)
    end
end

local function _cf_on_icon_kill(is_headshot, icon_streak_count, now)
    if not icon_streak_count then
        return
    end

    if icon_streak_count == 1 and is_headshot and cf_icon_tex["headshot_gold"] then
        cf_icon_state.current_icon = cf_icon_tex["headshot_gold"]
    else
        local icon_idx = math.min(icon_streak_count, CF_KILL_ICONS_MAX)
        cf_icon_state.current_icon = cf_icon_tex[icon_idx]
    end

    cf_icon_state.icon_show_until = now + get_killstreak_reset_time()
end

-- §13.C.3 Boss 击杀（不递增通用连杀计数器，但受连杀开关保护）
local function _cf_on_boss_kill(is_headshot, cf_sound_active, cf_icon_active, now)
    if not (cf_sound_active or cf_icon_active) then return end

    if cf_icon_active then
        if is_headshot and cf_icon_tex["headshot_gold"] then
            cf_icon_state.current_icon = cf_icon_tex["headshot_gold"]
        else
            cf_icon_state.current_icon = cf_icon_tex[1]
        end
        cf_icon_state.icon_show_until = now + get_killstreak_reset_time()
    end

    if cf_sound_active and CF_BOSS_SOUND_PATH then
        local use_normal_sound = is_headshot and HKS:get("kill_headshot_use_normal") == true
        local volume = get_kill_volume(is_headshot)
        local track = get_kill_track(is_headshot, use_normal_sound)
        local sound_kind = is_headshot and "boss_headshot" or "boss_kill"

        queue_sound(CF_BOSS_SOUND_PATH, track, volume, AUDIO_PRIORITY.BOSS, sound_kind)
    end
end

-- 命中/击杀 Wwise 事件名 pattern（基于 D:\暗潮mod\scripts 源码 grep 证据，2026-06-04 回填）：
--   - "melee_hits" 覆盖 wwise/events/weapon/play_melee_hits_* 全部 25+ 事件（近战物理命中音，§11）
--   - "bullet_hits" 覆盖 wwise/events/weapon/play_bullet_hits_* 全部 60+ 事件（远程/投掷物理命中音，§11）
--   - "indicator" 覆盖 wwise/events/weapon/play_*indicator* 全部 15 个事件
--     （暴击 / 爆头 / 死亡刀 / 无伤害命中 / 灵能者死亡 / 强制击杀 反馈音，§12）
--   - 击杀族：play_*_killed（minion / elite / special / monster / husk / ogryn），D:\暗潮mod\scripts\extension_systems\weapon\actions\action_sweep.lua 实战验证
-- 子串匹配：event_name:match(pattern) 不受 "wwise/events/..." 前缀影响
local HIT_WWISE_PATTERNS  = {
    "melee_hits",     -- 物理近战命中音（§11 已验证）
    "bullet_hits",    -- 物理远程/投掷命中音（§11 已验证）
    "indicator",      -- 全部命中质量反馈音（§12 新增，覆盖 15 个 play_*indicator* 事件：
                     --   暴击 / 爆头 / 死亡刀 / 无伤害命中 / 灵能者死亡 / 强制击杀 等所有 indicator 反馈）
    -- §11.A v1.12.1 兼容性补漏（2026-07-01）
    "play_chord_claw_hit",               -- Cryptic 共振爪（含 _flesh / _rip_flesh）
    "play_transonic_blades_impact_hit",  -- Cryptic 共振刃/刀
    "play_power_sword_1h_p3_hit",        -- Power Sword P3 重做（含 _heavy / _light）
    "play_power_sword_hit",              -- Power Sword 通用
    "play_arc_maul_hit",                 -- Power Maul P3 arc active
    "play_powermaul_1h_hit",             -- Power Maul P3
}
local KILL_WWISE_PATTERNS = { "play_minion_killed", "play_elite_killed", "play_special_killed", "play_monster_killed", "play_husk_killed", "play_ogryn_killed" }

-- 静音模式表（按 setting 状态填充；event_name:match(pattern) 子串匹配）
local silenced_patterns = {}

local function rebuild_silenced_patterns()
    for k in pairs(silenced_patterns) do silenced_patterns[k] = nil end

    local hit_off  = not HKS:get("game_hit_sound_enabled")
    local kill_off = not HKS:get("game_kill_sound_enabled")

    if hit_off then
        for _, p in ipairs(HIT_WWISE_PATTERNS) do silenced_patterns[p] = true end
    end
    if kill_off then
        for _, p in ipairs(KILL_WWISE_PATTERNS) do silenced_patterns[p] = true end
    end
end

local function is_event_silenced(event_name)
    if type(event_name) ~= "string" then return false end
    for pattern in pairs(silenced_patterns) do
        if event_name:match(pattern) then return true end
    end
    return false
end

-- 内联音效配置
local HIT_SOUNDS = {
    BF1 = {
        normal = {
            "HitSounds/BF1/hitsound_bf1_normal1.wav",
            "HitSounds/BF1/hitsound_bf1_normal2.wav",
            "HitSounds/BF1/hitsound_bf1_normal3.wav",
            "HitSounds/BF1/hitsound_bf1_normal4.wav",
            "HitSounds/BF1/hitsound_bf1_normal5.wav",
        },
        headshot = {
            "HitSounds/BF1/hitsound_bf1_headshot1.wav",
            "HitSounds/BF1/hitsound_bf1_headshot2.wav",
            "HitSounds/BF1/hitsound_bf1_headshot3.wav",
            "HitSounds/BF1/hitsound_bf1_headshot4.wav",
            "HitSounds/BF1/hitsound_bf1_headshot5.wav",
        },
    },
    BF2042 = {
        normal = {
            "HitSounds/BF2042/hitsound_bf2042_normalbase1.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase2.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase3.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase4.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase5.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase6.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase7.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase8.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase9.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase10.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase11.wav",
            "HitSounds/BF2042/hitsound_bf2042_normalbase12.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd1.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd2.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd3.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd4.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd5.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd6.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd7.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd8.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd9.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd10.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd11.wav",
            "HitSounds/BF2042/hitsound_bf2042_normaladd12.wav",
        },
        headshot = {
            "HitSounds/BF2042/hitsound_bf2042_headshotadd1.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd2.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd3.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd4.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd5.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd6.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd7.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd8.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd9.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd10.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd11.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd12.wav",
            "HitSounds/BF2042/hitsound_bf2042_headshotadd13.wav",
        },
    },
    BF6 = {
        normal = {
            "HitSounds/BF6/hit/h_bf6_normal_01.wav",
            "HitSounds/BF6/hit/h_bf6_normal_02.wav",
            "HitSounds/BF6/hit/h_bf6_normal_03.wav",
            "HitSounds/BF6/hit/h_bf6_normal_04.wav",
            "HitSounds/BF6/hit/h_bf6_normal_05.wav",
            "HitSounds/BF6/hit/h_bf6_normal_06.wav",
            "HitSounds/BF6/hit/h_bf6_normal_07.wav",
            "HitSounds/BF6/hit/h_bf6_normal_08.wav",
            "HitSounds/BF6/hit/h_bf6_normal_09.wav",
            "HitSounds/BF6/hit/h_bf6_normal_10.wav",
            "HitSounds/BF6/hit/h_bf6_normal_11.wav",
            "HitSounds/BF6/hit/h_bf6_normal_12.wav",
            "HitSounds/BF6/hit/h_bf6_normal_13.wav",
            "HitSounds/BF6/hit/h_bf6_normal_14.wav",
            "HitSounds/BF6/hit/h_bf6_normal_15.wav",
            "HitSounds/BF6/add/h_bf6_add_01.wav",
            "HitSounds/BF6/add/h_bf6_add_02.wav",
            "HitSounds/BF6/add/h_bf6_add_03.wav",
            "HitSounds/BF6/add/h_bf6_add_04.wav",
            "HitSounds/BF6/add/h_bf6_add_05.wav",
            "HitSounds/BF6/add/h_bf6_add_06.wav",
            "HitSounds/BF6/add/h_bf6_add_07.wav",
            "HitSounds/BF6/add/h_bf6_add_08.wav",
            "HitSounds/BF6/add/h_bf6_add_09.wav",
            "HitSounds/BF6/add/h_bf6_add_10.wav",
            "HitSounds/BF6/add/h_bf6_add_11.wav",
            "HitSounds/BF6/add/h_bf6_add_12.wav",
            "HitSounds/BF6/add/h_bf6_add_13.wav",
        },
        headshot = {
            "HitSounds/BF6/headshot/h_bf6_headshot_01.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_02.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_03.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_04.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_05.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_06.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_07.wav",
            "HitSounds/BF6/headshot/h_bf6_headshot_08.wav",
        },
    },
    BFV = {
        normal = {
            "HitSounds/BFV/hitsound_bfv_normal1.wav",
            "HitSounds/BFV/hitsound_bfv_normal2.wav",
            "HitSounds/BFV/hitsound_bfv_normal3.wav",
            "HitSounds/BFV/hitsound_bfv_normal4.wav",
            "HitSounds/BFV/hitsound_bfv_normal5.wav",
            "HitSounds/BFV/hitsound_bfv_normal6.wav",
            "HitSounds/BFV/hitsound_bfv_normal7.wav",
            "HitSounds/BFV/hitsound_bfv_normal8.wav",
            "HitSounds/BFV/hitsound_bfv_normal9.wav",
            "HitSounds/BFV/hitsound_bfv_normal10.wav",
            "HitSounds/BFV/hitsound_bfv_normal11.wav",
            "HitSounds/BFV/hitsound_bfv_normal12.wav",
        },
        headshot = {
            "HitSounds/BFV/hitsound_bfv_headshot1.wav",
            "HitSounds/BFV/hitsound_bfv_headshot2.wav",
            "HitSounds/BFV/hitsound_bfv_headshot3.wav",
            "HitSounds/BFV/hitsound_bfv_headshot4.wav",
            "HitSounds/BFV/hitsound_bfv_headshot5.wav",
        },
    },
    CODBO6 = {
        normal = {
            "HitSounds/CODBO6/hitsound_BO6_normal1.wav",
            "HitSounds/CODBO6/hitsound_BO6_normal2.wav",
        },
        headshot = {
            "HitSounds/CODBO6/hitsound_BO6_headshot.wav",
        },
    },
    CODMW2019 = {
        normal = {
            "HitSounds/CODMW2019/hitsound_MW2019.wav",
        },
        headshot = {
            "HitSounds/CODMW2019/hitsound_MW2019.wav",
        },
    },
    CODMW3 = {
        normal = {
            "HitSounds/CODMW3/hitsound_MW3.wav",
        },
        headshot = {
            "HitSounds/CODMW3/hitsound_MW3.wav",
        },
    },
    TheFinals = {
        normal = {
            "HitSounds/TheFinals/hitsound_TheFinals_normal2.wav",
            "HitSounds/TheFinals/hitsound_TheFinals_normal3.wav",
            "HitSounds/TheFinals/hitsound_TheFinals_normal4.wav",
        },
        headshot = {
            "HitSounds/TheFinals/hitsound_TheFinals_headshot1.wav",
            "HitSounds/TheFinals/hitsound_TheFinals_headshot2.wav",
            "HitSounds/TheFinals/hitsound_TheFinals_headshot3.wav",
            "HitSounds/TheFinals/hitsound_TheFinals_headshot4.wav",
            "HitSounds/TheFinals/hitsound_TheFinals_headshot5.wav",
        },
    },
    CODBOCW = {
        normal = {
            "HitSounds/CODBOCW/h_bocw_normal-01.wav",
            "HitSounds/CODBOCW/h_bocw_normal-02.wav",
            "HitSounds/CODBOCW/h_bocw_normal-03.wav",
            "HitSounds/CODBOCW/hitsound_BOCW_normal.wav",
        },
        headshot = {
            "HitSounds/CODBOCW/h_bocw_head-01.wav",
            "HitSounds/CODBOCW/h_bocw_head-02.wav",
            "HitSounds/CODBOCW/h_bocw_head-03.wav",
            "HitSounds/CODBOCW/hitsound_BOCW_headshot.wav",
        },
    },
    CODVG = {
        normal = {
            "HitSounds/CODVG/h_codvg_default_03.wav",
            "HitSounds/CODVG/h_codvg_default_07.wav",
            "HitSounds/CODVG/h_codvg_default_08.wav",
            "HitSounds/CODVG/h_codvg_default_11.wav",
            "HitSounds/CODVG/h_codvg_default_15.wav",
            "HitSounds/CODVG/h_codvg_armor_01.wav",
            "HitSounds/CODVG/h_codvg_armor_02.wav",
            "HitSounds/CODVG/h_codvg_armor_03.wav",
            "HitSounds/CODVG/h_codvg_armor_04.wav",
            "HitSounds/CODVG/h_codvg_armor_05.wav",
            "HitSounds/CODVG/h_codvg_armor_06.wav",
            "HitSounds/CODVG/h_codvg_armor_07.wav",
        },
        headshot = {
            "HitSounds/CODVG/h_codvg_headshot_01.wav",
            "HitSounds/CODVG/h_codvg_headshot_02.wav",
            "HitSounds/CODVG/h_codvg_headshot_13.wav",
            "HitSounds/CODVG/h_codvg_headshot_14.wav",
        },
    },
    Overwatch = {
        normal = {
            "HitSounds/Overwatch/hitsound_ow_normal.wav",
        },
        headshot = {
            "HitSounds/Overwatch/hitsound_ow_headshot.wav",
        },
    },
    -- §12 新增 4 个命中音源（2026-07-01）
    -- 注：APEX shieldhit 全部归 normal（用户决策，详见 MOD_PLAN §12.3.1）
    -- 注：缺 headshot 文件的游戏依赖现有 line 503-509 的 fallback 自动顶上 normal（§12.3.4 已实现）
    CODWZ = {
        normal = {
            "HitSounds/CODWZ/hitsound_codwz_v1.wav",
            "HitSounds/CODWZ/hitsound_codwz_v2.wav",
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
    CODWZ2 = {
        normal = {
            "HitSounds/CODWZ2/hitsound_codwz2_normal.wav",
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
    DeltaForce = {
        normal = {
            "HitSounds/DeltaForce/h_deltaforce.wav",
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
    APEX = {
        normal = {
            "HitSounds/APEX/h_apex_shieldhit_01.wav",
            "HitSounds/APEX/h_apex_shieldhit_02.wav",
            "HitSounds/APEX/h_apex_shieldhit_03.wav",
            "HitSounds/APEX/h_apex_shieldhit_addon.wav",
            "HitSounds/APEX/h_apex_shieldhit_v2_01.wav",
            "HitSounds/APEX/h_apex_shieldhit_v2_02.wav",
            "HitSounds/APEX/h_apex_shieldhit_v2_03.wav",
            "HitSounds/APEX/h_apex_shieldhit_v2_04.wav",
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
}

local KILL_SOUNDS = {
    BF1 = {
        normal = {
            "KillSounds/BF1/killsound_bf1_normal.wav",
        },
        headshot = {
            "KillSounds/BF1/killsound_bf1_headshot.wav",
        },
    },
    BF2042 = {
        normal = {
            "KillSounds/BF2042/killsound_bf2042_normal1.wav",
            "KillSounds/BF2042/killsound_bf2042_normal2.wav",
            "KillSounds/BF2042/killsound_bf2042_normal3.wav",
            "KillSounds/BF2042/killsound_bf2042_normal4.wav",
            "KillSounds/BF2042/killsound_bf2042_normal5.wav",
            "KillSounds/BF2042/killsound_bf2042_normal6.wav",
        },
        headshot = {
            "KillSounds/BF2042/killsound_bf2042_headshot1.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot2.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot3.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot4.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot5.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot6.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot7.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot8.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot9.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot10.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot11.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot12.wav",
            "KillSounds/BF2042/killsound_bf2042_headshot13.wav",
        },
    },
    BF6 = {
        normal = {
            "KillSounds/BF6/k_bf6_normal_v1_01.wav",
            "KillSounds/BF6/k_bf6_normal_v1_02.wav",
            "KillSounds/BF6/k_bf6_normal_v1_03.wav",
            "KillSounds/BF6/k_bf6_normal_v2_01.wav",
            "KillSounds/BF6/k_bf6_normal_v2_02.wav",
            "KillSounds/BF6/k_bf6_normal_v2_03.wav",
        },
        headshot = {
            "KillSounds/BF6/k_bf6_headshot_v1_01.wav",
            "KillSounds/BF6/k_bf6_headshot_v1_02.wav",
            "KillSounds/BF6/k_bf6_headshot_v1_03.wav",
            "KillSounds/BF6/k_bf6_headshot_v1_04.wav",
            "KillSounds/BF6/k_bf6_headshot_v2_01.wav",
            "KillSounds/BF6/k_bf6_headshot_v2_02.wav",
            "KillSounds/BF6/k_bf6_headshot_v2_03.wav",
            "KillSounds/BF6/k_bf6_headshot_v2_04.wav",
        },
    },
    BFV = {
        normal = {
            "KillSounds/BFV/killsound_bfv_normal.wav",
        },
        headshot = {
            "KillSounds/BFV/killsound_bfv_headshot1.wav",
            "KillSounds/BFV/killsound_bfv_headshot2.wav",
            "KillSounds/BFV/killsound_bfv_headshot3.wav",
            "KillSounds/BFV/killsound_bfv_headshot4.wav",
            "KillSounds/BFV/killsound_bfv_headshot5.wav",
            "KillSounds/BFV/killsound_bfv_headshot6.wav",
            "KillSounds/BFV/killsound_bfv_headshot7.wav",
            "KillSounds/BFV/killsound_bfv_headshot8.wav",
            "KillSounds/BFV/killsound_bfv_headshot9.wav",
            "KillSounds/BFV/killsound_bfv_headshot10.wav",
            "KillSounds/BFV/killsound_bfv_headshotadd.wav",
        },
    },
    CODBO6 = {
        normal = {
            "KillSounds/CODBO6/killsound_BO6_normal.wav",
        },
        headshot = {
            "KillSounds/CODBO6/killsound_BO6_headshot1.wav",
            "KillSounds/CODBO6/killsound_BO6_headshot2.wav",
            "KillSounds/CODBO6/killsound_BO6_headshot3.wav",
        },
    },
    CODMW2019 = {
        normal = {
            "KillSounds/CODMW2019/Killsound_MW2019_kill.wav",
        },
        headshot = {
            "KillSounds/CODMW2019/Killsound_MW2019_headshot.wav",
        },
    },
    CODMW3 = {
        normal = {
            "KillSounds/CODMW3/Killsound_MW3_normal.wav",
        },
        headshot = {
            "KillSounds/CODMW3/Killsound_MW3_headshot.wav",
        },
    },
    TheFinals = {
        normal = {
            "KillSounds/TheFinals/killsound_TheFinals_normal.wav",
        },
        headshot = {
            "KillSounds/TheFinals/killsound_TheFinals_headshot.wav",
        },
    },
    CODBOCW = {
        normal = {
            "KillSounds/CODBOCW/k_bocw_normal.wav",
            "KillSounds/CODBOCW/Killsound_BOCW.wav",
        },
        headshot = {
            "KillSounds/CODBOCW/k_bocw_headshot-01.wav",
            "KillSounds/CODBOCW/k_bocw_headshot-02.wav",
            "KillSounds/CODBOCW/k_bocw_headshot-03.wav",
        },
    },
    CODVG = {
        normal = {
            "KillSounds/CODVG/k_codvg_01.wav",
            "KillSounds/CODVG/k_codvg_04.wav",
            "KillSounds/CODVG/k_codvg_v4_01.wav",
        },
        headshot = {
            "KillSounds/CODVG/k_codvg_headshot_01.wav",
            "KillSounds/CODVG/k_codvg_headshot_metal_01.wav",
        },
    },
    Overwatch = {
        normal = {
            "KillSounds/Overwatch/killsound_ow_normal.wav",
            "KillSounds/Overwatch/killsound_ow2_normal.wav",
        },
        headshot = {
            "KillSounds/Overwatch/killsound_ow_normal.wav",
        },
    },
    -- §12 新增 4 个击杀音源（2026-07-01）
    -- 注：CODWZ2 armor 归 normal 作为第 2 变体（用户决策，详见 §12.3.3）
    -- 注：缺 headshot 文件的游戏依赖现有 line 535-541 的 fallback 自动顶上 normal（§12.3.4 已实现）
    CODWZ = {
        normal = {
            "KillSounds/CODWZ/killsound_codwz_normal.wav",
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
    CODWZ2 = {
        normal = {
            "KillSounds/CODWZ2/killsound_codwz2_normal.wav",
            "KillSounds/CODWZ2/k_codwz2_armor.wav",  -- armor 归 normal（§12.3.3）
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
    DeltaForce = {
        normal = {
            "KillSounds/DeltaForce/k_deltaforce_normal.wav",
        },
        headshot = {
            "KillSounds/DeltaForce/k_deltaforce_headshot.wav",
        },
    },
    APEX = {
        normal = {
            "KillSounds/APEX/k_apex_shieldbreak.wav",
        },
        headshot = {},  -- 缺 headshot，fallback 到 normal
    },
    CODBO7 = {
        normal = {
            "KillSounds/CODBO7/k_bo7-01.wav",
            "KillSounds/CODBO7/k_bo7-02.wav",
            "KillSounds/CODBO7/k_bo7-03.wav",
        },
        headshot = {
            "KillSounds/CODBO7/k_bo7_headshot.wav",
        },
    },
}

-- 命中间隔控制（秒）
local HIT_COOLDOWN = 0.08
local last_hit_time = 0

-- 音效播放通道定义在 player.lua, 通过 HKS.HitKillSoundsPlayer.TRACKS 访问
local function get_random_sound(sounds)
    if not sounds or #sounds == 0 then
        return nil
    end
    return sounds[math.random(#sounds)]
end

local function play_hit_sound(is_headshot, is_melee)
    local TRACKS = HKS.HitKillSoundsPlayer.TRACKS
    local game
    if is_melee then
        if is_headshot then
            game = HKS:get("hit_melee_headshot")
                  or HKS:get("hit_headshot_game")
                  or HKS:get("hit_game")
                  or "BF1"
        else
            game = HKS:get("hit_melee_normal")
                  or HKS:get("hit_game_normal")
                  or HKS:get("hit_game")
                  or "BF1"
        end
    else
        if is_headshot then
            game = HKS:get("hit_headshot_game") or HKS:get("hit_game") or "BF1"
        else
            game = HKS:get("hit_game_normal") or HKS:get("hit_game") or "BF1"
        end
    end
    local volume = HKS:get("hit_volume") or 100
    local sound_type = is_headshot and "headshot" or "normal"
    local sounds = HIT_SOUNDS[game]

    if not sounds then
        HKS:warning("Hit_Kill_Sounds: 未找到游戏 " .. game .. " 的命中音效")
        return
    end

    local sound_list = sounds[sound_type]
    if not sound_list or #sound_list == 0 then
        sound_list = sounds.normal
        if not sound_list or #sound_list == 0 then
            return
        end
    end

    local sound_file = get_random_sound(sound_list)
    if sound_file then
        local track = is_headshot and TRACKS.HIT_HEADSHOT or TRACKS.HIT_NORMAL
        local priority = is_headshot and AUDIO_PRIORITY.HEADSHOT_HIT or AUDIO_PRIORITY.HIT
        local sound_kind = is_headshot and "hit_headshot" or "hit_normal"

        queue_sound(sound_file, track, volume, priority, sound_kind)
    end
end

local function play_kill_sound(is_headshot)
    local TRACKS = HKS.HitKillSoundsPlayer.TRACKS
    local game
    local use_normal_sound = is_headshot and HKS:get("kill_headshot_use_normal") == true

    if is_headshot then
        game = HKS:get("kill_headshot_game") or HKS:get("kill_game") or "BF1"
    else
        game = HKS:get("kill_game_normal") or HKS:get("kill_game") or "BF1"
    end
    local volume = get_kill_volume(is_headshot)
    local sound_type = is_headshot and not use_normal_sound and "headshot" or "normal"
    local sounds = KILL_SOUNDS[game]

    if not sounds then
        HKS:warning("Hit_Kill_Sounds: 未找到游戏 " .. game .. " 的击杀音效")
        return
    end

    local sound_list = sounds[sound_type]
    if not sound_list or #sound_list == 0 then
        sound_list = sounds.normal
        if not sound_list or #sound_list == 0 then
            return
        end
    end

    local sound_file = get_random_sound(sound_list)
    if sound_file then
        local track = is_headshot and not use_normal_sound and TRACKS.KILL_HEADSHOT or TRACKS.KILL_NORMAL
        local priority = is_headshot and AUDIO_PRIORITY.HEADSHOT_KILL or AUDIO_PRIORITY.KILL
        local sound_kind = is_headshot and "kill_headshot" or "kill_normal"

        queue_sound(sound_file, track, volume, priority, sound_kind)
    end
end

local function can_play_hit()
    local current_time = Managers.time:time("main")
    if current_time - last_hit_time >= HIT_COOLDOWN then
        last_hit_time = current_time
        return true
    end
    return false
end

-- 处理攻击结果的内部函数
local function handle_attack_result(damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike)
    -- 总开关关闭时静默
    if not HKS:get("enabled") then
        return
    end

    -- §11.B 同伴攻击判定（用户 2026-07-01 决策：仅识别 Adamant 狗）
    local is_companion_attack = attack_type and COMPANION_ATTACK_TYPES[attack_type] == true

    -- 只处理有效伤害
    if not damage or damage <= 0 then
        return
    end

    -- 检查是否是本地玩家攻击
    local local_player = Managers.player and Managers.player:local_player_safe(1)
    if not local_player or not local_player.player_unit then
        return
    end

    if attacking_unit ~= local_player.player_unit then
        return
    end

    -- DoT伤害类型检测
    -- 优先依据 damage_profile.damage_type 字段（权威，由 damage_profile 显式声明）
    -- 后备依据 damage_profile.name 关键字模糊匹配（兼容部分未显式设置 damage_type 的 buff 类伤害）
    local is_dot_damage = false
    if damage_profile then
        -- 主判定：damage_type 字段查表
        local dt = damage_profile.damage_type
        if dt and DOT_DAMAGE_TYPES[dt] then
            is_dot_damage = true
        elseif damage_profile.name then
            -- 后备判定：profile name 关键字模糊匹配
            local profile_name = damage_profile.name:lower()
            if profile_name:find("bleed") or profile_name:find("burn") or profile_name:find("fire") or
               profile_name:find("toxin") or profile_name:find("corruption") or profile_name:find("grimoire") or
               profile_name:find("electrocution") or profile_name:find("warpfire") or
               profile_name:find("chain_lighting") or profile_name:find("chain_lightning") then
                is_dot_damage = true
            end
        end
    end

    -- 获取breed信息
    local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local breed_or_nil = unit_data_extension and unit_data_extension:breed()

    -- 如果是击杀
    if attack_result == AttackSettings.attack_results.died then
        local is_kill_headshot = hit_weakspot == true

        -- §23：三个输出各自使用自己的目标设置和连杀计数器。
        --   bf4_feed_target  -> BF4 文字事件 / bf4_feed_counter
        --   kill_target      -> CF 音效 / cf_sound_counter
        --   kill_icon_target -> CF 图标 / cf_icon_counter
        local kill_target_setting = HKS:get("kill_target") or "all"
        local kill_icon_target_setting = HKS:get("kill_icon_target") or "all"
        local bf4_feed_target_setting = HKS:get("bf4_feed_target") or "all"
        local kill_sound_target_valid = is_target_valid(breed_or_nil, kill_target_setting)
        local kill_icon_target_valid = is_target_valid(breed_or_nil, kill_icon_target_setting)
        local bf4_feed_target_valid = is_target_valid(breed_or_nil, bf4_feed_target_setting)

        -- DoT 击杀「音效」与「图标」解耦（§14 修复）：
        --   kill_dot       → 控制 DoT 击杀【音效】（默认 true=播音）
        --   kill_dot_icon  → 控制 DoT 击杀【图标】（默认 true=显示）
        -- 普通（非 DoT）击杀：两个守卫均为 true，照常处理；不引入任何回归。
        local dot_sound_allowed = not (is_dot_damage and not HKS:get("kill_dot"))
        local dot_icon_allowed  = not (is_dot_damage and not HKS:get("kill_dot_icon"))

        -- §11.B 同伴击杀分流（默认 ON 保持老用户行为兼容）
        local companion_kill_sound_allowed = not (is_companion_attack and not HKS:get("companion_kill_sound_enabled"))
        local companion_kill_icon_allowed  = not (is_companion_attack and not HKS:get("companion_kill_icon_enabled"))

        -- 所有计数资格都在击杀事件入口一次性确定。音频队列和 HUD 只消费
        -- 本次 accept() 返回的序号，不再从其他输出或共享状态重新读取计数。
        local now = Managers.time:time("main")
        local killstreak_enabled = is_killstreak_enabled()
        local is_boss = breed_or_nil and breed_or_nil.is_boss == true

        local cf_sound_on = killstreak_enabled and HKS:get("cf_kill_sound_enabled") and HKS:get("kill_sound_enabled")
        local cf_icon_on = killstreak_enabled and HKS:get("kill_icon_style") == "CF" and HKS:get("kill_icon_enabled")

        local cf_sound_active = cf_sound_on and kill_sound_target_valid and
            dot_sound_allowed and companion_kill_sound_allowed
        local cf_icon_active = cf_icon_on and kill_icon_target_valid and
            dot_icon_allowed and companion_kill_icon_allowed

        if not killstreak_enabled then
            -- 设置回调负责正常清理；此处处理关闭后尚未收到回调的边界情况，
            -- 防止重新开启时继承关闭期间隐藏的序号。
            if HKS.reset_all_killstreak_counters then
                HKS.reset_all_killstreak_counters("killstreak_disabled")
            end
            clear_cf_icon_state()
        end

        -- BF4 只由自己的有效文字事件刷新活动时间，并只推进自己的计数器。
        local bf4_event_added = add_bf4_score_feed(
            breed_or_nil,
            is_kill_headshot,
            killstreak_enabled and ScoreFeed and ScoreFeed.is_enabled and
                ScoreFeed.is_enabled() and bf4_feed_target_valid
        )
        if bf4_event_added then
            accept_counter(bf4_feed_counter, now, true)
        end

        -- Boss 仍可触发各自的专属输出，但不得修改普通 CF 音效/图标计数器。
        local sound_streak_count = accept_counter(
            cf_sound_counter,
            now,
            cf_sound_active and not is_boss
        )
        local icon_streak_count = accept_counter(
            cf_icon_counter,
            now,
            cf_icon_active and not is_boss
        )

        if is_boss then
            _cf_on_boss_kill(is_kill_headshot, cf_sound_active, cf_icon_active, now)
        else
            if sound_streak_count then
                _cf_on_sound_kill(is_kill_headshot, sound_streak_count)
            end
            if icon_streak_count then
                _cf_on_icon_kill(is_kill_headshot, icon_streak_count, now)
            end
        end

        -- BF5 音效：仅当 CF 音效未激活时（叠加 kill_sound_target_valid）
        if not cf_sound_active and kill_sound_target_valid and dot_sound_allowed and
            companion_kill_sound_allowed and HKS:get("kill_sound_enabled") then
            play_kill_sound(is_kill_headshot)
        end

        -- BF5 图标：仅当 CF 图标未激活时（叠加 kill_icon_target_valid）
        if not cf_icon_active and kill_icon_target_valid and dot_icon_allowed and
            companion_kill_icon_allowed and HKS:get("kill_icon_enabled") and HKS.HitKillIconManager then
            HKS.HitKillIconManager.show_icon(is_kill_headshot)
        end

        return
    end

    -- 命中音效子开关关闭时静默
    if not HKS:get("hit_sound_enabled") then
        return
    end

    -- §11.B 同伴命中分流（默认 ON 保持老用户行为兼容）
    local enable_companion_hit = HKS:get("companion_hit_sound_enabled")
    if is_companion_attack and not enable_companion_hit then
        return
    end

    -- 检查dot命中音效开关
    local enable_dot_hit = HKS:get("hit_dot")
    if is_dot_damage and not enable_dot_hit then
        return
    end

    -- 检查是否有效命中结果
    local valid_results = {
        [AttackSettings.attack_results.damaged] = true,
        [AttackSettings.attack_results.toughness_absorbed] = true,
        [AttackSettings.attack_results.toughness_absorbed_melee] = true,
        [AttackSettings.attack_results.toughness_broken] = true,
    }
    if not valid_results[attack_result] then
        return
    end

    -- 检查近战命中音效开关
    local enable_melee_hit = HKS:get("hit_melee")
    if attack_type == "melee" and not enable_melee_hit then
        return
    end

    -- 检查目标类型
    local hit_target_setting = HKS:get("hit_target") or "all"
    if not is_target_valid(breed_or_nil, hit_target_setting) then
        return
    end

    local is_weakspot = hit_weakspot == true

    if can_play_hit() then
        local is_melee = attack_type == "melee"
        play_hit_sound(is_weakspot, is_melee)
    end
end

-- 初始化Damage hook
HKS.HitKillSoundsEvents.init_damage_hooks = function()
    if damage_hooks_initialized then
        return
    end

    damage_hooks_initialized = true

    HKS:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
        func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
        handle_attack_result(damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike)
    end)

    -- 钩住 Wwise 事件触发器，按 setting 静音游戏自带的命中/击杀音效。
    -- 使用 vararg 原样转发，避免把 Stingray Unit/Vector3 userdata 当作普通 Lua type，
    -- 也避免丢失 source id、Unit、Vector3 以及 start/stop event 的附加参数。
    -- 该转发方式与 SimpleAudio/.../wwise/hooks.lua 的实现一致。
    HKS:hook(CLASS.WwiseWorld, "trigger_resource_event", function(func, wwise_world, wwise_event_name, ...)
        if is_event_silenced(wwise_event_name) then
            return
        end

        return func(wwise_world, wwise_event_name, ...)
    end)

    rebuild_silenced_patterns()
    -- 注意：_preload_cf_icons 不在这里调用！
    --   时机问题：on_all_mods_loaded 在所有 mod 加载后立即触发，
    --   但 HitKillSoundsPlayer 启动的 HTTP 服务器可能尚未就绪 → 纹理加载静默失败
    --   修复：把加载移到 HudHitKillCF.init（与 BFV hud.lua + EBuyToDeep multikill.lua 一致，
    --   都是在 HUD 初始化时加载，那时 HTTP 服务器一定就绪）
end

HKS.HitKillSoundsEvents.rebuild_silenced_patterns = rebuild_silenced_patterns
HKS.HitKillSoundsEvents._preload_cf_icons = _preload_cf_icons  -- 暴露给 HudHitKillCF.init 调用（修复时序问题）
-- 兼容旧调用方：reset_cf_state 现在只清理图标显示状态，不触碰任何计数器。
HKS.HitKillSoundsEvents.reset_cf_state = clear_cf_icon_state
HKS.HitKillSoundsEvents.clear_cf_icon_state = clear_cf_icon_state

-- §23 仅暴露三个独立实例；不存在可供 CF 音效和图标共用的 streak_count。
HKS.HitKillSoundsKillstreakStates = killstreak_counters
HKS.HitKillSoundsCFIconState = cf_icon_state
HKS.HitKillSoundsCFState = cf_icon_state

return HKS.HitKillSoundsEvents
