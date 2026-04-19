-- ========================================================================
-- sys_memory.lua
-- Pure SoA Motherboard. Data-Driven Metaprogramming Allocator.
-- ========================================================================
local ffi = require("ffi")

-- ==========================================
-- [1] THE UNIVERSE BOUNDARIES (Static Numbers)
-- ==========================================
MAX_OBJS = 4096
MAX_TOTAL_VERTS = 500000
MAX_TOTAL_TRIS = 1000000

MAX_SLIDES = 64
MAX_BOUND_SPHERES = 128
MAX_BOUND_BOXES = 128

BOUND_CONTAIN = 1; BOUND_REPEL = 2; BOUND_SOLID = 3;

-- ==========================================
-- [2] MEMORY SLICES (The ATX Map)
-- ==========================================
SLICE_SOLID_START      = 0;    SLICE_SOLID_MAX      = 399
SLICE_KINEMATIC_START  = 400;  SLICE_KINEMATIC_MAX  = 1399
SLICE_AUTONOMOUS_START = 1400; SLICE_AUTONOMOUS_MAX = 1999
SLICE_PROCEDURAL_START = 2000; SLICE_PROCEDURAL_MAX = 2999
SLICE_COLLIDER_START   = 3000; SLICE_COLLIDER_MAX   = 3499
SLICE_DEEP_SPACE_START = 3500; SLICE_DEEP_SPACE_MAX = 4095

-- ==========================================
-- [3] THE METAPROGRAMMING ALLOCATOR
-- ==========================================
-- Injects FFI arrays directly into the Lua Global namespace (_G)
local function AllocateSoA(type_str, size, names)
    for i = 1, #names do
        _G[names[i]] = ffi.new(type_str, size)
    end
end

-- ========================================================================
-- [4] THE SCHEMA (Ordered Basic to Specific)
-- ========================================================================

-- 1. Counters & Singletons (The "double[1]" Trojan Horse for Zero GC)
AllocateSoA("double[1]", 1, {
    "Count_Solid", "Count_Kinematic", "Count_Autonomous", "Count_Procedural", 
    "Count_Collider", "Count_DeepSpace", "NumObjects", "NumTotalVerts", 
    "NumTotalTris", "NumSlides", "Count_BoundSphere", "Count_BoundBox",
    "Count_Visible_Solid", "Count_Visible_Kinematic", 
    "Count_Visible_Autonomous", "Count_Visible_Procedural",
    "TargetSlide", "ActiveSlide"
})

-- 2. Object Spatial Data (The Core Transform)
AllocateSoA("float[?]", MAX_OBJS, {
    "Obj_Radius", "Obj_X", "Obj_Y", "Obj_Z",
    "Obj_VelX", "Obj_VelY", "Obj_VelZ",
    "Obj_Yaw", "Obj_Pitch", "Obj_RotSpeedYaw", "Obj_RotSpeedPitch",
    "Obj_FWX", "Obj_FWY", "Obj_FWZ",
    "Obj_RTX", "Obj_RTY", "Obj_RTZ",
    "Obj_UPX", "Obj_UPY", "Obj_UPZ"
})

-- 3. Object Geometry Linking & Visibility
AllocateSoA("int[?]", MAX_OBJS, {
    "Obj_HomeIdx", "Obj_VertStart", "Obj_VertCount", "Obj_TriStart", "Obj_TriCount",
    "Visible_Solid_IDs", "Visible_Kinematic_IDs", "Visible_Autonomous_IDs", "Visible_Procedural_IDs"
})

-- 4. Vertex Data (The Raw Points)
AllocateSoA("float[?]", MAX_TOTAL_VERTS, {
    "Vert_LX", "Vert_LY", "Vert_LZ", 
    "Vert_CX", "Vert_CY", "Vert_CZ", 
    "Vert_PX", "Vert_PY", "Vert_PZ"
})
AllocateSoA("bool[?]", MAX_TOTAL_VERTS, {"Vert_Valid"})

-- 5. Triangle Data (The Faces and Colors)
AllocateSoA("int[?]", MAX_TOTAL_TRIS, {"Tri_V1", "Tri_V2", "Tri_V3"})
AllocateSoA("float[?]", MAX_TOTAL_TRIS, {"Tri_A", "Tri_R", "Tri_G", "Tri_B"})
AllocateSoA("uint32_t[?]", MAX_TOTAL_TRIS, {"Tri_Color", "Tri_BakedColor"})

-- 6. Slide Anchors (Presentation Overlays)
AllocateSoA("float[?]", MAX_SLIDES, {
    "Slide_X", "Slide_Y", "Slide_Z", "Slide_W", "Slide_H",
    "Slide_NX", "Slide_NY", "Slide_NZ", "Slide_ZOffset"
})

-- 7. Physics Collision (Bounding Volumes)
AllocateSoA("float[?]", MAX_BOUND_SPHERES, {"BoundSphere_X", "BoundSphere_Y", "BoundSphere_Z", "BoundSphere_RSq"})
AllocateSoA("uint8_t[?]", MAX_BOUND_SPHERES, {"BoundSphere_Mode"})

AllocateSoA("float[?]", MAX_BOUND_BOXES, {
    "BoundBox_X", "BoundBox_Y", "BoundBox_Z",
    "BoundBox_HW", "BoundBox_HH", "BoundBox_HT",
    "BoundBox_FWX", "BoundBox_FWY", "BoundBox_FWZ",
    "BoundBox_RTX", "BoundBox_RTY", "BoundBox_RTZ",
    "BoundBox_UPX", "BoundBox_UPY", "BoundBox_UPZ"
})
AllocateSoA("uint8_t[?]", MAX_BOUND_BOXES, {"BoundBox_Mode"})


-- ==========================================
-- [5] STRUCTS & SINGLETONS
-- ==========================================
ffi.cdef[[
    typedef struct {
        float minX, minY, minZ;
        float maxX, maxY, maxZ;
        bool isActive;
    } GlobalCage;

    typedef struct {
        float x, y, z;
        float yaw, pitch;
        float fov;
        float fwx, fwy, fwz;
        float rtx, rty, rtz;
        float upx, upy, upz;
    } CameraState;

    typedef struct {
        float sx, sy, sz, syaw, spitch;
        float tx, ty, tz, tyaw, tpitch;
        float lerpT;
    } FlightTracker;
]]

UniverseCage = ffi.new("GlobalCage", {-15000, -4000, -15000, 15000, 15000, 15000, true})
MainCamera = ffi.new("CameraState"); MainCamera.fov = 600
FlightData = ffi.new("FlightTracker")

-- ========================================================================
-- [6] BOOLEAN STATE MACHINE
-- ========================================================================
STATE_FREEFLY = 0; STATE_CINEMATIC = 1; STATE_PRESENT = 2; 
STATE_ZEN = 3; STATE_HIBERNATED = 4; STATE_OVERVIEW = 5; 
MAX_STATES = 6;

EngineState = ffi.new("bool[?]", MAX_STATES); EngineState[STATE_ZEN] = true;
TargetState = ffi.new("bool[?]", MAX_STATES); TargetState[STATE_ZEN] = true;

-- ==========================================
-- [7] LUA GAMEPLAY GLOBALS
-- ==========================================
lastFreeX, lastFreeY, lastFreeZ, lastFreeYaw, lastFreePitch = 0, 0, 0, 0, 0
pendingResize = false; resizeTimer = 0; isMouseCaptured = false
globalTimer = 0; snapshotBaked = false; MasterTextAlpha = 0.0

manifest = {}; SlideTitles = {}
Font_Slide, Font_UI, Font_Terminal = nil, nil, nil

HUD = { open = false, scroll = 0, lines = {"BGB HUD INITIALIZED", "READY FOR QUERY"}, mode = "LOOKUP" }
HUD_DIST, HUD_MESH_ID = nil, nil

C_CREAM, C_LATTE = 4294306522, 4292131280
local ESC = string.char(27)
c_red, c_green, c_yellow, c_cyan, c_reset = ESC.."[31m", ESC.."[32m", ESC.."[33m", ESC.."[36m", ESC.."[0m"
