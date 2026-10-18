--[[
    WalkSpeed bypass + anti-lagback (ObbyAntiTP).
    Destroying the LocalScript is not enough — its Heartbeat connection keeps running.
]]

local SpeedBypass = {}

function SpeedBypass.create(deps)
    local Config = deps.Config
    local RunService = deps.RunService
    local Workspace = deps.Workspace
    local LocalPlayer = deps.LocalPlayer
    local ReplicatedStorage = deps.ReplicatedStorage
    local Movement = deps.Movement

    local runtime = Config.Runtime

    local heartbeatConnection = nil
    local characterConnection = nil
    local attributeConnection = nil
    local childConnection = nil
    local maintenanceThread = nil
    local walkSpeedConnection = nil
    local active = false
    local serverActionMode = false
    local hookedFunctions = {}
    local disabledConnections = {}
    local metaHookInstalled = false
    local oldNamecall = nil
    local remotesModule = nil

    local NEUTER_NAMES = {
        check = true,
        lagback = true,
        punish = true,
        kill = true,
    }

    local ANTI_TP_MARKERS = {
        "ObbyAntiTP",
        "ObbyAntiTp",
    }

    local function getCharacter()
        return LocalPlayer.Character
    end

    local function getRootPart()
        local character = getCharacter()
        return character and character:FindFirstChild("HumanoidRootPart")
    end

    local function getHumanoid()
        local character = getCharacter()
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function sourceMatchesAntiTp(source)
        if type(source) ~= "string" then
            return false
        end

        for _, marker in ipairs(ANTI_TP_MARKERS) do
            if source:find(marker, 1, true) then
                return true
            end
        end

        return false
    end

    local function destroyAntiTpScripts(root)
        if not root then
            return
        end

        for _, instance in ipairs(root:GetDescendants()) do
            if instance.Name == "ObbyAntiTPClient" and instance:IsA("LocalScript") then
                instance.Disabled = true
                instance:Destroy()
            end
        end
    end

    local function forceAntiTpOff()
        pcall(function()
            Workspace:SetAttribute("ClientObbyAntiTp", false)
        end)
    end

    local function shouldBlockLagbackPivot(targetInstance)
        if not active then
            return false
        end

        local character = getCharacter()

        if not character or not targetInstance then
            return false
        end

        if targetInstance ~= character then
            local rootPart = getRootPart()
            if targetInstance ~= rootPart then
                return false
            end
        end

        if serverActionMode then
            return false
        end

        if Movement and Movement.IsServerActionMode and Movement.IsServerActionMode() then
            return false
        end

        if Movement and Movement.IsTweening and Movement.IsTweening() then
            return true
        end

        if Movement and Movement.IsTweenMode and Movement.IsTweenMode() then
            return true
        end

        if Movement and Movement.IsBypassPrepared and Movement.IsBypassPrepared() then
            return true
        end

        return runtime.speedBypassBlockPivotAlways == true
    end

    local function installNamecallHook()
        if metaHookInstalled or typeof(getrawmetatable) ~= "function" then
            return
        end

        local ok, mt = pcall(getrawmetatable, game)

        if not ok or not mt or typeof(mt.__namecall) ~= "function" then
            return
        end

        oldNamecall = mt.__namecall

        pcall(function()
            setreadonly(mt, false)
        end)

        mt.__namecall = function(self, ...)
            local method = getnamecallmethod()

            if method == "PivotTo" and shouldBlockLagbackPivot(self) then
                return self
            end

            return oldNamecall(self, ...)
        end

        pcall(function()
            setreadonly(mt, true)
        end)

        metaHookInstalled = true
    end

    local function restoreNamecallHook()
        if not metaHookInstalled or not oldNamecall then
            return
        end

        local ok, mt = pcall(getrawmetatable, game)

        if ok and mt then
            pcall(function()
                setreadonly(mt, false)
            end)

            mt.__namecall = oldNamecall

            pcall(function()
                setreadonly(mt, true)
            end)
        end

        metaHookInstalled = false
        oldNamecall = nil
    end

    local function neuterAntiTpFunctions()
        if typeof(getgc) ~= "function" or typeof(hookfunction) ~= "function" then
            return
        end

        pcall(function()
            for _, fn in ipairs(getgc(true)) do
                if type(fn) == "function" and not hookedFunctions[fn] then
                    local okName, fnName = pcall(debug.info, fn, "n")
                    local okSource, fnSource = pcall(debug.info, fn, "s")

                    if okName and NEUTER_NAMES[fnName] and okSource and sourceMatchesAntiTp(fnSource) then
                        hookedFunctions[fn] = hookfunction(fn, function()
                            return nil
                        end)
                    end
                end
            end
        end)
    end

    local function disableTrackedConnection(connection)
        if not connection or disabledConnections[connection] then
            return
        end

        pcall(function()
            connection:Disable()
        end)

        disabledConnections[connection] = true
    end

    local function disconnectAntiTpSignals()
        if typeof(getconnections) ~= "function" then
            return
        end

        pcall(function()
            for _, connection in ipairs(getconnections(RunService.Heartbeat)) do
                local fn = connection.Function

                if fn then
                    local okSource, fnSource = pcall(debug.info, fn, "s")

                    if okSource and sourceMatchesAntiTp(fnSource) then
                        disableTrackedConnection(connection)
                    end
                end
            end
        end)

        pcall(function()
            for _, connection in ipairs(getconnections(RunService.Stepped)) do
                local fn = connection.Function

                if fn then
                    local okSource, fnSource = pcall(debug.info, fn, "s")

                    if okSource and sourceMatchesAntiTp(fnSource) then
                        disableTrackedConnection(connection)
                    end
                end
            end
        end)

        pcall(function()
            if not remotesModule then
                remotesModule = require(ReplicatedStorage.Shared.Remotes)
            end

            local refresh = remotesModule.RigSync and remotesModule.RigSync.Refresh

            if refresh and refresh.OnClientEvent then
                for _, connection in ipairs(getconnections(refresh.OnClientEvent)) do
                    local fn = connection.Function

                    if fn then
                        local okSource, fnSource = pcall(debug.info, fn, "s")

                        if okSource and sourceMatchesAntiTp(fnSource) then
                            disableTrackedConnection(connection)
                        end
                    end
                end
            end
        end)
    end

    local function reapplyAntiTpBypass()
        if not active then
            return
        end

        forceAntiTpOff()
        installNamecallHook()
        neuterAntiTpFunctions()
        disconnectAntiTpSignals()
        destroyAntiTpScripts(LocalPlayer:FindFirstChild("PlayerScripts"))
        destroyAntiTpScripts(getCharacter())
    end

    local lastApplyAt = 0

    local function applySpeed()
        if serverActionMode then
            return
        end

        if Movement and Movement.IsServerActionMode and Movement.IsServerActionMode() then
            return
        end

        if Movement and Movement.IsTweening and Movement.IsTweening() then
            return
        end

        if Movement and Movement.IsTweenMode and Movement.IsTweenMode() then
            return
        end

        local now = os.clock()
        local applyInterval = runtime.speedBypassApplyInterval or 0.25

        if now - lastApplyAt < applyInterval then
            return
        end

        lastApplyAt = now

        local humanoid = getHumanoid()

        if not humanoid or humanoid.Health <= 0 then
            return
        end

        local speed = runtime.autoFarmWalkSpeed or 300

        if humanoid.WalkSpeed + 0.01 < speed then
            humanoid.WalkSpeed = speed
        end

        humanoid.AutoRotate = true
        humanoid.PlatformStand = false
    end

    local function bindHumanoid(humanoid)
        if walkSpeedConnection then
            walkSpeedConnection:Disconnect()
            walkSpeedConnection = nil
        end

        if not humanoid then
            return
        end

        walkSpeedConnection = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if active and Movement and Movement.IsTweening and Movement.IsTweening() then
                if humanoid.Parent and humanoid.WalkSpeed ~= 0 then
                    humanoid.WalkSpeed = 0
                end

                return
            end

            if active and Movement and Movement.IsTweenMode and Movement.IsTweenMode() then
                if humanoid.Parent and humanoid.WalkSpeed ~= 0 then
                    humanoid.WalkSpeed = 0
                end

                return
            end

            if active then
                applySpeed()
            end
        end)
    end

    local function onCharacter(character)
        destroyAntiTpScripts(character)
        bindHumanoid(character:FindFirstChildOfClass("Humanoid"))
        task.defer(reapplyAntiTpBypass)
    end

    local function enable()
        if active then
            reapplyAntiTpBypass()
            return
        end

        active = true
        reapplyAntiTpBypass()

        if not attributeConnection then
            attributeConnection = Workspace:GetAttributeChangedSignal("ClientObbyAntiTp"):Connect(function()
                if active then
                    forceAntiTpOff()
                end
            end)
        end

        if not childConnection then
            childConnection = LocalPlayer.PlayerScripts.DescendantAdded:Connect(function(instance)
                if active and instance.Name == "ObbyAntiTPClient" and instance:IsA("LocalScript") then
                    instance.Disabled = true
                    instance:Destroy()
                    task.defer(reapplyAntiTpBypass)
                end
            end)
        end

        if not characterConnection then
            characterConnection = LocalPlayer.CharacterAdded:Connect(onCharacter)
        end

        if LocalPlayer.Character then
            onCharacter(LocalPlayer.Character)
        end

        if not heartbeatConnection then
            heartbeatConnection = RunService.Heartbeat:Connect(applySpeed)
        end

        if not maintenanceThread then
            maintenanceThread = task.spawn(function()
                local maintenanceInterval = runtime.speedBypassMaintenanceInterval or 3

                while active do
                    reapplyAntiTpBypass()
                    task.wait(maintenanceInterval)
                end
            end)
        end

        applySpeed()
    end

    local function disable()
        active = false

        if heartbeatConnection then
            heartbeatConnection:Disconnect()
            heartbeatConnection = nil
        end

        maintenanceThread = nil
        restoreNamecallHook()
    end

    local function destroy()
        disable()

        if walkSpeedConnection then
            walkSpeedConnection:Disconnect()
            walkSpeedConnection = nil
        end

        if characterConnection then
            characterConnection:Disconnect()
            characterConnection = nil
        end

        if attributeConnection then
            attributeConnection:Disconnect()
            attributeConnection = nil
        end

        if childConnection then
            childConnection:Disconnect()
            childConnection = nil
        end

        hookedFunctions = {}
        disabledConnections = {}
    end

    return {
        Enable = enable,
        Disable = disable,
        Destroy = destroy,
        ApplySpeed = applySpeed,
        Reapply = reapplyAntiTpBypass,
        SetServerActionMode = function(enabled)
            local want = enabled == true

            if want == serverActionMode then
                return
            end

            serverActionMode = want

            if Movement and Movement.SetServerActionMode then
                Movement.SetServerActionMode(enabled)
            end
        end,
        IsEnabled = function()
            return active
        end,
    }
end

return SpeedBypass
