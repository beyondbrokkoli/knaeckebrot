-- ========================================================================
-- main.lua
-- ========================================================================
require("sys_memory") -- Populates the global environment with our SoA
local CreateSequence = require("sys_sequence")
loacl Factory = require("sys_factory")

-- Instantiate our specific execution pipelines
local Seq_Physics = CreateSequence()
local Seq_Render  = CreateSequence()

function love.load()
    ReinitBuffers()

    -- ==========================================
    -- WIRING THE PHYSICS SEQUENCE
    -- ==========================================
    Seq_Physics:Slot(1, "KERNELS.phys_kinematic", 
        Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ
    )
    -- Seq_Physics:Slot(2, "KERNELS.phys_collision", ...) 

    -- ==========================================
    -- WIRING THE RENDER SEQUENCE
    -- ==========================================
    -- Notice how we wire the shared FFI Counters here!
    -- Seq_Render:Slot(1, "KERNELS.camera_cull",
        -- Obj_X, Obj_Y, Obj_Z, Obj_Radius, 
        -- Visible_IDs, Count_Visible, MainCamera
    --)

    --Seq_Render:Slot(2, "KERNELS.render_rasterize",
        --Visible_IDs, Count_Visible, 
        --Tri_V1, Tri_V2, Tri_V3, Tri_Color,
        --ScreenPtr, ZBuffer
    --)
    -- Add this to your love.load()
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
