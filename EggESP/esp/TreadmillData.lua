--[[
    Local player treadmill data: resolve model, position, upgrade info.
]]

local TreadmillData = {}

function TreadmillData.create(deps)
    local Config = deps.Config
    local Util = deps.Util
    local Workspace = deps.Workspace
    local LocalPlayer = deps.LocalPlayer
    local PlotState = deps.PlotState
    local Save = deps.Save
    local Treadmills = deps.Treadmills
    local TreadmillUtil = deps.TreadmillUtil

    local runtime = Config.Runtime
    local theme = Config.Theme

    local function resolveModel(slot)
        local renderFolder = Workspace:FindFirstChild("__ClientTreadmillRenders")

        if renderFolder then
            local renderModel = renderFolder:FindFirstChild("TreadmillRender_" .. tostring(slot))

            if renderModel and renderModel:IsA("Model") then
                return renderModel
            end
        end

        return nil
    end

    local function resolveBottomPart(slot)
        local plot = PlotState.ResolvePlot()

        if plot and plot.PlotFolder then
            local bottom = plot.PlotFolder:FindFirstChild("TreadmillBottom")

            if bottom and bottom:IsA("BasePart") then
                return bottom
            end
        end

        local plots = Workspace:FindFirstChild("Plots")
        local plotModel = plots and plots:FindFirstChild(tostring(slot))

        if plotModel then
            local bottom = plotModel:FindFirstChild("TreadmillBottom")

            if bottom and bottom:IsA("BasePart") then
                return bottom
            end
        end

        return nil
    end

    local function resolveBounds(slot, model)
        local padding = Config.Layout.treadmillBoundsPadding
        local bottom = resolveBottomPart(slot)
        local groundY = bottom and (bottom.Position.Y - bottom.Size.Y * 0.5) or nil

        if model then
            local modelCf, modelSize = model:GetBoundingBox()
            local modelHalf = modelSize * 0.5
            local minX = modelCf.Position.X - modelHalf.X
            local minY = modelCf.Position.Y - modelHalf.Y
            local minZ = modelCf.Position.Z - modelHalf.Z
            local maxX = modelCf.Position.X + modelHalf.X
            local maxY = modelCf.Position.Y + modelHalf.Y
            local maxZ = modelCf.Position.Z + modelHalf.Z

            if bottom then
                local bMinX, bMinY, bMinZ, bMaxX, bMaxY, bMaxZ = Util.getPartWorldAABB(bottom)
                minX, minY, minZ, maxX, maxY, maxZ = Util.mergeAABB(
                    minX, minY, minZ, maxX, maxY, maxZ,
                    bMinX, bMinY, bMinZ, bMaxX, bMaxY, bMaxZ
                )
            end

            return Util.groundBoundsFromAABB(minX, minY, minZ, maxX, maxY, maxZ, padding, groundY)
        end

        if bottom then
            return Util.groundBoundsFromPart(bottom, padding, groundY)
        end

        return nil, nil
    end

    local function resolveWorldPosition(slot, model)
        local offset = Vector3.new(0, runtime.treadmillYOffset, 0)

        if model then
            local root = model:FindFirstChild("Root")

            if root and root:IsA("BasePart") then
                return root.Position + offset
            end

            if model.PrimaryPart then
                return model.PrimaryPart.Position + offset
            end

            return model:GetPivot().Position + offset
        end

        local plot = PlotState.ResolvePlot()

        if plot and plot.PlotFolder then
            local bottom = plot.PlotFolder:FindFirstChild("TreadmillBottom")

            if bottom and bottom:IsA("BasePart") then
                return bottom.Position + offset
            end
        end

        local plots = Workspace:FindFirstChild("Plots")
        local plotModel = plots and plots:FindFirstChild(tostring(slot))

        if plotModel then
            local bottom = plotModel:FindFirstChild("TreadmillBottom")

            if bottom and bottom:IsA("BasePart") then
                return bottom.Position + offset
            end
        end

        return nil
    end

    local function getInfo(level)
        local config = Treadmills.GetByUpgradeLevel(level)

        if not config then
            return {
                name = "Treadmill",
                rarityName = "Unknown",
                rarityColor = theme.textMuted,
                rarityValue = "Lv " .. tostring(level),
                rarityNumber = 0,
            }
        end

        local rarity = config.Rarity
        local speedLabel = TreadmillUtil.FormatSpeedMultiplierValue
            and TreadmillUtil.FormatSpeedMultiplierValue(config.SpeedMultiplier)
            or ("x" .. tostring(config.SpeedMultiplier))

        return {
            name = config.DisplayName,
            rarityName = rarity.DisplayName,
            rarityColor = rarity.Color,
            rarityValue = string.format("Lv %d  |  %s", level, speedLabel),
            rarityNumber = rarity.RarityNumber or 0,
        }
    end

    local function collect()
        if not runtime.showTreadmill then
            return nil
        end

        local slot = PlotState.ResolveLocalSlot()

        if slot == nil then
            return nil
        end

        local model = resolveModel(slot)
        local worldPos = resolveWorldPosition(slot, model)

        if worldPos == nil then
            return nil
        end

        local saveData = Save.Get(LocalPlayer)
        local level = 1

        if saveData and typeof(saveData.TreadmillUpgradeLevel) == "number" then
            level = saveData.TreadmillUpgradeLevel
        end

        local character = LocalPlayer.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local distance = rootPart and (worldPos - rootPart.Position).Magnitude or 0

        if distance > runtime.maxDistance then
            return nil
        end

        local boundsCenter, boundsHalfSize = resolveBounds(slot, model)

        return {
            uid = "local_treadmill",
            kind = "treadmill",
            slot = slot,
            model = model,
            worldPos = worldPos,
            boundsCenter = boundsCenter,
            boundsHalfSize = boundsHalfSize,
            info = getInfo(level),
            distance = distance,
            rarityNumber = 9999,
        }
    end

    return {
        Collect = collect,
    }
end

return TreadmillData
