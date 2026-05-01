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
  - Normal icon color (RGB)
  - Headshot icon color (RGB)
  - Horizontal position (0=left, 50=center, 100=right)
  - Vertical position (0=top, 100=bottom)
  - Display duration (1.0s - 3.0s)

Icon assets: Battlefield V kill icons

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

## How It Works

This mod hooks `AttackReportManager:add_attack_result` to capture attack events:

- Intercept player damage/kill events
- Determine if it's a hit (normal/weakspot) or kill (normal/headshot)
- Apply target filtering based on enemy type
- Play the appropriate sound through an external audio player
- Call HUD system to display kill icons

An external audio player (HitKillSoundsPlayer) handles sound playback via HTTP requests, supporting multi-channel audio (separate channels for hit and kill sounds).

The kill icon system preloads textures and manages a queue of 10 slots. New kills trigger entry animations that push old icons left.

## Installation

1. Download the mod and place it in your Darktide mods folder
2. Enable the mod in the game's mod menu
3. Configure your preferred sound source and volume, as well as kill icon options in the mod settings

## Requirements

- Darktide with mod support enabled
- HitKillSoundsPlayer (bundled with this mod)

## Sound & Asset Sources

All hit and kill sounds are from their respective games and are used for modding/educational purposes:

- Battlefield series sounds and icons from EA/DICE games
- Call of Duty series sounds from Activision
- The Finals sounds from Embark Studios
- Overwatch sounds from Blizzard Entertainment
- Kill icon assets from EA/DICE Battlefield V

## Acknowledgments

- **BiliBili UP EBuyToDeep** ([https://space.bilibili.com/1273948298](https://space.bilibili.com/1273948298)): For providing the external audio player solution that made this mod possible. The HitKillSoundsPlayer application is based on the concept from their EBuyToDeep_KillFeedBack mod.

## License

This mod is provided for educational and personal use only. All sound files and icon assets remain the property of their respective copyright holders.

## Changelog

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
