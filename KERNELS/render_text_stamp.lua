-- ========================================================================
-- KERNELS/render_text_stamp.lua
-- Pure DOD Z-Buffered 2D Text Stamper. Zero allocations.
-- ========================================================================
local bit = require("bit")
local floor = math.floor

return function(SlideCaches, Visible_IDs, Count_Visible, Obj_X, Obj_Y, Obj_Z, MainCamera, ScreenPtr, ZBuffer, SLICE_START, SLICE_MAX)

    -- The Hot Loop Closure
    return function(CANVAS_W, CANVAS_H, MasterAlpha)
        if MasterAlpha <= 0 then return end

        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local alpha_mult = floor(MasterAlpha * 256)
        local visible_total = Count_Visible[0]

        for v = 0, visible_total - 1 do
            local id = Visible_IDs[v]

            -- Only check objects that are actually Slides
            if id >= SLICE_START and id <= SLICE_MAX then
                local slide_idx = id - SLICE_START
                local TextCache = SlideCaches[slide_idx]

                if TextCache then
                    -- 1. Calculate the exact 3D depth of this slide's center
                    local dx, dy, dz = Obj_X[id] - cpx, Obj_Y[id] - cpy, Obj_Z[id] - cpz
                    local slide_cz = dx*cfw_x + dy*cfw_y + dz*cfw_z

                    -- 2. Pull the text slightly forward based on the Baker's offset
                    local text_z = slide_cz - TextCache.text_z_offset

                    -- 3. Only draw if the text is in front of the near plane
                    if text_z > 0.1 then
                        local text_w, text_h = TextCache.w, TextCache.h
                        local t_ptr = TextCache.ptr

                        -- 4. Calculate exact screen center (Using orig_h to account for the crop!)
                        local start_x = floor((CANVAS_W - text_w) / 2)
                        local start_y = floor((CANVAS_H - TextCache.orig_h) / 2) + floor(TextCache.orig_h * 0.05)

                        -- 5. The Stamp Loop
                        for y = 0, text_h - 1 do
                            local screen_y = start_y + y

                            -- Vertical Screen bounds check
                            if screen_y >= 0 and screen_y < CANVAS_H then
                                local dest_row_offset = screen_y * CANVAS_W
                                local src_row_offset = y * text_w

                                for x = 0, text_w - 1 do
                                    local screen_x = start_x + x

                                    -- Horizontal Screen bounds check
                                    if screen_x >= 0 and screen_x < CANVAS_W then
                                        local screen_idx = dest_row_offset + screen_x

                                        -- DOD Z-BUFFER CHECK FIRST
                                        if text_z < ZBuffer[screen_idx] then
                                            local src_color = t_ptr[src_row_offset + x]
                                            local a = bit.band(bit.rshift(src_color, 24), 0xFF)

                                            -- Only process visible pixels
                                            if a > 0 then
                                                -- Apply presentation camera fade
                                                if MasterAlpha < 1.0 then 
                                                    a = bit.rshift(a * alpha_mult, 8) 
                                                end

                                                if a >= 255 then
                                                    -- Opaque Overwrite
                                                    ScreenPtr[screen_idx] = src_color
                                                    ZBuffer[screen_idx] = text_z
                                                elseif a > 10 then
                                                    -- AABBGGRR Alpha Blending
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

                                                    -- Claim the Z-buffer if mostly solid
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
        end
    end
end
