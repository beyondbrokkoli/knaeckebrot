-- ========================================================================
-- sys_factory.lua
-- The DOD Allocator. Claims memory slices and writes geometry.
-- ========================================================================
local ffi = require("ffi")
local bit = require("bit")
local pi, cos, sin, floor = math.pi, math.cos, math.sin, math.floor

local Factory = {}

-- ========================================================================
-- THE MASTER ALLOCATOR
-- Replaces CreateTriObject. Claims a specific ID inside a requested Slice.
-- ========================================================================
function Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, vCount, tCount, radius)
    -- 1. Get the current active count for this specific slice
    local current_count = count_ptr[0]
    local id = slice_start + current_count

    -- 2. Prevent Memory Overflows!
    if id > slice_max then
        print("[FACTORY ERROR] Slice Overflow! Cannot allocate ID " .. id)
        return nil
    end

    -- 3. Claim the memory slot by incrementing the shared pointer
    count_ptr[0] = current_count + 1
    
    -- (Optional: Track total objects if needed for debugging)
    NumObjects[0] = NumObjects[0] + 1

    -- 4. Write to the SoA Motherboard
    Obj_X[id], Obj_Y[id], Obj_Z[id] = x, y, z
    Obj_VelX[id], Obj_VelY[id], Obj_VelZ[id] = 0, 0, 0
    Obj_RotSpeedYaw[id], Obj_RotSpeedPitch[id] = 0, 0
    Obj_Yaw[id], Obj_Pitch[id] = 0, 0
    Obj_Radius[id] = radius or 50

    -- Identity Basis Vectors
    Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
    Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
    Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

    -- 5. Allocate Geometry Chunks
    Obj_VertStart[id] = NumTotalVerts[0]
    Obj_VertCount[id] = vCount
    Obj_TriStart[id] = NumTotalTris[0]
    Obj_TriCount[id] = tCount

    -- Advance global geometry pointers
    NumTotalVerts[0] = NumTotalVerts[0] + vCount
    NumTotalTris[0] = NumTotalTris[0] + tCount

    return id
end

-- ========================================================================
-- GEOMETRY GENERATORS
-- ========================================================================

function Factory.CreateTorus(slice_start, slice_max, count_ptr, cx, cy, cz, mainRadius, tubeRadius, segments, sides, baseColor)
    local vCount = segments * sides
    local tCount = segments * sides * 2
    
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, cx, cy, cz, vCount, tCount, mainRadius + tubeRadius)
    if not id then return nil end

    local vStart = Obj_VertStart[id]
    local tStart = Obj_TriStart[id]
    local r, g, b = bit.band(bit.rshift(baseColor, 16), 0xFF), bit.band(bit.rshift(baseColor, 8), 0xFF), bit.band(baseColor, 0xFF)
    local altColor = bit.bor(0xFF000000, bit.lshift(floor(r * 0.6), 16), bit.lshift(floor(g * 0.6), 8), floor(b * 0.6))

    local vIdx = vStart
    for i = 0, segments - 1 do
        local th = (i / segments) * pi * 2
        for j = 0, sides - 1 do
            local ph = (j / sides) * pi * 2
            Vert_LX[vIdx] = (mainRadius + tubeRadius * cos(ph)) * cos(th)
            Vert_LY[vIdx] = tubeRadius * sin(ph)
            Vert_LZ[vIdx] = (mainRadius + tubeRadius * cos(ph)) * sin(th)
            vIdx = vIdx + 1
        end
    end

    local tIdx = tStart
    for i = 0, segments - 1 do
        local i_next = (i + 1) % segments
        for j = 0, sides - 1 do
            local j_next = (j + 1) % sides
            local a, b_idx = (i * sides + j) + vStart, (i_next * sides + j) + vStart
            local c, d = (i_next * sides + j_next) + vStart, (i * sides + j_next) + vStart
            local col = (i + j) % 2 == 0 and baseColor or altColor
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx; Tri_Color[tIdx] = col; tIdx = tIdx + 1
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        end
    end
    return id
end

function Factory.CreateCylinder(slice_start, slice_max, count_ptr, cx, cy, cz, radius, height, segments, baseColor)
    local vCount = segments * 2 + 2
    local tCount = segments * 4
    
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, cx, cy, cz, vCount, tCount, height)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local r, g, b = bit.band(bit.rshift(baseColor, 16), 0xFF), bit.band(bit.rshift(baseColor, 8), 0xFF), bit.band(baseColor, 0xFF)
    local altColor = bit.bor(0xFF000000, bit.lshift(floor(r * 0.5), 16), bit.lshift(floor(g * 0.5), 8), floor(b * 0.5))

    for i = 0, segments - 1 do
        local angle = (i / segments) * pi * 2
        local x, z = cos(angle) * radius, sin(angle) * radius
        Vert_LX[vStart + i], Vert_LY[vStart + i], Vert_LZ[vStart + i] = x, -height/2, z
        Vert_LX[vStart + segments + i], Vert_LY[vStart + segments + i], Vert_LZ[vStart + segments + i] = x, height/2, z
    end

    local bCap, tCap = vStart + segments * 2, vStart + segments * 2 + 1
    Vert_LX[bCap], Vert_LY[bCap], Vert_LZ[bCap] = 0, -height/2, 0
    Vert_LX[tCap], Vert_LY[tCap], Vert_LZ[tCap] = 0, height/2, 0

    local tIdx = tStart
    for i = 0, segments - 1 do
        local next_i = (i + 1) % segments
        local col = (i % 2 == 0) and baseColor or altColor
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = vStart + next_i, vStart + i, vStart + segments + i; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = vStart + next_i, vStart + segments + i, vStart + segments + next_i; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = bCap, vStart + i, vStart + next_i; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = tCap, vStart + segments + next_i, vStart + segments + i; Tri_Color[tIdx] = col; tIdx = tIdx + 1
    end
    return id
end

function Factory.CreateSphere(slice_start, slice_max, count_ptr, cx, cy, cz, radius, rings, segments, baseColor)
    local vCount = (rings + 1) * (segments + 1)
    local tCount = rings * segments * 2
    
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, cx, cy, cz, vCount, tCount, radius)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local tIdx = tStart

    local vIdx = vStart
    for r = 0, rings do
        local v = r / rings
        local phi = v * math.pi
        for s = 0, segments do
            local u = s / segments
            local theta = u * math.pi * 2
            local x = radius * math.sin(phi) * math.cos(theta)
            local y = radius * math.cos(phi)
            local z = radius * math.sin(phi) * math.sin(theta)
            Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = x, y, z
            vIdx = vIdx + 1
        end
    end

    for r = 0, rings - 1 do
        for s = 0, segments - 1 do
            local a = vStart + (r * (segments + 1)) + s
            local b_idx = vStart + (r * (segments + 1)) + s + 1
            local c = vStart + ((r + 1) * (segments + 1)) + s + 1
            local d = vStart + ((r + 1) * (segments + 1)) + s
            local col = ((r + s) % 2 == 0) and baseColor or 0xFF444444
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, b_idx, c; Tri_Color[tIdx] = col; tIdx = tIdx + 1
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, d; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        end
    end
    return id
end

return Factory
