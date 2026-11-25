-- luacheck: globals get_mod Managers class
local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local CFG = {
    BASE_VICTIM_FONT_SIZE = 22,
    BASE_WEAPON_FONT_SIZE = 18,
    BASE_VALUE_FONT_SIZE = 32,
    BASE_COMBO_FONT_SIZE = 14,
    BASE_PAD_X = 14,
    BASE_PAD_Y = 9,
    BASE_ROW_GAP = 3,
    BASE_COL_GAP = 16,
    BASE_ACCENT_W = 3,
    BASE_DIVIDER_W = 1,
    MAX_TEXT_COL_WIDTH = 420,
    MAX_VALUE_WIDTH = 180,
    ICON_TO_BOX_RATIO = 0.80,
    SCREEN_EDGE_MARGIN = 12,

    ENTER_DURATION = 0.14,
    ENTER_OPEN_DURATION = 0.13,
    ENTER_REVEAL_DELAY = 0.01,
    ENTER_REVEAL_DURATION = 0.13,
    ENTER_TEXT_DELAY = 0.03,
    ENTER_TEXT_DURATION = 0.10,
    ENTER_ALPHA_DURATION = 0.04,
    ENTER_MIN_OPEN_Y = 0.02,

    SWITCH_DURATION = 0.14,
    SWITCH_TEXT_DURATION = 0.09,
    FLASH_DURATION = 0.10,
    GLOW_DURATION = 0.24,
    SHEEN_ENTER_DELAY = 0.09,
    SHEEN_ENTER_BASE_DURATION = 0.24,
    SHEEN_SWITCH_DELAY = 0.02,
    SHEEN_SWITCH_BASE_DURATION = 0.20,
    SHEEN_S_START = 0.06,
    SHEEN_S_END = 0.96,
    SHEEN_COLS = 4,
    SHEEN_ROWS = 4,
    SHEEN_FRAMES = 16,
    SHEEN_UV_INSET = 0.5 / 512,
    BOSS_SPIN_DELAY = 0.09,
    BOSS_SPIN_DURATION = 0.39,
    VALUE_FLASH_DURATION = 0.10,
    EXIT_DURATION = 0.20,
    EXIT_TEXT_FADE_START = 0.45,
    EXIT_TEXT_FADE_END = 0.88,
    EXIT_ALPHA_FADE_START = 0.76,

    MAX_QUEUE_SIZE = 4,
    MIN_SWITCH_INTERVAL = 0.18,
    URGENT_PREEMPT_INTERVAL = 0.08,
    BOSS_HOLD_PROTECT_INTERVAL = 0.65,
    SAME_BURST_MERGE_WINDOW = 0.08,
    BOSS_DURATION_MULTIPLIER = 1.35,
}

local BF1_RED_COLOR = {255, 56, 56}
local BOSS_DEFAULT_ACCENT_COLOR = {235, 58, 52}
local TIER_COLORS = {
    boss = {255, 68, 64},
    special = {255, 148, 42},
    elite = {255, 208, 72},
    normal = {255, 56, 56},
}

local _textures = {
    default = nil,
    headshot = nil,
    boss = nil,
    default_sheen = nil,
    headshot_sheen = nil,
    boss_sheen = nil,
    card_sheen = nil,
}
local textures_load_started = false

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function now_time()
    if Managers and Managers.time and Managers.time.time then
        return Managers.time:time("main")
    end
    return os.clock()
end

local function copy_context(ctx)
    return {
        kill_type = ctx.kill_type or "default",
        is_headshot = ctx.is_headshot == true,
        is_boss = ctx.is_boss == true,
        enemy_tier = ctx.enemy_tier or "normal",
        victim_name = tostring(ctx.victim_name or ""),
        weapon_name = tostring(ctx.weapon_name or ""),
        score = tonumber(ctx.score) or 100,
        max_health = tonumber(ctx.max_health) or 0,
        damage = tonumber(ctx.damage) or 0,
        priority = tonumber(ctx.priority) or 1,
        batch_count = math.max(1, tonumber(ctx.batch_count) or 1),
        created_at = tonumber(ctx.created_at) or now_time(),
    }
end

HKS.HitKillBF1Manager = {
    _state = "idle",
    _current = nil,
    _queue = {},
    _start_time = 0,
    _last_switch_time = 0,
    _exit_start_time = 0,
    _last_push_time = 0,
    _current_text_box_w = 0,
    _last_open_y = 0,
    _enter_from_open_y = CFG.ENTER_MIN_OPEN_Y,
    _entry_is_switch = false,
    _size_cache = {},
    _size_cache_count = 0,
}
local manager = HKS.HitKillBF1Manager

manager.clear = function()
    manager._state = "idle"
    manager._current = nil
    for i = #manager._queue, 1, -1 do
        manager._queue[i] = nil
    end
    manager._start_time = 0
    manager._last_switch_time = 0
    manager._exit_start_time = 0
    manager._last_push_time = 0
    manager._current_text_box_w = 0
    manager._last_open_y = 0
    manager._enter_from_open_y = CFG.ENTER_MIN_OPEN_Y
    manager._entry_is_switch = false
end

local function upgrade_entry_metadata(target, incoming)
    target.batch_count = (target.batch_count or 1) + (incoming.batch_count or 1)
    if (incoming.priority or 1) > (target.priority or 1) then
        target.kill_type = incoming.kill_type
        target.is_headshot = incoming.is_headshot
        target.is_boss = incoming.is_boss
        target.enemy_tier = incoming.enemy_tier
        target.victim_name = incoming.victim_name
        target.weapon_name = incoming.weapon_name
        target.score = incoming.score
        target.max_health = incoming.max_health
        target.damage = incoming.damage
        target.priority = incoming.priority
    else
        target.score = math.max(target.score or 0, incoming.score or 0)
    end
end

local function begin_entry(ctx, now, state_name, resume_open_y)
    manager._current = ctx
    manager._state = state_name
    manager._start_time = now
    manager._last_switch_time = now
    manager._exit_start_time = 0
    manager._entry_is_switch = state_name == "switch_punch"
    if state_name == "entering" then
        manager._current_text_box_w = 0
        manager._enter_from_open_y = clamp(tonumber(resume_open_y) or CFG.ENTER_MIN_OPEN_Y, CFG.ENTER_MIN_OPEN_Y, 1)
    else
        manager._enter_from_open_y = 1
    end
end

local function find_lowest_priority_queue_index(queue)
    local victim_index = 1
    local victim = queue[1]
    for i = 2, #queue do
        local candidate = queue[i]
        if candidate.priority < victim.priority or
            (candidate.priority == victim.priority and candidate.created_at < victim.created_at) then
            victim_index = i
            victim = candidate
        end
    end
    return victim_index, victim
end

local function find_highest_priority_queue_index(queue)
    local best_index = nil
    local best = nil
    for i = 1, #queue do
        local candidate = queue[i]
        if not best or candidate.priority > best.priority or
            (candidate.priority == best.priority and candidate.created_at < best.created_at) then
            best_index = i
            best = candidate
        end
    end
    return best_index, best
end

manager.push_kill = function(raw_ctx, optional_now)
    if type(raw_ctx) ~= "table" then
        return
    end
    local now = tonumber(optional_now) or now_time()
    local ctx = copy_context(raw_ctx)
    ctx.created_at = now
    manager._last_push_time = now

    if manager._state == "idle" or manager._state == "exiting" or not manager._current then
        local resume_open_y = manager._state == "exiting" and manager._last_open_y or CFG.ENTER_MIN_OPEN_Y
        for i = #manager._queue, 1, -1 do
            manager._queue[i] = nil
        end
        begin_entry(ctx, now, "entering", resume_open_y)
        return
    end

    local queue = manager._queue
    local current = manager._current

    -- Same-burst low-priority merge (horde cleave protection)
    if ctx.priority <= 2 then
        if #queue == 0 and current.priority <= 2 and (now - manager._start_time) <= CFG.SAME_BURST_MERGE_WINDOW then
            local upgraded = ctx.priority > current.priority
            upgrade_entry_metadata(current, ctx)
            if upgraded then
                manager._state = "switch_punch"
                manager._entry_is_switch = true
                manager._start_time = now
                manager._last_switch_time = now
            end
            return
        end

        local tail = queue[#queue]
        if tail and tail.priority <= 2 and (now - tail.created_at) <= CFG.SAME_BURST_MERGE_WINDOW then
            upgrade_entry_metadata(tail, ctx)
            return
        end
    end

    if #queue < CFG.MAX_QUEUE_SIZE then
        queue[#queue + 1] = ctx
        return
    end

    local victim_index, victim = find_lowest_priority_queue_index(queue)
    if victim and (ctx.priority > victim.priority or (ctx.priority >= 3 and ctx.priority == victim.priority)) then
        table.remove(queue, victim_index)
        queue[#queue + 1] = ctx
    end
end

local function textures_ready()
    return _textures.default ~= nil and _textures.headshot ~= nil and _textures.boss ~= nil
end

local function preload_textures_legacy()
    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.start_player then
        HKS.HitKillSoundsPlayer.start_player()
    end
    local host = HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host
    if not host then
        textures_load_started = false
        return
    end
    local urls = {
        default = host .. "image?path=cartoon_preview/kill_icon/BF1/kill_default.png",
        headshot = host .. "image?path=cartoon_preview/kill_icon/BF1/kill_headshot.png",
        boss = host .. "image?path=cartoon_preview/kill_icon/BF1/kill_boss.png",
        default_sheen = host .. "image?path=cartoon_preview/kill_icon/BF1/kill_default_sheen_atlas.png",
        headshot_sheen = host .. "image?path=cartoon_preview/kill_icon/BF1/kill_headshot_sheen_atlas.png",
        boss_sheen = host .. "image?path=cartoon_preview/kill_icon/BF1/kill_boss_sheen_atlas.png",
        card_sheen = host .. "image?path=cartoon_preview/kill_icon/BF1/bf1_card_sheen.png",
    }
    local pending = 0
    for _ in pairs(urls) do
        pending = pending + 1
    end
    for key, url in pairs(urls) do
        local texture_key = key
        local promise = Managers.url_loader:load_texture(url)
        if promise and promise.next then
            promise:next(function(data)
                if data and data.texture then
                    _textures[texture_key] = data.texture
                end
                pending = pending - 1
                if pending <= 0 and not textures_ready() then
                    textures_load_started = false
                end
            end)
            if promise.catch then
                promise:catch(function()
                    pending = pending - 1
                    if pending <= 0 and not textures_ready() then
                        textures_load_started = false
                    end
                end)
            end
        else
            pending = pending - 1
        end
    end
    if pending <= 0 and not textures_ready() then
        textures_load_started = false
    end
end

local function preload_textures()
    if textures_ready() or textures_load_started then
        return
    end
    textures_load_started = true
    if HKS.HitKillSoundsAssetsBackend and HKS.HitKillSoundsAssetsBackend.load_bf1_icons then
        HKS.HitKillSoundsAssetsBackend.load_bf1_icons(_textures, function()
            preload_textures_legacy()
        end, function(is_ok)
            if not is_ok and not textures_ready() then
                textures_load_started = false
            end
        end)
    else
        preload_textures_legacy()
    end
end

local function rect_visible(_content, style)
    return style.color[1] > 0 and style.size[1] > 0 and style.size[2] > 0
end

local function texture_visible(_content, style)
    return style.material_values.texture_map ~= nil and style.color[1] > 0 and
        style.size[1] > 0 and style.size[2] > 0
end

local function make_text_visible(value_id)
    return function(content, style)
        local text = content[value_id]
        return text ~= nil and text ~= "" and style.text_color[1] > 0
    end
end

local function create_rect_style(z)
    return {
        horizontal_alignment = "left",
        vertical_alignment = "top",
        color = {0, 0, 0, 0},
        offset = {0, 0, z},
        size = {0, 0},
    }
end

local function create_texture_style(z, rotated)
    local style = {
        horizontal_alignment = "left",
        vertical_alignment = "top",
        material_values = {use_placeholder_texture = 0, texture_map = nil},
        color = {0, 255, 255, 255},
        offset = {0, 0, z},
        size = {0, 0},
    }
    if rotated then
        style.uvs = {{0, 0}, {1, 1}}
        style.angle = 0
        style.pivot = {0, 0}
    end
    return style
end

local function create_texture_uv_style(z)
    local style = create_texture_style(z, false)
    style.uvs = {{0, 0}, {1, 1}}
    return style
end

local function create_text_style(font_size, z, horiz_align)
    local base_style = UIFontSettings.hud_body
    return {
        font_type = "proxima_nova_bold",
        font_size = font_size,
        line_spacing = base_style and base_style.line_spacing or 1.2,
        drop_shadow = true,
        horizontal_alignment = "left",
        vertical_alignment = "top",
        text_horizontal_alignment = horiz_align or "left",
        text_vertical_alignment = "center",
        text_color = {0, 255, 255, 255},
        default_text_color = {0, 255, 255, 255},
        offset = {0, 0, z},
        size = {0, 0},
    }
end

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
    bf1_root = {
        parent = "screen",
        horizontal_alignment = "left",
        vertical_alignment = "top",
        size = UIWorkspaceSettings.screen.size,
        position = {0, 0, 0},
    },
}

local bf1_passes = {
    {
        style_id = "icon_box_bg",
        pass_type = "rect",
        style = create_rect_style(1),
        visibility_function = rect_visible,
    },
    {
        style_id = "text_box_bg",
        pass_type = "rect",
        style = create_rect_style(1),
        visibility_function = rect_visible,
    },
    {
        style_id = "accent_bar",
        pass_type = "rect",
        style = create_rect_style(2),
        visibility_function = rect_visible,
    },
    {
        style_id = "box_divider",
        pass_type = "rect",
        style = create_rect_style(2),
        visibility_function = rect_visible,
    },
    {
        style_id = "icon_glow",
        value_id = "icon_glow",
        pass_type = "texture",
        style = create_texture_style(4, false),
        visibility_function = texture_visible,
    },
    {
        style_id = "icon_main",
        value_id = "icon_main",
        pass_type = "rotated_texture",
        style = create_texture_style(5, true),
        visibility_function = texture_visible,
    },
    {
        style_id = "icon_sheen",
        value_id = "icon_sheen",
        pass_type = "rotated_texture",
        style = create_texture_style(6, true),
        visibility_function = texture_visible,
    },
    {
        style_id = "victim_text",
        value_id = "victim_text",
        value = "",
        pass_type = "text",
        style = create_text_style(CFG.BASE_VICTIM_FONT_SIZE, 7, "right"),
        visibility_function = make_text_visible("victim_text"),
    },
    {
        style_id = "weapon_text",
        value_id = "weapon_text",
        value = "",
        pass_type = "text",
        style = create_text_style(CFG.BASE_WEAPON_FONT_SIZE, 7, "right"),
        visibility_function = make_text_visible("weapon_text"),
    },
    {
        style_id = "value_text",
        value_id = "value_text",
        value = "",
        pass_type = "text",
        style = create_text_style(CFG.BASE_VALUE_FONT_SIZE, 7, "center"),
        visibility_function = make_text_visible("value_text"),
    },
    {
        style_id = "combo_badge_text",
        value_id = "combo_badge_text",
        value = "",
        pass_type = "text",
        style = create_text_style(CFG.BASE_COMBO_FONT_SIZE, 8, "right"),
        visibility_function = make_text_visible("combo_badge_text"),
    },
    {
        style_id = "card_sheen",
        value_id = "card_sheen",
        pass_type = "texture_uv",
        style = create_texture_uv_style(9),
        visibility_function = texture_visible,
    },
}

local widget_definitions = {
    bf1_banner = UIWidget.create_definition(bf1_passes, "bf1_root"),
}

local function output_enabled()
    return HKS:get("enabled") ~= false and
        HKS:get("kill_icon_style") == "BF1" and
        HKS:get("kill_icon_enabled") ~= false
end

local function is_in_hub()
    local game_mode_manager = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()
    return game_mode_name == "hub"
end

local function get_rgb(prefix, def_r, def_g, def_b)
    return {
        clamp(tonumber(HKS:get(prefix .. "_r")) or def_r, 0, 255),
        clamp(tonumber(HKS:get(prefix .. "_g")) or def_g, 0, 255),
        clamp(tonumber(HKS:get(prefix .. "_b")) or def_b, 0, 255),
    }
end

local function mix_rgb(base, target, ratio)
    local t = clamp01(ratio)
    return {
        clamp(math.floor(base[1] + (target[1] - base[1]) * t + 0.5), 0, 255),
        clamp(math.floor(base[2] + (target[2] - base[2]) * t + 0.5), 0, 255),
        clamp(math.floor(base[3] + (target[3] - base[3]) * t + 0.5), 0, 255),
    }
end

local function resolve_colors()
    return {
        default = get_rgb("bf1_normal_color", 255, 255, 255),
        headshot = get_rgb("bf1_headshot_color", 232, 185, 7),
        boss = get_rgb("bf1_boss_color", 255, 255, 255),
    }
end

local function resolve_accent_color(kill_type, colors)
    if kill_type == "headshot" then
        return colors.headshot
    elseif kill_type == "boss" then
        local c = colors.boss
        if c[1] == 255 and c[2] == 255 and c[3] == 255 then
            return BOSS_DEFAULT_ACCENT_COLOR
        end
        return c
    end
    return colors.default
end

local function resolve_icon_color(kill_type, elapsed, colors)
    local base = colors[kill_type] or colors.default
    if elapsed >= CFG.FLASH_DURATION or kill_type == "default" then
        return base
    end
    local flash_t = (1 - clamp01(elapsed / CFG.FLASH_DURATION)) ^ 2
    if kill_type == "headshot" then
        return mix_rgb(base, {255, 255, 255}, 0.70 * flash_t)
    elseif kill_type == "boss" then
        return mix_rgb(base, {255, 225, 220}, 0.65 * flash_t)
    end
    return base
end

local function resolve_texture(kill_type)
    if kill_type == "boss" and HKS:get("bf1_boss_icon_enabled") ~= false and _textures.boss then
        return _textures.boss
    elseif kill_type == "headshot" and _textures.headshot then
        return _textures.headshot
    end
    return _textures.default or _textures.headshot or _textures.boss
end

local function resolve_sheen_texture(kill_type)
    if kill_type == "boss" and HKS:get("bf1_boss_icon_enabled") ~= false and _textures.boss then
        return _textures.boss_sheen
    elseif kill_type == "headshot" and _textures.headshot then
        return _textures.headshot_sheen
    end
    if _textures.default then
        return _textures.default_sheen
    elseif _textures.headshot then
        return _textures.headshot_sheen
    elseif _textures.boss then
        return _textures.boss_sheen
    end
    return nil
end

local function compute_sweep_state(
    elapsed, is_switch, is_exiting, left_x, total_w, draw_box_h, base_box_h,
    icon_center_x, icon_draw_w, icon_sheen_tex, card_sheen_tex, icon_only, bg_opacity
)
    if is_exiting or draw_box_h <= 0 or total_w <= 0 then
        return nil
    end
    if not icon_sheen_tex and not card_sheen_tex then
        return nil
    end

    local delay = is_switch and CFG.SHEEN_SWITCH_DELAY or CFG.SHEEN_ENTER_DELAY
    local card_ratio = total_w / math.max(base_box_h, 1)
    local dur
    if is_switch then
        dur = clamp(CFG.SHEEN_SWITCH_BASE_DURATION + 0.036 * math.max(card_ratio - 1, 0), 0.20, 0.38)
    else
        dur = clamp(CFG.SHEEN_ENTER_BASE_DURATION + 0.045 * math.max(card_ratio - 1, 0), 0.24, 0.48)
    end

    if elapsed < delay or elapsed >= delay + dur then
        return nil
    end

    local p = clamp01((elapsed - delay) / dur)
    local eased_p = p < 0.5 and (2 * p * p) or (1 - ((-2 * p + 2) ^ 2) * 0.5)
    local span_w = draw_box_h * 2.0
    local start_x = left_x - span_w * 0.42
    local end_x = left_x + total_w + span_w * 0.42
    local beam_cx = start_x + (end_x - start_x) * eased_p

    -- Full-card analytically clipped 45-degree sweep (exact 2:1 span keeps true 45 deg on any banner width)
    local card_x, card_w, card_uvs = 0, 0, nil
    local card_alpha_mult = 0
    if card_sheen_tex and (not icon_only or bg_opacity > 0) then
        local beam_left = beam_cx - span_w * 0.5
        local beam_right = beam_cx + span_w * 0.5
        local vis_left = math.max(beam_left, left_x)
        local vis_right = math.min(beam_right, left_x + total_w)
        if vis_right > vis_left then
            card_x = vis_left
            card_w = vis_right - vis_left
            local u0 = clamp01((vis_left - beam_left) / span_w)
            local u1 = clamp01((vis_right - beam_left) / span_w)
            card_uvs = {{u0, 0}, {u1, 1}}
            if bg_opacity > 0 then
                card_alpha_mult = 0.30 + 0.22 * clamp01(bg_opacity / 0.50)
            else
                card_alpha_mult = 0.24
            end
        end
    end

    -- Collinear silhouette-masked skull/gear highlight locked to the exact same beam_cx
    local icon_uvs = nil
    local contrast_dim = 0
    if icon_sheen_tex and icon_draw_w > 0 then
        local s_skull = 0.5 + (beam_cx - icon_center_x) / (2 * icon_draw_w)
        local dim_lo = CFG.SHEEN_S_START - 0.14
        local dim_hi = CFG.SHEEN_S_END + 0.16
        if s_skull >= dim_lo and s_skull <= dim_hi then
            if s_skull < CFG.SHEEN_S_START then
                contrast_dim = clamp01((s_skull - dim_lo) / 0.14)
            elseif s_skull <= CFG.SHEEN_S_END then
                contrast_dim = 1
            else
                contrast_dim = 1 - clamp01((s_skull - CFG.SHEEN_S_END) / 0.16)
            end
        end

        if s_skull >= CFG.SHEEN_S_START and s_skull <= CFG.SHEEN_S_END then
            local u_skull = clamp01((s_skull - CFG.SHEEN_S_START) / (CFG.SHEEN_S_END - CFG.SHEEN_S_START))
            local frame_idx = clamp(math.floor(u_skull * CFG.SHEEN_FRAMES), 0, CFG.SHEEN_FRAMES - 1)
            local col = frame_idx % CFG.SHEEN_COLS
            local row = math.floor(frame_idx / CFG.SHEEN_COLS)
            local u0 = col / CFG.SHEEN_COLS + CFG.SHEEN_UV_INSET
            local u1 = (col + 1) / CFG.SHEEN_COLS - CFG.SHEEN_UV_INSET
            local v0 = row / CFG.SHEEN_ROWS + CFG.SHEEN_UV_INSET
            local v1 = (row + 1) / CFG.SHEEN_ROWS - CFG.SHEEN_UV_INSET
            icon_uvs = {{u0, v0}, {u1, v1}}
        end
    end

    return {
        card_x = card_x,
        card_w = card_w,
        card_uvs = card_uvs,
        card_alpha_mult = card_alpha_mult,
        icon_uvs = icon_uvs,
        contrast_dim = contrast_dim,
    }
end

local function apply_sheen_contrast(rgb, contrast_dim)
    if contrast_dim <= 0 then
        return rgb
    end
    local min_chan = math.min(rgb[1], rgb[2], rgb[3]) / 255
    local dip_strength = 0.08 + 0.11 * min_chan
    local factor = 1 - dip_strength * clamp01(contrast_dim)
    return {
        clamp(math.floor(rgb[1] * factor + 0.5), 0, 255),
        clamp(math.floor(rgb[2] * factor + 0.5), 0, 255),
        clamp(math.floor(rgb[3] * factor + 0.5), 0, 255),
    }
end

local function resolve_value_text(entry)
    local mode = HKS:get("bf1_value_mode") or "score"
    if mode == "none" then
        return ""
    elseif mode == "max_health" then
        local hp = entry.max_health or 0
        if hp <= 0 then
            hp = entry.damage or 0
        end
        return hp > 0 and tostring(math.floor(hp + 0.5)) or ""
    elseif mode == "damage" then
        local dmg = math.max(1, math.floor((entry.damage or 0) + 0.5))
        return tostring(dmg)
    end
    return tostring(math.floor((entry.score or 100) + 0.5))
end

local function resolve_victim_color(entry)
    if HKS:get("bf1_victim_color_mode") == "enemy_tier" then
        return TIER_COLORS[entry.enemy_tier] or BF1_RED_COLOR
    end
    return BF1_RED_COLOR
end

local function compute_icon_enter_scale(kill_type, elapsed, is_switch)
    if is_switch then
        local t = clamp01(elapsed / CFG.SWITCH_DURATION)
        local eased = 1 - (1 - t) ^ 3
        return 1.22 + (1.00 - 1.22) * eased
    end

    if kill_type == "headshot" or kill_type == "boss" then
        local peak = kill_type == "headshot" and 1.32 or 1.28
        local t = clamp01(elapsed / 0.16)
        if t < 0.62 then
            local slam_t = t / 0.62
            local slam_eased = 1 - (1 - slam_t) ^ 3
            return peak + (0.96 - peak) * slam_eased
        end
        local rebound_t = (t - 0.62) / 0.38
        local rebound_eased = 1 - (1 - rebound_t) ^ 2
        return 0.96 + (1.00 - 0.96) * rebound_eased
    end

    local t = clamp01(elapsed / CFG.ENTER_OPEN_DURATION)
    local eased = 1 - (1 - t) ^ 3
    return 1.18 + (1.00 - 1.18) * eased
end

local function set_rect(style, x, y, w, h, alpha, rgb, z)
    local a = clamp(math.floor((tonumber(alpha) or 0) + 0.5), 0, 255)
    if a <= 0 or w <= 0 or h <= 0 then
        style.color[1] = 0
        style.size[1] = 0
        style.size[2] = 0
        return
    end
    style.color[1] = a
    style.color[2] = rgb[1]
    style.color[3] = rgb[2]
    style.color[4] = rgb[3]
    style.size[1] = w
    style.size[2] = h
    style.offset[1] = x
    style.offset[2] = y
    style.offset[3] = z
end

local function set_texture_pass(style, tex, x, y, w, h, alpha, rgb, z, angle, uvs)
    local a = clamp(math.floor((tonumber(alpha) or 0) + 0.5), 0, 255)
    if not tex or a <= 0 or w <= 0 or h <= 0 then
        style.material_values.texture_map = nil
        style.color[1] = 0
        style.size[1] = 0
        style.size[2] = 0
        return
    end
    style.material_values.texture_map = tex
    style.color[1] = a
    style.color[2] = rgb[1]
    style.color[3] = rgb[2]
    style.color[4] = rgb[3]
    style.size[1] = w
    style.size[2] = h
    style.offset[1] = x
    style.offset[2] = y
    style.offset[3] = z
    if style.uvs then
        if uvs then
            style.uvs[1][1] = uvs[1][1]
            style.uvs[1][2] = uvs[1][2]
            style.uvs[2][1] = uvs[2][1]
            style.uvs[2][2] = uvs[2][2]
        else
            style.uvs[1][1] = 0
            style.uvs[1][2] = 0
            style.uvs[2][1] = 1
            style.uvs[2][2] = 1
        end
    end
    if style.pivot then
        style.angle = angle or 0
        style.pivot[1] = w * 0.5
        style.pivot[2] = h * 0.5
    end
end

local function set_text_pass(content, style, key, text, x, y, w, h, font_size, alpha, rgb, z)
    local a = clamp(math.floor((tonumber(alpha) or 0) + 0.5), 0, 255)
    if not text or text == "" or a <= 0 then
        content[key] = ""
        style.text_color[1] = 0
        return
    end
    content[key] = text
    style.font_size = font_size
    style.text_color[1] = a
    style.text_color[2] = rgb[1]
    style.text_color[3] = rgb[2]
    style.text_color[4] = rgb[3]
    style.default_text_color[1] = a
    style.default_text_color[2] = rgb[1]
    style.default_text_color[3] = rgb[2]
    style.default_text_color[4] = rgb[3]
    style.size[1] = math.max(1, w)
    style.size[2] = math.max(1, h)
    style.offset[1] = x
    style.offset[2] = y
    style.offset[3] = z
end

local function clear_banner_widget(widget)
    if not widget or not widget.style then
        return
    end
    local styles = widget.style
    local content = widget.content
    for _, key in ipairs({"icon_box_bg", "text_box_bg", "accent_bar", "box_divider"}) do
        if styles[key] then
            styles[key].color[1] = 0
            styles[key].size[1] = 0
            styles[key].size[2] = 0
        end
    end
    for _, key in ipairs({"icon_glow", "icon_main", "icon_sheen", "card_sheen"}) do
        if styles[key] then
            styles[key].material_values.texture_map = nil
            styles[key].color[1] = 0
            styles[key].size[1] = 0
            styles[key].size[2] = 0
        end
    end
    for _, key in ipairs({"victim_text", "weapon_text", "value_text", "combo_badge_text"}) do
        if content then
            content[key] = ""
        end
        if styles[key] then
            styles[key].text_color[1] = 0
        end
    end
end

local HudHitKillBF1 = class("HudHitKillBF1", "HudElementBase")

HudHitKillBF1.init = function(self, parent, draw_layer, start_scale)
    HudHitKillBF1.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })
    self._was_active = false
    self._has_active_content = false
    preload_textures()
end

HudHitKillBF1._measure_text = function(self, ui_renderer, text, style, font_size, max_w, max_h)
    if not text or text == "" then
        return 0, font_size
    end
    local cache_key = tostring(font_size) .. "|" .. text
    local cached = manager._size_cache[cache_key]
    if cached then
        return cached.w, cached.h
    end

    local prev_size = style.font_size
    style.font_size = font_size
    local w, h = self:_text_size(ui_renderer, text, style, {max_w, max_h})
    style.font_size = prev_size

    local mw = math.ceil(tonumber(w) or 0)
    local mh = math.ceil(tonumber(h) or font_size)
    if (manager._size_cache_count or 0) >= 256 then
        manager._size_cache = {}
        manager._size_cache_count = 0
    end
    manager._size_cache[cache_key] = {w = mw, h = mh}
    manager._size_cache_count = (manager._size_cache_count or 0) + 1
    return mw, mh
end

local function try_advance_queue(now)
    local queue = manager._queue
    if #queue == 0 or not manager._current then
        return
    end
    local best_index, next_ctx = find_highest_priority_queue_index(queue)
    if not best_index or not next_ctx then
        return
    end

    local current = manager._current
    local required_delay = CFG.MIN_SWITCH_INTERVAL
    if current.kill_type == "boss" and next_ctx.priority < 5 then
        required_delay = CFG.BOSS_HOLD_PROTECT_INTERVAL
    elseif next_ctx.priority >= current.priority + 2 then
        required_delay = CFG.URGENT_PREEMPT_INTERVAL
    end

    if (now - manager._last_switch_time) >= required_delay then
        table.remove(queue, best_index)
        begin_entry(next_ctx, now, "switch_punch")
    end
end

HudHitKillBF1.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local widget = self._widgets_by_name and self._widgets_by_name.bf1_banner
    local step_dt = math.max(tonumber(dt) or 0, 0)

    if not output_enabled() or is_in_hub() then
        if self._was_active or manager._state ~= "idle" then
            manager.clear()
            clear_banner_widget(widget)
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
            HudHitKillBF1.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        end
        return
    end

    if not textures_ready() then
        preload_textures()
    end

    local now = now_time()
    if manager._state ~= "idle" and manager._state ~= "exiting" then
        try_advance_queue(now)
    end

    local entry = manager._current
    if manager._state == "idle" or not entry then
        if self._was_active then
            clear_banner_widget(widget)
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
            HudHitKillBF1.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        end
        return
    end

    local base_duration = (tonumber(HKS:get("kill_icon_duration_bf1")) or 25) / 10
    local hold_duration = entry.kill_type == "boss" and (base_duration * CFG.BOSS_DURATION_MULTIPLIER) or base_duration
    local elapsed = math.max(0, now - manager._start_time)

    if manager._state == "entering" and elapsed >= CFG.ENTER_DURATION then
        manager._state = "holding"
    elseif manager._state == "switch_punch" and elapsed >= CFG.SWITCH_DURATION then
        manager._state = "holding"
    end

    if manager._state ~= "exiting" and #manager._queue == 0 and elapsed >= hold_duration then
        manager._state = "exiting"
        manager._exit_start_time = now
    end

    if manager._state == "exiting" then
        local exit_elapsed = math.max(0, now - manager._exit_start_time)
        if exit_elapsed >= CFG.EXIT_DURATION then
            manager.clear()
            clear_banner_widget(widget)
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
            HudHitKillBF1.super.update(self, dt, t, ui_renderer, render_settings, input_service)
            return
        end
    end

    local size_scale = clamp((tonumber(HKS:get("kill_icon_size_bf1")) or 10) / 10, 0.5, 2.0)
    local transparency = clamp((tonumber(HKS:get("kill_icon_transparency_bf1")) or 100) / 100, 0, 1)
    local bg_opacity = clamp((tonumber(HKS:get("bf1_bg_opacity")) or 48) / 100, 0, 1)
    local icon_only = HKS:get("bf1_display_mode") == "icon_only"

    local victim_font = math.max(10, math.floor(CFG.BASE_VICTIM_FONT_SIZE * size_scale + 0.5))
    local weapon_font = math.max(10, math.floor(CFG.BASE_WEAPON_FONT_SIZE * size_scale + 0.5))
    local value_font = math.max(14, math.floor(CFG.BASE_VALUE_FONT_SIZE * size_scale + 0.5))
    local combo_font = math.max(10, math.floor(CFG.BASE_COMBO_FONT_SIZE * size_scale + 0.5))

    local pad_x = CFG.BASE_PAD_X * size_scale
    local pad_y = CFG.BASE_PAD_Y * size_scale
    local row_gap = CFG.BASE_ROW_GAP * size_scale
    local col_gap = CFG.BASE_COL_GAP * size_scale

    local styles = widget.style
    local content = widget.content
    local max_text_w = CFG.MAX_TEXT_COL_WIDTH * size_scale
    local max_val_w = CFG.MAX_VALUE_WIDTH * size_scale

    local victim_w, victim_h = self:_measure_text(
        ui_renderer, entry.victim_name, styles.victim_text, victim_font, max_text_w, victim_font * 2
    )
    local weapon_w, weapon_h = self:_measure_text(
        ui_renderer, entry.weapon_name, styles.weapon_text, weapon_font, max_text_w, weapon_font * 2
    )
    local value_str = resolve_value_text(entry)
    local value_w, value_h = self:_measure_text(
        ui_renderer, value_str, styles.value_text, value_font, max_val_w, value_font * 2
    )

    local row1_h = math.max(victim_h, victim_font)
    local row2_h = math.max(weapon_h, weapon_font)
    local text_block_h = row1_h + row_gap + row2_h
    local base_box_h = math.max(pad_y * 2 + text_block_h, 58 * size_scale)

    local text_col_w = math.min(max_text_w, math.max(victim_w, weapon_w, 60 * size_scale))
    local target_text_box_w = 0
    if not icon_only then
        if value_str ~= "" then
            target_text_box_w = pad_x + text_col_w + col_gap + value_w + pad_x
        else
            target_text_box_w = pad_x + text_col_w + pad_x
        end
    end

    -- Phase animation envelopes (vertical center-outward scale open & center-inward collapse)
    local global_alpha = 1
    local open_y
    local text_alpha = 1
    local text_scale = 1
    local text_slide_x = 0

    if manager._state == "entering" then
        local t_open = clamp01(elapsed / CFG.ENTER_OPEN_DURATION)
        local eased_open = 1 - (1 - t_open) ^ 4
        local start_open = clamp(tonumber(manager._enter_from_open_y) or CFG.ENTER_MIN_OPEN_Y, CFG.ENTER_MIN_OPEN_Y, 1)
        open_y = start_open + (1 - start_open) * eased_open
        global_alpha = 0.20 + 0.80 * clamp01(elapsed / CFG.ENTER_ALPHA_DURATION)

        local t_rev = clamp01((elapsed - CFG.ENTER_REVEAL_DELAY) / CFG.ENTER_REVEAL_DURATION)
        local eased_rev = 1 - (1 - t_rev) ^ 3
        manager._current_text_box_w = target_text_box_w * (0.92 + 0.08 * eased_rev)

        if open_y >= 0.38 then
            local t_txt = clamp01((elapsed - CFG.ENTER_TEXT_DELAY) / CFG.ENTER_TEXT_DURATION)
            local eased_txt = 1 - (1 - t_txt) ^ 3
            text_alpha = eased_txt
            text_scale = clamp(open_y ^ 0.85, 0.45, 1)
            text_slide_x = -6 * size_scale * (1 - eased_txt)
        else
            text_alpha = 0
            text_scale = 0.45
            text_slide_x = -6 * size_scale
        end
    elseif manager._state == "switch_punch" then
        open_y = 1
        local move_alpha = step_dt > 0 and (1 - math.exp(-22 * step_dt)) or 1
        manager._current_text_box_w = manager._current_text_box_w +
            (target_text_box_w - manager._current_text_box_w) * move_alpha

        local t_txt = clamp01(elapsed / CFG.SWITCH_TEXT_DURATION)
        local eased_txt = 1 - (1 - t_txt) ^ 3
        text_alpha = 0.30 + 0.70 * eased_txt
        text_slide_x = -6 * size_scale * (1 - eased_txt)
    elseif manager._state == "exiting" then
        local t_exit = clamp01((now - manager._exit_start_time) / CFG.EXIT_DURATION)
        open_y = 1 - (t_exit ^ 2.4)
        text_scale = clamp(open_y ^ 0.85, 0.35, 1)

        if t_exit <= CFG.EXIT_TEXT_FADE_START then
            text_alpha = 1
        elseif t_exit < CFG.EXIT_TEXT_FADE_END then
            local fade_span = CFG.EXIT_TEXT_FADE_END - CFG.EXIT_TEXT_FADE_START
            local t_txt_fade = clamp01((t_exit - CFG.EXIT_TEXT_FADE_START) / fade_span)
            text_alpha = 1 - t_txt_fade * t_txt_fade
        else
            text_alpha = 0
        end

        if t_exit >= CFG.EXIT_ALPHA_FADE_START then
            local t_alpha = clamp01((t_exit - CFG.EXIT_ALPHA_FADE_START) / (1 - CFG.EXIT_ALPHA_FADE_START))
            global_alpha = 1 - t_alpha * t_alpha
        else
            global_alpha = 1
        end
        manager._current_text_box_w = target_text_box_w
    else
        open_y = 1
        local move_alpha = step_dt > 0 and (1 - math.exp(-22 * step_dt)) or 1
        manager._current_text_box_w = manager._current_text_box_w +
            (target_text_box_w - manager._current_text_box_w) * move_alpha
    end

    manager._last_open_y = open_y

    local draw_box_h = base_box_h * open_y
    local icon_box_w = base_box_h
    local text_box_w = icon_only and 0 or manager._current_text_box_w
    local total_w = icon_box_w + text_box_w

    local screen_w = UIWorkspaceSettings.screen.size[1]
    local screen_h = UIWorkspaceSettings.screen.size[2]
    local horiz = clamp(tonumber(HKS:get("kill_icon_horizontal_position_bf1")) or 50, 0, 100)
    local vert = clamp(tonumber(HKS:get("kill_icon_vertical_position_bf1")) or 75, 0, 100)

    local center_x = screen_w * horiz / 100
    local left_x = clamp(
        center_x - total_w * 0.5,
        CFG.SCREEN_EDGE_MARGIN,
        math.max(CFG.SCREEN_EDGE_MARGIN, screen_w - total_w - CFG.SCREEN_EDGE_MARGIN)
    )
    local base_top_y = (vert / 100) * math.max(screen_h - base_box_h, 1)
    local center_y = clamp(
        base_top_y + base_box_h * 0.5,
        CFG.SCREEN_EDGE_MARGIN + base_box_h * 0.5,
        math.max(CFG.SCREEN_EDGE_MARGIN + base_box_h * 0.5, screen_h - CFG.SCREEN_EDGE_MARGIN - base_box_h * 0.5)
    )
    local top_y = center_y - draw_box_h * 0.5

    local eff_alpha = global_alpha * transparency
    local colors = resolve_colors()
    local accent_rgb = resolve_accent_color(entry.kill_type, colors)
    local icon_rgb = resolve_icon_color(entry.kill_type, elapsed, colors)
    local icon_tex = resolve_texture(entry.kill_type)
    local sheen_tex = resolve_sheen_texture(entry.kill_type)
    local is_exiting = manager._state == "exiting"
    local is_switch = manager._state == "switch_punch"
    local icon_scale = 1
    if not is_exiting then
        icon_scale = compute_icon_enter_scale(entry.kill_type, elapsed, is_switch)
    end
    local icon_center_x = left_x + icon_box_w * 0.5
    local icon_center_y = center_y
    local base_icon_size = base_box_h * CFG.ICON_TO_BOX_RATIO
    local icon_draw_w = base_icon_size * icon_scale
    local icon_draw_h = icon_draw_w * open_y

    local sweep = compute_sweep_state(
        elapsed, manager._entry_is_switch, is_exiting, left_x, total_w, draw_box_h, base_box_h,
        icon_center_x, icon_draw_w, sheen_tex, _textures.card_sheen, icon_only, bg_opacity
    )
    local draw_icon_rgb = apply_sheen_contrast(icon_rgb, sweep and sweep.contrast_dim or 0)

    -- Box backgrounds, accent bar, divider (no center seam or full-box flash)
    local icon_bg_alpha = 255 * bg_opacity * eff_alpha
    local text_bg_alpha = 255 * bg_opacity * 0.62 * eff_alpha
    set_rect(styles.icon_box_bg, left_x, top_y, icon_box_w, draw_box_h, icon_bg_alpha, {12, 14, 16}, 1)

    local accent_w = math.max(2, CFG.BASE_ACCENT_W * size_scale)
    local accent_alpha = bg_opacity > 0 and (255 * 0.90 * eff_alpha) or 0
    set_rect(styles.accent_bar, left_x, top_y, accent_w, draw_box_h, accent_alpha, accent_rgb, 2)

    if not icon_only then
        set_rect(
            styles.text_box_bg, left_x + icon_box_w, top_y, text_box_w, draw_box_h,
            text_bg_alpha, {16, 18, 20}, 1
        )
        local divider_alpha = bg_opacity > 0 and (255 * 0.14 * eff_alpha) or 0
        set_rect(
            styles.box_divider, left_x + icon_box_w, top_y, CFG.BASE_DIVIDER_W, draw_box_h,
            divider_alpha, {255, 255, 255}, 2
        )
    else
        set_rect(styles.text_box_bg, 0, 0, 0, 0, 0, {0, 0, 0}, 1)
        set_rect(styles.box_divider, 0, 0, 0, 0, 0, {0, 0, 0}, 2)
    end

    -- Emblem glow, main vertically-scaled emblem & collinear 45-degree silhouette sheen
    if (entry.kill_type == "headshot" or entry.kill_type == "boss") and
        elapsed < CFG.GLOW_DURATION and not is_exiting then
        local g_t = clamp01(elapsed / CFG.GLOW_DURATION)
        local glow_eased = 1 - (1 - g_t) ^ 3
        local glow_w = base_icon_size * (0.95 + 0.55 * glow_eased)
        local glow_h = glow_w * open_y
        local glow_alpha = 255 * 0.45 * ((1 - g_t) ^ 2) * eff_alpha
        set_texture_pass(
            styles.icon_glow,
            icon_tex,
            icon_center_x - glow_w * 0.5,
            icon_center_y - glow_h * 0.5,
            glow_w,
            glow_h,
            glow_alpha,
            accent_rgb,
            4
        )
    else
        set_texture_pass(styles.icon_glow, nil, 0, 0, 0, 0, 0, {255, 255, 255}, 4)
    end

    local icon_angle = 0
    if entry.kill_type == "boss" and not is_exiting then
        local spin_t = clamp01((elapsed - CFG.BOSS_SPIN_DELAY) / CFG.BOSS_SPIN_DURATION)
        local spin_deg = 45 * (1 - (1 - spin_t) ^ 3)
        icon_angle = -math.rad(spin_deg)
    end
    local icon_x = icon_center_x - icon_draw_w * 0.5
    local icon_y = icon_center_y - icon_draw_h * 0.5
    set_texture_pass(
        styles.icon_main,
        icon_tex,
        icon_x,
        icon_y,
        icon_draw_w,
        icon_draw_h,
        255 * eff_alpha,
        draw_icon_rgb,
        5,
        icon_angle
    )

    if sweep and sweep.icon_uvs then
        local sheen_alpha = 255 * ((entry.kill_type == "default") and 0.92 or 1.00) * eff_alpha
        set_texture_pass(
            styles.icon_sheen,
            sheen_tex,
            icon_x,
            icon_y,
            icon_draw_w,
            icon_draw_h,
            sheen_alpha,
            {255, 255, 255},
            6,
            icon_angle,
            sweep.icon_uvs
        )
    else
        set_texture_pass(styles.icon_sheen, nil, 0, 0, 0, 0, 0, {255, 255, 255}, 6)
    end

    -- Text passes (vertically compressed & pulled toward center_y in sync with open_y)
    local final_text_alpha = 255 * eff_alpha * text_alpha
    local victim_draw_font = math.max(8, math.floor(victim_font * text_scale + 0.5))
    local weapon_draw_font = math.max(8, math.floor(weapon_font * text_scale + 0.5))
    local value_draw_font = math.max(10, math.floor(value_font * text_scale + 0.5))
    local combo_draw_font = math.max(8, math.floor(combo_font * text_scale + 0.5))

    if not icon_only and final_text_alpha > 0 then
        local text_box_left = left_x + icon_box_w
        local text_col_left = text_box_left + pad_x + text_slide_x
        local text_col_right = text_col_left + text_col_w
        local scaled_row1_h = row1_h * open_y
        local scaled_row2_h = row2_h * open_y
        local scaled_row_gap = row_gap * open_y
        local scaled_block_h = scaled_row1_h + scaled_row_gap + scaled_row2_h
        local block_top_y = center_y - scaled_block_h * 0.5

        local victim_rgb = resolve_victim_color(entry)
        set_text_pass(
            content, styles.victim_text, "victim_text", entry.victim_name,
            text_col_left - 32, block_top_y,
            text_col_w + 32, math.max(scaled_row1_h, victim_draw_font),
            victim_draw_font, final_text_alpha, victim_rgb, 7
        )

        set_text_pass(
            content, styles.weapon_text, "weapon_text", entry.weapon_name,
            text_col_left - 32, block_top_y + scaled_row1_h + scaled_row_gap,
            text_col_w + 32, math.max(scaled_row2_h, weapon_draw_font),
            weapon_draw_font, final_text_alpha, {255, 255, 255}, 7
        )

        if value_str ~= "" then
            local val_rgb = {255, 255, 255}
            if entry.kill_type == "headshot" and elapsed < CFG.VALUE_FLASH_DURATION then
                local vt = 1 - clamp01(elapsed / CFG.VALUE_FLASH_DURATION)
                val_rgb = mix_rgb({255, 255, 255}, colors.headshot, 0.45 * vt)
            end
            local val_h = math.max(value_h * open_y, value_draw_font)
            local val_x = text_col_right + col_gap - 12
            local val_y = center_y - val_h * 0.5
            set_text_pass(
                content, styles.value_text, "value_text", value_str,
                val_x, val_y, value_w + 24, val_h, value_draw_font, final_text_alpha, val_rgb, 7
            )
        else
            set_text_pass(
                content, styles.value_text, "value_text", "", 0, 0, 0, 0, value_draw_font, 0, {255, 255, 255}, 7
            )
        end
    else
        set_text_pass(
            content, styles.victim_text, "victim_text", "", 0, 0, 0, 0, victim_draw_font, 0, {255, 255, 255}, 7
        )
        set_text_pass(
            content, styles.weapon_text, "weapon_text", "", 0, 0, 0, 0, weapon_draw_font, 0, {255, 255, 255}, 7
        )
        set_text_pass(
            content, styles.value_text, "value_text", "", 0, 0, 0, 0, value_draw_font, 0, {255, 255, 255}, 7
        )
    end

    -- Burst combo badge (x2, x3...) compressed and faded with text envelope
    local batch_count = tonumber(entry.batch_count) or 1
    if batch_count >= 2 and final_text_alpha > 0 then
        local badge_text = "x" .. tostring(batch_count)
        local badge_w, badge_h = self:_measure_text(
            ui_renderer, badge_text, styles.combo_badge_text, combo_font, 80 * size_scale, combo_font * 2
        )
        local badge_draw_h = math.max(badge_h * open_y, combo_draw_font)
        local badge_box_w = math.max(badge_w + 16, 24)
        local badge_x = icon_only and (left_x + icon_box_w - badge_box_w - 4 * size_scale) or
            (left_x + total_w - badge_box_w - 5 * size_scale)
        local badge_y = icon_only and (top_y + draw_box_h - badge_draw_h - 2 * size_scale * open_y) or
            (top_y + 2 * size_scale * open_y)
        set_text_pass(
            content, styles.combo_badge_text, "combo_badge_text", badge_text,
            badge_x, badge_y, badge_box_w, badge_draw_h,
            combo_draw_font, final_text_alpha, {255, 235, 190}, 8
        )
    else
        set_text_pass(
            content, styles.combo_badge_text, "combo_badge_text", "",
            0, 0, 0, 0, combo_draw_font, 0, {255, 235, 190}, 8
        )
    end

    -- Full-card 45-degree light sweep across emblem, divider & text (z = 9, strictly clipped to card)
    if sweep and sweep.card_uvs and sweep.card_w > 0 and sweep.card_alpha_mult > 0 then
        set_texture_pass(
            styles.card_sheen,
            _textures.card_sheen,
            sweep.card_x,
            top_y,
            sweep.card_w,
            draw_box_h,
            255 * sweep.card_alpha_mult * eff_alpha,
            {255, 255, 255},
            9,
            nil,
            sweep.card_uvs
        )
    else
        set_texture_pass(styles.card_sheen, nil, 0, 0, 0, 0, 0, {255, 255, 255}, 9)
    end

    self._was_active = true
    self._has_active_content = true
    self._update_scenegraph = true
    HudHitKillBF1.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillBF1.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not self._has_active_content or not output_enabled() or is_in_hub() then
        return
    end
    HudHitKillBF1.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillBF1.destroy = function(self, ui_renderer)
    local widget = self._widgets_by_name and self._widgets_by_name.bf1_banner
    manager.clear()
    clear_banner_widget(widget)
    self._was_active = false
    self._has_active_content = false
    HudHitKillBF1.super.destroy(self, ui_renderer)
end

return HudHitKillBF1
