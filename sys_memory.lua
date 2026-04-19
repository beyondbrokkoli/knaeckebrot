-- ========================================================================
-- sys_memory.lua
-- Pure SoA Motherboard. No return tables. Global FFI scope.
-- ========================================================================
local ffi = require("ffi")

-- ==========================================
-- [1] THE UNIVERSE BOUNDARIES (Static Numbers)
-- ==========================================
MAX_OBJS = 4096          -- Upgraded! (Costs practically nothing)
MAX_TOTAL_VERTS = 500000 
MAX_TOTAL_TRIS = 1000000 -- Give the Megaknot the room it deserves

MAX_SLIDES = 64
MAX_BOUND_SPHERES = 128
MAX_BOUND_BOXES = 128
BOUND_CONTAIN = 1; BOUND_REPEL = 2; BOUND_SOLID = 3;

ffi.cdef[[
    typedef struct {
        float minX, minY, minZ;
        float maxX, maxY, maxZ;
        bool isActive;
    } GlobalCage;
]]
UniverseCage = ffi.new("GlobalCage", {-15000, -4000, -15000, 15000, 15000, 15000, true})

-- ==========================================
-- [2] MEMORY SLICES (The ATX Upgrade)
-- ==========================================
SLICE_SOLID_START      = 0;    SLICE_SOLID_MAX      = 399   -- Presentations
SLICE_KINEMATIC_START  = 400;  SLICE_KINEMATIC_MAX  = 1399  -- Physics props
SLICE_AUTONOMOUS_START = 1400; SLICE_AUTONOMOUS_MAX = 1999  -- Megaknot & Panopticum!
SLICE_PROCEDURAL_START = 2000; SLICE_PROCEDURAL_MAX = 2999  -- Treadmill Ring Buffers
SLICE_COLLIDER_START   = 3000; SLICE_COLLIDER_MAX   = 3499  -- Invisible walls
SLICE_DEEP_SPACE_START = 3500; SLICE_DEEP_SPACE_MAX = 4095  -- ???

-- ==========================================
-- [3] SHARED KERNEL COUNTERS
-- ==========================================
Count_Solid        = ffi.new("int[1]")
Count_Kinematic    = ffi.new("int[1]")
Count_Autonomous   = ffi.new("int[1]")
Count_Procedural   = ffi.new("int[1]") -- NEW
Count_Collider     = ffi.new("int[1]")
Count_DeepSpace    = ffi.new("int[1]")

NumObjects         = ffi.new("int[1]")
NumTotalVerts      = ffi.new("int[1]")
NumTotalTris       = ffi.new("int[1]")
NumSlides          = ffi.new("int[1]")
Count_BoundSphere  = ffi.new("int[1]")
Count_BoundBox     = ffi.new("int[1]")

-- ==========================================
-- [4] THE VISIBILITY PIPELINE
-- ==========================================
Visible_Solid_IDs = ffi.new("int[?]", MAX_OBJS); Count_Visible_Solid = ffi.new("int[1]")
Visible_Kinematic_IDs = ffi.new("int[?]", MAX_OBJS); Count_Visible_Kinematic = ffi.new("int[1]")
Visible_Autonomous_IDs = ffi.new("int[?]", MAX_OBJS); Count_Visible_Autonomous = ffi.new("int[1]")
Visible_Procedural_IDs = ffi.new("int[?]", MAX_OBJS); Count_Visible_Procedural = ffi.new("int[1]") -- NEW

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

-- The original packed color (Source of Truth)
Tri_Color = ffi.new("uint32_t[?]", MAX_TOTAL_TRIS)

-- NEW: The fully pre-calculated integer color for static meshes (Zero-Math Rasterization)
Tri_BakedColor = ffi.new("uint32_t[?]", MAX_TOTAL_TRIS)

-- NEW: Pre-extracted color channels for dynamic meshes (AABBGGRR format)
Tri_A = ffi.new("float[?]", MAX_TOTAL_TRIS) 
Tri_R = ffi.new("float[?]", MAX_TOTAL_TRIS)
Tri_G = ffi.new("float[?]", MAX_TOTAL_TRIS)
Tri_B = ffi.new("float[?]", MAX_TOTAL_TRIS)

-- ==========================================
-- [7A] SLIDE ANCHORS (Camera & Text Logic)
-- Strictly used by the Gatekeeper and Text Stamp. No physics here.
-- ==========================================
Slide_X = ffi.new("float[?]", MAX_SLIDES); Slide_Y = ffi.new("float[?]", MAX_SLIDES); Slide_Z = ffi.new("float[?]", MAX_SLIDES)
Slide_W = ffi.new("float[?]", MAX_SLIDES); Slide_H = ffi.new("float[?]", MAX_SLIDES)
Slide_NX = ffi.new("float[?]", MAX_SLIDES); Slide_NY = ffi.new("float[?]", MAX_SLIDES); Slide_NZ = ffi.new("float[?]", MAX_SLIDES)
Slide_ZOffset = ffi.new("float[?]", MAX_SLIDES) -- NEW: Tells the text how far to float
-- ==========================================
-- [7B] EXPLICIT COLLISION SoA (Physics Volumes)
-- Completely decoupled from slides. Place them anywhere.
-- ==========================================
-- SPHERES
BoundSphere_X = ffi.new("float[?]", MAX_BOUND_SPHERES)
BoundSphere_Y = ffi.new("float[?]", MAX_BOUND_SPHERES)
BoundSphere_Z = ffi.new("float[?]", MAX_BOUND_SPHERES)
BoundSphere_RSq = ffi.new("float[?]", MAX_BOUND_SPHERES)
BoundSphere_Mode = ffi.new("uint8_t[?]", MAX_BOUND_SPHERES) -- 1: Contain, 2: Repel, 3: Solid

-- ORIENTED BOXES (OBB)
BoundBox_X = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_Y = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_Z = ffi.new("float[?]", MAX_BOUND_BOXES)
BoundBox_HW = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_HH = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_HT = ffi.new("float[?]", MAX_BOUND_BOXES)

BoundBox_FWX = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_FWY = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_FWZ = ffi.new("float[?]", MAX_BOUND_BOXES)
BoundBox_RTX = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_RTY = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_RTZ = ffi.new("float[?]", MAX_BOUND_BOXES)
BoundBox_UPX = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_UPY = ffi.new("float[?]", MAX_BOUND_BOXES); BoundBox_UPZ = ffi.new("float[?]", MAX_BOUND_BOXES)
BoundBox_Mode = ffi.new("uint8_t[?]", MAX_BOUND_BOXES)

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

-- ========================================================================
-- [9] PRESENTATION / APP STATE (Boolean SoA)
-- ========================================================================
STATE_FREEFLY = 0; STATE_CINEMATIC = 1; STATE_PRESENT = 2; STATE_ZEN = 3; STATE_HIBERNATED = 4; STATE_OVERVIEW = 5
MAX_STATES = 6

-- Natively unboxed booleans. Zero allocation.
EngineState = ffi.new("bool[?]", MAX_STATES)
TargetState = ffi.new("bool[?]", MAX_STATES)

TargetSlide = ffi.new("int[1]")
ActiveSlide = ffi.new("int[1]")

-- Initialize default state
EngineState[STATE_ZEN] = true
TargetState[STATE_ZEN] = true

-- ==========================================
-- [10] GLOBAL APPLICATION STATE (Merged from sys_state)
-- ==========================================
ffi.cdef[[
    typedef struct {
        float sx, sy, sz, syaw, spitch;
        float tx, ty, tz, tyaw, tpitch;
        float lerpT;
    } FlightTracker;
]]
FlightData = ffi.new("FlightTracker")

lastFreeX, lastFreeY, lastFreeZ, lastFreeYaw, lastFreePitch = 0, 0, 0, 0, 0
pendingResize = false; resizeTimer = 0
isMouseCaptured = false
manifest = {}; SlideTitles = {}
globalTimer = 0
Font_Slide, Font_UI, Font_Terminal = nil, nil, nil

HUD = { open = false, scroll = 0, lines = {"BGB HUD INITIALIZED", "READY FOR QUERY"}, mode = "LOOKUP" }
HUD_DIST, HUD_MESH_ID = nil, nil

C_CREAM, C_LATTE = 4294306522, 4292131280
local ESC = string.char(27)
c_red, c_green, c_yellow, c_cyan, c_reset = ESC.."[31m", ESC.."[32m", ESC.."[33m", ESC.."[36m", ESC.."[0m"

MasterTextAlpha = 0.0
snapshotBaked = false
