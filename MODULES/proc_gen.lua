-- ========================================================================
-- MODULES/proc_gen.lua
-- Procedural Flight Controller and State Manager
-- ========================================================================
local ffi = require("ffi")
local State = require("MODULES.state")

local ProcGen = {}

-- The "Viewpoint" logic applied to an infinite void
local TargetZ = 0
local VIEWPOINT_STRIDE = 5000 

function ProcGen.TriggerContinuousFlight()
    -- Lock the camera to face dead-ahead down the negative Z axis
    FlightData.tx = 0
    FlightData.ty = -200
    FlightData.tz = TargetZ
    FlightData.tyaw = math.pi
    FlightData.tpitch = 0

    FlightData.sx, FlightData.sy, FlightData.sz = MainCamera.x, MainCamera.y, MainCamera.z
    FlightData.syaw, FlightData.spitch = MainCamera.yaw, MainCamera.pitch
    FlightData.lerpT = 0
    
    -- Enter the transit tunnel!
    State.SetEngine(STATE_CINEMATIC)
    snapshotBaked = false
end

function ProcGen.ExecuteTransition(direction)
    -- Advance our target viewpoint
    if direction == "right" then
        TargetZ = TargetZ - VIEWPOINT_STRIDE
    elseif direction == "left" then
        TargetZ = TargetZ + VIEWPOINT_STRIDE
    end
    
    -- Book the future promise and fly!
    State.SetTarget(STATE_OVERVIEW)
    ProcGen.TriggerContinuousFlight()
end

function ProcGen.KeyPressed(key)
    -- Press 'o' to toggle the Procedural Overview
    if key == "o" then
        if EngineState[STATE_OVERVIEW] then
            State.SetEngine(STATE_FREEFLY)
            State.SetTarget(STATE_FREEFLY)
        else
            -- Snap the TargetZ to the nearest 5k checkpoint relative to where we are
            TargetZ = MainCamera.z - (MainCamera.z % VIEWPOINT_STRIDE)
            State.SetTarget(STATE_OVERVIEW)
            ProcGen.TriggerContinuousFlight()
        end

    -- If we are in the procedural state, fly between viewpoints
    elseif EngineState[STATE_OVERVIEW] and (key == "left" or key == "right") then
        ProcGen.ExecuteTransition(key)
    end
end

function ProcGen.GetTargetZ()
    return TargetZ
end

return ProcGen
