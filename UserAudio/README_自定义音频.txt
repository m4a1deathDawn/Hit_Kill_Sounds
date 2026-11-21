命中/击杀音效 Mod
UserAudio 自定义音频说明
适用于 v1.5.7

一、先记住这几件事

1. 你不需要修改任何 Lua 文件。
2. 你不需要使用文件选择器，也不需要把文件命名成 01、02、03。
3. 修改音频文件或播放清单后，要完全退出并重新启动游戏。
4. 命中和击杀音效使用 WAV 文件；BGM 使用 MP3 文件。
5. 文件必须是真正的 WAV 或 MP3。只把文件名后缀改成 .wav 或 .mp3，不等于格式转换。
6. 只使用你有权使用的音频，不要把未经授权的商业音乐或游戏音效重新发布到 Mod 中。

二、UserAudio 文件夹在哪里

本说明文件所在的 UserAudio 文件夹位于：
Hit_Kill_Sounds/UserAudio/

当前文件夹结构如下：

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

命中和击杀的四个 WAV 默认文件，是本 Mod 已有 BFV 音效的副本：
Hit/Normal.wav 对应普通命中。
Hit/Headshot.wav 对应弱点或爆头命中。
Kill/Normal.wav 对应普通击杀。
Kill/Headshot.wav 对应爆头击杀。

BGM 文件夹默认没有 Lobby.mp3 占位文件。tracks.txt 默认只有注释，所以 Mod 默认继续使用原来的六个大厅音乐文件。

三、新手方法：只替换一个命中或击杀音效

1. 完全退出 Darktide。
2. 打开 UserAudio/Hit 或 UserAudio/Kill 文件夹。
3. 先把原来的 Normal.wav 或 Headshot.wav 复制到其他安全位置，作为备份。
4. 用音频编辑软件把自己的音效真正导出为 WAV 文件。
5. 用新文件覆盖对应的 Normal.wav 或 Headshot.wav。文件名和文件夹位置不要改变。
6. 启动游戏。
7. 在 Mod 设置的命中音效设置或击杀音效设置中，把对应的音源选择为：
   自定义音频包
8. 如果是近战命中，还要确认近战命中开关已经打开。
9. 如果要使用自定义 BGM，还要打开哀星号自定义 BGM 设置中的大厅 BGM 开关。
10. 修改完成后完全退出并重新启动游戏。

建议的音频格式是 PCM WAV、16 位、48 kHz、单声道或立体声。这个格式更容易被音频后端读取，但最终仍需要在游戏中实际测试。

四、进阶方法：增加多个音效

你可以把新的 WAV 文件放到这些文件夹中：

普通命中：UserAudio/Hit/normal/
弱点命中：UserAudio/Hit/headshot/
普通击杀：UserAudio/Kill/normal/
爆头击杀：UserAudio/Kill/headshot/

然后用记事本打开对应的播放清单：

命中清单：UserAudio/Hit/playlist.txt
击杀清单：UserAudio/Kill/playlist.txt

命中清单的每一行都必须写成：
类别|相对 UserAudio 的文件路径

例如：
normal|Hit/Normal.wav
normal|Hit/normal/metal_01.wav
normal|Hit/normal/metal_02.wav
headshot|Hit/Headshot.wav
headshot|Hit/headshot/headshot_soft.wav

击杀清单的例子：
normal|Kill/Normal.wav
normal|Kill/normal/kill_01.wav
headshot|Kill/Headshot.wav
headshot|Kill/headshot/headshot_01.wav

类别必须写成 normal 或 headshot。程序不会根据文件夹名称猜测类别。

五、如何新增、替换和停用音频

新增音频：
1. 把真正的 WAV 文件放到 UserAudio 内合适的文件夹。
2. 在对应 playlist.txt 中增加一行。
3. 保存文件并重启游戏。

替换音频：
把清单中的文件路径改成另一个有效 WAV 文件的路径，保存后重启游戏。

暂时停用一条音频：
在整行最前面加井号。例如：
# normal|Hit/normal/metal_01.wav

也可以直接删除这一行。删除清单行不会删除音频文件。

彻底删除音频：
先从清单中删除或注释对应行，再删除音频文件。这样可以避免游戏启动时出现缺失文件提示。

清单中的音频不会因为排列在前面就获得更高概率。有效音频会在同一类别中随机选择。

六、如何添加自定义 BGM

UserAudio 默认没有 BGM 占位文件。你需要自己准备真正的 MP3 文件，并放进：
UserAudio/BGM/

然后打开：
UserAudio/BGM/tracks.txt

每行写一个相对 UserAudio 的文件路径。例如：

# relative path from UserAudio
BGM/My_Lobby_Track.mp3
BGM/Another_Track.mp3

井号开头的行是注释，不会播放。空白的 tracks.txt 不会启用 UserAudio BGM，游戏会继续使用原来的 Lobby_BGM1.mp3 到 Lobby_BGM6.mp3。

只要 tracks.txt 中有至少一条有效 MP3，UserAudio BGM 就会优先于原来的六个大厅音乐文件。

如果某一首自定义 BGM 播放失败，Mod 会尝试其他有效曲目。如果所有自定义曲目都失败，Mod 会恢复官方大厅音乐，不会永久把官方音乐留在静音状态。

七、清单和路径限制

清单允许：
1. UTF-8 文本。
2. UTF-8 BOM。
3. 空行。
4. 以井号开头的整行注释。
5. 路径前后的空格。
6. 使用正斜杠的相对路径。

清单不允许：
1. 绝对路径。
2. 盘符路径，例如 C:/Music/test.wav。
3. 网络路径。
4. .. 路径跳转。
5. 通配符，例如 *.wav。
6. 用引号包住的路径。
7. Lua 表达式、命令或其他可执行内容。
8. UserAudio 文件夹之外的文件。

每个命中类别最多加载 20 条有效路径，每个击杀类别最多加载 20 条有效路径，BGM 最多加载 20 条有效路径。超过数量的后续条目会被忽略。

重复路径不会增加随机概率。Windows 下大小写不同但实际相同的路径也会被视为重复路径。

八、Custom 音频的回退规则

1. 爆头或弱点池为空时，使用同一种音频类型的 Custom 普通池。
2. Custom 普通池也为空时，使用现有内置 BFV 音效池。
3. 命中池和击杀池不会互相混用。
4. 空池不会触发随机数组错误，也不会传入空路径。
5. 未选择“自定义音频包”时，Mod 不会读取或播放 Custom 音频。
6. kill_headshot_use_normal 的原有设置语义保持不变。
7. BFV 专用爆头叠加尾音只在明确选择 BFV 内置音源时使用，Custom 不会自动添加这段尾音。

九、常见问题

没有声音：
确认选择的是“自定义音频包”，对应的命中或击杀开关已经打开，音量不是 0，目标没有被筛选条件排除，并且已经完全重启游戏。

清单中的文件没有播放：
检查文件是否真的存在，路径是否相对 UserAudio，类别是否写成 normal 或 headshot，扩展名是否正确，文件是否是真正的 WAV 或 MP3。

文件名后缀正确但仍然没有声音：
文件可能只是改了后缀，并没有真正转换格式。请用音频编辑软件重新导出。

BGM 仍然播放旧六首：
这是默认行为。只有 tracks.txt 中存在至少一条有效 MP3 时，UserAudio BGM 才会优先播放。

BGM 播放失败：
检查 SimpleAudio 是否已经安装并启用，MP3 是否真实存在且可读取。安全回退到官方音乐是正常保护行为。

十、更新 Mod 时如何保留自己的音频

1. 完全退出游戏。
2. 把整个 UserAudio 文件夹复制到游戏安装目录之外的安全位置。
3. 更新 Mod。
4. 把自己的 UserAudio 文件夹和播放清单复制回新版本的 Mod 文件夹。
5. 如果新版本提供了新的示例清单，请手动合并需要的内容。

不要把个人音频放进 scripts 文件夹，也不要为了使用自定义音频修改 Lua 文件。

依赖说明：
命中和击杀音效需要 SimpleAudio；击杀图标需要 SimpleAssets。BGM 使用 SimpleAudio 播放，且只在普通 hub 大厅运行。
