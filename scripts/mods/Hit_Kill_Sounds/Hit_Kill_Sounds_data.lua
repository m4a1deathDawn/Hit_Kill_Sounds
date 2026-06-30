local HKS = get_mod("Hit_Kill_Sounds")

-- 游戏选项列表（使用本地化文本）
local GAME_OPTIONS = {
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

-- 目标类型选项（使用本地化文本）
local TARGET_OPTIONS = {
    {text = "All Enemies", value = "all"},
    {text = "Elite Only", value = "elite"},
    {text = "Special Only", value = "special"},
    {text = "Elite, Special and Boss", value = "elite_special_boss"},
}

-- 应用本地化到游戏选项
for i, opt in ipairs(GAME_OPTIONS) do
    local localized = HKS:localize(opt.value)
    if localized and localized ~= opt.value then
        GAME_OPTIONS[i].text = localized
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
                    -- §11.B 同伴开关（2026-07-01，默认 ON，兼容老用户）
                    {
                        setting_id = "companion_hit_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "companion_kill_sound_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "companion_kill_icon_enabled",
                        type = "checkbox",
                        default_value = true,
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
                        options = make_localized_options(GAME_OPTIONS),
                    },
                    {
                        setting_id = "hit_headshot_game",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(GAME_OPTIONS),
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
                        options = make_localized_options(GAME_OPTIONS),
                    },
                    {
                        setting_id = "hit_melee_headshot",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(GAME_OPTIONS),
                    },
                    {
                        setting_id = "game_hit_sound_enabled",
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
                    {
                        setting_id = "kill_game_normal",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(GAME_OPTIONS),
                    },
                    {
                        setting_id = "kill_headshot_game",
                        type = "dropdown",
                        default_value = "BF1",
                        options = make_localized_options(GAME_OPTIONS),
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
                },
            },
            {
                setting_id = "icon_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "kill_icon_enabled",
                        type = "checkbox",
                        default_value = true,
                    },
                    {
                        setting_id = "kill_dot_icon",
                        type = "checkbox",
                        default_value = true,
                    },
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
        }
    }
}
