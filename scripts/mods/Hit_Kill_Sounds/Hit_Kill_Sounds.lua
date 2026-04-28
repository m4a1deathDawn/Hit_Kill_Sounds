local HKS = get_mod("Hit_Kill_Sounds")

-- 使用 io_dofile 加载其他模块
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_player")
HKS:io_dofile("Hit_Kill_Sounds/scripts/mods/Hit_Kill_Sounds/Hit_Kill_Sounds_events")

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
end
