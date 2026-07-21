local HKS = get_mod("Hit_Kill_Sounds")

local function stop_hit_kill_audio()
    if HKS.HitKillSoundsAudioBackend and HKS.HitKillSoundsAudioBackend.stop_all then
        HKS.HitKillSoundsAudioBackend.stop_all()
    elseif HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.stop_all then
        HKS.HitKillSoundsPlayer.stop_all()
    end
end

local function clear_score_feed()
    if HKS.HitKillSoundsScoreFeed and HKS.HitKillSoundsScoreFeed.clear then
        HKS.HitKillSoundsScoreFeed.clear()
    end
end

local function reset_killstreak_counter(counter_id, reason)
    local counters = HKS.HitKillSoundsKillstreakCounters
    local counter = counters and counters[counter_id]

    if counter and counter.reset then
        counter:reset(reason)
    end
end

local function reset_all_killstreak_counters(reason)
    local counters = HKS.HitKillSoundsKillstreakCounters

    if not counters then
        return
    end

    for _, counter in pairs(counters) do
        if counter and counter.reset then
            counter:reset(reason)
        end
    end
end

HKS.reset_killstreak_counter = reset_killstreak_counter
HKS.reset_all_killstreak_counters = reset_all_killstreak_counters

local function clear_kill_state()
    if HKS.HitKillIconManager and HKS.HitKillIconManager.clear then
        HKS.HitKillIconManager.clear()
    end

    reset_all_killstreak_counters("clear_kill_state")

    if HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents.clear_cf_icon_state then
        HKS.HitKillSoundsEvents.clear_cf_icon_state()
    end

    clear_score_feed()
end

-- 使用 io_dofile 加载其他模块
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_player")
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_audio_backend")
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_assets_backend")

HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_killstreak")

local KillstreakCounter = HKS.HitKillSoundsKillstreakCounter
local killstreak_counters = {}

if KillstreakCounter and KillstreakCounter.new then
    killstreak_counters.bf4_feed_counter = KillstreakCounter.new("bf4_feed_counter")
    killstreak_counters.cf_sound_counter = KillstreakCounter.new("cf_sound_counter")
    killstreak_counters.cf_icon_counter = KillstreakCounter.new("cf_icon_counter")
end

HKS.HitKillSoundsKillstreakCounters = killstreak_counters
HKS.HitKillSoundsKillstreakStates = killstreak_counters

HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_score_feed")
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_events")
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_bgm")

-- HUD元素配置
local hud_elements = {
    {
        filename = "Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_hud",
        class_name = "HudHitKillICON",
    },
    -- §13.D.2 CF HUD（2026-07-01）
    {
        filename = "Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_cf_hud",
        class_name = "HudHitKillCF",
    },
    -- §21 BF4 风格文字击杀信息与独立计分 HUD
    {
        filename = "Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_score_feed_hud",
        class_name = "HudHitKillScoreFeed",
    },
}

-- 注册HUD路径
for _, hud_element in ipairs(hud_elements) do
    HKS:add_require_path(hud_element.filename)
end

-- Hook UIHud来添加HUD元素
HKS:hook("UIHud", "init", function(func, self, elements, visibility_groups, params)
    for _, hud_element in ipairs(hud_elements) do
        if not table.find_by_key(elements, "class_name", hud_element.class_name) then
            table.insert(elements, {
                class_name = hud_element.class_name,
                filename = hud_element.filename,
                use_hud_scale = true,
                visibility_groups = hud_element.visibility_groups or {"alive"},
            })
        end
    end

    return func(self, elements, visibility_groups, params)
end)

HKS.on_game_state_changed = function(status, state)
    if status == "enter" and state == "StateRun" then
        stop_hit_kill_audio()
        clear_kill_state()
        HKS:start_player()
    elseif status == "exit" and state == "StateRun" then
        if HKS.HitKillSoundsBGM and HKS.HitKillSoundsBGM.stop then
            HKS.HitKillSoundsBGM.stop(true)
        end
        HKS:stop_player()
        clear_kill_state()
    end
end

HKS.update = function(dt)
    if HKS.HitKillSoundsAudioBackend and HKS.HitKillSoundsAudioBackend.update then
        HKS.HitKillSoundsAudioBackend.update(dt)
    end

    if HKS.HitKillSoundsScoreFeed and HKS.HitKillSoundsScoreFeed.update then
        HKS.HitKillSoundsScoreFeed.update(dt)
    end

    if HKS.HitKillSoundsBGM and HKS.HitKillSoundsBGM.update then
        HKS.HitKillSoundsBGM.update(dt)
    end
end

HKS.start_player = function()
    -- legacy 播放器保持惰性：只有 AudioBackend 真正发送 fallback 播放请求，
    -- 或 legacy 图标加载明确需要 HTTP 服务时，player.lua 才启动外部进程。
end

HKS.stop_player = function()
    stop_hit_kill_audio()
end

HKS.on_all_mods_loaded = function()
    if HKS.HitKillSoundsInitialized then
        return
    end

    HKS.HitKillSoundsInitialized = true

    if HKS.HitKillSoundsAudioBackend then
        HKS.HitKillSoundsAudioBackend.init()
    end
    if HKS.HitKillSoundsAssetsBackend then
        HKS.HitKillSoundsAssetsBackend.init()
    end
    if HKS.HitKillSoundsEvents then
        HKS.HitKillSoundsEvents:init_damage_hooks()
    end
    if HKS.HitKillSoundsBGM and HKS.HitKillSoundsBGM.init then
        HKS.HitKillSoundsBGM.init()
    end
    -- 不在这里检查播放器，因为此时播放器可能还没完全启动
end

local all_counter_reset_settings = {
    enabled = true,
    killstreak_enabled = true,
    cf_killstreak_reset_time = true,
    cf_killstreak_max = true,
}

local sound_counter_reset_settings = {
    kill_target = true,
    kill_sound_enabled = true,
    cf_kill_sound_enabled = true,
    kill_dot = true,
    companion_kill_sound_enabled = true,
}

local icon_counter_reset_settings = {
    kill_icon_target = true,
    kill_icon_enabled = true,
    kill_icon_style = true,
    kill_dot_icon = true,
    companion_kill_icon_enabled = true,
}

local bf4_counter_reset_settings = {
    bf4_feed_enabled = true,
    bf4_feed_target = true,
}

local score_feed_reset_settings = {
    bf4_feed_enabled = true,
    bf4_feed_target = true,
    bf4_feed_duration = true,
    bf4_feed_horizontal_position = true,
    bf4_feed_vertical_position = true,
    bf4_feed_text_scale = true,
}

HKS.on_setting_changed = function(setting_id)
    -- Any setting switch cancels stale one-shot requests and active voices. BGM owns
    -- a separate SimpleAudio play_id and is refreshed by its own setting handler below.
    -- BF4 text-feed layout changes only clear their own HUD state. Output-specific
    -- target and eligibility changes reset only the affected counter instance.
    if not score_feed_reset_settings[setting_id] then
        stop_hit_kill_audio()
    end

    if HKS.HitKillSoundsBGM and HKS.HitKillSoundsBGM.on_setting_changed and
        (setting_id == "enabled" or setting_id == "lobby_bgm_enabled" or setting_id == "lobby_bgm_volume") then
        HKS.HitKillSoundsBGM.on_setting_changed(setting_id)
    end

    if all_counter_reset_settings[setting_id] then
        clear_kill_state()
    elseif sound_counter_reset_settings[setting_id] then
        reset_killstreak_counter("cf_sound_counter", setting_id)
    elseif icon_counter_reset_settings[setting_id] then
        reset_killstreak_counter("cf_icon_counter", setting_id)
        if HKS.HitKillIconManager and HKS.HitKillIconManager.clear then
            HKS.HitKillIconManager.clear()
        end
        if HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents.clear_cf_icon_state then
            HKS.HitKillSoundsEvents.clear_cf_icon_state()
        end
    elseif bf4_counter_reset_settings[setting_id] then
        reset_killstreak_counter("bf4_feed_counter", setting_id)
        clear_score_feed()
    elseif score_feed_reset_settings[setting_id] then
        clear_score_feed()
    end

    if setting_id == "game_hit_sound_enabled" or setting_id == "game_kill_sound_enabled" then
        if HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents.rebuild_silenced_patterns then
            HKS.HitKillSoundsEvents.rebuild_silenced_patterns()
        end
    end
end

HKS.on_unload = function()
    stop_hit_kill_audio()
    reset_all_killstreak_counters("unload")

    if HKS.HitKillSoundsScoreFeed and HKS.HitKillSoundsScoreFeed.clear then
        HKS.HitKillSoundsScoreFeed.clear()
    end

    if HKS.HitKillSoundsBGM and HKS.HitKillSoundsBGM.shutdown then
        HKS.HitKillSoundsBGM.shutdown()
    end
end
