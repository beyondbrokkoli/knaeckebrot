return function(Visible_IDs, Count_Visible)
return function(Slice_Start, Active_Count)
local Slice_End = Slice_Start + Active_Count - 1
local v_idx = Count_Visible[0]
for i = Slice_Start, Slice_End do
Visible_IDs[v_idx] = i
v_idx = v_idx + 1
end
Count_Visible[0] = v_idx
end
end
