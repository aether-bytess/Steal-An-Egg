--[[
    Egg data layer: collect field eggs, resolve models, asset metadata.
]]

local EggData = {}

function EggData.create(deps)
    local Config = deps.Config
    local FarmFilters = deps.FarmFilters
    local Workspace = deps.Workspace
    local LocalPlayer = deps.LocalPlayer
    local EggState = deps.EggState
    local Assets = deps.Assets
    local Areas = deps.Areas
    local STATES = deps.STATES

    local theme = Config.Theme
    local runtime = Config.Runtime

    local cache = {
        all = {},
        at = 0,
    }

    local function getAssetInfo(category)
        local entry = Assets.Directory[category]

        if not entry then
            return {
                name = category,
                rarityId = "Unknown",
                rarityName = "Unknown",
                rarityColor = theme.textMuted,
                rarityValue = "?",
                rarityTier = 0,
                dropWeight = math.huge,
            }
        end

        local rarity = entry.Rarity

        return {
            name = entry.Egg.DisplayName,
            rarityId = rarity._id or "Unknown",
            rarityName = rarity.DisplayName,
            rarityColor = rarity.Color,
            rarityValue = rarity.DefaultRarityValue or ("Tier " .. tostring(rarity.RarityNumber)),
            rarityTier = rarity.RarityNumber or 0,
            dropWeight = entry.DropWeight or math.huge,
        }
    end

    local function resolveModel(uid)
        local direct = Workspace:FindFirstChild(uid)

        if direct and direct:IsA("Model") then
            return direct
        end

        local clientFolder = Workspace:FindFirstChild("AreaEggSlotsClient")

        if clientFolder then
            local clientModel = clientFolder:FindFirstChild(uid)

            if clientModel and clientModel:IsA("Model") then
                return clientModel
            end
        end

        return nil
    end

    local function getWorldPosition(model, record)
        local offset = Vector3.new(0, runtime.positionYOffset, 0)

        if model then
            local eggPoint = model:FindFirstChild("EggPoint", true)

            if eggPoint and eggPoint:IsA("BasePart") then
                return eggPoint.Position + offset
            end

            if model.PrimaryPart then
                return model.PrimaryPart.Position + offset
            end

            return model:GetPivot().Position + offset
        end

        if record and record.BoundsCFrame then
            return record.BoundsCFrame.Position + offset
        end

        return nil
    end

    local AREA_ID_ALIASES = {
        CherryBlossom = "Cherry Blossom",
    }

    local function resolveAreaEntry(areaId)
        if typeof(areaId) ~= "string" then
            return nil, areaId
        end

        local directory = Areas and Areas.Directory

        if not directory then
            return nil, areaId
        end

        local entry = directory[areaId]

        if entry then
            return entry, areaId
        end

        local aliasId = AREA_ID_ALIASES[areaId]

        if aliasId then
            entry = directory[aliasId]

            if entry then
                return entry, aliasId
            end
        end

        for id, config in pairs(directory) do
            if config._id == areaId then
                return config, id
            end
        end

        return nil, areaId
    end

    local function getAreaInfo(areaId)
        if typeof(areaId) ~= "string" then
            return {
                areaId = "Unknown",
                areaName = "Unknown",
                areaTier = 0,
            }
        end

        local entry, resolvedId = resolveAreaEntry(areaId)

        if not entry then
            return {
                areaId = areaId,
                areaName = areaId,
                areaTier = 0,
            }
        end

        local rarity = entry.Rarity

        return {
            areaId = resolvedId,
            areaName = entry.DisplayName or resolvedId,
            areaTier = rarity and rarity.RarityNumber or 0,
        }
    end

    local function compareEggRarity(a, b)
        if a.rarityTier ~= b.rarityTier then
            return a.rarityTier > b.rarityTier
        end

        if runtime.autoFarmInfestedFirst ~= false then
            local aInfested = a.hasParasite == true
            local bInfested = b.hasParasite == true

            if aInfested ~= bInfested then
                return aInfested
            end
        end

        if a.dropWeight ~= b.dropWeight then
            return a.dropWeight < b.dropWeight
        end

        return a.distance < b.distance
    end

    local function sortEggs(results)
        table.sort(results, function(a, b)
            if a.rarityTier ~= b.rarityTier then
                return a.rarityTier > b.rarityTier
            end

            if runtime.autoFarmInfestedFirst ~= false then
                local aInfested = a.hasParasite == true
                local bInfested = b.hasParasite == true

                if aInfested ~= bInfested then
                    return aInfested
                end
            end

            if a.dropWeight ~= b.dropWeight then
                return a.dropWeight < b.dropWeight
            end

            return a.distance < b.distance
        end)
    end

    local function lockCandidatesToMaxTier(candidates)
        if runtime.autoFarmMaxRarityTierLock == false or #candidates == 0 then
            return candidates
        end

        local maxTier = candidates[1].rarityTier or 0

        for index = 2, #candidates do
            local tier = candidates[index].rarityTier or 0

            if tier > maxTier then
                maxTier = tier
            end
        end

        local locked = {}

        for _, egg in ipairs(candidates) do
            if (egg.rarityTier or 0) == maxTier then
                table.insert(locked, egg)
            end
        end

        return locked
    end

    local function passesFarmFilters(egg)
        if not egg then
            return false
        end

        if FarmFilters and FarmFilters.IsEggAllowed then
            return FarmFilters.IsEggAllowed(egg)
        end

        return true
    end

    local function rebuildCache()
        local snapshot = EggState.ReadFieldEggs()
        local results = {}
        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        for _, record in ipairs(snapshot.Records) do
            if record.State == STATES.Slot or record.State == STATES.Dropped then
                local model = resolveModel(record.Uid)
                local worldPos = getWorldPosition(model, record)

                if worldPos then
                    local info = getAssetInfo(record.AssetCategory)
                    local areaInfo = getAreaInfo(record.AreaId)
                    local distance = rootPart and (worldPos - rootPart.Position).Magnitude or 0

                    info.areaId = areaInfo.areaId
                    info.areaName = areaInfo.areaName
                    info.areaTier = areaInfo.areaTier

                    table.insert(results, {
                        uid = record.Uid,
                        kind = "egg",
                        record = record,
                        model = model,
                        worldPos = worldPos,
                        info = info,
                        distance = distance,
                        areaId = areaInfo.areaId,
                        areaName = areaInfo.areaName,
                        areaTier = areaInfo.areaTier,
                        rarityTier = info.rarityTier,
                        rarityNumber = info.rarityTier,
                        dropWeight = info.dropWeight,
                        hasParasite = record.HasParasite == true,
                    })
                end
            end
        end

        sortEggs(results)
        cache.all = results
        cache.at = os.clock()
    end

    local function ensureCache(force)
        local ttl = runtime.eggDataCacheTtl or 0.35

        if force or os.clock() - cache.at >= ttl then
            rebuildCache()
        end
    end

    local function collectAll(force)
        ensureCache(force)
        return cache.all
    end

    local function collect(force)
        ensureCache(force)
        local results = {}
        local maxDistance = runtime.maxDistance

        for _, egg in ipairs(cache.all) do
            if egg.distance <= maxDistance then
                table.insert(results, egg)
            end
        end

        return results
    end

    local function findBestForFarm(_maxDistance, force)
        local eggs = collectAll(force)
        local candidates = {}

        for _, egg in ipairs(eggs) do
            if passesFarmFilters(egg) then
                table.insert(candidates, egg)
            end
        end

        if #candidates == 0 then
            return nil
        end

        candidates = lockCandidatesToMaxTier(candidates)
        table.sort(candidates, compareEggRarity)

        return candidates[1]
    end

    local function findByUid(uid, force)
        if typeof(uid) ~= "string" then
            return nil
        end

        for _, egg in ipairs(collectAll(force)) do
            if egg.uid == uid then
                return egg
            end
        end

        return nil
    end

    return {
        Collect = collect,
        CollectAll = collectAll,
        FindBestForFarm = findBestForFarm,
        FindByUid = findByUid,
        InvalidateCache = function()
            cache.at = 0
        end,
        GetAssetInfo = getAssetInfo,
        ResolveModel = resolveModel,
        GetWorldPosition = getWorldPosition,
    }
end

return EggData
