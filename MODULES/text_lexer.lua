local ansi_to_love = {
    ["31"] = {1, 0.2, 0.2}, ["32"] = {0.2, 1, 0.2}, 
    ["33"] = {1, 1, 0.2},   ["36"] = {0.2, 1, 1}, 
    ["0"]  = {0, 0.8, 0}
}

local function ParseLine(rawText, fonts)
    if not rawText then return {} end

    local pipePos = rawText:find("|")
    if pipePos then
        local leftStr = rawText:sub(1, pipePos - 1):match("^%s*(.-)%s*$")
        local rightStr = rawText:sub(pipePos + 1):match("^%s*(.-)%s*$")
        local columns = ParseLine(leftStr, fonts)
        for _, col in ipairs(ParseLine(rightStr, fonts)) do table.insert(columns, col) end
        return columns
    end

    local cleanText = rawText
    local currentFont = fonts.body
    local currentAlign = "left"

    if cleanText:match("^~%s+") then cleanText = cleanText:gsub("^~%s+", ""); currentAlign = "center" end
    if cleanText:match("^#%s+") then cleanText = cleanText:gsub("^#%s+", ""); currentFont = fonts.head end

    local coloredTable, pureText = {}, ""
    local currentColor, lastPos = {1, 1, 1, 1}, 1

    for startPos, colorCode, endPos in cleanText:gmatch("()\27%[([%d;]*)m()") do
        if startPos > lastPos then
            local chunk = cleanText:sub(lastPos, startPos - 1)
            table.insert(coloredTable, currentColor)
            table.insert(coloredTable, chunk)
            pureText = pureText .. chunk
        end
        if colorCode == "0" or colorCode == "" then currentColor = {1, 1, 1, 1}
        elseif ansi_to_love[colorCode] then currentColor = {ansi_to_love[colorCode][1], ansi_to_love[colorCode][2], ansi_to_love[colorCode][3], 1} end
        lastPos = endPos
    end

    if lastPos <= #cleanText then
        local chunk = cleanText:sub(lastPos)
        table.insert(coloredTable, currentColor); table.insert(coloredTable, chunk)
        pureText = pureText .. chunk
    end

    if #coloredTable == 0 then coloredTable = {{1, 1, 1, 1}, cleanText}; pureText = cleanText end
    return {{ text = cleanText, pureText = pureText, coloredTable = coloredTable, font = currentFont, align = currentAlign }}
end

return ParseLine
