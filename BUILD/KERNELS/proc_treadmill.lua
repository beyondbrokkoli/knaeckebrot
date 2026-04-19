local floor = math.floor
return function(
SLICE_START, MAX_TILES, Count_Ptr,
Obj_X, Obj_Y, Obj_Z, Obj_Radius,
Obj_FWX, Obj_FWY, Obj_FWZ, Obj_RTX, Obj_RTY, Obj_RTZ, Obj_UPX, Obj_UPY, Obj_UPZ,
Obj_VertStart, Obj_VertCount, Obj_TriStart, Obj_TriCount,
Vert_LX, Vert_LY, Vert_LZ, Tri_V1, Tri_V2, Tri_V3, Tri_BakedColor,
Global_NumVerts, Global_NumTris, MainCamera, EngineState, TargetState
)
local TILE_SIZE = 1000
local THICKNESS = 100
local hs = TILE_SIZE / 2
local ht = THICKNESS / 2
for slot = 0, MAX_TILES - 1 do
local id = SLICE_START + slot
local vStart = Global_NumVerts[0]
local tStart = Global_NumTris[0]
Obj_VertStart[id], Obj_VertCount[id] = vStart, 8
Obj_TriStart[id],  Obj_TriCount[id]  = tStart, 12
Obj_Radius[id] = TILE_SIZE * 0.8
Obj_FWX[id], Obj_FWY[id], Obj_FWZ[id] = 0, 0, 1
Obj_RTX[id], Obj_RTY[id], Obj_RTZ[id] = 1, 0, 0
Obj_UPX[id], Obj_UPY[id], Obj_UPZ[id] = 0, 1, 0
Global_NumVerts[0] = Global_NumVerts[0] + 8
Global_NumTris[0] = Global_NumTris[0] + 12
local verts = {
{-hs, -ht, -hs}, {hs, -ht, -hs}, {hs, ht, -hs}, {-hs, ht, -hs},
{-hs, -ht,  hs}, {hs, -ht,  hs}, {hs, ht,  hs}, {-hs, ht,  hs}
}
for i, v in ipairs(verts) do
local vIdx = vStart + i - 1
Vert_LX[vIdx], Vert_LY[vIdx], Vert_LZ[vIdx] = v[1], v[2], v[3]
end
local indices = {
0,2,1, 0,3,2, 4,5,6, 4,6,7, 0,1,5, 0,5,4,
1,2,6, 1,6,5, 2,3,7, 2,7,6, 3,0,4, 3,4,7
}
for i = 1, #indices, 3 do
local tIdx = tStart + floor((i-1)/3)
Tri_V1[tIdx] = vStart + indices[i]
Tri_V2[tIdx] = vStart + indices[i+1]
Tri_V3[tIdx] = vStart + indices[i+2]
Tri_BakedColor[tIdx] = (slot % 2 == 0) and 0xFF222222 or 0xFF444444
end
Obj_X[id], Obj_Y[id], Obj_Z[id] = 0, -99999, 0
end
local spawn_count = 0
local next_spawn_z = 0
return function(dt)
if not (EngineState[STATE_OVERVIEW] or (EngineState[STATE_CINEMATIC] and TargetState[STATE_OVERVIEW])) then return end
local horizon_z = MainCamera.z - 10000
while next_spawn_z > horizon_z do
local slot = spawn_count % MAX_TILES
local id = SLICE_START + slot
Obj_X[id] = 0
Obj_Y[id] = -500
Obj_Z[id] = next_spawn_z
if Count_Ptr[0] < MAX_TILES then
Count_Ptr[0] = Count_Ptr[0] + 1
end
spawn_count = spawn_count + 1
next_spawn_z = next_spawn_z - TILE_SIZE
end
end
end
