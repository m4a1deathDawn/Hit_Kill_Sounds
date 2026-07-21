# Hit/Kill Sounds

A Darktide mod that plays hit and kill sounds from various games when you damage or kill enemies, and displays dynamic kill icons.

Current version: v1.4.2

## Features

- **Hit Sounds**: Play different sounds when hitting enemies (normal hit vs weakspot hit)
- **Kill Sounds**: Play different sounds when killing enemies (normal kill vs headshot kill)
- **Dynamic Kill Icons**: Queue-based kill icon system supporting consecutive kill accumulation
- **Random Selection**: Multiple sound variants for each type, randomly selected
- **Sound Cooldown**: Prevents sound spam from fast-firing weapons
- **Deduplication**: Prevents duplicate sounds in multiplayer mode
- **DoT Support**: Optional hit sounds for damage-over-time effects (bleed, burn, etc.)
- **Target Filtering**: Filter sounds to only play for specific enemy types (Elite, Special, Boss)
- **Volume Control**: Adjust volume independently for hit and kill sounds (0-100)
- **Icon Customization**: Adjust icon size, color, horizontal/vertical position, and display duration
- **Multiplayer Support**: Works correctly in both single-player and multiplayer modes
- **CF-style streak output** (v1.1): CrossFire-themed streak sound + icon system, plays sounds in indexed order based on streak count, switchable style
- **Style Switch** (v1.1): Toggle between "Battlefield 5 queue-based icon" and "CrossFire killstreak-style icon"
- **Decoupled CF Sound & Icon** (v1.1): CrossFire killstreak sound is independently toggleable from icon style, supporting 4 combinations (CF sound + BF5 icon, BF5 sound + CF icon, CF+CF, BF5+BF5)
- **SimpleAudio + SimpleAssets backend** (v1.2): Audio now plays through SimpleAudio by default, and icon textures load through SimpleAssets by default, with no external player executable required
- **CODBO7 kill sounds** (v1.3): Normal kills randomly use three variants and headshot kills use a dedicated file; CODBO7 is available only in kill-source dropdowns
- **Custom Mourningstar BGM** (v1.3): Optionally play six local MP3 tracks in the normal `hub` and adjust their volume independently
- **Generic killstreak mechanism and burst-playback protection** (v1.35): BF4 text, CF sound, and CF icon each maintain an independent streak counter, while SimpleAudio uses a bounded queue, frame-spread dispatch, and a multi-voice pool
- **Battlefield 4-style text kill feed and independent score tally** (v1.4): Fixed-slot HUD text and cumulative score output, independent of BF5/CF sound and icon switches
- **Independent output counters** (v1.4.2): BF4, CF sound, and CF icon use separate counters, so different filters may produce different streak numbers

## Kill Icons

Major rewrite in v0.9!

- **Queue System**: Up to 10 kill icons displayed simultaneously, new kills push old icons left
- **Entry Animation**: Icons slide in from right side to center (ease-out, 0.3s)
- **Normal Kill**: Entry scale 1.8→1.0 (ease-out), display then fade out
- **Headshot Kill**: Same as normal + circle shockwave effect (scale 1→3, alpha fade)
- **Exit Animation**: Slide left and fade out (ease-out, 0.2s)
- **Adjustable Parameters**:
  - Icon toggle
  - Icon size (0.5x - 2.0x)
  - Icon transparency (0% - 100%)
  - Normal icon color (RGB)
  - Headshot icon color (RGB)
  - Horizontal position (0=left, 50=center, 100=right)
  - Vertical position (0=top, 100=bottom)
  - Display duration (1.0s - 3.0s)

Icon assets: Battlefield V kill icons

## CF (CrossFire) Killstreak System

New in v1.1! A CrossFire-themed killstreak system ported from the EBuyToDeep_KillFeedBack mod, complementing the default "Battlefield 5 queue-based icon" system.

- **Indexed killstreak sounds**: Plays `killsound_cf_01..09.wav` in order (1→2→…→9→wraps), unlike the random-play behavior of normal kill sounds
- **Indexed killstreak icons**: Cycles through `kill1..6.png` + a dedicated gold `headshot_gold.png` for first-kill headshots
- **Dedicated boss sound**: Killing monster-tagged enemies plays `killsound_cf_boss.wav`
- **Style switch**: Select "CrossFire Style" in the Style dropdown at the top of Kill Icon Settings
- **Adjustable parameters**:
  - Killstreak max count (10-30, default 13; each counter wraps independently)
  - BF4 text target (`bf4_feed_target`), CF sound target (`kill_target`), and CF icon target (`kill_icon_target`)
  - Icon transparency, size, vertical/horizontal position
  - Counter reset time (1.0s-3.0s, default 2.0s; controls both the killstreak reset window and the icon display duration)
- **Decoupled sound & icon**: The "Enable CF Kill Sound" toggle in Kill Sound Settings is independent of icon style — supports 4 combinations: CF sound + BF5 icon, BF5 sound + CF icon, CF+CF, BF5+BF5
- **Independent target semantics**: `bf4_feed_target` controls only BF4 text events, `kill_target` controls only CF/BF5 kill sounds, and `kill_icon_target` controls only CF/BF5 kill icons; `killstreak_target` has been removed and old saved values are ignored

Icon assets: CrossFire killstreak icons

## Battlefield 4-style Text Kill Feed (v1.4)

Enable `bf4_feed_enabled` in the **Battlefield 4-style Text Kill Feed** settings group to display a borderless, background-free HUD text feed. It is disabled by default and requires `killstreak_enabled` to be enabled in General Settings.

- Normal kill 100, headshot bonus 50, elite kill 200, special kill 250, Boss kill 500
- A headshot special kill displays both `HEADSHOT BONUS` and `SPECIAL KILLED`, while adding 300 to the tally once
- The newest event is at the bottom; event text is right-aligned, scores are left-aligned, and the cumulative tally stays above/right of the feed with a short punch animation
- Supports target filtering, 1.0-3.0 second display duration, horizontal/vertical position, and 50%-150% text scale
- The feature does not depend on CF/BF5 sound or icon switches and does not trigger the official Combat Feed event. The native game feed may show duplicate information if it is enabled at the same time
- Disabling the feed or the killstreak mechanism immediately clears the text slots and tally without changing saved settings

## Supported Sound Sources

| Game | Normal Hit | Headshot Hit | Normal Kill | Headshot Kill |
|------|------------|--------------|-------------|---------------|
| Battlefield 1 | 5 variants | 5 variants | 1 | 1 |
| Battlefield 2042 | 24 variants | 13 variants | 6 variants | 13 variants |
| Battlefield 6 | 28 variants | 8 variants | 6 variants | 8 variants |
| Battlefield V | 12 variants | 5 variants | 1 | 10 variants |
| Call of Duty: Black Ops 6 | 2 variants | 1 | 1 | 3 variants |
| Call of Duty: Black Ops Cold War | 4 variants | 4 variants | 2 | 3 variants |
| Call of Duty: Vanguard | 13 variants | 4 variants | 3 | 2 variants |
| Call of Duty: MW 2019 | 1 | 1 | 1 | 1 |
| Call of Duty: MW 3 | 1 | 1 | 1 | 1 |
| The Finals | 3 variants | 5 variants | 1 | 1 |
| Overwatch | 1 | 1 | 2 variants | 1 |
| Call of Duty: Black Ops 7 | — | — | 3 variants | 1 |
| Call of Duty: Warzone | 2 variants | → normal | 1 | → normal |
| Call of Duty: Warzone 2 | 1 | → normal | 2 variants | → normal |
| Delta Force | 1 | → normal | 1 | 1 |
| Apex Legends | 8 variants | → normal | 1 | → normal |

*`→ normal` indicates the game source has no dedicated headshot files; the mod falls back to that source's normal pool so every headshot still produces feedback.*

## How It Works

This mod hooks `AttackReportManager:add_attack_result` to capture attack events:

- Intercept player damage/kill events
- Determine if it's a hit (normal/weakspot) or kill (normal/headshot)
- Apply target filtering based on enemy type
- Play the appropriate local sound through SimpleAudio
- Call HUD system to display kill icons
- Submit a separate BF4 text-feed batch for each valid kill and update an independent score tally without triggering the official Combat Feed event

Starting with v1.2, audio playback uses SimpleAudio by default, and icon textures use SimpleAssets by default. The old HTTP player adapter is still kept as a compatibility fallback, but Nexus Mods release packages can omit the `bin` folder.

The kill icon system preloads textures through SimpleAssets and manages a queue of 10 slots. New kills trigger entry animations that push old icons left.

## Custom Mourningstar BGM (v1.3)

Enable `lobby_bgm_enabled` in the **Custom Mourningstar BGM** settings group to play
`audio/BGM/Lobby_BGM1.mp3` through `Lobby_BGM6.mp3`, but only when
`Managers.state.game_mode:game_mode_name() == "hub"`. A track is selected randomly on hub entry, and the next track is selected from the other files when playback finishes.

- Disabled by default; it does not run in missions, the main menu, training grounds, the shooting range, or `prologue_hub`
- `lobby_bgm_volume` ranges from 0 to 100 in steps of 5; changing it during playback updates the active playback instance without restarting the track
- Requires **SimpleAudio** `play_file` and uses `audio_type = "music"`, so master and music volume settings still apply
- The mod only attempts to take over native hub music after a dedicated `play_id` is returned; missing SimpleAudio, missing files, or playback failure leave native music unchanged

## Installation

1. Install and enable the required mods: SimpleAudio and SimpleAssets
2. Download this mod and place `Hit_Kill_Sounds` next to `SimpleAudio` and `SimpleAssets` in your Darktide `mods` folder
3. Enable this mod in the game's mod menu
4. Configure sound sources, volumes, and kill icon options; enable **Custom Mourningstar BGM** if you want the optional hub music

## Requirements

- Darktide with mod support enabled
- SimpleAudio
- SimpleAssets

## Sound & Asset Sources

All hit and kill sounds are from their respective games and are used for modding/educational purposes:

- Battlefield series sounds and icons from EA/DICE games
- Call of Duty series sounds from Activision
- The Finals sounds from Embark Studios
- Overwatch sounds from Blizzard Entertainment
- Kill icon assets from EA/DICE Battlefield V

## Acknowledgments

- **BiliBili UP EBuyToDeep** ([https://space.bilibili.com/1273948298](https://space.bilibili.com/1273948298)): For providing the external audio player solution that made this mod possible. The HitKillSoundsPlayer application is based on the concept from their EBuyToDeep_KillFeedBack mod.
- **deluxghost** ([https://space.bilibili.com/4712698](https://space.bilibili.com/4712698)): For providing the SimpleAudio + SimpleAssets solution, allowing v1.2 to remove the external player requirement and use a cleaner local audio/texture loading path.

## Backend Notes

Starting with v1.2, the mod uses SimpleAudio to play local files under `audio/HitSounds`, `audio/KillSounds`, and the v1.3 `audio/BGM` folder, and SimpleAssets to load kill icon textures. Custom hub BGM does not use the legacy HTTP player and requires SimpleAudio. The old HitKillSoundsPlayer / HTTP player logic remains as a compatibility fallback for hit/kill sounds, but Nexus Mods release packages can omit the `bin` folder.

## License

This mod is provided for educational and personal use only. All sound files and icon assets remain the property of their respective copyright holders.

## Changelog

### v1.4.2
- **Three independent killstreak counters**: BF4 text, CF sound, and CF icon each maintain their own kill count and last-kill time, using `bf4_feed_target`, `kill_target`, and `kill_icon_target` respectively
- **Independent sequence numbers**: When filters differ, BF4, CF sound, and CF icon may show/play different streak numbers; they naturally synchronize only when their targets match
- **Removed `killstreak_target`**: It is no longer present in the settings UI or read at runtime; old saved values are ignored and are not synchronized to the other targets
- **Verification status**: Code and static checks are complete; in-game verification remains pending

### v1.4.1
- **Historical note**: This version attempted to use `killstreak_target` for a shared CF sound/icon counter. In-game verification did not meet the intended behavior; v1.4.2 removes that shared-counter design and runtime setting

### v1.4
- **Added Battlefield 4-style text kill feed**: Added an independent settings group with target filtering, 1.0-3.0 second duration, position, and scale controls; disabled by default
- **Added independent score tally**: Normal kills score 100, headshot bonus 50, elites 200, specials 250, and Bosses 500. Multiple lines from one kill are submitted as one batch and update the tally once
- **Fixed-slot HUD and animation**: Up to 8 fixed text slots, newest event at the bottom, official HUD text measurement, black drop shadows, and a tally fixed above/right of the feed
- **Lifecycle guards**: Text feed and tally depend only on the generic killstreak mechanism; StateRun exit, master/feature disable, and killstreak disable clear residual state immediately
- **Verification status**: luacheck and static logic checks have been run; the focused in-game matrix, including a Nexus package without the legacy HTTP player, remains pending

### v1.35
- **SimpleAudio burst stability**: Hit, normal-kill, headshot, CF, and Boss requests fix their path, track, volume, and priority at event time before entering a 10-item queue; each update starts at most 2 instances, with a 0.03-second minimum interval and a 0.12-second expiry window
- **Multi-instance tracks**: SimpleAudio one-shot playback is capped at 8 active voices total, 3 hit voices, and 4 kill voices. New requests no longer unconditionally stop an older voice on the same track; low-priority normal hits are evicted first when capacity is needed
- **Generic killstreak mechanism**: Added the enabled-by-default killstreak switch; counting is independent of CF sound/icon toggles. Legacy `cf_killstreak_max` and `cf_killstreak_reset_time` IDs remain readable in General Settings, and the reset window also controls CF icon display duration
- **CF output guards**: Disabling the mechanism immediately stops CF sounds and icons while leaving the non-CF BF5 paths available; the first-kill headshot fallback cannot increment the counter twice
- **Verification status**: Static checks are complete; the focused in-game matrix, including a Nexus package without the legacy HTTP player, remains pending

### v1.3
- **Added CODBO7 kill sounds**: Normal kills use the random pool `k_bo7-01.wav`, `k_bo7-02.wav`, and `k_bo7-03.wav`; headshot kills use `k_bo7_headshot.wav`. CODBO7 is intentionally absent from hit-source dropdowns
- **Added custom Mourningstar BGM**: Added `lobby_bgm_enabled` (default off) and `lobby_bgm_volume` (0-100, default 100, step 5). Six MP3 tracks play only in the normal `hub`, with adjacent tracks never repeating immediately
- **Added safe lifecycle and failure handling**: The BGM stores and stops only its own SimpleAudio `play_id`, uses a generation token to prevent stale completion callbacks from restarting playback, and restores official music on hub exit, setting disable, master-switch disable, or unload. Missing SimpleAudio, missing files, and playback failures never mute official music
- **Native hub music POC scope**: The first implementation covers the official `music_zone` state as `None` and does not modify `music_game_state`, official source, SimpleAudio, or SimpleAssets

### v1.25
- **Improved audio backend handling**: SimpleAudio is preferred when available; the legacy HTTP audio player starts on demand only when fallback is needed. Per-frame request limits and a minimum same-track interval reduce the risk of high-frequency playback stutter while preserving the legacy fallback path
- **Fixed Wwise argument forwarding**: Wwise hook arguments are forwarded with varargs so Unit, Vector3, source IDs, and additional parameters are preserved
- **Fixed Boss and state management**: Boss detection consistently uses `breed.is_boss`; setting, master-switch, and HUD-toggle changes clear existing icons and CF killstreak state; resource-loading and hook initialization guards prevent duplicate setup
- **Fixed asset loading paths**: Corrected BF5/CF icon paths and added existence checks for CF icon and sound assets to avoid requesting missing files unconditionally
- **Added headshot kill settings**: Added `kill_headshot_use_normal` and `kill_headshot_volume` (0-100). When enabled, headshot kills still use the game selected by `kill_headshot_game` but play that game's normal kill sound; normal kills continue to use `kill_game_normal`
- **Added the CF first-kill headshot sound**: A headshot as the first kill in a CF killstreak plays `audio/KillSounds/cf/cf_headshot.wav`, falling back to `killsound_cf_01.wav` if the special asset is missing or playback fails. The special file is excluded from the normal numeric CF sound scan, and Boss kills do not trigger it
- **Improved backend diagnostics**: The first use of an audio or icon backend is reported in chat. The first use of the legacy HTTP audio player also displays a diagnostic asking users with SimpleAudio/SimpleAssets installed to report the unexpected fallback

### v1.2
- **Migrated to the SimpleAudio audio backend**: Hit sounds, kill sounds, and CF killstreak sounds now play through SimpleAudio by default while preserving the original 4-track behavior (normal hit, headshot hit, normal kill, headshot kill). Replaying the same track stops the previous playback instance first
- **Migrated to the SimpleAssets icon backend**: Battlefield 5 kill icons and CF killstreak icons now load through SimpleAssets by default, with the old HTTP image loader kept only as a compatibility fallback
- **Removed runtime dependency on the `bin` external player**: Missing `bin` files no longer break mod loading. With SimpleAudio + SimpleAssets installed, the mod runs normally and is suitable for Nexus Mods packaging
- **Fixed backend path resolution**: SimpleAudio / SimpleAssets calls now use explicit `mods/Hit_Kill_Sounds/...` cross-mod paths, preventing dependency libraries from resolving files under their own mod folders
- **Backend status chat messages**: The mod now prints a one-time in-chat message when audio or icon backends are first used, making it clear whether SimpleAudio/SimpleAssets or legacy fallback is active
- **Core gameplay logic preserved**: Hit/kill detection, DoT detection, companion attack handling, CF killstreak logic, and Wwise game-sound silencing hooks were not rewritten; only playback and texture loading backends changed

### v1.1
- **New CF (CrossFire) killstreak system**: Ported from the EBuyToDeep_KillFeedBack mod. Added 10 kill sound files (`killsound_cf_01..09.wav` + `killsound_cf_boss.wav` under `audio/KillSounds/cf/`) and 7 kill icons (`kill1..6.png` + `headshot_gold.png` under `cartoon_preview/kill_icon/cf/`). Unlike the random-play behavior of normal kill sounds, CF sounds play in killstreak order (killsound_cf_01→02→…→09→wrap to 01)
- **New style switch dropdown**: Added a "Style" dropdown at the top of Kill Icon Settings, letting you toggle between "Battlefield 5 Style" and "CrossFire Style". Selecting CrossFire activates the new killstreak icon + sound system
- **New CF independent settings group**: Added a "CrossFire Icon Settings" subgroup under Kill Icon Settings with 6 CF-specific settings (killstreak max, transparency, size, vertical position, horizontal position)
- **Decoupled CF sound and icon**: Added an "Enable CF Kill Sound (Indexed Killstreak)" toggle in Kill Sound Settings, independent of icon style. You can now mix and match: CF sound + BF5 icon, BF5 sound + CF icon, CF+CF, or BF5+BF5
- **User-configurable killstreak max**: New "CF Killstreak Max" setting, range 10-30, step 1, default 13. When the counter reaches the max, it wraps around to 0 and starts a new killstreak
- **Unified kill icon master switch**: Removed the previous BF5/CF independent icon toggles, replaced with a single "Enable Kill Icon" master toggle at the top. Battlefield 5 and CrossFire icons share this switch
- **CF counter reset time moved to General Settings**: Renamed "CF Icon Display Duration" to "CF Killstreak Reset Time" and moved it to General Settings, range 1.0s-3.0s (×0.1s units). This value now controls both the CF counter reset window and the CF icon display duration
- **DoT icon toggle moved to Kill Icon Settings top level**: Lifted "Show Kill Icon on DoT Kills" from the BF5 subgroup to the top of Kill Icon Settings, applying to both Battlefield 5 and CrossFire style DoT kill icons
- **Companion toggles grouped with related features**: Moved the 3 companion (Adamant dog) toggles from General Settings to their respective feature groups — "Enable Companion Hit Sound" to Hit Sound Settings, "Enable Companion Kill Sound" to Kill Sound Settings, "Enable Companion Kill Icon" to Kill Icon Settings
- **Fixed CF guard separation bug**: Previously, the CF path was gated entirely by hit-sound guards (`kill_dot` / `companion_kill_sound_enabled`), causing CF icons to still appear when "Show Kill Icon on DoT Kills" was off or "Enable Companion Kill Icon" was off. CF sound now uses sound guards and CF icon uses icon guards, so each behavior is controlled by its corresponding toggle
- **Resource auto-discovery with hardcoded fallback**: Mod load scans CF asset directories to dynamically detect available sound count (0-9) and icon count (0-6). When the scan fails due to DMF mod-sandbox cwd restrictions, the mod falls back to hardcoded defaults (9 sounds, 6 icons) to ensure the feature always works
- **Decoupled kill target filter**: Added a new "Kill Icon Target" dropdown (kill_icon_target) under Kill Icon Settings, independent of "Kill Sound Target" (kill_target) under Kill Sound Settings. `kill_icon_target` applies to all icon styles — Battlefield 5, CrossFire, and any future additions. 4 combinations supported: ① both "All Enemies" (default — sound + icon both trigger; preserves legacy behavior); ② sound "All" + icon "Elite Only" (minions play sound but show no icon); ③ sound "Elite Only" + icon "All" (minions show icon but play no sound); ④ both "Elite Only"

### v1.05
- Added 4 new sound sources: Call of Duty: Warzone, Call of Duty: Warzone 2, Delta Force, and Apex Legends (12 hit files + 6 kill files distributed across 8 new audio subdirectories under `audio/HitSounds/` and `audio/KillSounds/`)
- Companion (Adamant dog) sound decoupling: Added 3 new independent toggles — "Enable Companion Hit Sound", "Enable Companion Kill Sound", "Enable Companion Kill Icon" (under General Settings) — letting you independently mute sounds and icons caused by Adamant dog attacks. Default ON preserves existing behavior for legacy users.
- v1.12.0 / v1.12.1 compatibility patch: Added 6 new Wwise patterns (`play_chord_claw_hit`, `play_transonic_blades_impact_hit`, `play_power_sword_1h_p3_hit`, `play_power_sword_hit`, `play_arc_maul_hit`, `play_powermaul_1h_hit`) so the original hit sounds of Cryptic Chord Claw / Transonic Blades, Power Sword P3, and Power Maul P3 are silenced when "Enable Game's Hit Sounds" is off.
- Headshot fallback: When a selected source has no dedicated headshot files (e.g. Warzone, APEX), the mod falls back to that source's normal pool so headshots still produce feedback instead of going silent.
- APEX shield sounds routed to normal: Per design decision, APEX's 8 shield-hit files and 1 shield-break file are pooled into the normal category (substituting for flesh-tone hits).
- CODWZ2 armor kill categorized as normal: `k_codwz2_armor.wav` joins the normal-kill pool as a second variant (deliberately *not* classified as headshot, since "armor" denotes a kill against armored enemies).

### v1.0
- Separated normal and headshot hit sounds: Added two new independent dropdowns under Hit Sound Settings — "Normal Hit Sound Source Game" and "Headshot Hit Sound Source Game" — letting you pick a different game source for normal hits vs headshot (weakspot) hits
- Separated normal and headshot kill sounds: Added two new independent dropdowns under Kill Sound Settings — "Normal Kill Sound Source Game" and "Headshot Kill Sound Source Game"
- Added independent melee hit sound configuration: Added two new dropdowns under Hit Sound Settings — "Normal Melee Hit Sound Source Game" and "Headshot Melee Hit Sound Source Game" — usable when the "Enable Melee Hit Sounds" toggle is on, letting you assign a different game source for normal melee hits and melee headshot hits
- Fixed DMF dropdown label bug: Six shared game-source dropdowns and two shared target-type dropdowns were getting wrapped in 1 to 3 pairs of stray `<>` characters under the Chinese locale; resolved by generating a fresh options copy per dropdown
- Full backward compatibility: All new settings retain the legacy `hit_game` / `kill_game` values as fallback, so existing users keep their current behavior after upgrading

### v0.97
- Fixed DoT (damage-over-time) misidentification bug: When using the Psyker Chain Lightning staff or other electrocution damage, the mod would still play hit/kill sounds even with the "DoT Hit Sound" and "DoT Kill Sound" toggles disabled. Now correctly identifies all DoT types (bleed, burn, toxin, corruption, grimoire, warpfire, electrocution)
- Decoupled DoT kill sound and kill icon controls: Previously, disabling the "DoT Kill Sound" toggle also suppressed the kill icon for DoT kills
- Added new "Show Kill Icon on DoT Kills" toggle (under Kill Icon Settings), allowing independent control of HUD kill icon display for DoT kills. Enabled by default

### v0.96
- Added "Enable Game's Hit Sounds" toggle (under Hit Sound Settings)
- Added "Enable Game's Kill Sounds" toggle (under Kill Sound Settings)
- Intercept game's built-in hit/kill sounds via Wwise hook with on-demand muting
- Fixed game startup crash caused by Wwise hook signature mismatch
- Fixed game hit sound toggle not silencing crit/headshot sounds
- Code structure optimization: removed unused settings and redundant constants

### v0.95
- Fixed bug where the master switch was visible in settings but had no actual effect
- Split "Sound Settings" into separate "Hit Sound Settings" and "Kill Sound Settings" groups
- Added independent "Enable Hit Sounds" and "Enable Kill Sounds" sub-toggles
- Decoupled kill sounds from kill icons: each can be toggled independently
- Added kill icon transparency slider (0% - 100%)
- Master switch now immediately stops all currently playing sounds when turned off

### v0.92
- Thanks to EBuyToDeep for providing the new audio player, significantly reducing antivirus and firewall blocking

### v0.91
- Improved kill icon horizontal position calculation logic
- Added icon horizontal position adjustment (0=left, 50=center, 100=right)

### v0.9
- Kill icon system rewritten with queue-based architecture
- Support up to 10 icons displayed simultaneously
- New kills push old icons to the left
- Added display duration configuration
- Added Call of Duty: Black Ops Cold War sounds
- Added Call of Duty: Vanguard sounds
- Added Overwatch sounds
- Code cleanup, removed unused code
