--[[
    VoidUI window builder — compiled into the same loadstring chunk as hub_loader (see run.lua).
    Do NOT load this file with loadstring(readfile(...)) alone — nested chunks lack Plugin capability.
]]

return function(ctx)
    local VoidUI = ctx.VoidUI
    local theme = ctx.theme
    local runtime = ctx.runtime
    local callbacks = ctx.callbacks or {}
    local formatStatus = ctx.formatStatus
    local AutoFarm = ctx.AutoFarm
    local SpeedBypass = ctx.SpeedBypass
    local PathService = ctx.PathService
    local FarmFilters = ctx.FarmFilters
    local FarmFilterUI = ctx.FarmFilterUI
    local EggData = ctx.EggData
    local BasePenAutomation = ctx.BasePenAutomation
    local LocalPlayer = ctx.LocalPlayer

    local function invalidateFarmTarget()
        if EggData and EggData.InvalidateCache then
            EggData.InvalidateCache()
        end

        if PathService then
            PathService.Invalidate()
        end
    end

    local controls = {}
    local window
    local statusParagraph

    window = VoidUI:CreateWindow({
        Title = "Steal An Egg",
        Author = "EggESP Hub",
        Icon = "lucide:egg",
        Accent = theme.dotCore or Color3.fromRGB(130, 60, 220),
        Size = UDim2.fromOffset(700, 540),
        Transparency = 0.06,
        Bloom = false,
        Search = true,
        OpenButton = true,
        CornerRadius = 12,
        Compact = true,
        ToggleKey = runtime.hubToggleKey or Enum.KeyCode.G,
        Folder = "StealAnEgg",
    })

    local farmTab = window:Tab({ Title = "Farm", Icon = "lucide:target", Selected = true })
    local farmPage = farmTab:Page({ Title = "Auto Farm", Columns = 1 })

    do
        local statusText = "Loading..."

        if formatStatus then
            local ok, text = pcall(formatStatus)

            if ok and typeof(text) == "string" then
                statusText = text
            end
        end

        local statusSec = farmPage:Section({ Title = "STATUS" })
        statusParagraph = statusSec:Paragraph({
            Title = "Live",
            Content = statusText,
        })

        local mainSec = farmPage:Section({ Title = "AUTO FARM" })

        controls.autoFarm = mainSec:Toggle({
            Title = "Auto Farm",
            Desc = "Standby -> rarest allowed egg -> pickup -> return",
            Value = runtime.autoFarmEnabled == true,
            Flag = "autoFarm",
            Callback = function(enabled)
                if enabled then
                    if callbacks.onAutoFarmStart then
                        callbacks.onAutoFarmStart()
                    end
                elseif callbacks.onAutoFarmStop then
                    callbacks.onAutoFarmStop()
                end
            end,
        })

        mainSec:Toggle({
            Title = "Wait For Day",
            Desc = "Pause field farming during night reset",
            Value = runtime.waitForDayBeforeFarm ~= false,
            Flag = "waitForDay",
            Callback = function(enabled)
                runtime.waitForDayBeforeFarm = enabled
            end,
        })

        if FarmFilterUI and FarmFilterUI.addMutantOnlyVoid then
            FarmFilterUI.addMutantOnlyVoid(mainSec, runtime)
        end

        if FarmFilterUI and FarmFilterUI.addInfestedFarmVoid then
            FarmFilterUI.addInfestedFarmVoid(mainSec, runtime, invalidateFarmTarget)
        end

        if FarmFilterUI and FarmFilterUI.addVoidFarmSettings then
            FarmFilterUI.addVoidFarmSettings(mainSec, runtime)
        end

        mainSec:Paragraph({
            Title = "Filters",
            Content = "Open the Filters tab for rarities/zones. Mutant-only toggle is above.",
        })

        mainSec:Button({
            Title = "Set Standby Here",
            Desc = "Use current position as home / standby point",
            Icon = "lucide:map-pin",
            Callback = function()
                local character = LocalPlayer and LocalPlayer.Character
                local rootPart = character and character:FindFirstChild("HumanoidRootPart")

                if rootPart then
                    runtime.standbyPosition = rootPart.Position

                    if PathService then
                        PathService.Invalidate()
                    end

                    VoidUI:Notify({
                        Title = "Standby",
                        Content = string.format(
                            "Standby set to (%.0f, %.0f, %.0f)",
                            rootPart.Position.X,
                            rootPart.Position.Y,
                            rootPart.Position.Z
                        ),
                        Duration = 3,
                    })
                end
            end,
        })
    end

    if FarmFilterUI and FarmFilterUI.buildVoidTab then
        FarmFilterUI.buildVoidTab(window, ctx)
    end

    local petTab = window:Tab({ Title = "Pet", Icon = "lucide:paw-print" })
    local petPage = petTab:Page({ Title = "Pet Care" })

    do
        local petSec = petPage:Section({ Title = "AUTOMATION" })

        petSec:Toggle({
            Title = "Pet Care (Master)",
            Desc = "Master switch for hatch / fuse / equip best",
            Value = runtime.autoPetCareEnabled ~= false,
            Flag = "autoPetCare",
            Callback = function(enabled)
                runtime.autoPetCareEnabled = enabled ~= false
            end,
        })

        petSec:Toggle({
            Title = "Auto Hatch",
            Desc = "Open eggs when ready on plot",
            Value = runtime.autoHatchEnabled ~= false,
            Flag = "autoHatch",
            Callback = function(enabled)
                runtime.autoHatchEnabled = enabled
            end,
        })

        petSec:Toggle({
            Title = "Auto Equip Best",
            Desc = "Wear best pets after hatch / fuse",
            Value = runtime.autoEquipBest ~= false,
            Flag = "autoEquipBest",
            Callback = function(enabled)
                runtime.autoEquipBest = enabled
            end,
        })

        petSec:Toggle({
            Title = "Auto Fuse",
            Desc = "Fuse 3+ duplicate pets automatically",
            Value = runtime.autoFuseEnabled ~= false,
            Flag = "autoFuse",
            Callback = function(enabled)
                runtime.autoFuseEnabled = enabled
            end,
        })

        local penSec = petPage:Section({ Title = "BASE PEN" })

        penSec:Toggle({
            Title = "Auto Upgrade Base",
            Desc = "Buy next base pen tier when you can afford it",
            Value = runtime.autoUpgradeBasePen ~= false,
            Flag = "autoUpgradeBase",
            Callback = function(enabled)
                runtime.autoUpgradeBasePen = enabled == true
            end,
        })

        penSec:Toggle({
            Title = "Auto Collect Money",
            Desc = "Claim pen/offline money while at home base",
            Value = runtime.autoCollectPenMoney ~= false,
            Flag = "autoCollectPen",
            Callback = function(enabled)
                runtime.autoCollectPenMoney = enabled == true
            end,
        })

        penSec:Slider({
            Title = "Collect Interval",
            Desc = "How often to try collecting while at home",
            Min = 5,
            Max = 120,
            Value = runtime.penCollectInterval or 20,
            Suffix = " sec",
            Flag = "penCollectInterval",
            Callback = function(value)
                runtime.penCollectInterval = math.floor(value)
            end,
        })

        if FarmFilterUI and FarmFilterUI.addVoidPenSettings then
            FarmFilterUI.addVoidPenSettings(penSec, runtime, BasePenAutomation)
        end

        if FarmFilterUI and FarmFilterUI.addVoidAutoPlace then
            FarmFilterUI.addVoidAutoPlace(petPage, runtime)
        end
    end

    local espTab = window:Tab({ Title = "ESP", Icon = "lucide:eye" })
    local espPage = espTab:Page({ Title = "Visuals", Columns = 2 })

    do
        local left = espPage:Section({ Title = "OVERLAY", Column = 1 })

        left:Toggle({
            Title = "Treadmill ESP",
            Value = runtime.showTreadmill == true,
            Flag = "espTreadmill",
            Callback = function(enabled)
                runtime.showTreadmill = enabled
            end,
        })

        left:Toggle({
            Title = "Treadmill Bounds",
            Value = runtime.showTreadmillBounds == true,
            Flag = "espTreadmillBounds",
            Callback = function(enabled)
                runtime.showTreadmillBounds = enabled
            end,
        })

        left:Toggle({
            Title = "Trap ESP",
            Value = runtime.showTraps == true,
            Flag = "espTraps",
            Callback = function(enabled)
                runtime.showTraps = enabled
            end,
        })

        left:Toggle({
            Title = "Trap Bounds",
            Value = runtime.showTrapBounds == true,
            Flag = "espTrapBounds",
            Callback = function(enabled)
                runtime.showTrapBounds = enabled
            end,
        })

        local right = espPage:Section({ Title = "PATH", Column = 2 })

        right:Toggle({
            Title = "Avoid Own Traps",
            Value = runtime.pathAvoidOwnTraps == true,
            Flag = "pathAvoidTraps",
            Callback = function(enabled)
                runtime.pathAvoidOwnTraps = enabled

                if PathService then
                    PathService.Invalidate()
                end
            end,
        })

        right:Slider({
            Title = "ESP Max Distance",
            Desc = "Hide eggs farther than this",
            Min = 50,
            Max = 500,
            Value = runtime.maxDistance or 200,
            Suffix = " studs",
            Flag = "espMaxDist",
            Callback = function(value)
                runtime.maxDistance = math.floor(value)
            end,
        })
    end

    local miscTab = window:Tab({ Title = "Misc", Icon = "lucide:sliders-horizontal" })
    local miscPage = miscTab:Page({ Title = "Misc" })

    do
        local miscSec = miscPage:Section({ Title = "MOVEMENT" })

        controls.speedBypass = miscSec:Toggle({
            Title = "Speed Bypass",
            Desc = "Anti lagback speed while auto farming",
            Value = SpeedBypass and SpeedBypass.IsEnabled() or false,
            Flag = "speedBypass",
            Callback = function(enabled)
                if not SpeedBypass then
                    return
                end

                if enabled then
                    SpeedBypass.Enable()
                else
                    SpeedBypass.Disable()
                end
            end,
        })

        if FarmFilterUI and FarmFilterUI.addVoidMiscMovement then
            FarmFilterUI.addVoidMiscMovement(miscSec, runtime, SpeedBypass)
        end
    end

    local settingsTab = window:Tab({ Title = "Settings", Icon = "lucide:settings" })
    local settingsPage = settingsTab:Page({ Title = "Settings" })

    do
        local cfg = settingsPage:Section({ Title = "CONFIG" })

        cfg:Button({
            Title = "Save Config",
            Icon = "lucide:save",
            Callback = function()
                window:SaveConfig("steal-an-egg")
                VoidUI:Notify({
                    Title = "Config",
                    Content = "Saved steal-an-egg.json",
                    Duration = 2,
                })
            end,
        })

        cfg:Button({
            Title = "Load Config",
            Icon = "lucide:folder-open",
            Callback = function()
                if window:LoadConfig("steal-an-egg") then
                    VoidUI:Notify({
                        Title = "Config",
                        Content = "Config loaded",
                        Duration = 2,
                    })
                else
                    VoidUI:Notify({
                        Title = "Config",
                        Content = "No config file found",
                        Duration = 2,
                    })
                end
            end,
        })

        cfg:Keybind({
            Title = "UI Toggle",
            Desc = "Show / hide this menu",
            Value = runtime.hubToggleKey or Enum.KeyCode.G,
            WindowToggle = true,
            Flag = "uiToggle",
            Callback = function(key)
                runtime.hubToggleKey = key
            end,
        })

        cfg:Paragraph({
            Title = "VoidUI",
            Content = string.format(
                "Library v%s · %s or float button to toggle",
                tostring(VoidUI.Version or "?"),
                (runtime.hubToggleKey or Enum.KeyCode.G).Name
            ),
        })
    end

    window:SetVisible(runtime.hubVisible ~= false)

    task.defer(function()
        if window and window.SelectTab and farmTab then
            pcall(function()
                window:SelectTab(farmTab)
            end)
        end
    end)

    VoidUI:Notify({
        Title = "Steal An Egg",
        Content = "VoidUI hub ready",
        Icon = "lucide:egg",
        Duration = 3,
    })

    print(string.format("[EggESP] VoidUI hub loaded (%s)", tostring(VoidUI.Version)))

    if ctx.onBuilt then
        ctx.onBuilt({
            window = window,
            statusParagraph = statusParagraph,
            controls = controls,
            voidUI = VoidUI,
        })
    end
end
