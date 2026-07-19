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
local TEXT_GAP = 12
local BOTTOM_MARGIN = 90
local TOP_MARGIN = 90
local TALLY_OFFSET_X = 95
local TALLY_OFFSET_Y = 68

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function setting_percent(setting_id, default_value)
    return clamp(tonumber(HKS:get(setting_id)) or default_value, 0, 100)
end

local function feed_visible()
    return HKS:get("enabled") ~= false and HKS:get("bf4_feed_enabled") == true and
        HKS:get("killstreak_enabled") ~= false
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
        style = create_text_style(BASE_FONT_SIZE * 1.25, "center", {255, 255, 220, 80}, 260, INITIAL_LINE_HEIGHT * 2),
    },
}, "score_feed_tally_root")

local function get_base_position()
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local screen_height = UIWorkspaceSettings.screen.size[2]
    local horizontal = setting_percent("bf4_feed_horizontal_position", 50)
    local vertical = setting_percent("bf4_feed_vertical_position", 0)
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

    for index = 1, MAX_ENTRIES do
        hide_widget(self._widgets_by_name["score_feed_entry_" .. index])
    end

    hide_widget(self._widgets_by_name.score_feed_tally)
end

function HudHitKillScoreFeed:_update_entry_widget(widget, entry, base_x, base_y, ui_renderer, font_size, line_height)
    local full_event_text = HKS:localize(entry.event_key) or entry.event_key
    local full_score_text = format_score(entry.score)
    local typewriter_speed = get_typewriter_speed()
    local reveal_elapsed = entry.reveal_elapsed or 0
    local event_text = get_revealed_text(full_event_text, reveal_elapsed, typewriter_speed)
    local event_duration = Utf8.string_length(full_event_text) / typewriter_speed
    local score_text = get_revealed_text(full_score_text, reveal_elapsed - event_duration, typewriter_speed)
    local event_style = widget.style.event
    local score_style = widget.style.score
    local event_font_scale = entry.event_key == "bf4_feed_headshot_bonus" and HEADSHOT_EVENT_FONT_SCALE or 1
    local event_font_size = math.max(1, math.floor(font_size * event_font_scale + 0.5))

    event_style.font_size = event_font_size
    score_style.font_size = font_size

    local full_event_width = self:_text_size(ui_renderer, full_event_text, event_style, {MAX_EVENT_WIDTH, line_height})
    local score_width = self:_text_size(ui_renderer, score_text, score_style, {MAX_SCORE_WIDTH, line_height})

    event_style.text_color = entry.color
    event_style.default_text_color = entry.color
    local event_pass_width = math.min(MAX_EVENT_WIDTH, math.max(1, (full_event_width or 0) + 32))

    event_style.size[1] = event_pass_width
    event_style.size[2] = line_height
    event_style.offset[1] = base_x - TEXT_GAP - event_pass_width
    event_style.offset[2] = base_y + entry.current_y

    score_style.text_color = entry.color
    score_style.default_text_color = entry.color
    score_style.size[1] = math.max(MAX_SCORE_WIDTH, (score_width or 0) + 16)
    score_style.size[2] = line_height
    score_style.offset[1] = base_x + TEXT_GAP
    score_style.offset[2] = base_y + entry.current_y

    widget.content.event_text = event_text
    widget.content.score_text = score_text
    widget.content.visible = true
    widget.visible = true
    widget.alpha_multiplier = entry.alpha
end

function HudHitKillScoreFeed:_update_tally_widget(widget, tally, base_x, base_y, ui_renderer, font_size, line_height)
    if not widget then
        return
    end

    if tally.alpha <= 0 or tally.displayed_total_score <= 0 then
        hide_widget(widget)

        return
    end

    local tally_style = widget.style.tally
    local tally_font_size = math.floor(font_size * 1.25 * tally.scale_multiplier)
    local tally_text = format_score(tally.displayed_total_score)

    tally_style.font_size = tally_font_size

    local tally_width = self:_text_size(ui_renderer, tally_text, tally_style, {260, line_height * 2})

    tally_style.text_color = {255, 255, 220, 80}
    tally_style.default_text_color = tally_style.text_color
    tally_style.size[1] = math.max(260, (tally_width or 0) + 16)
    tally_style.size[2] = line_height * 2
    tally_style.offset[1] = base_x + TALLY_OFFSET_X - tally_style.size[1] / 2
    tally_style.offset[2] = base_y - TALLY_OFFSET_Y + tally.y_offset

    widget.content.tally_text = tally_text
    widget.content.visible = true
    widget.visible = true
    widget.alpha_multiplier = tally.alpha
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
        self:_hide_all_widgets()

        return
    end

    local base_x, base_y = get_base_position()
    local font_size = math.floor(BASE_FONT_SIZE * get_text_scale())
    local line_height = get_line_height()
    local entries = manager.get_entries()

    for index = 1, MAX_ENTRIES do
        local widget = self._widgets_by_name["score_feed_entry_" .. index]
        local entry = entries[index]

        if entry then
            self:_update_entry_widget(widget, entry, base_x, base_y, ui_renderer, font_size, line_height)
        else
            hide_widget(widget)
        end
    end

    self:_update_tally_widget(
        self._widgets_by_name.score_feed_tally,
        manager.get_tally(),
        base_x,
        base_y,
        ui_renderer,
        font_size,
        line_height
    )
    HudHitKillScoreFeed.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

function HudHitKillScoreFeed:draw(dt, t, ui_renderer, render_settings, input_service)
    if not feed_visible() or is_in_hub() then
        return
    end

    HudHitKillScoreFeed.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

return HudHitKillScoreFeed
