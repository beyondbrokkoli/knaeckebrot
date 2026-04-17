local ffi = require("ffi")
return function(imgData, w, h, orig_h, opt_scale, z_offset)
return {
ptr = ffi.cast("uint32_t*", imgData:getPointer()),
w = w,
h = h,
orig_h = orig_h,
opt_scale = opt_scale,
text_z_offset = z_offset,
_keepAlive = imgData
}
end
