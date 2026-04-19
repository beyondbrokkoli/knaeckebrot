local RasterizeTriangle = require("MODULES.rasterize_triangle")
local TopologyMath = require("MODULES.topology_math")
local BakeHSLPalette = require("ROUTINES.bake_hsl_palette")

return function(MainCamera, ScreenPtr, ZBuffer)
    -- Closure Initialization: Bake the LUT once when the sequence binds!
    local TUBES = TopologyMath.TUBULAR_SEGMENTS
    local SIDES = TopologyMath.RADIAL_SEGMENTS
    local Palette = BakeHSLPalette(TUBES)

    -- THE COMPUTE LOOP
    return function(CANVAS_W, CANVAS_H, HALF_W, HALF_H, active_time, window_offset, window_size)
        -- Scroll the baked color palette through time
        local time_shift = math.floor(active_time * 15)

        for i = window_offset, window_offset + window_size - 1 do
            local u_idx = i % TUBES
            local next_u = (i + 1) % TUBES
            
            -- Read from the pre-baked HSL table (wrapping around safely)
            local col_idx = (i - time_shift) % TUBES
            if col_idx < 0 then col_idx = col_idx + TUBES end
            local segment_color = Palette[col_idx]

            for j = 0, SIDES - 1 do
                local next_j = (j + 1) % SIDES

                -- Fetch the 4 corners of the quad
                local ax, ay, az = TopologyMath.GetLiveVertex(u_idx, j, active_time, MainCamera)
                local bx, by, bz = TopologyMath.GetLiveVertex(next_u, j, active_time, MainCamera)
                local cx, cy, cz = TopologyMath.GetLiveVertex(next_u, next_j, active_time, MainCamera)
                local dx, dy, dz = TopologyMath.GetLiveVertex(u_idx, next_j, active_time, MainCamera)

                if az and bz and cz and dz then
                    -- Tri 1: (a, c, b) matching sys_factory's ordering
                    if (cx - ax)*(by - ay) - (cy - ay)*(bx - ax) < 0 then
                        RasterizeTriangle(
                            HALF_W + ax, HALF_H + ay, az, 
                            HALF_W + cx, HALF_H + cy, cz, 
                            HALF_W + bx, HALF_H + by, bz, 
                            segment_color, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer
                        )
                    end

                    -- Tri 2: (a, d, c) matching sys_factory's ordering
                    if (dx - ax)*(cy - ay) - (dy - ay)*(cx - ax) < 0 then
                        RasterizeTriangle(
                            HALF_W + ax, HALF_H + ay, az, 
                            HALF_W + dx, HALF_H + dy, dz, 
                            HALF_W + cx, HALF_H + cy, cz, 
                            segment_color, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer
                        )
                    end
                end
            end
        end
    end
end
