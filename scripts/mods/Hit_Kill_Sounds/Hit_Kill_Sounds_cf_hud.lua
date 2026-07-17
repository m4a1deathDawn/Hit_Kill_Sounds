local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- §13.D.1 CF HUD 常量
local ICON_BASE_SIZE = 180  -- 与 EBuyToDeep ok_size 一致
local ENTER_DURATION = 0.2  -- 淡入时长（沿用 EBuyToDeep）
local FADE_DELAY = 2.8      -- EBuyToDeep alpha 255→0 起始时间
local FADE_DURATION = 0.2   -- 淡出时长
local cf_icons_load_started = false

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

    -- 仅在 CF 模式、总开关和图标开关都开启时渲染。
    if not HKS:get("enabled") or HKS:get("kill_icon_style") ~= "CF" or not HKS:get("kill_icon_enabled") then
        widget.style.profile.material_values.texture_map = nil
        return
    end

    local cf_state = HKS.HitKillSoundsCFState
    if not cf_state then return end

    local now = Managers.time:time("main")

    -- 图标过期处理
    if now > cf_state.icon_show_until then
        widget.style.profile.material_values.texture_map = nil
        return
    end

    widget.style.profile.material_values.texture_map = cf_state.current_icon

    -- 计算动画进度
    local duration_cf = (tonumber(HKS:get("cf_killstreak_reset_time")) or 20) / 10  -- 2026-07-01 重命名（从 kill_icon_duration_CF 迁移）
    local elapsed = now - (cf_state.icon_show_until - duration_cf)
    local enter_elapsed = elapsed
    local fade_elapsed = elapsed - FADE_DELAY

    -- 缩放动画（0 → ICON_BASE_SIZE，0.2s 淡入）
    local size_scale = (HKS:get("kill_icon_size_CF") or 10) / 10
    local display_size = ICON_BASE_SIZE * size_scale

    local current_size
    if enter_elapsed < ENTER_DURATION then
        local progress = enter_elapsed / ENTER_DURATION
        progress = 1 - (1 - progress) ^ 3  -- ease-out
        current_size = math.floor(display_size * progress)
    else
        current_size = display_size
    end

    -- Alpha 动画
    local alpha = 255
    if fade_elapsed > 0 and fade_elapsed < FADE_DURATION then
        local progress = fade_elapsed / FADE_DURATION
        alpha = math.floor(255 * (1 - progress))
    elseif fade_elapsed >= FADE_DURATION then
        alpha = 0
    end

    -- 透明度叠加（决策 4 的可调透明度）
    local transparency = (HKS:get("kill_icon_transparency_CF") or 100) / 100
    local final_alpha = math.floor(alpha * transparency)

    -- 颜色设置（与 EBuyToDeep 一致：白色）
    widget.style.profile.color = {final_alpha, 255, 255, 255}
    widget.style.profile.size = {current_size, current_size}
    widget.style.profile.offset = {
        math.floor((ICON_BASE_SIZE - current_size) * 0.5),
        math.floor((ICON_BASE_SIZE - current_size) * 0.5),
        0,
    }

    -- 位置设置（决策 4：可调 v/h pos）
    local screen_height = UIWorkspaceSettings.screen.size[2]
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local v_pos = HKS:get("kill_icon_vertical_position_CF") or 0
    local h_pos = HKS:get("kill_icon_horizontal_position_CF") or 50
    background.position[1] = (h_pos / 100 - 0.5) * screen_width
    background.position[2] = -(v_pos / 100) * (screen_height - ICON_BASE_SIZE) + (-80)

    self._update_scenegraph = true

    HudHitKillCF.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillCF.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not HKS:get("enabled") then return end
    if HKS:get("kill_icon_style") ~= "CF" then return end
    -- 统一图标总开关（2026-07-01 修订：CF 也用 kill_icon_enabled）
    if not HKS:get("kill_icon_enabled") then return end

    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then return end

    HudHitKillCF.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillCF
