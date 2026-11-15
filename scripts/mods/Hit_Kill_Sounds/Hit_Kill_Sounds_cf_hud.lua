local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- §13.D.1 CF HUD 常量
local ICON_BASE_SIZE = 180  -- 与 EBuyToDeep ok_size 一致
local FIRST_ANIMATION_DURATION = 0.18
local UPGRADE_ANIMATION_DURATION = 0.14
local FADE_DURATION = 0.22
local cf_icons_load_started = false

local function cf_output_enabled()
    return HKS:get("enabled") ~= false
        and HKS:get("killstreak_enabled") ~= false
        and HKS:get("kill_icon_style") == "CF"
        and HKS:get("kill_icon_enabled") ~= false
end

local function clear_cf_icon(widget)
    if widget and widget.style and widget.style.profile then
        widget.style.profile.material_values.texture_map = nil
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

-- §13.D.3 widget 定义
local widget_definitions = {
    kill_icon = UIWidget.create_definition({
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
                offset = {0, 0, 0},
                size = {ICON_BASE_SIZE, ICON_BASE_SIZE},
            },
            visibility_function = function(_content, style)
                return style.material_values.texture_map ~= nil
            end,
        },
    }, "kill_icon"),
}

-- §13.D.4 HUD 类
local HudHitKillCF = class("HudHitKillCF", "HudElementBase")

HudHitKillCF.init = function(self, parent, draw_layer, start_scale)
    HudHitKillCF.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    -- §13.B.4 关键修复：纹理加载从 init_damage_hooks 移到这里
    --   原因：on_all_mods_loaded 时 HTTP 服务器可能未启动，纹理静默加载失败
    --   HUD init 时机 = 游戏开局后，HTTP 服务器已就绪（与 BFV/EBuyToDeep 一致）
    if not cf_icons_load_started and HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents._preload_cf_icons then
        cf_icons_load_started = true
        HKS.HitKillSoundsEvents._preload_cf_icons()
    end
end

HudHitKillCF.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local widget = self._widgets_by_name.kill_icon
    local background = self._ui_scenegraph.background

    -- CF HUD 也受通用连杀开关保护；关闭后立即清除 widget 和状态残留。
    if not cf_output_enabled() then
        clear_cf_icon(widget)
        return
    end

    local cf_state = HKS.HitKillSoundsCFIconState or HKS.HitKillSoundsCFState
    if not cf_state then
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

    -- All animation phases use the event timestamp, not frame count.  A
    -- non-positive frame delta must not advance state in the backing HUD.
    local duration_cf = math.max(0, (tonumber(HKS:get("cf_killstreak_reset_time")) or 20) / 10)
    local event_time = tonumber(cf_state.last_event_time) or (cf_state.icon_show_until - duration_cf)
    local elapsed = math.max(0, now - event_time)
    local size_scale = (tonumber(HKS:get("kill_icon_size_CF")) or 10) / 10
    local display_size = ICON_BASE_SIZE * size_scale
    local animation_kind = cf_state.animation_kind or "first"
    local animation_duration = animation_kind == "upgrade" and UPGRADE_ANIMATION_DURATION or FIRST_ANIMATION_DURATION
    local scale_multiplier = 1
    if elapsed < animation_duration then
        local progress = math.max(0, math.min(1, elapsed / animation_duration))
        if animation_kind == "upgrade" then
            scale_multiplier = 1.24 - 0.24 * progress
        else
            local first_progress = progress < 0.5 and progress / 0.5 or (progress - 0.5) / 0.5
            if progress < 0.5 then
                scale_multiplier = 1.7 + (0.92 - 1.7) * first_progress
            else
                scale_multiplier = 0.92 + (1 - 0.92) * first_progress
            end
        end
    end

    local fade_start = math.max(0, duration_cf - FADE_DURATION)
    local alpha = 1
    if elapsed >= fade_start then
        alpha = math.max(0, 1 - (elapsed - fade_start) / math.min(FADE_DURATION, duration_cf))
    end
    local transparency = (tonumber(HKS:get("kill_icon_transparency_CF")) or 100) / 100
    local final_alpha = math.floor(255 * alpha * transparency)
    local red, green, blue = 255, 255, 255
    if cf_state.is_headshot and elapsed < 0.14 then
        local gold_progress = math.max(0, math.min(1, elapsed / 0.14))
        red = 255
        green = math.floor(190 + 65 * gold_progress)
        blue = math.floor(70 + 185 * gold_progress)
    end
    widget.style.profile.color = {final_alpha, red, green, blue}
    widget.style.profile.size = {math.floor(display_size * scale_multiplier), math.floor(display_size * scale_multiplier)}
    widget.style.profile.offset = {
        math.floor((ICON_BASE_SIZE - widget.style.profile.size[1]) * 0.5),
        math.floor((ICON_BASE_SIZE - widget.style.profile.size[2]) * 0.5),
        0,
    }

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
        clear_cf_icon(self._widgets_by_name.kill_icon)
        return
    end

    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then return end

    HudHitKillCF.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillCF
