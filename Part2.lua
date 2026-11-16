--[[
    Svclutcher Hub v6.0  |  Delta / Android  |  keyless
    AC-aware build for Slap Battles / Slap Royale
    Order: services -> AC core -> UI shell -> pages -> features -> loops
]]

local P     = game:GetService("Players")
while not P.LocalPlayer do task.wait(0.1) end
local LP    = P.LocalPlayer
local VU    = game:GetService("VirtualUser")
local VIM   = game:GetService("VirtualInputManager")
local UIS   = game:GetService("UserInputService")
local TS    = game:GetService("TweenService")
local TP    = game:GetService("TeleportService")
local HS    = game:GetService("HttpService")
local RUN   = game:GetService("RunService")
local LT    = game:GetService("Lighting")
local PG    = LP:WaitForChild("PlayerGui")

local C = {
    bg=Color3.fromRGB(9,10,13), p=Color3.fromRGB(18,20,26), p2=Color3.fromRGB(26,29,37),
    p3=Color3.fromRGB(34,38,48), st=Color3.fromRGB(40,44,56), a=Color3.fromRGB(132,98,255),
    a2=Color3.fromRGB(86,220,146), warn=Color3.fromRGB(255,178,74), t=Color3.fromRGB(236,237,243),
    m=Color3.fromRGB(126,131,150), bad=Color3.fromRGB(255,90,104),
}

local S = {
    slap=false, kill=false, click=false, autoequip=true, ability=false, reach=false,
    size=14, cps=0.12, smooth=true, stealth=false, maxT=6,
    farm=false, autoslap=false, autoloot=false, collect=false, autowin=false,
    autoheal=false, autopick=false, claim=false, buy=false, prestige=false, rejoin=false, afk=false,
    acid=false, drop=false, void=false, ragdoll=false, fling=false, knock=false, dodge=false,
    fly=false, speed=65, lift=0, ws=40, jp=50, ijump=false, noclip=false,
    esp=false, box=false, tracer=false, itemesp=false, gloveesp=false, bright=false, dist=600,
}

local AC = { profile="Balanced", sps=6, budget=6, lastSlap=0, tpLock=0 }
local PROFILES = {
    Legit    = {size=8,  sps=3,  maxT=3,  speed=45,  ws=24, smooth=true,  stealth=true},
    Balanced = {size=14, sps=6,  maxT=6,  speed=65,  ws=40, smooth=true,  stealth=false},
    Rage     = {size=26, sps=14, maxT=14, speed=110, ws=90, smooth=false, stealth=false},
}

local Ch, HRP, Hum, unloaded = nil, nil, nil, false
local conns, tasks, pages, toggles, steppers, F = {}, {}, {}, {}, {}, {}
local orig    = setmetatable({}, {__mode="k"})
local ncStore = setmetatable({}, {__mode="k"})
local espObj, lootTags = {}, {}
local flyBV, stick = nil, Vector3.zero
local lastSafe, lastEquip, lastBuy, lastTP, tpGen = Vector3.new(), 0, 0, 0, 0
local lightStore, gloveList, currentTab = nil, nil, "Royale"
local G, main, tabBar, floating, statusLbl, search, segBar, segFill, underline

local function add(c) conns[#conns+1] = c end
local function ok(f, ...) local a, b = pcall(f, ...) return a and b end
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end

---------------------------------------------------------------------
-- toast
---------------------------------------------------------------------
local toastHost
local function toast(txt, kind)
    if not toastHost then return end
    local f = Instance.new("Frame")
    f.BackgroundColor3, f.BorderSizePixel = C.p, 0
    f.Size, f.Position = UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, -30)
    f.Parent = toastHost
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 7)
    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = (kind == "bad" and C.bad) or (kind == "warn" and C.warn) or C.a2
    bar.Size, bar.BorderSizePixel = UDim2.new(0, 3, 1, 0), 0
    bar.Parent = f
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency, l.Position, l.Size = 1, UDim2.new(0, 10, 0, 0), UDim2.new(1, -14, 1, 0)
    l.Font, l.TextSize, l.TextXAlignment, l.TextColor3 = Enum.Font.GothamMedium, 11, Enum.TextXAlignment.Left, C.t
    l.Text = tostring(txt)
    l.Parent = f
    local lay = toastHost:FindFirstChildOfClass("UIListLayout")
    lay.Padding = UDim.new(0, 4)
    task.delay(2.4, function()
        if f.Parent then
            TS:Create(f, TweenInfo.new(0.2), {BackgroundTransparency=1}):Play()
            l:GetPropertyChangedSignal("Text"):Wait()
            task.wait(0.2)
            f:Destroy()
        end
    end)
end

---------------------------------------------------------------------
-- character
---------------------------------------------------------------------
local function bind(c)
    Ch = c
    HRP = c:WaitForChild("HumanoidRootPart", 10)
    Hum = c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 10)
    if HRP and Hum then
        lastSafe = HRP.Position
        Hum.UseJumpPower = true
        Hum.WalkSpeed, Hum.JumpPower = S.ws, S.jp
        task.delay(1.5, function() if F.refreshGloves then ok(F.refreshGloves) end end)
    end
end
bind(LP.Character or LP.CharacterAdded:Wait())
add(LP.CharacterAdded:Connect(bind))

local function alive(p)
    if not p or p == LP or not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end
local function hrp(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function equipped() return Ch and Ch:FindFirstChildWhichIsA("Tool") end
local function handleOf(g) return g and (g:FindFirstChild("Handle") or g:FindFirstChildWhichIsA("BasePart")) end
local function touch(a, b)
    if a and b and firetouchinterest then
        pcall(firetouchinterest, a, b, 0)
        pcall(firetouchinterest, a, b, 1)
    end
end
local function nearest(maxd)
    if not HRP then return nil end
    local best, bd
    for _, p in ipairs(P:GetPlayers()) do
        if alive(p) then
            local t = hrp(p)
            if t then
                local d = (HRP.Position - t.Position).Magnitude
                if d <= maxd and (not bd or d < bd) then best, bd = t, d end
            end
        end
    end
    return best, bd
end
local function ground(pos)
    local rp = RaycastParams.new()
    rp.FilterType, rp.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, {Ch}
    local hit = workspace:Raycast(Vector3.new(pos.X, 600, pos.Z), Vector3.new(0, -1200, 0), rp)
    if hit then return hit.Position + Vector3.new(0, 4, 0) end
end
local function spawnCF()
    local sp = workspace:FindFirstChildOfClass("SpawnLocation")
    if sp then return sp.CFrame + Vector3.new(0, 4, 0) end
    return CFrame.new(0, 150, 0)
end
local function equipGlove(name)
    local bp = LP:FindFirstChild("Backpack")
    if not bp or not Hum then return end
    for _, t in ipairs(bp:GetChildren()) do
        if t:IsA("Tool") and (not name or t.Name == name) then
            lastEquip = os.clock()
            pcall(function() Hum:EquipTool(t) end)
            return
        end
    end
end
local function equipBest()
    if os.clock() - lastEquip < 0.6 then return end
    equipGlove(nil)
end
local function pressKey(k)
    pcall(function()
        VIM:SendKeyEvent(true, k, false, game)
        task.wait(0.02)
        VIM:SendKeyEvent(false, k, false, game)
    end)
end

---------------------------------------------------------------------
-- AC-safe teleport
---------------------------------------------------------------------
local function teleport(cf, instant)
    if not HRP then return end
    tpGen += 1
    local gen = tpGen
    local from = HRP.CFrame
    ok(function()
        HRP.AssemblyLinearVelocity = Vector3.zero
        HRP.AssemblyAngularVelocity = Vector3.zero
    end)
    lastTP = os.clock()
    if instant or not S.smooth then
        HRP.CFrame = cf
        return
    end
    task.spawn(function()
        for i = 1, 8 do
            if gen ~= tpGen or not HRP or not HRP.Parent then return end
            HRP.CFrame = from:Lerp(cf, i / 8)
            RUN.Heartbeat:Wait()
        end
    end)
end
local function tpReady()
    return os.clock() - lastTP >= AC.tpLock
end

---------------------------------------------------------------------
-- hitbox
---------------------------------------------------------------------
local function big(h)
    if not h then return end
    if not orig[h] then
        orig[h] = {s=h.Size, t=h.Transparency, c=h.CanCollide, m=h.Massless, b=h.BrickColor}
    end
    h.Size = Vector3.new(S.size, S.size, S.size)
    h.Transparency, h.CanCollide, h.Massless = 0.85, false, true
    h.BrickColor = BrickColor.new("Bright red")
end
local function small(h)
    local o = orig[h]
    if not o then return end
    orig[h] = nil
    if not h.Parent then return end
    h.Size, h.Transparency, h.CanCollide = o.s, o.t, o.c
    h.Massless, h.BrickColor = o.m, o.b
end
local function wantBox() return S.slap or S.kill or S.reach or S.autoslap or S.farm end

---------------------------------------------------------------------
-- scheduler
---------------------------------------------------------------------
local function reg(iv, fn)
    local t = {on=false, iv=iv, acc=0, fn=fn}
    tasks[#tasks+1] = t
    return t
end
add(RUN.Heartbeat:Connect(function(dt)
    AC.budget = math.min(AC.budget + dt * AC.sps, AC.sps)
    for i = 1, #tasks do
        local t = tasks[i]
        if t.on then
            t.acc += dt
            if t.acc >= t.iv then t.acc = 0 ok(t.fn) end
        end
    end
end))

---------------------------------------------------------------------
-- combat core
---------------------------------------------------------------------
local function slapCore(radius, extraTargets)
    local g = equipped()
    if not g then if S.autoequip then equipBest() end return end
    local h = handleOf(g)
    if not h then return end
    if AC.budget < 1 then return end
    AC.budget -= 1
    AC.lastSlap = os.clock()
    if h.Parent ~= Ch and Hum then pcall(function() Hum:EquipTool(g) end) end
    pcall(function() g:Activate() end)
    local n, cap = 0, S.maxT + (extraTargets or 0)
    for _, p in ipairs(P:GetPlayers()) do
        if n >= cap then break end
        if alive(p) then
            local t = hrp(p)
            if t and (h.Position - t.Position).Magnitude <= radius then
                touch(h, t)
                n += 1
            end
        end
    end
end

local slapT = reg(0.06, function() slapCore(S.size + 8, 0) end)
local killT = reg(0.06, function() slapCore(S.size + 16, 4) end)
local autoT = reg(0.1, function()
    local t, d = nearest(70)
    if not t then return end
    local g = equipped()
    local h = handleOf(g)
    if h then
        if AC.budget < 1 then return end
        AC.budget -= 1
        AC.lastSlap = os.clock()
        pcall(function() g:Activate() end)
        touch(h, t)
    elseif S.autoequip then equipBest() end
end)
local clickT = reg(0.15, function()
    local cam = workspace.CurrentCamera
    if not cam or not equipped() then return end
    local c = cam.ViewportSize / 2
    pcall(VU.Button1Down, VU, c)
    pcall(VU.Button1Up, VU, c)
end)
local abilityT = reg(0.6, function()
    if not equipped() then return end
    pressKey(Enum.KeyCode.E)
end)

---------------------------------------------------------------------
-- defence / survival
---------------------------------------------------------------------
local dodgeT = reg(0.3, function()
    if not HRP then return end
    for _, p in ipairs(P:GetPlayers()) do
        if alive(p) then
            local t = hrp(p)
            if t and (HRP.Position - t.Position).Magnitude < 7 then
                local d = (HRP.Position - t.Position).Unit
                HRP.CFrame = HRP.CFrame + Vector3.new(-d.Z, 0, d.X) * 4
                return
            end
        end
    end
end)
local voidT = reg(0.25, function()
    if HRP and HRP.Position.Y < -60 then
        local g = ground(HRP.Position)
        teleport(g and CFrame.new(g) or spawnCF(), true)
    end
end)
local ragT = reg(0.12, function()
    if not Ch then return end
    if Hum then
        if Hum.PlatformStand and not flyBV then Hum.PlatformStand = false end
        if Hum.Sit then Hum.Sit = false end
    end
    for _, d in ipairs(Ch:GetDescendants()) do
        if d:IsA("BallSocketConstraint") then d:Destroy() end
    end
end)
local knockT = reg(0, function()
    if not HRP then return end
    local v = HRP.AssemblyLinearVelocity
    if Vector3.new(v.X, 0, v.Z).Magnitude > 60 then
        HRP.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, v.Y, v.Z * 0.15)
    end
end)
local flingT = reg(0.1, function()
    if not HRP then return end
    local p = HRP.Position
    if p.X ~= p.X or p.Y ~= p.Y then teleport(CFrame.new(lastSafe), true) return end
    if HRP.AssemblyLinearVelocity.Magnitude > 1500 then HRP.AssemblyLinearVelocity = Vector3.zero end
    if HRP.AssemblyLinearVelocity.Magnitude < 400 then lastSafe = p end
end)
local ncT = reg(0.2, function()
    if not Ch then return end
    for _, d in ipairs(Ch:GetDescendants()) do
        if d:IsA("BasePart") then
            if ncStore[d] == nil then ncStore[d] = d.CanCollide end
            d.CanCollide = false
        end
    end
end)
local acidT = reg(0.15, function()
    if not HRP then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("BasePart") and string.find(string.lower(d.Name), "acid") then
            local r = d.CFrame:PointToObjectSpace(HRP.Position)
            local s = d.Size / 2
            if math.abs(r.X) <= s.X and math.abs(r.Y) <= s.Y and math.abs(r.Z) <= s.Z then
                teleport(d.CFrame + Vector3.new(0, s.Y + 5, 0), false)
                return
            end
        end
    end
end)
local dropT = reg(0.35, function()
    if not HRP or flyBV or HRP.Position.Y < 75 then return end
    local g = ground(HRP.Position)
    if g then teleport(CFrame.new(g), false) end
end)

---------------------------------------------------------------------
-- loot
---------------------------------------------------------------------
local function lootFilter(d)
    if not d:IsA("BasePart") then return false end
    local n = string.lower(d.Name)
    return string.find(n, "pickup") or string.find(n, "coin") or string.find(n, "slap") or string.find(n, "token")
end
local lootT = reg(0.3, function()
    if not HRP then return end
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if n >= 8 then break end
        if lootFilter(d) and (d.Position - HRP.Position).Magnitude < 55 then
            touch(HRP, d)
            n += 1
        end
    end
end)
local collectT = reg(0.4, function()
    if not HRP then return end
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if n >= 8 then break end
        if lootFilter(d) and (d.Position - HRP.Position).Magnitude < 40 then
            touch(HRP, d)
            n += 1
        end
    end
end)
local pickT = reg(0.4, function()
    if not HRP then return end
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Tool") and (d.Position - HRP.Position).Magnitude < 50 then touch(HRP, d) end
    end
end)
local healT = reg(0.6, function()
    if not Hum or not HRP then return end
    if Hum.Health < Hum.MaxHealth * 0.65 then
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and string.find(string.lower(d.Name), "pickup") then
                if (d.Position - HRP.Position).Magnitude < 30 then touch(HRP, d) end
            end
        end
    end
end)

---------------------------------------------------------------------
-- farm
---------------------------------------------------------------------
local winT = reg(1.4, function()
    if not HRP or not tpReady() then return end
    local sp = workspace:FindFirstChildOfClass("SpawnLocation")
    local center = sp and sp.Position or Vector3.new(0, 0, 0)
    local best, bd
    for _ = 1, 12 do
        local ang, rad = math.random() * math.pi * 2, math.random(25, 130)
        local g = ground(center + Vector3.new(math.cos(ang) * rad, 0, math.sin(ang) * rad))
        if g then
            local d = (g - HRP.Position).Magnitude
            if not bd or d < bd then best, bd = g, d end
        end
    end
    if best then teleport(CFrame.new(best), false) end
end)
local farmT = reg(0.7, function()
    if not HRP or not tpReady() then return end
    local t, d = nearest(320)
    if t then
        if d > 14 then teleport(t.CFrame * CFrame.new(0, 0, 4), false) end
        local g = equipped()
        local h = handleOf(g)
        if h and AC.budget >= 1 then
            AC.budget -= 1
            AC.lastSlap = os.clock()
            pcall(function() g:Activate() end)
            touch(h, t)
        end
    else
        local g = ground(HRP.Position)
        if g then teleport(CFrame.new(g), false) end
    end
end)
local function guiClick(words, cd)
    if os.clock() - lastBuy < cd then return end
    for _, d in ipairs(PG:GetDescendants()) do
        if d:IsA("TextButton") and d.Visible then
            local x = string.lower(d.Text)
            for _, w in ipairs(words) do
                if string.find(x, w) then
                    lastBuy = os.clock()
                    pcall(function() d:Activate() end)
                    return
                end
            end
        end
    end
end
local claimT = reg(1.8, function() guiClick({"claim", "collect", "reward", "daily"}, 1.8) end)
local buyT   = reg(2.2, function() guiClick({"buy", "purchase"}, 2.2) end)
local prestT = reg(3.2, function() guiClick({"prestige", "rebirth"}, 3.2) end)
local rejoinT = reg(0.6, function()
    if Hum and Hum.Health <= 0 then
        task.wait(2.2)
        ok(TP.Teleport, TP, game.PlaceId, LP)
    end
end)

---------------------------------------------------------------------
-- ESP
---------------------------------------------------------------------
local function makeESP(p)
    local o = {}
    if Drawing then
        o.box = Drawing.new("Square")
        o.box.Thickness, o.box.Filled, o.box.Transparency, o.box.Color = 1, false, 1, C.a
        o.tr = Drawing.new("Line")
        o.tr.Thickness, o.tr.Color, o.tr.Transparency = 1, C.a, 0.7
    end
    local hd = p.Character and p.Character:FindFirstChild("Head")
    if hd then
        local bb = Instance.new("BillboardGui")
        bb.Size, bb.StudsOffset, bb.AlwaysOnTop, bb.MaxDistance = UDim2.new(0, 160, 0, 18), Vector3.new(0, 3, 0), true, S.dist
        bb.Parent = hd
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency, l.Size, l.Font, l.TextSize = 1, UDim2.new(1, 0, 1, 0), Enum.Font.GothamBold, 12
        l.TextColor3, l.TextStrokeTransparency, l.Text = C.t, 0.4, p.DisplayName
        l.Parent = bb
        o.tag = bb
    end
    espObj[p] = o
end
local function killESP(p)
    local o = espObj[p]
    if not o then return end
    espObj[p] = nil
    if o.box then pcall(function() o.box:Remove() end) end
    if o.tr then pcall(function() o.tr:Remove() end) end
    if o.tag then o.tag:Destroy() end
end
local function corners(cf, size)
    local hs, out = size / 2, {}
    for _, x in ipairs({-1, 1}) do
        for _, y in ipairs({-1, 1}) do
            for _, z in ipairs({-1, 1}) do
                out[#out+1] = cf * Vector3.new(hs.X * x, hs.Y * y, hs.Z * z)
            end
        end
    end
    return out
end
local espActive = false
add(RUN.RenderStepped:Connect(function()
    if not espActive then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    for p, o in pairs(espObj) do
        if not p.Parent or not alive(p) then
            killESP(p)
        else
            local r = p.Character.HumanoidRootPart
            local vis = HRP and r and (HRP.Position - r.Position).Magnitude <= S.dist
            if o.tag then o.tag.MaxDistance = S.dist o.tag.Enabled = S.esp and vis end
            if o.box then
                local cf, sz = p.Character:GetBoundingBox()
                local minx, miny, maxx, maxy, good = math.huge, math.huge, -math.huge, -math.huge, true
                for _, w in ipairs(corners(cf, sz)) do
                    local sp, on = cam:WorldToViewportPoint(w)
                    if on then
                        minx, miny = math.min(minx, sp.X), math.min(miny, sp.Y)
                        maxx, maxy = math.max(maxx, sp.X), math.max(maxy, sp.Y)
                    else good = false end
                end
                o.box.Visible = S.box and vis and good
                if o.box.Visible then
                    o.box.Size = Vector2.new(maxx - minx, maxy - miny)
                    o.box.Position = Vector2.new(minx, miny)
                end
            end
            if o.tr then
                o.tr.Visible = S.tracer and vis and r ~= nil
                if o.tr.Visible then
                    local v = cam:WorldToViewportPoint(r.Position)
                    o.tr.From = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                    o.tr.To = Vector2.new(v.X, v.Y)
                end
            end
        end
    end
end))
add(RUN.Heartbeat:Connect(function()
    if unloaded then return end
    espActive = S.esp or S.box or S.tracer
    if espActive then
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP and alive(p) and not espObj[p] then makeESP(p) end
        end
    elseif next(espObj) then
        for p in pairs(espObj) do killESP(p) end
    end
end))
local itemT = reg(0.8, function()
    for i, t in pairs(lootTags) do
        if not i.Parent or not HRP or (i.Position - HRP.Position).Magnitude > S.dist then
            t:Destroy() lootTags[i] = nil
        end
    end
    if not S.itemesp or not HRP then return end
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if n >= 30 then break end
        if lootFilter(d) and not lootTags[d] and (d.Position - HRP.Position).Magnitude <= S.dist then
            local bb = Instance.new("BillboardGui")
            bb.Size, bb.AlwaysOnTop, bb.MaxDistance = UDim2.new(0, 120, 0, 14), true, S.dist
            bb.Parent = d
            local l = Instance.new("TextLabel")
            l.BackgroundTransparency, l.Size, l.Font, l.TextSize = 1, UDim2.new(1, 0, 1, 0), Enum.Font.GothamBold, 11
            l.TextColor3, l.TextStrokeTransparency, l.Text = C.a2, 0.4, d.Name
            l.Parent = bb
            lootTags[d] = bb
            n += 1
        end
    end
end)

---------------------------------------------------------------------
-- fly (physics state, less flaggy than PlatformStand)
---------------------------------------------------------------------
local ctrl
local function controls()
    if ctrl ~= nil then return ctrl or nil end
    local a, pm = pcall(function()
        return require(LP:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
    end)
    if a and pm then
        local b, c = pcall(function() return pm:GetControls() end)
        ctrl = (b and c) or false
    else ctrl = false end
    return ctrl or nil
end
local function flyOn()
    if flyBV or not HRP or not Hum then return end
    Hum:ChangeState(Enum.HumanoidStateType.Physics)
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBV.Parent = HRP
end
local function flyOff()
    if flyBV then flyBV:Destroy() flyBV = nil end
    stick = Vector3.zero
    if Hum then
        Hum.PlatformStand = false
        pcall(function() Hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
end
add(RUN.RenderStepped:Connect(function()
    if not flyBV or not HRP then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local mv = Vector3.zero
    local c = controls()
    if c then
        local a, v = pcall(function() return c:GetMoveVector() end)
        if a and v and v.Magnitude > 0.05 then mv = v end
    end
    if mv.Magnitude < 0.05 and stick.Magnitude > 0.05 then mv = stick end
    if mv.Magnitude > 1 then mv = mv.Unit end
    local dir = cam.CFrame:VectorToWorldSpace(Vector3.new(mv.X, 0, mv.Z))
    flyBV.Velocity = dir * S.speed + Vector3.new(0, S.lift, 0)
end))

---------------------------------------------------------------------
-- UI framework
---------------------------------------------------------------------
local function card(parent)
    local f = Instance.new("Frame")
    f.BackgroundColor3, f.BorderSizePixel = C.p, 0
    f.Size = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    local p = Instance.new("UIPadding", f)
    p.PaddingTop, p.PaddingBottom, p.PaddingLeft, p.PaddingRight =
        UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)
    local l = Instance.new("UIListLayout", f)
    l.Padding, l.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder
    return f
end

local function section(parent, name)
    local w = Instance.new("Frame")
    w.BackgroundTransparency, w.Size = 1, UDim2.new(1, 0, 0, 20)
    w.Parent = parent
    w:SetAttribute("svText", name)
    local bar = Instance.new("Frame")
    bar.BackgroundColor3, bar.BorderSizePixel = C.a, 0
    bar.Size, bar.Position = UDim2.new(0, 3, 0, 11), UDim2.new(0, 0, 0, 5)
    bar.Parent = w
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency, l.Position, l.Size = 1, UDim2.new(0, 10, 0, 0), UDim2.new(1, -10, 1, 0)
    l.Font, l.TextSize, l.TextXAlignment, l.TextColor3 = Enum.Font.GothamBold, 9, Enum.TextXAlignment.Left, C.m
    l.Text = string.upper(name)
    l.Parent = w
end

local function toggle(parent, label, key, cb)
    local r = Instance.new("Frame")
    r.BackgroundColor3, r.BorderSizePixel = C.p2, 0
    r.Size, r.Name = UDim2.new(1, 0, 0, 30), "row"
    r.Parent = parent
    r:SetAttribute("svText", label)
    Instance.new("UICorner", r).CornerRadius = UDim.new(0, 7)
    local b = Instance.new("TextButton")
    b.BackgroundTransparency, b.Size, b.Text = 1, UDim2.new(1, 0, 1, 0), ""
    b.Parent = r
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency, l.Position, l.Size = 1, UDim2.new(0, 9, 0, 0), UDim2.new(1, -54, 1, 0)
    l.Font, l.TextSize, l.TextXAlignment, l.TextColor3 = Enum.Font.GothamMedium, 11, Enum.TextXAlignment.Left, C.t
    l.Text = label
    l.Parent = r
    local tr = Instance.new("Frame")
    tr.BackgroundColor3, tr.BorderSizePixel = C.p3, 0
    tr.Position, tr.Size = UDim2.new(1, -42, 0.5, -8), UDim2.new(0, 32, 0, 16)
    tr.Parent = r
    Instance.new("UICorner", tr).CornerRadius = UDim.new(1, 0)
    local kn = Instance.new("Frame")
    kn.BackgroundColor3, kn.BorderSizePixel = C.m, 0
    kn.Position, kn.Size = UDim2.new(0, 2, 0.5, -6), UDim2.new(0, 12, 0, 12)
    kn.Parent = tr
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)
    local on = false
    local function set(v, force)
        if on == v and not force then return end
        on, S[key] = v, v
        TS:Create(kn, TweenInfo.new(0.13), {Position = v and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = v and C.a or C.m}):Play()
        TS:Create(tr, TweenInfo.new(0.13), {BackgroundColor3 = v and Color3.fromRGB(46, 36, 88) or C.p3}):Play()
        if cb and not force then ok(cb, v) end
    end
    b.MouseButton1Click:Connect(function() set(not on) end)
    toggles[key] = set
end

local function stepper(parent, label, key, min, max, step)
    local r = Instance.new("Frame")
    r.BackgroundColor3, r.BorderSizePixel = C.p2, 0
    r.Size = UDim2.new(1, 0, 0, 30)
    r.Parent = parent
    r:SetAttribute("svText", label)
    Instance.new("UICorner", r).CornerRadius = UDim.new(0, 7)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency, l.Position, l.Size = 1, UDim2.new(0, 9, 0, 0), UDim2.new(1, -104, 1, 0)
    l.Font, l.TextSize, l.TextXAlignment, l.TextColor3 = Enum.Font.GothamMedium, 11, Enum.TextXAlignment.Left, C.t
    l.Text = label
    l.Parent = r
    local val = Instance.new("TextLabel")
    val.BackgroundColor3, val.BorderSizePixel = C.p3, 0
    val.Position, val.Size = UDim2.new(1, -70, 0.5, -9), UDim2.new(0, 38, 0, 18)
    val.Font, val.TextSize, val.TextColor3 = Enum.Font.GothamBold, 10, C.a
    val.Parent = r
    Instance.new("UICorner", val).CornerRadius = UDim.new(0, 5)
    local function draw() val.Text = tostring(S[key]) end
    draw()
    steppers[key] = draw
    local function shift(d)
        S[key] = clamp(S[key] + d, min, max)
        draw()
    end
    local function hold(b, d)
        local held = false
        b.MouseButton1Down:Connect(function()
            held = true
            shift(d)
            task.spawn(function()
                task.wait(0.35)
                while held do shift(d) task.wait(0.06) end
            end)
        end)
        b.MouseButton1Up:Connect(function() held = false end)
        b.MouseLeave:Connect(function() held = false end)
    end
    local minus = Instance.new("TextButton")
    minus.BackgroundColor3, minus.BorderSizePixel = C.p3, 0
    minus.Position, minus.Size = UDim2.new(1, -30, 0.5, -9), UDim2.new(0, 24, 0, 18)
    minus.Font, minus.TextSize, minus.TextColor3, minus.Text = Enum.Font.GothamBold, 13, C.bad, "-"
    minus.Parent = r
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 5)
    hold(minus, -step)
    local plus = Instance.new("TextButton")
    plus.BackgroundColor3, plus.BorderSizePixel = C.p3, 0
    plus.Position, plus.Size = UDim2.new(1, -2, 0.5, -9), UDim2.new(0, 24, 0, 18)
    plus.Font, plus.TextSize, plus.TextColor3, plus.Text = Enum.Font.GothamBold, 13, C.a2, "+"
    plus.Parent = r
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 5)
    hold(plus, step)
end

local function button(parent, label, fn, color)
    local b = Instance.new("TextButton")
    b.BackgroundColor3, b.BorderSizePixel, b.AutoButtonColor = C.p2, 0, false
    b.Size, b.Font, b.TextSize = UDim2.new(1, 0, 0, 28), Enum.Font.GothamMedium, 11
    b.Text, b.TextColor3 = label, color or C.t
    b.Parent = parent
    b:SetAttribute("svText", label)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    b.MouseButton1Click:Connect(function()
        TS:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = C.p3}):Play()
        task.delay(0.1, function() TS:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = C.p2}):Play() end)
        ok(fn)
    end)
end

local function page(name)
    local sc = Instance.new("ScrollingFrame")
    sc.BackgroundTransparency, sc.BorderSizePixel = 1, 0
    sc.Size, sc.Visible, sc.ScrollBarThickness = UDim2.new(1, 0, 1, -110), false, 2
    sc.CanvasSize, sc.AutomaticCanvasSize = UDim2.new(0, 0, 0, 0), Enum.AutomaticSize.Y
    sc.ScrollBarImageColor3 = C.st
    sc.Parent = main
    local pd = Instance.new("UIPadding", sc)
    pd.PaddingLeft, pd.PaddingRight, pd.PaddingTop, pd.PaddingBottom =
        UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 4), UDim.new(0, 12)
    local ly = Instance.new("UIListLayout", sc)
    ly.Padding, ly.SortOrder = UDim.new(0, 6), Enum.SortOrder.LayoutOrder
    pages[name] = sc
    return sc
end

local function applyFilter()
    local q = search and string.lower(search.Text) or ""
    local p = pages[currentTab]
    if not p then return end
    for _, c in ipairs(p:GetDescendants()) do
        local txt = c:GetAttribute("svText")
        if txt then
            c.Visible = (q == "" or string.find(string.lower(txt), q, 1, true) ~= nil)
        end
    end
end

local function selectTab(name)
    currentTab = name
    for n, p in pairs(pages) do p.Visible = (n == name) end
    local i = 0
    for _, b in ipairs(tabBar:GetChildren()) do
        if b:IsA("TextButton") then
            i += 1
            local on = b.Name == name
            b.TextColor3 = on and C.t or C.m
            if on and underline then
                TS:Create(underline, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {
                    Position = UDim2.new(0, b.AbsolutePosition.X - main.AbsolutePosition.X + 8, 0, 30),
                    Size = UDim2.new(0, b.AbsoluteSize.X - 16, 0, 2),
                }):Play()
            end
        end
    end
    applyFilter()
end

---------------------------------------------------------------------
-- shell
---------------------------------------------------------------------
local function buildShell()
    if PG:FindFirstChild("SvHub") then PG.SvHub:Destroy() end
    G = Instance.new("ScreenGui")
    G.Name, G.ResetOnSpawn, G.DisplayOrder = "SvHub", false, 999

    toastHost = Instance.new("Frame")
    toastHost.BackgroundTransparency, toastHost.BorderSizePixel = 1, 0
    toastHost.Position, toastHost.Size = UDim2.new(0, 10, 0, 52), UDim2.new(0, 312, 0, 90)
    toastHost.Parent = G
    local thl = Instance.new("UIListLayout", toastHost)
    thl.Padding, thl.SortOrder = UDim.new(0, 4), Enum.SortOrder.LayoutOrder

    main = Instance.new("Frame")
    main.BackgroundColor3, main.BorderSizePixel = C.bg, 0
    main.Position, main.Size = UDim2.new(0, 10, 0, 56), UDim2.new(0, 312, 0, 462)
    main.ClipsDescendants, main.Active = true, true
    main.Parent = G
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
    local ms = Instance.new("UIStroke", main)
    ms.Color, ms.Transparency = C.st, 0.35

    local hd = Instance.new("Frame")
    hd.BackgroundColor3, hd.BorderSizePixel, hd.Size = C.p, 0, UDim2.new(1, 0, 0, 34)
    hd.Parent = main
    Instance.new("UICorner", hd).CornerRadius = UDim.new(0, 14)

    local dot = Instance.new("Frame")
    dot.BackgroundColor3, dot.BorderSizePixel = C.a2, 0
    dot.Position, dot.Size = UDim2.new(0, 12, 0.5, -3), UDim2.new(0, 6, 0, 6)
    dot.Parent = hd
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    task.spawn(function()
        while not unloaded do
            TS:Create(dot, TweenInfo.new(0.7), {BackgroundTransparency = 0.6}):Play()
            task.wait(0.7)
            TS:Create(dot, TweenInfo.new(0.7), {BackgroundTransparency = 0}):Play()
            task.wait(0.7)
        end
    end)

    local ti = Instance.new("TextLabel")
    ti.BackgroundTransparency, ti.Position, ti.Size = 1, UDim2.new(0, 24, 0, 0), UDim2.new(1, -84, 1, 0)
    ti.Font, ti.TextSize, ti.TextColor3, ti.TextXAlignment = Enum.Font.GothamBold, 12, C.t, Enum.TextXAlignment.Left
    ti.Text = "SVCLUTCHER"
    ti.Parent = hd

    local xb = Instance.new("TextButton")
    xb.BackgroundColor3, xb.BorderSizePixel = C.p3, 0
    xb.Position, xb.Size = UDim2.new(1, -30, 0.5, -10), UDim2.new(0, 20, 0, 20)
    xb.Font, xb.TextSize, xb.TextColor3, xb.Text = Enum.Font.GothamBold, 12, C.bad, "x"
    xb.Parent = hd
    Instance.new("UICorner", xb).CornerRadius = UDim.new(0, 6)

    -- profile segmented control
    segBar = Instance.new("Frame")
    segBar.BackgroundColor3, segBar.BorderSizePixel = C.p, 0
    segBar.Position, segBar.Size = UDim2.new(0, 8, 0, 38), UDim2.new(1, -16, 0, 26)
    segBar.Parent = main
    Instance.new("UICorner", segBar).CornerRadius = UDim.new(0, 7)
    local sp2 = Instance.new("UIPadding", segBar)
    sp2.PaddingTop, sp2.PaddingBottom, sp2.PaddingLeft, sp2.PaddingRight =
        UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3), UDim.new(0, 3)
    local sl = Instance.new("UIListLayout", segBar)
    sl.FillDirection, sl.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 3)
    for _, n in ipairs({"Legit", "Balanced", "Rage"}) do
        local b = Instance.new("TextButton")
        b.Name, b.BorderSizePixel, b.AutoButtonColor = n, 0, false
        b.BackgroundColor3, b.BackgroundTransparency = C.p2, 0
        b.Size, b.Font, b.TextSize, b.TextColor3 = UDim2.new(1, -6, 1, 0), Enum.Font.GothamBold, 10, C.m
        b.Text = n
        b.Parent = segBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
        b.MouseButton1Click:Connect(function() ok(function() F.profile(n) end) end)
    end

    tabBar = Instance.new("Frame")
    tabBar.BackgroundTransparency, tabBar.BorderSizePixel = 1, 0
    tabBar.Position, tabBar.Size = UDim2.new(0, 0, 0, 68), UDim2.new(1, 0, 0, 30)
    tabBar.Parent = main
    local tl = Instance.new("UIListLayout", tabBar)
    tl.FillDirection, tl.Padding = Enum.FillDirection.Horizontal, UDim.new(0, 4)
    local tp = Instance.new("UIPadding", tabBar)
    tp.PaddingLeft, tp.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)

    for _, n in ipairs({"Royale", "Battles", "Server"}) do
        local b = Instance.new("TextButton")
        b.Name, b.BorderSizePixel, b.AutoButtonColor = n, 0, false
        b.BackgroundTransparency, b.Size = 1, UDim2.new(1, -16, 1, 0)
        b.Font, b.TextSize, b.TextColor3, b.Text = Enum.Font.GothamBold, 11, C.m, n
        b.Parent = tabBar
        b.MouseButton1Click:Connect(function() selectTab(n) end)
    end

    underline = Instance.new("Frame")
    underline.BackgroundColor3, underline.BorderSizePixel = C.a, 0
    underline.Position, underline.Size = UDim2.new(0, 8, 0, 30), UDim2.new(0, 60, 0, 2)
    underline.Parent = main
    Instance.new("UICorner", underline).CornerRadius = UDim.new(1, 0)

    search = Instance.new("TextBox")
    search.BackgroundColor3, search.BorderSizePixel = C.p, 0
    search.Position, search.Size = UDim2.new(0, 8, 0, 100), UDim2.new(1, -16, 0, 26)
    search.Font, search.TextSize, search.TextColor3 = Enum.Font.Gotham, 11, C.t
    search.PlaceholderText, search.PlaceholderColor3 = "Search features...", C.m
    search.Text, search.ClearTextOnFocus = "", false
    search.Parent = main
    Instance.new("UICorner", search).CornerRadius = UDim.new(0, 7)
    local spad = Instance.new("UIPadding", search)
    spad.PaddingLeft, spad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
    search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    statusLbl = Instance.new("TextLabel")
    statusLbl.BackgroundTransparency, statusLbl.Position, statusLbl.Size = 1, UDim2.new(0, 10, 1, -19), UDim2.new(1, -20, 0, 15)
    statusLbl.Font, statusLbl.TextSize, statusLbl.TextColor3 = Enum.Font.Gotham, 9, C.m
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = main

    floating = Instance.new("TextButton")
    floating.BackgroundColor3, floating.BorderSizePixel = C.a, 0
    floating.Position, floating.Size = UDim2.new(0, 10, 0, 56), UDim2.new(0, 44, 0, 44)
    floating.Font, floating.TextSize, floating.TextColor3, floating.Text = Enum.Font.GothamBold, 12, Color3.new(1, 1, 1), "SV"
    floating.Visible = false
    floating.Parent = G
    Instance.new("UICorner", floating).CornerRadius = UDim.new(1, 0)
    floating.MouseButton1Click:Connect(function()
        floating.Visible = false
        main.Visible = true
    end)
    xb.MouseButton1Click:Connect(function()
        main.Visible = false
        floating.Visible = true
    end)

    local drag, ds, sp
    hd.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag, ds, sp = true, i.Position, main.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    add(UIS.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            main.Position = UDim2.new(0, sp.X.Offset + d.X, 0, sp.Y.Offset + d.Y)
        end
    end))

    G.Parent = PG
    main.Size = UDim2.new(0, 300, 0, 462)
    TS:Create(main, TweenInfo.new(0.16, Enum.EasingStyle.Quad), {Size = UDim2.new(0, 312, 0, 462)}):Play()
    task.spawn(function()
        while not unloaded do
            local dt = RUN.RenderStepped:Wait()
            statusLbl.Text = string.format("%s  ·  %d fps  ·  %s  ·  %.1f sps",
                game.Name, math.floor(1 / math.max(dt, 0.001)), AC.profile, AC.sps)
        end
    end)
end

buildShell()

---------------------------------------------------------------------
-- pages
---------------------------------------------------------------------
local pgR = page("Royale")
local c = card(pgR)
section(c, "Combat")
toggle(c, "Slap Aura", "slap")
toggle(c, "Kill Aura", "kill")
toggle(c, "Auto Equip", "autoequip")
toggle(c, "Auto Ability (E)", "ability")
toggle(c, "Hitbox Reach", "reach")
stepper(c, "Reach Size", "size", 8, 40, 2)
stepper(c, "Max Targets", "maxT", 1, 20, 1)

c = card(pgR)
section(c, "Auto Farm")
toggle(c, "Auto Farm", "farm")
toggle(c, "Auto Slap Nearest", "autoslap")
toggle(c, "Auto Loot", "autoloot")
toggle(c, "Auto Collect Coins", "collect")
toggle(c, "Auto Pickup Gloves", "autopick")
toggle(c, "Auto Heal", "autoheal")
toggle(c, "Auto Win (roam)", "autowin")
toggle(c, "Anti AFK", "afk")

c = card(pgR)
section(c, "Survival")
toggle(c, "Anti Acid", "acid")
toggle(c, "Auto Drop to Ground", "drop")
toggle(c, "Anti Void", "void")
toggle(c, "Anti Ragdoll", "ragdoll")
toggle(c, "Anti Fling", "fling")
toggle(c, "Anti Knockback", "knock")
toggle(c, "Auto Dodge", "dodge")

c = card(pgR)
section(c, "Movement")
toggle(c, "Fly (joystick)", "fly", function(v) F.fly(v) end)
stepper(c, "Fly Speed", "speed", 20, 220, 5)
stepper(c, "Walk Speed", "ws", 16, 250, 2)
stepper(c, "Jump Power", "jp", 50, 400, 10)
toggle(c, "Infinite Jump", "ijump")
toggle(c, "Noclip", "noclip")

c = card(pgR)
section(c, "Visuals")
toggle(c, "Player ESP", "esp")
toggle(c, "Box ESP", "box")
toggle(c, "Tracers", "tracer")
toggle(c, "Item ESP", "itemesp")
toggle(c, "Fullbright", "bright", function(v) F.bright(v) end)
stepper(c, "ESP Distance", "dist", 100, 3000, 100)

c = card(pgR)
section(c, "Anti-Cheat")
toggle(c, "Smooth Teleport", "smooth")
toggle(c, "Stealth Hitbox", "stealth")
button(c, "Reset Hitboxes", function() F.restoreBoxes() end)

c = card(pgR)
section(c, "Gloves")
gloveList = Instance.new("Frame")
gloveList.BackgroundTransparency, gloveList.Size = 1, UDim2.new(1, 0, 0, 0)
gloveList.AutomaticSize = Enum.AutomaticSize.Y
gloveList.Parent = c
local gl = Instance.new("UIListLayout", gloveList)
gl.Padding, gl.SortOrder = UDim.new(0, 3), Enum.SortOrder.LayoutOrder
button(c, "Refresh Gloves", function() F.refreshGloves() end)

c = card(pgR)
section(c, "Teleport")
button(c, "TP to Nearest Player", function() F.tpNearest() end)
button(c, "TP to Safe Ground", function() F.tpSafe() end)
button(c, "TP to Spawn", function() F.tpSpawn() end)

local pgB = page("Battles")
c = card(pgB)
section(c, "Combat")
toggle(c, "Slap Aura", "slap")
toggle(c, "Kill Aura", "kill")
toggle(c, "Auto Clicker", "click")
toggle(c, "Auto Equip", "autoequip")
toggle(c, "Auto Ability (E)", "ability")
toggle(c, "Hitbox Reach", "reach")
stepper(c, "Reach Size", "size", 8, 40, 2)
stepper(c, "Max Targets", "maxT", 1, 20, 1)

c = card(pgB)
section(c, "Farm")
toggle(c, "Auto Farm", "farm")
toggle(c, "Auto Slap Nearest", "autoslap")
toggle(c, "Auto Collect Slaps", "collect")
toggle(c, "Auto Claim Rewards", "claim")
toggle(c, "Auto Buy Gloves", "buy")
toggle(c, "Auto Prestige", "prestige")
toggle(c, "Auto Rejoin on Death", "rejoin")
toggle(c, "Anti AFK", "afk")

c = card(pgB)
section(c, "Defence")
toggle(c, "Anti Void", "void")
toggle(c, "Anti Ragdoll", "ragdoll")
toggle(c, "Anti Fling", "fling")
toggle(c, "Anti Knockback", "knock")
toggle(c, "Auto Dodge", "dodge")

c = card(pgB)
section(c, "Movement")
toggle(c, "Fly (joystick)", "fly", function(v) F.fly(v) end)
stepper(c, "Fly Speed", "speed", 20, 220, 5)
stepper(c, "Walk Speed", "ws", 16, 250, 2)
stepper(c, "Jump Power", "jp", 50, 400, 10)
toggle(c, "Infinite Jump", "ijump")
toggle(c, "Noclip", "noclip")

c = card(pgB)
section(c, "Visuals")
toggle(c, "Player ESP", "esp")
toggle(c, "Box ESP", "box")
toggle(c, "Tracers", "tracer")
toggle(c, "Glove ESP", "gloveesp")
toggle(c, "Fullbright", "bright", function(v) F.bright(v) end)
stepper(c, "ESP Distance", "dist", 100, 3000, 100)

c = card(pgB)
section(c, "Anti-Cheat")
toggle(c, "Smooth Teleport", "smooth")
toggle(c, "Stealth Hitbox", "stealth")
button(c, "Reset Hitboxes", function() F.restoreBoxes() end)

c = card(pgB)
section(c, "Actions")
button(c, "Slap All (once)", function() F.slapAll() end)
button(c, "Collect All (once)", function() F.collectAll() end)

local pgS = page("Server")
c = card(pgS)
section(c, "Session")
button(c, "Rejoin", function() F.rejoin() end)
button(c, "Server Hop", function() F.hop() end)
button(c, "Reset Character", function() F.reset() end)

c = card(pgS)
section(c, "Performance")
button(c, "FPS Boost", function() F.boost() end)
button(c, "UNLOAD HUB", function() F.unload() end, C.bad)

---------------------------------------------------------------------
-- features
---------------------------------------------------------------------
F.profile = function(name)
    local p = PROFILES[name]
    if not p then return end
    AC.profile, AC.sps, AC.budget = name, p.sps, p.sps
    AC.tpLock = (name == "Legit") and 1.2 or (name == "Balanced") and 0.6 or 0.2
    S.size, S.speed, S.ws, S.smooth, S.stealth = p.size, p.speed, p.ws, p.smooth, p.stealth
    for _, k in ipairs({"size", "speed", "ws"}) do
        if steppers[k] then steppers[k]() end
    end
    if toggles.smooth then toggles.smooth(S.smooth, true) end
    if toggles.stealth then toggles.stealth(S.stealth, true) end
    for _, b in ipairs(segBar:GetChildren()) do
        if b:IsA("TextButton") then
            local on = b.Name == name
            TS:Create(b, TweenInfo.new(0.12), {
                BackgroundColor3 = on and C.a or C.p2,
                TextColor3 = on and Color3.new(1, 1, 1) or C.m,
            }):Play()
        end
    end
    toast("Profile: " .. name .. " (" .. p.sps .. " sps)")
end

F.fly = function(v) if v then flyOn() else flyOff() end end

F.bright = function(v)
    if v then
        lightStore = lightStore or {b = LT.Brightness, a = LT.Ambient, o = LT.OutdoorAmbient, c = LT.ClockTime}
        LT.Brightness, LT.Ambient = 3, Color3.fromRGB(180, 180, 180)
        LT.OutdoorAmbient, LT.ClockTime = Color3.fromRGB(180, 180, 180), 14
    elseif lightStore then
        LT.Brightness, LT.Ambient = lightStore.b, lightStore.a
        LT.OutdoorAmbient, LT.ClockTime = lightStore.o, lightStore.c
        lightStore = nil
    end
end

F.slapAll = function()
    local g = equipped()
    local h = handleOf(g)
    if not h then return toast("Equip a glove first", "warn") end
    local n = 0
    for _, p in ipairs(P:GetPlayers()) do
        if alive(p) then
            local t = hrp(p)
            if t then touch(h, t) n += 1 end
        end
    end
    toast("Slapped " .. n)
end

F.collectAll = function()
    if not HRP then return end
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if lootFilter(d) and (d.Position - HRP.Position).Magnitude < 150 then
            touch(HRP, d)
            n += 1
        end
    end
    toast("Collected " .. n)
end

F.tpNearest = function()
    local t = nearest(900)
    if t then
        teleport(t.CFrame * CFrame.new(0, 0, 3), false)
        toast("Teleported")
    else
        toast("Nobody nearby", "warn")
    end
end
F.tpSafe = function()
    if not HRP then return end
    local g = ground(HRP.Position)
    teleport(g and CFrame.new(g) or spawnCF(), false)
end
F.tpSpawn = function() if HRP then teleport(spawnCF(), false) end end

F.rejoin = function()
    toast("Rejoining...")
    task.wait(0.3)
    ok(TP.Teleport, TP, game.PlaceId, LP)
end

F.hop = function()
    local req = request or http_request
    if not req then return toast("No HTTP executor", "bad") end
    local a, res = pcall(req, {
        Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100",
        Method = "GET",
    })
    if not a or not res or not res.Body then return toast("Hop failed", "bad") end
    local b, data = pcall(function() return HS:JSONDecode(res.Body) end)
    if not b then return toast("Hop failed", "bad") end
    for _, s in ipairs(data.data or {}) do
        if s.id ~= game.JobId and s.playing < s.maxPlayers then
            ok(TP.TeleportToPlaceInstance, TP, game.PlaceId, s.id, LP)
            return
        end
    end
    toast("No open server", "warn")
end

F.reset = function() if Hum then pcall(function() Hum.Health = 0 end) end end

F.boost = function()
    ok(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") then v.Enabled = false end
        end
    end)
    toast("Boost applied")
end

F.restoreBoxes = function()
    for h in pairs(orig) do small(h) end
    toast("Hitboxes reset")
end

F.refreshGloves = function()
    if not gloveList then return end
    for _, x in ipairs(gloveList:GetChildren()) do
        if x:IsA("TextButton") then x:Destroy() end
    end
    local bp = LP:FindFirstChild("Backpack")
    local n = 0
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and n < 40 then
                n += 1
                local b = Instance.new("TextButton")
                b.BackgroundColor3, b.BorderSizePixel, b.AutoButtonColor = C.p3, 0, false
                b.Size, b.Font, b.TextSize, b.TextColor3 = UDim2.new(1, 0, 0, 24), Enum.Font.GothamMedium, 10, C.t
                b.Text, b.TextXAlignment = t.Name, Enum.TextXAlignment.Left
                b.Parent = gloveList
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
                local pad = Instance.new("UIPadding", b)
                pad.PaddingLeft = UDim.new(0, 8)
                b.MouseButton1Click:Connect(function()
                    equipGlove(t.Name)
                    toast("Equipped " .. t.Name)
                end)
            end
        end
    end
    toast(n > 0 and (n .. " gloves found") or "Backpack empty", n > 0 and nil or "warn")
end

F.unload = function()
    if unloaded then return end
    unloaded = true
    ok(flyOff)
    for h in pairs(orig) do small(h) end
    for p in pairs(espObj) do killESP(p) end
    for i, t in pairs(lootTags) do t:Destroy() lootTags[i] = nil end
    for _, c2 in ipairs(conns) do ok(function() c2:Disconnect() end) end
    if lightStore then
        LT.Brightness, LT.Ambient = lightStore.b, lightStore.a
        LT.OutdoorAmbient, LT.ClockTime = lightStore.o, lightStore.c
    end
    for _, n in ipairs({"SvHub", "SvNotif"}) do
        local x = PG:FindFirstChild(n)
        if x then x:Destroy() end
    end
end

---------------------------------------------------------------------
-- loops
---------------------------------------------------------------------
local map = {
    slap=slapT, kill=killT, click=clickT, ability=abilityT, dodge=dodgeT,
    void=voidT, ragdoll=ragT, fling=flingT, knock=knockT, acid=acidT,
    drop=dropT, autoslap=autoT, farm=farmT, autoheal=healT,
    claim=claimT, buy=buyT, prestige=prestT, rejoin=rejoinT,
    autowin=winT, autopick=pickT, itemesp=itemT, autoloot=lootT, collect2=collectT,
}

task.spawn(function()
    while not unloaded do
        RUN.Heartbeat:Wait()
        for k, t in pairs(map) do
            local flag = (k == "collect2") and S.collect or S[k]
            t.on = flag == true
        end
        ncT.on = S.noclip
        clickT.iv = math.max(S.cps, 1 / math.max(AC.sps, 1))
        if Hum and Hum.Parent then
            if Hum.WalkSpeed ~= S.ws then Hum.WalkSpeed = S.ws end
            if Hum.UseJumpPower and Hum.JumpPower ~= S.jp then Hum.JumpPower = S.jp end
        end
        local g = equipped()
        local h = handleOf(g)
        local hold = wantBox() and h and (not S.stealth or (os.clock() - AC.lastSlap) < 0.35)
        if hold then
            big(h)
            for x in pairs(orig) do
                if x ~= h then small(x) end
            end
        elseif next(orig) then
            for x in pairs(orig) do small(x) end
        end
    end
end)

add(UIS.JumpRequest:Connect(function()
    if S.ijump and Hum then Hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))
add(LP.Idled:Connect(function()
    if not S.afk then return end
    VU:CaptureController()
    VU:ClickButton2(Vector2.new(0.5, 0.5))
end))
add(UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
        floating.Visible = not main.Visible
    end
end))

selectTab(string.find(string.lower(game.Name), "royale") and "Royale" or "Battles")
task.delay(0.3, function() ok(F.profile, "Balanced") end)
task.delay(0.6, function() ok(F.refreshGloves) end)
toast("Svclutcher v6 ready")
print("[Svclutcher] ready — " .. game.Name)
