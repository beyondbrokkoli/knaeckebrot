-- ========================================================================
-- MODULES/presentation.lua
-- The Deterministic Slide Controller
-- ========================================================================
local ffi = require("ffi")
local State = require("MODULES.state")
local Factory = require("sys_factory")
local Routine_InitText = require("ROUTINES.init_slide_text")

local Presentation = {}

function Presentation.UpdateTargetSide()
    local sx, sy, sz, nx, ny, nz, w, h
    local id = TargetSlide[0]
    if NumSlides[0] == 0 or id >= NumSlides[0] then return end

    sx, sy, sz = Slide_X[id], Slide_Y[id], Slide_Z[id]
    nx, ny, nz = Slide_NX[id], Slide_NY[id], Slide_NZ[id]
    w, h = Slide_W[id], Slide_H[id]

    local distScale = math.max(h, w * (CANVAS_H / CANVAS_W))
    local pad = TargetState[STATE_ZEN] and 0 or 200
    local dist = (distScale * MainCamera.fov) / CANVAS_H * 1.0 + pad

    local fx, fy, fz = sx + nx * dist, sy + ny * dist, sz + nz * dist
    local bx, by, bz = sx - nx * dist, sy - ny * dist, sz - nz * dist

    local dF = (fx - MainCamera.x)^2 + (fy - MainCamera.y)^2 + (fz - MainCamera.z)^2
    local dB = (bx - MainCamera.x)^2 + (by - MainCamera.y)^2 + (bz - MainCamera.z)^2

    local dx, dy, dz
    if dF <= dB then
        -- print(string.format("[GATEKEEPER] Routing -> FRONT face. (dF: %.1f <= dB: %.1f)", dF, dB))
        FlightData.tx, FlightData.ty, FlightData.tz = fx, fy, fz
        dx, dy, dz = sx - fx, sy - fy, sz - fz
    else
        -- print(string.format("[GATEKEEPER] Routing -> BACK face. (dF: %.1f > dB: %.1f)", dF, dB))
        FlightData.tx, FlightData.ty, FlightData.tz = bx, by, bz
        dx, dy, dz = sx - bx, sy - by, sz - bz
    end

    FlightData.tyaw = math.atan2(dx, dz)
    FlightData.tpitch = math.atan2(dy, math.sqrt(dx*dx + dz*dz))
end

function Presentation.TriggerContinuousFlight()
    Presentation.UpdateTargetSide()
    FlightData.sx, FlightData.sy, FlightData.sz = MainCamera.x, MainCamera.y, MainCamera.z
    FlightData.syaw, FlightData.spitch = MainCamera.yaw, MainCamera.pitch
    FlightData.lerpT = 0

    State.SetEngine(STATE_CINEMATIC)
    snapshotBaked = false
end

function Presentation.ExecuteSlideTransition()
    if EngineState[STATE_ZEN] or EngineState[STATE_HIBERNATED] then
        Presentation.UpdateTargetSide()
        MainCamera.x, MainCamera.y, MainCamera.z = FlightData.tx, FlightData.ty, FlightData.tz
        MainCamera.yaw, MainCamera.pitch = FlightData.tyaw, FlightData.tpitch

        State.SetEngine(STATE_ZEN)
        State.SetTarget(STATE_ZEN)

        ActiveSlide[0] = TargetSlide[0]
        MasterTextAlpha = 1.0
        snapshotBaked = false
        UpdateCameraBasis() -- Must be global in main.lua
    else
        State.SetTarget(STATE_PRESENT)
        Presentation.TriggerContinuousFlight()
    end
end

function Presentation.Load(num_slides)
    num_slides = num_slides or 12
    local C_CREAM = 4294306522
    local C_LATTE = 4292131280
    local radius = 3500
    local height_step = 800

    for i = 0, num_slides - 1 do
        local angle = (i / num_slides) * math.pi * 4
        local sx = math.sin(angle) * radius
        local sy = i * height_step
        local sz = math.cos(angle) * radius
        local yaw = angle + math.pi
        local pitch = -0.1

        local color = (i % 2 == 0) and C_CREAM or C_LATTE

        Factory.CreateSlideMesh(SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid, sx, sy, sz, yaw, pitch, 1600, 900, 40, color)

        manifest[i] = {
            title = "SPIRAL ASCENT: LEVEL " .. string.format("%02d", i + 1),
            content = {
                "~ \27[36mTELEMETRY:\27[0m X:" .. math.floor(sx) .. " | Y:" .. math.floor(sy) .. " | Z:" .. math.floor(sz),
                "",
                "The DOD engine now fully supports 6-DOF slide positioning.",
                "Notice how the text matrices seamlessly track the rotated normals.",
                (i % 2 == 0) and "# All geometry shares a single rasterization pass." or "# Physics and collision spheres are fully bound.",
                "",
                "~ \27[33mPress Right Arrow to Ascend.\27[0m"
            }
        }

        local objects_per_slide = 25
        local colors = {0xFF00FFFF, 0xFFFF00FF, 0xFFFFFF00, 0xFF00FF00, 0xFFFF4400}

        for j = 1, objects_per_slide do
            local px = sx + math.random(-800, 800)
            local py = sy + math.random(200, 1500)
            local pz = sz + math.random(-800, 800)
            local size = math.random(50, 150)
            local prop_color = colors[math.random(1, #colors)]
            local shape_type = math.random(1, 3)
            local id = nil

            if shape_type == 1 then id = Factory.CreatePropCube(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, px, py, pz, size, prop_color)
            elseif shape_type == 2 then id = Factory.CreatePropPyramid(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, px, py, pz, size, prop_color)
            else id = Factory.CreateDataSpike(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, px, py, pz, size * 1.5, prop_color) end

            if id then
                Obj_VelX[id], Obj_VelY[id], Obj_VelZ[id] = math.random(-2000, 2000), math.random(-1000, 2500), math.random(-2000, 2000)
                Obj_RotSpeedYaw[id], Obj_RotSpeedPitch[id] = math.random(-50, 50) / 10.0, math.random(-50, 50) / 10.0
            end
        end

        if i % 3 == 0 then
            local torus_id = Factory.CreateTorus(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 0, sy, 0, 1000, 100, 32, 12, 0xFF00FF00)
            if torus_id then 
                Obj_RotSpeedYaw[torus_id] = 0.5
                Obj_RotSpeedPitch[torus_id] = 0.2
            end
        end

        Factory.CreateBoundSphere(sx, sy, sz, 1200, 1)

        for k = 1, 8 do
            local cx = sx + math.random(-400, 400)
            local cy = sy + math.random(-400, 400)
            local cz = sz + math.random(-400, 400)
            local cube_id = Factory.CreatePropCube(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, cx, cy, cz, 60, 0xFF888888)

            if cube_id then
                Obj_VelX[cube_id], Obj_VelY[cube_id], Obj_VelZ[cube_id] = math.random(-1500, 1500), math.random(-1500, 1500), math.random(-1500, 1500)
                Obj_RotSpeedYaw[cube_id], Obj_RotSpeedPitch[cube_id] = math.random(-40, 40) / 10.0, math.random(-40, 40) / 10.0
            end
        end
    end

    NumSlides[0] = num_slides
    Routine_InitText(manifest, SlideTitles, MainCamera.fov, CANVAS_W, CANVAS_H)
end

function Presentation.Update(dt)
    local targetAlpha = (EngineState[STATE_PRESENT] or EngineState[STATE_ZEN] or EngineState[STATE_HIBERNATED]) and 1.0 or 0.0
    local alphaSpeed = EngineState[STATE_CINEMATIC] and 50.0 or 3.3

    if MasterTextAlpha < targetAlpha then
        MasterTextAlpha = math.min(targetAlpha, MasterTextAlpha + dt * alphaSpeed)
    elseif MasterTextAlpha > targetAlpha then
        MasterTextAlpha = math.max(targetAlpha, MasterTextAlpha - dt * alphaSpeed)
    end

    if MasterTextAlpha <= 0.01 then ActiveSlide[0] = TargetSlide[0] end

    local isTextReady = (MasterTextAlpha == targetAlpha)

    if EngineState[STATE_HIBERNATED] then
        if snapshotBaked then love.timer.sleep(0.25) end
    else
        snapshotBaked = false
    end

    if EngineState[STATE_ZEN] and isTextReady then
        State.SetEngine(STATE_HIBERNATED)
    end
end

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
