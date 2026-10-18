--[[
    Auto farm filters — allowed egg rarities and field zones.
]]

local FarmFilters = {}

local AREA_ID_ALIASES = {
    CherryBlossom = "Cherry Blossom",
}

function FarmFilters.create(deps)
    local Config = deps.Config
    local Rarity = deps.Rarity
    local Areas = deps.Areas
    local Assets = deps.Assets

    local runtime = Config.Runtime

    local rarityOptions = {}
    local zoneOptions = {}
    local rarityByKey = {}
    local zoneById = {}

    local function resolveZoneId(areaId)
        if typeof(areaId) ~= "string" then
            return nil
        end

        if zoneById[areaId] then
            return areaId
        end

        local aliasId = AREA_ID_ALIASES[areaId]

        if aliasId and zoneById[aliasId] then
            return aliasId
        end

        for id, option in pairs(zoneById) do
            if option.label == areaId then
                return id
            end
        end

        return areaId
    end

    local function buildOptions()
        rarityOptions = {}
        rarityByKey = {}
        zoneOptions = {}
        zoneById = {}

        local rarityGroups = {}

        if Assets and Assets.Directory then
            for _, entry in pairs(Assets.Directory) do
                local rarity = entry and entry.Rarity

                if typeof(rarity) == "table" then
                    local key = rarity._id or rarity.DisplayName or "Unknown"
                    local group = rarityGroups[key]

                    if not group then
                        group = {
                            key = key,
                            label = rarity.DisplayName or key,
                            tier = rarity.RarityNumber or 0,
                            ids = {},
                        }
                        rarityGroups[key] = group
                    end

                    local found = false

                    for _, existingId in ipairs(group.ids) do
                        if existingId == key then
                            found = true
                            break
                        end
                    end

                    if not found then
                        table.insert(group.ids, key)
                    end
                end
            end
        end

        if next(rarityGroups) == nil and Rarity and Rarity.Rarities then
            for id, entry in pairs(Rarity.Rarities) do
                local key = entry._id or id

                rarityGroups[key] = {
                    key = key,
                    label = entry.DisplayName or id,
                    tier = entry.RarityNumber or 0,
                    ids = { id },
                }
            end
        end

        for _, group in pairs(rarityGroups) do
            table.insert(rarityOptions, group)
            rarityByKey[group.key] = group
        end

        table.sort(rarityOptions, function(a, b)
            if a.tier ~= b.tier then
                return a.tier < b.tier
            end

            return a.label < b.label
        end)

        if Areas and Areas.Directory then
            for id, entry in pairs(Areas.Directory) do
                local zoneId = entry._id or id
                local option = {
                    id = zoneId,
                    label = entry.DisplayName or zoneId,
                    tier = entry.Rarity and entry.Rarity.RarityNumber or 0,
                }

                zoneById[zoneId] = option
                table.insert(zoneOptions, option)
            end
        end

        for aliasId, canonicalId in pairs(AREA_ID_ALIASES) do
            if zoneById[canonicalId] then
                zoneById[aliasId] = zoneById[canonicalId]
            end
        end

        table.sort(zoneOptions, function(a, b)
            if a.tier ~= b.tier then
                return a.tier < b.tier
            end

            return a.label < b.label
        end)
    end

    buildOptions()

    local function isMutantRecord(record)
        if typeof(record) ~= "table" then
            return false
        end

        if typeof(record.BaseMutation) == "string" and record.BaseMutation ~= "" then
            return true
        end

        local mutations = record.Mutations

        if typeof(mutations) ~= "table" then
            return false
        end

        if #mutations > 0 then
            return true
        end

        for _ in pairs(mutations) do
            return true
        end

        return false
    end

    local function isInfestedRecord(record)
        return typeof(record) == "table" and record.HasParasite == true
    end

    local function ensureRarityTable()
        if runtime.autoFarmRarities ~= nil then
            return
        end

        runtime.autoFarmRarities = {}

        for _, option in ipairs(rarityOptions) do
            for _, id in ipairs(option.ids) do
                runtime.autoFarmRarities[id] = true
            end
        end
    end

    local function ensureZoneTable()
        if runtime.autoFarmZones ~= nil then
            return
        end

        runtime.autoFarmZones = {}

        for _, option in ipairs(zoneOptions) do
            runtime.autoFarmZones[option.id] = true
        end
    end

    local function ensureSellRarityTable()
        if runtime.autoSellRarities ~= nil then
            return
        end

        runtime.autoSellRarities = {}

        for _, option in ipairs(rarityOptions) do
            for _, id in ipairs(option.ids) do
                runtime.autoSellRarities[id] = false
            end
        end
    end

    local function ensureTables()
        ensureRarityTable()
        ensureZoneTable()
        ensureSellRarityTable()
    end

    local function isRarityEnabled(rarityId)
        if typeof(rarityId) ~= "string" then
            return runtime.autoFarmFilterWhitelist ~= true
        end

        ensureRarityTable()

        if runtime.autoFarmFilterWhitelist == true then
            if runtime.autoFarmRarities[rarityId] == true then
                return true
            end

            local option = rarityByKey[rarityId]

            if option then
                for _, id in ipairs(option.ids) do
                    if runtime.autoFarmRarities[id] == true then
                        return true
                    end
                end
            end

            return false
        end

        if runtime.autoFarmRarities[rarityId] ~= nil then
            return runtime.autoFarmRarities[rarityId] == true
        end

        local option = rarityByKey[rarityId]

        if option then
            for _, id in ipairs(option.ids) do
                if runtime.autoFarmRarities[id] == false then
                    return false
                end
            end
        end

        return true
    end

    local function isZoneEnabled(areaId)
        if typeof(areaId) ~= "string" then
            return runtime.autoFarmFilterWhitelist ~= true
        end

        ensureZoneTable()

        local resolvedId = resolveZoneId(areaId)

        if runtime.autoFarmFilterWhitelist == true then
            if runtime.autoFarmZones[resolvedId] == true then
                return true
            end

            for aliasId, canonicalId in pairs(AREA_ID_ALIASES) do
                if resolvedId == aliasId or resolvedId == canonicalId then
                    if runtime.autoFarmZones[aliasId] == true or runtime.autoFarmZones[canonicalId] == true then
                        return true
                    end
                end
            end

            return false
        end

        local allowed = runtime.autoFarmZones[resolvedId]

        if allowed == nil then
            return true
        end

        return allowed == true
    end

    local function isSellRarityEnabled(rarityId)
        if typeof(rarityId) ~= "string" then
            return runtime.autoSellFilterWhitelist ~= true
        end

        ensureSellRarityTable()

        if runtime.autoSellFilterWhitelist == true then
            if runtime.autoSellRarities[rarityId] == true then
                return true
            end

            local option = rarityByKey[rarityId]

            if option then
                for _, id in ipairs(option.ids) do
                    if runtime.autoSellRarities[id] == true then
                        return true
                    end
                end
            end

            return false
        end

        if runtime.autoSellRarities[rarityId] ~= nil then
            return runtime.autoSellRarities[rarityId] == true
        end

        local option = rarityByKey[rarityId]

        if option then
            for _, id in ipairs(option.ids) do
                if runtime.autoSellRarities[id] == false then
                    return false
                end
            end
        end

        return true
    end

    local function setSellRarityEnabled(key, enabled)
        ensureSellRarityTable()

        local option = rarityByKey[key]

        if not option then
            return false
        end

        for _, id in ipairs(option.ids) do
            runtime.autoSellRarities[id] = enabled == true
        end

        return true
    end

    local function getSellRarityEnabled(key)
        ensureSellRarityTable()

        local option = rarityByKey[key]

        if not option then
            return false
        end

        for _, id in ipairs(option.ids) do
            if runtime.autoSellRarities[id] == true then
                return true
            end
        end

        return false
    end

    local function setAllSellRarities(enabled)
        ensureSellRarityTable()

        for _, option in ipairs(rarityOptions) do
            setSellRarityEnabled(option.key, enabled)
        end
    end

    local function isEggAllowed(egg)
        if not egg then
            return false
        end

        local rarityId = egg.info and egg.info.rarityId or egg.rarityId
        local areaId = egg.areaId or (egg.info and egg.info.areaId)

        if runtime.autoFarmMutantOnly == true and not isMutantRecord(egg.record) then
            return false
        end

        if runtime.autoFarmInfestedOnly == true and not isInfestedRecord(egg.record) then
            return false
        end

        return isRarityEnabled(rarityId) and isZoneEnabled(areaId)
    end

    local function setRarityEnabled(key, enabled)
        ensureRarityTable()

        local option = rarityByKey[key]

        if not option then
            return false
        end

        for _, id in ipairs(option.ids) do
            runtime.autoFarmRarities[id] = enabled == true
        end

        return true
    end

    local function setZoneEnabled(zoneId, enabled)
        ensureZoneTable()

        local resolvedId = resolveZoneId(zoneId)
        runtime.autoFarmZones[resolvedId] = enabled == true

        for aliasId, canonicalId in pairs(AREA_ID_ALIASES) do
            if resolvedId == canonicalId or resolvedId == aliasId then
                runtime.autoFarmZones[aliasId] = enabled == true
                runtime.autoFarmZones[canonicalId] = enabled == true
            end
        end

        return true
    end

    local function getRarityEnabled(key)
        ensureRarityTable()

        local option = rarityByKey[key]

        if not option then
            return true
        end

        for _, id in ipairs(option.ids) do
            if runtime.autoFarmRarities[id] == false then
                return false
            end
        end

        return true
    end

    local function getZoneEnabled(zoneId)
        ensureZoneTable()

        if runtime.autoFarmZones[zoneId] == false then
            return false
        end

        return true
    end

    local function setAllRarities(enabled)
        ensureRarityTable()

        for _, option in ipairs(rarityOptions) do
            setRarityEnabled(option.key, enabled)
        end
    end

    local function setAllZones(enabled)
        ensureZoneTable()

        for _, option in ipairs(zoneOptions) do
            runtime.autoFarmZones[option.id] = enabled == true
        end
    end

    return {
        GetRarityOptions = function()
            return rarityOptions
        end,
        GetZoneOptions = function()
            return zoneOptions
        end,
        EnsureInitialized = ensureTables,
        IsEggAllowed = isEggAllowed,
        IsMutantRecord = isMutantRecord,
        IsInfestedRecord = isInfestedRecord,
        IsRarityEnabled = isRarityEnabled,
        IsZoneEnabled = isZoneEnabled,
        GetRarityEnabled = getRarityEnabled,
        GetZoneEnabled = getZoneEnabled,
        SetRarityEnabled = setRarityEnabled,
        SetZoneEnabled = setZoneEnabled,
        SetAllRarities = setAllRarities,
        SetAllZones = setAllZones,
        IsSellRarityEnabled = isSellRarityEnabled,
        GetSellRarityEnabled = getSellRarityEnabled,
        SetSellRarityEnabled = setSellRarityEnabled,
        SetAllSellRarities = setAllSellRarities,
        ResolveZoneId = resolveZoneId,
        RebuildOptions = buildOptions,
    }
end

return FarmFilters
