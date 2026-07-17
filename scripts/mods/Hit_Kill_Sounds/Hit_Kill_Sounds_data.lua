local HKS = get_mod("Hit_Kill_Sounds")

-- 游戏选项列表（使用本地化文本）
local HIT_GAME_OPTIONS = {
    {text = "Battlefield 1", value = "BF1"},
    {text = "Battlefield 2042", value = "BF2042"},
    {text = "Battlefield 6", value = "BF6"},
    {text = "Battlefield V", value = "BFV"},
    {text = "Call of Duty: Black Ops 6", value = "CODBO6"},
    {text = "Call of Duty: Black Ops Cold War", value = "CODBOCW"},
    {text = "Call of Duty: Vanguard", value = "CODVG"},
    {text = "Call of Duty: MW 2019", value = "CODMW2019"},
    {text = "Call of Duty: MW 3", value = "CODMW3"},
    {text = "The Finals", value = "TheFinals"},
    {text = "Overwatch", value = "Overwatch"},
    {text = "Call of Duty: Warzone",     value = "CODWZ"},
    {text = "Call of Duty: Warzone 2",   value = "CODWZ2"},
    {text = "Delta Force",               value = "DeltaForce"},
    {text = "Apex Legends",              value = "APEX"},
}

-- 命中和击杀来源独立维护。CODBO7 目前只有击杀音效，不能出现在命中下拉框。
local KILL_GAME_OPTIONS = {}
for i, opt in ipairs(HIT_GAME_OPTIONS) do
    KILL_GAME_OPTIONS[i] = {text = opt.text, value = opt.value}
end
KILL_GAME_OPTIONS[#KILL_GAME_OPTIONS + 1] = {
    text = "Call of Duty: Black Ops 7",
    value = "CODBO7",
}

-- 目标类型选项（使用本地化文本）
local TARGET_OPTIONS = {
    {text = "All Enemies", value = "all"},
    {text = "Elite Only", value = "elite"},
    {text = "Special Only", value = "special"},
    {text = "Elite, Special and Boss", value = "elite_special_boss"},
}

-- 应用本地化到游戏选项
for i, opt in ipairs(HIT_GAME_OPTIONS) do
    local localized = HKS:localize(opt.value)
    if localized and localized ~= opt.value then
        HIT_GAME_OPTIONS[i].text = localized
    end
end

for i, opt in ipairs(KILL_GAME_OPTIONS) do
    local localized = HKS:localize(opt.value)
    if localized and localized ~= opt.value then
        KILL_GAME_OPTIONS[i].text = localized
    end
end

-- 应用本地化到目标选项
for i, opt in ipairs(TARGET_OPTIONS) do
    local localized = HKS:localize(opt.value)
    if localized and localized ~= opt.value then
        TARGET_OPTIONS[i].text = localized
    end
end

-- 为每个 dropdown 创建独立的 options 深拷贝
-- 防止 DMF 递归本地化 text 字段导致 <> 累积包裹
local function make_localized_options(raw_options)
    local result = {}
    for i, opt in ipairs(raw_options) do
        local text = opt.text
        local localized = HKS:localize(opt.value)
        if localized and localized ~= opt.value then
            text = localized
        end
        result[i] = { text = text, value = opt.value }
    end
    return result
end

-- §13.E.1 风格切换选项（BF5 / CF）
local STYLE_OPTIONS = {
    {text = HKS:localize("BF5"), value = "BF5"},
    {text = HKS:localize("CF"),  value = "CF"},
}

return {
    name = HKS:localize("mod_name"),
    description = HKS:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = {
            {
                setting_id = "general_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- §13 CF 连杀计数器重置时间（2026-07-01 从 icon_settings_cf.kill_icon_duration_CF 重命名并迁移）
                    -- 该值同时控制 CF 计数器重置窗口和 CF 图标显示时长（共享同一窗口，2.0s 默认）
                    {
                        setting_id = "cf_killstreak_reset_time",
                        type = "numeric",
                        default_value = 20,
                        range = {10, 30},
                        step = 1,
                    },
                },
            },
            {
                setting_id = "hit_sound_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "hit_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "hit_game_normal",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(HIT_GAME_OPTIONS),
                    },
                    {
                        setting_id = "hit_headshot_game",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(HIT_GAME_OPTIONS),
                    },
                    {
                        setting_id = "hit_volume",
                        type = "numeric",
                        default_value = 100,
                        range = {0, 100},
                        step = 5,
                    },
                    {
                        setting_id = "hit_target",
                        type = "dropdown",
                        default_value = "all",
                        options = make_localized_options(TARGET_OPTIONS),
                    },
                    {
                        setting_id = "hit_dot",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "hit_melee",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "hit_melee_normal",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(HIT_GAME_OPTIONS),
                    },
                    {
                        setting_id = "hit_melee_headshot",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(HIT_GAME_OPTIONS),
                    },
                    {
                        setting_id = "game_hit_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- §11.B 同伴命中音效（2026-07-01 迁移：从 general_settings）
                    {
                        setting_id = "companion_hit_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            {
                setting_id = "kill_sound_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "kill_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- §13 CF 击杀音效独立开关（2026-07-01 解耦）
                    -- 启用后使用 killsound_cf_01..09 顺序播放（连杀索引），替代 BF5 随机音效
                    -- 独立于 kill_icon_style：可单独开 CF 音 + BF5 图，或 BF5 音 + CF 图
                    {
                        setting_id = "cf_kill_sound_enabled",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "kill_game_normal",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(KILL_GAME_OPTIONS),
                    },
                    {
                        setting_id = "kill_headshot_game",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(KILL_GAME_OPTIONS),
                    },
                    {
                        setting_id = "kill_headshot_use_normal",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "kill_headshot_volume",
                        type = "numeric",
                        default_value = 100,
                        range = {0, 100},
                        step = 5,
                    },
                    {
                        setting_id = "kill_volume",
                        type = "numeric",
                        default_value = 100,
                        range = {0, 100},
                        step = 5,
                    },
                    {
                        setting_id = "kill_target",
                        type = "dropdown",
                        default_value = "all",
                        options = make_localized_options(TARGET_OPTIONS),
                    },
                    {
                        setting_id = "kill_dot",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "game_kill_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- §11.B 同伴击杀音效（2026-07-01 迁移：从 general_settings）
                    {
                        setting_id = "companion_kill_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                },
            },
            {
                setting_id = "lobby_bgm_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "lobby_bgm_enabled",
                        type = "checkbox",
                        default_value = false,
                    },
                    {
                        setting_id = "lobby_bgm_volume",
                        type = "numeric",
                        default_value = 100,
                        range = {0, 100},
                        step = 5,
                    },
                },
            },
            {
                setting_id = "icon_settings",
                type = "group",
                sub_widgets = {
                    -- 顶部：风格选择 + 统一开关（不再分 BF5/CF 两个开关）
                    {
                        setting_id = "kill_icon_style",
                        type = "dropdown",
                        default_value = "BF5",
                        options = make_localized_options(STYLE_OPTIONS),
                    },
                    {
                        setting_id = "kill_icon_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- §11.B DoT 击杀图标（2026-07-01 从 icon_settings_bf5 提升到顶层，对 BF5/CF 都生效）
                    {
                        setting_id = "kill_dot_icon",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- §11.B 同伴击杀图标（2026-07-01 迁移：从 general_settings）
                    {
                        setting_id = "companion_kill_icon_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    -- 击杀图标生效对象（2026-07-01 解耦：从 kill_sound_settings.kill_target 独立）
                    -- 控制所有图标风格（BF5/CF 及后续新增）的生效对象，独立于 kill_target（音效生效对象）
                    {
                        setting_id = "kill_icon_target",
                        type = "dropdown",
                        default_value = "all",
                        options = make_localized_options(TARGET_OPTIONS),
                    },
                    -- BF5 风格子分组（12 个设置，kill_dot_icon 已上移）
                    {
                        setting_id = "icon_settings_bf5",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "kill_icon_transparency",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                step = 5,
                            },
                            {
                                setting_id = "kill_icon_normal_color_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "kill_icon_normal_color_g",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "kill_icon_normal_color_b",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "kill_icon_headshot_color_r",
                                type = "numeric",
                                default_value = 255,
                                range = {0, 255},
                            },
                            {
                                setting_id = "kill_icon_headshot_color_g",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "kill_icon_headshot_color_b",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 255},
                            },
                            {
                                setting_id = "kill_icon_vertical_position",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 100},
                                step = 5,
                            },
                            {
                                setting_id = "kill_icon_horizontal_position",
                                type = "numeric",
                                default_value = 50,
                                range = {0, 100},
                                step = 5,
                            },
                            {
                                setting_id = "kill_icon_size",
                                type = "numeric",
                                default_value = 10,
                                range = {5, 20},
                                step = 1,
                            },
                            {
                                setting_id = "kill_icon_duration",
                                type = "dropdown",
                                default_value = "20",
                                options = {
                                    {text = "1.0s", value = "10"},
                                    {text = "1.5s", value = "15"},
                                    {text = "2.0s", value = "20"},
                                    {text = "2.5s", value = "25"},
                                    {text = "3.0s", value = "30"},
                                },
                            },
                        },
                    },
                    -- CF 风格子分组（5 个设置；kill_icon_duration_CF 已迁移并重命名为 general_settings.cf_killstreak_reset_time）
                    {
                        setting_id = "icon_settings_cf",
                        type = "group",
                        sub_widgets = {
                            {
                                setting_id = "cf_killstreak_max",
                                type = "numeric",
                                default_value = 13,
                                range = {10, 30},
                                step = 1,
                            },
                            {
                                setting_id = "kill_icon_transparency_CF",
                                type = "numeric",
                                default_value = 100,
                                range = {0, 100},
                                step = 5,
                            },
                            {
                                setting_id = "kill_icon_size_CF",
                                type = "numeric",
                                default_value = 10,
                                range = {5, 20},
                                step = 1,
                            },
                            {
                                setting_id = "kill_icon_vertical_position_CF",
                                type = "numeric",
                                default_value = 0,
                                range = {0, 100},
                                step = 5,
                            },
                            {
                                setting_id = "kill_icon_horizontal_position_CF",
                                type = "numeric",
                                default_value = 50,
                                range = {0, 100},
                                step = 5,
                            },
                        },
                    },
                },
            },
        }
    }
}
