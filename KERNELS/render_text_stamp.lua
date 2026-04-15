-- ========================================================================
-- KERNELS/render_text_stamp.lua
-- Stamps the Active Slide's text. Evaluates angular fade and dual caches.
-- ========================================================================
local bit = require("bit")
local floor = math.floor

return function(SlideCaches, ActiveSlide, EngineState, Obj_X, Obj_Y, Obj_Z, MainCamera, ScreenPtr, ZBuffer)
    return function(CANVAS_W, CANVAS_H, MasterAlpha)
        if MasterAlpha <= 0 then return end
        
        local slide_idx = ActiveSlide[0]
        local caches = SlideCaches[slide_idx]
        if not caches then return end

        -- Pick the right cache based on Zen mode
        local isZen = (EngineState[0] == 3 or EngineState[0] == 4) 
        local TextCache = caches[isZen]
        if not TextCache then return end

        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        
        local dx, dy, dz = Obj_X[slide_idx] - cpx, Obj_Y[slide_idx] - cpy, Obj_Z[slide_idx] - cpz
        
        -- Angular Fade: Look away, text fades!
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        local dot = (dist > 0) and ((dx/dist)*cfw_x + (dy/dist)*cfw_y + (dz/dist)*cfw_z) or 0
        if dot < 0.707 then return end
        
        local alpha_angle = math.min(1, (dot - 0.707) * 5)
        local final_alpha = MasterAlpha * alpha_angle
        if final_alpha <= 0.01 then return end
        
        local alpha_mult = floor(final_alpha * 256)
        local slide_cz = dx*cfw_x + dy*cfw_y + dz*cfw_z
        local text_z = slide_cz - TextCache.text_z_offset
        
        if text_z > 0.1 then
            local text_w, text_h = TextCache.w, TextCache.h
            local t_ptr = TextCache.ptr
            local start_x = floor((CANVAS_W - text_w) / 2)
            local start_y = floor((CANVAS_H - TextCache.orig_h) / 2) + floor(TextCache.orig_h * 0.05)
            
            for y = 0, text_h - 1 do
                local screen_y = start_y + y
                if screen_y >= 0 and screen_y < CANVAS_H then
                    local dest_row_offset = screen_y * CANVAS_W
                    local src_row_offset = y * text_w
                    for x = 0, text_w - 1 do
                        local screen_x = start_x + x
                        if screen_x >= 0 and screen_x < CANVAS_W then
                            local screen_idx = dest_row_offset + screen_x
                            if text_z < ZBuffer[screen_idx] then
                                local src_color = t_ptr[src_row_offset + x]
                                local a = bit.band(bit.rshift(src_color, 24), 0xFF)
                                if a > 0 then
                                    if final_alpha < 1.0 then a = bit.rshift(a * alpha_mult, 8) end
                                    if a >= 255 then
                                        ScreenPtr[screen_idx] = src_color
                                        ZBuffer[screen_idx] = text_z
                                    elseif a > 10 then
                                        local bg = ScreenPtr[screen_idx]
                                        local inv_a = 255 - a
                                        local br = bit.band(bg, 0xFF)
                                        local bg_g = bit.band(bit.rshift(bg, 8), 0xFF)
                                        local bb = bit.band(bit.rshift(bg, 16), 0xFF)
                                        local tr = bit.band(src_color, 0xFF)
                                        local tg = bit.band(bit.rshift(src_color, 8), 0xFF)
                                        local tb = bit.band(bit.rshift(src_color, 16), 0xFF)
                                        local out_r = bit.rshift((tr * a) + (br * inv_a), 8)
                                        local out_g = bit.rshift((tg * a) + (bg_g * inv_a), 8)
                                        local out_b = bit.rshift((tb * a) + (bb * inv_a), 8)
                                        ScreenPtr[screen_idx] = bit.bor(0xFF000000, bit.lshift(out_b, 16), bit.lshift(out_g, 8), out_r)
                                        if a > 128 then ZBuffer[screen_idx] = text_z end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

