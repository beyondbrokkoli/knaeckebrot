local bit = require("bit")

return function(Total_Tris)
    for i = 0, Total_Tris - 1 do
        local tc = Tri_Color[i]

        -- AABBGGRR unpacking
        Tri_A[i] = bit.band(bit.rshift(tc, 24), 0xFF)
        Tri_B[i] = bit.band(bit.rshift(tc, 16), 0xFF)
        Tri_G[i] = bit.band(bit.rshift(tc, 8), 0xFF)
        Tri_R[i] = bit.band(tc, 0xFF)
    end
end
