-- luacheck: globals get_mod Managers Utf8
local HKS = get_mod("Hit_Kill_Sounds")

local MAX_KILL_QUEUE = 16
local MAX_BONUS_QUEUE = 32
local MAX_BONUS_LINES = 3
local MAX_WEAPON_CHARS = 24

local KILL_FADE_IN_DURATION = 0.08
local KILL_FADE_OUT_DURATION = 0.18
local COMBO_WINDOW = 5.0
local BONUS_STAGGER_INTERVAL = 0.18
local BONUS_QUIET_HOLD = 2.0
local BONUS_EXIT_DURATION = 0.45
local BONUS_SLIDE_SPEED = 18
local HIT_HOLD_TIMEOUT = 1.5
local TOTAL_QUIET_HOLD = 0.35
local TOTAL_FADE_DURATION = 0.45

local BF5Text = {
    _kill_queue = {},
    _current_kill = nil,
    _bonus_queue = {},
    _bonus_lines = {},
    _bonus_cooldown = 0,
    _bonus_idle = 0,
    _hit_hold = nil,
    _hit_remainder = 0,
    _unit_hit_credits = setmetatable({}, {__mode = "k"}),
    _combo = 0,
    _last_kill_time = nil,
    _total_target = 0,
    _total_display = 0,
    _total_alpha = 0,
    _total_idle_elapsed = 0,
    _cached_total_int = -1,
    _cached_total_text = "",
}

local function clamp01(value)
    if value <= 0 then
        return 0
    elseif value >= 1 then
        return 1
    end
    return value
end

local function now_time()
    if Managers and Managers.time and Managers.time.time then
        return Managers.time:time("main")
    end
    return os.clock()
end

local function localize_safe(key, fallback)
    if HKS and HKS.localize then
        local ok, text = pcall(HKS.localize, HKS, key)
        if ok and type(text) == "string" and text ~= "" and text ~= key and text ~= ("<" .. key .. ">") then
            return text
        end
    end
    return fallback
end

local function clean_label(value)
    if type(value) ~= "string" then
        return ""
    end
    local cleaned = value:gsub("[%c]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned
end

local function truncate_utf8(text, max_chars)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    if Utf8 and Utf8.string_length and Utf8.sub_string then
        local len = Utf8.string_length(text)
        if len <= max_chars then
            return text
        end
        if max_chars <= 3 then
            return Utf8.sub_string(text, 1, math.max(1, max_chars))
        end
        return Utf8.sub_string(text, 1, max_chars - 3) .. "..."
    end
    if #text <= max_chars then
        return text
    end
    return text:sub(1, math.max(1, max_chars - 3)) .. "..."
end

local function format_score_number(int_value)
    local raw = tostring(math.max(0, int_value))
    local out = ""
    while #raw > 3 do
        out = "," .. raw:sub(-3) .. out
        raw = raw:sub(1, #raw - 3)
    end
    return raw .. out
end

local function get_formatted_total_text(display_value)
    local int_val = math.max(0, math.floor((tonumber(display_value) or 0) + 0.5))
    if int_val ~= BF5Text._cached_total_int then
        BF5Text._cached_total_int = int_val
        BF5Text._cached_total_text = format_score_number(int_val)
    end
    return BF5Text._cached_total_text
end

local function is_known_weapon(weapon_name)
    local cleaned = clean_label(weapon_name)
    if cleaned == "" then
        return false, ""
    end
    local unknown_label = localize_safe("bf1_weapon_unknown", "Unknown")
    if cleaned == unknown_label or cleaned == "Unknown" or cleaned == "未知武器" or cleaned == "未知" then
        return false, ""
    end
    return true, truncate_utf8(cleaned, MAX_WEAPON_CHARS)
end

local function build_kill_line_text(victim_name, weapon_name, base_score)
    local enemy = clean_label(victim_name)
    if enemy == "" then
        enemy = localize_safe("bf5_enemy_fallback", "Enemy")
    end
    local score_str = tostring(math.max(0, math.floor(tonumber(base_score) or 100)))
    local known, weapon = is_known_weapon(weapon_name)
    if known then
        return enemy .. " [" .. weapon .. "] +" .. score_str
    end
    return enemy .. " +" .. score_str
end

local function resolve_combo_bonus(combo)
    if combo == 2 then
        return localize_safe("bf5_double_kill", "DOUBLE KILL"), 20
    elseif combo == 3 then
        return localize_safe("bf5_triple_kill", "TRIPLE KILL"), 30
    elseif combo == 4 then
        return localize_safe("bf5_quad_kill", "QUAD KILL"), 40
    elseif combo == 5 then
        return localize_safe("bf5_five_kill", "FIVE KILL"), 50
    elseif combo > 5 then
        return localize_safe("bf5_multi_kill", "MULTI KILL"), 50
    end
    return nil, nil
end

local function add_points(points)
    points = math.max(0, math.floor((tonumber(points) or 0) + 0.5))
    if points <= 0 then
        return
    end
    BF5Text._total_target = BF5Text._total_target + points
    BF5Text._total_idle_elapsed = 0
    BF5Text._total_alpha = 1
end

local function push_kill_bounded(entry)
    local queue = BF5Text._kill_queue
    if #queue < MAX_KILL_QUEUE then
        queue[#queue + 1] = entry
        return
    end

    local victim_index = nil
    local lowest_priority = math.huge
    for i = 1, #queue do
        local item = queue[i]
        if item.priority < lowest_priority then
            lowest_priority = item.priority
            victim_index = i
        end
    end

    if not victim_index or lowest_priority > entry.priority then
        return
    end

    table.remove(queue, victim_index)
    queue[#queue + 1] = entry
end

local function push_bonus_bounded(entry)
    local queue = BF5Text._bonus_queue
    queue[#queue + 1] = entry
    while #queue > MAX_BONUS_QUEUE do
        table.remove(queue, 1)
    end
end

local function start_next_kill()
    if BF5Text._current_kill ~= nil or #BF5Text._kill_queue == 0 then
        return false
    end
    local entry = table.remove(BF5Text._kill_queue, 1)
    entry.age = 0
    BF5Text._current_kill = entry
    add_points(entry.base_score)
    return true
end

local function insert_bonus_line(bonus, already_credited)
    local cap = BF5Text._hit_hold ~= nil and (MAX_BONUS_LINES - 1) or MAX_BONUS_LINES
    local lines = BF5Text._bonus_lines
    while #lines >= cap do
        table.remove(lines, #lines)
    end
    for i = 1, #lines do
        lines[i].slot = (lines[i].slot or i) + 1
    end
    bonus.slot = 1
    bonus.display_slot = 1
    bonus.age = 0
    table.insert(lines, 1, bonus)
    BF5Text._bonus_idle = 0
    if not already_credited then
        add_points(bonus.points)
    end
end

local function spawn_next_bonus()
    if #BF5Text._bonus_queue == 0 then
        return false
    end
    local bonus = table.remove(BF5Text._bonus_queue, 1)
    insert_bonus_line(bonus, false)
    BF5Text._bonus_cooldown = BONUS_STAGGER_INTERVAL
    return true
end

local function clear_unit_hit_credits()
    local credits = BF5Text._unit_hit_credits
    for unit in pairs(credits) do
        credits[unit] = nil
    end
end

BF5Text.clear_hit_hold = function()
    BF5Text._hit_hold = nil
    BF5Text._hit_remainder = 0
    clear_unit_hit_credits()
end

BF5Text.clear = function()
    local kq = BF5Text._kill_queue
    for i = #kq, 1, -1 do kq[i] = nil end
    local bq = BF5Text._bonus_queue
    for i = #bq, 1, -1 do bq[i] = nil end
    local bl = BF5Text._bonus_lines
    for i = #bl, 1, -1 do bl[i] = nil end

    BF5Text._current_kill = nil
    BF5Text._bonus_cooldown = 0
    BF5Text._bonus_idle = 0
    BF5Text._hit_hold = nil
    BF5Text._hit_remainder = 0
    clear_unit_hit_credits()
    BF5Text._combo = 0
    BF5Text._last_kill_time = nil
    BF5Text._total_target = 0
    BF5Text._total_display = 0
    BF5Text._total_alpha = 0
    BF5Text._total_idle_elapsed = 0
    BF5Text._cached_total_int = -1
    BF5Text._cached_total_text = ""
end

BF5Text.is_active = function()
    return BF5Text._current_kill ~= nil
        or #BF5Text._kill_queue > 0
        or BF5Text._hit_hold ~= nil
        or #BF5Text._bonus_lines > 0
        or #BF5Text._bonus_queue > 0
        or (BF5Text._total_target > 0 and BF5Text._total_alpha > 0)
end

BF5Text.add_kill = function(ctx, now)
    if type(ctx) ~= "table" then
        return false
    end
    now = tonumber(now) or now_time()

    if BF5Text._last_kill_time ~= nil and now >= BF5Text._last_kill_time
        and now - BF5Text._last_kill_time <= COMBO_WINDOW then
        BF5Text._combo = BF5Text._combo + 1
    else
        BF5Text._combo = 1
    end
    BF5Text._last_kill_time = now

    local base_score = math.max(0, math.floor(tonumber(ctx.base_score) or 100))
    local priority = tonumber(ctx.priority) or (ctx.is_boss and 5 or (ctx.is_headshot and 2 or 1))
    local line_text = build_kill_line_text(ctx.victim_name, ctx.weapon_name, base_score)

    push_kill_bounded({
        text = line_text,
        base_score = base_score,
        priority = priority,
        age = 0,
    })

    if ctx.is_headshot == true then
        local hs_label = localize_safe("bf5_headshot_bonus", "HEADSHOT")
        push_bonus_bounded({
            label = hs_label,
            points = 50,
            text = hs_label .. " +50",
        })
    end

    local combo_label, combo_points = resolve_combo_bonus(BF5Text._combo)
    if combo_label and combo_points then
        push_bonus_bounded({
            label = combo_label,
            points = combo_points,
            text = combo_label .. " +" .. tostring(combo_points),
        })
    end

    start_next_kill()
    if BF5Text._bonus_cooldown <= 0 and #BF5Text._bonus_queue > 0 then
        spawn_next_bonus()
    end
    return true
end

BF5Text.add_hit_damage = function(damage, max_health, now, attacked_unit, is_kill)
    local dmg = tonumber(damage) or 0
    local max_hp = tonumber(max_health) or 0
    if dmg <= 0 or max_hp <= 0 then
        if attacked_unit and is_kill then
            BF5Text._unit_hit_credits[attacked_unit] = nil
        end
        return false
    end
    now = tonumber(now) or now_time()

    local credits = BF5Text._unit_hit_credits
    local prev_credit = attacked_unit and credits[attacked_unit] or 0
    local remaining_cap = math.max(0, 100 - prev_credit)
    local exact_points = math.min(remaining_cap, (dmg / max_hp) * 100)

    if attacked_unit then
        if is_kill then
            credits[attacked_unit] = nil
        else
            credits[attacked_unit] = prev_credit + exact_points
        end
    end

    if exact_points <= 0 then
        return false
    end

    BF5Text._hit_remainder = BF5Text._hit_remainder + exact_points
    local whole = math.floor(BF5Text._hit_remainder + 1e-6)
    if whole < 1 then
        return false
    end
    BF5Text._hit_remainder = math.max(0, BF5Text._hit_remainder - whole)

    local hold = BF5Text._hit_hold
    if hold == nil then
        hold = {
            label = localize_safe("bf5_hit_enemy", "ENEMY HIT"),
            points = 0,
            display_points = 0,
            last_at = now,
            cached_int = -1,
            text = "",
        }
        BF5Text._hit_hold = hold
        local lines = BF5Text._bonus_lines
        while #lines > MAX_BONUS_LINES - 1 do
            table.remove(lines, #lines)
        end
    end

    hold.points = hold.points + whole
    hold.last_at = now
    BF5Text._bonus_idle = 0
    add_points(whole)
    return true
end

BF5Text.update = function(dt, now, kill_duration)
    local step_dt = math.max(0, math.min(0.25, tonumber(dt) or 0))
    now = tonumber(now) or now_time()
    kill_duration = math.max(1.0, tonumber(kill_duration) or 2.0)

    local current = BF5Text._current_kill
    if current ~= nil then
        current.age = current.age + step_dt
        local queued = #BF5Text._kill_queue
        if queued > 0 then
            local min_hold = queued <= 2 and 0.45 or (queued <= 5 and 0.28 or 0.16)
            if current.age >= min_hold then
                BF5Text._current_kill = nil
            end
        elseif current.age >= kill_duration + KILL_FADE_OUT_DURATION then
            BF5Text._current_kill = nil
        end
    end
    start_next_kill()

    local hold = BF5Text._hit_hold
    if hold ~= nil then
        local diff = hold.points - hold.display_points
        if diff > 0 then
            local rate = math.max(45, diff * 7.0)
            hold.display_points = math.min(hold.points, hold.display_points + rate * step_dt)
        else
            hold.display_points = hold.points
        end
        if now - hold.last_at >= HIT_HOLD_TIMEOUT then
            local final_points = math.max(1, math.floor(hold.points + 0.5))
            BF5Text._hit_hold = nil
            BF5Text._hit_remainder = 0
            insert_bonus_line({
                label = hold.label,
                points = final_points,
                text = hold.label .. " +" .. tostring(final_points),
            }, true)
        end
    end

    BF5Text._bonus_cooldown = math.max(0, BF5Text._bonus_cooldown - step_dt)
    if #BF5Text._bonus_queue > 0 and BF5Text._bonus_cooldown <= 0 then
        spawn_next_bonus()
    end

    local lines = BF5Text._bonus_lines
    local slide_blend = step_dt > 0 and (1 - math.exp(-BONUS_SLIDE_SPEED * step_dt)) or 0
    for i = 1, #lines do
        local line = lines[i]
        line.age = (line.age or 0) + step_dt
        if line.display_slot ~= line.slot then
            line.display_slot = line.display_slot + (line.slot - line.display_slot) * slide_blend
            if math.abs(line.display_slot - line.slot) < 0.01 then
                line.display_slot = line.slot
            end
        end
    end

    if #BF5Text._bonus_queue > 0 or BF5Text._hit_hold ~= nil then
        BF5Text._bonus_idle = 0
    elseif #lines > 0 then
        BF5Text._bonus_idle = BF5Text._bonus_idle + step_dt
        if BF5Text._bonus_idle >= BONUS_QUIET_HOLD + BONUS_EXIT_DURATION then
            for i = #lines, 1, -1 do lines[i] = nil end
            BF5Text._bonus_idle = 0
        end
    else
        BF5Text._bonus_idle = 0
    end

    if BF5Text._total_display < BF5Text._total_target then
        local diff = BF5Text._total_target - BF5Text._total_display
        local rate = math.max(120, diff * 5.0)
        BF5Text._total_display = math.min(BF5Text._total_target, BF5Text._total_display + rate * step_dt)
    else
        BF5Text._total_display = BF5Text._total_target
    end

    local lines_busy = BF5Text._current_kill ~= nil
        or #BF5Text._kill_queue > 0
        or BF5Text._hit_hold ~= nil
        or #lines > 0
        or #BF5Text._bonus_queue > 0

    if BF5Text._total_target > 0 then
        if lines_busy then
            BF5Text._total_idle_elapsed = 0
            BF5Text._total_alpha = 1
        else
            BF5Text._total_idle_elapsed = BF5Text._total_idle_elapsed + step_dt
            if BF5Text._total_idle_elapsed <= TOTAL_QUIET_HOLD then
                BF5Text._total_alpha = 1
            else
                local fade_p = (BF5Text._total_idle_elapsed - TOTAL_QUIET_HOLD) / TOTAL_FADE_DURATION
                if fade_p >= 1 then
                    BF5Text._total_target = 0
                    BF5Text._total_display = 0
                    BF5Text._total_alpha = 0
                    BF5Text._total_idle_elapsed = 0
                    BF5Text._cached_total_int = -1
                    BF5Text._cached_total_text = ""
                else
                    BF5Text._total_alpha = 1 - fade_p * fade_p
                end
            end
        end
    else
        BF5Text._total_alpha = 0
        BF5Text._total_idle_elapsed = 0
    end
end

BF5Text.get_kill_render = function(kill_duration)
    local current = BF5Text._current_kill
    if current == nil then
        return "", 0
    end
    kill_duration = math.max(1.0, tonumber(kill_duration) or 2.0)
    local age = current.age or 0
    local alpha = 1
    if age < KILL_FADE_IN_DURATION then
        alpha = clamp01(age / KILL_FADE_IN_DURATION)
    elseif #BF5Text._kill_queue == 0 and age > kill_duration then
        alpha = 1 - clamp01((age - kill_duration) / KILL_FADE_OUT_DURATION)
    end
    return current.text, alpha
end

BF5Text.get_total_render = function()
    if BF5Text._total_target <= 0 or BF5Text._total_alpha <= 0 then
        return "", 0
    end
    return get_formatted_total_text(BF5Text._total_display), BF5Text._total_alpha
end

BF5Text.fill_bonus_render_slots = function(out_texts, out_slots, out_alphas, out_shifts)
    for i = 1, MAX_BONUS_LINES do
        out_texts[i] = ""
        out_slots[i] = i
        out_alphas[i] = 0
        out_shifts[i] = 0
    end

    local out_idx = 0
    local hold = BF5Text._hit_hold
    if hold ~= nil then
        local shown = math.min(hold.points, math.max(1, math.floor(hold.display_points + 0.5)))
        if shown ~= hold.cached_int then
            hold.cached_int = shown
            hold.text = hold.label .. " +" .. tostring(shown)
        end
        out_idx = out_idx + 1
        out_texts[out_idx] = hold.text
        out_slots[out_idx] = 1
        out_alphas[out_idx] = 1
        out_shifts[out_idx] = 0
    end

    local exit_p = clamp01((BF5Text._bonus_idle - BONUS_QUIET_HOLD) / BONUS_EXIT_DURATION)
    local stack_alpha = 1 - exit_p
    local shift_ratio = 1.15 * (exit_p * exit_p * (3 - 2 * exit_p))
    local slot_offset = hold ~= nil and 1 or 0
    local lines = BF5Text._bonus_lines

    for i = 1, #lines do
        if out_idx >= MAX_BONUS_LINES then
            break
        end
        local line = lines[i]
        local entry_alpha = line.age < 0.08 and clamp01(line.age / 0.08) or 1
        out_idx = out_idx + 1
        out_texts[out_idx] = line.text or ""
        out_slots[out_idx] = (line.display_slot or line.slot or i) + slot_offset
        out_alphas[out_idx] = entry_alpha * stack_alpha
        out_shifts[out_idx] = shift_ratio
    end
    return out_idx
end

BF5Text.MAX_BONUS_LINES = MAX_BONUS_LINES
HKS.HitKillBF5Text = BF5Text

return BF5Text
