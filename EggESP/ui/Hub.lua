--[[
    Steal An Egg hub — Drawing UI (works on Potassium / loadfile).
    Default toggle: G | click tabs + rows
]]

local Hub = {}

function Hub.create(deps)
    local Config = deps.Config
    local Util = deps.Util
    local UserInputService = deps.UserInputService
    local AutoFarm = deps.AutoFarm
    local SpeedBypass = deps.SpeedBypass
    local Diagnostics = deps.Diagnostics
    local PathService = deps.PathService
    local FarmFilters = deps.FarmFilters
    local FarmFilterUI = deps.FarmFilterUI
    local EggData = deps.EggData
    local BasePenAutomation = deps.BasePenAutomation
    local LocalPlayer = deps.LocalPlayer or game:GetService("Players").LocalPlayer

    local theme = Config.Theme
    local layout = Config.Layout
    local runtime = Config.Runtime
    local font = Config.Drawing.font

    local visible = runtime.hubVisible ~= false
    local activeTab = "Farm"
    local clickRegions = {}
    local inputConnection = nil
    local callbacks = {}

    local statusCache = {
        at = 0,
        lines = { "Loading...", "", "" },
    }

    local TABS = {
        { id = "Farm", label = "FRM" },
        { id = "Rarity", label = "RAR" },
        { id = "Zone", label = "ZON" },
        { id = "Sell", label = "SEL" },
        { id = "ESP", label = "ESP" },
        { id = "Pet", label = "PET" },
        { id = "Misc", label = "MSC" },
    }

    local function buildFilterRows(section)
        if FarmFilterUI and FarmFilterUI.buildDrawingRows then
            return FarmFilterUI.buildDrawingRows(FarmFilters, section, invalidateFarmTarget)
        end

        return {
            {
                label = "Filters unavailable",
                isOn = function()
                    return false
                end,
                toggle = function() end,
            },
        }
    end

    local function invalidateFarmTarget()
        if EggData and EggData.InvalidateCache then
            EggData.InvalidateCache()
        end

        if PathService then
            PathService.Invalidate()
        end
    end

    local draw = {
        shadow = Util.createDrawing("Square", { Filled = true, Visible = false }),
        panel = Util.createDrawing("Square", { Filled = true, Visible = false }),
        border = Util.createDrawing("Square", { Filled = false, Thickness = 1, Visible = false }),
        sidebar = Util.createDrawing("Square", { Filled = true, Visible = false }),
        title = Util.createDrawing("Text", { Size = 15, Center = false, Outline = true, Visible = false }),
        hint = Util.createDrawing("Text", { Size = 12, Center = false, Outline = true, Visible = false }),
        section = Util.createDrawing("Text", { Size = 13, Center = false, Outline = true, Visible = false }),
    }

    local tabDrawings = {}
    local rowDrawings = {}
    local statusDrawings = {}

    local function setDiagnostics(diagnostics)
        Diagnostics = diagnostics
    end

    local function ensureTabs(count)
        while #tabDrawings < count do
            table.insert(tabDrawings, {
                bg = Util.createDrawing("Square", { Filled = true, Visible = false }),
                label = Util.createDrawing("Text", { Size = 11, Center = true, Outline = true, Visible = false }),
            })
        end
    end

    local function ensureRows(count)
        while #rowDrawings < count do
            table.insert(rowDrawings, {
                bg = Util.createDrawing("Square", { Filled = true, Visible = false }),
                track = Util.createDrawing("Square", { Filled = true, Visible = false }),
                knob = Util.createDrawing("Square", { Filled = true, Visible = false }),
                label = Util.createDrawing("Text", { Size = 13, Center = false, Outline = true, Visible = false }),
            })
        end
    end

    local function ensureStatusLines(count)
        while #statusDrawings < count do
            table.insert(statusDrawings, Util.createDrawing("Text", {
                Size = 12,
                Center = false,
                Outline = true,
                Visible = false,
            }))
        end
    end

    local function hideTabs(fromIndex)
        for index = fromIndex, #tabDrawings do
            tabDrawings[index].bg.Visible = false
            tabDrawings[index].label.Visible = false
        end
    end

    local function hideRows(fromIndex)
        for index = fromIndex, #rowDrawings do
            local row = rowDrawings[index]
            row.bg.Visible = false
            row.track.Visible = false
            row.knob.Visible = false
            row.label.Visible = false
        end
    end

    local function hideStatus(fromIndex)
        for index = fromIndex, #statusDrawings do
            statusDrawings[index].Visible = false
        end
    end

    local function hideAll()
        for _, object in pairs(draw) do
            object.Visible = false
        end

        hideTabs(1)
        hideRows(1)
        hideStatus(1)
        clickRegions = {}
    end

    local function buildTabRows(tabId)
        if tabId == "Farm" then
            local rows = {
                {
                    label = function()
                        return AutoFarm.GetStatus().enabled and "Auto Farm [ON]" or "Auto Farm [OFF]"
                    end,
                    isOn = function()
                        return AutoFarm.GetStatus().enabled
                    end,
                    toggle = function()
                        local status = AutoFarm.GetStatus()

                        if status.enabled then
                            if callbacks.onAutoFarmStop then
                                callbacks.onAutoFarmStop()
                            end
                        elseif callbacks.onAutoFarmStart then
                            callbacks.onAutoFarmStart()
                        end
                    end,
                },
                {
                    label = "Wait For Day (night reset)",
                    isOn = function()
                        return runtime.waitForDayBeforeFarm ~= false
                    end,
                    toggle = function()
                        runtime.waitForDayBeforeFarm = not (runtime.waitForDayBeforeFarm ~= false)
                    end,
                },
            }

            if FarmFilterUI and FarmFilterUI.buildDrawingFarmSettingsRows then
                for _, row in ipairs(FarmFilterUI.buildDrawingFarmSettingsRows(runtime)) do
                    table.insert(rows, row)
                end
            end

            if FarmFilterUI and FarmFilterUI.buildDrawingMutantOnlyRow then
                table.insert(rows, FarmFilterUI.buildDrawingMutantOnlyRow(runtime, invalidateFarmTarget))
            end

            if FarmFilterUI and FarmFilterUI.buildDrawingInfestedRows then
                for _, row in ipairs(FarmFilterUI.buildDrawingInfestedRows(runtime, invalidateFarmTarget)) do
                    table.insert(rows, row)
                end
            end

            if FarmFilterUI and FarmFilterUI.buildDrawingSetStandbyRow then
                table.insert(rows, FarmFilterUI.buildDrawingSetStandbyRow(LocalPlayer, PathService, runtime))
            end

            return rows
        end

        if tabId == "Rarity" then
            return buildFilterRows("rarity")
        end

        if tabId == "Zone" then
            return buildFilterRows("zone")
        end

        if tabId == "Sell" then
            if FarmFilterUI and FarmFilterUI.buildDrawingSellRows then
                return FarmFilterUI.buildDrawingSellRows(FarmFilters, runtime)
            end

            return {}
        end

        if tabId == "ESP" then
            return {
                {
                    label = "Treadmill ESP",
                    isOn = function()
                        return runtime.showTreadmill == true
                    end,
                    toggle = function()
                        runtime.showTreadmill = not runtime.showTreadmill
                    end,
                },
                {
                    label = "Treadmill Bounds",
                    isOn = function()
                        return runtime.showTreadmillBounds == true
                    end,
                    toggle = function()
                        runtime.showTreadmillBounds = not runtime.showTreadmillBounds
                    end,
                },
                {
                    label = "Trap ESP",
                    isOn = function()
                        return runtime.showTraps == true
                    end,
                    toggle = function()
                        runtime.showTraps = not runtime.showTraps
                    end,
                },
                {
                    label = "Trap Bounds",
                    isOn = function()
                        return runtime.showTrapBounds == true
                    end,
                    toggle = function()
                        runtime.showTrapBounds = not runtime.showTrapBounds
                    end,
                },
                {
                    label = "Avoid Own Traps",
                    isOn = function()
                        return runtime.pathAvoidOwnTraps == true
                    end,
                    toggle = function()
                        runtime.pathAvoidOwnTraps = not runtime.pathAvoidOwnTraps

                        if PathService then
                            PathService.Invalidate()
                        end
                    end,
                },
            }
        end

        if tabId == "Pet" then
            local rows = {
                {
                    label = "Pet Care (Master)",
                    isOn = function()
                        return runtime.autoPetCareEnabled ~= false
                    end,
                    toggle = function()
                        runtime.autoPetCareEnabled = not (runtime.autoPetCareEnabled ~= false)
                    end,
                },
                {
                    label = "Auto Hatch Ready Eggs",
                    isOn = function()
                        return runtime.autoHatchEnabled ~= false
                    end,
                    toggle = function()
                        runtime.autoHatchEnabled = not (runtime.autoHatchEnabled ~= false)
                    end,
                },
                {
                    label = "Auto Equip Best",
                    isOn = function()
                        return runtime.autoEquipBest ~= false
                    end,
                    toggle = function()
                        runtime.autoEquipBest = not (runtime.autoEquipBest ~= false)
                    end,
                },
                {
                    label = "Auto Fuse (3+ dupes)",
                    isOn = function()
                        return runtime.autoFuseEnabled ~= false
                    end,
                    toggle = function()
                        runtime.autoFuseEnabled = not (runtime.autoFuseEnabled ~= false)
                    end,
                },
                {
                    label = "Auto Upgrade Base Pen",
                    isOn = function()
                        return runtime.autoUpgradeBasePen ~= false
                    end,
                    toggle = function()
                        runtime.autoUpgradeBasePen = not (runtime.autoUpgradeBasePen ~= false)
                    end,
                },
                {
                    label = "Auto Collect Pen Money",
                    isOn = function()
                        return runtime.autoCollectPenMoney ~= false
                    end,
                    toggle = function()
                        runtime.autoCollectPenMoney = not (runtime.autoCollectPenMoney ~= false)
                    end,
                },
            }

            if FarmFilterUI and FarmFilterUI.buildDrawingPenSettingsRows then
                for _, row in ipairs(FarmFilterUI.buildDrawingPenSettingsRows(runtime, BasePenAutomation)) do
                    table.insert(rows, row)
                end
            end

            if FarmFilterUI and FarmFilterUI.buildDrawingAutoPlaceRows then
                for _, row in ipairs(FarmFilterUI.buildDrawingAutoPlaceRows(runtime)) do
                    table.insert(rows, row)
                end
            end

            return rows
        end

        local miscRows = {
            {
                label = "Speed Bypass",
                isOn = function()
                    return SpeedBypass and SpeedBypass.IsEnabled() or false
                end,
                toggle = function()
                    if not SpeedBypass then
                        return
                    end

                    if SpeedBypass.IsEnabled() then
                        SpeedBypass.Disable()
                    else
                        SpeedBypass.Enable()
                    end
                end,
            },
        }

        if FarmFilterUI and FarmFilterUI.buildDrawingMiscMovementRows then
            for _, row in ipairs(FarmFilterUI.buildDrawingMiscMovementRows(runtime, SpeedBypass)) do
                table.insert(miscRows, row)
            end
        end

        return miscRows
    end

    local function refreshStatus()
        if not Diagnostics then
            statusCache.lines = { "No diagnostics", "", "" }
            return
        end

        local diag = Diagnostics.Collect()
        local lines = {
            string.format(
                "Eggs %d/%d | %s | carry:%s",
                diag.esp.eggsVisible,
                diag.esp.eggsTotal,
                diag.autoFarm.phase,
                tostring(diag.autoFarm.isCarrying)
            ),
            "Target: none",
            "",
        }

        if diag.autoFarm.target then
            local t = diag.autoFarm.target
            local zone = t.zone and ("[" .. t.zone .. "] ") or ""
            local tier = t.zoneTier and t.zoneTier > 0 and (" T" .. t.zoneTier) or ""

            lines[2] = string.format("Target: %s%s%s (%s) %dm", zone, t.name, tier, t.rarity, t.distance)
        elseif diag.autoFarm.bestCandidate then
            local c = diag.autoFarm.bestCandidate
            local zone = c.zone and ("[" .. c.zone .. "] ") or ""
            local tier = c.zoneTier and c.zoneTier > 0 and (" T" .. c.zoneTier) or ""

            lines[2] = string.format("Next: %s%s%s (%s) %dm", zone, c.name, tier, c.rarity, c.distance)
        end

        if diag.inventory and diag.inventory.active then
            lines[3] = string.format("Inv: %s - %s", diag.inventory.phase, diag.inventory.detail or "")
        elseif diag.basePen and (diag.basePen.claimableOffline or 0) > 0 then
            lines[3] = string.format("Pen: claim $%d", diag.basePen.claimableOffline)
        elseif diag.basePen and diag.basePen.canUpgrade and diag.basePen.nextTier then
            lines[3] = string.format("Pen: upgrade T%s ready", tostring(diag.basePen.nextTier))
        elseif diag.autoFarm.targetMismatch then
            lines[3] = "Target stale — refreshing"
        elseif diag.dayCycle and diag.dayCycle.blocked then
            lines[3] = "Night reset — waiting for day"
        end

        statusCache.lines = lines
    end

    local function render(camera)
        if not visible or not camera then
            hideAll()
            return
        end

        local sidebarW = 38
        local panelW = layout.hubPanelWidth or 280
        local totalW = panelW + sidebarW
        local rowH = layout.hubRowHeight or 26
        local pad = layout.hubPadding or 10
        local tabH = 32
        local statusLines = 3
        local rows = buildTabRows(activeTab)
        local rowCount = #rows
        local contentH = 44 + rowCount * (rowH + 4) + statusLines * 14 + pad
        local panelH = math.max(contentH, 220)

        local viewport = camera.ViewportSize
        local x = viewport.X - totalW - 14
        local y = 14

        clickRegions = {}

        draw.shadow.Size = Vector2.new(totalW + 4, panelH + 4)
        draw.shadow.Position = Vector2.new(x + 2, y + 2)
        draw.shadow.Color = theme.shadow
        draw.shadow.Transparency = 0.4
        draw.shadow.Visible = true

        draw.panel.Size = Vector2.new(totalW, panelH)
        draw.panel.Position = Vector2.new(x, y)
        draw.panel.Color = Color3.fromRGB(16, 16, 18)
        draw.panel.Transparency = 0.06
        draw.panel.Visible = true

        draw.border.Size = Vector2.new(totalW, panelH)
        draw.border.Position = Vector2.new(x, y)
        draw.border.Color = theme.border
        draw.border.Transparency = 0.1
        draw.border.Visible = true

        draw.sidebar.Size = Vector2.new(sidebarW, panelH)
        draw.sidebar.Position = Vector2.new(x, y)
        draw.sidebar.Color = Color3.fromRGB(12, 12, 14)
        draw.sidebar.Transparency = 0.02
        draw.sidebar.Visible = true

        local contentX = x + sidebarW

        draw.title.Text = "Steal An Egg"
        draw.title.Font = font
        draw.title.Color = theme.textMain
        draw.title.Position = Vector2.new(contentX + pad, y + pad)
        draw.title.Visible = true

        draw.hint.Text = string.format("[%s] hide", runtime.hubToggleKey and runtime.hubToggleKey.Name or "G")
        draw.hint.Font = font
        draw.hint.Color = theme.textMuted
        draw.hint.Position = Vector2.new(contentX + pad, y + pad + 16)
        draw.hint.Visible = true

        draw.section.Text = activeTab
        draw.section.Font = font
        draw.section.Color = theme.dotRing
        draw.section.Position = Vector2.new(contentX + pad, y + pad + 34)
        draw.section.Visible = true

        ensureTabs(#TABS)

        for index, tab in ipairs(TABS) do
            local tabY = y + (index - 1) * (tabH + 2) + 8
            local tabDraw = tabDrawings[index]
            local selected = tab.id == activeTab

            tabDraw.bg.Size = Vector2.new(sidebarW - 4, tabH)
            tabDraw.bg.Position = Vector2.new(x + 2, tabY)
            tabDraw.bg.Color = selected and theme.dotCore or Color3.fromRGB(22, 22, 26)
            tabDraw.bg.Transparency = selected and 0.05 or 0.15
            tabDraw.bg.Visible = true

            tabDraw.label.Text = tab.label
            tabDraw.label.Font = font
            tabDraw.label.Color = selected and theme.textMain or theme.textMuted
            tabDraw.label.Position = Vector2.new(x + sidebarW * 0.5, tabY + 10)
            tabDraw.label.Visible = true

            table.insert(clickRegions, {
                x1 = x + 2,
                y1 = tabY,
                x2 = x + sidebarW - 2,
                y2 = tabY + tabH,
                action = function()
                    activeTab = tab.id
                end,
            })
        end

        hideTabs(#TABS + 1)

        ensureRows(rowCount)

        for index, rowDef in ipairs(rows) do
            local rowY = y + pad + 54 + (index - 1) * (rowH + 4)
            local row = rowDrawings[index]
            local enabled = rowDef.isOn()
            local labelText = typeof(rowDef.label) == "function" and rowDef.label() or rowDef.label
            local rowW = panelW - pad * 2

            row.bg.Size = Vector2.new(rowW, rowH)
            row.bg.Position = Vector2.new(contentX + pad, rowY)
            row.bg.Color = Color3.fromRGB(24, 24, 27)
            row.bg.Transparency = 0.08
            row.bg.Visible = true

            local hideToggle = rowDef.hideToggle == true

            row.track.Visible = not hideToggle
            row.knob.Visible = not hideToggle

            if not hideToggle then
                row.track.Size = Vector2.new(38, 18)
                row.track.Position = Vector2.new(contentX + pad + rowW - 44, rowY + 4)
                row.track.Color = enabled and theme.dotCore or Color3.fromRGB(46, 46, 52)
                row.track.Transparency = 0.05

                row.knob.Size = Vector2.new(14, 14)
                row.knob.Position = enabled
                    and Vector2.new(contentX + pad + rowW - 22, rowY + 6)
                    or Vector2.new(contentX + pad + rowW - 40, rowY + 6)
                row.knob.Color = Color3.fromRGB(245, 245, 247)
                row.knob.Transparency = 0
            end

            row.label.Text = labelText
            row.label.Font = font
            row.label.Color = theme.textMain
            row.label.Position = Vector2.new(contentX + pad + 6, rowY + 5)
            row.label.Visible = true

            table.insert(clickRegions, {
                x1 = contentX + pad,
                y1 = rowY,
                x2 = contentX + pad + rowW,
                y2 = rowY + rowH,
                action = rowDef.toggle,
            })
        end

        hideRows(rowCount + 1)

        if os.clock() - statusCache.at >= (runtime.hubStatusRefreshInterval or 0.5) then
            refreshStatus()
            statusCache.at = os.clock()
        end

        ensureStatusLines(statusLines)

        local statusY = y + panelH - pad - statusLines * 14

        for index = 1, statusLines do
            local line = statusDrawings[index]
            line.Text = statusCache.lines[index] or ""
            line.Font = font
            line.Color = theme.textMuted
            line.Position = Vector2.new(contentX + pad, statusY + (index - 1) * 14)
            line.Visible = line.Text ~= ""
        end

        hideStatus(statusLines + 1)
    end

    local function pointInRegion(mouseX, mouseY, region)
        return mouseX >= region.x1 and mouseX <= region.x2 and mouseY >= region.y1 and mouseY <= region.y2
    end

    local function handleClick(input)
        if not visible or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        local mouse = UserInputService:GetMouseLocation()

        for _, region in ipairs(clickRegions) do
            if pointInRegion(mouse.X, mouse.Y, region) then
                region.action()
                return
            end
        end
    end

    local function handleInput(input, processed)
        if processed then
            return
        end

        if input.KeyCode == (runtime.hubToggleKey or Enum.KeyCode.G) then
            visible = not visible
            runtime.hubVisible = visible
            return
        end

        handleClick(input)
    end

    local function setCallbacks(newCallbacks)
        callbacks = newCallbacks or {}
    end

    local function start()
        if inputConnection then
            inputConnection:Disconnect()
        end

        inputConnection = UserInputService.InputBegan:Connect(handleInput)
        print(string.format("[EggESP] Hub ready — %s to toggle | tabs: FRM RAR ZON ESP PET MSC", (runtime.hubToggleKey or Enum.KeyCode.G).Name))
    end

    local function stop()
        hideAll()

        if inputConnection then
            inputConnection:Disconnect()
            inputConnection = nil
        end
    end

    local function destroy()
        stop()

        for _, object in pairs(draw) do
            object:Remove()
        end

        for _, tab in ipairs(tabDrawings) do
            tab.bg:Remove()
            tab.label:Remove()
        end

        for _, row in ipairs(rowDrawings) do
            row.bg:Remove()
            row.track:Remove()
            row.knob:Remove()
            row.label:Remove()
        end

        for _, line in ipairs(statusDrawings) do
            line:Remove()
        end

        tabDrawings = {}
        rowDrawings = {}
        statusDrawings = {}
    end

    return {
        Start = start,
        Stop = stop,
        Destroy = destroy,
        Render = render,
        SetCallbacks = setCallbacks,
        SetVisible = function(value)
            visible = value == true
            runtime.hubVisible = visible
        end,
        IsVisible = function()
            return visible
        end,
        ToggleVisible = function()
            visible = not visible
            runtime.hubVisible = visible
            return visible
        end,
        SetDiagnostics = setDiagnostics,
    }
end

return Hub
