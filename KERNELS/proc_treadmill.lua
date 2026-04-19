-- ========================================================================
-- KERNELS/proc_treadmill.lua
-- The Infinite Frenet-Serret Rollercoaster.
-- Spawns just-in-time chunks directly into the static rendering pipeline.
-- ========================================================================
local bit = require("bit")
local math_sin, math_cos, sqrt, abs, floor = math.sin, math.cos, math.sqrt, math.abs, math.floor

return function(
    SLICE_START, MAX_TILES, Count_Ptr,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
    Global_NumVerts, Global_NumTris, MainCamera, EngineState, TargetState
)

    local CHUNK_LENGTH = 1000
    local SEGMENTS = 8
    local SIDES = 12
    local TUBE_RADIUS = 300
    local VCOUNT = (SEGMENTS + 1) * SIDES
    local TCOUNT = SEGMENTS * SIDES * 2

    -- Helper: The global continuous math function for our rollercoaster spine
    local function getSpine(z)
        local t = z * 0.0005
        local x = math_sin(t) * 2000 + math_cos(t * 1.3) * 500
        local y = math_cos(t * 0.8) * 1500 + math_sin(t * 1.7) * 500
        return x, y, z
    end

    -- ==========================================
    -- PHASE 1: PRE-ALLOCATION (The Topology Web)
    -- ==========================================
    for slot = 0, MAX_TILES - 1 do
        local id = SLICE_START + slot
        local vStart = Global_NumVerts[0]
        local tStart = Global_NumTris[0]
        
        Obj_VertStart[id], Obj_VertCount[id] = vStart, VCOUNT
        Obj_TriStart[id],  Obj_TriCount[id]  = tStart, TCOUNT
        Obj_Radius[id] = 4000 -- Give it a massive bounding sphere so the camera doesn't accidentally cull the chunk edge

        -- Identity Matrix (All vertices will contain exact global offsets)
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

        Global_NumVerts[0] = Global_NumVerts[0] + VCOUNT
        Global_NumTris[0]  = Global_NumTris[0]  + TCOUNT

        -- Wire the Triangle Indices once. The mesh structure never changes!
        local tIdx = tStart
        for i = 0, SEGMENTS - 1 do
            for j = 0, SIDES - 1 do
                local next_j = (j + 1) % SIDES
                local a = vStart + i * SIDES + j
                local b = vStart + (i + 1) * SIDES + j
                local c = vStart + (i + 1) * SIDES + next_j
                local d = vStart + i * SIDES + next_j

                -- Tri 1
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b
                tIdx = tIdx + 1
                -- Tri 2
                Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c
                tIdx = tIdx + 1
            end
        end
        
        -- Hide deep underground
        Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, -99999, 0
    end

    local spawn_count = 0
    local next_spawn_z = 0

    -- ==========================================
    -- PHASE 2: THE HOT LOOP (Memory Injection)
    -- ==========================================
    return function(dt)
        -- Only run if we are in OVERVIEW mode
        if not (EngineState[5] or (EngineState[1] and TargetState[5])) then return end

        local horizon_z = MainCamera.z - 10000 
        
        while next_spawn_z > horizon_z do
            local slot = spawn_count % MAX_TILES
            local id = SLICE_START + slot
            
            -- Object base sits exactly on the Z axis
            Obj_X[id] = 0
            Obj_Y[id] = 0
            Obj_Z[id] = next_spawn_z

            local vStart = Obj_VertStart[id]
            local tStart = Obj_TriStart[id]

            -- 1. Calculate a dynamic color for this chunk
            local phase = abs(next_spawn_z * 0.0001)
            local intensity = (math_sin(phase * 10) + 1.0) * 0.5
            local r = floor((0.1 + intensity * 0.6) * 255)
            local g = floor((0.4 + intensity * 0.4) * 255)
            local b = floor((0.7 + intensity * 0.3) * 255)
            local chunk_color = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)

            -- Color the triangles
            for t = 0, TCOUNT - 1 do Tri_BakedColor[tStart + t] = chunk_color end

            -- 2. Inject Frenet-Serret vertices dynamically into memory!
            for i = 0, SEGMENTS do
                local segment_z = next_spawn_z - (i / SEGMENTS) * CHUNK_LENGTH
                
                local px, py, pz = getSpine(segment_z)
                local nx, ny, nz = getSpine(segment_z - 1.0) 
                local tx, ty, tz = nx - px, ny - py, nz - pz

                local upx, upy, upz = 0, 1, 0
                if abs(ty) > 0.99 then upx, upy, upz = 1, 0, 0 end 

                local bx = ty * upz - tz * upy
                local by = tz * upx - tx * upz
                local bz = tx * upy - ty * upx
                local bLen = sqrt(bx*bx + by*by + bz*bz)
                if bLen == 0 then bLen = 1 end
                bx, by, bz = bx/bLen, by/bLen, bz/bLen

                local normX = by * tz - bz * ty
                local normY = bz * tx - bx * tz
                local normZ = bx * ty - by * tx
                local nLen = sqrt(normX*normX + normY*normY + normZ*normZ)
                if nLen == 0 then nLen = 1 end
                normX, normY, normZ = normX/nLen, normY/nLen, normZ/nLen

                for j = 0, SIDES - 1 do
                    local v_angle = (j / SIDES) * math.pi * 2
                    local cosV, sinV = math_cos(v_angle) * TUBE_RADIUS, math_sin(v_angle) * TUBE_RADIUS
                    local vIdx = vStart + i * SIDES + j
                    
                    -- Note how Z is mapped local to the Object_Z origin!
                    Vert_LX[vIdx] = px + normX * cosV + bx * sinV
                    Vert_LY[vIdx] = py + normY * cosV + by * sinV
                    Vert_LZ[vIdx] = (pz - next_spawn_z) + normZ * cosV + bz * sinV 
                end
            end

            if Count_Ptr[0] < MAX_TILES then Count_Ptr[0] = Count_Ptr[0] + 1 end
            
            spawn_count = spawn_count + 1
            next_spawn_z = next_spawn_z - CHUNK_LENGTH 
        end
    end
end
