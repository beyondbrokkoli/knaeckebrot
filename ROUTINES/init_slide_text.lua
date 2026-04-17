local Lexer = require("MODULES.text_lexer")
local Math = require("MODULES.text_math")
local Baker = require("MODULES.text_baker")
local Anchor = require("MODULES.text_anchor")

return function(textPayload, SlideCaches_Ptr, fov, canvas_w, canvas_h)
    for i = 0, NumSlides[0] - 1 do
        if SlideCaches_Ptr[i] then
            if SlideCaches_Ptr[i][false] then SlideCaches_Ptr[i][false]._keepAlive:release() end
            if SlideCaches_Ptr[i][true] then SlideCaches_Ptr[i][true]._keepAlive:release() end
        end
        SlideCaches_Ptr[i] = {}
    end

    for i = 0, NumSlides[0] - 1 do
        local slideData = textPayload[i]
        local titleText = (slideData and slideData.title) or ("SLIDE " .. tostring(i + 1))
        local rawLines = slideData and slideData.content

        local slide_w, slide_h = Slide_W[i], Slide_H[i]
        local z_offset = Slide_ZOffset[i]

        local function BakeMode(isZen)
            local distScale = math.max(slide_h, slide_w * (canvas_h / canvas_w))
            local pad = isZen and 0 or 200
            local optDist = (distScale * fov) / canvas_h * 1.0 + pad
            local text_depth = optDist - z_offset
            local opt_scale, virtW, virtH, fonts = Math(slide_w, slide_h, text_depth, fov, canvas_w, canvas_h)

            local contentASTs = {}
            if rawLines then
                for _, line in ipairs(rawLines) do
                    table.insert(contentASTs, Lexer(line, fonts))
                end
            end

            local imgData, finalH = Baker(titleText, contentASTs, fonts, virtW, virtH)
            return Anchor(imgData, virtW, finalH, virtH, opt_scale, z_offset)
        end

        SlideCaches_Ptr[i][false] = BakeMode(false)
        SlideCaches_Ptr[i][true] = BakeMode(true)
    end
    collectgarbage("collect")
end
