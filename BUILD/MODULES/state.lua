local ffi = require("ffi")
local State = {}
function State.SetEngine(idx)
ffi.fill(EngineState, MAX_STATES, 0)
EngineState[idx] = true
end
function State.SetTarget(idx)
ffi.fill(TargetState, MAX_STATES, 0)
TargetState[idx] = true
end
function State.SyncToTarget()
ffi.copy(EngineState, TargetState, MAX_STATES)
end
function State.GetEngineName()
if EngineState[STATE_FREEFLY] then return "FREEFLY" end
if EngineState[STATE_CINEMATIC] then return "CINEMATIC" end
if EngineState[STATE_PRESENT] then return "PRESENT" end
if EngineState[STATE_ZEN] then return "ZEN" end
if EngineState[STATE_HIBERNATED] then return "HIBERNATED" end
if EngineState[STATE_OVERVIEW] then return "OVERVIEW" end
return "UNKNOWN"
end
return State
