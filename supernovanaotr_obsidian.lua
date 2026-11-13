local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

repeat task.wait() until Players.LocalPlayer

local player = Players.LocalPlayer
local success, result = pcall(function()
    return player:GetMouse()
end)

local mouse = success and result or nil

-- ============================================================
--  OBSIDIAN UI (deividcomsono/Obsidian)
--  A small helper layer below maps Tabs.X:AddToggle / AddSlider /
--  AddDropdown ... onto Obsidian groupboxes.
-- ============================================================
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local ObsidianWindow = Library:CreateWindow({
    Title = "Aotr:update5",
    Footer = "Attack on Titan: Revolution",
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(640, 480),
    Center = true,
    AutoShow = true,
})

local Notifier = {}
function Notifier:Notify(o)
    pcall(function()
        Library:Notify({
            Title = o.Title or "",
            Description = o.Content or "",
            Time = o.Duration or 4,
        })
    end)
end

-- Tab wrapper -> Obsidian tab. Each AddSection() starts a new groupbox,
-- alternating left/right. Controls added before any section go in a groupbox
-- named after the tab.
local function MakeTab(rawTab, title)
    local tab = { _tab = rawTab, _count = 0, _box = nil }

    local function newBox(name)
        tab._count += 1
        if tab._count % 2 == 1 then
            tab._box = rawTab:AddLeftGroupbox(name)
        else
            tab._box = rawTab:AddRightGroupbox(name)
        end
        return tab._box
    end
    local function box() return tab._box or newBox(title) end
    local function note(o)
        if o.Description and o.Description ~= "" then box():AddLabel(o.Description, true) end
    end

    function tab:AddSection(name) newBox(name) end

    function tab:AddToggle(idx, o)
        local t = box():AddToggle(idx, { Text = o.Title, Default = o.Default or false, Callback = o.Callback })
        note(o)
        return t
    end

    function tab:AddSlider(idx, o)
        local s = box():AddSlider(idx, {
            Text = o.Title, Default = o.Default, Min = o.Min, Max = o.Max,
            Rounding = o.Rounding or 0, Callback = o.Callback,
        })
        note(o)
        return s
    end

    function tab:AddDropdown(idx, o)
        local multi = o.Multi == true
        local info = { Text = o.Title, Values = o.Values or {}, Multi = multi, Callback = o.Callback }
        if not multi then info.Default = o.Default end
        local dd = box():AddDropdown(idx, info)
        if multi and type(o.Default) == "table" then
            local map = {}
            for k, v in pairs(o.Default) do
                if type(k) == "number" then map[v] = true elseif v then map[k] = true end
            end
            if next(map) then pcall(function() dd:SetValue(map) end) end
        end
        note(o)
        return dd
    end

    function tab:AddInput(idx, o)
        return box():AddInput(idx, {
            Text = o.Title, Default = o.Default or "", Placeholder = o.Placeholder or "",
            Numeric = o.Numeric or false, Finished = o.Finished or false, Callback = o.Callback,
        })
    end

    function tab:AddButton(o)
        local b = box():AddButton({ Text = o.Title, Func = o.Callback })
        note(o)
        return b
    end

    function tab:AddColorpicker(idx, o)
        local lbl = box():AddLabel(o.Title or "Color")
        local picker = lbl:AddColorPicker(idx, { Default = o.Default or Color3.new(1, 1, 1), Title = o.Title })
        local wrap = { _p = picker }
        function wrap:OnChanged(fn)
            pcall(function() picker:OnChanged(fn) end)
        end
        function wrap:SetValueRGB(c)
            local ok = pcall(function() picker:SetValueRGB(c) end)
            if not ok then
                pcall(function() picker:SetValue({ Color3.toHSV(c) }) end)
            end
        end
        return wrap
    end

    -- Paragraph -> wrapped label (keeps :SetDesc / .DescLabel for the Account tab).
    function tab:AddParagraph(o)
        local ttl, content = o.Title or "", o.Content or ""
        local function render(c)
            if ttl == "" then return c end
            if c:find("\n") or #c > 40 then return ttl .. "\n" .. c end
            return ttl .. ": " .. c
        end
        local lbl = box():AddLabel(render(content), true)
        local p = { DescLabel = lbl and lbl.TextLabel }
        function p:SetDesc(c) pcall(function() lbl:SetText(render(tostring(c))) end) end
        function p:SetTitle(t) ttl = t end
        return p
    end

    return tab
end

local Window = {}
Window.Root = setmetatable({}, {
    __index = function(_, k) if k == "Visible" then return Library.Toggled end end,
    __newindex = function(_, k, v)
        if k == "Visible" and Library.Toggled ~= v then pcall(function() Library:Toggle() end) end
    end,
})
function Window:AddTab(o)
    local raw
    local icon = (o.Icon and o.Icon ~= "") and o.Icon or nil
    local ok = pcall(function() raw = ObsidianWindow:AddTab(o.Title, icon) end)
    if not ok or not raw then raw = ObsidianWindow:AddTab(o.Title) end
    return MakeTab(raw, o.Title)
end
function Window:Minimize(force)
    pcall(function()
        if force == true then
            if Library.Toggled then Library:Toggle() end
        else
            Library:Toggle()
        end
    end)
end
function Window:SelectTab(tab) pcall(function() tab._tab:Show() end) end

local TrayIcon = {}
TrayIcon.isVisible = true
TrayIcon.connection = nil

function TrayIcon:CreateIcon()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrayIconGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "TrayIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(1, -60, 0, 10)
    iconFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = iconFrame

    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.Position = UDim2.new(0, 0, 0, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "A"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.TextScaled = true
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconFrame

    local hoverTween = nil
    iconFrame.MouseEnter:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(16, 110, 190)}
        )
        hoverTween:Play()
    end)

    iconFrame.MouseLeave:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = Color3.fromRGB(0, 120, 212)}
        )
        hoverTween:Play()
    end)

    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.Position = UDim2.new(0, 0, 0, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = iconFrame

    clickDetector.MouseButton1Click:Connect(function()
        self:ToggleUI()
        local clickTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Size = UDim2.new(0, 45, 0, 45)}
        )
        clickTween:Play()
        clickTween.Completed:Connect(function()
            local returnTween = TweenService:Create(iconFrame,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 50, 0, 50)}
            )
            returnTween:Play()
        end)
    end)

    self.gui = screenGui
    self.frame = iconFrame
    self.text = iconText
    self:CreateTooltip()
end

function TrayIcon:CreateTooltip()
    local tooltip = Instance.new("Frame")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 200, 0, 30)
    tooltip.Position = UDim2.new(1, -210, 0.5, -15)
    tooltip.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.Parent = self.frame

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 5)
    tooltipCorner.Parent = tooltip

    local tooltipText = Instance.new("TextLabel")
    tooltipText.Size = UDim2.new(1, -10, 1, 0)
    tooltipText.Position = UDim2.new(0, 5, 0, 0)
    tooltipText.BackgroundTransparency = 1
    tooltipText.Text = "Click to toggle UI visibility"
    tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipText.TextScaled = true
    tooltipText.Font = Enum.Font.Gotham
    tooltipText.Parent = tooltip

    self.frame.MouseEnter:Connect(function() tooltip.Visible = true end)
    self.frame.MouseLeave:Connect(function() tooltip.Visible = false end)
end

function TrayIcon:ToggleUI()
    if self.isVisible then self:HideUI() else self:ShowUI() end
end

function TrayIcon:HideUI()
    if Window and Window.Root then
        Window.Root.Visible = false
        self.isVisible = false
        self.text.Text = "H"
        self.frame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        Notifier:Notify({ Title = "UI Hidden", Content = "Click the tray icon to show UI again", Duration = 3 })
    end
end

function TrayIcon:ShowUI()
    if Window and Window.Root then
        Window.Root.Visible = true
        self.isVisible = true
        self.text.Text = "A"
        self.frame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
        Notifier:Notify({ Title = "UI Shown", Content = "UI is now visible", Duration = 2 })
    end
end

TrayIcon:CreateIcon()

--//==============================\\--
--||         TABS SETUP           ||--
--\\==============================//--

local EarlyAccountTab = Window:AddTab({ Title = "Account", Icon = "user" })

local Tabs = {
    Main          = Window:AddTab({ Title = "Main(Risky)",               Icon = "swords" }),
    Glide         = Window:AddTab({ Title = "Gliding Mode",              Icon = "wind" }),
    AutoJoin      = Window:AddTab({ Title = "Auto Join",                 Icon = "door-open" }),
    Servers       = Window:AddTab({ Title = "Servers",                   Icon = "server" }),
    Misc          = Window:AddTab({ Title = "Misc",                      Icon = "wrench" }),
    Esp           = Window:AddTab({ Title = "Titans Esp",                Icon = "eye" }),
    Webhook       = Window:AddTab({ Title = "Webhook",                   Icon = "webhook" }),
    Settings      = Window:AddTab({ Title = "Settings",                  Icon = "settings" }),
}

--//==============================\\--
--||         SETTINGS TAB         ||--
--\\==============================//--

Tabs.Settings:AddToggle("TrayIconToggle", {
    Title = "Show Tray Icon",
    Description = "Show/Hide the system tray icon",
    Default = true,
    Callback = function(state)
        if TrayIcon.gui then TrayIcon.gui.Enabled = state end
    end
})

Tabs.Settings:AddParagraph({
    Title = "Tray Icon Usage",
    Content = "• The tray icon appears in the top-right corner\n• Click it to hide/show the UI\n• Red icon = UI hidden, Blue icon = UI visible\n• Ctrl+H (keyboard) or double-tap the screen (mobile) also toggles the UI"
})

--//==============================\\--
--||       MAINMENU (PlaceId)     ||--
--\\==============================//--

local allowedPlaceId = 13379208636
if game.PlaceId == allowedPlaceId then
    Tabs.Mainmenu = Window:AddTab({ Title = "Mainmenu", Icon = "house" })
    Tabs.Mainmenu:AddToggle("AutoRollToggle", {
        Title = "Auto Roll",
        Default = false,
        Callback = function(state) ENABLED = state end
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        TrayIcon:ToggleUI()
    end
end)

game.Players.PlayerRemoving:Connect(function(plr)
    if plr == player and TrayIcon.gui then TrayIcon.gui:Destroy() end
end)

--------------------------------------------------------------------------

local HttpService     = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput    = game:GetService("VirtualInputManager")
local GuiService      = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local char = player.Character or player.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

local retryRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local isFlying   = false
local bodyPos
local LocalPlayer = Players.LocalPlayer
local startDelay  = 0
local flyHeight   = 120

--//==============================\\--
--||      👑 AUTO KILL TITANS     ||--
--\\==============================//--

local Services = {
    Players         = game:GetService("Players"),
    RunService      = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService    = game:GetService("TweenService"),
    CoreGui         = game:GetService("CoreGui")
}

local Player = {
    self      = Services.Players.LocalPlayer,
    character = nil,
    hrp       = nil,
    gui       = nil
}

local Config = {
    flySpeed              = 250,
    canHit                = true,
    isFlying              = false,
    moveMode              = "Teleportation",
    notificationsEnabled  = true,
    startDelay            = 0,
    flyHeight             = 120,
    orbitRadius           = 20,   -- studs (slider 10-100)
    orbitSpeed            = 2,    -- radians per second
    orbitAngle            = 0,
    orbitEnabled          = true,
    waveEnabled           = false,
    waveAmp               = 15,   -- studs up/down (slider 5-60)
    waveWidth             = 20,   -- studs left/right (slider 0-80)
    waveSpeed             = 3,    -- radians per second
    waveTime              = 0,
    titanKillCount        = 0,
    autoRefill            = false,
    lastBladesEmpty       = false,
    lastSpearsEmpty       = false
}

local Data = {
    notified    = {},
    activeNotifs = {},
    POST        = nil,
    refill      = nil
}

Player.character = Player.self.Character or Player.self.CharacterAdded:Wait()
Player.hrp       = Player.character:WaitForChild("HumanoidRootPart")
Player.gui       = Player.self:WaitForChild("PlayerGui")

task.spawn(function()
    local success2, result2 = pcall(function()
        return Services.ReplicatedStorage:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("POST", 10)
    end)
    Data.POST = success2 and result2 or nil
end)

function showKillNotification(count)
    if not Config.notificationsEnabled then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TN_" .. tick()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Services.CoreGui
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 190, 0, 75)
    frame.Position = UDim2.new(1, 20, 0, 10 + (#Data.activeNotifs * 80))
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(184, 164, 101)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Successfully\nHit:"
    label.TextColor3 = Color3.fromRGB(184, 164, 101)
    label.Font = Enum.Font.Fantasy
    label.TextScaled = true
    local counter = Instance.new("TextLabel", frame)
    counter.Size = UDim2.new(0, 60, 0.5, 0)
    counter.Position = UDim2.new(1, -65, 0, 0)
    counter.BackgroundTransparency = 1
    counter.Text = tostring(count)
    counter.TextColor3 = Color3.fromRGB(255, 255, 255)
    counter.Font = Enum.Font.Fantasy
    counter.TextScaled = true
    table.insert(Data.activeNotifs, gui)
    Services.TweenService:Create(frame, TweenInfo.new(0.35), {
        Position = UDim2.new(1, -210, 0, 10 + ((#Data.activeNotifs - 1) * 80))
    }):Play()
    task.delay(5, function()
        gui:Destroy()
        for i, v in ipairs(Data.activeNotifs) do
            if v == gui then table.remove(Data.activeNotifs, i) break end
        end
    end)
end

local TITAN_PRIORITY = { "Attack_Titan", "Female_Titan", "Armored_Titan" }

local function napeOf(titan)
    local hb = titan:FindFirstChild("Hitboxes")
    local hit = hb and hb:FindFirstChild("Hit")
    return hit and hit:FindFirstChild("Nape")
end

local function isAlive(titan)
    local h = titan:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

-- keep the character reference fresh after respawn (the old code kept a dead HRP)
Player.self.CharacterAdded:Connect(function(c)
    Player.character = c
    Player.hrp = c:WaitForChild("HumanoidRootPart")
end)

local targetList, lastScan = {}, 0

local function scanTargets()
    table.clear(targetList)
    local folder = workspace:FindFirstChild("Titans")
    if not folder or not Player.hrp then return end
    local pos = Player.hrp.Position
    for _, name in ipairs(TITAN_PRIORITY) do
        local t = folder:FindFirstChild(name)
        if t and isAlive(t) then
            local n = napeOf(t)
            if n then targetList[#targetList + 1] = n end
        end
    end
    local others = {}
    for _, t in ipairs(folder:GetChildren()) do
        if not table.find(TITAN_PRIORITY, t.Name) and isAlive(t) then
            local n = napeOf(t)
            if n then others[#others + 1] = { n, (pos - n.Position).Magnitude } end
        end
    end
    table.sort(others, function(a, b) return a[2] < b[2] end)
    for _, o in ipairs(others) do targetList[#targetList + 1] = o[1] end
end

-- target list is rebuilt at most 10x/second instead of every frame
function getClosestValidNape()
    local first = targetList[1]
    if os.clock() - lastScan > 0.1 or not first or not first.Parent then
        scanTargets()
        lastScan = os.clock()
    end
    return targetList[1]
end

Config.hitCooldown = 0.12   -- seconds between hit bursts (was 0.25)
Config.multiHit    = 8      -- napes hit per burst (was 3)
Config.hitAll      = false  -- true = every alive titan gets hit in the same burst

local killConnection
local killStartAt = 0

Config.baseStartDelay = 5   -- fixed 5 second wait before farming begins (slider adds on top)

function killFromAbove()
    killStartAt = os.clock() + Config.baseStartDelay + Config.startDelay
    if killConnection then return end -- one connection only (old code stacked a new one on every toggle)
    killConnection = Services.RunService.Heartbeat:Connect(function(dt)
        if not Config.isFlying or Config.missionDone or os.clock() < killStartAt then return end
        local hrp = Player.hrp
        if not hrp or not hrp.Parent then return end
        local nape = getClosestValidNape()
        if not nape then return end
        local offX, offZ, offY = 0, 0, 0
        if Config.orbitEnabled then
            Config.orbitAngle = (Config.orbitAngle + (dt or 0.016) * Config.orbitSpeed) % (math.pi * 2)
            offX = math.cos(Config.orbitAngle) * Config.orbitRadius
            offZ = math.sin(Config.orbitAngle) * Config.orbitRadius
        end
        if Config.waveEnabled then
            Config.waveTime = (Config.waveTime + (dt or 0.016) * Config.waveSpeed) % (math.pi * 2)
            offY = math.sin(Config.waveTime) * Config.waveAmp
            -- sideways sway (left/right of the camera) at half speed = snake-like weave
            local cam = workspace.CurrentCamera
            if cam and Config.waveWidth > 0 then
                local r = cam.CFrame.RightVector
                r = Vector3.new(r.X, 0, r.Z)
                if r.Magnitude > 0.01 then
                    local side = math.sin(Config.waveTime * 0.5) * Config.waveWidth
                    offX = offX + r.Unit.X * side
                    offZ = offZ + r.Unit.Z * side
                end
            end
        end
        local targetPos = nape.Position + Vector3.new(offX, Config.flyHeight + offY, offZ)
        if Config.moveMode == "Gliding" then
            local delta = targetPos - hrp.Position
            if delta.Magnitude > 1 then hrp.AssemblyLinearVelocity = delta.Unit * Config.flySpeed end
        else
            hrp.CFrame = CFrame.new(targetPos)
        end
        -- Gliding Mode tab hook (does nothing unless a Gliding Mode feature is on)
        if Config.glideOverride then Config.glideOverride(hrp, nape, dt or 0.016) end
        if Config.canHit and (hrp.Position - nape.Position).Magnitude <= 1520 then
            Config.canHit = false
            task.spawn(function()
                local post = Data.POST
                local count = Config.hitAll and #targetList or math.min(Config.multiHit, #targetList)
                for i = 1, count do
                    local n = targetList[i]
                    if n and n.Parent then
                        if post then
                            post:FireServer("Hitboxes", "Register", n, math.random(200, 300), math.random(20, 30) / 100)
                            post:FireServer("Attacks", "Slash", true)
                        end
                        local id = tostring(n:GetDebugId())
                        if not Data.notified[id] then
                            Data.notified[id] = true
                            Config.titanKillCount = Config.titanKillCount + 1
                            showKillNotification(Config.titanKillCount)
                        end
                    end
                end
                if Config.onKillBurst then task.spawn(Config.onKillBurst) end
                task.wait(Config.hitCooldown)
                Config.canHit = true
            end)
        end
    end)
end

--//==============================\\--
--||   👑 REFILL / RELOAD SYSTEM  ||--
--\\==============================//--

local BladeUI_S2       = nil
local Gradient_S2      = nil
local SetsLabel_S2     = nil
local autoBladeRunning = false

pcall(function()
    BladeUI_S2    = player.PlayerGui.Interface.HUD.Main.Top["7"].Blades
    Gradient_S2   = BladeUI_S2.Inner.Bar.Gradient
    SetsLabel_S2  = BladeUI_S2.Sets
end)

local function TweenTo_S2(cf, speed)
    local charRef = player.Character if not charRef then return end
    local hrpRef  = charRef:FindFirstChild("HumanoidRootPart")
    local humRef  = charRef:FindFirstChild("Humanoid")
    if not hrpRef or not humRef or humRef.Health <= 0 then return end
    local distance = (hrpRef.Position - cf.Position).Magnitude
    local t        = distance / speed
    local tween    = TweenService:Create(hrpRef, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tween:Play()
    return tween
end

local refillParts, refillScanAt = nil, 0

local function FindRefillPart()
    -- scan the whole workspace once, then only re-check the cached parts
    local stale = os.clock() - refillScanAt
    if not refillParts or stale > 30 or (#refillParts == 0 and stale > 3) then
        refillParts = {}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local name = v.Name:lower()
                if name:find("refill") or name:find("fill") then
                    refillParts[#refillParts + 1] = v
                end
            end
        end
        refillScanAt = os.clock()
    end
    for _, v in ipairs(refillParts) do
        if v.Parent then
            local display = v:FindFirstChild("Display")
            if display then
                local ok, title = pcall(function() return display.Main.Top.Title.Text end)
                if ok and title ~= "REFILLS: 0 / 3 [R]" then return v end
            end
        end
    end
    return nil
end

local function Refill_S2()
    local refillPart = FindRefillPart()
    if not refillPart then return end
    TweenTo_S2(refillPart.CFrame, 6000)
    pcall(function()
        ReplicatedStorage.Assets.Remotes.POST:FireServer("Attacks", "Reload", refillPart)
    end)
end

local function ChangeBlade_S2()
    pcall(function()
        ReplicatedStorage.Assets.Remotes.GET:InvokeServer("Blades", "Reload")
    end)
end

local function CheckBlade_S2()
    if not Gradient_S2 then return false end
    local x = Gradient_S2.Offset.X
    if x < 0 then
        local bladeOk = false
        pcall(function()
            local rig = workspace.Characters[player.Name]["Rig_" .. player.Name]
            local blade = rig.LeftHand.Blade_1
            if blade.Transparency == 0 then bladeOk = true end
        end)
        if bladeOk then return false end
        if SetsLabel_S2 and SetsLabel_S2.Text == "0 / 3" then
            Refill_S2()
        else
            ChangeBlade_S2()
        end
        return true
    end
    return false
end

if Gradient_S2 then
    Gradient_S2:GetPropertyChangedSignal("Offset"):Connect(function()
        if autoBladeRunning then CheckBlade_S2() end
    end)
end

local bladeLoopToken = 0
local function StartBladeLoop()
    bladeLoopToken = bladeLoopToken + 1
    local my = bladeLoopToken
    autoBladeRunning = true
    task.spawn(function()
        while autoBladeRunning and bladeLoopToken == my do
            CheckBlade_S2()
            task.wait(0.2)
        end
    end)
end

Tabs.Main:AddSection("Auto Farm")

local BladeToggle = Tabs.Main:AddToggle("AutoBladeReload", {
    Title = "Auto Reload / Refill Blades",
    Description = "Switches blade sets automatically; teleports to refill station when all sets are empty",
    Default = true,
    Callback = function(state)
        if state then
            StartBladeLoop()
        else
            autoBladeRunning = false
            bladeLoopToken = bladeLoopToken + 1
        end
    end
})
-- callbacks don't fire on creation, so start it for the default-on state
if BladeToggle.Value then StartBladeLoop() end

--//==============================\\--
--||        👑 AUTO CLICK M1       ||--
--\\==============================//--

local autoM1Running = false
local autoM1Token   = 0
local M1_DELAY       = 0.25
local M1Toggle

local RESULT_TITLES_M1 = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }

local function GuiVisibleM1(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function MissionCompleted()
    local ok, res = pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                t = t:gsub("^%s+", ""):gsub("%s+$", "")
                if RESULT_TITLES_M1[t:upper()] and GuiVisibleM1(d) then return true end
            end
        end
        return false
    end)
    return ok and res
end

--//==============================\\--
--||     SLOW LAND AFTER MISSION  ||--
--\\==============================//--

Config.missionDone = false
Config.landSpeed   = 15   -- studs per second (lower = slower)

do
    local landed = false

    -- watch for the MISSION / RAID COMPLETED screen (polled, not every frame)
    task.spawn(function()
        while true do
            local done = MissionCompleted()
            if done and not Config.missionDone then
                Config.missionDone = true
                landed = false
            elseif not done and Config.missionDone then
                Config.missionDone = false  -- new mission / retry: farm resumes
                killStartAt = os.clock() + Config.baseStartDelay + Config.startDelay
                landed = false
            end
            task.wait(0.5)
        end
    end)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true

    RunService.Heartbeat:Connect(function(dt)
        if not Config.missionDone or landed then return end
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local ignore = { char }
        local titans = workspace:FindFirstChild("Titans")
        local chars  = workspace:FindFirstChild("Characters")
        if titans then ignore[#ignore + 1] = titans end
        if chars  then ignore[#ignore + 1] = chars  end
        rayParams.FilterDescendantsInstances = ignore

        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -5000, 0), rayParams)
        if not hit then landed = true return end -- nothing below: let normal physics take over

        -- stand height = ground + hip height + half the root part (never lower than this = no clipping)
        local standY = hit.Position.Y + hum.HipHeight + hrp.Size.Y / 2 + 0.2
        local y = hrp.Position.Y

        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        if y <= standY + 0.3 then
            landed = true
            return
        end

        local newY = math.max(standY, y - Config.landSpeed * dt)
        local pos  = hrp.Position
        hrp.CFrame = CFrame.new(pos.X, newY, pos.Z) * (hrp.CFrame - hrp.CFrame.Position)
    end)
end

local cachedAttackBtn
local function FindAttackButton()
    if cachedAttackBtn and cachedAttackBtn.Parent and cachedAttackBtn.Visible then return cachedAttackBtn end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local n = d.Name:lower()
            if n == "attack" or n == "m1" or n == "slash" then cachedAttackBtn = d return d end
        end
    end
    return nil
end

local function ClickM1()
    -- real mouse click in the screen centre (M1)
    pcall(function()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local x, y = size.X / 2, size.Y / 2
        VirtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    -- on-screen attack button (mobile layout), if one exists
    pcall(function()
        local btn = FindAttackButton()
        if btn then
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            else
                local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.03)
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end
    end)
end

-- M1 no longer spams on its own: it only clicks when Auto Kill actually fires a hit burst
local M1Enabled = true
local lastM1 = 0

Config.onKillBurst = function()
    if not M1Enabled then return end
    if os.clock() - lastM1 < M1_DELAY then return end
    lastM1 = os.clock()
    ClickM1()
end

M1Toggle = Tabs.Main:AddToggle("AutoClickM1", {
    Title = "Auto Click M1 (only while killing)",
    Description = "Clicks M1 only when Auto Kill is hitting titans. Follows the Auto Kill switch",
    Default = true,
    Callback = function(state)
        M1Enabled = state and true or false
    end
})
if M1Toggle and M1Toggle.Value ~= nil then M1Enabled = M1Toggle.Value and true or false end

local KillToggle = Tabs.Main:AddToggle("AutoKillTitans", {
    Title = "Auto Kill Titans",
    Description = "Don't Finish the mission under 17 sec",
    Default = true,
    Callback = function(state)
        Config.isFlying = state
        if state then task.spawn(killFromAbove) end
        -- M1 setting turns on/off together with Auto Kill
        if M1Toggle and M1Toggle.SetValue then pcall(function() M1Toggle:SetValue(state and true or false) end) end
    end
})
if KillToggle.Value then Config.isFlying = true task.spawn(killFromAbove) end

--//==============================\\--
--||   SMOOTH CAMERA WHILE FARMING ||--
--\\==============================//--
-- Keeps your camera angle fixed and only glides the camera position after
-- you, so the view doesn't whip around when Auto Kill teleports you.

Config.lockCamera = true

do
    local SMOOTHNESS = 10      -- higher = camera catches up faster
    local locked, savedType, savedRot, dist = false, nil, nil, 20

    local function farming()
        return Config.lockCamera and Config.isFlying and not Config.missionDone
            and os.clock() >= killStartAt
    end

    RunService:BindToRenderStep("AotrSmoothCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
        local cam = workspace.CurrentCamera
        local root = Player.hrp
        if not cam then return end

        if farming() and root and root.Parent then
            if not locked then
                locked    = true
                savedType = cam.CameraType
                savedRot  = cam.CFrame.Rotation
                dist      = math.clamp((cam.CFrame.Position - root.Position).Magnitude, 8, 40)
                cam.CameraType = Enum.CameraType.Scriptable
            end
            local goal  = root.Position - savedRot.LookVector * dist
            local alpha = 1 - math.exp(-SMOOTHNESS * dt)
            cam.CFrame  = CFrame.new(cam.CFrame.Position:Lerp(goal, alpha)) * savedRot
        elseif locked then
            locked = false
            cam.CameraType = savedType or Enum.CameraType.Custom
        end
    end)
end

Tabs.Main:AddToggle("SmoothCameraLock", {
    Title = "Smooth Camera While Farming",
    Description = "Keeps the camera angle steady and follows you smoothly instead of snapping around",
    Default = true,
    Callback = function(state) Config.lockCamera = state and true or false end
})

Tabs.Main:AddDropdown("MoveMode", {
    Title = "Movement Mode",
    Values = {"Teleportation", "Gliding"},
    Default = 1,
    Callback = function(option) Config.moveMode = option end
})

Tabs.Main:AddSlider("StartDelaySlider", {
    Title = "Farm Delay",
    Description = "Extra seconds added on top of the fixed 5 second start delay",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(value) Config.startDelay = value end
})

Tabs.Main:AddSlider("LandSpeedSlider", {
    Title = "Landing Speed (after mission)",
    Description = "How slowly you descend once the mission is complete",
    Default = 15,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Callback = function(value) Config.landSpeed = value end
})

Tabs.Main:AddSlider("FlySpeedSlider", {
    Title = "Gliding Speed",
    Default = 300,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.flySpeed = value end
})

Tabs.Main:AddSlider("FlyHeightSlider", {
    Title = "Float Height",
    Default = 120,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value) Config.flyHeight = value end
})

Tabs.Main:AddToggle("OrbitEnabled", {
    Title = "Circle Hover",
    Description = "Hover in circles around the titan while farming",
    Default = true,
    Callback = function(state) Config.orbitEnabled = state end
})

Tabs.Main:AddToggle("WaveEnabled", {
    Title = "Wave Hover",
    Description = "Snake-like wave: up/down and left/right while farming (works with or without Circle Hover)",
    Default = false,
    Callback = function(state) Config.waveEnabled = state end
})

Tabs.Main:AddSlider("WaveAmpSlider", {
    Title = "Wave Height (studs)",
    Default = 15,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Callback = function(value) Config.waveAmp = value end
})

Tabs.Main:AddSlider("WaveWidthSlider", {
    Title = "Wave Width (studs)",
    Description = "Left/right sway of the snake wave (0 = up/down only)",
    Default = 20,
    Min = 0,
    Max = 80,
    Rounding = 0,
    Callback = function(value) Config.waveWidth = value end
})

Tabs.Main:AddSlider("OrbitRadiusSlider", {
    Title = "Circle Radius (studs)",
    Description = "Radius of the circle you hover in while farming",
    Default = 20,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(value) Config.orbitRadius = value end
})

Tabs.Main:AddSlider("HitSpeedSlider", {
    Title = "Hit Interval (ms) - lower = faster",
    Default = 120,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.hitCooldown = value / 1000 end
})

Tabs.Main:AddSlider("MultiHitSlider", {
    Title = "Titans Hit Per Burst",
    Default = 8,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Config.multiHit = value end
})

Tabs.Main:AddToggle("HitAllTitans", {
    Title = "Hit All Titans At Once",
    Description = "Every alive titan gets hit in the same burst (ignores Titans Hit Per Burst)",
    Default = false,
    Callback = function(state) Config.hitAll = state end
})

--//==============================\\--
--||       GLIDING MODE TAB       ||--
--\\==============================//--
-- Both features ride on Auto Kill Titans (Main tab): turn Auto Kill on, then
-- switch these on. Hits/refill/everything else is untouched.

do
    local G = {
        wave   = false,   -- Wave Farm (snake glide)
        hop    = false,   -- Titan Hop Farm
        radius = 20,      -- studs, slider 10-50
    }
    local WAVE_SPEED = 3      -- radians/sec of the up/down wave
    local WAVE_AMP   = 18     -- studs up/down
    local WAVE_SWAY  = 25     -- studs left/right (snake weave)
    local ORBIT_SPEED = 2     -- radians/sec around the titan
    local HOP_DWELL  = 4      -- max seconds on one titan before jumping to the next

    local waveT, orbitA = 0, 0
    local hopNape, hopSince = nil, 0
    local visited = {}

    local function aliveNapes()
        local list = {}
        local folder = workspace:FindFirstChild("Titans")
        if not folder then return list end
        for _, t in ipairs(folder:GetChildren()) do
            if isAlive(t) then
                local n = napeOf(t)
                if n then list[#list + 1] = n end
            end
        end
        return list
    end

    local function napeAlive(n)
        if not n or not n.Parent then return false end
        -- Nape sits at Titan/Hitboxes/Hit/Nape
        local titan = n.Parent and n.Parent.Parent and n.Parent.Parent.Parent
        return titan ~= nil and isAlive(titan) == true
    end

    -- nearest alive titan we have not visited yet; when all were visited, start over
    local function pickNext(fromPos)
        local list = aliveNapes()
        if #list == 0 then return nil end
        for pass = 1, 2 do
            local best, bestD
            for _, n in ipairs(list) do
                if not visited[n] and n ~= hopNape then
                    local d = (n.Position - fromPos).Magnitude
                    if not bestD or d < bestD then best, bestD = n, d end
                end
            end
            if best then visited[best] = true return best end
            table.clear(visited)
        end
        return list[1]
    end

    Config.glideOverride = function(hrp, nape, dt)
        if not (G.wave or G.hop) then return end

        local center = nape
        if G.hop then
            if not napeAlive(hopNape) or os.clock() - hopSince > HOP_DWELL then
                hopNape  = pickNext(hrp.Position)
                hopSince = os.clock()
                orbitA   = 0
            end
            center = hopNape or nape
        end
        if not center then return end

        local offX, offZ, offY = 0, 0, 0

        if G.hop then
            -- hover in circles (radius from the slider) above the current titan
            orbitA = (orbitA + dt * ORBIT_SPEED) % (math.pi * 2)
            offX = math.cos(orbitA) * G.radius
            offZ = math.sin(orbitA) * G.radius
        end

        if G.wave then
            -- snake glide: smooth up/down + left/right weave
            waveT = (waveT + dt * WAVE_SPEED) % (math.pi * 2)
            offY = math.sin(waveT) * WAVE_AMP
            if not G.hop then
                offX = math.sin(waveT * 0.5) * WAVE_SWAY
                offZ = math.cos(waveT * 0.5) * (WAVE_SWAY * 0.4)
            end
        end

        local pos = center.Position + Vector3.new(offX, Config.flyHeight + offY, offZ)
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(pos)
    end

    Tabs.Glide:AddSection("Wave Farm")

    Tabs.Glide:AddToggle("GlideWaveFarm", {
        Title = "Wave Farm (Snake Glide)",
        Description = "Glide up and down like a snake while farming. Needs Auto Kill Titans on. If Titan Hop is also on, the wave is added to its circle",
        Default = false,
        Callback = function(state) G.wave = state and true or false end
    })

    Tabs.Glide:AddSection("Titan Hop Farm")

    Tabs.Glide:AddToggle("GlideTitanHop", {
        Title = "Titan Hop Farm",
        Description = "Teleport above a titan, hover in circles while farming, then teleport to the next titan and repeat. Needs Auto Kill Titans on",
        Default = false,
        Callback = function(state)
            G.hop = state and true or false
            hopNape = nil
            table.clear(visited)
        end
    })

    Tabs.Glide:AddSlider("GlideCircleRadius", {
        Title = "Circle Radius (studs)",
        Description = "Radius of the circle you hover in above each titan",
        Default = 20,
        Min = 10,
        Max = 50,
        Rounding = 0,
        Callback = function(value) G.radius = value end
    })
end

local _Remotes = game:GetService("ReplicatedStorage").Assets.Remotes
local GET, POST = _Remotes.GET, _Remotes.POST

--//==============================\\--
--||        👑 AUTO Retry         ||--
--\\==============================//--

local VIM = game:GetService("VirtualInputManager")

local interface = player:FindFirstChild("PlayerGui")
    and player.PlayerGui:FindFirstChild("Interface")

local rewards     = interface and interface:FindFirstChild("Rewards")
local rewardsMain = rewards and rewards:FindFirstChild("Main")
local retryBtn    = rewardsMain
    and rewardsMain:FindFirstChild("Info")
    and rewardsMain.Info:FindFirstChild("Main")
    and rewardsMain.Info.Main:FindFirstChild("Buttons")
    and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")

local autoRetryEnabled = false

local function showDebugDot(x, y)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, x - 5, 0, y - 5)
    dot.BackgroundColor3 = Color3.new(1, 0, 0)
    dot.BorderSizePixel = 0
    dot.ZIndex = 10000
    dot.Name = "DebugDot"
    pcall(function() dot.Parent = game:GetService("CoreGui") end)
    game:GetService("Debris"):AddItem(dot, 2)
end

local function Retryshi()
    local pos  = retryBtn.AbsolutePosition
    local size = retryBtn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2 + 20
    local y
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        y = pos.Y + size.Y / 2 + 60
    else
        y = pos.Y + size.Y / 2 + inset.Y
    end
    showDebugDot(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function shouldClickRetry()
    return retryBtn
        and rewards and rewards.Visible
        and rewardsMain and rewardsMain.Visible
        and retryBtn.Visible
        and retryBtn.AbsoluteSize.Magnitude > 10
end

task.spawn(function()
    while true do
        if autoRetryEnabled and shouldClickRetry() then
            task.wait(0.3)
            if shouldClickRetry() then
                Retryshi()
                task.wait(2)
            end
        end
        task.wait(0.25)
    end
end)

Tabs.Main:AddSection("Utilities")

Tabs.Main:AddToggle("AutoRetryToggle", {
    Title = "Auto Retry",
    Default = false,
    Callback = function(state) autoRetryEnabled = state end
})

--//==============================\\--
--||     AUTO SKIP CUTSCENES      ||--
--\\==============================//--

local autoSkipRunning = false
local autoSkipToken   = 0
local skipClickedAt   = setmetatable({}, { __mode = "k" })

local function SkipGuiShown(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function LooksLikeSkip(btn)
    if btn.Name:lower():find("skip", 1, true) then return true end
    if btn:IsA("TextButton") then
        local t = btn.Text:gsub("<[^>]->", ""):lower()
        if t:find("skip", 1, true) then return true end
    end
    for _, c in ipairs(btn:GetChildren()) do -- label sitting inside an ImageButton
        if c:IsA("TextLabel") then
            local t = c.Text:gsub("<[^>]->", ""):lower()
            if t:find("skip", 1, true) then return true end
        end
    end
    return false
end

local function PressButton(btn)
    local fired = false
    if getconnections then
        for _, sig in ipairs({ btn.MouseButton1Down, btn.MouseButton1Up, btn.MouseButton1Click, btn.Activated }) do
            pcall(function()
                for _, c in ipairs(getconnections(sig)) do
                    c:Fire()
                    fired = true
                end
            end)
        end
    end
    if not fired and firesignal then
        pcall(function()
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
            fired = true
        end)
    end
    if not fired then -- last resort: a real click on the button
        local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
        local inset = GuiService:GetGuiInset()
        local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
        VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end
end

local function SkipCutscenesOnce()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.AbsoluteSize.X > 0 and d.AbsoluteSize.Y > 0
            and LooksLikeSkip(d) and SkipGuiShown(d) then
            local last = skipClickedAt[d]
            if not last or os.clock() - last > 1.5 then
                skipClickedAt[d] = os.clock()
                PressButton(d)
                return
            end
        end
    end
end

local function StartSkipLoop()
    autoSkipToken += 1
    local my = autoSkipToken
    autoSkipRunning = true
    task.spawn(function()
        while autoSkipRunning and autoSkipToken == my do
            pcall(SkipCutscenesOnce)
            task.wait(0.5)
        end
    end)
end

local SkipToggle = Tabs.Main:AddToggle("AutoSkipCutscenes", {
    Title = "Auto Skip Cutscenes",
    Description = "Presses the Skip button as soon as a cutscene shows one",
    Default = true,
    Callback = function(state)
        if state then
            StartSkipLoop()
        else
            autoSkipRunning = false
            autoSkipToken += 1
        end
    end
})
if SkipToggle.Value then StartSkipLoop() end

--//==============================\\--
--||        👑 AUTO Escape        ||--
--\\==============================//--

local escapeRunning    = false
local escapeThread     = nil
local cleanGUIThread   = nil
local lastEscapeButton = nil

Tabs.Main:AddToggle("Escape", {
    Title = "Auto Escape",
    Default = false,
    Callback = function(Value)
        escapeRunning = Value
        if not Value then lastEscapeButton = nil return end
        escapeThread = task.spawn(function()
            local pg = player:WaitForChild("PlayerGui")
            while escapeRunning do
                local iface   = pg:FindFirstChild("Interface")
                local buttons = iface and iface:FindFirstChild("Buttons")
                if buttons then
                    local list = buttons:GetChildren()
                    if #list > 0 then
                        POST:FireServer("Attacks", "Slash_Escape")
                        for _, b in ipairs(list) do b:Destroy() end
                    end
                end
                task.wait(0.05)
            end
        end)
    end
})

--//==============================\\--
--||         👑 Auto Roll         ||--
--\\==============================//--

local CLICK_DELAY = 0.2
local WAIT_DELAY  = 1
local ENABLED     = false

local function canClick(btn)
    return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

local function isActuallyVisible(obj)
    if not obj then return false end
    local current = obj
    local Gui = player:WaitForChild("PlayerGui")
    while current and current ~= Gui do
        local success3, result3 = pcall(function() return current.Visible end)
        if success3 and not result3 then return false end
        current = current.Parent
    end
    return obj.AbsoluteSize.Magnitude > 10
end

local function clickButton(btn)
    if not btn then return false end
    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2 + inset.Y
    VIM:SendMouseMoveEvent(x, y, game)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function findButton(parent, buttonName)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj.Name == buttonName and obj:IsA("GuiButton") then return obj end
        for _, child in pairs(obj:GetChildren()) do
            local result4 = searchRecursive(child)
            if result4 then return result4 end
        end
        return nil
    end
    return searchRecursive(parent)
end

local function findButtonByText(parent, text)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj:IsA("GuiButton") or obj:IsA("TextButton") then
            local hasText = obj:FindFirstChild("Text") or obj.Text
            if hasText and string.find(string.lower(tostring(hasText)), string.lower(text)) then return obj end
        end
        for _, child in pairs(obj:GetChildren()) do
            local result5 = searchRecursive(child)
            if result5 then return result5 end
        end
        return nil
    end
    return searchRecursive(parent)
end

task.spawn(function()
    local Gui = player:WaitForChild("PlayerGui")
    local interface2 = Gui:WaitForChild("Interface", 10)
    if not interface2 then return end
    local rollButton = nil
    local searchPaths = {"Customisation.Family.Buttons_2.Roll", "Roll", "RollButton"}
    for _, path in pairs(searchPaths) do
        local pathParts = string.split(path, ".")
        local current = interface2
        for _, part in pairs(pathParts) do
            if current then current = current:FindFirstChild(part) end
        end
        if current and current:IsA("GuiButton") then rollButton = current break end
    end
    if not rollButton then rollButton = findButton(interface2, "Roll") end
    if not rollButton then rollButton = findButtonByText(interface2, "roll") end
    if not rollButton then return end
    while true do
        if ENABLED then
            if canClick(rollButton) and isActuallyVisible(rollButton) then
                clickButton(rollButton)
                task.wait(CLICK_DELAY)
            else task.wait(WAIT_DELAY) end
        else task.wait(1) end
    end
end)

--//==============================\\--
--||        AUTO JOIN TAB         ||--
--\\==============================//--

local Difficulties      = {"Best For You","Easy","Normal","Hard","Severe","Aberrant"}
local DifficultiesRaids = {"Best For You","Hard","Severe","Aberrant"}
local ModifiersList     = {"No Perks","No Skills","No Memories","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}
local MissionMaps       = {"Shiganshina","Trost","Outskirts","Forest","Utgard","Docks","Stohess","Chapel"}
local MissionObjectives = {
    ["Shiganshina"]={"Skirmish","Breach","Random"},
    ["Trost"]      ={"Skirmish","Protect","Random"},
    ["Outskirts"]  ={"Skirmish","Escort","Random"},
    ["Forest"]     ={"Skirmish","Guard","Random"},
    ["Utgard"]     ={"Skirmish","Defend","Random"},
    ["Docks"]      ={"Skirmish","Stall","Random"},
    ["Stohess"]    ={"Skirmish","Random"},
    ["Chapel"]     ={"Skirmish","Random"},
}
local RaidMaps      = {"Shiganshina","Trost","Stohess"}
local RaidObjectives= {["Shiganshina"]={"Armored Titan","Colossal Titan"},["Trost"]={"Attack Titan"},["Stohess"]={"Female Titan"}}
local WaveMaps      = {"Trost"}

_G.AJ = {
    SelectMissionMap        = MissionMaps[1],
    SelectMissionObjective  = MissionObjectives[MissionMaps[1]][1],
    SelectMissionDifficulty = "Easy",
    SelectMissionModifiers  = {},
    SelectRaidMap           = RaidMaps[1],
    SelectRaidObjective     = RaidObjectives[RaidMaps[1]][1],
    SelectRaidDifficulty    = "Easy",
    SelectRaidModifiers     = {},
    SelectWaveMap           = WaveMaps[1],
    AutoJoinMission         = false,
    AutoJoinMissionBoost    = false,
    AutoJoinRaid            = false,
    AutoJoinWaves           = false,
}

local function PressButton(d)
    game:GetService("GuiService").SelectedObject = d
    VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end

local function CreateAndStart(data)
    if game.PlaceId == 14916516914 then
        local ok, res = pcall(function() return GET:InvokeServer("S_Missions","Create",data) end)
        if ok and typeof(res) == "Instance" then
            task.wait(1)
            pcall(function() return GET:InvokeServer("S_Missions","Start") end)
            return true
        end
        return false
    end
end

-- Mission section
Tabs.AutoJoin:AddSection("Auto Join Missions")

local MissionObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_MissionMap", {
    Title = "Select Map",
    Values = MissionMaps,
    Default = _G.AJ.SelectMissionMap,
    Callback = function(v)
        _G.AJ.SelectMissionMap = v
        local objs = MissionObjectives[v]
        if objs then _G.AJ.SelectMissionObjective = objs[1] end
        if MissionObjectiveDropdown2 then MissionObjectiveDropdown2:SetValues(MissionObjectives[v] or {}) end
    end
})

MissionObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_MissionObjective", {
    Title = "Select Objective",
    Values = MissionObjectives[_G.AJ.SelectMissionMap] or {},
    Default = _G.AJ.SelectMissionObjective,
    Callback = function(v) _G.AJ.SelectMissionObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionDifficulty", {
    Title = "Select Difficulty",
    Values = Difficulties,
    Default = _G.AJ.SelectMissionDifficulty,
    Callback = function(v) _G.AJ.SelectMissionDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectMissionModifiers,
    Callback = function(v) _G.AJ.SelectMissionModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMission", {
    Title = "Auto Join Mission",
    Description = "Automatically joins missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMission = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission then
            CreateAndStart({Name=_G.AJ.SelectMissionMap,Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMissionBoost", {
    Title = "Auto Join Mission (Rewards Boost)",
    Description = "Automatically joins boosted missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMissionBoost = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMissionBoost then
            CreateAndStart({Name=game:GetService("Workspace"):GetAttribute("Boosted_Map"),Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

-- Raids section
Tabs.AutoJoin:AddSection("Auto Join Raids")

local RaidObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_RaidMap", {
    Title = "Select Raid Map",
    Values = RaidMaps,
    Default = _G.AJ.SelectRaidMap,
    Callback = function(v)
        _G.AJ.SelectRaidMap = v
        local objs = RaidObjectives[v]
        if objs then _G.AJ.SelectRaidObjective = objs[1] end
        if RaidObjectiveDropdown2 then RaidObjectiveDropdown2:SetValues(RaidObjectives[v] or {}) end
    end
})

RaidObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_RaidObjective", {
    Title = "Select Raid Boss",
    Values = RaidObjectives[_G.AJ.SelectRaidMap] or {},
    Default = _G.AJ.SelectRaidObjective,
    Callback = function(v) _G.AJ.SelectRaidObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidDifficulty", {
    Title = "Select Difficulty",
    Values = DifficultiesRaids,
    Default = _G.AJ.SelectRaidDifficulty,
    Callback = function(v) _G.AJ.SelectRaidDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectRaidModifiers,
    Callback = function(v) _G.AJ.SelectRaidModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinRaid", {
    Title = "Auto Join Raid",
    Description = "Automatically joins raids",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinRaid = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinRaid then
            CreateAndStart({Name=_G.AJ.SelectRaidMap,Type="Raids",Difficulty=_G.AJ.SelectRaidDifficulty,Objective=_G.AJ.SelectRaidObjective,Modifiers=_G.AJ.SelectRaidModifiers,Limit=8})
        end
    end
end)

-- Waves section
Tabs.AutoJoin:AddSection("Auto Join Waves")

Tabs.AutoJoin:AddDropdown("AJ_WaveMap", {
    Title = "Select Wave Map",
    Values = WaveMaps,
    Default = _G.AJ.SelectWaveMap,
    Callback = function(v) _G.AJ.SelectWaveMap = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinWaves", {
    Title = "Auto Join Waves",
    Description = "Automatically joins waves",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinWaves = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinWaves then
            CreateAndStart({Name=_G.AJ.SelectWaveMap,Type="Waves",Difficulty="Easy",Objective="Waves",Limit=8})
        end
    end
end)

-- Leave wrong mission auto-correct
spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission or _G.AJ.AutoJoinRaid or _G.AJ.AutoJoinWaves then
            for _, v in pairs(game:GetService("ReplicatedStorage").Missions:GetChildren()) do
                if v.Leader.Value == player.Name then
                    local Target = nil
                    if _G.AJ.AutoJoinMission then Target = _G.AJ.SelectMissionMap
                    elseif _G.AJ.AutoJoinMissionBoost then Target = game:GetService("Workspace"):GetAttribute("Boosted_Map")
                    elseif _G.AJ.AutoJoinRaid then Target = _G.AJ.SelectRaidMap
                    elseif _G.AJ.AutoJoinWaves then Target = _G.AJ.SelectWaveMap end
                    if v.Name ~= Target then
                        GET:InvokeServer("S_Missions","Leave")
                    end
                end
            end
        end
    end
end)

--//==============================\\--
--||        SERVERS TAB           ||--
--\\==============================//--

local TPS = TeleportService

Tabs.Servers:AddSection("Server")

Tabs.Servers:AddInput("JobIDInput", {
    Title = "JobID",
    Placeholder = "Paste Job ID here",
    Callback = function(x) _G.JobId_Textbox = x end
})

Tabs.Servers:AddToggle("AutoJoinJobID", {
    Title = "Auto Join JobID",
    Default = false,
    Callback = function(v)
        _G.AutoJoinJobID = v
        if v then
            task.spawn(function()
                while _G.AutoJoinJobID do
                    if _G.JobId_Textbox and _G.JobId_Textbox ~= "" then
                        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
                        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
                    else
                        warn("Please enter a JobID before enabling Auto Join JobID")
                        _G.AutoJoinJobID = false break
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Join JobID",
    Callback = function()
        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
    end
})

Tabs.Servers:AddButton({
    Title = "Copy JobID",
    Callback = function()
        setclipboard(game.JobId)
        Notifier:Notify({ Title="Aotr:update5", Content="Copied JobID!", Duration=3 })
    end
})

Tabs.Servers:AddSection("Basic")

Tabs.Servers:AddButton({
    Title = "Rejoin",
    Description = "Re-enter the same server",
    Callback = function() TeleportService:Teleport(game.PlaceId, player) end
})

getgenv().ServerHop = function()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local data = HttpService:JSONDecode(game:HttpGet(url))
    for _, v in ipairs(data.data or {}) do
        if v.playing < v.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer) return
        end
    end
end

Tabs.Servers:AddButton({
    Title = "Server Hop",
    Description = "Move to new server",
    Callback = function() getgenv().ServerHop() end
})

Tabs.Servers:AddSection("Smart Server")

Tabs.Servers:AddSlider("MaxPlayersFilter", {
    Title = "Max Players Filter",
    Min = 1,
    Max = 20,
    Default = 5,
    Rounding = 0,
    Callback = function(v) _G.SetP = v end
})

Tabs.Servers:AddButton({
    Title = "Smart Hop",
    Description = "Find server with fewest players",
    Callback = function()
        local limit = _G.SetP
        local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
        for _, v in ipairs(body.data or {}) do
            if v.playing <= limit then TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, player) break end
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Low Ping Hop",
    Description = "Find lowest ping server",
    Callback = function()
        pcall(function()
            local bestServer, lowestPing = nil, math.random(50, 200)
            local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
            for _, v in ipairs(body.data or {}) do
                local ping = tonumber(v.ping)
                if ping and ping < lowestPing then lowestPing = ping bestServer = v.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(bestServer), player) end
        end)
    end
})

--//==============================\\--
--||           MISC TAB           ||--
--\\==============================//--

getgenv().AutoHideAfterDelay = false

Tabs.Misc:AddSection("Interface")

Tabs.Misc:AddToggle("AutoHideAfter10s", {
    Title = "Auto Hide UI (5s)",
    Default = false,
    Callback = function(state)
        getgenv().AutoHideAfterDelay = state
        if state then
            task.delay(5, function()
                if not getgenv().AutoHideAfterDelay then return end
                getgenv().AutoHideUI = true
                Window:Minimize(true)
            end)
        end
    end
})

local lastTap = 0
local function toggleUI()
    Window:Minimize()
end

UserInputService.TouchTap:Connect(function(_, gameProcessed)
    if gameProcessed then return end
    local now = tick()
    if now - lastTap <= 0.4 then toggleUI() end
    lastTap = now
end)

Tabs.Misc:AddToggle("ToggleNotifications", {
    Title = "Notifications",
    Default = false,
    Callback = function(value) Config.notificationsEnabled = value end
})

Tabs.Misc:AddSection("Game")

local delaySeconds = 180
local toggleActive = false

Tabs.Misc:AddToggle("ForceRetryToggle", {
    Title = "Fail Safe",
    Default = false,
    Callback = function(state)
        toggleActive = state
        if state then
            task.delay(delaySeconds, function()
                if toggleActive then
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            end)
        end
    end
})

-- Auto Force Retry: fires 15s after the MISSION / RAID COMPLETED screen appears
do
    local AUTO_FORCE_RETRY_DELAY = 15
    local autoForceRetry = true
    Tabs.Misc:AddToggle("AutoForceRetry15", {
        Title = "Auto Force Retry (15s)",
        Description = "Automatically Force Retry 15 seconds after a mission is completed.",
        Default = true,
        Callback = function(state) autoForceRetry = state end
    })
    task.spawn(function()
        local shownAt, fired = nil, false
        while true do
            task.wait(0.5)
            if autoForceRetry and MissionCompleted() then
                shownAt = shownAt or os.clock()
                if not fired and os.clock() - shownAt >= AUTO_FORCE_RETRY_DELAY then
                    fired = true
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            else
                shownAt, fired = nil, false
            end
        end
    end)
end

-- Damage Text
local iface2 = player:WaitForChild("PlayerGui"):WaitForChild("Interface")
local damageConnection

Tabs.Misc:AddToggle("dmg", {
    Title = "Remove Dmg Text",
    Default = false,
    Callback = function(state)
        if state then
            for _, obj in pairs(iface2:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end
            damageConnection = iface2.DescendantAdded:Connect(function(obj)
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end)
        else
            if damageConnection then damageConnection:Disconnect() damageConnection = nil end
        end
    end
})

-- Teleport buttons
local lobbyPlaceId    = 14916516914
local mainMenuPlaceId = 13379208636

Tabs.Misc:AddSection("Teleport")

Tabs.Misc:AddButton({
    Title = "Return to Lobby",
    Callback = function() TeleportService:Teleport(lobbyPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Return to Main Menu",
    Callback = function() TeleportService:Teleport(mainMenuPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Force Retry",
    Callback = function()
        local ok, err = pcall(function()
            retryRemote:InvokeServer("Functions", "Retry", "Add")
        end)
        if not ok then warn(".") end
    end,
})

--//==============================\\--
--||            👑 ESP            ||--
--\\==============================//--

local ESPEnabled = false
local ESPColor   = Color3.fromRGB(96, 205, 255)
local ESPSize    = Vector3.new(50, 50, 50)

local function createNapeESP(nape)
    if not nape:FindFirstChild("NapeESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name        = "NapeESP"
        esp.Adornee     = nape
        esp.AlwaysOnTop = true
        esp.ZIndex      = 5
        esp.Size        = ESPSize
        esp.Transparency = 0.5
        esp.Color3      = ESPColor
        esp.Parent      = nape
    end
end

local function applyNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit  = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:IsA("BasePart") then createNapeESP(nape) end
            end
        end
    end
end

local function removeAllNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:FindFirstChild("NapeESP") then nape.NapeESP:Destroy() end
            end
        end
    end
end

local function updateNapeESPColor()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    local esp = nape:FindFirstChild("NapeESP")
                    if esp then esp.Color3 = ESPColor end
                end
            end
        end
    end
end

local titansFolderEsp = workspace:FindFirstChild("Titans")
if titansFolderEsp then
    titansFolderEsp.ChildAdded:Connect(function(titan)
        if not ESPEnabled then return end
        task.wait(0.5)
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then createNapeESP(nape) end
            end
        end
    end)
end

Tabs.Esp:AddToggle("NapeESP", {
    Title = "Enable Nape ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if value then applyNapeESP() else removeAllNapeESP() end
    end
})

local Colorpicker = Tabs.Esp:AddColorpicker("ESPColorPicker", {
    Title = "ESP Color",
    Default = ESPColor
})

Colorpicker:OnChanged(function(newColor)
    ESPColor = newColor
    updateNapeESPColor()
end)

Colorpicker:SetValueRGB(Color3.fromRGB(96, 205, 255))

-- ============================================================
--  Account / Webhook
--  Logic is copied verbatim from the original; only the UI layer is Obsidian.
-- ============================================================
do
local okMod, errMod = pcall(function()

-- ---------- compat layer (replaces Smooth Hub globals the extracted code expects) ----------
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IN_MENU = (game.PlaceId == 13379208636)
local modToken = {}
_G.AotrUpdate5ModToken = modToken
local function Alive() return _G.AotrUpdate5ModToken == modToken end
local SH = { DEV = false }
function SH.say(...) print("[Aotr:update5]", ...) end
function SH.dbg(...) if SH.DEV then print(...) end end
function SH.Guard(name, fn)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
    if not ok then warn("[Aotr:update5] block " .. tostring(name) .. " failed to load: " .. tostring(err)) end
end
function SH.PlayOn() return true end
local Farm = {}
SH.Farm = Farm
function Farm.CanUseHere()
    return not IN_MENU and game.PlaceId ~= 14916516914
end
local Cfg = {
    AutoFarmThunder = false,
    UseThunderSpears = false,
}
local function Save() end
-- thunder-spear counter (verbatim from Smooth Hub; the "stuck" detector belongs to its farm loop and is not included)
    local function SpearsLeft()
        local char = LocalPlayer.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end
Farm.SpearsLeft = SpearsLeft
local function IsShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

-- tiny file store for the Webhook tab (own file, never mixed into configs)
local SettingsStore = {}
do
    local DIR = "Aotr_update5/" .. tostring(LocalPlayer.UserId)
    local function Path(file) return DIR .. "/" .. file .. ".json" end
    function SettingsStore.Load(file)
        local data = {}
        pcall(function()
            if isfile and readfile and isfile(Path(file)) then
                local d = HttpService:JSONDecode(readfile(Path(file)))
                if type(d) == "table" then data = d end
            end
        end)
        return data
    end
    function SettingsStore.Write(file, data)
        pcall(function()
            if not (writefile and makefolder) then return end
            if isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
            if isfolder and not isfolder(DIR) then makefolder(DIR) end
            writefile(Path(file), HttpService:JSONEncode(data))
        end)
    end
    function SettingsStore.Restore(target, data)
        if type(data) ~= "table" then return end
        for k, v in pairs(data) do
            if target[k] ~= nil and type(target[k]) == type(v) then target[k] = v end
        end
    end
end

-- paragraph -> object with a .Text setter
local function MakeLabel(para)
    local obj = { __instance = para and para.DescLabel }
    return setmetatable(obj, { __newindex = function(_, k, v)
        if k == "Text" then pcall(function() para:SetDesc(tostring(v)) end) end
    end })
end


local AccountTab = EarlyAccountTab
local WebhookTab = Tabs.Webhook
Tabs.Account = AccountTab


-- ================== ACCOUNT TAB ==================
AccountTab:AddSection("📊 Account Overview")
AccountTab:AddParagraph({ Title = "Info", Content = "Read from your player data. N/A = this value was not found." })
local ReplicatedStorageSvc = game:GetService("ReplicatedStorage")
local function FindGui(path)
    local cur = PlayerGui
    for seg in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end
local function CountShards()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    local total = 0
    for _, c in ipairs(items:GetChildren()) do
        if c.Name:lower():find("shard", 1, true) then
            local q = 1
            local label = c:FindFirstChild("Quantity", true)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                q = tonumber((label.Text:gsub("[^%d]", ""))) or 1
            end
            total += q
        end
    end
    return total
end
local function CurrentFamily()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    for _, c in ipairs(items:GetChildren()) do
        local id, name = c.Name:match("^(%d+)%s*%-%s*(.+)$")
        if id and tonumber(id) % 100 == 2 then
            local main = c:FindFirstChild("Main")
            local eq = main and main:FindFirstChild("Equipped")
            if eq and eq:IsA("GuiObject") and eq.Visible then
                local check = eq:FindFirstChild("Checkmark")
                local on = true
                if check and check:IsA("ImageLabel") and check.ImageTransparency >= 1 then on = false end
                if on then return name end
            end
        end
    end
    return "None"
end
local function AttrTrue(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local x = v:lower()
        return x == "true" or x == "yes" or x == "1"
    end
    return false
end
local hiddenLabelCache, hiddenLabelAt = nil, 0
local function FindWarningLabel()
    if os.clock() - hiddenLabelAt < 15 then return hiddenLabelCache end
    hiddenLabelAt = os.clock()
    hiddenLabelCache = false
    local n = 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        n += 1
        if n % 600 == 0 then task.wait() end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = (d.Text or ""):lower()
            if t:find("exploiter", 1, true) or t:find("shadow ban", 1, true) or t:find("shadowban", 1, true) then
                hiddenLabelCache = d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
                break
            end
        end
    end
    return hiddenLabelCache
end
local function ShadowStatus()
    if FindWarningLabel() then return "✅" end
    if AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted")) then
        return "✅"
    end
    return "❌"
end
local function FlagCompare()
    local others, flagged = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            others += 1
            if AttrTrue(plr:GetAttribute("Exploiter")) or AttrTrue(plr:GetAttribute("Blacklisted")) then
                flagged += 1
            end
        end
    end
    local mine = (AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted"))) and "flagged" or "clear"
    return ("You: %s | Others flagged: %d/%d"):format(mine, flagged, others)
end
local FIELDS = {
    { key = "ShadowBan", title = "🛠️ Shadow Ban", raw = true, aliases = {}, calc = ShadowStatus,
      colors = { ["✅"] = Color3.fromRGB(80, 200, 120), ["❌"] = Color3.fromRGB(235, 87, 87) } },
    { key = "FlagCompare", title = "🔍 Flag Compare", raw = true, aliases = {}, calc = FlagCompare },
    { key = "Blacklisted", title = "🚫 Blacklisted", flag = true, aliases = { "blacklisted" } },
    { key = "Exploiter", title = "⚠️ Exploiter Flag", flag = true, aliases = { "exploiter" } },
    { key = "Level",     title = "▶️ Level",    aliases = { "level", "lvl", "playerlevel" } },
    { key = "XP",        title = "📈 XP",       aliases = {}, strip = "^XP:%s*",
      gui = "Interface.Gear_Up.XP.Percentage" },
    { key = "Prestige",  title = "🔺 Prestige", aliases = { "prestige", "prestigelevel" } },
    { key = "Gold",      title = "💰 Gold",     aliases = { "gold", "coins", "money" },
      gui = "Interface.Topbar.Main.Currencies.Gold.Amount" },
    { key = "Gems",      title = "💎 Gems",     aliases = { "gems", "gem" },
      gui = "Interface.Topbar.Main.Currencies.Gems.Amount" },
    { key = "Family",    title = "⚡ Family",   aliases = { "family", "familyname", "clan" }, calc = CurrentFamily },
    { key = "Title",     title = "🏷️ Title",    aliases = { "title" }, pretty = true },
    { key = "Shards",    title = "✨ Shards",   aliases = { "shards", "shard" }, calc = CountShards },
}
for _, f in ipairs(FIELDS) do
    local para = AccountTab:AddParagraph({ Title = f.title, Content = "..." })
    f.label = MakeLabel(para)
    f.last = nil
end
local function NormName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end
local function Fmt(v)
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        local s = tostring(math.floor(v))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    return tostring(v)
end
local function Truthy(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "yes" or s == "1"
    end
    return false
end
local dataRoots = { LocalPlayer }
local lastRootScan = 0
local function ScanRoots(force)
    if not force and os.clock() - lastRootScan < 15 then return end
    lastRootScan = os.clock()
    local roots = { LocalPlayer }
    local uid = tostring(LocalPlayer.UserId)
    local n = 0
    for _, d in ipairs(ReplicatedStorageSvc:GetDescendants()) do
        n += 1
        if n % 500 == 0 then task.wait() end
        if d.Name == LocalPlayer.Name or d.Name == uid then
            table.insert(roots, d)
        end
    end
    dataRoots = roots
end
local SKIP_NAMES = { PlayerGui = true, PlayerScripts = true }
local function CollectEntries()
    local entries = {}
    local function keep(v)
        local t = type(v)
        return t == "number" or t == "string" or t == "boolean"
    end
    local function walk(inst, depth)
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if keep(v) then
                    entries[#entries + 1] = { name = k, value = v, path = inst:GetFullName() .. " @" .. k }
                end
            end
            if inst:IsA("ValueBase") then
                local ok, v = pcall(function() return inst.Value end)
                if ok and keep(v) then
                    entries[#entries + 1] = { name = inst.Name, value = v, path = inst:GetFullName() }
                end
            end
        end)
        if depth >= 6 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if not SKIP_NAMES[c.Name] then walk(c, depth + 1) end
        end
    end
    for _, root in ipairs(dataRoots) do
        if root and root.Parent then walk(root, 0) end
    end
    return entries
end
local function IsExcludedPath(path)
    return path:find("%.Boosts") ~= nil or path:find("%.Gamepasses") ~= nil
end
local function LookupField(entries, field)
    for _, alias in ipairs(field.aliases) do
        for _, e in ipairs(entries) do
            if NormName(e.name) == alias and not IsExcludedPath(e.path) then
                return e.value
            end
        end
    end
    return nil
end
local function ReadGui(path)
    local cur = FindGui(path)
    if cur and (cur:IsA("TextLabel") or cur:IsA("TextButton")) then
        local t = (cur.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then return t end
    end
    return nil
end
local function LabelObject(label)
    local inst = label and label.__instance
    if not inst then return nil end
    if inst:IsA("TextLabel") then return inst end
    return inst:FindFirstChildWhichIsA("TextLabel", true)
end
local lastEntries = {}
local function RefreshOverview()
    ScanRoots(false)
    local entries = CollectEntries()
    lastEntries = entries
    for _, f in ipairs(FIELDS) do
        local v
        if f.calc then
            local okC, r = pcall(f.calc)
            if okC then v = r end
        end
        if v == nil and f.gui then v = ReadGui(f.gui) end
        if v == nil then v = LookupField(entries, f) end
        local text
        if v == nil then
            text = "N/A"
        elseif f.raw then
            text = tostring(v)
        elseif f.flag then
            text = Truthy(v) and "⚠️ Yes" or "✅ No"
        elseif f.strip then
            text = (tostring(v):gsub(f.strip, ""))
        elseif f.pretty then
            text = (tostring(v):gsub("_", " "))
        else
            text = Fmt(v)
        end
        if text ~= f.last then
            f.last = text
            pcall(function() f.label.Text = text end)
            if f.colors and f.colors[text] then
                pcall(function()
                    local obj = LabelObject(f.label)
                    if obj then obj.TextColor3 = f.colors[text] end
                end)
            end
        end
    end
end
task.spawn(function()
    while Alive() do
        pcall(RefreshOverview)
        for _ = 1, 12 do
            if not Alive() then return end
            task.wait(0.25)
        end
    end
end)

-- ================== WEBHOOK (Rewards Logger) ==================
SH.Guard("webhook", function()

    local player = LocalPlayer

    local webhookURL = ""
    local sendWebhook = false
    local showUsername = true
    local thumbnailURL = "https://media.discordapp.net/attachments/1159475375752106086/1370816214242164836/image.png"

    -- Toggle to control whether webhook should be sent
    Tabs.Webhook:AddToggle("SendWebhookToggle", {
        Title = "Notify Webhook",
        Default = false,
        Callback = function(Value)
            sendWebhook = Value
        end
    })

    -- Toggle to display Roblox username
    Tabs.Webhook:AddToggle("DisplayUsernameToggle", {
        Title = "Display Roblox Username",
        Default = true,
        Callback = function(Value)
            showUsername = Value
        end
    })

    -- Input for the webhook URL
    Tabs.Webhook:AddInput("WebhookInput", {
        Title = "Webhook",
        Placeholder = "https://discord.com/api/webhooks/...",
        Finished = true,
        Callback = function(Value)
            webhookURL = Value
        end
    })

    -- Check visibility of GUI
    local function isActuallyVisible(instance)
        if not instance then return false end
        if not instance:IsDescendantOf(player.PlayerGui) then return false end
        while instance and instance ~= player.PlayerGui do
            if instance:IsA("GuiObject") and not instance.Visible then
                return false
            end
            instance = instance.Parent
        end
        return true
    end

    -- Get Retry button
    local function getRetryButton()
        local interface = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("Interface")
        local rewards = interface and interface:FindFirstChild("Rewards")
        local rewardsMain = rewards and rewards:FindFirstChild("Main")
        local retryBtn = rewardsMain
            and rewardsMain:FindFirstChild("Info")
            and rewardsMain.Info:FindFirstChild("Main")
            and rewardsMain.Info.Main:FindFirstChild("Buttons")
            and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")
        return retryBtn
    end

    -- Get GUI text value
    local function getText(path)
        local node = player:FindFirstChild("PlayerGui")
        for _, part in ipairs(string.split(path, ".")) do
            if node then
                node = node:FindFirstChild(part)
            end
        end
        return node and node.Text or "0"
    end

    -- Get items and stats panels
    local function getItems()
        local gui = player:FindFirstChild("PlayerGui")
        local interface = gui and gui:FindFirstChild("Interface")
        local rewards = interface and interface:FindFirstChild("Rewards")
        local main = rewards and rewards:FindFirstChild("Main")
        local info = main and main:FindFirstChild("Info")
        local infoMain = info and info:FindFirstChild("Main")
        local items = infoMain and infoMain:FindFirstChild("Items")
        local stats = infoMain and infoMain:FindFirstChild("Stats")
        return items, stats
    end

    -- Loop check and send webhook
    local lastMissionTime = nil

    task.spawn(function()
        while Alive() do
            local retryBtn = getRetryButton()
            local items, stats = getItems()
            if isActuallyVisible(retryBtn) and stats and sendWebhook and webhookURL ~= "" then
                local currentTime = getText("Interface.Rewards.Main.Info.Main.Stats.Time_Taken.Amount")
                if currentTime ~= "0" and currentTime ~= lastMissionTime then
                    lastMissionTime = currentTime

                    local gold = getText("Interface.Rewards.Main.Info.Main.Items.Gold.Main.Inner.Quantity")
                    local xp = getText("Interface.Rewards.Main.Info.Main.Items.XP.Main.Inner.Quantity")
                    local bp_xp = getText("Interface.Rewards.Main.Info.Main.Items.BP_XP.Main.Inner.Quantity")
                    local gems = getText("Interface.Rewards.Main.Info.Main.Items.Gems.Main.Inner.Quantity")
                    local serum = getText("Interface.Rewards.Main.Info.Main.Items.Serum.Main.Inner.Quantity")
                    local common = getText("Interface.Rewards.Main.Info.Main.Items.Common_Perk.Main.Inner.Quantity")
                    local secret = getText("Interface.Rewards.Main.Info.Main.Items.Secret_Perk.Main.Inner.Quantity")
                    local epic = getText("Interface.Rewards.Main.Info.Main.Items.Epic_Perk.Main.Inner.Quantity")
                    local prestige = getText("Interface.Rewards.Main.Info.Main.Items.Prestige_Scroll.Main.Inner.Quantity")

                    local damage = getText("Interface.Rewards.Main.Info.Main.Stats.Damage_Dealt.Amount")
                    local kills = getText("Interface.Rewards.Main.Info.Main.Stats.Titans_Killed.Amount")
                    local crits = getText("Interface.Rewards.Main.Info.Main.Stats.Critical_Hits.Amount")

                    local timeString = os.date("%d-%b-%Y %I:%M %p")

                    local fields = {
                        {name = "**User:**", value = tostring(showUsername and player.Name or "Disabled"), inline = false},
                        {name = "**Stats:**", value = string.format(
                            "%s Time Taken\n%s Damage Dealt\n%s Titan Kills\n%s Critical Hits", currentTime, damage, kills, crits
                        ), inline = true},
                        {name = "**Rewards:**", value = string.format(
                            "%s Gold\n%s XP\n%s Gems", gold, xp, gems
                        ), inline = true},
                        {name = "**Drops:**", value = string.format(
                            "BP XP: %s\nCommon: %s\nSecret: %s\nEpic: %s\nPrestige: %s", bp_xp, common, secret, epic, prestige
                        ), inline = true},
                        {name = "**Special Rewards:**", value = string.format(
                            "Serum: %s", serum
                        ), inline = false}
                    }

                    local embed = {
                        title = "AOT:R Rewards Logger",
                        thumbnail = { url = thumbnailURL },
                        fields = fields,
                        footer = { text = "Sent at: " .. timeString }
                    }

                    local data = {
                        content = (tonumber(serum) or 0) > 0 and "@everyone" or nil,
                        embeds = {embed}
                    }

                    request({
                        Url = webhookURL,
                        Method = "POST",
                        Headers = {["Content-Type"] = "application/json"},
                        Body = HttpService:JSONEncode(data)
                    })
                end
            end
            task.wait(1)
        end
    end)
end)


end)
if not okMod then warn("[Aotr:update5] Account/Webhook/Refill module failed: " .. tostring(errMod)) end
end

--//==============================\\--
--||         SAVE / LOAD          ||--
--\\==============================//--

Window:SelectTab(Tabs.Main)

pcall(function()
    local menu = Tabs.Settings._tab:AddRightGroupbox("Menu")
    menu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
        Default = "LeftControl", NoUI = true, Text = "Menu keybind",
    })
    Library.ToggleKeybind = Library.Options.MenuKeybind
end)

local function safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then warn("[Aotr:update5] " .. name .. " failed: " .. tostring(err)) end
end

safe("ThemeManager", function()
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Aotr_update5")
end)
safe("SaveManager", function()
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("Aotr_update5")
    SaveManager:BuildConfigSection(Tabs.Settings._tab)
end)
safe("ThemeTab", function() ThemeManager:ApplyToTab(Tabs.Settings._tab) end)
safe("Autoload", function() SaveManager:LoadAutoloadConfig() end)

-- ============================================================
--  BACKGROUND IMAGE (Attack on Titan art, embedded)
-- ============================================================
do
local BG_IMAGE_TRANSPARENCY = 0.35  -- 0 = fully visible image, 1 = hidden
local BG_PANEL_TRANSPARENCY = 0.55  -- see-through panels so the image shows (0.3 - 0.8)

local BG_DATA = table.concat({
    "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",
    "L4+Sf//Z",
})

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64decode(s)
    local map = {}
    for i = 1, 64 do map[B64:byte(i)] = i - 1 end
    local out, n, buf, bits = {}, 0, 0, 0
    for i = 1, #s do
        local v = map[s:byte(i)]
        if v then
            buf = bit32.bor(bit32.lshift(buf, 6), v)
            bits += 6
            if bits >= 8 then
                bits -= 8
                n += 1
                out[n] = string.char(bit32.band(bit32.rshift(buf, bits), 255))
                buf = bit32.band(buf, bit32.lshift(1, bits) - 1)
            end
        end
    end
    return table.concat(out)
end

task.spawn(function()
    local ok, err = pcall(function()
        assert(writefile and getcustomasset, "executor has no writefile/getcustomasset")
        local path = "Aotr_update5_bg.jpg"
        writefile(path, b64decode(BG_DATA))
        local asset = getcustomasset(path)

        -- find the Obsidian window frame (we created it at 640x480)
        local main
        for _ = 1, 40 do
            for _, d in ipairs(Library.ScreenGui:GetDescendants()) do
                if d:IsA("Frame") and d.Size == UDim2.fromOffset(640, 480) then main = d break end
            end
            if main then break end
            task.wait(0.25)
        end
        assert(main, "window frame not found")

        local img = Instance.new("ImageLabel")
        img.Name = "AotrBackground"
        img.BackgroundTransparency = 1
        img.Size = UDim2.fromScale(1, 1)
        img.Image = asset
        img.ScaleType = Enum.ScaleType.Crop
        img.ImageTransparency = BG_IMAGE_TRANSPARENCY
        img.ZIndex = 0
        img.Active = false
        img.Parent = main
        local cr = main:FindFirstChildOfClass("UICorner")
        if cr then cr:Clone().Parent = img end

        local function soften(o)
            if o ~= img and (o:IsA("Frame") or o:IsA("ScrollingFrame")) and o.BackgroundTransparency < BG_PANEL_TRANSPARENCY then
                o.BackgroundTransparency = BG_PANEL_TRANSPARENCY
            end
        end
        for _, d in ipairs(main:GetDescendants()) do soften(d) end
        main.DescendantAdded:Connect(function(d) task.defer(soften, d) end)
    end)
    if not ok then warn("[Aotr:update5] background failed: " .. tostring(err)) end
end)
end

Notifier:Notify({
    Title   = "Aotr:update5",
    Content = "Loaded successfully! Tap the tray icon to hide/show the UI.",
    Duration = 4,
})
