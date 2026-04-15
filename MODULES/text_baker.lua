local floor, min = math.floor, math.min

return function(titleText, contentASTs, fonts, virtW, virtH)
    local giantCanvas = love.graphics.newCanvas(virtW, virtH)
    love.graphics.setCanvas(giantCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)

    local currentY = floor(virtH * 0.05)
    local paddingX = floor(virtW * 0.05)
    local maxTextWidth = virtW - (paddingX * 2)

    if titleText and titleText ~= "" then
        love.graphics.setFont(fonts.title)
        love.graphics.printf(titleText, paddingX, currentY, maxTextWidth, "center")
        currentY = currentY + fonts.title:getHeight() + floor(virtH * 0.02)
    end

    if contentASTs then
        for _, columns in ipairs(contentASTs) do
            local numCols = #columns
            local colWidth = floor(maxTextWidth / numCols)
            local maxRowHeight = 0
            for colIdx, colData in ipairs(columns) do
                love.graphics.setFont(colData.font)
                local xOffset = paddingX + ((colIdx - 1) * colWidth)
                local colPrintWidth = colWidth - (numCols > 1 and floor(virtW * 0.02) or 0) + 4
                
                local _, wrappedLines = colData.font:getWrap(colData.pureText, colPrintWidth)
                local colHeight = #wrappedLines * colData.font:getHeight()
                if colHeight > maxRowHeight then maxRowHeight = colHeight end
                
                love.graphics.printf(colData.coloredTable, floor(xOffset - 2), floor(currentY), colPrintWidth, colData.align)
            end
            currentY = currentY + maxRowHeight + floor(virtH * 0.005)
        end
    end

    local finalH = min(virtH, currentY + floor(virtH * 0.05))
    local croppedCanvas = love.graphics.newCanvas(virtW, finalH)
    love.graphics.setCanvas(croppedCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(giantCanvas, 0, 0)
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()

    local imgData = croppedCanvas:newImageData()
    giantCanvas:release()
    croppedCanvas:release()

    return imgData, finalH, currentY
end
