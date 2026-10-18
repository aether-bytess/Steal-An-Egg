--[[
    Steal An Egg - Entry Point
    Execute: loadfile("Steal-An-Egg/hub_loader.lua")()
    Or:      loadstring(readfile("Steal-An-Egg/EggESP.lua"), "EggESP")()
]]

local INIT_CANDIDATES = {
    "Steal-An-Egg/EggESP/init.lua",
    "EggESP/init.lua",
}

local function loadInit()
    local lastErr

    for _, path in ipairs(INIT_CANDIDATES) do
        local chunk, err

        if type(readfile) == "function" and type(loadstring) == "function" then
            local readOk, source = pcall(readfile, path)

            if readOk and typeof(source) == "string" and #source > 0 then
                chunk, err = loadstring(source, "@" .. path)
            end
        end

        if not chunk then
            chunk, err = loadfile(path)
        end

        if chunk then
            local ok, result = pcall(chunk)

            if not ok then
                error("[EggESP] init crashed: " .. tostring(result), 0)
            end

            if result == nil then
                error("[EggESP] init returned nil (" .. path .. ")", 0)
            end

            return result
        end

        lastErr = err
    end

    error(
        "[EggESP] init.lua not found.\nTried:\n  - Steal-An-Egg/EggESP/init.lua\n  - EggESP/init.lua\n\n"
            .. tostring(lastErr),
        0
    )
end

local API = loadInit()

-- hub_loader calls BuildNow(VoidUI) then Start() — do not auto-start here.
return API
