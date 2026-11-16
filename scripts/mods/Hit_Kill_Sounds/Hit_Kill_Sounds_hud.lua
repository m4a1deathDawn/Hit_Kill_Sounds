-- luacheck: globals get_mod Managers class
local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local ICON_SIZE = 64
local ICON_ROOT_SIZE = 96
local MAX_SLOTS = 10
local MAX_LEAVING_SLOTS = 2
local ENTER_DURATION = 0.18
local ENTER_ALPHA_DURATION = 0.06
local NATURAL_FADE_DURATION = 0.22
local OVERFLOW_LEAVE_DURATION = 0.18
local RING_DURATION = 0.35
local LEAVE_OFFSET = 48

local _textures = {normal = nil, headshot = nil, circle = nil}
local textures_load_started = false

local function new_slot()
    return {
        active = false,
        is_headshot = false,
        start_time = 0,
        target_x = 0,
        current_x = 0,
        order = 0,
        leaving = false,
        leaving_start_time = 0,
        fade_start_time = nil,
        fade_start_alpha = 1,
        fade_start_scale = 1,
        render_alpha = 1,
        render_scale = 1,
    }
end

HKS.HitKillIconManager = {
    _slots = {},
    _leaving_slots = {},
    _next_order = 0,
    _last_kill_time = nil,
    _natural_fade_start = nil,
}
local manager = HKS.HitKillIconManager

for i = 1, MAX_SLOTS do manager._slots[i] = new_slot() end
for i = 1, MAX_LEAVING_SLOTS do manager._leaving_slots[i] = new_slot() end

local function reset_slot(slot)
    local fresh = new_slot()
    for key, value in pairs(fresh) do slot[key] = value end
end

manager.clear = function()
    for _, slot in ipairs(manager._slots) do reset_slot(slot) end
    for _, slot in ipairs(manager._leaving_slots) do reset_slot(slot) end
    manager._last_kill_time = nil
    manager._natural_fade_start = nil
end

local function get_size_scale()
    return (tonumber(HKS:get("kill_icon_size")) or 10) / 10
end

local function sorted_active_slots()
    local active = {}
    for _, slot in ipairs(manager._slots) do
        if slot.active then active[#active + 1] = slot end
    end
    table.sort(active, function(a, b) return a.order < b.order end)
    return active
end

local function recompute_targets()
    local size_scale = get_size_scale()
    local spacing = (ICON_ROOT_SIZE - 20) * size_scale
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local horizontal = tonumber(HKS:get("kill_icon_horizontal_position")) or 50
    local base_x = screen_width * horizontal / 100 - ICON_ROOT_SIZE / 2
    local active = sorted_active_slots()
    local count = #active

    for index, slot in ipairs(active) do
        slot.target_x = base_x + (index - (count + 1) / 2) * spacing
    end
end

local function oldest_active_slot()
    local oldest
    for _, slot in ipairs(manager._slots) do
        if slot.active and (not oldest or slot.order < oldest.order) then oldest = slot end
    end
    return oldest
end

local function has_active_slots(slots_list, leaving_list)
    slots_list = slots_list or manager._slots
    leaving_list = leaving_list or manager._leaving_slots

    for i = 1, #slots_list do
        local s = slots_list[i]
        if s and s.active ~= false then
            return true
        end
    end
    for i = 1, #leaving_list do
        local s = leaving_list[i]
        if s and s.active ~= false then
            return true
        end
    end
    return false
end

local function copy_overflow_slot(source, now)
    local destination
    for _, slot in ipairs(manager._leaving_slots) do
        if not slot.active then destination = slot break end
    end
    if not destination then
        destination = manager._leaving_slots[1]
        for _, slot in ipairs(manager._leaving_slots) do
            if slot.leaving_start_time < destination.leaving_start_time then destination = slot end
        end
    end

    local fade_start_alpha = (source.render_alpha ~= nil and source.render_alpha > 0) and source.render_alpha or 1
    local fade_start_scale = (source.render_scale ~= nil and source.render_scale > 0) and source.render_scale or 1

    destination.active = true
    destination.leaving = true
    destination.is_headshot = source.is_headshot
    destination.start_time = source.start_time
    destination.current_x = source.current_x
    destination.target_x = source.current_x
    destination.leaving_start_time = now
    destination.fade_start_time = nil
    destination.fade_start_alpha = fade_start_alpha
    destination.fade_start_scale = fade_start_scale
    destination.render_alpha = fade_start_alpha
    destination.render_scale = fade_start_scale
    return destination
end

local function update_leaving_slot_state(slot, now, size_scale)
    local leave_t = math.min(1, math.max(0, (now - slot.leaving_start_time) / OVERFLOW_LEAVE_DURATION))
    if leave_t >= 1 then
        reset_slot(slot)
        return false
    end
    local eased = 1 - (1 - leave_t) ^ 3
    slot.current_x = slot.target_x - LEAVE_OFFSET * (size_scale or 1) * eased
    slot.render_alpha = (slot.fade_start_alpha or 1) * (1 - leave_t)
    slot.render_scale = (slot.fade_start_scale or 1) * (1 - 0.15 * leave_t)
    return true
end

local function update_leaving_slots(now, size_scale)
    size_scale = size_scale or get_size_scale()
    for _, slot in ipairs(manager._leaving_slots) do
        if slot.active then
            update_leaving_slot_state(slot, now, size_scale)
        end
    end
end

manager.copy_overflow_slot = copy_overflow_slot
manager.update_leaving_slots = update_leaving_slots

manager.show_icon = function(is_headshot)
    local now = Managers.time:time("main")
    -- A new kill during the natural fade starts a new row rather than reviving
    -- the old row from full alpha.
    if manager._natural_fade_start then manager.clear() end

    local slot
    for _, candidate in ipairs(manager._slots) do
        if not candidate.active then slot = candidate break end
    end
    if not slot then
        slot = oldest_active_slot()
        if slot then
            copy_overflow_slot(slot, now)
            reset_slot(slot)
        end
    end
    if not slot then return end

    local size_scale = get_size_scale()
    manager._next_order = manager._next_order + 1
    slot.active = true
    slot.is_headshot = is_headshot == true
    slot.start_time = now
    slot.current_x = 0
    slot.target_x = 0
    slot.order = manager._next_order
    slot.leaving = false
    slot.fade_start_time = nil
    slot.fade_start_alpha = 1
    slot.fade_start_scale = 1
    slot.render_alpha = 0
    slot.render_scale = 0
    manager._last_kill_time = now
    manager._natural_fade_start = nil
    recompute_targets()

    local active_count = #sorted_active_slots()
    local has_leaving = false
    for _, leaving_slot in ipairs(manager._leaving_slots) do
        if leaving_slot.active then
            has_leaving = true
            break
        end
    end
    local slide_offset = (active_count > 1 or has_leaving) and (28 * size_scale) or 0
    slot.slide_offset_x = slide_offset
    slot.current_x = slot.target_x + slide_offset
end

local function textures_ready()
    return _textures.normal ~= nil and _textures.headshot ~= nil and _textures.circle ~= nil
end

local function preload_textures_legacy()
    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.start_player then HKS.HitKillSoundsPlayer.start_player() end
    local host = HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host
    if not host then
        textures_load_started = false
        return
    end
    local urls = {
        normal = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_normal.png",
        headshot = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_headshot.png",
        circle = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_circle.png",
    }
    for key, url in pairs(urls) do
        Managers.url_loader:load_texture(url):next(function(data)
            if data and data.texture then _textures[key] = data.texture end
        end)
    end
end

local function preload_textures()
    if textures_ready() then return end
    if textures_load_started then return end
    textures_load_started = true
    if HKS.HitKillSoundsAssetsBackend then
        HKS.HitKillSoundsAssetsBackend.load_bf5_icons(_textures, function()
            textures_load_started = false
            preload_textures_legacy()
        end)
        if not textures_ready() then
            textures_load_started = false
        end
    else
        preload_textures_legacy()
        if not textures_ready() then
            textures_load_started = false
        end
    end
end

local scenegraph_definition = {screen = UIWorkspaceSettings.screen}
local widget_definitions = {}
for i = 1, MAX_SLOTS + MAX_LEAVING_SLOTS do
    scenegraph_definition["icon_root_" .. i] = {
        horizontal_alignment = "left", parent = "screen", vertical_alignment = "top",
        size = {ICON_ROOT_SIZE, ICON_ROOT_SIZE}, position = {0, 0, 0},
    }
    scenegraph_definition["circle_root_" .. i] = {
        horizontal_alignment = "center", parent = "icon_root_" .. i,
        vertical_alignment = "center", size = {ICON_ROOT_SIZE, ICON_ROOT_SIZE}, position = {0, 0, -1},
    }
    widget_definitions["kill_icon_" .. i] = UIWidget.create_definition({{
        style_id = "icon", value_id = "icon", pass_type = "texture",
        style = {material_values = {use_placeholder_texture = 0, texture_map = nil},
            color = {0, 255, 255, 255}, offset = {0, 0, 0}, size = {ICON_SIZE, ICON_SIZE}},
        visibility_function = function(_content, style) return style.material_values.texture_map ~= nil end,
    }}, "icon_root_" .. i)
    widget_definitions["circle_icon_" .. i] = UIWidget.create_definition({{
        style_id = "circle", value_id = "circle", pass_type = "texture",
        style = {material_values = {use_placeholder_texture = 0, texture_map = nil},
            color = {0, 255, 255, 255}, offset = {0, 0, 0}, size = {ICON_SIZE, ICON_SIZE}},
        visibility_function = function(_content, style) return style.material_values.texture_map ~= nil end,
    }}, "circle_root_" .. i)
end

local HudHitKillICON = class("HudHitKillICON", "HudElementBase")

HudHitKillICON.init = function(self, parent, draw_layer, start_scale)
    HudHitKillICON.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition, widget_definitions = widget_definitions,
    })
    self._slots = manager._slots
    self._leaving_slots = manager._leaving_slots
    self._was_active = true
    self._has_active_content = false
    preload_textures()
end

local function clear_widget(icon_widget, circle_widget)
    if icon_widget and icon_widget.style and icon_widget.style.icon then
        icon_widget.style.icon.material_values.texture_map = nil
    end
    if circle_widget and circle_widget.style and circle_widget.style.circle then
        circle_widget.style.circle.material_values.texture_map = nil
    end
end

local function set_icon_style(icon_widget, texture, alpha, color, size, root_size)
    if not icon_widget or not icon_widget.style or not icon_widget.style.icon then return end
    local style = icon_widget.style.icon
    style.material_values.texture_map = texture
    style.color = {math.floor(alpha), color[1], color[2], color[3]}
    style.size = {math.floor(size), math.floor(size)}
    style.offset = {math.floor((root_size - size) / 2), math.floor((root_size - size) / 2), 0}
end

local function update_item(self, slot, index, now, step_dt, y_pos, size_scale, transparency_factor, colors, is_leaving)
    local icon_widget = self._widgets_by_name["kill_icon_" .. index]
    local circle_widget = self._widgets_by_name["circle_icon_" .. index]
    local root = self._ui_scenegraph["icon_root_" .. index]
    if not root then return end

    if is_leaving then
        if not update_leaving_slot_state(slot, now, size_scale) then
            clear_widget(icon_widget, circle_widget)
            return
        end
        local color = slot.is_headshot and colors.headshot or colors.normal
        set_icon_style(icon_widget, slot.is_headshot and _textures.headshot or _textures.normal,
            255 * slot.render_alpha * transparency_factor, color, ICON_SIZE * size_scale * slot.render_scale, ICON_ROOT_SIZE)
        clear_widget(nil, circle_widget)
    else
        local elapsed = math.max(0, now - slot.start_time)
        if manager._last_kill_time and not manager._natural_fade_start and
            now - manager._last_kill_time >= ((tonumber(HKS:get("kill_icon_duration")) or 20) / 10) then
            manager._natural_fade_start = now
            for _, active in ipairs(manager._slots) do
                if active.active then
                    active.fade_start_time = now
                    active.fade_start_alpha = (active.render_alpha ~= nil and active.render_alpha > 0) and active.render_alpha or 1
                    active.fade_start_scale = (active.render_scale ~= nil and active.render_scale > 0) and active.render_scale or 1
                end
            end
        end
        local scale_t = math.min(1, math.max(0, elapsed / ENTER_DURATION))
        local scale_eased = 1 - (1 - scale_t) ^ 3
        local scale_multiplier = 1.85 + (1.0 - 1.85) * scale_eased
        local alpha = math.min(1, elapsed / ENTER_ALPHA_DURATION)
        if slot.fade_start_time then
            local fade_progress = math.min(1, math.max(0, (now - slot.fade_start_time) / NATURAL_FADE_DURATION))
            if fade_progress >= 1 then
                reset_slot(slot)
                clear_widget(icon_widget, circle_widget)
                return
            end
            local screen_width = UIWorkspaceSettings.screen.size[1]
            local horizontal = tonumber(HKS:get("kill_icon_horizontal_position")) or 50
            local base_x = screen_width * horizontal / 100 - ICON_ROOT_SIZE / 2
            local pull_t = math.min(1, fade_progress / 0.3)
            slot.target_x = slot.target_x + (base_x - slot.target_x) * (0.15 * pull_t)
            if fade_progress < 0.3 then
                alpha = slot.fade_start_alpha
                scale_multiplier = slot.fade_start_scale
            else
                local tail_t = (fade_progress - 0.3) / 0.7
                local fade_eased = tail_t * tail_t
                alpha = slot.fade_start_alpha * (1 - fade_eased)
                scale_multiplier = slot.fade_start_scale * (1.0 + (0.88 - 1.0) * tail_t)
            end
        end
        if step_dt > 0 then
            local move_alpha = 1 - math.exp(-16 * step_dt)
            slot.current_x = slot.current_x + (slot.target_x - slot.current_x) * move_alpha
        end
        slot.render_alpha = alpha
        slot.render_scale = scale_multiplier
        root.position[1] = slot.current_x
        root.position[2] = y_pos
        local color = slot.is_headshot and colors.headshot or colors.normal
        set_icon_style(icon_widget, slot.is_headshot and _textures.headshot or _textures.normal,
            255 * alpha * transparency_factor, color, ICON_SIZE * size_scale * slot.render_scale, ICON_ROOT_SIZE)
        local ring_style = circle_widget and circle_widget.style and circle_widget.style.circle
        if slot.is_headshot and ring_style and _textures.circle then
            local ring_t = math.min(1, math.max(0, elapsed / RING_DURATION))
            if ring_t < 1 then
                local eased_ring = 1 - (1 - ring_t) ^ 4
                local ring_scale = 0.85 + (2.8 - 0.85) * eased_ring
                ring_style.material_values.texture_map = _textures.circle
                ring_style.size = {math.floor(ICON_SIZE * size_scale * ring_scale), math.floor(ICON_SIZE * size_scale * ring_scale)}
                ring_style.offset = {math.floor((ICON_ROOT_SIZE - ring_style.size[1]) / 2), math.floor((ICON_ROOT_SIZE - ring_style.size[2]) / 2), 0}
                ring_style.color = {math.floor(255 * ((1 - ring_t) ^ 1.8) * transparency_factor), colors.headshot[1], colors.headshot[2], colors.headshot[3]}
            else
                ring_style.material_values.texture_map = nil
            end
        else
            clear_widget(nil, circle_widget)
        end
    end
    root.position[1] = slot.current_x
    root.position[2] = y_pos
end

HudHitKillICON.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local step_dt = math.max(tonumber(dt) or 0, 0)
    if not HKS:get("enabled") or HKS:get("kill_icon_style") ~= "BF5" or not HKS:get("kill_icon_enabled") then
        if self._was_active or has_active_slots(self._slots, self._leaving_slots) then
            manager.clear()
            for i = 1, MAX_SLOTS + MAX_LEAVING_SLOTS do
                clear_widget(self._widgets_by_name["kill_icon_" .. i], self._widgets_by_name["circle_icon_" .. i])
            end
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
        end
        return
    end

    if not has_active_slots(self._slots, self._leaving_slots) then
        if self._was_active then
            for i = 1, MAX_SLOTS + MAX_LEAVING_SLOTS do
                clear_widget(self._widgets_by_name["kill_icon_" .. i], self._widgets_by_name["circle_icon_" .. i])
            end
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
            HudHitKillICON.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        end
        return
    end

    self._was_active = true
    self._has_active_content = true

    local size_scale = get_size_scale()
    local vert_pos = tonumber(HKS:get("kill_icon_vertical_position")) or 75
    local screen_height = UIWorkspaceSettings.screen.size[2]
    local y_pos = (vert_pos / 100) * (screen_height - ICON_ROOT_SIZE)
    local transparency_factor = (tonumber(HKS:get("kill_icon_transparency")) or 100) / 100
    local colors = {
        normal = {HKS:get("kill_icon_normal_color_r") or 255, HKS:get("kill_icon_normal_color_g") or 255, HKS:get("kill_icon_normal_color_b") or 255},
        headshot = {HKS:get("kill_icon_headshot_color_r") or 255, HKS:get("kill_icon_headshot_color_g") or 140, HKS:get("kill_icon_headshot_color_b") or 20},
    }
    recompute_targets()
    local now = Managers.time:time("main")
    for i = 1, MAX_SLOTS do
        local slot = manager._slots[i]
        if slot.active then update_item(self, slot, i, now, step_dt, y_pos, size_scale, transparency_factor, colors, false)
        else clear_widget(self._widgets_by_name["kill_icon_" .. i], self._widgets_by_name["circle_icon_" .. i]) end
    end
    for i = 1, MAX_LEAVING_SLOTS do
        local slot = manager._leaving_slots[i]
        local index = MAX_SLOTS + i
        if slot.active then update_item(self, slot, index, now, step_dt, y_pos, size_scale, transparency_factor, colors, true)
        else clear_widget(self._widgets_by_name["kill_icon_" .. index], self._widgets_by_name["circle_icon_" .. index]) end
    end
    self._has_active_content = has_active_slots(self._slots, self._leaving_slots)
    self._update_scenegraph = true
    HudHitKillICON.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillICON.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not self._has_active_content or not has_active_slots(self._slots, self._leaving_slots) then return end
    if not HKS:get("enabled") or HKS:get("kill_icon_style") ~= "BF5" or not HKS:get("kill_icon_enabled") then return end
    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then return end
    HudHitKillICON.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillICON
