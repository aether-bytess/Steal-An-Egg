--[[
    Steal An Egg - Egg ESP bootstrap
]]

local INIT_CANDIDATES = {
    "Steal-An-Egg/EggESP/core/Loader.lua",
    "EggESP/core/Loader.lua",
}

local loaderPath
for _, path in ipairs(INIT_CANDIDATES) do
    if loadfile(path) then
        loaderPath = path
        break
    end
end

if not loaderPath then
    error("[EggESP] Loader.lua not found", 0)
end

local Loader = loadfile(loaderPath)()
local ROOT = Loader.resolveRoot()
local import = Loader.create(ROOT)

local Config = import("core/Config")
local Util = import("core/Util")
local TextLayoutModule = import("esp/TextLayout")
local EggDataModule = import("esp/EggData")
local TreadmillDataModule = import("esp/TreadmillData")
local TrapDataModule = import("esp/TrapData")
local DataCollectorModule = import("esp/DataCollector")
local StackLayoutModule = import("esp/StackLayout")
local DrawingPoolModule = import("esp/DrawingPool")
local BoundingBoxPoolModule = import("esp/BoundingBoxPool")
local RendererModule = import("esp/Renderer")
local BoundingBoxRendererModule = import("esp/BoundingBoxRenderer")
local PathfinderModule = import("navigation/Pathfinder")
local ObstacleDataModule = import("esp/ObstacleData")
local PathServiceModule = import("esp/PathService")
local GuardZoneModule = import("automation/GuardZone")
local MovementModule = import("automation/Movement")
local AutoFarmModule = import("automation/AutoFarm")
local InventoryManagerModule = import("automation/InventoryManager")
local PetAutomationModule = import("automation/PetAutomation")
local BasePenAutomationModule = import("automation/BasePenAutomation")
local DayCycleModule = import("automation/DayCycle")
local PassthroughModule = import("automation/Passthrough")
local SpeedBypassModule = import("automation/SpeedBypass")
local DiagnosticsModule = import("core/Diagnostics")
local FarmFiltersModule = import("core/FarmFilters")
local FarmFilterUIModule = import("ui/FarmFilterUI")
local HubDrawingModule = import("ui/Hub")
local VoidUIHubModule = import("ui/VoidUIHub")
local ControllerModule = import("esp/Controller")

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local deps = {
    Config = Config,
    Util = Util,
    Workspace = Workspace,
    RunService = RunService,
    UserInputService = UserInputService,
    LocalPlayer = Players.LocalPlayer,
    CollectionService = CollectionService,
    ReplicatedStorage = ReplicatedStorage,
    EggState = require(ReplicatedStorage.Client.EggState),
    Assets = require(ReplicatedStorage.Data.Assets),
    Areas = require(ReplicatedStorage.Data.Areas),
    Constants = require(ReplicatedStorage.Shared.Globals.Constants),
    Gears = require(ReplicatedStorage.Data.Gears),
    Rarity = require(ReplicatedStorage.Data.Rarity),
    PlotState = require(ReplicatedStorage.Client.PlotState),
    Save = require(ReplicatedStorage.Shared.Save),
    Treadmills = require(ReplicatedStorage.Data.Treadmills),
    TreadmillUtil = require(ReplicatedStorage.Shared.Util.TreadmillUtil),
    STATES = require(ReplicatedStorage.Shared.Types.AreaEggs).States,
    AreaEggSlotIdentity = require(ReplicatedStorage.Shared.Util.AreaEggSlotIdentity),
    Eggs = require(ReplicatedStorage.Shared.Types.Eggs),
    Remotes = require(ReplicatedStorage.Shared.Remotes),
    MonsterParasiteData = require(ReplicatedStorage.Data.MonsterParasite),
    AreaEggCycle = require(ReplicatedStorage.Shared.Util.AreaEggCycle),
    AreaEggResetCycle = require(ReplicatedStorage.Data.AreaEggResetCycle),
    AreaEggResetWall = require(ReplicatedStorage.Client.AreaEggResetWall),
    PlacedEggRenderer = require(ReplicatedStorage.Shared.Eggs.PlacedEggRenderer),
    AssetRoster = require(ReplicatedStorage.Client.AssetRoster),
}

local TextLayout = TextLayoutModule.create(deps)
deps.TextLayout = TextLayout

local FarmFilters = FarmFiltersModule.create(deps)
deps.FarmFilters = FarmFilters

local EggData = EggDataModule.create(deps)
local TreadmillData = TreadmillDataModule.create(deps)
local TrapData = TrapDataModule.create(deps)
local DataCollector = DataCollectorModule.create({
    EggData = EggData,
    TreadmillData = TreadmillData,
    TrapData = TrapData,
})
local StackLayout = StackLayoutModule.create(deps)
local DrawingPool = DrawingPoolModule.create(deps)
local BoundingBoxPool = BoundingBoxPoolModule.create(deps)
local Renderer = RendererModule.create(deps)
local BoundingBoxRenderer = BoundingBoxRendererModule.create(deps)
local Pathfinder = PathfinderModule.create()
local ObstacleData = ObstacleDataModule.create(deps)
local PathService = PathServiceModule.create({
    Config = Config,
    ObstacleData = ObstacleData,
    Pathfinder = Pathfinder,
})
local GuardZone = GuardZoneModule.create({
    Config = Config,
    Workspace = Workspace,
    ReplicatedStorage = ReplicatedStorage,
})
local Movement = MovementModule.create({
    Config = Config,
    LocalPlayer = deps.LocalPlayer,
    GuardZone = GuardZone,
})
deps.Movement = Movement

local DayCycle = DayCycleModule.create(deps)
local Passthrough = PassthroughModule.create(deps)
local SpeedBypass = SpeedBypassModule.create(deps)

-- SpeedBypass hooks fight simple tween movement; only wire when user enables it manually.

local InventoryManager = InventoryManagerModule.create(deps)
local PetAutomation = PetAutomationModule.create(deps)

local AutoFarm = AutoFarmModule.create({
    Config = Config,
    EggData = EggData,
    PathService = PathService,
    Movement = Movement,
    EggState = deps.EggState,
    AreaEggSlotIdentity = deps.AreaEggSlotIdentity,
    Passthrough = Passthrough,
    SpeedBypass = SpeedBypass,
    InventoryManager = InventoryManager,
    DayCycle = DayCycle,
    PetAutomation = PetAutomation,
    LocalPlayer = deps.LocalPlayer,
})

if InventoryManager.SetAutoFarm then
    InventoryManager.SetAutoFarm(AutoFarm)
end

local BasePenAutomation = BasePenAutomationModule.create({
    Config = Config,
    Save = deps.Save,
    Remotes = deps.Remotes,
    AssetRoster = deps.AssetRoster,
    PlotState = deps.PlotState,
    LocalPlayer = deps.LocalPlayer,
    Movement = Movement,
    AutoFarm = AutoFarm,
    ReplicatedStorage = ReplicatedStorage,
})

local Controller = ControllerModule.create({
    Config = Config,
    RunService = RunService,
    Workspace = Workspace,
    DataCollector = DataCollector,
    StackLayout = StackLayout,
    DrawingPool = DrawingPool,
    Renderer = Renderer,
    BoundingBoxPool = BoundingBoxPool,
    BoundingBoxRenderer = BoundingBoxRenderer,
    AutoFarm = AutoFarm,
    PetAutomation = PetAutomation,
    BasePenAutomation = BasePenAutomation,
    InventoryManager = InventoryManager,
    Hub = nil,
})

local Diagnostics = DiagnosticsModule.create({
    Config = Config,
    EggData = EggData,
    DataCollector = DataCollector,
    AutoFarm = AutoFarm,
    InventoryManager = InventoryManager,
    Passthrough = Passthrough,
    SpeedBypass = SpeedBypass,
    Controller = Controller,
    BasePenAutomation = BasePenAutomation,
    LocalPlayer = deps.LocalPlayer,
})

local DrawingHub = HubDrawingModule.create({
    Config = Config,
    Util = Util,
    UserInputService = UserInputService,
    AutoFarm = AutoFarm,
    SpeedBypass = SpeedBypass,
    PathService = PathService,
    Diagnostics = Diagnostics,
    FarmFilters = FarmFilters,
    FarmFilterUI = FarmFilterUIModule,
    EggData = EggData,
    BasePenAutomation = BasePenAutomation,
    LocalPlayer = deps.LocalPlayer,
})

local genv = (type(getgenv) == "function" and getgenv()) or _G
local forceDrawing = genv.__HUB_FORCE_DRAWING == true

local Hub = forceDrawing and DrawingHub or VoidUIHubModule.create({
    Config = Config,
    Util = Util,
    UserInputService = UserInputService,
    RunService = RunService,
    AutoFarm = AutoFarm,
    SpeedBypass = SpeedBypass,
    PathService = PathService,
    DrawingHub = DrawingHub,
    Diagnostics = Diagnostics,
    FarmFilters = FarmFilters,
    FarmFilterUI = FarmFilterUIModule,
    EggData = EggData,
    BasePenAutomation = BasePenAutomation,
    LocalPlayer = deps.LocalPlayer,
})

Controller.SetHub(Hub)

Hub.SetCallbacks({
    onAutoFarmStart = function()
        Config.Runtime.autoFarmEnabled = true
        AutoFarm.Start()
    end,
    onAutoFarmStop = function()
        Config.Runtime.autoFarmEnabled = false
        AutoFarm.Stop()
    end,
})

local function startAutoFarm()
    Config.Runtime.autoFarmEnabled = true
    return AutoFarm.Start()
end

local function stopAutoFarm()
    Config.Runtime.autoFarmEnabled = false
    return AutoFarm.Stop()
end

local API = {
    Root = ROOT,
    Start = Controller.Start,
    Stop = Controller.Stop,
    Destroy = Controller.Destroy,
    RenderOnce = Controller.RenderOnce,
    IsActive = Controller.IsActive,

    SetMaxDistance = function(studs)
        Config.Runtime.maxDistance = studs or math.huge
    end,

    SetAutoFarmMaxDistance = function(_studs)
        -- removed — auto farm has no max travel distance
    end,

    SetShowTreadmill = function(enabled)
        Config.Runtime.showTreadmill = enabled == true
    end,

    SetShowTreadmillBounds = function(enabled)
        Config.Runtime.showTreadmillBounds = enabled == true
    end,

    SetShowTraps = function(enabled)
        Config.Runtime.showTraps = enabled == true
    end,

    SetShowTrapBounds = function(enabled)
        Config.Runtime.showTrapBounds = enabled == true
    end,

    SetTreadmillBoundsMeters = function(scale)
        Config.Layout.treadmillBoundsPadding = math.max((scale or 10) / 10, 0.5)
    end,

    SetPathAvoidOwnTraps = function(enabled)
        Config.Runtime.pathAvoidOwnTraps = enabled == true
        PathService.Invalidate()
    end,

    StartAutoFarm = startAutoFarm,
    StopAutoFarm = stopAutoFarm,

    GetAutoFarmStatus = function()
        return AutoFarm.GetStatus()
    end,

    GetInventoryStatus = function()
        return InventoryManager.GetStatus()
    end,

    GetPetAutomationStatus = function()
        return PetAutomation.GetStatus()
    end,

    GetBasePenStatus = function()
        return BasePenAutomation.GetStatus()
    end,

    GetDayCycleStatus = function()
        return DayCycle.GetStatus()
    end,

    SetWaitForDayBeforeFarm = function(enabled)
        Config.Runtime.waitForDayBeforeFarm = enabled ~= false
    end,

    StartInventoryManage = function()
        return InventoryManager.Start()
    end,

    StopInventoryManage = function()
        return InventoryManager.Stop()
    end,

    GetDiagnostics = function()
        return Diagnostics.Collect()
    end,

    SetStandbyPosition = function(x, y, z)
        Config.Runtime.standbyPosition = Vector3.new(x, y, z)
        PathService.Invalidate()
    end,

    SetStandbyFromPlayer = function()
        local character = deps.LocalPlayer and deps.LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if rootPart then
            Config.Runtime.standbyPosition = rootPart.Position
            PathService.Invalidate()
            return rootPart.Position
        end

        return nil
    end,

    SetTweenSpeed = function(speed)
        Config.Runtime.tweenSpeed = math.clamp(speed or 700, 300, 1000)
    end,

    SetHubVisible = function(enabled)
        Hub.SetVisible(enabled == true)
    end,

    ToggleHub = function()
        return Hub.ToggleVisible()
    end,

    EnableSpeedBypass = function()
        SpeedBypass.Enable()
    end,

    DisableSpeedBypass = function()
        SpeedBypass.Disable()
    end,

    GetConfig = function()
        return Config
    end,

    Modules = {
        Config = Config,
        Util = Util,
        TextLayout = TextLayout,
        EggData = EggData,
        TreadmillData = TreadmillData,
        TrapData = TrapData,
        DataCollector = DataCollector,
        StackLayout = StackLayout,
        DrawingPool = DrawingPool,
        BoundingBoxPool = BoundingBoxPool,
        Renderer = Renderer,
        BoundingBoxRenderer = BoundingBoxRenderer,
        Pathfinder = Pathfinder,
        ObstacleData = ObstacleData,
        PathService = PathService,
        Movement = Movement,
        AutoFarm = AutoFarm,
        InventoryManager = InventoryManager,
        PetAutomation = PetAutomation,
        BasePenAutomation = BasePenAutomation,
        DayCycle = DayCycle,
        Passthrough = Passthrough,
        SpeedBypass = SpeedBypass,
        Diagnostics = Diagnostics,
        FarmFilters = FarmFilters,
        FarmFilterUI = FarmFilterUIModule,
        Hub = Hub,
        Controller = Controller,
    },
}

getgenv().EggESP = API

return API
