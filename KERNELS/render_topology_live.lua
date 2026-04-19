local bit = require("bit")
local RasterizeTriangle = require("MODULES.rasterize_triangle")
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi

-- Fast HSL to Packed RGB (AABBGGRR)
local function GetNeonColor(phase)
    local intensity = (math_sin(phase) + 1.0) * 0.5
    local r = math.floor((0.1 + intensity * 0.6) * 255)
    local g = math.floor((0.4 + intensity * 0.4) * 255)
    local b = math.floor((0.7 + intensity * 0.3) * 255)
    return bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)
end

return function(MainCamera, ScreenPtr, ZBuffer)
    local P, Q = 3, 7
    local MAJOR_RADIUS = 2500
    local TUBE_RADIUS = 300
    local TUBULAR_SEGMENTS = 400
    local RADIAL_SEGMENTS = 12

    local function GetLiveVertex(u_idx, v_idx, active_time)
        local u = u_idx / TUBULAR_SEGMENTS * P * math_pi * 2
        local v = v_idx / RADIAL_SEGMENTS * math_pi * 2
        local quOverP = Q * u / P
        
        -- SCALE: Full "Mega" scale (Radius 2500)
        local r_knot = MAJOR_RADIUS * (2 + math_cos(quOverP))
        local px, py, pz = r_knot * math_cos(u), MAJOR_RADIUS * math_sin(quOverP), r_knot * math_sin(u)

        local yaw, pitch = active_time * 0.2, active_time * 0.1
        local cy, sy, cp, sp = math_cos(yaw), math_sin(yaw), math_cos(pitch), math_sin(pitch)

        local wx = px * cy + pz * sy
        local wy = py * cp - (pz * cy - px * sy) * sp
        -- LOCATION: +5000 (In front of camera)
        local wz = (pz * cy - px * sy) * cp + py * sp + 5000 

        local vdx, vdy, vdz = wx - MainCamera.x, wy - MainCamera.y, wz - MainCamera.z
        local cz = vdx * MainCamera.fwx + vdy * MainCamera.fwy + vdz * MainCamera.fwz

        if cz < 0.1 then return nil, nil, nil end
        local f = MainCamera.fov / cz
        return (vdx * MainCamera.rtx + vdz * MainCamera.rtz) * f,
               (vdx * MainCamera.upx + vdy * MainCamera.upy + vdz * MainCamera.upz) * f,
               cz
    end

    return function(CANVAS_W, CANVAS_H, HALF_W, HALF_H, active_time, window_offset, window_size)
        for i = window_offset, window_offset + window_size - 1 do
            local u_idx, next_u = i % TUBULAR_SEGMENTS, (i + 1) % TUBULAR_SEGMENTS
            local segment_color = GetNeonColor((i / TUBULAR_SEGMENTS) * 10.0 - (active_time * 5.0))

            for j = 0, RADIAL_SEGMENTS - 1 do
                local x1, y1, z1 = GetLiveVertex(u_idx, j, active_time)
                local x2, y2, z2 = GetLiveVertex(next_u, j, active_time)
                local x3, y3, z3 = GetLiveVertex(next_u, j+1, active_time)
                local x4, y4, z4 = GetLiveVertex(u_idx, j+1, active_time)

                if z1 and z2 and z3 and z4 then
                    -- TRI 1: Standard Winding (1 -> 2 -> 4)
                    RasterizeTriangle(
                        HALF_W + x1, HALF_H + y1, z1, 
                        HALF_W + x2, HALF_H + y2, z2, 
                        HALF_W + x4, HALF_H + y4, z4, 
                        segment_color, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer
                    )
                    -- TRI 2: Standard Winding (2 -> 3 -> 4)
                    RasterizeTriangle(
                        HALF_W + x2, HALF_H + y2, z2, 
                        HALF_W + x3, HALF_H + y3, z3, 
                        HALF_W + x4, HALF_H + y4, z4, 
                        segment_color, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer
                    )
                end
            end
        end
    end
end
