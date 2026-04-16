local sqrt, max, min = math.sqrt, math.max, math.min

return function(Slice_Start, Active_Count)
    local Slice_End = Slice_Start + Active_Count - 1

    for id = Slice_Start, Slice_End do
        local vStart = Obj_VertStart[id]
        local tStart = Obj_TriStart[id]
        local tCount = Obj_TriCount[id]

        local rx, rz = Obj_RTX[id], Obj_RTZ[id]
        local ux, uy, uz = Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id]
        local fx, fy, fz = Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id]
        local ox, oy, oz = Obj_X[id], Obj_Y[id], Obj_Z[id]

        for t = 0, tCount - 1 do
            local idx = tStart + t
            local i1, i2, i3 = Tri_V1[idx], Tri_V2[idx], Tri_V3[idx]

            -- Get world positions of vertices
            local getW = function(vi)
                local lx, ly, lz = Vert_LX[vi], Vert_LY[vi], Vert_LZ[vi]
                return ox + lx*rx + ly*ux + lz*fx, oy + ly*uy + lz*fy, oz + lx*rz + ly*uz + lz*fz
            end

            local wx1, wy1, wz1 = getW(i1)
            local wx2, wy2, wz2 = getW(i2)
            local wx3, wy3, wz3 = getW(i3)

            -- Normal math
            local nx = (wy1-wy2)*(wz1-wz3) - (wz1-wz2)*(wy1-wy3)
            local ny = (wz1-wz2)*(wx1-wx3) - (wx1-wx2)*(wz1-wz3)
            local nz = (wx1-wx2)*(wy1-wy3) - (wy1-wy2)*(wx1-wx3)

            local len = sqrt(nx*nx + ny*ny + nz*nz)
            if len == 0 then len = 1 end

            -- RESTORED LEGACY STATIC LIGHTING
            local lightDot = max(0.2, min(1.0, (nx*0.5 + ny*1.0 + nz*0.5) / len))
            Tri_BaseLight[idx] = lightDot
        end
    end
end
