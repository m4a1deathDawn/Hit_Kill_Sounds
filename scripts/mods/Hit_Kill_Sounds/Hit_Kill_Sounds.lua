local HKS = get_mod("Hit_Kill_Sounds")

-- 使用 io_dofile 加载其他模块
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_player")
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_events")

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
        HKS:start_player()
    elseif status == "exit" and state == "StateRun" then
        HKS:stop_player()
    end
end

HKS.start_player = function()
    if HKS.HitKillSoundsPlayer then
        HKS.HitKillSoundsPlayer.check_player_running()
    end
end

HKS.stop_player = function()
    if HKS.HitKillSoundsPlayer then
        HKS.HitKillSoundsPlayer.stop_file(1)
        HKS.HitKillSoundsPlayer.stop_file(2)
        HKS.HitKillSoundsPlayer.stop_file(3)
        HKS.HitKillSoundsPlayer.stop_file(4)
    end
end

HKS.on_all_mods_loaded = function()
    if HKS.HitKillSoundsEvents then
        HKS.HitKillSoundsEvents:init_damage_hooks()
    end
    -- 不在这里检查播放器，因为此时播放器可能还没完全启动
end

HKS.on_setting_changed = function(setting_id)
    if setting_id == "enabled" and HKS:get("enabled") == false then
        if HKS.HitKillSoundsPlayer then
            HKS.HitKillSoundsPlayer.stop_file(1)
            HKS.HitKillSoundsPlayer.stop_file(2)
            HKS.HitKillSoundsPlayer.stop_file(3)
            HKS.HitKillSoundsPlayer.stop_file(4)
        end
    elseif setting_id == "game_hit_sound_enabled" or setting_id == "game_kill_sound_enabled" then
        if HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents.rebuild_silenced_patterns then
            HKS.HitKillSoundsEvents.rebuild_silenced_patterns()
        end
    end
end
