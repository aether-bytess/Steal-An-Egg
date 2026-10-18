--[[
    Label stacking: prevent overlapping info boxes on screen.
]]

local StackLayout = {}

function StackLayout.create(deps)
    local Config = deps.Config
    local Util = deps.Util
    local TextLayout = deps.TextLayout

    local layout = Config.Layout

    local function assign(entries, camera)
        local visible = {}

        for _, entry in ipairs(entries) do
            local screenPos, onScreen, depth = Util.worldToScreen(camera, entry.worldPos)

            if onScreen and depth > 0 then
                entry.screenPos = screenPos
                entry.depth = depth
                TextLayout.ApplyBoxSize(entry)
                table.insert(visible, entry)
            end
        end

        table.sort(visible, function(a, b)
            if math.abs(a.screenPos.Y - b.screenPos.Y) > layout.screenSortYTolerance then
                return a.screenPos.Y > b.screenPos.Y
            end

            return a.screenPos.X < b.screenPos.X
        end)

        local placed = {}

        for _, entry in ipairs(visible) do
            local boxW = entry.boxWidth
            local boxH = entry.boxHeight
            local centerX = entry.screenPos.X
            local boxX = centerX - boxW * 0.5
            local boxY = entry.screenPos.Y - layout.labelOffsetY

            for _ = 1, layout.stackMaxIterations do
                local collided = false

                for _, rect in ipairs(placed) do
                    local nearX = math.abs(rect.cx - centerX) < boxW * layout.stackNearXFactor

                    if nearX and Util.rectsOverlap(boxX, boxY, boxW, boxH, rect.x, rect.y, rect.w, rect.h) then
                        boxY = math.min(boxY, rect.y - boxH - layout.stackGap)
                        collided = true
                    end
                end

                if not collided then
                    break
                end
            end

            entry.boxX = boxX
            entry.boxY = boxY
            entry.labelCenter = Vector2.new(centerX, boxY + boxH * 0.5)

            table.insert(placed, {
                x = boxX,
                y = boxY,
                w = boxW,
                h = boxH,
                cx = centerX,
            })

            table.sort(placed, function(a, b)
                return a.y < b.y
            end)
        end

        return visible
    end

    return {
        Assign = assign,
    }
end

return StackLayout
