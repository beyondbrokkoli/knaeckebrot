require("sys_memory")
local CreateSequence = require("sys_sequence")
local Seq_Physics = CreateSequence()
local Seq_Render  = CreateSequence()
function love.load()
ReinitBuffers()
Seq_Physics:Slot(1, "KERNELS.phys_kinematic",
Obj_X, Obj_Y, Obj_Z, Obj_VelX, Obj_VelY, Obj_VelZ
)
-)
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
Count_Visible[0] = 0
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
