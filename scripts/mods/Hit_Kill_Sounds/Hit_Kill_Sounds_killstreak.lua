-- luacheck: globals get_mod
local HKS = get_mod("Hit_Kill_Sounds")

local KillstreakCounter = {}
KillstreakCounter.__index = KillstreakCounter

local function get_reset_time()
    local reset_time = tonumber(HKS:get("cf_killstreak_reset_time")) or 20

    return math.max(reset_time, 0) / 10
end

local function get_max_count()
    return math.max(1, tonumber(HKS:get("cf_killstreak_max")) or 13)
end

function KillstreakCounter.new(id, options)
    options = options or {}

    return setmetatable({
        id = id,
        kills_counter = 0,
        last_kill_time = 0,
        last_reset_reason = nil,
        max_count = options.max_count,
        overflow_mode = options.overflow_mode or "loop",
    }, KillstreakCounter)
end

local function resolve_counter_max(counter)
    local max_count = counter.max_count

    if type(max_count) == "function" then
        max_count = max_count(counter)
    end

    return math.max(1, tonumber(max_count) or get_max_count())
end

function KillstreakCounter:reset(reason)
    self.kills_counter = 0
    self.last_kill_time = 0
    self.last_reset_reason = reason
end

function KillstreakCounter:is_expired(now)
    if self.last_kill_time <= 0 then
        return false
    end

    local current_time = tonumber(now) or 0

    return current_time - self.last_kill_time >= get_reset_time()
end

-- Return the next sequence number without changing counter state.  Consumers use
-- this to build an atomic display batch before accepting a successful event.
function KillstreakCounter:preview_next(now)
    local current_time = tonumber(now) or 0
    local count = self.kills_counter

    if self:is_expired(current_time) then
        count = 0
    end

    local max_count = resolve_counter_max(self)

    if count >= max_count then
        if self.overflow_mode == "clamp" then
            return max_count
        end

        count = 0
    end

    return count + 1
end

function KillstreakCounter:accept(now, eligible)
    if not eligible then
        return nil
    end

    local current_time = tonumber(now) or 0

    if self:is_expired(current_time) then
        self:reset("timeout")
    end

    local max_count = resolve_counter_max(self)

    if self.kills_counter >= max_count then
        if self.overflow_mode == "clamp" then
            self.kills_counter = max_count
        else
            self.kills_counter = 0
        end
    end

    if self.kills_counter < max_count then
        self.kills_counter = self.kills_counter + 1
    end
    self.last_kill_time = current_time

    return self.kills_counter
end

function KillstreakCounter:get_count()
    return self.kills_counter
end

HKS.HitKillSoundsKillstreakCounter = KillstreakCounter

return KillstreakCounter
