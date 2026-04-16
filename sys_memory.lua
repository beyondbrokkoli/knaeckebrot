-- ========================================================================
-- sys_memory.lua
-- Pure SoA Motherboard. No return tables. Global FFI scope.
-- ========================================================================
local ffi = require("ffi")

-- ==========================================
-- [1] THE UNIVERSE BOUNDARIES (Static Numbers)
-- ==========================================

-- sys_memory.lua
MAX_OBJS = 1024
MAX_TOTAL_VERTS = 250000 -- Give yourself plenty of headroom!
MAX_TOTAL_TRIS = 500000  -- Half a million triangles of capacity



MAX_SLIDES = 64
-- MAX_TOTAL_VERTS = MAX_OBJS * 24
-- MAX_TOTAL_TRIS  = MAX_OBJS * 36



B_MinX, B_MinY, B_MinZ = -8000, -4000, -2000
B_MaxX, B_MaxY, B_MaxZ = 8000, 4000, 15000

-- ==========================================
-- [2] MEMORY SLICES (Contiguous Partitions)
-- Replacing the old "Pool" indirection arrays.
-- ==========================================
SLICE_SOLID_START = 0;         SLICE_SOLID_MAX = 199
SLICE_KINEMATIC_START = 200;   SLICE_KINEMATIC_MAX = 399
SLICE_COLLIDER_START = 400;    SLICE_COLLIDER_MAX = 599
SLICE_AUTONOMOUS_START = 600;  SLICE_AUTONOMOUS_MAX = 799
SLICE_DEEP_SPACE_START = 800;  SLICE_DEEP_SPACE_MAX = 1023

-- ==========================================
-- [3] SHARED KERNEL COUNTERS (The FFI Whiteboards)
-- These breathe and change, so they must be int[1] pointers.
-- ==========================================
Count_Solid        = ffi.new("int[1]")
Count_Kinematic    = ffi.new("int[1]")
Count_Collider     = ffi.new("int[1]")
Count_Autonomous   = ffi.new("int[1]")
Count_DeepSpace    = ffi.new("int[1]")

NumObjects         = ffi.new("int[1]")
NumTotalVerts      = ffi.new("int[1]")
NumTotalTris       = ffi.new("int[1]")
NumSlides          = ffi.new("int[1]")

-- ==========================================
-- [4] THE VISIBILITY PIPELINE (Camera to Rasterizer)
-- ==========================================
-- Visible_IDs   = ffi.new("int[?]", MAX_OBJS) -- Filled by Camera Kernel
-- Count_Visible = ffi.new("int[1]")           -- Read by Render Kernel

Visible_Solid_IDs = ffi.new("int[?]", MAX_OBJS);
Count_Visible_Solid = ffi.new("int[1]");

Visible_Kinematic_IDs = ffi.new("int[?]", MAX_OBJS);
Count_Visible_Kinematic = ffi.new("int[1]");

-- ==========================================
-- [5] OBJECT SoA (The Compute Data)
-- ==========================================
Obj_HomeIdx = ffi.new("int[?]", MAX_OBJS)
Obj_Radius  = ffi.new("float[?]", MAX_OBJS)
Obj_X       = ffi.new("float[?]", MAX_OBJS); Obj_Y = ffi.new("float[?]", MAX_OBJS); Obj_Z = ffi.new("float[?]", MAX_OBJS)
Obj_VelX    = ffi.new("float[?]", MAX_OBJS); Obj_VelY = ffi.new("float[?]", MAX_OBJS); Obj_VelZ = ffi.new("float[?]", MAX_OBJS)
Obj_Yaw     = ffi.new("float[?]", MAX_OBJS); Obj_Pitch = ffi.new("float[?]", MAX_OBJS)
Obj_RotSpeedYaw = ffi.new("float[?]", MAX_OBJS); Obj_RotSpeedPitch = ffi.new("float[?]", MAX_OBJS)

Obj_FWX = ffi.new("float[?]", MAX_OBJS); Obj_FWY = ffi.new("float[?]", MAX_OBJS); Obj_FWZ = ffi.new("float[?]", MAX_OBJS)
Obj_RTX = ffi.new("float[?]", MAX_OBJS); Obj_RTY = ffi.new("float[?]", MAX_OBJS); Obj_RTZ = ffi.new("float[?]", MAX_OBJS)
Obj_UPX = ffi.new("float[?]", MAX_OBJS); Obj_UPY = ffi.new("float[?]", MAX_OBJS); Obj_UPZ = ffi.new("float[?]", MAX_OBJS)

-- ==========================================
-- [6] GEOMETRY SoA
-- ==========================================
Obj_VertStart = ffi.new("int[?]", MAX_OBJS); Obj_VertCount = ffi.new("int[?]", MAX_OBJS)
Obj_TriStart  = ffi.new("int[?]", MAX_OBJS); Obj_TriCount  = ffi.new("int[?]", MAX_OBJS)

Vert_LX = ffi.new("float[?]", MAX_TOTAL_VERTS); Vert_LY = ffi.new("float[?]", MAX_TOTAL_VERTS); Vert_LZ = ffi.new("float[?]", MAX_TOTAL_VERTS)
Vert_CX = ffi.new("float[?]", MAX_TOTAL_VERTS); Vert_CY = ffi.new("float[?]", MAX_TOTAL_VERTS); Vert_CZ = ffi.new("float[?]", MAX_TOTAL_VERTS)
Vert_PX = ffi.new("float[?]", MAX_TOTAL_VERTS); Vert_PY = ffi.new("float[?]", MAX_TOTAL_VERTS); Vert_PZ = ffi.new("float[?]", MAX_TOTAL_VERTS)
Vert_Valid = ffi.new("bool[?]", MAX_TOTAL_VERTS)

Tri_V1 = ffi.new("int[?]", MAX_TOTAL_TRIS); Tri_V2 = ffi.new("int[?]", MAX_TOTAL_TRIS); Tri_V3 = ffi.new("int[?]", MAX_TOTAL_TRIS)
Tri_Color = ffi.new("uint32_t[?]", MAX_TOTAL_TRIS)

-- ADD THESE: Pre-extracted Float Colors!
Tri_R = ffi.new("float[?]", MAX_TOTAL_TRIS)
Tri_G = ffi.new("float[?]", MAX_TOTAL_TRIS)
Tri_B = ffi.new("float[?]", MAX_TOTAL_TRIS)

Tri_BaseLight = ffi.new("float[?]", MAX_TOTAL_TRIS)

-- ==========================================
-- [7] SLIDE SoA
-- ==========================================
Sphere_X = ffi.new("float[?]", MAX_SLIDES); Sphere_Y = ffi.new("float[?]", MAX_SLIDES); Sphere_Z = ffi.new("float[?]", MAX_SLIDES); Sphere_RSq = ffi.new("float[?]", MAX_SLIDES)
Box_X = ffi.new("float[?]", MAX_SLIDES); Box_Y = ffi.new("float[?]", MAX_SLIDES); Box_Z = ffi.new("float[?]", MAX_SLIDES)
Box_HW = ffi.new("float[?]", MAX_SLIDES); Box_HH = ffi.new("float[?]", MAX_SLIDES); Box_HT = ffi.new("float[?]", MAX_SLIDES)
Box_CosA = ffi.new("float[?]", MAX_SLIDES); Box_SinA = ffi.new("float[?]", MAX_SLIDES)
Box_NX = ffi.new("float[?]", MAX_SLIDES); Box_NY = ffi.new("float[?]", MAX_SLIDES); Box_NZ = ffi.new("float[?]", MAX_SLIDES)
Box_FWX = ffi.new("float[?]", MAX_SLIDES); Box_FWY = ffi.new("float[?]", MAX_SLIDES); Box_FWZ = ffi.new("float[?]", MAX_SLIDES)
Box_RTX = ffi.new("float[?]", MAX_SLIDES); Box_RTY = ffi.new("float[?]", MAX_SLIDES); Box_RTZ = ffi.new("float[?]", MAX_SLIDES)
Box_UPX = ffi.new("float[?]", MAX_SLIDES); Box_UPY = ffi.new("float[?]", MAX_SLIDES); Box_UPZ = ffi.new("float[?]", MAX_SLIDES)
Way_X = ffi.new("float[?]", MAX_SLIDES); Way_Y = ffi.new("float[?]", MAX_SLIDES); Way_Z = ffi.new("float[?]", MAX_SLIDES); Way_Yaw = ffi.new("float[?]", MAX_SLIDES); Way_Pitch = ffi.new("float[?]", MAX_SLIDES)

-- ==========================================
-- [8] SINGLETON STRUCTS
-- Replacing scattered camera variables.
-- ==========================================
ffi.cdef[[
    typedef struct {
        float x, y, z;
        float yaw, pitch;
        float fov;
        float fwx, fwy, fwz;
        float rtx, rty, rtz;
        float upx, upy, upz;
    } CameraState;
]]
MainCamera = ffi.new("CameraState")
MainCamera.fov = 600

-- ==========================================
-- [9] PRESENTATION / APP STATE
-- Note: EngineState and TargetState are now shared pointers!
-- ==========================================
STATE_FREEFLY = 0; STATE_CINEMATIC = 1; STATE_PRESENT = 2; STATE_ZEN = 3; STATE_HIBERNATED = 4; STATE_OVERVIEW = 5

EngineState = ffi.new("int[1]", STATE_ZEN)
TargetState = ffi.new("int[1]", STATE_ZEN)

TargetSlide = ffi.new("int[1]")
ActiveSlide = ffi.new("int[1]")

-- ==========================================
-- [10] GLOBAL APPLICATION STATE (Merged from sys_state)
-- ==========================================
tX, tY, tZ, tYaw, tPitch = 0, 0, 0, 0, 0
startX, startY, startZ, startYaw, startPitch = 0, 0, 0, 0, 0
lastFreeX, lastFreeY, lastFreeZ, lastFreeYaw, lastFreePitch = 0, 0, 0, 0, 0
pendingResize = false; resizeTimer = 0
isMouseCaptured = false

manifest = {}; SlideTitles = {}
globalTimer = 0; lerpT = 0
Font_Slide, Font_UI, Font_Terminal = nil, nil, nil

HUD = { open = false, scroll = 0, lines = {"BGB HUD INITIALIZED", "READY FOR QUERY"}, mode = "LOOKUP" }
HUD_DIST, HUD_MESH_ID = nil, nil

C_CREAM, C_LATTE = 4294306522, 4292131280
local ESC = string.char(27)
c_red, c_green, c_yellow, c_cyan, c_reset = ESC.."[31m", ESC.."[32m", ESC.."[33m", ESC.."[36m", ESC.."[0m"

MasterTextAlpha = 0.0
snapshotBaked = false
