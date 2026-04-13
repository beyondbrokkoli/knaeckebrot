-- core/bench.lua
BENCH = {
    registry = {},
--    frame_logs = {}
}

function BENCH.Run(label, func)
    local start = love.timer.getTime()
    func()
    local duration = love.timer.getTime() - start

    -- Initialize stats for new labels
    if not BENCH.registry[label] then
        BENCH.registry[label] = {
            count = 0,
            total = 0,
            min = math.huge,
            max = 0
        }
    end

    local stats = BENCH.registry[label]
    stats.count = stats.count + 1
    stats.total = stats.total + duration
    stats.min = math.min(stats.min, duration)
    stats.max = math.max(stats.max, duration)

    -- Real-time logging for the current frame
    -- Real time memory leak because frame_logs is never cleared
    -- table.insert(BENCH.frame_logs, string.format("[%s]: %.6fs", label, duration))
end

function BENCH.GetStats(label)
    local s = BENCH.registry[label]
    if not s or s.count == 0 then return "N/A" end
    return string.format("Avg: %.6fs | Max: %.6fs", s.total / s.count, s.max)
end
