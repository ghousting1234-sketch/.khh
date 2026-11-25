--!nocheck
--[[==================================================================
    HalfPunch Panel (sem key)
    --------------------------------------------------------------
    Usa: ReplicatedStorage.HalfPunch.Remotes
         BodyHit | Hit | Grab
         PlayerGui.HalfPunchTouch (fallback de input local)
    Tudo com pcall, loops gerenciados e alvo por proximidade.
==================================================================]]--

local VERSION = "1.0.0"

local CONFIG = {
    Interval = 0.06,      -- segundos entre disparos dos loops
    Radius   = 35,        -- raio de deteccao / aura
    Reach    = 1,         -- multiplicador do vetor de alcance
    AntiFlingCap = 900,
    ShowHUD  = true,
}

--==================== servicos ====================================--
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local Lighting     = game:GetService("Lighting")
local Workspace    = game:GetService("Workspace")
local RS           = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer
local genv = getgenv or function() return _G end
local unpack = table.unpack or unpack
local clamp = math.clamp or function(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

local function rnd(n)
    local t = {}
    for i = 1, n do t[i] = string.char(math.random(97, 122)) end
    return table.concat(t)
end

local S = {
    dead = false, conns = {},
    loops = {},
    cfg = {
        interval = CONFIG.Interval,
        radius = CONFIG.Radius,
        reach = CONFIG.Reach,
        side = "Right",
        part = "Hand",
        hitPart = "UpperTorso",
        targetMode = "nearest",
        targetName = nil,
    },
    ui = nil, hud = nil, logBox = nil, status = nil, bar = nil,
    pages = {}, godmode = false, grabbed = nil, fired = 0,
}
genv().__hp_panel = S

local function log(...)
    local msg = table.concat({...}, " ")
    if S.status then pcall(function() S.status.Text = msg end) end
    if S.logBox then
        pcall(function()
            local l = Instance.new("TextLabel")
            l.Size = UDim2.new(1, -6, 0, 14)
            l.BackgroundTransparency = 1
            l.Font = Enum.Font.Code
            l.TextSize = 11
            l.TextXAlignment = Enum.TextXAlignment.Left
            l.TextColor3 = Color3.fromRGB(140, 148, 162)
            l.Text = msg
            l.Parent = S.logBox
            S.logBox.CanvasSize = UDim2.new(0, 0, 0, #S.logBox:GetChildren() * 15)
        end)
    end
    print("[HP]", msg)
end

--==================== utils =======================================--
local function new(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function corner(p, r)
    return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p)
end

local function tween(o, t, p)
    local x = TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad), p)
    x:Play()
    return x
end

local function bind(sig, fn)
    local c = sig:Connect(fn)
    table.insert(S.conns, c)
    return c
end

local function mount(gui)
    if gethui then pcall(function() gui.Parent = gethui() end) end
    if not gui.Parent then pcall(function() gui.Parent = game:GetService("CoreGui") end) end
    if not gui.Parent then
        local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 8)
        if pg then gui.Parent = pg end
    end
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        if getgenv().protect_gui then getgenv().protect_gui(gui) end
    end)
end

--==================== remotes =====================================--
local function remotes()
    local hp = RS:FindFirstChild("HalfPunch")
    if not hp then
        local ok, v = pcall(function() return RS:WaitForChild("HalfPunch", 8) end)
        hp = ok and v or nil
    end
    return hp and hp:FindFirstChild("Remotes") or nil
end

local function getRemote(name)
    local r = remotes()
    return r and r:FindFirstChild(name) or nil
end

local function fire(name, ...)
    local r = getRemote(name)
    if not r then return false end
    local args = { ... }
    local ok = pcall(function() r:FireServer(unpack(args)) end)
    if ok then S.fired = S.fired + 1 end
    return ok
end

--==================== personagens =================================--
local function selfChar()
    local ch = LP.Character
    if ch and ch:FindFirstChild("HumanoidRootPart") then return ch end
end

local function selfHrp()
    local ch = selfChar()
    return ch and ch:FindFirstChild("HumanoidRootPart")
end

local function isChar(m)
    return m
        and typeof(m) == "Instance"
        and m:IsA("Model")
        and m:FindFirstChild("HumanoidRootPart") ~= nil
        and m ~= LP.Character
end

local function allChars()
    local list, seen = {}, {}
    local function add(m)
        if isChar(m) and not seen[m] then
            seen[m] = true
            table.insert(list, m)
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then add(p.Character) end
    end
    if getnilinstances then
        for _, v in ipairs(getnilinstances()) do
            if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then add(v) end
        end
    end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") then add(v) end
    end
    return list
end

local function distTo(m)
    local a, b = selfHrp(), m and m:FindFirstChild("HumanoidRootPart")
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

local function inRadius()
    local r = S.cfg.radius
    local out = {}
    for _, m in ipairs(allChars()) do
        if distTo(m) <= r then table.insert(out, m) end
    end
    return out
end

local function getTarget()
    if S.cfg.targetMode == "manual" and S.cfg.targetName then
        for _, m in ipairs(allChars()) do
            if m.Name == S.cfg.targetName then return m end
        end
    end
    local pool = inRadius()
    if #pool == 0 then return nil end
    if S.cfg.targetMode == "random" then
        return pool[math.random(#pool)]
    end
    table.sort(pool, function(a, b) return distTo(a) < distTo(b) end)
    return pool[1]
end

local function relVec(part)
    local hrp = selfHrp()
    if not hrp or not part then return Vector3.new(0, 0, 0) end
    return (part.Position - hrp.Position) * S.cfg.reach
end

--==================== acoes =======================================--
local function doBodyHit()
    local ch = selfChar()
    local limb = ch and ch:FindFirstChild("LeftLowerLeg")
    if not limb then return end
    fire("BodyHit", limb, 1332.847, Vector3.new(-9.05, 0.5, 39.73), 1.4e-10, 0, 2.09e-32)
end

local function doHit(target)
    target = target or getTarget()
    if not target then return end
    local ch = selfChar()
    local limb = ch and ch:FindFirstChild(S.cfg.side .. S.cfg.part)
    local tpart = target:FindFirstChild(S.cfg.hitPart) or target:FindFirstChild("UpperTorso")
    if not limb or not tpart then return end
    fire("Hit", limb, tpart, relVec(tpart))
end

local function doGrab(target)
    target = target or getTarget()
    if not target then return end
    local ch = selfChar()
    local hand = ch and ch:FindFirstChild(S.cfg.side .. "Hand")
    local torso = target:FindFirstChild("UpperTorso") or target:FindFirstChild("HumanoidRootPart")
    if not hand or not torso then return end
    S.grabbed = target
    fire("Grab", S.cfg.side, hand, torso, relVec(torso), 1)
end

local function doRelease()
    S.grabbed = nil
    fire("Grab", S.cfg.side)
end

local function touchBtn(index)
    local pg = LP:FindFirstChild("PlayerGui")
    local hpt = pg and pg:FindFirstChild("HalfPunchTouch")
    local frame = hpt and hpt:FindFirstChild("Frame")
    if not frame then return end
    local raw = frame:GetChildren()[index]
    if raw then
        pcall(function() firesignal(raw.Activated) end)
        return
    end
    local buttons = {}
    for _, c in ipairs(frame:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("ImageButton") then table.insert(buttons, c) end
    end
    local b = buttons[index]
    if b then pcall(function() firesignal(b.Activated) end) end
end

--==================== loops =======================================--
local function loop(name, fn)
    S.loops[name] = true
    task.spawn(function()
        while S.loops[name] and not S.dead do
            pcall(fn)
            task.wait(S.cfg.interval)
        end
        S.loops[name] = nil
    end)
end

local function stop(name)
    S.loops[name] = nil
end

local function toggle(name, fn)
    if S.loops[name] then
        stop(name)
        log(name .. " OFF")
    else
        loop(name, fn)
        log(name .. " ON")
    end
end

local function stopAll()
    for k in pairs(S.loops) do S.loops[k] = nil end
end

--==================== extras ======================================--
local function toggleGodmode()
    S.godmode = not S.godmode
    local ch = selfChar()
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hrp then hrp.Anchored = S.godmode end
    if hum then
        if S.godmode then
            hum.MaxHealth = math.huge
            hum.Health = math.huge
        else
            hum.MaxHealth = 100
            hum.Health = 100
        end
    end
    log("Godmode " .. (S.godmode and "ON" or "OFF"))
end

local function installAntiFling()
    bind(LP.CharacterAdded, function()
        if S.godmode then
            local ch = LP.Character
            task.wait(0.5)
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = true end
        end
    end)
    bind(RunService.Heartbeat, function()
        if S.dead then return end
        local hrp = selfHrp()
        if not hrp then return end
        if hrp.AssemblyLinearVelocity.Magnitude > CONFIG.AntiFlingCap then
            pcall(function()
                hrp.AssemblyLinearVelocity =
                    hrp.AssemblyLinearVelocity.Unit * CONFIG.AntiFlingCap
            end)
        end
    end)
end

local function teleportToTarget()
    local t = getTarget()
    local hrp, th = selfHrp(), t and t:FindFirstChild("HumanoidRootPart")
    if hrp and th then
        hrp.CFrame = th.CFrame * CFrame.new(0, 0, 3)
        log("TP -> " .. t.Name)
    end
end

--==================== HUD =========================================--
local function buildHUD()
    local gui = new("ScreenGui", {
        Name = rnd(9), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998,
    })
    mount(gui)
    S.hud = gui
    local box = new("Frame", {
        Size = UDim2.new(0, 168, 0, 20), Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Color3.fromRGB(14, 14, 17),
        BackgroundTransparency = 0.3, BorderSizePixel = 0,
    }, gui)
    corner(box, 5)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -8, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = Color3.fromRGB(170, 215, 180), Text = "hp -- | fired --",
    }, box)

    local frames, acc, t0 = 0, 0, os.clock()
    bind(RunService.RenderStepped, function()
        frames = frames + 1
        local now = os.clock()
        if now - t0 >= 0.5 then
            acc = math.floor(frames / (now - t0))
            frames, t0 = 0, now
            lbl.Text = ("fps %d | fired %d"):format(acc, S.fired)
        end
    end)
end

--==================== primitivas de UI ============================--
local function mkBtn(parent, text, cb)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), LayoutOrder = #parent:GetChildren(),
        BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = Color3.fromRGB(215, 215, 228), Text = text,
        AutoButtonColor = false,
    }, parent)
    corner(b, 6)
    b.MouseEnter:Connect(function() tween(b, 0.15, {BackgroundColor3 = Color3.fromRGB(45, 45, 58)}) end)
    b.MouseLeave:Connect(function() tween(b, 0.15, {BackgroundColor3 = Color3.fromRGB(30, 30, 38)}) end)
    b.MouseButton1Click:Connect(function() pcall(cb) end)
    return b
end

local function mkInput(parent, label, default, apply)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        LayoutOrder = #parent:GetChildren(),
    }, parent)
    new("TextLabel", {
        Size = UDim2.new(0.52, 0, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(180, 185, 200),
        TextXAlignment = Enum.TextXAlignment.Left, Text = label,
    }, row)
    local tb = new("TextBox", {
        Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0,
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = Color3.fromRGB(230, 230, 240),
        Text = tostring(default), ClearTextOnFocus = false,
    }, row)
    corner(tb, 5)
    local ab = new("TextButton", {
        Size = UDim2.new(0.18, -4, 1, 0), Position = UDim2.new(0.82, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(55, 45, 110), BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium, TextSize = 11,
        TextColor3 = Color3.fromRGB(225, 225, 240), Text = "set",
        AutoButtonColor = false,
    }, row)
    corner(ab, 5)
    ab.MouseButton1Click:Connect(function()
        pcall(function() apply(tonumber(tb.Text) or tb.Text) end)
    end)
end

--==================== painel ======================================--
local function buildUI()
    local gui = new("ScreenGui", {
        Name = rnd(11), ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    mount(gui)
    S.ui = gui

    local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
        or Vector2.new(1280, 720)
    local scale = clamp(math.min((vp.X - 20) / 430, (vp.Y - 40) / 380), 0.5, 1)

    local panel = new("Frame", {
        Size = UDim2.new(0, 430, 0, 380),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(16, 16, 20), BorderSizePixel = 0,
    }, gui)
    corner(panel, 12)
    new("UIStroke", {Color = Color3.fromRGB(42, 42, 52), Thickness = 1}, panel)
    new("UIScale", {Scale = scale}, panel)

    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.fromRGB(255, 90, 70), BorderSizePixel = 0,
    }, panel)
    new("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(255, 90, 70), Color3.fromRGB(255, 200, 60)),
    }, top)

    new("TextLabel", {
        Size = UDim2.new(1, -110, 0, 24), Position = UDim2.new(0, 16, 0, 12),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = Color3.fromRGB(240, 240, 245),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "HalfPunch  v" .. VERSION,
    }, panel)

    S.status = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 14), Position = UDim2.new(0, 16, 0, 38),
        BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = Color3.fromRGB(150, 155, 170),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "sem key · remotes em standby",
    }, panel)

    local bg = new("Frame", {
        Size = UDim2.new(1, -32, 0, 3), Position = UDim2.new(0, 16, 0, 58),
        BackgroundColor3 = Color3.fromRGB(32, 32, 40), BorderSizePixel = 0,
    }, panel)
    corner(bg, 2)
    S.bar = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 90, 70),
        BorderSizePixel = 0,
    }, bg)
    corner(S.bar, 2)

    local tabBar = new("Frame", {
        Size = UDim2.new(1, -32, 0, 26), Position = UDim2.new(0, 16, 0, 72),
        BackgroundTransparency = 1,
    }, panel)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
    }, tabBar)

    local content = new("Frame", {
        Size = UDim2.new(1, -32, 1, -170), Position = UDim2.new(0, 16, 0, 104),
        BackgroundColor3 = Color3.fromRGB(11, 11, 14), BorderSizePixel = 0,
    }, panel)
    corner(content, 8)

    local pages = S.pages
    local function page(name, order)
        local b = new("TextButton", {
            Size = UDim2.new(0, 68, 1, 0), LayoutOrder = order,
            BackgroundColor3 = Color3.fromRGB(28, 28, 36), BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, TextSize = 11,
            TextColor3 = Color3.fromRGB(190, 190, 205), Text = name,
            AutoButtonColor = false,
        }, tabBar)
        corner(b, 5)
        local f = new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
        }, content)
        new("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder}, f)
        new("UIPadding", {
            PaddingTop = UDim.new(0, 7), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7),
        }, f)
        pages[name] = f
        b.MouseButton1Click:Connect(function()
            for k, p in pairs(pages) do p.Visible = (k == name) end
            for _, c in ipairs(tabBar:GetChildren()) do
                if c:IsA("TextButton") then
                    tween(c, 0.15, {
                        BackgroundColor3 = c.Text == name
                            and Color3.fromRGB(120, 60, 50)
                            or Color3.fromRGB(28, 28, 36),
                    })
                end
            end
        end)
        return f
end-- Combate
    local cb = page("Combate", 1)
    mkBtn(cb, "Hit (alvo)", function() doHit() end)
    mkBtn(cb, "Body Hit", function() doBodyHit() end)
    mkBtn(cb, "Grab", function() doGrab() end)
    mkBtn(cb, "Soltar grab", doRelease)
    mkBtn(cb, "Auto Hit: alternar", function() toggle("AutoHit", function() doHit() end) end)
    mkBtn(cb, "Hit Aura: alternar", function()
        toggle("Aura", function()
            for _, m in ipairs(inRadius()) do doHit(m) end
        end)
    end)
    mkBtn(cb, "Grab Infinito: alternar", function()
        toggle("InfGrab", function()
            local t = S.grabbed and (S.grabbed.Parent and S.grabbed or nil) or getTarget()
            if t then doGrab(t) else doRelease() end
        end)
    end)
    mkBtn(cb, "Auto Grab (proximidade): alternar", function()
        toggle("AutoGrab", function()
            local t = getTarget()
            if not t then
                if S.grabbed then doRelease() end
                return
            end
            if distTo(t) <= S.cfg.radius then doGrab(t) else doRelease() end
        end)
    end)
    mkBtn(cb, "No Cooldown (touch 1): alternar", function()
        toggle("NC1", function() touchBtn(1) end)
    end)
    mkBtn(cb, "Touch 6 spam: alternar", function()
        toggle("NC6", function() touchBtn(6) end)
    end)
    mkBtn(cb, "PARAR TUDO", function() stopAll(); doRelease(); log("loops parados") end)

    -- Alvo
    local al = page("Alvo", 2)
    mkBtn(al, "Modo: proximo / aleatorio / manual", function()
        S.cfg.targetMode = S.cfg.targetMode == "nearest" and "random"
            or S.cfg.targetMode == "random" and "manual"
            or "nearest"
        log("Alvo = " .. S.cfg.targetMode)
    end)
    mkInput(al, "Nome do alvo", "-", function(v)
        S.cfg.targetName = tostring(v)
        S.cfg.targetMode = "manual"
        log("Alvo manual: " .. tostring(v))
    end)
    mkBtn(al, "Teleportar até o alvo", teleportToTarget)
    mkInput(al, "Raio", CONFIG.Radius, function(v)
        if type(v) == "number" then S.cfg.radius = v; log("Raio = " .. v) end
    end)
    mkInput(al, "Alcance (multiplicador)", CONFIG.Reach, function(v)
        if type(v) == "number" then S.cfg.reach = v; log("Reach = " .. v) end
    end)
    mkInput(al, "Intervalo (ms)", math.floor(CONFIG.Interval * 1000), function(v)
        if type(v) == "number" then
            S.cfg.interval = math.max(v, 10) / 1000
            log("Intervalo = " .. v .. "ms")
        end
    end)
    mkBtn(al, "Membro: mao / pe", function()
        S.cfg.part = S.cfg.part == "Hand" and "Foot" or "Hand"
        log("Membro = " .. S.cfg.side .. S.cfg.part)
    end)
    mkBtn(al, "Lado: direito / esquerdo", function()
        S.cfg.side = S.cfg.side == "Right" and "Left" or "Right"
        log("Lado = " .. S.cfg.side)
    end)
    mkBtn(al, "Parte atingida: torso / cabeca / pernas", function()
        local order = { "UpperTorso", "Head", "LeftUpperLeg", "RightUpperLeg" }
        local i = 1
        for idx, v in ipairs(order) do if v == S.cfg.hitPart then i = idx end end
        S.cfg.hitPart = order[(i % #order) + 1]
        log("Parte = " .. S.cfg.hitPart)
    end)-- Extra
    local ex = page("Extra", 3)
    mkBtn(ex, "Godmode (anchor): alternar", toggleGodmode)
    mkBtn(ex, "Fullbright: alternar", function()
        Lighting.Brightness = Lighting.Brightness > 2 and 2 or 3
        Lighting.FogEnd = Lighting.Brightness > 2 and 1e5 or 400
        log("Brightness = " .. Lighting.Brightness)
    end)
    mkBtn(ex, "HUD: alternar", function()
        if S.hud then S.hud:Destroy(); S.hud = nil; log("HUD OFF")
        else buildHUD(); log("HUD ON") end
    end)
    mkBtn(ex, "Listar alvos no raio", function()
        local l = inRadius()
        log(("alvos: %d"):format(#l))
        for _, m in ipairs(l) do log(" - " .. m.Name) end
    end)
    mkBtn(ex, "Recarregar painel", function()
        local src = game:HttpGet(
            "https://raw.githubusercontent.com/ghousting1234-sketch/.khh/refs/heads/main/HalfPunch.lua")
        panic(true)
        task.wait(0.4)
        if src then loadstring(src)() end
    end)

    -- Debug
    local db = page("Debug", 4)
    mkBtn(db, "Estado dos remotes", function()
        local r = remotes()
        if not r then return log("Remotes NAO encontrados") end
        for _, n in ipairs({ "BodyHit", "Hit", "Grab" }) do
            log(n .. ": " .. (r:FindFirstChild(n) and "ok" or "ausente"))
        end
    end)
    mkBtn(db, "Testar touch 1", function() touchBtn(1); log("touch 1 disparado") end)
    mkBtn(db, "Testar touch 6", function() touchBtn(6); log("touch 6 disparado") end)
    mkBtn(db, "Contagem de disparos", function() log("fired = " .. S.fired) end)
    mkBtn(db, "PANIC", function() panic() end)

    if true then
        local sc = new("ScrollingFrame", {
            Size = UDim2.new(1, -32, 0, 48), Position = UDim2.new(0, 16, 1, -56),
            BackgroundColor3 = Color3.fromRGB(10, 10, 13), BorderSizePixel = 0,
            ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0),
        }, panel)
        corner(sc, 6)
        S.logBox = new("Frame", { Size = UDim2.new(1, -6, 1, 0), BackgroundTransparency = 1 }, sc)
        new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, S.logBox)
    end

    local min = new("TextButton", {
        Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -34, 0, 10),
        BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 13,
        TextColor3 = Color3.fromRGB(205, 205, 215), Text = "-", AutoButtonColor = false,
    }, panel)
    corner(min, 5)

    local minimized = false
    min.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tween(panel, 0.2, {
                Size = UDim2.new(0, 150, 0, 34), Position = UDim2.new(0, 16, 0, 16),
                AnchorPoint = Vector2.zero,
            })
            for _, c in ipairs(panel:GetDescendants()) do
                if (c:IsA("Frame") or c:IsA("ScrollingFrame") or c:IsA("TextLabel")
                    or c:IsA("TextButton")) and c ~= panel then
                    c.Visible = false
                end
            end
            min.Text, min.Visible = "+", true
        else
            tween(panel, 0.2, {
                Size = UDim2.new(0, 430, 0, 380), Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
            })
            for _, c in ipairs(panel:GetDescendants()) do
                if c:IsA("Frame") or c:IsA("ScrollingFrame") or c:IsA("TextLabel")
                    or c:IsA("TextButton") then
                    c.Visible = true
                end
            end
            min.Text = "-"
            for k, p in pairs(pages) do p.Visible = (k == "Combate") end
        end
    end)

    local dragging, ds, sp
    panel.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging, ds, sp = true, i.Position, panel.Position
        end
    end)
    panel.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    bind(UserInput.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - ds
            panel.Position = UDim2.new(
                sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
        end
    end)

    pages.Combate.Visible = true
    return gui
end--==================== panic =======================================--
function panic(silent)
    if S.dead then return end
    S.dead = true
    stopAll()
    pcall(doRelease)
    local hrp = selfHrp()
    if hrp and S.godmode then hrp.Anchored = false end
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    S.conns = {}
    if S.hud then pcall(function() S.hud:Destroy() end) end
    if S.ui then pcall(function() S.ui:Destroy() end) end
    genv().__hp_panel = nil
    if not silent then log("descarregado") end
end
genv().HalfPunchPanic = panic

--==================== start =======================================--
local ok, err = pcall(buildUI)
if not ok then
    warn("[HP] UI: " .. tostring(err))
end
pcall(installAntiFling)
if CONFIG.ShowHUD then pcall(buildHUD) end
log("pronto · remotes: " .. (remotes() and "ok" or "nao achados"))
if S.bar then tween(S.bar, 0.4, {Size = UDim2.new(1, 0, 1, 0)}) end
