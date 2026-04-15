-- ========================================================================
-- main.lua
-- ========================================================================
require("sys_memory")
require("core/bench")
local CreateSequence = require("sys_sequence")
local Factory = require("sys_factory")

local Seq_Physics = CreateSequence()
local Seq_Render = CreateSequence()
-- ========================================================================
-- HELPER FUNCTIONS
-- ========================================================================
local pendingResize = false
local resizeTimer = 0
local isMouseCaptured = false

local function UpdateCameraBasis()
    local cy, sy = math.cos(MainCamera.yaw), math.sin(MainCamera.yaw)
    local cp, sp = math.cos(MainCamera.pitch), math.sin(MainCamera.pitch)

    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy

    MainCamera.upx = MainCamera.fwy * MainCamera.rtz
    MainCamera.upy = MainCamera.fwz * MainCamera.rtx - MainCamera.fwx * MainCamera.rtz
    MainCamera.upz = -MainCamera.fwy * MainCamera.rtx
end

-- We must call this on Boot AND on Resize to lock in the new pointers!
local function BindRenderSequence()
--    Seq_Render:Slot(1, "KERNELS.camera_cull_dumb", Visible_IDs, Count_Visible)
-- Replace camera_cull_dumb with camera_cull_smart
    -- Notice we must now pass Obj_X, Y, Z, and Obj_Radius into the binding!
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
        MainCamera, ScreenPtr, ZBuffer -- <-- These pointers change on resize!
    )
end
function love.load()
    ReinitBuffers()

    -- 1. Camera Setup
    MainCamera.x, MainCamera.y, MainCamera.z = 0, 0, -400
    MainCamera.yaw, MainCamera.pitch = 0, 0
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = 0, 0, 1
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = 1, 0, 0
    MainCamera.upx, MainCamera.upy, MainCamera.upz = 0, 1, 0

    -- 2. Bind Physics
    Seq_Physics:Slot(1, "KERNELS.phys_kinematics",
        Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ,
        Obj_Yaw, Obj_Pitch, Obj_RotSpeedYaw, Obj_RotSpeedPitch,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ
    )

    BindRenderSequence()

    -- 4. Spawn the Universe
    -- A nice dark backing platform
    -- Factory.CreateSlideMesh(
        --SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid,
        --0, -200, 800,
        --800, 20, 800,   -- <--- THE FIX: w=800, h=20, thickness=800
        --0xFF555555      -- Slightly lighter grey so the light catches it
    --)

    -- THE HIGHLY DETAILED DONUT
    -- Cranked to 64 segments and 32 sides for that smooth, buttery geometry!
    --local torus_id = Factory.CreateTorus(
       -- SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic,
       -- 0, 0, 500,     -- Perfectly centered, just inside the frustum
       -- 120, 45,       -- Fat, chunky proportions
       -- 64, 32,        -- High-Poly Resolution
       -- 0xFFDD8800     -- AABBGGRR (Results in a gorgeous Azure/Teal with the Lambertian Shading)
    --)

    --if torus_id then
      --  Obj_RotSpeedYaw[torus_id] = 1.5
      --  Obj_RotSpeedPitch[torus_id] = 2.2
    --end
    -- Delete or comment out the old standard Torus, and summon the boss:
    Factory.CreateMegaknot(
        SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 
        0, 0, 8000 -- Pushed way back so the massive 1500 radius fits on screen
    )
end
-- ========================================================================
-- ENGINE TICKS
-- ========================================================================
function love.update(dt)
    dt = math.min(dt, 0.033)

    -- 1. Handle Debounced Resizing
    if pendingResize then
        resizeTimer = resizeTimer - dt
        if resizeTimer <= 0 then
            ReinitBuffers()
            BindRenderSequence() -- Re-lock the closures to the new buffers!
            pendingResize = false
        end
        return -- Skip physics and camera logic while the window is rebuilding
    end

    -- 2. Freefly Camera Movement (WASD + EQ)
    local s = 2000 * dt
    if love.keyboard.isDown("w") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x + MainCamera.fwx * s, MainCamera.y + MainCamera.fwy * s, MainCamera.z + MainCamera.fwz * s end
    if love.keyboard.isDown("s") then MainCamera.x, MainCamera.y, MainCamera.z = MainCamera.x - MainCamera.fwx * s, MainCamera.y - MainCamera.fwy * s, MainCamera.z - MainCamera.fwz * s end
    if love.keyboard.isDown("a") then MainCamera.x, MainCamera.z = MainCamera.x - MainCamera.rtx * s, MainCamera.z - MainCamera.rtz * s end
    if love.keyboard.isDown("d") then MainCamera.x, MainCamera.z = MainCamera.x + MainCamera.rtx * s, MainCamera.z + MainCamera.rtz * s end
    if love.keyboard.isDown("e") then MainCamera.y = MainCamera.y - s end
    if love.keyboard.isDown("q") then MainCamera.y = MainCamera.y + s end

    -- ========================================================
    -- VIRTUALBOX DEBUG FIX: Arrow Key Camera Rotation
    -- ========================================================
    local rotSpeed = 2.5 * dt
    if love.keyboard.isDown("left") then MainCamera.yaw = MainCamera.yaw - rotSpeed end
    if love.keyboard.isDown("right") then MainCamera.yaw = MainCamera.yaw + rotSpeed end
    if love.keyboard.isDown("up") then MainCamera.pitch = MainCamera.pitch - rotSpeed end
    if love.keyboard.isDown("down") then MainCamera.pitch = MainCamera.pitch + rotSpeed end

    -- Clamp pitch to prevent flipping upside down (approx 90 degrees)
    MainCamera.pitch = math.max(-1.56, math.min(1.56, MainCamera.pitch))
    -- ========================================================

    -- 3. Calculate new basis vectors based on mouse/keyboard movement
    UpdateCameraBasis()

    -- 4. Run Physics Sequence
    -- Seq_Physics:Run(SLICE_KINEMATIC_START, Count_Kinematic[0], dt)
    -- 4. Run Physics Sequence (MEASURED)
    BENCH.Run("Physics", function()
        Seq_Physics:Run(SLICE_KINEMATIC_START, Count_Kinematic[0], dt)
    end)
end
function love.draw()
    if pendingResize then
        love.graphics.clear(0.05, 0.05, 0.05)
        love.graphics.print("REBUILDING SWAPCHAIN...", 20, 20)
        return
    end

    Count_Visible[0] = 0

    -- MEASURE CULLING
    -- BENCH.Run("Camera_Cull", function()
        -- local CullKernel = Seq_Render.Kernels[1]
        -- if CullKernel then
            -- if Count_Solid[0] > 0 then CullKernel(SLICE_SOLID_START, Count_Solid[0]) end
            -- if Count_Kinematic[0] > 0 then CullKernel(SLICE_KINEMATIC_START, Count_Kinematic[0]) end
            -- if Count_Autonomous[0] > 0 then CullKernel(SLICE_AUTONOMOUS_START, Count_Autonomous[0]) end
            -- if Count_DeepSpace[0] > 0 then CullKernel(SLICE_DEEP_SPACE_START, Count_DeepSpace[0]) end
        -- end
    -- end)
    BENCH.Run("Camera_Cull", function()
        local CullKernel = Seq_Render.Kernels[1]
        if CullKernel then
            -- Pass CANVAS_W, CANVAS_H, HALF_W, HALF_H so the culler knows the screen size!
            if Count_Solid[0] > 0 then CullKernel(SLICE_SOLID_START, Count_Solid[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
            if Count_Kinematic[0] > 0 then CullKernel(SLICE_KINEMATIC_START, Count_Kinematic[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
            if Count_Autonomous[0] > 0 then CullKernel(SLICE_AUTONOMOUS_START, Count_Autonomous[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
            if Count_DeepSpace[0] > 0 then CullKernel(SLICE_DEEP_SPACE_START, Count_DeepSpace[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        end
    end)
    -- MEASURE RASTERIZATION
    BENCH.Run("Rasterize", function()
        local RasterKernel = Seq_Render.Kernels[2]
        if RasterKernel then
            RasterKernel(CANVAS_W, CANVAS_H, HALF_W, HALF_H)
        end
    end)

    -- Blit the 3D buffer to the screen
    ScreenImage:replacePixels(ScreenBuffer)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")
    -- ========================================================
    -- THE PERFORMANCE HUD
    -- ========================================================
    -- Terminal Green color for that hacker aesthetic
    love.graphics.setColor(0, 1, 0.5, 1)

    local y_offset = 10
    local line_height = 15
    local x_offset = 10

    -- Standard FPS
    love.graphics.print("FPS: " .. love.timer.getFPS(), x_offset, y_offset)
    y_offset = y_offset + line_height * 2

    -- DOD Pipeline Stats
    love.graphics.print("--- KERNEL TIMES ---", x_offset, y_offset)
    y_offset = y_offset + line_height

    love.graphics.print("Physics  | " .. BENCH.GetStats("Physics"), x_offset, y_offset)
    y_offset = y_offset + line_height

    love.graphics.print("Cull     | " .. BENCH.GetStats("Camera_Cull"), x_offset, y_offset)
    y_offset = y_offset + line_height

    love.graphics.print("Raster   | " .. BENCH.GetStats("Rasterize"), x_offset, y_offset)
    y_offset = y_offset + line_height * 2

    -- Universe Stats
    love.graphics.print("--- UNIVERSE ---", x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Total Objects : " .. NumObjects[0], x_offset, y_offset)
    y_offset = y_offset + line_height
    love.graphics.print("Visible IDs   : " .. Count_Visible[0], x_offset, y_offset)

end

-- ========================================================================
-- INPUT & EVENTS
-- ========================================================================
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "j" then
        isMouseCaptured = not isMouseCaptured
        love.mouse.setRelativeMode(isMouseCaptured)
    end
end

function love.mousemoved(x, y, dx, dy)
    if isMouseCaptured then
        local sensitivity = 0.002
        MainCamera.yaw = MainCamera.yaw + (dx * sensitivity)
        MainCamera.pitch = MainCamera.pitch + (dy * sensitivity)

        -- Clamp pitch so you don't flip upside down
        MainCamera.pitch = math.max(-1.56, math.min(1.56, MainCamera.pitch))
    end
end

function love.resize(w, h)
    pendingResize = true
    resizeTimer = 0.2
end
