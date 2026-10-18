--[[
    Drawing object pool: create, reuse, and hide ESP draw instances.
]]

local DrawingPool = {}

function DrawingPool.create(deps)
    local Config = deps.Config
    local Util = deps.Util

    local theme = Config.Theme
    local layout = Config.Layout
    local drawing = Config.Drawing

    local pool = {}

    local function createEntry()
        local font = drawing.font
        local outline = theme.shadow
        local radius = layout.dotRadius

        return {
            dot = Util.createDrawing("Circle", {
                Radius = radius,
                Filled = true,
                Thickness = 1,
                NumSides = 16,
                Visible = false,
            }),
            dotRing = Util.createDrawing("Circle", {
                Radius = radius + 2,
                Filled = false,
                Thickness = 1,
                NumSides = 16,
                Visible = false,
            }),
            connector = Util.createDrawing("Line", {
                Thickness = layout.connectorThickness,
                Visible = false,
            }),
            shadow = Util.createDrawing("Square", {
                Filled = true,
                Visible = false,
            }),
            box = Util.createDrawing("Square", {
                Filled = true,
                Visible = false,
            }),
            boxInner = Util.createDrawing("Square", {
                Filled = true,
                Visible = false,
            }),
            boxBorder = Util.createDrawing("Square", {
                Filled = false,
                Thickness = layout.borderThickness,
                Visible = false,
            }),
            accent = Util.createDrawing("Square", {
                Filled = true,
                Visible = false,
            }),
            accentTop = Util.createDrawing("Line", {
                Thickness = 2,
                Visible = false,
            }),
            textName = Util.createDrawing("Text", {
                Size = drawing.textNameSize,
                Center = false,
                Outline = true,
                OutlineColor = outline,
                Font = font,
                Visible = false,
            }),
            textRarity = Util.createDrawing("Text", {
                Size = drawing.textRaritySize,
                Center = false,
                Outline = true,
                OutlineColor = outline,
                Font = font,
                Visible = false,
            }),
            textDistance = Util.createDrawing("Text", {
                Size = drawing.textDistanceSize,
                Center = false,
                Outline = true,
                OutlineColor = outline,
                Font = font,
                Visible = false,
            }),
        }
    end

    local function hideEntry(entry)
        for _, key in ipairs(drawing.keys) do
            local obj = entry[key]

            if obj then
                obj.Visible = false
            end
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
        for _, entry in ipairs(pool) do
            hideEntry(entry)
        end
    end

    local function destroyAll()
        for _, entry in ipairs(pool) do
            for _, key in ipairs(drawing.keys) do
                local obj = entry[key]

                if obj then
                    obj:Remove()
                end
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

return DrawingPool
