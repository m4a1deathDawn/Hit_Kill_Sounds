return {
    mod_name = {
        en = "Hit/Kill Sounds",
        ["zh-cn"] = "命中/击杀音效",
    },
    mod_description = {
        en = "Play hit and kill sounds from different games when hitting or killing enemies in Darktide. Also supports displaying kill icons on enemy kills.\n\n{#color(0,255,0)}Version v1.3{#reset()}  {#color(255,255,0)}Author: m4a1_death-Dawn{#reset()}\n{#color(0,102,255)}Special thanks to EBuyToDeep for the external audio player solution! Thanks to deluxghost for the SimpleAudio + SimpleAssets solution!{#reset()}",
        ["zh-cn"] = "在暗潮中命中或击杀敌人时，播放来自不同游戏的命中和击杀音效，并支持击杀后显示击杀图标。\n\n{#color(0,255,0)}版本 v1.3{#reset()}  {#color(255,255,0)}作者: m4a1_death-Dawn{#reset()}\n{#color(0,102,255)}感谢 EBuyToDeep 提供的外部音频播放器方案！感谢 deluxghost 提供的 SimpleAudio + SimpleAssets 方案！{#reset()}",
    },
    -- 主开关
    enabled = {
        en = "Master Switch",
        ["zh-cn"] = "总开关",
    },
    -- §11.B 同伴开关（2026-07-01）
    companion_hit_sound_enabled = {
        en = "Enable Companion Hit Sound",
        ["zh-cn"] = "启用同伴命中音效",
    },
    companion_kill_sound_enabled = {
        en = "Enable Companion Kill Sound",
        ["zh-cn"] = "启用同伴击杀音效",
    },
    companion_kill_icon_enabled = {
        en = "Enable Companion Kill Icon",
        ["zh-cn"] = "启用同伴击杀图标",
    },
    -- 分组标题
    general_settings = {
        en = "General Settings",
        ["zh-cn"] = "通用设置",
    },
    hit_sound_settings = {
        en = "Hit Sound Settings",
        ["zh-cn"] = "命中音效设置",
    },
    kill_sound_settings = {
        en = "Kill Sound Settings",
        ["zh-cn"] = "击杀音效设置",
    },
    lobby_bgm_settings = {
        en = "Custom Mourningstar BGM",
        ["zh-cn"] = "哀星号自定义 BGM",
    },
    icon_settings = {
        en = "Icon Settings",
        ["zh-cn"] = "图标设置",
    },
    -- 命中音效设置
    hit_sound_enabled = {
        en = "Enable Hit Sounds",
        ["zh-cn"] = "启用命中音效",
    },
    hit_game = {
        en = "Hit Sound Source Game",
        ["zh-cn"] = "命中音效来源游戏",
    },
    hit_game_normal = {
        en = "Normal Hit Sound Source Game",
        ["zh-cn"] = "普通命中音效来源游戏",
    },
    hit_headshot_game = {
        en = "Headshot Hit Sound Source Game",
        ["zh-cn"] = "爆头命中音效来源游戏",
    },
    hit_volume = {
        en = "Hit Sound Volume",
        ["zh-cn"] = "命中音效音量",
    },
    hit_target = {
        en = "Hit Sound Target",
        ["zh-cn"] = "命中音效生效对象",
    },
    hit_dot = {
        en = "Enable DoT Hit Sounds",
        ["zh-cn"] = "启用持续伤害命中音效",
    },
    hit_melee = {
        en = "Enable Melee Hit Sounds",
        ["zh-cn"] = "启用近战命中音效",
    },
    hit_melee_normal = {
        en = "Normal Melee Hit Sound Source Game",
        ["zh-cn"] = "普通近战命中音效来源游戏",
    },
    hit_melee_headshot = {
        en = "Headshot Melee Hit Sound Source Game",
        ["zh-cn"] = "爆头近战命中音效来源游戏",
    },
    -- 击杀音效设置
    kill_sound_enabled = {
        en = "Enable Kill Sounds",
        ["zh-cn"] = "启用击杀音效",
    },
    lobby_bgm_enabled = {
        en = "Enable Custom Mourningstar BGM (Hub Only)",
        ["zh-cn"] = "启用哀星号自定义 BGM（仅大厅）",
    },
    lobby_bgm_volume = {
        en = "Custom Mourningstar BGM Volume",
        ["zh-cn"] = "哀星号自定义 BGM 音量",
    },
    kill_game = {
        en = "Kill Sound Source Game",
        ["zh-cn"] = "击杀音效来源游戏",
    },
    kill_game_normal = {
        en = "Normal Kill Sound Source Game",
        ["zh-cn"] = "普通击杀音效来源游戏",
    },
    kill_headshot_game = {
        en = "Headshot Kill Sound Source Game",
        ["zh-cn"] = "爆头击杀音效来源游戏",
    },
    kill_headshot_use_normal = {
        en = "Use Normal Sound from Headshot Game for Headshot Kills",
        ["zh-cn"] = "爆头击杀使用爆头来源游戏的普通音效",
    },
    kill_headshot_volume = {
        en = "Headshot Kill Sound Volume",
        ["zh-cn"] = "爆头击杀音效音量",
    },
    kill_volume = {
        en = "Kill Sound Volume",
        ["zh-cn"] = "击杀音效音量",
    },
    kill_target = {
        en = "Kill Sound Target",
        ["zh-cn"] = "击杀音效生效对象",
    },
    -- 击杀图标生效对象（2026-07-01 解耦：从 kill_target 独立，控制 BF5/CF 及后续图标风格）
    kill_icon_target = {
        en = "Kill Icon Target",
        ["zh-cn"] = "击杀图标生效对象",
    },
    kill_dot = {
        en = "Enable DoT Kill Sounds",
        ["zh-cn"] = "启用持续伤害击杀音效",
    },
    game_hit_sound_enabled = {
        en = "Enable Game's Hit Sounds",
        ["zh-cn"] = "启用游戏自带命中音效",
    },
    game_kill_sound_enabled = {
        en = "Enable Game's Kill Sounds",
        ["zh-cn"] = "启用游戏自带击杀音效",
    },
    -- 击杀图标设置
    kill_icon_enabled = {
        en = "Enable Kill Icon",
        ["zh-cn"] = "启用击杀图标",
    },
    kill_dot_icon = {
        en = "Show Kill Icon on DoT Kills",
        ["zh-cn"] = "持续伤害击杀显示图标",
    },
    kill_icon_transparency = {
        en = "Kill Icon Transparency",
        ["zh-cn"] = "击杀图标透明度",
    },
    kill_icon_normal_color_r = {
        en = "Normal Icon Color - Red",
        ["zh-cn"] = "普通图标颜色 - 红",
    },
    kill_icon_normal_color_g = {
        en = "Normal Icon Color - Green",
        ["zh-cn"] = "普通图标颜色 - 绿",
    },
    kill_icon_normal_color_b = {
        en = "Normal Icon Color - Blue",
        ["zh-cn"] = "普通图标颜色 - 蓝",
    },
    kill_icon_headshot_color_r = {
        en = "Headshot Icon Color - Red",
        ["zh-cn"] = "爆头图标颜色 - 红",
    },
    kill_icon_headshot_color_g = {
        en = "Headshot Icon Color - Green",
        ["zh-cn"] = "爆头图标颜色 - 绿",
    },
    kill_icon_headshot_color_b = {
        en = "Headshot Icon Color - Blue",
        ["zh-cn"] = "爆头图标颜色 - 蓝",
    },
    kill_icon_vertical_position = {
        en = "Icon Vertical Position",
        ["zh-cn"] = "图标垂直位置",
    },
    kill_icon_horizontal_position = {
        en = "Icon Horizontal Position",
        ["zh-cn"] = "图标水平位置",
    },
    kill_icon_size = {
        en = "Icon Size",
        ["zh-cn"] = "图标大小",
    },
    kill_icon_duration = {
        en = "Icon Display Duration",
        ["zh-cn"] = "图标显示时长",
    },
    -- §13.E.3 CF 风格设置本地化（2026-07-01）
    kill_icon_style = {
        en = "Kill Icon Style",
        ["zh-cn"] = "击杀图标风格",
    },
    -- §13 CF 击杀音效独立开关（2026-07-01 解耦）
    cf_kill_sound_enabled = {
        en = "Enable CF Kill Sound (Indexed Killstreak)",
        ["zh-cn"] = "启用 CF 击杀音效（连杀索引）",
    },
    BF5 = {
        en = "Battlefield 5",
        ["zh-cn"] = "战地 5 风格",
    },
    CF = {
        en = "CrossFire",
        ["zh-cn"] = "穿越火线",
    },
    -- kill_icon_enabled_CF 已移除（2026-07-01：统一为 kill_icon_enabled 总开关）
    -- BF5 / CF 风格子分组标题
    icon_settings_bf5 = {
        en = "Battlefield 5 Icon Settings",
        ["zh-cn"] = "战地 5 图标设置",
    },
    icon_settings_cf = {
        en = "CrossFire Icon Settings",
        ["zh-cn"] = "穿越火线图标设置",
    },
    cf_killstreak_max = {
        en = "CF Killstreak Max (10-30)",
        ["zh-cn"] = "CF 连杀计数上限 (10-30)",
    },
    kill_icon_transparency_CF = {
        en = "CF Icon Transparency",
        ["zh-cn"] = "CF 图标透明度",
    },
    kill_icon_size_CF = {
        en = "CF Icon Size",
        ["zh-cn"] = "CF 图标大小",
    },
    kill_icon_vertical_position_CF = {
        en = "CF Icon Vertical Position",
        ["zh-cn"] = "CF 图标垂直位置",
    },
    kill_icon_horizontal_position_CF = {
        en = "CF Icon Horizontal Position",
        ["zh-cn"] = "CF 图标水平位置",
    },
    -- kill_icon_duration_CF 已重命名为 cf_killstreak_reset_time（2026-07-01：迁移到通用设置）
    cf_killstreak_reset_time = {
        en = "CF Killstreak Reset Time (1.0s-3.0s, also icon display duration)",
        ["zh-cn"] = "CF 连杀计数器重置时间 (1.0s-3.0s，同时控制图标显示时长)",
    },
    -- 游戏选项本地化
    BF1 = {
        en = "Battlefield 1",
        ["zh-cn"] = "战地1",
    },
    BF2042 = {
        en = "Battlefield 2042",
        ["zh-cn"] = "战地2042",
    },
    BF6 = {
        en = "Battlefield 6",
        ["zh-cn"] = "战地6",
    },
    BFV = {
        en = "Battlefield V",
        ["zh-cn"] = "战地5",
    },
    CODBO6 = {
        en = "Call of Duty: Black Ops 6",
        ["zh-cn"] = "使命召唤：黑色行动6",
    },
    CODBO7 = {
        en = "Call of Duty: Black Ops 7",
        ["zh-cn"] = "使命召唤：黑色行动7",
    },
    CODBOCW = {
        en = "Call of Duty: Black Ops Cold War",
        ["zh-cn"] = "使命召唤：黑色行动冷战",
    },
    CODVG = {
        en = "Call of Duty: Vanguard",
        ["zh-cn"] = "使命召唤：先锋",
    },
    CODMW2019 = {
        en = "Call of Duty: MW 2019",
        ["zh-cn"] = "使命召唤：现代战争2019",
    },
    CODMW3 = {
        en = "Call of Duty: MW 3",
        ["zh-cn"] = "使命召唤：现代战争3",
    },
    TheFinals = {
        en = "The Finals",
        ["zh-cn"] = "终极角逐",
    },
    Overwatch = {
        en = "Overwatch",
        ["zh-cn"] = "守望先锋",
    },
    -- §12 新增 4 个游戏（2026-07-01）
    CODWZ = {
        en = "Call of Duty: Warzone",
        ["zh-cn"] = "使命召唤：战区",
    },
    CODWZ2 = {
        en = "Call of Duty: Warzone 2",
        ["zh-cn"] = "使命召唤：战区 2",
    },
    DeltaForce = {
        en = "Delta Force",
        ["zh-cn"] = "三角洲行动",
    },
    APEX = {
        en = "Apex Legends",
        ["zh-cn"] = "APEX 英雄",
    },
    -- 目标类型选项本地化
    all = {
        en = "All Enemies",
        ["zh-cn"] = "全部敌人",
    },
    elite = {
        en = "Elite Only",
        ["zh-cn"] = "仅精英",
    },
    special = {
        en = "Special Only",
        ["zh-cn"] = "仅专家",
    },
    elite_special_boss = {
        en = "Elite, Special and Boss",
        ["zh-cn"] = "精英、专家和Boss",
    },
}
