--[[
    ESP lifecycle controller: start/stop render loop.
]]

local Controller = {}

function Controller.create(deps)
    local Config = deps.Config
    local RunService = deps.RunService
    local Workspace = deps.Workspace
    local DataCollector = deps.DataCollector
    local StackLayout = deps.StackLayout
    local DrawingPool = deps.DrawingPool
    local Renderer = deps.Renderer
    local BoundingBoxPool = deps.BoundingBoxPool
    local BoundingBoxRenderer = deps.BoundingBoxRenderer
    local AutoFarm = deps.AutoFarm
    local PetAutomation = deps.PetAutomation
    local BasePenAutomation = deps.BasePenAutomation
    local InventoryManager = deps.InventoryManager
    local Hub = deps.Hub

    local runtime = Config.Runtime

    local renderConnection = nil
    local logicConnection = nil
    local camera = Workspace.CurrentCamera
    local active = false

    local cachedTargets = {}
    local cachedVisible = {}
    local lastEspRefresh = 0
    local lastLogicTick = 0

    local function setHub(hub)
        Hub = hub
    end

    local function refreshEspData(now)
        cachedTargets = DataCollector.Collect()
        cachedVisible = StackLayout.Assign(cachedTargets, camera)
        lastEspRefresh = now
    end

    local function runLogicTick(now)
        if PetAutomation then
            PetAutomation.Tick()
        end

        if BasePenAutomation then
            BasePenAutomation.Tick()
        end

        if InventoryManager and InventoryManager.TickAutoPlace then
            InventoryManager.TickAutoPlace()
        end

        if InventoryManager and InventoryManager.TickAutoSell then
            InventoryManager.TickAutoSell()
        end

        if InventoryManager and InventoryManager.TickAutoDumpWorstEggs then
            InventoryManager.TickAutoDumpWorstEggs()
        end

        AutoFarm.Tick()
        lastLogicTick = now
    end

    local function renderVisuals()
        if not camera then
            camera = Workspace.CurrentCamera

            if not camera then
                return
            end
        end

        Renderer.RenderFrame(cachedVisible, DrawingPool)
        BoundingBoxRenderer.RenderFrame(cachedTargets, camera, BoundingBoxPool)

        if Hub then
            Hub.Render(camera)
        end
    end

    local function onRenderStep()
        local now = os.clock()
        local espInterval = runtime.espRefreshInterval or 0.12

        if now - lastEspRefresh >= espInterval then
            refreshEspData(now)
        end

        renderVisuals()
    end

    local function onLogicStep()
        local now = os.clock()
        local logicInterval = runtime.logicTickInterval or 0.1

        if now - lastLogicTick >= logicInterval then
            runLogicTick(now)
        end
    end

    local function start()
        if renderConnection then
            renderConnection:Disconnect()
        end

        if logicConnection then
            logicConnection:Disconnect()
        end

        lastEspRefresh = 0
        lastLogicTick = 0
        cachedTargets = {}
        cachedVisible = {}

        logicConnection = RunService.Heartbeat:Connect(onLogicStep)
        renderConnection = RunService.RenderStepped:Connect(onRenderStep)
        active = true

        if Hub then
            Hub.Start()
        end

        print("[EggESP] Active")
    end

    local function stop()
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end

        if logicConnection then
            logicConnection:Disconnect()
            logicConnection = nil
        end

        active = false
        cachedTargets = {}
        cachedVisible = {}
        DrawingPool.HideAll()
        BoundingBoxPool.HideAll()

        if Hub then
            Hub.Stop()
        end

        print("[EggESP] Stopped")
    end

    local function destroy()
        stop()
        AutoFarm.Destroy()

        if Hub then
            Hub.Destroy()
        end

        DrawingPool.DestroyAll()
        BoundingBoxPool.DestroyAll()
    end

    return {
        Start = start,
        Stop = stop,
        Destroy = destroy,
        RenderOnce = function()
            onLogicStep()
            onRenderStep()
        end,
        IsActive = function()
            return active
        end,
        SetHub = setHub,
    }
end

return Controller
