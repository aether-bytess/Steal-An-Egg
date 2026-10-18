--[[
    Grid A* pathfinding on the XZ plane with axis-aligned obstacle rects.
]]

local Pathfinder = {}

local DIRS = {
    { 1, 0, 1 },
    { -1, 0, 1 },
    { 0, 1, 1 },
    { 1, 1, 1.41421356237 },
    { -1, 1, 1.41421356237 },
    { 1, -1, 1.41421356237 },
    { -1, -1, 1.41421356237 },
}

local function segmentIntersectsAABB(x1, z1, x2, z2, minX, minZ, maxX, maxZ)
    local dx = x2 - x1
    local dz = z2 - z1
    local tMin = 0
    local tMax = 1

    local function clip(p, q)
        if math.abs(p) < 1e-8 then
            return q >= 0
        end

        local r = q / p

        if p < 0 then
            if r > tMax then
                return false
            end

            if r > tMin then
                tMin = r
            end
        else
            if r < tMin then
                return false
            end

            if r < tMax then
                tMax = r
            end
        end

        return true
    end

    if not clip(-dx, x1 - minX) then
        return false
    end

    if not clip(dx, maxX - x1) then
        return false
    end

    if not clip(-dz, z1 - minZ) then
        return false
    end

    if not clip(dz, maxZ - z1) then
        return false
    end

    return tMin <= tMax
end

local function isLineClear(x1, z1, x2, z2, obstacles)
    for _, obstacle in ipairs(obstacles) do
        if segmentIntersectsAABB(x1, z1, x2, z2, obstacle.minX, obstacle.minZ, obstacle.maxX, obstacle.maxZ) then
            return false
        end
    end

    return true
end

local function stringPull(points, obstacles)
    if #points <= 2 then
        return points
    end

    local pulled = { points[1] }
    local index = 1

    while index < #points do
        local farthest = index + 1

        for candidate = #points, index + 1, -1 do
            local from = pulled[#pulled]

            if isLineClear(from.X, from.Z, points[candidate].X, points[candidate].Z, obstacles) then
                farthest = candidate
                break
            end
        end

        table.insert(pulled, points[farthest])
        index = farthest
    end

    return pulled
end

function Pathfinder.create()
    local function cellKey(gx, gz)
        return gx .. ":" .. gz
    end

    local function isBlocked(gx, gz, grid)
        if gx < 0 or gz < 0 or gx >= grid.width or gz >= grid.height then
            return true
        end

        return grid.blocked[cellKey(gx, gz)] == true
    end

    local function worldToCell(x, z, grid)
        local gx = math.floor((x - grid.originX) / grid.cellSize)
        local gz = math.floor((z - grid.originZ) / grid.cellSize)
        return gx, gz
    end

    local function cellToWorld(gx, gz, grid)
        local x = grid.originX + (gx + 0.5) * grid.cellSize
        local z = grid.originZ + (gz + 0.5) * grid.cellSize
        return x, z
    end

    local function buildGrid(startPos, goalPos, obstacles, options)
        options = options or {}

        local cellSize = options.cellSize or 4
        local margin = options.margin or 16
        local padding = options.obstaclePadding or 2
        local maxCells = options.maxCells or 9000

        local minX = math.min(startPos.X, goalPos.X) - margin
        local maxX = math.max(startPos.X, goalPos.X) + margin
        local minZ = math.min(startPos.Z, goalPos.Z) - margin
        local maxZ = math.max(startPos.Z, goalPos.Z) + margin

        for _, obstacle in ipairs(obstacles) do
            minX = math.min(minX, obstacle.minX - margin)
            maxX = math.max(maxX, obstacle.maxX + margin)
            minZ = math.min(minZ, obstacle.minZ - margin)
            maxZ = math.max(maxZ, obstacle.maxZ + margin)
        end

        local width = math.max(1, math.ceil((maxX - minX) / cellSize))
        local height = math.max(1, math.ceil((maxZ - minZ) / cellSize))

        while width * height > maxCells do
            cellSize = cellSize + 1
            width = math.max(1, math.ceil((maxX - minX) / cellSize))
            height = math.max(1, math.ceil((maxZ - minZ) / cellSize))
        end

        local blocked = {}

        for gz = 0, height - 1 do
            for gx = 0, width - 1 do
                local x, z = cellToWorld(gx, gz, {
                    originX = minX,
                    originZ = minZ,
                    cellSize = cellSize,
                })

                for _, obstacle in ipairs(obstacles) do
                    if x >= obstacle.minX and x <= obstacle.maxX
                        and z >= obstacle.minZ and z <= obstacle.maxZ then
                        blocked[cellKey(gx, gz)] = true
                        break
                    end
                end
            end
        end

        local startGX, startGZ = worldToCell(startPos.X, startPos.Z, {
            originX = minX,
            originZ = minZ,
            cellSize = cellSize,
        })
        local goalGX, goalGZ = worldToCell(goalPos.X, goalPos.Z, {
            originX = minX,
            originZ = minZ,
            cellSize = cellSize,
        })

        blocked[cellKey(startGX, startGZ)] = nil
        blocked[cellKey(goalGX, goalGZ)] = nil

        return {
            originX = minX,
            originZ = minZ,
            cellSize = cellSize,
            width = width,
            height = height,
            blocked = blocked,
            startGX = startGX,
            startGZ = startGZ,
            goalGX = goalGX,
            goalGZ = goalGZ,
            obstaclePadding = padding,
        }
    end

    local function reconstruct(cameFrom, currentKey, grid, groundY)
        local points = {}
        local key = currentKey

        while key do
            local gx, gz = key:match("^(-?%d+):(-?%d+)$")
            gx = tonumber(gx)
            gz = tonumber(gz)
            local x, z = cellToWorld(gx, gz, grid)
            table.insert(points, 1, Vector3.new(x, groundY, z))
            key = cameFrom[key]
        end

        return points
    end

    local function simplify(points)
        if #points <= 2 then
            return points
        end

        local simplified = { points[1] }

        for index = 2, #points - 1 do
            local prev = simplified[#simplified]
            local current = points[index]
            local nextPoint = points[index + 1]
            local dirA = Vector3.new(current.X - prev.X, 0, current.Z - prev.Z)
            local dirB = Vector3.new(nextPoint.X - current.X, 0, nextPoint.Z - current.Z)

            if dirA.Magnitude > 0.01 and dirB.Magnitude > 0.01 then
                dirA = dirA.Unit
                dirB = dirB.Unit
                local dot = dirA:Dot(dirB)

                if dot < 0.995 then
                    table.insert(simplified, current)
                end
            else
                table.insert(simplified, current)
            end
        end

        table.insert(simplified, points[#points])
        return simplified
    end

    local function findPath(startPos, goalPos, obstacles, options)
        options = options or {}
        local groundY = options.groundY or startPos.Y

        if (Vector3.new(startPos.X, 0, startPos.Z) - Vector3.new(goalPos.X, 0, goalPos.Z)).Magnitude < (options.cellSize or 4) then
            return { startPos, goalPos }, true
        end

        if isLineClear(startPos.X, startPos.Z, goalPos.X, goalPos.Z, obstacles) then
            return {
                Vector3.new(startPos.X, groundY, startPos.Z),
                Vector3.new(goalPos.X, groundY, goalPos.Z),
            }, true
        end

        local grid = buildGrid(startPos, goalPos, obstacles, options)
        local startKey = cellKey(grid.startGX, grid.startGZ)
        local goalKey = cellKey(grid.goalGX, grid.goalGZ)

        local openSet = { startKey }
        local openMap = { [startKey] = true }
        local cameFrom = {}
        local gScore = { [startKey] = 0 }
        local fScore = { [startKey] = 0 }

        local function heuristic(gx, gz)
            local dx = math.abs(gx - grid.goalGX)
            local dz = math.abs(gz - grid.goalGZ)
            return math.max(dx, dz) + (1.41421356237 - 1) * math.min(dx, dz)
        end

        fScore[startKey] = heuristic(grid.startGX, grid.startGZ)

        local iterations = 0
        local maxIterations = options.maxIterations or 12000

        while #openSet > 0 and iterations < maxIterations do
            iterations = iterations + 1

            local bestIndex = 1
            local bestKey = openSet[1]
            local bestScore = fScore[bestKey] or math.huge

            for index = 2, #openSet do
                local key = openSet[index]
                local score = fScore[key] or math.huge

                if score < bestScore then
                    bestScore = score
                    bestKey = key
                    bestIndex = index
                end
            end

            local currentKey = bestKey
            table.remove(openSet, bestIndex)
            openMap[currentKey] = nil

            if currentKey == goalKey then
                local path = reconstruct(cameFrom, currentKey, grid, groundY)
                path[1] = Vector3.new(startPos.X, groundY, startPos.Z)
                path[#path] = Vector3.new(goalPos.X, groundY, goalPos.Z)
                path = simplify(path)
                path = stringPull(path, obstacles)
                return path, true
            end

            local cgx, cgz = currentKey:match("^(-?%d+):(-?%d+)$")
            cgx = tonumber(cgx)
            cgz = tonumber(cgz)

            for _, dir in ipairs(DIRS) do
                local ngx = cgx + dir[1]
                local ngz = cgz + dir[2]

                if not isBlocked(ngx, ngz, grid) then
                    local neighborKey = cellKey(ngx, ngz)
                    local tentative = (gScore[currentKey] or math.huge) + dir[3]

                    if tentative < (gScore[neighborKey] or math.huge) then
                        cameFrom[neighborKey] = currentKey
                        gScore[neighborKey] = tentative
                        fScore[neighborKey] = tentative + heuristic(ngx, ngz)

                        if not openMap[neighborKey] then
                            table.insert(openSet, neighborKey)
                            openMap[neighborKey] = true
                        end
                    end
                end
            end
        end

        return nil, false
    end

    return {
        BuildGrid = buildGrid,
        FindPath = findPath,
        IsLineClear = isLineClear,
    }
end

return Pathfinder
