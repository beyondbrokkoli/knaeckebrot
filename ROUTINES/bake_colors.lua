local bit = require("bit")

return function(Total_Tris)
    for i = 0, Total_Tris - 1 do
        local tc = Tri_Color[i]

        -- Unpack exactly once!
        -- Notice: Your engine uses ABGR format based on your bitshifts
        Tri_B[i] = bit.band(bit.rshift(tc, 16), 0xFF)
        Tri_G[i] = bit.band(bit.rshift(tc, 8), 0xFF)
        Tri_R[i] = bit.band(tc, 0xFF)
    end
end
