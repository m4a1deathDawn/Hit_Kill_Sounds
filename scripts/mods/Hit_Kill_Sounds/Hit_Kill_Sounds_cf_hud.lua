-- luacheck: globals get_mod Managers class
local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- §13.D.1 CF HUD 常量
local ICON_BASE_SIZE = 180  -- 与 EBuyToDeep ok_size 一致
local FIRST_ANIMATION_DURATION = 0.15
local UPGRADE_ANIMATION_DURATION = 0.14
local AFTERIMAGE_DURATION = 0.22
local FADE_DURATION = 0.20
local GOLD_HEADSHOT_TEX_SCALE = 0.75
local cf_icons_load_started = false

local function cf_output_enabled()
    return HKS:get("enabled") ~= false
        and HKS:get("killstreak_enabled") ~= false
        and HKS:get("kill_icon_style") == "CF"
        and HKS:get("kill_icon_enabled") ~= false
end

local function clear_cf_icon(widget)
    if widget and widget.style then
        if widget.style.profile then
            widget.style.profile.material_values.texture_map = nil
        end
        if widget.style.afterimage then
            widget.style.afterimage.material_values.texture_map = nil
        end
    end

    if HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents.clear_cf_icon_state then
        HKS.HitKillSoundsEvents.clear_cf_icon_state()
    end
end

-- §13.D.2 scenegraph 定义（单图，垂直/水平位置可调）
local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    background = {
        horizontal_alignment = "center",
        parent = "screen",
        vertical_alignment = "bottom",
        size = {ICON_BASE_SIZE, ICON_BASE_SIZE},
        position = {0, -80, 0},  -- 默认 bottom-center，y=-80
    },
    kill_icon = {
        horizontal_alignment = "center",
        parent = "background",
        vertical_alignment = "center",
        size = {ICON_BASE_SIZE, ICON_BASE_SIZE},
    },
}

-- §13.D.3 widget 定义（包含底层扩散残影 afterimage pass 与主徽章 profile pass）
local cf_kill_icon_passes = {
    {
        style_id = "afterimage",
        value_id = "afterimage",
        pass_type = "texture",
        style = {
            material_values = {
                use_placeholder_texture = 0,
                texture_map = nil,
            },
            color = {0, 255, 255, 255},
            offset = {0, 0, 0},
            size = {ICON_BASE_SIZE, ICON_BASE_SIZE},
        },
        visibility_function = function(_content, style)
            return style.material_values.texture_map ~= nil
        end,
    },
    {
        style_id = "profile",
        value_id = "profile",
        pass_type = "texture",
        style = {
            material_values = {
                use_placeholder_texture = 0,
                texture_map = nil,
            },
            color = {0, 255, 255, 255},
            offset = {0, 0, 1},
            size = {ICON_BASE_SIZE, ICON_BASE_SIZE},
        },
        visibility_function = function(_content, style)
            return style.material_values.texture_map ~= nil
        end,
    },
}

local cf_kill_icon_definition = UIWidget.create_definition(cf_kill_icon_passes, "kill_icon")

local widget_definitions = {
    cf_kill_icon = cf_kill_icon_definition,
}

-- §13.D.4 HUD 类
local HudHitKillCF = class("HudHitKillCF", "HudElementBase")

local function cf_icons_ready()
    local tex = HKS.HitKillSoundsCFIconTex
    return tex and tex[1] ~= nil and tex["headshot_gold"] ~= nil
end

HudHitKillCF.init = function(self, parent, draw_layer, start_scale)
    HudHitKillCF.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    if self._widgets_by_name then
        self._widgets_by_name.kill_icon = self._widgets_by_name.cf_kill_icon or self._widgets_by_name.kill_icon
    end

    if (not cf_icons_load_started or not cf_icons_ready()) and HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents._preload_cf_icons then
        cf_icons_load_started = true
        HKS.HitKillSoundsEvents._preload_cf_icons()
    end
end

HudHitKillCF.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local widget = self._widgets_by_name.cf_kill_icon or self._widgets_by_name.kill_icon
    local background = self._ui_scenegraph.background

    -- CF HUD 也受通用连杀开关保护；关闭后立即清除 widget 和状态残留。
    if not cf_output_enabled() then
        clear_cf_icon(widget)
        return
    end

    local cf_state = HKS.HitKillSoundsCFIconState or HKS.HitKillSoundsCFState
    if not cf_state or not cf_state.current_icon then
        clear_cf_icon(widget)
        return
    end

    local now = Managers.time:time("main")

    -- 图标过期处理
    if now >= cf_state.icon_show_until then
        clear_cf_icon(widget)
        return
    end

    widget.style.profile.material_values.texture_map = cf_state.current_icon

    local duration_cf = math.max(0, (tonumber(HKS:get("cf_killstreak_reset_time")) or 20) / 10)
    local event_time = tonumber(cf_state.last_event_time) or (cf_state.icon_show_until - duration_cf)
    local elapsed = math.max(0, now - event_time)
    local size_scale = (tonumber(HKS:get("kill_icon_size_CF")) or 10) / 10

    local cf_icon_tex = HKS.HitKillSoundsCFIconTex
    local streak_count = tonumber(cf_state.inherited_streak_count) or 0
    local is_gold_headshot = (cf_icon_tex and cf_icon_tex["headshot_gold"] ~= nil and cf_state.current_icon == cf_icon_tex["headshot_gold"])
        or (cf_state.is_headshot == true and streak_count <= 1)
    local tex_norm_scale = is_gold_headshot and GOLD_HEADSHOT_TEX_SCALE or 1.0
    local display_size = ICON_BASE_SIZE * size_scale * tex_norm_scale

    local animation_kind = cf_state.animation_kind or "first"
    local animation_duration = animation_kind == "upgrade" and UPGRADE_ANIMATION_DURATION or FIRST_ANIMATION_DURATION
    local scale_multiplier = 1.0
    local enter_alpha = 1.0

    if elapsed < animation_duration then
        local progress = math.max(0, math.min(1, elapsed / animation_duration))
        if animation_kind == "upgrade" then
            -- 连杀升级（前 0.14s）：0.82 -> 1.28 -> 1.0 二段弹性脉冲
            if progress < 0.40 then
                local up_t = progress / 0.40
                local up_eased = 1 - (1 - up_t) ^ 2
                scale_multiplier = 0.82 + (1.28 - 0.82) * up_eased
            else
                local down_t = (progress - 0.40) / 0.60
                local down_eased = 1 - (1 - down_t) ^ 3
                scale_multiplier = 1.28 + (1.0 - 1.28) * down_eased
            end
        else
            -- 首杀唤醒（前 0.15s）：2.15 -> 0.92 (Cubic Ease-Out 重砸微缩) -> 回弹定格 1.0，伴随 Alpha 0.25 -> 1.0 亮起
            enter_alpha = 0.25 + (1.0 - 0.25) * progress
            if progress < 0.65 then
                local slam_t = progress / 0.65
                local slam_eased = 1 - (1 - slam_t) ^ 3
                scale_multiplier = 2.15 + (0.92 - 2.15) * slam_eased
            else
                local settle_t = (progress - 0.65) / 0.35
                local settle_eased = 1 - (1 - settle_t) ^ 2
                scale_multiplier = 0.92 + (1.0 - 0.92) * settle_eased
            end
        end
    end

    -- 消失阶段（最后 0.20s）：1.0 -> 1.08 微扩消散淡出
    local fade_window = math.min(FADE_DURATION, duration_cf)
    local fade_start = math.max(0, duration_cf - fade_window)
    local fade_alpha = 1.0
    if elapsed >= fade_start and fade_window > 0 then
        local fade_t = math.max(0, math.min(1, (elapsed - fade_start) / fade_window))
        fade_alpha = math.max(0, 1 - fade_t)
        scale_multiplier = scale_multiplier * (1.0 + (1.08 - 1.0) * fade_t)
    end

    local transparency = (tonumber(HKS:get("kill_icon_transparency_CF")) or 100) / 100
    local final_alpha = math.floor(255 * enter_alpha * fade_alpha * transparency)
    local red, green, blue = 255, 255, 255
    if cf_state.is_headshot and elapsed < 0.14 then
        local gold_progress = math.max(0, math.min(1, elapsed / 0.14))
        red = 255
        green = math.floor(190 + 65 * gold_progress)
        blue = math.floor(70 + 185 * gold_progress)
    end

    local current_size = math.floor(display_size * scale_multiplier)
    widget.style.profile.color = {final_alpha, red, green, blue}
    widget.style.profile.size = {current_size, current_size}
    widget.style.profile.offset = {
        math.floor((ICON_BASE_SIZE - current_size) * 0.5),
        math.floor((ICON_BASE_SIZE - current_size) * 0.5),
        1,
    }

    -- 底层扩散残影 afterimage pass：在入场/升级前 0.22s 内从 1.0x 扩散至 1.65x 并从 0.55 Alpha 衰减至 0
    local after_style = widget.style.afterimage
    if after_style then
        if elapsed < AFTERIMAGE_DURATION and elapsed < fade_start then
            local after_t = math.max(0, math.min(1, elapsed / AFTERIMAGE_DURATION))
            local after_eased = 1 - (1 - after_t) ^ 3
            local after_scale = 1.0 + (1.65 - 1.0) * after_eased
            local after_size = math.floor(display_size * after_scale)
            local after_alpha = math.floor(255 * 0.55 * (1 - after_t) * transparency)
            after_style.material_values.texture_map = cf_state.current_icon
            after_style.color = (cf_state.is_headshot or streak_count >= 6)
                and {after_alpha, 255, 215, 80}
                or {after_alpha, 255, 255, 255}
            after_style.size = {after_size, after_size}
            after_style.offset = {
                math.floor((ICON_BASE_SIZE - after_size) * 0.5),
                math.floor((ICON_BASE_SIZE - after_size) * 0.5),
                0,
            }
        else
            after_style.material_values.texture_map = nil
        end
    end

    local screen_height = UIWorkspaceSettings.screen.size[2]
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local v_pos = tonumber(HKS:get("kill_icon_vertical_position_CF")) or 0
    local h_pos = tonumber(HKS:get("kill_icon_horizontal_position_CF")) or 50
    local half_extent = display_size * scale_multiplier * 0.5
    local desired_center_x = screen_width * h_pos / 100
    local clamped_center_x = math.max(half_extent, math.min(screen_width - half_extent, desired_center_x))
    local desired_center_y = screen_height - 80 - (v_pos / 100) * math.max(screen_height - ICON_BASE_SIZE, 1)
    local clamped_center_y = math.max(half_extent, math.min(screen_height - half_extent, desired_center_y))
    background.position[1] = clamped_center_x - screen_width * 0.5
    background.position[2] = clamped_center_y - screen_height + ICON_BASE_SIZE * 0.5

    self._update_scenegraph = true

    HudHitKillCF.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillCF.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not cf_output_enabled() then
        clear_cf_icon(self._widgets_by_name.cf_kill_icon or self._widgets_by_name.kill_icon)
        return
    end

    local cf_state = HKS.HitKillSoundsCFIconState or HKS.HitKillSoundsCFState
    if not cf_state or not cf_state.current_icon then
        return
    end

    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then return end

    HudHitKillCF.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillCF
