local ffi = require("ffi")
local State = require("MODULES.state")
local ProcGen = {}
local TargetZ = 0
local VIEWPOINT_STRIDE = 5000
function ProcGen.TriggerContinuousFlight()
FlightData.tx = 0
FlightData.ty = -200
FlightData.tz = TargetZ
FlightData.tyaw = math.pi
FlightData.tpitch = 0
FlightData.sx, FlightData.sy, FlightData.sz = MainCamera.x, MainCamera.y, MainCamera.z
FlightData.syaw, FlightData.spitch = MainCamera.yaw, MainCamera.pitch
FlightData.lerpT = 0
State.SetEngine(STATE_CINEMATIC)
snapshotBaked = false
end
function ProcGen.ExecuteTransition(direction)
if direction == "right" then
TargetZ = TargetZ - VIEWPOINT_STRIDE
elseif direction == "left" then
TargetZ = TargetZ + VIEWPOINT_STRIDE
end
State.SetTarget(STATE_OVERVIEW)
ProcGen.TriggerContinuousFlight()
end
function ProcGen.KeyPressed(key)
if key == "o" then
if EngineState[STATE_OVERVIEW] then
State.SetEngine(STATE_FREEFLY)
State.SetTarget(STATE_FREEFLY)
else
TargetZ = MainCamera.z - (MainCamera.z % VIEWPOINT_STRIDE)
State.SetTarget(STATE_OVERVIEW)
ProcGen.TriggerContinuousFlight()
end
elseif EngineState[STATE_OVERVIEW] and (key == "left" or key == "right") then
ProcGen.ExecuteTransition(key)
end
end
return ProcGen
