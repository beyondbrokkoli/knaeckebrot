-- ========================================================================
-- main.lua
-- ========================================================================
require("sys_memory")
require("core/bench")
require("sys_init")
require("sys_state")

local CreateSequence = require("sys_sequence")
local Factory = require("sys_factory")

local Seq_Physics = CreateSequence()
local Seq_Render = CreateSequence()

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

    sx, sy, sz = Box_X[id], Box_Y[id], Box_Z[id]
    nx, ny, nz = Box_NX[id], Box_NY[id], Box_NZ[id]
    w, h = Box_HW[id] * 2, Box_HH[id] * 2

    local distScale = math.max(h, w * (CANVAS_H / CANVAS_W))
    local pad = (TargetState[0] == STATE_ZEN) and 0 or 200
    local dist = (distScale * MainCamera.fov) / CANVAS_H * 1.0 + pad

    local fx, fy, fz = sx + nx * dist, sy + ny * dist, sz + nz * dist
    local bx, by, bz = sx - nx * dist, sy - ny * dist, sz - nz * dist

    local dF = (fx - MainCamera.x)^2 + (fy - MainCamera.y)^2 + (fz - MainCamera.z)^2
    local dB = (bx - MainCamera.x)^2 + (by - MainCamera.y)^2 + (bz - MainCamera.z)^2

    local dx, dy, dz
    if dF <= dB then
        tX, tY, tZ = fx, fy, fz
        dx, dy, dz = sx - fx, sy - fy, sz - fz
    else
        tX, tY, tZ = bx, by, bz
        dx, dy, dz = sx - bx, sy - by, sz - bz
    end

    tYaw = math.atan2(dx, dz)
    tPitch = math.atan2(dy, math.sqrt(dx*dx + dz*dz))
end

local function TriggerContinuousFlight()
    updateTargetSide()
    startX, startY, startZ = MainCamera.x, MainCamera.y, MainCamera.z
    startYaw, startPitch = MainCamera.yaw, MainCamera.pitch
    lerpT = 0
    EngineState[0] = STATE_CINEMATIC
    snapshotBaked = false
end

local function ExecuteSlideTransition()
    if EngineState[0] == STATE_ZEN or EngineState[0] == STATE_HIBERNATED then
        updateTargetSide()
        MainCamera.x, MainCamera.y, MainCamera.z = tX, tY, tZ
        MainCamera.yaw, MainCamera.pitch = tYaw, tPitch
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
    Seq_Render:Slot(1, "KERNELS.camera_cull_smart",
        Visible_IDs, Count_Visible,
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        MainCamera
    )
    Seq_Render:Slot(2, "KERNELS.render_rasterize",
        Visible_IDs, Count_Visible,
        Obj_X, Obj_Y, Obj_Z,
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_Color,
        MainCamera, ScreenPtr, ZBuffer
    )
    -- NEW STAMPER BINDING!
    Seq_Render:Slot(3, "KERNELS.render_text_stamp",
        SlideTitles, ActiveSlide, EngineState,
        Obj_X, Obj_Y, Obj_Z,
        MainCamera, ScreenPtr, ZBuffer
    )
end

function love.load()
    ReinitBuffers()
    Font_UI = love.graphics.newFont(14)

    MainCamera.x, MainCamera.y, MainCamera.z = 0, 0, -400
    MainCamera.yaw, MainCamera.pitch = 0, 0
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = 0, 0, 1
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = 1, 0, 0
    MainCamera.upx, MainCamera.upy, MainCamera.upz = 0, 1, 0

    Seq_Physics:Slot(1, "KERNELS.phys_kinematics",
        Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ,
        Obj_Yaw, Obj_Pitch, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ
    )

    BindRenderSequence()

    Factory.CreateSlideMesh(
        SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid,
        0, 0, 800,
        800, 450, 20,
        0xFF555555
    )

    manifest[0] = {
        title = "KFC CRISPNESS RESTORED",
        content = {
            "Welcome back to the absolute pinnacle of DOD engine design.",
            "",
            "~ \27[36m1:1 Pixel Mapping\27[0m | \27[33mZen Mode Hibernation\27[0m",
            "",
            "# This text runs at true zero allocations per frame."
        }
    }
    NumSlides[0] = 1

    Routine_InitText(manifest, SlideTitles, MainCamera.fov, CANVAS_W, CANVAS_H)

    Factory.CreateMegaknot(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 0, 0, 8000)
    Factory.CreatePropCube(SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 0, 0, 600, 100, 0xFF0000FF)

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
            ReinitBuffers()
            BindRenderSequence()
            pendingResize = false
        end
        return
    end

    if EngineState[0] == STATE_FREEFLY then
        UpdateFreeflyCamera(dt)
    elseif EngineState[0] == STATE_CINEMATIC then
        lerpT = math.min(1.0, lerpT + dt * 1.5)
        local easeT = 1 - (1 - lerpT) * (1 - lerpT)

        MainCamera.x = lerp(startX, tX, easeT)
        MainCamera.y = lerp(startY, tY, easeT)
        MainCamera.z = lerp(startZ, tZ, easeT)
        MainCamera.yaw = lerpAngle(startYaw, tYaw, easeT)
        MainCamera.pitch = lerpAngle(startPitch, tPitch, easeT)
        UpdateCameraBasis()

        if lerpT >= 1.0 then
            MainCamera.x, MainCamera.y, MainCamera.z = tX, tY, tZ
            MainCamera.yaw, MainCamera.pitch = tYaw, tPitch
            UpdateCameraBasis()
            EngineState[0] = TargetState[0]
        end
    end

    -- ALPHA FADING MACHINE
    local targetAlpha = (EngineState[0] >= STATE_PRESENT) and 1.0 or 0.0
    local alphaSpeed = (EngineState[0] == STATE_CINEMATIC) and 5.0 or 3.0

    if MasterTextAlpha < targetAlpha then
        MasterTextAlpha = math.min(targetAlpha, MasterTextAlpha + dt * alphaSpeed)
    elseif MasterTextAlpha > targetAlpha then
        MasterTextAlpha = math.max(targetAlpha, MasterTextAlpha - dt * alphaSpeed)
    end

    -- SLIDE SWITCH SYNC
    if MasterTextAlpha <= 0.01 then
        ActiveSlide[0] = TargetSlide[0]
    end

    -- HIBERNATION ENGINE
    local isTextReady = (MasterTextAlpha == targetAlpha)

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

    -- ONLY RASTERIZE IF NOT HIBERNATING
    if not snapshotBaked then
        Count_Visible[0] = 0

        BENCH.Run("Camera_Cull", function()
            local CullKernel = Seq_Render.Kernels[1]
            if CullKernel then
                if Count_Solid[0] > 0 then CullKernel(SLICE_SOLID_START, Count_Solid[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
                if Count_Kinematic[0] > 0 then CullKernel(SLICE_KINEMATIC_START, Count_Kinematic[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
            end
        end)

        BENCH.Run("Rasterize", function()
            local RasterKernel = Seq_Render.Kernels[2]
            if RasterKernel then RasterKernel(CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        end)

        BENCH.Run("Text_Stamp", function()
            local TextKernel = Seq_Render.Kernels[3]
            if TextKernel then TextKernel(CANVAS_W, CANVAS_H, MasterTextAlpha) end
        end)

        ScreenImage:replacePixels(ScreenBuffer)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")

    if Font_UI then love.graphics.setFont(Font_UI) end
    love.graphics.setColor(0, 1, 0.5, 1)

    local y_offset = 10
    local line_height = 15
    local x_offset = 10

    love.graphics.print("FPS: " .. love.timer.getFPS(), x_offset, y_offset)
    y_offset = y_offset + line_height * 2

    love.graphics.print("--- KERNEL TIMES ---", x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Physics | " .. BENCH.GetStats("Physics"), x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Cull    | " .. BENCH.GetStats("Camera_Cull"), x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Raster  | " .. BENCH.GetStats("Rasterize"), x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Text    | " .. BENCH.GetStats("Text_Stamp"), x_offset, y_offset)
    y_offset = y_offset + line_height * 2

    love.graphics.print("--- UNIVERSE ---", x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Total Objects : " .. NumObjects[0], x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Visible IDs   : " .. Count_Visible[0], x_offset, y_offset)

    -- Flag the hibernation lock
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

