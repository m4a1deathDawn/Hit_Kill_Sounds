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
                },
            },
            {
                setting_id = "sound_settings",
                type = "group",
                sub_widgets = {
                    {
                        setting_id = "hit_game",
                        type = "dropdown",
                        default_value = "BF1",
                        options = GAME_OPTIONS,
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
                        options = TARGET_OPTIONS,
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
                        setting_id = "kill_game",
                        type = "dropdown",
                        default_value = "BF1",
                        options = GAME_OPTIONS,
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
                        options = TARGET_OPTIONS,
                    },
                    {
                        setting_id = "kill_dot",
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
                        setting_id = "kill_icon_debug",
                        type = "checkbox",
                        default_value = false,
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
