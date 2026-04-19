-- ========================================================================
-- KERNELS/proc_megaknot.lua
-- The Megaknot Generator and Real-Time Topology Colorizer
-- ========================================================================
local bit = require("bit")
local math_sin, math_cos, math_pi = math.sin, math.cos, math.pi
local floor, min, max = math.floor, math.min, math.max

-- A fast HSL to RGB converter for our neon pulses
local function HSLtoRGB(h, s, l)
    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1/6 then return p + (q - p) * 6 * t end
            if t < 1/2 then return q end
            if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
            return p
        end
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue2rgb(p, q, h + 1/3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1/3)
    end
    return floor(r * 255), floor(g * 255), floor(b * 255)
end

return function(
    SLICE_START, Count_Ptr,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
    Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
    Vert_LX, Vert_LY, Vert_LZ, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
    Global_NumVerts, Global_NumTris
)

    -- ==========================================
    -- PHASE 1: THE BIG BANG (Topology Generation)
    -- ==========================================
    local id = SLICE_START
    local vStart = Global_NumVerts[0]
    local tStart = Global_NumTris[0]

    -- Megaknot Parameters
    local P, Q = 3, 7             -- The Knot winding numbers
    local MAJOR_RADIUS = 2500     -- Overall size
    local TUBE_RADIUS = 300       -- Thickness of the knot
    local TUBULAR_SEGMENTS = 400  -- How smooth the knot path is
    local RADIAL_SEGMENTS = 12    -- How round the tube is

    local numVerts = (TUBULAR_SEGMENTS + 1) * (RADIAL_SEGMENTS + 1)
    local numTris = TUBULAR_SEGMENTS * RADIAL_SEGMENTS * 2

    Obj_VertStart[id], Obj_VertCount[id] = vStart, numVerts
    Obj_TriStart[id],  Obj_TriCount[id]  = tStart, numTris
    Obj_Radius[id] = MAJOR_RADIUS + TUBE_RADIUS

    -- Position the Knot deep in the void, rotating on its own
    Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, 0, -25000
    Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
    Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
    Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0

    -- Helper to calculate knot position
    local function calculatePosition(u)
        local cu = math_cos(u)
        local su = math_sin(u)
        local quOverP = Q * u / P
        local cs = math_cos(quOverP)
        
        local r = MAJOR_RADIUS * (2 + cs) * 0.3
        local x = r * cu
        local y = MAJOR_RADIUS * math_sin(quOverP) * 0.3
        local z = r * su
        return x, y, z
    end

    -- BAKE VERTICES
    local vIdx = vStart
    for i = 0, TUBULAR_SEGMENTS do
        local u = i / TUBULAR_SEGMENTS * P * math_pi * 2
        local px, py, pz = calculatePosition(u)
        
        -- Forward vector (Derivative)
        local u_next = u + 0.01
        local nx, ny, nz = calculatePosition(u_next)
        local tx, ty, tz = nx - px, ny - py, nz - pz
        local tLen = math.sqrt(tx*tx + ty*ty + tz*tz)
        tx, ty, tz = tx/tLen, ty/tLen, tz/tLen
        
        -- Normal and Binormal for tube extrusion
        local npx, npy, npz = 0, 1, 0
        if math.abs(ty) > 0.99 then npx, npy, npz = 1, 0, 0 end
        local bx = ty*npz - tz*npy
        local by = tz*npx - tx*npz
        local bz = tx*npy - ty*npx
        local bLen = math.sqrt(bx*bx + by*by + bz*bz)
        bx, by, bz = bx/bLen, by/bLen, bz/bLen
        
        local normal_x = by*tz - bz*ty
        local normal_y = bz*tx - bx*tz
        local normal_z = bx*ty - by*tx

        for j = 0, RADIAL_SEGMENTS do
            local v = j / RADIAL_SEGMENTS * math_pi * 2
            local cx, cy = math_cos(v), math_sin(v)
            
            -- Final vertex position
            local vx = px + TUBE_RADIUS * (cx * normal_x + cy * bx)
            local vy = py + TUBE_RADIUS * (cx * normal_y + cy * by)
            local vz = pz + TUBE_RADIUS * (cx * normal_z + cy * bz)
            
            Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = vx, vy, vz
            vIdx = vIdx + 1
        end
    end
    Global_NumVerts[0] = Global_NumVerts[0] + numVerts

    -- BAKE TRIANGLES
    local tIdx = tStart
    for i = 1, TUBULAR_SEGMENTS do
        for j = 1, RADIAL_SEGMENTS do
            local a = vStart + (RADIAL_SEGMENTS + 1) * (i - 1) + (j - 1)
            local b = vStart + (RADIAL_SEGMENTS + 1) * i + (j - 1)
            local c = vStart + (RADIAL_SEGMENTS + 1) * i + j
            local d = vStart + (RADIAL_SEGMENTS + 1) * (i - 1) + j

            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = a, b, d
            tIdx = tIdx + 1
            Tri_V1[tIdx], Tri_V2[tIdx], Tri_V3[tIdx] = b, c, d
            tIdx = tIdx + 1
        end
    end
    Global_NumTris[0] = Global_NumTris[0] + numTris
    Count_Ptr[0] = 1

    -- ==========================================
    -- PHASE 2: THE HOT LOOP (Topology Vibrance)
    -- ==========================================
    local active_time = 0

    return function(dt)
        active_time = active_time + dt
        
        -- Slowly rotate the Megaknot in space
        local yaw, pitch = active_time * 0.2, active_time * 0.1
        local cy, sy = math_cos(yaw), math_sin(yaw)
        local cp, sp = math_cos(pitch), math_sin(pitch)
        Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = sy * cp, sp, cy * cp
        Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = cy, 0, -sy
        Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = sp * (-sy), (cy * cp) * cy - (sy * cp) * (-sy), -(sp) * cy

        -- IMPERATIVE MEMORY MANIPULATION:
        -- Send a vibrant neon wave traveling through the topology!
        local current_tIdx = tStart
        for i = 1, TUBULAR_SEGMENTS do
            -- Calculate a color phase based on the segment index and time
            local phase = (i / TUBULAR_SEGMENTS) * 10.0 - (active_time * 5.0)
            local intensity = (math_sin(phase) + 1.0) * 0.5 -- Pulses between 0.0 and 1.0
            
            -- Base color is Dark Purple, glowing segments are Neon Cyan/Green
            local hue = 0.7 - (intensity * 0.3)
            local light = 0.1 + (intensity * 0.6)
            
            local r, g, b = HSLtoRGB(hue, 1.0, light)
            local packed_color = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)

            -- Apply this exact color to all radial triangles in this segment
            for j = 1, RADIAL_SEGMENTS * 2 do
                Tri_BakedColor[current_tIdx] = packed_color
                current_tIdx = current_tIdx + 1
            end
        end
    end
end
