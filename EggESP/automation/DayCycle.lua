--[[
    Day/night egg reset cycle — block field farming during night reset.
]]

local DayCycle = {}

function DayCycle.create(deps)
    local Workspace = deps.Workspace
    local AreaEggCycle = deps.AreaEggCycle
    local AreaEggResetCycle = deps.AreaEggResetCycle
    local AreaEggResetWall = deps.AreaEggResetWall

    local function serverTime()
        return Workspace:GetServerTimeNow()
    end

    local function getPhase()
        if Workspace:GetAttribute("Event_AdminAbuse") == true then
            return "Day"
        end

        local now = serverTime()

        if AreaEggCycle.IsNightPhase(now) then
            return "Night"
        end

        if AreaEggCycle.IsWithinNightTransition(
            now,
            AreaEggResetCycle.NightLightingTransitionSeconds,
            AreaEggResetCycle.NightLightingStartDelaySeconds
        ) then
            return "NightTransition"
        end

        return "Day"
    end

    local function isEggAreaBlocked()
        if AreaEggResetWall.IsSealed() then
            return true, "wall sealed"
        end

        local phase = getPhase()

        if phase == "Night" then
            return true, "night reset"
        end

        if phase == "NightTransition" then
            return true, "night approaching"
        end

        return false, nil
    end

    local function secondsUntilDay()
        local now = serverTime()

        if not AreaEggCycle.IsNightPhase(now) then
            return 0
        end

        return math.ceil(AreaEggCycle.SecondsUntilReset(now))
    end

    local function getStatus()
        local blocked, reason = isEggAreaBlocked()
        local phase = getPhase()
        local untilDay = secondsUntilDay()

        return {
            phase = phase,
            blocked = blocked,
            reason = reason,
            secondsUntilDay = untilDay,
        }
    end

    return {
        GetPhase = getPhase,
        IsEggAreaBlocked = isEggAreaBlocked,
        SecondsUntilDay = secondsUntilDay,
        GetStatus = getStatus,
    }
end

return DayCycle
