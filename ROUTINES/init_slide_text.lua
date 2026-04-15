local Lexer  = require("MODULES.text_lexer")
local Math   = require("MODULES.text_math")
local Baker  = require("MODULES.text_baker")
local Anchor = require("MODULES.text_anchor")

return function(textPayload, SlideCaches_Ptr, fov, canvas_w, canvas_h)
    -- Clean up old caches to prevent memory leaks if re-running
    for i = 0, NumSlides[0] - 1 do
        if SlideCaches_Ptr[i] and SlideCaches_Ptr[i]._keepAlive then
            SlideCaches_Ptr[i]._keepAlive:release()
        end
    end

    for i = 0, NumSlides[0] - 1 do
        local slideData = textPayload[i]
        local titleText = (slideData and slideData.title) or ("SLIDE " .. tostring(i + 1))
        local rawLines = slideData and slideData.content

        -- 1. Determine slide physical dimensions from FFI Motherboard
        local slide_w, slide_h = Box_HW[i] * 2, Box_HH[i] * 2

        -- 2. Calculate Distance (Assume parked distance uses pad=200 for now)
        local distScale = math.max(slide_h, slide_w * (canvas_h / canvas_w))
        local optDist = (distScale * fov) / canvas_h * 1.0 + 200
        local text_depth = optDist - (Box_HT[i] + 5)

        -- 3. Calculate Scale
        local opt_scale, virtW, virtH, fonts = Math(slide_w, slide_h, text_depth, fov, canvas_w, canvas_h)

        -- 4. Lex Text
        local contentASTs = {}
        if rawLines then
            for _, line in ipairs(rawLines) do
                if line ~= "" then table.insert(contentASTs, Lexer(line, fonts)) end
            end
        end

        -- 5. Bake and Crop
        local imgData, finalH = Baker(titleText, contentASTs, fonts, virtW, virtH)

        -- 6. Anchor to FFI
        SlideCaches_Ptr[i] = Anchor(imgData, virtW, finalH, virtH, opt_scale, (Box_HT[i] + 5))
    end

    collectgarbage("collect")
end
