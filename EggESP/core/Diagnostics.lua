--[[
    Runtime diagnostics for MCP debug and hub status panel.
]]

local Diagnostics = {}

function Diagnostics.create(deps)
    local Config = deps.Config
    local EggData = deps.EggData
    local DataCollector = deps.DataCollector
    local AutoFarm = deps.AutoFarm
    local InventoryManager = deps.InventoryManager
    local Passthrough = deps.Passthrough
    local SpeedBypass = deps.SpeedBypass
    local Controller = deps.Controller
    local BasePenAutomation = deps.BasePenAutomation
    local LocalPlayer = deps.LocalPlayer

    local runtime = Config.Runtime

    local function collect()
        local eggsAll = EggData.CollectAll(false)
        local eggsVis = EggData.Collect(false)
        local bestFarm = EggData.FindBestForFarm and EggData.FindBestForFarm(nil, false) or eggsAll[1]

        local espCounts = {
            egg = #eggsVis,
            treadmill = runtime.showTreadmill and 1 or 0,
            trap = 0,
        }

        local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local standbyDist = nil

        if rootPart then
            standbyDist = (rootPart.Position - runtime.standbyPosition).Magnitude
        end

        local autoStatus = AutoFarm.GetStatus()
        local inventoryStatus = InventoryManager and InventoryManager.GetStatus() or nil
        local dayStatus = autoStatus.dayCycle
        local target = autoStatus.targetEgg
        local penStatus = BasePenAutomation and BasePenAutomation.GetStatus() or nil
        local targetMismatch = false

        if target and bestFarm and target.uid and bestFarm.uid and target.uid ~= bestFarm.uid then
            targetMismatch = true
        end

        return {
            hub = {
                active = Controller.IsActive(),
                menuVisible = runtime.hubVisible,
            },
            esp = {
                maxDistance = runtime.maxDistance,
                showTreadmill = runtime.showTreadmill,
                showTraps = runtime.showTraps,
                eggsTotal = #eggsAll,
                eggsVisible = #eggsVis,
                espCounts = espCounts,
            },
            autoFarm = {
                enabled = autoStatus.enabled,
                phase = autoStatus.phase,
                isCarrying = autoStatus.isCarrying,
                target = target and {
                    name = target.info.name,
                    rarity = target.info.rarityName,
                    tier = target.rarityTier,
                    zone = target.areaName or target.info.areaName,
                    zoneTier = target.areaTier or target.info.areaTier,
                    distance = math.floor(target.distance),
                } or nil,
                bestCandidate = bestFarm and {
                    name = bestFarm.info.name,
                    rarity = bestFarm.info.rarityName,
                    tier = bestFarm.rarityTier,
                    zone = bestFarm.areaName or bestFarm.info.areaName,
                    zoneTier = bestFarm.areaTier or bestFarm.info.areaTier,
                    distance = math.floor(bestFarm.distance),
                    uid = bestFarm.uid,
                } or nil,
                targetMismatch = targetMismatch,
                pickupFails = autoStatus.pickupFailCount,
            },
            basePen = penStatus,
            inventory = inventoryStatus,
            dayCycle = dayStatus,
            player = {
                atStandby = standbyDist ~= nil and standbyDist <= runtime.standbyArriveRadius,
                distToStandby = standbyDist and math.floor(standbyDist) or nil,
            },
            modules = {
                passthrough = Passthrough.IsActive(),
                speedBypass = SpeedBypass and SpeedBypass.IsEnabled() or false,
            },
        }
    end

    return {
        Collect = collect,
    }
end

return Diagnostics
