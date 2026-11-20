-- luacheck: globals get_mod Managers class UIWorkspaceSettings
local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local CANVAS_BASE_SIZE = 256
local BASE_DISPLAY_SCALE = 0.78
local VALORANT_DISPLAY_MAX = 5
local HEADSHOT_BADGE_Y_OFFSET = -16
local BAR_LAYOUT_ANGLES = {
    [1] = {0},
    [2] = {-90, 90},
    [3] = {0, -120, 120},
    [4] = {0, -90, 90, 180},
    [5] = {0, -72, 72, -144, 144},
}

local function clamp01(value)
    value = tonumber(value) or 0
    return value < 0 and 0 or value > 1 and 1 or value
end

local function smoothstep(value)
    value = clamp01(value)
    return value * value * (3 - 2 * value)
end

local function ease_out_cubic(value)
    local u = 1 - clamp01(value)
    return 1 - u * u * u
end

local function ease_in_quart(value)
    value = clamp01(value)
    return value * value * value * value
end

local function ease_out_quart(value)
    local u = 1 - clamp01(value)
    return 1 - u * u * u * u
end

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    background = {
        parent = "screen",
        horizontal_alignment = "center",
        vertical_alignment = "bottom",
        size = {CANVAS_BASE_SIZE, CANVAS_BASE_SIZE},
        position = {0, -180, 0},
    },
    kill_icon = {
        parent = "background",
        horizontal_alignment = "center",
        vertical_alignment = "center",
        size = {CANVAS_BASE_SIZE, CANVAS_BASE_SIZE},
    },
}

local function texture_style(z)
    return {
        material_values = {use_placeholder_texture = 0, texture_map = nil},
        color = {0, 255, 255, 255},
        offset = {0, 0, z},
        size = {0, 0},
    }
end

local function texture_uv_style(z)
    local style = texture_style(z)
    style.uvs = {{0, 0}, {1, 1}}
    return style
end

local function rotated_style(z)
    local style = texture_style(z)
    style.angle = 0
    style.pivot = {0, 0}
    return style
end

local function visible_when_loaded(_content, style)
    return style.material_values.texture_map ~= nil and style.color[1] > 0
end

local passes = {}
local function add_pass(style_id, pass_type, style)
    passes[#passes + 1] = {
        style_id = style_id,
        value_id = style_id,
        pass_type = pass_type,
        style = style,
        visibility_function = visible_when_loaded,
    }
end

add_pass("vignette", "texture", texture_style(1))
add_pass("fx_base_right", "texture_uv", texture_uv_style(2))
add_pass("fx_base_left", "texture_uv", texture_uv_style(2))
add_pass("base_ring", "texture_uv", texture_uv_style(3))
for i = 1, 5 do
    add_pass("pip_hover_" .. i, "rotated_texture", rotated_style(4))
end
for i = 1, 5 do
    add_pass("pip_up_" .. i, "rotated_texture", rotated_style(5))
end
add_pass("base_frame", "texture", texture_style(6))
add_pass("emblem_main", "texture", texture_style(7))
add_pass("emblem_flash", "texture", texture_style(8))
add_pass("headshot_badge", "texture", texture_style(9))
add_pass("fx_hero_flame", "texture_uv", texture_uv_style(10))
add_pass("fx_large_sparks", "texture_uv", texture_uv_style(11))
for i = 1, 4 do
    add_pass("fx_x_sparks_" .. i, "rotated_texture", rotated_style(12))
end

local widget_definitions = {
    valorant_kill_icon = UIWidget.create_definition(passes, "kill_icon"),
}

local HudHitKillValorant = class("HudHitKillValorant", "HudElementBase")

local function output_enabled()
    return HKS:get("enabled") ~= false and HKS:get("killstreak_enabled") ~= false and
        HKS:get("kill_icon_style") == "Valorant" and HKS:get("kill_icon_enabled") ~= false
end

local function set_hidden(style)
    style.color[1] = 0
end

local function set_texture(style, texture, alpha, red, green, blue)
    style.material_values.texture_map = texture
    style.color = {math.floor(clamp01(alpha) * 255), red or 255, green or 255, blue or 255}
end

local function set_offset(style, x, y, width, height, z)
    style.size = {width, height}
    style.offset = {128 + x - width * 0.5, 128 + y - height * 0.5, z}
end

local function set_uv(style, texture, alpha, width, height, x, y, z, frame_idx, cols, rows, flip_x, total_frames)
    set_texture(style, texture, alpha, 69, 255, 190)
    set_offset(style, x, y, width, height, z)
    frame_idx = math.floor(frame_idx or -1)
    if frame_idx < 0 then
        style.color[1] = 0
        return
    end
    total_frames = total_frames or cols * rows
    if frame_idx >= total_frames then
        style.color[1] = 0
        return
    end
    local col = frame_idx % cols
    local row = math.floor(frame_idx / cols)
    local u0, u1 = col / cols, (col + 1) / cols
    local v0, v1 = row / rows, (row + 1) / rows
    if flip_x then u0, u1 = u1, u0 end
    style.uvs[1][1], style.uvs[1][2] = u0, v0
    style.uvs[2][1], style.uvs[2][2] = u1, v1
end

local function atlas_frame(elapsed, start_time, interval)
    return math.floor(math.max(0, elapsed - start_time) / interval)
end

HudHitKillValorant.init = function(self, parent, draw_layer, start_scale)
    HudHitKillValorant.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })
    self._was_active = false
    self._has_active_content = false
    if HKS.HitKillSoundsEvents and HKS.HitKillSoundsEvents._preload_valorant_icons then
        HKS.HitKillSoundsEvents._preload_valorant_icons()
    end
end

HudHitKillValorant.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local widget = self._widgets_by_name.valorant_kill_icon
    local state = HKS.HitKillSoundsValorantIconState
    if not output_enabled() or not state or state.streak_count <= 0 then
        if self._was_active then
            for _, pass in ipairs(passes) do set_hidden(widget.style[pass.style_id]) end
            self._update_scenegraph = true
        end
        self._was_active = false
        self._has_active_content = false
        return
    end

    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then
        return
    end

    local now = Managers.time:time("main")
    if now >= state.icon_show_until then
        for _, pass in ipairs(passes) do set_hidden(widget.style[pass.style_id]) end
        self._was_active = false
        self._has_active_content = false
        return
    end

    local tex = HKS.HitKillSoundsValorantIconTex or {}
    local streak = math.max(1, math.min(VALORANT_DISPLAY_MAX, tonumber(state.streak_count) or 1))
    local event_time = tonumber(state.last_event_time) or now
    local elapsed = math.max(0, now - event_time)
    local duration = math.max(0.25, (tonumber(state.icon_show_until) or now) - event_time)
    local fade_out = math.min(0.22, duration)
    local fade_start = duration - fade_out
    local global_alpha, outro_scale = 1, 1
    if elapsed >= fade_start then
        local fade_t = clamp01((elapsed - fade_start) / math.max(fade_out, 0.001))
        global_alpha = 1 - fade_t
        outro_scale = 1 - fade_t * fade_t
    end
    local transparency = (tonumber(HKS:get("kill_icon_transparency_valorant")) or 100) / 100
    global_alpha = global_alpha * transparency
    local scale_factor = BASE_DISPLAY_SCALE * ((tonumber(HKS:get("kill_icon_size_valorant")) or 10) / 10)
    local root_y_offset
    if elapsed < 0.05 then
        root_y_offset = -30 * scale_factor
    elseif elapsed < 0.10 then
        root_y_offset = -30 * scale_factor * (1 - smoothstep((elapsed - 0.05) / 0.05))
    else
        root_y_offset = 0
    end

    local background = self._ui_scenegraph.background
    local screen_width, screen_height = UIWorkspaceSettings.screen.size[1], UIWorkspaceSettings.screen.size[2]
    local half_extent = 128 * scale_factor
    local h_pos = tonumber(HKS:get("kill_icon_horizontal_position_valorant")) or 50
    local v_pos = tonumber(HKS:get("kill_icon_vertical_position_valorant")) or 15
    local center_x = math.max(half_extent, math.min(screen_width - half_extent, screen_width * h_pos / 100))
    local center_y = math.max(half_extent, math.min(screen_height - half_extent, screen_height - 180 - (v_pos / 100) * math.max(screen_height - CANVAS_BASE_SIZE, 1)))
    background.position[1] = center_x - screen_width * 0.5
    background.position[2] = center_y - screen_height + CANVAS_BASE_SIZE * 0.5

    local ring_reveal, ring_scale = 1, 1
    if elapsed < 0.05 then
        ring_reveal, ring_scale = 0, 1.1
    elseif elapsed < 0.55 then
        ring_reveal = smoothstep((elapsed - 0.05) / 0.50)
        ring_scale = 1.1 - 0.1 * ring_reveal
    end

    local styles = widget.style
    set_texture(styles.vignette, tex.vignette, global_alpha)
    set_offset(styles.vignette, 0, root_y_offset, 256 * scale_factor, 256 * scale_factor, 1)

    local base_key = streak >= 5 and "fx_base_t3" or streak >= 3 and "fx_base_t2" or "fx_base_t1"
    local base_rows = streak >= 5 and 6 or 7
    local base_frame = atlas_frame(elapsed, 0, 0.025)
    local base_total_frames = streak >= 5 and 42 or 49
    set_uv(styles.fx_base_right, tex[base_key], global_alpha, 256 * scale_factor, 256 * scale_factor, 128 * scale_factor, root_y_offset, 2, base_frame, 7, base_rows, false, base_total_frames)
    set_uv(styles.fx_base_left, tex[base_key], global_alpha, 256 * scale_factor, 256 * scale_factor, -128 * scale_factor, root_y_offset, 2, base_frame, 7, base_rows, true, base_total_frames)
    styles.fx_base_right.color[1] = elapsed <= 0.62 and styles.fx_base_right.color[1] or 0
    styles.fx_base_left.color[1] = styles.fx_base_right.color[1]

    set_texture(styles.base_ring, tex.base_ring, global_alpha * ring_reveal)
    styles.base_ring.uvs[1][1], styles.base_ring.uvs[1][2] = 0, 0
    styles.base_ring.uvs[2][1], styles.base_ring.uvs[2][2] = 1, ring_reveal
    local ring_w = 170 * scale_factor * ring_scale
    styles.base_ring.size = {ring_w, ring_w * ring_reveal}
    styles.base_ring.offset = {128 - ring_w * 0.5, 128 + root_y_offset - ring_w * 0.5, 3}

    local travel = elapsed < 0.02 and 0 or elapsed <= 0.18 and 15 * ease_out_quart((elapsed - 0.02) / 0.16) or elapsed <= 0.27 and 15 or elapsed < 0.62 and 15 * (1 - ease_in_quart((elapsed - 0.27) / 0.35)) or 0
    local bar_rot_deg = 0
    if streak >= 2 and elapsed > 0.75 then
        local target = streak >= 5 and 360 or 180
        bar_rot_deg = target * ease_out_cubic((elapsed - 0.75) / (target / 360)) * (state.spin_dir or 1)
    end
    local hover_alpha = elapsed < 0.15 and smoothstep(elapsed / 0.15) or elapsed < 0.30 and 1 or elapsed < 0.75 and 1 - 0.4 * smoothstep((elapsed - 0.30) / 0.45) or 0.6
    for i = 1, 5 do
        local angle = BAR_LAYOUT_ANGLES[streak][i]
        local active = angle ~= nil
        local deg = (angle or 0) + bar_rot_deg
        local rad = math.rad(deg)
        local radius = (76 + travel) * scale_factor * ring_scale
        local px, py = radius * math.sin(rad), -radius * math.cos(rad) + root_y_offset
        local pw, ph = 68 * scale_factor * ring_scale, 64 * scale_factor * ring_scale
        for _, prefix in ipairs({"pip_hover_", "pip_up_"}) do
            local style = styles[prefix .. i]
            set_texture(style, tex[prefix == "pip_hover_" and "base_pip_hover" or "base_pip"], active and global_alpha * (prefix == "pip_hover_" and hover_alpha or 1) or 0, 69, 255, 190)
            set_offset(style, px, py, pw, ph, prefix == "pip_hover_" and 4 or 5)
            -- The source pip texture faces outward at the top of the ring.
            -- Darktide's rotated_texture screen-space rotation runs opposite
            -- to the polar angle used for the position, so negate it to keep
            -- every arc tangent to the ring and facing outward.
            style.angle = -rad
            style.pivot[1], style.pivot[2] = pw * 0.5, ph * 0.5
        end
    end

    set_texture(styles.base_frame, tex.base_frame, global_alpha)
    set_offset(styles.base_frame, 0, root_y_offset, 200 * scale_factor, 256 * scale_factor, 6)
    local emblem_style = HKS:get("valorant_emblem_style") == "standard_x" and "emblem_x" or "emblem_skull"
    local emblem_w, emblem_h = emblem_style == "emblem_x" and 76 or 84, emblem_style == "emblem_x" and 100 or 112
    emblem_w, emblem_h = emblem_w * scale_factor * outro_scale, emblem_h * scale_factor * outro_scale
    set_texture(styles.emblem_main, tex[emblem_style], global_alpha)
    set_offset(styles.emblem_main, 0, root_y_offset, emblem_w, emblem_h, 7)

    local pulse = 0
    if elapsed < 0.50 then
        local phase = elapsed % 0.14
        if phase < 0.08 then
            pulse = phase < 0.02 and phase / 0.02 or phase > 0.06 and (0.08 - phase) / 0.02 or 1
        end
    end
    set_texture(styles.emblem_flash, tex[emblem_style], global_alpha * 0.9 * pulse, 255, 42, 54)
    set_offset(styles.emblem_flash, 0, root_y_offset, emblem_w, emblem_h, 8)

    local hs_t = elapsed - 0.15
    local hs_alpha = state.is_headshot and hs_t >= 0 and global_alpha or 0
    local container_scale = hs_t < 0.25 and 2 - clamp01(hs_t / 0.25) or 1
    local bounce_nodes = {1.155, 1.0, 1.106, 1.0, 1.076, 1.0, 1.049, 1.0}
    local bounce_scale = 1
    if hs_t >= 0 and hs_t < 0.35 then
        local step_index = math.floor(hs_t / 0.05) + 1
        local local_t = (hs_t % 0.05) / 0.05
        bounce_scale = bounce_nodes[step_index] + (bounce_nodes[math.min(step_index + 1, #bounce_nodes)] - bounce_nodes[step_index]) * smoothstep(local_t)
    end
    local hs_red, hs_green, hs_blue = 255, 42, 54
    if hs_t >= 0 and hs_t < 0.35 and math.floor(hs_t / 0.05) % 2 == 0 then
        hs_green, hs_blue = 255, 255
    end
    set_texture(styles.headshot_badge, tex.headshot, hs_alpha, hs_red, hs_green, hs_blue)
    local hs_size = 38.4 * scale_factor * container_scale * bounce_scale * outro_scale
    set_offset(styles.headshot_badge, 0, root_y_offset + HEADSHOT_BADGE_Y_OFFSET * scale_factor, hs_size, hs_size, 9)

    local particle_enabled = HKS:get("valorant_particle_fx_enabled") ~= false
    if particle_enabled then
        set_uv(styles.fx_hero_flame, tex.fx_hero_flame, global_alpha, 200 * scale_factor, 224 * scale_factor, 0, root_y_offset - 30 * scale_factor, 10, atlas_frame(elapsed, 0, 0.029), 5, 4, false, 20)
        set_uv(styles.fx_large_sparks, tex.fx_large_sparks, streak >= 5 and global_alpha or 0, 300 * scale_factor, 300 * scale_factor, 0, root_y_offset, 11, atlas_frame(elapsed, 0, 0.025), 8, 7, false, 52)
        local spark_positions = {{-100, -100, -45}, {100, -100, 45}, {100, 100, 135}, {-100, 100, -135}}
        for i, position in ipairs(spark_positions) do
            local style = styles["fx_x_sparks_" .. i]
            local spark_elapsed = elapsed - 0.15
            set_uv(style, tex.fx_x_sparks, state.is_headshot and spark_elapsed >= 0 and global_alpha or 0, 80 * scale_factor, 250 * scale_factor, position[1] * scale_factor, position[2] * scale_factor + root_y_offset, 12, atlas_frame(spark_elapsed, 0, 0.025), 6, 5, false, 29)
            style.angle = math.rad(position[3])
            style.pivot[1], style.pivot[2] = 40 * scale_factor, 125 * scale_factor
        end
    else
        for _, key in ipairs({"fx_hero_flame", "fx_large_sparks", "fx_x_sparks_1", "fx_x_sparks_2", "fx_x_sparks_3", "fx_x_sparks_4"}) do set_hidden(styles[key]) end
    end

    self._was_active = true
    self._has_active_content = true
    self._update_scenegraph = true
    HudHitKillValorant.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillValorant.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not output_enabled() then return end
    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then return end
    if not self._has_active_content then return end
    HudHitKillValorant.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillValorant
