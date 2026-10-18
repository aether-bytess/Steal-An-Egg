--[[
    Auto hatch ready eggs, fuse duplicate pets (3+ same category), equip best.
]]

local PetAutomation = {}

function PetAutomation.create(deps)
    local Config = deps.Config
    local Save = deps.Save
    local Eggs = deps.Eggs
    local EggState = deps.EggState
    local Remotes = deps.Remotes
    local PlacedEggRenderer = deps.PlacedEggRenderer
    local LocalPlayer = deps.LocalPlayer
    local Workspace = deps.Workspace
    local FuseKernel = require(deps.ReplicatedStorage.Shared.Util.FuseKernel)

    local runtime = Config.Runtime

    local state = {
        lastWearBestAt = 0,
        pendingWearBest = false,
        lastActionAt = 0,
        detail = nil,
        lastHatchUid = nil,
        hatchCooldownUntil = 0,
    }

    local function getSave()
        return Save.Get()
    end

    local function isEnabled()
        if runtime.autoPetCareEnabled == false then
            return false
        end

        return runtime.autoHatchEnabled ~= false
            or runtime.autoFuseEnabled ~= false
            or runtime.autoEquipBest ~= false
    end

    local function setDetail(detail)
        if state.detail ~= detail then
            state.detail = detail

            if detail then
                print(string.format("[EggESP Pet] %s", detail))
            end
        end
    end

    local function now()
        return Workspace:GetServerTimeNow()
    end

    local function canWearBest()
        local cooldown = runtime.equipBestCooldown or 5

        return now() - state.lastWearBestAt >= cooldown
    end

    local function requestWearBest(force)
        if runtime.autoEquipBest == false then
            return false
        end

        if not force and not canWearBest() then
            state.pendingWearBest = true
            return false
        end

        local ok, result = pcall(function()
            return Remotes.Haul.WearBest:InvokeServer()
        end)

        state.lastWearBestAt = now()

        if ok and typeof(result) == "table" and result[1] == true then
            state.pendingWearBest = false
            setDetail("equipped best pets")
            return true
        end

        state.pendingWearBest = true
        return false
    end

    local function flushWearBest()
        if state.pendingWearBest and canWearBest() then
            requestWearBest(true)
        end
    end

    local function isUidInFusionSlots(saveData, uid)
        for _, slotUid in ipairs(saveData.FusionSlots or {}) do
            if slotUid == uid then
                return true
            end
        end

        return false
    end

    local function isEquipped(saveData, uid)
        for _, equippedUid in ipairs(saveData.EquippedAssets or {}) do
            if equippedUid == uid then
                return true
            end
        end

        return false
    end

    local function collectFusableByCategory(saveData)
        local groups = {}

        for uid, item in pairs(saveData.Inventory or {}) do
            if not isUidInFusionSlots(saveData, uid) and not isEquipped(saveData, uid) then
                local allowed = FuseKernel.MayEnterFuse(uid, item, nil, false)

                if allowed then
                    local category = item.Category
                    local bucket = groups[category]

                    if not bucket then
                        bucket = {}
                        groups[category] = bucket
                    end

                    table.insert(bucket, uid)
                end
            end
        end

        return groups
    end

    local function getFusionSlotCategory(saveData)
        for _, uid in ipairs(saveData.FusionSlots or {}) do
            if uid then
                local item = saveData.Inventory[uid]

                if item then
                    return item.Category, uid
                end
            end
        end

        return nil
    end

    local function countFilledFusionSlots(saveData)
        local count = 0

        for _, uid in ipairs(saveData.FusionSlots or {}) do
            if uid then
                count = count + 1
            end
        end

        return count
    end

    local function ensureFusionBriefing()
        local saveData = getSave()

        if not saveData or saveData.FusionInfoAcknowledged then
            return true
        end

        local ok, result = pcall(function()
            return Remotes.Fusery.ConfirmBriefing:InvokeServer()
        end)

        return ok and result == true
    end

    local function tryFinishFuseReveal(saveData)
        if saveData.FusionEggReward == false then
            return false
        end

        setDetail("finishing fuse reveal")

        local ok, success = pcall(function()
            return Remotes.Fusery.FinishReveal:InvokeServer()
        end)

        if ok and success == true then
            state.pendingWearBest = true
            setDetail("fuse complete")
            return true
        end

        return false
    end

    local function tryLoadFusionPet(uid)
        local ok, success, err = pcall(function()
            return Remotes.Fusery.LoadPet:InvokeServer(uid)
        end)

        if not ok then
            return false, tostring(success)
        end

        if success == true then
            return true
        end

        return false, typeof(err) == "string" and err or "load failed"
    end

    local function tryBeginFuse(saveData)
        if countFilledFusionSlots(saveData) < 3 then
            return false
        end

        if saveData.FusionLocked or saveData.FusionEggReward ~= false then
            return false
        end

        local eggCount = 0

        for _ in pairs(saveData.EggInventory or {}) do
            eggCount = eggCount + 1
        end

        if eggCount >= Eggs.MAX_INVENTORY then
            setDetail("fuse blocked - egg bag full")
            return false
        end

        if not ensureFusionBriefing() then
            return false
        end

        setDetail("starting fuse")

        local ok, success, err = pcall(function()
            return Remotes.Fusery.BeginFuse:InvokeServer()
        end)

        if not ok then
            return false
        end

        if success ~= true then
            local message = typeof(err) == "string" and err or "begin fuse failed"
            setDetail(message)
            return false
        end

        setDetail("fuse started")
        return true
    end

    local function tryContinueFusion(saveData)
        if saveData.FusionLocked then
            return tryFinishFuseReveal(saveData)
        end

        if saveData.FusionEggReward ~= false then
            return tryFinishFuseReveal(saveData)
        end

        local filled = countFilledFusionSlots(saveData)

        if filled >= 3 then
            return tryBeginFuse(saveData)
        end

        if filled == 0 then
            return false
        end

        local requiredCategory = getFusionSlotCategory(saveData)

        if not requiredCategory then
            return false
        end

        local groups = collectFusableByCategory(saveData)
        local candidates = groups[requiredCategory]

        if not candidates or #candidates == 0 then
            return false
        end

        for _, uid in ipairs(candidates) do
            if countFilledFusionSlots(getSave() or saveData) >= 3 then
                break
            end

            local loaded = tryLoadFusionPet(uid)

            if loaded then
                setDetail(string.format("loaded fuse pet %s", uid:sub(1, 8)))
                return true
            end
        end

        return false
    end

    local function tryStartNewFusion(saveData)
        if runtime.autoFuseEnabled == false then
            return false
        end

        if saveData.FusionLocked or saveData.FusionEggReward ~= false then
            return false
        end

        if countFilledFusionSlots(saveData) > 0 then
            return false
        end

        local minCount = runtime.autoFuseMinCount or 3
        local groups = collectFusableByCategory(saveData)
        local bestCategory
        local bestUids

        for category, uids in pairs(groups) do
            if #uids >= minCount then
                if not bestUids or #uids > #bestUids then
                    bestCategory = category
                    bestUids = uids
                end
            end
        end

        if not bestUids then
            return false
        end

        local loaded = 0

        for index = 1, math.min(3, #bestUids) do
            if tryLoadFusionPet(bestUids[index]) then
                loaded = loaded + 1
            end
        end

        if loaded > 0 then
            setDetail(string.format("loading %s for fuse (%d/3)", bestCategory, loaded))
            return true
        end

        return false
    end

    local function collectReadyEggUids()
        local ready = {}
        local eggs = EggState.ReadOwnerEggs(LocalPlayer.UserId)

        for uid, record in pairs(eggs) do
            if record.Placement ~= nil and EggState.IsReadyToHatch(uid) then
                table.insert(ready, uid)
            end
        end

        table.sort(ready)
        return ready
    end

    local function hatchEgg(uid)
        if now() < state.hatchCooldownUntil then
            return false
        end

        setDetail(string.format("hatching %s", uid:sub(1, 8)))

        local activated, activateErr = PlacedEggRenderer.ActivateLocalEgg(uid)

        if activated == true then
            state.lastHatchUid = uid
            state.hatchCooldownUntil = now() + 2
            state.pendingWearBest = true
            return true
        end

        local began, beginErr = EggState.BeginHatch(uid)

        if began ~= true then
            setDetail(typeof(beginErr) == "string" and beginErr or "hatch begin failed")
            return false
        end

        local finished, finishErr = EggState.FinishHatch(uid)

        if finished == true then
            state.lastHatchUid = uid
            state.hatchCooldownUntil = now() + 1.5
            state.pendingWearBest = true
            setDetail("hatched egg")
            return true
        end

        setDetail(typeof(finishErr) == "string" and finishErr or "hatch finish failed")
        return false
    end

    local function tryHatchReadyEggs()
        if runtime.autoHatchEnabled == false then
            return false
        end

        local ready = collectReadyEggUids()

        for _, uid in ipairs(ready) do
            if uid ~= state.lastHatchUid or #ready == 1 then
                if hatchEgg(uid) then
                    return true
                end
            end
        end

        if #ready > 0 and ready[1] then
            return hatchEgg(ready[1])
        end

        return false
    end

    local function tick()
        if not isEnabled() then
            return false
        end

        local saveData = getSave()

        if not saveData then
            return false
        end

        if tryFinishFuseReveal(saveData) then
            flushWearBest()
            return true
        end

        if tryContinueFusion(saveData) then
            return true
        end

        if tryStartNewFusion(saveData) then
            return true
        end

        if tryHatchReadyEggs() then
            flushWearBest()
            return true
        end

        flushWearBest()
        return false
    end

    local function getStatus()
        local saveData = getSave()
        local readyCount = #collectReadyEggUids()
        local fuseGroups = saveData and collectFusableByCategory(saveData) or {}
        local fuseReady = 0

        for _, uids in pairs(fuseGroups) do
            if #uids >= (runtime.autoFuseMinCount or 3) then
                fuseReady = fuseReady + 1
            end
        end

        return {
            enabled = isEnabled(),
            detail = state.detail,
            readyEggs = readyCount,
            fuseableGroups = fuseReady,
            pendingWearBest = state.pendingWearBest,
            fusionLocked = saveData and saveData.FusionLocked or false,
            fusionSlots = saveData and countFilledFusionSlots(saveData) or 0,
        }
    end

    return {
        Tick = tick,
        GetStatus = getStatus,
        RequestWearBest = requestWearBest,
    }
end

return PetAutomation
