-- ========================================================================
-- MODULES/presentation.lua
-- The Spherical Whispering Gallery (Lightweight Edition)
-- ========================================================================
local Factory = require("sys_factory")
local Presentation = {}

local function normalize(x, y, z)
    local len = math.sqrt(x*x + y*y + z*z)
    if len == 0 then return 0, 0, 0 end
    return x/len, y/len, z/len
end

local function cross(ax, ay, az, bx, by, bz)
    return ay*bz - az*by, az*bx - ax*bz, ax*by - ay*bx
end

local function BuildDish(vx, vy, vz, ux, uy, uz, focal_length, num_slides)
    ux, uy, uz = normalize(ux, uy, uz)
    
    local rx, ry, rz
    if math.abs(uy) > 0.99 then
        rx, ry, rz = 1, 0, 0
    else
        rx, ry, rz = cross(ux, uy, uz, 0, 1, 0)
        rx, ry, rz = normalize(rx, ry, rz)
    end
    local fwx, fwy, fwz = cross(rx, ry, rz, ux, uy, uz)

    local C_CREAM = 4294306522
    local C_LATTE = 4292131280

    for i = 0, num_slides - 1 do
        local t = i / math.max(1, (num_slides - 1))
        local radius = math.sqrt(t) * 4000  
        local angle = i * 2.39996323

        local u = math.sin(angle) * radius
        local v = math.cos(angle) * radius
        local w = (radius * radius) / (4 * focal_length)

        local px = vx + rx*u + fwx*v + ux*w
        local py = vy + ry*u + fwy*v + uy*w
        local pz = vz + rz*u + fwz*v + uz*w

        local nx = (-u / (2 * focal_length)) * rx + (-v / (2 * focal_length)) * fwx + 1.0 * ux
        local ny = (-u / (2 * focal_length)) * ry + (-v / (2 * focal_length)) * fwy + 1.0 * uy
        local nz = (-u / (2 * focal_length)) * rz + (-v / (2 * focal_length)) * fwz + 1.0 * uz
        nx, ny, nz = normalize(nx, ny, nz)

        local target_fwx, target_fwy, target_fwz = -nx, -ny, -nz
        local pitch = math.asin(math.max(-1, math.min(1, target_fwy)))
        local yaw = math.atan2(target_fwx, target_fwz)

        local color = (i % 2 == 0) and C_CREAM or C_LATTE

        -- Thinned out panels (1400x1400) to create cool gaps!
        Factory.CreateSlideMesh(SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid, px, py, pz, yaw, pitch, 1400, 1400, 100, color)
    end
end

function Presentation.Load()
    local D = 7000         
    local FOCAL = 3500     
    local SLIDES_PER_DISH = 30 -- Reduced count for a skeletal look

    BuildDish( D, 0, 0,   -1, 0, 0,  FOCAL, SLIDES_PER_DISH)
    BuildDish(-D, 0, 0,    1, 0, 0,  FOCAL, SLIDES_PER_DISH)
    BuildDish(0,  D, 0,    0,-1, 0,  FOCAL, SLIDES_PER_DISH)
    BuildDish(0, -D, 0,    0, 1, 0,  FOCAL, SLIDES_PER_DISH)
    BuildDish(0, 0,  D,    0, 0,-1,  FOCAL, SLIDES_PER_DISH)
    BuildDish(0, 0, -D,    0, 0, 1,  FOCAL, SLIDES_PER_DISH)
end
-- Empty stubs so main.lua doesn't crash when it attempts to call them
function Presentation.Update(dt) end
--function Presentation.KeyPressed(key) end
function Presentation.KeyPressed(key)
    if EngineState[STATE_FREEFLY] and (key == "p" or key == "space") then
        lastFreeX, lastFreeY, lastFreeZ = MainCamera.x, MainCamera.y, MainCamera.z
        lastFreeYaw, lastFreePitch = MainCamera.yaw, MainCamera.pitch
        State.SetTarget(STATE_PRESENT)
        Presentation.TriggerContinuousFlight()
    elseif not EngineState[STATE_FREEFLY] and (key == "left" or key == "right") then
        local oldTarget = TargetSlide[0]
        if key == "right" then
            TargetSlide[0] = (TargetSlide[0] + 1) % NumSlides[0]
        elseif key == "left" then
            TargetSlide[0] = (TargetSlide[0] - 1 + NumSlides[0]) % NumSlides[0]
        end
        if TargetSlide[0] ~= oldTarget then Presentation.ExecuteSlideTransition() end
    elseif key == "i" or key == "u" then
        State.SetEngine(STATE_FREEFLY)
        State.SetTarget(STATE_FREEFLY)
        if key == "u" then
            MainCamera.x, MainCamera.y, MainCamera.z = lastFreeX, lastFreeY, lastFreeZ
            MainCamera.yaw, MainCamera.pitch = lastFreeYaw, lastFreePitch
            UpdateCameraBasis()
        end
    elseif key == "z" then
        if EngineState[STATE_FREEFLY] then return end
        local tempState = EngineState[STATE_PRESENT] and STATE_ZEN or STATE_PRESENT
        State.SetTarget(tempState)
        Presentation.TriggerContinuousFlight()
    end
end
return Presentation
