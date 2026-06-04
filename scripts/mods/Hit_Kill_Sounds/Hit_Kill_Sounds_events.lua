local HKS = get_mod("Hit_Kill_Sounds")

HKS.HitKillSoundsEvents = {}

-- 引入AttackSettings用于攻击结果检测
local AttackSettings = require("scripts/settings/damage/attack_settings")

-- 声类型枚举（与 EBuyToDeepPlayer.lua:289-297 一致）
local SOUND_TYPE = table.enum(
    "2d_sound",
    "3d_sound",
    "start_stop_event",
    "external_sound",
    "source_sound",
    "unit_sound",
    "unknown_userdata_sound"
)

-- 声类型映射：第二个参数（position_or_unit_or_id）的 Lua 类型 → SOUND_TYPE
local sound_type_map = {
    ["nil"]     = SOUND_TYPE["2d_sound"],
    ["boolean"] = SOUND_TYPE["start_stop_event"],
    ["number"]  = SOUND_TYPE["source_sound"],
    ["Vector3"] = SOUND_TYPE["3d_sound"],
    ["Unit"]    = SOUND_TYPE["unit_sound"],
}

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
}

-- 命中间隔控制（秒）
local HIT_COOLDOWN = 0.08
local last_hit_time = 0

-- 目标类型检测函数
-- target_setting: "all" | "elite" | "special" | "elite_special_boss"
local function is_target_valid(breed_or_nil, target_setting)
    if not target_setting or target_setting == "all" then
        return true
    end

    if not breed_or_nil then
        return false
    end

    local tags = breed_or_nil.tags
    if not tags then
        return false
    end

    if target_setting == "elite" then
        return tags.elite == true
    elseif target_setting == "special" then
        return tags.special == true
    elseif target_setting == "elite_special_boss" then
        return tags.elite == true or tags.special == true or tags.monster == true or tags.captain == true
    end

    return true
end

-- 音效播放通道定义在 player.lua, 通过 HKS.HitKillSoundsPlayer.TRACKS 访问
local function get_random_sound(sounds)
    if not sounds or #sounds == 0 then
        return nil
    end
    return sounds[math.random(#sounds)]
end

local function play_hit_sound(is_headshot)
    local TRACKS = HKS.HitKillSoundsPlayer.TRACKS
    local game = HKS:get("hit_game") or "BF1"
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
        HKS.HitKillSoundsPlayer.play_file(sound_file, track, volume)
    end
end

local function play_kill_sound(is_headshot)
    local TRACKS = HKS.HitKillSoundsPlayer.TRACKS
    local game = HKS:get("kill_game") or "BF1"
    local volume = HKS:get("kill_volume") or 100
    local sound_type = is_headshot and "headshot" or "normal"
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
        local track = is_headshot and TRACKS.KILL_HEADSHOT or TRACKS.KILL_NORMAL
        HKS.HitKillSoundsPlayer.play_file(sound_file, track, volume)
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
    local is_dot_damage = false
    if damage_profile and damage_profile.name then
        local profile_name = damage_profile.name:lower()
        if profile_name:find("bleed") or profile_name:find("burn") or profile_name:find("fire") or
           profile_name:find("toxin") or profile_name:find("corruption") or profile_name:find("grimoire") or
           profile_name:find("electrocution") or profile_name:find("warpfire") then
            is_dot_damage = true
        end
    end

    -- 获取breed信息
    local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local breed_or_nil = unit_data_extension and unit_data_extension:breed()

    -- 如果是击杀
    if attack_result == AttackSettings.attack_results.died then
        -- 检查DoT击杀音效开关
        local enable_dot_kill = HKS:get("kill_dot")
        if is_dot_damage and not enable_dot_kill then
            return
        end

        local is_kill_headshot = hit_weakspot == true

        local kill_target_setting = HKS:get("kill_target") or "all"
        if not is_target_valid(breed_or_nil, kill_target_setting) then
            return
        end

        -- 播放击杀音效
        if HKS:get("kill_sound_enabled") then
            play_kill_sound(is_kill_headshot)
        end

        -- 显示击杀图标
        if HKS:get("kill_icon_enabled") and HKS.HitKillIconManager then
            HKS.HitKillIconManager.show_icon(is_kill_headshot)
        end

        return
    end

    -- 命中音效子开关关闭时静默
    if not HKS:get("hit_sound_enabled") then
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
        play_hit_sound(is_weakspot)
    end
end

-- 初始化Damage hook
HKS.HitKillSoundsEvents.init_damage_hooks = function()
    HKS:hook(CLASS.AttackReportManager, "add_attack_result", function(func, self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
        func(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
        handle_attack_result(damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike)
    end)

    -- 钩住 Wwise 事件触发器，按 setting 静音游戏自带的命中/击杀音效
    -- 注意：trigger_resource_event 必须按声类型（2d/3d/unit/source/start_stop）传不同数量参数，
    -- 多传参数会被 Wwise 当作 source_id 解释并触发 "Bad Source Id parameter" 崩溃。
    -- 实现参考：EBuyToDeepPlayer.lua:425-459
    HKS:hook(CLASS.WwiseWorld, "trigger_resource_event", function(func, wwise_world, wwise_event_name, position_or_unit_or_id, optional_a, optional_b)
        if is_event_silenced(wwise_event_name) then
            return
        end

        local var_type = type(position_or_unit_or_id)
        local sound_type = sound_type_map[var_type]

        if sound_type == SOUND_TYPE["2d_sound"] then
            return func(wwise_world, wwise_event_name)
        elseif sound_type == SOUND_TYPE["3d_sound"] then
            return func(wwise_world, wwise_event_name, position_or_unit_or_id)
        elseif sound_type == SOUND_TYPE["start_stop_event"] then
            return func(wwise_world, wwise_event_name, position_or_unit_or_id, optional_a, optional_b)
        elseif sound_type == SOUND_TYPE["source_sound"] then
            return func(wwise_world, wwise_event_name, position_or_unit_or_id)
        elseif sound_type == SOUND_TYPE["unit_sound"] then
            return func(wwise_world, wwise_event_name, position_or_unit_or_id, optional_a)
        end

        -- 兜底：未识别声类型 → 安全按 2 个参数调用（最少破坏性）
        return func(wwise_world, wwise_event_name)
    end)

    rebuild_silenced_patterns()
end

HKS.HitKillSoundsEvents.rebuild_silenced_patterns = rebuild_silenced_patterns

return HKS.HitKillSoundsEvents
