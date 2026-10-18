--[[
    Steal An Egg hub — VoidUI (https://github.com/Sanchez1911/VoidUI)
]]

local VoidUIHub = {}

local EXECUTOR_IDENTITY = 8

local function withExecutorIdentity(fn)
    local previousIdentity

    if type(getthreadidentity) == "function" then
        local ok, value = pcall(getthreadidentity)

        if ok then
            previousIdentity = value
        end
    end

    if type(setthreadidentity) == "function" then
        pcall(setthreadidentity, EXECUTOR_IDENTITY)
    end

    local ok, result = pcall(fn)

    if type(setthreadidentity) == "function" and previousIdentity ~= nil then
        pcall(setthreadidentity, previousIdentity)
    end

    if not ok then
        error(result, 0)
    end

    return result
end

local function tryExecutorIdentity(fn)
    local ok, result = pcall(withExecutorIdentity, fn)

    return ok, result
end

local VOIDUI_SHA = "ed27ccf745d7835dd9e16245979407fb4440d2bb"
local VOIDUI_URL = "https://raw.githubusercontent.com/Sanchez1911/VoidUI/" .. VOIDUI_SHA .. "/VoidUI.lua"

local LOCAL_VOIDUI = {
    "Steal-An-Egg/EggESP/ui/VoidUI.lua",
    "EggESP/ui/VoidUI.lua",
}

local function loadVoidUI()
    local genv = (type(getgenv) == "function" and getgenv()) or _G

    if genv.__EGGESP_VOIDUI then
        return genv.__EGGESP_VOIDUI
    end

    local ok, body = pcall(function()
        return game:HttpGet(VOIDUI_URL)
    end)

    if ok and typeof(body) == "string" and #body > 500 then
        if body:find("Soft text bloom %(accent glow", 1, true) and not body:find("after mk", 1, true) then
            error("VoidUI stale cache — reopen with SHA URL", 0)
        end

        local fn, err = loadstring(body, "@VoidUI")

        if fn then
            local ok2, lib = pcall(fn)

            if ok2 and lib then
                genv.__EGGESP_VOIDUI = lib
                return lib
            end

            error("VoidUI exec: " .. tostring(lib), 0)
        end

        error("VoidUI compile: " .. tostring(err), 0)
    end

    if type(readfile) == "function" and type(loadstring) == "function" then
        local isfileFn = type(isfile) == "function" and isfile or nil

        for _, path in ipairs(LOCAL_VOIDUI) do
            if not isfileFn or isfileFn(path) then
                local readOk, source = pcall(readfile, path)

                if readOk and typeof(source) == "string" and #source > 500 then
                    local fn = loadstring(source, "@" .. path)

                    if fn then
                        local ok3, lib = pcall(fn)

                        if ok3 and lib then
                            genv.__EGGESP_VOIDUI = lib
                            return lib
                        end
                    end
                end
            end
        end
    end

    error("[EggESP] VoidUI load failed — run hub via loadstring(readfile(...)) or check HttpGet", 0)
end

function VoidUIHub.create(deps)
    local Config = deps.Config
    local AutoFarm = deps.AutoFarm
    local SpeedBypass = deps.SpeedBypass
    local Diagnostics = deps.Diagnostics
    local PathService = deps.PathService
    local FarmFilters = deps.FarmFilters
    local FarmFilterUI = deps.FarmFilterUI
    local EggData = deps.EggData
    local BasePenAutomation = deps.BasePenAutomation
    local LocalPlayer = deps.LocalPlayer or game:GetService("Players").LocalPlayer
    local DrawingHub = deps.DrawingHub
    local RunService = deps.RunService or game:GetService("RunService")

    local theme = Config.Theme
    local runtime = Config.Runtime

    local VoidUI = nil
    local callbacks = {}
    local statusTask = nil
    local statusRunning = false
    local statusParagraph = nil
    local window = nil
    local controls = {}
    local useDrawingFallback = false
    local pendingVoidBuild = false
    local buildAttempts = 0
    local MAX_BUILD_ATTEMPTS = 40

    local function getVoidUI()
        if VoidUI then
            return VoidUI
        end

        VoidUI = loadVoidUI()
        return VoidUI
    end

    local function destroyOrphanVoidWindows()
        local genv = (type(getgenv) == "function" and getgenv()) or _G
        local lib = genv.__EGGESP_VOIDUI or VoidUI

        if not lib or not lib._windows then
            return
        end

        for i = #lib._windows, 1, -1 do
            local entry = lib._windows[i]

            pcall(function()
                if entry and entry.Destroy then
                    entry:Destroy()
                end
            end)
        end
    end

    local function activateDrawingFallback(reason)
        if useDrawingFallback or not DrawingHub then
            return false
        end

        destroyOrphanVoidWindows()

        useDrawingFallback = true
        pendingVoidBuild = false
        print("[EggESP] VoidUI unavailable: " .. tostring(reason))
        print(string.format("[EggESP] Using Drawing hub (%s to toggle)", (runtime.hubToggleKey or Enum.KeyCode.G).Name))

        if DrawingHub.SetCallbacks then
            DrawingHub.SetCallbacks(callbacks)
        end

        if DrawingHub.SetDiagnostics and Diagnostics then
            DrawingHub.SetDiagnostics(Diagnostics)
        end

        DrawingHub.Start()
        return true
    end

    local function setDiagnostics(diagnostics)
        Diagnostics = diagnostics
    end

    local function formatStatus()
        if not Diagnostics then
            return "Diagnostics unavailable"
        end

        local diag = Diagnostics.Collect()
        local lines = {
            string.format(
                "Eggs %d/%d | Phase: %s | Carrying: %s",
                diag.esp.eggsVisible,
                diag.esp.eggsTotal,
                diag.autoFarm.phase,
                tostring(diag.autoFarm.isCarrying)
            ),
        }

        if diag.autoFarm.target then
            local target = diag.autoFarm.target
            local zone = target.zone and ("[" .. target.zone .. "] ") or ""
            local tier = target.zoneTier and target.zoneTier > 0 and (" T" .. target.zoneTier) or ""

            table.insert(
                lines,
                string.format(
                    "Target: %s%s%s (%s) %dm",
                    zone,
                    target.name,
                    tier,
                    target.rarity,
                    target.distance
                )
            )
        elseif diag.autoFarm.bestCandidate then
            local candidate = diag.autoFarm.bestCandidate
            local zone = candidate.zone and ("[" .. candidate.zone .. "] ") or ""
            local tier = candidate.zoneTier and candidate.zoneTier > 0 and (" T" .. candidate.zoneTier) or ""

            table.insert(
                lines,
                string.format(
                    "Next: %s%s%s (%s) %dm",
                    zone,
                    candidate.name,
                    tier,
                    candidate.rarity,
                    candidate.distance
                )
            )
        else
            table.insert(lines, "Target: none")
        end

        if diag.inventory and diag.inventory.active then
            table.insert(
                lines,
                string.format("Inventory: %s (%s)", diag.inventory.phase, diag.inventory.detail or "")
            )
        end

        if diag.dayCycle and diag.dayCycle.blocked then
            table.insert(lines, "Night reset: waiting for day")
        end

        if diag.basePen then
            local pen = diag.basePen
            local penParts = {}

            if pen.claimableOffline and pen.claimableOffline > 0 then
                table.insert(penParts, string.format("claim $%d", pen.claimableOffline))
            end

            if pen.canUpgrade and pen.nextTier then
                table.insert(penParts, string.format("upgrade T%s ready", tostring(pen.nextTier)))
            end

            if pen.detail and pen.detail ~= "" then
                table.insert(penParts, pen.detail)
            end

            if #penParts > 0 then
                table.insert(lines, "Pen: " .. table.concat(penParts, " | "))
            end
        end

        if diag.autoFarm.targetMismatch then
            table.insert(lines, "Target stale — refreshing next tick")
        end

        return table.concat(lines, "\n")
    end

    local function syncAutoFarmToggle()
        if controls.autoFarm and controls.autoFarm.Set then
            local enabled = AutoFarm.GetStatus().enabled
            controls.autoFarm:Set(enabled, true)
        end
    end

    local function startStatusLoop()
        if statusRunning then
            return
        end

        statusRunning = true

        statusTask = task.spawn(function()
            while statusRunning and statusParagraph and statusParagraph.Set do
                if not window or not window.ScreenGui or not window.ScreenGui.Parent then
                    break
                end

                syncAutoFarmToggle()
                statusParagraph:Set(formatStatus())
                task.wait(runtime.hubStatusRefreshInterval or 0.5)
            end

            statusRunning = false
            statusTask = nil
        end)
    end

    local function stopStatusLoop()
        statusRunning = false
    end

    local function attachBuilt(state)
        if not state or not state.window then
            return false
        end

        window = state.window
        statusParagraph = state.statusParagraph
        controls = state.controls or {}
        VoidUI = state.voidUI or VoidUI
        pendingVoidBuild = false
        useDrawingFallback = false

        if window.SetVisible then
            window:SetVisible(runtime.hubVisible ~= false)
        end

        startStatusLoop()

        return true
    end

    local function getBuildContext()
        return {
            theme = theme,
            runtime = runtime,
            callbacks = callbacks,
            formatStatus = formatStatus,
            AutoFarm = AutoFarm,
            SpeedBypass = SpeedBypass,
            PathService = PathService,
            FarmFilters = FarmFilters,
            FarmFilterUI = FarmFilterUI,
            EggData = EggData,
            BasePenAutomation = BasePenAutomation,
            LocalPlayer = LocalPlayer,
        }
    end

    local function tryBuild()
        if window or useDrawingFallback or not pendingVoidBuild then
            return
        end

        pendingVoidBuild = false
        activateDrawingFallback("VoidUI not built — use loadstring(readfile(hub_loader))()")
    end

    local function setCallbacks(newCallbacks)
        callbacks = newCallbacks or {}

        if DrawingHub and DrawingHub.SetCallbacks then
            DrawingHub.SetCallbacks(callbacks)
        end
    end

    local function start()
        if useDrawingFallback then
            if DrawingHub then
                DrawingHub.Start()
            end

            return
        end

        if window then
            startStatusLoop()

            if window.SetVisible then
                window:SetVisible(runtime.hubVisible ~= false)
            end

            return
        end

        pendingVoidBuild = true
        tryBuild()
    end

    local function stop()
        if useDrawingFallback then
            if DrawingHub then
                DrawingHub.Stop()
            end

            return
        end

        stopStatusLoop()

        if window and window.SetVisible then
            window:SetVisible(false)
        end
    end

    local function destroy()
        if useDrawingFallback then
            if DrawingHub then
                DrawingHub.Destroy()
            end

            return
        end

        stopStatusLoop()

        if window and window.Destroy then
            window:Destroy()
        end

        window = nil
        statusParagraph = nil
        controls = {}
    end

    return {
        Start = start,
        Stop = stop,
        Destroy = destroy,
        TryBuild = tryBuild,
        GetBuildContext = getBuildContext,
        AttachBuilt = attachBuilt,
        ActivateDrawingFallback = activateDrawingFallback,
        Render = function(_camera)
            if useDrawingFallback and DrawingHub then
                DrawingHub.Render(_camera)
            end
        end,
        SetCallbacks = setCallbacks,
        SetVisible = function(value)
            runtime.hubVisible = value == true

            if useDrawingFallback and DrawingHub then
                DrawingHub.SetVisible(value)
                return
            end

            if window and window.SetVisible then
                window:SetVisible(runtime.hubVisible)
            end
        end,
        IsVisible = function()
            if useDrawingFallback and DrawingHub then
                return DrawingHub.IsVisible()
            end

            if window and window.Visible ~= nil then
                return window.Visible
            end

            return runtime.hubVisible ~= false
        end,
        ToggleVisible = function()
            if useDrawingFallback and DrawingHub then
                return DrawingHub.ToggleVisible()
            end

            if window and window.Toggle then
                window:Toggle()
                runtime.hubVisible = window.Visible
                return window.Visible
            end

            runtime.hubVisible = not (runtime.hubVisible ~= false)

            if window and window.SetVisible then
                window:SetVisible(runtime.hubVisible)
            end

            return runtime.hubVisible
        end,
        SetDiagnostics = function(diagnostics)
            setDiagnostics(diagnostics)

            if DrawingHub and DrawingHub.SetDiagnostics then
                DrawingHub.SetDiagnostics(diagnostics)
            end
        end,
    }
end

return VoidUIHub
