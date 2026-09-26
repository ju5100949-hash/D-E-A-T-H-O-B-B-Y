-- =========================================
--             SEZXE MOD v1.0
--     Delta Executor | Universal Obby
-- =========================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")

local LP     = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ════════════════════════════════════════
--              STATE
-- ════════════════════════════════════════
local speedEnabled  = false
local flyEnabled    = false
local noclipEnabled = false
local flyConn, noclipConn
local lockedPlayers = {}
local savedParts    = {}

-- ════════════════════════════════════════
--              HELPERS
-- ════════════════════════════════════════
local function getChar() return LP.Character or LP.CharacterAdded:Wait() end
local function getHRP()  return getChar():FindFirstChild("HumanoidRootPart") end
local function getHum()  return getChar():FindFirstChildOfClass("Humanoid") end

-- ════════════════════════════════════════
--              SPEED
-- ════════════════════════════════════════
local function applySpeed(state)
    speedEnabled = state
    local h = getHum()
    if h then h.WalkSpeed = state and 100 or 16 end
end

-- ════════════════════════════════════════
--              FLY
-- ════════════════════════════════════════
local function stopFly()
    flyEnabled = false
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    local hrp = getHRP()
    if hrp then
        local bv = hrp:FindFirstChild("SX_Vel")
        local bg = hrp:FindFirstChild("SX_Gyro")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
    local h = getHum()
    if h then h.PlatformStand = false end
end

local function startFly()
    flyEnabled = true
    local hrp = getHRP()
    local h   = getHum()
    if not hrp or not h then return end

    h.PlatformStand = true

    local bv      = Instance.new("BodyVelocity")
    bv.Name       = "SX_Vel"
    bv.MaxForce   = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity   = Vector3.zero
    bv.Parent     = hrp

    local bg      = Instance.new("BodyGyro")
    bg.Name       = "SX_Gyro"
    bg.MaxTorque  = Vector3.new(1e9, 1e9, 1e9)
    bg.D          = 100
    bg.CFrame     = hrp.CFrame
    bg.Parent     = hrp

    flyConn = RunService.Heartbeat:Connect(function()
        if not flyEnabled then return end
        local hrp2 = getHRP()
        local bv2  = hrp2 and hrp2:FindFirstChild("SX_Vel")
        local bg2  = hrp2 and hrp2:FindFirstChild("SX_Gyro")
        if not (hrp2 and bv2 and bg2) then return end

        local dir = Vector3.zero
        local cf  = Camera.CFrame
        local UIS = UserInputService

        if UIS:IsKeyDown(Enum.KeyCode.W)            then dir = dir + cf.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)            then dir = dir - cf.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)            then dir = dir - cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)            then dir = dir + cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)        then dir = dir + Vector3.yAxis  end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl)  then dir = dir - Vector3.yAxis  end

        bv2.Velocity = dir.Magnitude > 0 and dir.Unit * 80 or Vector3.zero
        bg2.CFrame   = cf
    end)
end

-- ════════════════════════════════════════
--              NOCLIP
-- ════════════════════════════════════════
local function applyNoclip(state)
    noclipEnabled = state
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            if not noclipEnabled then noclipConn:Disconnect(); return end
            local c = LP.Character
            if not c then return end
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                    p.CanCollide = false
                end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() end
        local c = LP.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = true end
            end
        end
    end
end

-- ════════════════════════════════════════
--              LOCK PLAYER
-- ════════════════════════════════════════
local function lockPlayer(player)
    if lockedPlayers[player.Name] then return end
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not lockedPlayers[player.Name] then conn:Disconnect(); return end
        local c   = player.Character
        if not c then return end
        local hrp = c:FindFirstChild("HumanoidRootPart")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hrp then hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero end
        if hum then hum.WalkSpeed = 0; hum.JumpPower = 0 end
    end)
    lockedPlayers[player.Name] = conn
end

local function unlockPlayer(player)
    local conn = lockedPlayers[player.Name]
    if conn then conn:Disconnect(); lockedPlayers[player.Name] = nil end
    local c = player.Character
    if c then
        local hum = c:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end
end

-- ════════════════════════════════════════
--              KICK (local)
-- ════════════════════════════════════════
local function kickPlayer(player)
    if player == LP then return end
    local c = player.Character
    if c then c:Destroy() end
end

-- ════════════════════════════════════════
--              MAP EDITOR
-- ════════════════════════════════════════
local function editMap(mode)
    if mode == "restore" then
        for _, d in ipairs(savedParts) do
            if d.p and d.p.Parent then
                d.p.Material     = d.mat
                d.p.Color        = d.col
                d.p.Transparency = d.tr
            end
        end
        savedParts = {}
        return
    end

    savedParts = {}
    local lc = LP.Character

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not (lc and obj:IsDescendantOf(lc)) then
            table.insert(savedParts, { p = obj, mat = obj.Material, col = obj.Color, tr = obj.Transparency })

            if mode == "neon" then
                obj.Material = Enum.Material.Neon
                obj.Color    = Color3.fromHSV(math.random(), 1, 1)

            elseif mode == "chaos" then
                obj.Material     = Enum.Material.SmoothPlastic
                obj.Color        = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
                obj.Transparency = math.random() * 0.4

            elseif mode == "ghost" then
                if not obj:FindFirstChildOfClass("SpecialMesh") then
                    obj.Transparency = 0.85
                end

            elseif mode == "glass" then
                obj.Material     = Enum.Material.Glass
                obj.Transparency = 0.4
                obj.Color        = Color3.fromRGB(200, 230, 255)
            end
        end
    end
end

-- ════════════════════════════════════════
--              AUTO TOP 1
-- ════════════════════════════════════════
local function autoTop1()
    local hrp = getHRP()
    if not hrp then return end

    local best, bestNum = nil, -1
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n   = obj.Name:lower()
            local num = tonumber(obj.Name:match("%d+")) or 0
            if (n:find("finish") or n:find("end") or n:find("goal") or n:find("win") or n:find("exit")) and num > bestNum then
                best    = obj
                bestNum = num
            end
        end
    end

    if best then
        hrp.CFrame = best.CFrame + Vector3.new(0, 6, 0)
        return
    end

    -- Fallback: highest numbered stage part
    local stages = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local num = tonumber(obj.Name:match("^(%d+)$"))
                     or tonumber(obj.Name:match("[Ss]tage(%d+)"))
                     or tonumber(obj.Name:match("[Pp]art(%d+)"))
            if num then table.insert(stages, { p = obj, n = num }) end
        end
    end
    if #stages > 0 then
        table.sort(stages, function(a, b) return a.n > b.n end)
        hrp.CFrame = stages[1].p.CFrame + Vector3.new(0, 6, 0)
    end
end

-- ════════════════════════════════════════
--         RESPAWN RE-APPLY
-- ════════════════════════════════════════
LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if speedEnabled  then applySpeed(true)  end
    if flyEnabled    then startFly()         end
    if noclipEnabled then applyNoclip(true)  end
end)

-- ════════════════════════════════════════
--                  GUI
-- ════════════════════════════════════════
do local old = CoreGui:FindFirstChild("SEZXE_MOD"); if old then old:Destroy() end end

local SG = Instance.new("ScreenGui")
SG.Name           = "SEZXE_MOD"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
pcall(function() SG.Parent = CoreGui end)
if not SG.Parent then SG.Parent = LP.PlayerGui end

-- ── Palette ──────────────────────────────
local C = {
    bg      = Color3.fromRGB(8,   8,  18),
    card    = Color3.fromRGB(15,  15, 32),
    purple  = Color3.fromRGB(110,  0, 240),
    accent  = Color3.fromRGB(160, 80, 255),
    green   = Color3.fromRGB(0,  210, 100),
    red     = Color3.fromRGB(220, 50,  75),
    amber   = Color3.fromRGB(220, 160,  0),
    blue    = Color3.fromRGB(30,  130, 220),
    white   = Color3.fromRGB(255, 255, 255),
    gray    = Color3.fromRGB(130, 130, 155),
    border  = Color3.fromRGB(50,  20,  90),
    stripe  = Color3.fromRGB(18,  18,  40),
}

local function mkCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end
local function mkStroke(p, col, t)
    local s = Instance.new("UIStroke"); s.Color = col or C.border; s.Thickness = t or 1; s.Parent = p
end
local function mkGrad(p, a, b, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new{ ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b) }
    g.Rotation = rot or 90; g.Parent = p
end
local function mkLabel(p, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.Gotham
    for k, v in pairs(props) do l[k] = v end
    l.Parent = p; return l
end

-- ════════════════════════════════════════
--              MAIN WINDOW
-- ════════════════════════════════════════
local Win = Instance.new("Frame")
Win.Name             = "Win"
Win.Size             = UDim2.new(0, 410, 0, 560)
Win.Position         = UDim2.new(0, 24, 0, 70)
Win.BackgroundColor3 = C.bg
Win.BorderSizePixel  = 0
Win.Parent           = SG
mkCorner(Win, 14)
mkStroke(Win, C.purple, 1.5)

-- Glow
local Glow = Instance.new("ImageLabel")
Glow.Size               = UDim2.new(1, 70, 1, 70)
Glow.Position           = UDim2.new(0, -35, 0, -35)
Glow.BackgroundTransparency = 1
Glow.Image              = "rbxassetid://6014261993"
Glow.ImageColor3        = C.purple
Glow.ImageTransparency  = 0.65
Glow.ZIndex             = -1
Glow.ScaleType          = Enum.ScaleType.Slice
Glow.SliceCenter        = Rect.new(49, 49, 450, 450)
Glow.Parent             = Win

-- ── Title Bar ────────────────────────────
local TBar = Instance.new("Frame")
TBar.Size            = UDim2.new(1, 0, 0, 52)
TBar.BackgroundColor3 = C.purple
TBar.BorderSizePixel = 0
TBar.Parent          = Win
mkCorner(TBar, 14)
mkGrad(TBar, Color3.fromRGB(145, 0, 255), Color3.fromRGB(60, 0, 180), 90)

-- Bottom-corner fixer
local TFix = Instance.new("Frame")
TFix.Size             = UDim2.new(1, 0, 0.5, 0)
TFix.Position         = UDim2.new(0, 0, 0.5, 0)
TFix.BorderSizePixel  = 0
TFix.ZIndex           = 2
TFix.Parent           = TBar
mkGrad(TFix, Color3.fromRGB(145, 0, 255), Color3.fromRGB(60, 0, 180), 90)

-- Accent stripe under title
local TStripe = Instance.new("Frame")
TStripe.Size         = UDim2.new(1, 0, 0, 2)
TStripe.Position     = UDim2.new(0, 0, 1, -1)
TStripe.BorderSizePixel = 0
TStripe.ZIndex       = 5
TStripe.Parent       = TBar
mkGrad(TStripe, C.accent, Color3.fromRGB(0, 200, 255), 0)

mkLabel(TBar, { Size = UDim2.new(0, 36, 1, 0), Position = UDim2.new(0, 10, 0, 0), Text = "⚡", TextSize = 22, TextColor3 = C.white, Font = Enum.Font.GothamBold, ZIndex = 3 })
mkLabel(TBar, { Size = UDim2.new(0, 180, 0, 28), Position = UDim2.new(0, 46, 0, 5), Text = "SEZXE MOD", TextSize = 19, TextColor3 = C.white, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
mkLabel(TBar, { Size = UDim2.new(0, 220, 0, 14), Position = UDim2.new(0, 46, 0, 33), Text = "v1.0  ·  Delta Executor  ·  Universal Obby", TextSize = 9, TextColor3 = Color3.fromRGB(200, 175, 255), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })

local function mkIconBtn(pos, col, txt)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0, 28, 0, 28)
    b.Position         = pos
    b.BackgroundColor3 = col
    b.Text             = txt
    b.TextColor3       = C.white
    b.TextSize         = 14
    b.Font             = Enum.Font.GothamBold
    b.ZIndex           = 4
    b.Parent           = TBar
    mkCorner(b, 7)
    return b
end

local BtnClose = mkIconBtn(UDim2.new(1, -36, 0.5, -14), C.red,   "✕")
local BtnMin   = mkIconBtn(UDim2.new(1, -68, 0.5, -14), C.amber, "−")
BtnClose.MouseButton1Click:Connect(function() SG:Destroy() end)

-- Drag
do
    local drag, ds, sp = false, Vector3.zero, UDim2.new()
    TBar.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        drag = true; ds = i.Position; sp = Win.Position
    end)
    TBar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not drag or i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local d = i.Position - ds
        Win.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
    end)
end

-- ── Scroll Frame ──────────────────────────
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size               = UDim2.new(1, 0, 1, -52)
Scroll.Position           = UDim2.new(0, 0, 0, 52)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel    = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = C.accent
Scroll.CanvasSize         = UDim2.new(0, 0, 0, 0)
Scroll.Parent             = Win

local SLayout = Instance.new("UIListLayout")
SLayout.SortOrder = Enum.SortOrder.LayoutOrder
SLayout.Padding   = UDim.new(0, 7)
SLayout.Parent    = Scroll

local SPad = Instance.new("UIPadding")
SPad.PaddingLeft  = UDim.new(0, 12)
SPad.PaddingRight = UDim.new(0, 12)
SPad.PaddingTop   = UDim.new(0, 10)
SPad.Parent       = Scroll

SLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, SLayout.AbsoluteContentSize.Y + 20)
end)

-- ── Widget helpers ────────────────────────
local order = 0

local function sec(label)
    order += 1
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 24)
    f.BackgroundColor3 = C.stripe
    f.BorderSizePixel  = 0
    f.LayoutOrder      = order
    f.Parent           = Scroll
    mkCorner(f, 5)

    local bar = Instance.new("Frame")
    bar.Size           = UDim2.new(0, 3, 0.55, 0)
    bar.Position       = UDim2.new(0, 7, 0.225, 0)
    bar.BackgroundColor3 = C.purple
    bar.BorderSizePixel = 0
    bar.Parent         = f
    mkCorner(bar, 2)

    mkLabel(f, { Size = UDim2.new(1, -18, 1, 0), Position = UDim2.new(0, 16, 0, 0), Text = label, TextSize = 11, TextColor3 = C.accent, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left })
end

local function tog(label, cb)
    order += 1
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 42)
    card.BackgroundColor3 = C.card
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.Parent           = Scroll
    mkCorner(card, 8)
    mkStroke(card, C.border)

    mkLabel(card, { Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 12, 0, 0), Text = label, TextSize = 13, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left })

    local sbg = Instance.new("Frame")
    sbg.Size             = UDim2.new(0, 44, 0, 23)
    sbg.Position         = UDim2.new(1, -54, 0.5, -11)
    sbg.BackgroundColor3 = Color3.fromRGB(32, 32, 52)
    sbg.BorderSizePixel  = 0
    sbg.Parent           = card
    mkCorner(sbg, 11)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 17, 0, 17)
    knob.Position         = UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = C.gray
    knob.BorderSizePixel  = 0
    knob.Parent           = sbg
    mkCorner(knob, 9)

    local on = false
    local function flip()
        on = not on
        TweenService:Create(knob, TweenInfo.new(0.12), {
            Position         = on and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            BackgroundColor3 = on and C.green or C.gray,
        }):Play()
        TweenService:Create(sbg, TweenInfo.new(0.12), {
            BackgroundColor3 = on and Color3.fromRGB(0, 155, 70) or Color3.fromRGB(32, 32, 52),
        }):Play()
        if cb then cb(on) end
    end

    sbg.InputBegan:Connect(function(i)  if i.UserInputType == Enum.UserInputType.MouseButton1 then flip() end end)
    card.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then flip() end end)
end

local function btn(label, col, cb)
    order += 1
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = col or C.purple
    b.Text             = label
    b.TextColor3       = C.white
    b.TextSize         = 13
    b.Font             = Enum.Font.GothamBold
    b.LayoutOrder      = order
    b.Parent           = Scroll
    mkCorner(b, 8)
    b.MouseEnter:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = C.accent }):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = col or C.purple }):Play() end)
    if cb then b.MouseButton1Click:Connect(cb) end
    return b
end

-- ════════════════════════════════════════
--              SECTIONS
-- ════════════════════════════════════════

-- ── Movement ──
sec("⚡  MOVEMENT")
tog("  Speed Hack  —  WalkSpeed × 100",       function(v) applySpeed(v)                                end)
tog("  Fly Mode  —  WASD · Space · LCtrl",    function(v) if v then startFly() else stopFly() end      end)
tog("  Noclip  —  Phase Through Walls",        function(v) applyNoclip(v)                              end)

-- ── Obby ──
sec("🏆  OBBY TOOLS")
btn("  🥇  Auto Top 1 / Teleport to Finish",   Color3.fromRGB(0, 145, 85),  function() task.spawn(autoTop1) end)
btn("  🔁  Teleport ke SpawnPoint",            Color3.fromRGB(30, 110, 200), function()
    local hrp   = getHRP()
    local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
    if hrp and spawn then hrp.CFrame = spawn.CFrame + Vector3.new(0, 5, 0) end
end)

-- ── Map Editor ──
sec("🗺  MAP EDITOR")
do
    order += 1
    local row = Instance.new("Frame")
    row.Size               = UDim2.new(1, 0, 0, 38)
    row.BackgroundTransparency = 1
    row.LayoutOrder        = order
    row.Parent             = Scroll

    local rl = Instance.new("UIListLayout")
    rl.FillDirection = Enum.FillDirection.Horizontal
    rl.Padding       = UDim.new(0, 5)
    rl.Parent        = row

    local defs = {
        { "🟣 Neon",   Color3.fromRGB(140, 0, 255), "neon"    },
        { "🔶 Chaos",  Color3.fromRGB(200, 90,  0),  "chaos"   },
        { "👻 Ghost",  Color3.fromRGB(50,  50, 80),  "ghost"   },
        { "↩ Reset",   Color3.fromRGB(38,  38, 60),  "restore" },
    }
    for _, d in ipairs(defs) do
        local mb = Instance.new("TextButton")
        mb.Size             = UDim2.new(0.25, -4, 1, 0)
        mb.BackgroundColor3 = d[2]
        mb.Text             = d[1]
        mb.TextColor3       = C.white
        mb.TextSize         = 10
        mb.Font             = Enum.Font.GothamBold
        mb.Parent           = row
        mkCorner(mb, 7)
        local mode = d[3]
        mb.MouseButton1Click:Connect(function() task.spawn(editMap, mode) end)
    end
end

-- ── Player Control ──
sec("👥  PLAYER CONTROL")
order += 1
local pCont = Instance.new("Frame")
pCont.Size             = UDim2.new(1, 0, 0, 135)
pCont.BackgroundColor3 = C.card
pCont.LayoutOrder      = order
pCont.Parent           = Scroll
mkCorner(pCont, 8)
mkStroke(pCont, C.border)

local pScroll = Instance.new("ScrollingFrame")
pScroll.Size               = UDim2.new(1, -8, 1, -8)
pScroll.Position           = UDim2.new(0, 4, 0, 4)
pScroll.BackgroundTransparency = 1
pScroll.BorderSizePixel    = 0
pScroll.ScrollBarThickness = 2
pScroll.ScrollBarImageColor3 = C.purple
pScroll.CanvasSize         = UDim2.new(0, 0, 0, 0)
pScroll.Parent             = pCont

local pLayout = Instance.new("UIListLayout")
pLayout.Padding  = UDim.new(0, 3)
pLayout.Parent   = pScroll

local function buildPlayerList()
    for _, c in ipairs(pScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local count = 0
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP then
            count += 1
            local row = Instance.new("Frame")
            row.Size             = UDim2.new(1, 0, 0, 28)
            row.BackgroundColor3 = Color3.fromRGB(16, 16, 36)
            row.LayoutOrder      = count
            row.Parent           = pScroll
            mkCorner(row, 5)

            mkLabel(row, {
                Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                Text = "👤  " .. pl.Name, TextSize = 11, TextColor3 = C.white,
                TextXAlignment = Enum.TextXAlignment.Left
            })

            local function rowBtn(xOff, col, txt)
                local b = Instance.new("TextButton")
                b.Size             = UDim2.new(0, 44, 0, 20)
                b.Position         = UDim2.new(1, xOff, 0.5, -10)
                b.BackgroundColor3 = col
                b.Text             = txt
                b.TextColor3       = C.white
                b.TextSize         = 9
                b.Font             = Enum.Font.GothamBold
                b.Parent           = row
                mkCorner(b, 5)
                return b
            end

            local lkBtn = rowBtn(-92, C.amber, "🔒 Lock")
            local lkOn  = false
            lkBtn.MouseButton1Click:Connect(function()
                lkOn = not lkOn
                if lkOn then
                    lockPlayer(pl)
                    lkBtn.BackgroundColor3 = C.green
                    lkBtn.Text             = "✓ Lock"
                else
                    unlockPlayer(pl)
                    lkBtn.BackgroundColor3 = C.amber
                    lkBtn.Text             = "🔒 Lock"
                end
            end)

            local kkBtn = rowBtn(-44, C.red, "✕ Kick")
            kkBtn.MouseButton1Click:Connect(function()
                kickPlayer(pl)
                row:Destroy()
            end)
        end
    end
    pScroll.CanvasSize = UDim2.new(0, 0, 0, count * 31)
end

buildPlayerList()
Players.PlayerAdded:Connect(function()   task.wait(0.5); buildPlayerList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.2); buildPlayerList() end)

btn("  🔄  Refresh Player List", Color3.fromRGB(26, 26, 50), function() buildPlayerList() end)

-- ── Keybinds ──
sec("⌨  KEYBINDS")
order += 1
local kb = Instance.new("Frame")
kb.Size             = UDim2.new(1, 0, 0, 50)
kb.BackgroundColor3 = C.card
kb.LayoutOrder      = order
kb.Parent           = Scroll
mkCorner(kb, 8)
mkStroke(kb, C.border)

local hints = {
    "RightShift  —  Toggle menu visibility",
    "Fly  →  WASD move · Space naik · LCtrl turun",
}
for i, h in ipairs(hints) do
    mkLabel(kb, {
        Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 8, 0, 5 + (i - 1) * 21),
        Text = "›  " .. h, TextSize = 10, TextColor3 = C.gray,
        TextXAlignment = Enum.TextXAlignment.Left
    })
end

-- ── Status Bar ──
order += 1
local stBar = Instance.new("Frame")
stBar.Size             = UDim2.new(1, 0, 0, 28)
stBar.BackgroundColor3 = Color3.fromRGB(8, 8, 20)
stBar.LayoutOrder      = order
stBar.Parent           = Scroll
mkCorner(stBar, 8)
mkStroke(stBar, C.green, 1)

mkLabel(stBar, {
    Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 8, 0, 0),
    Text = "✅  SEZXE MOD  ·  Active  ·  Delta Ready",
    TextSize = 10, TextColor3 = C.green,
    TextXAlignment = Enum.TextXAlignment.Left
})

-- ── Minimize ─────────────────────────────
local minimized = false
BtnMin.MouseButton1Click:Connect(function()
    minimized   = not minimized
    Scroll.Visible = not minimized
    Win.Size    = minimized and UDim2.new(0, 410, 0, 52) or UDim2.new(0, 410, 0, 560)
end)

-- ── RightShift toggle ─────────────────────
UserInputService.InputBegan:Connect(function(inp, gp)
    if not gp and inp.KeyCode == Enum.KeyCode.RightShift then
        Win.Visible = not Win.Visible
    end
end)

print("[SEZXE MOD] ⚡ v1.0 — Delta Executor loaded")
