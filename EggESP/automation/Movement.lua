--[[
    Tween movement matching ObbyAntiTP bypass pattern:
    clone Humanoid -> WalkSpeed 0 -> tween PrimaryPart -> restore WalkSpeed on complete.
]]

local Movement = {}

function Movement.create(deps)
    local Config = deps.Config
    local LocalPlayer = deps.LocalPlayer
    local GuardZone = deps.GuardZone
    local TweenService = game:GetService("TweenService")

    local runtime = Config.Runtime

    local cache = nil
    local clonedCharacter = nil
    local bypassPrepared = false
    local activeTween = nil
    local activeTarget = nil
    local onCompleteCallback = nil
    local walkTarget = nil
    local walkCompleteCallback = nil
    local walkConnection = nil
    local walkStartedAt = 0
    local walkLastPos = nil
    local serverActionMode = false
    local onBypassPrepared = nil

    local function getCharacter()
        return LocalPlayer.Character
    end

    local function getRootPart()
        local character = getCharacter()
        return character and (character.PrimaryPart or character:FindFirstChild("HumanoidRootPart"))
    end

    local function getHumanoid()
        local character = getCharacter()
        return character and character:FindFirstChildOfClass("Humanoid")
    end

    local function horizontalDistance(a, b)
        return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
    end

    local function isNear(position, target, radius)
        return horizontalDistance(position, target) <= radius
    end

    local function flatXZ(target, rootPart)
        local y = rootPart and rootPart.Position.Y or target.Y

        return Vector3.new(target.X, y, target.Z)
    end

    local function ensureCache(character, humanoid)
        if not cache or cache.Character ~= character then
            cache = { Character = character }

            for _, property in ipairs({ "WalkSpeed", "JumpPower", "JumpHeight", "AutoRotate", "PlatformStand" }) do
                cache[property] = humanoid[property]
            end
        end
    end

    local function savedWalkSpeed()
        return cache and cache.WalkSpeed or 16
    end

    local function restoreHumanoidWalkSpeed()
        local character = getCharacter()
        local humanoid = getHumanoid()

        if not humanoid then
            return
        end

        ensureCache(character, humanoid)
        humanoid.WalkSpeed = savedWalkSpeed()
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end

    local function clearStaleWalk()
        walkTarget = nil
        walkCompleteCallback = nil
        walkStartedAt = 0
        walkLastPos = nil
        clearWalkConnection()
        restoreHumanoidWalkSpeed()
    end

    local function zeroRootVelocity()
        local rootPart = getRootPart()

        if rootPart then
            rootPart.AssemblyLinearVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local function shouldCloneHumanoid()
        return runtime.movementHumanoidClone ~= false
    end

    local function prepareTweenHumanoid(character, oldHumanoid)
        ensureCache(character, oldHumanoid)

        if not shouldCloneHumanoid() then
            oldHumanoid.WalkSpeed = 0
            return oldHumanoid
        end

        if clonedCharacter == character and oldHumanoid and oldHumanoid.Parent == character then
            oldHumanoid.WalkSpeed = 0
            return oldHumanoid
        end

        oldHumanoid.Archivable = true
        local humanoid = oldHumanoid:Clone()

        humanoid.BreakJointsOnDeath = false
        oldHumanoid:Destroy()
        humanoid.Parent = character
        humanoid.WalkSpeed = 0

        if not humanoid:FindFirstChildOfClass("Animator") then
            Instance.new("Animator", humanoid)
        end

        clonedCharacter = character
        bypassPrepared = true

        if onBypassPrepared then
            pcall(onBypassPrepared)
        end

        return humanoid
    end

    local function stopActiveTween(silent)
        if activeTween then
            activeTween:Cancel()
            activeTween = nil
        end

        activeTarget = nil
        zeroRootVelocity()
        restoreHumanoidWalkSpeed()

        local callback = onCompleteCallback
        onCompleteCallback = nil

        if callback and not silent then
            callback(false)
        end
    end

    local function clearWalkConnection()
        if walkConnection then
            walkConnection:Disconnect()
            walkConnection = nil
        end
    end

    local function cancelWalk()
        walkTarget = nil
        walkCompleteCallback = nil
        walkStartedAt = 0
        walkLastPos = nil
        clearWalkConnection()

        local humanoid = getHumanoid()
        local rootPart = getRootPart()

        if humanoid and rootPart then
            humanoid:MoveTo(rootPart.Position)
        end

        restoreHumanoidWalkSpeed()
    end

    local function prepareForServerAction()
        stopActiveTween(true)
        cancelWalk()
        zeroRootVelocity()

        local humanoid = getHumanoid()

        if humanoid then
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
        end
    end

    local function setServerActionMode(enabled)
        local want = enabled == true

        if want == serverActionMode then
            return
        end

        serverActionMode = want

        if serverActionMode then
            prepareForServerAction()
        end
    end

    local function isServerActionMode()
        return serverActionMode
    end

    local function prepareBypass()
        return getRootPart() ~= nil
    end

    local function walkTo(target, speed, onComplete)
        stopActiveTween(true)

        local character = getCharacter()
        local humanoid = getHumanoid()
        local rootPart = getRootPart()

        if not character or not humanoid or not rootPart then
            if onComplete then
                onComplete(false)
            end

            return false
        end

        ensureCache(character, humanoid)
        zeroRootVelocity()

        local flatTarget = flatXZ(target, rootPart)
        local arriveRadius = runtime.pathWaypointRadius or 5

        if isNear(rootPart.Position, flatTarget, arriveRadius) then
            walkTarget = nil
            walkCompleteCallback = nil
            clearWalkConnection()

            if onComplete then
                onComplete(true)
            end

            return true
        end

        if walkTarget and horizontalDistance(walkTarget, flatTarget) < 2 then
            walkCompleteCallback = onComplete
            return true
        end

        clearWalkConnection()

        humanoid.WalkSpeed = speed or runtime.pickupSyncWalkSpeed or 24
        humanoid.AutoRotate = true
        humanoid.PlatformStand = false
        humanoid:MoveTo(flatTarget)
        walkTarget = flatTarget
        walkCompleteCallback = onComplete
        walkStartedAt = os.clock()
        walkLastPos = rootPart.Position

        walkConnection = humanoid.MoveToFinished:Connect(function(reached)
            if not walkTarget or horizontalDistance(walkTarget, flatTarget) >= 2 then
                return
            end

            clearWalkConnection()

            local callback = walkCompleteCallback
            walkTarget = nil
            walkCompleteCallback = nil

            if callback then
                callback(reached)
            end
        end)

        return true
    end

    local function isWalking()
        return walkTarget ~= nil
    end

    local function isWalkNear(target, radius)
        local rootPart = getRootPart()

        if not rootPart or not target then
            return false
        end

        return horizontalDistance(rootPart.Position, target) <= (radius or 2)
    end

    local function cancelTween(silent)
        stopActiveTween(silent)
    end

    local function cancelMovement()
        stopActiveTween(true)
        cancelWalk()
    end

    local function buildTargetCFrame(rootPart, target)
        local flatTarget = flatXZ(target, rootPart)
        local delta = Vector3.new(flatTarget.X - rootPart.Position.X, 0, flatTarget.Z - rootPart.Position.Z)

        if delta.Magnitude > 0.05 then
            return CFrame.new(flatTarget, flatTarget + delta)
        end

        return CFrame.new(flatTarget) * rootPart.CFrame.Rotation
    end

    local function isTweeningTo(target)
        if activeTween == nil or activeTarget == nil then
            return false
        end

        local ok, playbackState = pcall(function()
            return activeTween.PlaybackState
        end)

        if ok and playbackState ~= Enum.PlaybackState.Playing then
            activeTween = nil
            activeTarget = nil
            restoreHumanoidWalkSpeed()
            return false
        end

        return horizontalDistance(activeTarget, target) < 2
    end

    local function updateWalkStale(rootPart, flatTarget)
        if not walkTarget then
            return false
        end

        if isNear(rootPart.Position, flatTarget, runtime.pathWaypointRadius or 5) then
            clearStaleWalk()
            return true
        end

        local now = os.clock()

        if walkLastPos and horizontalDistance(rootPart.Position, walkLastPos) >= 0.35 then
            walkLastPos = rootPart.Position
            walkStartedAt = now
            return false
        end

        walkLastPos = rootPart.Position

        if now - (walkStartedAt or now) >= 1.5 then
            clearStaleWalk()
            return true
        end

        return false
    end

    local function isMovingTo(target)
        local rootPart = getRootPart()

        if not rootPart or not target then
            return false
        end

        local flatTarget = flatXZ(target, rootPart)

        if isTweeningTo(flatTarget) then
            return true
        end

        if walkTarget and horizontalDistance(walkTarget, flatTarget) < 2 then
            if updateWalkStale(rootPart, flatTarget) then
                return false
            end

            if isNear(rootPart.Position, flatTarget, runtime.pathWaypointRadius or 5) then
                return false
            end

            return true
        end

        return false
    end

    local function isActivelyMovingTo(target)
        if not isMovingTo(target) then
            return false
        end

        return activeTween ~= nil or walkTarget ~= nil
    end

    local function ensureLocomotion()
        restoreHumanoidWalkSpeed()
        zeroRootVelocity()
    end

    local function tweenTo(target, speed, onComplete)
        if serverActionMode then
            walkTo(target, runtime.pickupSyncWalkSpeed or 24, onComplete)
            return nil
        end

        cancelWalk()

        local character = getCharacter() or LocalPlayer.CharacterAdded:Wait()

        if clonedCharacter and clonedCharacter ~= character then
            clonedCharacter = nil
            cache = nil
            bypassPrepared = false
        end

        local rootPart = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
        local oldHumanoid = character:FindFirstChildOfClass("Humanoid")

        if not rootPart or not oldHumanoid then
            if onComplete then
                onComplete(false)
            end

            return nil
        end

        local flatTarget = flatXZ(target, rootPart)

        if activeTween and activeTarget and horizontalDistance(activeTarget, flatTarget) < 2 then
            onCompleteCallback = onComplete
            return activeTween
        end

        if isNear(rootPart.Position, flatTarget, runtime.pathWaypointRadius or 5) then
            if onComplete then
                onComplete(true)
            end

            return nil
        end

        stopActiveTween(true)

        prepareTweenHumanoid(character, oldHumanoid)
        zeroRootVelocity()

        local targetCFrame = buildTargetCFrame(rootPart, flatTarget)
        local distance = (targetCFrame.Position - rootPart.Position).Magnitude
        local tweenSpeed = math.max(speed or runtime.tweenSpeed or 450, 300)
        local tween = TweenService:Create(
            rootPart,
            TweenInfo.new(distance / tweenSpeed, Enum.EasingStyle.Linear),
            { CFrame = targetCFrame }
        )

        activeTween = tween
        activeTarget = flatTarget
        onCompleteCallback = onComplete

        tween:Play()

        tween.Completed:Once(function(playbackState)
            if activeTween ~= tween then
                return
            end

            activeTween = nil
            activeTarget = nil

            local callback = onCompleteCallback
            onCompleteCallback = nil

            zeroRootVelocity()

            if playbackState == Enum.PlaybackState.Completed then
                rootPart.CFrame = targetCFrame
            end

            local humanoid = getHumanoid()

            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = savedWalkSpeed()
            end

            if callback then
                callback(playbackState == Enum.PlaybackState.Completed)
            end
        end)

        return tween
    end

    local function moveToward(target, onComplete)
        return tweenTo(target, runtime.tweenSpeed, onComplete)
    end

    local function isInGuardZone()
        local rootPart = getRootPart()

        if not rootPart or not GuardZone or not GuardZone.IsGuardZonePosition then
            return false
        end

        return GuardZone.IsGuardZonePosition(rootPart.Position)
    end

    local function isTweening()
        if activeTween == nil then
            return false
        end

        local ok, playbackState = pcall(function()
            return activeTween.PlaybackState
        end)

        return ok and playbackState == Enum.PlaybackState.Playing
    end

    local function isTweenMode()
        return activeTween ~= nil
    end

    local function isBypassPrepared()
        return bypassPrepared
    end

    local function reset()
        stopActiveTween(true)
        cancelWalk()
        serverActionMode = false
        bypassPrepared = false
        clonedCharacter = nil
        cache = nil
    end

    local function setBypassPreparedCallback(callback)
        onBypassPrepared = callback
    end

    return {
        GetCharacter = getCharacter,
        GetRootPart = getRootPart,
        GetHumanoid = getHumanoid,
        HorizontalDistance = horizontalDistance,
        IsNear = isNear,
        PrepareBypass = prepareBypass,
        TweenTo = tweenTo,
        MoveToward = moveToward,
        WalkTo = walkTo,
        IsWalking = isWalking,
        IsWalkNear = isWalkNear,
        PrepareForServerAction = prepareForServerAction,
        SetServerActionMode = setServerActionMode,
        IsServerActionMode = isServerActionMode,
        CancelTween = cancelTween,
        CancelWalk = cancelWalk,
        CancelMovement = cancelMovement,
        EnsureLocomotion = ensureLocomotion,
        IsTweening = isTweening,
        IsTweenMode = isTweenMode,
        IsMovingTo = isMovingTo,
        IsActivelyMovingTo = isActivelyMovingTo,
        IsInGuardZone = isInGuardZone,
        IsBypassPrepared = isBypassPrepared,
        IsTweeningTo = isTweeningTo,
        Reset = reset,
        SetBypassPreparedCallback = setBypassPreparedCallback,
    }
end

return Movement
