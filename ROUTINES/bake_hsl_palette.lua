local bit = require("bit")
local ffi = require("ffi")
local math_sin = math.sin

return function(segments)
    -- Allocate an FFI C-array for blazing fast lookups in the kernel
    local palette = ffi.new("uint32_t[?]", segments)
    
    for i = 0, segments - 1 do
        -- Pre-bake the intensity phase
        local phase = (i / segments) * 10.0
        local intensity = (math_sin(phase) + 1.0) * 0.5
        
        local r = math.floor((0.1 + intensity * 0.6) * 255)
        local g = math.floor((0.4 + intensity * 0.4) * 255)
        local b = math.floor((0.7 + intensity * 0.3) * 255)
        
        -- Store as packed AABBGGRR
        palette[i] = bit.bor(0xFF000000, bit.lshift(b, 16), bit.lshift(g, 8), r)
    end
    
    return palette
end
