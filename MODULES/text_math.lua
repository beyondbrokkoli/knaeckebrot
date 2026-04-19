-- ========================================================================
-- MODULES/text_math.lua
-- Hardened high-res scaling. Perfect for unboxed Zen-mode lerps.
-- ========================================================================
local max, min, floor, abs = math.max, math.min, math.floor, math.abs

return function(slide_w, slide_h, target_depth, fov, canvas_w, canvas_h)
    -- 1. Epsilon guard for target_depth (0.05 units)
    -- Prevents division by zero/singularity if camera is perfectly on slide.
    if abs(target_depth) < 0.05 then target_depth = 0.05 end
    
    local optimal_scale = (fov / target_depth)

    -- Guard against NaN/Inf from floating point jitter in FFI doubles
    if optimal_scale ~= optimal_scale or optimal_scale == math.huge then
        optimal_scale = 1.0
    end

    -- 2. Initial resolution calculation
    local virtW = max(1, floor(slide_w * optimal_scale))
    local virtH = max(1, floor(slide_h * optimal_scale))

    -- 3. THE RESOLUTION CAP (Crash Guard)
    -- We allow up to 4K resolution bakes for sharp Zen mode text.
    local MAX_RES = 4096 
    if virtW > MAX_RES or virtH > MAX_RES then
        local ratio = min(MAX_RES / virtW, MAX_RES / virtH)
        virtW = floor(virtW * ratio)
        virtH = floor(virtH * ratio)
        -- RE-SYNC: Syncs the Bake Scale with the Stamp Kernel
        optimal_scale = optimal_scale * ratio
    end

    -- 4. Font Scaling (Ensures safe integers for LÖVE fonts)
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
