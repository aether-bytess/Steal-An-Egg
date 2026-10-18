--[[
    Auto upgrade base pen + auto collect money while in / near the pet area.
]]

local BasePenAutomation = {}

function BasePenAutomation.create(deps)
    local Config = deps.Config
    local Save = deps.Save
    local Remotes = deps.Remotes
    local AssetRoster = deps.AssetRoster
    local PlotState = deps.PlotState
    local LocalPlayer = deps.LocalPlayer
    local Movement = deps.Movement
    local AutoFarm = deps.AutoFarm
    local ReplicatedStorage = deps.ReplicatedStorage

    local runtime = Config.Runtime

    local BaseUpgrade = require(ReplicatedStorage.Client.BaseUpgrade)
    local BaseUpgradeTransitionLifecycle = require(ReplicatedStorage.Client.BaseUpgradeTransitionLifecycle)
    local OfflineAssets = require(ReplicatedStorage.Client.Types.OfflineAssets)
    local Constants = require(ReplicatedStorage.Shared.Globals.Constants)
    local Player = require(ReplicatedStorage.Shared.Player)

    local MIN_CLAIM_MONEY = Constants.OFFLINE_ASSETS.MIN_CLAIM_MONEY

    local state = {
        detail = nil,
        lastUpgradeCheck = 0,
        lastCollectCheck = 0,
        lastClaimAttempt = 0,
        visitingPen = false,
    }

    local function setDetail(detail)
        if state.detail ~= detail then
            state.detail = detail

            if detail then
                print(string.format("[EggESP Pen] %s", detail))
            end
        end
    end

    local function getSave()
        if not Save.IsLocalDataLoaded() then
            return nil
        end

        return Save.Get()
    end

    local function getRootPart()
        if Movement and Movement.GetRootPart then
            return Movement.GetRootPart()
        end

        local character = LocalPlayer.Character

        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function getFeetPosition()
        local feet = Player.Optional.FeetCFrame(LocalPlayer)

        if feet then
            return feet.Position
        end

        local rootPart = getRootPart()

        return rootPart and rootPart.Position
    end

    local function getPetArea()
        return AssetRoster.FindPenArea(LocalPlayer)
    end

    local function getPenCenter(petArea)
        return petArea.Position + Vector3.new(0, 2, 0)
    end

    local function isInsidePetAreaXZ(position, petArea)
        if not position or not petArea then
            return false
        end

        local localPos = petArea.CFrame:PointToObjectSpace(position)
        local scale = runtime.penAreaClaimScale or 0.74
        local halfX = petArea.Size.X * scale * 0.5
        local halfZ = petArea.Size.Z * scale * 0.5

        return math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
    end

    local function isNearStandby(position)
        if not position then
            return false
        end

        local standby = runtime.standbyPosition
        local radius = runtime.standbyArriveRadius or 6

        return (Vector3.new(position.X, 0, position.Z) - Vector3.new(standby.X, 0, standby.Z)).Magnitude <= radius
    end

    local function autoFarmBlocksPenVisit()
        if not AutoFarm or not AutoFarm.GetStatus then
            return false
        end

        local status = AutoFarm.GetStatus()

        if status.isCarrying then
            return true
        end

        local phase = status.phase

        if phase == "GoToEgg" or phase == "ReturnStandby" or phase == "Pickup" then
            return true
        end

        if status.inventory and status.inventory.active then
            return true
        end

        return false
    end

    local function canVisitPen()
        if autoFarmBlocksPenVisit() then
            return false
        end

        if Movement and Movement.IsTweening and Movement.IsTweening() then
            return state.visitingPen
        end

        return true
    end

    local function readOfflineSummary()
        local ok, summary = pcall(function()
            return Remotes.AwayEarnings.FetchSummary:InvokeServer()
        end)

        if not ok or not OfflineAssets.OfflineClaimSummary(summary) then
            return nil
        end

        return summary
    end

    local function tryClaimOfflineMoney()
        local now = os.clock()
        local cooldown = runtime.penCollectClaimCooldown or 3

        if now - state.lastClaimAttempt < cooldown then
            return false
        end

        local summary = readOfflineSummary()

        if not summary then
            return false
        end

        local amount = math.max(summary.TotalAmount or 0, 0)

        if amount < MIN_CLAIM_MONEY then
            return false
        end

        local feetPos = getFeetPosition()
        local petArea = getPetArea()

        if not feetPos or not petArea or not isInsidePetAreaXZ(feetPos, petArea) then
            return false
        end

        state.lastClaimAttempt = now

        local ok, success, _, result = pcall(function()
            return Remotes.AwayEarnings.AskCollect:InvokeServer({
                Kind = "Claim",
            })
        end)

        if ok and success == true and OfflineAssets.OfflineRedeemResult(result) then
            setDetail(string.format("claimed offline $%s", tostring(math.floor(result.AwardedAmount or 0))))
            return true
        end

        setDetail("offline claim failed")
        return false
    end

    local function ensureInsidePenForCollect()
        local petArea = getPetArea()

        if not petArea then
            return false
        end

        local feetPos = getFeetPosition()

        if feetPos and isInsidePetAreaXZ(feetPos, petArea) then
            return true
        end

        if runtime.penCollectVisitPen ~= true or not canVisitPen() then
            return false
        end

        if runtime.penCollectAtStandbyOnly == true and not isNearStandby(feetPos) then
            return false
        end

        local rootPart = getRootPart()

        if not rootPart or not Movement or not Movement.TweenTo then
            return false
        end

        local target = getPenCenter(petArea)

        if Movement.IsNear and Movement.IsNear(rootPart.Position, target, runtime.penCollectArriveRadius or 8) then
            return isInsidePetAreaXZ(getFeetPosition(), petArea)
        end

        if not Movement.IsTweeningTo or not Movement.IsTweeningTo(target) then
            state.visitingPen = true
            Movement.TweenTo(target, runtime.tweenSpeed, function(completed)
                state.visitingPen = false

                if completed then
                    tryClaimOfflineMoney()
                end
            end)
        end

        return false
    end

    local function tryCollectMoney()
        if runtime.autoCollectPenMoney ~= true then
            return false
        end

        if not getSave() then
            return false
        end

        local feetPos = getFeetPosition()
        local petArea = getPetArea()

        if not petArea then
            return false
        end

        if runtime.penCollectAtStandbyOnly == true and not isNearStandby(feetPos) then
            return false
        end

        if isInsidePetAreaXZ(feetPos, petArea) then
            return tryClaimOfflineMoney()
        end

        ensureInsidePenForCollect()
        return false
    end

    local function tryUpgradeBase()
        if runtime.autoUpgradeBasePen ~= true then
            return false
        end

        if runtime.penUpgradeAtStandbyOnly == true then
            local feetPos = getFeetPosition()

            if not isNearStandby(feetPos) then
                return false
            end
        end

        local saveData = getSave()

        if not saveData then
            return false
        end

        if BaseUpgradeTransitionLifecycle.IsPlaying() then
            return false
        end

        if not BaseUpgrade.IsNextTierAffordable(saveData) then
            return false
        end

        local nextTier, nextConfig = BaseUpgrade.ResolveNextTier(saveData)

        if not nextTier or not nextConfig then
            return false
        end

        local ok, started = pcall(BaseUpgrade.PurchaseNextTier)

        if ok and started then
            setDetail(string.format("upgrading base to tier %s", tostring(nextTier)))
            return true
        end

        return false
    end

    local function tick()
        local now = os.clock()
        local didWork = false

        local upgradeInterval = runtime.penUpgradeCheckInterval or 10

        if now - state.lastUpgradeCheck >= upgradeInterval then
            state.lastUpgradeCheck = now

            if tryUpgradeBase() then
                didWork = true
            end
        end

        local collectInterval = runtime.penCollectInterval or 20

        if now - state.lastCollectCheck >= collectInterval then
            state.lastCollectCheck = now

            if tryCollectMoney() then
                didWork = true
            end
        end

        return didWork
    end

    local function getStatus()
        local saveData = getSave()
        local summary = nil
        local claimable = 0
        local affordable = false
        local nextTier = nil
        local petArea = getPetArea()
        local feetPos = getFeetPosition()

        if saveData then
            affordable = BaseUpgrade.IsNextTierAffordable(saveData)
            nextTier = select(1, BaseUpgrade.ResolveNextTier(saveData))
        end

        local ok, fetched = pcall(readOfflineSummary)

        if ok and fetched then
            summary = fetched
            claimable = math.max(fetched.TotalAmount or 0, 0)
        end

        return {
            enabled = runtime.autoUpgradeBasePen == true or runtime.autoCollectPenMoney == true,
            autoUpgrade = runtime.autoUpgradeBasePen == true,
            autoCollect = runtime.autoCollectPenMoney == true,
            detail = state.detail,
            claimableOffline = claimable,
            canUpgrade = affordable,
            nextTier = nextTier,
            baseLevel = saveData and saveData.BaseUpgradeLevel or nil,
            inPenArea = petArea ~= nil and isInsidePetAreaXZ(feetPos, petArea) or false,
            visitingPen = state.visitingPen,
        }
    end

    return {
        Tick = tick,
        GetStatus = getStatus,
        TryUpgrade = tryUpgradeBase,
        TryCollect = tryCollectMoney,
    }
end

return BasePenAutomation
