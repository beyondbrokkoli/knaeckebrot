local bit = require("bit"); local ffi = require("ffi")
local max, min, floor, ceil, sqrt = math.max, math.min, math.floor, math.ceil, math.sqrt
local RasterizeTriangle = require("MODULES.rasterize_triangle")

return function(
    -- [4] Pipeline
    Visible_IDs, Count_Visible,
    -- [5] Object SoA
    Obj_X, Obj_Y, Obj_Z,
    Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,
    -- [6] Geometry SoA
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
    Tri_V1, Tri_V2, Tri_V3, Tri_Color, Tri_BakedColor, Tri_A, Tri_R, Tri_G, Tri_B,
    -- [8] Singletons & Render Targets
    MainCamera, ScreenPtr, ZBuffer
)

    return function(CANVAS_W, CANVAS_H, HALF_W, HALF_H)
        local visible_total = Count_Visible[0]
        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local crt_x, crt_z = MainCamera.rtx, MainCamera.rtz
        local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
        local cam_fov = MainCamera.fov

        for v = 0, visible_total - 1 do
            local id = Visible_IDs[v]
            local vStart, vCount = Obj_VertStart[id], Obj_VertCount[id]
            local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]
            local rx, rz = Obj_RTX[id], Obj_RTZ[id]
            local ux, uy, uz = Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id]
            local fx, fy, fz = Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id]

            for i = 0, vCount - 1 do
                local idx = vStart + i
                local lvx, lvy, lvz = Vert_LX[idx], Vert_LY[idx], Vert_LZ[idx]
                local wx = ox + lvx*rx + lvy*ux + lvz*fx
                local wy = oy + lvy*uy + lvz*fy
                local wz = oz + lvx*rz + lvy*uz + lvz*fz
                Vert_CX[idx], Vert_CY[idx], Vert_CZ[idx] = wx, wy, wz -- Cache for normals
                local vdx, vdy, vdz = wx-cpx, wy-cpy, wz-cpz
                local cz = vdx*cfw_x + vdy*cfw_y + vdz*cfw_z
                if cz < 0.1 then Vert_Valid[idx] = false else
                    local f = cam_fov / cz
                    Vert_PX[idx] = HALF_W + (vdx*crt_x + vdz*crt_z) * f
                    Vert_PY[idx] = HALF_H + (vdx*cup_x + vdy*cup_y + vdz*cup_z) * f
                    Vert_PZ[idx] = cz * 1.004; Vert_Valid[idx] = true
                end
            end

            local tStart, tCount = Obj_TriStart[id], Obj_TriCount[id]
            for i = 0, tCount - 1 do
                local idx = tStart + i
                local i1, i2, i3 = Tri_V1[idx], Tri_V2[idx], Tri_V3[idx]
                if Vert_Valid[i1] and Vert_Valid[i2] and Vert_Valid[i3] then
                    local px1, py1, pz1 = Vert_PX[i1], Vert_PY[i1], Vert_PZ[i1]
                    local px2, py2, pz2 = Vert_PX[i2], Vert_PY[i2], Vert_PZ[i2]
                    local px3, py3, pz3 = Vert_PX[i3], Vert_PY[i3], Vert_PZ[i3]

                    if (px2-px1)*(py3-py1) - (py2-py1)*(px3-px1) < 0 then

                        local wx1, wy1, wz1 = Vert_CX[i1], Vert_CY[i1], Vert_CZ[i1]
                        local wx2, wy2, wz2 = Vert_CX[i2], Vert_CY[i2], Vert_CZ[i2]
                        local wx3, wy3, wz3 = Vert_CX[i3], Vert_CY[i3], Vert_CZ[i3]

                        local nx = (wy1-wy2)*(wz1-wz3) - (wz1-wz2)*(wy1-wy3)
                        local ny = (wz1-wz2)*(wx1-wx3) - (wx1-wx2)*(wz1-wz3)
                        local nz = (wx1-wx2)*(wy1-wy3) - (wy1-wy2)*(wx1-wx3)

                        -- FLIP THE NORMALS for LÖVE2D coordinate space!
                        nx, ny, nz = -nx, -ny, -nz

                        local len = sqrt(nx*nx + ny*ny + nz*nz); if len == 0 then len = 1 end

                        -- Define the exact same light vector as the baker: (0.5, 1.0, 0.5)
                        local lx, ly, lz = 0.5, 1.0, 0.5
                        local l_len = sqrt(lx*lx + ly*ly + lz*lz)
                        lx, ly, lz = lx/l_len, ly/l_len, lz/l_len

                        local final_light = max(0.2, min(1.0, (nx*lx + ny*ly + nz*lz) / len))

                        -- Read from SoA and apply shading
                        local a = Tri_A[idx]
                        local b = min(255, Tri_B[idx] * final_light)
                        local g = min(255, Tri_G[idx] * final_light)
                        local r = min(255, Tri_R[idx] * final_light)

                        local shadedColor = bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r)
                        RasterizeTriangle(px1,py1,pz1, px2,py2,pz2, px3,py3,pz3, shadedColor, CANVAS_W, CANVAS_H, ScreenPtr, ZBuffer)
                    end
                end
            end
        end
    end
end
