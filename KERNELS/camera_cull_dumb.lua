-- ========================================================================
-- KERNELS/camera_cull_dumb.lua
-- The purest Knäckebrot. Zero math. Just feeds the rasterizer.
-- ========================================================================
return function(Visible_IDs, Count_Visible)

    return function(Slice_Start, Active_Count)
        local Slice_End = Slice_Start + Active_Count - 1

        -- Dereference the shared pointer locally
        local v_idx = Count_Visible[0]

        for i = Slice_Start, Slice_End do
            Visible_IDs[v_idx] = i
            v_idx = v_idx + 1
        end

        -- Write the updated count back to shared memory
        Count_Visible[0] = v_idx
    end

end
