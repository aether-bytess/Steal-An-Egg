--[[
    Collect treadmill/trap obstacle rects for pathfinding.
]]

local ObstacleData = {}

function ObstacleData.create(deps)
    local Config = deps.Config
    local Util = deps.Util
    local Workspace = deps.Workspace
    local CollectionService = deps.CollectionService
    local Constants = deps.Constants

    local layout = Config.Layout
    local runtime = Config.Runtime
    local placedTrapTag = Constants.TAGS_MAP.Traps.PLACED_TRAP

    local obstacleCache = {
        data = nil,
        origin = nil,
        radius = nil,
        at = 0,
    }

    local function boundsToObstacle(center, halfSize, extraPadding)
        extraPadding = extraPadding or runtime.pathObstaclePadding

        local hx, hz

        if typeof(halfSize) == "Vector3" then
            hx, hz = halfSize.X, halfSize.Z
        else
            hx, hz = halfSize, halfSize
        end

        hx = hx + extraPadding
        hz = hz + extraPadding

        return {
            minX = center.X - hx,
            maxX = center.X + hx,
            minZ = center.Z - hz,
            maxZ = center.Z + hz,
            kind = "obstacle",
        }
    end

    local function resolveTrapBounds(trap)
        local hitbox = trap:FindFirstChild("Hitbox")
        local padding = layout.trapBoundsPadding

        if hitbox and hitbox:IsA("BasePart") then
            return Util.groundBoundsFromPart(hitbox, padding)
        end

        return Util.groundBoundsFromPart(trap, padding)
    end

    local function collectTreadmills(origin, maxRadius)
        local obstacles = {}
        local seen = {}
        local padding = layout.treadmillBoundsPadding
        local renderFolder = Workspace:FindFirstChild("__ClientTreadmillRenders")

        if renderFolder then
            for _, model in ipairs(renderFolder:GetChildren()) do
                if model:IsA("Model") then
                    local slot = model.Name:match("^TreadmillRender_(.+)$")

                    if slot and not seen[slot] then
                        seen[slot] = true
                        local center, halfSize = Util.groundBoundsFromModel(model, padding)

                        if center and (not origin or (Vector3.new(center.X, 0, center.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude <= maxRadius) then
                            table.insert(obstacles, boundsToObstacle(center, halfSize, runtime.pathTreadmillPadding or 8))
                        end
                    end
                end
            end
        end

        local plots = Workspace:FindFirstChild("Plots")

        if plots then
            for _, plot in ipairs(plots:GetChildren()) do
                local slot = plot.Name

                if not seen[slot] then
                    local bottom = plot:FindFirstChild("TreadmillBottom")

                    if bottom and bottom:IsA("BasePart") then
                        seen[slot] = true
                        local groundY = bottom.Position.Y - bottom.Size.Y * 0.5
                        local center, halfSize = Util.groundBoundsFromPart(bottom, padding, groundY)

                        if not origin or (Vector3.new(center.X, 0, center.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude <= maxRadius then
                            table.insert(obstacles, boundsToObstacle(center, halfSize, runtime.pathTreadmillPadding or 8))
                        end
                    end
                end
            end
        end

        return obstacles
    end

    local function collectTraps(origin, maxRadius, avoidOwnTraps)
        local obstacles = {}

        for _, trap in ipairs(CollectionService:GetTagged(placedTrapTag)) do
            if trap:IsA("BasePart") and trap.Parent then
                local owner = trap:GetAttribute("Owner")
                local isOwn = typeof(owner) == "string" and owner == deps.LocalPlayer.Name

                if avoidOwnTraps ~= true or not isOwn then
                    local hitbox = trap:FindFirstChild("Hitbox")
                    local sample = hitbox and hitbox.Position or trap.Position

                    if not origin or (Vector3.new(sample.X, 0, sample.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude <= maxRadius then
                        local center, halfSize = resolveTrapBounds(trap)

                        if center then
                            table.insert(obstacles, boundsToObstacle(center, halfSize, runtime.pathTrapPadding or 6))
                        end
                    end
                end
            end
        end

        return obstacles
    end

    local function collectAround(origin, maxRadius)
        maxRadius = maxRadius or runtime.pathSearchRadius

        local ttl = runtime.obstacleCacheTtl or 1.0
        local now = os.clock()

        if obstacleCache.data
            and obstacleCache.radius == maxRadius
            and obstacleCache.origin
            and (origin - obstacleCache.origin).Magnitude < 12
            and now - obstacleCache.at < ttl then
            return obstacleCache.data
        end

        local treadmills = collectTreadmills(origin, maxRadius)
        local traps = collectTraps(origin, maxRadius, runtime.pathAvoidOwnTraps == true)

        local all = {}

        for _, obstacle in ipairs(treadmills) do
            table.insert(all, obstacle)
        end

        for _, obstacle in ipairs(traps) do
            table.insert(all, obstacle)
        end

        obstacleCache.data = all
        obstacleCache.origin = origin
        obstacleCache.radius = maxRadius
        obstacleCache.at = now

        return all
    end

    return {
        CollectAround = collectAround,
        CollectTreadmills = collectTreadmills,
        CollectTraps = collectTraps,
        InvalidateCache = function()
            obstacleCache.at = 0
        end,
    }
end

return ObstacleData
