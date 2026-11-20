-- Pure Lua tests; also executable as a luacheck config using its bundled Lua 5.4.
-- Run from the Mod root: luacheck --config tests/run.lua --no-cache scripts/mods/Hit_Kill_Sounds
local root = "scripts/mods/Hit_Kill_Sounds/"
local total = 0
local function test(name, body)
    local ok, reason = pcall(body)
    assert(ok, name .. ": " .. tostring(reason))
    total = total + 1
    print("PASS " .. name)
end
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function load_module(filename, env)
    return assert(loadfile(root .. filename .. ".lua", "t", env))()
end
local function environment(hks, extra)
    local env = extra or {}
    env.get_mod = env.get_mod or function() return hks end
    return setmetatable(env, {__index = _G})
end
local function custom_fixture(files)
    local warnings, reads = {}, {}
    local hks = {warning = function(_, _, text) warnings[#warnings + 1] = text end}
    local env = environment(hks, {Mods = {lua = {io = {open = function(path)
        reads[#reads + 1] = path
        local content = files and files[path]
        if not content then return nil end
        return {
            read = function(_, size) return content:sub(1, size) end,
            close = function() return true end,
        }
    end}}}})
    return load_module("Hit_Kill_Sounds_custom_audio", env), warnings, reads
end
local custom = custom_fixture()
local function parse(text, kind, probe)
    return custom.parse_manifest(text, kind or "hit", probe or function() return true end)
end
local playback_root = "mods/Hit_Kill_Sounds/UserAudio/"
local filesystem_root = "../mods/Hit_Kill_Sounds/UserAudio/"
local wav = "RIFF1234WAVErest"

test("BOM, CRLF, whitespace, comments and explicit categories", function()
    local pools = parse("\239\187\191# comment\r\n\n normal | Hit/Normal.wav \r\nheadshot|other.WAV\n")
    equal(#pools.normal, 1)
    equal(#pools.headshot, 1)
    equal(pools.normal[1], playback_root .. "Hit/Normal.wav")
    equal(pools.headshot[1], playback_root .. "other.WAV")
    equal(#parse("Hit/Normal.wav\nunknown|Hit/a.wav\nbgm|a.wav").normal, 0)
end)
test("path rejection happens before file access", function()
    local invalid = {
        "../a.wav", "Hit/../a.wav", "Hit/foo..wav", "/a.wav", "C:/a.wav", "C:a.wav",
        "//server/a.wav", "\\\\server\\a.wav", "Hit/*.wav", "Hit/?.wav", '"Hit/a.wav"',
        "'Hit/a.wav'", "os.execute('a.wav')", "Hit/a.wav;return 1", "Hit/a.wav|other",
        "Hit/a.mp3", "Hit/./a.wav", "Hit//a.wav", "Hit/a /b.wav", "Hit/a./b.wav",
        "NUL.wav", "aux/b.wav", "COM1.wav", "Hit/a.wav:stream", "Hit/a\0.wav",
    }
    for _, path in ipairs(invalid) do
        local probes = 0
        local pools = parse("normal|" .. path, "hit", function() probes = probes + 1; return true end)
        equal(#pools.normal, 0)
        equal(probes, 0)
    end
end)
test("slash normalization, spaces and UTF-8 names", function()
    equal(parse("normal|Hit\\normal\\my sound.wav").normal[1], playback_root .. "Hit/normal/my sound.wav")
    equal(#parse("headshot|Hit/爆头.wav").headshot, 1)
end)
test("missing and unreadable files are skipped, valid entries survive", function()
    local pools = parse("normal|missing.wav\nnormal|bad.wav\nnormal|ok.wav", "hit", function(path)
        if path == "bad.wav" then error("read denied") end
        return path == "ok.wav"
    end)
    equal(#pools.normal, 1)
    equal(pools.normal[1], playback_root .. "ok.wav")
end)
test("case-insensitive dedup is per category", function()
    local pools = parse("normal|Hit/A.wav\nnormal|hit/a.WAV\nheadshot|Hit/A.wav")
    equal(#pools.normal, 1)
    equal(#pools.headshot, 1)
end)
test("first 20 valid paths per SFX category and BGM", function()
    local lines, bgm_lines = {"normal|missing.wav"}, {}
    for i = 1, 25 do
        lines[#lines + 1] = "normal|Hit/" .. i .. ".wav"
        lines[#lines + 1] = "headshot|Hit/h" .. i .. ".wav"
        bgm_lines[#bgm_lines + 1] = "BGM/" .. i .. ".mp3"
    end
    local pools = parse(table.concat(lines, "\n"), "hit", function(path) return path ~= "missing.wav" end)
    equal(#pools.normal, 20)
    equal(#pools.headshot, 20)
    equal(pools.normal[20], playback_root .. "Hit/20.wav")
    equal(#parse(table.concat(bgm_lines, "\n"), "bgm").bgm, 20)
end)
test("BGM accepts only pure MP3 paths and rejects oversized manifests", function()
    local pools = parse("\239\187\191 # BGM\nBGM/a.mp3\nBGM/a.mp3\nnormal|BGM/b.mp3\nBGM/b.wav", "bgm")
    equal(#pools.bgm, 1)
    equal(#parse(string.rep("a", 65537)).normal, 0)
end)
test("init caches once; header checks; headshot -> normal -> BFV; warn once", function()
    local files = {
        [filesystem_root .. "Hit/playlist.txt"] = "normal|Hit/Normal.wav\nheadshot|Hit/Fake.wav",
        [filesystem_root .. "Hit/Normal.wav"] = wav,
        [filesystem_root .. "Hit/Fake.wav"] = "ID3not a WAV",
        [filesystem_root .. "BGM/tracks.txt"] = "BGM/Lobby.mp3",
        [filesystem_root .. "BGM/Lobby.mp3"] = "ID3test MP3",
    }
    local helper, warnings, reads = custom_fixture(files)
    helper.init()
    local count = #reads
    helper.init()
    equal(#reads, count)
    equal(helper.sample("hit", true, {}), playback_root .. "Hit/Normal.wav")
    equal(helper.sample("kill", true, {normal = {"BFV.wav"}}), "BFV.wav")
    equal(helper.sample("kill", false, {}), nil)
    local warning_count = #warnings
    for _ = 1, 20 do helper.sample("kill", true, {}) end
    equal(#warnings, warning_count)
    equal(#reads, count)
    equal(helper.get_bgm_paths()[1], playback_root .. "BGM/Lobby.mp3")
    helper.clear()
    equal(#helper.get_bgm_paths(), 0)
    helper.init()
    assert(#reads > count)
end)

local function bgm_fixture(paths, options)
    options = options or {}
    local state = {mode = "hub", native = "hub", calls = {}, stopped = {}, reads = 0, enabled = true}
    state.settings = {enabled = true, lobby_bgm_enabled = true, lobby_bgm_volume = 100}
    state.native_calls = {}
    state.persistent = options.persistent or {}
    local hks = {
        persistent_table = function(_, key)
            equal(key, "Hit_Kill_Sounds_native_music_restore_v1")
            state.persistent[key] = state.persistent[key] or {}
            state.restore_storage = state.persistent[key]
            return state.restore_storage
        end,
        get = function(_, key) return state.settings[key] end,
        is_enabled = function() return state.enabled end,
        warning = function() end,
        HitKillSoundsCustomAudio = {get_bgm_paths = function() return paths or {} end},
    }
    local manager = {_wwise_state_group_states = {music_zone = "hub"}}
    state.manager = manager
    local wwise = {set_state = function(group, value)
        state.native_calls[#state.native_calls + 1] = {group = group, value = value}
        state.native = value
    end}
    manager._set_state = function(_, group, value)
        -- Match official WwiseGameSyncManager: repeated cached values are no-ops.
        if manager._wwise_state_group_states[group] ~= value then
            manager._wwise_state_group_states[group] = value
            wwise.set_state(group, value)
        end
    end
    manager._wwise_state_groups = {music_zone = {wwise_state = function() return state.native end}}
    local audio = {
        hook_sound = function(_, callback) state.music_event_hook = callback end,
        play_file = function(path, config)
            equal(config.audio_type, "music")
            state.calls[#state.calls + 1] = {path = path, config = config, native_before = state.native}
            if options.fail and options.fail(path, #state.calls) then return nil end
            return options.reuse_play_id and 1 or #state.calls
        end,
        stop_file = function(id)
            assert(id ~= nil, "HKS must never stop all SimpleAudio instances")
            state.stopped[#state.stopped + 1] = id
            if options.finish_on_stop then state.calls[#state.calls].config.on_finished(id) end
        end,
        set_position = function() return not options.volume_fail end,
    }
    local base_manager_set_state = manager._set_state
    hks.hook = function(_, _, method, callback)
        local original = manager[method]
        manager[method] = function(self, ...) return callback(original, self, ...) end
    end
    local env = environment(hks, {
        get_mod = function(name)
            if name == "SimpleAudio" then return not options.no_audio and audio or nil end
            return hks
        end,
        CLASS = options.no_native and {} or {WwiseGameSyncManager = {}},
        require = function() error("no fallback native class") end,
        Wwise = wwise,
        Managers = {
            state = {game_mode = {game_mode_name = function() return state.mode end}},
            ui = {get_current_sub_state_name = function() return "GameplayStateRun" end},
            wwise_game_sync = manager,
        },
        Vector3 = setmetatable({zero = function() return {} end}, {__call = function() return {} end}),
        Quaternion = {identity = function() return {} end},
        Mods = {lua = {io = {open = function()
            state.reads = state.reads + 1
            if options.missing_legacy then return nil end
            return {close = function() return true end}
        end}}},
    })
    state.env = env
    state.audio = audio
    state.hks = hks
    state.reload = function()
        -- DMF restores hooked functions and rebuilds Mod objects, but retains persistent tables.
        manager._set_state = base_manager_set_state
        local rebuilt = {}
        for key, value in pairs(hks) do
            if key ~= "HitKillSoundsBGM" then rebuilt[key] = value end
        end
        hks = rebuilt
        state.hks = hks
        state.bgm = load_module("Hit_Kill_Sounds_bgm", env)
        state.bgm.init()
    end
    state.bgm = load_module("Hit_Kill_Sounds_bgm", env)
    state.bgm.init()
    return state
end

test("BGM manifest priority, no repeated disk reads, live volume and callback rotation", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3", playback_root .. "BGM/b.mp3"})
    equal(state.reads, 0)
    state.bgm.update(0.1)
    equal(#state.calls, 1)
    equal(state.calls[1].native_before, "hub")
    equal(state.native, "None")
    local first = state.calls[1]
    first.config.on_finished(1)
    equal(#state.calls, 2)
    assert(state.calls[2].path ~= first.path)
    state.settings.lobby_bgm_volume = 50
    state.bgm.on_setting_changed("lobby_bgm_volume")
    equal(#state.calls, 2)
    for _ = 1, 10 do state.bgm.update(0.1) end
    equal(state.reads, 0)
    state.bgm.stop(true)
    equal(state.native, "hub")
    first.config.on_finished(1)
    equal(#state.calls, 2) -- obsolete callback must not restart a track
end)
test("empty/absent/invalid manifest preserves all six legacy slots", function()
    local seen = {}
    for index = 1, 6 do
        local state = bgm_fixture({})
        state.env.math = setmetatable({random = function() return index end}, {__index = math})
        equal(state.reads, 6)
        state.bgm.update(0.1)
        local path = state.calls[1].path
        assert(path:match("^mods/Hit_Kill_Sounds/audio/BGM/Lobby_BGM[1-6]%.mp3$"))
        seen[path] = true
        state.bgm.stop(true)
        equal(state.native, "hub")
    end
    local count = 0
    for _ in pairs(seen) do count = count + 1 end
    equal(count, 6)
end)
test("BGM tries every failed custom track once, then keeps native music", function()
    local paths = {}
    for i = 1, 20 do paths[i] = playback_root .. "BGM/" .. i .. ".mp3" end
    local state = bgm_fixture(paths, {fail = function() return true end})
    for _ = 1, 25 do
        state.bgm.update(0.6)
        equal(state.native, "hub")
    end
    equal(#state.calls, 20)
    local seen = {}
    for _, call in ipairs(state.calls) do
        assert(not seen[call.path])
        seen[call.path] = true
    end
end)
test("BGM failed transition releases native music before retrying other custom track", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3", playback_root .. "BGM/b.mp3"}, {
        fail = function(_, count) return count == 2 end,
    })
    state.bgm.update(0.1)
    equal(state.native, "None")
    state.calls[1].config.on_finished(1)
    equal(state.native, "hub")
    state.bgm.update(0.6)
    equal(#state.calls, 3)
    equal(state.calls[3].native_before, "hub")
    equal(state.native, "None")
end)
test("BGM fails open without audio, readiness, native control, files or volume control", function()
    for _, options in ipairs({
        {no_audio = true}, {no_native = true}, {volume_fail = true},
        {fail = function() return true end},
    }) do
        local state = bgm_fixture({playback_root .. "BGM/a.mp3"}, options)
        state.bgm.update(0.1)
        equal(state.native, "hub")
    end
    local state = bgm_fixture({}, {missing_legacy = true})
    state.bgm.update(0.1)
    equal(#state.calls, 0)
    equal(state.native, "hub")
end)
test("hub exit, mission, return, disabled settings, Mod disable and shutdown restore native", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.mode = "mission"
    state.bgm.update(0.1)
    equal(state.native, "hub")
    equal(#state.stopped, 1)
    state.mode = "hub"
    state.bgm.update(0.1)
    equal(#state.calls, 2)
    state.settings.lobby_bgm_enabled = false
    state.bgm.on_setting_changed("lobby_bgm_enabled")
    equal(state.native, "hub")
    state.settings.lobby_bgm_enabled = true
    state.bgm.on_setting_changed("lobby_bgm_enabled")
    equal(state.native, "None")
    state.enabled = false
    state.bgm.update(0.1)
    equal(state.native, "hub")
    state.enabled = true
    state.bgm.update(0.1)
    equal(state.native, "None")
    state.bgm.shutdown()
    equal(state.native, "hub")
end)
test("temporary native restore API loss is retried on later updates", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    local original = state.manager._set_state
    local wwise = state.env.Wwise
    state.manager._set_state = function() error("temporary native failure") end
    state.env.Wwise = false
    state.settings.lobby_bgm_enabled = false
    equal(state.bgm.stop(true), false)
    equal(state.native, "None")
    state.manager._set_state = original
    state.env.Wwise = wwise
    state.bgm.update(0.1)
    equal(state.native, "hub")
end)

local function backend_fixture(options)
    options = options or {}
    local state = {now = 1, calls = {}, stopped = {}, legacy = {}, settings = {enabled = true}}
    local hks = {
        get = function(_, key) return state.settings[key] end,
        info = function() end, warning = function() end,
        HitKillSoundsPlayer = {
            TRACKS = {HIT_NORMAL = 1, HIT_HEADSHOT = 2, KILL_NORMAL = 3, KILL_HEADSHOT = 4},
            legacy_available = options.legacy == true,
            play_file = function(path) state.legacy[#state.legacy + 1] = path; return true end,
            stop_file = function() end,
        },
    }
    local audio = {
        play_file = function(path, config)
            state.calls[#state.calls + 1] = {path = path, config = config}
            if options.play_fail then return nil end
            return #state.calls
        end,
        stop_file = function(id, fade) state.stopped[#state.stopped + 1] = {id = id, fade = fade} end,
        is_file_playing = function() return true end,
    }
    local env = environment(hks, {
        get_mod = function(name)
            if name == "SimpleAudio" then return not options.no_audio and audio or nil end
            return hks
        end,
        Managers = {time = {time = function() return state.now end}},
    })
    state.hks, state.env, state.audio = hks, env, audio
    state.backend = load_module("Hit_Kill_Sounds_audio_backend", env)
    state.backend.init()
    state.enqueue = function(kind, priority)
        local track = kind == "hit_normal" and 1 or 3
        return state.backend.enqueue("test.wav", track, 100, priority, kind)
    end
    state.step = function(dt)
        state.now = state.now + dt
        state.backend.update(dt)
    end
    return state
end

test("HKS voice limits 5 hit / 5 kill / 10 total; capacity counts and cleanup callbacks", function()
    local state = backend_fixture()
    for _ = 1, 5 do assert(state.enqueue("hit_normal", 4)); state.step(0.04) end
    equal(#state.backend.get_active_voices(), 5)
    assert(state.enqueue("hit_normal", 4))
    state.step(0.04)
    equal(state.backend.get_statistics().dropped_capacity, 1)
    equal(#state.stopped, 0) -- normal hit must not truncate an equal-priority voice
    for _ = 1, 5 do assert(state.enqueue("kill_normal", 2)); state.step(0.04) end
    equal(#state.backend.get_active_voices(), 10)
    equal(state.backend.get_statistics().peak_active, 10)
    assert(state.enqueue("kill_normal", 0)); state.step(0.04)
    equal(#state.backend.get_active_voices(), 10)
    equal(state.stopped[1].fade, 0.025)
    state.calls[1].config.on_finished(1)
    equal(#state.backend.get_active_voices(), 9)
    state.backend.stop_all()
    equal(#state.backend.get_active_voices(), 0)
    equal(#state.backend.get_pending_queue(), 0)
end)
test("pending cap 10, priority replacement, dispatch max 2, interval and expiry unchanged", function()
    local state = backend_fixture()
    for _ = 1, 10 do assert(state.enqueue("hit_normal", 4)) end
    equal(state.enqueue("hit_normal", 4), false)
    equal(state.backend.get_statistics().dropped_queue_full, 1)
    assert(state.enqueue("kill_normal", 1))
    equal(#state.backend.get_pending_queue(), 10)
    state.step(0)
    equal(#state.calls, 2)
    assert(state.calls[1].config.audio_type == "sfx")
    state.step(0.01)
    equal(#state.calls, 2)
    state.step(0.03)
    equal(#state.calls, 4)
    state.step(0.2)
    equal(#state.backend.get_pending_queue(), 0)
    equal(state.backend.get_statistics().dropped_expired, 6)
end)
test("playback failure never launches legacy while SimpleAudio exists; old fallback path intact", function()
    local state = backend_fixture({play_fail = true, legacy = true})
    assert(state.enqueue("hit_normal", 4)); state.step(0.04)
    equal(state.backend.get_statistics().playback_failed, 1)
    equal(#state.legacy, 0)
    local legacy = backend_fixture({no_audio = true, legacy = true})
    assert(legacy.backend.enqueue("HitSounds/BF1/test.wav", 1, 50, 4, "hit_normal"))
    legacy.step(0.04)
    equal(legacy.legacy[1], "HitSounds/BF1/test.wav")
end)

local function event_fixture(options)
    local state = backend_fixture(options)
    local settings = state.settings
    settings.hit_sound_enabled, settings.kill_sound_enabled, settings.hit_melee = true, true, true
    settings.killstreak_enabled = false
    local hooks = {}
    state.hks.hook = function(_, _, method, callback) hooks[method] = callback end
    state.env.CLASS = {AttackReportManager = {}, WwiseWorld = {}}
    state.env.Mods = false -- tests never run the existing CF directory probe against a real disk
    local enum = setmetatable({}, {__index = function(_, key) return key end})
    state.env.require = function(name)
        if name:find("attack_settings", 1, true) then return {attack_types = enum, attack_results = enum} end
        if name:find("damage_settings", 1, true) then return {damage_types = enum} end
        return {is_player = function() return false end, is_prop = function() return false end}
    end
    state.env.Managers.player = {local_player_safe = function() return {player_unit = "player"} end}
    state.env.ScriptUnit = {has_extension = function() return {breed = function() return {} end} end}
    local KillstreakCounter = load_module("Hit_Kill_Sounds_killstreak", state.env)
    state.hks.HitKillSoundsKillstreakCounters = {cf_sound_counter = KillstreakCounter.new("cf_sound")}
    load_module("Hit_Kill_Sounds_events", state.env)
    state.hks.HitKillSoundsEvents.init_damage_hooks()
    state.wwise_hook = hooks.trigger_resource_event
    state.hit_timestamp = function()
        for i = 1, 50 do
            local name, handler = debug.getupvalue(hooks.add_attack_result, i)
            if not name then break end
            if name == "handle_attack_result" then
                for j = 1, 100 do
                    local key, value = debug.getupvalue(handler, j)
                    if not key then break end
                    if key == "last_hit_time" then return value end
                end
            end
        end
        error("hit timestamp upvalue not found")
    end
    state.attack = function(headshot, melee, killed, damage, result)
        hooks.add_attack_result(function() end, {}, {name = "test_attack"}, "enemy", "player",
            nil, nil, headshot == true, damage or 1, result or (killed and "died" or "damaged"),
            melee and "melee" or "ranged")
    end
    return state
end

-- §33 Wwise coverage exercises the installed regular hook, not a copied matcher.
local wwise_hit_events = {
    "melee_hits", "melee_hits_blunt_heavy", "melee_hits_blunt_gen", "melee_hits_sword_gen",
    "melee_hits_knife_gen", "melee_hits_blunt_shield", "melee_hits_blunt_heavy_husk",
    "play_melee_hits", "play_melee_hits_axe_armor", "play_melee_hits_sharp_impact_add",
    "play_bullet_hits", "play_bullet_hits_gen", "play_bullet_hits_gen_husk",
    "play_bullet_hits_throwing_knife", "play_traitor_captain_shield_bullet_hits",
    "play_traitor_captain_shield_bullet_hits_husk",
    "play_hit_indicator_death_knife", "play_hit_indicator_melee_slashing_super_armor_no_damage",
    "play_hit_indicator_melee_super_armor_no_damage", "play_hit_indicator_vanguard_shield_break",
    "play_hit_indicator_weakspot_melee_blunt", "play_hit_indicator_weakspot_melee_sharp",
    "play_indicator_crit", "play_indicator_crit_melee_hit", "play_indicator_crit_melee_hit_slashing",
    "play_indicator_crit_psyker", "play_indicator_crit_weak", "play_indicator_death_psyker",
    "play_indicator_force_kill_2d", "play_indicator_weakspot", "play_indicator_weakspot_armored",
    "play_indicator_weakspot_husk",
    "play_chord_claw_hit", "play_chord_claw_hit_flesh", "play_chord_claw_hit_rip_flesh",
    "play_transonic_blades_impact_hit", "play_power_sword_1h_p3_hit_heavy",
    "play_power_sword_1h_p3_hit_light", "play_power_sword_hit", "play_power_sword_hit_heavy",
    "play_arc_maul_hit", "play_powermaul_1h_hit", "play_psyker_chain_lightning_hit",
    "play_ogryn_powermaul_1h_hit_sparks", "play_ogryn_powermaul_1h_spark",
    "play_arc_maul_1h_electric_sparks", "play_power_sword_1h_p2_hit", "play_power_sword_2h_hit",
    "play_melee_hit_forcesword_hit_damage", "play_melee_hits_forcesword_special_cleave",
    "play_combat_weapon_chainsword_hit_impact", "play_combat_weapon_chainsword_hit_res",
    "play_weapon_addon_hit_thunderhammer_sparks", "play_powermaul_1h_stuck_impact",
    "play_powermaul_1h_stuck_impact_died", "play_psyker_lightning_bolt_impact_death",
}
local wwise_kill_events = {
    "play_minion_killed", "play_elite_killed", "play_special_killed",
    "play_monster_killed", "play_husk_killed", "play_ogryn_killed",
}
local wwise_unrelated_events = {
    "play_player_get_hit_blunt", "play_toughness_hits", "play_toughness_hits_melee",
    "play_ogryn_hit_chest", "play_bolter_reload_hit", "play_bolter_equip_hit",
    "play_backstab_indicator_melee", "play_backstab_indicator_melee_elite", "play_backstab_indicator_ranged",
    "play_indicator_backstab_melee", "play_indicator_backstab_ranged",
    "play_indicator_crit_melee_swing", "play_indicator_crit_melee_swing_husk",
    "play_bullet_hits_gen_reload_foley", "play_indicator_weakspot_equip_start",
    "play_power_sword_hit_reload", "play_chord_claw_hit_equip", "melee_hits_reload",
    "play_power_sword_1h_p3_swing", "play_combat_weapon_chainsword_activate",
    "play_enemy_hit_react", "play_environment_hit_metal", "play_player_push_unarmored",
    "stop_psyker_chain_lightning_hit", "stop_bullet_hits_gen", "stop_melee_hits_blunt_heavy",
    -- Candidate families are deliberately deferred until a separate scope decision.
    "play_grenade_hits_unarmored", "play_saw_hit_heavy", "play_shovel_ogryn_hit_folded",
    "play_combat_weapon_hit_addon_bone", "play_psyker_throwing_knife_hit", "play_heavy_swing_hit",
}
local wwise_switches = {
    {name = "hit on / kill off", hit = true, kill = false},
    {name = "hit off / kill on", hit = false, kill = true},
    {name = "hit off / kill off", hit = false, kill = false},
    {name = "hit on / kill on", hit = true, kill = true},
}
local function set_wwise_switches(state, hit, kill)
    state.settings.game_hit_sound_enabled = hit
    state.settings.game_kill_sound_enabled = kill
    state.hks.HitKillSoundsEvents.rebuild_silenced_patterns()
end
local function wwise_is_silenced(state, event_name)
    local calls = 0
    local result = table.pack(state.wwise_hook(function(world, forwarded_event)
        calls = calls + 1
        equal(world, "wwise_test_world")
        equal(forwarded_event, event_name)
        return "played"
    end, "wwise_test_world", event_name))
    equal(calls, result.n)
    if calls > 0 then equal(result[1], "played") end
    return calls == 0
end
for _, switches in ipairs(wwise_switches) do
    test("Wwise full paths and basenames: " .. switches.name, function()
        local state = event_fixture()
        set_wwise_switches(state, switches.hit, switches.kill)
        for _, group in ipairs({
            {events = wwise_hit_events, silenced = not switches.hit, prefix = "wwise/events/weapon/"},
            {events = wwise_kill_events, silenced = not switches.kill, prefix = "wwise/events/minions/"},
            {events = wwise_unrelated_events, silenced = false, prefix = "wwise/events/player/"},
        }) do
            for _, basename in ipairs(group.events) do
                for _, event_name in ipairs({basename, group.prefix .. basename}) do
                    assert(wwise_is_silenced(state, event_name) == group.silenced, event_name)
                end
            end
        end
        equal(#state.backend.get_pending_queue(), 0)
        equal(#state.calls, 0)
    end)
end

test("Wwise exact kills, event-family boundaries and literal names avoid false matches", function()
    local state = event_fixture()
    set_wwise_switches(state, false, false)
    local unrelated = {
        "", "wwise/events/weapon/", "melee_hits/", "melee_hitsound", "play_melee_hitsound",
        "play_not_melee_hits_blunt_heavy", "play_not_bullet_hits_gen", "play_enemy_indicator_attack",
        "play_bullet_hits.gen", "play_bullet_hits%gen", "play_bullet_hits[gen]",
        "play_chord_claw_hit.flesh", "play_chord_claw_hit%flesh", "play_indicator+crit",
        "play_ogryn_powermaul_1h_spark_extra", "play_combat_weapon_chainsword_hit_impact_extra",
        "play_melee_hit_forcesword_hit_damage_extra", "play_psyker_lightning_bolt_impact_death_extra",
        "wwise/events/play_bullet_hits_gen/play_weapon_reload",
        "wwise/events/play_indicator_crit/play_weapon_equip",
        "wwise/events/melee_hits_blunt_heavy/play_weapon_swing",
        "wwise/events/play_minion_killed/play_weapon_swing",
    }
    for _, basename in ipairs(wwise_kill_events) do
        unrelated[#unrelated + 1] = basename .. "_extra"
        unrelated[#unrelated + 1] = basename .. "_husk"
        unrelated[#unrelated + 1] = basename .. ".*"
        unrelated[#unrelated + 1] = "play_not_" .. basename
    end
    for _, name in ipairs(unrelated) do
        assert(not wwise_is_silenced(state, name), name)
        assert(not wwise_is_silenced(state, "wwise/events/weapon/" .. name), name)
    end
    -- Directory names are opaque; punctuation there cannot become a Lua pattern.
    assert(wwise_is_silenced(state, "wwise/events/[weapon].%/melee_hits_blunt_heavy"))
    assert(wwise_is_silenced(state, "wwise/events/[weapon].%/play_indicator_crit"))
end)

test("Wwise non-string event names fail open under every switch combination", function()
    local names = table.pack(nil, false, true, 0, 2468, {}, function() end, io.stdout)
    local state = event_fixture()
    for _, switches in ipairs(wwise_switches) do
        set_wwise_switches(state, switches.hit, switches.kill)
        for index = 1, names.n do
            equal(wwise_is_silenced(state, names[index]), false)
        end
    end
end)

test("Wwise setting refresh changes both switches independently without reinstalling hooks", function()
    local state = event_fixture()
    local hook = state.wwise_hook
    for _, switches in ipairs(wwise_switches) do
        set_wwise_switches(state, switches.hit, switches.kill)
        equal(state.wwise_hook, hook)
        equal(wwise_is_silenced(state, "melee_hits_blunt_heavy"), not switches.hit)
        equal(wwise_is_silenced(state, "play_psyker_chain_lightning_hit"), not switches.hit)
        equal(wwise_is_silenced(state, "play_minion_killed"), not switches.kill)
    end
end)

test("Wwise forwards opaque Unit/Vector3/source/extra arguments, nils and all return values", function()
    -- Stand-ins preserve object identity; pure Lua does not construct Stingray userdata.
    local unit, vector, extra, world, resource = {}, {}, {}, {}, {}
    local arguments = {
        table.pack(), table.pack(unit), table.pack(vector), table.pack(12345), table.pack(nil),
        table.pack(unit, nil, vector, 12345, false, extra, "tail", io.stdout, nil),
        table.pack(nil, unit, nil, vector, 12345, extra, nil),
    }
    local expected_return = table.pack(resource, nil, false, 19, "last", nil)
    local state = event_fixture()
    for _, switches in ipairs(wwise_switches) do
        set_wwise_switches(state, switches.hit, switches.kill)
        for _, case in ipairs({
            {event = "melee_hits_blunt_heavy", silenced = not switches.hit},
            {event = "play_minion_killed", silenced = not switches.kill},
            {event = "play_bolter_reload_hit", silenced = false},
        }) do
            for _, event in ipairs({case.event, "wwise/events/weapon/" .. case.event}) do
                for _, args in ipairs(arguments) do
                    local calls = 0
                    local actual_return = table.pack(state.wwise_hook(function(got_world, got_event, ...)
                        calls = calls + 1
                        assert(got_world == world)
                        equal(got_event, event)
                        local actual_args = table.pack(...)
                        equal(actual_args.n, args.n)
                        for index = 1, args.n do assert(actual_args[index] == args[index]) end
                        return table.unpack(expected_return, 1, expected_return.n)
                    end, world, event, table.unpack(args, 1, args.n)))
                    if case.silenced then
                        equal(calls, 0)
                        equal(actual_return.n, 0)
                    else
                        equal(calls, 1)
                        equal(actual_return.n, expected_return.n)
                        for index = 1, expected_return.n do
                            assert(actual_return[index] == expected_return[index])
                        end
                    end
                end
            end
        end
    end
end)

test("Wwise preserves zero original return values and propagates original errors", function()
    local state = event_fixture()
    set_wwise_switches(state, false, false)
    local result = table.pack(state.wwise_hook(function() end, {}, "play_bolter_reload_hit"))
    equal(result.n, 0)
    local reason = {}
    local ok, actual = pcall(state.wwise_hook, function() error(reason) end, {}, "play_bolter_reload_hit")
    equal(ok, false)
    assert(actual == reason)
    equal(wwise_is_silenced(state, "melee_hits_blunt_heavy"), true)
end)

test("queue admission commits shared hit cooldown; synchronous refusal does not", function()
    local state = event_fixture()
    for _ = 1, 10 do assert(state.enqueue("hit_normal", 4)) end
    state.attack(false, false)
    equal(#state.backend.get_pending_queue(), 10) -- refused, must not commit
    state.backend.stop_all()
    state.attack(false, false) -- same clock; succeeds if earlier refusal did not consume cooldown
    equal(#state.backend.get_pending_queue(), 1)
    state.attack(true, true) -- headshot and melee share that same cooldown
    equal(#state.backend.get_pending_queue(), 1)
    state.step(0.081)
    state.attack(true, true)
    equal(#state.backend.get_pending_queue(), 1)
    state.attack(false, false)
    equal(#state.backend.get_pending_queue(), 1)
end)
test("invalid source and empty custom path do not consume hit cooldown", function()
    local state = event_fixture()
    state.settings.hit_game_normal = "INVALID"
    state.attack()
    equal(#state.backend.get_pending_queue(), 0)
    state.settings.hit_game_normal = "CUSTOM"
    state.hks.HitKillSoundsCustomAudio = {sample = function() return nil end}
    state.attack()
    equal(#state.backend.get_pending_queue(), 0)
    state.settings.hit_game_normal = "BF1"
    state.attack()
    equal(#state.backend.get_pending_queue(), 1)
end)
test("async failed playback/unready/capacity/expiry do not roll back committed hit cooldown", function()
    for _, mode in ipairs({"playback", "capacity", "expiry"}) do
        local state = event_fixture({play_fail = mode == "playback"})
        if mode == "capacity" then
            for _ = 1, 5 do assert(state.enqueue("hit_normal", 4)); state.step(0.04) end
        end
        state.attack()
        local committed = state.hit_timestamp()
        equal(committed, state.now)
        if mode == "expiry" then
            state.step(0.121) -- old request expired; a subsequent admission is now eligible
            equal(state.backend.get_statistics().dropped_expired, 1)
        else
            state.step(0.04)
            local stats = state.backend.get_statistics()
            equal(mode == "capacity" and stats.dropped_capacity or stats.playback_failed, 1)
            state.attack()
            equal(#state.backend.get_pending_queue(), 0)
        end
        equal(state.hit_timestamp(), committed)
    end
end)
test("Custom source mapping for all six selectors, normal-headshot semantics and no BFV tail", function()
    for _, case in ipairs({
        {"hit_game_normal", false, false, false, "hit", false},
        {"hit_headshot_game", true, false, false, "hit", true},
        {"hit_melee_normal", false, true, false, "hit", false},
        {"hit_melee_headshot", true, true, false, "hit", true},
        {"kill_game_normal", false, false, true, "kill", false},
        {"kill_headshot_game", true, false, true, "kill", true},
    }) do
        local state = event_fixture()
        state.settings[case[1]] = "CUSTOM"
        local samples = 0
        state.hks.HitKillSoundsCustomAudio = {sample = function(kind, headshot)
            samples = samples + 1
            equal(kind, case[5]); equal(headshot, case[6])
            return playback_root .. "test.wav"
        end}
        state.attack(case[2], case[3], case[4])
        equal(samples, 1)
        equal(#state.backend.get_pending_queue(), 1)
        equal(state.backend.get_pending_queue()[1].path, playback_root .. "test.wav")
    end
    local state = event_fixture()
    state.settings.kill_headshot_game, state.settings.kill_headshot_use_normal = "CUSTOM", true
    state.hks.HitKillSoundsCustomAudio = {sample = function(_, headshot)
        equal(headshot, false)
        return playback_root .. "kill_normal.wav"
    end}
    state.attack(true, false, true)
    equal(#state.backend.get_pending_queue(), 1)
    equal(state.backend.get_pending_queue()[1].track_id, 3)
end)
test("non-Custom and old hit_game/kill_game settings never sample Custom; BFV tail remains BFV-only", function()
    local state = event_fixture()
    state.hks.HitKillSoundsCustomAudio = {sample = function() error("unexpected Custom sampling") end}
    state.settings.hit_game, state.settings.kill_game = "BF1", "BF1"
    state.attack()
    assert(state.backend.get_pending_queue()[1].path:find("HitSounds/BF1/", 1, true))
    state.attack(true, false, true)
    equal(#state.backend.get_pending_queue(), 2)
    state.backend.stop_all()
    state.settings.kill_headshot_game = "BFV"
    state.attack(true, false, true)
    equal(#state.backend.get_pending_queue(), 2)
    equal(state.backend.get_pending_queue()[2].replace_group, "bfv_headshot_add")
end)
test("damage, blocked hits, melee and target filters still precede hit admission", function()
    local state = event_fixture()
    state.attack(false, false, false, 0)
    state.attack(false, false, false, 1, "blocked")
    state.settings.hit_melee = false
    state.attack(false, true)
    state.settings.hit_target = "elite"
    state.attack()
    equal(#state.backend.get_pending_queue(), 0)
end)

test("female CF streak plays sounds 1–8, then the first-kill copy from kill 9 onward", function()
    local state = event_fixture()
    state.settings.killstreak_enabled = true
    state.settings.cf_kill_sound_enabled = true
    state.settings.cf_kill_voice = "female"

    local paths = {"kill.wav", "kill2.wav", "kill3.wav", "kill4.wav", "kill5.wav", "kill6.wav",
        "kill7.wav", "kill8.wav", "kill9.wav", "kill9.wav", "kill9.wav"}
    for index, filename in ipairs(paths) do
        state.attack(index == #paths, false, true)
        local pending = state.backend.get_pending_queue()
        equal(#pending, 1)
        equal(pending[1].path, "mods/Hit_Kill_Sounds/audio/KillSounds/cf/female/" .. filename)
        state.backend.stop_all()
    end
end)

test("six dropdowns gain CUSTOM without changing BF1 defaults; bilingual keys exist", function()
    local localization = load_module("Hit_Kill_Sounds_localization", {})
    local hks = {localize = function(_, key) return localization[key] and localization[key].en or key end}
    local data = load_module("Hit_Kill_Sounds_data", environment(hks))
    local found = {}
    local function visit(widgets)
        for _, widget in ipairs(widgets or {}) do
            if widget.options then
                for _, option in ipairs(widget.options) do
                    if option.value == "CUSTOM" then
                        equal(widget.default_value, "BF1")
                        equal(option.text, "Custom Audio Pack")
                        found[widget.setting_id] = true
                    end
                end
            end
            visit(widget.sub_widgets)
        end
    end
    visit(data.options.widgets)
    local count = 0
    for _ in pairs(found) do count = count + 1 end
    equal(count, 6)
    for _, key in ipairs({"hit_game_normal", "hit_headshot_game", "hit_melee_normal", "hit_melee_headshot",
        "kill_game_normal", "kill_headshot_game"}) do assert(found[key]) end
    equal(localization.CUSTOM["zh-cn"], "自定义音频包")
    assert(localization.mod_description.en:find("v1.5.5", 1, true))
    assert(localization.mod_description["zh-cn"]:find("v1.5.5", 1, true))
end)
test("actual default manifests and audio headers populate cached pools", function()
    local reads = 0
    local hks = {warning = function() error("default assets should not warn") end}
    local env = environment(hks, {Mods = {lua = {io = {open = function(path, mode)
        assert(path:sub(1, #filesystem_root) == filesystem_root)
        reads = reads + 1
        return io.open("UserAudio/" .. path:sub(#filesystem_root + 1), mode)
    end}}}})
    local helper = load_module("Hit_Kill_Sounds_custom_audio", env)
    helper.init()
    equal(helper.sample("hit", false), playback_root .. "Hit/Normal.wav")
    equal(helper.sample("hit", true), playback_root .. "Hit/Headshot.wav")
    equal(helper.sample("kill", false), playback_root .. "Kill/Normal.wav")
    equal(helper.sample("kill", true), playback_root .. "Kill/Headshot.wav")
    equal(helper.get_bgm_paths()[1], nil)
    equal(reads, 7)
    helper.init()
    equal(reads, 7)
end)
test("main entry loads Custom before consumers and initializes it before event hooks and BGM", function()
    local order = {}
    local function record(name) order[#order + 1] = name end
    local hks = {
        io_dofile = function(self, path)
            local name = path:match("([^/]+)$")
            record("load:" .. name)
            if name == "Hit_Kill_Sounds_custom_audio" then
                self.HitKillSoundsCustomAudio = {
                    init = function() record("custom_init") end, clear = function() record("custom_clear") end,
                }
            elseif name == "Hit_Kill_Sounds_events" then
                self.HitKillSoundsEvents = {init_damage_hooks = function() record("events_init") end}
            elseif name == "Hit_Kill_Sounds_bgm" then
                self.HitKillSoundsBGM = {
                    init = function() record("bgm_init") end,
                    stop = function() record("bgm_stop") end,
                    shutdown = function() record("bgm_shutdown") end,
                }
            end
        end,
        hook = function() end, add_require_path = function() end,
    }
    load_module("Hit_Kill_Sounds", environment(hks))
    hks.on_all_mods_loaded()
    local positions = {}
    for i, value in ipairs(order) do positions[value] = i end
    assert(positions["load:Hit_Kill_Sounds_custom_audio"] < positions["load:Hit_Kill_Sounds_events"])
    assert(positions["load:Hit_Kill_Sounds_custom_audio"] < positions["load:Hit_Kill_Sounds_bgm"])
    assert(positions.custom_init < positions.events_init)
    assert(positions.custom_init < positions.bgm_init)
    hks.on_disabled()
    equal(order[#order], "bgm_stop")
    hks.on_unload()
    equal(order[#order - 1], "bgm_shutdown")
    equal(order[#order], "custom_clear")
end)

test("limit warning is once per category; missing IO and corrupt reads fail open", function()
    local files = {
        [filesystem_root .. "Kill/playlist.txt"] = "",
        [filesystem_root .. "BGM/tracks.txt"] = "",
    }
    local lines = {}
    for i = 1, 25 do
        lines[i] = "normal|Hit/" .. i .. ".wav"
        files[filesystem_root .. "Hit/" .. i .. ".wav"] = wav
    end
    files[filesystem_root .. "Hit/playlist.txt"] = table.concat(lines, "\n")
    local helper, warnings = custom_fixture(files)
    helper.init()
    equal(#warnings, 1)
    assert(warnings[1]:find("limit is 20", 1, true))
    local hks = {warning = function() end}
    for _, lua_io in ipairs({{}, {open = function() error("IO unavailable") end}, {
        open = function() return {read = function() error("read error") end, close = function() return true end} end,
    }}) do
        local empty = load_module("Hit_Kill_Sounds_custom_audio", environment(hks, {Mods = {lua = {io = lua_io}}}))
        empty.init()
        equal(empty.sample("hit", true, {normal = {"BFV.wav"}}), "BFV.wav")
        equal(#empty.get_bgm_paths(), 0)
    end
end)

test("native restoration follows official mission state rather than a stale hub state", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.mode = "mission"
    state.env.Managers.state.mission = {mission = function() return {wwise_state = "test_mission_music"} end}
    state.bgm.update(0.1)
    equal(state.native, "test_mission_music")
end)
test(".mod descriptor keeps existing startup/data/localization resource paths valid", function()
    local resources
    local env = {fassert = assert, new_mod = function(name, value)
        equal(name, "Hit_Kill_Sounds")
        resources = value
    end}
    env._G = env
    setmetatable(env, {__index = _G})
    local descriptor = assert(loadfile("Hit_Kill_Sounds.mod", "t", env))()
    descriptor.run()
    equal(#descriptor.packages, 0)
    for _, key in ipairs({"mod_script", "mod_data", "mod_localization"}) do
        local relative = resources[key]:gsub("^Hit_Kill_Sounds/", "") .. ".lua"
        local handle = assert(io.open(relative, "rb"))
        assert(handle:close())
    end
end)

test("legacy player translates only the validated Custom prefix, keeping original builtin paths", function()
    local requests, commands = {}, {}
    local hks = {}
    local env = environment(hks, {
        Mods = {lua = {io = {
            popen = function(command)
                commands[#commands + 1] = command -- fake only: never executes a process
                return {read = function() return "X:\\Game\\binaries\r\n" end, close = function() return true end}
            end,
            open = function()
                return {read = function() return '{"port":42213}' end, close = function() return true end}
            end,
        }}},
        cjson = {decode = function() return {port = 42213} end},
        Managers = {backend = {url_request = function(_, _, request) requests[#requests + 1] = request end}},
    })
    load_module("Hit_Kill_Sounds_player", env)
    local player = hks.HitKillSoundsPlayer
    assert(player.play_file("HitSounds/BF1/test.wav", 1, 50))
    equal(requests[1].body.file_path, "X:/Game/mods/Hit_Kill_Sounds/audio/HitSounds/BF1/test.wav")
    equal(requests[1].body.left_volume, 0.5)
    assert(player.play_file(playback_root .. "Hit/Normal.wav", 1, 100))
    equal(requests[2].body.file_path, "X:/Game/mods/Hit_Kill_Sounds/UserAudio/Hit/Normal.wav")
    equal(#commands, 2) -- fake cwd discovery + lazy player startup, never a real process
end)
test("native mute exception after side effects stops custom playback and restores official music", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    local original = state.env.Wwise.set_state
    state.env.Wwise.set_state = function(group, value)
        original(group, value)
        if value == "None" then error("native failure after muting") end
    end
    state.bgm.update(0.1)
    equal(state.native, "hub")
    equal(#state.stopped, 1)
end)
-- v1.5.3: native music recovery is independent of playback initialization.
test("BGM stop restores hub, clears recovery state, and subsequent stops do not write", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.settings.lobby_bgm_enabled = false
    equal(state.bgm.stop(true), true)
    equal(state.native, "hub")
    equal(state.restore_storage.pending_restore, nil)
    local writes = #state.native_calls
    state.bgm.stop(true)
    state.bgm.shutdown()
    state.bgm.update(1)
    equal(#state.native_calls, writes)
    equal(#state.calls, 1)
end)

test("BGM first direct restore failure stays pending despite a matching manager cache", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.settings.lobby_bgm_enabled = false
    equal(state.manager._wwise_state_group_states.music_zone, "hub")
    local original, attempts = state.env.Wwise.set_state, 0
    state.env.Wwise.set_state = function(group, value)
        if value == "hub" then
            attempts = attempts + 1
            if attempts == 1 then error("first direct restore fails") end
        end
        return original(group, value)
    end
    equal(state.bgm.stop(true), false)
    equal(attempts, 1)
    equal(state.native, "None")
    equal(state.restore_storage.pending_restore.zone_state, "hub")
    equal(state.restore_storage.pending_restore.saved_native_music_state, "hub")
    equal(state.restore_storage.pending_restore.created_by, "Hit_Kill_Sounds")
    equal(state.music_event_hook(), nil)
    state.bgm.update(0.1)
    equal(attempts, 2)
    equal(state.native, "hub")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1)
end)

test("BGM shutdown retains failed recovery and update retries while uninitialized", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    local original, unavailable, attempts = state.env.Wwise.set_state, true, 0
    state.env.Wwise.set_state = function(group, value)
        if value == "hub" then
            attempts = attempts + 1
            if unavailable then error("teardown Wwise unavailable") end
        end
        return original(group, value)
    end
    state.bgm.shutdown()
    equal(state.native, "None")
    equal(state.restore_storage.pending_restore.pending, true)
    local previous_attempts = attempts
    state.bgm.update(0.2)
    assert(attempts > previous_attempts)
    equal(state.native, "None")
    unavailable = false
    state.bgm.update(0.2)
    equal(state.native, "hub")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1) -- Playback remains shut down after recovery succeeds.
    local writes = #state.native_calls
    state.bgm.update(1)
    state.bgm.stop(true)
    equal(#state.native_calls, writes)
end)

test("BGM new Mod object recovers pending state during init before normal playback", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    local original = state.env.Wwise.set_state
    state.env.Wwise.set_state = function() error("reload teardown unavailable") end
    local old_hks, old_callback = state.hks, state.calls[1].config.on_finished
    state.bgm.shutdown()
    assert(state.restore_storage.pending_restore)
    state.env.Wwise.set_state = original
    state.reload()
    assert(state.hks ~= old_hks)
    equal(state.native, "hub")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1)
    old_callback(1)
    equal(#state.calls, 1)
    state.bgm.update(0.1)
    equal(#state.calls, 2)
    equal(state.calls[2].native_before, "hub")
    state.bgm.stop(true)
end)

test("BGM reload recovery failure keeps hooks open and custom playback suspended", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    local original, unavailable = state.env.Wwise.set_state, true
    local old_event_hook, old_callback = state.music_event_hook, state.calls[1].config.on_finished
    state.env.Wwise.set_state = function(group, value)
        if value == "hub" and unavailable then error("native restore unavailable") end
        return original(group, value)
    end
    state.bgm.shutdown()
    state.reload()
    state.bgm.update(0.1)
    equal(#state.calls, 1)
    assert(state.restore_storage.pending_restore)
    equal(old_event_hook(), nil)
    equal(state.music_event_hook(), nil)
    -- A fresh official state must pass through the manager hook while pending.
    state.manager:_set_state("music_zone", "zone_2")
    equal(state.native, "zone_2")
    old_callback(1)
    equal(#state.calls, 1)
    state.settings.lobby_bgm_enabled = false
    unavailable = false
    state.bgm.update(0.1)
    equal(state.native, "zone_2")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1)
end)

test("BGM pending init recovery works without SimpleAudio or a hookable manager class", function()
    local persistent = {Hit_Kill_Sounds_native_music_restore_v1 = {pending_restore = {
        pending = true, zone_state = "hub", saved_native_music_state = "hub", created_by = "Hit_Kill_Sounds",
    }}}
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"}, {
        persistent = persistent, no_audio = true, no_native = true,
    })
    equal(#state.native_calls, 1)
    equal(state.native_calls[1].value, "hub")
    equal(state.restore_storage.pending_restore, nil)
    state.bgm.update(0.1)
    equal(#state.calls, 0)
end)

test("BGM explicit false from direct Wwise restore remains pending", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.settings.lobby_bgm_enabled = false
    local original = state.env.Wwise.set_state
    state.env.Wwise.set_state = function() return false end
    equal(state.bgm.stop(true), false)
    state.bgm.update(0.1)
    equal(state.native, "None")
    assert(state.restore_storage.pending_restore)
    equal(#state.calls, 1)
    state.env.Wwise.set_state = original
    state.bgm.update(0.1)
    equal(state.native, "hub")
    equal(state.restore_storage.pending_restore, nil)
end)

test("BGM direct success restores native music even after manager cache update throws", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.manager._wwise_state_group_states.music_zone = "None"
    local original, attempts = state.env.Wwise.set_state, 0
    state.env.Wwise.set_state = function(group, value)
        attempts = attempts + 1
        if attempts == 1 then error("cache changed before native exception") end
        return original(group, value)
    end
    equal(state.bgm.stop(true), true)
    equal(attempts, 2)
    equal(state.native, "hub")
    equal(state.manager._wwise_state_group_states.music_zone, "hub")
    equal(state.restore_storage.pending_restore, nil)
end)

test("BGM recovery chooses fresh mission state and retains it through manager teardown", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    local original = state.env.Wwise.set_state
    state.env.Wwise.set_state = function() error("transition recovery unavailable") end
    equal(state.bgm.stop(true), false)
    equal(state.restore_storage.pending_restore.zone_state, "hub")
    state.mode = "mission"
    state.env.Managers.state.mission = {mission = function() return {wwise_state = "zone_3"} end}
    state.bgm.update(0.1)
    equal(state.restore_storage.pending_restore.zone_state, "zone_3")
    equal(state.restore_storage.pending_restore.saved_native_music_state, "hub")
    state.env.Managers.state = nil
    state.manager._wwise_state_groups = {}
    state.manager._wwise_state_group_states.music_zone = "None"
    state.env.Wwise.set_state = original
    state.bgm.update(0.1)
    equal(state.native, "zone_3")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1)
end)

test("BGM saves a fresh pre-mute state after recovery and never reuses cleared targets", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    local official_zone = "zone_1"
    state.manager._wwise_state_groups.music_zone.wwise_state = function() return official_zone end
    state.bgm.update(0.1)
    official_zone = "None"
    state.manager._wwise_state_group_states.music_zone = "None"
    equal(state.bgm.stop(true), true)
    equal(state.native, "zone_1")
    equal(state.restore_storage.pending_restore, nil)
    official_zone = "zone_2"
    state.bgm.update(0.1)
    official_zone = "None"
    state.manager._wwise_state_group_states.music_zone = "None"
    equal(state.bgm.stop(true), true)
    equal(state.native, "zone_2")
    equal(state.restore_storage.pending_restore, nil)
end)

test("BGM never writes music_zone when HKS has not suppressed music", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.stop(true)
    state.settings.lobby_bgm_enabled = false
    state.bgm.on_setting_changed("lobby_bgm_enabled")
    state.bgm.shutdown()
    state.bgm.update(1)
    equal(#state.native_calls, 0)
    equal(#state.stopped, 0)
    equal(state.restore_storage.pending_restore, nil)
end)

test("BGM generation rejects stale callbacks after every stop path even when play IDs are reused", function()
    local actions = {
        function(s) s.bgm.stop(true) end,
        function(s) s.bgm.shutdown() end,
        function(s) s.settings.lobby_bgm_enabled = false; s.bgm.on_setting_changed("lobby_bgm_enabled") end,
        function(s) s.settings.enabled = false; s.bgm.on_setting_changed("enabled") end,
        function(s) s.enabled = false; s.bgm.update(0.1) end,
        function(s) s.mode = "mission"; s.bgm.update(0.1) end,
        function(s) s.mode = nil; s.bgm.update(0.1) end,
        function(s) s.bgm.shutdown(); s.reload() end,
    }
    for _, action in ipairs(actions) do
        local state = bgm_fixture({playback_root .. "BGM/a.mp3", playback_root .. "BGM/b.mp3"}, {
            reuse_play_id = true, finish_on_stop = true,
        })
        state.bgm.update(0.1)
        local old_callback = state.calls[1].config.on_finished
        action(state)
        equal(#state.calls, 1)
        state.settings.enabled, state.settings.lobby_bgm_enabled = true, true
        state.enabled, state.mode = true, "hub"
        state.bgm.init()
        state.bgm.update(0.1)
        equal(#state.calls, 2)
        old_callback(1)
        equal(#state.calls, 2)
        state.bgm.stop(true)
    end
end)

test("BGM confirmed mission target survives stale hub state and Mod reconstruction", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.mode = "mission"
    state.env.Managers.state.mission = {mission = function() return {wwise_state = "zone_3"} end}
    local original = state.env.Wwise.set_state
    state.env.Wwise.set_state = function() error("native recovery temporarily unavailable") end
    equal(state.bgm.stop(true), false)
    equal(state.restore_storage.pending_restore.zone_state, "zone_3")
    -- Gameplay manager teardown can precede the zone group's next update.
    state.env.Managers.state.mission = nil
    state.manager._wwise_state_groups.music_zone.wwise_state = function() return "hub" end
    state.manager._wwise_state_group_states.music_zone = "hub"
    state.bgm.update(0.1)
    equal(state.restore_storage.pending_restore.zone_state, "zone_3")
    state.bgm.shutdown()
    state.reload()
    equal(state.restore_storage.pending_restore.zone_state, "zone_3")
    state.env.Wwise.set_state = original
    state.bgm.update(0.1)
    equal(state.native, "zone_3")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1)
end)

test("BGM a fresh official hub mission replaces an older confirmed mission target", function()
    local state = bgm_fixture({playback_root .. "BGM/a.mp3"})
    state.bgm.update(0.1)
    state.mode = "mission"
    local mission_zone = "zone_3"
    state.env.Managers.state.mission = {mission = function() return {wwise_state = mission_zone} end}
    local original = state.env.Wwise.set_state
    state.env.Wwise.set_state = function() error("waiting for native music") end
    equal(state.bgm.stop(true), false)
    equal(state.restore_storage.pending_restore.zone_state, "zone_3")
    state.mode, mission_zone = "hub", "hub"
    state.manager._wwise_state_groups.music_zone.wwise_state = function() return "zone_3" end
    state.bgm.update(0.1)
    equal(state.restore_storage.pending_restore.zone_state, "hub")
    state.settings.lobby_bgm_enabled = false
    state.env.Wwise.set_state = original
    state.bgm.update(0.1)
    equal(state.native, "hub")
    equal(state.restore_storage.pending_restore, nil)
    equal(#state.calls, 1)
end)

print("Local Lua tests passed: " .. total)
