Hit/Kill Sounds Mod
UserAudio Custom Audio Guide
For v1.5.7

1. Important things to know

1. You do not need to edit any Lua file.
2. You do not need a file picker or numbered files such as 01, 02 and 03.
3. Fully exit and restart the game after changing audio files or playlists.
4. Hit and kill sounds use WAV files. BGM uses MP3 files.
5. The file must really be a WAV or MP3. Renaming a file extension is not conversion.
6. Use only audio that you are allowed to use. Do not redistribute commercial music or game audio without permission.

2. Where the UserAudio folder is

The UserAudio folder is located at:
Hit_Kill_Sounds/UserAudio/

Its current structure is:

BGM/
  tracks.txt

Hit/
  Normal.wav
  Headshot.wav
  playlist.txt
  normal/
  headshot/

Kill/
  Normal.wav
  Headshot.wav
  playlist.txt
  normal/
  headshot/

The four default SFX files are copies of sounds already included in this Mod:
Hit/Normal.wav is the normal hit sound.
Hit/Headshot.wav is the weakspot or headshot hit sound.
Kill/Normal.wav is the normal kill sound.
Kill/Headshot.wav is the headshot kill sound.

There is no default Lobby.mp3 in the BGM folder. tracks.txt contains comments only, so the Mod uses the original six lobby music files by default.

3. Beginner method: replace one hit or kill sound

1. Fully exit Darktide.
2. Open the UserAudio/Hit or UserAudio/Kill folder.
3. Copy the original Normal.wav or Headshot.wav to a safe place as a backup.
4. Use an audio editor to export your sound as a real WAV file.
5. Replace the matching Normal.wav or Headshot.wav. Keep the same name and folder.
6. Start the game.
7. In the Hit Sound Settings or Kill Sound Settings, select this source:
   Custom Audio Pack
8. For melee hits, also make sure the melee hit switch is enabled.
9. To use a custom BGM, enable the Mourningstar BGM switch.
10. Fully exit and restart the game after making the change.

PCM WAV, 16-bit, 48 kHz, mono or stereo is recommended. This is easier for the audio backend to read, but the result still needs to be tested in the game.

4. Advanced method: add more sounds

You can put new WAV files in these folders:

Normal hits: UserAudio/Hit/normal/
Weakspot hits: UserAudio/Hit/headshot/
Normal kills: UserAudio/Kill/normal/
Headshot kills: UserAudio/Kill/headshot/

Then open the matching playlist with Notepad:

Hit playlist: UserAudio/Hit/playlist.txt
Kill playlist: UserAudio/Kill/playlist.txt

Every SFX playlist line must use this format:
category|path relative to UserAudio

Hit example:
normal|Hit/Normal.wav
normal|Hit/normal/metal_01.wav
normal|Hit/normal/metal_02.wav
headshot|Hit/Headshot.wav
headshot|Hit/headshot/headshot_soft.wav

Kill example:
normal|Kill/Normal.wav
normal|Kill/normal/kill_01.wav
headshot|Kill/Headshot.wav
headshot|Kill/headshot/headshot_01.wav

The category must be normal or headshot. The Mod does not guess the category from the folder name.

5. Add, replace or disable an audio file

To add audio:
1. Put a real WAV file in the correct UserAudio folder.
2. Add one line to the matching playlist.
3. Save the file and restart the game.

To replace audio:
Change a playlist path to another valid WAV file, then save and restart the game.

To disable one entry without deleting the file:
Put a hash character at the beginning of the whole line. Example:
# normal|Hit/normal/metal_01.wav

You can also delete the line. Deleting a playlist line does not delete the audio file.

To remove an audio file completely:
First remove or comment out its playlist line. Then delete the audio file.

Playlist order does not increase playback probability. Valid entries in the same category are selected randomly.

6. Add custom BGM

There is no default BGM placeholder in UserAudio. Prepare your own real MP3 file and put it in:
UserAudio/BGM/

Then open:
UserAudio/BGM/tracks.txt

Write one path relative to UserAudio on each line. Example:

# relative path from UserAudio
BGM/My_Lobby_Track.mp3
BGM/Another_Track.mp3

Lines starting with a hash are comments and do not play. An empty tracks.txt keeps the original Lobby_BGM1.mp3 through Lobby_BGM6.mp3.

When tracks.txt contains at least one valid MP3, UserAudio BGM takes priority over the original six lobby tracks.

If one custom track fails, the Mod tries another valid track. If all custom tracks fail, it restores official lobby music instead of leaving it muted.

7. Playlist and path rules

Allowed:
1. UTF-8 text.
2. UTF-8 BOM.
3. Blank lines.
4. Whole-line comments beginning with a hash.
5. Spaces around a path.
6. Relative paths using forward slashes.

Not allowed:
1. Absolute paths.
2. Drive-letter paths such as C:/Music/test.wav.
3. Network paths.
4. .. path traversal.
5. Wildcards such as *.wav.
6. Quoted paths.
7. Lua expressions, commands or executable content.
8. Files outside UserAudio.

Each hit category loads at most 20 valid paths. Each kill category loads at most 20 valid paths. BGM loads at most 20 valid paths. Later entries are ignored after the limit.

Duplicate paths do not increase random probability. On Windows, paths that differ only by letter case are also treated as duplicates.

8. Custom audio fallback rules

1. An empty Custom headshot or weakspot pool uses the Custom normal pool of the same audio type.
2. An empty Custom normal pool uses the existing built-in BFV pool.
3. Hit and kill pools never use each other.
4. Empty pools never cause a random-index error or an empty path.
5. If Custom Audio Pack is not selected, the Mod does not sample Custom audio.
6. The existing meaning of kill_headshot_use_normal is unchanged.
7. BFV's extra headshot tail is used only when BFV is explicitly selected. Custom audio does not add it automatically.

9. Troubleshooting

No sound:
Confirm that Custom Audio Pack is selected, the matching hit or kill switch is enabled, volume is not zero, target filters allow the target, and the game was fully restarted.

A playlist entry is skipped:
Check that the file exists, the path is relative to UserAudio, the category is normal or headshot, the extension is correct, and the file is a real WAV or MP3.

The extension is correct but there is still no sound:
The file may only have been renamed. Export it again with an audio editor.

Old six BGM tracks are still playing:
This is the default behavior. UserAudio BGM takes priority only after tracks.txt contains at least one valid MP3.

BGM playback fails:
Check that SimpleAudio is installed and enabled, and that the MP3 exists and can be read. Falling back to official music is intentional protection.

10. Keep your audio when updating the Mod

1. Fully exit the game.
2. Copy the entire UserAudio folder to a safe location outside the game installation.
3. Update the Mod.
4. Copy your UserAudio folder and playlists back into the new Mod folder.
5. Manually merge any new example entries that you want.

Do not put personal audio in the scripts folder. Do not edit Lua to use custom audio.

Dependencies:
Hit and kill sounds require SimpleAudio. Kill icons require SimpleAssets. BGM uses SimpleAudio and runs only in a regular hub.
