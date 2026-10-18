--[[
    Detect egg/guard zones where client-only tween desyncs from server hit detection.
]]

local GuardZone = {}

function GuardZone.create(deps)
    local Workspace = deps.Workspace
    local ReplicatedStorage = deps.ReplicatedStorage
    local Config = deps.Config
    local runtime = Config and Config.Runtime or {}

    local GuardAreaGeometry = nil

    pcall(function()
        GuardAreaGeometry = require(ReplicatedStorage.Shared.Util.GuardAreaGeometry)
    end)

    local separationLine = nil
    local areaEntries = {}

    local function getAreasFolder()
        local objects = Workspace:FindFirstChild("__OBJECTS")

        if not objects then
            return nil
        end

        return objects:FindFirstChild("Areas")
    end

    local function rebuildAreaEntries()
        table.clear(areaEntries)

        if not GuardAreaGeometry then
            return
        end

        local areasFolder = getAreasFolder()

        if not areasFolder then
            return
        end

        separationLine = areasFolder:FindFirstChild("SeparationLine")

        local guardAreas = areasFolder:FindFirstChild("GuardAreas")

        if guardAreas then
            for _, entry in ipairs(GuardAreaGeometry.ReadAreaBounds(guardAreas)) do
                table.insert(areaEntries, entry)
            end
        end

        local cherryBlossom = areasFolder:FindFirstChild("CherryBlossom")
        local bounds = cherryBlossom and cherryBlossom:FindFirstChild("Bounds")

        if bounds and bounds:IsA("BasePart") then
            table.insert(areaEntries, {
                AreaId = "CherryBlossom",
                Bounds = bounds,
            })
        end
    end

    local function isPastSeparationLine(position)
        if not GuardAreaGeometry or not separationLine or not position then
            return false
        end

        return GuardAreaGeometry.IsPastLine(separationLine, position)
    end

    local function isWithinGuardFootprint(position)
        if not GuardAreaGeometry or not position then
            return false
        end

        for _, entry in ipairs(areaEntries) do
            local bounds = entry.Bounds

            if bounds and bounds.Parent and GuardAreaGeometry.IsWithinFootprint(bounds, position) then
                return true
            end
        end

        return false
    end

    local function isGuardZonePosition(position)
        if not position then
            return false
        end

        if #areaEntries == 0 and not separationLine then
            rebuildAreaEntries()
        end

        return isPastSeparationLine(position) or isWithinGuardFootprint(position)
    end

    local function horizontalDistance(a, b)
        return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
    end

    local function shouldUseWalkMovement(fromPos, toPos)
        if not fromPos then
            return false
        end

        if isGuardZonePosition(fromPos) then
            return true
        end

        if not toPos or not isGuardZonePosition(toPos) then
            return false
        end

        local approach = runtime.guardZoneWalkApproach or runtime.pickupApproachRadius or 80

        return horizontalDistance(fromPos, toPos) <= approach
    end

    rebuildAreaEntries()

    return {
        Refresh = rebuildAreaEntries,
        IsPastSeparationLine = isPastSeparationLine,
        IsWithinGuardFootprint = isWithinGuardFootprint,
        IsGuardZonePosition = isGuardZonePosition,
        ShouldUseWalkMovement = shouldUseWalkMovement,
    }
end

return GuardZone
