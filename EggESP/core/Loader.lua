--[[
    Module loader for Potassium workspace scripts.
]]

local Loader = {}

Loader.ROOT_CANDIDATES = {
    "Steal-An-Egg/EggESP",
    "EggESP",
}

function Loader.resolveRoot()
    for _, root in ipairs(Loader.ROOT_CANDIDATES) do
        local chunk = loadfile(root .. "/core/Config.lua")

        if chunk then
            return root
        end
    end

    error(
        "[EggESP] Module root not found. Tried:\n  - "
            .. table.concat(Loader.ROOT_CANDIDATES, "\n  - "),
        2
    )
end

function Loader.run(path)
    if type(readfile) == "function" and type(loadstring) == "function" then
        local readOk, source = pcall(readfile, path)

        if readOk and typeof(source) == "string" and #source > 0 then
            local chunk, err = loadstring(source, "@" .. path)

            if chunk then
                return chunk()
            end

            error("[EggESP] loadstring failed: " .. path .. "\n" .. tostring(err), 2)
        end
    end

    local chunk, err = loadfile(path)

    if not chunk then
        error("[EggESP] loadfile failed: " .. path .. "\n" .. tostring(err), 2)
    end

    return chunk()
end

function Loader.create(root)
    return function(relativePath)
        return Loader.run(root .. "/" .. relativePath .. ".lua")
    end
end

return Loader
