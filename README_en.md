# Hit/Kill Sounds

A Darktide mod that plays hit and kill sounds from various games when you damage or kill enemies, and displays dynamic kill icons.

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
- **CF Killstreak System** (v1.1): CrossFire-themed killstreak sound + icon system, plays sounds in indexed order based on killstreak count, switchable style
- **Style Switch** (v1.1): Toggle between "Battlefield 5 queue-based icon" and "CrossFire killstreak-style icon"
- **Decoupled CF Sound & Icon** (v1.1): CrossFire killstreak sound is independently toggleable from icon style, supporting 4 combinations (CF sound + BF5 icon, BF5 sound + CF icon, CF+CF, BF5+BF5)
- **SimpleAudio + SimpleAssets backend** (v1.2): Audio now plays through SimpleAudio by default, and icon textures load through SimpleAssets by default, with no external player executable required

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
  - Killstreak max count (10-30, default 13; wraps to 0 and restarts a new streak when reached)
  - Icon transparency, size, vertical/horizontal position
  - Counter reset time (1.0s-3.0s, default 2.0s; controls both the killstreak reset window and the icon display duration)
- **Decoupled sound & icon**: The "Enable CF Kill Sound" toggle in Kill Sound Settings is independent of icon style — supports 4 combinations: CF sound + BF5 icon, BF5 sound + CF icon, CF+CF, BF5+BF5

Icon assets: CrossFire killstreak icons

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

Starting with v1.2, audio playback uses SimpleAudio by default, and icon textures use SimpleAssets by default. The old HTTP player adapter is still kept as a compatibility fallback, but Nexus Mods release packages can omit the `bin` folder.

The kill icon system preloads textures through SimpleAssets and manages a queue of 10 slots. New kills trigger entry animations that push old icons left.

## Installation

1. Install and enable the required mods: SimpleAudio and SimpleAssets
2. Download this mod and place `Hit_Kill_Sounds` next to `SimpleAudio` and `SimpleAssets` in your Darktide `mods` folder
3. Enable this mod in the game's mod menu
4. Configure your preferred sound source and volume, as well as kill icon options in the mod settings

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

Starting with v1.2, the mod uses SimpleAudio to play local files under `audio/HitSounds` and `audio/KillSounds`, and SimpleAssets to load kill icon textures. The old HitKillSoundsPlayer / HTTP player logic remains as a compatibility fallback, but Nexus Mods release packages can omit the `bin` folder.

## License

This mod is provided for educational and personal use only. All sound files and icon assets remain the property of their respective copyright holders.

## Changelog

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
