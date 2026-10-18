--[[
    Auto farm: standby -> rarest egg -> pickup -> return standby -> repeat.
]]

local AutoFarm = {}

local CARRY_RADIUS = 8
local PICKUP_MOVE_RADIUS = 12

local PHASE = {
    Standby = "Standby",
    GoToEgg = "GoToEgg",
    Pickup = "Pickup",
    ReturnStandby = "ReturnStandby",
    WaitDeposit = "WaitDeposit",
    ManageInventory = "ManageInventory",
    FeedParasite = "FeedParasite",
    WaitForDay = "WaitForDay",
    Idle = "Idle",
}

function AutoFarm.create(deps)
    local Config = deps.Config
    local EggData = deps.EggData
    local PathService = deps.PathService
    local Movement = deps.Movement
    local EggState = deps.EggState
    local AreaEggSlotIdentity = deps.AreaEggSlotIdentity
    local Passthrough = deps.Passthrough
    local SpeedBypass = deps.SpeedBypass
    local InventoryManager = deps.InventoryManager
    local DayCycle = deps.DayCycle
    local PetAutomation = deps.PetAutomation
    local LocalPlayer = deps.LocalPlayer

    local runtime = Config.Runtime

    local state = {
        enabled = false,
        phase = PHASE.Idle,
        targetEgg = nil,
        waypoints = nil,
        waypointIndex = 1,
        pathGoal = nil,
        carryUid = nil,
        isCarrying = false,
        lastPathCalc = 0,
        stuckTimer = 0,
        lastPosition = nil,
        connection = nil,
        characterConnection = nil,
        detail = nil,
        lastTargetRefresh = 0,
        pickupFailCount = 0,
        pickupSettleTicks = 0,
        requireStandbyOnStart = false,
        phaseEnteredAt = 0,
        lastProgressAt = 0,
        lastProgressPos = nil,
        standbyStartAt = 0,
        depositWaitSince = nil,
        carryConfirmedAt = nil,
        farmStartedAt = 0,
        wasDayBlocked = false,
        rushFarmAfterDay = false,
    }

    local function compareEggPriority(a, b)
        if not a then
            return false
        end

        if not b then
            return true
        end

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

    local function formatTargetDetail(egg)
        local zoneLabel = egg.areaName or egg.info.areaName or "?"
        return string.format("[%s] %s (%s)", zoneLabel, egg.info.name, egg.info.rarityName)
    end

    local function isAtStandbyStart(rootPos, standbyPos)
        local radius = runtime.standbyStartRadius or runtime.standbyArriveRadius or 6
        return Movement.IsNear(rootPos, standbyPos, radius)
    end

    local function isAtStandby(rootPos, standbyPos)
        return Movement.IsNear(rootPos, standbyPos, runtime.standbyArriveRadius)
    end

    local function clearTargetPath()
        state.waypoints = nil
        state.pathGoal = nil
        state.waypointIndex = 1
    end

    local function setTargetEgg(egg, updatePhaseDetail)
        local changed = not state.targetEgg or not egg or state.targetEgg.uid ~= egg.uid

        state.targetEgg = egg

        if changed then
            state.pickupFailCount = 0
            clearTargetPath()
        end

        if egg and updatePhaseDetail then
            state.detail = formatTargetDetail(egg)
        end
    end

    local function setPhase(phase, detail)
        local phaseChanged = state.phase ~= phase
        local oldPhase = state.phase

        if phaseChanged or state.detail ~= detail then
            state.phase = phase
            state.detail = detail

            if phaseChanged then
                state.phaseEnteredAt = os.clock()

                local movementPhases = {
                    [PHASE.GoToEgg] = true,
                    [PHASE.Pickup] = true,
                    [PHASE.ReturnStandby] = true,
                }
                local sameMovement = movementPhases[oldPhase] and movementPhases[phase]

                if not sameMovement then
                    state.waypointIndex = 1
                    state.stuckTimer = 0
                    state.lastPosition = nil
                    Movement.CancelMovement()
                else
                    state.stuckTimer = 0
                end

                if phase == PHASE.WaitDeposit then
                    state.depositWaitSince = os.clock()
                elseif phase ~= PHASE.ReturnStandby or not state.isCarrying then
                    state.depositWaitSince = nil
                end
            end

            print(string.format("[EggESP Auto] %s%s", phase, detail and (" - " .. detail) or ""))
        end
    end

    local function setServerActionMode(enabled)
        if SpeedBypass and SpeedBypass.SetServerActionMode then
            SpeedBypass.SetServerActionMode(enabled)
        elseif Movement.SetServerActionMode then
            Movement.SetServerActionMode(enabled)
        end
    end

    local function noteProgress(rootPos)
        local now = os.clock()
        local minDist = runtime.autoFarmProgressMinDist or 3

        if state.lastProgressPos then
            if Movement.HorizontalDistance(rootPos, state.lastProgressPos) >= minDist then
                state.lastProgressAt = now
                state.lastProgressPos = rootPos
            end
        else
            state.lastProgressAt = now
            state.lastProgressPos = rootPos
        end
    end

    local function recoverFromStuck(reason)
        print(string.format("[EggESP Auto] Recovery: %s", reason))
        Movement.CancelMovement()
        if Movement.EnsureLocomotion then
            Movement.EnsureLocomotion()
        end
        setServerActionMode(false)
        clearTargetPath()
        state.pickupSettleTicks = 0
        state.pickupFailCount = 0
        state.lastProgressAt = os.clock()
        state.lastProgressPos = Movement.GetRootPart() and Movement.GetRootPart().Position or nil

        if state.isCarrying then
            local rootPart = Movement.GetRootPart()
            local standbyPos = runtime.standbyPosition

            if rootPart and isAtStandby(rootPart.Position, standbyPos) then
                state.depositWaitSince = os.clock()
                setPhase(PHASE.WaitDeposit, "recovery deposit")
            else
                setPhase(PHASE.ReturnStandby, reason)
            end

            return
        end

        if state.phase == PHASE.Pickup or state.phase == PHASE.GoToEgg then
            state.targetEgg = nil
        end

        setPhase(PHASE.Standby, reason)
    end

    local function checkWatchdog(rootPart)
        if not rootPart then
            return
        end

        local now = os.clock()
        local phaseAge = now - (state.phaseEnteredAt or now)
        local progressAge = now - (state.lastProgressAt or now)

        if state.requireStandbyOnStart then
            local standbyTimeout = runtime.autoFarmStandbyStartTimeout or 30

            if now - (state.standbyStartAt or now) >= standbyTimeout then
                state.requireStandbyOnStart = false
                clearTargetPath()
                print("[EggESP Auto] Recovery: standby start timeout")
            end
        end

        if state.isCarrying and state.depositWaitSince then
            local depositTimeout = runtime.autoFarmDepositTimeout or 45

            if now - state.depositWaitSince >= depositTimeout then
                state.isCarrying = false
                state.carryUid = nil
                state.depositWaitSince = nil
                recoverFromStuck("deposit timeout")
                return
            end
        end

        if state.phase == PHASE.Pickup then
            local pickupTimeout = runtime.autoFarmPickupTimeout or 60

            if phaseAge >= pickupTimeout then
                state.targetEgg = nil
                recoverFromStuck("pickup timeout")
                return
            end
        end

        if state.phase == PHASE.ManageInventory or state.phase == PHASE.FeedParasite then
            local phaseTimeout = runtime.autoFarmPhaseTimeout or 90

            if phaseAge >= phaseTimeout then
                if InventoryManager then
                    InventoryManager.Stop()
                end

                recoverFromStuck("inventory timeout")
                return
            end
        end

        local idlePhases = {
            [PHASE.GoToEgg] = true,
            [PHASE.Pickup] = true,
            [PHASE.ReturnStandby] = true,
            [PHASE.WaitDeposit] = true,
        }

        local stuckTimeout = runtime.autoFarmStuckTimeout or 22

        if idlePhases[state.phase] then
            if progressAge >= stuckTimeout then
                recoverFromStuck("stuck timeout")
            end
        end

        if state.phase == PHASE.Standby then
            local stallTimeout = runtime.autoFarmStandbyStallTimeout or 10
            local detail = state.detail or ""
            local waiting = detail == "no eggs"
                or detail == "waiting for spawn"
                or detail:find("waiting", 1, true) ~= nil

            if waiting and progressAge >= stallTimeout then
                state.lastProgressAt = os.clock()
                state.lastTargetRefresh = 0
                clearTargetPath()

                if EggData.InvalidateCache then
                    EggData.InvalidateCache()
                end

                PathService.Invalidate()

                if Movement.EnsureLocomotion then
                    Movement.EnsureLocomotion()
                end

                print("[EggESP Auto] Recovery: standby stall refresh")
            end
        end
    end

    local function getStatus()
        local inventoryStatus = InventoryManager and InventoryManager.GetStatus() or nil
        local dayStatus = DayCycle and DayCycle.GetStatus() or nil

        return {
            enabled = state.enabled,
            phase = state.phase,
            detail = state.detail,
            targetEgg = state.targetEgg,
            isCarrying = state.isCarrying,
            carryUid = state.carryUid,
            standby = runtime.standbyPosition,
            inventory = inventoryStatus,
            dayCycle = dayStatus,
            petAutomation = PetAutomation and PetAutomation.GetStatus() or nil,
            pickupFailCount = state.pickupFailCount or 0,
        }
    end

    local function shouldWaitForDay()
        if not runtime.waitForDayBeforeFarm or not DayCycle then
            return false
        end

        return DayCycle.IsEggAreaBlocked()
    end

    local function waitForDayDetail()
        if not DayCycle then
            return "waiting for day"
        end

        local seconds = DayCycle.SecondsUntilDay()

        if seconds > 0 then
            return string.format("%ds until day", seconds)
        end

        local _, reason = DayCycle.IsEggAreaBlocked()

        return reason or "waiting for day"
    end

    local function handleNightWait(rootPart, standbyPos, atStandby)
        if state.phase == PHASE.GoToEgg or state.phase == PHASE.Pickup then
            state.targetEgg = nil
            setPhase(PHASE.ReturnStandby, "night reset")
            return true
        end

        setPhase(PHASE.WaitForDay, waitForDayDetail())

        if not atStandby then
            followPath(standbyPos, runtime.standbyArriveRadius)
        else
            Movement.CancelMovement()
        end

        return true
    end

    local function triggerRushFarmAfterDay()
        state.rushFarmAfterDay = true
        state.lastTargetRefresh = 0
        state.lastPathCalc = 0
        state.targetEgg = nil
        clearTargetPath()

        if EggData.InvalidateCache then
            EggData.InvalidateCache()
        end

        PathService.Invalidate()
        Movement.CancelMovement()
    end

    local function resolveSlotKey(record)
        if record and AreaEggSlotIdentity.LooksLikeFirstAreaUid(record.Uid) then
            return AreaEggSlotIdentity.SlotKey(record.AreaId, record.NestId)
        end

        return nil
    end

    local function findRarestEgg(force)
        if EggData.InvalidateCache and force then
            EggData.InvalidateCache()
        end

        if EggData.FindBestForFarm then
            return EggData.FindBestForFarm(nil, force)
        end

        local eggs = EggData.CollectAll(force)
        return eggs[1]
    end

    local function refreshTargetEgg(force)
        local now = os.clock()
        local interval = state.rushFarmAfterDay and 0
            or (runtime.autoFarmTargetRefreshInterval or 0.75)

        if not force and interval > 0 and now - state.lastTargetRefresh < interval then
            return state.targetEgg
        end

        state.lastTargetRefresh = now

        local bestEgg = findRarestEgg(false)
        local current = state.targetEgg

        if not current then
            setTargetEgg(bestEgg, false)
            return bestEgg
        end

        local refreshed = EggData.FindByUid and EggData.FindByUid(current.uid, false) or nil

        if not refreshed then
            setTargetEgg(bestEgg, state.phase == PHASE.GoToEgg or state.phase == PHASE.Pickup)
            return state.targetEgg
        end

        if bestEgg and bestEgg.uid ~= refreshed.uid then
            if (bestEgg.rarityTier or 0) > (refreshed.rarityTier or 0) then
                setTargetEgg(bestEgg, true)
                return state.targetEgg
            end

            if (bestEgg.rarityTier or 0) == (refreshed.rarityTier or 0)
                and compareEggPriority(bestEgg, refreshed) then
                setTargetEgg(bestEgg, true)
                return state.targetEgg
            end
        end

        if refreshed.worldPos ~= current.worldPos then
            refreshed = EggData.FindByUid(current.uid, true) or refreshed
        end

        state.targetEgg = refreshed
        return refreshed
    end

    local function syncWaypointIndex(rootPos, waypoints)
        if not waypoints or #waypoints == 0 then
            state.waypointIndex = 1
            return
        end

        local bestIndex = state.waypointIndex
        local bestDistance = math.huge

        for index = state.waypointIndex, #waypoints do
            local distance = Movement.HorizontalDistance(rootPos, waypoints[index])

            if distance < bestDistance then
                bestDistance = distance
                bestIndex = index
            end
        end

        while bestIndex < #waypoints
            and Movement.IsNear(rootPos, waypoints[bestIndex], runtime.pathWaypointRadius) do
            bestIndex = bestIndex + 1
        end

        state.waypointIndex = math.clamp(bestIndex, 1, #waypoints)
    end

    local function refreshPath(goalPos, force)
        local rootPart = Movement.GetRootPart()

        if not rootPart or not goalPos then
            state.waypoints = nil
            state.pathGoal = nil
            return false
        end

        local now = os.clock()
        local sameGoal = state.pathGoal and Movement.HorizontalDistance(state.pathGoal, goalPos) < 2

        if not force and sameGoal and state.waypoints and now - state.lastPathCalc < runtime.pathRecalcInterval then
            syncWaypointIndex(rootPart.Position, state.waypoints)
            return true
        end

        PathService.Invalidate()

        local waypoints, found = PathService.ComputePathBetween(rootPart.Position, goalPos)

        if not waypoints or #waypoints == 0 then
            state.waypoints = nil
            state.pathGoal = goalPos
            state.lastPathCalc = now
            return false
        end

        state.waypoints = waypoints
        state.pathGoal = goalPos
        state.lastPathCalc = now
        syncWaypointIndex(rootPart.Position, waypoints)

        return waypoints ~= nil
    end

    local function followPath(goalPos, arriveRadius)
        setServerActionMode(false)

        if Movement.EnsureLocomotion then
            Movement.EnsureLocomotion()
        end

        local rootPart = Movement.GetRootPart()

        if not rootPart then
            return false
        end

        arriveRadius = arriveRadius or runtime.standbyArriveRadius

        if Movement.IsNear(rootPart.Position, goalPos, arriveRadius) then
            Movement.CancelMovement()
            return true
        end

        refreshPath(goalPos, false)

        local waypoints = state.waypoints
        local moveTarget = goalPos

        if waypoints and #waypoints > 0 then
            syncWaypointIndex(rootPart.Position, waypoints)

            if Movement.IsNear(rootPart.Position, waypoints[state.waypointIndex], runtime.pathWaypointRadius)
                and state.waypointIndex < #waypoints then
                state.waypointIndex = state.waypointIndex + 1
            end

            moveTarget = waypoints[state.waypointIndex] or waypoints[#waypoints]
        elseif PathService.IsLineClearBetween and PathService.IsLineClearBetween(rootPart.Position, goalPos) then
            moveTarget = goalPos
        else
            refreshPath(goalPos, true)
            waypoints = state.waypoints

            if waypoints and #waypoints > 0 then
                syncWaypointIndex(rootPart.Position, waypoints)
                moveTarget = waypoints[state.waypointIndex] or waypoints[#waypoints]
            else
                moveTarget = goalPos
            end
        end

        if not waypoints or #waypoints == 0 then
            if not Movement.IsActivelyMovingTo or not Movement.IsActivelyMovingTo(moveTarget) then
                Movement.MoveToward(moveTarget)
            end
        elseif not Movement.IsActivelyMovingTo or not Movement.IsActivelyMovingTo(moveTarget) then
            Movement.MoveToward(moveTarget, function(completed)
                if not completed or not state.enabled then
                    return
                end

                local currentRoot = Movement.GetRootPart()

                if not currentRoot then
                    return
                end

                if Movement.IsNear(currentRoot.Position, goalPos, arriveRadius) then
                    return
                end

                if waypoints and state.waypointIndex < #waypoints then
                    state.waypointIndex = state.waypointIndex + 1
                end
            end)
        end

        if state.lastPosition and Movement.HorizontalDistance(rootPart.Position, state.lastPosition) < 0.2
            and (Movement.IsTweening() or Movement.IsWalking()) then
            state.stuckTimer = state.stuckTimer + 1

            local stuckThreshold = runtime.autoFarmPathStuckTicks or 25

            if state.stuckTimer >= stuckThreshold then
                Movement.CancelMovement()
                if Movement.EnsureLocomotion then
                    Movement.EnsureLocomotion()
                end
                state.waypointIndex = math.min((state.waypointIndex or 1) + 1, #(waypoints or { 1 }))
                refreshPath(goalPos, true)
                state.stuckTimer = 0
                Movement.MoveToward(moveTarget)
            end
        else
            state.stuckTimer = 0
        end

        state.lastPosition = rootPart.Position

        return Movement.IsNear(rootPart.Position, goalPos, arriveRadius)
    end

    local function shouldWalkPickupSync()
        return runtime.autoFarmWalkPickupSync ~= false
    end

    local function carryRadius()
        return runtime.pickupCarryRadius or CARRY_RADIUS
    end

    local function pickupMoveRadius()
        return runtime.pickupMoveRadius
            or runtime.pathWaypointRadius
            or PICKUP_MOVE_RADIUS
    end

    local function eggDistance(rootPos, eggPos)
        return (rootPos - eggPos).Magnitude
    end

    local function refreshEggPosition(egg)
        if not egg or not EggData.FindByUid then
            return egg
        end

        local refreshed = EggData.FindByUid(egg.uid, true)

        if refreshed then
            state.targetEgg = refreshed
            return refreshed
        end

        return egg
    end

    local function approachForServerSync(rootPart, targetPos, arriveRadius)
        if not shouldWalkPickupSync() then
            return eggDistance(rootPart.Position, targetPos) <= arriveRadius
        end

        if eggDistance(rootPart.Position, targetPos) > arriveRadius then
            Movement.WalkTo(targetPos, runtime.pickupSyncWalkSpeed or 24)
            state.pickupSettleTicks = 0
            return false
        end

        local settleTicks = runtime.pickupSyncSettleTicks or 4

        if (state.pickupSettleTicks or 0) < settleTicks then
            state.pickupSettleTicks = (state.pickupSettleTicks or 0) + 1
            Movement.WalkTo(targetPos, runtime.pickupSyncWalkSpeed or 24)
            return false
        end

        return true
    end

    local function prepareForPickup(rootPart, eggPos)
        if eggDistance(rootPart.Position, eggPos) > carryRadius() then
            Movement.PrepareForServerAction()
            Movement.WalkTo(eggPos, runtime.pickupSyncWalkSpeed or 24)
            state.pickupSettleTicks = 0
            return false
        end

        Movement.WalkTo(eggPos, runtime.pickupSyncWalkSpeed or 24)

        local settleTicks = runtime.pickupSyncSettleTicks or 4

        if (state.pickupSettleTicks or 0) < settleTicks then
            state.pickupSettleTicks = (state.pickupSettleTicks or 0) + 1
            return false
        end

        return true
    end

    local function tryPickupEgg()
        local egg = refreshEggPosition(state.targetEgg)

        if not egg or not egg.record then
            setServerActionMode(false)
            return false
        end

        local slotKey = resolveSlotKey(egg.record)
        local ok, reason = EggState.CarryFieldEgg(egg.record.Uid, slotKey)

        if ok == true then
            setServerActionMode(false)
            state.pickupSettleTicks = 0
            state.pickupFailCount = 0
            state.isCarrying = true
            state.carryUid = egg.record.Uid
            state.carryConfirmedAt = os.clock()
            clearTargetPath()
            PathService.Invalidate()
            return true
        end

        if reason then
            state.detail = string.format("denied: %s", reason)
        end

        state.pickupSettleTicks = 0
        state.pickupFailCount = (state.pickupFailCount or 0) + 1
        local maxFails = runtime.autoFarmPickupMaxFails or 5

        if state.pickupFailCount >= maxFails then
            state.pickupFailCount = 0
            state.targetEgg = nil
            clearTargetPath()
            setServerActionMode(false)
            setPhase(PHASE.Standby, reason or "pickup failed")
        end

        return false
    end

    local function tickGoToEgg(rootPart, egg)
        egg = refreshEggPosition(egg)
        local eggPos = egg.worldPos
        local dist = eggDistance(rootPart.Position, eggPos)
        local carryR = carryRadius()
        local moveR = pickupMoveRadius()

        if state.phase == PHASE.Pickup or dist <= moveR then
            setPhase(PHASE.Pickup, dist <= carryR and egg.info.name or "approaching")

            if dist > carryR then
                Movement.WalkTo(eggPos, runtime.pickupSyncWalkSpeed or 24)
                state.pickupSettleTicks = 0
                return
            end

            if not prepareForPickup(rootPart, eggPos) then
                return
            end

            Movement.CancelMovement()

            if tryPickupEgg() then
                state.targetEgg = nil
                setPhase(PHASE.ReturnStandby, egg.info.name)
            elseif not state.isCarrying then
                Movement.WalkTo(eggPos, runtime.pickupSyncWalkSpeed or 24)
            else
                setPhase(PHASE.ReturnStandby, egg.info.name)
            end

            return
        end

        setServerActionMode(false)
        followPath(eggPos, moveR)
    end

    local function shouldAutoPlaceDuringFarm()
        if state.rushFarmAfterDay then
            return false
        end

        if not InventoryManager or not InventoryManager.ShouldAutoPlaceDue then
            return false
        end

        if not InventoryManager.ShouldAutoPlaceDue() then
            return false
        end

        local interval = runtime.autoPlaceInterval or 60
        local farmAge = os.clock() - (state.farmStartedAt or 0)

        return farmAge >= interval
    end

    local function beginGoToEgg()
        if EggData.InvalidateCache then
            EggData.InvalidateCache()
        end

        local egg = findRarestEgg(true)

        if not egg then
            return false
        end

        state.lastTargetRefresh = os.clock()
        setTargetEgg(egg, false)
        state.rushFarmAfterDay = false
        state.lastPathCalc = 0
        setPhase(PHASE.GoToEgg, formatTargetDetail(egg))
        return true
    end

    local function tick()
        if not state.enabled then
            return
        end

        if InventoryManager and InventoryManager.IsActive and InventoryManager.IsActive() then
            local invStatus = InventoryManager.GetStatus and InventoryManager.GetStatus()

            if invStatus and invStatus.autoPlaceBackground then
                InventoryManager.Tick()
                return
            end
        end

        local rootPart = Movement.GetRootPart()

        if not rootPart then
            setPhase(PHASE.Idle, "no character")
            return
        end

        if state.phase == PHASE.Idle then
            setPhase(PHASE.Standby, "recovered")
        end

        noteProgress(rootPart.Position)
        checkWatchdog(rootPart)

        local standbyPos = runtime.standbyPosition
        local atStandby = isAtStandby(rootPart.Position, standbyPos)
        local atStandbyStart = isAtStandbyStart(rootPart.Position, standbyPos)

        if state.isCarrying then
            state.depositWaitSince = state.depositWaitSince or os.clock()

            local depositApproach = runtime.depositApproachRadius or 24

            if shouldWalkPickupSync()
                and Movement.HorizontalDistance(rootPart.Position, standbyPos) <= depositApproach then
                if not approachForServerSync(rootPart, standbyPos, runtime.standbyArriveRadius) then
                    setPhase(PHASE.ReturnStandby, "sync home")
                    return
                end

                setPhase(PHASE.WaitDeposit, "waiting for claim")
                return
            end

            if atStandby then
                setPhase(PHASE.WaitDeposit, "waiting for claim")
                setServerActionMode(false)
                if Movement.EnsureLocomotion then
                    Movement.EnsureLocomotion()
                end
            else
                setPhase(PHASE.ReturnStandby)
                setServerActionMode(false)
                followPath(standbyPos, runtime.standbyArriveRadius)
            end

            return
        end

        if shouldWaitForDay() then
            state.wasDayBlocked = true

            if handleNightWait(rootPart, standbyPos, atStandby) then
                return
            end
        else
            if state.wasDayBlocked then
                triggerRushFarmAfterDay()

                if state.phase == PHASE.WaitForDay or state.phase == PHASE.ReturnStandby then
                    setPhase(PHASE.Standby, "eggs dropped")
                end
            end

            state.wasDayBlocked = false
        end

        if InventoryManager and InventoryManager.ShouldFeedParasite and InventoryManager.ShouldFeedParasite() then
            if not InventoryManager.IsActive() then
                InventoryManager.StartFeedParasite()
            end

            if InventoryManager.IsActive() then
                if state.phase ~= PHASE.FeedParasite then
                    setPhase(PHASE.FeedParasite, "feeding infested eggs")
                end

                InventoryManager.Tick()
                return
            end
        elseif state.phase == PHASE.FeedParasite then
            setPhase(PHASE.Standby, "infested fed")
        end

        if InventoryManager then
            if InventoryManager.ShouldManage() then
                if state.phase ~= PHASE.ManageInventory then
                    setPhase(PHASE.ManageInventory, "inventory full")
                    InventoryManager.Start()
                end

                InventoryManager.Tick()
                return
            end

            if state.phase == PHASE.ManageInventory then
                InventoryManager.Stop()
                setPhase(PHASE.Standby, "inventory cleared")
            end
        end

        if state.phase == PHASE.WaitDeposit then
            if atStandby then
                if shouldAutoPlaceDuringFarm()
                    and InventoryManager.StartBackgroundPlace
                    and InventoryManager.StartBackgroundPlace("between runs") then
                    setPhase(PHASE.Standby, "placing eggs")
                    return
                end

                setServerActionMode(false)
                setPhase(PHASE.Standby, "ready for next egg")
            else
                setServerActionMode(false)
                followPath(standbyPos, runtime.standbyArriveRadius)
            end

            return
        end

        if state.phase == PHASE.Standby then
            if state.requireStandbyOnStart and not atStandby and not atStandbyStart then
                setPhase(PHASE.Standby, "going to start")
                followPath(standbyPos, runtime.standbyArriveRadius)
                return
            end

            if state.requireStandbyOnStart and (atStandby or atStandbyStart) then
                state.requireStandbyOnStart = false
                clearTargetPath()
            end

            if InventoryManager and InventoryManager.ShouldManage() then
                setPhase(PHASE.ManageInventory, "inventory full")
                InventoryManager.Start()
                return
            end

            if shouldWaitForDay() then
                handleNightWait(rootPart, standbyPos, atStandby)
                return
            end

            if atStandby
                and shouldAutoPlaceDuringFarm()
                and InventoryManager.StartBackgroundPlace
                and InventoryManager.StartBackgroundPlace("farm standby") then
                setPhase(PHASE.Standby, "placing eggs")
                return
            end

            if beginGoToEgg() then
                -- fall through to GoToEgg handler in the same tick
            elseif state.rushFarmAfterDay then
                setPhase(PHASE.Standby, "waiting for spawn")
                return
            elseif not atStandby then
                followPath(standbyPos, runtime.standbyArriveRadius)
                return
            else
                setPhase(PHASE.Standby, "no eggs")
                if Movement.EnsureLocomotion then
                    Movement.EnsureLocomotion()
                end
                return
            end
        end

        if state.phase == PHASE.GoToEgg or state.phase == PHASE.Pickup then
            if InventoryManager and InventoryManager.ShouldManage() then
                state.targetEgg = nil
                setPhase(PHASE.ManageInventory, "inventory full")
                InventoryManager.Start()
                return
            end

            local egg = refreshTargetEgg(false)

            if not egg then
                setServerActionMode(false)
                setPhase(PHASE.Standby, "target lost")
                return
            end

            tickGoToEgg(rootPart, egg)
            return
        end

        if state.phase == PHASE.ReturnStandby then
            setServerActionMode(false)

            if atStandby then
                setPhase(PHASE.Standby, "home")
                return
            end

            followPath(standbyPos, runtime.standbyArriveRadius)
            return
        end

        setPhase(PHASE.Standby, "reset")
    end

    local function onCarryChanged(carryState)
        state.isCarrying = carryState.IsCarrying == true
        state.carryUid = carryState.Uid
        state.lastProgressAt = os.clock()

        if state.isCarrying then
            state.carryConfirmedAt = os.clock()
            state.depositWaitSince = nil
        else
            state.carryConfirmedAt = nil
            state.depositWaitSince = nil
            state.targetEgg = nil
            state.waypoints = nil
            state.pathGoal = nil
            setServerActionMode(false)
            state.pickupSettleTicks = 0

            if state.enabled then
                setPhase(PHASE.Standby, "deposit complete")
            end
        end
    end

    local function onCharacterAdded()
        if not state.enabled then
            return
        end

        Movement.Reset()
        setServerActionMode(false)
        clearTargetPath()
        state.targetEgg = nil
        state.isCarrying = false
        state.carryUid = nil
        state.pickupSettleTicks = 0
        state.pickupFailCount = 0
        state.depositWaitSince = nil
        state.carryConfirmedAt = nil
        state.requireStandbyOnStart = true
        state.standbyStartAt = os.clock()
        state.lastProgressAt = os.clock()
        state.lastProgressPos = nil
        PathService.Invalidate()
        setPhase(PHASE.Standby, "respawned")
    end

    local function start()
        if state.enabled then
            return getStatus()
        end

        state.enabled = true
        state.targetEgg = nil
        state.waypoints = nil
        state.pathGoal = nil
        state.waypointIndex = 1
        state.lastTargetRefresh = 0
        state.pickupFailCount = 0
        state.pickupSettleTicks = 0
        state.requireStandbyOnStart = false
        state.farmStartedAt = os.clock()
        state.standbyStartAt = os.clock()
        state.wasDayBlocked = shouldWaitForDay()
        state.rushFarmAfterDay = false
        state.phaseEnteredAt = os.clock()
        state.lastProgressAt = os.clock()
        state.lastProgressPos = nil
        state.depositWaitSince = nil
        state.carryConfirmedAt = nil
        setServerActionMode(false)
        PathService.Invalidate()

        if SpeedBypass then
            if runtime.speedBypassOnAutoFarm then
                SpeedBypass.Enable()
            else
                SpeedBypass.Disable()
            end
        end

        Passthrough.Enable()

        if InventoryManager and InventoryManager.NotifyFarmStarted then
            InventoryManager.NotifyFarmStarted()
        end

        if not state.connection then
            state.connection = EggState.CarryChanged:Connect(onCarryChanged)
        end

        if LocalPlayer and not state.characterConnection then
            state.characterConnection = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
        end

        setPhase(PHASE.Standby, "started")

        print("[EggESP Auto] Workflow:")
        print("  1. Standby at home position")
        print("  2. Pick rarest allowed field egg (rarity filters apply)")
        print("  3. Carry egg back to standby")
        print("  4. Wait for auto deposit/claim")
        print("  5. Repeat from step 1")
        print("  Night reset: wait at standby until day")

        return getStatus()
    end

    local function stop()
        state.enabled = false
        state.targetEgg = nil
        state.waypoints = nil
        state.pathGoal = nil
        Movement.Reset()
        Passthrough.Disable()

        if SpeedBypass and runtime.speedBypassOnAutoFarm then
            SpeedBypass.Disable()
        end

        if InventoryManager then
            InventoryManager.Stop()
        end

        setPhase(PHASE.Idle, "stopped")

        return getStatus()
    end

    local function destroy()
        stop()

        if state.connection then
            state.connection:Disconnect()
            state.connection = nil
        end

        if state.characterConnection then
            state.characterConnection:Disconnect()
            state.characterConnection = nil
        end
    end

    return {
        Start = start,
        Stop = stop,
        Destroy = destroy,
        GetStatus = getStatus,
        Tick = tick,
        Phases = PHASE,
    }
end

return AutoFarm
