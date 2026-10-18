--[[
    VoidUI — voidw0rld (flat charcoal, accent only on active)
    Docs: CHANGELOG.md · VoidUI.API.md
    Usage:
      local VoidUI = loadstring(game:HttpGet(".../VoidUI.lua"))()

    API sketch:
      local W = VoidUI:CreateWindow({ Title=..., Icon=..., Accent=..., Search=true, OpenButton=true })
      Page:Section({ Title=..., Icon="rbxassetid://...", TitleSize=, IconSize=, HeaderScale= })
      CreateWindow({ SectionHeader={ TitleSize=14, IconSize=15, Scale=1 } })  -- defaults; override per game
      S:Toggle / Slider / Dropdown / Button / Input / Keybind  — row icons omitted (section header only)
      S:PriorityList({ Values=..., MaxVisible=, RowHeight=, Resizable=true, Callback=fn })
      S:Panel({ Title=, Desc=, Values={{Name,Id,Image,Right,Sub}}, Flag= }) -- progress / item rows
      W:Popup({ Title=..., Size=..., Icon=... })  -- Hidden host page; does not add a Farm subtab
      VoidUI:Notify({ Title=, Content=, Icon=, Duration= })
      Assets: "rbxassetid://N" | number | "lucide:name" anywhere Icon/Image is accepted
]]

local VoidUI = {
    Version = "1.8.5",
    _windows = {},
}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()

---------------------------------------------------------------------------
-- Theme
---------------------------------------------------------------------------
local Theme = {
    -- Neutral charcoal. Accent is brand — use only for ON / selected / fill.
    Accent = Color3.fromRGB(162, 89, 255),
    AccentDim = Color3.fromRGB(124, 58, 210),
    Bg = Color3.fromRGB(16, 16, 18),
    BgPanel = Color3.fromRGB(20, 20, 22),
    BgSidebar = Color3.fromRGB(14, 14, 16),
    BgSection = Color3.fromRGB(24, 24, 27),
    BgHover = Color3.fromRGB(36, 36, 40),
    BgInput = Color3.fromRGB(18, 18, 20),
    BgToggleOff = Color3.fromRGB(46, 46, 52),
    Stroke = Color3.fromRGB(48, 48, 54),
    Divider = Color3.fromRGB(38, 38, 42),
    Text = Color3.fromRGB(245, 245, 247),
    TextDim = Color3.fromRGB(158, 158, 166),
    TextMute = Color3.fromRGB(112, 112, 120),
    Shadow = Color3.fromRGB(0, 0, 0),
    Danger = Color3.fromRGB(255, 92, 110),
    Success = Color3.fromRGB(92, 214, 148),
    RWin = 12,
    RCard = 8,
    RCtrl = 8,
}

local Fonts = {
    Title = Enum.Font.GothamBold,
    Body = Enum.Font.GothamMedium,
    Desc = Enum.Font.Gotham,
    Mono = Enum.Font.Code,
}

-- Dropdown / PriorityList entry helpers (string or { Name, Image, Icon, Id })
local function entryKey(v)
    if type(v) == "table" then
        return tostring(v.Id or v.Name or v.Title or v.Text or v[1] or "?")
    end
    return tostring(v)
end
local function entryLabel(v)
    if type(v) == "table" then
        return tostring(v.Name or v.Title or v.Text or v.Id or "?")
    end
    return tostring(v)
end
local function entryAsset(v)
    if type(v) ~= "table" then return nil end
    local a = v.Image or v.Icon or v.Asset
    if type(a) == "number" then return "rbxassetid://" .. tostring(a) end
    return a
end
-- Accept number / "rbxassetid://…" / "lucide:…" / table with Icon|Image|Asset
local function normalizeAsset(a)
    if a == nil or a == false or a == "" then return nil end
    if type(a) == "number" then return "rbxassetid://" .. tostring(a) end
    if type(a) == "string" then return a end
    if type(a) == "table" then return entryAsset(a) end
    return nil
end
VoidUI.NormalizeAsset = normalizeAsset
local function entriesEqual(a, b)
    if a == b then return true end
    if type(a) == "table" or type(b) == "table" then
        return entryKey(a) == entryKey(b)
    end
    return tostring(a) == tostring(b)
end

local TI = TweenInfo.new
local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

---------------------------------------------------------------------------
-- Icons — Lucide / Geist / Craft (Footagesus/Icons, same as WindUI)
-- Usage: "swords" | "lucide:swords" | "geist:window" | "craft:macbook-stroke"
--        or raw "rbxassetid://..."
---------------------------------------------------------------------------
local ICON_CDN = {
    lucide = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua",
    craft = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/craft/dist/Icons.lua",
    geist = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/geist/dist/Icons.lua",
    solar = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/solar/dist/Icons.lua",
}

local IconPacks = {}
local IconAlias = {
    home = "house",
    sword = "swords",
    bag = "backpack",
    gear = "settings",
    plant = "leaf",
    cart = "shopping-cart",
    shop = "shopping-cart",
    piggy = "piggy-bank",
    money = "coins",
    keys = "key",
    robot = "bot",
    turtle = "origami",
    chevron = "chevron-down",
    close = "x",
    minimize = "minus",
    search = "search",
    warn = "triangle-alert",
    check = "check",
    info = "info",
    dice = "dices",
    expand = "maximize-2",
    target = "crosshair",
    flame = "flame",
    bolt = "zap",
    eye = "eye",
    lock = "lock",
    unlock = "lock-open",
    server = "server",
    code = "code",
    list = "list",
    grid = "layout-grid",
    user = "user",
    star = "star",
    play = "play",
    pause = "pause",
    plus = "plus",
    minus = "minus",
}

local function httpGet(url)
    local ok, body = pcall(function()
        if type(game.HttpGetAsync) == "function" then
            return game:HttpGetAsync(url)
        end
        return game:HttpGet(url)
    end)
    if ok and type(body) == "string" and #body > 50 and body:sub(1, 1) ~= "<" then
        return body
    end
    return nil
end

local function loadIconPack(pack)
    pack = string.lower(pack or "lucide")
    if IconPacks[pack] then return IconPacks[pack] end
    local url = ICON_CDN[pack]
    if not url then return nil end
    local src = httpGet(url)
    if not src then return nil end
    local fn = (loadstring or load)(src, "@Icons-" .. pack)
    if not fn then return nil end
    local ok, data = pcall(fn)
    if ok and type(data) == "table" then
        IconPacks[pack] = data
        return data
    end
    return nil
end

-- returns rbxassetid string or nil
local function resolveIcon(name)
    if not name or name == "" then return nil end
    if typeof(name) ~= "string" then
        name = tostring(name)
    end
    if name:find("rbxasset", 1, true) or name:find("http", 1, true) then
        return name
    end

    local pack, iconName = "lucide", name
    local colon = name:find(":", 1, true)
    if colon then
        pack = string.lower(name:sub(1, colon - 1))
        iconName = name:sub(colon + 1)
    else
        iconName = IconAlias[string.lower(name)] or string.lower(name)
    end

    local set = loadIconPack(pack)
    if not set then
        -- fallback lucide
        if pack ~= "lucide" then
            set = loadIconPack("lucide")
            iconName = IconAlias[string.lower(iconName)] or iconName
        end
    end
    if not set then return nil end

    local id = set[iconName] or set[IconAlias[iconName]]
    if type(id) == "string" then return id end
    if type(id) == "number" then return "rbxassetid://" .. tostring(id) end
    if type(id) == "table" and id.Image then
        local img = id.Image
        if type(img) == "number" then return "rbxassetid://" .. tostring(img) end
        return img
    end
    return nil
end

local function makeIcon(parent, iconName, size, color, z)
    size = size or 18
    local asset = resolveIcon(iconName)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.fromOffset(size, size)
    holder.Parent = parent

    local img
    if asset then
        img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = asset
        img.ImageColor3 = color or Theme.TextDim
        img.ScaleType = Enum.ScaleType.Fit
        img.Size = UDim2.fromScale(1, 1)
        img.ZIndex = z or 2
        img.Parent = holder
        holder:SetAttribute("IsIcon", true)
        return holder, img
    end
    local dot = Instance.new("Frame")
    dot.BackgroundColor3 = color or Theme.TextDim
    dot.BackgroundTransparency = 0.45
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.Position = UDim2.fromScale(0.5, 0.5)
    dot.Size = UDim2.fromOffset(math.max(4, math.floor(size * 0.28)), math.max(4, math.floor(size * 0.28)))
    dot.Parent = holder
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = dot
    return holder, nil
end

local function setIconColor(iconImg, color)
    if iconImg and iconImg:IsA("ImageLabel") then
        iconImg.ImageColor3 = color
    end
end

VoidUI.ResolveIcon = resolveIcon
VoidUI.SetIconPack = function(_, pack)
    loadIconPack(pack)
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function protect(gui)
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, gui)
    elseif protect_gui then
        pcall(protect_gui, gui)
    end
    local parent
    if gethui then
        pcall(function() parent = gethui() end)
    end
    if not parent then
        pcall(function() parent = CoreGui end)
    end
    if not parent then
        parent = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")
    end
    gui.Parent = parent
    return gui
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 12)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thick or 1
    s.Transparency = trans or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function pad(parent, t, r, b, l)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 0)
    p.PaddingRight = UDim.new(0, r or t or 0)
    p.PaddingBottom = UDim.new(0, b or t or 0)
    p.PaddingLeft = UDim.new(0, l or r or t or 0)
    p.Parent = parent
    return p
end

local function list(parent, dir, padPx, hAlign, vAlign)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, padPx or 8)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
    l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
    l.Parent = parent
    return l
end

local function mk(class, props, children)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            i[k] = v
        end
    end
    if children then
        for _, c in ipairs(children) do
            c.Parent = i
        end
    end
    if props and props.Parent then
        i.Parent = props.Parent
    end
    return i
end

-- Soft text bloom (after mk — locals aren't visible before declaration)
local function bloomLabel(opts)
    local parent = opts.Parent
    local text = opts.Text or ""
    local size = opts.TextSize or 13
    local font = opts.Font or Fonts.Title
    local color = opts.Color or Theme.Text
    local accent = opts.Accent or Theme.Accent
    local align = opts.TextXAlignment or Enum.TextXAlignment.Left
    local height = opts.Height or (size + 4)
    local bloom = opts.Bloom == true
    local layoutOrder = opts.LayoutOrder

    local wrap = mk("Frame", {
        Name = opts.Name or "BloomText",
        BackgroundTransparency = 1,
        Size = opts.Size or UDim2.new(1, 0, 0, height),
        Position = opts.Position,
        LayoutOrder = layoutOrder,
        Parent = parent,
    })

    if bloom then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Font = font,
            TextSize = size,
            TextColor3 = accent,
            TextTransparency = 0.78,
            TextXAlignment = align,
            Text = text,
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromOffset(0, 0),
            ZIndex = 1,
            Parent = wrap,
        })
    end

    local label = mk("TextLabel", {
        BackgroundTransparency = 1,
        Font = font,
        TextSize = size,
        TextColor3 = color,
        TextXAlignment = align,
        Text = text,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 2,
        Parent = wrap,
    })
    return wrap, label
end

local function hover(btn, onEnter, onLeave)
    btn.MouseEnter:Connect(onEnter)
    btn.MouseLeave:Connect(onLeave)
end

local function ripples(btn, color)
    -- light press flash
    btn.MouseButton1Down:Connect(function()
        tween(btn, TI(0.08), { BackgroundTransparency = math.min((btn.BackgroundTransparency or 0) + 0.1, 0.5) })
    end)
    btn.MouseButton1Up:Connect(function()
        tween(btn, TI(0.12), { BackgroundTransparency = btn:GetAttribute("_bt") or 0 })
    end)
end

---------------------------------------------------------------------------
-- Notifications
---------------------------------------------------------------------------
local notifHost

local function ensureNotifHost()
    if notifHost and notifHost.Parent then return notifHost end
    local sg = Instance.new("ScreenGui")
    sg.Name = "VoidUI_Notify"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 9999
    sg.IgnoreGuiInset = true
    protect(sg)
    notifHost = mk("Frame", {
        Name = "Host",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -18, 0, 18),
        Size = UDim2.fromOffset(280, 640),
        Parent = sg,
    })
    list(notifHost, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)
    return notifHost
end

-- Toast: same charcoal card as the hub. Timer is the only accent.
function VoidUI:Notify(opts)
    opts = opts or {}
    local host = ensureNotifHost()
    local duration = opts.Duration or 3.2
    local accent = opts.Accent or Theme.Accent
    local iconName = opts.Icon

    local card = mk("Frame", {
        BackgroundColor3 = Theme.Bg,
        BackgroundTransparency = 0.04,
        Size = UDim2.fromOffset(260, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        Parent = host,
    })
    corner(card, Theme.RCard or 8)
    stroke(card, Theme.Stroke, 1, 0.35)
    pad(card, 10, 12, 12, 12)

    local textLeft = 0
    if iconName then
        local ih = makeIcon(card, iconName, 14, Theme.TextDim, 3)
        ih.Position = UDim2.fromOffset(0, 1)
        textLeft = 22
    end

    local title = mk("TextLabel", {
        BackgroundTransparency = 1,
        Font = Fonts.Title,
        TextSize = 13,
        TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = opts.Title or "Notification",
        Size = UDim2.new(1, -textLeft, 0, 16),
        Position = UDim2.fromOffset(textLeft, 0),
        ZIndex = 2,
        Parent = card,
    })

    if opts.Content and opts.Content ~= "" then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Font = Fonts.Desc,
            TextSize = 11,
            TextColor3 = Theme.TextMute,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Text = opts.Content,
            Size = UDim2.new(1, -textLeft, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Position = UDim2.fromOffset(textLeft, 17),
            ZIndex = 2,
            Parent = card,
        })
    end

    local timerTrack = mk("Frame", {
        BackgroundColor3 = Theme.Divider,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, -12, 1, 11),
        Size = UDim2.new(1, 24, 0, 1),
        ZIndex = 3,
        Parent = card,
    })
    local timer = mk("Frame", {
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = timerTrack,
    })

    card.Position = UDim2.fromOffset(24, 0)
    card.BackgroundTransparency = 1
    tween(card, TI(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.06,
        Position = UDim2.fromOffset(0, 0),
    })
    tween(timer, TI(duration, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 1, 0) })

    task.delay(duration, function()
        if not card.Parent then return end
        local tw = tween(card, TI(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(18, 0),
        })
        tw.Completed:Wait()
        card:Destroy()
    end)
    return card
end

---------------------------------------------------------------------------
-- CreateWindow
---------------------------------------------------------------------------
function VoidUI:CreateWindow(cfg)
    cfg = cfg or {}
    -- drop previous windows so a failed/partial run doesn't leave a blank shell
    for i = #VoidUI._windows, 1, -1 do
        local w = VoidUI._windows[i]
        pcall(function()
            if w and w.Destroy then w:Destroy() end
        end)
        VoidUI._windows[i] = nil
    end
    -- load lucide pack once (cached) so sidebar icons aren't blank on first paint
    loadIconPack("lucide")

    local accent = cfg.Accent or Theme.Accent
    local title = cfg.Title or "VoidUI"
    local author = cfg.Author or cfg.Subtitle or ""
    local logoIcon = cfg.Icon or "rbxassetid://111627748770819"
    local size = cfg.Size or UDim2.fromOffset(720, 560)
    local toggleKey = cfg.ToggleKey or Enum.KeyCode.RightShift
    local folder = cfg.Folder -- optional config folder name

    -- deep copy theme overrides first (radius tokens live on T)
    local T = {}
    for k, v in pairs(Theme) do T[k] = v end
    T.Accent = accent
    if cfg.Theme and type(cfg.Theme) == "table" then
        for k, v in pairs(cfg.Theme) do T[k] = v end
    end

    local glass = cfg.Transparency
    if glass == nil then
        glass = (cfg.Transparent == false) and 0.02 or 0.06
    end
    glass = math.clamp(tonumber(glass) or 0.06, 0, 0.6)
    local compactOn = cfg.Compact ~= false -- hide per-row Desc (Lumen density)
    local bloomOn = cfg.Bloom == true -- off by default (glow titles = slop)
    local wantOpenBtn = cfg.OpenButton ~= false
    local wantSearch = cfg.Search ~= false
    local rWin = T.RWin or 12
    local rCard = T.RCard or 8
    local rCtrl = T.RCtrl or 8
    local cornerR = cfg.CornerRadius or rWin

    local function styleScroll(sf)
        sf.ScrollBarThickness = 2
        sf.ScrollBarImageColor3 = T.TextMute
        sf.ScrollBarImageTransparency = 0.45
        sf.BorderSizePixel = 0
    end

    local function prettySectionTitle(s)
        s = tostring(s or "")
        if s == "" or s:find("%l") then return s end
        return (s:gsub("%S+", function(w)
            if #w <= 3 then return w end
            return w:sub(1, 1) .. w:sub(2):lower()
        end))
    end

    -- Section header sizing (window default → per-Section override)
    -- Compact by default — 1.7.11's 16/20 was too loud for lucide icons.
    local secHdrCfg = type(cfg.SectionHeader) == "table" and cfg.SectionHeader or {}
    local winSecTitleSize = math.clamp(tonumber(cfg.SectionTitleSize or secHdrCfg.TitleSize) or 13, 11, 22)
    local winSecIconSize = math.clamp(tonumber(cfg.SectionIconSize or secHdrCfg.IconSize) or 14, 12, 28)
    local winSecHdrScale = math.clamp(tonumber(cfg.SectionHeaderScale or secHdrCfg.Scale) or 1, 0.75, 1.75)

    local screen = Instance.new("ScreenGui")
    screen.Name = "VoidUI_" .. tostring(math.random(1000, 9999))
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 100
    screen.IgnoreGuiInset = true
    protect(screen)

    -- Soft black drop shadow only (no purple window bloom)
    local shadow = mk("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.72,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(size.X.Scale, size.X.Offset + 28, size.Y.Scale, size.Y.Offset + 28),
        ZIndex = 0,
        Parent = screen,
    })

    -- Frame + clip (CanvasGroup blanks content on some executors)
    local main = mk("Frame", {
        Name = "Main",
        BackgroundColor3 = T.Bg,
        BackgroundTransparency = glass,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = size,
        ZIndex = 1,
        ClipsDescendants = true,
        Parent = screen,
    })
    corner(main, cornerR)
    stroke(main, T.Stroke, 1, 0.45)

    -- Sidebar
    local sidebarW = 52
    local sidebar = mk("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = T.BgSidebar,
        BackgroundTransparency = math.clamp(glass * 0.55, 0, 0.35),
        Size = UDim2.new(0, sidebarW, 1, 0),
        BorderSizePixel = 0,
        Parent = main,
    })
    mk("Frame", {
        BackgroundColor3 = T.Stroke,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 1, 1, 0),
        BackgroundTransparency = 0.35,
        Parent = sidebar,
    })

    local logo = mk("Frame", {
        Name = "Logo",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 54),
        Parent = sidebar,
    })
    local logoIsAsset = typeof(logoIcon) == "string" and (logoIcon:find("rbxasset", 1, true) or logoIcon:find("http", 1, true))
    local logoTint = Color3.new(1, 1, 1)
    local logoHolder = makeIcon(logo, logoIcon, logoIsAsset and 28 or 20, logoTint, 2)
    logoHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    logoHolder.Position = UDim2.fromScale(0.5, 0.5)

    local sideNav = mk("ScrollingFrame", {
        Name = "Nav",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 54),
        Size = UDim2.new(1, 0, 1, -54),
        ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = sidebar,
    })
    list(sideNav, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
    pad(sideNav, 2, 0, 12, 0)

    -- Content shell (transparent so main corner radius fits clean — no bottom seam)
    local content = mk("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(sidebarW, 0),
        Size = UDim2.new(1, -sidebarW, 1, 0),
        ClipsDescendants = true,
        Parent = main,
    })

    -- Top bar (title + window controls)
    local topBar = mk("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 56),
        ZIndex = 20,
        Parent = content,
    })
    pad(topBar, 0, 16, 0, 20)

    local titleHost = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(wantSearch and 0.48 or 0.62, 0, 1, 0),
        Parent = topBar,
    })
    local titleWrap = bloomLabel({
        Parent = titleHost,
        Name = "Title",
        Text = title,
        TextSize = 18,
        Font = Fonts.Title,
        Color = T.Text,
        Accent = accent,
        Bloom = bloomOn,
        Height = 24,
    })
    titleWrap.Position = UDim2.fromOffset(0, author ~= "" and 6 or 16)

    if author ~= "" then
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Font = Fonts.Desc,
            TextSize = 12,
            TextColor3 = T.TextMute,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = author,
            Position = UDim2.fromOffset(0, 32),
            Size = UDim2.new(1, 0, 0, 14),
            Parent = titleHost,
        })
    end

    -- thin hairline under header
    mk("Frame", {
        BackgroundColor3 = T.Stroke,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 20, 1, 0),
        Size = UDim2.new(1, -40, 0, 1),
        Parent = topBar,
    })

    local winBtns = mk("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -4, 0.5, 0),
        Size = UDim2.fromOffset(72, 30),
        Parent = topBar,
    })
    list(winBtns, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

    -- Search: compact icon → expands into a clean find field
    local searchBox
    local searchHost
    local searchExpanded = false
    local setSearchOpen
    local searchCountLbl
    if wantSearch then
        searchHost = mk("Frame", {
            Name = "SearchHost",
            BackgroundColor3 = T.BgInput,
            BackgroundTransparency = 0,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -88, 0.5, 0),
            Size = UDim2.fromOffset(32, 32),
            ClipsDescendants = true,
            Parent = topBar,
        })
        corner(searchHost, rCtrl)
        local searchStroke = stroke(searchHost, T.Stroke, 1, 0.4)

        local sIconHold = makeIcon(searchHost, "lucide:search", 15, T.TextMute, 3)
        sIconHold.AnchorPoint = Vector2.new(0, 0.5)
        sIconHold.Position = UDim2.new(0, 9, 0.5, 0)
        sIconHold.ZIndex = 3

        searchBox = mk("TextBox", {
            BackgroundTransparency = 1,
            Font = Fonts.Body,
            TextSize = 12,
            TextColor3 = T.Text,
            PlaceholderText = "Find options…",
            PlaceholderColor3 = T.TextMute,
            Text = "",
            ClearTextOnFocus = false,
            Visible = false,
            Position = UDim2.fromOffset(32, 0),
            Size = UDim2.new(1, -58, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 3,
            Parent = searchHost,
        })

        local clearBtn = mk("TextButton", {
            BackgroundTransparency = 1,
            Text = "",
            Visible = false,
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -6, 0.5, 0),
            Size = UDim2.fromOffset(22, 22),
            ZIndex = 4,
            Parent = searchHost,
        })
        local clearIcon = makeIcon(clearBtn, "lucide:x", 12, T.TextMute, 5)
        clearIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        clearIcon.Position = UDim2.fromScale(0.5, 0.5)

        searchCountLbl = mk("TextLabel", {
            BackgroundTransparency = 1,
            Font = Fonts.Body,
            TextSize = 10,
            TextColor3 = T.TextMute,
            Text = "",
            Visible = false,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -28, 0.5, 0),
            Size = UDim2.fromOffset(28, 14),
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 4,
            Parent = searchHost,
        })

        local hitOpen = mk("TextButton", {
            BackgroundTransparency = 1,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 2,
            Parent = searchHost,
        })

        setSearchOpen = function(on, focus)
            searchExpanded = on
            hitOpen.Visible = not on
            if on then
                tween(searchHost, TI(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.fromOffset(220, 32),
                })
                searchStroke.Color = T.Stroke
                searchStroke.Transparency = 0.15
                searchBox.Visible = true
                clearBtn.Visible = true
                if focus then
                    task.defer(function()
                        searchBox:CaptureFocus()
                    end)
                end
            else
                searchBox.Text = ""
                searchCountLbl.Visible = false
                searchCountLbl.Text = ""
                searchBox.Visible = false
                clearBtn.Visible = false
                tween(searchHost, TI(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.fromOffset(32, 32),
                })
                searchStroke.Color = T.Stroke
                searchStroke.Transparency = 0.4
            end
        end

        hitOpen.MouseButton1Click:Connect(function()
            setSearchOpen(true, true)
        end)

        searchBox.Focused:Connect(function()
            searchStroke.Transparency = 0.1
        end)
        searchBox.FocusLost:Connect(function()
            if searchBox.Text == "" then
                setSearchOpen(false, false)
            else
                searchStroke.Transparency = 0.15
            end
        end)
        clearBtn.MouseButton1Click:Connect(function()
            searchBox.Text = ""
            setSearchOpen(false, false)
        end)
    end

    local function winBtn(iconName, cb)
        local b = mk("TextButton", {
            BackgroundColor3 = T.BgInput,
            BackgroundTransparency = 0.15,
            Text = "",
            Size = UDim2.fromOffset(28, 28),
            AutoButtonColor = false,
            Parent = winBtns,
        })
        corner(b, rCtrl)
        local h, img = makeIcon(b, iconName, 14, T.TextDim, 2)
        h.AnchorPoint = Vector2.new(0.5, 0.5)
        h.Position = UDim2.fromScale(0.5, 0.5)
        hover(b, function()
            tween(b, TI(0.12), { BackgroundColor3 = T.BgHover })
            setIconColor(img, T.Text)
        end, function()
            tween(b, TI(0.12), { BackgroundColor3 = T.BgInput })
            setIconColor(img, T.TextDim)
        end)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    -- Horizontal subtabs strip
    local subTabBar = mk("Frame", {
        Name = "SubTabs",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 56),
        Size = UDim2.new(1, 0, 0, 36),
        Visible = false,
        Parent = content,
    })
    pad(subTabBar, 0, 16, 0, 16)
    local subTabList = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Parent = subTabBar,
    })
    list(subTabList, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

    -- Pages host
    local pages = mk("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 56),
        Size = UDim2.new(1, 0, 1, -56),
        ClipsDescendants = true,
        Parent = content,
    })

    ---------------------------------------------------------------------------
    -- Drag
    ---------------------------------------------------------------------------
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local np = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            main.Position = np
            shadow.Position = np
        end
    end)

    ---------------------------------------------------------------------------
    -- Window API
    ---------------------------------------------------------------------------
    local Window = {
        ScreenGui = screen,
        Main = main,
        Theme = T,
        Accent = accent,
        SectionHeader = {
            TitleSize = winSecTitleSize,
            IconSize = winSecIconSize,
            Scale = winSecHdrScale,
        },
        _tabs = {},
        _activeTab = nil,
        _flags = {},
        _searchEntries = {},
        _searchQuery = "",
        Visible = true,
        _openBtn = nil,
    }

    -- Search = command palette: results drop down as a list; click jumps there
    local searchPanel

    local function closeSearchPanel()
        if searchPanel then
            searchPanel:Destroy()
            searchPanel = nil
        end
    end

    local function navigateTo(e)
        closeSearchPanel()
        if setSearchOpen then setSearchOpen(false, false) end
        Window:SetVisible(true)
        if e.Tab then Window:SelectTab(e.Tab) end
        if e.Tab and e.Page and e.Tab.SelectPage then e.Tab:SelectPage(e.Page) end
        -- scroll to the row + flash it after layout settles
        task.defer(function()
            task.wait(0.05)
            local frame = e.Page and e.Page.Frame
            local row = e.Row
            if not (frame and row and row.Parent) then return end
            local y = row.AbsolutePosition.Y - frame.AbsolutePosition.Y + frame.CanvasPosition.Y - 64
            frame.CanvasPosition = Vector2.new(0, math.max(0, y))
            local flash = mk("Frame", {
                BackgroundColor3 = T.BgHover,
                BackgroundTransparency = 0.35,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 5,
                Parent = row,
            })
            corner(flash, 10)
            task.delay(0.35, function()
                if flash.Parent then
                    local tw = tween(flash, TI(0.8), { BackgroundTransparency = 1 })
                    tw.Completed:Wait()
                    flash:Destroy()
                end
            end)
        end)
    end

    local function applySearch(query)
        query = string.lower(tostring(query or "")):gsub("^%s+", ""):gsub("%s+$", "")
        Window._searchQuery = query
        closeSearchPanel()

        if query == "" then
            if searchCountLbl then
                searchCountLbl.Text = ""
                searchCountLbl.Visible = false
            end
            return
        end

        local matches = {}
        for _, e in ipairs(Window._searchEntries) do
            if e.Row and e.Row.Parent and e.Text ~= "" and string.find(e.Text, query, 1, true) then
                matches[#matches + 1] = e
                if #matches >= 30 then break end
            end
        end

        if searchCountLbl then
            searchCountLbl.Text = tostring(#matches)
            searchCountLbl.Visible = true
        end

        if not searchHost then return end

        local itemH = 44
        local gap = 2
        local padV = 6
        local shown = math.min(#matches, 6)
        local listH = (shown == 0) and 36 or (shown * itemH + math.max(0, shown - 1) * gap)
        local panelW = 280
        local panelH = listH + padV * 2

        -- Parent under content + delta AbsolutePosition — avoids GuiInset mismatch
        -- that was shoving the panel up over the search input.
        searchPanel = mk("Frame", {
            Name = "SearchResults",
            BackgroundColor3 = T.BgSection,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(panelW, panelH),
            ZIndex = 5,
            Parent = content,
        })
        corner(searchPanel, rCard)
        stroke(searchPanel, T.Stroke, 1, 0.35)
        pad(searchPanel, padV, 6, padV, 6)

        local function placePanel()
            if not (searchPanel and searchPanel.Parent and searchHost.Parent) then return end
            local hp = searchHost.AbsolutePosition
            local hs = searchHost.AbsoluteSize
            local cp = content.AbsolutePosition
            local cs = content.AbsoluteSize
            local x = hp.X - cp.X + hs.X - panelW
            local y = hp.Y - cp.Y + hs.Y + 8
            -- keep inside content bounds
            x = math.clamp(x, 8, math.max(8, cs.X - panelW - 8))
            -- never cover the search input / top bar
            y = math.max(y, 60)
            y = math.clamp(y, 60, math.max(60, cs.Y - panelH - 8))
            searchPanel.Position = UDim2.fromOffset(x, y)
        end
        placePanel()
        task.defer(placePanel)

        if #matches == 0 then
            mk("TextLabel", {
                BackgroundTransparency = 1,
                Font = Fonts.Body,
                TextSize = 12,
                TextColor3 = T.TextMute,
                Text = "No results",
                Size = UDim2.fromScale(1, 1),
                ZIndex = 81,
                Parent = searchPanel,
            })
            return
        end

        local host = mk("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = T.TextMute,
            ScrollBarImageTransparency = 0.4,
            CanvasSize = UDim2.fromOffset(0, #matches * itemH + math.max(0, #matches - 1) * gap),
            ScrollingEnabled = #matches > shown,
            ZIndex = 81,
            Parent = searchPanel,
        })
        styleScroll(host)
        list(host, Enum.FillDirection.Vertical, gap)

        for _, e in ipairs(matches) do
            local item = mk("TextButton", {
                BackgroundColor3 = T.BgHover,
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                Text = "",
                Size = UDim2.new(1, 0, 0, itemH),
                ZIndex = 82,
                Parent = host,
            })
            corner(item, 10)

            local ic = makeIcon(item, "lucide:corner-down-right", 13, T.TextMute, 83)
            ic.AnchorPoint = Vector2.new(0, 0.5)
            ic.Position = UDim2.new(0, 10, 0.5, 0)

            mk("TextLabel", {
                BackgroundTransparency = 1,
                Font = Fonts.Title,
                TextSize = 13,
                TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = e.Title,
                Position = UDim2.fromOffset(32, 6),
                Size = UDim2.new(1, -40, 0, 16),
                ZIndex = 83,
                Parent = item,
            })
            mk("TextLabel", {
                BackgroundTransparency = 1,
                Font = Fonts.Desc,
                TextSize = 11,
                TextColor3 = T.TextMute,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = e.TabTitle .. "  ·  " .. e.Section,
                Position = UDim2.fromOffset(32, 23),
                Size = UDim2.new(1, -40, 0, 14),
                ZIndex = 83,
                Parent = item,
            })

            item.MouseEnter:Connect(function()
                tween(item, TI(0.1), { BackgroundTransparency = 0.4 })
            end)
            item.MouseLeave:Connect(function()
                tween(item, TI(0.1), { BackgroundTransparency = 1 })
            end)
            item.MouseButton1Click:Connect(function()
                navigateTo(e)
            end)
        end
    end

    function Window:Search(query)
        query = tostring(query or "")
        if searchBox then
            if query ~= "" and setSearchOpen then
                setSearchOpen(true, false)
            end
            searchBox.Text = query
        end
        applySearch(query)
    end

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            applySearch(searchBox.Text)
        end)
        -- dragging the window would leave the panel floating at a stale spot
        topBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                closeSearchPanel()
            end
        end)
        -- / or Ctrl+F opens find
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if UserInputService:GetFocusedTextBox() then return end
            local open = false
            if input.KeyCode == Enum.KeyCode.Slash then
                open = true
            elseif input.KeyCode == Enum.KeyCode.F and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
                open = true
            end
            if open and setSearchOpen then
                setSearchOpen(true, true)
            end
        end)
    end

    local function setPagesOffset(hasSub)
        if hasSub then
            subTabBar.Visible = true
            pages.Position = UDim2.fromOffset(0, 92)
            pages.Size = UDim2.new(1, 0, 1, -92)
        else
            subTabBar.Visible = false
            pages.Position = UDim2.fromOffset(0, 56)
            pages.Size = UDim2.new(1, 0, 1, -56)
        end
    end

    function Window:SetVisible(v)
        self.Visible = v and true or false
        main.Visible = self.Visible
        shadow.Visible = self.Visible
        if not self.Visible then
            closeSearchPanel()
            if setSearchOpen then setSearchOpen(false, false) end
        end
        if self._openBtn then
            self._openBtn.Visible = true
            if self._styleOpenOrb then
                self._styleOpenOrb(self.Visible)
            end
        end
    end

    function Window:Toggle()
        self:SetVisible(not self.Visible)
    end

    function Window:SetTransparency(amount)
        amount = math.clamp(tonumber(amount) or glass, 0, 0.6)
        glass = amount
        main.BackgroundTransparency = amount
        sidebar.BackgroundTransparency = math.clamp(amount * 0.55, 0, 0.35)
    end

    function Window:Destroy()
        screen:Destroy()
        for i, w in ipairs(VoidUI._windows) do
            if w == self then
                table.remove(VoidUI._windows, i)
                break
            end
        end
    end

    function Window:SelectTab(tab)
        if not tab then return end
        for _, t in ipairs(self._tabs) do
            t:_setActive(t == tab)
        end
        self._activeTab = tab
        -- rebuild subtabs
        for _, c in ipairs(subTabList:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local hasSub = #tab._pages > 1
        setPagesOffset(hasSub)
        if hasSub then
            for _, page in ipairs(tab._pages) do
                local btn = mk("TextButton", {
                    BackgroundColor3 = T.BgHover,
                    BackgroundTransparency = page._active and 0 or 1,
                    AutoButtonColor = false,
                    Font = Fonts.Body,
                    TextSize = 12,
                    Text = page.Title,
                    TextColor3 = page._active and T.Text or T.TextMute,
                    Size = UDim2.fromOffset(0, 26),
                    AutomaticSize = Enum.AutomaticSize.X,
                    Parent = subTabList,
                })
                corner(btn, rCtrl)
                pad(btn, 0, 12, 0, 12)
                btn.MouseEnter:Connect(function()
                    if not page._active then
                        tween(btn, TI(0.1), { BackgroundTransparency = 0.55 })
                    end
                end)
                btn.MouseLeave:Connect(function()
                    if not page._active then
                        tween(btn, TI(0.1), { BackgroundTransparency = 1 })
                    end
                end)
                btn.MouseButton1Click:Connect(function()
                    tab:SelectPage(page)
                end)
                page._subBtn = btn
                page._under = nil
            end
        end
        if tab._activePage then
            tab:SelectPage(tab._activePage)
        elseif tab._pages[1] then
            tab:SelectPage(tab._pages[1])
        end
    end

    winBtn("lucide:minus", function()
        Window:SetVisible(false)
        VoidUI:Notify({ Title = title, Content = "Hidden — tap the float icon or toggle key", Duration = 2 })
    end)
    winBtn("lucide:x", function()
        Window:Destroy()
    end)

    -- Toggle key (mutable — Keybind can rebind via Window:SetToggleKey)
    local toggleKeyState = toggleKey
    function Window:SetToggleKey(key)
        if typeof(key) == "EnumItem" then
            toggleKeyState = key
        end
    end
    function Window:GetToggleKey()
        return toggleKeyState
    end

    UserInputService.InputBegan:Connect(function(input, gp)
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        if input.KeyCode ~= toggleKeyState then return end
        if UserInputService:GetFocusedTextBox() then return end
        Window:Toggle()
    end)

    -- Floating open button — matte circle, no glow/wash
    if wantOpenBtn then
        local obWrap = mk("Frame", {
            Name = "OpenOrb",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 18, 1, -18),
            Size = UDim2.fromOffset(48, 48),
            ZIndex = 50,
            Parent = screen,
        })

        local glow = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 0),
            Parent = obWrap,
        })

        local ob = mk("TextButton", {
            Name = "OpenButton",
            BackgroundColor3 = T.Bg,
            BackgroundTransparency = 0.04,
            Text = "",
            AutoButtonColor = false,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(44, 44),
            ZIndex = 51,
            Parent = obWrap,
        })
        corner(ob, 22)
        local obStroke = stroke(ob, T.Stroke, 1, 0.3)

        local wash = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 0),
            Parent = ob,
        })

        local oh = makeIcon(ob, logoIsAsset and logoIcon or "lucide:layout-dashboard", logoIsAsset and 22 or 18, Color3.new(1, 1, 1), 52)
        oh.AnchorPoint = Vector2.new(0.5, 0.5)
        oh.Position = UDim2.fromScale(0.5, 0.5)

        local function styleOpenOrb(uiVisible)
            if uiVisible then
                tween(ob, TI(0.15), { BackgroundTransparency = 0.2, BackgroundColor3 = T.Bg })
                obStroke.Transparency = 0.5
            else
                tween(ob, TI(0.15), { BackgroundTransparency = 0.02, BackgroundColor3 = T.BgSection })
                obStroke.Transparency = 0.25
            end
        end

        hover(ob, function()
            tween(ob, TI(0.12), { Size = UDim2.fromOffset(46, 46) })
        end, function()
            tween(ob, TI(0.12), { Size = UDim2.fromOffset(44, 44) })
            styleOpenOrb(Window.Visible)
        end)

        -- drag whole wrap
        local draggingOb, d0, p0
        ob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                draggingOb = true
                d0 = input.Position
                p0 = obWrap.Position
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        draggingOb = false
                    end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingOb and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - d0
                obWrap.Position = UDim2.new(p0.X.Scale, p0.X.Offset + d.X, p0.Y.Scale, p0.Y.Offset + d.Y)
            end
        end)

        local moved = false
        ob.InputChanged:Connect(function(input)
            if draggingOb and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                if (input.Position - d0).Magnitude > 6 then moved = true end
            end
        end)
        ob.MouseButton1Click:Connect(function()
            if moved then moved = false return end
            Window:Toggle()
        end)

        Window._openBtn = obWrap
        Window._styleOpenOrb = styleOpenOrb
        styleOpenOrb(true)
    end

    ---------------------------------------------------------------------------
    -- Tab (sidebar entry)
    ---------------------------------------------------------------------------
    function Window:Tab(opts)
        opts = opts or {}
        local tabTitle = opts.Title or "Tab"
        local tabIcon = opts.Icon or "lucide:house"
        local selected = opts.Selected

        local btn = mk("TextButton", {
            Name = "Tab_" .. tabTitle,
            BackgroundTransparency = 1,
            Text = "",
            Size = UDim2.fromOffset(40, 40),
            AutoButtonColor = false,
            Parent = sideNav,
        })

        local indicator = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 0),
            Parent = btn,
        })

        local iconBg = mk("Frame", {
            BackgroundColor3 = T.BgHover,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(32, 32),
            Parent = btn,
        })
        corner(iconBg, 16)

        local iconHolder, iconLbl = makeIcon(iconBg, tabIcon, 18, T.TextDim, 2)
        iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
        iconHolder.Position = UDim2.fromScale(0.5, 0.5)

        -- sidebar tooltip (tab name)
        local tip
        local function hideTip()
            if tip then tip:Destroy() tip = nil end
        end
        local function showTip()
            hideTip()
            local abs = btn.AbsolutePosition
            local sz = btn.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local x = abs.X + sz.X + 10 + (screen.IgnoreGuiInset and inset.X or 0)
            local y = abs.Y + sz.Y * 0.5 + (screen.IgnoreGuiInset and inset.Y or 0)
            tip = mk("Frame", {
                Name = "TabTip",
                BackgroundColor3 = T.BgSection,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.fromOffset(x, y),
                AutomaticSize = Enum.AutomaticSize.XY,
                ZIndex = 900,
                Parent = screen,
            })
            corner(tip, rCtrl)
            stroke(tip, T.Stroke, 1, 0.35)
            pad(tip, 4, 8, 4, 8)
            mk("TextLabel", {
                BackgroundTransparency = 1,
                Font = Fonts.Body,
                TextSize = 11,
                TextColor3 = T.Text,
                Text = tabTitle,
                AutomaticSize = Enum.AutomaticSize.XY,
                ZIndex = 901,
                Parent = tip,
            })
        end

        local pageHost = mk("Frame", {
            Name = "TabHost_" .. tabTitle,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = pages,
        })

        local Tab = {
            Title = tabTitle,
            Button = btn,
            Host = pageHost,
            _pages = {},
            _activePage = nil,
            _window = Window,
        }

        local darkIcon = Color3.new(1, 1, 1)
        function Tab:_setActive(on)
            pageHost.Visible = on
            if on then
                tween(iconBg, TI(0.15), { BackgroundTransparency = 0.35, BackgroundColor3 = accent })
                if iconLbl then
                    tween(iconLbl, TI(0.15), { ImageColor3 = Color3.new(1, 1, 1) })
                end
            else
                tween(iconBg, TI(0.15), { BackgroundTransparency = 1 })
                if iconLbl then
                    tween(iconLbl, TI(0.15), { ImageColor3 = T.TextDim })
                end
            end
        end

        btn.MouseEnter:Connect(function()
            showTip()
            if not pageHost.Visible then
                tween(iconBg, TI(0.12), { BackgroundColor3 = T.BgHover, BackgroundTransparency = 0.25 })
            end
        end)
        btn.MouseLeave:Connect(function()
            hideTip()
            if not pageHost.Visible then
                tween(iconBg, TI(0.12), { BackgroundTransparency = 1 })
            end
        end)

        function Tab:SelectPage(page)
            for _, p in ipairs(self._pages) do
                p.Frame.Visible = (p == page)
                p._active = (p == page)
                if p._subBtn then
                    p._subBtn.TextColor3 = p._active and T.Text or T.TextMute
                    p._subBtn.BackgroundTransparency = p._active and 0 or 1
                end
            end
            self._activePage = page
        end

        ---------------------------------------------------------------------------
        -- Page (horizontal sub-tab) — if only one, no subtab UI
        ---------------------------------------------------------------------------
        function Tab:Page(popts)
            popts = popts or {}
            local pageTitle = popts.Title or tabTitle

            local frame = mk("ScrollingFrame", {
                Name = "Page_" .. pageTitle,
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.None,
                Visible = false,
                Parent = pageHost,
            })
            styleScroll(frame)
            -- two-column optional layout container
            local body = mk("Frame", {
                Name = "Body",
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(14, 8),
                Size = UDim2.new(1, -28, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = frame,
            })
            local function updateCanvas()
                frame.CanvasSize = UDim2.fromOffset(0, 12 + body.AbsoluteSize.Y + 48)
            end
            body:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCanvas)
            task.defer(updateCanvas)

            local columns = popts.Columns or 1
            local colFrames = {}
            if columns >= 2 then
                local row = mk("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = body,
                })
                local layout = Instance.new("UIListLayout")
                layout.FillDirection = Enum.FillDirection.Horizontal
                layout.Padding = UDim.new(0, 12)
                layout.SortOrder = Enum.SortOrder.LayoutOrder
                layout.Parent = row
                for i = 1, columns do
                    local col = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1 / columns, -6, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = i,
                        Parent = row,
                    })
                    list(col, Enum.FillDirection.Vertical, 10)
                    colFrames[i] = col
                end
            else
                list(body, Enum.FillDirection.Vertical, 10)
                colFrames[1] = body
            end

            local Page = {
                Title = pageTitle,
                Frame = frame,
                Body = body,
                _active = false,
                _columns = colFrames,
            }

            function Page:Section(sopts)
                sopts = sopts or {}
                local colIndex = sopts.Column or 1
                local parentCol = colFrames[colIndex] or colFrames[1]
                local secTitle = prettySectionTitle(sopts.Title or "Section")
                local secIcon = normalizeAsset(sopts.Icon or sopts.Image)

                local wrap = mk("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = parentCol,
                })
                list(wrap, Enum.FillDirection.Vertical, 6)

                -- Section header size: Section opts > Window SectionHeader > defaults (14 / 15)
                local hdrScale = math.clamp(tonumber(sopts.HeaderScale or sopts.Scale) or winSecHdrScale, 0.75, 1.75)
                local titleSize = math.clamp(
                    math.floor((tonumber(sopts.TitleSize) or winSecTitleSize) * hdrScale + 0.5),
                    11, 22
                )
                local iconSize = math.clamp(
                    math.floor((tonumber(sopts.IconSize) or winSecIconSize) * hdrScale + 0.5),
                    12, 28
                )
                local labelH = titleSize + 4
                local headH = math.max(labelH + 2, iconSize + 6, 20)

                local headRow = mk("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headH),
                    Parent = wrap,
                })
                local titleX = 0
                if secIcon then
                    local iconCol = (type(secIcon) == "string" and secIcon:find("rbxassetid", 1, true))
                        and Color3.new(1, 1, 1) or T.TextDim
                    local ih = makeIcon(headRow, secIcon, iconSize, iconCol, 2)
                    ih.AnchorPoint = Vector2.new(0, 0.5)
                    ih.Position = UDim2.new(0, 0, 0.5, 0)
                    titleX = iconSize + 8
                end
                bloomLabel({
                    Parent = headRow,
                    Name = "SectionTitle",
                    Text = secTitle,
                    TextSize = titleSize,
                    Font = Fonts.Body,
                    Color = T.TextDim,
                    Accent = accent,
                    Bloom = bloomOn,
                    Height = labelH,
                    Position = UDim2.fromOffset(titleX, math.floor((headH - labelH) / 2)),
                    Size = UDim2.new(1, -titleX, 0, labelH),
                })

                local card = mk("Frame", {
                    BackgroundColor3 = T.BgSection,
                    BackgroundTransparency = math.clamp(glass * 0.15, 0, 0.1),
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = wrap,
                })
                corner(card, rCard)
                stroke(card, T.Stroke, 1, 0.42)
                pad(card, 4, 4, 4, 4)
                list(card, Enum.FillDirection.Vertical, 0)

                local Section = { Frame = card, Title = secTitle }
                local rowOrder = 0

                -- No hairline between rows — padding separates (Callisto/Lumen)
                local function addDivider()
                end

                local function registerSearch(row, titleText, descText)
                    table.insert(Window._searchEntries, {
                        Row = row,
                        Tab = Tab,
                        Page = Page,
                        Title = tostring(titleText or ""),
                        Section = tostring(secTitle or ""),
                        TabTitle = tostring(tabTitle or ""),
                        Text = string.lower(table.concat({
                            tostring(titleText or ""),
                            " ",
                            tostring(descText or ""),
                            " ",
                            tostring(secTitle or ""),
                            " ",
                            tostring(tabTitle or ""),
                        })),
                    })
                end

                -- base row: title left + control right. Compact hides Desc.
                local function makeRow(titleText, descText, iconSpec)
                    if compactOn then descText = nil end
                    addDivider()
                    rowOrder = rowOrder + 1
                    local row = mk("Frame", {
                        BackgroundColor3 = T.BgSection,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = rowOrder,
                        Active = true,
                        Parent = card,
                    })
                    row:SetAttribute("_bt", 1)
                    pad(row, 8, 10, 8, 10)

                    local hitBg = mk("Frame", {
                        BackgroundColor3 = T.BgHover,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 1, 0),
                        ZIndex = 0,
                        Parent = row,
                    })
                    corner(hitBg, rCtrl)
                    row.MouseEnter:Connect(function()
                        tween(hitBg, TI(0.1), { BackgroundTransparency = 0.88 })
                    end)
                    row.MouseLeave:Connect(function()
                        tween(hitBg, TI(0.1), { BackgroundTransparency = 1 })
                    end)

                    local left = mk("Frame", {
                        BackgroundTransparency = 1,
                        Position = UDim2.fromOffset(0, 0),
                        Size = UDim2.new(1, -112, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Parent = row,
                    })
                    list(left, Enum.FillDirection.Vertical, 1)

                    mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Title,
                        TextSize = 14,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = titleText or "",
                        Size = UDim2.new(1, 0, 0, 18),
                        Parent = left,
                    })

                    if descText and descText ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 12,
                            TextColor3 = T.TextMute,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextWrapped = true,
                            Text = descText,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Parent = left,
                        })
                    end

                    local right = mk("Frame", {
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        Size = UDim2.fromOffset(110, 28),
                        Parent = row,
                    })
                    registerSearch(row, titleText, descText)
                    return row, left, right
                end

                -----------------------------------------------------------------
                -- Toggle
                -----------------------------------------------------------------
                function Section:Toggle(o)
                    o = o or {}
                    local value = o.Value and true or false
                    local row, _, right = makeRow(o.Title or "Toggle", o.Desc, o.Icon or o.Image)

                    right.Size = UDim2.fromOffset(50, 28)
                    local track = mk("Frame", {
                        BackgroundColor3 = value and accent or T.BgToggleOff,
                        Size = UDim2.fromScale(1, 1),
                        Parent = right,
                    })
                    corner(track, 14)
                    local knob = mk("Frame", {
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        Size = UDim2.fromOffset(24, 24),
                        Position = value and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12),
                        Parent = track,
                    })
                    corner(knob, 12)

                    local hit = mk("TextButton", {
                        BackgroundTransparency = 1,
                        Text = "",
                        Size = UDim2.fromScale(1, 1),
                        Parent = track,
                    })

                    local api = {
                        Value = value,
                        Row = row,
                        Set = function(self, v, silent)
                            self.Value = v and true or false
                            local on = self.Value
                            local col = on and accent or T.BgToggleOff
                            local pos = on and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)
                            -- apply immediately so remote/silent Set never leaves stale visuals
                            pcall(function()
                                track.BackgroundColor3 = col
                                knob.Position = pos
                            end)
                            pcall(function()
                                tween(track, TI(0.18), { BackgroundColor3 = col })
                                tween(knob, TI(0.18, Enum.EasingStyle.Quart), { Position = pos })
                            end)
                            if not silent and o.Callback then
                                task.spawn(o.Callback, self.Value)
                            end
                        end,
                        SetVisible = function(self, vis)
                            if row then row.Visible = vis and true or false end
                        end,
                    }

                    hit.MouseButton1Click:Connect(function()
                        api:Set(not api.Value)
                    end)

                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                -----------------------------------------------------------------
                -- Slider
                -----------------------------------------------------------------
                function Section:Slider(o)
                    o = o or {}
                    local min, max = o.Min or 0, o.Max or 100
                    local value = math.clamp(o.Value or min, min, max)
                    local suffix = o.Suffix or ""
                    local decimals = o.Decimals or 0

                    addDivider()
                    rowOrder = rowOrder + 1
                    local row = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    pad(row, 8, 8, 8, 10)
                    list(row, Enum.FillDirection.Vertical, 6)
                    registerSearch(row, o.Title or "Slider", o.Desc)

                    local top = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 20),
                        LayoutOrder = 1,
                        Parent = row,
                    })
                    local sliderTitleX = 0
                    mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Title,
                        TextSize = 14,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = o.Title or "Slider",
                        Position = UDim2.fromOffset(0, 0),
                        Size = UDim2.new(1, -78, 1, 0),
                        Parent = top,
                    })
                    local function fmt(v)
                        return (decimals > 0 and string.format("%." .. decimals .. "f", v) or tostring(math.floor(v + 0.5)))
                    end
                    local valBox = mk("TextBox", {
                        BackgroundColor3 = T.BgInput,
                        Font = Fonts.Title,
                        TextSize = 12,
                        TextColor3 = T.Text,
                        Text = fmt(value),
                        ClearTextOnFocus = false,
                        TextXAlignment = Enum.TextXAlignment.Center,
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, 0, 0.5, 0),
                        Size = UDim2.fromOffset(56, 22),
                        Parent = top,
                    })
                    corner(valBox, rCtrl)
                    stroke(valBox, T.Stroke, 1, 0.4)
                    if suffix ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 10,
                            TextColor3 = T.TextMute,
                            Text = suffix,
                            AnchorPoint = Vector2.new(1, 0.5),
                            Position = UDim2.new(1, -68, 0.5, 0),
                            Size = UDim2.fromOffset(20, 14),
                            TextXAlignment = Enum.TextXAlignment.Right,
                            Parent = top,
                        })
                        valBox.Position = UDim2.new(1, 0, 0.5, 0)
                        valBox.Size = UDim2.fromOffset(56, 22)
                    end

                    if not compactOn and o.Desc and o.Desc ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 13,
                            TextColor3 = T.TextMute,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextYAlignment = Enum.TextYAlignment.Top,
                            TextWrapped = true,
                            Text = o.Desc,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            LayoutOrder = 2,
                            Parent = row,
                        })
                    end

                    local trackWrap = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 18),
                        LayoutOrder = 3,
                        Parent = row,
                    })
                    local track = mk("Frame", {
                        BackgroundColor3 = T.BgToggleOff,
                        AnchorPoint = Vector2.new(0, 0.5),
                        Position = UDim2.new(0, 0, 0.5, 0),
                        Size = UDim2.new(1, 0, 0, 4),
                        Parent = trackWrap,
                    })
                    corner(track, 2)
                    local fill = mk("Frame", {
                        BackgroundColor3 = accent,
                        Size = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 1, 0),
                        Parent = track,
                    })
                    corner(fill, 2)
                    local knob = mk("Frame", {
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.new((value - min) / math.max(max - min, 1e-6), 0, 0.5, 0),
                        Size = UDim2.fromOffset(12, 12),
                        ZIndex = 3,
                        Parent = track,
                    })
                    corner(knob, 6)
                    stroke(knob, T.Stroke, 1, 0.35)

                    local sliding = false
                    local api = { Value = value }

                    local function applyVisual(raw)
                        local p = (raw - min) / math.max(max - min, 1e-6)
                        fill.Size = UDim2.new(p, 0, 1, 0)
                        knob.Position = UDim2.new(p, 0, 0.5, 0)
                        if not valBox:IsFocused() then
                            valBox.Text = fmt(raw)
                        end
                    end

                    local function setFromX(x, silent)
                        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
                        local raw = min + rel * (max - min)
                        if decimals <= 0 then
                            raw = math.floor(raw + 0.5)
                        else
                            local m = 10 ^ decimals
                            raw = math.floor(raw * m + 0.5) / m
                        end
                        api.Value = raw
                        applyVisual(raw)
                        if not silent and o.Callback then
                            task.spawn(o.Callback, raw)
                        end
                    end

                    function api:Set(v, silent)
                        v = math.clamp(tonumber(v) or min, min, max)
                        if decimals <= 0 then
                            v = math.floor(v + 0.5)
                        else
                            local m = 10 ^ decimals
                            v = math.floor(v * m + 0.5) / m
                        end
                        self.Value = v
                        applyVisual(v)
                        if not silent and o.Callback then task.spawn(o.Callback, v) end
                    end

                    valBox.FocusLost:Connect(function()
                        local n = tonumber(valBox.Text)
                        if n then
                            api:Set(n)
                        else
                            valBox.Text = fmt(api.Value)
                        end
                    end)

                    track.InputBegan:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            sliding = true
                            setFromX(input.Position.X)
                        end
                    end)
                    UserInputService.InputChanged:Connect(function(input)
                        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                            setFromX(input.Position.X)
                        end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                            sliding = false
                        end
                    end)

                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                -----------------------------------------------------------------
                -- Dropdown
                -----------------------------------------------------------------
                function Section:Dropdown(o)
                    o = o or {}
                    local values = o.Values or { "Option 1" }
                    local multi = o.Multi == true
                    local current = o.Value
                    if multi then
                        if type(current) ~= "table" then current = {} end
                    else
                        if current == nil then current = values[1] end
                    end

                    local row, _, right = makeRow(o.Title or "Dropdown", o.Desc, o.Icon or o.Image)
                    right.Size = UDim2.fromOffset(136, 30)

                    local box = mk("TextButton", {
                        BackgroundColor3 = T.BgInput,
                        AutoButtonColor = false,
                        Text = "",
                        Size = UDim2.fromScale(1, 1),
                        Parent = right,
                    })
                    corner(box, rCtrl)
                    stroke(box, T.Stroke, 1, 0.4)

                    local rail = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(0, 0, 0, 0),
                        Parent = box,
                    })

                    local function displayLabel(v)
                        local key = entryKey(v)
                        for _, opt in ipairs(values) do
                            if entryKey(opt) == key then return entryLabel(opt) end
                        end
                        return entryLabel(v)
                    end

                    local function labelText()
                        if multi then
                            local n = #current
                            if n == 0 then return o.Placeholder or "Select..." end
                            if n == 1 then return displayLabel(current[1]) end
                            return n .. " selected"
                        end
                        if current == nil then return o.Placeholder or "Select..." end
                        return displayLabel(current)
                    end

                    local txt = mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Body,
                        TextSize = 13,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Text = "",
                        Position = UDim2.fromOffset(14, 0),
                        Size = UDim2.new(1, -36, 1, 0),
                        Parent = box,
                    })

                    local previewIcon
                    local function refreshPreview()
                        if previewIcon then previewIcon:Destroy() previewIcon = nil end
                        local asset = (not multi) and entryAsset(current) or nil
                        local leftPad = 14
                        if asset then
                            previewIcon = makeIcon(box, asset, 20, Color3.new(1, 1, 1), 3)
                            previewIcon.AnchorPoint = Vector2.new(0, 0.5)
                            previewIcon.Position = UDim2.new(0, 8, 0.5, 0)
                            leftPad = 36
                        end
                        txt.Position = UDim2.fromOffset(leftPad, 0)
                        txt.Size = UDim2.new(1, -(leftPad + 22), 1, 0)
                        txt.Text = labelText()
                    end
                    refreshPreview()
                    local chevHolder = makeIcon(box, "lucide:chevron-down", 14, T.TextDim, 2)
                    chevHolder.AnchorPoint = Vector2.new(1, 0.5)
                    chevHolder.Position = UDim2.new(1, -8, 0.5, 0)

                    local open = false
                    local menu
                    local menuShadow
                    local dismiss

                    local api = {
                        Value = current,
                        Values = values,
                        Row = row,
                    }
                    function api:SetVisible(vis)
                        if row then row.Visible = vis and true or false end
                    end

                    local function closeMenu()
                        open = false
                        rail.BackgroundTransparency = 0.55
                        if chevHolder:FindFirstChildWhichIsA("ImageLabel") then
                            tween(chevHolder:FindFirstChildWhichIsA("ImageLabel"), TI(0.15), { Rotation = 0 })
                        end
                        if menu then menu:Destroy() menu = nil end
                        if menuShadow then menuShadow:Destroy() menuShadow = nil end
                        if dismiss then dismiss:Destroy() dismiss = nil end
                    end

                    local function isSelected(v)
                        if multi then
                            for _, x in ipairs(current) do
                                if entriesEqual(x, v) then return true end
                            end
                            return false
                        end
                        return entriesEqual(current, v)
                    end

                    local function fire()
                        if o.Callback then task.spawn(o.Callback, current) end
                    end

                    local function openMenu()
                        if open then closeMenu() return end
                        open = true
                        rail.BackgroundTransparency = 0.15
                        local chevImg = chevHolder:FindFirstChildWhichIsA("ImageLabel")
                        if chevImg then tween(chevImg, TI(0.15), { Rotation = 180 }) end

                        local abs = box.AbsolutePosition
                        local boxSz = box.AbsoluteSize
                        -- Taller rows so game asset icons (Shop/Craft) are readable
                        local itemH = 44
                        local iconSz = 28
                        local gap = 3
                        local padTop, padBot = 6, 8
                        local searchH = 0
                        local wantFilter = (o.Search ~= false) and (#values >= 6 or o.Search == true)
                        if wantFilter then searchH = 34 end
                        local countH = multi and 22 or 0

                        local maxListH = math.floor((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720) * 0.42)
                        maxListH = math.clamp(maxListH, 180, 320)
                        local fullListH = #values * itemH + math.max(0, #values - 1) * gap
                        local listH = math.min(fullListH, maxListH)
                        local menuW = math.max(boxSz.X, 200)
                        local menuH = padTop + padBot + searchH + countH + listH

                        -- GuiInset-safe place (same ScreenGui IgnoreGuiInset)
                        local inset = GuiService:GetGuiInset()
                        local posX = abs.X + (screen.IgnoreGuiInset and inset.X or 0)
                        local posYBelow = abs.Y + boxSz.Y + 6 + (screen.IgnoreGuiInset and inset.Y or 0)
                        local posYAbove = abs.Y - menuH - 6 + (screen.IgnoreGuiInset and inset.Y or 0)
                        local screenH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080
                        local openUp = (posYBelow + menuH + 12) > screenH and posYAbove > 8
                        local posXFinal = math.clamp(posX + boxSz.X - menuW, 8, math.max(8, (workspace.CurrentCamera.ViewportSize.X or 1280) - menuW - 8))
                        local posY = openUp and math.max(8, posYAbove) or math.max(8, posYBelow)

                        -- Above Window:Popup (700+) so menus are visible inside modals
                        local z0 = 920
                        dismiss = mk("TextButton", {
                            BackgroundTransparency = 1,
                            Text = "",
                            AutoButtonColor = false,
                            Active = true,
                            Size = UDim2.fromScale(1, 1),
                            ZIndex = z0,
                            Parent = screen,
                        })
                        dismiss.MouseButton1Click:Connect(closeMenu)

                        menuShadow = mk("ImageLabel", {
                            BackgroundTransparency = 1,
                            Image = "rbxassetid://6014261993",
                            ImageColor3 = Color3.new(0, 0, 0),
                            ImageTransparency = 0.55,
                            ScaleType = Enum.ScaleType.Slice,
                            SliceCenter = Rect.new(49, 49, 450, 450),
                            Position = UDim2.fromOffset(posXFinal - 10, posY - 8),
                            Size = UDim2.fromOffset(menuW + 20, menuH + 20),
                            ZIndex = z0 + 1,
                            Parent = screen,
                        })

                        menu = mk("Frame", {
                            BackgroundColor3 = T.BgSection,
                            BorderSizePixel = 0,
                            Position = UDim2.fromOffset(posXFinal, posY),
                            Size = UDim2.fromOffset(menuW, menuH),
                            ZIndex = z0 + 2,
                            Parent = screen,
                        })
                        corner(menu, rCard)
                        stroke(menu, T.Stroke, 1, 0.4)
                        pad(menu, padTop, 6, padBot, 6)

                        local countLbl
                        local rebuildList
                        local function refreshCount()
                            if not countLbl then return end
                            local n = (type(current) == "table") and #current or 0
                            countLbl.Text = n == 0 and "None selected" or (n .. " selected")
                        end

                        if multi then
                            local countBar = mk("Frame", {
                                BackgroundTransparency = 1,
                                Position = UDim2.fromOffset(0, searchH),
                                Size = UDim2.new(1, 0, 0, countH),
                                ZIndex = z0 + 4,
                                Parent = menu,
                            })
                            countLbl = mk("TextLabel", {
                                BackgroundTransparency = 1,
                                Font = Fonts.Body,
                                TextSize = 11,
                                TextColor3 = T.TextMute,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                Text = "",
                                Size = UDim2.new(1, -48, 1, 0),
                                ZIndex = z0 + 5,
                                Parent = countBar,
                            })
                            local clearBtn = mk("TextButton", {
                                BackgroundTransparency = 1,
                                AutoButtonColor = false,
                                Font = Fonts.Body,
                                TextSize = 11,
                                TextColor3 = T.TextDim,
                                Text = "Clear",
                                AnchorPoint = Vector2.new(1, 0.5),
                                Position = UDim2.new(1, 0, 0.5, 0),
                                Size = UDim2.fromOffset(44, 18),
                                ZIndex = z0 + 5,
                                Parent = countBar,
                            })
                            clearBtn.MouseButton1Click:Connect(function()
                                current = {}
                                api.Value = current
                                refreshPreview()
                                fire()
                                refreshCount()
                                rebuildList(true)
                            end)
                            refreshCount()
                        end

                        local filterQ = ""
                        local scroll
                        rebuildList = function(keepScroll)
                            local keepY = 0
                            if keepScroll and scroll then
                                keepY = scroll.CanvasPosition.Y
                            end
                            if scroll then scroll:Destroy() end
                            local filtered = {}
                            local q = string.lower(filterQ)
                            for _, v in ipairs(values) do
                                if q == "" or string.find(string.lower(entryLabel(v)), q, 1, true) then
                                    filtered[#filtered + 1] = v
                                end
                            end

                            local fH = #filtered * itemH + math.max(0, #filtered - 1) * gap
                            local viewH = math.min(math.max(fH, itemH), maxListH)
                            local newMenuH = padTop + padBot + searchH + countH + viewH
                            menu.Size = UDim2.fromOffset(menuW, newMenuH)
                            if menuShadow then
                                menuShadow.Size = UDim2.fromOffset(menuW + 20, newMenuH + 20)
                            end

                            scroll = mk("ScrollingFrame", {
                                BackgroundTransparency = 1,
                                BorderSizePixel = 0,
                                Position = UDim2.fromOffset(0, searchH + countH),
                                Size = UDim2.new(1, 0, 0, viewH),
                                CanvasSize = UDim2.fromOffset(0, fH),
                                ScrollingEnabled = fH > viewH,
                                ZIndex = z0 + 3,
                                Parent = menu,
                            })
                            styleScroll(scroll)
                            local listHost = mk("Frame", {
                                BackgroundTransparency = 1,
                                Size = UDim2.new(1, 0, 0, fH),
                                ZIndex = z0 + 4,
                                Parent = scroll,
                            })
                            list(listHost, Enum.FillDirection.Vertical, gap)

                            if keepScroll then
                                local y = keepY
                                task.defer(function()
                                    if scroll and scroll.Parent then
                                        local maxY = math.max(0, fH - viewH)
                                        scroll.CanvasPosition = Vector2.new(0, math.clamp(y, 0, maxY))
                                    end
                                end)
                            end

                            if #filtered == 0 then
                                mk("TextLabel", {
                                    BackgroundTransparency = 1,
                                    Font = Fonts.Body,
                                    TextSize = 12,
                                    TextColor3 = T.TextMute,
                                    Text = "No matches",
                                    Size = UDim2.new(1, 0, 0, itemH),
                                    ZIndex = z0 + 5,
                                    Parent = listHost,
                                })
                                return
                            end

                            for _, v in ipairs(filtered) do
                                local selected = isSelected(v)
                                local item = mk("TextButton", {
                                    BackgroundColor3 = T.BgHover,
                                    BackgroundTransparency = selected and 0.15 or 1,
                                    AutoButtonColor = false,
                                    Active = true,
                                    Text = "",
                                    Size = UDim2.new(1, 0, 0, itemH),
                                    ZIndex = z0 + 5,
                                    Parent = listHost,
                                })
                                corner(item, rCtrl)

                                local textLeft = 14
                                local asset = entryAsset(v)
                                if asset then
                                    local slot = mk("Frame", {
                                        BackgroundColor3 = T.BgInput,
                                        BackgroundTransparency = 0.35,
                                        Size = UDim2.fromOffset(iconSz, iconSz),
                                        AnchorPoint = Vector2.new(0, 0.5),
                                        Position = UDim2.new(0, 10, 0.5, 0),
                                        ClipsDescendants = true,
                                        ZIndex = z0 + 6,
                                        Parent = item,
                                    })
                                    corner(slot, 7)
                                    local ic = makeIcon(slot, asset, iconSz - 4, Color3.new(1, 1, 1), z0 + 7)
                                    ic.AnchorPoint = Vector2.new(0.5, 0.5)
                                    ic.Position = UDim2.fromScale(0.5, 0.5)
                                    ic.Size = UDim2.fromOffset(iconSz - 4, iconSz - 4)
                                    textLeft = 10 + iconSz + 10
                                end

                                mk("TextLabel", {
                                    BackgroundTransparency = 1,
                                    Font = Fonts.Body,
                                    TextSize = 13,
                                    TextScaled = false,
                                    TextColor3 = T.Text,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                    TextYAlignment = Enum.TextYAlignment.Center,
                                    TextTruncate = Enum.TextTruncate.AtEnd,
                                    Text = entryLabel(v),
                                    Size = UDim2.new(1, -(textLeft + 28), 1, 0),
                                    Position = UDim2.fromOffset(textLeft, 0),
                                    ZIndex = z0 + 6,
                                    Active = false,
                                    Parent = item,
                                })

                                local chkHold
                                local function setRowSelected(on)
                                    item.BackgroundTransparency = on and 0.15 or 1
                                    item.BackgroundColor3 = T.BgHover
                                    if on then
                                        if not chkHold then
                                            chkHold = makeIcon(item, "lucide:check", 13, accent, z0 + 7)
                                            chkHold.AnchorPoint = Vector2.new(1, 0.5)
                                            chkHold.Position = UDim2.new(1, -8, 0.5, 0)
                                        end
                                    elseif chkHold then
                                        chkHold:Destroy()
                                        chkHold = nil
                                    end
                                end
                                setRowSelected(selected)

                                item.MouseEnter:Connect(function()
                                    if not isSelected(v) then
                                        tween(item, TI(0.1), { BackgroundTransparency = 0.2, BackgroundColor3 = T.BgHover })
                                    end
                                end)
                                item.MouseLeave:Connect(function()
                                    if not isSelected(v) then
                                        tween(item, TI(0.1), { BackgroundTransparency = 1 })
                                    end
                                end)

                                item.MouseButton1Click:Connect(function()
                                    if multi then
                                        local found
                                        for i, x in ipairs(current) do
                                            if entriesEqual(x, v) then found = i break end
                                        end
                                        if found then
                                            table.remove(current, found)
                                        else
                                            table.insert(current, v)
                                        end
                                        api.Value = current
                                        refreshPreview()
                                        fire()
                                        setRowSelected(isSelected(v))
                                        refreshCount()
                                    else
                                        current = v
                                        api.Value = current
                                        refreshPreview()
                                        closeMenu()
                                        fire()
                                    end
                                end)
                            end
                        end

                        if wantFilter then
                            local searchBar = mk("Frame", {
                                BackgroundColor3 = T.BgInput,
                                Size = UDim2.new(1, 0, 0, 28),
                                ZIndex = 502,
                                Parent = menu,
                            })
                            corner(searchBar, 8)
                            stroke(searchBar, T.Stroke, 1, 0.4)
                            local sIcon = makeIcon(searchBar, "lucide:search", 13, T.TextMute, 503)
                            sIcon.Position = UDim2.fromOffset(8, 7)
                            local sBox = mk("TextBox", {
                                BackgroundTransparency = 1,
                                Font = Fonts.Body,
                                TextSize = 12,
                                TextColor3 = T.Text,
                                PlaceholderText = "Search…",
                                PlaceholderColor3 = T.TextMute,
                                Text = "",
                                ClearTextOnFocus = false,
                                Position = UDim2.fromOffset(28, 0),
                                Size = UDim2.new(1, -34, 1, 0),
                                TextXAlignment = Enum.TextXAlignment.Left,
                                ZIndex = 503,
                                Parent = searchBar,
                            })
                            -- don't dismiss when clicking search
                            sBox.Focused:Connect(function() end)
                            sBox:GetPropertyChangedSignal("Text"):Connect(function()
                                filterQ = sBox.Text
                                rebuildList()
                            end)
                        end

                        rebuildList()
                    end

                    box.MouseButton1Click:Connect(openMenu)
                    hover(box, function()
                        if not open then
                            tween(box, TI(0.12), { BackgroundColor3 = T.BgHover })
                        end
                    end, function()
                        if not open then
                            tween(box, TI(0.12), { BackgroundColor3 = T.BgInput })
                        end
                    end)

                    function api:Set(v, silent)
                        if multi then
                            current = type(v) == "table" and v or { v }
                        else
                            current = v
                        end
                        self.Value = current
                        refreshPreview()
                        if not silent then fire() end
                    end

                    function api:Refresh(newValues)
                        values = newValues or values
                        self.Values = values
                    end

                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                -----------------------------------------------------------------
                -- Button (default = WindUI-clean row: title/desc + action icon)
                -- Style: "Clean" (default) | "Accent" | "Soft" | "Ghost" (filled CTA)
                -----------------------------------------------------------------
                function Section:Button(o)
                    o = o or {}
                    local style = string.lower(tostring(o.Style or "clean"))
                    -- Always show a trailing icon so rows read as clickable.
                    -- Prefer explicit Icon/Image; else chevron (not play — that made every button identical).
                    local iconName = normalizeAsset(o.Icon or o.Image) or "lucide:chevron-right"

                    -- Clean row — whole row is clickable (not just the icon)
                    if style == "clean" or style == "row" or style == "icon" then
                        local row, _, right = makeRow(o.Title or "Button", o.Desc, o.LeadingIcon or o.LeadingImage)
                        right.Size = UDim2.fromOffset(34, 34)
                        local ih, img = makeIcon(right, iconName, 18, T.TextDim, 2)
                        ih.AnchorPoint = Vector2.new(0.5, 0.5)
                        ih.Position = UDim2.fromScale(0.5, 0.5)

                        local hitBg = row:FindFirstChildWhichIsA("Frame") -- first child is hover bg from makeRow
                        local hit = mk("TextButton", {
                            BackgroundTransparency = 1,
                            AutoButtonColor = false,
                            Text = "",
                            Size = UDim2.fromScale(1, 1),
                            ZIndex = 25,
                            Parent = row,
                        })

                        local function setHover(on)
                            if hitBg then
                                tween(hitBg, TI(0.1), { BackgroundTransparency = on and 0.88 or 1 })
                            end
                            if img then setIconColor(img, on and accent or T.TextDim) end
                        end
                        hit.MouseEnter:Connect(function() setHover(true) end)
                        hit.MouseLeave:Connect(function() setHover(false) end)
                        hit.MouseButton1Click:Connect(function()
                            if o.Callback then task.spawn(o.Callback) end
                        end)
                        return hit
                    end

                    -- Filled CTA (optional)
                    addDivider()
                    rowOrder = rowOrder + 1
                    local row = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, o.Desc and 52 or 42),
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    pad(row, 6, 6, 6, 6)
                    registerSearch(row, o.Title or "Button", o.Desc)

                    local bg, bgHover, textCol, strokeCol, strokeT
                    if style == "ghost" then
                        bg = T.BgInput
                        bgHover = T.BgHover
                        textCol = T.Text
                        strokeCol = T.Stroke
                        strokeT = 0.4
                    elseif style == "soft" then
                        bg = T.BgHover
                        bgHover = Color3.fromRGB(48, 48, 54)
                        textCol = T.Text
                        strokeCol = T.Stroke
                        strokeT = 0.45
                    else
                        bg = accent
                        bgHover = T.AccentDim
                        textCol = Color3.new(1, 1, 1)
                        strokeCol = nil
                    end

                    local b = mk("TextButton", {
                        BackgroundColor3 = bg,
                        AutoButtonColor = false,
                        Text = "",
                        Size = UDim2.fromScale(1, 1),
                        Parent = row,
                    })
                    corner(b, 11)
                    if strokeCol then
                        stroke(b, strokeCol, 1, strokeT)
                    end

                    local inner = mk("Frame", {
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.new(1, -18, 1, -6),
                        Parent = b,
                    })
                    list(inner, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

                    local ih = makeIcon(inner, iconName, 15, textCol, 2)
                    ih.Size = UDim2.fromOffset(15, 15)
                    ih.LayoutOrder = 1

                    local labels = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(0, 0),
                        AutomaticSize = Enum.AutomaticSize.XY,
                        LayoutOrder = 2,
                        Parent = inner,
                    })
                    list(labels, Enum.FillDirection.Vertical, 1, Enum.HorizontalAlignment.Left)

                    mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Title,
                        TextSize = 13,
                        TextColor3 = textCol,
                        Text = o.Title or "Button",
                        Size = UDim2.fromOffset(0, 16),
                        AutomaticSize = Enum.AutomaticSize.X,
                        Parent = labels,
                    })
                    if not compactOn and o.Desc and o.Desc ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 11,
                            TextColor3 = style == "accent" and Color3.fromRGB(230, 220, 255) or T.TextMute,
                            TextTransparency = style == "accent" and 0.28 or 0,
                            Text = o.Desc,
                            Size = UDim2.fromOffset(0, 14),
                            AutomaticSize = Enum.AutomaticSize.X,
                            Parent = labels,
                        })
                    end

                    hover(b, function()
                        tween(b, TI(0.12), { BackgroundColor3 = bgHover })
                    end, function()
                        tween(b, TI(0.12), { BackgroundColor3 = bg })
                    end)
                    b.MouseButton1Click:Connect(function()
                        if o.Callback then task.spawn(o.Callback) end
                    end)
                    return b
                end

                -----------------------------------------------------------------
                -- Input
                -----------------------------------------------------------------
                function Section:Input(o)
                    o = o or {}
                    -- stacked full-width so long strings (URLs) don't blow the layout
                    addDivider()
                    rowOrder = rowOrder + 1
                    local row = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    pad(row, 6, 8, 6, 8)
                    list(row, Enum.FillDirection.Vertical, 5)
                    registerSearch(row, o.Title or "Input", o.Desc)

                    local inputHead = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 18),
                        LayoutOrder = 1,
                        Parent = row,
                    })
                    mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Title,
                        TextSize = 14,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = o.Title or "Input",
                        Size = UDim2.new(1, 0, 0, 18),
                        Parent = inputHead,
                    })
                    if not compactOn and o.Desc and o.Desc ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 11,
                            TextColor3 = T.TextMute,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextWrapped = true,
                            Text = o.Desc,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            LayoutOrder = 2,
                            Parent = row,
                        })
                    end

                    local boxHost = mk("Frame", {
                        BackgroundColor3 = T.BgInput,
                        Size = UDim2.new(1, 0, 0, 32),
                        ClipsDescendants = true,
                        LayoutOrder = 3,
                        Parent = row,
                    })
                    corner(boxHost, 8)
                    stroke(boxHost, Color3.fromRGB(48, 46, 58), 1, 0.5)

                    local box = mk("TextBox", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Body,
                        TextSize = 13,
                        TextColor3 = T.Text,
                        PlaceholderText = o.Placeholder or "...",
                        PlaceholderColor3 = T.TextMute,
                        Text = o.Value and tostring(o.Value) or "",
                        ClearTextOnFocus = false,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Size = UDim2.fromScale(1, 1),
                        Parent = boxHost,
                    })
                    pad(box, 0, 8, 0, 8)

                    local api = { Value = box.Text, Row = row }
                    box.FocusLost:Connect(function(enter)
                        api.Value = box.Text
                        if o.Callback then task.spawn(o.Callback, box.Text, enter) end
                    end)
                    function api:Set(v, silent)
                        box.Text = tostring(v or "")
                        self.Value = box.Text
                        if not silent and o.Callback then task.spawn(o.Callback, box.Text, false) end
                    end
                    function api:SetVisible(vis)
                        row.Visible = vis and true or false
                    end
                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                -----------------------------------------------------------------
                -- Keybind
                -----------------------------------------------------------------
                function Section:Keybind(o)
                    o = o or {}
                    local key = o.Value or Enum.KeyCode.Unknown
                    local _, _, right = makeRow(o.Title or "Keybind", o.Desc, o.Icon or o.Image)
                    right.Size = UDim2.fromOffset(110, 32)
                    local box = mk("TextButton", {
                        BackgroundColor3 = T.BgInput,
                        AutoButtonColor = false,
                        Font = Fonts.Body,
                        TextSize = 12,
                        TextColor3 = T.Text,
                        Text = key.Name or "None",
                        Size = UDim2.fromScale(1, 1),
                        Parent = right,
                    })
                    corner(box, 12)
                    stroke(box, T.Stroke, 1, 0.4)

                    local listening = false
                    local api = { Value = key }

                    local function setKey(k, silent)
                        key = k
                        api.Value = k
                        box.Text = (k and k.Name) or "None"
                        if o.WindowToggle and Window.SetToggleKey then
                            Window:SetToggleKey(k)
                        end
                        if not silent and o.Callback then task.spawn(o.Callback, k) end
                    end
                    api.Set = function(_, k, silent) setKey(k, silent) end

                    if o.WindowToggle and Window.SetToggleKey then
                        Window:SetToggleKey(key)
                    end

                    box.MouseButton1Click:Connect(function()
                        listening = true
                        box.Text = "..."
                        box.TextColor3 = accent
                    end)

                    UserInputService.InputBegan:Connect(function(input, gp)
                        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
                            listening = false
                            box.TextColor3 = T.Text
                            if input.KeyCode == Enum.KeyCode.Escape then
                                setKey(Enum.KeyCode.Unknown)
                            else
                                setKey(input.KeyCode)
                            end
                            return
                        end
                        -- Window toggle is handled by Window listener — don't double-fire Pressed
                        if o.WindowToggle then return end
                        if UserInputService:GetFocusedTextBox() then return end
                        if not listening and key and key ~= Enum.KeyCode.Unknown and input.KeyCode == key then
                            if o.Pressed then task.spawn(o.Pressed) end
                        end
                    end)

                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                -----------------------------------------------------------------
                -- Paragraph / Label
                -----------------------------------------------------------------
                function Section:Paragraph(o)
                    o = o or {}
                    addDivider()
                    rowOrder = rowOrder + 1
                    local row = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    pad(row, 8, 8, 8, 10)
                    list(row, Enum.FillDirection.Vertical, 3)
                    registerSearch(row, o.Title, o.Content or o.Desc)
                    if o.Title then
                        local pHead = mk("Frame", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 17),
                            LayoutOrder = 1,
                            Parent = row,
                        })
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Title,
                            TextSize = 14,
                            TextColor3 = T.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = o.Title,
                            Size = UDim2.new(1, 0, 0, 17),
                            Parent = pHead,
                        })
                    end
                    local body = mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Desc,
                        TextSize = 13,
                        TextColor3 = T.TextMute,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextWrapped = true,
                        Text = o.Content or o.Desc or "",
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = 2,
                        Parent = row,
                    })
                    return {
                        Set = function(_, text)
                            body.Text = tostring(text or "")
                        end,
                    }
                end

                function Section:Divider()
                    rowOrder = rowOrder + 1
                    local row = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 12),
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    mk("Frame", {
                        BackgroundColor3 = T.Divider,
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        Position = UDim2.fromScale(0.5, 0.5),
                        Size = UDim2.new(1, -12, 0, 1),
                        BorderSizePixel = 0,
                        Parent = row,
                    })
                end

                -----------------------------------------------------------------
                -- PriorityList — smooth drag-reorder (ghost + LayoutOrder swap)
                -----------------------------------------------------------------
                function Section:PriorityList(o)
                    o = o or {}
                    local items = {}
                    for i, v in ipairs(o.Values or {}) do
                        items[i] = v
                    end

                    local ROW_H = math.clamp(math.floor(tonumber(o.RowHeight) or 40), 32, 56)
                    local ROW_GAP = 4
                    local showItemIcons = o.ShowItemIcons ~= false -- default on; AE Auto Join sets false

                    addDivider()
                    rowOrder = rowOrder + 1
                    local wrap = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    pad(wrap, 6, 8, 8, 8)
                    list(wrap, Enum.FillDirection.Vertical, 4)
                    registerSearch(wrap, o.Title or "Priority", o.Desc)

                    if o.Title then
                        local head = mk("Frame", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 18),
                            Parent = wrap,
                        })
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Title,
                            TextSize = 14,
                            TextColor3 = T.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = o.Title,
                            Size = UDim2.new(1, 0, 0, 18),
                            Parent = head,
                        })
                    end
                    if not compactOn and o.Desc and o.Desc ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 11,
                            TextColor3 = T.TextMute,
                            TextWrapped = true,
                            Text = o.Desc,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Parent = wrap,
                        })
                    end

                    local function contentH(n)
                        n = math.max(tonumber(n) or 1, 1)
                        return n * ROW_H + math.max(0, n - 1) * ROW_GAP
                    end

                    local maxVis = tonumber(o.MaxVisible) or tonumber(o.VisibleRows)
                    local resizable = o.Resizable == true
                    local minH = tonumber(o.MinHeight) or contentH(3)
                    local maxH = tonumber(o.MaxHeight) or contentH(10)
                    local viewH = tonumber(o.Height)
                    if not viewH and maxVis then
                        viewH = contentH(maxVis)
                    end
                    local useScroll = viewH ~= nil or resizable
                    if useScroll and not viewH then
                        viewH = contentH(math.min(5, math.max(#items, 3)))
                    end
                    if viewH then
                        viewH = math.clamp(viewH, minH, maxH)
                    end

                    local scroll
                    local listFrame
                    if useScroll then
                        scroll = mk("ScrollingFrame", {
                            BackgroundTransparency = 1,
                            BorderSizePixel = 0,
                            Size = UDim2.new(1, 0, 0, viewH),
                            CanvasSize = UDim2.fromOffset(0, contentH(#items)),
                            ScrollBarThickness = 3,
                            ScrollBarImageColor3 = accent,
                            ScrollBarImageTransparency = 0.4,
                            ScrollingEnabled = true,
                            ClipsDescendants = true,
                            Parent = wrap,
                        })
                        styleScroll(scroll)
                        listFrame = mk("Frame", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Parent = scroll,
                        })
                    else
                        listFrame = mk("Frame", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            ClipsDescendants = false,
                            Parent = wrap,
                        })
                    end
                    list(listFrame, Enum.FillDirection.Vertical, ROW_GAP)

                    local api = { Values = items, Height = viewH, RowHeight = ROW_H }
                    local rowFrames = {}
                    local drag = {
                        active = false,
                        idx = 0,
                        ghost = nil,
                        grabDY = 0,
                    }

                    local function fire()
                        if o.Callback then task.spawn(o.Callback, items) end
                    end

                    local function paintRest(r, i, lit)
                        r.LayoutOrder = i
                        local num = r:FindFirstChild("Num")
                        if num then num.Text = "#" .. tostring(i) end
                        if lit then
                            r.BackgroundColor3 = T.BgHover
                            local st = r:FindFirstChildOfClass("UIStroke")
                            if st then
                                st.Color = T.Stroke
                                st.Transparency = 0.25
                            end
                        else
                            r.BackgroundColor3 = T.BgInput
                            local st = r:FindFirstChildOfClass("UIStroke")
                            if st then
                                st.Color = T.Stroke
                                st.Transparency = 0.5
                            end
                        end
                    end

                    local function syncOrders(litIdx)
                        for i, r in ipairs(rowFrames) do
                            paintRest(r, i, litIdx == i)
                        end
                        api.Values = items
                    end

                    local function moveItem(from, to)
                        if from == to or from < 1 or to < 1 or from > #items or to > #items then return end
                        local it = table.remove(items, from)
                        table.insert(items, to, it)
                        local rf = table.remove(rowFrames, from)
                        table.insert(rowFrames, to, rf)
                        syncOrders(to)
                    end

                    -- probe = จุดกลาง ghost (สิ่งที่ตาเห็น) ไม่ใช่แค่เมาส์
                    -- threshold ตามทิศ: ขึ้น/ลง swap ไว ไม่ต้องลากพ้น midpoint
                    local function probeY(mouseY)
                        if drag.ghost and drag.ghost.Parent then
                            return drag.ghost.AbsolutePosition.Y + drag.ghost.AbsoluteSize.Y * 0.5
                        end
                        return mouseY
                    end

                    local function nextTarget(py)
                        local i = drag.idx
                        if i > 1 then
                            local above = rowFrames[i - 1]
                            -- ลากขึ้น: แค่กลาง ghost โผล่เข้า ~78% ของแถวบน → สลับเลย
                            local thresh = above.AbsolutePosition.Y + above.AbsoluteSize.Y * 0.78
                            if py < thresh then
                                return i - 1
                            end
                        end
                        if i < #rowFrames then
                            local below = rowFrames[i + 1]
                            -- ลากลง: กลาง ghost แตะ ~22% ของแถวล่าง → สลับ
                            local thresh = below.AbsolutePosition.Y + below.AbsoluteSize.Y * 0.22
                            if py > thresh then
                                return i + 1
                            end
                        end
                        return i
                    end

                    local function clearGhost()
                        if drag.ghost then
                            drag.ghost:Destroy()
                            drag.ghost = nil
                        end
                    end

                    local function endDrag()
                        if not drag.active then return end
                        drag.active = false
                        clearGhost()
                        for i, r in ipairs(rowFrames) do
                            r.BackgroundTransparency = 0
                            local sc = r:FindFirstChild("DragScale")
                            if sc then sc:Destroy() end
                            paintRest(r, i, false)
                        end
                        fire()
                    end

                    local function startDrag(idx, input)
                        if drag.active or idx < 1 or idx > #rowFrames then return end
                        local src = rowFrames[idx]
                        drag.active = true
                        drag.idx = idx
                        -- sticky grab: offset จากมุมบนซ้ายแถว → เมาส์ (ไม่หักครึ่งสูงซ้ำ)
                        drag.grabOX = input.Position.X - src.AbsolutePosition.X
                        drag.grabOY = input.Position.Y - src.AbsolutePosition.Y

                        src.BackgroundTransparency = 0.55

                        local sg = listFrame:FindFirstAncestorOfClass("ScreenGui")
                        local ghostParent = sg or listFrame
                        local g = src:Clone()
                        g.Name = "VoidDragGhost"
                        g.BackgroundTransparency = 0.08
                        g.BackgroundColor3 = T.BgSection
                        g.Size = UDim2.fromOffset(src.AbsoluteSize.X, src.AbsoluteSize.Y)
                        g.AnchorPoint = Vector2.new(0, 0)
                        g.Parent = ghostParent
                        for _, d in ipairs(g:GetDescendants()) do
                            if d:IsA("GuiObject") then
                                d.ZIndex = (d.ZIndex or 1) + 800
                            end
                        end
                        g.ZIndex = 900
                        local gst = g:FindFirstChildOfClass("UIStroke")
                        if gst then
                            gst.Color = T.Stroke
                            gst.Transparency = 0.2
                            gst.Thickness = 1
                        end
                        local gsc = g:FindFirstChild("DragScale")
                        if gsc then gsc:Destroy() end
                        drag.ghost = g

                        local function screenToParent(sx, sy)
                            if ghostParent:IsA("ScreenGui") then
                                -- AbsolutePosition == ScreenGui coords เมื่อ IgnoreGuiInset
                                if ghostParent.IgnoreGuiInset then
                                    return sx, sy
                                end
                                local inset = GuiService:GetGuiInset()
                                return sx - inset.X, sy - inset.Y
                            end
                            local p = ghostParent.AbsolutePosition
                            return sx - p.X, sy - p.Y
                        end

                        local function setGhostPos(pos)
                            if not drag.ghost then return end
                            local px, py = screenToParent(pos.X - drag.grabOX, pos.Y - drag.grabOY)
                            drag.ghost.Position = UDim2.fromOffset(px, py)
                        end
                        setGhostPos(input.Position)
                        drag._setGhostPos = setGhostPos
                        syncOrders(idx)
                    end

                    local function onDragMove(input)
                        if not drag.active then return end
                        local pos = input.Position
                        if input.UserInputType == Enum.UserInputType.MouseMovement then
                            local m = UserInputService:GetMouseLocation()
                            pos = Vector3.new(m.X, m.Y, 0)
                        end
                        if drag._setGhostPos then drag._setGhostPos(pos) end
                        -- หลังวาง ghost แล้วค่อยวัด — ใช้กลาง ghost + threshold ไว
                        local target = nextTarget(probeY(pos.Y))
                        if target ~= drag.idx then
                            moveItem(drag.idx, target)
                            drag.idx = target
                        end
                    end

                    local function buildRows()
                        clearGhost()
                        drag.active = false
                        for _, r in ipairs(rowFrames) do
                            if r and r.Parent then r:Destroy() end
                        end
                        for i = #rowFrames, 1, -1 do rowFrames[i] = nil end

                        for i, v in ipairs(items) do
                            local r = mk("TextButton", {
                                BackgroundColor3 = T.BgInput,
                                AutoButtonColor = false,
                                Text = "",
                                Size = UDim2.new(1, 0, 0, ROW_H),
                                LayoutOrder = i,
                                Parent = listFrame,
                            })
                            corner(r, rCtrl)
                            stroke(r, T.Stroke, 1, 0.5)
                            rowFrames[i] = r

                            local grip = makeIcon(r, "lucide:grip-vertical", 14, T.TextMute, 2)
                            grip.AnchorPoint = Vector2.new(0, 0.5)
                            grip.Position = UDim2.new(0, 8, 0.5, 0)

                            local left = 28
                            if showItemIcons then
                                local asset = entryAsset(v) or normalizeAsset(type(v) == "table" and (v.Image or v.Icon))
                                if asset then
                                    local ic = makeIcon(r, asset, 16, T.Text, 2)
                                    ic.AnchorPoint = Vector2.new(0, 0.5)
                                    ic.Position = UDim2.new(0, 26, 0.5, 0)
                                    left = 48
                                end
                            end

                            mk("TextLabel", {
                                Name = "Num",
                                BackgroundTransparency = 1,
                                Font = Fonts.Title,
                                TextSize = 11,
                                TextColor3 = T.TextMute,
                                Text = "#" .. i,
                                AnchorPoint = Vector2.new(0, 0.5),
                                Position = UDim2.new(0, left, 0.5, 0),
                                Size = UDim2.fromOffset(28, 16),
                                ZIndex = 2,
                                Parent = r,
                            })
                            mk("TextLabel", {
                                Name = "Label",
                                BackgroundTransparency = 1,
                                Font = Fonts.Body,
                                TextSize = 13,
                                TextColor3 = T.Text,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextTruncate = Enum.TextTruncate.AtEnd,
                                Text = entryLabel(v),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Position = UDim2.new(0, left + 28, 0.5, 0),
                                Size = UDim2.new(1, -(left + 38), 0, 18),
                                ZIndex = 2,
                                Parent = r,
                            })

                            r.InputBegan:Connect(function(input)
                                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                                    and input.UserInputType ~= Enum.UserInputType.Touch then
                                    return
                                end
                                local live = r.LayoutOrder
                                startDrag(live, input)
                            end)

                            r.MouseEnter:Connect(function()
                                if drag.active then return end
                                tween(r, TI(0.1), { BackgroundColor3 = T.BgHover })
                            end)
                            r.MouseLeave:Connect(function()
                                if drag.active then return end
                                tween(r, TI(0.1), { BackgroundColor3 = T.BgInput })
                            end)
                        end
                        api.Values = items
                        if scroll then
                            local h = contentH(#items)
                            scroll.CanvasSize = UDim2.fromOffset(0, h)
                            scroll.ScrollingEnabled = h > (scroll.AbsoluteSize.Y > 0 and scroll.AbsoluteSize.Y or (viewH or 0))
                        end
                    end

                    local function applyViewH(h)
                        if not scroll then return end
                        viewH = math.clamp(math.floor(tonumber(h) or viewH or minH), minH, maxH)
                        api.Height = viewH
                        scroll.Size = UDim2.new(1, 0, 0, viewH)
                        local ch = contentH(#items)
                        scroll.CanvasSize = UDim2.fromOffset(0, ch)
                        scroll.ScrollingEnabled = ch > viewH
                        if o.OnResize then task.spawn(o.OnResize, viewH) end
                    end

                    UserInputService.InputChanged:Connect(function(input)
                        if not drag.active then return end
                        if input.UserInputType ~= Enum.UserInputType.MouseMovement
                            and input.UserInputType ~= Enum.UserInputType.Touch then
                            return
                        end
                        onDragMove(input)
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if not drag.active then return end
                        if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                            endDrag()
                        end
                    end)

                    function api:Set(listVals, silent)
                        items = {}
                        for i, v in ipairs(listVals or {}) do items[i] = v end
                        buildRows()
                        if not silent then fire() end
                    end
                    function api:Get()
                        return items
                    end
                    function api:SetHeight(h, silent)
                        applyViewH(h)
                        if not silent and o.OnResize then task.spawn(o.OnResize, api.Height) end
                    end
                    function api:GetHeight()
                        return api.Height
                    end

                    buildRows()

                    -- Bottom grip — thin hit area (PriorityList resize)
                    if resizable and scroll then
                        local grip = mk("TextButton", {
                            BackgroundTransparency = 1,
                            AutoButtonColor = false,
                            Text = "",
                            Size = UDim2.new(1, 0, 0, 10),
                            Parent = wrap,
                        })
                        mk("Frame", {
                            BackgroundColor3 = accent,
                            BackgroundTransparency = 0.55,
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            Position = UDim2.fromScale(0.5, 0.5),
                            Size = UDim2.fromOffset(28, 2),
                            BorderSizePixel = 0,
                            Parent = grip,
                        })
                        local resizing = false
                        local startY, startH = 0, viewH or minH
                        grip.InputBegan:Connect(function(input)
                            if input.UserInputType ~= Enum.UserInputType.MouseButton1
                                and input.UserInputType ~= Enum.UserInputType.Touch then
                                return
                            end
                            resizing = true
                            startY = input.Position.Y
                            startH = viewH or scroll.AbsoluteSize.Y
                        end)
                        UserInputService.InputChanged:Connect(function(input)
                            if not resizing then return end
                            if input.UserInputType ~= Enum.UserInputType.MouseMovement
                                and input.UserInputType ~= Enum.UserInputType.Touch then
                                return
                            end
                            applyViewH(startH + (input.Position.Y - startY))
                        end)
                        UserInputService.InputEnded:Connect(function(input)
                            if not resizing then return end
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                                or input.UserInputType == Enum.UserInputType.Touch then
                                resizing = false
                            end
                        end)
                    end

                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                -- Item / progress rows (icon + name + right text). Refresh with api:Set.
                function Section:Panel(o)
                    o = o or {}
                    local items = {}
                    for i, v in ipairs(o.Values or {}) do
                        items[i] = v
                    end
                    local ROW_H = math.clamp(math.floor(tonumber(o.RowHeight) or 44), 36, 64)

                    addDivider()
                    rowOrder = rowOrder + 1
                    local wrap = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        LayoutOrder = rowOrder,
                        Parent = card,
                    })
                    pad(wrap, 6, 8, 8, 8)
                    list(wrap, Enum.FillDirection.Vertical, 4)
                    registerSearch(wrap, o.Title or "Panel", o.Desc)

                    if o.Title then
                        local head = mk("Frame", {
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, 18),
                            Parent = wrap,
                        })
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Title,
                            TextSize = 14,
                            TextColor3 = T.Text,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Text = o.Title,
                            Size = UDim2.new(1, 0, 0, 18),
                            Parent = head,
                        })
                    end
                    if not compactOn and o.Desc and o.Desc ~= "" then
                        mk("TextLabel", {
                            BackgroundTransparency = 1,
                            Font = Fonts.Desc,
                            TextSize = 11,
                            TextColor3 = T.TextMute,
                            TextWrapped = true,
                            Text = o.Desc,
                            Size = UDim2.new(1, 0, 0, 0),
                            AutomaticSize = Enum.AutomaticSize.Y,
                            Parent = wrap,
                        })
                    end

                    local listHost = mk("Frame", {
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        Parent = wrap,
                    })
                    list(listHost, Enum.FillDirection.Vertical, 4)

                    local emptyLab = mk("TextLabel", {
                        BackgroundTransparency = 1,
                        Font = Fonts.Desc,
                        TextSize = 12,
                        TextColor3 = T.TextMute,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = o.EmptyText or "Nothing selected",
                        Size = UDim2.new(1, 0, 0, 18),
                        Visible = #items == 0,
                        Parent = wrap,
                    })

                    local api = { Values = items, Flag = o.Flag }

                    local function rowName(v)
                        if type(v) == "table" then
                            return tostring(v.Name or v.Title or v.Id or "")
                        end
                        return tostring(v or "")
                    end
                    local function rowRight(v)
                        if type(v) == "table" then
                            return tostring(v.Right or v.Value or "")
                        end
                        return ""
                    end
                    local function rowSub(v)
                        if type(v) == "table" then
                            return tostring(v.Sub or v.Desc or "")
                        end
                        return ""
                    end

                    local function buildRows()
                        for _, ch in ipairs(listHost:GetChildren()) do
                            if ch:IsA("GuiObject") then ch:Destroy() end
                        end
                        emptyLab.Visible = #items == 0
                        for i, v in ipairs(items) do
                            local sub = rowSub(v)
                            local h = (sub ~= "" and ROW_H) or math.max(36, ROW_H - 6)
                            local r = mk("Frame", {
                                BackgroundColor3 = T.BgInput,
                                Size = UDim2.new(1, 0, 0, h),
                                LayoutOrder = i,
                                Parent = listHost,
                            })
                            corner(r, rCtrl)
                            stroke(r, T.Stroke, 1, 0.5)
                            local left = 10
                            local asset = entryAsset(v)
                            if asset then
                                local ic = makeIcon(r, asset, 22, T.Text, 2)
                                ic.AnchorPoint = Vector2.new(0, 0.5)
                                ic.Position = UDim2.new(0, 10, 0.5, 0)
                                left = 40
                            end
                            local rightTxt = rowRight(v)
                            local rightW = 0
                            if rightTxt ~= "" then
                                local rl = mk("TextLabel", {
                                    BackgroundTransparency = 1,
                                    Font = Fonts.Title,
                                    TextSize = 12,
                                    TextColor3 = T.TextDim,
                                    TextXAlignment = Enum.TextXAlignment.Right,
                                    Text = rightTxt,
                                    AnchorPoint = Vector2.new(1, 0.5),
                                    Position = UDim2.new(1, -10, 0.5, sub ~= "" and -6 or 0),
                                    Size = UDim2.fromOffset(88, 16),
                                    Parent = r,
                                })
                                rightW = 96
                            end
                            mk("TextLabel", {
                                BackgroundTransparency = 1,
                                Font = Fonts.Body,
                                TextSize = 13,
                                TextColor3 = T.Text,
                                TextXAlignment = Enum.TextXAlignment.Left,
                                TextTruncate = Enum.TextTruncate.AtEnd,
                                Text = rowName(v),
                                AnchorPoint = Vector2.new(0, 0.5),
                                Position = UDim2.new(0, left, 0.5, sub ~= "" and -7 or 0),
                                Size = UDim2.new(1, -(left + rightW + 4), 0, 16),
                                Parent = r,
                            })
                            if sub ~= "" then
                                mk("TextLabel", {
                                    BackgroundTransparency = 1,
                                    Font = Fonts.Desc,
                                    TextSize = 11,
                                    TextColor3 = T.TextMute,
                                    TextXAlignment = Enum.TextXAlignment.Left,
                                    TextTruncate = Enum.TextTruncate.AtEnd,
                                    Text = sub,
                                    AnchorPoint = Vector2.new(0, 1),
                                    Position = UDim2.new(0, left, 1, -6),
                                    Size = UDim2.new(1, -(left + 10), 0, 14),
                                    Parent = r,
                                })
                            end
                        end
                        api.Values = items
                    end

                    function api:Set(listVals, _silent)
                        items = {}
                        for i, v in ipairs(listVals or {}) do items[i] = v end
                        buildRows()
                    end
                    function api:Get()
                        return items
                    end

                    buildRows()
                    if o.Flag then Window._flags[o.Flag] = api end
                    return api
                end

                return Section
            end

            -- Hidden pages (Popup host) stay off the subtab bar
            if popts.Hidden then
                return Page
            end
            -- convenience: Tab:Section goes to first/default page
            table.insert(Tab._pages, Page)
            if not Tab._activePage then
                Tab._activePage = Page
                Page.Frame.Visible = true
                Page._active = true
            end
            -- Tab() with Selected=true runs SelectTab before any Page exists,
            -- so subtabs never appear until user re-clicks. Refresh when pages grow.
            if Window._activeTab == Tab then
                if #Tab._pages >= 2 then
                    Window:SelectTab(Tab)
                elseif #Tab._pages == 1 then
                    Tab:SelectPage(Page)
                end
            end
            return Page
        end

        -- Tab:Section → auto page
        function Tab:Section(sopts)
            if #self._pages == 0 then
                self:Page({ Title = self.Title })
            end
            return self._pages[1]:Section(sopts)
        end

        btn.MouseButton1Click:Connect(function()
            Window:SelectTab(Tab)
        end)

        table.insert(Window._tabs, Tab)
        if selected or #Window._tabs == 1 then
            -- defer so Pages added right after Tab() are visible to SelectTab
            task.defer(function()
                if Tab.Host and Tab.Host.Parent then
                    Window:SelectTab(Tab)
                end
            end)
        else
            Tab:_setActive(false)
        end
        return Tab
    end

    -- Config helpers
    function Window:GetFlag(name)
        return self._flags[name]
    end

    function Window:SaveConfig(name)
        if not (writefile and folder) then return false end
        local data = {}
        for flag, api in pairs(self._flags) do
            if api and api.Value ~= nil then
                local v = api.Value
                if typeof(v) == "EnumItem" then
                    data[flag] = { __enum = v.EnumType.Name, name = v.Name }
                else
                    data[flag] = v
                end
            end
        end
        pcall(function()
            if makefolder and not isfolder(folder) then makefolder(folder) end
            writefile(folder .. "/" .. (name or "config") .. ".json", HttpService:JSONEncode(data))
        end)
        return true
    end

    function Window:LoadConfig(name)
        if not (readfile and isfile and folder) then return false end
        local path = folder .. "/" .. (name or "config") .. ".json"
        if not isfile(path) then return false end
        local ok, raw = pcall(readfile, path)
        if not ok then return false end
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if not ok2 or type(data) ~= "table" then return false end
        for flag, val in pairs(data) do
            local api = self._flags[flag]
            if api and api.Set then
                if type(val) == "table" and val.__enum then
                    local enumType = Enum[val.__enum]
                    if enumType then
                        pcall(function() api:Set(enumType[val.name], true) end)
                    end
                else
                    pcall(function() api:Set(val, true) end)
                end
            end
        end
        return true
    end

    ---------------------------------------------------------------------------
    -- Popup / Modal (settings-style floating page)
    ---------------------------------------------------------------------------
    function Window:Popup(opts)
        opts = opts or {}
        local pTitle = opts.Title or "Settings"
        local pIcon = opts.Icon or "lucide:settings"
        local pSize = opts.Size or UDim2.fromOffset(420, 480)

        local overlay = mk("TextButton", {
            Name = "PopupOverlay",
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.45,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 700,
            Parent = screen,
        })

        local panel = mk("Frame", {
            Name = "Popup",
            BackgroundColor3 = T.Bg,
            BackgroundTransparency = math.clamp(glass, 0.02, 0.12),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = pSize,
            ZIndex = 710,
            Parent = screen,
        })
        corner(panel, rWin)
        stroke(panel, T.Stroke, 1, 0.4)

        local header = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 48),
            ZIndex = 711,
            Parent = panel,
        })
        pad(header, 0, 14, 0, 14)
        local ih = makeIcon(header, pIcon, 16, T.TextDim, 712)
        ih.Position = UDim2.fromOffset(0, 16)
        mk("TextLabel", {
            BackgroundTransparency = 1,
            Font = Fonts.Title,
            TextSize = 15,
            TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Text = pTitle,
            Position = UDim2.fromOffset(24, 14),
            Size = UDim2.new(1, -64, 0, 22),
            ZIndex = 712,
            Parent = header,
        })
        local closeBtn = mk("TextButton", {
            BackgroundColor3 = T.BgInput,
            AutoButtonColor = false,
            Text = "",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(28, 28),
            ZIndex = 712,
            Parent = header,
        })
        corner(closeBtn, rCtrl)
        local cx = makeIcon(closeBtn, "lucide:x", 14, T.TextDim, 713)
        cx.AnchorPoint = Vector2.new(0.5, 0.5)
        cx.Position = UDim2.fromScale(0.5, 0.5)

        mk("Frame", {
            BackgroundColor3 = T.Stroke,
            BackgroundTransparency = 0.55,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 14, 0, 48),
            Size = UDim2.new(1, -28, 0, 1),
            ZIndex = 711,
            Parent = panel,
        })

        local body = mk("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 52),
            Size = UDim2.new(1, 0, 1, -60),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 711,
            Parent = panel,
        })
        styleScroll(body)
        pad(body, 12, 14, 18, 14)
        list(body, Enum.FillDirection.Vertical, 10)

        local Popup = {
            Title = pTitle,
            Frame = panel,
            Body = body,
            _closed = false,
        }

        local function destroy()
            if Popup._closed then return end
            Popup._closed = true
            overlay:Destroy()
            panel:Destroy()
            if opts.OnClose then task.spawn(opts.OnClose) end
        end
        Popup.Close = destroy
        Popup.Destroy = destroy
        closeBtn.MouseButton1Click:Connect(destroy)
        if opts.CloseOnOverlay ~= false then
            overlay.MouseButton1Click:Connect(destroy)
        end

        -- Isolated hidden page so Popup sections never land on Auto Join / first Farm page
        function Popup:Section(sopts)
            sopts = sopts or {}
            local secTitle = prettySectionTitle(sopts.Title or "Section")
            local hostTab = Window._tabs[1]
            if not hostTab then
                return nil
            end
            if not Window._popupHostPage then
                Window._popupHostPage = hostTab:Page({ Title = "_popup_host", Hidden = true })
            end
            local real = Window._popupHostPage:Section({
                Title = secTitle,
                Column = 1,
                Icon = sopts.Icon or sopts.Image,
            })
            if real and real.Frame and real.Frame.Parent then
                local secWrap = real.Frame.Parent
                if secWrap and secWrap:IsA("GuiObject") then
                    secWrap.Parent = body
                end
            end
            return real
        end

        return Popup
    end

    table.insert(VoidUI._windows, Window)

    if cfg.OpenCallback then
        task.spawn(cfg.OpenCallback, Window)
    end

    return Window
end

function VoidUI:SetAccent(color)
    Theme.Accent = color
end

return VoidUI
