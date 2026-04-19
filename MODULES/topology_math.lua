local math_sin, math_cos, math_pi, sqrt, abs = math.sin, math.cos, math.pi, math.sqrt, math.abs

local Topology = {
    P = 3,
    Q = 7,
    TUBULAR_SEGMENTS = 400,
    RADIAL_SEGMENTS = 12
}

function Topology.GetLiveVertex(u_idx, v_idx, active_time, MainCamera)
    local u = u_idx / Topology.TUBULAR_SEGMENTS * Topology.P * math_pi * 2
    local v = v_idx / Topology.RADIAL_SEGMENTS * math_pi * 2
    
    local function getSpine(t)
        local qu = Topology.Q * t / Topology.P
        local r = 200 * (2 + math_cos(qu))
        return r * math_cos(t), 200 * math_sin(qu), r * math_sin(t)
    end

    local px, py, pz = getSpine(u)
    local nx, ny, nz = getSpine(u + 0.01)
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

    local tube_radius = 40 
    local cosV, sinV = math_cos(v) * tube_radius, math_sin(v) * tube_radius
    px = px + normX * cosV + bx * sinV
    py = py + normY * cosV + by * sinV
    pz = pz + normZ * cosV + bz * sinV

    local yaw, pitch = active_time * 0.2, active_time * 0.1
    local cy, sy, cp, sp = math_cos(yaw), math_sin(yaw), math_cos(pitch), math_sin(pitch)
    local wx = px * cy + pz * sy + MainCamera.x
    local wy = py * cp - (pz * cy - px * sy) * sp + MainCamera.y
    local wz = (pz * cy - px * sy) * cp + py * sp + MainCamera.z + 600

    local vdx, vdy, vdz = wx - MainCamera.x, wy - MainCamera.y, wz - MainCamera.z
    local cz = vdx * MainCamera.fwx + vdy * MainCamera.fwy + vdz * MainCamera.fwz
    
    if cz < 0.1 then return nil, nil, nil end
    local f = MainCamera.fov / cz
    return (vdx * MainCamera.rtx + vdz * MainCamera.rtz) * f, 
           (vdx * MainCamera.upx + vdy * MainCamera.upy + vdz * MainCamera.upz) * f, 
           cz
end

return Topology
