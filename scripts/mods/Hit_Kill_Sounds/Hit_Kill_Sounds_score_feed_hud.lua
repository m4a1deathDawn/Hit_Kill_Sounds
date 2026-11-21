-- luacheck: globals get_mod Managers class Utf8
local HKS = get_mod("Hit_Kill_Sounds")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local ScoreFeed = HKS.HitKillSoundsScoreFeed
local HudHitKillScoreFeed = class("HudHitKillScoreFeed", "HudElementBase")

local MAX_ENTRIES = 8
local BASE_FONT_SIZE = 22
local MAX_LEFT_WIDTH = 460
local MAX_SCORE_WIDTH = 140
local INITIAL_LINE_HEIGHT = ScoreFeed and ScoreFeed.get_line_height and ScoreFeed.get_line_height() or 34
local KILL_MAIN_FONT_SCALE = 1.15
local BONUS_FONT_SCALE = 0.90
local TALLY_FONT_SCALE = 1.95
local TEXT_GAP = 12
local SEGMENT_GAP = 8
local BOTTOM_MARGIN = 90
local TOP_MARGIN = 90
local MIN_TALLY_OFFSET_X = 84

local TRANSFORM_STAGE1_END = 0.60
local TRANSFORM_OUT_DURATION = 0.08
local DETAIL_TYPEWRITER_DURATION = 0.22

local BF4_VICTIM_RED = {255, 255, 72, 56}
local BF4_WEAPON_WHITE = {255, 224, 238, 250}
local BF4_SCORE_WHITE = {255, 244, 250, 255}
local BF4_TALLY_COOL = {255, 232, 246, 255}
local BF4_TALLY_WARM = {255, 255, 245, 210}
local BF4_TALLY_GLOW = {255, 130, 210, 255}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function clamp01(value)
    return clamp(tonumber(value) or 0, 0, 1)
end

local function feed_visible()
    return HKS:get("enabled") ~= false and HKS:get("bf4_feed_enabled") == true
end

local function is_in_hub()
    local game_mode_manager = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

    return game_mode_name == "hub"
end

local function create_text_style(font_size, text_color, width, height, z)
    local base_style = UIFontSettings.hud_body
    local style = {
        font_type = "proxima_nova_bold",
        font_size = font_size,
        line_spacing = base_style and base_style.line_spacing or 1.2,
        drop_shadow = true,
        text_horizontal_alignment = "left",
        horizontal_alignment = "left",
        text_vertical_alignment = "center",
        vertical_alignment = "top",
        text_color = {text_color[1], text_color[2], text_color[3], text_color[4]},
        default_text_color = {text_color[1], text_color[2], text_color[3], text_color[4]},
        text_fit_with = true,
        size = {width, height},
        offset = {0, 0, z or 0},
    }

    return style
end

local function make_text_visible(value_id)
    return function(content, style)
        local text = content[value_id]
        return text ~= nil and text ~= "" and style.text_color[1] > 0
    end
end

local scenegraph_definition = {
    screen = UIWorkspaceSettings.screen,
}

for index = 1, MAX_ENTRIES do
    scenegraph_definition["score_feed_root_" .. index] = {
        horizontal_alignment = "left",
        parent = "screen",
        vertical_alignment = "top",
        size = UIWorkspaceSettings.screen.size,
        position = {0, 0, 0},
    }
end

scenegraph_definition.score_feed_tally_root = {
    horizontal_alignment = "left",
    parent = "screen",
    vertical_alignment = "top",
    size = UIWorkspaceSettings.screen.size,
    position = {0, 0, 0},
}

local widget_definitions = {}

for index = 1, MAX_ENTRIES do
    widget_definitions["score_feed_entry_" .. index] = UIWidget.create_definition({
        {
            pass_type = "text",
            style_id = "prefix",
            value = "",
            value_id = "prefix_text",
            style = create_text_style(
                BASE_FONT_SIZE,
                BF4_WEAPON_WHITE,
                MAX_LEFT_WIDTH,
                INITIAL_LINE_HEIGHT,
                1
            ),
            visibility_function = make_text_visible("prefix_text"),
        },
        {
            pass_type = "text",
            style_id = "victim",
            value = "",
            value_id = "victim_text",
            style = create_text_style(
                BASE_FONT_SIZE,
                BF4_VICTIM_RED,
                MAX_LEFT_WIDTH,
                INITIAL_LINE_HEIGHT,
                1
            ),
            visibility_function = make_text_visible("victim_text"),
        },
        {
            pass_type = "text",
            style_id = "score",
            value = "",
            value_id = "score_text",
            style = create_text_style(
                BASE_FONT_SIZE,
                BF4_SCORE_WHITE,
                MAX_SCORE_WIDTH,
                INITIAL_LINE_HEIGHT,
                1
            ),
            visibility_function = make_text_visible("score_text"),
        },
    }, "score_feed_root_" .. index)
end

widget_definitions.score_feed_tally = UIWidget.create_definition({
    {
        pass_type = "text",
        style_id = "tally_glow",
        value = "",
        value_id = "tally_text",
        style = create_text_style(
            BASE_FONT_SIZE * TALLY_FONT_SCALE,
            BF4_TALLY_GLOW,
            280,
            INITIAL_LINE_HEIGHT * 2,
            0
        ),
        visibility_function = make_text_visible("tally_text"),
    },
    {
        pass_type = "text",
        style_id = "tally",
        value = "",
        value_id = "tally_text",
        style = create_text_style(
            BASE_FONT_SIZE * TALLY_FONT_SCALE,
            BF4_TALLY_COOL,
            280,
            INITIAL_LINE_HEIGHT * 2,
            1
        ),
        visibility_function = make_text_visible("tally_text"),
    },
}, "score_feed_tally_root")

local function get_base_position(line_height)
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local screen_height = UIWorkspaceSettings.screen.size[2]
    local raw_h = HKS:get("bf4_feed_horizontal_position")
    if raw_h == nil then
        raw_h = HKS:get("bf4_score_feed_offset_x")
    end
    local raw_v = HKS:get("bf4_feed_vertical_position")
    if raw_v == nil then
        raw_v = HKS:get("bf4_score_feed_offset_y")
    end
    local horizontal = clamp(tonumber(raw_h) or 50, 0, 100)
    local vertical = clamp(tonumber(raw_v) or 35, 0, 100)
    local usable_height = math.max(screen_height - TOP_MARGIN - BOTTOM_MARGIN, 1)
    local base_x = screen_width * horizontal / 100
    local base_y = screen_height - BOTTOM_MARGIN - usable_height * vertical / 100

    local direction = ScoreFeed and ScoreFeed.get_direction and ScoreFeed.get_direction() or "top_down"
    if direction == "top_down" then
        local max_top_y = math.max(TOP_MARGIN, screen_height - BOTTOM_MARGIN - (line_height or INITIAL_LINE_HEIGHT) * 3)
        base_y = clamp(base_y, TOP_MARGIN, max_top_y)
    end

    return base_x, base_y
end

local function get_text_scale()
    local scale = tonumber(HKS:get("bf4_feed_text_scale")) or 100

    return clamp(scale / 100, 0.5, 1.5)
end

local function get_line_height()
    if ScoreFeed and ScoreFeed.get_line_height then
        return ScoreFeed.get_line_height()
    end

    return INITIAL_LINE_HEIGHT
end

local function get_typewriter_speed()
    if ScoreFeed and ScoreFeed.get_typewriter_speed then
        return ScoreFeed.get_typewriter_speed()
    end

    return 32
end

local function hide_widget(widget)
    if widget then
        widget.visible = false
        widget.alpha_multiplier = 0
        widget.content.visible = false
        widget.content.prefix_text = ""
        widget.content.victim_text = ""
        widget.content.score_text = ""
        widget.content.tally_text = ""
    end
end

local function format_score(score)
    return string.format("%d", math.floor(tonumber(score) or 0))
end

local function get_revealed_text(text, elapsed, characters_per_second)
    if not text or text == "" then
        return ""
    end
    local text_length = Utf8.string_length(text)
    local visible_length = math.min(
        text_length,
        math.floor(math.max(tonumber(elapsed) or 0, 0) * characters_per_second)
    )

    if visible_length <= 0 then
        return ""
    elseif visible_length >= text_length then
        return text
    end

    return Utf8.sub_string(text, 1, visible_length)
end

local function set_color_with_alpha(dest, rgb_color, alpha_ratio)
    local a = clamp(math.floor((rgb_color[1] or 255) * clamp01(alpha_ratio) + 0.5), 0, 255)
    dest[1] = a
    dest[2] = rgb_color[2]
    dest[3] = rgb_color[3]
    dest[4] = rgb_color[4]
end

local function truncate_utf8(text, max_chars)
    if not text or text == "" then
        return ""
    end
    local len = Utf8.string_length(text)
    if len <= max_chars then
        return text
    end
    if max_chars <= 3 then
        return Utf8.sub_string(text, 1, math.max(1, max_chars))
    end
    return Utf8.sub_string(text, 1, max_chars - 3) .. "..."
end

function HudHitKillScoreFeed:init(parent, draw_layer, start_scale)
    HudHitKillScoreFeed.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    self._has_visible_content = false
    self._was_visible = false
    self._size_cache = {}
    self._size_cache_count = 0

    for index = 1, MAX_ENTRIES do
        hide_widget(self._widgets_by_name["score_feed_entry_" .. index])
    end

    hide_widget(self._widgets_by_name.score_feed_tally)
end

function HudHitKillScoreFeed:_measure_width(ui_renderer, text, style, font_size, max_width, line_height)
    if not text or text == "" then
        return 0
    end
    local cache_key = tostring(font_size) .. "|" .. text
    local cached = self._size_cache[cache_key]
    if cached then
        return cached
    end

    local prev_size = style.font_size
    style.font_size = font_size
    local measured = self:_text_size(ui_renderer, text, style, {max_width, line_height})
    style.font_size = prev_size

    local width = math.ceil(tonumber(measured) or 0)
    if self._size_cache_count >= 256 then
        self._size_cache = {}
        self._size_cache_count = 0
    end
    self._size_cache[cache_key] = width
    self._size_cache_count = self._size_cache_count + 1
    return width
end

function HudHitKillScoreFeed:_fit_weapon_prefix(ui_renderer, weapon_name, victim_w, style, font_size, line_height, s)
    if not weapon_name or weapon_name == "" then
        return "", 0
    end
    local seg_gap = victim_w > 0 and math.floor(SEGMENT_GAP * s) or 0
    local budget = math.max(80 * s, MAX_LEFT_WIDTH * s - victim_w - seg_gap)
    local bracketed = "[" .. weapon_name .. "]"
    local width = self:_measure_width(ui_renderer, bracketed, style, font_size, MAX_LEFT_WIDTH * s, line_height)
    if width <= budget then
        return bracketed, width
    end

    local char_len = Utf8.string_length(weapon_name)
    local est_chars = math.max(6, math.floor(char_len * (budget / math.max(width, 1))))
    local clipped = "[" .. truncate_utf8(weapon_name, est_chars) .. "]"
    local clipped_w = self:_measure_width(ui_renderer, clipped, style, font_size, MAX_LEFT_WIDTH * s, line_height)
    local attempts = 0
    while clipped_w > budget and est_chars > 4 and attempts < 4 do
        est_chars = math.max(4, est_chars - 2)
        clipped = "[" .. truncate_utf8(weapon_name, est_chars) .. "]"
        clipped_w = self:_measure_width(ui_renderer, clipped, style, font_size, MAX_LEFT_WIDTH * s, line_height)
        attempts = attempts + 1
    end
    return clipped, clipped_w
end

function HudHitKillScoreFeed:_update_entry_widget(widget, entry, base_x, base_y, ui_renderer, font_size, line_height, s)
    local entry_alpha = clamp01(entry.alpha)
    if entry_alpha <= 0 then
        hide_widget(widget)
        return false, 0
    end

    local reveal_elapsed = math.max(0, entry.reveal_elapsed or 0)
    local is_bonus = entry.event_key == "bf4_feed_headshot_bonus" or entry.event_key == "bf4_feed_multikill_bonus"
    local is_kill_main = entry.is_kill_main == true and not is_bonus

    local row_scale = is_bonus and BONUS_FONT_SCALE or (is_kill_main and KILL_MAIN_FONT_SCALE or 1)
    local row_font_size = math.max(10, math.floor(font_size * row_scale + 0.5))

    local prefix_style = widget.style.prefix
    local victim_style = widget.style.victim
    local score_style = widget.style.score
    prefix_style.font_size = row_font_size
    victim_style.font_size = row_font_size
    score_style.font_size = row_font_size

    local kill_line_mode = HKS:get("bf4_feed_kill_line_mode") or "transform"
    local show_weapon = HKS:get("bf4_feed_show_weapon") ~= false
    local show_victim = HKS:get("bf4_feed_show_victim") ~= false
    local has_detail = is_kill_main and kill_line_mode ~= "classic" and (
        (show_weapon and entry.weapon_name and entry.weapon_name ~= "") or
        (show_victim and entry.victim_name and entry.victim_name ~= "")
    )

    local use_detail_stage = false
    local stage1_erasing = false
    local erase_progress = 0
    local detail_elapsed = 0
    if has_detail then
        if kill_line_mode == "direct" then
            use_detail_stage = true
            detail_elapsed = reveal_elapsed
        elseif reveal_elapsed >= TRANSFORM_STAGE1_END + TRANSFORM_OUT_DURATION then
            use_detail_stage = true
            detail_elapsed = reveal_elapsed - (TRANSFORM_STAGE1_END + TRANSFORM_OUT_DURATION)
        elseif reveal_elapsed >= TRANSFORM_STAGE1_END then
            stage1_erasing = true
            erase_progress = clamp01((reveal_elapsed - TRANSFORM_STAGE1_END) / TRANSFORM_OUT_DURATION)
        end
    end

    local draw_y = base_y + (entry.current_y or 0) + (entry.fade_y_offset or 0)
    local prefix_text = ""
    local victim_text = ""
    local prefix_color = entry.color
    local prefix_w = 0
    local victim_w = 0

    if use_detail_stage then
        local full_victim = ""
        local full_prefix = ""
        if show_victim and entry.victim_name and entry.victim_name ~= "" then
            full_victim = entry.victim_name
            victim_w = self:_measure_width(
                ui_renderer, full_victim, victim_style, row_font_size, MAX_LEFT_WIDTH * s, line_height
            )
        end
        if show_weapon and entry.weapon_name and entry.weapon_name ~= "" then
            full_prefix, prefix_w = self:_fit_weapon_prefix(
                ui_renderer, entry.weapon_name, victim_w, prefix_style, row_font_size, line_height, s
            )
            prefix_color = BF4_WEAPON_WHITE
        end

        local prefix_len = full_prefix ~= "" and Utf8.string_length(full_prefix) or 0
        local victim_len = full_victim ~= "" and Utf8.string_length(full_victim) or 0
        local total_len = prefix_len + victim_len
        if total_len > 0 then
            local detail_speed = math.max(
                get_typewriter_speed(),
                math.ceil(total_len / DETAIL_TYPEWRITER_DURATION)
            )
            local revealed_chars = math.min(
                total_len,
                math.max(1, math.floor(detail_elapsed * detail_speed) + 1)
            )
            if prefix_len > 0 then
                local p_chars = math.min(revealed_chars, prefix_len)
                prefix_text = p_chars >= prefix_len and full_prefix or Utf8.sub_string(full_prefix, 1, p_chars)
            end
            if victim_len > 0 and revealed_chars > prefix_len then
                local v_chars = math.min(revealed_chars - prefix_len, victim_len)
                victim_text = v_chars >= victim_len and full_victim or Utf8.sub_string(full_victim, 1, v_chars)
            end
        end
    else
        local full_event_text = HKS:localize(entry.event_key) or entry.event_key
        local base_speed = get_typewriter_speed()
        local text_len = math.max(1, Utf8.string_length(full_event_text))
        if stage1_erasing then
            local remaining = math.floor(text_len * (1 - erase_progress) + 0.5)
            prefix_text = remaining > 0 and Utf8.sub_string(full_event_text, 1, remaining) or ""
        else
            local typewriter_speed = math.max(base_speed, math.ceil(text_len / 0.12))
            prefix_text = get_revealed_text(full_event_text, reveal_elapsed, typewriter_speed)
        end
        prefix_w = self:_measure_width(
            ui_renderer, full_event_text, prefix_style, row_font_size, MAX_LEFT_WIDTH * s, line_height
        )
    end

    local full_score_text = format_score(entry.score)
    local score_text = get_revealed_text(full_score_text, reveal_elapsed - 0.04, 65)
    local score_w = self:_measure_width(
        ui_renderer, full_score_text, score_style, row_font_size, MAX_SCORE_WIDTH * s, line_height
    )

    local seg_gap = (prefix_w > 0 and victim_w > 0) and math.floor(SEGMENT_GAP * s) or 0
    local score_gap = math.floor(TEXT_GAP * s)

    if victim_text ~= "" then
        set_color_with_alpha(victim_style.text_color, BF4_VICTIM_RED, 1)
        set_color_with_alpha(victim_style.default_text_color, BF4_VICTIM_RED, 1)
        victim_style.size[1] = math.max(1, victim_w + 32)
        victim_style.size[2] = line_height
        victim_style.offset[1] = base_x - victim_w
        victim_style.offset[2] = draw_y
    else
        victim_style.text_color[1] = 0
    end

    if prefix_text ~= "" then
        set_color_with_alpha(prefix_style.text_color, prefix_color, 1)
        set_color_with_alpha(prefix_style.default_text_color, prefix_color, 1)
        prefix_style.size[1] = math.max(1, prefix_w + 32)
        prefix_style.size[2] = line_height
        prefix_style.offset[1] = base_x - victim_w - seg_gap - prefix_w
        prefix_style.offset[2] = draw_y
    else
        prefix_style.text_color[1] = 0
    end

    local score_rgb = is_bonus and entry.color or BF4_SCORE_WHITE
    set_color_with_alpha(score_style.text_color, score_rgb, 1)
    set_color_with_alpha(score_style.default_text_color, score_rgb, 1)
    score_style.size[1] = math.max(1, score_w + 20)
    score_style.size[2] = line_height
    score_style.offset[1] = base_x + score_gap
    score_style.offset[2] = draw_y

    widget.content.prefix_text = prefix_text
    widget.content.victim_text = victim_text
    widget.content.score_text = score_text
    widget.content.visible = true
    widget.visible = true
    widget.alpha_multiplier = entry_alpha
    return true, score_w
end

function HudHitKillScoreFeed:_update_tally_widget(
    widget, tally, base_x, base_y, ui_renderer, font_size, line_height, s, max_score_w
)
    if not widget then
        return false
    end

    if tally.alpha <= 0 or tally.displayed_total_score <= 0 then
        hide_widget(widget)

        return false
    end

    local tally_style = widget.style.tally
    local glow_style = widget.style.tally_glow
    local tally_font_size = math.max(12, math.floor(font_size * TALLY_FONT_SCALE * tally.scale_multiplier + 0.5))
    local tally_text = format_score(tally.displayed_total_score)

    tally_style.font_size = tally_font_size
    glow_style.font_size = tally_font_size

    local tally_w = self:_measure_width(ui_renderer, tally_text, tally_style, tally_font_size, 320, line_height * 2)
    local flash_t = clamp01((tally.scale_multiplier - 1.0) / 0.24)
    local color = {
        255,
        math.floor(BF4_TALLY_COOL[2] + (BF4_TALLY_WARM[2] - BF4_TALLY_COOL[2]) * flash_t + 0.5),
        math.floor(BF4_TALLY_COOL[3] + (BF4_TALLY_WARM[3] - BF4_TALLY_COOL[3]) * flash_t + 0.5),
        math.floor(BF4_TALLY_COOL[4] + (BF4_TALLY_WARM[4] - BF4_TALLY_COOL[4]) * flash_t + 0.5),
    }

    local tally_x = base_x + math.max(MIN_TALLY_OFFSET_X * s, (max_score_w or 0) + 32 * s)
    local tally_y = base_y - math.floor(line_height * 0.18) + (tally.y_offset or 0)
    local box_w = math.max(260, tally_w + 24)
    local box_h = line_height * 2

    set_color_with_alpha(tally_style.text_color, color, 1)
    set_color_with_alpha(tally_style.default_text_color, color, 1)
    tally_style.size[1] = box_w
    tally_style.size[2] = box_h
    tally_style.offset[1] = tally_x
    tally_style.offset[2] = tally_y

    set_color_with_alpha(glow_style.text_color, BF4_TALLY_GLOW, 0.28 + 0.18 * flash_t)
    set_color_with_alpha(glow_style.default_text_color, BF4_TALLY_GLOW, 0.28 + 0.18 * flash_t)
    glow_style.size[1] = box_w
    glow_style.size[2] = box_h
    glow_style.offset[1] = tally_x + 1
    glow_style.offset[2] = tally_y + 1

    widget.content.tally_text = tally_text
    widget.content.visible = true
    widget.visible = true
    widget.alpha_multiplier = tally.alpha
    return true
end

function HudHitKillScoreFeed:_hide_all_widgets()
    for index = 1, MAX_ENTRIES do
        hide_widget(self._widgets_by_name["score_feed_entry_" .. index])
    end

    hide_widget(self._widgets_by_name.score_feed_tally)
end

function HudHitKillScoreFeed:update(dt, t, ui_renderer, render_settings, input_service)
    local manager = HKS.HitKillSoundsScoreFeed

    if not manager or not feed_visible() or is_in_hub() then
        if self._was_visible then
            self:_hide_all_widgets()
            self._was_visible = false
        end
        self._has_visible_content = false

        return
    end

    local scale = get_text_scale()
    local font_size = math.floor(BASE_FONT_SIZE * scale)
    local line_height = get_line_height()
    local base_x, base_y = get_base_position(line_height)
    local entries = manager.get_entries()
    local has_visible = false
    local max_score_w = 0

    for index = 1, MAX_ENTRIES do
        local widget = self._widgets_by_name["score_feed_entry_" .. index]
        local entry = entries[index]

        if entry then
            local visible, score_w = self:_update_entry_widget(
                widget, entry, base_x, base_y, ui_renderer, font_size, line_height, scale
            )
            if visible then
                has_visible = true
                if score_w > max_score_w then
                    max_score_w = score_w
                end
            end
        else
            hide_widget(widget)
        end
    end

    if self:_update_tally_widget(
        self._widgets_by_name.score_feed_tally,
        manager.get_tally(),
        base_x,
        base_y,
        ui_renderer,
        font_size,
        line_height,
        scale,
        max_score_w
    ) then
        has_visible = true
    end

    self._has_visible_content = has_visible
    self._was_visible = has_visible
    HudHitKillScoreFeed.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

function HudHitKillScoreFeed:draw(dt, t, ui_renderer, render_settings, input_service)
    if not self._has_visible_content or not feed_visible() or is_in_hub() then
        return
    end

    HudHitKillScoreFeed.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillScoreFeed
