-- sys_state.lua
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
snapshotBaked = false -- <--- ADD THIS
Routine_InitText = require("ROUTINES.init_slide_text")
