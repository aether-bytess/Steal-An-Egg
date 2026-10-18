--[[
    Drawing pool for 3D bounding box edges (12 lines per box).
]]

local BoundingBoxPool = {}

local EDGE_COUNT = 12

function BoundingBoxPool.create(deps)
    local Config = deps.Config
    local Util = deps.Util

    local layout = Config.Layout
    local pool = {}

    local function createEntry()
        local lines = {}

        for i = 1, EDGE_COUNT do
            lines[i] = Util.createDrawing("Line", {
                Thickness = layout.treadmillBoundsThickness,
                Visible = false,
            })
        end

        return lines
    end

    local function hideEntry(lines)
        for i = 1, EDGE_COUNT do
            lines[i].Visible = false
        end
    end

    local function acquire(index)
        if not pool[index] then
            pool[index] = createEntry()
        end

        return pool[index]
    end

    local function hideFrom(index)
        for i = index, #pool do
            hideEntry(pool[i])
        end
    end

    local function hideAll()
        for _, lines in ipairs(pool) do
            hideEntry(lines)
        end
    end

    local function destroyAll()
        for _, lines in ipairs(pool) do
            for i = 1, EDGE_COUNT do
                lines[i]:Remove()
            end
        end

        table.clear(pool)
    end

    return {
        Acquire = acquire,
        HideFrom = hideFrom,
        HideAll = hideAll,
        DestroyAll = destroyAll,
    }
end

return BoundingBoxPool
