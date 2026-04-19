-- ========================================================================
-- MODULES/text_math.lua
-- Hardened text scaling math to prevent LÖVE2D font size 0 crashes.
-- ========================================================================
local max, floor, abs = math.max, math.floor, math.abs

return function(slide_w, slide_h, target_depth, fov, canvas_w, canvas_h)
    local distScale = max(slide_h, slide_w * (canvas_h / canvas_w))

    -- HARD SAFEGUARD: Prevent division by zero or negative depths
    if abs(target_depth) < 1.0 then target_depth = 1.0 end

    local optimal_scale = (fov / target_depth)

    -- HARD SAFEGUARD: Prevent Infinity or NaN from breaking the floor() math
    if optimal_scale ~= optimal_scale or optimal_scale == math.huge then
        optimal_scale = 1.0
    end

    local virtW = max(1, floor(slide_w * optimal_scale))
    local virtH = max(1, floor(slide_h * optimal_scale))

    -- Isolate the calculations to guarantee safe integer inputs for LÖVE
    -- The math.max(8, ...) ensures the font NEVER drops below 8 pixels
    local s_title = max(8, floor((slide_h * 0.10) * optimal_scale))
    local s_head  = max(8, floor((slide_h * 0.08) * optimal_scale))
    local s_body  = max(8, floor((slide_h * 0.05) * optimal_scale))

    local scaled_fonts = {
        title = love.graphics.newFont(s_title),
        head  = love.graphics.newFont(s_head),
        body  = love.graphics.newFont(s_body)
    }

    return optimal_scale, virtW, virtH, scaled_fonts
end
