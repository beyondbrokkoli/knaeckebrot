local math_min = math.min
local math_pi = math.pi
local math_cos = math.cos
local math_sin = math.sin
local function lerp(a, b, t) return a + (b - a) * t end
local function lerpAngle(a, b, t)
local diff = (b - a + math_pi) % (math_pi * 2) - math_pi
return a + diff * t
end
return function(MainCamera, FlightData, EngineState, TargetState, STATE_CINEMATIC)
return function(dt)
if EngineState[0] ~= STATE_CINEMATIC then return end
FlightData.lerpT = math_min(1.0, FlightData.lerpT + dt * 1.5)
local easeT = 1 - (1 - FlightData.lerpT) * (1 - FlightData.lerpT)
MainCamera.x = lerp(FlightData.sx, FlightData.tx, easeT)
MainCamera.y = lerp(FlightData.sy, FlightData.ty, easeT)
MainCamera.z = lerp(FlightData.sz, FlightData.tz, easeT)
MainCamera.yaw = lerpAngle(FlightData.syaw, FlightData.tyaw, easeT)
MainCamera.pitch = lerpAngle(FlightData.spitch, FlightData.tpitch, easeT)
local cy, sy = math_cos(MainCamera.yaw), math_sin(MainCamera.yaw)
local cp, sp = math_cos(MainCamera.pitch), math_sin(MainCamera.pitch)
local fwx, fwy, fwz = sy * cp, sp, cy * cp
local rtx, rty, rtz = cy, 0, -sy
MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = fwx, fwy, fwz
MainCamera.rtx, MainCamera.rty, MainCamera.rtz = rtx, rty, rtz
MainCamera.upx = fwy * rtz
MainCamera.upy = fwz * rtx - fwx * rtz
MainCamera.upz = -fwy * rtx
if FlightData.lerpT >= 1.0 then
MainCamera.x, MainCamera.y, MainCamera.z = FlightData.tx, FlightData.ty, FlightData.tz
MainCamera.yaw, MainCamera.pitch = FlightData.tyaw, FlightData.tpitch
cy, sy = math_cos(MainCamera.yaw), math_sin(MainCamera.yaw)
cp, sp = math_cos(MainCamera.pitch), math_sin(MainCamera.pitch)
MainCamera.fwx, MainCamera.fwy, MainCamera.fwz = sy * cp, sp, cy * cp
MainCamera.rtx, MainCamera.rty, MainCamera.rtz = cy, 0, -sy
MainCamera.upx = sp * (-sy)
MainCamera.upy = (cy * cp) * cy - (sy * cp) * (-sy)
MainCamera.upz = -(sp) * cy
EngineState[0] = TargetState[0]
end
end
end
