-- luacheck: globals get_mod Mods Managers ScriptUnit CLASS Unit Vector3 Localize
local HKS = get_mod("Hit_Kill_Sounds")

HKS.HitKillSoundsEvents = {}
local damage_hooks_initialized = false
local AudioBackend = HKS.HitKillSoundsAudioBackend
local ScoreFeed = HKS.HitKillSoundsScoreFeed
local killstreak_counters = HKS.HitKillSoundsKillstreakCounters or {}
local bf4_feed_counter = killstreak_counters.bf4_feed_counter
local cf_sound_counter = killstreak_counters.cf_sound_counter
local cf_icon_counter = killstreak_counters.cf_icon_counter
local valorant_sound_counter = killstreak_counters.valorant_sound_counter
local valorant_icon_counter = killstreak_counters.valorant_icon_counter
local VALORANT_DISPLAY_MAX = 5
local AUDIO_PRIORITY = AudioBackend and AudioBackend.PRIORITY or {
    BOSS = 0,
    HEADSHOT_KILL = 1,
    CF_KILL = 1,
    VALORANT_KILL = 1,
    KILL = 2,
    HEADSHOT_HIT = 3,
    HIT = 4,
}

-- 引入AttackSettings用于攻击结果检测
local AttackSettings = require("scripts/settings/damage/attack_settings")
local DamageSettings = require("scripts/settings/damage/damage_settings")
local Breed = require("scripts/utilities/breed")
local Items = require("scripts/utilities/items")
local damage_types = DamageSettings.damage_types

local ABILITY_DISPLAY_ALIASES = {
    psyker_discharge_shout_improved = "psyker_discharge_shout",
    zealot_targeted_dash_improved = "zealot_targeted_dash",
    zealot_targeted_dash_improved_double = "zealot_targeted_dash",
    ogryn_charge_cooldown_reduction = "ogryn_charge",
    ogryn_charge_damage = "ogryn_charge",
    ogryn_charge_increased_distance = "ogryn_charge",
    ogryn_charge_bleed = "ogryn_charge",
    ogryn_grenade_box_cluster = "ogryn_grenade_box",
    veteran_combat_ability_stance_improved = "veteran_combat_ability_stance",
    zealot_invisibility_improved = "zealot_invisibility",
    psyker_force_field_improved = "psyker_force_field",
    adamant_shout_improved = "adamant_shout",
    adamant_grenade_improved = "adamant_grenade",
    broker_ability_focus_improved = "broker_ability_focus",
    broker_flash_grenade_improved = "broker_flash_grenade",
    cryptic_discharge_base = "cryptic_discharge",
}

local BLITZ_DAMAGE_PROFILES = {
    -- Veteran
    frag_grenade = "veteran_frag_grenade",
    close_frag_grenade = "veteran_frag_grenade",
    frag_grenade_impact = "veteran_frag_grenade",
    krak_grenade = "veteran_krak_grenade",
    close_krak_grenade = "veteran_krak_grenade",
    krak_grenade_impact = "veteran_krak_grenade",
    smoke_grenade = "veteran_smoke_grenade",
    -- Zealot
    shock_grenade = "zealot_shock_grenade",
    shock_grenade_stun_interval = "zealot_shock_grenade",
    fire_grenade_impact = "zealot_fire_grenade",
    flame_grenade_liquid_area_fire_burning = "zealot_fire_grenade",
    zealot_throwing_knives = "zealot_throwing_knives",
    -- Ogryn
    ogryn_grenade = "ogryn_grenade_frag",
    close_ogryn_grenade = "ogryn_grenade_frag",
    ogryn_grenade_impact = "ogryn_grenade_frag",
    ogryn_grenade_box_impact = "ogryn_grenade_box",
    ogryn_grenade_box_cluster_impact = "ogryn_grenade_box",
    ogryn_box_cluster_frag_grenade = "ogryn_grenade_box",
    ogryn_box_cluster_close_frag_grenade = "ogryn_grenade_box",
    ogryn_friendly_rock_impact = "ogryn_grenade_friend_rock",
    -- Psyker
    psyker_smite_kill = "psyker_smite",
    psyker_smite_stagger = "psyker_smite",
    psyker_smite_light = "psyker_smite",
    psyker_smite_heavy = "psyker_smite",
    psyker_biomancer_soul = "psyker_smite",
    psyker_throwing_knives = "psyker_throwing_knives",
    psyker_throwing_knives_aimed = "psyker_throwing_knives",
    psyker_throwing_knives_aimed_pierce = "psyker_throwing_knives",
    psyker_throwing_knives_pierce = "psyker_throwing_knives",
    psyker_throwing_knives_psychic_fortress = "psyker_throwing_knives",
    psyker_protectorate_chain_lighting = "psyker_chain_lightning",
    psyker_protectorate_chain_lighting_fast = "psyker_chain_lightning",
    psyker_protectorate_spread_chain_lightning_interval = "psyker_chain_lightning",
    psyker_protectorate_channel_chain_lightning_activated = "psyker_chain_lightning",
    psyker_heavy_swings_shock = "psyker_chain_lightning",
    psyker_stun = "psyker_chain_lightning",
    chain_lightning_killing_blow = "psyker_chain_lightning",
    -- Arbites (adamant)
    adamant_grenade = "adamant_grenade",
    close_adamant_grenade = "adamant_grenade",
    adamant_grenade_impact = "adamant_grenade",
    whistle_explosion = "adamant_whistle",
    close_whistle_explosion = "adamant_whistle",
    shock_mine_self_destruct = "adamant_shock_mine",
    -- Hive Scum (broker)
    broker_flash_grenade = "broker_flash_grenade",
    broker_flash_grenade_close = "broker_flash_grenade",
    broker_flash_grenade_impact = "broker_flash_grenade",
    broker_tox_grenade = "broker_tox_grenade",
    broker_missile_launcher_explosion = "broker_missile_launcher",
    broker_missile_launcher_explosion_close = "broker_missile_launcher",
    broker_missile_launcher_impact = "broker_missile_launcher",
    missile_launcher_knockback = "broker_missile_launcher",
    -- Cryptic
    arc_grenade = "arc_grenade",
    arc_grenade_chain_jump_damage = "arc_grenade",
    cryptic_arc_grenade_shock_damage = "arc_grenade",
    force_field_explosion_damage = "cryptic_force_field",
    force_field_chain_jump_damage = "cryptic_force_field",
}

local COMBAT_ABILITY_DAMAGE_PROFILES = {
    shout_stagger_veteran = "veteran_combat_ability_shout",
    zealot_dash_impact = "zealot_targeted_dash",
    zealot_dash_health_to_damage_transfer = "zealot_targeted_dash",
    zealot_preacher_ability_close = "zealot_relic",
    zealot_preacher_ability_far = "zealot_relic",
    zealot_channel_stagger = "zealot_relic",
    ogryn_charge_impact = "ogryn_charge",
    ogryn_charge_finish = "ogryn_charge",
    ogryn_charge_impact_damage = "ogryn_charge",
    ogryn_charge_finish_damage = "ogryn_charge",
    shout_stagger_ogryn_taunt = "ogryn_taunt_shout",
    psyker_biomancer_shout = "psyker_discharge_shout",
    psyker_biomancer_shout_damage = "psyker_discharge_shout",
    psyker_shield_stagger = "psyker_force_field",
    adamant_shout = "adamant_shout",
    adamant_shout_damage = "adamant_shout",
    adamant_charge_impact = "adamant_charge",
    adamant_charge_damage = "adamant_charge",
    broker_stimm_field = "broker_ability_stimm_field",
    broker_stimm_field_close = "broker_ability_stimm_field",
    broker_punk_rage_shout = "broker_ability_punk_rage",
    cryptic_discharge_explosion = "cryptic_discharge",
    cryptic_discharge_weapon_malfunction_explosion = "cryptic_discharge",
    cryptic_discharge_shock_damage = "cryptic_discharge",
    discharge_chain_jump_damage = "cryptic_discharge",
    chordclaw_main = "cryptic_chordclaw",
    chordclaw_light = "cryptic_chordclaw",
    chordclaw_horizontal = "cryptic_chordclaw",
    chordclaw_stab_bleed = "cryptic_chordclaw",
    chordclaw_sticky = "cryptic_chordclaw",
    chordclaw_sticky_dodge = "cryptic_chordclaw",
}

local WEAPON_EXPLOSION_SLOT_BY_PROFILE = {
    ogryn_thumper_p1_m2_default = "slot_secondary",
    ogryn_thumper_p1_m2_close = "slot_secondary",
    ogryn_thumper_p1_m2_default_instant = "slot_secondary",
    ogryn_thumper_p1_m2_close_instant = "slot_secondary",
    thumper_grenade_impact = "slot_secondary",
    close_gauntlet_demolitions = "slot_secondary",
    close_special_gauntlet_demolitions = "slot_secondary",
    default_gauntlet_demolitions = "slot_secondary",
    bolter_kill_explosion = "slot_secondary",
    bolter_m2_kill_explosion = "slot_secondary",
    bolter_m2_stop_explosion = "slot_secondary",
    bolter_stop_explosion = "slot_secondary",
    boltpistol_kill_explosion = "slot_secondary",
    boltpistol_m2_kill_explosion = "slot_secondary",
    boltpistol_m2_stop_explosion = "slot_secondary",
    boltpistol_stop_explosion = "slot_secondary",
    plasma_demolition = "slot_secondary",
    plasma_overheat = "slot_secondary",
    close_charged_plasma_demolition_p1_m2 = "slot_secondary",
    close_light_plasma_demolition = "slot_secondary",
    close_light_plasma_demolition_p1_m2 = "slot_secondary",
    default_plasma_demolition = "slot_secondary",
    far_charged_plasma_demolition_p1_m2 = "slot_secondary",
    far_light_plasma_demolition_p1_m2 = "slot_secondary",
    light_plasma_demolition = "slot_secondary",
    force_staff_demolition_close = "slot_secondary",
    force_staff_demolition_default = "slot_secondary",
    close_force_staff_demolition = "slot_secondary",
    default_force_staff_demolition = "slot_secondary",
    close_force_staff_p4_demolition = "slot_secondary",
    force_staff_p4_demolition = "slot_secondary",
    needlepistol_explosion_parent = "slot_secondary",
    phosphor_pistol_backblast_explosion = "slot_secondary",
    primer_explosion = "slot_secondary",
    primer_explosion_close = "slot_secondary",
    primer_gas = "slot_secondary",
    primer_stun = "slot_secondary",
    powermaul_explosion = "slot_primary",
    powermaul_explosion_outer = "slot_primary",
    powermaul_explosion_m2 = "slot_primary",
    powermaul_explosion_outer_m2 = "slot_primary",
    ogryn_powermaul_explosion = "slot_primary",
    ogryn_powermaul_explosion_outer = "slot_primary",
    forcesword_explosion = "slot_primary",
    forcesword_explosion_outer = "slot_primary",
    powersword_explosion = "slot_primary",
    powersword_explosion_outer = "slot_primary",
    trait_powersword_2h_p1_trade_overheat_lockout_for_damage = "slot_primary",
}

local PROP_EXPLOSION_PROFILES = {
    barrel_explosion = true,
    barrel_explosion_close = true,
    fire_barrel_explosion = true,
    fire_barrel_explosion_close = true,
    promethium_barrel_explosion = true,
    promethium_barrel_explosion_close = true,
    flamer_backpack_explosion = true,
    flamer_backpack_explosion_close = true,
    interrupted_flamer_backpack_explosion = true,
    interrupted_flamer_backpack_explosion_close = true,
    breach_charge_explosion = true,
    expeditions_big_grenade = true,
    expeditions_big_grenade_close = true,
    attack_valkyrie_missile_explosion = true,
    attack_valkyrie_missile_explosion_close = true,
    expeditions_lightning_strike_explosion = true,
    expeditions_lightning_strike_explosion_close = true,
}

local ability_display_name_cache = nil

local function get_ability_display_name_map()
    if ability_display_name_cache ~= nil then
        return ability_display_name_cache
    end

    local map = {}
    local ok, archetype_talents = pcall(require, "scripts/settings/ability/archetype_talents/archetype_talents")
    if ok and type(archetype_talents) == "table" then
        for _, talents in pairs(archetype_talents) do
            if type(talents) == "table" then
                for talent_name, talent in pairs(talents) do
                    local player_ability = type(talent) == "table" and talent.player_ability
                    local ability = type(player_ability) == "table" and player_ability.ability
                    local ability_name = type(ability) == "table" and ability.name
                    local display_name = type(talent) == "table" and talent.display_name
                    if type(ability_name) == "string" and type(display_name) == "string" and
                        string.sub(display_name, 1, 4) == "loc_" then
                        if not map[ability_name] or talent_name == ability_name then
                            map[ability_name] = display_name
                        end
                    end
                end
            end
        end
    end

    ability_display_name_cache = map
    return map
end

-- 只保留有明确持续伤害语义的通用 damage_type。electrocution 必须通过
-- damage_profile.name 精确判定，不能把所有电击伤害都当成 DoT。
local DOT_DAMAGE_TYPES = {
    [damage_types.bleeding] = true,
    [damage_types.burning] = true,
    [damage_types.toxin] = true,
    [damage_types.corruption] = true,
    [damage_types.grimoire] = true,
    [damage_types.warpfire] = true,
}

local ELECTROCUTION_DOT_PROFILES = {
    shock_grenade_stun_interval = true,
    default_chain_lighting_interval = true,
    psyker_protectorate_spread_chain_lightning_interval = true,
    psyker_heavy_swings_shock = true,
    psyker_stun = true,
    shockmaul_stun_interval_damage = true,
    powermaul_p2_stun_interval = true,
    powermaul_p2_stun_interval_basic = true,
    cryptic_discharge_shock_damage = true,
    cryptic_arc_grenade_shock_damage = true,
    cryptic_arc_shock_damage = true,
    cryptic_discharge_weapon_shock = true,
    broker_toxin_stacks_stun_interval = true,
}

-- 通用 tick 的运行时 damage_type 未必写回 profile，按 1.13.2 源码补充精确名称。
local GENERIC_DOT_PROFILES = {
    bleeding = true,
    burning = true,
    phosphor_burning = true,
    liquid_area_fire_burning = true,
    liquid_area_fire_burning_barrel = true,
    flame_grenade_liquid_area_fire_burning = true,
    grenadier_liquid_fire_burning = true,
    cultist_flamer_liquid_fire_burning = true,
    renegade_flamer_liquid_fire_burning = true,
    horde_flame_impact = true,
    spillway_wizard_dance_floor_burn = true,
    toxin_variant_1 = true,
    toxin_variant_2 = true,
    toxin_variant_3 = true,
    horde_mode_self_propagating_toxin = true,
    corruptor_damage_tick = true,
    corruptor_liquid_corruption = true,
    daemonhost_corruption_aura = true,
    mutator_green_corruption = true,
    mutator_corruption = true,
    toxic_gas = true,
    toxic_gas_mutator = true,
    cultist_grenadier_gas = true,
}

local NON_DOT_DAMAGE_PROFILES = {
    default_chain_lighting_attack = true,
    psyker_protectorate_channel_chain_lightning_activated = true,
    psyker_shield_stagger = true,
    chain_lightning_killing_blow = true,
    default_flamer_assault = true,
    default_flamer_assault_burst = true,
    default_warpfire_assault = true,
    default_warpfire_assault_burst = true,
    shockmaul_shield_stun_interval_damage = true,
}

local VALID_HIT_RESULTS = {
    [AttackSettings.attack_results.damaged] = true,
    [AttackSettings.attack_results.toughness_absorbed] = true,
    [AttackSettings.attack_results.toughness_absorbed_melee] = true,
    [AttackSettings.attack_results.toughness_broken] = true,
}

-- §11.B 同伴攻击识别：保留 Adamant 狗 attack_type，并按精确伤害配置补充 Servo skull。
local COMPANION_ATTACK_TYPES = {
    [AttackSettings.attack_types.companion_dog] = true,
}
local COMPANION_DAMAGE_PROFILES = {
    -- Servo skull 激光
    default_companion_servo_skull_lasgun_killshot = true,
    improved_companion_servo_skull_lasgun_killshot = true,
    -- Servo skull 火焰初始直击（后续燃烧 tick 使用通用 burning 配置）
    companion_servo_skull_flamer = true,
}
local SERVO_SKULL_FLAMER_DIRECT_DAMAGE_PROFILE = "companion_servo_skull_flamer"
NON_DOT_DAMAGE_PROFILES[SERVO_SKULL_FLAMER_DIRECT_DAMAGE_PROFILE] = true

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

local function is_kill_feedback_target_excluded(breed_or_nil)
    if not breed_or_nil then
        return true
    end

    return Breed.is_player(breed_or_nil) or Breed.is_prop(breed_or_nil) or breed_or_nil.has_scripted_death_sequence == true
end

local function is_dot_damage_profile(damage_profile, attack_type)
    if not damage_profile then
        return false
    end

    local profile_name = damage_profile.name

    if NON_DOT_DAMAGE_PROFILES[profile_name] then
        return false
    end

    if profile_name == "primer_stun" then
        return attack_type == AttackSettings.attack_types.buff or attack_type == "buff"
    end

    if ELECTROCUTION_DOT_PROFILES[profile_name] or GENERIC_DOT_PROFILES[profile_name] then
        return true
    end

    local damage_type = damage_profile.damage_type

    return damage_type ~= nil and DOT_DAMAGE_TYPES[damage_type] == true
end

-- §13.B CF 资源探测
-- 默认值基于 2026-07-01 实际资源数，作为 scan 失败兜底：
--   9 个普通音效（killsound_cf_01..09.wav）+ 1 个 boss 音（killsound_cf_boss.wav）
--   6 个普通图标（kill1..6.png）+ 1 个首杀爆头（headshot_gold.png）
local CF_VOICE_ASSETS = {
    male = {
        max = 9,
        base = "KillSounds/cf/male",
        kill_pattern = "KillSounds/cf/male/killsound_cf_%02d.wav",
        headshot = "KillSounds/cf/male/cf_headshot.wav",
        boss = "KillSounds/cf/male/killsound_cf_boss.wav",
    },
    female = {
        max = 9, -- kill9.wav is a copy of the normal first-kill sound.
        base = "KillSounds/cf/female",
        kill_pattern = "KillSounds/cf/female/kill%s.wav",
        headshot = "KillSounds/cf/female/headshot.wav",
        boss = "KillSounds/cf/female/killsound_cf_boss.wav",
    },
}

local function _cf_voice()
    return HKS:get("cf_kill_voice") == "female" and "female" or "male"
end

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

    local open_ok, handle = pcall(lua_io.open, path, "rb")
    if not open_ok or not handle then
        return false
    end

    pcall(function()
        handle:close()
    end)
    return true
end

-- §21/§23 BF4 文字击杀信息使用自己的目标和有效事件状态。
-- 这里不能读取 CF 音效、CF 图标、BF5 音效或 BF5 图标开关。
local function add_bf4_score_feed(breed_or_nil, is_headshot, bf4_feed_eligible, bf4_next_count, extra_context)
    if not bf4_feed_eligible or not ScoreFeed then
        return false
    end

    return ScoreFeed.add_kill(breed_or_nil, is_headshot, bf4_next_count, extra_context) == true
end

local function _scan_cf_assets()
    local SimpleAudio = get_mod and get_mod("SimpleAudio")
    for voice, assets in pairs(CF_VOICE_ASSETS) do
        local files
        if SimpleAudio and type(SimpleAudio.glob) == "function" then
            local ok, glob_res = pcall(SimpleAudio.glob, assets.base .. "/*.wav")
            if not ok or not glob_res then
                ok, glob_res = pcall(SimpleAudio.glob, "mods/Hit_Kill_Sounds/audio/" .. assets.base .. "/*.wav")
            end
            if ok and type(glob_res) == "table" then
                if type(glob_res.list) == "function" then
                    local list_ok, list_res = pcall(glob_res.list, glob_res)
                    if list_ok and type(list_res) == "table" then files = list_res end
                else
                    files = glob_res
                end
            end
        end

        local has_boss = false
        local has_headshot = false
        if files and #files > 0 then
            for _, rel_path in ipairs(files) do
                local filename = rel_path:match("([^/\\]+)$") or rel_path
                if filename == "killsound_cf_boss.wav" then
                    has_boss = true
                elseif (voice == "male" and filename == "cf_headshot.wav") or
                    (voice == "female" and filename == "headshot.wav") then
                    has_headshot = true
                else
                    local num
                    if voice == "male" then
                        num = tonumber(filename:match("^killsound_cf_(%d+)%.wav$"))
                    elseif filename == "kill.wav" then
                        num = 1
                    else
                        num = tonumber(filename:match("^kill(%d+)%.wav$"))
                    end
                    if voice == "male" and num and num > assets.max then
                        assets.max = num
                    end
                end
            end
        end

        local lua_io = Mods and Mods.lua and Mods.lua.io
        if (not files or #files == 0) and lua_io and lua_io.popen then
            local pattern = voice == "male" and "killsound_cf_*.wav" or "kill*.wav"
            local scan_ok, handle = pcall(lua_io.popen,
                'dir /b "..\\mods\\Hit_Kill_Sounds\\audio\\' .. assets.base:gsub("/", "\\") .. '\\' .. pattern .. '" 2>nul')
            if scan_ok and handle then
                pcall(function()
                    for line in handle:lines() do
                        local num
                        if voice == "male" then
                            num = tonumber(line:match("^killsound_cf_(%d+)%.wav$"))
                        elseif line == "kill.wav" then
                            num = 1
                        else
                            num = tonumber(line:match("^kill(%d+)%.wav$"))
                        end
                        if voice == "male" and num and num > assets.max then
                            assets.max = num
                        end
                    end
                end)
                pcall(function() handle:close() end)
            end
        end

        if files and #files > 0 then
            assets.boss = has_boss and assets.boss or nil
            assets.headshot = has_headshot and assets.headshot or nil
        else
            local prefix = "../mods/Hit_Kill_Sounds/audio/" .. assets.base
            if not _file_exists(prefix .. "/killsound_cf_boss.wav") then
                assets.boss = nil
            end
            local headshot_name = voice == "male" and "cf_headshot.wav" or "headshot.wav"
            if not _file_exists(prefix .. "/" .. headshot_name) then
                assets.headshot = nil
            end
        end
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

local valorant_icon_tex = {}
local valorant_icons_load_started = false

local function _preload_valorant_icons_legacy()
    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.start_player then
        HKS.HitKillSoundsPlayer.start_player()
    end

    local host = HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host
    if not host then return end

    local keys = HKS.HitKillSoundsAssetsBackend and HKS.HitKillSoundsAssetsBackend.VALORANT_TEXTURE_KEYS or {}
    for key, filename in pairs(keys) do
        local texture_key = key
        Managers.url_loader:load_texture(host .. "image?path=cartoon_preview/kill_icon/valorant/" .. filename):next(function(data)
            if data and data.texture then
                valorant_icon_tex[texture_key] = data.texture
            end
        end)
    end
end

local function _preload_valorant_icons()
    if valorant_icons_load_started then return end
    valorant_icons_load_started = true
    if HKS.HitKillSoundsAssetsBackend then
        HKS.HitKillSoundsAssetsBackend.load_valorant_icons(valorant_icon_tex, _preload_valorant_icons_legacy)
    else
        _preload_valorant_icons_legacy()
        valorant_icons_load_started = false
    end
end

-- §23 三个输出各自维护连杀状态；CF 图标显示状态不承担计数职责。
local cf_icon_state = {
    current_icon = nil,
    icon_show_until = 0,
    inherited_streak_count = nil,
    last_event_time = 0,
    animation_kind = "first",
    is_headshot = false,
}

local valorant_icon_state = {
    streak_count = 0,
    is_headshot = false,
    last_event_time = 0,
    icon_show_until = 0,
    spin_dir = 1,
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
    cf_icon_state.inherited_streak_count = nil
    cf_icon_state.last_event_time = 0
    cf_icon_state.animation_kind = "first"
    cf_icon_state.is_headshot = false
end

local function clear_valorant_icon_state()
    valorant_icon_state.streak_count = 0
    valorant_icon_state.is_headshot = false
    valorant_icon_state.last_event_time = 0
    valorant_icon_state.icon_show_until = 0
    valorant_icon_state.spin_dir = 1
end

local function accept_counter(counter, now, eligible)
    if not counter or not counter.accept then
        return nil
    end

    return counter:accept(now, eligible)
end

local function queue_sound(path, track_id, volume, priority, sound_kind, replace_group)
    local backend = HKS.HitKillSoundsAudioBackend

    if backend and backend.enqueue then
        return backend.enqueue(path, track_id, volume, priority, sound_kind, replace_group) == true
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
    local assets = CF_VOICE_ASSETS[_cf_voice()]
    if not assets or assets.max == 0 then return end

    local sound_idx = math.min(sound_streak_count, assets.max)
    local suffix = assets == CF_VOICE_ASSETS.female and (sound_idx == 1 and "" or tostring(sound_idx)) or sound_idx
    local sound_path = string.format(assets.kill_pattern, suffix)

    local use_normal_sound = is_headshot and HKS:get("kill_headshot_use_normal") == true
    local volume = get_kill_volume(is_headshot)
    local track = get_kill_track(is_headshot, use_normal_sound)
    local sound_kind = is_headshot and "cf_kill_headshot" or "cf_kill"

    local replace_group = sound_streak_count >= 2 and "cf_numeric" or nil
    queue_sound(sound_path, track, volume, AUDIO_PRIORITY.CF_KILL, sound_kind, replace_group)
end

local function _cf_play_headshot_special()
    local assets = CF_VOICE_ASSETS[_cf_voice()]
    if not assets or not assets.headshot then
        return false
    end

    local track = HKS.HitKillSoundsPlayer.TRACKS.KILL_HEADSHOT
    local played = queue_sound(
        assets.headshot,
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

    cf_icon_state.inherited_streak_count = icon_streak_count
    cf_icon_state.last_event_time = now
    cf_icon_state.animation_kind = icon_streak_count == 1 and "first" or "upgrade"
    cf_icon_state.is_headshot = is_headshot == true
    cf_icon_state.icon_show_until = now + get_killstreak_reset_time()
end

local function _valorant_on_sound_kill(is_headshot, sound_streak_count)
    if not sound_streak_count then return end

    local idx = math.max(1, math.min(VALORANT_DISPLAY_MAX, tonumber(sound_streak_count) or 1))
    local volume = get_kill_volume(is_headshot)
    local track = get_kill_track(is_headshot, true)
    local priority = idx >= 5 and AUDIO_PRIORITY.BOSS or AUDIO_PRIORITY.VALORANT_KILL
    queue_sound(string.format("KillSounds/Valorant/k_valorant_default-%02d.wav", idx), track, volume, priority, "valorant_kill", "valorant_kill")

    if HKS:get("valorant_ui_fx_enabled") ~= false then
        local ui_path = idx == 1 and "KillSounds/Valorant/k_valorant_appear.wav" or "KillSounds/Valorant/k_valorant_transition.wav"
        queue_sound(ui_path, HKS.HitKillSoundsPlayer.TRACKS.KILL_NORMAL, math.floor((tonumber(volume) or 100) * 0.30), AUDIO_PRIORITY.KILL, "valorant_ui_fx", "valorant_ui_fx")
    end
end

local function _valorant_on_icon_kill(is_headshot, icon_streak_count, now)
    if not icon_streak_count then return end

    local next_dir = (valorant_icon_state.spin_dir or 1) * -1
    valorant_icon_state.streak_count = math.max(1, math.min(VALORANT_DISPLAY_MAX, tonumber(icon_streak_count) or 1))
    valorant_icon_state.is_headshot = is_headshot == true
    valorant_icon_state.last_event_time = now
    valorant_icon_state.icon_show_until = now + get_killstreak_reset_time()
    valorant_icon_state.spin_dir = next_dir
end

-- §13.C.3 Boss 击杀（不递增通用连杀计数器，但受连杀开关保护）
local function _cf_on_boss_kill(is_headshot, cf_sound_active, cf_icon_active, now, inherited_streak_count)
    if not (cf_sound_active or cf_icon_active) then return end

    if cf_icon_active then
        local streak = tonumber(inherited_streak_count) or 0
        if (not inherited_streak_count or streak <= 0) and is_headshot and cf_icon_tex["headshot_gold"] then
            cf_icon_state.current_icon = cf_icon_tex["headshot_gold"]
        else
            local icon_idx = math.min(math.max(streak, 1), CF_KILL_ICONS_MAX)
            cf_icon_state.current_icon = cf_icon_tex[icon_idx] or cf_icon_tex[1]
        end
        cf_icon_state.inherited_streak_count = inherited_streak_count
        cf_icon_state.last_event_time = now
        cf_icon_state.animation_kind = streak > 0 and "upgrade" or "first"
        cf_icon_state.is_headshot = is_headshot == true
        cf_icon_state.icon_show_until = now + get_killstreak_reset_time()
    end

    local assets = CF_VOICE_ASSETS[_cf_voice()]
    if cf_sound_active and assets and assets.boss then
        local use_normal_sound = is_headshot and HKS:get("kill_headshot_use_normal") == true
        local volume = get_kill_volume(is_headshot)
        local track = get_kill_track(is_headshot, use_normal_sound)
        local sound_kind = is_headshot and "boss_headshot" or "boss_kill"

        queue_sound(assets.boss, track, volume, AUDIO_PRIORITY.BOSS, sound_kind)
    end
end

-- §33：只按 basename 分类；旧式 melee_hits_* 没有 play_ 前缀。
-- 家族匹配要求完整名称或下划线边界，避免路径、相似名称和 Lua pattern 误匹配。
local HIT_WWISE_FAMILIES = {
    "play_bullet_hits",
    -- impact_fx_injector.lua：攻击命中 void/warp shield，属于原有 bullet_hits 覆盖范围。
    "play_traitor_captain_shield_bullet_hits",
    "play_indicator",
    "play_hit_indicator",
    "play_chord_claw_hit",
    "play_transonic_blades_impact_hit",
    "play_power_sword_1h_p3_hit",
    "play_power_sword_hit",
    "play_arc_maul_hit",
    "play_powermaul_1h_hit",
    "play_psyker_chain_lightning_hit", -- 仅开始事件，不拦截 stop 事件。
}
local HIT_WWISE_EXACT_EVENTS = {
    ["play_ogryn_powermaul_1h_hit_sparks"] = true,
    ["play_ogryn_powermaul_1h_spark"] = true,
    ["play_arc_maul_1h_electric_sparks"] = true,
    ["play_power_sword_1h_p2_hit"] = true,
    ["play_power_sword_2h_hit"] = true,
    ["play_melee_hit_forcesword_hit_damage"] = true,
    ["play_melee_hits_forcesword_special_cleave"] = true,
    ["play_combat_weapon_chainsword_hit_impact"] = true,
    ["play_combat_weapon_chainsword_hit_res"] = true,
    ["play_weapon_addon_hit_thunderhammer_sparks"] = true,
    ["play_powermaul_1h_stuck_impact"] = true,
    ["play_powermaul_1h_stuck_impact_died"] = true,
    ["play_psyker_lightning_bolt_impact_death"] = true,
}
local KILL_WWISE_EXACT_EVENTS = {
    play_minion_killed = true,
    play_elite_killed = true,
    play_special_killed = true,
    play_monster_killed = true,
    play_husk_killed = true,
    play_ogryn_killed = true,
}
local NON_HIT_WWISE_FAMILIES = {
    "play_player_get_hit",
    "play_toughness_hits",
    "play_ogryn_hit_chest",
    -- minion_backstab_settings.lua / player_character_sound_event_aliases.lua：玩家危险预警。
    "play_backstab_indicator",
    "play_indicator_backstab",
    -- player_character_sound_event_aliases.lua 的 sfx_swing_critical 是挥击动作，不是命中。
    "play_indicator_crit_melee_swing",
}

local hit_events_silenced = false
local kill_events_silenced = false

-- 保留原有设置刷新入口；两个开关独立缓存，不再构造混合的 substring 表。
local function rebuild_silenced_patterns()
    hit_events_silenced = not HKS:get("game_hit_sound_enabled")
    kill_events_silenced = not HKS:get("game_kill_sound_enabled")
end

local function normalize_event_name(event_name)
    if type(event_name) ~= "string" then
        return nil
    end

    -- 这里只提取 basename，hook 仍将原始 event_name 原样传给下一个消费者。
    return string.match(event_name, "([^/]+)$")
end

local function is_event_family(basename, family)
    return basename == family or string.sub(basename, 1, #family + 1) == family .. "_"
end

local function is_legacy_melee_hit_event(basename)
    return is_event_family(basename, "melee_hits") or is_event_family(basename, "play_melee_hits")
end

local function is_modern_hit_event(basename)
    if HIT_WWISE_EXACT_EVENTS[basename] then
        return true
    end

    for i = 1, #HIT_WWISE_FAMILIES do
        if is_event_family(basename, HIT_WWISE_FAMILIES[i]) then
            return true
        end
    end

    return false
end

local function is_kill_event(basename)
    return KILL_WWISE_EXACT_EVENTS[basename] == true
end

local function is_event_silenced(event_name)
    if not hit_events_silenced and not kill_events_silenced then
        return false
    end

    local basename = normalize_event_name(event_name)
    if not basename then
        return false
    end

    if is_kill_event(basename) then
        return kill_events_silenced
    end
    if not hit_events_silenced then
        return false
    end

    -- 只对字面量的完整动作 token 做排除，也包含以 reload/equip 结尾的事件。
    local action_tokens = "_" .. basename .. "_"
    if string.find(action_tokens, "_reload_", 1, true) or string.find(action_tokens, "_equip_", 1, true) then
        return false
    end
    for i = 1, #NON_HIT_WWISE_FAMILIES do
        if is_event_family(basename, NON_HIT_WWISE_FAMILIES[i]) then
            return false
        end
    end

    return is_legacy_melee_hit_event(basename) or is_modern_hit_event(basename)
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
    CODBO4 = {
        normal = {
            "HitSounds/CODBO4/h_bo4_armor.wav",
        },
        headshot = {
            "HitSounds/CODBO4/h_bo4_head.wav",
        },
    },
    CODBO7 = {
        normal = {
            "HitSounds/CODBO7/h_bo7_normal_1.wav",
            "HitSounds/CODBO7/h_bo7_normal_2.wav",
            "HitSounds/CODBO7/h_bo7_normal_3.wav",
        },
        headshot = {
            "HitSounds/CODBO7/h_bo7_headshot_1.wav",
            "HitSounds/CODBO7/h_bo7_headshot_2.wav",
            "HitSounds/CODBO7/h_bo7_headshot_3.wav",
        },
    },
    CODBOClassic = {
        normal = {
            "HitSounds/CODBOClassic/hitsound_BO_Classic.wav",
        },
        headshot = {
            "HitSounds/CODBOClassic/hitsound_BO_Classic.wav",
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

local BFV_HEADSHOT_ADD_SOUND = "KillSounds/BFV/killsound_bfv_headshotadd.wav"

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
        },
        headshot_add = BFV_HEADSHOT_ADD_SOUND,
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
    CODBO4 = {
        normal = {
            "KillSounds/CODBO4/killsound_BO4_normal_1.wav",
            "KillSounds/CODBO4/killsound_BO4_normal_2.wav",
            "KillSounds/CODBO4/killsound_BO4_normal_3.wav",
        },
        headshot = {
            "KillSounds/CODBO4/killsound_BO4_headshot_1.wav",
            "KillSounds/CODBO4/killsound_BO4_headshot_2.wav",
            "KillSounds/CODBO4/killsound_BO4_headshot_3.wav",
            "KillSounds/CODBO4/killsound_BO4_headshot_4.wav",
            "KillSounds/CODBO4/killsound_BO4_headshot_5.wav",
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
    local sound_file
    if game == "CUSTOM" then
        local custom = HKS.HitKillSoundsCustomAudio
        sound_file = custom and custom.sample("hit", sound_type == "headshot", HIT_SOUNDS.BFV)
    else
        local sounds = HIT_SOUNDS[game]
        if not sounds then
            HKS:warning("Hit_Kill_Sounds: 未找到游戏 " .. tostring(game) .. " 的命中音效")
            return false
        end
        local sound_list = sounds[sound_type]
        if not sound_list or #sound_list == 0 then
            sound_list = sounds.normal
        end
        sound_file = get_random_sound(sound_list)
    end

    if sound_file then
        local track = is_headshot and TRACKS.HIT_HEADSHOT or TRACKS.HIT_NORMAL
        local priority = is_headshot and AUDIO_PRIORITY.HEADSHOT_HIT or AUDIO_PRIORITY.HIT
        local sound_kind = is_headshot and "hit_headshot" or "hit_normal"

        return queue_sound(sound_file, track, volume, priority, sound_kind) == true
    end
    return false
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
    local sound_file
    if game == "CUSTOM" then
        local custom = HKS.HitKillSoundsCustomAudio
        sound_file = custom and custom.sample("kill", sound_type == "headshot", KILL_SOUNDS.BFV)
    else
        local sounds = KILL_SOUNDS[game]
        if not sounds then
            HKS:warning("Hit_Kill_Sounds: 未找到游戏 " .. tostring(game) .. " 的击杀音效")
            return
        end
        local sound_list = sounds[sound_type]
        if not sound_list or #sound_list == 0 then
            sound_list = sounds.normal
        end
        sound_file = get_random_sound(sound_list)
    end

    if sound_file then
        local track = is_headshot and not use_normal_sound and TRACKS.KILL_HEADSHOT or TRACKS.KILL_NORMAL
        local priority = is_headshot and AUDIO_PRIORITY.HEADSHOT_KILL or AUDIO_PRIORITY.KILL
        local sound_kind = is_headshot and "kill_headshot" or "kill_normal"

        queue_sound(sound_file, track, volume, priority, sound_kind)

        -- BFV 原版爆头双层混音：钢盔穿透瞬态脆响 (headshot1..10) + 低频金属共鸣尾音 (BFV_HEADSHOT_ADD_SOUND)
        if game == "BFV" and is_headshot and not use_normal_sound and BFV_HEADSHOT_ADD_SOUND then
            queue_sound(
                BFV_HEADSHOT_ADD_SOUND,
                TRACKS.KILL_NORMAL,
                volume,
                AUDIO_PRIORITY.KILL,
                "kill_headshot_add",
                "bfv_headshot_add"
            )
        end
    end
end

local function can_play_hit()
    local current_time = Managers.time:time("main")
    if current_time - last_hit_time >= HIT_COOLDOWN then
        return true
    end
    return false
end

local function safe_game_localize(key)
    if type(key) ~= "string" or key == "" or type(Localize) ~= "function" then
        return nil
    end
    local ok, text = pcall(Localize, key)
    if ok and type(text) == "string" and text ~= "" then
        return text
    end
    return nil
end

local function is_boss_target(breed_or_nil)
    if not breed_or_nil then
        return false
    end
    local tags = breed_or_nil.tags or {}
    return breed_or_nil.is_boss == true or breed_or_nil.boss == true or
        tags.monster == true or tags.captain == true
end

local function resolve_bf1_dot_weapon_name(damage_profile)
    local profile_name = damage_profile and damage_profile.name
    local damage_type = damage_profile and damage_profile.damage_type
    if ELECTROCUTION_DOT_PROFILES[profile_name] then
        return HKS:localize("bf1_weapon_dot_electrocution")
    elseif damage_type == damage_types.bleeding or profile_name == "bleeding" then
        return HKS:localize("bf1_weapon_dot_bleeding")
    elseif damage_type == damage_types.warpfire then
        return HKS:localize("bf1_weapon_dot_warpfire")
    elseif damage_type == damage_types.burning or
        (type(profile_name) == "string" and string.find(profile_name, "burn", 1, true)) then
        return HKS:localize("bf1_weapon_dot_burning")
    elseif damage_type == damage_types.toxin or
        (type(profile_name) == "string" and (string.find(profile_name, "toxin", 1, true) or
            string.find(profile_name, "gas", 1, true))) then
        return HKS:localize("bf1_weapon_dot_toxin")
    elseif damage_type == damage_types.corruption or damage_type == damage_types.grimoire or
        (type(profile_name) == "string" and string.find(profile_name, "corrupt", 1, true)) then
        return HKS:localize("bf1_weapon_dot_corruption")
    end
    return HKS:localize("bf1_weapon_dot_generic")
end

local function resolve_slot_weapon_name(visual_loadout_ext, slot_name)
    if not visual_loadout_ext or not slot_name or slot_name == "none" then
        return nil
    end
    local ok_item, item = pcall(visual_loadout_ext.item_from_slot, visual_loadout_ext, slot_name)
    if not ok_item or not item then
        return nil
    end
    if Items and Items.weapon_card_display_name then
        local ok_card, card_name = pcall(Items.weapon_card_display_name, item)
        if ok_card and type(card_name) == "string" and card_name ~= "" and card_name ~= "n/a" then
            return card_name
        end
    end
    if Items and Items.display_name then
        local ok_disp, disp_name = pcall(Items.display_name, item)
        if ok_disp and type(disp_name) == "string" and disp_name ~= "" and
            disp_name ~= "n/a" and disp_name ~= "-" then
            return disp_name
        end
    end
    return nil
end

local function resolve_victim_name(breed_or_nil)
    return (breed_or_nil and safe_game_localize(breed_or_nil.display_name)) or
        HKS:localize("bf1_fallback_enemy")
end

local function get_equipped_ability_name(attacking_unit, ability_type)
    local ability_ext = attacking_unit and ScriptUnit.has_extension(attacking_unit, "ability_system")
    if not ability_ext or not ability_ext.equipped_abilities then
        return nil
    end

    local ok_ab, abilities = pcall(ability_ext.equipped_abilities, ability_ext)
    local ability = ok_ab and abilities and abilities[ability_type]
    return type(ability) == "table" and ability.name or nil
end

local function localize_ability_by_name(ability_name)
    if type(ability_name) ~= "string" or ability_name == "" then
        return nil
    end

    local display_map = get_ability_display_name_map()
    local canonical = ABILITY_DISPLAY_ALIASES[ability_name] or ability_name
    local loc_key = display_map[canonical] or display_map[ability_name]
    return safe_game_localize(loc_key)
end

local function resolve_ability_label(attacking_unit, ability_type, explicit_ability_name)
    local label = localize_ability_by_name(explicit_ability_name)
    if label then
        return label
    end

    local equipped_name = get_equipped_ability_name(attacking_unit, ability_type)
    label = localize_ability_by_name(equipped_name)
    if label then
        return label
    end

    return nil
end

local function resolve_kill_weapon_name(
    damage_profile, attacking_unit, attack_type, is_dot_damage, is_companion_attack
)
    if is_companion_attack then
        if attack_type == AttackSettings.attack_types.companion_dog then
            return HKS:localize("bf1_weapon_companion_dog")
        end
        return HKS:localize("bf1_weapon_servo_skull")
    end

    local profile_name = damage_profile and damage_profile.name

    -- 1. Unambiguous Blitz (grenade / psychic blitz / throwing knives) profiles first.
    local blitz_ability = profile_name and BLITZ_DAMAGE_PROFILES[profile_name]
    if blitz_ability then
        local blitz_label = resolve_ability_label(attacking_unit, "grenade_ability", blitz_ability)
        if blitz_label then
            return blitz_label
        end
        if attack_type == AttackSettings.attack_types.explosion then
            return HKS:localize("bf1_weapon_explosion")
        end
    end

    -- 2. Unambiguous Combat Ability profiles (shouts, charges, discharge, chordclaw, etc.).
    local combat_ability = profile_name and COMBAT_ABILITY_DAMAGE_PROFILES[profile_name]
    if combat_ability then
        local combat_label = resolve_ability_label(attacking_unit, "combat_ability", combat_ability)
        if combat_label then
            return combat_label
        end
    end

    -- 3. Generic DoT profiles (bleed, burn, warpfire, toxin, weapon/environmental electrocution).
    if is_dot_damage then
        return resolve_bf1_dot_weapon_name(damage_profile)
    end

    -- 4. Environmental / prop / barrel explosions.
    if profile_name and PROP_EXPLOSION_PROFILES[profile_name] then
        return HKS:localize("bf1_weapon_explosion")
    end

    local unit_data_ext = attacking_unit and ScriptUnit.has_extension(attacking_unit, "unit_data_system")
    local visual_loadout_ext = attacking_unit and ScriptUnit.has_extension(attacking_unit, "visual_loadout_system")
    local inventory = unit_data_ext and unit_data_ext:read_component("inventory")
    local wielded_slot = inventory and inventory.wielded_slot

    -- 5. Weapon-specific explosions (e.g. Rumbler, Trauma Staff, Plasma, Power Maul, Force Sword).
    local weapon_explosion_slot = profile_name and WEAPON_EXPLOSION_SLOT_BY_PROFILE[profile_name]
    if weapon_explosion_slot then
        local weapon_exp_name = resolve_slot_weapon_name(visual_loadout_ext, weapon_explosion_slot)
        if weapon_exp_name then
            return weapon_exp_name
        end
    end

    -- 6. Shared default_grenade profile (Zealot Immolation pop vs weapon blessing minion explosions).
    if profile_name == "default_grenade" then
        local equipped_grenade = get_equipped_ability_name(attacking_unit, "grenade_ability")
        if equipped_grenade == "zealot_fire_grenade" and wielded_slot ~= "slot_secondary" then
            local fire_label = resolve_ability_label(attacking_unit, "grenade_ability", "zealot_fire_grenade")
            if fire_label then
                return fire_label
            end
        end
        local ranged_name = resolve_slot_weapon_name(visual_loadout_ext, "slot_secondary")
        if ranged_name then
            return ranged_name
        end
        return HKS:localize("bf1_weapon_explosion")
    end

    -- 7. Remaining shout kills map to combat ability; remaining unknown explosions map to blitz or explosion.
    if attack_type == AttackSettings.attack_types.shout then
        local shout_label = resolve_ability_label(attacking_unit, "combat_ability", nil)
        if shout_label then
            return shout_label
        end
    end

    if attack_type == AttackSettings.attack_types.explosion then
        if wielded_slot == "slot_grenade_ability" then
            local grenade_label = resolve_ability_label(attacking_unit, "grenade_ability", nil)
            if grenade_label then
                return grenade_label
            end
        elseif wielded_slot == "slot_combat_ability" then
            local combat_label = resolve_ability_label(attacking_unit, "combat_ability", nil)
            if combat_label then
                return combat_label
            end
        end
        return HKS:localize("bf1_weapon_explosion")
    end

    -- 8. If currently wielding an ability slot and not a standard melee/ranged attack, resolve ability name.
    if wielded_slot == "slot_grenade_ability" and
        attack_type ~= AttackSettings.attack_types.melee and
        attack_type ~= AttackSettings.attack_types.ranged then
        local grenade_label = resolve_ability_label(attacking_unit, "grenade_ability", nil)
        if grenade_label then
            return grenade_label
        end
    elseif wielded_slot == "slot_combat_ability" and
        attack_type ~= AttackSettings.attack_types.melee and
        attack_type ~= AttackSettings.attack_types.ranged then
        local combat_label = resolve_ability_label(attacking_unit, "combat_ability", nil)
        if combat_label then
            return combat_label
        end
    end

    -- 9. Regular melee / ranged weapons.
    local preferred_slot = wielded_slot
    if attack_type == AttackSettings.attack_types.melee and preferred_slot ~= "slot_primary" then
        preferred_slot = "slot_primary"
    elseif attack_type == AttackSettings.attack_types.ranged and preferred_slot ~= "slot_secondary" then
        preferred_slot = "slot_secondary"
    end

    local weapon_name = resolve_slot_weapon_name(visual_loadout_ext, preferred_slot)
    if not weapon_name and wielded_slot and wielded_slot ~= preferred_slot then
        weapon_name = resolve_slot_weapon_name(visual_loadout_ext, wielded_slot)
    end

    return weapon_name or HKS:localize("bf1_weapon_unknown")
end

local function resolve_bf1_kill_context(
    damage_profile, attacked_unit, attacking_unit, breed_or_nil,
    is_kill_headshot, damage, attack_type, is_dot_damage, is_companion_attack
)
    local tags = breed_or_nil and breed_or_nil.tags or {}
    local is_boss = is_boss_target(breed_or_nil)
    local is_special = breed_or_nil and (breed_or_nil.special == true or tags.special == true) or false
    local is_elite = breed_or_nil and (breed_or_nil.elite == true or tags.elite == true) or false

    local enemy_tier = "normal"
    local base_score = 100
    local priority = is_kill_headshot and 2 or 1
    if is_boss then
        enemy_tier = "boss"
        base_score = 500
        priority = 5
    elseif is_special then
        enemy_tier = "special"
        base_score = 250
        priority = 4
    elseif is_elite then
        enemy_tier = "elite"
        base_score = 200
        priority = 3
    end

    local kill_type = "default"
    if is_boss and HKS:get("bf1_boss_icon_enabled") ~= false then
        kill_type = "boss"
    elseif is_kill_headshot then
        kill_type = "headshot"
    end

    local victim_name = resolve_victim_name(breed_or_nil)
    local weapon_name = resolve_kill_weapon_name(
        damage_profile, attacking_unit, attack_type, is_dot_damage, is_companion_attack
    )

    local max_health = 0
    local health_ext = attacked_unit and ScriptUnit.has_extension(attacked_unit, "health_system")
    if health_ext and health_ext.max_health then
        local ok_hp, hp_val = pcall(health_ext.max_health, health_ext)
        if ok_hp and type(hp_val) == "number" and hp_val > 0 then
            max_health = hp_val
        end
    end

    return {
        kill_type = kill_type,
        is_headshot = is_kill_headshot == true,
        is_boss = is_boss,
        enemy_tier = enemy_tier,
        victim_name = victim_name,
        weapon_name = weapon_name,
        score = base_score + (is_kill_headshot and 50 or 0),
        max_health = max_health,
        damage = tonumber(damage) or 0,
        priority = priority,
    }
end

-- 处理攻击结果的内部函数
local function handle_attack_result(damage_profile, attacked_unit, attacking_unit, _attack_direction, _hit_world_position, hit_weakspot, damage, attack_result, attack_type, _damage_efficiency, _is_critical_strike)
    -- 总开关关闭时静默
    if not HKS:get("enabled") then
        return
    end

    -- §11.B 同伴攻击判定（保留 Adamant 狗，并精确识别 Servo skull 直接伤害）
    local damage_profile_name = damage_profile and damage_profile.name
    local is_companion_attack = (attack_type and COMPANION_ATTACK_TYPES[attack_type] == true) or
        (damage_profile_name and COMPANION_DAMAGE_PROFILES[damage_profile_name] == true)

    -- Push/stagger and other non-damaging reports can still use a valid hit
    -- result.  They must not produce a Mod hit sound; only positive damage is
    -- a damage hit for this feedback path.
    local numeric_damage = tonumber(damage)
    if not numeric_damage or numeric_damage <= 0 then
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

    -- AttackReportManager 不传运行时 damage_type；电击来源依赖 profile name，
    -- primer_stun 依赖 attack_type，通用 DoT 使用精确 profile 或明确的 damage_type。
    local is_dot_damage = is_dot_damage_profile(damage_profile, attack_type)

    -- 获取breed信息
    local unit_data_extension = ScriptUnit.has_extension(attacked_unit, "unit_data_system")
    local breed_or_nil = unit_data_extension and unit_data_extension:breed()

    -- 如果是击杀
    if attack_result == AttackSettings.attack_results.died then
        -- 零伤害报告可以是韧性命中，但不能产生击杀反馈。
        if damage <= 0 then
            return
        end

        -- 过滤玩家、自伤/友伤和普通 prop；living_prop 保持原有行为。
        if is_kill_feedback_target_excluded(breed_or_nil) then
            return
        end

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
        local melee_kill_sound_allowed = attack_type ~= "melee" or HKS:get("kill_melee_sound_enabled") ~= false

        -- 所有计数资格都在击杀事件入口一次性确定。音频队列和 HUD 只消费
        -- 本次 accept() 返回的序号，不再从其他输出或共享状态重新读取计数。
        local now = Managers.time:time("main")
        local killstreak_enabled = is_killstreak_enabled()
        local is_boss = breed_or_nil and breed_or_nil.is_boss == true

        local killstreak_sound_style = HKS:get("killstreak_sound_style") or "off"
        if killstreak_sound_style == "off" and HKS:get("killstreak_sound_style_migrated") ~= true and
            HKS:get("cf_kill_sound_enabled") == true then
            killstreak_sound_style = "CF"
        end
        local cf_sound_on = killstreak_enabled and killstreak_sound_style == "CF" and HKS:get("kill_sound_enabled")
        local valorant_sound_on = killstreak_enabled and killstreak_sound_style == "Valorant" and HKS:get("kill_sound_enabled")
        local cf_icon_on = killstreak_enabled and HKS:get("kill_icon_style") == "CF" and HKS:get("kill_icon_enabled")
        local valorant_icon_on = killstreak_enabled and HKS:get("kill_icon_style") == "Valorant" and HKS:get("kill_icon_enabled")

        local cf_sound_active = cf_sound_on and kill_sound_target_valid and
            dot_sound_allowed and companion_kill_sound_allowed and melee_kill_sound_allowed
        local cf_icon_active = cf_icon_on and kill_icon_target_valid and
            dot_icon_allowed and companion_kill_icon_allowed
        local valorant_sound_active = valorant_sound_on and kill_sound_target_valid and
            dot_sound_allowed and companion_kill_sound_allowed and melee_kill_sound_allowed
        local valorant_icon_active = valorant_icon_on and kill_icon_target_valid and
            dot_icon_allowed and companion_kill_icon_allowed

        if not killstreak_enabled then
            -- 设置回调负责正常清理；此处处理关闭后尚未收到回调的边界情况，
            -- 防止重新开启时继承关闭期间隐藏的序号。
            if HKS.reset_all_killstreak_counters then
                HKS.reset_all_killstreak_counters("killstreak_disabled")
            end
            clear_cf_icon_state()
            clear_valorant_icon_state()
        end

        -- BF4 works independently of killstreak_enabled; killstreak only adds the
        -- optional MULTI KILL bonus row.
        local bf4_eligible = ScoreFeed and ScoreFeed.is_enabled and
            ScoreFeed.is_enabled() and bf4_feed_target_valid and
            dot_icon_allowed and companion_kill_icon_allowed
        local bf4_next_count = (killstreak_enabled and bf4_eligible and bf4_feed_counter and
            bf4_feed_counter.preview_next) and bf4_feed_counter:preview_next(now) or nil
        local bf4_extra_context = nil
        if bf4_eligible then
            bf4_extra_context = {
                victim_name = resolve_victim_name(breed_or_nil),
                weapon_name = resolve_kill_weapon_name(
                    damage_profile, attacking_unit, attack_type, is_dot_damage, is_companion_attack
                ),
            }
        end
        local bf4_event_added = add_bf4_score_feed(
            breed_or_nil,
            is_kill_headshot,
            bf4_eligible,
            bf4_next_count,
            bf4_extra_context
        )
        if bf4_event_added and killstreak_enabled then
            accept_counter(bf4_feed_counter, now, true)
        end

        -- Boss 仍可触发各自的专属输出，但不得修改普通 CF 音效/图标计数器。
        local ordinary_icon_streak_count = nil
        if is_boss and cf_icon_counter and cf_icon_counter.get_count and
            not cf_icon_counter:is_expired(now) then
            ordinary_icon_streak_count = cf_icon_counter:get_count()
        end

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
        local valorant_sound_streak_count = accept_counter(
            valorant_sound_counter,
            now,
            valorant_sound_active
        )
        local valorant_icon_streak_count = accept_counter(
            valorant_icon_counter,
            now,
            valorant_icon_active
        )

        if is_boss then
            _cf_on_boss_kill(
                is_kill_headshot,
                cf_sound_active,
                cf_icon_active,
                now,
                ordinary_icon_streak_count
            )
        else
            if sound_streak_count then
                _cf_on_sound_kill(is_kill_headshot, sound_streak_count)
            end
            if icon_streak_count then
                _cf_on_icon_kill(is_kill_headshot, icon_streak_count, now)
            end
        end

        if valorant_sound_streak_count then
            _valorant_on_sound_kill(is_kill_headshot, valorant_sound_streak_count)
        end
        if valorant_icon_streak_count then
            _valorant_on_icon_kill(is_kill_headshot, valorant_icon_streak_count, now)
        end

        -- BF5 音效：仅当 CF 音效未激活时（叠加 kill_sound_target_valid）
        if not cf_sound_active and not valorant_sound_active and kill_sound_target_valid and dot_sound_allowed and
            companion_kill_sound_allowed and melee_kill_sound_allowed and HKS:get("kill_sound_enabled") then
            play_kill_sound(is_kill_headshot)
        end

        -- BF5 图标：仅当 CF / Valorant 图标未激活时（叠加 kill_icon_target_valid）
        local is_bfv_boss = is_boss_target(breed_or_nil)
        if HKS:get("kill_icon_style") == "BF5" and not cf_icon_active and not valorant_icon_active and
            kill_icon_target_valid and dot_icon_allowed and companion_kill_icon_allowed and
            HKS:get("kill_icon_enabled") and HKS.HitKillIconManager then
            HKS.HitKillIconManager.show_icon(is_kill_headshot, is_bfv_boss)
        end

        -- BF1 图标：仅当 CF / Valorant 图标未激活时（叠加 kill_icon_target_valid）
        if HKS:get("kill_icon_style") == "BF1" and not cf_icon_active and not valorant_icon_active and
            kill_icon_target_valid and dot_icon_allowed and companion_kill_icon_allowed and
            HKS:get("kill_icon_enabled") and HKS.HitKillBF1Manager then
            local bf1_ctx = resolve_bf1_kill_context(
                damage_profile,
                attacked_unit,
                attacking_unit,
                breed_or_nil,
                is_kill_headshot,
                damage,
                attack_type,
                is_dot_damage,
                is_companion_attack
            )
            HKS.HitKillBF1Manager.push_kill(bf1_ctx, now)
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

    -- 普通命中只接受明确的有效结果；nil、blocked、dodged 和未知结果均拒绝。
    if not VALID_HIT_RESULTS[attack_result] then
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
        if play_hit_sound(is_weakspot, is_melee) then
            -- Queue admission, NOT confirmed playback; async drops keep this cooldown.
            last_hit_time = Managers.time:time("main")
        end
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
HKS.HitKillSoundsEvents._preload_valorant_icons = _preload_valorant_icons
-- 兼容旧调用方：reset_cf_state 现在只清理图标显示状态，不触碰任何计数器。
HKS.HitKillSoundsEvents.reset_cf_state = clear_cf_icon_state
HKS.HitKillSoundsEvents.clear_cf_icon_state = clear_cf_icon_state
HKS.HitKillSoundsEvents.clear_valorant_icon_state = clear_valorant_icon_state

-- §23 仅暴露三个独立实例；不存在可供 CF 音效和图标共用的 streak_count。
HKS.HitKillSoundsKillstreakStates = killstreak_counters
HKS.HitKillSoundsCFIconState = cf_icon_state
HKS.HitKillSoundsCFState = cf_icon_state
HKS.HitKillSoundsCFIconTex = cf_icon_tex
HKS.HitKillSoundsValorantIconState = valorant_icon_state
HKS.HitKillSoundsValorantIconTex = valorant_icon_tex

return HKS.HitKillSoundsEvents
