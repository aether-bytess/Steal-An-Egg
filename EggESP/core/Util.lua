--[[
    Shared helpers: math, screen projection, text formatting.
]]

local Util = {}

function Util.formatDistance(studs)
    if studs >= 1000 then
        return string.format("%.1fkm", studs / 1000)
    end

    return string.format("%dm", math.floor(studs + 0.5))
end

function Util.rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

function Util.worldToScreen(camera, worldPos)
    local screenPos, onScreen = camera:WorldToViewportPoint(worldPos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

function Util.isValidScreenPoint(pos)
    if not pos then
        return false
    end

    return pos.X == pos.X and pos.Y == pos.Y
        and math.abs(pos.X) < 100000
        and math.abs(pos.Y) < 100000
end

function Util.isReasonableScreenLine(from, to, viewportSize)
    if not Util.isValidScreenPoint(from) or not Util.isValidScreenPoint(to) then
        return false
    end

    local dx = to.X - from.X
    local dy = to.Y - from.Y
    local maxLen = math.max(viewportSize.X, viewportSize.Y) * 2.5

    return (dx * dx + dy * dy) <= maxLen * maxLen
end

function Util.clipWorldEdge(worldA, worldB, depthA, depthB, minDepth)
    minDepth = minDepth or 0.05

    if depthA <= minDepth and depthB <= minDepth then
        return nil, nil, false
    end

    local pointA, pointB = worldA, worldB

    if depthA <= minDepth then
        local delta = depthB - depthA

        if math.abs(delta) < 1e-6 then
            return nil, nil, false
        end

        local t = (minDepth - depthA) / delta

        if t <= 0 or t >= 1 then
            return nil, nil, false
        end

        pointA = worldA:Lerp(worldB, t)
    elseif depthB <= minDepth then
        local delta = depthA - depthB

        if math.abs(delta) < 1e-6 then
            return nil, nil, false
        end

        local t = (minDepth - depthB) / delta

        if t <= 0 or t >= 1 then
            return nil, nil, false
        end

        pointB = worldB:Lerp(worldA, t)
    end

    return pointA, pointB, true
end

function Util.projectBoxEdge(camera, worldA, worldB)
    local posA, _, depthA = Util.worldToScreen(camera, worldA)
    local posB, _, depthB = Util.worldToScreen(camera, worldB)
    local clipA, clipB, ok = Util.clipWorldEdge(worldA, worldB, depthA, depthB)

    if not ok then
        return nil, nil, false
    end

    if clipA ~= worldA then
        posA = Util.worldToScreen(camera, clipA)
    end

    if clipB ~= worldB then
        posB = Util.worldToScreen(camera, clipB)
    end

    local _, _, finalDepthA = Util.worldToScreen(camera, clipA)
    local _, _, finalDepthB = Util.worldToScreen(camera, clipB)

    if finalDepthA <= 0.05 or finalDepthB <= 0.05 then
        return nil, nil, false
    end

    if not Util.isReasonableScreenLine(posA, posB, camera.ViewportSize) then
        return nil, nil, false
    end

    return posA, posB, true
end

function Util.projectPathSegment(camera, worldA, worldB)
    return Util.projectBoxEdge(camera, worldA, worldB)
end

function Util.metersToStuds(meters)
    return meters * (1 / 0.28)
end

function Util.getPartWorldAABB(part)
    local cf = part.CFrame
    local size = part.Size
    local hx = size.X * 0.5
    local hy = size.Y * 0.5
    local hz = size.Z * 0.5
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

    for _, sx in ipairs({ -1, 1 }) do
        for _, sy in ipairs({ -1, 1 }) do
            for _, sz in ipairs({ -1, 1 }) do
                local point = cf:PointToWorldSpace(Vector3.new(hx * sx, hy * sy, hz * sz))
                minX = math.min(minX, point.X)
                minY = math.min(minY, point.Y)
                minZ = math.min(minZ, point.Z)
                maxX = math.max(maxX, point.X)
                maxY = math.max(maxY, point.Y)
                maxZ = math.max(maxZ, point.Z)
            end
        end
    end

    return minX, minY, minZ, maxX, maxY, maxZ
end

function Util.mergeAABB(aMinX, aMinY, aMinZ, aMaxX, aMaxY, aMaxZ, bMinX, bMinY, bMinZ, bMaxX, bMaxY, bMaxZ)
    return
        math.min(aMinX, bMinX),
        math.min(aMinY, bMinY),
        math.min(aMinZ, bMinZ),
        math.max(aMaxX, bMaxX),
        math.max(aMaxY, bMaxY),
        math.max(aMaxZ, bMaxZ)
end

function Util.groundBoundsFromAABB(minX, minY, minZ, maxX, maxY, maxZ, paddingXZ, groundY)
    paddingXZ = paddingXZ or 1.05

    local halfX = (maxX - minX) * 0.5 * paddingXZ
    local halfZ = (maxZ - minZ) * 0.5 * paddingXZ
    local bottomY = groundY or minY
    local topY = maxY
    local halfY = math.max((topY - bottomY) * 0.5, 0.05)
    local center = Vector3.new((minX + maxX) * 0.5, bottomY + halfY, (minZ + maxZ) * 0.5)

    return center, Vector3.new(halfX, halfY, halfZ)
end

function Util.groundBoundsFromPart(part, paddingXZ, groundY)
    local minX, minY, minZ, maxX, maxY, maxZ = Util.getPartWorldAABB(part)
    return Util.groundBoundsFromAABB(minX, minY, minZ, maxX, maxY, maxZ, paddingXZ, groundY)
end

function Util.groundBoundsFromModel(model, paddingXZ, groundY)
    local cf, size = model:GetBoundingBox()
    local half = size * 0.5
    local minX = cf.Position.X - half.X
    local minY = cf.Position.Y - half.Y
    local minZ = cf.Position.Z - half.Z
    local maxX = cf.Position.X + half.X
    local maxY = cf.Position.Y + half.Y
    local maxZ = cf.Position.Z + half.Z

    return Util.groundBoundsFromAABB(minX, minY, minZ, maxX, maxY, maxZ, paddingXZ, groundY)
end

function Util.estimateTextWidth(text, fontSize)
    local bytes = 0

    for i = 1, #text do
        local byte = string.byte(text, i)

        if byte and byte < 128 then
            bytes = bytes + 1
        else
            bytes = bytes + 2
        end
    end

    return bytes * fontSize * 0.62
end

function Util.getBoxCorners(center, halfSize)
    local hx, hy, hz

    if typeof(halfSize) == "Vector3" then
        hx, hy, hz = halfSize.X, halfSize.Y, halfSize.Z
    else
        hx, hy, hz = halfSize, halfSize, halfSize
    end

    local cx, cy, cz = center.X, center.Y, center.Z

    return {
        Vector3.new(cx - hx, cy - hy, cz - hz),
        Vector3.new(cx + hx, cy - hy, cz - hz),
        Vector3.new(cx - hx, cy - hy, cz + hz),
        Vector3.new(cx + hx, cy - hy, cz + hz),
        Vector3.new(cx - hx, cy + hy, cz - hz),
        Vector3.new(cx + hx, cy + hy, cz - hz),
        Vector3.new(cx - hx, cy + hy, cz + hz),
        Vector3.new(cx + hx, cy + hy, cz + hz),
    }
end

Util.BOX_EDGES = {
    { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 },
    { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 },
    { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 },
}

function Util.createDrawing(className, props)
    local obj = Drawing.new(className)

    for key, value in pairs(props) do
        obj[key] = value
    end

    return obj
end

return Util
