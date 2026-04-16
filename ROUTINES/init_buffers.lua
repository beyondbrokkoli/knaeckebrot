local ffi = require("ffi")

return function()
    local pixel_w, pixel_h = love.graphics.getPixelDimensions()
    CANVAS_W, CANVAS_H = pixel_w, pixel_h
    HALF_W, HALF_H = pixel_w * 0.5, pixel_h * 0.5

    ScreenBuffer = love.image.newImageData(CANVAS_W, CANVAS_H)
    ScreenImage = love.graphics.newImage(ScreenBuffer)
    ScreenPtr = ffi.cast("uint32_t*", ScreenBuffer:getPointer())

    ZBuffer = ffi.new("float[?]", CANVAS_W * CANVAS_H)
    MainCamera.fov = (CANVAS_W / 800) * 600
end
