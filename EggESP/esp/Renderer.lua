--[[
    ESP renderer: draw pooled labels for eggs, treadmill, and traps.
]]

local Renderer = {}

function Renderer.create(deps)
    local Config = deps.Config
    local Util = deps.Util
    local TextLayout = deps.TextLayout

    local theme = Config.Theme
    local layout = Config.Layout
    local drawing = Config.Drawing

    local function getAccentColor(entry, info)
        if entry.kind == "treadmill" then
            return theme.treadmillTag
        end

        if entry.kind == "trap" then
            return entry.isOwn and theme.trapOwn or theme.trapEnemy
        end

        return info.rarityColor
    end

    local function getBorderColor(entry)
        if entry.kind == "treadmill" then
            return theme.treadmillBorder
        end

        if entry.kind == "trap" then
            return entry.isOwn and theme.trapOwnBorder or theme.trapEnemyBorder
        end

        return theme.border
    end

    local function getRingColor(entry)
        if entry.kind == "treadmill" then
            return theme.treadmillDotRing
        end

        if entry.kind == "trap" then
            return entry.isOwn and theme.trapOwnRing or theme.trapEnemyRing
        end

        return theme.dotRing
    end

    local function getConnectorColor(entry)
        if entry.kind == "treadmill" then
            return theme.treadmillBorder
        end

        if entry.kind == "trap" then
            return entry.isOwn and theme.trapOwnBorder or theme.trapEnemyBorder
        end

        return theme.connector
    end

    local function getTitleColor(entry)
        if entry.kind == "treadmill" then
            return theme.treadmillTag
        end

        if entry.kind == "trap" then
            return entry.isOwn and theme.trapOwn or theme.trapEnemy
        end

        return theme.textMain
    end

    local function drawEntry(entry, draw)
        local info = entry.info
        local accentColor = getAccentColor(entry, info)
        local boxW = entry.boxWidth or layout.boxWidth
        local boxH = entry.boxHeight or layout.boxHeight

        draw.dot.Color = accentColor
        draw.dot.Position = entry.screenPos
        draw.dot.Visible = true

        draw.dotRing.Color = getRingColor(entry)
        draw.dotRing.Position = entry.screenPos
        draw.dotRing.Visible = true

        local boxTop = Vector2.new(entry.boxX, entry.boxY)
        local boxSize = Vector2.new(boxW, boxH)

        draw.shadow.Color = theme.shadow
        draw.shadow.Position = boxTop + Vector2.new(2, 2)
        draw.shadow.Size = boxSize
        draw.shadow.Transparency = 0.35
        draw.shadow.Visible = true

        draw.box.Color = theme.bg
        draw.box.Position = boxTop
        draw.box.Size = boxSize
        draw.box.Visible = true

        draw.boxInner.Color = theme.bgInner
        draw.boxInner.Position = boxTop + Vector2.new(3, 3)
        draw.boxInner.Size = Vector2.new(boxW - 6, boxH - 6)
        draw.boxInner.Transparency = 0.15
        draw.boxInner.Visible = true

        draw.boxBorder.Color = getBorderColor(entry)
        draw.boxBorder.Position = boxTop
        draw.boxBorder.Size = boxSize
        draw.boxBorder.Visible = true

        draw.accent.Color = accentColor
        draw.accent.Position = boxTop
        draw.accent.Size = Vector2.new(layout.accentWidth, boxH)
        draw.accent.Visible = true

        draw.accentTop.Color = accentColor
        draw.accentTop.From = boxTop
        draw.accentTop.To = boxTop + Vector2.new(boxW, 0)
        draw.accentTop.Visible = true

        draw.connector.Color = getConnectorColor(entry)
        draw.connector.From = entry.screenPos
        draw.connector.To = Vector2.new(entry.labelCenter.X, entry.boxY + boxH)
        draw.connector.Visible = true

        local textX = entry.boxX + layout.textPaddingX
        local baseY = entry.boxY + layout.textPaddingY

        draw.textName.Text = TextLayout.GetTitleText(entry)
        draw.textName.Color = getTitleColor(entry)
        draw.textName.Position = Vector2.new(textX, baseY + layout.textLine1)
        draw.textName.Visible = true

        draw.textRarity.Text = TextLayout.GetDetailText(entry)
        draw.textRarity.Color = entry.kind == "trap" and accentColor or info.rarityColor
        draw.textRarity.Position = Vector2.new(textX, baseY + layout.textLine2)
        draw.textRarity.Visible = true

        local distanceText = Util.formatDistance(entry.distance)
        local distanceWidth = Util.estimateTextWidth(distanceText, layout.textDistanceSize or drawing.textDistanceSize)

        draw.textDistance.Text = distanceText
        draw.textDistance.Color = theme.textMuted
        draw.textDistance.Position = Vector2.new(entry.boxX + boxW - layout.textPaddingX - distanceWidth, baseY + layout.textLine3)
        draw.textDistance.Visible = true
    end

    local function renderFrame(entries, pool)
        for index, entry in ipairs(entries) do
            drawEntry(entry, pool.Acquire(index))
        end

        pool.HideFrom(#entries + 1)
    end

    return {
        DrawEntry = drawEntry,
        RenderFrame = renderFrame,
    }
end

return Renderer
