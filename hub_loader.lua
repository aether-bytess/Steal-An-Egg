--[[
    Steal An Egg - Unified Hub Loader
    Starts MCP bridge (if needed) then EggESP hub.

    Execute (required for VoidUI):
        loadstring(readfile("Steal-An-Egg/run.lua"))()
        -- run.lua merges hub_loader + void_build into ONE loadstring chunk

    Minimal menu only (no Settings/Misc tabs):
        loadstring(readfile("Steal-An-Egg/hub_loader.lua"))()

    Do NOT use loadfile() — menu will be empty (no Instance/Plugin capability).

    Play without MCP bridge (default — less lag):
        -- bridge is OFF unless you opt in:
        getgenv().__HUB_ENABLE_MCP_BRIDGE = true

    Force skip bridge:
        getgenv().__HUB_SKIP_MCP_BRIDGE = true

    Force Drawing hub (skip VoidUI):
        getgenv().__HUB_FORCE_DRAWING = true
]]

local genv = (type(getgenv) == "function" and getgenv()) or _G

local VOIDUI_SHA = "ed27ccf745d7835dd9e16245979407fb4440d2bb"
local VOIDUI_URL = "https://raw.githubusercontent.com/Sanchez1911/VoidUI/" .. VOIDUI_SHA .. "/VoidUI.lua"

local VOIDUI_LOCAL = {
    "Steal-An-Egg/EggESP/ui/VoidUI.lua",
    "EggESP/ui/VoidUI.lua",
    "GUI/VoidUI.lua",
    "VoidUI.lua",
}

-- Same loadLib pattern as VoidUI.Example.lua — HttpGet + loadstring only (never loadfile VoidUI)
local function preloadVoidUI()
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

        for _, path in ipairs(VOIDUI_LOCAL) do
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

    error("VoidUI load failed — check HttpGet / local VoidUI.lua", 0)
end

local VOID_BUILD_PATHS = {
    "Steal-An-Egg/EggESP/ui/void_build.lua",
    "EggESP/ui/void_build.lua",
}

local PLUGIN_IDENTITIES = { 7, 2, 8 }

local function withPluginIdentity(fn)
    local previousIdentity

    if type(getthreadidentity) == "function" then
        pcall(function()
            previousIdentity = getthreadidentity()
        end)
    end

    local lastErr

    for _, identity in ipairs(PLUGIN_IDENTITIES) do
        if type(setthreadidentity) == "function" then
            pcall(setthreadidentity, identity)
        end

        local ok, result = pcall(fn)

        if ok then
            if type(setthreadidentity) == "function" and previousIdentity ~= nil then
                pcall(setthreadidentity, previousIdentity)
            end

            return true, result
        end

        lastErr = result
        local message = tostring(result)

        if not message:find("Plugin", 1, true) and not message:find("CoreGui", 1, true) and not message:find("Instance", 1, true) then
            if type(setthreadidentity) == "function" and previousIdentity ~= nil then
                pcall(setthreadidentity, previousIdentity)
            end

            error(result, 0)
        end
    end

    if type(setthreadidentity) == "function" and previousIdentity ~= nil then
        pcall(setthreadidentity, previousIdentity)
    end

    return false, lastErr
end

-- Minimal menu built in THIS file (same executor chunk as HttpGet VoidUI — always works)
local function buildVoidMenuMinimal(ctx)
    local VoidUI = ctx.VoidUI
    local runtime = ctx.runtime
    local callbacks = ctx.callbacks or {}
    local theme = ctx.theme or {}
    local controls = {}

    local window = VoidUI:CreateWindow({
        Title = "Steal An Egg",
        Author = "EggESP Hub",
        Accent = theme.dotCore or Color3.fromRGB(130, 60, 220),
        Size = UDim2.fromOffset(700, 540),
        Transparency = 0.06,
        Bloom = false,
        Search = false,
        OpenButton = true,
        CornerRadius = 12,
        Compact = true,
        ToggleKey = runtime.hubToggleKey or Enum.KeyCode.G,
        Folder = "StealAnEgg",
    })

    local farmTab = window:Tab({ Title = "Farm", Icon = "lucide:target", Selected = true })
    local farmPage = farmTab:Page({ Title = "Auto Farm", Columns = 1 })
    local farmSec = farmPage:Section({ Title = "AUTO FARM" })

    controls.autoFarm = farmSec:Toggle({
        Title = "Auto Farm",
        Desc = "Standby -> zone priority -> pickup -> return",
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

    farmSec:Toggle({
        Title = "Wait For Day",
        Value = runtime.waitForDayBeforeFarm ~= false,
        Callback = function(enabled)
            runtime.waitForDayBeforeFarm = enabled
        end,
    })

    if ctx.FarmFilterUI and ctx.FarmFilterUI.addVoidFarmSettings then
        ctx.FarmFilterUI.addVoidFarmSettings(farmSec, runtime)
    end

    if ctx.FarmFilterUI and ctx.FarmFilterUI.buildVoidTab then
        ctx.FarmFilterUI.buildVoidTab(window, ctx)
    end

    local petTab = window:Tab({ Title = "Pet", Icon = "lucide:paw-print" })
    local petPage = petTab:Page({ Title = "Pet Care" })
    local petSec = petPage:Section({ Title = "AUTOMATION" })

    petSec:Toggle({
        Title = "Auto Hatch",
        Value = runtime.autoHatchEnabled ~= false,
        Callback = function(v)
            runtime.autoHatchEnabled = v
        end,
    })

    petSec:Toggle({
        Title = "Auto Equip Best",
        Value = runtime.autoEquipBest ~= false,
        Callback = function(v)
            runtime.autoEquipBest = v
        end,
    })

    petSec:Toggle({
        Title = "Auto Fuse",
        Value = runtime.autoFuseEnabled ~= false,
        Callback = function(v)
            runtime.autoFuseEnabled = v
        end,
    })

    local espTab = window:Tab({ Title = "ESP", Icon = "lucide:eye" })
    local espPage = espTab:Page({ Title = "Visuals", Columns = 2 })
    local espLeft = espPage:Section({ Title = "OVERLAY", Column = 1 })

    espLeft:Toggle({
        Title = "Treadmill ESP",
        Value = runtime.showTreadmill == true,
        Callback = function(v)
            runtime.showTreadmill = v
        end,
    })

    espLeft:Toggle({
        Title = "Trap ESP",
        Value = runtime.showTraps == true,
        Callback = function(v)
            runtime.showTraps = v
        end,
    })

    local espRight = espPage:Section({ Title = "PATH", Column = 2 })

    espRight:Toggle({
        Title = "Avoid Own Traps",
        Value = runtime.pathAvoidOwnTraps == true,
        Callback = function(v)
            runtime.pathAvoidOwnTraps = v
        end,
    })

    window:SetVisible(runtime.hubVisible ~= false)

    task.defer(function()
        pcall(function()
            window:SelectTab(farmTab)
        end)
    end)

    print(string.format("[Hub] VoidUI minimal menu OK (%s)", tostring(VoidUI.Version)))

    if ctx.onBuilt then
        ctx.onBuilt({
            window = window,
            statusParagraph = nil,
            controls = controls,
            voidUI = VoidUI,
        })
    end

    return true
end

local function tryLoadVoidBuildFn()
    if typeof(__EGGESP_VOID_BUILD) == "function" then
        return __EGGESP_VOID_BUILD
    end

    return nil
end

local function buildVoidMenuFromLoader(hub)
    if not hub or not hub.GetBuildContext or not hub.AttachBuilt then
        return false
    end

    local VoidUI = genv.__EGGESP_VOIDUI

    if typeof(VoidUI) ~= "table" then
        return false
    end

    local ctx = hub.GetBuildContext()
    ctx.VoidUI = VoidUI
    ctx.onBuilt = function(state)
        hub.AttachBuilt(state)
    end

    local buildFn = tryLoadVoidBuildFn()

    if buildFn then
        local ok, err = withPluginIdentity(function()
            buildFn(ctx)
        end)

        if ok then
            print("[Hub] VoidUI full menu built")
            return true
        end

        warn("[Hub] void_build failed: " .. tostring(err))
    end

    local ok, err = withPluginIdentity(function()
        buildVoidMenuMinimal(ctx)
    end)

    if ok then
        return true
    end

    warn("[Hub] minimal menu failed: " .. tostring(err))

    if hub.ActivateDrawingFallback then
        hub.ActivateDrawingFallback(tostring(err))
    end

    return false
end

if genv.__HUB_FORCE_DRAWING ~= true then
    local voidOk, voidResult = pcall(preloadVoidUI)

    if voidOk then
        print(string.format("[Hub] VoidUI %s preloaded (sha %s)", tostring(voidResult.Version), VOIDUI_SHA:sub(1, 8)))
    else
        warn("[Hub] VoidUI preload failed: " .. tostring(voidResult))
    end
end

local BRIDGE_PATHS = {
    "Steal-An-Egg/potassium_bridge.lua",
    "potassium_bridge.lua",
}

local HUB_PATHS = {
    "Steal-An-Egg/EggESP.lua",
    "EggESP.lua",
}

if not genv.__MCP_BRIDGE_PERF then
    genv.__MCP_BRIDGE_PERF = {
        SNAPSHOT_INTERVAL = 2,
        EXPLORER_INTERVAL = 300,
        LOG_FLUSH_INTERVAL = 2,
        FILE_POLL_INTERVAL = 1,
        FILE_MIRROR_INTERVAL = 2,
        SCAN_YIELD_EVERY = 800,
        PERIODIC_RESCAN = false,
    }
end

local function loadScript(path)
    if type(readfile) == "function" and type(loadstring) == "function" then
        local readOk, source = pcall(readfile, path)

        if readOk and typeof(source) == "string" and #source > 0 then
            local chunk, err = loadstring(source, "@" .. path)

            if chunk then
                return chunk
            end

            warn("[Hub] loadstring failed: " .. path .. " — " .. tostring(err))
        end
    end

    return loadfile(path)
end

if genv.__HUB_ENABLE_MCP_BRIDGE == true and genv.__HUB_SKIP_MCP_BRIDGE ~= true and not genv.__MCP_BRIDGE_GENERATION then
    for _, path in ipairs(BRIDGE_PATHS) do
        local chunk = loadScript(path)

        if chunk then
            local ok, err = pcall(chunk)

            if not ok then
                warn("[Hub] bridge failed: " .. tostring(err))
            else
                print("[Hub] MCP bridge started (lite perf profile)")
            end

            break
        end
    end
elseif genv.__HUB_SKIP_MCP_BRIDGE or genv.__HUB_ENABLE_MCP_BRIDGE ~= true then
    print("[Hub] MCP bridge skipped")
end

for _, path in ipairs(HUB_PATHS) do
    local chunk = loadScript(path)

    if chunk then
        local ok, result = pcall(function()
            genv.__EGGESP_SKIP_INIT_UI = true
            return chunk()
        end)

        if not ok then
            error("[Hub] EggESP failed: " .. tostring(result), 0)
        end

        genv.__EGGESP_SKIP_INIT_UI = nil

        if genv.__EGGESP_VOIDUI and genv.__HUB_FORCE_DRAWING ~= true then
            local hub = result.Modules and result.Modules.Hub
            buildVoidMenuFromLoader(hub)
        end

        if type(setthreadidentity) == "function" then
            pcall(setthreadidentity, 8)
        end

        local startOk, startErr = pcall(function()
            result.Start()
        end)

        if not startOk then
            warn("[Hub] EggESP Start failed: " .. tostring(startErr))
        end

        local toggleKey = Enum.KeyCode.G

        if result.GetConfig then
            toggleKey = result.GetConfig().Runtime.hubToggleKey or toggleKey
        end

        print(string.format("[Hub] EggESP ready — %s toggles menu", toggleKey.Name))
        return result
    end
end

error("[Hub] EggESP.lua not found", 0)
