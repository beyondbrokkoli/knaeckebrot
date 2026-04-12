-- ========================================================================
-- main.lua
-- ========================================================================
require("sys_memory") -- Populates the global environment with our SoA
local CreateSequence = require("sys_sequence")
local Factory = require("sys_factory")

-- Instantiate our specific execution pipelines
local Seq_Physics = CreateSequence()
local Seq_Render  = CreateSequence()

function love.load()
    ReinitBuffers()
-- ==========================================
    -- WAKE UP THE CAMERA
    -- ==========================================
    MainCamera.x, MainCamera.y, MainCamera.z = 0, 0, -400
    MainCamera.yaw, MainCamera.pitch = 0, 0
    
    -- Identity Basis Vectors (Looking straight down positive Z)
    MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = 0, 0, 1
    MainCamera.rtx, MainCamera.rty, MainCamera.rtz = 1, 0, 0
    MainCamera.upx, MainCamera.upy, MainCamera.upz = 0, 1, 0
    -- ==========================================
    -- WIRING THE RENDER SEQUENCE
    -- ==========================================
    -- Notice how we wire the shared FFI Counters here!

    Seq_Render:Slot(1, "KERNELS.camera_cull_dumb", Visible_IDs, Count_Visible)

    Seq_Render:Slot(2, "KERNELS.render_rasterize",
        Visible_IDs, Count_Visible,
        Obj_X, Obj_Y, Obj_Z,
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ,
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
        Vert_LX, Vert_LY, Vert_LZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid,
        Tri_V1, Tri_V2, Tri_V3, Tri_Color,
        MainCamera, ScreenPtr, ZBuffer
    )
-- 1. Spawn a giant static slide base into the Solid Slice
Factory.CreateSlideMesh(
    SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid,
    0, 0, 800,      -- x, y, z (Pushed out into the screen)
    500, 300, 20,   -- width, height, thickness
    0x00FF00        -- Green
)

-- 2. Spawn a Kinematic Torus that we will make spin!
local torus_id = Factory.CreateTorus(
    SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic,
    0, 0, 600,      -- x, y, z (Slightly closer to camera)
    100, 30,        -- mainRadius, tubeRadius
    16, 8,          -- segments, sides
    0xFF0000        -- Red
)

-- Because we have the direct ID, we can initialize its physics state manually:
if torus_id then
    Obj_RotSpeedYaw[torus_id] = 2.0
    Obj_RotSpeedPitch[torus_id] = 1.0
end

end

function love.update(dt)
    dt = math.min(dt, 0.033)
    
    -- 1. Reset shared dynamic counters
    Count_Visible[0] = 0
    
    -- 2. Execute the Physics sequence. 
    -- We pass the specific memory slices we want it to process!
    Seq_Physics:Run(SLICE_KINEMATIC_START, Count_Kinematic[0], dt)
end

--function love.draw()
    -- 3. Execute the Render sequence.
    -- Cull calculates the visible IDs, Rasterize draws them.
    -- Seq_Render:Run(SLICE_KINEMATIC_START, Count_Kinematic[0])
--end
function love.draw()
    -- 1. Reset the buffer counter for the new frame
    Count_Visible[0] = 0
    
    -- 2. Build the Visibility List (Feed it the slices!)
    -- (We access Kernel 1 directly here because we need to loop it over different slices)
    local CullKernel = Seq_Render.Kernels[1]
    if CullKernel then
        if Count_Solid[0] > 0 then CullKernel(SLICE_SOLID_START, Count_Solid[0]) end
        if Count_Kinematic[0] > 0 then CullKernel(SLICE_KINEMATIC_START, Count_Kinematic[0]) end
        if Count_Autonomous[0] > 0 then CullKernel(SLICE_AUTONOMOUS_START, Count_Autonomous[0]) end
        if Count_DeepSpace[0] > 0 then CullKernel(SLICE_DEEP_SPACE_START, Count_DeepSpace[0]) end
    end
    
    -- 3. Execute the Rasterizer!
    local RasterKernel = Seq_Render.Kernels[2]
    if RasterKernel then
        -- Pass the dynamic window size into the kernel
        RasterKernel(CANVAS_W, CANVAS_H, HALF_W, HALF_H)
    end
    
    -- 4. Blit to the LOVE2D Window
    ScreenImage:replacePixels(ScreenBuffer)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("replace")
    love.graphics.draw(ScreenImage, 0, 0)
    love.graphics.setBlendMode("alpha")
end
