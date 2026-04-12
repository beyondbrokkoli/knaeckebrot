-- ========================================================================
-- KERNELS/phys_kinematic.lua
-- Pure DOD integration. Linear velocity and Basis Vector recalculation.
-- ========================================================================
local cos, sin = math.cos, math.sin

-- 1. The Binding
return function(
    X, Y, Z, VelX, VelY, VelZ, 
    Yaw, Pitch, RotYaw, RotPitch,
    FWX, FWY, FWZ, RTX, RTY, RTZ, UPX, UPY, UPZ
)

    -- 2. The Compute Kernel
    return function(Slice_Start, Active_Count, dt)
        
        -- Zero indirection. 100% Cache efficiency.
        local Slice_End = Slice_Start + Active_Count - 1
        
        for i = Slice_Start, Slice_End do
            
            -- 1. Linear Integration
            X[i] = X[i] + VelX[i] * dt
            Y[i] = Y[i] + VelY[i] * dt
            Z[i] = Z[i] + VelZ[i] * dt
            
            -- 2. Angular Integration
            local y_val = Yaw[i] + RotYaw[i] * dt
            local p_val = Pitch[i] + RotPitch[i] * dt
            Yaw[i], Pitch[i] = y_val, p_val
            
            -- 3. Recalculate 3D Basis Vectors
            local cy, sy = cos(y_val), sin(y_val)
            local cp, sp = cos(p_val), sin(p_val)
            
            local fwx, fwy, fwz = sy * cp, sp, cy * cp
            local rtx, rty, rtz = cy, 0, -sy
            
            FWX[i], FWY[i], FWZ[i] = fwx, fwy, fwz
            RTX[i], RTY[i], RTZ[i] = rtx, rty, rtz
            UPX[i] = fwy * rtz
            UPY[i] = fwz * rtx - fwx * rtz
            UPZ[i] = -fwy * rtx
        end
        
    end
end
