--[[
    Shared rarity / zone filter UI for VoidUI hub builders.
]]

local FarmFilterUI = {}

local TWEEN_MIN = 300
local TWEEN_MAX = 1000
local TWEEN_STEP = 50

local PLACE_BATCH_MIN = 1
local PLACE_BATCH_MAX = 20
local PLACE_BATCH_STEP = 1

local PLACE_INTERVAL_MIN = 10
local PLACE_INTERVAL_MAX = 600
local PLACE_INTERVAL_STEP = 10

function FarmFilterUI.clampTweenSpeed(speed)
    return math.clamp(math.floor(speed or 700), TWEEN_MIN, TWEEN_MAX)
end

function FarmFilterUI.clampAutoPlaceBatchSize(size)
    return math.clamp(math.floor(size or 5), PLACE_BATCH_MIN, PLACE_BATCH_MAX)
end

function FarmFilterUI.clampAutoPlaceInterval(seconds)
    return math.clamp(math.floor(seconds or 60), PLACE_INTERVAL_MIN, PLACE_INTERVAL_MAX)
end

function FarmFilterUI.addVoidAutoPlace(page, runtime)
    if not page or not runtime then
        return
    end

    local placeSec = page:Section({ Title = "AUTO PLACE" })

    placeSec:Toggle({
        Title = "Auto Place Enabled",
        Desc = "Place unplaced inventory eggs on your plot periodically",
        Value = runtime.autoPlaceEnabled ~= false,
        Flag = "autoPlaceEnabled",
        Callback = function(enabled)
            runtime.autoPlaceEnabled = enabled ~= false
        end,
    })

    placeSec:Slider({
        Title = "Eggs Per Round",
        Desc = "How many eggs to place each auto-place cycle",
        Min = PLACE_BATCH_MIN,
        Max = PLACE_BATCH_MAX,
        Value = FarmFilterUI.clampAutoPlaceBatchSize(runtime.autoPlaceBatchSize),
        Suffix = "",
        Flag = "autoPlaceBatchSize",
        Callback = function(value)
            runtime.autoPlaceBatchSize = FarmFilterUI.clampAutoPlaceBatchSize(value)
        end,
    })

    placeSec:Slider({
        Title = "Place Interval",
        Desc = "Seconds between auto-place rounds",
        Min = PLACE_INTERVAL_MIN,
        Max = PLACE_INTERVAL_MAX,
        Value = FarmFilterUI.clampAutoPlaceInterval(runtime.autoPlaceInterval),
        Suffix = " sec",
        Flag = "autoPlaceInterval",
        Callback = function(value)
            runtime.autoPlaceInterval = FarmFilterUI.clampAutoPlaceInterval(value)
        end,
    })

    placeSec:Paragraph({
        Title = "Auto Place",
        Content = "Skips when there are no unplaced eggs or no free plot space.",
    })
end

function FarmFilterUI.buildDrawingAutoPlaceRows(runtime)
    local rows = {}

    if not runtime then
        return rows
    end

    local function currentBatch()
        return FarmFilterUI.clampAutoPlaceBatchSize(runtime.autoPlaceBatchSize)
    end

    local function setBatch(size)
        runtime.autoPlaceBatchSize = FarmFilterUI.clampAutoPlaceBatchSize(size)
    end

    local function currentInterval()
        return FarmFilterUI.clampAutoPlaceInterval(runtime.autoPlaceInterval)
    end

    local function setInterval(seconds)
        runtime.autoPlaceInterval = FarmFilterUI.clampAutoPlaceInterval(seconds)
    end

    table.insert(rows, {
        label = "Auto Place Enabled",
        isOn = function()
            return runtime.autoPlaceEnabled ~= false
        end,
        toggle = function()
            runtime.autoPlaceEnabled = not (runtime.autoPlaceEnabled ~= false)
        end,
    })

    table.insert(rows, {
        label = function()
            return string.format("Place Batch: %d eggs", currentBatch())
        end,
        hideToggle = true,
        isOn = function()
            return true
        end,
        toggle = function()
            local nextBatch = currentBatch() + PLACE_BATCH_STEP

            if nextBatch > PLACE_BATCH_MAX then
                nextBatch = PLACE_BATCH_MIN
            end

            setBatch(nextBatch)
        end,
    })

    table.insert(rows, {
        label = "Place Batch -1",
        hideToggle = true,
        isOn = function()
            return false
        end,
        toggle = function()
            setBatch(currentBatch() - PLACE_BATCH_STEP)
        end,
    })

    table.insert(rows, {
        label = "Place Batch +1",
        hideToggle = true,
        isOn = function()
            return true
        end,
        toggle = function()
            setBatch(currentBatch() + PLACE_BATCH_STEP)
        end,
    })

    table.insert(rows, {
        label = function()
            return string.format("Place Interval: %ds", currentInterval())
        end,
        hideToggle = true,
        isOn = function()
            return true
        end,
        toggle = function()
            local nextInterval = currentInterval() + PLACE_INTERVAL_STEP

            if nextInterval > PLACE_INTERVAL_MAX then
                nextInterval = PLACE_INTERVAL_MIN
            end

            setInterval(nextInterval)
        end,
    })

    table.insert(rows, {
        label = "Place Interval -10s",
        hideToggle = true,
        isOn = function()
            return false
        end,
        toggle = function()
            setInterval(currentInterval() - PLACE_INTERVAL_STEP)
        end,
    })

    table.insert(rows, {
        label = "Place Interval +10s",
        hideToggle = true,
        isOn = function()
            return true
        end,
        toggle = function()
            setInterval(currentInterval() + PLACE_INTERVAL_STEP)
        end,
    })

    return rows
end

function FarmFilterUI.addVoidFarmSettings(section, runtime)
    if not section or not runtime then
        return
    end

    section:Slider({
        Title = "Tween Speed",
        Desc = "Movement speed while auto farming (300-1000)",
        Min = TWEEN_MIN,
        Max = TWEEN_MAX,
        Value = FarmFilterUI.clampTweenSpeed(runtime.tweenSpeed),
        Suffix = "",
        Flag = "tweenSpeed",
        Callback = function(value)
            runtime.tweenSpeed = FarmFilterUI.clampTweenSpeed(value)
        end,
    })

    section:Toggle({
        Title = "Strict Filters (Whitelist)",
        Desc = "Only farm rarities/zones that are toggled ON",
        Value = runtime.autoFarmFilterWhitelist ~= false,
        Flag = "filterWhitelist",
        Callback = function(enabled)
            runtime.autoFarmFilterWhitelist = enabled == true
        end,
    })
end

function FarmFilterUI.buildDrawingFarmSettingsRows(runtime)
    local rows = {}

    local function currentSpeed()
        return FarmFilterUI.clampTweenSpeed(runtime and runtime.tweenSpeed)
    end

    local function setSpeed(speed)
        if runtime then
            runtime.tweenSpeed = FarmFilterUI.clampTweenSpeed(speed)
        end
    end

    table.insert(rows, {
        label = function()
            return string.format("Tween Speed: %d", currentSpeed())
        end,
        hideToggle = true,
        isOn = function()
            return true
        end,
        toggle = function()
            local nextSpeed = currentSpeed() + TWEEN_STEP

            if nextSpeed > TWEEN_MAX then
                nextSpeed = TWEEN_MIN
            end

            setSpeed(nextSpeed)
        end,
    })

    table.insert(rows, {
        label = "Tween Speed -50",
        hideToggle = true,
        isOn = function()
            return false
        end,
        toggle = function()
            setSpeed(currentSpeed() - TWEEN_STEP)
        end,
    })

    table.insert(rows, {
        label = "Tween Speed +50",
        hideToggle = true,
        isOn = function()
            return true
        end,
        toggle = function()
            setSpeed(currentSpeed() + TWEEN_STEP)
        end,
    })

    table.insert(rows, {
        label = "Strict Filters (Whitelist)",
        isOn = function()
            return runtime and runtime.autoFarmFilterWhitelist ~= false
        end,
        toggle = function()
            if runtime then
                runtime.autoFarmFilterWhitelist = not (runtime.autoFarmFilterWhitelist ~= false)
            end
        end,
    })

    return rows
end

function FarmFilterUI.buildDrawingSetStandbyRow(localPlayer, pathService, runtime)
    return {
        label = "Set Standby Here",
        hideToggle = true,
        isOn = function()
            return false
        end,
        toggle = function()
            local character = localPlayer and localPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")

            if rootPart and runtime then
                runtime.standbyPosition = rootPart.Position

                if pathService then
                    pathService.Invalidate()
                end
            end
        end,
    }
end

function FarmFilterUI.buildDrawingPenSettingsRows(runtime, penAutomation)
    local rows = {
        {
            label = "Collect At Home Only",
            isOn = function()
                return runtime and runtime.penCollectAtStandbyOnly ~= false
            end,
            toggle = function()
                if runtime then
                    runtime.penCollectAtStandbyOnly = not (runtime.penCollectAtStandbyOnly ~= false)
                end
            end,
        },
        {
            label = "Walk Into Pen",
            isOn = function()
                return runtime and runtime.penCollectVisitPen ~= false
            end,
            toggle = function()
                if runtime then
                    runtime.penCollectVisitPen = not (runtime.penCollectVisitPen ~= false)
                end
            end,
        },
        {
            label = "Upgrade At Home Only",
            isOn = function()
                return runtime and runtime.penUpgradeAtStandbyOnly ~= false
            end,
            toggle = function()
                if runtime then
                    runtime.penUpgradeAtStandbyOnly = not (runtime.penUpgradeAtStandbyOnly ~= false)
                end
            end,
        },
    }

    if penAutomation then
        table.insert(rows, {
            label = "Collect Pen Money Now",
            hideToggle = true,
            isOn = function()
                return false
            end,
            toggle = function()
                penAutomation.TryCollect()
            end,
        })

        table.insert(rows, {
            label = "Upgrade Base Now",
            hideToggle = true,
            isOn = function()
                return false
            end,
            toggle = function()
                penAutomation.TryUpgrade()
            end,
        })
    end

    return rows
end

function FarmFilterUI.buildDrawingMiscMovementRows(runtime, speedBypass)
    return {
        {
            label = "Speed Bypass On Auto Farm",
            isOn = function()
                return runtime and runtime.speedBypassOnAutoFarm ~= false
            end,
            toggle = function()
                if runtime then
                    runtime.speedBypassOnAutoFarm = not (runtime.speedBypassOnAutoFarm ~= false)
                end
            end,
        },
        {
            label = function()
                return string.format("Walk Speed: %d", runtime and runtime.autoFarmWalkSpeed or 300)
            end,
            hideToggle = true,
            isOn = function()
                return true
            end,
            toggle = function()
                if not runtime then
                    return
                end

                local nextSpeed = (runtime.autoFarmWalkSpeed or 300) + 25

                if nextSpeed > 400 then
                    nextSpeed = 100
                end

                runtime.autoFarmWalkSpeed = nextSpeed

                if speedBypass and speedBypass.ApplySpeed then
                    speedBypass.ApplySpeed()
                end
            end,
        },
    }
end

function FarmFilterUI.addVoidPenSettings(section, runtime, penAutomation)
    if not section or not runtime then
        return
    end

    section:Toggle({
        Title = "Collect At Home Only",
        Desc = "Only collect pen money when near standby position",
        Value = runtime.penCollectAtStandbyOnly ~= false,
        Flag = "penCollectHomeOnly",
        Callback = function(enabled)
            runtime.penCollectAtStandbyOnly = enabled == true
        end,
    })

    section:Toggle({
        Title = "Walk Into Pen",
        Desc = "Tween into pet area to claim offline money",
        Value = runtime.penCollectVisitPen ~= false,
        Flag = "penCollectVisitPen",
        Callback = function(enabled)
            runtime.penCollectVisitPen = enabled == true
        end,
    })

    section:Toggle({
        Title = "Upgrade At Home Only",
        Desc = "Only upgrade base pen while near standby",
        Value = runtime.penUpgradeAtStandbyOnly ~= false,
        Flag = "penUpgradeHomeOnly",
        Callback = function(enabled)
            runtime.penUpgradeAtStandbyOnly = enabled == true
        end,
    })

    section:Slider({
        Title = "Upgrade Check Interval",
        Desc = "How often to try upgrading base pen",
        Min = 5,
        Max = 60,
        Value = runtime.penUpgradeCheckInterval or 10,
        Suffix = " sec",
        Flag = "penUpgradeInterval",
        Callback = function(value)
            runtime.penUpgradeCheckInterval = math.floor(value)
        end,
    })

    if penAutomation then
        section:Button({
            Title = "Collect Pen Money Now",
            Icon = "lucide:coins",
            Callback = function()
                penAutomation.TryCollect()
            end,
        })

        section:Button({
            Title = "Upgrade Base Now",
            Icon = "lucide:arrow-up",
            Callback = function()
                penAutomation.TryUpgrade()
            end,
        })
    end
end

function FarmFilterUI.addVoidMiscMovement(section, runtime, speedBypass)
    if not section or not runtime then
        return
    end

    section:Toggle({
        Title = "Speed Bypass On Auto Farm",
        Desc = "Enable anti-lagback speed when auto farm starts",
        Value = runtime.speedBypassOnAutoFarm ~= false,
        Flag = "speedBypassOnFarm",
        Callback = function(enabled)
            runtime.speedBypassOnAutoFarm = enabled == true
        end,
    })

    section:Slider({
        Title = "Walk Speed (Bypass)",
        Desc = "Humanoid WalkSpeed when speed bypass is active",
        Min = 100,
        Max = 400,
        Value = runtime.autoFarmWalkSpeed or 300,
        Suffix = "",
        Flag = "autoFarmWalkSpeed",
        Callback = function(value)
            runtime.autoFarmWalkSpeed = math.floor(value)

            if speedBypass and speedBypass.ApplySpeed then
                speedBypass.ApplySpeed()
            end
        end,
    })
end

function FarmFilterUI.addInfestedFarmVoid(section, runtime, onChange)
    if not section or not runtime then
        return
    end

    section:Toggle({
        Title = "Infested First",
        Desc = "Prioritize parasite / infested field eggs when auto farming",
        Value = runtime.autoFarmInfestedFirst ~= false,
        Flag = "infestedFirst",
        Callback = function(enabled)
            runtime.autoFarmInfestedFirst = enabled ~= false

            if onChange then
                onChange()
            end
        end,
    })

    section:Toggle({
        Title = "Infested Only",
        Desc = "Farm only infested field eggs (HasParasite)",
        Value = runtime.autoFarmInfestedOnly == true,
        Flag = "infestedOnly",
        Callback = function(enabled)
            runtime.autoFarmInfestedOnly = enabled == true

            if onChange then
                onChange()
            end
        end,
    })

    section:Toggle({
        Title = "Feed Frog After Farm",
        Desc = "Feed infested inventory eggs to the parasite frog before next run",
        Value = runtime.autoFeedParasiteEnabled ~= false,
        Flag = "autoFeedParasite",
        Callback = function(enabled)
            runtime.autoFeedParasiteEnabled = enabled ~= false
        end,
    })

    section:Toggle({
        Title = "Highest Rarity First",
        Desc = "Farm only the top enabled rarity tier until none remain",
        Value = runtime.autoFarmMaxRarityTierLock ~= false,
        Flag = "maxRarityTierLock",
        Callback = function(enabled)
            runtime.autoFarmMaxRarityTierLock = enabled ~= false

            if onChange then
                onChange()
            end
        end,
    })
end

function FarmFilterUI.buildDrawingInfestedRows(runtime, onChange)
    return {
        {
            label = "Infested First",
            isOn = function()
                return runtime.autoFarmInfestedFirst ~= false
            end,
            toggle = function()
                runtime.autoFarmInfestedFirst = not (runtime.autoFarmInfestedFirst ~= false)

                if onChange then
                    onChange()
                end
            end,
        },
        {
            label = "Infested Only",
            isOn = function()
                return runtime.autoFarmInfestedOnly == true
            end,
            toggle = function()
                runtime.autoFarmInfestedOnly = not (runtime.autoFarmInfestedOnly == true)

                if onChange then
                    onChange()
                end
            end,
        },
        {
            label = "Feed Frog After Farm",
            isOn = function()
                return runtime.autoFeedParasiteEnabled ~= false
            end,
            toggle = function()
                runtime.autoFeedParasiteEnabled = not (runtime.autoFeedParasiteEnabled ~= false)
            end,
        },
        {
            label = "Highest Rarity First",
            isOn = function()
                return runtime.autoFarmMaxRarityTierLock ~= false
            end,
            toggle = function()
                runtime.autoFarmMaxRarityTierLock = not (runtime.autoFarmMaxRarityTierLock ~= false)

                if onChange then
                    onChange()
                end
            end,
        },
    }
end

function FarmFilterUI.addMutantOnlyVoid(section, runtime, onChange)
    if not section or not runtime then
        return
    end

    section:Toggle({
        Title = "Mutant Only",
        Desc = "Farm only mutated field eggs (Golden / Silver / Rainbow / …)",
        Value = runtime.autoFarmMutantOnly == true,
        Flag = "mutantOnly",
        Callback = function(enabled)
            runtime.autoFarmMutantOnly = enabled == true

            if onChange then
                onChange()
            end
        end,
    })
end

function FarmFilterUI.buildDrawingMutantOnlyRow(runtime, onChange)
    return {
        label = "Mutant Only",
        isOn = function()
            return runtime.autoFarmMutantOnly == true
        end,
        toggle = function()
            runtime.autoFarmMutantOnly = not (runtime.autoFarmMutantOnly == true)

            if onChange then
                onChange()
            end
        end,
    }
end

function FarmFilterUI.buildVoidTab(window, ctx)
    local FarmFilters = ctx.FarmFilters
    local EggData = ctx.EggData
    local PathService = ctx.PathService

    if not FarmFilters or not window then
        return nil
    end

    local function invalidateFarmTarget()
        if EggData and EggData.InvalidateCache then
            EggData.InvalidateCache()
        end

        if PathService then
            PathService.Invalidate()
        end
    end

    FarmFilters.EnsureInitialized()

    local filterTab = window:Tab({ Title = "Filters", Icon = "lucide:filter" })
    local filterPage = filterTab:Page({ Title = "Farm Targets", Columns = 2 })
    local raritySec = filterPage:Section({ Title = "RARITY", Column = 1 })
    local zoneSec = filterPage:Section({ Title = "ZONES", Column = 2 })

    local rarityCount = 0

    for _, option in ipairs(FarmFilters.GetRarityOptions()) do
        rarityCount = rarityCount + 1
        raritySec:Toggle({
            Title = option.label,
            Value = FarmFilters.GetRarityEnabled(option.key),
            Flag = "rarity_" .. option.key,
            Callback = function(enabled)
                FarmFilters.SetRarityEnabled(option.key, enabled)
                invalidateFarmTarget()
            end,
        })
    end

    local zoneCount = 0

    for _, option in ipairs(FarmFilters.GetZoneOptions()) do
        zoneCount = zoneCount + 1
        zoneSec:Toggle({
            Title = option.label,
            Value = FarmFilters.GetZoneEnabled(option.id),
            Flag = "zone_" .. option.id:gsub("%s+", "_"),
            Callback = function(enabled)
                FarmFilters.SetZoneEnabled(option.id, enabled)
                invalidateFarmTarget()
            end,
        })
    end

    filterPage:Section({ Title = "INFO", Column = 1 }):Paragraph({
        Title = "Auto Farm",
        Content = string.format(
            "Toggle each rarity / zone — farm only what is ON (%d rarities, %d zones). Mutant-only is on the Farm tab.",
            rarityCount,
            zoneCount
        ),
    })

    if FarmFilterUI.addVoidAutoSellPage then
        FarmFilterUI.addVoidAutoSellPage(filterTab, ctx)
    end

    return filterTab
end

function FarmFilterUI.addVoidAutoSellPage(filterTab, ctx)
    local FarmFilters = ctx.FarmFilters
    local runtime = ctx.runtime

    if not FarmFilters or not filterTab or not runtime then
        return nil
    end

    FarmFilters.EnsureInitialized()

    local sellPage = filterTab:Page({ Title = "Auto Sell" })
    local sellSec = sellPage:Section({ Title = "AUTO SELL" })

    sellSec:Toggle({
        Title = "Auto Sell Enabled",
        Desc = "Sell unplaced eggs by selected rarities",
        Value = runtime.autoSellEnabled == true,
        Flag = "autoSellEnabled",
        Callback = function(enabled)
            runtime.autoSellEnabled = enabled == true
        end,
    })

    sellSec:Slider({
        Title = "Sell Interval",
        Desc = "Delay between each auto-sell attempt",
        Min = 0.5,
        Max = 10,
        Value = runtime.autoSellInterval or 1.5,
        Suffix = " sec",
        Flag = "autoSellInterval",
        Callback = function(value)
            runtime.autoSellInterval = value
        end,
    })

    local raritySec = sellPage:Section({ Title = "SELL RARITIES" })

    for _, option in ipairs(FarmFilters.GetRarityOptions()) do
        raritySec:Toggle({
            Title = "Sell " .. option.label,
            Desc = "Auto-sell unplaced eggs of this rarity",
            Value = FarmFilters.GetSellRarityEnabled(option.key),
            Flag = "sell_rarity_" .. option.key,
            Callback = function(enabled)
                FarmFilters.SetSellRarityEnabled(option.key, enabled)
            end,
        })
    end

    sellPage:Section({ Title = "INFO" }):Paragraph({
        Title = "Auto Sell",
        Content = "Toggle ON the rarities you want sold from inventory (unplaced eggs only). Does not sell equipped or placed eggs.",
    })

    return sellPage
end

function FarmFilterUI.buildDrawingSellRows(FarmFilters, runtime)
    local rows = {}

    if not FarmFilters or not runtime then
        return rows
    end

    FarmFilters.EnsureInitialized()

    table.insert(rows, {
        label = "Auto Sell Enabled",
        isOn = function()
            return runtime.autoSellEnabled == true
        end,
        toggle = function()
            runtime.autoSellEnabled = not (runtime.autoSellEnabled == true)
        end,
    })

    for _, option in ipairs(FarmFilters.GetRarityOptions()) do
        table.insert(rows, {
            label = "Sell " .. option.label,
            isOn = function()
                return FarmFilters.GetSellRarityEnabled(option.key)
            end,
            toggle = function()
                local enabled = FarmFilters.GetSellRarityEnabled(option.key)
                FarmFilters.SetSellRarityEnabled(option.key, not enabled)
            end,
        })
    end

    return rows
end

function FarmFilterUI.buildDrawingRows(FarmFilters, section, invalidateFarmTarget)
    local rows = {}

    if not FarmFilters then
        table.insert(rows, {
            label = "Filters unavailable",
            isOn = function()
                return false
            end,
            toggle = function() end,
        })

        return rows
    end

    FarmFilters.EnsureInitialized()

    if section == "rarity" then
        for _, option in ipairs(FarmFilters.GetRarityOptions()) do
            table.insert(rows, {
                label = option.label,
                isOn = function()
                    return FarmFilters.GetRarityEnabled(option.key)
                end,
                toggle = function()
                    local enabled = FarmFilters.GetRarityEnabled(option.key)
                    FarmFilters.SetRarityEnabled(option.key, not enabled)
                    invalidateFarmTarget()
                end,
            })
        end

        return rows
    end

    for _, option in ipairs(FarmFilters.GetZoneOptions()) do
        table.insert(rows, {
            label = option.label,
            isOn = function()
                return FarmFilters.GetZoneEnabled(option.id)
            end,
            toggle = function()
                local enabled = FarmFilters.GetZoneEnabled(option.id)
                FarmFilters.SetZoneEnabled(option.id, not enabled)
                invalidateFarmTarget()
            end,
        })
    end

    return rows
end

return FarmFilterUI
