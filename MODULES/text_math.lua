-- ========================================================================
-- MODULES/text_math.lua
-- Corrected for High-Res Zen Mode dual-baking.
-- ========================================================================
local max, min, floor, abs = math.max, math.min, math.floor, math.abs

return function(slide_w, slide_h, target_depth, fov, canvas_w, canvas_h)
    -- 1. Use a much smaller epsilon (0.05 instead of 1.0).
    -- This allows the Zen bake (true key) to reach much higher resolutions.
    if abs(target_depth) < 0.05 then target_depth = 0.05 end

    local optimal_scale = (fov / target_depth)

    -- Guard against NaN if the camera is precisely on top of the slide
    if optimal_scale ~= optimal_scale or optimal_scale == math.huge then
        optimal_scale = 1.0
    end

    -- 2. Calculate projected virtual resolution
    local virtW = max(1, floor(slide_w * optimal_scale))
    local virtH = max(1, floor(slide_h * optimal_scale))

    -- 3. THE RESOLUTION CAP (The real crash guard)
    -- We allow up to 4096px for razor-sharp Zen text, but no higher.
    local MAX_CANVAS = 4096
    if virtW > MAX_CANVAS or virtH > MAX_CANVAS then
        local ratio = min(MAX_CANVAS / virtW, MAX_CANVAS / virtH)
        virtW = floor(virtW * ratio)
        virtH = floor(virtH * ratio)
        
        -- IMPORTANT: Re-sync optimal_scale.
        -- This tells the Stamp Kernel exactly how much we shrunk the 
        -- bake relative to the "infinite" math.
        optimal_scale = optimal_scale * ratio
    end

    -- 4. Scale fonts based on the final, safe, high-res scale
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
