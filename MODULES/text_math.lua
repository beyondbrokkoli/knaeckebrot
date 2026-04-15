local max, floor = math.max, math.floor

return function(slide_w, slide_h, target_depth, fov, canvas_w, canvas_h)
    local distScale = max(slide_h, slide_w * (canvas_h / canvas_w))
    local optimal_scale = (fov / target_depth)
    
    local virtW = max(1, floor(slide_w * optimal_scale))
    local virtH = max(1, floor(slide_h * optimal_scale))

    local scaled_fonts = {
        title = love.graphics.newFont(max(8, floor((slide_h * 0.10) * optimal_scale))),
        head  = love.graphics.newFont(max(8, floor((slide_h * 0.08) * optimal_scale))),
        body  = love.graphics.newFont(max(8, floor((slide_h * 0.05) * optimal_scale)))
    }

    return optimal_scale, virtW, virtH, scaled_fonts
end
