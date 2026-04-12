-- ========================================================================
-- main.lua
-- ========================================================================
require("sys_memory") 
local CreateSequence = require("sys_sequence") 
local Factory = require("sys_factory") 

local Seq_Physics = CreateSequence() 
local Seq_Render = CreateSequence() 

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
    
    -- 3. Bind Render (FIXED INDICES: 1 and 2)
    Seq_Render:Slot(1, "KERNELS.camera_cull_dumb", Visible_IDs, Count_Visible) 
    Seq_Render:Slot(2, "KERNELS.render_rasterize", 
        Visible_IDs, Count_Visible, 
        Obj_X, Obj_Y, Obj_Z, 
        Obj_RTX, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ, Obj_FWX, Obj_FWY, Obj_FWZ, 
        Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount, 
        Vert_LX, Vert_LY, Vert_LZ, Vert_CX, Vert_CY, Vert_CZ, Vert_PX, Vert_PY, Vert_PZ, Vert_Valid, 
        Tri_V1, Tri_V2, Tri_V3, Tri_Color, 
        MainCamera, ScreenPtr, ZBuffer 
    ) 
    
    -- 4. Spawn the Universe
    -- A nice dark backing platform
    Factory.CreateSlideMesh( 
        SLICE_SOLID_START, SLICE_SOLID_MAX, Count_Solid, 
        0, -200, 800, 
        800, 800, 20, 
        0xFF222222 
    ) 
    
    -- THE HIGHLY DETAILED DONUT
    -- Cranked to 64 segments and 32 sides for that smooth, buttery geometry!
    local torus_id = Factory.CreateTorus( 
        SLICE_KINEMATIC_START, SLICE_KINEMATIC_MAX, Count_Kinematic, 
        0, 0, 500,     -- Perfectly centered, just inside the frustum 
        120, 45,       -- Fat, chunky proportions
        64, 32,        -- High-Poly Resolution
        0xFFDD8800     -- AABBGGRR (Results in a gorgeous Azure/Teal with the Lambertian Shading)
    ) 
    
    if torus_id then 
        Obj_RotSpeedYaw[torus_id] = 1.5 
        Obj_RotSpeedPitch[torus_id] = 2.2 
    end 
end 

function love.update(dt) 
    dt = math.min(dt, 0.033) 
    -- Run the physics kernel to update rotations and basis vectors
    Seq_Physics:Run(SLICE_KINEMATIC_START, Count_Kinematic[0], dt) 
end 

function love.draw() 
    Count_Visible[0] = 0 
    
    local CullKernel = Seq_Render.Kernels[1] 
    if CullKernel then 
        if Count_Solid[0] > 0 then CullKernel(SLICE_SOLID_START, Count_Solid[0]) end 
        if Count_Kinematic[0] > 0 then CullKernel(SLICE_KINEMATIC_START, Count_Kinematic[0]) end 
        if Count_Autonomous[0] > 0 then CullKernel(SLICE_AUTONOMOUS_START, Count_Autonomous[0]) end 
        if Count_DeepSpace[0] > 0 then CullKernel(SLICE_DEEP_SPACE_START, Count_DeepSpace[0]) end 
    end 
    
    local RasterKernel = Seq_Render.Kernels[2] 
    if RasterKernel then 
        RasterKernel(CANVAS_W, CANVAS_H, HALF_W, HALF_H) 
    end 
    
    ScreenImage:replacePixels(ScreenBuffer) 
    love.graphics.setColor(1, 1, 1, 1) 
    love.graphics.setBlendMode("replace") 
    love.graphics.draw(ScreenImage, 0, 0) 
    love.graphics.setBlendMode("alpha") 
end
