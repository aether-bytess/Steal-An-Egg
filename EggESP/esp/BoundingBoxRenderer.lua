--[[
    Render 3D bounding boxes projected to screen lines.
]]

local BoundingBoxRenderer = {}

function BoundingBoxRenderer.create(deps)
    local Config = deps.Config
    local Util = deps.Util

    local theme = Config.Theme
    local runtime = Config.Runtime
    local layout = Config.Layout

    local function shouldDraw(entry)
        if entry.kind == "treadmill" then
            return runtime.showTreadmillBounds and entry.boundsCenter and entry.boundsHalfSize
        end

        if entry.kind == "trap" then
            return runtime.showTrapBounds and entry.boundsCenter and entry.boundsHalfSize
        end

        return false
    end

    local function getColor(entry)
        if entry.kind == "treadmill" then
            return theme.treadmillBounds
        end

        if entry.kind == "trap" then
            return entry.isOwn and theme.trapOwnBorder or theme.trapEnemyBorder
        end

        return theme.treadmillBounds
    end

    local function getThickness(entry)
        if entry.kind == "trap" then
            return layout.trapBoundsThickness
        end

        return layout.treadmillBoundsThickness
    end

    local function drawEntry(entry, camera, lines)
        local corners = Util.getBoxCorners(entry.boundsCenter, entry.boundsHalfSize)
        local color = getColor(entry)
        local thickness = getThickness(entry)

        for edgeIndex, edge in ipairs(Util.BOX_EDGES) do
            local fromPos, toPos, visible = Util.projectBoxEdge(
                camera,
                corners[edge[1]],
                corners[edge[2]]
            )
            local line = lines[edgeIndex]

            if visible then
                line.From = fromPos
                line.To = toPos
                line.Color = color
                line.Thickness = thickness
                line.Visible = true
            else
                line.Visible = false
            end
        end
    end

    local function renderFrame(entries, camera, pool)
        local boxIndex = 0

        for _, entry in ipairs(entries) do
            if shouldDraw(entry) then
                boxIndex = boxIndex + 1
                drawEntry(entry, camera, pool.Acquire(boxIndex))
            end
        end

        pool.HideFrom(boxIndex + 1)
    end

    return {
        DrawEntry = drawEntry,
        RenderFrame = renderFrame,
    }
end

return BoundingBoxRenderer
