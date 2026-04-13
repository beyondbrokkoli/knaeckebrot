-- ========================================================================
-- sys_factory.lua
-- The DOD Allocator. Claims memory slices and writes geometry.
-- ========================================================================
local ffi = require("ffi")
local bit = require("bit")
local pi, cos, sin, floor = math.pi, math.cos, math.sin, math.floor
local sqrt = math.sqrt

local Factory = {}

-- ==========================================
-- CORE FFI ALLOCATOR (Replaces CreateTriObject)
-- ==========================================
function Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, vCount, tCount, radius)
    -- 1. Get the current active count for this specific slice
    local current_count = count_ptr[0]
    local id = slice_start + current_count

    -- 2. Prevent Memory Overflows
    if id > slice_max then
        print("[FACTORY ERROR] Slice Overflow! Cannot allocate ID " .. id)
        return nil
    end

    -- 3. Claim the memory slot by incrementing the shared pointers
    count_ptr[0] = current_count + 1
    NumObjects[0] = NumObjects[0] + 1

    -- 4. Spatial Setup
    Obj_X[id], Obj_Y[id], Obj_Z[id] = x, y, z
    Obj_Yaw[id], Obj_Pitch[id] = 0, 0
    Obj_VelX[id], Obj_VelY[id], Obj_VelZ[id] = 0, 0, 0
    Obj_RotSpeedYaw[id], Obj_RotSpeedPitch[id] = 0, 0
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

-- ==========================================
-- GEOMETRY PRIMITIVES
-- ==========================================

function Factory.CreateSlideMesh(slice_start, slice_max, count_ptr, x, y, z, w, h, thickness, color)
    local maxDiagonal = sqrt((w/2)^2 + (h/2)^2 + (thickness/2)^2)
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, 8, 12, maxDiagonal)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local hw, hh, ht = w/2, h/2, thickness/2

    local verts = {
        {-hw, -hh, -ht}, {hw, -hh, -ht}, {hw, hh, -ht}, {-hw, hh, -ht},
        {-hw, -hh,  ht}, {hw, -hh,  ht}, {hw, hh,  ht}, {-hw, hh,  ht}
    }

    for i, v in ipairs(verts) do
        local vIdx = vStart + (i - 1)
        Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = v[1], v[2], v[3]
    end

    local indices = {
        0,2,1, 0,3,2, 4,5,6, 4,6,7, 0,1,5, 0,5,4,
        1,2,6, 1,6,5, 2,3,7, 2,7,6, 3,0,4, 3,4,7
    }

    for i = 1, #indices, 3 do
        local tIdx = tStart + floor((i-1)/3)
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = indices[i] + vStart, indices[i+1] + vStart, indices[i+2] + vStart
        Tri_Color[tIdx] = color
    end
    return id
end

function Factory.CreatePropCube(slice_start, slice_max, count_ptr, x, y, z, size, color)
    local maxDiagonal = sqrt(3 * (size/2)^2)
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, 8, 12, maxDiagonal)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local hs = size / 2

    local verts = {
        {-hs, -hs, -hs}, {hs, -hs, -hs}, {hs, hs, -hs}, {-hs, hs, -hs},
        {-hs, -hs,  hs}, {hs, -hs,  hs}, {hs, hs,  hs}, {-hs, hs,  hs}
    }

    for i, v in ipairs(verts) do
        local vIdx = vStart + (i - 1)
        Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = v[1], v[2], v[3]
    end

    local indices = {
        0,2,1, 0,3,2, 4,5,6, 4,6,7, 0,1,5, 0,5,4,
        1,2,6, 1,6,5, 2,3,7, 2,7,6, 3,0,4, 3,4,7
    }

    for i = 1, #indices, 3 do
        local tIdx = tStart + floor((i-1)/3)
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = indices[i] + vStart, indices[i+1] + vStart, indices[i+2] + vStart
        Tri_Color[tIdx] = color
    end
    return id
end

function Factory.CreatePropPyramid(slice_start, slice_max, count_ptr, x, y, z, size, color)
    local maxDiagonal = sqrt(size^2 + size^2 + size^2)
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, 5, 6, maxDiagonal)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local verts = {
        {0, size, 0}, {-size, -size, -size}, {size, -size, -size},
        {size, -size, size}, {-size, -size, size}
    }

    for i, v in ipairs(verts) do
        local vIdx = vStart + (i - 1)
        Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = v[1], v[2], v[3]
    end

    local indices = { 0,1,2, 0,2,3, 0,3,4, 0,4,1, 1,4,3, 1,3,2 }

    for i = 1, #indices, 3 do
        local tIdx = tStart + floor((i-1)/3)
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = vStart + indices[i], vStart + indices[i+1], vStart + indices[i+2]
        Tri_Color[tIdx] = color
    end
    return id
end

function Factory.CreateDataSpike(slice_start, slice_max, count_ptr, x, y, z, height, color)
    local w = height * 0.3
    local maxDiagonal = sqrt(w^2 + height^2)
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, 6, 8, maxDiagonal)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local verts = {
        {0, height, 0}, {0, -height, 0},
        {w, 0, w}, {w, 0, -w}, {-w, 0, -w}, {-w, 0, w}
    }

    for j, v in ipairs(verts) do
        local vIdx = vStart + (j - 1)
        Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = v[1], v[2], v[3]
    end

    local indices = { 0,2,3, 0,3,4, 0,4,5, 0,5,2, 1,3,2, 1,4,3, 1,5,4, 1,2,5 }

    for j = 1, #indices, 3 do
        local tIdx = tStart + floor((j-1)/3)
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = indices[j] + vStart, indices[j+1] + vStart, indices[j+2] + vStart
        Tri_Color[tIdx] = color
    end
    return id
end

function Factory.CreateTorus(slice_start, slice_max, count_ptr, cx, cy, cz, mainRadius, tubeRadius, segments, sides, baseColor)
    local vCount = segments * sides
    local tCount = segments * sides * 2
    local bound = mainRadius + tubeRadius

    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, cx, cy, cz, vCount, tCount, bound)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
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

            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx
            Tri_Color[tIdx] = col; tIdx = tIdx + 1

            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c
            Tri_Color[tIdx] = col; tIdx = tIdx + 1
        end
    end
    return id
end

function Factory.CreateTerminalSlide(slice_start, slice_max, count_ptr, x, y, z, w, h, thickness, color)
    local maxDiagonal = sqrt((w/2)^2 + (h/2)^2 + (thickness/2)^2)
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, x, y, z, 8, 12, maxDiagonal)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    local hw, hh, ht = w/2, h/2, thickness/2

    local verts = {
        {-hw, -hh, -ht}, {hw, -hh, -ht}, {hw, hh, -ht}, {-hw, hh, -ht},
        {-hw, -hh, ht}, {hw, -hh, ht}, {hw, hh, ht}, {-hw, hh, ht}
    }
    for i, v in ipairs(verts) do
        local vIdx = vStart + (i - 1)
        Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = v[1], v[2], v[3]
    end

    local indices = {
        0,2,1, 0,3,2, 4,5,6, 4,6,7, 0,1,5, 0,5,4,
        1,2,6, 1,6,5, 2,3,7, 2,7,6, 3,0,4, 3,4,7
    }
    for i = 1, #indices, 3 do
        local tIdx = tStart + floor((i-1)/3)
        Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = indices[i] + vStart, indices[i+1] + vStart, indices[i+2] + vStart
        Tri_Color[tIdx] = color
    end

    return id
end
-- ========================================================================
-- DOD TORUS KNOT GENERATOR
-- ========================================================================
function Factory.CreateTorusKnot(slice_start, slice_max, count_ptr, cx, cy, cz, scale, tubeRadius, p, q, segments, sides, baseColor)
    local vCount, tCount = segments * sides, segments * sides * 2
    local id = Factory.AllocateObject(slice_start, slice_max, count_ptr, cx, cy, cz, vCount, tCount, scale * 3)
    if not id then return nil end

    local vStart, tStart = Obj_VertStart[id], Obj_TriStart[id]
    
    local function getKnotPos(u)
        local theta = u * pi * 2
        local r = scale * (2 + cos(p * theta))
        return r * cos(q * theta), r * sin(p * theta), r * sin(q * theta)
    end

    -- 1. Calculate Frenet-Serret Frames and Vertices
    for i = 0, segments - 1 do
        local u = i / segments
        local p1 = {getKnotPos(u)}
        local p2 = {getKnotPos((i + 1) / segments)}
        local T = {p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]}
        local B = {p1[1] + p2[1], p1[2] + p2[2], p1[3] + p2[3]}
        local N = {T[2]*B[3] - T[3]*B[2], T[3]*B[1] - T[1]*B[3], T[1]*B[2] - T[2]*B[1]}
        
        local lenN = math.sqrt(N[1]^2 + N[2]^2 + N[3]^2)
        if lenN == 0 then lenN = 1 end
        N = {N[1]/lenN, N[2]/lenN, N[3]/lenN}
        
        local bitan = {T[2]*N[3] - T[3]*N[2], T[3]*N[1] - T[1]*N[3], T[1]*N[2] - T[2]*N[1]}
        local lenB = math.sqrt(bitan[1]^2 + bitan[2]^2 + bitan[3]^2)
        if lenB == 0 then lenB = 1 end
        bitan = {bitan[1]/lenB, bitan[2]/lenB, bitan[3]/lenB}

        for j = 0, sides - 1 do
            local v_angle = (j / sides) * pi * 2
            local cosV, sinV = cos(v_angle) * tubeRadius, sin(v_angle) * tubeRadius
            local vIdx = vStart + i * sides + j
            Vert_LX[vIdx] = p1[1] + cosV * N[1] + sinV * bitan[1]
            Vert_LY[vIdx] = p1[2] + cosV * N[2] + sinV * bitan[2]
            Vert_LZ[vIdx] = p1[3] + cosV * N[3] + sinV * bitan[3]
        end
    end

    -- 2. Stitch the Triangles
    local tIdx = tStart
    for i = 0, segments - 1 do
        local next_i = (i + 1) % segments
        for j = 0, sides - 1 do
            local next_j = (j + 1) % sides
            local a, b_idx = vStart + i * sides + j, vStart + next_i * sides + j
            local c, d = vStart + next_i * sides + next_j, vStart + i * sides + next_j
            
            -- Checkerboard styling
            local col = ((i + j) % 2 == 0) and baseColor or 0xFF444444
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, c, b_idx; Tri_Color[tIdx] = col; tIdx = tIdx + 1
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, d, c; Tri_Color[tIdx] = col; tIdx = tIdx + 1
        end
    end
    return id
end

-- ========================================================================
-- THE MEGAKNOT WRAPPER
-- Completely decoupled from the old "api" injection.
-- ========================================================================
function Factory.CreateMegaknot(slice_start, slice_max, count_ptr, x, y, z)
    -- FFI Endianness: AABBGGRR. Hot Magenta!
    local magenta = 0xFFFF00FF 
    
    -- Parameters: radius=1500, tube=400, p=4, q=9
    -- Resolution: 800 segments * 150 sides = 120,000 Vertices & 240,000 Triangles
    local id = Factory.CreateTorusKnot(
        slice_start, slice_max, count_ptr, 
        x, y, z, 
        1500, 400, 4, 9, 
        800, 150, magenta
    )
    
    if id then
        -- Override default allocations
        Obj_HomeIdx[id] = -1
        Obj_VelX[id], Obj_VelY[id], Obj_VelZ[id] = 0, 0, 0
        Obj_RotSpeedYaw[id] = 0.8
        Obj_RotSpeedPitch[id] = -0.4
    end
    
    return id
end
return Factory
