local function CreateSequence()
return {
Kernels = {},
Slot = function(self, index, filepath, ...)
package.loaded[filepath] = nil
local success, factory = pcall(require, filepath)
if not success then
print("[FATAL] Syntax Error in Kernel: " .. filepath)
return false
end
if type(factory) ~= "function" then
print("[FATAL] Kernel must return a factory function: " .. filepath)
return false
end
self.Kernels[index] = factory(...)
print("[SEQUENCE] Bound Kernel: " .. filepath .. " to Slot " .. index)
return true
end,
Run = function(self, ...)
for i = 1, #self.Kernels do
self.Kernels[i](...)
end
end
}
end
return CreateSequence
