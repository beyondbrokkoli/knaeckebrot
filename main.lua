require("sys_memory")
require("MODULES.bench")
State = require("MODULES.state")

local ffi = require("ffi")
local Presentation = require("MODULES.presentation")
local CreateSequence = require("sys_sequence")
local Routine_InitBuffers = require("ROUTINES.init_buffers")
local Routine_BakeLighting = require("ROUTINES.bake_lighting")
local Routine_BakeColors = require("ROUTINES.bake_colors")

local Seq_Physics = CreateSequence()
local Seq_Render = CreateSequence()
local Seq_Camera = CreateSequence()

local ProcGen = require("MODULES.proc_gen")

local HUD_timer = 0
local HUD_frames = 0
local HUD_min_dt, HUD_max_dt, HUD_avg_dt = 999.0, 0.0, 0.0
local Display_FPS, Display_Min, Display_Max, Display_Avg = 0, 0, 0, 0

local Cached_HUD_FPS = ""
local Cached_HUD_Mem = ""
local Cached_HUD_Slide = ""
local Cached_HUD_State = ""
local Cached_HUD_Counts = ""

-- IMPORTANT: Not local anymore, so Presentation can use it
function UpdateCameraBasis()
    local cy, sy = math.cos(MainCamera.yaw), math.sin(MainCamera.yaw)
    local cp, sp = math.cos(MainCamera.pitch), math.sin(MainCamera.pitch)
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy
    MainCamera.upx = MainCamera.fwy * MainCamera.rtz
    MainCamera.upy = MainCamera.fwz * MainCamera.rtx - MainCamera.fwx * MainCamera.rtz
    MainCamera.upz = -MainCamera.fwy * MainCamera.rtx
end

local function BindRenderSequence()
    -- ==========================================
    -- CULLING PASS (Slots 1, 2, 6)
    -- ==========================================
    Seq_Render:Slot(1, "KERNELS.camera_cull",
        Visible_Solid_IDs, Count_Visible_Solid,         -- 1. Integration Pointers
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,                -- 2. Object Bounds
        MainCamera                                      -- 3. System
    )

    Seq_Render:Slot(2, "KERNELS.camera_cull",
        Visible_Kinematic_IDs, Count_Visible_Kinematic, -- 1. Integration Pointers
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,                -- 2. Object Bounds
        MainCamera                                      -- 3. System
    )

    Seq_Render:Slot(6, "KERNELS.camera_cull",
        Visible_Procedural_IDs, Count_Visible_Procedural, -- 1. Integration Pointers
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,                  -- 2. Object Bounds
        MainCamera                                        -- 3. System
    )

    -- ==========================================
    -- RASTERIZATION PASS (Slots 3, 4, 7)
    -- ==========================================
    Seq_Render:Slot(3, "KERNELS.render_rasterize_baked",
        Visible_Solid_IDs, Count_Visible_Solid,                                       -- 1. Visibility Pointers
        Obj_X, Obj_Y, Obj_Z,                                                          -- 2. Object Positions
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,       -- 3. Object Matrices
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,                     -- 4. Geometry Offsets
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, -- 5. Vertices
        Tri_V1, Tri_V2, Tri_V3, Tri_Color, Tri_BakedColor, Tri_A, Tri_R, Tri_G, Tri_B,               -- 6. Triangles & Colors
        MainCamera, ScreenPtr, ZBuffer                                                -- 7. System Singletons
    )

    Seq_Render:Slot(4, "KERNELS.render_rasterize_dynamic",
        Visible_Kinematic_IDs, Count_Visible_Kinematic,                               -- 1. Visibility Pointers
        Obj_X, Obj_Y, Obj_Z,                                                          -- 2. Object Positions
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,       -- 3. Object Matrices
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,                     -- 4. Geometry Offsets
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, -- 5. Vertices
        Tri_V1, Tri_V2, Tri_V3, Tri_Color, Tri_BakedColor, Tri_A, Tri_R, Tri_G, Tri_B,               -- 6. Triangles & Colors
        MainCamera, ScreenPtr, ZBuffer                                                -- 7. System Singletons
    )

    Seq_Render:Slot(7, "KERNELS.render_rasterize_baked",
        Visible_Procedural_IDs, Count_Visible_Procedural,                             -- 1. Visibility Pointers
        Obj_X, Obj_Y, Obj_Z,                                                          -- 2. Object Positions
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,       -- 3. Object Matrices
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,                     -- 4. Geometry Offsets
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, -- 5. Vertices
        Tri_V1, Tri_V2, Tri_V3, Tri_Color, Tri_BakedColor, Tri_A, Tri_R, Tri_G, Tri_B,               -- 6. Triangles & Colors
        MainCamera, ScreenPtr, ZBuffer                                                -- 7. System Singletons
    )

    -- ==========================================
    -- TEXT STAMP PASS (Slot 5)
    -- ==========================================
    Seq_Render:Slot(5, "KERNELS.render_text_stamp",
        SlideTitles, ActiveSlide, EngineState,                                        -- 1. App State Pointers
        Slide_X, Slide_Y, Slide_Z, Slide_NX, Slide_NY, Slide_NZ,                      -- 2. Slide Geometry
        MainCamera, ScreenPtr, ZBuffer                                                -- 3. System Singletons
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
    Seq_Physics:Slot(2, "KERNELS.proc_treadmill",
        SLICE_PROCEDURAL_START, 100, Count_Procedural, -- Updated!
        Obj_X, Obj_Y, Obj_Z, Obj_Radius,
        Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
        NumTotalVerts, NumTotalTris, MainCamera, EngineState, TargetState
    )
    Seq_Camera:Slot(1, "KERNELS.camera_flight", MainCamera, FlightData, EngineState, TargetState, STATE_CINEMATIC)
    BindRenderSequence()

    -- Outsourced generation!
    Presentation.Load(12)

    if Count_Solid[0] > 0 then Routine_BakeLighting(SLICE_SOLID_START, Count_Solid[0]) end
    if NumTotalTris[0] > 0 then Routine_BakeColors(NumTotalTris[0]) end

    State.SetEngine(STATE_FREEFLY)
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
    local ms = dt * 1000
    if ms < HUD_min_dt then HUD_min_dt = ms end
    if ms > HUD_max_dt then HUD_max_dt = ms end
    HUD_avg_dt = HUD_avg_dt + ms
    HUD_frames = HUD_frames + 1
    HUD_timer = HUD_timer + dt

    if HUD_timer >= 1.0 then
        Display_FPS = love.timer.getFPS()
        Display_Min = HUD_min_dt
        Display_Max = HUD_max_dt
        Display_Avg = HUD_avg_dt / HUD_frames
        HUD_min_dt, HUD_max_dt, HUD_avg_dt = 999.0, 0.0, 0.0
        HUD_frames = 0
        HUD_timer = 0

        Cached_HUD_FPS = string.format("FPS: %d | FRAME: %.2fms (Min: %.2fms / Max: %.2fms)", Display_FPS, Display_Avg, Display_Min, Display_Max)
        Cached_HUD_Mem = string.format("LUA HEAP: %.2f MB", collectgarbage("count") / 1024)
        Cached_HUD_Slide = "SLIDE: " .. (TargetSlide[0] + 1) .. " / " .. NumSlides[0]
        Cached_HUD_State = "STATE: " .. State.GetEngineName()
        Cached_HUD_Counts = "SOLIDS: " .. Count_Solid[0] .. " | KINEMATICS: " .. Count_Kinematic[0]

        BENCH.ResetRollingStats()
    end
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

    if EngineState[STATE_FREEFLY] then UpdateFreeflyCamera(dt) end
    Seq_Camera:Run(dt)

    -- Outsourced state checks!
    Presentation.Update(dt)

    if not EngineState[STATE_ZEN] and not EngineState[STATE_HIBERNATED] then
        BENCH.Begin("Physics")
        Seq_Physics:Run(SLICE_KINEMATIC_START, Count_Kinematic[0], dt)
        BENCH.End("Physics")
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
        Count_Visible_Procedural[0] = 0 -- Reset the new counter

        BENCH.Begin("Camera_Cull")
        if Count_Solid[0] > 0 then Seq_Render.Kernels[1](SLICE_SOLID_START, Count_Solid[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        if Count_Kinematic[0] > 0 then Seq_Render.Kernels[2](SLICE_KINEMATIC_START, Count_Kinematic[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        if Count_Procedural[0] > 0 then Seq_Render.Kernels[6](SLICE_PROCEDURAL_START, Count_Procedural[0], CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        BENCH.End("Camera_Cull")

        BENCH.Begin("Rasterize")
        local total_pixels = CANVAS_W * CANVAS_H
        ffi.fill(ScreenPtr, total_pixels * 4, 0)
        ffi.fill(ZBuffer, total_pixels * 4, 0x7F)

        -- Draw Opaque/Baked geometry first
        if Count_Solid[0] > 0 then Seq_Render.Kernels[3](CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        if Count_Procedural[0] > 0 then Seq_Render.Kernels[7](CANVAS_W, CANVAS_H, HALF_W, HALF_H) end

        -- Draw Dynamic geometry last
        if Count_Kinematic[0] > 0 then Seq_Render.Kernels[4](CANVAS_W, CANVAS_H, HALF_W, HALF_H) end
        BENCH.End("Rasterize")

        BENCH.Begin("Text_Stamp")
        if Seq_Render.Kernels[5] then Seq_Render.Kernels[5](CANVAS_W, CANVAS_H, HALF_W, HALF_H, MasterTextAlpha) end
        BENCH.End("Text_Stamp")

        ScreenImage:replacePixels(ScreenBuffer)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")

    love.graphics.setColor(0, 1, 0, 1)
    if Font_UI then love.graphics.setFont(Font_UI) end

    love.graphics.print(Cached_HUD_FPS, 20, 20)
    love.graphics.print(Cached_HUD_Mem, 20, 40)
    love.graphics.print(Cached_HUD_Slide, 20, 60)
    love.graphics.print(Cached_HUD_State, 20, 80)
    love.graphics.print(Cached_HUD_Counts, 20, 100)

    love.graphics.setColor(1, 1, 1, 1)

    if EngineState[STATE_ZEN] or EngineState[STATE_HIBERNATED] then
        snapshotBaked = true
    end
end

function love.keypressed(key)
    if key == "escape" then love.event.quit()
    elseif key == "j" then
        isMouseCaptured = not isMouseCaptured
        love.mouse.setRelativeMode(isMouseCaptured)
    else
        -- Outsourced logic!
        Presentation.KeyPressed(key)
    end
end

function love.mousemoved(x, y, dx, dy)
    if isMouseCaptured and EngineState[STATE_FREEFLY] then
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
