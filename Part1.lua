--[[ Svclutcher Hub - Delta MOBILE (v2.2) ]]
local MyHubName = "Svclutcher Hub"
local VERSION   = "2.2"

local Players           = game:GetService("Players")
local LocalPlayer       = Players.LocalPlayer
local VirtualUser       = game:GetService("VirtualUser")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local TeleportService   = game:GetService("TeleportService")
local TweenService      = game:GetService("TweenService")
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

local CFG_FOLDER = "SvclutcherHub"
local CFG_FILE   = CFG_FOLDER .. "/config.json"

local settings = {
    tpfarm=false, arenaonly=true, hitboxaura=false, slapaura=false, slapmode="Safe",
    autoslap=false, slapples=false, killaura=false, autoability=false,
    antiragdoll=false, antiknock=false, antivoat=false, antifling=false,
    infinitejump=false, noclip=false, fly=false, sillyfly=false, autorespawn=false,
    playeresp=false, toolesp=false, gloveesp=false, slappleesp=false,
    boxesp=false, tracers=false, healthbar=true,
    autododge=false, aimassist=false, antiafk=false,
    trollevel=false, trollspin=false, trollshake=false, trollflip=false,
    walkspeed=20, jumpspeed=50, reachsize=16, clickspeed=0.08,
    flyspeed=55, flylift=0, aimstrength=0.28, espmaxdist=600,
}

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local Character, HumanoidRootPart, Humanoid
local charConns, conns = {}, {}
local toggles, cycles = {}, {}
local lastSafe = Vector3.new()
local lockTarget, trollTarget
local flyBV, flying = nil, false
local unloaded = false

local gloveOriginals = setmetatable({}, {__mode="k"})
local noclipStore    = setmetatable({}, {__mode="k"})

local applyNoclip, restoreNoclip, startFly, stopFly

local function addConn(c) table.insert(conns, c) return c end

---------------------------------------------------------------------
-- Notificaties
---------------------------------------------------------------------
local notifGui = Instance.new("ScreenGui")
notifGui.Name = "SvclutcherNotif"
notifGui.ResetOnSpawn = false
notifGui.DisplayOrder = 1000
notifGui.IgnoreGuiInset = true

local notifList = Instance.new("Frame")
notifList.BackgroundTransparency = 1
notifList.Size = UDim2.new(0, 300, 0, 200)
notifList.Position = UDim2.new(0.5, -150, 0, 50)
notifList.Parent = notifGui

local notifLay = Instance.new("UIListLayout")
notifLay.Padding = UDim.new(0, 6)
notifLay.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLay.Parent = notifList

local function notify(text)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    f.BorderSizePixel = 0
    f.Size = UDim2.new(1, 0, 0, 34)
    f.Parent = notifList

    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = f
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(90, 90, 120); s.Parent = f

    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, -14, 1, 0)
    l.Position = UDim2.new(0, 7, 0, 0)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = Color3.fromRGB(230, 230, 240)
    l.Text = tostring(text)
    l.Parent = f

    task.delay(2.6, function()
        if f and f.Parent then
            TweenService:Create(f, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
            TweenService:Create(l, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
            task.wait(0.3)
            f:Destroy()
        end
    end)
end

---------------------------------------------------------------------
-- Character binding
---------------------------------------------------------------------
local function clearCharConns()
    for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
    table.clear(charConns)
end

local function bindCharacter(c)
    clearCharConns()
    Character = c
    HumanoidRootPart = c:WaitForChild("HumanoidRootPart", 10)
    Humanoid = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 10)
    if not HumanoidRootPart or not Humanoid then return end

    task.wait(0.1)
    if Humanoid and Humanoid.Parent then
        Humanoid.WalkSpeed = settings.walkspeed
        Humanoid.UseJumpPower = true
        Humanoid.JumpPower = settings.jumpspeed
    end

    table.insert(charConns, c.DescendantAdded:Connect(function(d)
        if settings.antiragdoll and d:IsA("BallSocketConstraint") then d:Destroy() end
        if settings.noclip and d:IsA("BasePart") then
            if noclipStore[d] == nil then noclipStore[d] = d.CanCollide end
            d.CanCollide = false
        end
    end))

    if settings.noclip and applyNoclip then applyNoclip() end
    if settings.fly and startFly then startFly() end
end

bindCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
addConn(LocalPlayer.CharacterAdded:Connect(bindCharacter))

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function click()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local c = cam.ViewportSize / 2
    pcall(function()
        VirtualUser:Button1Down(c)
        VirtualUser:Button1Up(c)
    end)
end

local function alive(plr)
    if not plr or plr == LocalPlayer then return false end
    local ch = plr.Character
    if not ch then return false end
    local h = ch:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function hrpOf(plr)
    local ch = plr and plr.Character
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

-- arena detectie
local arenaCache, arenaCacheT = nil, 0

local function arenaBounds()
    if arenaCache and os.clock() - arenaCacheT < 1 then return arenaCache.cf, arenaCache.size end
    local arena = workspace:FindFirstChild("Arena")
    if not arena or not arena:IsA("Model") then return nil end
    local ok, cf, size = pcall(function() return arena:GetBoundingBox() end)
    if not ok or not cf or not size then return nil end
    arenaCache = {cf = cf, size = size}
    arenaCacheT = os.clock()
    return cf, size
end

local function inArena(pos)
    if not settings.arenaonly then return true end
    local cf, size = arenaBounds()
    if not cf then return true end
    local rel = cf:PointToObjectSpace(pos)
    return math.abs(rel.X) <= size.X / 2 + 15
        and math.abs(rel.Z) <= size.Z / 2 + 15
        and rel.Y >= -size.Y / 2 - 80
end

local function nearestTarget(maxDist, arenaOnly)
    if not HumanoidRootPart then return nil end
    local best, bestD
    for _, plr in ipairs(Players:GetPlayers()) do
        if alive(plr) then
            local t = hrpOf(plr)
            if t and (not arenaOnly or inArena(t.Position)) then
                local d = (HumanoidRootPart.Position - t.Position).Magnitude
                if d <= maxDist and (not bestD or d < bestD) then best, bestD = t, d end
            end
        end
    end
    return best, bestD
end

local function fireRemote(name)
    local rs = ReplicatedStorage
    local r = rs:FindFirstChild(name)
        or (rs:FindFirstChild("Remotes") and rs.Remotes:FindFirstChild(name))
        or (rs:FindFirstChild("RemoteEvents") and rs.RemoteEvents:FindFirstChild(name))
    if r and r:IsA("RemoteEvent") then
        pcall(function() r:FireServer() end)
        return true
    end
    return false
end

local function getSpawnCFrame()
    local sp = workspace:FindFirstChildOfClass("SpawnLocation")
    if sp then return sp.CFrame + Vector3.new(0, 4, 0) end
    local arena = workspace:FindFirstChild("Arena")
    if arena then
        for _, d in ipairs(arena:GetDescendants()) do
            if d:IsA("SpawnLocation") then return d.CFrame + Vector3.new(0, 4, 0) end
        end
    end
    return CFrame.new(0, 150, 0)
end

local function groundBelow(pos)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    local hit = workspace:Raycast(Vector3.new(pos.X, 400, pos.Z), Vector3.new(0, -800, 0), params)
    if hit then return hit.Position + Vector3.new(0, 4, 0) end
    return nil
end

local function slappleFolder()
    local arena = workspace:FindFirstChild("Arena")
    local island = arena and arena:FindFirstChild("island5")
    local f = island and island:FindFirstChild("Slapples")
    if f then return f end
    return workspace:FindFirstChild("Slapples", true)
end

local function trollHRP()
    if not trollTarget then return nil end
    local ch = trollTarget.Character
    if not ch then return nil end
    local h = ch:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    return ch:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------------
-- Dispatcher
---------------------------------------------------------------------
local dispatcher = {}
local function registerTask(interval, fn)
    local t = {enabled=false, interval=interval, acc=0, fn=fn}
    table.insert(dispatcher, t)
    return t
end

addConn(RunService.Heartbeat:Connect(function(dt)
    for i = 1, #dispatcher do
        local t = dispatcher[i]
        if t.enabled then
            t.acc += dt
            if t.acc >= t.interval then
                t.acc = 0
                pcall(t.fn)
            end
        end
    end
end))

---------------------------------------------------------------------
-- UI basis
---------------------------------------------------------------------
if PlayerGui:FindFirstChild("SvclutcherDelta") then
    PlayerGui.SvclutcherDelta:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SvclutcherDelta"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999
ScreenGui.IgnoreGuiInset = true

local MainFrame = Instance.new("Frame")
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0, 12, 0, 60)
MainFrame.Size = UDim2.new(0, 300, 0, 430)
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, -72, 0, 38)
Title.Font = Enum.Font.GothamBold
Title.Text = "  " .. MyHubName .. " v" .. VERSION
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextSize = 14
Title.Parent = MainFrame

local function titleBtn(txt, xo, col)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    b.BorderSizePixel = 0
    b.Position = UDim2.new(1, xo, 0, 5)
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Font = Enum.Font.GothamBold
    b.Text = txt
    b.TextColor3 = col
    b.TextSize = 14
    b.Parent = MainFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local CollapseBtn = titleBtn("_", -64, Color3.fromRGB(180, 180, 255))
local CloseBtn    = titleBtn("X", -32, Color3.fromRGB(255, 120, 120))

local Content = Instance.new("ScrollingFrame")
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.Position = UDim2.new(0, 0, 0, 42)
Content.Size = UDim2.new(1, 0, 1, -46)
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 85)
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.ScrollingDirection = Enum.ScrollingDirection.Y
Content.Parent = MainFrame

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 8)
pad.Parent = Content

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 4)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = Content

local FloatBtn = Instance.new("TextButton")
FloatBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
FloatBtn.BorderSizePixel = 0
FloatBtn.Size = UDim2.new(0, 48, 0, 48)
FloatBtn.Position = UDim2.new(0, 12, 0, 60)
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.Text = "SV"
FloatBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
FloatBtn.TextSize = 15
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 12)

FloatBtn.MouseButton1Click:Connect(function()
    FloatBtn.Visible = false
    MainFrame.Visible = true
end)

local dragging, dragStart, startPos
Title.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, i.Position, MainFrame.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)

addConn(UserInputService.InputChanged:Connect(function(i)
    if not dragging then return end
    if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
        local cam = workspace.CurrentCamera
        if not cam then return end
        local d = i.Position - dragStart
        local nx = math.clamp(startPos.X.Offset + d.X, -260, cam.ViewportSize.X - 40)
        local ny = math.clamp(startPos.Y.Offset + d.Y, 0, cam.ViewportSize.Y - 60)
        MainFrame.Position = UDim2.new(0, nx, 0, ny)
    end
end))

---------------------------------------------------------------------
-- UI builders
---------------------------------------------------------------------
local order = 0
local function nextOrder() order += 1 return order end

local function makeSection(name)
    local header = Instance.new("TextButton")
    header.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    header.BorderSizePixel = 0
    header.Size = UDim2.new(1, 0, 0, 28)
    header.Font = Enum.Font.GothamBold
    header.Text = "  - " .. name
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.TextColor3 = Color3.fromRGB(130, 130, 165)
    header.TextSize = 12
    header.LayoutOrder = nextOrder()
    header.Parent = Content
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 6)

    local body = Instance.new("Frame")
    body.BackgroundTransparency = 1
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.LayoutOrder = nextOrder()
    body.Parent = Content

    local bl = Instance.new("UIListLayout")
    bl.Padding = UDim.new(0, 4)
    bl.Parent = body

    header.MouseButton1Click:Connect(function()
        body.Visible = not body.Visible
        header.Text = (body.Visible and "  - " or "  + ") .. name
    end)

    return body
end

local function makeToggle(parent, label, key, onChanged, h)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Size = UDim2.new(1, 0, 0, h or 38)
    btn.Font = Enum.Font.GothamBold
    btn.Text = label .. ": UIT"
    btn.TextColor3 = Color3.fromRGB(255, 80, 80)
    btn.TextSize = 13
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local on = false
    local function set(v)
        if on == v then return end
        on = v
        settings[key] = v
        btn.Text = label .. ": " .. (v and "AAN" or "UIT")
        btn.TextColor3 = v and Color3.fromRGB(80, 255, 80) or Color3.fromRGB(255, 80, 80)
        if onChanged then pcall(onChanged, v) end
    end
    btn.MouseButton1Click:Connect(function() set(not on) end)
    toggles[key] = set
    return set
end

local function makeAction(parent, label, fn, h, col)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Size = UDim2.new(1, 0, 0, h or 38)
    btn.Font = Enum.Font.GothamBold
    btn.Text = label
    btn.TextColor3 = col or Color3.fromRGB(215, 215, 255)
    btn.TextSize = 13
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function() pcall(fn) end)
    return btn
end

local function cycleText(c, i)
    return c.label .. ": " .. tostring(c.cycle[i]) .. (c.suffix or "")
end

local function makeCycle(parent, label, key, cycle, suffix, h)
    local idx = table.find(cycle, settings[key]) or 1
    local btn = makeAction(parent, cycleText({label=label, cycle=cycle, suffix=suffix}, idx), function()
        idx = (idx % #cycle) + 1
        settings[key] = cycle[idx]
        btn.Text = cycleText({label=label, cycle=cycle, suffix=suffix}, idx)
    end, h)
    cycles[key] = {btn=btn, label=label, cycle=cycle, suffix=suffix}
    return btn
end

local function syncUI()
    for k, set in pairs(toggles) do set(settings[k] == true) end
    for k, c in pairs(cycles) do
        local i = table.find(c.cycle, settings[k]) or 1
        c.btn.Text = cycleText(c, i)
    end
end

---------------------------------------------------------------------
-- ESP core
---------------------------------------------------------------------
local highlightCount = 0

local function applyHighlight(char)
    if not char or char:FindFirstChild("SvclutcherHighlight") then return end
    if highlightCount >= 30 then return end
    local plr = Players:GetPlayerFromCharacter(char)
    local hue = plr and ((plr.UserId % 100) / 100) or 0.33
    local hl = Instance.new("Highlight")
    hl.Name = "SvclutcherHighlight"
    hl.FillColor = Color3.fromHSV(hue, 0.85, 1)
    hl.FillTransparency = 0.55
    hl.OutlineColor = Color3.new(1, 1, 1)
    hl.OutlineTransparency = 0.2
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    highlightCount += 1
end

local function removeHighlight(char)
    local hl = char and char:FindFirstChild("SvclutcherHighlight")
    if hl then hl:Destroy() highlightCount = math.max(0, highlightCount - 1) end
end

local function createNameTag(char)
    local head = char and char:FindFirstChild("Head")
    if not head or head:FindFirstChild("PlayerESP") then return end
    local plr = Players:GetPlayerFromCharacter(char)

    local bb = Instance.new("BillboardGui")
    bb.Name = "PlayerESP"
    bb.Size = UDim2.new(0, 200, 0, 52)
    bb.StudsOffset = Vector3.new(0, 2.8, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 2000
    bb.Parent = head

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.BackgroundTransparency = 1
    nameLabel.Size = UDim2.new(1, 0, 0, 17)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Text = plr and plr.DisplayName or char.Name
    nameLabel.Parent = bb

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Distance"
    distLabel.BackgroundTransparency = 1
    distLabel.Size = UDim2.new(1, 0, 0, 15)
    distLabel.Position = UDim2.new(0, 0, 0, 17)
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = 12
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0
    distLabel.Text = "?"
    distLabel.Parent = bb

    if settings.healthbar then
        local bg = Instance.new("Frame")
        bg.Name = "HealthBG"
        bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        bg.BorderSizePixel = 0
        bg.Size = UDim2.new(0, 70, 0, 5)
        bg.Position = UDim2.new(0.5, -35, 0, 34)
        bg.Parent = bb

        local fill = Instance.new("Frame")
        fill.Name = "HealthFill"
        fill.BackgroundColor3 = Color3.fromRGB(90, 240, 90)
        fill.BorderSizePixel = 0
        fill.Size = UDim2.new(1, 0, 1, 0)
        fill.Parent = bg
    end
end

local function removeNameTag(char)
    local head = char and char:FindFirstChild("Head")
    local bb = head and head:FindFirstChild("PlayerESP")
    if bb then bb:Destroy() end
end

local function getGloveValue(plr)
    local g = plr:FindFirstChild("Glove")
    if not g then return nil end
    local ok, v = pcall(function() return g.Value end)
    if ok and v ~= nil then return tostring(v) end
    return nil
end

local function updateGloveTag(char)
    if not settings.gloveesp then return end
    local head = char and char:FindFirstChild("Head")
    if not head then return end
    local plr = Players:GetPlayerFromCharacter(char)
    if not plr then return end
    local pesp = head:FindFirstChild("PlayerESP")
    if not pesp then return end

    local gl = pesp:FindFirstChild("Glove")
    if not gl then
        gl = Instance.new("TextLabel")
        gl.Name = "Glove"
        gl.BackgroundTransparency = 1
        gl.Size = UDim2.new(1, 0, 0, 16)
        gl.Position = UDim2.new(0, 0, 0, 39)
        gl.TextColor3 = Color3.fromRGB(255, 220, 80)
        gl.TextStrokeTransparency = 0
        gl.TextSize = 12
        gl.Font = Enum.Font.GothamBold
        gl.Parent = pesp
        pesp.Size = UDim2.new(0, 200, 0, 56)
    end
    gl.Text = getGloveValue(plr) or "?"
end

local function removeGloveTag(char)
    local head = char and char:FindFirstChild("Head")
    local pesp = head and head:FindFirstChild("PlayerESP")
    if not pesp then return end
    local gl = pesp:FindFirstChild("Glove")
    if gl then gl:Destroy() end
    pesp.Size = UDim2.new(0, 200, 0, 52)
end

local function createToolTag(tool)
    if not tool or tool:FindFirstChild("ToolESP") then return end
    local part = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "ToolESP"
    bb.Size = UDim2.new(0, 150, 0, 18)
    bb.StudsOffset = Vector3.new(0, 1.2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 500
    bb.Parent = part
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Size = UDim2.new(1, 0, 1, 0)
    l.Font = Enum.Font.GothamBold
    l.TextSize = 12
    l.TextColor3 = Color3.fromRGB(255, 220, 80)
    l.TextStrokeTransparency = 0
    l.Text = tool.Name
    l.Parent = bb
end

local function removeToolTag(tool)
    if not tool then return end
    for _, d in ipairs(tool:GetDescendants()) do
        if d.Name == "ToolESP" then d:Destroy() end
    end
end

local function applyPlayerESP(char)
    if not char or char == Character then return end
    local plr = Players:GetPlayerFromCharacter(char)
    if not plr or plr == LocalPlayer then return end
    if not char:FindFirstChild("HumanoidRootPart") then return end
    applyHighlight(char)
    createNameTag(char)
    updateGloveTag(char)
end

local function removePlayerESP(char)
    if not char then return end
    removeHighlight(char)
    removeNameTag(char)
end

local drawOk = pcall(function() local d = Drawing.new("Square") d:Remove() end)
local drawStore = {}

local function clearDrawings(plr)
    local o = drawStore[plr]
    if not o then return end
    for _, d in pairs(o) do pcall(function() d:Remove() end) end
    drawStore[plr] = nil
end

local function ensureDrawings(plr)
    if not drawOk then return nil end
    local o = drawStore[plr]
    if not o then
        o = {}
        if settings.boxesp then
            o.box = Drawing.new("Square")
            o.box.Thickness = 1
            o.box.Filled = false
            o.box.Transparency = 1
        end
        if settings.tracers then
            o.line = Drawing.new("Line")
            o.line.Thickness = 1
            o.line.Transparency = 1
        end
        drawStore[plr] = o
    end
    return o
end

---------------------------------------------------------------------
-- Taken
---------------------------------------------------------------------
local hitboxTask = registerTask(0, function()
    local glove = Character and Character:FindFirstChildWhichIsA("Tool")
    local handle = glove and (glove:FindFirstChild("Handle") or glove:FindFirstChildWhichIsA("BasePart"))
    if not handle then return end
    if not gloveOriginals[handle] then
        gloveOriginals[handle] = {
            size = handle.Size, transparency = handle.Transparency,
            collide = handle.CanCollide, massless = handle.Massless,
            color = handle.BrickColor,
        }
    end
    handle.Size = Vector3.new(settings.reachsize, settings.reachsize, settings.reachsize)
    handle.Transparency = 0.85
    handle.BrickColor = BrickColor.new("Bright red")
    handle.CanCollide = false
    handle.Massless = true
end)

local slapTask = registerTask(0.13, function()
    local glove = Character and Character:FindFirstChildWhichIsA("Tool")
    if not glove or not Humanoid or Humanoid.Health <= 0 then return end
    local target = nearestTarget(settings.reachsize + 6, true)
    if not target then return end
    glove:Activate()
    local handle = glove:FindFirstChild("Handle") or glove:FindFirstChildWhichIsA("BasePart")
    if handle and firetouchinterest then
        pcall(firetouchinterest, handle, target, 0)
        pcall(firetouchinterest, handle, target, 1)
    end
    click()
end)

local killauraTask = registerTask(0.06, function()
    local glove = Character and Character:FindFirstChildWhichIsA("Tool")
    if not glove then return end
    local handle = glove:FindFirstChild("Handle") or glove:FindFirstChildWhichIsA("BasePart")
    if not handle or not firetouchinterest then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if alive(plr) then
            local t = hrpOf(plr)
            if t and (handle.Position - t.Position).Magnitude <= settings.reachsize + 4 then
                pcall(firetouchinterest, handle, t, 0)
                pcall(firetouchinterest, handle, t, 1)
            end
        end
    end
end)

local clickerTask = registerTask(0.08, function()
    if Character and Character:FindFirstChildWhichIsA("Tool") then click() end
end)

local slappleTask = registerTask(0.05, function()
    if not HumanoidRootPart then return end
    local folder = slappleFolder()
    if not folder then return end
    for _, v in ipairs(folder:GetChildren()) do
        local g = v:FindFirstChild("Glove")
        if g and g:IsA("PVInstance") then
            pcall(function() g:PivotTo(HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)) end)
        end
    end
end)

local abilityTask = registerTask(0.4, function()
    if not Character or not Character:FindFirstChildWhichIsA("Tool") then return end
    if nearestTarget(40, true) then fireRemote("GeneralAbility") end
end)

local aimTask = registerTask(0, function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local target = (lockTarget and alive(lockTarget) and hrpOf(lockTarget))
        or nearestTarget(settings.reachsize + 20, true)
    if not target then return end
    local goal = CFrame.new(cam.CFrame.Position, target.Position + Vector3.new(0, 1.5, 0))
    cam.CFrame = cam.CFrame:Lerp(goal, settings.aimstrength)
end)

local dodgeTask = registerTask(0.3, function()
    if not HumanoidRootPart then return end
    if not (Character and Character:FindFirstChildWhichIsA("Tool")) then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if alive(plr) then
            local t = hrpOf(plr)
            if t and (HumanoidRootPart.Position - t.Position).Magnitude < 7 then
                local dir = (HumanoidRootPart.Position - t.Position).Unit
                HumanoidRootPart.CFrame = HumanoidRootPart.CFrame + Vector3.new(-dir.Z, 0, dir.X) * 4
                return
            end
        end
    end
end)

local flyTask = registerTask(0, function()
    if not flying or not flyBV or not HumanoidRootPart then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    flyBV.Velocity = cam.CFrame.LookVector * settings.flyspeed + Vector3.new(0, settings.flylift, 0)
end)

-- silly fly glitch emulatie
local sillyTask = registerTask(0.07, function()
    local glove = Character and Character:FindFirstChildWhichIsA("Tool")
    if not glove then return end
    if Humanoid and Humanoid.Health > 0 then
        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    glove:Activate()
    fireRemote("GeneralAbility")
    if HumanoidRootPart then
        local v = HumanoidRootPart.AssemblyLinearVelocity
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 34), v.Z)
    end
end)

local ragdollTask = registerTask(0.05, function()
    if not Character then return end
    local h = Character:FindFirstChildOfClass("Humanoid")
    if h then
        if h.PlatformStand and not flying then h.PlatformStand = false end
        if h.Sit then h.Sit = false end
    end
    for _, d in ipairs(Character:GetDescendants()) do
        if d:IsA("Motor6D") and not d.Enabled then d.Enabled = true end
        if d:IsA("BallSocketConstraint") then d:Destroy() end
    end
end)

local knockTask = registerTask(0, function()
    if not HumanoidRootPart then return end
    local v = HumanoidRootPart.AssemblyLinearVelocity
    if Vector3.new(v.X, 0, v.Z).Magnitude > 60 then
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, v.Y, v.Z * 0.15)
    end
end)

local voidTask = registerTask(0.2, function()
    if not HumanoidRootPart then return end
    if HumanoidRootPart.Position.Y < -60 then
        local g = groundBelow(HumanoidRootPart.Position)
        HumanoidRootPart.CFrame = g and CFrame.new(g) or getSpawnCFrame()
        HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
        notify("Anti Void: teruggezet")
    end
end)

local flingTask = registerTask(0.1, function()
    if not HumanoidRootPart then return end
    local p = HumanoidRootPart.Position
    if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then
        HumanoidRootPart.CFrame = CFrame.new(lastSafe)
        return
    end
    local v = HumanoidRootPart.AssemblyLinearVelocity
    if v.Magnitude > 1500 then HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero end
    if v.Magnitude < 400 then lastSafe = p end
end)

-- TROLL taken
local elevatorTask = registerTask(0, function()
    local hrp = trollHRP()
    if not hrp then return end
    hrp.CFrame = hrp.CFrame + Vector3.new(0, 0.16, 0)
end)

local spinTask = registerTask(0, function()
    local hrp = trollHRP()
    if not hrp then return end
    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, 0.22, 0)
end)

local shakeTask = registerTask(0, function()
    local hrp = trollHRP()
    if not hrp then return end
    hrp.CFrame = hrp.CFrame + Vector3.new(
        math.random(-40, 40) / 100,
        math.random(-40, 40) / 100,
        math.random(-40, 40) / 100
    )
end)

local flipTask = registerTask(0, function()
    local hrp = trollHRP()
    if not hrp then return end
    hrp.CFrame = hrp.CFrame * CFrame.Angles(0, 0, 0.05)
end)

local espTask = registerTask(0.2, function()
    if not settings.playeresp then
        if settings.gloveesp then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer and plr.Character then updateGloveTag(plr.Character) end
            end
        end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            local bb = head and head:FindFirstChild("PlayerESP")
            if not bb and plr.Character:FindFirstChild("HumanoidRootPart") then
                applyPlayerESP(plr.Character)
                bb = head and head:FindFirstChild("PlayerESP")
            end
            local hrp = hrpOf(plr)
            if bb and hrp and HumanoidRootPart then
                local d = bb:FindFirstChild("Distance")
                if d then
                    d.Text = math.floor((HumanoidRootPart.Position - hrp.Position).Magnitude) .. " studs"
                end
                local bg = bb:FindFirstChild("HealthBG")
                local fill = bg and bg:FindFirstChild("HealthFill")
                local h = plr.Character:FindFirstChildOfClass("Humanoid")
                if fill and h then
                    local r = math.clamp(h.Health / math.max(h.MaxHealth, 1), 0, 1)
                    fill.Size = UDim2.new(r, 0, 1, 0)
                    fill.BackgroundColor3 = Color3.fromRGB(255 - 165 * r, 90 + 150 * r, 90)
                end
            end
            if settings.gloveesp then updateGloveTag(plr.Character) end
        end
    end
end)
espTask.enabled = true

local frames = 0
addConn(RunService.RenderStepped:Connect(function() frames += 1 end))

local statsTask = registerTask(1, function()
    local ping = ""
    pcall(function()
        local stats = game:GetService("Stats")
        ping = math.floor(stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. "ms"
    end)
    statsLabel.Text = string.format("FPS %d | %s | %d spelers", frames, ping, #Players:GetPlayers())
    frames = 0
end)
statsTask.enabled = true

---------------------------------------------------------------------
-- Fly implementatie
---------------------------------------------------------------------
startFly = function()
    if flying or not HumanoidRootPart then return end
    flying = true
    flyBV = Instance.new("BodyVelocity")
    flyBV.Name = "SvclutcherFly"
    flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = HumanoidRootPart
    if Humanoid then Humanoid.PlatformStand = true end
end

stopFly = function()
    flying = false
    if flyBV then flyBV:Destroy() flyBV = nil end
    if Humanoid and Humanoid.Parent then
        Humanoid.PlatformStand = false
        Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

applyNoclip = function()
    if not Character then return end
    for _, d in ipairs(Character:GetDescendants()) do
        if d:IsA("BasePart") then
            if noclipStore[d] == nil then noclipStore[d] = d.CanCollide end
            d.CanCollide = false
        end
    end
end

restoreNoclip = function()
    for part, orig in pairs(noclipStore) do
        if part and part.Parent then
            pcall(function() part.CanCollide = orig and true or false end)
        end
    end
end

---------------------------------------------------------------------
-- Combat
---------------------------------------------------------------------
local combat = makeSection("COMBAT")

makeToggle(combat, "TP Farm", "tpfarm")
makeToggle(combat, "Alleen arena", "arenaonly")

task.spawn(function()
    while not unloaded do
        if not settings.tpfarm then task.wait(0.1) continue end
        if not (HumanoidRootPart and Humanoid and Humanoid.Health > 0) then task.wait(0.2) continue end
        for _, plr in ipairs(Players:GetPlayers()) do
            if not settings.tpfarm then break end
            if not alive(plr) then continue end
            local thrp = hrpOf(plr)
            if not thrp then continue end
            if not inArena(thrp.Position) then continue end
            local started = os.clock()
            while os.clock() - started < 3 and settings.tpfarm and thrp.Parent
                and inArena(thrp.Position) do
                RunService.Heartbeat:Wait()
                pcall(function()
                    HumanoidRootPart.CFrame = thrp.CFrame * CFrame.new(0, 0, 2.5)
                    HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
                end)
                pcall(click)
            end
            task.wait(0.12)
        end
    end
end)

makeToggle(combat, "Hitbox Reach", "hitboxaura", function(v)
    if not v then
        for handle, o in pairs(gloveOriginals) do
            if handle and handle.Parent then
                handle.Size = o.size
                handle.Transparency = o.transparency
                handle.CanCollide = o.collide
                handle.Massless = o.massless
                handle.BrickColor = o.color
            end
        end
    end
end)

makeCycle(combat, "Reach", "reachsize", {8, 16, 24, 32}, "", 28)

makeToggle(combat, "Slap Aura", "slapaura")

local modeBtn = makeAction(combat, "Snelheid: Veilig", function()
    settings.slapmode = (settings.slapmode == "Safe") and "Fast" or "Safe"
    modeBtn.Text = (settings.slapmode == "Safe") and "Snelheid: Veilig" or "Snelheid: Snel"
    slapTask.interval = (settings.slapmode == "Fast") and 0.05 or 0.13
    slapTask.acc = 0
end, 28)

makeToggle(combat, "Kill Aura (touch)", "killaura")
makeToggle(combat, "Auto Clicker", "autoslap", function()
    clickerTask.interval = settings.clickspeed
    clickerTask.acc = 0
end)

makeCycle(combat, "CPS delay", "clickspeed", {0.05, 0.08, 0.12, 0.2}, "s", 28)

makeToggle(combat, "Slapple Magnet", "slapples")
makeToggle(combat, "Auto Ability", "autoability")

makeAction(combat, "Slap alles in bereik", function()
    local glove = Character and Character:FindFirstChildWhichIsA("Tool")
    if not glove then return notify("Geen glove") end
    glove:Activate()
    local handle = glove:FindFirstChild("Handle")
    if handle and firetouchinterest then
        for _, plr in ipairs(Players:GetPlayers()) do
            if alive(plr) then
                local t = hrpOf(plr)
                if t and (handle.Position - t.Position).Magnitude <= settings.reachsize + 8 then
                    pcall(firetouchinterest, handle, t, 0)
                    pcall(firetouchinterest, handle, t, 1)
                end
            end
        end
    end
    notify("Slap burst")
end, 34)

---------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------
local move = makeSection("MOVEMENT")

makeCycle(move, "WalkSpeed", "walkspeed", {20, 45, 75, 120}, "", 34)
makeCycle(move, "JumpPower", "jumpspeed", {50, 90, 150}, "", 34)

addConn(RunService.Heartbeat:Connect(function()
    if Humanoid and Humanoid.Parent then
        if Humanoid.WalkSpeed ~= settings.walkspeed then Humanoid.WalkSpeed = settings.walkspeed end
        if Humanoid.UseJumpPower and Humanoid.JumpPower ~= settings.jumpspeed then
            Humanoid.JumpPower = settings.jumpspeed
        end
    end
end))

makeToggle(move, "Fly", "fly", function(v)
    if v then
        if settings.sillyfly then toggles.sillyfly(false) end
        startFly()
    else
        stopFly()
    end
end)

local flyRow = Instance.new("Frame")
flyRow.BackgroundTransparency = 1
flyRow.Size = UDim2.new(1, 0, 0, 30)
flyRow.Parent = move
local flyLay = Instance.new("UIListLayout")
flyLay.FillDirection = Enum.FillDirection.Horizontal
flyLay.Padding = UDim.new(0, 4)
flyLay.Parent = flyRow

local function flyBtn(txt, delta)
    local b = Instance.new("TextButton")
    b.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    b.BorderSizePixel = 0
    b.Size = UDim2.new(0.25, -3, 1, 0)
    b.Font = Enum.Font.GothamBold
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(215, 215, 255)
    b.TextSize = 13
    b.Parent = flyRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        settings.flylift = math.clamp(settings.flylift + delta, -120, 120)
        notify("Lift: " .. settings.flylift)
    end)
    return b
end

flyBtn("Lift -", -20)
flyBtn("Lift 0", 0)
flyBtn("Lift +", 20)
makeCycle(move, "FlySpeed", "flyspeed", {35, 55, 90}, "", 28)

makeToggle(move, "Funny Silly Fly", "sillyfly", function(v)
    if v then
        if settings.fly then toggles.fly(false) end
        local glove = Character and Character:FindFirstChildWhichIsA("Tool")
        if not glove then notify("Silly Fly: equip eerst een glove") end
    end
end)

makeAction(move, "Silly Fly uitleg", function()
    notify("Equip de Silly glove en zet Funny Silly Fly aan")
    notify("Werkt ook met andere lift-gloves")
end, 30)

makeToggle(move, "Infinite Jump", "infinitejump")

addConn(UserInputService.JumpRequest:Connect(function()
    if not settings.infinitejump then return end
    local h = Character and Character:FindFirstChildOfClass("Humanoid")
    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

makeToggle(move, "Noclip", "noclip", function(v)
    if v then applyNoclip() else restoreNoclip() end
end)

---------------------------------------------------------------------
-- Survival
---------------------------------------------------------------------
local surv = makeSection("SURVIVAL")

makeToggle(surv, "Anti Ragdoll", "antiragdoll", function(v)
    if v and Character then
        for _, d in ipairs(Character:GetDescendants()) do
            if d:IsA("BallSocketConstraint") then d:Destroy() end
        end
    end
end)

makeToggle(surv, "Anti Knockback", "antiknock")
makeToggle(surv, "Anti Void", "antivoat")
makeToggle(surv, "Anti Fling", "antifling")
makeToggle(surv, "Anti AFK", "antiafk")

addConn(LocalPlayer.Idled:Connect(function()
    if not settings.antiafk then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end))

makeToggle(surv, "Auto Respawn", "autorespawn")

addConn(LocalPlayer.CharacterAdded:Connect(function(c)
    if not settings.autorespawn then return end
    task.wait(1)
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then h.Health = 0 end
end))

---------------------------------------------------------------------
-- TROLL
---------------------------------------------------------------------
local trollSec = makeSection("TROLL")

local trollLabel = Instance.new("TextLabel")
trollLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
trollLabel.BorderSizePixel = 0
trollLabel.Size = UDim2.new(1, 0, 0, 26)
trollLabel.Font = Enum.Font.GothamBold
trollLabel.TextSize = 12
trollLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
trollLabel.Text = "Target: -"
trollLabel.Parent = trollSec
Instance.new("UICorner", trollLabel).CornerRadius = UDim.new(0, 6)

registerTask(0.5, function()
    trollLabel.Text = "Target: " .. (trollTarget and trollTarget.DisplayName or "-")
end).enabled = true

makeAction(trollSec, "Target = dichtstbijzijnde", function()
    local t = nearestTarget(200, true)
    if t then
        trollTarget = Players:GetPlayerFromCharacter(t.Parent)
        notify("Troll target: " .. (trollTarget and trollTarget.DisplayName or "?"))
    else
        notify("Geen target")
    end
end, 30)

makeToggle(trollSec, "Troll Elevator", "trollevel")
makeToggle(trollSec, "Troll Spin", "trollspin")
makeToggle(trollSec, "Troll Shake", "trollshake")
makeToggle(trollSec, "Troll Flip", "trollflip")

makeAction(trollSec, "Troll Yeet (omhoog)", function()
    local hrp = trollHRP()
    if not hrp then return notify("Geen troll target") end
    hrp.CFrame = hrp.CFrame + Vector3.new(0, 90, 0)
    notify("Yeet")
end, 32)

makeAction(trollSec, "Troll naar mij", function()
    local hrp = trollHRP()
    if not hrp or not HumanoidRootPart then return notify("Geen troll target") end
    hrp.CFrame = HumanoidRootPart.CFrame * CFrame.new(0, 0, 4)
    notify("Pulled")
end, 32)

makeAction(trollSec, "Troll void drop", function()
    local hrp = trollHRP()
    if not hrp then return notify("Geen troll target") end
    hrp.CFrame = CFrame.new(hrp.Position.X, -120, hrp.Position.Z)
    notify("Void drop")
end, 32)

makeAction(trollSec, "Troll rain (10x)", function()
    task.spawn(function()
        for i = 1, 10 do
            local hrp = trollHRP()
            if not hrp then break end
            hrp.CFrame = hrp.CFrame + Vector3.new(0, 60, 0)
            task.wait(0.45)
        end
        notify("Rain klaar")
    end)
end, 32)

makeAction(trollSec, "Troll target wissen", function()
    trollTarget = nil
    notify("Troll target gewist")
end, 30)

---------------------------------------------------------------------
-- ESP
---------------------------------------------------------------------
local esp = makeSection("ESP")

makeToggle(esp, "Player ESP", "playeresp", function(v)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if v then applyPlayerESP(plr.Character) else removePlayerESP(plr.Character) end
        end
    end
end)

makeToggle(esp, "Glove ESP", "gloveesp", function(v)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if v then updateGloveTag(plr.Character) else removeGloveTag(plr.Character) end
        end
    end
end)

makeToggle(esp, "Box ESP", "boxesp", function()
    for plr in pairs(drawStore) do clearDrawings(plr) end
end)

makeToggle(esp, "Tracers", "tracers", function()
    for plr in pairs(drawStore) do clearDrawings(plr) end
end)

makeToggle(esp, "Healthbar", "healthbar")
makeCycle(esp, "ESP afstand", "espmaxdist", {200, 600, 1500}, "", 28)

makeToggle(esp, "Tool ESP", "toolesp", function(v)
    if v then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Tool") then createToolTag(d) end
        end
    else
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Tool") then removeToolTag(d) end
        end
    end
end)

addConn(workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Tool") and settings.toolesp then
        task.delay(0.1, function() createToolTag(d) end)
    end
end))

makeToggle(esp, "Slapple ESP", "slappleesp", function(v)
    local f = slappleFolder()
    if not f then return end
    for _, s in ipairs(f:GetChildren()) do
        local g = s:FindFirstChild("Glove")
        if g and g:IsA("BasePart") then
            if v then
                if not g:FindFirstChild("SlappleHL") then
                    local hl = Instance.new("Highlight")
                    hl.Name = "SlappleHL"
                    hl.FillColor = Color3.fromRGB(120, 255, 120)
                    hl.FillTransparency = 0.5
                    hl.Parent = g
                end
            else
                local hl = g:FindFirstChild("SlappleHL")
                if hl then hl:Destroy() end
            end
        end
    end
end)

---------------------------------------------------------------------
-- AIM
---------------------------------------------------------------------
local aimSec = makeSection("AIM")

makeToggle(aimSec, "Aim Assist", "aimassist")
makeCycle(aimSec, "Aim sterkte", "aimstrength", {0.12, 0.28, 0.5}, "", 28)

makeAction(aimSec, "Target lock wissen", function()
    lockTarget = nil
    notify("Lock gewist")
end, 30)

---------------------------------------------------------------------
-- Spelers
---------------------------------------------------------------------
local plrSec = makeSection("SPELERS")
local plrList = Instance.new("Frame")
plrList.BackgroundTransparency = 1
plrList.Size = UDim2.new(1, 0, 0, 0)
plrList.AutomaticSize = Enum.AutomaticSize.Y
plrList.Parent = plrSec
local plrLay = Instance.new("UIListLayout")
plrLay.Padding = UDim.new(0, 3)
plrLay.Parent = plrList

local function refreshPlayers()
    for _, c in ipairs(plrList:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local row = Instance.new("Frame")
            row.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
            row.BorderSizePixel = 0
            row.Size = UDim2.new(1, 0, 0, 30)
            row.Parent = plrList
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

            local nm = Instance.new("TextLabel")
            nm.BackgroundTransparency = 1
            nm.Size = UDim2.new(0.28, 0, 1, 0)
            nm.Position = UDim2.new(0, 6, 0, 0)
            nm.Font = Enum.Font.GothamBold
            nm.TextSize = 11
            nm.TextXAlignment = Enum.TextXAlignment.Left
            nm.TextColor3 = alive(plr) and Color3.fromRGB(230, 230, 240) or Color3.fromRGB(130, 130, 140)
            nm.TextTruncate = Enum.TextTruncate.AtEnd
            nm.Text = plr.DisplayName
            nm.Parent = row

            local function rowBtn(txt, x, fn, col)
                local b = Instance.new("TextButton")
                b.BackgroundColor3 = Color3.fromRGB(38, 38, 50)
                b.BorderSizePixel = 0
                b.Size = UDim2.new(0, 44, 1, -6)
                b.Position = UDim2.new(1, x, 0, 3)
                b.Font = Enum.Font.GothamBold
                b.TextSize = 10
                b.Text = txt
                b.TextColor3 = col or Color3.fromRGB(210, 210, 255)
                b.Parent = row
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
                b.MouseButton1Click:Connect(function() pcall(fn) end)
            end

            rowBtn("LOCK", -192, function()
                lockTarget = plr
                notify("Lock: " .. plr.DisplayName)
            end)
            rowBtn("TROLL", -146, function()
                trollTarget = plr
                notify("Troll: " .. plr.DisplayName)
            end, Color3.fromRGB(255, 200, 100))
            rowBtn("TP", -100, function()
                local t = hrpOf(plr)
                if t and HumanoidRootPart then HumanoidRootPart.CFrame = t.CFrame * CFrame.new(0, 0, 3) end
            end)
            rowBtn("SLAP", -54, function()
                local t = hrpOf(plr)
                local glove = Character and Character:FindFirstChildWhichIsA("Tool")
                if t and glove then
                    local handle = glove:FindFirstChild("Handle")
                    if handle and firetouchinterest then
                        glove:Activate()
                        pcall(firetouchinterest, handle, t, 0)
                        pcall(firetouchinterest, handle, t, 1)
                    end
                end
            end)
        end
    end
end

makeAction(plrSec, "Lijst verversen", refreshPlayers, 30)
refreshPlayers()
addConn(Players.PlayerAdded:Connect(function() task.wait(0.5) refreshPlayers() end))
addConn(Players.PlayerRemoving:Connect(function(p) clearDrawings(p) task.wait(0.3) refreshPlayers() end))

local function hookPlayer(plr)
    if plr == LocalPlayer then return end
    addConn(plr.CharacterAdded:Connect(function(c)
        task.wait(0.3)
        if settings.playeresp then applyPlayerESP(c) end
        task.wait(0.2)
        refreshPlayers()
    end))
    if plr.Character and settings.playeresp then applyPlayerESP(plr.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
addConn(Players.PlayerAdded:Connect(hookPlayer))

---------------------------------------------------------------------
-- Util
---------------------------------------------------------------------
local util = makeSection("UTIL")

makeAction(util, "TP naar dichtstbijzijnde", function()
    local t = nearestTarget(300, true)
    if t and HumanoidRootPart then
        HumanoidRootPart.CFrame = t.CFrame * CFrame.new(0, 0, 3)
    else
        notify("Geen target")
    end
end)

makeAction(util, "TP naar spawn", function()
    if HumanoidRootPart then HumanoidRootPart.CFrame = getSpawnCFrame() end
end)

makeAction(util, "Reset character", function()
    if Humanoid then Humanoid.Health = 0 end
end)

makeAction(util, "Rejoin server", function()
    notify("Rejoining...")
    task.wait(0.4)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

makeAction(util, "Server hop", function()
    local req = request or http_request or (syn and syn.request)
    if not req then return notify("Geen HTTP") end
    local ok, res = pcall(req, {
        Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
        Method = "GET",
    })
    if not ok or not res or not res.Body then return notify("Hop mislukt") end
    local data = HttpService:JSONDecode(res.Body)
    for _, s in ipairs(data.data or {}) do
        if s.id ~= game.JobId and s.playing < s.maxPlayers then
            notify("Hopping...")
            task.wait(0.3)
            TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            return
        end
    end
    notify("Geen server gevonden")
end)

makeAction(util, "FPS / Graphics boost", function()
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
                v.Reflectance = 0
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") then
                v.Enabled = false
            end
        end
    end)
    notify("Boost toegepast")
end)

local statsLabel = Instance.new("TextLabel")
statsLabel.BackgroundTransparency = 1
statsLabel.Size = UDim2.new(0, 200, 0, 16)
statsLabel.Font = Enum.Font.Code
statsLabel.TextSize = 11
statsLabel.TextColor3 = Color3.fromRGB(120, 255, 140)
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Text = ""
statsLabel.Parent = util

---------------------------------------------------------------------
-- Config
---------------------------------------------------------------------
local cfgSec = makeSection("CONFIG")

makeAction(cfgSec, "Config opslaan", function()
    local ok = pcall(function()
        if makefolder and isfolder and not isfolder(CFG_FOLDER) then makefolder(CFG_FOLDER) end
        writefile(CFG_FILE, HttpService:JSONEncode(settings))
    end)
    notify(ok and "Config opgeslagen" or "Opslaan mislukt")
end)

makeAction(cfgSec, "Config laden", function()
    local ok, raw = pcall(readfile, CFG_FILE)
    if not ok or not raw then return notify("Geen config") end
    local decOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not decOk or type(data) ~= "table" then return notify("Config corrupt") end
    for k, v in pairs(data) do
        if settings[k] ~= nil and type(v) == type(settings[k]) then settings[k] = v end
    end
    syncUI()
    notify("Config geladen")
end)

---------------------------------------------------------------------
-- Drawing loop
---------------------------------------------------------------------
addConn(RunService.RenderStepped:Connect(function()
    if not drawOk then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local vp = cam.ViewportSize
    local myPos = HumanoidRootPart and HumanoidRootPart.Position or Vector3.zero

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local o = drawStore[plr]
            if not o and (settings.boxesp or settings.tracers) then o = ensureDrawings(plr) end
            if o then
                local hrp = hrpOf(plr)
                local head = plr.Character:FindFirstChild("Head")
                local dist = hrp and (myPos - hrp.Position).Magnitude or 9999
                local show = hrp and head and dist <= settings.espmaxdist

                if show then
                    local top, v1 = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1, 0))
                    local bot, v2 = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    show = v1 and v2
                    if show then
                        local hgt = math.abs(bot.Y - top.Y)
                        local wid = hgt * 0.55
                        local col = Color3.fromRGB(120, 255, 120)
                        if dist < 20 then col = Color3.fromRGB(255, 90, 90)
                        elseif dist < 60 then col = Color3.fromRGB(255, 220, 90) end
                        if o.box then
                            o.box.Visible = true
                            o.box.Color = col
                            o.box.Position = Vector2.new(top.X - wid / 2, top.Y)
                            o.box.Size = Vector2.new(wid, hgt)
                        end
                        if o.line then
                            o.line.Visible = true
                            o.line.Color = col
                            o.line.From = Vector2.new(vp.X / 2, vp.Y)
                            o.line.To = Vector2.new(top.X, top.Y)
                        end
                    end
                end
                if not show then
                    if o.box then o.box.Visible = false end
                    if o.line then o.line.Visible = false end
                end
            end
        end
    end
end))

---------------------------------------------------------------------
-- Enable-map
---------------------------------------------------------------------
local taskMap = {
    hitboxaura  = hitboxTask,
    slapaura    = slapTask,
    killaura    = killauraTask,
    autoslap    = clickerTask,
    slapples    = slappleTask,
    autoability = abilityTask,
    aimassist   = aimTask,
    autododge   = dodgeTask,
    fly         = flyTask,
    sillyfly    = sillyTask,
    antiragdoll = ragdollTask,
    antiknock   = knockTask,
    antivoat    = voidTask,
    antifling   = flingTask,
    trollevel   = elevatorTask,
    trollspin   = spinTask,
    trollshake  = shakeTask,
    trollflip   = flipTask,
}

task.spawn(function()
    while not unloaded do
        RunService.Heartbeat:Wait()
        for key, t in pairs(taskMap) do
            t.enabled = settings[key] == true
        end
    end
end)

---------------------------------------------------------------------
-- Collapse / close / unload
---------------------------------------------------------------------
local collapsed = false
CollapseBtn.MouseButton1Click:Connect(function()
    collapsed = not collapsed
    Content.Visible = not collapsed
    MainFrame.Size = collapsed and UDim2.new(0, 300, 0, 38) or UDim2.new(0, 300, 0, 430)
    CollapseBtn.Text = collapsed and "+" or "_"
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatBtn.Visible = true
end)

makeAction(util, "UNLOAD hub", function()
    unloaded = true
    for k, v in pairs(settings) do
        if type(v) == "boolean" then settings[k] = false end
    end
    stopFly()
    restoreNoclip()
    for handle, o in pairs(gloveOriginals) do
        if handle and handle.Parent then handle.Size = o.size handle.Transparency = o.transparency end
    end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    clearCharConns()
    for plr in pairs(drawStore) do clearDrawings(plr) end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then removePlayerESP(plr.Character) end
    end
    notifGui:Destroy()
    ScreenGui:Destroy()
end, 34, Color3.fromRGB(255, 120, 120))

ScreenGui.Parent = PlayerGui
notifGui.Parent = PlayerGui
syncUI()
notify("Svclutcher Hub v" .. VERSION .. " geladen")
