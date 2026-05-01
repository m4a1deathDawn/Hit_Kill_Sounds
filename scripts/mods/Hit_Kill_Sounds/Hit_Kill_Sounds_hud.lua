local HKS = get_mod("Hit_Kill_Sounds")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- 图标尺寸
local ICON_SIZE = 64
local ICON_ROOT_SIZE = 96
local SLOT_SPACING = 110
local MAX_SLOTS = 10

-- 预加载的纹理
local _textures = {
    normal = nil,
    headshot = nil,
    circle = nil,
}

-- 队列数据结构
HKS.HitKillIconManager = {
    _slots = {},
}

-- 初始化slots
for i = 1, MAX_SLOTS do
    HKS.HitKillIconManager._slots[i] = {
        active = false,
        is_headshot = false,
        start_time = 0,
        target_x = 0,
        current_x = 0,
        leaving = false,
        leaving_start_time = 0,
    }
end

-- 显示图标接口
HKS.HitKillIconManager.show_icon = function(is_headshot)
    local manager = HKS.HitKillIconManager
    local now_time = Managers.time:time("main")

    -- 获取当前图标大小设置，动态计算间距
    local size_scale = (HKS:get("kill_icon_size") or 10) / 10
    local dynamic_spacing = ICON_ROOT_SIZE * size_scale - 20  -- 图标大小 - 20px重叠间隔

    -- 1. 找到最右侧空闲slot
    local free_slot = nil
    for i = 1, MAX_SLOTS do
        if not manager._slots[i].active then
            free_slot = i
            break
        end
    end

    -- 如果没有空闲slot，找最老的leaving slot
    if not free_slot then
        for i = 1, MAX_SLOTS do
            if manager._slots[i].leaving then
                free_slot = i
                break
            end
        end
    end

    -- 如果还是没有，强制复用最左边的slot
    if not free_slot then
        local leftmost_x = math.huge
        for i = 1, MAX_SLOTS do
            local s = manager._slots[i]
            if s.active and s.target_x < leftmost_x then
                leftmost_x = s.target_x
                free_slot = i
            end
        end
        -- 标记它为leaving以排除在shift之外
        if free_slot then
            manager._slots[free_slot].leaving = true
        end
    end

    -- 2. 获取屏幕宽度和水平位置设置
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local horiz_pos = HKS:get("kill_icon_horizontal_position") or 50

    -- 3. 计算图标左边缘位置（根据水平位置设置）
    local center_x = screen_width * (horiz_pos / 100) - ICON_ROOT_SIZE / 2

    -- 4. 所有活跃slot的target_x左移一个位置
    for i = 1, MAX_SLOTS do
        local s = manager._slots[i]
        if s.active and not s.leaving then
            s.target_x = s.target_x - dynamic_spacing
        end
    end

    -- 5. 激活新slot，从中央偏右弹入到中央
    local slot = manager._slots[free_slot]
    slot.active = true
    slot.is_headshot = is_headshot
    slot.start_time = now_time
    slot.target_x = center_x
    slot.current_x = center_x + 60  -- 从中央偏右60px开始
    slot.leaving = false
end

-- 预加载纹理
local function preload_textures()
    local host = HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host
    if not host then
        return
    end

    local normal_url = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_normal.png"
    local headshot_url = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_headshot.png"
    local circle_url = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_circle.png"

    Managers.url_loader:load_texture(normal_url):next(function(data)
        if data and data.texture then
            _textures.normal = data.texture
        end
    end)

    Managers.url_loader:load_texture(headshot_url):next(function(data)
        if data and data.texture then
            _textures.headshot = data.texture
        end
    end)

    Managers.url_loader:load_texture(circle_url):next(function(data)
        if data and data.texture then
            _textures.circle = data.texture
        end
    end)
end

-- 场景图定义
local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
}

-- 为每个slot创建scenegraph条目
for i = 1, MAX_SLOTS do
    scenegraph_definition["icon_root_" .. i] = {
        horizontal_alignment = "left",
        parent = "screen",
        vertical_alignment = "top",
        size = {ICON_ROOT_SIZE, ICON_ROOT_SIZE},
        position = {0, 0, 0},
    }
    scenegraph_definition["circle_root_" .. i] = {
        horizontal_alignment = "center",
        parent = "icon_root_" .. i,
        vertical_alignment = "center",
        size = {ICON_ROOT_SIZE, ICON_ROOT_SIZE},
        position = {0, 0, 1},
    }
end

-- Widget定义
local widget_definitions = {}

-- 为每个slot创建widget对
for i = 1, MAX_SLOTS do
    widget_definitions["kill_icon_" .. i] = UIWidget.create_definition({
        {
            style_id = "icon",
            value_id = "icon",
            pass_type = "texture",
            style = {
                material_values = {
                    use_placeholder_texture = 0,
                    texture_map = nil,
                },
                color = {
                    0,
                    255,
                    255,
                    255,
                },
                offset = {0, 0, 0},
                size = {ICON_SIZE, ICON_SIZE},
            },
            visibility_function = function(_content, style)
                return style.material_values.texture_map ~= nil
            end,
        },
    }, "icon_root_" .. i)

    widget_definitions["circle_icon_" .. i] = UIWidget.create_definition({
        {
            style_id = "circle",
            value_id = "circle",
            pass_type = "texture",
            style = {
                material_values = {
                    use_placeholder_texture = 0,
                    texture_map = nil,
                },
                color = {
                    255,
                    255,
                    0,
                    0,
                },
                offset = {0, 0, 0},
                size = {ICON_SIZE, ICON_SIZE},
            },
            visibility_function = function(_content, style)
                return style.material_values.texture_map ~= nil
            end,
        },
    }, "circle_root_" .. i)
end

-- HUD元素类
local HudHitKillICON = class("HudHitKillICON", "HudElementBase")

HudHitKillICON.init = function(self, parent, draw_layer, start_scale)
    HudHitKillICON.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    -- 预加载纹理
    preload_textures()
end

HudHitKillICON.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local manager = HKS.HitKillIconManager
    local now_time = Managers.time:time("main")

    -- 动画参数
    local enter_duration = 0.3
    local fade_duration = 0.2
    local leave_duration = 0.2

    -- 获取设置
    local size_scale = (HKS:get("kill_icon_size") or 10) / 10
    local vert_pos = HKS:get("kill_icon_vertical_position") or 0
    local screen_height = UIWorkspaceSettings.screen.size[2]
    local y_pos = (vert_pos / 100) * (screen_height - ICON_ROOT_SIZE)
    local display_duration = (tonumber(HKS:get("kill_icon_duration")) or 20) / 10  -- 存储值除以10得到秒数

    local normal_r = HKS:get("kill_icon_normal_color_r") or 255
    local normal_g = HKS:get("kill_icon_normal_color_g") or 255
    local normal_b = HKS:get("kill_icon_normal_color_b") or 255
    local headshot_r = HKS:get("kill_icon_headshot_color_r") or 255
    local headshot_g = HKS:get("kill_icon_headshot_color_g") or 0
    local headshot_b = HKS:get("kill_icon_headshot_color_b") or 0

    -- 更新每个slot
    for i = 1, MAX_SLOTS do
        local slot = manager._slots[i]
        local icon_widget = self._widgets_by_name["kill_icon_" .. i]
        local circle_widget = self._widgets_by_name["circle_icon_" .. i]
        local icon_root = self._ui_scenegraph["icon_root_" .. i]

        if not icon_root then
            -- 跳过无效slot
        elseif not slot.active then
            -- 隐藏非活跃slot
            if icon_widget.style.icon.material_values.texture_map ~= nil then
                icon_widget.style.icon.material_values.texture_map = nil
            end
            if circle_widget.style and circle_widget.style.circle and circle_widget.style.circle.material_values then
                circle_widget.style.circle.material_values.texture_map = nil
            end
        elseif slot.leaving then
            -- 处理离场动画
            local leave_elapsed = now_time - slot.leaving_start_time
            if leave_elapsed >= leave_duration then
                slot.active = false
                slot.leaving = false
                if icon_widget.style.icon.material_values.texture_map ~= nil then
                    icon_widget.style.icon.material_values.texture_map = nil
                end
                if circle_widget.style and circle_widget.style.circle and circle_widget.style.circle.material_values then
                    circle_widget.style.circle.material_values.texture_map = nil
                end
            else
                -- 离场动画：向左滑出并淡出
                local progress = leave_elapsed / leave_duration
                progress = 1 - (1 - progress) ^ 3
                local leave_offset = SLOT_SPACING * progress
                slot.current_x = slot.target_x - leave_offset

                local alpha = math.floor(255 * (1 - progress))
                icon_widget.style.icon.color = {alpha, slot.is_headshot and headshot_r or normal_r, slot.is_headshot and headshot_g or normal_g, slot.is_headshot and headshot_b or normal_b}
                if icon_widget.style.circle then
                    icon_widget.style.circle.material_values.texture_map = nil
                end

                icon_root.position[1] = slot.current_x
                icon_root.position[2] = y_pos
                self._update_scenegraph = true
            end
        else
            -- 活跃slot处理
            local elapsed = now_time - slot.start_time
            local is_headshot = slot.is_headshot

            -- 检查是否超时需要离开
            if elapsed > display_duration + enter_duration then
                slot.leaving = true
                slot.leaving_start_time = now_time
            end

            -- 平滑移动到target_x (使用正确的插值公式)
            slot.current_x = slot.current_x + (slot.target_x - slot.current_x) * dt * 10

            icon_root.position[1] = slot.current_x
            icon_root.position[2] = y_pos
            self._update_scenegraph = true

            -- 计算透明度
            local alpha = 255
            if elapsed < enter_duration then
                local progress = elapsed / enter_duration
                progress = 1 - (1 - progress) ^ 3
                alpha = math.floor(255 * progress)
            elseif elapsed > display_duration then
                local fade_elapsed = elapsed - display_duration
                if fade_elapsed >= fade_duration then
                    -- 标记离开
                    slot.leaving = true
                    slot.leaving_start_time = now_time
                    alpha = 0
                else
                    local progress = fade_elapsed / fade_duration
                    progress = 1 - (1 - progress) ^ 3
                    alpha = math.floor(255 * (1 - progress))
                end
            end

            -- 计算scale (入场动画 1.8 -> size_scale, ease-out)
            local scale = size_scale
            if elapsed < enter_duration then
                local progress = elapsed / enter_duration
                progress = 1 - (1 - progress) ^ 3
                scale = 1.8 - (1.8 - size_scale) * progress
            end

            -- 应用纹理
            local tex = is_headshot and _textures.headshot or _textures.normal
            icon_widget.style.icon.material_values.texture_map = tex

            -- 应用颜色
            if is_headshot then
                icon_widget.style.icon.color = {alpha, headshot_r, headshot_g, headshot_b}
            else
                icon_widget.style.icon.color = {alpha, normal_r, normal_g, normal_b}
            end

            -- 应用scale和offset
            local scaled_size = {
                math.floor(ICON_SIZE * scale),
                math.floor(ICON_SIZE * scale),
            }
            icon_widget.style.icon.size = scaled_size
            icon_widget.style.icon.offset = {
                math.floor((ICON_ROOT_SIZE - scaled_size[1]) * 0.5),
                math.floor((ICON_ROOT_SIZE - scaled_size[2]) * 0.5),
                0,
            }

            -- 圆环效果 (仅爆头)
            if is_headshot and _textures.circle and circle_widget.style and circle_widget.style.circle then
                circle_widget.style.circle.material_values.texture_map = _textures.circle

                local base_display_size = ICON_SIZE * size_scale
                local circle_duration = 0.5
                local circle_elapsed = elapsed - enter_duration

                local circle_scale = 1
                local circle_alpha = 255

                if circle_elapsed > 0 and circle_elapsed < circle_duration then
                    local progress = circle_elapsed / circle_duration
                    circle_scale = 1 + 3 * progress
                    circle_alpha = math.floor(255 * (1 - progress))
                elseif circle_elapsed >= circle_duration then
                    circle_alpha = 0
                end

                local circle_size = {
                    math.floor(base_display_size * circle_scale),
                    math.floor(base_display_size * circle_scale),
                }
                circle_widget.style.circle.size = circle_size
                circle_widget.style.circle.offset = {
                    math.floor((ICON_ROOT_SIZE - circle_size[1]) * 0.5),
                    math.floor((ICON_ROOT_SIZE - circle_size[2]) * 0.5),
                    0,
                }
                circle_widget.style.circle.color = {circle_alpha, headshot_r, headshot_g, headshot_b}
            elseif circle_widget.style and circle_widget.style.circle then
                circle_widget.style.circle.material_values.texture_map = nil
            end
        end
    end

    HudHitKillICON.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillICON.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not HKS:get("kill_icon_enabled") then
        return
    end

    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    local is_in_hub = game_mode_name == "hub"
    if is_in_hub then
        return
    end

    HudHitKillICON.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillICON
