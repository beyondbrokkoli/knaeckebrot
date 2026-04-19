-- ========================================================================
-- MODULES/proc_gen.lua
-- Dedicated Exhibition Orbit Controller
-- ========================================================================
local State = require("MODULES.state")
local Presentation = require("MODULES.presentation")

local ProcGen = {}

local orbitAngle = math.pi -- Start facing from the negative Z direction
local ORBIT_RADIUS = 16000
local ORBIT_HEIGHT = 4400  -- Dead center of your slide tower

function ProcGen.TriggerOverview()
    -- Calculate the exact target coordinates on our orbital ring
    FlightData.tx = math.sin(orbitAngle) * ORBIT_RADIUS
    FlightData.ty = ORBIT_HEIGHT
    FlightData.tz = math.cos(orbitAngle) * ORBIT_RADIUS

    -- Force the camera to look inward at the presentation pillar
    FlightData.tyaw = orbitAngle + math.pi
    FlightData.tpitch = 0

    -- Capture our current location for the kernel to lerp from
    FlightData.sx, FlightData.sy, FlightData.sz = MainCamera.x, MainCamera.y, MainCamera.z
    FlightData.syaw, FlightData.spitch = MainCamera.yaw, MainCamera.pitch
    FlightData.lerpT = 0
    
    -- Engage the camera_flight kernel!
    State.SetEngine(STATE_CINEMATIC)
    State.SetTarget(STATE_OVERVIEW)
    snapshotBaked = false
end

function ProcGen.Update(dt)
    -- If the flight kernel has successfully delivered us to the Overview...
    if EngineState[STATE_OVERVIEW] then
        -- Take manual control and slowly rotate the camera around the center!
        orbitAngle = orbitAngle + (dt * 0.1)
        
        MainCamera.x = math.sin(orbitAngle) * ORBIT_RADIUS
        MainCamera.y = ORBIT_HEIGHT
        MainCamera.z = math.cos(orbitAngle) * ORBIT_RADIUS
        
        MainCamera.yaw = orbitAngle + math.pi
        MainCamera.pitch = 0
        
        -- Call main.lua's global function to mathematically align the frustum
        if UpdateCameraBasis then UpdateCameraBasis() end
        
        -- PREVENT HIBERNATION: We are moving, so we must force the pipeline to draw
        snapshotBaked = false 
    end
end

function ProcGen.KeyPressed(key)
    if key == "o" then
        if EngineState[STATE_OVERVIEW] then
            -- We are in orbit. Time to go back!
            -- Assuming your Presentation module has a function to focus the active slide.
            -- If not, we fall back to a safe freefly state.
            if Presentation.FlyToSlide then
                Presentation.FlyToSlide(ActiveSlide[0])
            else
                State.SetEngine(STATE_FREEFLY)
                State.SetTarget(STATE_FREEFLY)
            end
        else
            -- We are looking at a slide. Blast off into orbit!
            ProcGen.TriggerOverview()
        end
    end
end

function ProcGen.GetTargetZ()
    -- Safely return 0 for the HUD since we no longer track a linear Z path
    return 0 
end

return ProcGen
