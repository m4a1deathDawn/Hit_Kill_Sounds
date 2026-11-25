-- luacheck: globals get_mod Managers class
local HKS = get_mod("Hit_Kill_Sounds")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIFontSettings = require("scripts/managers/ui/ui_font_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

local ICON_SIZE = 64
local ICON_ROOT_SIZE = 96
local MAX_SLOTS = 10
local MAX_LEAVING_SLOTS = 8
local MAX_DETACHED_RIPPLES = 4
local MAX_PENDING_QUEUE = 24
local MAX_ROW_WIDTH_RATIO = 0.54
local MAX_BF5_BONUS_LINES = 3
local BF5_TEXT_BOX_WIDTH = 960
local BF5_KILL_BASE_FONT = 22
local BF5_TOTAL_BASE_FONT = 44
local BF5_BONUS_BASE_FONT = 18
local BF5_TEXT_MARGIN_X = 220
local BF5_TEXT_BOTTOM_MARGIN = 20

local NORMAL_BASE_SCALE = 1.00
local HEADSHOT_BASE_SCALE = 1.12
local BOSS_BASE_SCALE = 1.16

local ENTRY_START_ALPHA = 0.15

local NORMAL_POP_RATIO = 2.60
local NORMAL_HOLD_DURATION = 0.025
local NORMAL_SLAM_DURATION = 0.145

local HEADSHOT_POP_RATIO = 3.15
local HEADSHOT_HOLD_DURATION = 0.045
local HEADSHOT_SLAM_DURATION = 0.115
local HEADSHOT_REBOUND_DURATION = 0.065
local HEADSHOT_OVERSHOOT_SCALE = 0.92

local BOSS_POP_RATIO = 3.45
local BOSS_HOLD_DURATION = 0.060
local BOSS_SLAM_DURATION = 0.120
local BOSS_REBOUND_DURATION = 0.075
local BOSS_OVERSHOOT_SCALE = 0.89
local BOSS_SPIN_DURATION = 0.42

local RIPPLE_TRIGGER_SCALE = 1.08
local RIPPLE_FORCE_START = 0.18
local RING_DURATION = 0.50
local RING_MORPH_DURATION = 0.26
local RING_PEAK_END = 0.03
local RING_HOLD_END = 0.08
local RING_START_SCALE = 0.96
local RING_END_SCALE = 4.15

local WAVE_STEP_NORMAL = 0.055
local WAVE_STEP_DENSE = 0.040
local NATURAL_FADE_DURATION = 0.26
local OVERFLOW_LEAVE_DURATION = 0.18
local HANDOFF_FADE_DURATION = 0.18
local LEAVE_OFFSET = 48
local HORIZONTAL_DAMP_SPEED = 18

local _textures = {
    normal = nil,
    headshot = nil,
    boss = nil,
    circle = nil,
    circle_bold = nil,
    circle_thin = nil,
}
local _texture_load_state = "idle" -- "idle" | "loading" | "ready"

local _settings_cache = {
    enabled = true,
    style = "BF5",
    icon_enabled = true,
    boss_icon_enabled = true,
    text_enabled = true,
    hit_score_enabled = true,
    text_scale = 1.0,
    size_scale = 1.0,
    duration = 2.0,
    horizontal = 50,
    vertical = 75,
    transparency_factor = 1.0,
    normal_r = 255,
    normal_g = 255,
    normal_b = 255,
    headshot_r = 255,
    headshot_g = 140,
    headshot_b = 20,
    boss_r = 220,
    boss_g = 46,
    boss_b = 38,
}
local _settings_force_layout = true

local _sorted_active_buf = {}
local _bonus_texts = {"", "", ""}
local _bonus_slots = {1, 2, 3}
local _bonus_alphas = {0, 0, 0}
local _bonus_shifts = {0, 0, 0}

local function clamp01(value)
    if value <= 0 then
        return 0
    elseif value >= 1 then
        return 1
    end
    return value
end

local function refresh_settings_cache()
    local c = _settings_cache
    c.enabled = HKS:get("enabled") ~= false
    c.style = HKS:get("kill_icon_style")
    c.icon_enabled = HKS:get("kill_icon_enabled") == true
    c.boss_icon_enabled = HKS:get("bf5_boss_icon_enabled") ~= false
    c.text_enabled = HKS:get("bf5_text_feedback_enabled") ~= false
    c.hit_score_enabled = HKS:get("bf5_hit_score_enabled") ~= false
    c.text_scale = math.max(0.5, math.min(1.5, (tonumber(HKS:get("bf5_text_scale")) or 100) / 100))
    c.size_scale = (tonumber(HKS:get("kill_icon_size")) or 10) / 10
    c.duration = (tonumber(HKS:get("kill_icon_duration")) or 20) / 10
    c.horizontal = tonumber(HKS:get("kill_icon_horizontal_position")) or 50
    c.vertical = tonumber(HKS:get("kill_icon_vertical_position")) or 75
    c.transparency_factor = (tonumber(HKS:get("kill_icon_transparency")) or 100) / 100
    c.normal_r = tonumber(HKS:get("kill_icon_normal_color_r")) or 255
    c.normal_g = tonumber(HKS:get("kill_icon_normal_color_g")) or 255
    c.normal_b = tonumber(HKS:get("kill_icon_normal_color_b")) or 255
    c.headshot_r = tonumber(HKS:get("kill_icon_headshot_color_r")) or 255
    c.headshot_g = tonumber(HKS:get("kill_icon_headshot_color_g")) or 140
    c.headshot_b = tonumber(HKS:get("kill_icon_headshot_color_b")) or 20
    c.boss_r = tonumber(HKS:get("kill_icon_boss_color_r")) or 220
    c.boss_g = tonumber(HKS:get("kill_icon_boss_color_g")) or 46
    c.boss_b = tonumber(HKS:get("kill_icon_boss_color_b")) or 38
    return c
end

local function compute_y_pos(settings)
    local screen_height = UIWorkspaceSettings.screen.size[2]
    return (settings.vertical / 100) * (screen_height - ICON_ROOT_SIZE)
end

local function compute_stagger_interval(pending_count)
    if pending_count <= 2 then
        return 0.095
    elseif pending_count <= 5 then
        return 0.070
    elseif pending_count <= 10 then
        return 0.050
    end
    return 0.035
end

local function compute_kill_priority(is_headshot, is_boss)
    if is_boss then
        return 3
    elseif is_headshot then
        return 2
    end
    return 1
end

local function new_slot()
    return {
        active = false,
        is_headshot = false,
        is_boss = false,
        start_time = 0,
        target_x = 0,
        current_x = 0,
        order = 0,
        leaving = false,
        leave_mode = "overflow",
        leaving_start_time = 0,
        leave_duration = OVERFLOW_LEAVE_DURATION,
        fade_start_time = nil,
        fade_captured = false,
        fade_start_alpha = 1,
        fade_start_scale = 1,
        render_alpha = 1,
        render_scale = 1,
        render_angle = 0,
        ripple_triggered = false,
        ripple_start_time = nil,
    }
end

local function reset_slot(slot)
    slot.active = false
    slot.is_headshot = false
    slot.is_boss = false
    slot.start_time = 0
    slot.target_x = 0
    slot.current_x = 0
    slot.order = 0
    slot.leaving = false
    slot.leave_mode = "overflow"
    slot.leaving_start_time = 0
    slot.leave_duration = OVERFLOW_LEAVE_DURATION
    slot.fade_start_time = nil
    slot.fade_captured = false
    slot.fade_start_alpha = 1
    slot.fade_start_scale = 1
    slot.render_alpha = 1
    slot.render_scale = 1
    slot.render_angle = 0
    slot.ripple_triggered = false
    slot.ripple_start_time = nil
end

local function new_detached_ripple()
    return {
        active = false,
        is_headshot = false,
        is_boss = false,
        ripple_start_time = 0,
        x = 0,
        y = 0,
        size_scale = 1,
    }
end

local function reset_detached_ripple(ripple)
    ripple.active = false
    ripple.is_headshot = false
    ripple.is_boss = false
    ripple.ripple_start_time = 0
    ripple.x = 0
    ripple.y = 0
    ripple.size_scale = 1
end

local function new_pending_entry()
    return {
        is_headshot = false,
        is_boss = false,
        priority = 1,
    }
end

HKS.HitKillIconManager = {
    _slots = {},
    _leaving_slots = {},
    _detached_ripples = {},
    _pending_queue = {},
    _pending_count = 0,
    _next_spawn_time = 0,
    _next_order = 0,
    _last_kill_time = nil,
    _natural_fade_start = nil,
    _fade_wave_active = false,
}
local manager = HKS.HitKillIconManager

for i = 1, MAX_SLOTS do manager._slots[i] = new_slot() end
for i = 1, MAX_LEAVING_SLOTS do manager._leaving_slots[i] = new_slot() end
for i = 1, MAX_DETACHED_RIPPLES do manager._detached_ripples[i] = new_detached_ripple() end
for i = 1, MAX_PENDING_QUEUE do manager._pending_queue[i] = new_pending_entry() end

manager.invalidate_settings = function()
    _settings_force_layout = true
end

local function get_bf5_text()
    return HKS.HitKillBF5Text
end

manager.clear = function()
    for i = 1, MAX_SLOTS do reset_slot(manager._slots[i]) end
    for i = 1, MAX_LEAVING_SLOTS do reset_slot(manager._leaving_slots[i]) end
    for i = 1, MAX_DETACHED_RIPPLES do reset_detached_ripple(manager._detached_ripples[i]) end
    manager._pending_count = 0
    manager._next_spawn_time = 0
    manager._last_kill_time = nil
    manager._natural_fade_start = nil
    manager._fade_wave_active = false
    local bf5_text = get_bf5_text()
    if bf5_text and bf5_text.clear then
        bf5_text.clear()
    end
    _settings_force_layout = true
end

local function get_size_scale()
    return (tonumber(HKS:get("kill_icon_size")) or 10) / 10
end

local function is_slot_boss_active(slot, boss_enabled)
    if boss_enabled == nil then
        boss_enabled = HKS:get("bf5_boss_icon_enabled") ~= false
    end
    return slot ~= nil and slot.is_boss == true and boss_enabled and _textures.boss ~= nil
end

local function default_slot_base_scale(slot, boss_enabled)
    if is_slot_boss_active(slot, boss_enabled) then
        return BOSS_BASE_SCALE
    end
    return slot.is_headshot and HEADSHOT_BASE_SCALE or NORMAL_BASE_SCALE
end

local function slot_pop_ratio(slot, boss_enabled)
    if is_slot_boss_active(slot, boss_enabled) then
        return BOSS_POP_RATIO
    end
    return slot.is_headshot and HEADSHOT_POP_RATIO or NORMAL_POP_RATIO
end

local function sort_slots_by_order(a, b)
    return a.order < b.order
end

local function collect_sorted_active_slots()
    local count = 0
    for i = 1, MAX_SLOTS do
        local slot = manager._slots[i]
        if slot.active then
            count = count + 1
            _sorted_active_buf[count] = slot
        end
    end
    for i = count + 1, #_sorted_active_buf do
        _sorted_active_buf[i] = nil
    end
    if count > 1 then
        table.sort(_sorted_active_buf, sort_slots_by_order)
    end
    return _sorted_active_buf, count
end

local function recompute_targets(settings)
    local size_scale = settings and settings.size_scale or get_size_scale()
    local horizontal = settings and settings.horizontal or (tonumber(HKS:get("kill_icon_horizontal_position")) or 50)
    local screen_width = UIWorkspaceSettings.screen.size[1]
    local base_x = screen_width * horizontal / 100 - ICON_ROOT_SIZE * 0.5
    local active, count = collect_sorted_active_slots()

    local base_spacing = (ICON_ROOT_SIZE - 20) * size_scale
    local max_row_width = screen_width * MAX_ROW_WIDTH_RATIO
    local spacing = count > 1 and math.min(base_spacing, max_row_width / (count - 1)) or base_spacing

    for index = 1, count do
        active[index].target_x = base_x + (index - (count + 1) * 0.5) * spacing
    end
    return count
end

local function oldest_active_slot()
    local oldest
    for i = 1, MAX_SLOTS do
        local slot = manager._slots[i]
        if slot.active and (not oldest or slot.order < oldest.order) then
            oldest = slot
        end
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

local function has_active_ripples()
    for i = 1, MAX_DETACHED_RIPPLES do
        if manager._detached_ripples[i].active then
            return true
        end
    end
    return false
end

local function has_leaving_slots()
    for i = 1, MAX_LEAVING_SLOTS do
        if manager._leaving_slots[i].active then
            return true
        end
    end
    return false
end

local function has_active_text()
    local bf5_text = get_bf5_text()
    return bf5_text ~= nil and bf5_text.is_active ~= nil and bf5_text.is_active()
end

local function has_any_visual(slots_list, leaving_list)
    return has_active_slots(slots_list, leaving_list) or has_active_ripples() or has_active_text()
end

local function has_any_work(slots_list, leaving_list)
    return has_any_visual(slots_list, leaving_list) or manager._pending_count > 0
end

local function detach_slot_ripple(slot, now, y_pos, size_scale, boss_enabled)
    if not slot or not slot.ripple_triggered or not slot.ripple_start_time then
        return false
    end
    local r_elapsed = now - slot.ripple_start_time
    if r_elapsed < 0 or r_elapsed >= RING_DURATION then
        slot.ripple_start_time = nil
        return false
    end

    local use_boss = is_slot_boss_active(slot, boss_enabled)
    if not slot.is_headshot and not use_boss then
        slot.ripple_start_time = nil
        return false
    end

    local dest
    for i = 1, MAX_DETACHED_RIPPLES do
        local candidate = manager._detached_ripples[i]
        if not candidate.active then
            dest = candidate
            break
        end
    end
    if not dest then
        dest = manager._detached_ripples[1]
        for i = 2, MAX_DETACHED_RIPPLES do
            local candidate = manager._detached_ripples[i]
            if candidate.ripple_start_time < dest.ripple_start_time then
                dest = candidate
            end
        end
    end

    dest.active = true
    dest.is_headshot = slot.is_headshot
    dest.is_boss = use_boss
    dest.ripple_start_time = slot.ripple_start_time
    dest.x = slot.current_x
    dest.y = y_pos
    dest.size_scale = size_scale or get_size_scale()
    slot.ripple_start_time = nil
    return true
end

local function copy_leaving_slot(source, now, leave_mode)
    local destination
    for i = 1, MAX_LEAVING_SLOTS do
        local candidate = manager._leaving_slots[i]
        if not candidate.active then
            destination = candidate
            break
        end
    end
    if not destination then
        destination = manager._leaving_slots[1]
        for i = 2, MAX_LEAVING_SLOTS do
            local candidate = manager._leaving_slots[i]
            if candidate.leaving_start_time < destination.leaving_start_time then
                destination = candidate
            end
        end
    end

    local default_scale = default_slot_base_scale(source)
    local fade_start_alpha = (source.render_alpha ~= nil and source.render_alpha > 0) and source.render_alpha or 1
    local fade_start_scale = (source.render_scale ~= nil and source.render_scale > 0)
        and source.render_scale or default_scale

    destination.active = true
    destination.leaving = true
    destination.leave_mode = leave_mode or "overflow"
    destination.is_headshot = source.is_headshot
    destination.is_boss = source.is_boss == true
    destination.start_time = source.start_time
    destination.current_x = source.current_x
    destination.target_x = source.current_x
    destination.leaving_start_time = now
    destination.leave_duration = destination.leave_mode == "fade_in_place"
        and HANDOFF_FADE_DURATION or OVERFLOW_LEAVE_DURATION
    destination.fade_start_time = nil
    destination.fade_captured = false
    destination.fade_start_alpha = fade_start_alpha
    destination.fade_start_scale = fade_start_scale
    destination.render_alpha = fade_start_alpha
    destination.render_scale = fade_start_scale
    destination.render_angle = source.render_angle or 0
    destination.ripple_triggered = false
    destination.ripple_start_time = nil
    return destination
end

local function copy_overflow_slot(source, now)
    return copy_leaving_slot(source, now, "overflow")
end

local function update_leaving_slot_state(slot, now, size_scale)
    local duration = slot.leave_duration or OVERFLOW_LEAVE_DURATION
    local leave_t = clamp01((now - slot.leaving_start_time) / duration)
    if leave_t >= 1 then
        reset_slot(slot)
        return false
    end
    if slot.leave_mode == "fade_in_place" then
        slot.current_x = slot.target_x
        slot.render_alpha = (slot.fade_start_alpha or 1) * (1 - leave_t * leave_t)
        slot.render_scale = (slot.fade_start_scale or 1) * (1 - 0.16 * leave_t)
    else
        local eased = 1 - (1 - leave_t) ^ 3
        slot.current_x = slot.target_x - LEAVE_OFFSET * (size_scale or 1) * eased
        slot.render_alpha = (slot.fade_start_alpha or 1) * (1 - leave_t)
        slot.render_scale = (slot.fade_start_scale or 1) * (1 - 0.15 * leave_t)
    end
    return true
end

local function update_leaving_slots(now, size_scale)
    size_scale = size_scale or get_size_scale()
    for i = 1, MAX_LEAVING_SLOTS do
        local slot = manager._leaving_slots[i]
        if slot.active then
            update_leaving_slot_state(slot, now, size_scale)
        end
    end
end

manager.copy_overflow_slot = copy_overflow_slot
manager.update_leaving_slots = update_leaving_slots

local function enqueue_pending(is_headshot, is_boss)
    local incoming_priority = compute_kill_priority(is_headshot, is_boss)
    local count = manager._pending_count

    if count < MAX_PENDING_QUEUE then
        count = count + 1
        local entry = manager._pending_queue[count]
        entry.is_headshot = is_headshot == true
        entry.is_boss = is_boss == true
        entry.priority = incoming_priority
        manager._pending_count = count
        return true
    end

    -- Queue full: protect higher-priority kills (Boss > Headshot > Normal).
    local victim_index = nil
    local lowest_priority = math.huge
    for i = 1, count do
        local item = manager._pending_queue[i]
        if item.priority < lowest_priority then
            lowest_priority = item.priority
            victim_index = i
        end
    end

    if not victim_index or lowest_priority > incoming_priority then
        return false
    end

    local recycled = manager._pending_queue[victim_index]
    for i = victim_index, count - 1 do
        manager._pending_queue[i] = manager._pending_queue[i + 1]
    end
    recycled.is_headshot = is_headshot == true
    recycled.is_boss = is_boss == true
    recycled.priority = incoming_priority
    manager._pending_queue[count] = recycled
    return true
end

local function dequeue_pending()
    local count = manager._pending_count
    if count <= 0 then
        return nil, nil
    end

    local head = manager._pending_queue[1]
    local is_headshot = head.is_headshot
    local is_boss = head.is_boss

    for i = 1, count - 1 do
        manager._pending_queue[i] = manager._pending_queue[i + 1]
    end
    manager._pending_queue[count] = head
    manager._pending_count = count - 1
    return is_headshot, is_boss
end

local function spawn_slot_now(is_headshot, is_boss, now, settings)
    settings = settings or refresh_settings_cache()
    local size_scale = settings.size_scale
    local y_pos = compute_y_pos(settings)

    -- Seamless handoff: move fading wave icons into the leaving pool instead of popping them out.
    if manager._fade_wave_active or manager._natural_fade_start then
        for i = 1, MAX_SLOTS do
            local existing = manager._slots[i]
            if existing.active then
                detach_slot_ripple(existing, now, y_pos, size_scale, settings.boss_icon_enabled)
                copy_leaving_slot(existing, now, "fade_in_place")
                reset_slot(existing)
            end
        end
        manager._fade_wave_active = false
        manager._natural_fade_start = nil
    end

    local slot
    for i = 1, MAX_SLOTS do
        local candidate = manager._slots[i]
        if not candidate.active then
            slot = candidate
            break
        end
    end
    if not slot then
        slot = oldest_active_slot()
        if slot then
            detach_slot_ripple(slot, now, y_pos, size_scale, settings.boss_icon_enabled)
            copy_leaving_slot(slot, now, "overflow")
            reset_slot(slot)
        end
    end
    if not slot then return end

    manager._next_order = manager._next_order + 1
    slot.active = true
    slot.is_headshot = is_headshot == true
    slot.is_boss = is_boss == true
    slot.start_time = now
    slot.current_x = 0
    slot.target_x = 0
    slot.order = manager._next_order
    slot.leaving = false
    slot.leave_mode = "overflow"
    slot.fade_start_time = nil
    slot.fade_captured = false
    slot.fade_start_alpha = 1
    local base_scale = default_slot_base_scale(slot, settings.boss_icon_enabled)
    slot.fade_start_scale = base_scale
    slot.render_alpha = ENTRY_START_ALPHA
    slot.render_scale = base_scale * slot_pop_ratio(slot, settings.boss_icon_enabled)
    slot.render_angle = 0
    slot.ripple_triggered = false
    slot.ripple_start_time = nil

    manager._last_kill_time = now
    manager._natural_fade_start = nil
    manager._fade_wave_active = false

    local active_count = recompute_targets(settings)
    local slide_offset = (active_count > 1 or has_leaving_slots()) and (28 * size_scale) or 0
    slot.current_x = slot.target_x + slide_offset
end

local function drain_pending_queue(now, settings)
    local spawned = 0
    while manager._pending_count > 0 and now >= manager._next_spawn_time and spawned < 2 do
        local is_headshot, is_boss = dequeue_pending()
        spawn_slot_now(is_headshot, is_boss, now, settings)
        spawned = spawned + 1
        manager._next_spawn_time = now + compute_stagger_interval(manager._pending_count)
    end
    return spawned > 0
end

manager.show_icon = function(is_headshot, is_boss, kill_ctx)
    local now = Managers.time:time("main")
    local settings = refresh_settings_cache()

    if manager._pending_count == 0 and now >= manager._next_spawn_time then
        spawn_slot_now(is_headshot, is_boss, now, settings)
        manager._next_spawn_time = now + compute_stagger_interval(0)
    else
        enqueue_pending(is_headshot, is_boss)
        manager._last_kill_time = now
    end

    if settings.text_enabled and kill_ctx then
        local bf5_text = get_bf5_text()
        if bf5_text and bf5_text.add_kill then
            bf5_text.add_kill(kill_ctx, now)
        end
    end
end

local function textures_ready()
    return _textures.normal ~= nil and _textures.headshot ~= nil
        and (_textures.circle_thin ~= nil or _textures.circle_bold ~= nil or _textures.circle ~= nil)
end

local function preload_textures_legacy()
    if HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.start_player then
        HKS.HitKillSoundsPlayer.start_player()
    end
    local host = HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host
    if not host then
        _texture_load_state = textures_ready() and "ready" or "idle"
        return
    end
    _texture_load_state = "loading"
    local urls = {
        normal = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_normal.png",
        headshot = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_headshot.png",
        boss = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_boss.png",
        circle_bold = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_circle_bold.png",
        circle_thin = host .. "image?path=cartoon_preview/kill_icon/BFV/kill_circle_thin.png",
    }
    local remaining = 5
    local function on_item_done()
        remaining = remaining - 1
        if textures_ready() then
            _texture_load_state = "ready"
        elseif remaining <= 0 then
            _texture_load_state = "idle"
        end
    end
    for key, url in pairs(urls) do
        local texture_key = key
        local promise = Managers.url_loader:load_texture(url)
        if promise and promise.next then
            promise:next(function(data)
                if data and data.texture then
                    _textures[texture_key] = data.texture
                    if texture_key == "circle_thin" or texture_key == "circle_bold" then
                        _textures.circle = _textures.circle_thin or _textures.circle_bold
                    end
                end
                on_item_done()
            end)
            if promise.catch then
                promise:catch(on_item_done)
            end
        else
            on_item_done()
        end
    end
end

local function preload_textures()
    if textures_ready() then
        _texture_load_state = "ready"
        return
    end
    if _texture_load_state == "loading" then
        return
    end
    _texture_load_state = "loading"
    if HKS.HitKillSoundsAssetsBackend then
        HKS.HitKillSoundsAssetsBackend.load_bf5_icons(_textures, function()
            preload_textures_legacy()
        end, function(ok)
            if ok and textures_ready() then
                _texture_load_state = "ready"
            elseif not ok and not (HKS.HitKillSoundsPlayer and HKS.HitKillSoundsPlayer.host) then
                _texture_load_state = textures_ready() and "ready" or "idle"
            end
        end)
    else
        preload_textures_legacy()
    end
end

local function pass_visible(_content, style)
    return style.material_values.texture_map ~= nil and style.color[1] > 0
end

local function text_pass_visible(content, style)
    local text = content.text
    return text ~= nil and text ~= "" and style.text_color[1] > 0
end

local function create_bf5_text_widget_definition(scenegraph_id, font_size, r, g, b)
    local base_style = UIFontSettings.hud_body
    return UIWidget.create_definition({
        {
            pass_type = "text",
            style_id = "text",
            value = "",
            value_id = "text",
            style = {
                font_type = "proxima_nova_bold",
                font_size = font_size,
                line_spacing = base_style and base_style.line_spacing or 1.1,
                drop_shadow = true,
                text_horizontal_alignment = "center",
                horizontal_alignment = "center",
                text_vertical_alignment = "top",
                vertical_alignment = "top",
                text_color = {0, r, g, b},
                default_text_color = {0, r, g, b},
                size = {BF5_TEXT_BOX_WIDTH, math.ceil(font_size * 1.4)},
                offset = {0, 0, 0},
            },
            visibility_function = text_pass_visible,
        },
    }, scenegraph_id)
end

local function create_dual_ring_widget_definition(scenegraph_id)
    return UIWidget.create_definition({
        {
            style_id = "circle_bold",
            value_id = "circle_bold",
            pass_type = "texture",
            style = {
                material_values = {use_placeholder_texture = 0, texture_map = nil},
                color = {0, 255, 255, 255},
                offset = {0, 0, 0},
                size = {ICON_SIZE, ICON_SIZE},
            },
            visibility_function = pass_visible,
        },
        {
            style_id = "circle",
            value_id = "circle",
            pass_type = "texture",
            style = {
                material_values = {use_placeholder_texture = 0, texture_map = nil},
                color = {0, 255, 255, 255},
                offset = {0, 0, 1},
                size = {ICON_SIZE, ICON_SIZE},
            },
            visibility_function = pass_visible,
        },
    }, scenegraph_id)
end

local scenegraph_definition = {screen = UIWorkspaceSettings.screen}
local widget_definitions = {}
local TOTAL_ICON_WIDGETS = MAX_SLOTS + MAX_LEAVING_SLOTS

for i = 1, TOTAL_ICON_WIDGETS do
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
        position = {0, 0, -1},
    }
    widget_definitions["kill_icon_" .. i] = UIWidget.create_definition({{
        style_id = "icon",
        value_id = "icon",
        pass_type = "rotated_texture",
        style = {
            material_values = {use_placeholder_texture = 0, texture_map = nil},
            color = {0, 255, 255, 255},
            offset = {0, 0, 0},
            size = {ICON_SIZE, ICON_SIZE},
            uvs = {{0, 0}, {1, 1}},
            angle = 0,
            pivot = {0, 0},
        },
        visibility_function = pass_visible,
    }}, "icon_root_" .. i)
    widget_definitions["circle_icon_" .. i] = create_dual_ring_widget_definition("circle_root_" .. i)
end

for i = 1, MAX_DETACHED_RIPPLES do
    scenegraph_definition["detached_circle_root_" .. i] = {
        horizontal_alignment = "left",
        parent = "screen",
        vertical_alignment = "top",
        size = {ICON_ROOT_SIZE, ICON_ROOT_SIZE},
        position = {0, 0, -2},
    }
    widget_definitions["detached_circle_icon_" .. i] =
        create_dual_ring_widget_definition("detached_circle_root_" .. i)
end

scenegraph_definition.bf5_text_kill_root = {
    horizontal_alignment = "left",
    parent = "screen",
    vertical_alignment = "top",
    size = {BF5_TEXT_BOX_WIDTH, 48},
    position = {0, 0, 2},
}
widget_definitions.bf5_text_kill = create_bf5_text_widget_definition(
    "bf5_text_kill_root", BF5_KILL_BASE_FONT, 255, 255, 255
)

scenegraph_definition.bf5_text_total_root = {
    horizontal_alignment = "left",
    parent = "screen",
    vertical_alignment = "top",
    size = {BF5_TEXT_BOX_WIDTH, 76},
    position = {0, 0, 2},
}
widget_definitions.bf5_text_total = create_bf5_text_widget_definition(
    "bf5_text_total_root", BF5_TOTAL_BASE_FONT, 255, 255, 255
)

for i = 1, MAX_BF5_BONUS_LINES do
    scenegraph_definition["bf5_text_bonus_root_" .. i] = {
        horizontal_alignment = "left",
        parent = "screen",
        vertical_alignment = "top",
        size = {BF5_TEXT_BOX_WIDTH, 40},
        position = {0, 0, 2},
    }
    widget_definitions["bf5_text_bonus_" .. i] = create_bf5_text_widget_definition(
        "bf5_text_bonus_root_" .. i, BF5_BONUS_BASE_FONT, 238, 244, 250
    )
end

local HudHitKillICON = class("HudHitKillICON", "HudElementBase")

HudHitKillICON.init = function(self, parent, draw_layer, start_scale)
    HudHitKillICON.super.init(self, parent, draw_layer, start_scale, {
        scenegraph_definition = scenegraph_definition,
        widget_definitions = widget_definitions,
    })
    self._slots = manager._slots
    self._leaving_slots = manager._leaving_slots
    self._detached_ripples = manager._detached_ripples
    self._was_active = true
    self._has_active_content = false
    preload_textures()
end

local function clear_pass_style(style)
    if not style then return false end
    local changed = false
    if style.material_values and style.material_values.texture_map ~= nil then
        style.material_values.texture_map = nil
        changed = true
    end
    if style.color and style.color[1] ~= 0 then
        style.color[1] = 0
        changed = true
    end
    return changed
end

local function clear_widget(icon_widget, circle_widget)
    local changed = false
    if icon_widget and icon_widget.style then
        if clear_pass_style(icon_widget.style.icon) then
            changed = true
        end
    end
    if circle_widget and circle_widget.style then
        if clear_pass_style(circle_widget.style.circle_bold) then
            changed = true
        end
        if clear_pass_style(circle_widget.style.circle) then
            changed = true
        end
    end
    return changed
end

local function clear_text_widget(widget)
    if not widget then return false end
    local changed = false
    if widget.content and widget.content.text ~= "" then
        widget.content.text = ""
        changed = true
    end
    local style = widget.style and widget.style.text
    if style and style.text_color and style.text_color[1] ~= 0 then
        style.text_color[1] = 0
        changed = true
    end
    return changed
end

local function clear_all_text_widgets(self)
    local changed = false
    if clear_text_widget(self._widgets_by_name.bf5_text_kill) then
        changed = true
    end
    if clear_text_widget(self._widgets_by_name.bf5_text_total) then
        changed = true
    end
    for i = 1, MAX_BF5_BONUS_LINES do
        if clear_text_widget(self._widgets_by_name["bf5_text_bonus_" .. i]) then
            changed = true
        end
    end
    return changed
end

local function clear_all_widgets(self)
    for i = 1, TOTAL_ICON_WIDGETS do
        clear_widget(self._widgets_by_name["kill_icon_" .. i], self._widgets_by_name["circle_icon_" .. i])
    end
    for i = 1, MAX_DETACHED_RIPPLES do
        clear_widget(nil, self._widgets_by_name["detached_circle_icon_" .. i])
    end
    clear_all_text_widgets(self)
end

local function set_pass_style(style, texture, alpha, r, g, b, size, root_size, z, angle)
    if not style then return end
    local clamped_alpha = math.max(0, math.min(255, math.floor((tonumber(alpha) or 0) + 0.5)))
    if not texture or clamped_alpha <= 0 or size <= 0 then
        clear_pass_style(style)
        return
    end
    style.material_values.texture_map = texture
    local color = style.color
    color[1] = clamped_alpha
    color[2] = r
    color[3] = g
    color[4] = b
    local size_tbl = style.size
    size_tbl[1] = size
    size_tbl[2] = size
    local half_offset = (root_size - size) * 0.5
    local offset_tbl = style.offset
    offset_tbl[1] = half_offset
    offset_tbl[2] = half_offset
    offset_tbl[3] = z or 0
    if style.pivot then
        style.angle = angle or 0
        style.pivot[1] = size * 0.5
        style.pivot[2] = size * 0.5
    end
end

local function resolve_slot_color(slot, settings, use_boss_icon)
    if use_boss_icon then
        return settings.boss_r, settings.boss_g, settings.boss_b
    end
    if slot.is_headshot then
        return settings.headshot_r, settings.headshot_g, settings.headshot_b
    end
    return settings.normal_r, settings.normal_g, settings.normal_b
end

local function compute_entry_state(slot, elapsed, use_boss_icon)
    local pop_ratio
    local hold_duration
    local slam_duration
    local rebound_duration
    local overshoot_scale

    if use_boss_icon then
        pop_ratio = BOSS_POP_RATIO
        hold_duration = BOSS_HOLD_DURATION
        slam_duration = BOSS_SLAM_DURATION
        rebound_duration = BOSS_REBOUND_DURATION
        overshoot_scale = BOSS_OVERSHOOT_SCALE
    elseif slot.is_headshot then
        pop_ratio = HEADSHOT_POP_RATIO
        hold_duration = HEADSHOT_HOLD_DURATION
        slam_duration = HEADSHOT_SLAM_DURATION
        rebound_duration = HEADSHOT_REBOUND_DURATION
        overshoot_scale = HEADSHOT_OVERSHOOT_SCALE
    else
        pop_ratio = NORMAL_POP_RATIO
        hold_duration = NORMAL_HOLD_DURATION
        slam_duration = NORMAL_SLAM_DURATION
        rebound_duration = 0
        overshoot_scale = 1.00
    end

    if elapsed <= hold_duration then
        return pop_ratio, ENTRY_START_ALPHA
    end

    local slam_elapsed = elapsed - hold_duration
    if slam_elapsed <= slam_duration then
        local t = slam_elapsed / slam_duration
        local eased = 1 - (1 - t) ^ 3
        local anim_scale = pop_ratio + (overshoot_scale - pop_ratio) * eased
        local clamped_ratio = math.max(1.0, anim_scale)
        local remaining = (clamped_ratio - 1.0) / (pop_ratio - 1.0)
        local progress = 1.0 - clamp01(remaining)
        local entry_alpha = ENTRY_START_ALPHA + (1.0 - ENTRY_START_ALPHA) * (progress ^ 0.85)
        return anim_scale, entry_alpha
    end

    if rebound_duration > 0 then
        local rebound_elapsed = slam_elapsed - slam_duration
        if rebound_elapsed < rebound_duration then
            local rt = rebound_elapsed / rebound_duration
            local rebound_eased = 1 - (1 - rt) ^ 2
            local anim_scale = overshoot_scale + (1.00 - overshoot_scale) * rebound_eased
            return anim_scale, 1.0
        end
    end

    return 1.0, 1.0
end

local function render_dual_rings(
    circle_widget, r_elapsed, size_scale, transparency_factor, base_r, base_g, base_b
)
    if not circle_widget or not circle_widget.style then
        return false
    end
    if r_elapsed == nil or r_elapsed < 0 or r_elapsed >= RING_DURATION then
        clear_widget(nil, circle_widget)
        return false
    end

    local bold_style = circle_widget.style.circle_bold
    local thin_style = circle_widget.style.circle
    local bold_tex = _textures.circle_bold or _textures.circle_thin or _textures.circle
    local thin_tex = _textures.circle_thin or _textures.circle or _textures.circle_bold

    local t = clamp01(r_elapsed / RING_DURATION)
    local eased = 1 - (1 - t) ^ 3.2
    local ring_scale = RING_START_SCALE + (RING_END_SCALE - RING_START_SCALE) * eased
    local ring_size = ICON_SIZE * size_scale * ring_scale

    local envelope
    if r_elapsed < RING_PEAK_END then
        envelope = 0.65 + 0.30 * (r_elapsed / RING_PEAK_END)
    elseif r_elapsed < RING_HOLD_END then
        envelope = 0.95
    else
        local decay_t = clamp01((r_elapsed - RING_HOLD_END) / (RING_DURATION - RING_HOLD_END))
        envelope = 0.95 * ((1 - decay_t) ^ 1.7)
    end

    local target_alpha = clamp01(envelope * transparency_factor)
    if target_alpha <= 0 then
        clear_widget(nil, circle_widget)
        return false
    end

    -- Both bold and thin textures share the exact same outer radius (r_out = 239px in 512x512).
    -- Rendering them at the identical ring_scale while solving exact alpha-preservation cross-fade
    -- makes the inner body dissolve seamlessly behind the leading edge as one thinning shockwave.
    local drew_any = false
    if bold_tex and thin_tex and bold_tex ~= thin_tex then
        local u = clamp01(r_elapsed / RING_MORPH_DURATION)
        local morph = u * u * (3 - 2 * u)
        local bold_norm = target_alpha * (1 - morph)
        local thin_norm = morph > 0 and ((target_alpha - bold_norm) / math.max(0.001, 1 - bold_norm)) or 0

        if bold_style and bold_norm > 0.002 then
            set_pass_style(
                bold_style,
                bold_tex,
                255 * bold_norm,
                base_r, base_g, base_b,
                ring_size,
                ICON_ROOT_SIZE,
                0
            )
            drew_any = true
        else
            clear_pass_style(bold_style)
        end

        if thin_style and thin_norm > 0.002 then
            set_pass_style(
                thin_style,
                thin_tex,
                255 * thin_norm,
                base_r, base_g, base_b,
                ring_size,
                ICON_ROOT_SIZE,
                1
            )
            drew_any = true
        else
            clear_pass_style(thin_style)
        end
    else
        clear_pass_style(bold_style)
        if thin_style and thin_tex then
            set_pass_style(
                thin_style,
                thin_tex,
                255 * target_alpha,
                base_r, base_g, base_b,
                ring_size,
                ICON_ROOT_SIZE,
                1
            )
            drew_any = true
        else
            clear_pass_style(thin_style)
        end
    end

    return drew_any
end

local function resolve_slot_texture(slot, use_boss_icon)
    if use_boss_icon then
        return _textures.boss
    end
    return slot.is_headshot and _textures.headshot or _textures.normal
end

local function update_root_position(root, x, y)
    local pos = root.position
    if math.abs(pos[1] - x) > 0.01 or math.abs(pos[2] - y) > 0.01 then
        pos[1] = x
        pos[2] = y
        return true
    end
    return false
end

local function update_item(self, slot, index, now, step_dt, y_pos, settings, is_leaving)
    local icon_widget = self._widgets_by_name["kill_icon_" .. index]
    local circle_widget = self._widgets_by_name["circle_icon_" .. index]
    local root = self._ui_scenegraph["icon_root_" .. index]
    if not root then return false end

    local size_scale = settings.size_scale
    local transparency_factor = settings.transparency_factor
    local use_boss_icon = is_slot_boss_active(slot, settings.boss_icon_enabled)

    if is_leaving then
        if not update_leaving_slot_state(slot, now, size_scale) then
            clear_widget(icon_widget, circle_widget)
            return true
        end
        local r, g, b
        if use_boss_icon then
            r, g, b = settings.boss_r, settings.boss_g, settings.boss_b
        elseif slot.is_headshot then
            r, g, b = settings.headshot_r, settings.headshot_g, settings.headshot_b
        else
            r, g, b = settings.normal_r, settings.normal_g, settings.normal_b
        end
        set_pass_style(
            icon_widget and icon_widget.style and icon_widget.style.icon,
            resolve_slot_texture(slot, use_boss_icon),
            255 * slot.render_alpha * transparency_factor,
            r, g, b,
            ICON_SIZE * size_scale * slot.render_scale,
            ICON_ROOT_SIZE,
            0,
            slot.render_angle
        )
        clear_widget(nil, circle_widget)
        return update_root_position(root, slot.current_x, y_pos)
    end

    local elapsed = math.max(0, now - slot.start_time)
    local base_scale = default_slot_base_scale(slot, settings.boss_icon_enabled)
    local anim_scale, entry_alpha = compute_entry_state(slot, elapsed, use_boss_icon)
    local scale_multiplier = base_scale * anim_scale
    local alpha = entry_alpha

    -- Trigger dual-layer shockwave right as the icon slams into steady position.
    local needs_ring = slot.is_headshot or use_boss_icon
    if needs_ring and not slot.ripple_triggered then
        if anim_scale <= RIPPLE_TRIGGER_SCALE or elapsed >= RIPPLE_FORCE_START then
            slot.ripple_triggered = true
            slot.ripple_start_time = now
        end
    end

    if slot.fade_start_time and now >= slot.fade_start_time then
        if not slot.fade_captured then
            slot.fade_captured = true
            slot.fade_start_alpha = slot.render_alpha > 0 and slot.render_alpha or alpha
            slot.fade_start_scale = slot.render_scale > 0 and slot.render_scale or scale_multiplier
        end
        local fade_t = clamp01((now - slot.fade_start_time) / NATURAL_FADE_DURATION)
        if fade_t >= 1 then
            detach_slot_ripple(slot, now, y_pos, size_scale, settings.boss_icon_enabled)
            reset_slot(slot)
            clear_widget(icon_widget, circle_widget)
            return true
        end
        alpha = slot.fade_start_alpha * (1 - fade_t * fade_t)
        scale_multiplier = slot.fade_start_scale * (1 - 0.16 * fade_t)
    end

    if step_dt > 0 then
        local dx = slot.target_x - slot.current_x
        if math.abs(dx) > 0.05 then
            local move_alpha = 1 - math.exp(-HORIZONTAL_DAMP_SPEED * step_dt)
            slot.current_x = slot.current_x + dx * move_alpha
        else
            slot.current_x = slot.target_x
        end
    end

    local icon_angle = 0
    if use_boss_icon then
        local spin_t = clamp01(elapsed / BOSS_SPIN_DURATION)
        icon_angle = -math.rad(45 * (1 - (1 - spin_t) ^ 3))
    end

    slot.render_alpha = alpha
    slot.render_scale = scale_multiplier
    slot.render_angle = icon_angle

    local r, g, b = resolve_slot_color(slot, settings, use_boss_icon)
    set_pass_style(
        icon_widget and icon_widget.style and icon_widget.style.icon,
        resolve_slot_texture(slot, use_boss_icon),
        255 * alpha * transparency_factor,
        r, g, b,
        ICON_SIZE * size_scale * scale_multiplier,
        ICON_ROOT_SIZE,
        0,
        icon_angle
    )

    if needs_ring and slot.ripple_triggered and slot.ripple_start_time then
        local ring_r = use_boss_icon and settings.boss_r or settings.headshot_r
        local ring_g = use_boss_icon and settings.boss_g or settings.headshot_g
        local ring_b = use_boss_icon and settings.boss_b or settings.headshot_b
        render_dual_rings(
            circle_widget,
            now - slot.ripple_start_time,
            size_scale,
            transparency_factor,
            ring_r, ring_g, ring_b
        )
    else
        clear_widget(nil, circle_widget)
    end

    return update_root_position(root, slot.current_x, y_pos)
end

local function update_detached_ripples(self, now, settings)
    local scenegraph_dirty = false
    local transparency_factor = settings.transparency_factor
    for i = 1, MAX_DETACHED_RIPPLES do
        local ripple = manager._detached_ripples[i]
        local circle_widget = self._widgets_by_name["detached_circle_icon_" .. i]
        local root = self._ui_scenegraph["detached_circle_root_" .. i]
        if ripple.active then
            local r_elapsed = now - ripple.ripple_start_time
            if r_elapsed >= RING_DURATION then
                reset_detached_ripple(ripple)
                clear_widget(nil, circle_widget)
                scenegraph_dirty = true
            else
                local ring_r = ripple.is_boss and settings.boss_r or settings.headshot_r
                local ring_g = ripple.is_boss and settings.boss_g or settings.headshot_g
                local ring_b = ripple.is_boss and settings.boss_b or settings.headshot_b
                render_dual_rings(
                    circle_widget,
                    r_elapsed,
                    ripple.size_scale,
                    transparency_factor,
                    ring_r, ring_g, ring_b
                )
                if root and update_root_position(root, ripple.x, ripple.y) then
                    scenegraph_dirty = true
                end
            end
        elseif clear_widget(nil, circle_widget) then
            scenegraph_dirty = true
        end
    end
    return scenegraph_dirty
end

local function set_text_widget_state(widget, root, text, alpha, r, g, b, font_size, box_h, x, y)
    if not widget or not root then return false end
    local clamped_alpha = math.max(0, math.min(255, math.floor((tonumber(alpha) or 0) + 0.5)))
    if not text or text == "" or clamped_alpha <= 0 then
        return clear_text_widget(widget)
    end
    local changed = false
    if widget.content.text ~= text then
        widget.content.text = text
        changed = true
    end
    local style = widget.style.text
    if style.font_size ~= font_size then
        style.font_size = font_size
        changed = true
    end
    if style.size[2] ~= box_h then
        style.size[2] = box_h
        changed = true
    end
    local color = style.text_color
    color[1] = clamped_alpha
    color[2] = r
    color[3] = g
    color[4] = b
    if update_root_position(root, x, y) then
        changed = true
    end
    return changed
end

local function update_bf5_text(self, step_dt, now, y_pos, settings)
    local bf5_text = get_bf5_text()
    if not settings.text_enabled or not bf5_text then
        if bf5_text and bf5_text.is_active and bf5_text.is_active() then
            bf5_text.clear()
        end
        return clear_all_text_widgets(self)
    end

    if not settings.hit_score_enabled and bf5_text.clear_hit_hold then
        bf5_text.clear_hit_hold()
    end

    bf5_text.update(step_dt, now, settings.duration)

    if not bf5_text.is_active() then
        return clear_all_text_widgets(self)
    end

    local screen_width = UIWorkspaceSettings.screen.size[1]
    local screen_height = UIWorkspaceSettings.screen.size[2]
    local text_scale = settings.text_scale
    local transparency = settings.transparency_factor

    local raw_center_x = screen_width * settings.horizontal / 100
    local center_x = math.max(BF5_TEXT_MARGIN_X, math.min(screen_width - BF5_TEXT_MARGIN_X, raw_center_x))
    local box_x = center_x - BF5_TEXT_BOX_WIDTH * 0.5

    local icon_center_y = y_pos + ICON_ROOT_SIZE * 0.5
    local icon_bottom_y = icon_center_y + ICON_SIZE * settings.size_scale * 0.5 * 1.12

    local kill_font = math.max(10, math.floor(BF5_KILL_BASE_FONT * text_scale + 0.5))
    local total_font = math.max(18, math.floor(BF5_TOTAL_BASE_FONT * text_scale + 0.5))
    local bonus_font = math.max(9, math.floor(BF5_BONUS_BASE_FONT * text_scale + 0.5))

    local kill_h = math.ceil(kill_font * 1.28)
    local total_h = math.ceil(total_font * 1.16)
    local bonus_h = math.ceil(bonus_font * 1.28)
    local bonus_row_gap = math.max(20 * text_scale, bonus_font + 5 * text_scale)

    local kill_y = icon_bottom_y + 10 * text_scale
    local total_y = kill_y + kill_h + 4 * text_scale
    local bonus_y = total_y + total_h + 8 * text_scale

    local block_bottom = bonus_y + bonus_row_gap * (MAX_BF5_BONUS_LINES - 1) + bonus_h
    local max_bottom = screen_height - BF5_TEXT_BOTTOM_MARGIN
    if block_bottom > max_bottom then
        local shift_up = block_bottom - max_bottom
        kill_y = kill_y - shift_up
        total_y = total_y - shift_up
        bonus_y = bonus_y - shift_up
    end

    local dirty = false

    local kill_text, kill_alpha = bf5_text.get_kill_render(settings.duration)
    if set_text_widget_state(
        self._widgets_by_name.bf5_text_kill,
        self._ui_scenegraph.bf5_text_kill_root,
        kill_text,
        255 * kill_alpha * transparency,
        255, 255, 255,
        kill_font, kill_h,
        box_x, kill_y
    ) then
        dirty = true
    end

    local total_text, total_alpha = bf5_text.get_total_render()
    if set_text_widget_state(
        self._widgets_by_name.bf5_text_total,
        self._ui_scenegraph.bf5_text_total_root,
        total_text,
        255 * total_alpha * transparency,
        255, 255, 255,
        total_font, total_h,
        box_x, total_y
    ) then
        dirty = true
    end

    bf5_text.fill_bonus_render_slots(_bonus_texts, _bonus_slots, _bonus_alphas, _bonus_shifts)
    for i = 1, MAX_BF5_BONUS_LINES do
        local slot_y = bonus_y + (_bonus_slots[i] - 1) * bonus_row_gap + _bonus_shifts[i] * bonus_row_gap
        if set_text_widget_state(
            self._widgets_by_name["bf5_text_bonus_" .. i],
            self._ui_scenegraph["bf5_text_bonus_root_" .. i],
            _bonus_texts[i],
            255 * _bonus_alphas[i] * transparency,
            238, 244, 250,
            bonus_font, bonus_h,
            box_x, slot_y
        ) then
            dirty = true
        end
    end

    return dirty
end

local function trigger_fade_wave(now)
    local active, count = collect_sorted_active_slots()
    if count <= 0 then
        return
    end
    local wave_step = count > 8 and WAVE_STEP_DENSE or WAVE_STEP_NORMAL
    for rank = 1, count do
        local slot = active[rank]
        slot.fade_start_time = now + (rank - 1) * wave_step
        slot.fade_captured = false
    end
    manager._fade_wave_active = true
    manager._natural_fade_start = now
end

HudHitKillICON.update = function(self, dt, t, ui_renderer, render_settings, input_service)
    local step_dt = math.max(tonumber(dt) or 0, 0)
    local settings = refresh_settings_cache()
    local game_mode_name = Managers.state and Managers.state.game_mode
        and Managers.state.game_mode:game_mode_name()

    if not settings.enabled or settings.style ~= "BF5" or not settings.icon_enabled or game_mode_name == "hub" then
        if self._was_active or has_any_work(self._slots, self._leaving_slots) then
            manager.clear()
            clear_all_widgets(self)
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
        end
        return
    end

    if not has_any_work(self._slots, self._leaving_slots) then
        if self._was_active then
            clear_all_widgets(self)
            self._update_scenegraph = true
            self._was_active = false
            self._has_active_content = false
            HudHitKillICON.super.update(self, dt, t, ui_renderer, render_settings, input_service)
        end
        return
    end

    local scenegraph_dirty = _settings_force_layout or not self._was_active
    self._was_active = true
    local now = Managers.time:time("main")
    _settings_force_layout = false

    if drain_pending_queue(now, settings) then
        scenegraph_dirty = true
    end

    if manager._pending_count == 0 and manager._last_kill_time and not manager._fade_wave_active
        and now - manager._last_kill_time >= settings.duration then
        trigger_fade_wave(now)
    end

    local y_pos = compute_y_pos(settings)
    recompute_targets(settings)

    for i = 1, MAX_SLOTS do
        local slot = manager._slots[i]
        if slot.active then
            if update_item(self, slot, i, now, step_dt, y_pos, settings, false) then
                scenegraph_dirty = true
            end
        elseif clear_widget(self._widgets_by_name["kill_icon_" .. i], self._widgets_by_name["circle_icon_" .. i]) then
            scenegraph_dirty = true
        end
    end

    for i = 1, MAX_LEAVING_SLOTS do
        local slot = manager._leaving_slots[i]
        local index = MAX_SLOTS + i
        if slot.active then
            if update_item(self, slot, index, now, step_dt, y_pos, settings, true) then
                scenegraph_dirty = true
            end
        elseif clear_widget(
            self._widgets_by_name["kill_icon_" .. index],
            self._widgets_by_name["circle_icon_" .. index]
        ) then
            scenegraph_dirty = true
        end
    end

    if update_detached_ripples(self, now, settings) then
        scenegraph_dirty = true
    end

    if update_bf5_text(self, step_dt, now, y_pos, settings) then
        scenegraph_dirty = true
    end

    local any_visual = has_any_visual(self._slots, self._leaving_slots)
    self._has_active_content = any_visual

    if not any_visual and manager._pending_count == 0 then
        manager._natural_fade_start = nil
        manager._fade_wave_active = false
        manager._last_kill_time = nil
    else
        local any_primary = false
        for i = 1, MAX_SLOTS do
            if manager._slots[i].active then
                any_primary = true
                break
            end
        end
        if not any_primary then
            manager._fade_wave_active = false
            manager._natural_fade_start = nil
        end
    end

    if scenegraph_dirty then
        self._update_scenegraph = true
    end
    HudHitKillICON.super.update(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillICON.draw = function(self, dt, t, ui_renderer, render_settings, input_service)
    if not self._has_active_content or not has_any_visual(self._slots, self._leaving_slots) then
        return
    end
    local settings = _settings_cache
    if not settings.enabled or settings.style ~= "BF5" or not settings.icon_enabled then
        return
    end
    local game_mode_name = Managers.state.game_mode and Managers.state.game_mode:game_mode_name()
    if game_mode_name == "hub" then
        return
    end
    HudHitKillICON.super.draw(self, dt, t, ui_renderer, render_settings, input_service)
end

HudHitKillICON.destroy = function(self, ui_renderer)
    manager.clear()
    clear_all_widgets(self)
    self._was_active = false
    self._has_active_content = false
    HudHitKillICON.super.destroy(self, ui_renderer)
end

return HudHitKillICON
