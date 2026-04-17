require("sys_memory")
require("MODULES.bench")

local ffi = require("ffi")
local CreateSequence = require("sys_sequence")
local Factory = require("sys_factory")
local Routine_InitBuffers = require("ROUTINES.init_buffers") -- New
local Routine_InitText = require("ROUTINES.init_slide_text")
local Routine_BakeLighting = require("ROUTINES.bake_lighting")
local Routine_BakeColors = require("ROUTINES.bake_colors")

local Seq_Physics = CreateSequence()
local Seq_Render = CreateSequence()
local Seq_Camera = CreateSequence()

local function lerp(a, b, t) return a + (b - a) * t end
local function lerpAngle(a, b, t)
    local diff = (b - a + math.pi) % (math.pi * 2) - math.pi
    return a + diff * t
end

local function UpdateCameraBasis()
    local cy, sy = math.cos(MainCamera.yaw), math.sin(MainCamera.yaw)
    local cp, sp = math.cos(MainCamera.pitch), math.sin(MainCamera.pitch)
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy
    MainCamera.upx = MainCamera.fwy * MainCamera.rtz
    MainCamera.upy = MainCamera.fwz * MainCamera.rtx - MainCamera.fwx * MainCamera.rtz
    MainCamera.upz = -MainCamera.fwy * MainCamera.rtx
end

local function updateTargetSide()
    local sx, sy, sz, nx, ny, nz, w, h
    local id = TargetSlide[0]
    if NumSlides[0] == 0 or id >= NumSlides[0] then return end

    sx, sy, sz = Slide_X[id], Slide_Y[id], Slide_Z[id]
    nx, ny, nz = Slide_NX[id], Slide_NY[id], Slide_NZ[id]
    w, h = Slide_W[id], Slide_H[id]

    local distScale = math.max(h, w * (CANVAS_H / CANVAS_W))
    local pad = (TargetState[0] == STATE_ZEN) and 0 or 200
    local dist = (distScale * MainCamera.fov) / CANVAS_H * 1.0 + pad

    local fx, fy, fz = sx + nx * dist, sy + ny * dist, sz + nz * dist
    local bx, by, bz = sx - nx * dist, sy - ny * dist, sz - nz * dist

    local dF = (fx - MainCamera.x)^2 + (fy - MainCamera.y)^2 + (fz - MainCamera.z)^2
    local dB = (bx - MainCamera.x)^2 + (by - MainCamera.y)^2 + (bz - MainCamera.z)^2

    local dx, dy, dz
    if dF <= dB then
        print(string.format("[GATEKEEPER] Routing -> FRONT face. (dF: %.1f <= dB: %.1f)", dF, dB))
        FlightData.tx, FlightData.ty, FlightData.tz = fx, fy, fz
        dx, dy, dz = sx - fx, sy - fy, sz - fz
    else
        print(string.format("[GATEKEEPER] Routing -> BACK face. (dF: %.1f > dB: %.1f)", dF, dB))
        FlightData.tx, FlightData.ty, FlightData.tz = bx, by, bz
        dx, dy, dz = sx - bx, sy - by, sz - bz
    end

    FlightData.tyaw = math.atan2(dx, dz)
    FlightData.tpitch = math.atan2(dy, math.sqrt(dx*dx + dz*dz))

    print(string.format("[GATEKEEPER] Final Flight Target: Pos(%.1f, %.1f, %.1f) | Angles(Yaw: %.2f, Pitch: %.2f)",
        FlightData.tx, FlightData.ty, FlightData.tz, FlightData.tyaw, FlightData.tpitch))
    print("[GATEKEEPER] ------------------------------------------------\n")
end

local function TriggerContinuousFlight()
    updateTargetSide("TriggerContinuousFlight")
    FlightData.sx, FlightData.sy, FlightData.sz = MainCamera.x, MainCamera.y, MainCamera.z
    FlightData.syaw, FlightData.spitch = MainCamera.yaw, MainCamera.pitch
    FlightData.lerpT = 0
    EngineState[0] = STATE_CINEMATIC
    snapshotBaked = false
end

local function ExecuteSlideTransition()
    if EngineState[0] == STATE_ZEN or EngineState[0] == STATE_HIBERNATED then
        updateTargetSide("ExecuteSlideTransition [Snap to ZEN]")
        MainCamera.x, MainCamera.y, MainCamera.z = FlightData.tx, FlightData.ty, FlightData.tz
        MainCamera.yaw, MainCamera.pitch = FlightData.tyaw, FlightData.tpitch
        EngineState[0] = STATE_ZEN
        TargetState[0] = STATE_ZEN
        ActiveSlide[0] = TargetSlide[0]
        MasterTextAlpha = 1.0
        snapshotBaked = false
        UpdateCameraBasis()
    else
        TargetState[0] = STATE_PRESENT
        TriggerContinuousFlight()
    end
end

local function BindRenderSequence()
    -- 1. Cull Solids
    Seq_Render:Slot(1, "KERNELS.camera_cull",
        Visible_Solid_IDs, Count_Visible_Solid, Obj_X, Obj_Y, Obj_Z, Obj_Radius, MainCamera
    )
    -- 2. Cull Kinematics
    Seq_Render:Slot(2, "KERNELS.camera_cull",
        Visible_Kinematic_IDs, Count_Visible_Kinematic, Obj_X, Obj_Y, Obj_Z, Obj_Radius, MainCamera
    )
    -- 3. Rasterize Solids (Baked Lighting)
    Seq_Render:Slot(3, "KERNELS.render_rasterize_baked",
        Visible_Solid_IDs, Count_Visible_Solid, Obj_X, Obj_Y, Obj_Z,
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_Color, Tri_R, Tri_G, Tri_B,
        Tri_BaseLight, MainCamera, ScreenPtr, ZBuffer
    )
    -- 4. Rasterize Kinematics (Dynamic Lighting)
    Seq_Render:Slot(4, "KERNELS.render_rasterize_dynamic_fog",
        Visible_Kinematic_IDs, Count_Visible_Kinematic, Obj_X, Obj_Y, Obj_Z,
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_Color, Tri_R, Tri_G, Tri_B,
        MainCamera, ScreenPtr, ZBuffer
    )
    Seq_Render:Slot(5, "KERNELS.render_text_stamp",
        SlideTitles, ActiveSlide, EngineState,
        Slide_X, Slide_Y, Slide_Z, Slide_NX, Slide_NY, Slide_NZ, -- Changed!
        MainCamera, ScreenPtr, ZBuffer
    )
end

function love.load()
    Routine_InitBuffers()
    Font_UI = love.graphics.newFont(12)

    MainCamera.x, MainCamera.y, MainCamera.z = 0, 0, -400
    MainCamera.yaw, MainCamera.pitch = 0, 0
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = 0, 0, 1
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = 1, 0, 0
    MainCamera.upx, MainCamera.upy, MainCamera.upz = 0, 1, 0

    Seq_Physics:Slot(1, "KERNELS.phys_kinematics",
        Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ,
        Obj_Yaw, Obj_Pitch, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        UniverseCage,
        Count_BoundSphere, BoundSphere_X, BoundSphere_Y, BoundSphere_Z, BoundSphere_RSq, BoundSphere_Mode,
        Count_BoundBox, BoundBox_X, BoundBox_Y, BoundBox_Z, BoundBox_HW, BoundBox_HH, BoundBox_HT,
        BoundBox_FWX, BoundBox_FWY, BoundBox_FWZ, BoundBox_RTX, BoundBox_RTY, BoundBox_RTZ, BoundBox_UPX, BoundBox_UPY, BoundBox_UPZ, BoundBox_Mode
    )
    Seq_Camera:Slot(1, "KERNELS.camera_flight", MainCamera, FlightData, EngineState, TargetState, STATE_CINEMATIC)
    BindRenderSequence()

    local C_CREAM = 4294306522
    local C_LATTE = 4292131280

    local num_slides = 12
    local radius = 3500
    local height_step = 800

    for i = 0, num_slides - 1 do
        local angle = (i / num_slides) * math.pi * 4 -- 2 full rotations
        local sx = math.sin(angle) * radius
        local sy = i * height_step
        local sz = math.cos(angle) * radius

        -- Slide faces inward toward the center pillar
        local yaw = angle + math.pi
        local pitch = -0.1 -- Slight tilt upwards

        local color = (i % 2 == 0) and C_CREAM or C_LATTE

        local slide_id = Factory.CreateSlideMesh(
            SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid,
            sx, sy, sz, yaw, pitch,
            1600, 900, 40, color
        )

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

        -- Decorate the path with spinning shapes
        local cube_id = Factory.CreatePropCube(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, sx, sy + 700, sz, 150, 0xFF00FFFF)
        Obj_RotSpeedYaw[cube_id] = 1.5
        Obj_RotSpeedPitch[cube_id] = 1.0

        local spike_id = Factory.CreateDataSpike(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, sx + math.cos(yaw)*1200, sy, sz - math.sin(yaw)*1200, 300, 0xFFFF00FF)
        Obj_RotSpeedYaw[spike_id] = -2.0

        -- Add a structural center pillar piece every few slides
        if i % 3 == 0 then
            local torus_id = Factory.CreateTorus(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 0, sy, 0, 1000, 100, 32, 12, 0xFF00FF00)
            Obj_RotSpeedYaw[torus_id] = 0.5
            Obj_RotSpeedPitch[torus_id] = 0.2
        end
    end

    NumSlides[0] = num_slides

    Routine_InitText(manifest, SlideTitles, MainCamera.fov, CANVAS_W, CANVAS_H)

    -- Factory.CreateMegaknot(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 0, 0, 8000)
    -- Factory.CreatePropCube(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 0, 0, 600, 100, 0xFF0000FF)

    -- THE MISSING EXECUTION: Bake the lighting for all solid and kinematic objects!
    if Count_Solid[0] > 0 then
        Routine_BakeLighting(SLICE_SOLID_START, Count_Solid[0])
    end
    -- Extract all hex colors into fast flat floats!
    if NumTotalTris[0] > 0 then
        Routine_BakeColors(NumTotalTris[0])
    end
    EngineState[0] = STATE_FREEFLY
end

local function UpdateFreeflyCamera(dt)
    local s = 2000 * dt
    if love.keyboard.isDown("w") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x + MainCamera.fwx * s, MainCamera.y + MainCamera.fwy * s, MainCamera.z + MainCamera.fwz * s end
    if love.keyboard.isDown("s") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x - MainCamera.fwx * s, MainCamera.y - MainCamera.fwy * s, MainCamera.z - MainCamera.fwz * s end
    if love.keyboard.isDown("a") then MainCamera.x, MainCamera.z = MainCamera.x - MainCamera.rtx * s, MainCamera.z - MainCamera.rtz * s end
    if love.keyboard.isDown("d") then MainCamera.x, MainCamera.z = MainCamera.x + MainCamera.rtx * s, MainCamera.z + MainCamera.rtz * s end
    if love.keyboard.isDown("e") then MainCamera.y = MainCamera.y - s end
    if love.keyboard.isDown("q") then MainCamera.y = MainCamera.y + s end

    local rotSpeed = 2.5 * dt
    if love.keyboard.isDown("left") then MainCamera.yaw = MainCamera.yaw - rotSpeed end
    if love.keyboard.isDown("right") then MainCamera.yaw = MainCamera.yaw + rotSpeed end
    if love.keyboard.isDown("up") then MainCamera.pitch = MainCamera.pitch - rotSpeed end
    if love.keyboard.isDown("down") then MainCamera.pitch = MainCamera.pitch + rotSpeed end

    MainCamera.pitch = math.max(-1.56, math.min(1.56, MainCamera.pitch))
    UpdateCameraBasis()
end

function love.update(dt)
    dt = math.min(dt, 0.033)

    if pendingResize then
        resizeTimer = resizeTimer - dt
        if resizeTimer <= 0 then
            Routine_InitBuffers()
            BindRenderSequence()
            pendingResize = false
        end
        return
    end

    if EngineState[0] == STATE_FREEFLY then
        UpdateFreeflyCamera(dt)
    end
    Seq_Camera:Run(dt)
    -- PERFECT MATCH TO OLD SysText.Update(EngineState, dt)
    local targetAlpha = (EngineState[0] >= STATE_PRESENT) and 1.0 or 0.0
    local alphaSpeed = (EngineState[0] == STATE_CINEMATIC) and 50.0 or 3.3

    if MasterTextAlpha < targetAlpha then
        MasterTextAlpha = math.min(targetAlpha, MasterTextAlpha + dt * alphaSpeed)
    elseif MasterTextAlpha > targetAlpha then
        MasterTextAlpha = math.max(targetAlpha, MasterTextAlpha - dt * alphaSpeed)
    end

    if MasterTextAlpha <= 0.01 then ActiveSlide[0] = TargetSlide[0] end

    local isTextReady = (MasterTextAlpha == targetAlpha)

    -- THE HIBERNATION ENGINE
    if EngineState[0] == STATE_HIBERNATED then
        if snapshotBaked then love.timer.sleep(0.25) end
    else
        snapshotBaked = false
    end

    if EngineState[0] == STATE_ZEN and isTextReady then
        EngineState[0] = STATE_HIBERNATED
    end

    if EngineState[0] ~= STATE_ZEN and EngineState[0] ~= STATE_HIBERNATED then
        BENCH.Run("Physics", function()
            Seq_Physics:Run(SLICE_KINEMATIC_START, Count_Kinematic[0], dt)
        end)
    end
end

function love.draw()
    if pendingResize then
        love.graphics.clear(0.05, 0.05, 0.05)
        if Font_UI then love.graphics.setFont(Font_UI) end
        love.graphics.print("REBUILDING SWAPCHAIN...", 20, 20)
        return
    end

    if not snapshotBaked then
        Count_Visible_Solid[0] = 0
        Count_Visible_Kinematic[0] = 0

        BENCH.Run("Camera_Cull", function()
            if Count_Solid[0] > 0 then Seq_Render.Kernels[1](SLICE_SOLID_START, Count_Solid[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
            if Count_Kinematic[0] > 0 then Seq_Render.Kernels[2](SLICE_KINEMATIC_START, Count_Kinematic[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        end)

        BENCH.Run("Rasterize", function()
            -- Clear the screen ONE time, before both kernels run!
            local total_pixels = CANVAS_W * CANVAS_H
            ffi.fill(ScreenPtr, total_pixels * 4, 0)
            ffi.fill(ZBuffer, total_pixels * 4, 0x7F)

            if Count_Solid[0] > 0 then Seq_Render.Kernels[3](CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
            if Count_Kinematic[0] > 0 then Seq_Render.Kernels[4](CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        end)

        BENCH.Run("Text_Stamp", function()
            if Seq_Render.Kernels[5] then Seq_Render.Kernels[5](CANVAS_W, CANVAS_H, HALF_W, HALF_H, MasterTextAlpha) end
        end)

        ScreenImage:replacePixels(ScreenBuffer)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(0, 1, 0, 1)
    if Font_UI then love.graphics.setFont(Font_UI) end

    love.graphics.print("FPS: " .. love.timer.getFPS(), 20, 20)
    love.graphics.print("SLIDE: " .. (TargetSlide[0] + 1) .. " / " .. NumSlides[0], 20, 40)

    local stateNames = {"FREEFLY", "CINEMATIC", "PRESENT", "ZEN", "HIBERNATED"}
    love.graphics.print("STATE: " .. stateNames[EngineState[0] + 1], 20, 60)
    love.graphics.print("SOLIDS: " .. Count_Solid[0] .. " | KINEMATICS: " .. Count_Kinematic[0], 20, 80)

    love.graphics.setColor(1, 1, 1, 1)

    if EngineState[0] == STATE_ZEN or EngineState[0] == STATE_HIBERNATED then
        snapshotBaked = true
    end
end
function love.keypressed(key)
    if key == "escape" then love.event.quit()
    elseif key == "j" then
        isMouseCaptured = not isMouseCaptured
        love.mouse.setRelativeMode(isMouseCaptured)
    elseif EngineState[0] == STATE_FREEFLY and (key == "p" or key == "space") then
        lastFreeX, lastFreeY, lastFreeZ = MainCamera.x, MainCamera.y, MainCamera.z
        lastFreeYaw, lastFreePitch = MainCamera.yaw, MainCamera.pitch
        TargetState[0] = STATE_PRESENT
        TriggerContinuousFlight()
    elseif EngineState[0] ~= STATE_FREEFLY and (key == "left" or key == "right") then
        local oldTarget = TargetSlide[0]
        if key == "right" then
            TargetSlide[0] = (TargetSlide[0] + 1) % NumSlides[0]
        elseif key == "left" then
            TargetSlide[0] = (TargetSlide[0] - 1 + NumSlides[0]) % NumSlides[0]
        end
        if TargetSlide[0] ~= oldTarget then ExecuteSlideTransition() end

    elseif key == "i" or key == "u" then
        EngineState[0] = STATE_FREEFLY; TargetState[0] = STATE_FREEFLY
        if key == "u" then
            MainCamera.x, MainCamera.y, MainCamera.z = lastFreeX, lastFreeY, lastFreeZ
            MainCamera.yaw, MainCamera.pitch = lastFreeYaw, lastFreePitch
            UpdateCameraBasis()
        end

    elseif key == "z" then
        if EngineState[0] == STATE_FREEFLY then return end
        TargetState[0] = (EngineState[0] == STATE_PRESENT) and STATE_ZEN or STATE_PRESENT
        TriggerContinuousFlight()
    end
end

function love.mousemoved(x, y, dx, dy)
    if isMouseCaptured and EngineState[0] == STATE_FREEFLY then
        local sensitivity = 0.002
        MainCamera.yaw = MainCamera.yaw + (dx * sensitivity)
        MainCamera.pitch = MainCamera.pitch + (dy * sensitivity)
        MainCamera.pitch = math.max(-1.56, math.min(1.56, MainCamera.pitch))
        UpdateCameraBasis()
    end
end

function love.resize(w, h)
    pendingResize = true
    resizeTimer = 0.2
end
