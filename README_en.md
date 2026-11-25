# Hit/Kill Sounds

[English](README_en.md) | [简体中文](README.md)

**Current version: v1.5.8**

Adds multi-game **hit and kill sounds**, **kill icon & banner HUDs** (BFV / BF1 / CF / Valorant), a **Battlefield 4-style text kill feed and score tally**, **custom audio packs (UserAudio)**, and **custom Mourningstar hub BGM** to Warhammer 40,000: Darktide.

### Highlights

- **18 Built-in Game Sound Sources + Custom Audio Pack**: Mix and match 6 independent audio slots (normal hit, weakspot hit, normal/weakspot melee hit, normal kill, headshot kill) with optional native game hit/kill sound muting.
- **4 Distinct Kill Icon HUD Styles**: Battlefield V HD queued skulls (with a 12-tooth destroy-vehicle Boss gear, adaptive staggered spawning, settle-triggered thinning shockwave, staggered fade wave, and centered 3-tier BFV text kill/hit score feedback), Battlefield 1 dual-box kill banner (with vertical center-outward unfold/collapse & synchronized text compression, a unified full-card 45° left-to-right light sweep, exact all-class weapon/blitz/ability/DoT/companion attribution, and a horde-safe priority queue), CrossFire killstreak badges, and Valorant killstreak emblems with particle effects.
- **Battlefield 4-Style Text Kill Feed**: Works standalone (no killstreak toggle required), featuring a top-down cascade, two-stage terminal typewriter transform (`[Weapon / Kill Method]` + bright red victim name), and authentic no-plus-sign cumulative tally.
- **Zero-Lua Custom Audio**: Drop in WAV or MP3 files and edit plain-text playlists to customize hit sounds, kill sounds, and Mourningstar hub BGM without touching Lua.

### Table of Contents

- [Installation and Quick Start](#installation-and-quick-start)
- [Features and Common Settings](#features-and-common-settings)
- [Kill Icons and HUD Feedback](#kill-icons-and-hud-feedback)
- [Supported Sound Sources](#supported-sound-sources)
- [Custom Hit and Kill Sounds (UserAudio)](#custom-hit-and-kill-sounds-useraudio)
- [Mourningstar Hub BGM](#mourningstar-hub-bgm)
- [Troubleshooting and Update Backups](#troubleshooting-and-update-backups)
- [Backend and Technical Notes](#backend-and-technical-notes)
- [Asset Sources and Acknowledgments](#asset-sources-and-acknowledgments)
- [Usage and Copyright](#usage-and-copyright)
- [Changelog](#changelog)

---

## Installation and Quick Start

1. Make sure **DML** (Darktide Mod Loader) and **DMF** (Darktide Mod Framework) are installed and enabled.
2. Install and enable both required dependencies: **SimpleAudio** (audio playback) and **SimpleAssets** (icon texture loading).
3. Place the entire `Hit_Kill_Sounds` folder inside the game's `mods/` directory alongside `SimpleAudio` and `SimpleAssets`.
4. Enable these mods in `mods/mod_load_order.txt`, placing `SimpleAudio` and `SimpleAssets` **before** `Hit_Kill_Sounds`:
   ```text
   SimpleAudio
   SimpleAssets
   Hit_Kill_Sounds
   ```
5. Launch the game, open **Hit/Kill Sounds** in Mod Settings, verify that the master switch is enabled, and choose your preferred sound sources and HUD style.

> **First-time tip**: Keep the default BF1 audio sources first to confirm hit and kill sounds work cleanly. Both the **Battlefield 4 Text Kill Feed** and **Mourningstar Hub BGM** are disabled by default—enable them whenever you want.

---

## Features and Common Settings

| What you want to adjust | Settings group | Notes |
| --- | --- | --- |
| Master toggle & killstreak window | General Settings | Controls the master switch, independent killstreak counters, reset window (`1.0–3.0s`), and streak cap (`10–30`) |
| BF4 text kill feed & score tally | Battlefield 4-style Text Kill Feed | Off by default; runs standalone (no killstreak needed), with cascade direction, kill-line transform mode, weapon/victim toggles, and layout |
| Ranged & melee hit sounds | Hit Sound Settings | Independent selectors for normal/weakspot and melee normal/weakspot hits, sharing hit volume and cooldown |
| Normal, headshot & melee kill sounds | Kill Sound Settings | Separate normal/headshot sources and volumes, melee kill toggle, plus CF / Valorant killstreak announcements |
| Original game hit/kill sounds | Hit / Kill Sound Settings | Independently keep or mute Darktide's built-in hit and kill sounds |
| DoT, companion & target filters | Matching Sound / Icon / BF4 groups | Separate controls for damage-over-time, companions (Cyber-Mastiff / Servo-Skull), and eligible enemy tiers |
| BFV / BF1 / CF / Valorant icons | Kill Icon Settings | Switch icon style and tune opacity, size, position, colors, duration, and visual effects |
| Mourningstar hub BGM | Custom Mourningstar BGM | Off by default; plays only in the regular Mourningstar hub (`hub`) |
| Your own hit/kill sounds | Sound source dropdowns | Choose **Custom Audio Pack** and place WAV files and playlists in `UserAudio/` |

Hit sounds, kill sounds, kill icons, and the BF4 text feed can all be toggled independently. Ranged and melee hits share one `0.08s` global hit cooldown. Choosing Custom Audio Pack does not bypass target, DoT, companion, melee, or volume settings.

---

## Kill Icons and HUD Feedback

### Battlefield V (BFV) Kill Icons and Text Kill Feedback

Recreates Battlefield V's horizontal kill-icon queue and centered 3-tier score feedback with `512×512` fringe-free Lanczos-3 HD textures (V-notch normal skull, lightning-crack headshot skull, and a dedicated 12-tooth destroy-vehicle gear icon for Boss / Monster / Captain kills).

- **High-impact kinetics & adaptive queue**: 10 main slots + 8 leaving-transition slots + 4 detached shockwave slots, powered by an adaptive staggered multi-kill queue (`0ms` first-kill response, `0.095s → 0.035s` dynamic cadence during horde bursts, priority protection for `Boss > Headshot > Normal`). Features translucent high-scale entry slams (`0.15 → 1.0` scale-coupled opacity + peak micro-hold), headshot (`1.12x`) and Boss (`1.16x` + `45°` spin settle) two-stage micro-rebound, a **settle-triggered single-ring morphing shockwave** (outer-radius-locked bold/thin alpha-preserving cross-fade expanding to `4.15x`, finishing cleanly in place via the detached ripple pool on eviction or handoff), staggered fade-out waves with seamless handoff on new kills, and `54%` max-row-width dynamic spacing compression.
- **Centered 3-tier BFV text kill feedback (on by default, independently toggleable)**: Automatically anchors below the BFV kill icons following their position, scale, opacity, duration, and target filters with screen-edge safety clamping, styled in authentic BFV crisp white with drop shadows:
  1. **Kill main line**: Displays `Victim [Kill Method] +Score` (reusing exact all-class weapon/blitz/ability/DoT/companion attribution; Normal `+100`, Elite `+200`, Special `+250`, Boss `+500`) with horde-adaptive fast-switching.
  2. **Rolling total score**: Large thousand-separated total with smooth rolling catch-up and graceful idle fade-out.
  3. **Bonus lines stack (up to 3 rows)**: Includes **Headshot (`+50`)**, an independent `5.0s` **multi-kill streak bonus** (Double / Triple / Quad / Five / Multi Kill), and an optional **Enemy Hit Score** (`ENEMY HIT +N` scaled by `% max HP` dealt across both non-lethal hits and killing blows, with per-unit credit capping and overkill subtraction so each enemy sums cleanly to `+100` plus a fractional remainder accumulator so light hits on high-HP Bosses never round away; pins at row 1 while firing, drops into the fading stack after `1.5s`, and is fully decoupled from hit-sound toggles).
- **Customization**: Opacity, separate Normal/Headshot/Boss RGB sliders, Boss gear toggle, horizontal/vertical position, icon scale (`0.5–2.0x`), display duration (`1.0–3.0s`), plus BFV text kill feedback toggle, enemy hit score toggle, and text size (`50%–150%`).

### Battlefield 1 (BF1) Kill Icons and Dual-Box Kill Banner

Recreates Battlefield 1's iconic lower-center dual-box kill banner with three `256×256` luminance-normalized pure-white Lanczos-3 textures (classic skull & crossbones, cracked headshot skull, and an 8-tooth rotating Boss gear) for lossless custom RGB tinting.

- **Dual-box banner & all-class kill attribution**: A darker square icon box on the left (with a side status accent bar) pairs seamlessly with a dynamically sized info box on the right displaying the localized victim name, kill method, and right-hand value (defaults to BF1 classic kill score; switchable to target max health, killing blow damage, or hidden). Kill attribution routes by exact `damage_profile` across melee/ranged weapons, weapon-specific explosions (Rumbler, Bolters, Plasma, Force Staffs, Power Mauls, etc.), all classes' blitzes and combat abilities (resolved via native `ArchetypeTalents` localization), DoT types (Bleed/Burn/Soulblaze/Toxin/Electrocution/Corruption), environmental barrels, and Cyber-Mastiff/Servo-Skull companions.
- **Authentic BF1 kinetics & horde-safe priority queue**: Recreates Battlefield 1's signature **vertical center-outward unfold** (`0.13s` `EaseOutQuart`) and **vertical center-inward collapse** (`0.20s`, with font sizes and row spacing compressing into the centerline alongside the card without overflowing, plus smooth mid-exit reopen on chained kills). Right after opening (and on multi-kill refreshes), a **unified 45° left-to-right light sweep** glides cleanly across the entire card—emblem, divider, victim name, weapon, and score—analytically clipped to the card edges at a true 45° angle regardless of banner width and pixel-locked to 3 silhouette-masked emblem sheen atlases with adaptive contrast for pure-white/gold/custom colors (transparent `icon_only` mode automatically shows emblem-silhouette sheen only). Includes headshot two-stage slam with warm-white glow, Boss 8-tooth gear vertical unfold followed by `45°` spin settle and `1.35x` extended hold, plus a cap-4 priority short queue (`Boss > Special > Elite > Headshot > Normal`) that merges rapid low-tier horde kills into an `xN` badge while supporting urgent preemption (`0.08s`) and Boss hold protection (`0.65s`).
- **Customization**: Full Kill Banner / Icon Box Only modes, victim color mode (Classic BF1 Red or enemy tier), Boss gear toggle, banner background opacity, Normal/Headshot/Boss RGB sliders, plus BFV-aligned opacity, horizontal/vertical position, size (`0.5–2.0x`), and display duration (`1.0–4.5s`).

### Battlefield 4 (BF4)-Style Text Kill Feed and Score Tally

Enable directly under **Battlefield 4-style Text Kill Feed**—**no killstreak switch, sound switch, or icon switch is required**. Recreates Battlefield 4's borderless top-down cascading feed, two-stage terminal typewriter transform, and large frost-white cumulative score tally.

- **Top-down cascade (default)**: Newest kills appear at the top anchor, same-batch bonuses (Headshot Bonus, Multi Kill) cascade underneath, and older batches smoothly slide downward with positional depth fade (`3.5–5.8` lines). On idle expiry, rows peel off bottom-up with staggered timing; a `Bottom-Up` direction option is also available.
- **Authentic two-stage typewriter transform (default)**: Kill main lines type out the event confirmation first (e.g., `SPECIAL KILLED 250`, held for `0.60s`), rapidly backspace-erase over `0.08s`, and then continuously type left-to-right into cool frost-white `[Weapon / Kill Method]` + bright BF4 red `Victim Name` (`~0.22s`, while the right-hand score stays rock solid). Also supports typewriter-enabled `Direct` and `Classic` modes plus independent weapon/victim toggles, sharing BF1's exact all-class blitz/ability/weapon-explosion/DoT/companion attribution.
- **No-plus-sign scores & optional multikill bonus**: Single-row and cumulative values remain authentic plain integers without `+` (Normal `100`, Elite `200`, Special `250`, Boss `500`, Headshot Bonus `50`). Turning on **Independent Killstreak Counters** appends `MULTI KILL` rows; turning it off keeps the base kill feed, weapon/victim details, and headshot bonuses running normally. The tally features a subtle cyan glow, two-stage elastic punch (`1.0 → 1.24 → 1.0`), dynamic horizontal clearance, and synchronized exit with the final row.
- **Note**: Displayed points are HUD-only and do not alter official mission rewards or results. If the game's own combat feed is enabled, duplicate notifications may appear.

### CrossFire (CF) Killstreak Announcements and Icons

Turn on **Enable Independent Killstreak Counters** under **General Settings**. In **Kill Sound Settings**, set **Killstreak Sound Style** to `CF` (with kill sounds enabled) and pick **Male** or **Female** under **CF Kill Voice**. For CF icons, set **Kill Icon Style** to `CF` under **Kill Icon Settings**. Sounds and icons can be mixed freely (e.g. CF announcements + BFV/BF1 icons).

- **Male & Female voices**: Male plays kills 1–9 sequentially and repeats kill 9 from kill 10 onward; Female plays kills 1–8 and repeats its normal first-kill clip from kill 9 onward. Switching voices carries over the current streak count.
- **Headshots & Bosses**: A first-kill headshot plays the selected voice's dedicated headshot clip (falling back to normal kill 1 if missing or if "Use Normal Sound for Headshots" is enabled). Boss kills play the Boss clip without interrupting the ordinary streak count.
- **Icons & limits**: Displays kill 1–6 icons (plus gold headshot on first-kill headshots), repeating the highest tier beyond that. Streak limit defaults to `13` (`10–30`) and reset window defaults to `2.0s` (`1.0–3.0s`). Active CF announcements take priority over ordinary kill sound sources, including Custom Audio Pack.

### Valorant Killstreak Sounds and HUD

Turn on **Enable Independent Killstreak Counters** under **General Settings**, set **Killstreak Sound Style** to `Valorant` in **Kill Sound Settings**, and/or set **Kill Icon Style** to `Valorant` in **Kill Icon Settings**.

- **Audio & HUD**: Includes kill 1–5 sounds, first-kill appearance audio, streak transitions, and an independently toggleable UI accompaniment layer. Past kill 5, resources repeat kill 5 while the counter continues to the general `cf_killstreak_max` limit; Boss kills count normally.
- **Visual options**: Classic Skull and Standard X-Wing emblem styles, tangent kill 1–5 arc segments, headshot particle toggle, plus opacity, size, and horizontal/vertical position sliders.

> **Independent counters**: BF4 multikills, CF sounds, CF icons, Valorant sounds, and Valorant icons each maintain separate counters and target filters—they do not need to stay synchronized.

---

## Supported Sound Sources

| Game source | Normal hit | Weakspot / Headshot hit | Normal kill | Headshot kill |
| --- | :---: | :---: | :---: | :---: |
| Battlefield 1 (default) | 5 variants | 5 variants | 1 | 1 |
| Battlefield 2042 | 24 variants | 13 variants | 6 variants | 13 variants |
| Battlefield 6 | 28 variants | 8 variants | 6 variants | 8 variants |
| Battlefield V | 12 variants | 5 variants | 1 | 10 variants |
| Call of Duty: Black Ops 4 (BO4) | 1 | 1 | 3 variants | 5 variants |
| Call of Duty: Black Ops 6 | 2 variants | 1 | 1 | 3 variants |
| Call of Duty: Black Ops 7 (BO7) | 3 variants | 3 variants | 3 variants | 1 |
| Call of Duty: Black Ops Classic (BO Classic) | 1 | Shared with normal hit | — | — |
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
| Custom Audio Pack (Custom) | Up to 20 | Up to 20 | Up to 20 | Up to 20 |

Notes: `→ normal` falls back to that source's normal pool for headshots; `—` marks an unavailable category. Multi-variant pools pick one clip at random. **BO4 / BO7 / BO Classic** work for both ranged and melee hits; **BO4 / BO7** also support normal and headshot kills.

---

## Custom Hit and Kill Sounds (UserAudio)

**No Lua editing is needed.** Replace a default WAV for a quick setup, or edit a playlist to randomize multiple clips (plain-text guides are also bundled in `UserAudio/README_Custom_Audio.txt`). All paths below are relative to `Hit_Kill_Sounds/`:

```text
UserAudio/
├─ README_自定义音频.txt      Chinese plain-text guide (v1.5.8)
├─ README_Custom_Audio.txt  English plain-text guide (v1.5.8)
├─ BGM/
│  └─ tracks.txt            BGM playlist (comments only by default)
├─ Hit/
│  ├─ Normal.wav            Default normal hit (built-in BFV copy)
│  ├─ Headshot.wav          Default weakspot hit (built-in BFV copy)
│  ├─ normal/               Optional extra normal hit WAVs
│  ├─ headshot/             Optional extra weakspot hit WAVs
│  └─ playlist.txt          Hit playlist
└─ Kill/
   ├─ Normal.wav            Default normal kill (built-in BFV copy)
   ├─ Headshot.wav          Default headshot kill (built-in BFV copy)
   ├─ normal/               Optional extra normal kill WAVs
   ├─ headshot/             Optional extra headshot kill WAVs
   └─ playlist.txt          Kill playlist
```

### Method 1: Replace a Default WAV (Recommended for Beginners)

1. **Fully exit the game** and back up the original `Normal.wav` / `Headshot.wav`.
2. Export your sound as a real **WAV** file (PCM 16-bit, 48 kHz, mono or stereo recommended; renaming an MP3 to `.wav` does not convert it).
3. Overwrite the matching file under `UserAudio/Hit/` or `UserAudio/Kill/`, keeping the filename and location unchanged (default playlists are already configured).
4. Start the game and choose **Custom Audio Pack** in any of the 6 audio source dropdowns, verifying switches and volume.

> Enable **View → Show → File name extensions** in Windows Explorer to avoid double extensions such as `Normal.wav.wav` or `playlist.txt.txt`.

### Method 2: Add Multiple Randomized Sounds via Playlist

Place WAV files inside `UserAudio`, then edit `UserAudio/Hit/playlist.txt` or `UserAudio/Kill/playlist.txt` in Notepad using `category|relative path from UserAudio` (category must be `normal` or `headshot`; folder names do not determine category):

```text
# Hit playlist example: UserAudio/Hit/playlist.txt
normal|Hit/Normal.wav
normal|Hit/normal/metal_01.wav
headshot|Hit/Headshot.wav
headshot|Hit/headshot/headshot_soft.wav
```

```text
# Kill playlist example: UserAudio/Kill/playlist.txt
normal|Kill/Normal.wav
normal|Kill/normal/kill_01.wav
headshot|Kill/Headshot.wav
headshot|Kill/headshot/headshot_01.wav
```

| Common task | How to do it |
| --- | --- |
| Add a sound | Place a real WAV inside `UserAudio` and append a `normal\|...` or `headshot\|...` line |
| Temporarily disable | Prefix the whole line with `#` (e.g. `# normal\|Hit/Normal.wav`) |
| Delete permanently | Remove or comment out the playlist line first, then delete the audio file |

### Playlist Rules and Fallback

- Save playlists as **UTF-8 plain text** (BOM allowed). Blank lines and whole-line `#` comments are ignored; inline comments are not supported; max file size is 64 KiB.
- Use `/` without quotes. Only paths relative to `UserAudio` are accepted—absolute paths, drive letters, `..`, wildcards, and symlinks/junctions are rejected.
- Each SFX category loads up to the first **20 valid paths**, deduplicated case-insensitively (duplicates do not increase probability).
- **Fallback chain**: Empty Custom weakspot/headshot pool → Custom normal pool of the same type → built-in BFV pool (hit and kill pools never mix, and Custom fallback never adds BFV's extra headshot tail).
- Always **fully exit and restart the game** after changing audio files or playlists (manifests are cached on initialization).

---

## Mourningstar Hub BGM

Turn on the toggle under **Custom Mourningstar BGM** (off by default). Volume ranges from `0–100`, updates live without restarting the current track, and follows the game's master and music volume. BGM plays **only in the regular Mourningstar hub (`hub`)**—never in missions, menus, the Psykhanium, or `prologue_hub`.

- **Default tracks**: `UserAudio/BGM/tracks.txt` contains comments only by default, so the original six `audio/BGM/Lobby_BGM1.mp3`–`Lobby_BGM6.mp3` tracks play randomly.
- **Use your own MP3s**:
  1. Fully exit the game and place real MP3 files into `UserAudio/BGM/`.
  2. Edit `UserAudio/BGM/tracks.txt` with one path relative to `UserAudio` per line (no `normal|`/`headshot|` label):
     ```text
     # Relative to UserAudio
     BGM/My_Lobby_Track.mp3
     BGM/Another_Track.mp3
     ```
  3. Save as UTF-8, restart the game, and enable the BGM switch (no need to select Custom in any SFX dropdown). Loads up to 20 tracks and avoids immediate repeats.

| Playlist / runtime condition | Behavior |
| --- | --- |
| At least 1 valid custom MP3 | UserAudio playlist takes priority (not mixed with the default six) |
| Missing, empty, or all-invalid manifest | Falls back to the default six hub tracks |
| One custom track fails to start | Automatically tries another valid track in the playlist |
| Every custom track fails or playback unavailable | Restores official hub music automatically—never stays muted |

Leaving the hub, starting a mission, disabling BGM/master switches, or unloading the Mod smoothly fades out custom BGM and restores official music. To return to the default six tracks, clear or comment out `tracks.txt` and restart the game.

---

## Troubleshooting and Update Backups

| Problem | Check these first |
| --- | --- |
| No hit or kill sounds | Check master/sound toggles, volume, target/DoT/companion/melee filters, and `SimpleAudio` load order |
| Custom sounds like built-in audio | Invalid playlist entry, label, or file format triggered BFV fallback—check logs and real WAV format |
| Custom kill sound replaced by CF/Valorant | **Killstreak Sound Style** is active; set it back to `Off` to test normal kill sources |
| File or playlist edits do nothing | **Fully exit and restart the game**; check UTF-8 encoding and duplicate extensions like `.wav.wav` |
| No kill icons | Check `SimpleAssets` load order, Kill Icon toggle, and Kill Icon target filter |
| CF / Valorant killstreak features inactive | Enable **Independent Killstreak Counters** in General Settings, then check style and target filters |
| BF4 text feed does not appear | Check master toggle, BF4 text feed toggle, and BF4 target filter (**no killstreak required**; only Multi Kill rows use it) |
| Hub BGM plays old six tracks or official music | Confirm regular `hub`, valid MP3 entries in `tracks.txt`, and `SimpleAudio` status; playback failures intentionally restore official music |

> **Back up your audio before updating**: Fully exit the game and copy `UserAudio/` outside the game directory before updating or using a mod manager, then copy it back afterward. Never store personal audio inside `scripts/`.

---

## Backend and Technical Notes

- **Dependencies**: Audio uses **SimpleAudio** and icons use **SimpleAssets**. The legacy HTTP player remains only as an SFX compatibility fallback; release packages with SimpleAudio + SimpleAssets do not need `bin/`. Hub BGM always uses SimpleAudio.
- **Concurrency & queue**: HKS caps its own short-sound concurrency at 5 hit, 5 kill, and 10 total active voices (pending queue 10, max wait `0.12s`, up to 2 dispatches per frame, `0.03s` min interval) without limiting SimpleAudio globally or BGM.
- **v1.5.8 validation**: New `Hit_Kill_Sounds_bf5_text.lua` and all modified Lua files (`Hit_Kill_Sounds_hud.lua`, `Hit_Kill_Sounds_bf1_hud.lua`, `Hit_Kill_Sounds_assets_backend.lua`, `Hit_Kill_Sounds.lua`, `Hit_Kill_Sounds_data.lua`, `Hit_Kill_Sounds_localization.lua`, `Hit_Kill_Sounds_events.lua`) pass `luacheck` with 0 errors and 0 new warnings plus a full-mod LuaJIT 60-upvalue safety audit across all 17 Lua files; alpha-preserving single-ring morph math, fractional Boss hit-score accumulation, BF1 full-card 45° collinear sheen & exit text compression curves, and screen-edge clamp bounds are verified alongside in-game BFV and BF1 testing.

---

## Asset Sources and Acknowledgments

Built-in sounds and icons remain the property of their respective rights holders. The four default UserAudio WAVs are copies of built-in BFV sounds; no UserAudio BGM placeholder is bundled.

- **Battlefield sounds & BFV kill icons**: EA / DICE
- **Call of Duty sounds**: Activision
- **The Finals sounds**: Embark Studios
- **Overwatch sounds**: Blizzard Entertainment
- **BF1 kill icons/banner, BFV destroy-vehicle Boss icon & Valorant icon/animation references**: [gd656killicon](https://github.com/MinecraftGD656/gd656killicon)
- **Multi-game hit & kill sounds**: Extracted from [Custom Hitmarker](https://mod.io/g/drg/m/custom-hitmarker)
- **CF killstreak concept**: Ported from EBuyToDeep_KillFeedBack
- **Special thanks**:
  - **BiliBili UP EBuyToDeep** ([Profile](https://space.bilibili.com/1273948298)): For the original external audio player concept and killstreak inspiration that made this mod possible.
  - **deluxghost** ([Profile](https://space.bilibili.com/4712698)): For **SimpleAudio + SimpleAssets**, allowing this mod since v1.2 to remove external executable dependencies.
  - **BiliBili UP 博学橘耄** ([Profile](https://space.bilibili.com/321884781)): Special thanks for graciously granting permission to reference the BFV kill feedback animation and text kill feedback code from their Helldivers 2 mod [BFV Hit and Kill Feedback](https://www.nexusmods.com/helldivers2/mods/16927).

---

## Usage and Copyright

This Mod is provided for educational and personal use. Before replacing, sharing, or redistributing personal audio, verify that you hold the appropriate permissions—do not redistribute unauthorized commercial audio with the Mod.

---

## Changelog

### v1.5.8

- **Battlefield V (BFV) kill icon animation overhaul**:
  - **High-impact translucent entry kinetics**: Upgraded normal (`2.60x`), headshot (`3.15x`, steady `1.12x`, `0.92x` rebound), and Boss (`3.45x`, steady `1.16x`, `0.89x` rebound + preserved `-45°` spin settle) entry curves with peak micro-hold and `0.15 → 1.0` scale-coupled opacity, removing redundant impact white flash.
  - **Settle-triggered single-ring thinning shockwave + detached ripple pool**: Shockwaves now ignite at the exact landing settle frame; bold and thin ring textures share the identical real-time scale (`0.96x → 4.15x`) with exact alpha-preserving cross-fade so they read as one continuously thinning shockwave rather than two separate rings; added a 4-slot detached ripple pool so evicted/handed-off rings finish smoothly in place.
  - **Adaptive staggered multi-kill queue & fade wave**: Added a 24-slot priority-protected adaptive stagger queue (`0ms` first-kill spawn, `0.095s → 0.035s` cadence under horde bursts, protecting `Boss > Headshot > Normal`) while keeping `SimpleAudio` dispatch zero-delay; idle exit now peels left-to-right in a staggered fade wave, an expanded 8-slot leaving pool hands off fading rows cleanly without pop-out when new kills arrive, and dynamic row spacing compresses safely within `54%` screen width.
- **Battlefield V (BFV) centered 3-tier text kill feedback & enemy hit score**:
  - Added `Hit_Kill_Sounds_bf5_text.lua` and integrated 5 native `text` widgets directly into `HudHitKillICON`, locked to BFV icon position, scale, opacity, and duration with horizontal/bottom edge clamping; added `bf5_text_feedback_enabled` (on by default), `bf5_hit_score_enabled` (on by default), and `bf5_text_scale` (`50%–150%`) under `icon_settings_bf5`.
  - Recreated BFV's crisp white 3-tier layout: **Kill main line** (`Victim [Kill Method] +Score` reusing all-class attribution and horde-adaptive fast-switching), **thousand-separated rolling total score**, and a **3-row bonus stack** (Headshot `+50`, independent `5.0s` Double/Triple/Quad/Five/Multi Kill streaks, plus an optional `% max HP` enemy hit score covering both non-lethal hits and killing blows / one-shots with overkill subtraction and a fractional remainder accumulator for high-HP Bosses, decoupled from hit-sound toggles).
- **Battlefield 1 (BF1) kill icon & banner animation authenticity upgrade**:
  - **Vertical center-outward unfold/collapse & synchronized exit text compression**: Rebuilt entry and exit kinetics in `Hit_Kill_Sounds_bf1_hud.lua`, replacing uniform box scaling, downward exit drift, and full-box entry flash with center-anchored vertical scale unfolding (`0.13s`, `EaseOutQuart`) and vertical collapsing (`0.20s`, `open_y = 1 - t^2.4`). Banner text and combo badge font sizes and row spacing compress smoothly into the centerline alongside the closing card before fading out cleanly, mid-exit kills smoothly reopen from the current aperture height, and the 8-tooth Boss gear unfolds/collapses cleanly along the vertical axis (`0°`) before spinning `-45°`.
  - **Unified full-card 45° left-to-right light sweep**: Added `BF1/bf1_card_sheen.png` and three 16-frame silhouette-masked sheen atlases (`kill_default_sheen_atlas.png`, `kill_headshot_sheen_atlas.png`, `kill_boss_sheen_atlas.png`). Analytically clipped `texture_uv` sweeping maintains a true 45° angle across any banner width with zero border overflow, sweeping continuously across both the emblem and text while adaptive base contrast keeps pure-white skulls gleaming; transparent `icon_only` mode automatically displays emblem-silhouette sheen only.
- **Darktide UI optimizations & cross-match leak fix**: Eliminated per-frame Lua table allocations in `Hit_Kill_Sounds_hud.lua`, gated `_update_scenegraph` to dirty frames only, unified 3-state async texture loading (with `on_settled` callback & `is_ok` check in `Hit_Kill_Sounds_assets_backend.lua`) plus `destroy` & hub cleanup across both BFV and BF1, and consolidated BF1 constants into a `CFG` table to stay well within LuaJIT's 60-upvalue per-function limit; fixed `HKS.on_game_state_changed` to handle Darktide's real state names (`StateGameplay` / `GameplayStateRun` / `StateLoading` / `StateVictoryDefeat` / `StateGameScore`, etc.) and added `clear_kill_state()` to `HKS.on_disabled`, preventing leftover kill text from carrying over into the next mission.
- **Cross-type weapon special attack kill attribution fix (shared by BF1 / BF4 / BF5)**: Fixed `resolve_kill_weapon_name` in `Hit_Kill_Sounds_events.lua` unconditionally overriding the weapon slot based solely on `attack_type`—kills now first match `damage_profile.name` directly against the equipped primary and secondary `weapon_template`s (weak-key cached across `actions`, `shotshell`, `hit_scan_template`, `projectile_template`, `explosion_template`, and `weapon_special_tweak_data`), with fallback preserving the active weapon slot when inconclusive. Fixes ranged weapons' melee special attacks (e.g. Double-Barreled Shotgun bash, bayonets, Ogryn Grenadier Gauntlet melee punches, Force Staff/Bolter bashes) displaying the melee weapon in kill text, while also handling melee weapons' non-melee specials (Dual Shivs throw, Blaze Force Greatsword warp slash, Shock Maul/Shield `weapon_shout`) and quick weapon-swaps after firing.

### v1.5.7

- **Battlefield 1 (BF1) kill icon style & dual-box kill banner HUD**: Added `Hit_Kill_Sounds_bf1_hud.lua` and three `256×256` luminance-normalized pure-white Lanczos-3 textures (`BF1/kill_default.png`, `BF1/kill_headshot.png`, `BF1/kill_boss.png`) for lossless custom RGB tinting; implemented elastic icon-box pop-in + horizontal info-box reveal, headshot two-stage slam with warm-white flash and glow, Boss 8-tooth gear `45°` spin with `1.35x` extended hold, a cap-4 high-value priority queue (`Boss > Special > Elite > Headshot > Normal`) with `xN` horde merging and Boss hold protection, plus Full Banner / Icon Only modes and full BFV-aligned customization.
- **Battlefield V (BFV) Boss destroy-vehicle gear icon**: Added `512×512` pure-white flat 12-tooth gear texture `BFV/kill_boss.png` and upgraded BFV's main icon pass to `rotated_texture`; Boss / Monster / Captain kills trigger a `1.06x` heavy slam rebound, `45°` spin settle, warm-white flash, and Boss-tinted dual shockwave rings, configurable via `bf5_boss_icon_enabled` and Boss RGB sliders (default crimson `220, 46, 38`).
- **Battlefield 4 (BF4) text kill feed overhaul**:
  - Switched default layout to `top_down` cascade (`bottom_up` kept as an option) with newest kills at the top anchor, same-batch bonuses cascading below, older batches sliding down with positional depth fade (`3.5–5.8` lines), and bottom-up staggered idle clear. Upgraded the cumulative tally with a dual-pass cyan glow, two-stage elastic punch (`1.0 → 1.24 → 1.0`), dynamic horizontal clearance, and synchronized exit with the final row.
  - Upgraded each row to 3 independent text passes (`prefix`, `victim`, `score`) and implemented BF4's authentic two-stage typewriter transform (`0.00–0.60s` event typewriter reveal → `0.60–0.68s` rapid backspace-erase → `~0.22s` continuous left-to-right typewriter reveal of cool-white `[Weapon / Kill Method]` + bright BF4 red `Victim Name` with rock-solid score), alongside typewriter-enabled `Direct` and `Classic` modes and independent weapon/victim toggles; scores remain authentic plain integers without `+`.
  - Decoupled from `killstreak_enabled`: runs standalone when killstreak is off (omitting `MULTI KILL` rows), with tally hold driven directly by `bf4_feed_duration`.
- **Accurate all-class blitz & combat ability kill attribution (shared by BF1 & BF4)**: Built a native `ArchetypeTalents` ability-name lookup in `Hit_Kill_Sounds_events.lua` and routed kill attribution by exact `damage_profile.name` across all classes' grenades/blitzes, combat abilities, weapon-specific explosions (Bolters, Rumbler, Plasma, Force Staffs, Power Mauls, etc.), and map barrels—fixing grenade and ability kills showing the currently held or equipped ranged weapon.
- **Backend & documentation updates**: Added `load_bf1_icons` and optional BFV `kill_boss.png` loading to `Hit_Kill_Sounds_assets_backend.lua`; refreshed both README files and bumped both `UserAudio` plain-text guides to `v1.5.7`.

<details>
<summary>Expand older version history (v1.5.6 – v0.9)</summary>

### v1.5.6

- **BFV HD kill icon upgrade**: Replaced BFV icons with Lanczos-3 resampled `512×512` fringe-free HD textures (`kill_normal.png`, `kill_headshot.png`, `kill_circle_bold.png`, `kill_circle_thin.png`, plus a `kill_circle.png` compatibility copy) with unified silhouettes and `16px` safety padding.
- **Dual-ring morphing headshot shockwave**: Upgraded `circle_icon` to a concentric dual-pass widget handing off from an inner bold ring (`0.00–0.24s`) to an outer thin ring (`0.00–0.40s`) to recreate BFV's stroke-thinning shockwave.
- **Impact kinetics & sub-pixel centering**: Tuned normal (`0.16s`) and headshot (`+4%`, `0.18s` micro-rebound + warm-white flash) animations, switched to floating-point sub-pixel centering to eliminate 1px jitter, and fixed fade-out queue contraction.

### v1.5.5

- **Valorant kill feedback**: Added Valorant kill sounds, HUD icons, particle effects, and UI-layer accompaniment sounds (7 audio files, 14 icon assets).
- **Independent counters & customization**: Separate Valorant sound/icon counters sharing `cf_killstreak_max`, Classic Skull & Standard X-Wing emblem styles, tangent kill 1–5 arc segments, and legacy CF config migration.

### v1.5.4

- **BO4 / BO7 / BO Classic**: Added BO4 hit/kill variants, BO7 hit/headshot kill updates, and BO Classic shared hit audio.
- **CF female voice**: Added a female announcer option (Male default) that preserves streak count on switch and repeats kill 1 from kill 9 onward.

### v1.5.3

- **Native hit-sound muting**: Fixed missing coverage for prefix-less `melee_hits` / `melee_hits_*` events.
- **BGM unload & reload recovery**: Persisted failed official `music_zone` restoration retries across DMF reloads and paused custom BGM while recovery is pending.

### v1.5.2

- **Custom Audio Packs & BGM manifests**: Added `Custom` to 6 audio dropdowns with default BFV WAV copies and explicit playlists (up to 20 per category), safe fallbacks, and custom hub BGM playlists.
- **High-fire-rate tuning**: Raised HKS short-sound voice limits to 5 hit / 5 kill / 10 total and committed hit cooldown only after queue admission.

### v1.5.1

- **BFV / CF / BF4 refinements**: Separated BFV headshot metallic resonance tail for 0ms dual-track playback, fixed leaving-slot decay, normalized CF gold headshot sizing (`0.75x`), moved BF4 tally to an independent right column, and added HUD idle short-circuits plus micro fade-outs on voice stop.

### v1.5.0

- **Lifecycle & filters**: Finalized BFV 10-slot eviction, CF default window fade and Boss boundaries, BF4 batch multikill bonuses, `kill_melee_sound_enabled`, and exclusion of `damage <= 0` push/stagger hit sounds.

### v1.4.7

- **1.13.2 compatibility**: Completed native hit-mute coverage, preserved zero-damage toughness hits, switched electrocution DoT to exact profile matching, and excluded player/prop kill feedback.

### v1.4.5

- **Servo-skull & chain lightning**: Wired Servo-Skull laser/initial flamer hits into companion toggles and muted chain-lightning loop start events when native hit sounds are off.

### v1.4.2

- **Three independent streak counters**: Split BF4 text, CF sound, and CF icon counters and target filters; removed shared `killstreak_target`.

### v1.4.1

- **Historical note**: Trial shared `killstreak_target` counter for CF sounds/icons; removed in v1.4.2.

### v1.4

- **Added Battlefield 4-style text kill feed**: Introduced independent BF4 settings, scoring, fixed 8-slot HUD, and lifecycle guards.

### v1.35

- **SimpleAudio burst stability & generic killstreak**: Added queued voice dispatch, multi-instance track caps, and the general killstreak switch.

### v1.3

- **Added CODBO7 kill sounds & Mourningstar hub BGM**: Added 6-track hub-only BGM with safe official-music restoration.

### v1.25

- **Backend & Wwise improvements**: Prioritized SimpleAudio with on-demand legacy fallback, forwarded Wwise varargs intact, and added headshot normal-sound/volume options plus CF first-kill headshot audio.

### v1.2

- **Migrated to SimpleAudio + SimpleAssets**: Removed mandatory `bin` external player dependency and standardized cross-mod asset paths.

### v1.1

- **Added CF killstreak system**: Ported from EBuyToDeep_KillFeedBack with style switching, decoupled sound/icon controls, independent icon target filter, and reorganized DoT/companion toggles.

### v1.05

- Added Warzone, Warzone 2, Delta Force, and Apex Legends sources; added 3 companion toggles; patched v1.12.0+ native hit-mute Wwise patterns.

### v1.0

- Split normal/headshot hit, normal/headshot kill, and melee hit into 6 independent source dropdowns; fixed DMF `<>` dropdown label wrapping.

### v0.97

- Fixed missed DoT detection across all DoT types and decoupled DoT kill sound vs. kill icon toggles.

### v0.96

- Added Wwise hooks to mute native hit and kill sounds on demand.

### v0.95

- Fixed master switch enforcement, split Hit/Kill settings groups, and added icon opacity slider.

### v0.92 – v0.9

- Rewrote kill icons into a 10-slot queue with horizontal position and duration controls; added Cold War, Vanguard, and Overwatch sounds.

</details>
