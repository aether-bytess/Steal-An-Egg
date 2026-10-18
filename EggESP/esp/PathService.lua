--[[
    Obstacle-avoiding path computation for auto farm movement.
]]

local PathService = {}

function PathService.create(deps)
    local Config = deps.Config
    local ObstacleData = deps.ObstacleData
    local Pathfinder = deps.Pathfinder

    local runtime = Config.Runtime

    local function mergeObstacles(...)
        local merged = {}
        local seen = {}

        for _, list in ipairs({ ... }) do
            if list then
                for _, obstacle in ipairs(list) do
                    local key = string.format(
                        "%.1f:%.1f:%.1f:%.1f",
                        obstacle.minX,
                        obstacle.minZ,
                        obstacle.maxX,
                        obstacle.maxZ
                    )

                    if not seen[key] then
                        seen[key] = true
                        table.insert(merged, obstacle)
                    end
                end
            end
        end

        return merged
    end

    local function collectObstaclesForSegment(playerPos, goalPos)
        local groundY = playerPos.Y - 2.5
        local startPos = Vector3.new(playerPos.X, groundY, playerPos.Z)
        local goalFlat = Vector3.new(goalPos.X, groundY, goalPos.Z)
        local segmentLength = (startPos - goalFlat).Magnitude
        local searchRadius = math.max(
            runtime.pathSearchRadius,
            segmentLength + runtime.pathSearchMargin
        )

        local midPos = startPos:Lerp(goalFlat, 0.5)

        local startObstacles = ObstacleData.CollectAround(startPos, searchRadius)
        local midObstacles = ObstacleData.CollectAround(midPos, searchRadius)
        local goalObstacles = ObstacleData.CollectAround(goalFlat, searchRadius)

        return startPos, goalFlat, mergeObstacles(startObstacles, midObstacles, goalObstacles)
    end

    local function computePathBetween(playerPos, goalPos)
        local startPos, goalFlat, obstacles = collectObstaclesForSegment(playerPos, goalPos)
        local groundY = startPos.Y

        return Pathfinder.FindPath(startPos, goalFlat, obstacles, {
            cellSize = runtime.pathCellSize,
            margin = runtime.pathSearchMargin,
            obstaclePadding = runtime.pathObstaclePadding,
            maxCells = runtime.pathMaxCells,
            groundY = groundY + runtime.pathDrawYOffset,
            maxIterations = runtime.pathMaxIterations,
        })
    end

    local function isLineClearBetween(playerPos, goalPos)
        if not playerPos or not goalPos then
            return false
        end

        local startPos, goalFlat, obstacles = collectObstaclesForSegment(playerPos, goalPos)

        return Pathfinder.IsLineClear(startPos.X, startPos.Z, goalFlat.X, goalFlat.Z, obstacles)
    end

    return {
        ComputePathBetween = computePathBetween,
        IsLineClearBetween = isLineClearBetween,
        Invalidate = function()
            if ObstacleData.InvalidateCache then
                ObstacleData.InvalidateCache()
            end
        end,
    }
end

return PathService
