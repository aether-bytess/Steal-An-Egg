--[[
    Label text builders and dynamic box sizing.
]]

local TextLayout = {}

function TextLayout.create(deps)
    local Config = deps.Config
    local Util = deps.Util

    local theme = Config.Theme
    local layout = Config.Layout
    local drawing = Config.Drawing

    local function getTitleText(entry)
        local info = entry.info

        if entry.kind == "treadmill" then
            return "[MY TREADMILL] " .. info.name
        end

        if entry.kind == "trap" then
            if entry.isOwn then
                return "[MY TRAP] " .. info.name
            end

            return "[TRAP] " .. info.name
        end

        return info.name
    end

    local function getDetailText(entry)
        local info = entry.info

        if entry.kind == "trap" then
            return string.format("%s  |  %s  |  %s", info.rarityName, info.rarityValue, entry.owner)
        end

        if info.areaName then
            return string.format("%s  |  %s  |  %s", info.areaName, info.rarityName, info.rarityValue)
        end

        return string.format("%s  |  %s", info.rarityName, info.rarityValue)
    end

    local function computeBoxSize(entry)
        local horizontalPad = layout.textPaddingX * 2 + layout.accentWidth + 6
        local minWidth = entry.kind == "trap" and layout.trapBoxWidthMin or layout.boxWidthMin
        local titleWidth = Util.estimateTextWidth(getTitleText(entry), drawing.textNameSize)
        local detailWidth = Util.estimateTextWidth(getDetailText(entry), drawing.textRaritySize)
        local distanceWidth = Util.estimateTextWidth(Util.formatDistance(entry.distance), drawing.textDistanceSize)
        local contentWidth = math.max(titleWidth, detailWidth, distanceWidth) + horizontalPad

        return {
            width = math.clamp(contentWidth, minWidth, layout.boxWidthMax),
            height = layout.boxHeight,
        }
    end

    local function applyBoxSize(entry)
        local size = computeBoxSize(entry)
        entry.boxWidth = size.width
        entry.boxHeight = size.height
        return entry
    end

    return {
        GetTitleText = getTitleText,
        GetDetailText = getDetailText,
        ComputeBoxSize = computeBoxSize,
        ApplyBoxSize = applyBoxSize,
    }
end

return TextLayout
