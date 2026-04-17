-- ========================================================================
-- KERNELS/camera_cull_smart.lua
-- Bounding-Sphere Frustum Culling. 
-- ========================================================================
local max, abs = math.max, math.abs

return function(
    Visible_IDs, Count_Visible,
    Obj_X, Obj_Y, Obj_Z, Obj_Radius,
    MainCamera
)

    -- The Compute Kernel
    return function(Slice_Start, Active_Count, CANVAS_W, CANVAS_H, HALF_W, HALF_H)
        local Slice_End = Slice_Start + Active_Count - 1
        local v_idx = Count_Visible[0] 

        -- Load Camera State into fast local registers
        local cpx, cpy, cpz = MainCamera.x, MainCamera.y, MainCamera.z
        local cfw_x, cfw_y, cfw_z = MainCamera.fwx, MainCamera.fwy, MainCamera.fwz
        local crt_x, crt_y, crt_z = MainCamera.rtx, MainCamera.rty, MainCamera.rtz
        local cup_x, cup_y, cup_z = MainCamera.upx, MainCamera.upy, MainCamera.upz
        local cam_fov = MainCamera.fov

        for i = Slice_Start, Slice_End do
            -- Vector from Camera to Object
            local dx = Obj_X[i] - cpx
            local dy = Obj_Y[i] - cpy
            local dz = Obj_Z[i] - cpz
            local r = Obj_Radius[i]

            -- 1. The "180 Degree" Near-Plane Check
            -- Is the object's center + its radius in front of the camera lens?
            local cz = dx*cfw_x + dy*cfw_y + dz*cfw_z
            
            if cz + r >= 0.1 then
                -- 2. The Exact FOV Frustum Check
                -- Project the object into the Camera's Left/Right and Up/Down axes
                local cx = dx*crt_x + dy*crt_y + dz*crt_z
                local cy = dx*cup_x + dy*cup_y + dz*cup_z

                -- Calculate how wide/tall the screen is at this specific depth
                local depth = max(0.1, cz)
                local frustum_w = (HALF_W * depth) / cam_fov
                local frustum_h = (HALF_H * depth) / cam_fov

                -- If the object's position is within the frustum + its radius, it's visible!
                if abs(cx) <= frustum_w + r and abs(cy) <= frustum_h + r then
                    Visible_IDs[v_idx] = i
                    v_idx = v_idx + 1
                end
            end
        end
        
        -- Write final visible count back to the Motherboard
        Count_Visible[0] = v_idx
    end
end
