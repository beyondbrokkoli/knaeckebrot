-- ========================================================================
-- KERNELS/render_text_stamp.lua
-- Dynamic 3D UI Projection with Inverse Software Scaling
-- ========================================================================
local bit = require("bit")
local floor, max, min, abs, sqrt = math.floor, math.max, math.min, math.abs, math.sqrt

return function(SlideCaches, ActiveSlide, EngineState, Box_X, Box_Y, Box_Z, Box_NX, Box_NY, Box_NZ, MainCamera, ScreenPtr, ZBuffer)

    return function(CANVAS_W, CANVAS_H, HALF_W, HALF_H, MasterAlpha)
        if MasterAlpha <= 0 then return end
        
        local slide_idx = ActiveSlide[0]
        local isZen = (EngineState[0] == 3 or EngineState[0] == 4) 
        
        local caches = SlideCaches[slide_idx]
        if not caches then return end
        
        local cache = caches[isZen]
        if not cache then return end

        local sx, sy, sz = Box_X[slide_idx], Box_Y[slide_idx], Box_Z[slide_idx]
        local bnx, bny, bnz = Box_NX[slide_idx], Box_NY[slide_idx], Box_NZ[slide_idx]
        
        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local crt_x, crt_z = MainCamera.rtx, MainCamera.rtz
        local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
        
        -- 1. Angular Fade (Fade out if looking away)
        local camDX, camDY, camDZ = cpx - sx, cpy - sy, cpz - sz
        local dist = sqrt(camDX*camDX + camDY*camDY + camDZ*camDZ)
        local dot = (dist > 0) and ((camDX/dist)*bnx + (camDY/dist)*bny + (camDZ/dist)*bnz) or 0
        local abs_dot = abs(dot)
        
        if abs_dot < 0.707 then return end
        
        -- 2. 3D Depth Calculation
        local t_off = (dot > 0 and 1 or -1) * cache.text_z_offset
        local tdx = (sx + bnx * t_off) - cpx
        local tdy = (sy + bny * t_off) - cpy
        local tdz = (sz + bnz * t_off) - cpz
        
        local depth = tdx*cfw_x + tdy*cfw_y + tdz*cfw_z
        if depth < 10 or depth > 15000 then return end
        
        -- 3. Dynamic Alpha Generation
        local alpha_close = max(0, min(1, (depth-100)/300))
        local alpha_angle = min(1, (abs_dot-0.707)*5)
        local alpha_far = max(0, min(1, (15000-depth)/2000))
        local final_alpha = alpha_close * alpha_angle * alpha_far * MasterAlpha
        
        if final_alpha <= 0.01 then return end
        
        -- 4. Dynamic Scale & Perspective
        local current_perspective = (MainCamera.fov / depth)
        local draw_scale = current_perspective / cache.opt_scale
        
        local cx = HALF_W + (tdx*crt_x + tdz*crt_z) * current_perspective
        local cy = HALF_H + (tdx*cup_x + tdy*cup_y + tdz*cup_z) * current_perspective
        
        cy = cy - ((cache.orig_h - cache.h) * 0.5) * draw_scale

        -- 5. The BlitUI_3D Interpolator Loop
        local ptr, tw, th = cache.ptr, cache.w, cache.h
        local sw, sh = floor(tw * draw_scale), floor(th * draw_scale)
        if sw <= 0 or sh <= 0 then return end
        
        local startX, startY = floor(cx - sw * 0.5), floor(cy - sh * 0.5)
        local clipX, clipY = max(0, startX), max(0, startY)
        local endX, endY = min(CANVAS_W - 1, startX + sw - 1), min(CANVAS_H - 1, startY + sh - 1)
        
        local inv_scale = 1.0 / draw_scale
        local z_threshold = depth - 5
        local global_a256 = floor(final_alpha * 255)
        
        for y = clipY, endY do
            local ty = floor((y - startY) * inv_scale)
            if ty >= 0 and ty < th then
                local screenOff = y * CANVAS_W
                local buffOff = ty * tw
                for x = clipX, endX do
                    local tx = floor((x - startX) * inv_scale)
                    if tx >= 0 and tx < tw then
                        local px = ptr[buffOff + tx]
                        if px >= 0x01000000 then -- Fast alpha check
                            if ZBuffer[screenOff + x] >= z_threshold then
                                local pa = bit.rshift(px, 24)
                                local final_a = bit.rshift(pa * global_a256, 8)
                                if final_a > 0 then
                                    local bg = ScreenPtr[screenOff + x]
                                    local bg_r, bg_g, bg_b = bit.band(bit.rshift(bg, 16), 0xFF), bit.band(bit.rshift(bg, 8), 0xFF), bit.band(bg, 0xFF)
                                    local inv_a = 255 - final_a
                                    local r, g, b = bit.rshift(bg_r*inv_a, 8), bit.rshift(bg_g*inv_a, 8), bit.rshift(bg_b*inv_a, 8)
                                    ScreenPtr[screenOff + x] = bit.bor(0xFF000000, bit.lshift(r, 16), bit.lshift(g, 8), b)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
