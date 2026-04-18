local bit = require("bit")
local sqrt, max, min = math.sqrt, math.max, math.min

return function(Slice_Start, Active_Count)
    local Slice_End = Slice_Start + Active_Count - 1

    for id = Slice_Start, Slice_End do
        local vStart, tStart, tCount = Obj_VertStart[id], Obj_TriStart[id], Obj_TriCount[id]
        local rx, rz = Obj_RTX[id], Obj_RTZ[id]
        local ux, uy, uz = Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id]
        local fx, fy, fz = Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id]
        local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]

        for t = 0, tCount - 1 do
            local idx = tStart + t
            local i1, i2, i3 = Tri_V1[idx], Tri_V2[idx], Tri_V3[idx]

            -- Vertex extraction...
            local getW = function(vi)
                local lx, ly, lz = Vert_LX[vi], Vert_LY[vi], Vert_LZ[vi]
                return ox + lx*rx + ly*ux + lz*fx, oy + ly*uy + lz*fy, oz + lx*rz + ly*uz + lz*fz
            end

            local wx1, wy1, wz1 = getW(i1)
            local wx2, wy2, wz2 = getW(i2)
            local wx3, wy3, wz3 = getW(i3)

            -- Normal math...
            local nx = (wy1-wy2)*(wz1-wz3) - (wz1-wz2)*(wy1-wy3)
            local ny = (wz1-wz2)*(wx1-wx3) - (wx1-wx2)*(wz1-wz3)
            local nz = (wx1-wx2)*(wy1-wy3) - (wy1-wy2)*(wx1-wx3)

            local len = sqrt(nx*nx + ny*ny + nz*nz); if len == 0 then len = 1 end
            local lightDot = max(0.2, min(1.0, (nx*0.5 + ny*1.0 + nz*0.5) / len))

            -- NEW: PRE-BAKE THE AABBGGRR PIXEL
            local tc = Tri_Color[idx]
            local a = bit.band(bit.rshift(tc, 24), 0xFF)
            local b = min(255, bit.band(bit.rshift(tc, 16), 0xFF) * lightDot)
            local g = min(255, bit.band(bit.rshift(tc, 8), 0xFF) * lightDot)
            local r = min(255, bit.band(tc, 0xFF) * lightDot)
            
            Tri_BakedColor[idx] = bit.bor(bit.lshift(a, 24), bit.lshift(b, 16), bit.lshift(g, 8), r)
        end
    end
end
