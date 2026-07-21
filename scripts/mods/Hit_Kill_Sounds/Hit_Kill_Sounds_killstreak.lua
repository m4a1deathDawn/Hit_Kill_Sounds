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

function KillstreakCounter.new(id)
    return setmetatable({
        id = id,
        kills_counter = 0,
        last_kill_time = 0,
        last_reset_reason = nil,
    }, KillstreakCounter)
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

function KillstreakCounter:accept(now, eligible)
    if not eligible then
        return nil
    end

    local current_time = tonumber(now) or 0

    if self:is_expired(current_time) then
        self:reset("timeout")
    end

    if self.kills_counter >= get_max_count() then
        self.kills_counter = 0
    end

    self.kills_counter = self.kills_counter + 1
    self.last_kill_time = current_time

    return self.kills_counter
end

function KillstreakCounter:get_count()
    return self.kills_counter
end

HKS.HitKillSoundsKillstreakCounter = KillstreakCounter

return KillstreakCounter
