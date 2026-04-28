# Hit/Kill Sounds v0.8

A Darktide mod that plays hit and kill sounds from various games when you damage or kill enemies.

## Features

- **Hit Sounds**: Play different sounds when hitting enemies (normal hit vs weakspot hit)
- **Kill Sounds**: Play different sounds when killing enemies (normal kill vs headshot kill)
- **Random Selection**: Multiple sound variants for each type, randomly selected
- **Sound Cooldown**: Prevents sound spam from fast-firing weapons
- **DoT Support**: Optional hit and kill sounds for damage-over-time effects (bleed, burn, etc.)
- **Melee Toggle**: Option to enable/disable melee weapon hit sounds
- **Target Filtering**: Filter sounds to only play for specific enemy types (Elite, Special, Boss)
- **Volume Control**: Adjust volume independently for hit and kill sounds (0-100)
- **Multiplayer Support**: Works correctly in both single-player and multiplayer modes

## Changelog

### v0.8
- **Bug Fix**: Fixed issue where kill sounds could play multiple times when killing an enemy
- **New Feature**: Added DoT kill sound toggle
- **New Feature**: Added melee weapon hit sound toggle
- **Code Cleanup**: Removed deprecated code and simplified core logic

## Supported Sound Sources

| Game | Normal Hit | Headshot Hit | Normal Kill | Headshot Kill |
|------|------------|--------------|-------------|---------------|
| Battlefield 1 | 5 variants | 5 variants | 1 | 1 |
| Battlefield 2042 | 24 variants | 13 variants | 6 variants | 13 variants |
| Battlefield 6 | 28 variants | 8 variants | 6 variants | 8 variants |
| Battlefield V | 12 variants | 5 variants | 1 | 10 variants |
| Call of Duty: Black Ops 6 | 2 variants | 1 | 1 | 3 variants |
| Call of Duty: MW 2019 | 1 | 1 | 1 | 1 |
| Call of Duty: MW 3 | 1 | 1 | 1 | 1 |
| The Finals | 3 variants | 5 variants | 1 | 1 |

## How It Works

This mod uses the AttackReportManager Hook to capture attack events:

1. **AttackReportManager Hook**: Captures attack events through the game's networking system, supporting both single-player and multiplayer modes

The mod processes attacks through the following flow:
- Intercept damage events via hooks
- Determine if it's a hit (normal/weakspot) or kill (normal/headshot)
- Apply DoT and melee weapon filtering based on settings
- Apply target filtering based on enemy type
- Play the appropriate sound through an external audio player

An external audio player (HitKillSoundsPlayer) handles sound playback via HTTP requests, allowing for multi-channel audio support (separate channels for hit and kill sounds).

## Installation

1. Download the mod and place it in your Darktide mods folder
2. Enable the mod in the game's mod menu
3. Configure your preferred sound source and volume in the mod settings

## Requirements

- Darktide with mod support enabled
- HitKillSoundsPlayer (bundled with this mod)

## Sound Sources

All hit and kill sounds are from their respective games and are used for modding/educational purposes:

- Battlefield series sounds from EA/DICE games
- Call of Duty series sounds from Activision
- The Finals sounds from Embark Studios

## Acknowledgments

- **BiliBili UP EBuyToDeep** ([https://space.bilibili.com/1273948298](https://space.bilibili.com/1273948298)): For providing the external audio player solution that made this mod possible. The HitKillSoundsPlayer application is based on the concept from their EBuyToDeep_KillFeedBack mod.

## License

This mod is provided for educational and personal use only. All sound files remain the property of their respective copyright holders.
