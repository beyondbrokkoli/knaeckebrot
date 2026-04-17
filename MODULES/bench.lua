-- ========================================================================
-- core/bench.lua
-- Pure, leak-free aggregate benchmarking.
-- ========================================================================
BENCH = {
    registry = {}
}

function BENCH.Run(label, func)
    local start = love.timer.getTime()
    func()
    local duration = love.timer.getTime() - start

    if not BENCH.registry[label] then
        BENCH.registry[label] = { count = 0, total = 0, min = math.huge, max = 0 }
    end

    local stats = BENCH.registry[label]
    stats.count = stats.count + 1
    stats.total = stats.total + duration

    if duration < stats.min then stats.min = duration end
    if duration > stats.max then stats.max = duration end
end

function BENCH.GetStats(label)
    local s = BENCH.registry[label]
    if not s or s.count == 0 then return "N/A" end
    return string.format("Avg: %.6fs | Max: %.6fs", s.total / s.count, s.max)
end
