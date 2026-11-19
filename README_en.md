# Hit/Kill Sounds

Add hit sounds, kill sounds and kill icons inspired by several games to Warhammer 40,000: Darktide. Optional features include CrossFire killstreak announcements, a Battlefield 4-style text feed and score tally, and Mourningstar hub BGM.

**Current version: v1.5.4**

## Installation and Quick Start

1. Make sure DML (the Mod Loader) and DMF (the Mod Framework) are installed and enabled.
2. Install and enable the dependencies: **SimpleAudio** plays audio, and **SimpleAssets** loads icons.
3. Put the entire Hit_Kill_Sounds folder in the game's mods directory, alongside SimpleAudio and SimpleAssets.
4. Enable these mods in mods/mod_load_order.txt, placing SimpleAudio and SimpleAssets before Hit_Kill_Sounds.
5. Start the game, open **Hit/Kill Sounds** in the Mod settings, check that the master switch is enabled, then choose your sound sources and icon style.

For a first check, keep the default BF1 sources and confirm that hit and kill sounds work. Hub BGM and the Battlefield 4 text feed are disabled by default; enable them when needed.

## Features and Common Settings

| What you want to change | Where to look | Notes |
| --- | --- | --- |
| Normal and weakspot hit sounds | Hit Sound Settings | Choose the two sources separately; both use hit volume |
| Normal and weakspot melee hit sounds | Hit Sound Settings | Enable melee hit sounds, then choose their sources |
| Normal and headshot kill sounds | Kill Sound Settings | Choose separate sources and adjust their respective volumes |
| Melee kill sounds | Kill Sound Settings | An independent switch lets you mute melee kill sounds while keeping icons |
| DoT, companion and target filters | The relevant sound or icon settings | Damage-over-time, companion feedback and eligible targets have separate controls |
| The game's original hit and kill sounds | Hit or Kill Sound Settings | Keep or mute the original game feedback |
| BFV and CF kill icons | Kill Icon Settings | Adjust style, size, opacity, position and other options |
| CF killstreak announcements and voice | General Settings, Kill Sound Settings | Enable independent killstreak counters and CF kill sounds, then choose Male or Female |
| BF4 text feed | Battlefield 4-style Text Kill Feed | Enable the general killstreak mechanism, then the text feed |
| Mourningstar hub BGM | Custom Mourningstar BGM | Disabled by default; regular hub only |
| Your own hit and kill sounds | The corresponding source dropdown | Choose Custom Audio Pack and put files in UserAudio |

Hit sounds, kill sounds and kill icons can be enabled independently. Normal, weakspot and melee hits still share one hit cooldown. Choosing Custom does not bypass target, DoT, companion, melee or volume settings.

### BFV Kill Icons

The BFV style queues kill icons and moves existing icons when a new kill arrives. It uses 10 main slots and up to 2 leaving-transition slots, with entry, headshot ring and fade animations.

Adjust size, opacity, normal/headshot colors, horizontal/vertical position and display duration. Size ranges from 0.5 to 2.0 times the base size; display duration ranges from 1.0 to 3.0 seconds.

### CF Killstreak Sounds and Icons

In **General Settings**, turn on **Enable Independent Killstreak Counters**. In **Kill Sound Settings**, turn on **Enable Kill Sounds** and **Enable CF Kill Sound (requires Killstreak)**, then choose **Male** or **Female** under **CF Kill Voice**. Male is the default, including for older configurations. After a voice change, the next eligible kill uses the new voice at the current streak's next count.

- **Male:** Kills 1–9 use their corresponding sounds. From kill 10 onward in the same streak, the ninth sound repeats.
- **Female:** Kills 1–8 use their corresponding sounds. From kill 9 onward in the same streak, the normal first-kill sound repeats.
- **Headshots:** A weakspot kill at count 1 uses the selected voice's dedicated headshot sound. If that file is missing or **Use Normal Sound from Headshot Game for Headshot Kills** is enabled, it uses that voice's normal first-kill sound. Later headshot kills use the sound for the current streak count.
- **Boss kills:** These play the Boss sound from the selected voice and leave the ordinary killstreak count intact.

CF sounds and CF icons can be enabled separately. For example, combine CF announcements with BFV icons, or ordinary kill sounds with CF icons.

- Icons advance through the available tiers and keep the highest tier beyond that. A first-kill headshot can display the gold headshot icon.
- The killstreak limit defaults to 13 and ranges from 10 to 30. After the limit is reached, the next kill starts at count 1. The reset time defaults to 2.0 seconds and ranges from 1.0 to 3.0 seconds.
- When CF killstreak sounds are active for a kill, they take priority over the selected kill sound source, including Custom Audio Pack.

The BF4 text feed, CF sounds and CF icons each maintain their own counter and target filter. Their counts can differ and do not need to stay synchronized.

### BF4 Text Feed and Score Tally

Enable the killstreak mechanism in General Settings, then enable the Battlefield 4-style Text Kill Feed. It displays borderless kill messages, bonus values and an accumulated tally, independently of sound and icon switches.

- Normal kills award 100 display points, elites 200, specials 250 and Bosses 500. Headshots add 50, with additional multikill bonuses supported.
- For example, a headshot special kill displays both the special-kill message and headshot bonus, totaling 300 before any multikill bonus.
- Adjust targets, display duration, position and text size. The accumulated tally is displayed beside the feed.
- These points are for this Mod's HUD only and do not change official mission rewards or results.
- Disabling the feed or the killstreak mechanism clears its current display. If the game's own kill feed is also enabled, you may see duplicate notifications.

## Supported Sound Sources

| Game | Normal Hit | Headshot Hit | Normal Kill | Headshot Kill |
|------|------------|--------------|-------------|---------------|
| Battlefield 1 | 5 variants | 5 variants | 1 | 1 |
| Battlefield 2042 | 24 variants | 13 variants | 6 variants | 13 variants |
| Battlefield 6 | 28 variants | 8 variants | 6 variants | 8 variants |
| Battlefield V | 12 variants | 5 variants | 1 | 10 variants |
| Call of Duty: Black Ops 4 (BO4) | 1 | 1 | 3 variants | 5 variants |
| Call of Duty: Black Ops 6 | 2 variants | 1 | 1 | 3 variants |
| Call of Duty: Black Ops 7 (BO7) | 3 variants | 3 variants | 3 variants | 1 |
| Call of Duty: Black Ops Classic (BO Classic) | 1 | Shared with Normal Hit | — | — |
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
| Custom Audio Pack | Up to 20 | Up to 20 | Up to 20 | Up to 20 |

“→ normal” means headshot feedback uses the source's normal sound pool. “—” marks an unavailable category. When a category has multiple variants, the mod picks one at random. BO4, BO7 and BO Classic are available for normal and weakspot hits in both ranged and melee combat. BO4 and BO7 are also available for normal and headshot kills.

## Custom Hit and Kill Sounds (UserAudio)

**No Lua editing is needed.** Replace a default WAV for a simple setup, or edit a playlist to use several sounds. All paths below are relative to the Hit_Kill_Sounds folder.

### Where to Put Files

~~~text
UserAudio/
├─ README_自定义音频.txt      Chinese plain-text guide
├─ README_Custom_Audio.txt  English plain-text guide
├─ BGM/
│  └─ tracks.txt            BGM playlist; comments only by default
├─ Hit/
│  ├─ Normal.wav           Default normal hit
│  ├─ Headshot.wav         Default weakspot hit
│  ├─ normal/              Optional additional normal hits
│  ├─ headshot/            Optional additional weakspot hits
│  └─ playlist.txt         Hit playlist
└─ Kill/
   ├─ Normal.wav           Default normal kill
   ├─ Headshot.wav         Default headshot kill
   ├─ normal/              Optional additional normal kills
   ├─ headshot/            Optional additional headshot kills
   └─ playlist.txt         Kill playlist
~~~

The four default WAVs are direct copies of BFV sounds already included in this Mod. Replace these copies as desired. No UserAudio BGM placeholder is bundled, and the original files under audio remain available.

### Method 1: Replace a Default WAV

1. Fully exit the game and copy the default file you want to replace to a safe personal location.
2. Use an audio editor to export your sound as a real WAV file.
3. Overwrite the corresponding Normal.wav or Headshot.wav under Hit or Kill, keeping its name and location. The default SFX playlists are already filled in; no playlist editing is required.
4. Start the game and select **Custom Audio Pack** in the appropriate source dropdown. The six selectors cover normal hit, weakspot hit, normal melee hit, weakspot melee hit, normal kill and headshot kill; each can be changed separately.
5. Check the master switch, the relevant sound switch and volume. Melee hits also require the melee hit switch.

**Format:** Phase-one SFX support is WAV only. PCM 16-bit, 48 kHz, mono or stereo is recommended. Renaming an MP3 to .wav is not conversion; compatibility with other WAV encodings depends on actual playback.

In Windows Explorer, enable **View → Show → File name extensions** to avoid names such as Normal.wav.wav or playlist.txt.txt.

### Method 2: Add Several Sounds Through a Playlist

Put audio files inside UserAudio, then edit the matching playlist.txt with Notepad. Paths start at the UserAudio root and must have a normal or headshot label; folder names do not determine the category.

Hit playlist, UserAudio/Hit/playlist.txt:

~~~text
# type|relative path from UserAudio
normal|Hit/Normal.wav
normal|Hit/normal/metal_01.wav
headshot|Hit/Headshot.wav
headshot|Hit/headshot/headshot_soft.wav
~~~

Kill playlist, UserAudio/Kill/playlist.txt:

~~~text
normal|Kill/Normal.wav
normal|Kill/normal/kill_01.wav
headshot|Kill/Headshot.wav
headshot|Kill/headshot/headshot_01.wav
~~~

The extra filenames are examples. Add the real WAV files before adding their entries. When a category has several valid files, one is selected randomly for each event.

| What you want to do | How to do it |
| --- | --- |
| Add a sound | Put in a WAV and append its category and path to the playlist |
| Replace an entry | Change the path on that line, or overwrite the same-named file |
| Temporarily disable an entry | Put # at the beginning of the whole line, for example # normal\|Hit/Normal.wav |
| Remove from the playlist | Delete the entry; the audio file can stay |
| Delete completely | Remove or comment out the entry first, then delete your unwanted audio file |
| Restore the default sound | Restore the default WAV and keep its matching default playlist entry |

### Playlist Rules and Fallback

- Save as UTF-8 plain text; BOM is allowed. Blank lines, surrounding whitespace and whole-line # comments are ignored. Inline comments are not supported.
- Use / in paths and do not add quotes. Only paths relative to UserAudio are accepted. Absolute paths, drive letters, network paths, .., wildcards and executable content are rejected.
- Do not use symlinks or directory junctions to reference external files. Spaces and UTF-8 filenames can be listed; try a simple English filename if a file cannot be read.
- Each SFX category loads at most the first 20 valid paths. Duplicate paths within a category are deduplicated without regard to case and do not increase probability. One file can be explicitly assigned to both normal and headshot.
- Manifests are limited to 64 KiB. Missing files, invalid paths and unsupported formats are skipped with rate-limited warnings. Oversized manifests are ignored with fallback.
- Empty Custom weakspot/headshot pool → Custom normal pool of the same type → corresponding built-in BFV pool if that is also empty. Hit and kill pools never mix.
- “Use normal sound for headshots” still uses the selected headshot source's normal pool. BFV's extra headshot tail is added only when BFV is explicitly selected. Custom does not add the tail, even when falling back to BFV.

After editing files or playlists, **fully exit and restart the game**. Playlists are read and cached at initialization; hits, kills and track transitions do not reread manifests or scan user folders.

## Mourningstar Hub BGM

Enable the BGM switch in **Custom Mourningstar BGM** to use this feature; it is off by default. Volume ranges from 0 to 100, can change during playback without restarting the track, and also follows the game's master and music volume.

BGM runs only in the regular Mourningstar hub. It does not run in missions, the main menu, training grounds, the shooting range or prologue_hub.

### What Plays by Default

UserAudio/BGM/tracks.txt contains comments only by default, and Lobby.mp3 is not bundled. The original six files therefore remain the default:

~~~text
audio/BGM/Lobby_BGM1.mp3
audio/BGM/Lobby_BGM2.mp3
audio/BGM/Lobby_BGM3.mp3
audio/BGM/Lobby_BGM4.mp3
audio/BGM/Lobby_BGM5.mp3
audio/BGM/Lobby_BGM6.mp3
~~~

### Use Your Own BGM

1. Fully exit the game, prepare real MP3 files and put them in UserAudio/BGM.
2. Open UserAudio/BGM/tracks.txt with Notepad. Write one path relative to UserAudio per line, without normal/headshot labels:

~~~text
# Relative to UserAudio; add these files yourself before using these entries
BGM/My_Lobby_Track.mp3
BGM/Another_Track.mp3
~~~

3. Save as UTF-8, restart the game and enable the hub BGM switch. You do not need to select Custom in any hit or kill source dropdown.

BGM loads at most 20 valid paths, chooses tracks randomly and avoids immediate repetition where possible. Renaming a file extension does not convert another format to MP3.

### Playback Priority and Failure Handling

| Playlist condition | What plays |
| --- | --- |
| At least one valid MP3 | The UserAudio playlist takes priority; it is not mixed with the old six tracks |
| Manifest missing, empty or entirely invalid | The original six slots |
| A valid custom track fails to start | Another not-yet-failed track from the custom playlist is tried |
| Every custom track fails to start | Official hub music is restored; playback does not fall back to the old six tracks |
| SimpleAudio or safe native music control is unavailable | Official music is kept or restored |

The Mod attempts to suppress official hub music only after a custom track obtains a valid playback instance. Hub exit, mission entry, BGM/master switch off, Mod disable and unload stop its owned BGM instance and restore official music.

To return to the old six tracks, comment out or remove every track entry in tracks.txt, then fully restart the game.

## Troubleshooting and Preserving Files During Updates

| Problem | Check these first |
| --- | --- |
| No hit or kill sounds | Master and relevant sound switches, volume, target filters, DoT/companion/melee settings, and whether SimpleAudio is enabled |
| Custom still sounds like built-in audio | An invalid playlist or file may have triggered BFV fallback; check labels, paths, real file formats and Mod warnings |
| CF announcements replace my custom kill sound | CF killstreak sounds are active; disable them to test the ordinary kill source |
| File or playlist changes have no effect | Fully exit and restart the game; check duplicate extensions and UTF-8 encoding |
| No icons | SimpleAssets, the icon switch and the icon target filter |
| BF4 feed or CF killstreak features do not work | Enable the general killstreak mechanism, then check the feature's own switch and target filter |
| BGM still uses the old six tracks | This is the default; UserAudio needs at least one valid MP3 entry to take priority |
| BGM returns to official music | Check hub state, SimpleAudio and files; failed playback or safe-control checks intentionally restore official music |

**Before updating:** Fully exit the game and copy the entire UserAudio folder to a safe personal location outside the installation. After updating, restore your files and playlists; manually merge any new examples you want. Installers or Mod managers may overwrite the whole folder, so do not rely on automatic preservation.

Keep personal audio in UserAudio. No changes to Lua files under scripts are needed.

## Backend and Validation Notes

Audio normally uses SimpleAudio; icons use SimpleAssets. The old HTTP player remains only as an SFX compatibility path where available. With SimpleAudio + SimpleAssets installed, the external player executable is not required, and release packages can omit bin. BGM always uses SimpleAudio, never the HTTP player.

v1.5.2 sets the short-sound voice limits managed by HKS to 5 hit, 5 kill and 10 total. These are not global limits for SimpleAudio or BGM. The pending queue remains 10, with the existing priority and replacement rules.

**Current validation:** 32 local Lua tests have passed. Full-script luacheck reports 0 errors and retains 27 line-length warnings. The user's initial in-game test has not revealed any issues; dedicated checks for dense combat, failure fallback, the full BGM lifecycle and lower-end hardware have not all been recorded.

## Asset Sources and Acknowledgments

Built-in sounds and icons remain the property of their respective rights holders. The four default UserAudio WAVs are copies of BFV sounds already included in this Mod. No UserAudio BGM placeholder is bundled.

- Battlefield sounds and BFV kill icons: EA/DICE.
- Call of Duty sounds: Activision.
- The Finals sounds: Embark Studios.
- Overwatch sounds: Blizzard Entertainment.
- Other game-themed resources belong to their respective games; the CF killstreak system was ported from EBuyToDeep_KillFeedBack.

- **BiliBili UP EBuyToDeep** ([https://space.bilibili.com/1273948298](https://space.bilibili.com/1273948298)): For providing the external audio player solution that made this mod possible. The HitKillSoundsPlayer application is based on the concept from their EBuyToDeep_KillFeedBack mod.
- **deluxghost** ([https://space.bilibili.com/4712698](https://space.bilibili.com/4712698)): For providing the SimpleAudio + SimpleAssets solution, allowing v1.2 to remove the external player requirement and use a cleaner local audio/texture loading path.

## Usage and Copyright

This Mod is provided for educational and personal use. Before replacing, sharing or redistributing personal audio, make sure you have the relevant permissions. Do not redistribute unauthorized commercial audio with the Mod.

## Changelog

### v1.5.4

- **BO4:** Added normal and weakspot hit sounds, plus three normal kill variants and five headshot kill variants.
- **BO7:** Added three variants each for normal and weakspot hits. Replaced the headshot kill sound and kept the three normal kill variants.
- **BO Classic:** Added a classic hit sound shared by normal and weakspot hits.
- **CF killstreak announcements:** Added a female voice option. Male remains the default. Switching voices carries over the streak count. The female voice repeats its normal first-kill sound from kill 9 onward in the same streak.

### v1.5.3

- **Native hit-sound muting:** Fix missing coverage for `melee_hits` / `melee_hits_*` events without a `play_` prefix. Keep the approved hit events and six kill events independently controlled, with player damage, toughness, warnings, reload and equip sounds excluded.
- **BGM unload and reload recovery:** Retain and retry failed official `music_zone` restoration, including updates after shutdown. An HKS-specific persistent record carries recovery across DMF reloads, and only a successful direct Wwise call confirms restoration. Custom BGM waits while recovery is pending, and stale playback callbacks are invalidated.
- **Dependencies:** SimpleAudio, SimpleAssets and official game scripts are unchanged. Attack eligibility, the HKS short-sound queue and existing audio assets are unchanged.
- **Validation:** All 55 local Lua tests pass. The user reports no issues so far in initial in-game testing; full targeted acceptance and restore-failure injection remain unconfirmed.

### v1.5.2

- **Custom Audio Packs:** Custom is added to six existing source dropdowns, with default BFV WAV copies and explicitly categorized playlists. Each category supports up to 20 entries, checked and cached at startup; no Lua editing is needed.
- **Safe fallback:** Invalid entries are skipped, duplicates are removed and warnings are rate-limited. Empty Custom weakspot/headshot pools fall back to Custom normal, then built-in BFV, without adding BFV's extra headshot tail.
- **BGM playlists:** No UserAudio Lobby placeholder is bundled, and the playlist contains comments only by default, preserving the original six tracks. Adding valid MP3 entries gives the custom playlist priority; all custom tracks failing restores official music.
- **Hub music restoration:** Playback-instance, volume and exit cleanup remain in place. Restoration now avoids cached-state suppression and retains retry state after temporary failures.
- **High-fire-rate optimization:** HKS short-sound voices change to 5 hit, 5 kill and 10 total. The pending queue remains 10, with a 0.12-second maximum wait, up to 2 dispatches per update and at least 0.03 seconds between dispatch updates. Priority and replacement rules stay unchanged.
- **Hit cooldown admission:** The shared cooldown remains 0.08 seconds and commits only after a request is admitted to the queue. Synchronous refusal does not consume cooldown; later asynchronous dispatch failure does not roll it back. Admission is not confirmed playback.
- **Guides and validation:** Separate Chinese and English plain-text tutorials are included. All 32 local Lua tests pass, and initial user testing in game has revealed no issues; dedicated acceptance checks still need to be recorded.

### v1.5.1
- **Battlefield V (BFV) authentic audio-visual restoration & leaving-slot fixes**:
  - Separated `killsound_bfv_headshotadd.wav` (2.077s low-frequency metallic resonance tail) from `headshot1~10.wav` (transient helmet crack pool), dispatching both on the same frame with 0ms delay on headshot kills and binding `replace_group = "bfv_headshot_add"` to prevent voice pool exhaustion.
  - Fixed `_leaving_slots` per-frame self-multiplicative decay and the Lua `0 or 1` invisibility trap when overflowing on the same frame with `render_alpha = 0`.
  - Restored BFV Cubic Ease-Out (`1.85 -> 1.0`) entry slam (vertical center drop for a single icon, `+28 * scale` slide-in when queued), Quartic Ease-Out (`0.85 -> 2.8`) background (`z = -1`) headshot ring shockwave, and two-stage natural fade (30% horizontal micro-convergence + 70% quadratic fade with `1.0 -> 0.88` scale shrink).
- **CrossFire (CF) visual size normalization & animation upgrade**:
  - Added `GOLD_HEADSHOT_TEX_SCALE = 0.75` to normalize `headshot_gold.png` (100% canvas fill) against `kill1~6.png` (65.2%×74.2% canvas fill), and restored the gold headshot skull when killing a Boss with a headshot at zero streak.
  - Restored CF first-kill heavy slam (`2.15 -> 0.92 -> 1.0` with Alpha `0.25 -> 1.0`), streak upgrade two-stage elastic pulse (`0.82 -> 1.28 -> 1.0`), tail micro-expansion fade (`1.0 -> 1.08`), and an underlying `afterimage` expansion pass (`1.0x -> 1.65x`).
- **Battlefield 4 (BF4) staggered reveal timing & independent right tally column**:
  - Added `refresh_visible_targets` and `trigger_tally_roll`: fixed staggered entries (`reveal_at`) finishing their slide while hidden or spawning mid-air, preserved smooth upward push transitions for existing rows, and anchored score roll interpolation with `roll_start_score`.
  - Removed the redundant `- event_pass_width` (32px gap bug) and moved the cumulative tally to an independent right-hand column (`base_x + 88 * scale`, left-aligned), eliminating text overlap on rows 3–8 and vertical jumping.
- **Audio backend, dependency integration & HUD performance optimizations**:
  - `Hit_Kill_Sounds_audio_backend.lua`: Stopped replaced voices (`stop_active_replace_group`) before `make_voice_room`; moved `MIN_DISPATCH_INTERVAL` outside the per-frame dispatch loop; enabled a 25ms micro fade-out (`0.025s`) in `stop_active_voice` to eliminate waveform clipping clicks; prevented accidental fallback to the legacy HTTP player when `using_simple_audio == true`.
  - `Hit_Kill_Sounds_bgm.lua`: Added a `0.4s` fade-out on stop and async initialization retry protection (up to 5 retries at 0.5s intervals) in `play_track`.
  - `Hit_Kill_Sounds_events.lua`: Prioritized `SimpleAudio.glob` for fast CF asset scanning; optimized `is_event_silenced` with an $O(1)$ `has_silenced_patterns` short-circuit and plain `string.find` matching; excluded `has_scripted_death_sequence` targets and decoupled `bf4_eligible` from `killstreak_enabled`.
  - Added idle `update`/`draw` short-circuits across all three HUD elements, cached `_text_size` widths in BF4 HUD, added texture preload retry protection, and expanded `visibility_groups` to include `player_in_danger_zone`, `communication_wheel`, `emote_wheel`, and `tactical_overlay`.

### v1.5.0
- **BFV lifecycle and queue fixes**: The tenth main icon is retained and the eleventh evicts the oldest; bounded leaving copies, symmetric spacing, scale-aware layout, entry/ring effects, natural fade, and overflow eviction are time-driven.
- **CF/O01 update**: Fixed fade-out at the default window and constrained the HUD using actual size and animation expansion; Boss kills display only an unexpired ordinary CF streak without advancing or extending its counter.
- **CF announcement replacement**: Only ordinary numeric streak announcements are replaced; first-kill special audio, Boss audio, hit audio, and BGM remain untouched, with existing queue and voice limits preserved.
- **BF4 N03/S09-S11**: Added independent-sequence multikill text and score bonuses, atomic batch submission, whole-batch capacity eviction, a separate cumulative-total display, non-overlapping text layout, staggered rows, and time-stable total-score animation.
- **N05**: Added the enabled-by-default `kill_melee_sound_enabled` switch for Mod-owned BFV/CF melee kill sounds only; melee hit sounds, icons, BF4 text/score, and native game sounds remain independent.
- **Non-damaging hit fix**: Valid push/stagger reports with `damage <= 0` no longer play Mod hit sounds; hits with positive damage retain the existing sound behavior.
- **Verification status**: Static checks and isolated regression coverage were updated; in-game layout, audio, and multiplayer/RPC verification remain pending.

### v1.4.7
- **1.13.2 compatibility fixes**: Added missing native hit-mute events, preserved zero-damage toughness hits, and changed electrocution DoT handling to exact damage profiles
- **Kill-target and runtime stability fixes**: Filtered player/ordinary prop kill feedback, protected legacy player path detection, and clamped low-FPS HUD interpolation

### v1.4.5
- **Servo skull companion filtering**: Servo skull laser and initial flamer direct hits reuse the companion hit-sound, kill-sound, and kill-icon toggles; subsequent burn DoT is excluded from companion filtering
- **Chain-lightning game hit-sound mute**: Disabling the game's hit sounds now mutes the chain-lightning loop start event while preserving its stop event

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
