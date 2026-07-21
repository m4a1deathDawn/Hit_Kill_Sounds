-- luacheck: globals get_mod Managers
local HKS = get_mod("Hit_Kill_Sounds")

local MAX_ENTRIES = 8
local BASE_FONT_SIZE = 22
local BASE_LINE_HEIGHT = 34
local MIN_TEXT_SCALE = 0.5
local MAX_TEXT_SCALE = 1.5
local TYPEWRITER_CHARS_PER_SECOND = 28
local FADE_IN_TIME = 0.15
local TALLY_FADE_TIME = 0.3
local TALLY_PUNCH_TIME = 0.2

local EVENT_COLORS = {
    bf4_feed_enemy_killed = {255, 255, 255, 255},
    bf4_feed_headshot_bonus = {255, 255, 225, 90},
    bf4_feed_elite_killed = {255, 255, 205, 70},
    bf4_feed_special_killed = {255, 255, 145, 35},
    bf4_feed_boss_killed = {255, 255, 70, 70},
}

local SCORE_BY_EVENT = {
    bf4_feed_enemy_killed = 100,
    bf4_feed_headshot_bonus = 50,
    bf4_feed_elite_killed = 200,
    bf4_feed_special_killed = 250,
    bf4_feed_boss_killed = 500,
}

local ScoreFeed = {
    _entries = {},
    _line_height = BASE_LINE_HEIGHT,
    _last_activity_time = 0,
    _tally = {
        accumulated_total_score = 0,
        displayed_total_score = 0,
        scale_multiplier = 1,
        alpha = 0,
        fade_state = "hidden",
        scale_elapsed = TALLY_PUNCH_TIME,
        fade_elapsed = 0,
        y_offset = 0,
    },
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function get_text_scale()
    local stored_scale = tonumber(HKS:get("bf4_feed_text_scale")) or 100

    return clamp(stored_scale / 100, MIN_TEXT_SCALE, MAX_TEXT_SCALE)
end

local function calculate_line_height()
    local font_size = math.floor(BASE_FONT_SIZE * get_text_scale())

    return math.max(1, math.floor(font_size * BASE_LINE_HEIGHT / BASE_FONT_SIZE + 0.5))
end

local function sync_line_height()
    local line_height = calculate_line_height()

    if line_height == ScoreFeed._line_height then
        return
    end

    local entry_count = #ScoreFeed._entries

    for index, entry in ipairs(ScoreFeed._entries) do
        entry.target_y = -(entry_count - index) * line_height
    end

    ScoreFeed._line_height = line_height
end

local function now_time()
    if Managers and Managers.time then
        return Managers.time:time("main")
    end

    return os.clock()
end

local function is_feed_enabled()
    return HKS:get("enabled") ~= false and HKS:get("bf4_feed_enabled") == true and
        HKS:get("killstreak_enabled") ~= false
end

local function get_feed_duration()
    local stored_duration = tonumber(HKS:get("bf4_feed_duration")) or 30

    return clamp(stored_duration / 10, 1, 3)
end

local function get_reset_time()
    local stored_reset_time = tonumber(HKS:get("cf_killstreak_reset_time")) or 20

    return stored_reset_time / 10
end

local function copy_color(color)
    return {
        color[1],
        color[2],
        color[3],
        color[4],
    }
end

local function reset_tally(tally)
    tally.accumulated_total_score = 0
    tally.displayed_total_score = 0
    tally.scale_multiplier = 1
    tally.alpha = 0
    tally.fade_state = "hidden"
    tally.scale_elapsed = TALLY_PUNCH_TIME
    tally.fade_elapsed = 0
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

local function get_tally_activity_time()
    -- BF4 tally lifetime is owned by the most recent valid BF4 text batch.
    -- Do not let a kill accepted by another output target extend this feed.
    return ScoreFeed._last_activity_time
end

local function event_color(event_key)
    return copy_color(EVENT_COLORS[event_key] or EVENT_COLORS.bf4_feed_enemy_killed)
end

local function insert_batch_entries(batch, created_at)
    local batch_count = #batch
    local line_height = ScoreFeed._line_height

    for _, entry in ipairs(ScoreFeed._entries) do
        entry.target_y = entry.target_y - batch_count * line_height
    end

    for index, request in ipairs(batch) do
        local event_key = request.event_key
        local score = tonumber(request.score)

        if type(event_key) == "string" and SCORE_BY_EVENT[event_key] and score then
            local target_y = -(batch_count - index) * line_height
            local entry = {
                event_key = event_key,
                score = score,
                color = request.color and copy_color(request.color) or event_color(event_key),
                spawn_time = created_at,
                reveal_elapsed = 0,
                current_y = target_y,
                target_y = target_y,
                alpha = 0,
            }

            ScoreFeed._entries[#ScoreFeed._entries + 1] = entry
        end
    end

    while #ScoreFeed._entries > MAX_ENTRIES do
        table.remove(ScoreFeed._entries, 1)
    end
end

function ScoreFeed.clear()
    table.clear(ScoreFeed._entries)
    ScoreFeed._last_activity_time = 0
    reset_tally(ScoreFeed._tally)
end

function ScoreFeed.is_enabled()
    return is_feed_enabled()
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
            }
            batch_score = batch_score + score
        end
    end

    if #normalized_batch == 0 then
        return false
    end

    local created_at = now_time()
    local tally = ScoreFeed._tally

    sync_line_height()
    insert_batch_entries(normalized_batch, created_at)

    ScoreFeed._last_activity_time = created_at
    tally.accumulated_total_score = tally.accumulated_total_score + batch_score
    tally.displayed_total_score = tally.accumulated_total_score
    tally.scale_multiplier = 1.3
    tally.scale_elapsed = 0
    tally.fade_state = "visible"
    tally.fade_elapsed = 0
    tally.alpha = 1
    tally.y_offset = 0

    return true
end

function ScoreFeed.add_kill(breed, is_headshot)
    local event_key
    local tags = breed and breed.tags or {}
    local is_boss = breed and (breed.is_boss == true or breed.boss == true)
    local is_special = breed and (breed.special == true or tags.special == true)
    local is_elite = breed and (breed.elite == true or tags.elite == true)

    if is_boss then
        event_key = "bf4_feed_boss_killed"
    elseif is_special then
        event_key = "bf4_feed_special_killed"
    elseif is_elite then
        event_key = "bf4_feed_elite_killed"
    else
        event_key = "bf4_feed_enemy_killed"
    end

    local batch = {}

    if is_headshot then
        batch[#batch + 1] = {
            event_key = "bf4_feed_headshot_bonus",
            score = SCORE_BY_EVENT.bf4_feed_headshot_bonus,
        }
    end

    batch[#batch + 1] = {
        event_key = event_key,
        score = SCORE_BY_EVENT[event_key],
    }

    return ScoreFeed.add_batch(batch)
end

local function update_entries(dt, current_time)
    local duration = get_feed_duration()
    local fade_out_time = math.min(0.5, duration * 0.35)
    local hold_end = duration - fade_out_time

    for index = #ScoreFeed._entries, 1, -1 do
        local entry = ScoreFeed._entries[index]
        local age = current_time - entry.spawn_time

        if age >= duration then
            table.remove(ScoreFeed._entries, index)
        else
            local move_alpha = math.min(dt * 12, 1)

            entry.reveal_elapsed = (entry.reveal_elapsed or 0) + dt
            entry.current_y = entry.current_y + (entry.target_y - entry.current_y) * move_alpha

            if age < FADE_IN_TIME then
                entry.alpha = clamp(age / FADE_IN_TIME, 0, 1)
            elseif age >= hold_end then
                entry.alpha = clamp((duration - age) / fade_out_time, 0, 1)
            else
                entry.alpha = 1
            end
        end
    end
end

local function update_tally(dt, current_time)
    local tally = ScoreFeed._tally

    if tally.fade_state == "visible" then
        tally.scale_elapsed = math.min(tally.scale_elapsed + dt, TALLY_PUNCH_TIME)
        local punch_progress = clamp(tally.scale_elapsed / TALLY_PUNCH_TIME, 0, 1)

        tally.scale_multiplier = 1.3 - 0.3 * punch_progress

        local activity_time = get_tally_activity_time()

        if activity_time > 0 and current_time - activity_time >= get_reset_time() then
            start_tally_fade(tally)
        end
    elseif tally.fade_state == "fading" then
        tally.fade_elapsed = tally.fade_elapsed + dt

        local fade_progress = clamp(tally.fade_elapsed / TALLY_FADE_TIME, 0, 1)

        tally.alpha = 1 - fade_progress
        tally.y_offset = -20 * fade_progress

        if fade_progress >= 1 then
            reset_tally(tally)
        end
    end
end

function ScoreFeed.update(dt)
    sync_line_height()

    if not is_feed_enabled() then
        if #ScoreFeed._entries > 0 or ScoreFeed._tally.fade_state ~= "hidden" then
            ScoreFeed.clear()
        end

        return
    end

    local current_time = now_time()

    update_entries(dt, current_time)
    update_tally(dt, current_time)
end

function ScoreFeed.get_entries()
    return ScoreFeed._entries
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
