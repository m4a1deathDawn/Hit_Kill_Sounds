-- luacheck: globals get_mod Managers
local HKS = get_mod("Hit_Kill_Sounds")

local table_clear = table.clear or function(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

local MAX_ENTRIES = 8
local BASE_FONT_SIZE = 22
local BASE_LINE_HEIGHT = 34
local MIN_TEXT_SCALE = 0.5
local MAX_TEXT_SCALE = 1.5
local TYPEWRITER_CHARS_PER_SECOND = 32
local BATCH_STAGGER_INTERVAL = 0.07
local FADE_IN_TIME = 0.10
local ENTRY_FADE_OUT_TIME = 0.22
local IDLE_FADE_STAGGER = 0.10
local TALLY_FADE_TIME = 0.30
local TALLY_PUNCH_UP_TIME = 0.08
local TALLY_PUNCH_DOWN_TIME = 0.14
local TALLY_PUNCH_TOTAL = TALLY_PUNCH_UP_TIME + TALLY_PUNCH_DOWN_TIME
local TALLY_PUNCH_PEAK = 1.24
local TALLY_ROLL_TIME = 0.16
local DEPTH_FADE_START = 3.5
local DEPTH_FADE_END = 5.8

local KILL_MAIN_EVENTS = {
    bf4_feed_enemy_killed = true,
    bf4_feed_elite_killed = true,
    bf4_feed_special_killed = true,
    bf4_feed_boss_killed = true,
}

local EVENT_COLORS = {
    bf4_feed_enemy_killed = {255, 224, 238, 250},
    bf4_feed_headshot_bonus = {255, 255, 228, 96},
    bf4_feed_elite_killed = {255, 255, 210, 75},
    bf4_feed_special_killed = {255, 255, 150, 45},
    bf4_feed_boss_killed = {255, 255, 86, 78},
    bf4_feed_multikill_bonus = {255, 255, 168, 42},
}

local SCORE_BY_EVENT = {
    bf4_feed_enemy_killed = 100,
    bf4_feed_headshot_bonus = 50,
    bf4_feed_elite_killed = 200,
    bf4_feed_special_killed = 250,
    bf4_feed_boss_killed = 500,
    -- The actual amount is supplied by add_kill; this value only marks the key valid.
    bf4_feed_multikill_bonus = 10,
}

local ScoreFeed = {
    _entries = {},
    _batches = {},
    _next_batch_id = 0,
    _line_height = BASE_LINE_HEIGHT,
    _last_activity_time = 0,
    _next_idle_fade_time = 0,
    _tally = {
        accumulated_total_score = 0,
        displayed_total_score = 0,
        displayed_score = 0,
        roll_start_score = 0,
        scale_multiplier = 1,
        alpha = 0,
        fade_state = "hidden",
        scale_elapsed = TALLY_PUNCH_TOTAL,
        roll_elapsed = TALLY_ROLL_TIME,
        fade_elapsed = 0,
        y_offset = 0,
    },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function positive_dt(dt)
    return math.max(tonumber(dt) or 0, 0)
end

local function get_text_scale()
    local stored_scale = tonumber(HKS:get("bf4_feed_text_scale")) or 100

    return clamp(stored_scale / 100, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
end

local function get_direction()
    return HKS:get("bf4_feed_direction") == "bottom_up" and "bottom_up" or "top_down"
end

local function calculate_line_height()
    local font_size = math.floor(BASE_FONT_SIZE * get_text_scale())

    return math.max(1, math.floor(font_size * BASE_LINE_HEIGHT / BASE_FONT_SIZE + 0.5))
end

local function now_time()
    if Managers and Managers.time then
        return Managers.time:time("main")
    end

    return os.clock()
end

local function is_feed_enabled()
    return HKS:get("enabled") ~= false and HKS:get("bf4_feed_enabled") == true
end

local function get_feed_duration()
    local stored_duration = tonumber(HKS:get("bf4_feed_duration")) or 30

    return clamp(stored_duration / 10, 1, 3)
end

local function copy_color(color)
    return {color[1], color[2], color[3], color[4]}
end

local function reset_tally(tally)
    tally.accumulated_total_score = 0
    tally.displayed_total_score = 0
    tally.displayed_score = 0
    tally.roll_start_score = 0
    tally.scale_multiplier = 1
    tally.alpha = 0
    tally.fade_state = "hidden"
    tally.scale_elapsed = TALLY_PUNCH_TOTAL
    tally.roll_elapsed = TALLY_ROLL_TIME
    tally.fade_elapsed = 0
    tally.y_offset = 0
end

local function trigger_tally_roll(tally, batch_score)
    tally = tally or ScoreFeed._tally
    if tally.fade_state == "hidden" or tally.alpha <= 0 then
        tally.displayed_total_score = 0
        tally.displayed_score = 0
        tally.roll_start_score = 0
    else
        local current_displayed = tally.displayed_total_score
        if tally.displayed_score ~= nil and tally.displayed_score ~= current_displayed then
            current_displayed = tally.displayed_score
            tally.displayed_total_score = current_displayed
        end
        tally.roll_start_score = current_displayed or 0
    end

    if batch_score ~= nil then
        tally.accumulated_total_score = (tally.accumulated_total_score or 0) + (tonumber(batch_score) or 0)
    end
    tally.scale_multiplier = 1
    tally.scale_elapsed = 0
    tally.roll_elapsed = 0
    tally.fade_state = "visible"
    tally.fade_elapsed = 0
    tally.alpha = 1
    tally.y_offset = 0
end

local function start_tally_fade(tally)
    if tally.fade_state == "fading" or tally.fade_state == "hidden" then
        return
    end

    tally.fade_state = "fading"
    tally.fade_elapsed = 0
    tally.y_offset = 0
end

local function event_color(event_key)
    return copy_color(EVENT_COLORS[event_key] or EVENT_COLORS.bf4_feed_enemy_killed)
end

local function refresh_visible_targets(current_time)
    current_time = tonumber(current_time) or now_time()
    local line_height = ScoreFeed._line_height
    local direction = get_direction()
    local visible_list = {}

    for _, entry in ipairs(ScoreFeed._entries) do
        if current_time >= (entry.reveal_at or 0) then
            visible_list[#visible_list + 1] = entry
        else
            entry.visible_slot_index = nil
        end
    end

    local visible_count = #visible_list
    if direction == "top_down" then
        for idx, entry in ipairs(visible_list) do
            local target_y = (idx - 1) * line_height
            entry.visible_slot_index = idx
            entry.target_y = target_y
            if not entry._revealed then
                entry.current_y = target_y - 0.40 * line_height
                entry._revealed = true
            end
        end
    else
        for idx, entry in ipairs(visible_list) do
            local visible_slot_index = visible_count - idx + 1
            local target_y = -(visible_slot_index - 1) * line_height
            entry.visible_slot_index = visible_slot_index
            entry.target_y = target_y
            if not entry._revealed then
                entry.current_y = target_y + 0.35 * line_height
                entry._revealed = true
            end
        end
    end
end

local function sync_line_height()
    local line_height = calculate_line_height()

    if line_height == ScoreFeed._line_height then
        return
    end

    ScoreFeed._line_height = line_height
    refresh_visible_targets(now_time())
end

local function rebuild_entries_from_batches(current_time)
    table_clear(ScoreFeed._entries)
    local direction = get_direction()

    if direction == "top_down" then
        -- Newest batch at top (Slot 1), preserving kill main -> bonuses inside each batch.
        for b = #ScoreFeed._batches, 1, -1 do
            local batch = ScoreFeed._batches[b]
            for _, entry in ipairs(batch.entries) do
                ScoreFeed._entries[#ScoreFeed._entries + 1] = entry
            end
        end
    else
        for _, batch in ipairs(ScoreFeed._batches) do
            for _, entry in ipairs(batch.entries) do
                ScoreFeed._entries[#ScoreFeed._entries + 1] = entry
            end
        end
    end

    refresh_visible_targets(current_time or now_time())
end

local function remove_entry_from_batches(target_entry)
    for b = #ScoreFeed._batches, 1, -1 do
        local entries = ScoreFeed._batches[b].entries
        for e = #entries, 1, -1 do
            if entries[e] == target_entry then
                table.remove(entries, e)
                break
            end
        end
        if #entries == 0 then
            table.remove(ScoreFeed._batches, b)
        end
    end
end

local function drop_old_batches_for_capacity()
    local entry_count = 0
    for _, batch in ipairs(ScoreFeed._batches) do
        entry_count = entry_count + #batch.entries
    end

    while entry_count > MAX_ENTRIES and #ScoreFeed._batches > 0 do
        local removed = table.remove(ScoreFeed._batches, 1)
        entry_count = entry_count - #removed.entries
    end
end

function ScoreFeed.clear()
    table_clear(ScoreFeed._entries)
    table_clear(ScoreFeed._batches)
    ScoreFeed._last_activity_time = 0
    ScoreFeed._next_idle_fade_time = 0
    reset_tally(ScoreFeed._tally)
end

function ScoreFeed.is_enabled()
    return is_feed_enabled()
end

function ScoreFeed.get_direction()
    return get_direction()
end

function ScoreFeed.add_batch(batch)
    if not is_feed_enabled() or type(batch) ~= "table" then
        return false
    end

    local normalized_batch = {}
    local batch_score = 0

    for _, request in ipairs(batch) do
        if type(request) == "table" and type(request.event_key) == "string" and SCORE_BY_EVENT[request.event_key] then
            local score = tonumber(request.score) or SCORE_BY_EVENT[request.event_key]

            normalized_batch[#normalized_batch + 1] = {
                event_key = request.event_key,
                score = score,
                color = request.color,
                is_kill_main = request.is_kill_main == true or KILL_MAIN_EVENTS[request.event_key] == true,
                victim_name = request.victim_name,
                weapon_name = request.weapon_name,
                enemy_tier = request.enemy_tier,
            }
            batch_score = batch_score + score
        end
    end

    if #normalized_batch == 0 then
        return false
    end

    local created_at = now_time()
    ScoreFeed._next_batch_id = ScoreFeed._next_batch_id + 1
    local batch_record = {
        batch_id = ScoreFeed._next_batch_id,
        created_at = created_at,
        expires_at = created_at + get_feed_duration(),
        entries = {},
    }

    for index, request in ipairs(normalized_batch) do
        batch_record.entries[index] = {
            batch_id = batch_record.batch_id,
            batch_index = index,
            event_key = request.event_key,
            score = request.score,
            color = request.color and copy_color(request.color) or event_color(request.event_key),
            is_kill_main = request.is_kill_main,
            victim_name = request.victim_name,
            weapon_name = request.weapon_name,
            enemy_tier = request.enemy_tier,
            spawn_time = created_at,
            reveal_at = created_at + math.min(index - 1, 2) * BATCH_STAGGER_INTERVAL,
            reveal_elapsed = 0,
            current_y = 0,
            target_y = 0,
            fade_y_offset = 0,
            fade_start_time = nil,
            alpha = 0,
            _revealed = false,
            visible_slot_index = nil,
        }
    end

    ScoreFeed._batches[#ScoreFeed._batches + 1] = batch_record
    drop_old_batches_for_capacity()
    sync_line_height()
    rebuild_entries_from_batches(created_at)

    ScoreFeed._last_activity_time = created_at
    ScoreFeed._next_idle_fade_time = created_at + get_feed_duration()
    trigger_tally_roll(ScoreFeed._tally, batch_score)

    return true
end

function ScoreFeed.add_kill(breed, is_headshot, streak_count, extra_context)
    local event_key
    local enemy_tier = "normal"
    local tags = breed and breed.tags or {}
    local is_boss = breed and (breed.is_boss == true or breed.boss == true or
        tags.monster == true or tags.captain == true)
    local is_special = breed and (breed.special == true or tags.special == true)
    local is_elite = breed and (breed.elite == true or tags.elite == true)

    if is_boss then
        event_key = "bf4_feed_boss_killed"
        enemy_tier = "boss"
    elseif is_special then
        event_key = "bf4_feed_special_killed"
        enemy_tier = "special"
    elseif is_elite then
        event_key = "bf4_feed_elite_killed"
        enemy_tier = "elite"
    else
        event_key = "bf4_feed_enemy_killed"
    end

    local victim_name = type(extra_context) == "table" and extra_context.victim_name or nil
    local weapon_name = type(extra_context) == "table" and extra_context.weapon_name or nil

    local batch = {
        {
            event_key = event_key,
            score = SCORE_BY_EVENT[event_key],
            is_kill_main = true,
            victim_name = victim_name,
            weapon_name = weapon_name,
            enemy_tier = enemy_tier,
        },
    }

    if is_headshot then
        batch[#batch + 1] = {
            event_key = "bf4_feed_headshot_bonus",
            score = SCORE_BY_EVENT.bf4_feed_headshot_bonus,
            is_kill_main = false,
        }
    end

    if tonumber(streak_count) and streak_count >= 2 then
        batch[#batch + 1] = {
            event_key = "bf4_feed_multikill_bonus",
            score = math.min(100, math.floor(streak_count * 10)),
            is_kill_main = false,
        }
    end

    return ScoreFeed.add_batch(batch)
end

local function trigger_next_idle_fade(current_time)
    if #ScoreFeed._entries == 0 or ScoreFeed._next_idle_fade_time <= 0 or
        current_time < ScoreFeed._next_idle_fade_time then
        return
    end

    local direction = get_direction()
    local target_entry = nil
    if direction == "top_down" then
        -- Bottom-most (oldest) non-fading row fades first.
        for i = #ScoreFeed._entries, 1, -1 do
            local entry = ScoreFeed._entries[i]
            if not entry.fade_start_time then
                target_entry = entry
                break
            end
        end
    else
        for i = 1, #ScoreFeed._entries do
            local entry = ScoreFeed._entries[i]
            if not entry.fade_start_time then
                target_entry = entry
                break
            end
        end
    end

    if target_entry then
        target_entry.fade_start_time = current_time
        ScoreFeed._next_idle_fade_time = current_time + IDLE_FADE_STAGGER
    end
end

local function update_entries(step_dt, current_time)
    refresh_visible_targets(current_time)
    trigger_next_idle_fade(current_time)

    local duration = get_feed_duration()
    local line_height = math.max(ScoreFeed._line_height, 1)
    local direction = get_direction()
    local scale = get_text_scale()
    local drift_sign = direction == "top_down" and 1 or -1
    local removed_any = false

    for index = #ScoreFeed._entries, 1, -1 do
        local entry = ScoreFeed._entries[index]
        local age = current_time - entry.spawn_time

        if not entry.fade_start_time and age >= duration + 0.8 then
            entry.fade_start_time = current_time
        end

        if current_time < entry.reveal_at then
            entry.reveal_elapsed = 0
            entry.alpha = 0
        else
            entry.reveal_elapsed = current_time - entry.reveal_at
            local move_alpha = 1 - math.exp(-20 * step_dt)
            entry.current_y = entry.current_y + (entry.target_y - entry.current_y) * move_alpha

            local in_alpha = entry.reveal_elapsed < FADE_IN_TIME
                and clamp(entry.reveal_elapsed / FADE_IN_TIME, 0, 1) or 1

            local line_pos = math.abs(entry.current_y) / line_height
            local pos_alpha = 1
            if line_pos > DEPTH_FADE_START then
                pos_alpha = clamp(
                    1 - (line_pos - DEPTH_FADE_START) / (DEPTH_FADE_END - DEPTH_FADE_START),
                    0,
                    1
                )
            end

            local fade_alpha = 1
            local expired = false
            if entry.fade_start_time then
                local fade_t = clamp((current_time - entry.fade_start_time) / ENTRY_FADE_OUT_TIME, 0, 1)
                fade_alpha = 1 - fade_t * fade_t
                entry.fade_y_offset = 6 * scale * drift_sign * fade_t
                if fade_t >= 1 then
                    expired = true
                end
            else
                entry.fade_y_offset = 0
            end

            if line_pos >= DEPTH_FADE_END and entry._revealed then
                expired = true
            end

            if expired then
                remove_entry_from_batches(entry)
                table.remove(ScoreFeed._entries, index)
                removed_any = true
            else
                entry.alpha = in_alpha * pos_alpha * fade_alpha
            end
        end
    end

    if removed_any then
        refresh_visible_targets(current_time)
    end
end

local function update_tally(step_dt, current_time)
    local tally = ScoreFeed._tally

    if tally.fade_state == "visible" then
        tally.scale_elapsed = math.min(tally.scale_elapsed + step_dt, TALLY_PUNCH_TOTAL)
        if tally.scale_elapsed < TALLY_PUNCH_UP_TIME then
            local up_t = clamp(tally.scale_elapsed / TALLY_PUNCH_UP_TIME, 0, 1)
            local eased_up = 1 - (1 - up_t) ^ 3
            tally.scale_multiplier = 1 + (TALLY_PUNCH_PEAK - 1) * eased_up
        else
            local down_t = clamp((tally.scale_elapsed - TALLY_PUNCH_UP_TIME) / TALLY_PUNCH_DOWN_TIME, 0, 1)
            local eased_down = 1 - (1 - down_t) ^ 3
            tally.scale_multiplier = TALLY_PUNCH_PEAK - (TALLY_PUNCH_PEAK - 1) * eased_down
        end

        tally.roll_elapsed = math.min(tally.roll_elapsed + step_dt, TALLY_ROLL_TIME)
        local roll_progress = clamp(tally.roll_elapsed / TALLY_ROLL_TIME, 0, 1)
        local eased = 1 - (1 - roll_progress) ^ 3
        local start_score = tally.roll_start_score or 0
        tally.displayed_total_score = math.floor(start_score +
            (tally.accumulated_total_score - start_score) * eased + 0.5)
        if roll_progress >= 1 then
            tally.displayed_total_score = tally.accumulated_total_score
        end
        tally.displayed_score = tally.displayed_total_score

        local all_fading = true
        for i = 1, #ScoreFeed._entries do
            if not ScoreFeed._entries[i].fade_start_time then
                all_fading = false
                break
            end
        end

        local hold_timeout = get_feed_duration() + 1.2
        if ScoreFeed._last_activity_time > 0 and
            (#ScoreFeed._entries == 0 or all_fading or
                current_time - ScoreFeed._last_activity_time >= hold_timeout) then
            start_tally_fade(tally)
        end
    elseif tally.fade_state == "fading" then
        tally.fade_elapsed = tally.fade_elapsed + step_dt

        local fade_progress = clamp(tally.fade_elapsed / TALLY_FADE_TIME, 0, 1)

        tally.alpha = 1 - fade_progress * fade_progress
        tally.y_offset = -16 * fade_progress

        if fade_progress >= 1 then
            reset_tally(tally)
        end
    end
end

function ScoreFeed.update(dt)
    sync_line_height()
    local step_dt = positive_dt(dt)

    if not is_feed_enabled() then
        if #ScoreFeed._entries > 0 or ScoreFeed._tally.fade_state ~= "hidden" then
            ScoreFeed.clear()
        end

        return
    end

    local current_time = now_time()

    if step_dt <= 0 then
        return
    end

    update_entries(step_dt, current_time)
    update_tally(step_dt, current_time)
end

ScoreFeed.refresh_visible_targets = refresh_visible_targets
ScoreFeed.trigger_tally_roll = trigger_tally_roll

function ScoreFeed.get_entries()
    return ScoreFeed._entries
end

function ScoreFeed.get_batches()
    return ScoreFeed._batches
end

function ScoreFeed.get_tally()
    return ScoreFeed._tally
end

function ScoreFeed.get_line_height()
    sync_line_height()

    return ScoreFeed._line_height
end

function ScoreFeed.get_typewriter_speed()
    return TYPEWRITER_CHARS_PER_SECOND
end

function ScoreFeed.get_event_score(event_key)
    return SCORE_BY_EVENT[event_key]
end

HKS.HitKillSoundsScoreFeed = ScoreFeed
HKS.HitKillSoundsScoreTallyState = ScoreFeed._tally

return ScoreFeed
