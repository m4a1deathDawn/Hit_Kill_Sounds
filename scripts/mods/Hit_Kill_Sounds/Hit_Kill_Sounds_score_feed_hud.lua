-- luacheck: globals get_mod Managers class Utf8
local HKS = get_mod("Hit_Kill_Sounds")

local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local ScoreFeed = HKS.HitKillSoundsScoreFeed
local HudHitKillScoreFeed = class("HudHitKillScoreFeed", "HudElementBase")

local MAX_ENTRIES = 8
local BASE_FONT_SIZE = 22
local MAX_EVENT_WIDTH = 520
local MAX_SCORE_WIDTH = 120
local INITIAL_LINE_HEIGHT = ScoreFeed and ScoreFeed.get_line_height and ScoreFeed.get_line_height() or 34
local HEADSHOT_EVENT_FONT_SCALE = 0.9
local TEXT_GAP = 10
local BOTTOM_MARGIN = 90
local TOP_MARGIN = 90
local TALLY_OFFSET_X = 88

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function feed_visible()
    return HKS:get("enabled") ~= false and HKS:get("bf4_feed_enabled") == true
end

local function is_in_hub()
    local game_mode_manager = Managers.state and Managers.state.game_mode
    local game_mode_name = game_mode_manager and game_mode_manager:game_mode_name()

    return game_mode_name == "hub"
end

local function create_text_style(font_size, text_alignment, text_color, width, height)
    local base_style = UIFontSettings.hud_body
    local style = {
        font_type = base_style.font_type,
        line_spacing = base_style.line_spacing,
        drop_shadow = base_style.drop_shadow,
    }

    style.font_type = "proxima_nova_bold"
    style.font_size = font_size
    style.text_horizontal_alignment = text_alignment
    style.horizontal_alignment = text_alignment
    style.text_vertical_alignment = "center"
    style.vertical_alignment = "top"
    style.text_color = text_color
    style.default_text_color = text_color
    style.drop_shadow = true
    style.text_fit_with = true
    style.size = {width, height}
    style.offset = {0, 0, 0}

    return style
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
            style_id = "event",
            value = "",
            value_id = "event_text",
            style = create_text_style(
                BASE_FONT_SIZE,
                "left",
                {255, 255, 255, 255},
                MAX_EVENT_WIDTH,
                INITIAL_LINE_HEIGHT
            ),
        },
        {
            pass_type = "text",
            style_id = "score",
            value = "",
            value_id = "score_text",
            style = create_text_style(
                BASE_FONT_SIZE,
                "left",
                {255, 255, 255, 255},
                MAX_SCORE_WIDTH,
                INITIAL_LINE_HEIGHT
            ),
        },
    }, "score_feed_root_" .. index)
end

widget_definitions.score_feed_tally = UIWidget.create_definition({
    {
        pass_type = "text",
        style_id = "tally",
        value = "",
        value_id = "tally_text",
        style = create_text_style(BASE_FONT_SIZE * 1.85, "left", {255, 245, 250, 255}, 260, INITIAL_LINE_HEIGHT * 2),
    },
}, "score_feed_tally_root")

local function get_base_position()
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
    local vertical = clamp(tonumber(raw_v) or 25, 0, 100)
    local usable_height = math.max(screen_height - TOP_MARGIN - BOTTOM_MARGIN, 1)
    local base_x = screen_width * horizontal / 100
    local base_y = screen_height - BOTTOM_MARGIN - usable_height * vertical / 100

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

    return 28
end

local function hide_widget(widget)
    if widget then
        widget.visible = false
        widget.alpha_multiplier = 0
        widget.content.visible = false
        widget.content.event_text = ""
        widget.content.score_text = ""
    end
end

local function format_score(score)
    return string.format("%d", math.floor(tonumber(score) or 0))
end

local function get_revealed_text(text, elapsed, characters_per_second)
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

function HudHitKillScoreFeed:init(parent, draw_layer, start_scale)
    HudHitKillScoreFeed.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })

    self._has_visible_content = false
    self._was_visible = false

    for index = 1, MAX_ENTRIES do
        hide_widget(self._widgets_by_name["score_feed_entry_" .. index])
    end

    hide_widget(self._widgets_by_name.score_feed_tally)
end

function HudHitKillScoreFeed:_update_entry_widget(widget, entry, base_x, base_y, ui_renderer, font_size, line_height, scale)
    if (entry.alpha or 0) <= 0 then
        hide_widget(widget)
        return false
    end

    local s = scale or get_text_scale()
    local full_event_text = HKS:localize(entry.event_key) or entry.event_key
    local full_score_text = format_score(entry.score)
    local base_speed = get_typewriter_speed()
    local text_len = math.max(1, Utf8.string_length(full_event_text))
    local typewriter_speed = math.max(base_speed, math.ceil(text_len / 0.16))
    local reveal_elapsed = entry.reveal_elapsed or 0
    local event_text = get_revealed_text(full_event_text, reveal_elapsed, typewriter_speed)
    local event_duration = text_len / typewriter_speed
    local score_speed = math.max(typewriter_speed * 2, 60)
    local score_text = get_revealed_text(full_score_text, reveal_elapsed - event_duration * 0.7, score_speed)

    local event_style = widget.style.event
    local score_style = widget.style.score
    local is_bonus = entry.event_key == "bf4_feed_headshot_bonus" or entry.event_key == "bf4_feed_multikill_bonus"
    local event_font_scale = is_bonus and HEADSHOT_EVENT_FONT_SCALE or 1
    local event_font_size = math.max(1, math.floor(font_size * event_font_scale + 0.5))
    local score_font_size = event_font_size

    event_style.font_size = event_font_size
    score_style.font_size = score_font_size

    if entry._cached_event_text ~= full_event_text or entry._cached_event_font_size ~= event_font_size then
        local measured_event_width = self:_text_size(ui_renderer, full_event_text, event_style, {MAX_EVENT_WIDTH, line_height})
        entry._cached_event_width = math.ceil(measured_event_width or 0)
        entry._cached_event_text = full_event_text
        entry._cached_event_font_size = event_font_size
    end

    if entry._cached_score_text ~= score_text or entry._cached_score_font_size ~= score_font_size then
        local measured_score_width = self:_text_size(ui_renderer, score_text, score_style, {MAX_SCORE_WIDTH, line_height})
        entry._cached_score_width = math.ceil(measured_score_width or 0)
        entry._cached_score_text = score_text
        entry._cached_score_font_size = score_font_size
    end

    local clean_event_width = entry._cached_event_width or 0
    local clean_score_width = entry._cached_score_width or 0
    local gap = math.floor(TEXT_GAP * s)

    event_style.text_color = entry.color
    event_style.default_text_color = entry.color
    local event_pass_width = math.min(MAX_EVENT_WIDTH, math.max(1, clean_event_width + 32))

    event_style.size[1] = event_pass_width
    event_style.size[2] = line_height
    -- Eliminate - event_pass_width (+32px void); align using actual measured clean_event_width
    event_style.offset[1] = base_x - clean_event_width
    event_style.offset[2] = base_y + entry.current_y

    score_style.text_color = entry.color
    score_style.default_text_color = entry.color
    local score_pass_width = math.max(1, clean_score_width + 16)
    score_style.size[1] = score_pass_width
    score_style.size[2] = line_height
    -- Single-row score tightly follows event name on the right by 10 * scale
    score_style.offset[1] = base_x + gap
    score_style.offset[2] = base_y + entry.current_y

    widget.content.event_text = event_text
    widget.content.score_text = score_text
    widget.content.visible = true
    widget.visible = true
    widget.alpha_multiplier = entry.alpha
    return true
end

function HudHitKillScoreFeed:_update_tally_widget(widget, tally, base_x, base_y, ui_renderer, font_size, line_height, scale)
    if not widget then
        return false
    end

    if tally.alpha <= 0 or tally.displayed_total_score <= 0 then
        hide_widget(widget)

        return false
    end

    local s = scale or get_text_scale()
    local tally_style = widget.style.tally
    local tally_font_size = math.max(1, math.floor(font_size * 1.85 * tally.scale_multiplier))
    local tally_text = format_score(tally.displayed_total_score)

    tally_style.font_size = tally_font_size
    tally_style.text_horizontal_alignment = "left"
    tally_style.horizontal_alignment = "left"

    if tally._cached_text ~= tally_text or tally._cached_font_size ~= tally_font_size then
        local measured_tally_width = self:_text_size(ui_renderer, tally_text, tally_style, {260, line_height * 2})
        tally._cached_width = math.ceil(measured_tally_width or 0)
        tally._cached_text = tally_text
        tally._cached_font_size = tally_font_size
    end

    local flash_t = clamp((tally.scale_multiplier - 1.0) / 0.3, 0, 1)
    local color = {
        255,
        math.floor(245 + 10 * flash_t),
        math.floor(250 - 95 * flash_t),
        math.floor(255 - 195 * flash_t),
    }
    tally_style.text_color = color
    tally_style.default_text_color = color
    tally_style.size[1] = math.max(260, (tally._cached_width or 0) + 16)
    tally_style.size[2] = line_height * 2
    -- Independent right column for BF4 cumulative tally
    tally_style.offset[1] = base_x + math.floor(TALLY_OFFSET_X * s)
    tally_style.offset[2] = base_y - math.floor(line_height * 0.15) + tally.y_offset

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
    local base_x, base_y = get_base_position()
    local font_size = math.floor(BASE_FONT_SIZE * scale)
    local line_height = get_line_height()
    local entries = manager.get_entries()
    local has_visible = false

    for index = 1, MAX_ENTRIES do
        local widget = self._widgets_by_name["score_feed_entry_" .. index]
        local entry = entries[index]

        if entry then
            if self:_update_entry_widget(widget, entry, base_x, base_y, ui_renderer, font_size, line_height, scale) then
                has_visible = true
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
        scale
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
