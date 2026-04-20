-- ========================================================================
-- MODULES/presentation.lua
-- The Spherical Whispering Gallery (Pure Physics Playground)
-- ========================================================================
local Factory = require("sys_factory")
local Presentation = {}

-- Quick Vector Math Helpers
local function normalize(x, y, z)
    local len = math.sqrt(x*x + y*y + z*z)
    if len == 0 then return 0, 0, 0 end
    return x/len, y/len, z/len
end

local function cross(ax, ay, az, bx, by, bz)
    return ay*bz - az*by, az*bx - ax*bz, ax*by - ay*bx
end

-- ========================================================================
-- THE PARABOLA FORGE
-- Generates a parabolic dish facing ANY arbitrary direction
-- ========================================================================
local function BuildDish(vx, vy, vz, ux, uy, uz, focal_length, num_slides)
    -- (vx, vy, vz) is the Vertex (bottom center of the bowl)
    -- (ux, uy, uz) is the "Up" vector (the direction the bowl OPENS towards)
    ux, uy, uz = normalize(ux, uy, uz)

    -- Generate an arbitrary orthogonal basis (Right and Forward vectors)
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
        -- math.sqrt(t) ensures the area distribution is uniform!
        -- Without sqrt, slides cluster tightly in the center and leave gaps at the rim.
        local t = i / math.max(1, (num_slides - 1))
        local radius = math.sqrt(t) * 4000  

        local angle = i * 2.39996323 -- The Golden Angle

        -- Local Parabola Coordinates
        local u = math.sin(angle) * radius
        local v = math.cos(angle) * radius
        local w = (radius * radius) / (4 * focal_length)

        -- 1. Matrix Transform: Local to World Space Position
        local px = vx + rx*u + fwx*v + ux*w
        local py = vy + ry*u + fwy*v + uy*w
        local pz = vz + rz*u + fwz*v + uz*w

        -- 2. Calculus Gradient to find the World Normal vector
        -- The gradient of the parabolic surface w - (u^2+v^2)/4F = 0
        local nx = (-u / (2 * focal_length)) * rx + (-v / (2 * focal_length)) * fwx + 1.0 * ux
        local ny = (-u / (2 * focal_length)) * ry + (-v / (2 * focal_length)) * fwy + 1.0 * uy
        local nz = (-u / (2 * focal_length)) * rz + (-v / (2 * focal_length)) * fwz + 1.0 * uz
        nx, ny, nz = normalize(nx, ny, nz)

        -- 3. Convert Normal to Yaw/Pitch
        -- In our engine, the face normal is -FW, so FW must equal -Normal
        local target_fwx, target_fwy, target_fwz = -nx, -ny, -nz
        local pitch = math.asin(math.max(-1, math.min(1, target_fwy)))
        local yaw = math.atan2(target_fwx, target_fwz)

        local color = (i % 2 == 0) and C_CREAM or C_LATTE

        -- Use MASSIVE overlapping panels (2400x2400) with 200 thickness to seal all gaps!
        Factory.CreateSlideMesh(SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid, px, py, pz, yaw, pitch, 2400, 2400, 200, color)
    end
end

-- ========================================================================
-- THE CONSTELLATION BUILDER
-- ========================================================================
function Presentation.Load()
    local D = 7000         -- Distance from the origin to the back of the dish
    local FOCAL = 3500     -- The focus point relative to the dish vertex
    
    -- We have a hard limit of 399 objects in the SOLID memory slice.
    -- 65 slides * 6 dishes = 390 objects. A perfect fit.
    local SLIDES_PER_DISH = 65 

    -- Pair 1: X-Axis (Facing inward towards origin)
    BuildDish( D, 0, 0,   -1, 0, 0,  FOCAL, SLIDES_PER_DISH)
    BuildDish(-D, 0, 0,    1, 0, 0,  FOCAL, SLIDES_PER_DISH)

    -- Pair 2: Y-Axis 
    BuildDish(0,  D, 0,    0,-1, 0,  FOCAL, SLIDES_PER_DISH)
    BuildDish(0, -D, 0,    0, 1, 0,  FOCAL, SLIDES_PER_DISH)

    -- Pair 3: Z-Axis
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
