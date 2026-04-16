local Lexer  = require("MODULES.text_lexer")
local Math   = require("MODULES.text_math")
local Baker  = require("MODULES.text_baker")
local Anchor = require("MODULES.text_anchor")

return function(textPayload, SlideCaches_Ptr, fov, canvas_w, canvas_h)
    -- Clean up old caches
    for i = 0, NumSlides[0] - 1 do
        if SlideCaches_Ptr[i] then
            if SlideCaches_Ptr[i][false] then SlideCaches_Ptr[i][false]._keepAlive:release() end
            if SlideCaches_Ptr[i][true]  then SlideCaches_Ptr[i][true]._keepAlive:release() end
        end
        SlideCaches_Ptr[i] = {}
    end

    for i = 0, NumSlides[0] - 1 do
        local slideData = textPayload[i]
        local titleText = (slideData and slideData.title) or ("SLIDE " .. tostring(i + 1))
        local rawLines = slideData and slideData.content
        local slide_w, slide_h = Box_HW[i] * 2, Box_HH[i] * 2

        -- Local helper to bake for specific distances
        local function BakeMode(isZen)
            local distScale = math.max(slide_h, slide_w * (canvas_h / canvas_w))
            local pad = isZen and 0 or 200
            local optDist = (distScale * fov) / canvas_h * 1.0 + pad
            local text_depth = optDist - (Box_HT[i] + 5)

            local opt_scale, virtW, virtH, fonts = Math(slide_w, slide_h, text_depth, fov, canvas_w, canvas_h)

            local contentASTs = {}
            if rawLines then
                for _, line in ipairs(rawLines) do
                    table.insert(contentASTs, Lexer(line, fonts))
                end
            end

            local imgData, finalH = Baker(titleText, contentASTs, fonts, virtW, virtH)
            return Anchor(imgData, virtW, finalH, virtH, opt_scale, (Box_HT[i] + 5))
        end

        -- Bake both versions!
        SlideCaches_Ptr[i][false] = BakeMode(false) -- STATE_PRESENT
        SlideCaches_Ptr[i][true]  = BakeMode(true)  -- STATE_ZEN
    end

    collectgarbage("collect")
end

