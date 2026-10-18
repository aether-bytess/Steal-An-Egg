--[[
    Placed trap data via CollectionService tag "PlacedTrap".
]]

local TrapData = {}

function TrapData.create(deps)
    local Config = deps.Config
    local Util = deps.Util
    local CollectionService = deps.CollectionService
    local LocalPlayer = deps.LocalPlayer
    local Constants = deps.Constants
    local Gears = deps.Gears
    local Rarity = deps.Rarity

    local runtime = Config.Runtime
    local theme = Config.Theme
    local placedTrapTag = Constants.TAGS_MAP.Traps.PLACED_TRAP

    local function resolveGearInfo(trap)
        local gearName = trap:GetAttribute("GearName")

        if typeof(gearName) ~= "string" or gearName == "" then
            gearName = "Trap"
        end

        local gear = Gears.Directory[gearName]
        local displayName = gear and gear.DisplayName or gearName
        local rarityKey = gear and gear.Rarity
        local rarity = theme.textMuted

        if typeof(rarityKey) == "string" and Rarity.Rarities[rarityKey] then
            rarity = Rarity.Rarities[rarityKey]
        end

        return {
            gearName = gearName,
            name = displayName,
            rarityName = typeof(rarity) == "table" and rarity.DisplayName or tostring(rarityKey or "Trap"),
            rarityColor = typeof(rarity) == "table" and rarity.Color or theme.trapEnemy,
            rarityValue = trap:GetAttribute("TrapActive") == true and "TRIGGERED" or "ARMED",
            rarityNumber = typeof(rarity) == "table" and (rarity.RarityNumber or 0) or 0,
        }
    end

    local function resolveBounds(trap)
        local hitbox = trap:FindFirstChild("Hitbox")
        local padding = Config.Layout.trapBoundsPadding

        if hitbox and hitbox:IsA("BasePart") then
            return Util.groundBoundsFromPart(hitbox, padding)
        end

        return Util.groundBoundsFromPart(trap, padding)
    end

    local function getWorldPosition(trap)
        local hitbox = trap:FindFirstChild("Hitbox")

        if hitbox and hitbox:IsA("BasePart") then
            return hitbox.Position + Vector3.new(0, hitbox.Size.Y * 0.5 + 0.2, 0)
        end

        return trap.Position + Vector3.new(0, trap.Size.Y * 0.5 + 0.2, 0)
    end

    local function collect()
        if not runtime.showTraps then
            return {}
        end

        local results = {}
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        for _, trap in ipairs(CollectionService:GetTagged(placedTrapTag)) do
            if trap:IsA("BasePart") and trap.Parent then
                local worldPos = getWorldPosition(trap)
                local distance = rootPart and (worldPos - rootPart.Position).Magnitude or 0

                if distance <= runtime.maxDistance then
                    local owner = trap:GetAttribute("Owner")
                    local isOwn = typeof(owner) == "string" and owner == LocalPlayer.Name
                    local boundsCenter, boundsHalfSize = resolveBounds(trap)

                    table.insert(results, {
                        uid = "trap_" .. tostring(trap),
                        kind = "trap",
                        isOwn = isOwn,
                        instance = trap,
                        worldPos = worldPos,
                        boundsCenter = boundsCenter,
                        boundsHalfSize = boundsHalfSize,
                        info = resolveGearInfo(trap),
                        owner = typeof(owner) == "string" and owner or "Unknown",
                        distance = distance,
                        rarityNumber = isOwn and 9000 or 8500,
                    })
                end
            end
        end

        table.sort(results, function(a, b)
            if a.isOwn ~= b.isOwn then
                return a.isOwn
            end

            return a.distance < b.distance
        end)

        return results
    end

    return {
        Collect = collect,
    }
end

return TrapData
