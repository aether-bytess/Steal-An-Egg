--[[
    Steal An Egg — single loadstring chunk (VoidUI needs Plugin capability).
    loadstring(readfile("Steal-An-Egg/run.lua"))()
]]

local HUB_PATH = "Steal-An-Egg/hub_loader.lua"
local BUILD_PATH = "Steal-An-Egg/EggESP/ui/void_build.lua"

local altHub = "hub_loader.lua"
local altBuild = "EggESP/ui/void_build.lua"

local function readFirst(paths, label)
    for _, path in ipairs(paths) do
        local ok, source = pcall(readfile, path)

        if ok and typeof(source) == "string" and #source > 0 then
            return source, path
        end
    end

    error("[Hub] run.lua: " .. tostring(label) .. " not found", 0)
end

local function normalizeVoidBuildSource(source)
    local transformed, count = source:gsub(
        "return%s+function%s*%(ctx%)",
        "local function __EGGESP_VOID_BUILD(ctx)",
        1
    )

    if count > 0 then
        return transformed
    end

    error("[Hub] run.lua: void_build.lua must start with return function(ctx)", 0)
end

local hubSource = readFirst({ HUB_PATH, altHub }, "hub_loader.lua")
local buildSource = readFirst({ BUILD_PATH, altBuild }, "void_build.lua")
buildSource = normalizeVoidBuildSource(buildSource)

local combined = hubSource .. "\n" .. buildSource .. "\n"
local chunk, err = loadstring(combined, "@StealAnEggHub")

if not chunk then
    error("[Hub] run.lua compile failed: " .. tostring(err), 0)
end

return chunk()
