-- ========================================================================
-- sys_sequence.lua
-- The ultimate, crispy-thin DOD dispatcher.
-- ========================================================================

local function CreateSequence()
    return {
        Kernels = {},

        -- THE BINDING PHASE
        -- Takes a filepath and ANY number of FFI pointers (...)
        Slot = function(self, index, filepath, ...)
            -- Bust the cache for hot-reloading
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

            -- Execute the factory, passing all FFI pointers (...) into it.
            -- This locks the pointers into the closure and caches the hot loop!
            self.Kernels[index] = factory(...)
            print("[SEQUENCE] Bound Kernel: " .. filepath .. " to Slot " .. index)
            return true
        end,

        -- THE EXECUTION PHASE
        -- Takes any execution arguments (like dt) and passes them to the Kernels
        Run = function(self, ...)
            for i = 1, #self.Kernels do
                self.Kernels[i](...)
            end
        end
    }
end

-- We return the constructor so we can make multiple sequences (e.g., Physics vs Render)
return CreateSequence
