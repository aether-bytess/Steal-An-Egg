--[[
    Inventory management when egg bag is full:
    1. Feed parasite eggs to Monster Parasite (frog) when event is active
    2. Place unplaced eggs on plot, best rarity first
    3. If plot has no room, sell all remaining unplaced eggs
]]

local InventoryManager = {}

function InventoryManager.create(deps)
    local Config = deps.Config
    local Save = deps.Save
    local Eggs = deps.Eggs
    local Assets = deps.Assets
    local EggState = deps.EggState
    local PlotState = deps.PlotState
    local Remotes = deps.Remotes
    local Movement = deps.Movement
    local LocalPlayer = deps.LocalPlayer
    local Workspace = deps.Workspace
    local MonsterParasiteData = deps.MonsterParasiteData
    local PlacedEggRenderer = deps.PlacedEggRenderer
    local FarmFilters = deps.FarmFilters
    local AutoFarm = nil

    local runtime = Config.Runtime

    local PHASE = {
        Idle = "Idle",
        FeedParasite = "FeedParasite",
        GoToPlot = "GoToPlot",
        GoToMonster = "GoToMonster",
        PlaceEgg = "PlaceEgg",
        SellEggs = "SellEggs",
        WaitEquip = "WaitEquip",
        WaitAction = "WaitAction",
    }

    local state = {
        active = false,
        phase = PHASE.Idle,
        queue = {},
        queueIndex = 1,
        sellMode = false,
        sellUids = nil,
        sellIndex = 1,
        sellStep = nil,
        sellStepUid = nil,
        sellAttempts = 0,
        sellPass = 0,
        autoSellBackground = false,
        autoPlaceBackground = false,
        autoDumpWorstBackground = false,
        lastAutoSellAt = 0,
        lastAutoDumpWorstAt = 0,
        lastAutoPlaceAt = os.clock(),
        currentUid = nil,
        currentAction = nil,
        gridCursor = nil,
        detail = nil,
        waitUntil = 0,
        wearAttempts = 0,
        placeAttempts = 0,
        pendingFeed = false,
        plotFailStreak = 0,
        placeRoundSkipped = {},
        feedOnlyMode = false,
    }

    local function getRootPart()
        if Movement and Movement.GetRootPart then
            return Movement.GetRootPart()
        end

        local character = LocalPlayer.Character

        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function isNear(position, target, radius)
        if Movement and Movement.IsNear then
            return Movement.IsNear(position, target, radius)
        end

        return (Vector3.new(position.X, 0, position.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude <= radius
    end

    local function tweenTo(target)
        if Movement and Movement.TweenTo then
            Movement.TweenTo(target, runtime.tweenSpeed)
        end
    end

    local function cancelTween()
        if Movement and Movement.CancelTween then
            Movement.CancelTween()
        end
    end

    local function setPhase(phase, detail)
        if state.phase ~= phase or state.detail ~= detail then
            state.phase = phase
            state.detail = detail
            print(string.format("[EggESP Inv] %s%s", phase, detail and (" - " .. detail) or ""))
        end
    end

    local function now()
        return os.clock()
    end

    local function waiting()
        return now() < state.waitUntil
    end

    local function pause(seconds)
        state.waitUntil = now() + (seconds or 0.15)
        setPhase(PHASE.WaitAction, state.detail)
    end

    local function getAssetRarityId(category)
        local entry = Assets.Directory[category]

        if not entry or not entry.Rarity then
            return nil
        end

        return entry.Rarity._id or entry.Rarity.DisplayName
    end

    local function shouldAutoSellEgg(entry)
        if not entry or runtime.autoSellEnabled ~= true then
            return false
        end

        if not FarmFilters or not FarmFilters.IsSellRarityEnabled then
            return false
        end

        local rarityId = getAssetRarityId(entry.category)

        return FarmFilters.IsSellRarityEnabled(rarityId)
    end

    local function getAssetTier(category)
        local entry = Assets.Directory[category]

        if not entry or not entry.Rarity then
            return 0
        end

        return entry.Rarity.RarityNumber or 0
    end

    local function getDropWeight(category)
        local entry = Assets.Directory[category]

        if not entry then
            return math.huge
        end

        return entry.DropWeight or math.huge
    end

    local function countEggs()
        local save = Save.Get()
        local inventory = save and save.EggInventory

        if typeof(inventory) ~= "table" then
            return 0, 0
        end

        local total = 0
        local unplaced = 0

        for _, egg in pairs(inventory) do
            if typeof(egg) == "table" then
                total = total + 1

                if egg.Placement == nil then
                    unplaced = unplaced + 1
                end
            end
        end

        return total, unplaced
    end

    local function isInventoryFull()
        local total = countEggs()
        local maxInventory = Eggs.MAX_INVENTORY or 115

        return total >= maxInventory
    end

    local function collectUnplacedEggs(parasiteOnly)
        local save = Save.Get()
        local inventory = save and save.EggInventory
        local results = {}

        if typeof(inventory) ~= "table" then
            return results
        end

        for uid, egg in pairs(inventory) do
            if typeof(uid) == "string" and typeof(egg) == "table" and egg.Placement == nil then
                local hasParasite = egg.HasParasite == true

                if parasiteOnly == nil or hasParasite == parasiteOnly then
                    table.insert(results, {
                        uid = uid,
                        record = egg,
                        category = egg.AssetCategory,
                        tier = getAssetTier(egg.AssetCategory),
                        dropWeight = getDropWeight(egg.AssetCategory),
                        hasParasite = hasParasite,
                    })
                end
            end
        end

        table.sort(results, function(a, b)
            if a.tier ~= b.tier then
                return a.tier > b.tier
            end

            if a.dropWeight ~= b.dropWeight then
                return a.dropWeight < b.dropWeight
            end

            return a.uid < b.uid
        end)

        return results
    end

    local function isParasiteEventActive()
        local folder = Workspace:FindFirstChild(MonsterParasiteData.WorldFolderName)

        if not folder then
            return false
        end

        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                return true
            end
        end

        return false
    end

    local function findMonsterPosition()
        local folder = Workspace:FindFirstChild(MonsterParasiteData.WorldFolderName)

        if not folder then
            return nil
        end

        local rootPart = getRootPart()
        local origin = rootPart and rootPart.Position or runtime.standbyPosition
        local bestPos = nil
        local bestDist = math.huge

        for _, child in ipairs(folder:GetChildren()) do
            local part = nil

            if child:IsA("BasePart") then
                part = child
            elseif child:IsA("Model") then
                part = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)
            end

            if part then
                local dist = (part.Position - origin).Magnitude

                if dist < bestDist then
                    bestDist = dist
                    bestPos = part.Position
                end
            end
        end

        return bestPos
    end

    local function getPlotStandPosition()
        local plot = PlotState.ResolvePlot()

        if not plot then
            return runtime.standbyPosition
        end

        if plot.RespawnPointCFrame then
            return plot.RespawnPointCFrame.Position
        end

        if plot.CenterPoint then
            return plot.CenterPoint.Position
        end

        return runtime.standbyPosition
    end

    local function isEggUnplaced(uid)
        local save = Save.Get()
        local egg = save and save.EggInventory and save.EggInventory[uid]

        return typeof(egg) == "table" and egg.Placement == nil
    end

    local function getEquippedEggUid()
        local character = LocalPlayer.Character

        if not character then
            return nil
        end

        for _, child in ipairs(character:GetChildren()) do
            if child:IsA("Tool") and child:GetAttribute("ItemType") == "AssetEgg" then
                return child:GetAttribute("UID")
            end
        end

        return nil
    end

    local function initGridCursor(petArea)
        if state.gridCursor and state.gridCursor.initialized then
            return
        end

        local half = petArea.Size * 0.5
        local step = runtime.inventoryPlacementStep or 4
        local margin = step * 0.5

        state.gridCursor = {
            initialized = true,
            step = step,
            x = -half.X + margin,
            z = -half.Z + margin,
            xMax = half.X - margin,
            zMax = half.Z - margin,
        }
    end

    local function raycastPlacementCFrame(plot, localX, localZ)
        local petArea = plot.PetArea
        local half = petArea.Size * 0.5
        local rayHeight = math.max(half.Y + 80, 100)
        local localOrigin = Vector3.new(localX, rayHeight, localZ)
        local localTarget = Vector3.new(localX, -half.Y - 5, localZ)
        local worldOrigin = petArea.CFrame:PointToWorldSpace(localOrigin)
        local worldTarget = petArea.CFrame:PointToWorldSpace(localTarget)
        local direction = worldTarget - worldOrigin

        if direction.Magnitude < 0.01 then
            return nil
        end

        local filter = { petArea }
        PlacedEggRenderer.AppendRaycastTargets(filter, LocalPlayer.UserId)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = filter
        params.IgnoreWater = true

        local result = Workspace:Raycast(worldOrigin, direction, params)

        if not result or result.Instance ~= petArea then
            return nil
        end

        return plot.CenterPoint.CFrame:ToObjectSpace(CFrame.new(result.Position))
    end

    local function nextPlacementCFrame()
        local plot = PlotState.ResolvePlot()

        if not plot or not plot.PetArea or not plot.CenterPoint then
            return nil
        end

        initGridCursor(plot.PetArea)

        local petArea = plot.PetArea
        local cursor = state.gridCursor
        local step = cursor.step

        while cursor.z <= cursor.zMax do
            while cursor.x <= cursor.xMax do
                local localX = cursor.x
                local localZ = cursor.z
                cursor.x = cursor.x + step

                local localCFrame = raycastPlacementCFrame(plot, localX, localZ)

                if localCFrame then
                    return localCFrame
                end
            end

            cursor.x = -petArea.Size.X * 0.5 + step * 0.5
            cursor.z = cursor.z + step
        end

        return nil
    end

    local function isEggEquipped(uid)
        return getEquippedEggUid() == uid
    end

    local function resetGridCursor()
        state.gridCursor = nil
    end

    local function unequipEggTools()
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if humanoid then
            humanoid:UnequipTools()
        end

        EggState.DoffEggTool(nil)
    end

    local function prepareWear(uid)
        if isEggEquipped(uid) then
            return true
        end

        local equippedUid = getEquippedEggUid()

        if equippedUid and equippedUid ~= uid then
            unequipEggTools()
            pause(0.35)
            return false
        end

        if equippedUid == uid then
            pause(0.1)
            return false
        end

        local ok = EggState.WearEggTool(uid)
        state.wearAttempts = state.wearAttempts + 1

        if ok ~= true then
            pause(0.2)
            return false
        end

        pause(0.35)
        return isEggEquipped(uid)
    end

    local function buildQueue()
        local queue = {}

        if isParasiteEventActive() then
            for _, entry in ipairs(collectUnplacedEggs(true)) do
                table.insert(queue, { action = "feed", uid = entry.uid, tier = entry.tier })
            end
        end

        for _, entry in ipairs(collectUnplacedEggs(false)) do
            if not shouldAutoSellEgg(entry)
                and (not entry.hasParasite or not isParasiteEventActive()) then
                table.insert(queue, { action = "place", uid = entry.uid, tier = entry.tier })
            end
        end

        return queue
    end

    local function getAutoPlaceBatchSize()
        return math.clamp(math.floor(runtime.autoPlaceBatchSize or 5), 1, 20)
    end

    local function getAutoPlaceInterval()
        return math.clamp(math.floor(runtime.autoPlaceInterval or 60), 10, 600)
    end

    local function hasPlaceableEggs()
        for _, entry in ipairs(collectUnplacedEggs(false)) do
            if not shouldAutoSellEgg(entry)
                and (not entry.hasParasite or not isParasiteEventActive()) then
                return true
            end
        end

        return false
    end

    local function hasPlotSpace(force)
        local cache = state.plotSpaceCache
        local now = os.clock()

        if not force and cache and now - (cache.at or 0) < 2 then
            return cache.value == true
        end

        local plot = PlotState.ResolvePlot()

        if not plot or not plot.PetArea or not plot.CenterPoint then
            state.plotSpaceCache = { at = now, value = false }
            return false
        end

        local savedCursor = state.gridCursor
        state.gridCursor = nil
        initGridCursor(plot.PetArea)

        local cframe = nextPlacementCFrame()
        state.gridCursor = savedCursor

        local hasSpace = cframe ~= nil
        state.plotSpaceCache = { at = now, value = hasSpace }

        return hasSpace
    end

    local function buildPlaceBatchQueue(limit)
        local queue = {}
        local count = 0

        for _, entry in ipairs(collectUnplacedEggs(false)) do
            if not shouldAutoSellEgg(entry)
                and (not entry.hasParasite or not isParasiteEventActive()) then
                table.insert(queue, { action = "place", uid = entry.uid, tier = entry.tier })
                count = count + 1

                if count >= limit then
                    break
                end
            end
        end

        return queue
    end

    local function buildFeedQueue()
        local queue = {}

        for _, entry in ipairs(collectUnplacedEggs(true)) do
            table.insert(queue, { action = "feed", uid = entry.uid, tier = entry.tier })
        end

        table.sort(queue, function(a, b)
            return a.tier > b.tier
        end)

        return queue
    end

    local function hasParasiteEggsToFeed()
        if runtime.autoFeedParasiteEnabled == false then
            return false
        end

        if not isParasiteEventActive() then
            return false
        end

        return #collectUnplacedEggs(true) > 0
    end

    local function shouldFeedParasite()
        return hasParasiteEggsToFeed()
    end

    local function isActive()
        return state.active
    end

    local function collectUnplacedEggsForSell(filterByAutoSell)
        local results = collectUnplacedEggs(false)

        if filterByAutoSell == true then
            local filtered = {}

            for _, entry in ipairs(results) do
                if shouldAutoSellEgg(entry) then
                    table.insert(filtered, entry)
                end
            end

            results = filtered
        end

        table.sort(results, function(a, b)
            if a.tier ~= b.tier then
                return a.tier < b.tier
            end

            if a.dropWeight ~= b.dropWeight then
                return a.dropWeight > b.dropWeight
            end

            return a.uid > b.uid
        end)

        return results
    end

    local function collectAutoSellCandidates()
        return collectUnplacedEggsForSell(true)
    end

    local function buildWorstSellUids(limit)
        limit = limit or runtime.autoDumpWorstEggCount or 10
        local candidates = collectUnplacedEggsForSell(false)
        local uids = {}

        for index = 1, math.min(limit, #candidates) do
            table.insert(uids, candidates[index].uid)
        end

        return uids
    end

    local function shouldUseWorstEggDump()
        return runtime.autoDumpWorstEggsEnabled ~= false
            and isInventoryFull()
            and not hasPlotSpace(true)
    end

    local function shouldDumpWorstEggs()
        if runtime.autoDumpWorstEggsEnabled == false then
            return false
        end

        if not isInventoryFull() then
            return false
        end

        if hasPlotSpace(true) then
            return false
        end

        local _, unplaced = countEggs()

        return unplaced > 0
    end

    local function beginWorstEggDumpSell(reason)
        if state.sellMode or (state.active and not state.autoPlaceBackground) then
            return false
        end

        if not shouldDumpWorstEggs() then
            return false
        end

        local sellUids = buildWorstSellUids()

        if #sellUids == 0 then
            return false
        end

        state.sellMode = true
        state.autoSellBackground = true
        state.autoDumpWorstBackground = true
        state.sellUids = sellUids
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.sellPass = 0
        state.lastAutoDumpWorstAt = now()
        setPhase(PHASE.SellEggs, reason or string.format("dump worst x%d", #sellUids))

        print(string.format("[EggESP Inv] Dumping %d worst eggs (bag full, plot full)", #sellUids))

        return true
    end

    local function beginBackgroundSell(reason)
        local candidates = collectAutoSellCandidates()

        if #candidates == 0 then
            return false
        end

        state.sellMode = true
        state.autoSellBackground = true
        state.sellUids = { candidates[1].uid }
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.sellPass = 0
        setPhase(PHASE.SellEggs, reason or "auto sell")
        return true
    end

    local function finishBackgroundSell()
        state.sellMode = false
        state.autoSellBackground = false
        state.autoDumpWorstBackground = false
        state.sellUids = nil
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.lastAutoSellAt = now()
        setPhase(PHASE.Idle, "auto sell idle")
    end

    local function finishBackgroundPlace()
        local placed = state.autoPlacePlacedCount or 0
        local target = state.autoPlaceTargetCount or getAutoPlaceBatchSize()

        state.autoPlaceBackground = false
        state.autoPlaceTargetCount = nil
        state.autoPlacePlacedCount = nil
        state.autoPlaceTriedUids = nil
        state.lastAutoPlaceAt = now()
        stop()
        setPhase(PHASE.Idle, string.format("auto place %d/%d", placed, target))
    end

    local function tryRefillAutoPlaceQueue()
        if not state.autoPlaceBackground then
            return false
        end

        local target = state.autoPlaceTargetCount or getAutoPlaceBatchSize()
        local placed = state.autoPlacePlacedCount or 0

        if placed >= target then
            return false
        end

        local tried = state.autoPlaceTriedUids or {}

        for _, item in ipairs(state.queue) do
            tried[item.uid] = true
        end

        for _, entry in ipairs(collectUnplacedEggs(false)) do
            if not tried[entry.uid]
                and not shouldAutoSellEgg(entry)
                and (not entry.hasParasite or not isParasiteEventActive()) then
                table.insert(state.queue, {
                    action = "place",
                    uid = entry.uid,
                    tier = entry.tier,
                })
                tried[entry.uid] = true
                state.autoPlaceTriedUids = tried
                return true
            end
        end

        state.autoPlaceTriedUids = tried

        return false
    end

    local function finishAutoPlaceRoundIfDone()
        if not state.autoPlaceBackground then
            return false
        end

        local target = state.autoPlaceTargetCount or getAutoPlaceBatchSize()
        local placed = state.autoPlacePlacedCount or 0

        if placed >= target then
            print(string.format("[EggESP Inv] Auto place round done: placed %d/%d", placed, target))
            finishBackgroundPlace()
            return true
        end

        if state.queueIndex > #state.queue then
            if not tryRefillAutoPlaceQueue() then
                if placed > 0 then
                    print(string.format("[EggESP Inv] Auto place round done: placed %d/%d", placed, target))
                end

                finishBackgroundPlace()
                return true
            end

            state.queueIndex = #state.queue

            local nextItem = state.queue[state.queueIndex]

            if nextItem then
                state.currentAction = nextItem.action
                state.currentUid = nextItem.uid
                setPhase(PHASE.GoToPlot, string.format("tier %d", nextItem.tier))
            end
        end

        return false
    end

    local function beginBackgroundPlace(reason)
        if not hasPlaceableEggs() then
            state.lastAutoPlaceAt = now()
            return false
        end

        local batchSize = getAutoPlaceBatchSize()
        local queue = buildPlaceBatchQueue(batchSize)

        if #queue == 0 then
            state.lastAutoPlaceAt = now()
            return false
        end

        state.active = true
        state.autoPlaceBackground = true
        state.autoPlaceTargetCount = batchSize
        state.autoPlacePlacedCount = 0
        state.autoPlaceTriedUids = {}

        for _, item in ipairs(queue) do
            state.autoPlaceTriedUids[item.uid] = true
        end

        state.feedOnlyMode = false
        state.queue = queue
        state.queueIndex = 1
        state.sellMode = false
        state.sellUids = nil
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.sellPass = 0
        state.currentUid = nil
        state.currentAction = nil
        state.wearAttempts = 0
        state.placeAttempts = 0
        state.pendingFeed = false
        state.plotFailStreak = 0
        state.placeRoundSkipped = {}
        state.waitUntil = 0
        state.autoSellBackground = false
        resetGridCursor()

        setPhase(PHASE.GoToPlot, reason or string.format("auto place x%d", #queue))
        applyQueueStart()

        return true
    end

    local function shouldAutoPlaceDue()
        if runtime.autoPlaceEnabled == false then
            return false
        end

        if state.active or state.sellMode then
            return false
        end

        if not hasPlaceableEggs() then
            return false
        end

        local interval = getAutoPlaceInterval()

        return now() - (state.lastAutoPlaceAt or 0) >= interval
    end

    local function canAutoPlaceNow()
        if not shouldAutoPlaceDue() then
            return false
        end

        if runtime.autoPlaceAtStandbyOnly == false then
            return true
        end

        local rootPart = getRootPart()

        if not rootPart then
            return false
        end

        return isNear(rootPart.Position, runtime.standbyPosition, runtime.standbyArriveRadius or 6)
    end

    local function notifyFarmStarted()
        state.lastAutoPlaceAt = now()

        if state.active and state.autoPlaceBackground then
            finishBackgroundPlace()
        end
    end

    local function enterSellMode(reason)
        if state.sellMode then
            return
        end

        state.sellMode = true
        state.sellUids = {}
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.autoSellBackground = false
        state.autoDumpWorstBackground = false

        local useSellFilter = runtime.autoSellEnabled == true
        local sellUids

        if shouldUseWorstEggDump() then
            sellUids = buildWorstSellUids()
        else
            sellUids = {}

            for _, entry in ipairs(collectUnplacedEggsForSell(useSellFilter)) do
                table.insert(sellUids, entry.uid)
            end
        end

        for _, uid in ipairs(sellUids) do
            table.insert(state.sellUids, uid)
        end

        state.currentUid = nil
        state.currentAction = nil
        state.placeRoundSkipped = {}
        cancelTween()

        if #state.sellUids == 0 then
            print("[EggESP Inv] Nothing left to sell")
            state.sellMode = false
            if not state.active then
                setPhase(PHASE.Idle, "nothing to sell")
            else
                state.active = false
                setPhase(PHASE.Idle, "all eggs placed")
            end
            return
        end

        setPhase(PHASE.SellEggs, reason or "plot full")
    end

    local function getStatus()
        local total, unplaced = countEggs()

        return {
            active = state.active,
            phase = state.phase,
            detail = state.detail,
            sellMode = state.sellMode,
            autoSellBackground = state.autoSellBackground,
            autoPlaceBackground = state.autoPlaceBackground,
            autoPlaceEnabled = runtime.autoPlaceEnabled ~= false,
            autoPlaceBatchSize = getAutoPlaceBatchSize(),
            autoPlaceInterval = getAutoPlaceInterval(),
            autoPlacePlacedCount = state.autoPlacePlacedCount,
            autoPlaceTargetCount = state.autoPlaceTargetCount,
            autoSellEnabled = runtime.autoSellEnabled == true,
            feedOnlyMode = state.feedOnlyMode,
            parasiteEventActive = isParasiteEventActive(),
            parasiteEggsPending = #collectUnplacedEggs(true),
            queueRemaining = math.max(#state.queue - state.queueIndex + 1, 0),
            eggTotal = total,
            eggUnplaced = unplaced,
            inventoryFull = isInventoryFull(),
        }
    end

    local function applyQueueStart()
        if #state.queue == 0 then
            if state.feedOnlyMode then
                stop()
                return
            end

            local _, unplaced = countEggs()

            if unplaced > 0 and isInventoryFull() then
                enterSellMode("no queue")
            else
                state.active = false
                setPhase(PHASE.Idle, "nothing to do")
            end

            return
        end

        local first = state.queue[state.queueIndex]
        state.currentAction = first.action
        state.currentUid = first.uid

        if first.action == "feed" then
            setPhase(PHASE.GoToMonster, string.format("tier %d", first.tier))
        else
            setPhase(PHASE.GoToPlot, string.format("tier %d", first.tier))
        end
    end

    local function start()
        if state.active then
            return getStatus()
        end

        state.active = true
        state.feedOnlyMode = false
        state.queue = buildQueue()
        state.queueIndex = 1
        state.sellMode = false
        state.sellUids = nil
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.sellPass = 0
        state.currentUid = nil
        state.currentAction = nil
        state.wearAttempts = 0
        state.placeAttempts = 0
        state.pendingFeed = false
        state.plotFailStreak = 0
        state.placeRoundSkipped = {}
        state.waitUntil = 0
        resetGridCursor()

        applyQueueStart()

        return getStatus()
    end

    local function startFeedParasite()
        if state.active then
            return getStatus()
        end

        local queue = buildFeedQueue()

        if #queue == 0 then
            setPhase(PHASE.Idle, "no infested eggs")
            return getStatus()
        end

        state.active = true
        state.feedOnlyMode = true
        state.queue = queue
        state.queueIndex = 1
        state.sellMode = false
        state.sellUids = nil
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.sellPass = 0
        state.currentUid = nil
        state.currentAction = nil
        state.wearAttempts = 0
        state.placeAttempts = 0
        state.pendingFeed = false
        state.plotFailStreak = 0
        state.placeRoundSkipped = {}
        state.waitUntil = 0
        state.autoSellBackground = false

        applyQueueStart()

        return getStatus()
    end

    local function stop()
        state.active = false
        state.queue = {}
        state.queueIndex = 1
        state.sellUids = nil
        state.sellIndex = 1
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
        state.sellPass = 0
        state.currentUid = nil
        state.currentAction = nil
        state.sellMode = false
        state.feedOnlyMode = false
        state.autoPlaceBackground = false
        state.pendingFeed = false
        state.placeRoundSkipped = {}
        setPhase(PHASE.Idle, "stopped")
        cancelTween()

        return getStatus()
    end

    local function finish()
        if state.autoPlaceBackground then
            finishBackgroundPlace()
            return
        end

        local total, unplaced = countEggs()
        print(string.format("[EggESP Inv] Done - total=%d unplaced=%d", total, unplaced))

        if state.feedOnlyMode then
            stop()
            return
        end

        if unplaced > 0 and isInventoryFull() then
            state.sellMode = false
            enterSellMode("finish fallback")
            return
        end

        stop()
    end

    local function advanceQueue()
        state.queueIndex = state.queueIndex + 1
        state.wearAttempts = 0
        state.placeAttempts = 0
        state.pendingFeed = false

        if state.queueIndex <= #state.queue then
            local nextItem = state.queue[state.queueIndex]

            while nextItem and not isEggUnplaced(nextItem.uid) do
                state.queueIndex = state.queueIndex + 1
                nextItem = state.queue[state.queueIndex]
            end
        end

        if state.queueIndex <= #state.queue then
            local nextItem = state.queue[state.queueIndex]
            state.currentAction = nextItem.action
            state.currentUid = nextItem.uid

            if nextItem.action == "feed" then
                setPhase(PHASE.GoToMonster, string.format("tier %d", nextItem.tier))
            else
                setPhase(PHASE.GoToPlot, string.format("tier %d", nextItem.tier))
            end

            return
        end

        if state.autoPlaceBackground then
            if finishAutoPlaceRoundIfDone() then
                return
            end

            if state.queueIndex <= #state.queue then
                local nextItem = state.queue[state.queueIndex]
                state.currentAction = nextItem.action
                state.currentUid = nextItem.uid
                setPhase(PHASE.GoToPlot, string.format("tier %d", nextItem.tier))
            end

            return
        end

        -- Queue exhausted — rebuild from live save (fed/placed eggs drop out)
        local fresh = state.feedOnlyMode and buildFeedQueue() or buildQueue()

        if #fresh > 0 then
            state.queue = fresh
            state.queueIndex = 1
            applyQueueStart()
            return
        end

        if state.feedOnlyMode then
            finish()
            return
        end

        local _, unplaced = countEggs()

        if unplaced > 0 and isInventoryFull() then
            enterSellMode("still full after place")
        else
            finish()
        end
    end

    local function allUnplacedSkipped()
        local unplaced = collectUnplacedEggs(false)

        if #unplaced == 0 then
            return false
        end

        for _, entry in ipairs(unplaced) do
            if not state.placeRoundSkipped[entry.uid] then
                return false
            end
        end

        return true
    end

    local function skipEggPlacement(reason)
        local uid = state.currentUid
        print(string.format("[EggESP Inv] Skip place: %s%s", reason or "unknown", uid and (" (" .. uid:sub(1, 8) .. ")") or ""))

        if uid then
            state.placeRoundSkipped[uid] = true

            if state.autoPlaceTriedUids then
                state.autoPlaceTriedUids[uid] = true
            end
        end

        state.placeAttempts = 0
        state.wearAttempts = 0
        unequipEggTools()

        if state.autoPlaceBackground then
            tryRefillAutoPlaceQueue()
            advanceQueue()
            return
        end

        state.plotFailStreak = state.plotFailStreak + 1

        if allUnplacedSkipped() then
            enterSellMode("cannot place remaining eggs")
            return
        end

        if state.plotFailStreak >= (runtime.inventoryPlotFailStreak or 2) then
            enterSellMode("plot full")
            return
        end

        advanceQueue()
    end

    local function shouldManage()
        if not isInventoryFull() then
            return false
        end

        local _, unplaced = countEggs()

        if unplaced == 0 then
            return false
        end

        if not hasPlotSpace(true) then
            return false
        end

        return true
    end

    local function resetSellStep()
        state.sellStep = nil
        state.sellStepUid = nil
        state.sellAttempts = 0
    end

    local function tickSell()
        if not state.sellUids or state.sellIndex > #state.sellUids then
            if state.autoSellBackground then
                if state.autoDumpWorstBackground then
                    print(string.format("[EggESP Inv] Worst egg dump done (%d sold)", #(state.sellUids or {})))
                end

                finishBackgroundSell()
                return false
            end

            local _, unplaced = countEggs()
            print(string.format("[EggESP Inv] Sell pass done (%d left unplaced)", unplaced))

            if unplaced > 0 and isInventoryFull() then
                state.sellPass = state.sellPass + 1

                if state.sellPass >= 3 then
                    print("[EggESP Inv] Sell gave up after 3 passes")
                    state.sellMode = false
                    stop()
                    return false
                end

                state.sellUids = {}
                state.sellIndex = 1
                resetSellStep()

                if shouldUseWorstEggDump() then
                    state.sellUids = buildWorstSellUids()
                else
                    local useSellFilter = runtime.autoSellEnabled == true

                    for _, entry in ipairs(collectUnplacedEggsForSell(useSellFilter)) do
                        table.insert(state.sellUids, entry.uid)
                    end
                end

                if #state.sellUids > 0 then
                    setPhase(PHASE.SellEggs, string.format("retry pass %d", state.sellPass + 1))
                    return true
                end
            end

            finish()
            return false
        end

        if waiting() then
            return true
        end

        local uid = state.sellUids[state.sellIndex]

        if not isEggUnplaced(uid) then
            resetSellStep()
            state.sellIndex = state.sellIndex + 1
            return true
        end

        if state.sellStepUid ~= uid then
            resetSellStep()
            state.sellStepUid = uid
            state.sellStep = "equip"
        end

        if state.sellStep == "equip" then
            setPhase(PHASE.SellEggs, string.format("equip %s", uid:sub(1, 8)))

            if isEggEquipped(uid) then
                state.sellStep = "sell"
                return true
            end

            unequipEggTools()
            local ok = EggState.WearEggTool(uid)
            state.sellAttempts = state.sellAttempts + 1

            if ok ~= true then
                if state.sellAttempts >= 10 then
                    print(string.format("[EggESP Inv] Cannot equip to sell: %s", uid:sub(1, 8)))
                    resetSellStep()
                    state.sellIndex = state.sellIndex + 1
                else
                    pause(0.25)
                end

                return true
            end

            pause(0.3)
            return true
        end

        if state.sellStep == "sell" then
            if not isEggEquipped(uid) then
                state.sellStep = "equip"
                return true
            end

            setPhase(PHASE.SellEggs, string.format("sell %s", uid:sub(1, 8)))
            Remotes.PetSatchel.SellPet:FireServer({ uid })
            state.sellStep = "wait"
            state.sellAttempts = 0
            pause(0.35)
            return true
        end

        if state.sellStep == "wait" then
            if not isEggUnplaced(uid) then
                print(string.format("[EggESP Inv] Sold egg %s", uid:sub(1, 8)))
                unequipEggTools()
                resetSellStep()
                state.sellIndex = state.sellIndex + 1
                return true
            end

            state.sellAttempts = state.sellAttempts + 1

            if state.sellAttempts >= 6 then
                print(string.format("[EggESP Inv] Sell failed for %s, skipping", uid:sub(1, 8)))
                unequipEggTools()
                resetSellStep()
                state.sellIndex = state.sellIndex + 1
                return true
            end

            if isEggEquipped(uid) then
                Remotes.PetSatchel.SellPet:FireServer({ uid })
            else
                state.sellStep = "equip"
            end

            pause(0.3)
            return true
        end

        state.sellStep = "equip"
        return true
    end

    local function tickFeed(item)
        local monsterPos = findMonsterPosition()

        if not monsterPos then
            advanceQueue()
            return true
        end

        local rootPart = getRootPart()

        if not rootPart then
            return true
        end

        local arriveRadius = runtime.inventoryFeedRadius or 12

        if not isNear(rootPart.Position, monsterPos, arriveRadius) then
            setPhase(PHASE.GoToMonster, string.format("tier %d", item.tier))
            tweenTo(monsterPos)
            return true
        end

        setPhase(PHASE.FeedParasite, string.format("tier %d", item.tier))

        if not isEggEquipped(item.uid) then
            if state.wearAttempts >= 12 then
                advanceQueue()
                return true
            end

            setPhase(PHASE.WaitEquip, string.format("tier %d", item.tier))

            if not prepareWear(item.uid) then
                return true
            end
        end

        if state.pendingFeed then
            return true
        end

        state.pendingFeed = true

        local success, result = pcall(function()
            return Remotes.MonsterParasite.AskFeed:InvokeServer()
        end)

        unequipEggTools()
        state.pendingFeed = false

        if success and typeof(result) == "table" and result.Success == true then
            print("[EggESP Inv] Fed parasite egg to monster")
            pause(1.5)
        else
            print("[EggESP Inv] Feed failed, skipping egg")
            pause(0.3)
        end

        advanceQueue()
        return true
    end

    local function tickPlace(item)
        if not isEggUnplaced(item.uid) then
            advanceQueue()
            return true
        end

        local plotPos = getPlotStandPosition()
        local rootPart = getRootPart()

        if not rootPart then
            return true
        end

        local arriveRadius = runtime.standbyArriveRadius or 6

        if not isNear(rootPart.Position, plotPos, arriveRadius) then
            setPhase(PHASE.GoToPlot, string.format("tier %d", item.tier))
            tweenTo(plotPos)
            return true
        end

        setPhase(PHASE.PlaceEgg, string.format("tier %d", item.tier))

        if not isEggEquipped(item.uid) then
            if state.wearAttempts >= 12 then
                skipEggPlacement("cannot equip")
                return true
            end

            setPhase(PHASE.WaitEquip, string.format("tier %d", item.tier))

            if not prepareWear(item.uid) then
                return true
            end
        end

        if not isEggUnplaced(item.uid) then
            advanceQueue()
            return true
        end

        setPhase(PHASE.PlaceEgg, string.format("tier %d", item.tier))

        local attemptsThisTick = runtime.inventoryPlaceAttemptsPerTick or 6
        local tried = 0
        local gridExhausted = false

        while tried < attemptsThisTick do
            tried = tried + 1
            state.placeAttempts = state.placeAttempts + 1

            local localCFrame = nextPlacementCFrame()

            if not localCFrame then
                gridExhausted = true
                break
            end

            local ok, err = EggState.PlantEgg(item.uid, localCFrame)

            if ok == true then
                state.plotFailStreak = 0
                state.placeRoundSkipped[item.uid] = nil
                unequipEggTools()
                print(string.format("[EggESP Inv] Placed egg tier %d (%s)", item.tier, item.uid))
                state.plotSpaceCache = nil

                if state.autoPlaceBackground then
                    state.autoPlacePlacedCount = (state.autoPlacePlacedCount or 0) + 1
                end

                pause(0.4)
                advanceQueue()
                return true
            end

            if err then
                state.detail = tostring(err)
            end
        end

        if gridExhausted and state.autoPlaceBackground then
            skipEggPlacement("plot full")
            return true
        end

        if gridExhausted then
            enterSellMode("plot full")
            return true
        end

        local maxAttempts = runtime.inventoryMaxPlaceAttemptsPerEgg or 12

        if state.placeAttempts >= maxAttempts then
            skipEggPlacement("placement failed")
            return true
        end

        pause(0.1)
        return true
    end

    local function tick()
        if not state.active then
            return false
        end

        if waiting() then
            return true
        end

        if state.sellMode then
            return tickSell()
        end

        if state.queueIndex > #state.queue then
            if state.autoPlaceBackground then
                if finishAutoPlaceRoundIfDone() then
                    return state.active
                end

                return state.active
            end

            local fresh = buildQueue()

            if #fresh > 0 then
                state.queue = fresh
                state.queueIndex = 1
                applyQueueStart()
                return state.active
            end

            local _, unplaced = countEggs()

            if unplaced > 0 and isInventoryFull() then
                enterSellMode("still full")
            else
                finish()
            end

            return state.active
        end

        local item = state.queue[state.queueIndex]

        while item and item.action == "place" and not isEggUnplaced(item.uid) do
            state.queueIndex = state.queueIndex + 1
            item = state.queue[state.queueIndex]
        end

        if not item or state.queueIndex > #state.queue then
            if state.autoPlaceBackground then
                if finishAutoPlaceRoundIfDone() then
                    return state.active
                end

                return state.active
            end

            local fresh = buildQueue()

            if #fresh > 0 then
                state.queue = fresh
                state.queueIndex = 1
                applyQueueStart()
                return state.active
            end

            local _, unplaced = countEggs()

            if unplaced > 0 and isInventoryFull() then
                enterSellMode("still full")
            else
                finish()
            end

            return state.active
        end

        state.currentUid = item.uid
        state.currentAction = item.action

        if item.action == "feed" then
            tickFeed(item)
        else
            tickPlace(item)
        end

        return state.active
    end

    local function tickAutoSell()
        if runtime.autoSellEnabled ~= true then
            return false
        end

        if state.active then
            return false
        end

        if state.sellMode then
            if state.autoSellBackground then
                return tickSell()
            end

            return false
        end

        if waiting() then
            return false
        end

        local interval = runtime.autoSellInterval or 1.5

        if now() - (state.lastAutoSellAt or 0) < interval then
            return false
        end

        return beginBackgroundSell("auto sell")
    end

    local function tickAutoDumpWorstEggs()
        if runtime.autoDumpWorstEggsEnabled == false then
            return false
        end

        if state.sellMode then
            if state.autoDumpWorstBackground then
                return tickSell()
            end

            return false
        end

        if state.active and not state.autoPlaceBackground then
            return false
        end

        if not shouldDumpWorstEggs() then
            return false
        end

        local cooldown = runtime.autoDumpWorstEggCooldown or 15

        if now() - (state.lastAutoDumpWorstAt or 0) < cooldown then
            return false
        end

        return beginWorstEggDumpSell(string.format("dump worst x%d", runtime.autoDumpWorstEggCount or 10))
    end

    local function tickAutoPlace()
        if runtime.autoPlaceEnabled == false then
            return false
        end

        if AutoFarm and AutoFarm.GetStatus then
            local farmStatus = AutoFarm.GetStatus()

            if farmStatus.enabled then
                return false
            end
        end

        if state.active then
            if state.autoPlaceBackground then
                return tick()
            end

            return false
        end

        if state.sellMode then
            return false
        end

        if waiting() then
            return false
        end

        local interval = getAutoPlaceInterval()

        if now() - (state.lastAutoPlaceAt or 0) < interval then
            return false
        end

        if not canAutoPlaceNow() then
            return false
        end

        return beginBackgroundPlace(string.format("auto place x%d", getAutoPlaceBatchSize()))
    end

    local function setAutoFarm(autoFarm)
        AutoFarm = autoFarm
    end

    return {
        Start = start,
        StartFeedParasite = startFeedParasite,
        Stop = stop,
        Tick = tick,
        TickAutoSell = tickAutoSell,
        TickAutoDumpWorstEggs = tickAutoDumpWorstEggs,
        TickAutoPlace = tickAutoPlace,
        ShouldDumpWorstEggs = shouldDumpWorstEggs,
        BeginWorstEggDumpSell = beginWorstEggDumpSell,
        ShouldAutoPlaceDue = shouldAutoPlaceDue,
        StartBackgroundPlace = beginBackgroundPlace,
        NotifyFarmStarted = notifyFarmStarted,
        SetAutoFarm = setAutoFarm,
        GetStatus = getStatus,
        ShouldManage = shouldManage,
        ShouldFeedParasite = shouldFeedParasite,
        IsActive = isActive,
        IsInventoryFull = isInventoryFull,
        Phases = PHASE,
    }
end

return InventoryManager
