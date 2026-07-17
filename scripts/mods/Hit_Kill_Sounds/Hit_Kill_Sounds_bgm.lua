-- luacheck: globals get_mod Managers Mods Wwise CLASS Vector3 Quaternion
local HKS = get_mod("Hit_Kill_Sounds")

local BGM = {}

local MUSIC_ZONE_GROUP = "music_zone"
local HUB_GAME_MODE = "hub"
local SILENCED_MUSIC_ZONE = "None"
local WWISE_GAME_SYNC_MANAGER_PATH = "scripts/managers/wwise_game_sync/wwise_game_sync_manager"
local LIVE_VOLUME_DECAY = 0.01
local LIVE_VOLUME_MIN_DISTANCE = 0
local LIVE_VOLUME_MAX_DISTANCE = 100

local BGM_FILES = {
    "Lobby_BGM1.mp3",
    "Lobby_BGM2.mp3",
    "Lobby_BGM3.mp3",
    "Lobby_BGM4.mp3",
    "Lobby_BGM5.mp3",
    "Lobby_BGM6.mp3",
}

local BGM_PATHS = {}
local BGM_FILESYSTEM_PATHS = {}

for i, filename in ipairs(BGM_FILES) do
    BGM_PATHS[i] = "mods/Hit_Kill_Sounds/audio/BGM/" .. filename
    BGM_FILESYSTEM_PATHS[i] = "../mods/Hit_Kill_Sounds/audio/BGM/" .. filename
end

local simple_audio
local initialized = false
local manager_hook_installed = false
local native_music_suppressed = false
local play_id
local current_index
local previous_index
local current_file
local generation = 0
local last_mode
local playback_blocked = false
local files_valid
local warnings = {}
local saved_native_music_state
local volume_update_pending = false

local function warn_once(key, message)
    if warnings[key] then
        return
    end

    warnings[key] = true
    HKS:warning(message)
end

local function get_game_mode_name()
    local state = Managers and Managers.state
    local game_mode = state and state.game_mode

    if not game_mode or type(game_mode.game_mode_name) ~= "function" then
        return nil
    end

    local ok, game_mode_name = pcall(function()
        return game_mode:game_mode_name()
    end)

    return ok and game_mode_name or nil
end

local function is_hub()
    return get_game_mode_name() == HUB_GAME_MODE
end

local function is_gameplay_ui_ready()
    local ui = Managers and Managers.ui

    if not ui or type(ui.get_current_sub_state_name) ~= "function" then
        return false
    end

    local ok, sub_state_name = pcall(function()
        return ui:get_current_sub_state_name()
    end)

    return ok and sub_state_name == "GameplayStateRun"
end

local function should_run()
    return HKS:get("enabled") ~= false
        and HKS:get("lobby_bgm_enabled") == true
        and is_hub()
end

local function get_simple_audio()
    if simple_audio == nil and get_mod then
        simple_audio = get_mod("SimpleAudio")
    end

    return simple_audio
end

local function file_exists(path)
    local lua_mods = Mods and Mods.lua
    local lua_io = lua_mods and lua_mods.io

    if not lua_io or type(lua_io.open) ~= "function" then
        return nil
    end

    local ok, handle = pcall(lua_io.open, path, "rb")
    if not ok or not handle then
        return false
    end

    pcall(function()
        handle:close()
    end)

    return true
end

local function validate_bgm_files()
    for _, path in ipairs(BGM_FILESYSTEM_PATHS) do
        if file_exists(path) == false then
            warn_once(
                "missing_file",
                "[Hit_Kill_Sounds] Custom Mourningstar BGM is disabled because the file is missing: " .. path
            )
            return false
        end
    end

    return true
end

local function get_volume()
    local volume = tonumber(HKS:get("lobby_bgm_volume")) or 100

    if volume < 0 then
        return 0
    elseif volume > 100 then
        return 100
    end

    return volume
end

local function apply_live_volume(active_play_id)
    local SimpleAudio = get_simple_audio()

    if not active_play_id or not SimpleAudio or type(SimpleAudio.set_position) ~= "function" then
        return false
    end

    -- SimpleAudio 的公开实时增益入口是 set_position。通过固定虚拟距离生成
    -- 0-100 的 spatial_volume，并传入覆盖位置，避免改变真实 BGM 的空间位置。
    -- 播放实例以 100 为 base volume，确保音量滑块可以双向调整。
    local distance = (100 - get_volume()) / 2
    local ok, updated = pcall(function()
        return SimpleAudio.set_position(
            active_play_id,
            Vector3(0, 0, distance),
            LIVE_VOLUME_DECAY,
            LIVE_VOLUME_MIN_DISTANCE,
            LIVE_VOLUME_MAX_DISTANCE,
            Vector3.zero(),
            Quaternion.identity()
        )
    end)

    return ok and updated == true
end

local function valid_play_id(value)
    local numeric_id = tonumber(value)

    return numeric_id and numeric_id > 0
end

local function choose_next_index()
    local count = #BGM_PATHS

    if count == 0 then
        return nil
    end

    if count == 1 then
        return 1
    end

    local excluded_index = current_index or previous_index
    if not excluded_index then
        return math.random(count)
    end

    local index = math.random(count - 1)

    if index >= excluded_index then
        index = index + 1
    end

    return index
end

local function official_music_zone_state()
    local wwise_game_sync = Managers and Managers.wwise_game_sync
    local wwise_state_groups = wwise_game_sync and wwise_game_sync._wwise_state_groups
    local zone_group = wwise_state_groups and wwise_state_groups[MUSIC_ZONE_GROUP]
    local zone_state

    if zone_group and type(zone_group.wwise_state) == "function" then
        local ok, state = pcall(function()
            return zone_group:wwise_state()
        end)

        if ok and type(state) == "string" then
            zone_state = state
        end
    end

    local mission_manager = Managers and Managers.state and Managers.state.mission
    local mission
    if mission_manager and type(mission_manager.mission) == "function" then
        local ok, result = pcall(function()
            return mission_manager:mission()
        end)

        if ok then
            mission = result
        end
    end

    local mission_state = mission and mission.wwise_state
    local game_mode_name = get_game_mode_name()

    -- 在离开 hub 的过渡帧中，以官方 mission.wwise_state 优先，避免把 hub 恢复状态带入任务。
    if game_mode_name ~= HUB_GAME_MODE and type(mission_state) == "string" then
        zone_state = mission_state
    elseif not zone_state and type(mission_state) == "string" then
        zone_state = mission_state
    end

    if not zone_state and wwise_game_sync and wwise_game_sync._wwise_state_group_states then
        zone_state = wwise_game_sync._wwise_state_group_states[MUSIC_ZONE_GROUP]
    end

    -- 未知状态不应被当作恢复状态写回，否则可能把原生音乐留在 None。
    if zone_state == SILENCED_MUSIC_ZONE then
        return nil
    end

    return zone_state
end

local function restore_native_music()
    if not Wwise or type(Wwise.set_state) ~= "function" then
        return false
    end

    local zone_state = official_music_zone_state() or saved_native_music_state
    if not zone_state then
        return false
    end

    local wwise_game_sync = Managers and Managers.wwise_game_sync
    if wwise_game_sync and type(wwise_game_sync._set_state) == "function" then
        local ok = pcall(function()
            wwise_game_sync:_set_state(MUSIC_ZONE_GROUP, zone_state)
        end)

        if ok then
            return true
        end
    end

    local ok = pcall(function()
        Wwise.set_state(MUSIC_ZONE_GROUP, zone_state)
    end)

    return ok
end

local function release_native_music()
    local was_suppressed = native_music_suppressed
    native_music_suppressed = false

    if not was_suppressed then
        return true
    end

    local restored = restore_native_music()
    if not restored then
        warn_once(
            "restore_failed",
            "[Hit_Kill_Sounds] Could not restore the official music_zone state after custom hub BGM stopped."
        )
    else
        saved_native_music_state = nil
    end

    return restored
end

local function mute_native_music()
    if not is_hub() or not Wwise or type(Wwise.set_state) ~= "function" then
        return false
    end

    saved_native_music_state = official_music_zone_state() or HUB_GAME_MODE

    native_music_suppressed = true
    local ok = pcall(function()
        Wwise.set_state(MUSIC_ZONE_GROUP, SILENCED_MUSIC_ZONE)
    end)

    if not ok then
        native_music_suppressed = false
    end

    return ok
end

local function stop_playback_only()
    generation = generation + 1
    volume_update_pending = false

    local active_play_id = play_id
    play_id = nil

    local SimpleAudio = get_simple_audio()
    if active_play_id and SimpleAudio and type(SimpleAudio.stop_file) == "function" then
        pcall(SimpleAudio.stop_file, active_play_id)
    end
end

local function block_playback(key, message)
    playback_blocked = true
    warn_once(key, message)

    if native_music_suppressed then
        release_native_music()
    end
end

local function play_track(index)
    local SimpleAudio = get_simple_audio()
    local path = BGM_PATHS[index]

    if not SimpleAudio or type(SimpleAudio.play_file) ~= "function" then
        block_playback(
            "simple_audio_missing",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM is disabled because "
                .. "SimpleAudio.play_file is unavailable; official music was left unchanged."
        )
        return false
    end

    if not path or not is_hub() or HKS:get("enabled") == false or HKS:get("lobby_bgm_enabled") ~= true then
        return false
    end

    local callback_generation = generation
    local ok, new_play_id = pcall(function()
        return SimpleAudio.play_file(path, {
            audio_type = "music",
            volume = 100,
            on_finished = function(finished_play_id)
                if finished_play_id ~= play_id or callback_generation ~= generation then
                    return
                end

                play_id = nil

                if not should_run() then
                    BGM.stop(true)
                    return
                end

                local next_index = choose_next_index()
                if not next_index then
                    block_playback(
                        "no_bgm_files",
                        "[Hit_Kill_Sounds] Custom Mourningstar BGM has no playable files; official music was restored."
                    )
                    return
                end

                play_track(next_index)
            end,
        })
    end)

    if not ok or not valid_play_id(new_play_id) then
        block_playback(
            "play_failed",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM playback failed for "
                .. tostring(current_file or path)
                .. "; official music was left/restored."
        )
        return false
    end

    play_id = new_play_id
    previous_index = current_index
    current_index = index
    current_file = path

    if not apply_live_volume(new_play_id) then
        pcall(SimpleAudio.stop_file, new_play_id)
        play_id = nil
        block_playback(
            "live_volume_unavailable",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM was not started because its live volume "
                .. "could not be applied safely."
        )
        return false
    end

    -- 原生音乐只有在 SimpleAudio 已经返回有效 play_id 后才允许静音。
    if not native_music_suppressed and not mute_native_music() then
        pcall(SimpleAudio.stop_file, new_play_id)
        play_id = nil
        block_playback(
            "native_mute_failed",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM was not started because "
                .. "the official hub music could not be safely muted."
        )
        return false
    end

    return true
end

local function install_music_state_hook()
    local manager_class = CLASS and CLASS.WwiseGameSyncManager

    if not manager_class then
        local ok, result = pcall(require, WWISE_GAME_SYNC_MANAGER_PATH)
        if ok then
            manager_class = result
        end
    end

    if not manager_class then
        warn_once(
            "wwise_manager_missing",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM is disabled because WwiseGameSyncManager could not be loaded."
        )
        return false
    end

    local ok = pcall(function()
        HKS:hook(manager_class, "_set_state", function(func, self, group_name, new_state, ...)
            if group_name == MUSIC_ZONE_GROUP and native_music_suppressed and is_hub() then
                return func(self, group_name, SILENCED_MUSIC_ZONE, ...)
            end

            return func(self, group_name, new_state, ...)
        end)
    end)

    if not ok then
        warn_once(
            "wwise_manager_hook_failed",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM is disabled because the "
                .. "Wwise music_zone hook could not be installed."
        )
        return false
    end

    manager_hook_installed = true
    return true
end

local function install_music_event_hook()
    local SimpleAudio = get_simple_audio()

    if not SimpleAudio or type(SimpleAudio.hook_sound) ~= "function" then
        return false
    end

    local ok = pcall(function()
        SimpleAudio.hook_sound("^wwise/events/music/play_music_manager$", function()
            if native_music_suppressed and is_hub() then
                return false
            end
        end)
    end)

    return ok
end

local function native_music_control_available()
    return manager_hook_installed and Wwise and type(Wwise.set_state) == "function"
end

local function stop_bgm(reset_track)
    stop_playback_only()

    local restored = release_native_music()

    if reset_track then
        current_index = nil
        previous_index = nil
        current_file = nil
    end

    return restored
end

BGM.init = function()
    if initialized then
        return
    end

    initialized = true
    get_simple_audio()
    install_music_state_hook()
    install_music_event_hook()

    files_valid = validate_bgm_files()
    if files_valid == false then
        playback_blocked = true
    end
end

BGM.update = function(_dt)
    if not initialized then
        return
    end

    local game_mode_name = get_game_mode_name()
    if game_mode_name ~= last_mode then
        if last_mode == HUB_GAME_MODE or game_mode_name ~= HUB_GAME_MODE then
            stop_bgm(true)
        end

        playback_blocked = false
        last_mode = game_mode_name

        if files_valid == false then
            playback_blocked = true
        end
    end

    if not should_run() then
        if play_id or native_music_suppressed then
            stop_bgm(true)
        end

        return
    end

    if playback_blocked then
        return
    end

    -- 进入 hub 的过渡帧还没有 GameplayStateRun 时，先等待，避免对尚未
    -- 完成初始化的 SimpleAudio 实例调用 set_position。
    if not is_gameplay_ui_ready() then
        return
    end

    if play_id and volume_update_pending then
        volume_update_pending = false

        if not apply_live_volume(play_id) then
            warn_once(
                "live_volume_update_failed",
                "[Hit_Kill_Sounds] Custom Mourningstar BGM volume could not be updated live; "
                    .. "the current track was kept without restarting."
            )
        end
    end

    if not native_music_control_available() then
        block_playback(
            "native_control_unavailable",
            "[Hit_Kill_Sounds] Custom Mourningstar BGM is disabled because safe "
                .. "native hub music control is unavailable; official music was left unchanged."
        )
        return
    end

    if files_valid == nil then
        files_valid = validate_bgm_files()
        if not files_valid then
            playback_blocked = true
            return
        end
    end

    if files_valid == false then
        playback_blocked = true
        return
    end

    if not play_id then
        local next_index = choose_next_index()
        if not next_index then
            block_playback(
                "no_bgm_files",
                "[Hit_Kill_Sounds] Custom Mourningstar BGM is disabled because no "
                    .. "BGM files are configured; official music was left unchanged."
            )
            return
        end

        play_track(next_index)
    end
end

BGM.stop = function(reset_track)
    return stop_bgm(reset_track == true)
end

BGM.on_setting_changed = function(setting_id)
    if setting_id == "lobby_bgm_volume" then
        if play_id and should_run() then
            if is_gameplay_ui_ready() then
                if not apply_live_volume(play_id) then
                    warn_once(
                        "live_volume_update_failed",
                        "[Hit_Kill_Sounds] Custom Mourningstar BGM volume could not be updated live; "
                            .. "the current track was kept without restarting."
                    )
                end
            else
                volume_update_pending = true
            end
        end

        return
    end

    if setting_id == "enabled" or setting_id == "lobby_bgm_enabled" then
        playback_blocked = false

        if should_run() then
            BGM.update(0)
        else
            BGM.stop(true)
        end
    end
end

BGM.shutdown = function()
    BGM.stop(true)
    generation = generation + 1
    initialized = false
    last_mode = nil
end

HKS.HitKillSoundsBGM = BGM

return BGM
