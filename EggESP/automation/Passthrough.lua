--[[
    Disable collision on configured world objects so auto farm can walk through them.
]]

local Passthrough = {}

function Passthrough.create(deps)
    local Workspace = deps.Workspace

    local ROOT_PATHS = {
        "Stands.Models.GearShopStand",
        "__OBJECTS.Machines.FuseMachine.Model.Base",
    }

    local saved = {}
    local active = false

    local function resolvePath(path)
        local current = Workspace

        for segment in string.gmatch(path, "[^%.]+") do
            current = current and current:FindFirstChild(segment)

            if not current then
                return nil
            end
        end

        return current
    end

    local function rememberPart(part)
        if saved[part] then
            return
        end

        saved[part] = {
            CanCollide = part.CanCollide,
            CanTouch = part.CanTouch,
            CanQuery = part.CanQuery,
        }
    end

    local function disablePart(part)
        rememberPart(part)
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
    end

    local function applyToInstance(instance)
        if instance:IsA("BasePart") then
            disablePart(instance)
        end

        for _, descendant in ipairs(instance:GetDescendants()) do
            if descendant:IsA("BasePart") then
                disablePart(descendant)
            end
        end
    end

    local function restorePart(part, props)
        if part.Parent and props then
            part.CanCollide = props.CanCollide
            part.CanTouch = props.CanTouch
            part.CanQuery = props.CanQuery
        end
    end

    local function enable()
        if active then
            return
        end

        active = true

        for _, path in ipairs(ROOT_PATHS) do
            local instance = resolvePath(path)

            if instance then
                applyToInstance(instance)
            else
                warn("[EggESP] Passthrough target not found: " .. path)
            end
        end
    end

    local function disable()
        if not active then
            return
        end

        for part, props in pairs(saved) do
            restorePart(part, props)
        end

        table.clear(saved)
        active = false
    end

    return {
        Enable = enable,
        Disable = disable,
        IsActive = function()
            return active
        end,
    }
end

return Passthrough
