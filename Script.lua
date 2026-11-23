--!nocheck
--[[==================================================================
    VolleyBomb :: Loading.lua  (v3 - Hardened)
    --------------------------------------------------------------
    Camadas:
      L1  Stealth   -> GUI em gethui(), nome aleatorio, sem PlayerGui
      L2  Anti-Kick -> hook de __namecall/__index em LocalPlayer:Kick
      L3  Anti-Ban  -> snapshot/restore, rate limit de remotes, safe mode
      L4  Anti-AC   -> anti-fling, anti-teleport-back, watchdog de Humanoid
      L5  Utilidade -> player/visual/sessao/debug + Panic (kill switch)
    Key system: removido (bypass em 3 camadas)
==================================================================]]--

local VERSION = "3.0.0"

local CONFIG = {
    -- rede
    RetryCount = 3, RetryDelay = 0.6, Timeout = 20,
    UseCache = true, CacheDir = "VolleyBomb/cache/",
    -- recursos
    DisableKeySystem = true, UnlockFPS = true, AntiAFK = true,
    AntiFling = true, AntiKick = true, AutoRejoin = true,
    SafeMode = true, ShowHUD = true, ShowLog = true,
    CloseDelay = 1.4,
    -- limites
    RemoteBudgetPerSec = 45,
    FlingVelocityCap = 900,
    TPThreshold = 30,
    -- links
    Discord = "https://discord.gg/volleybomb",
    REPO = "https://raw.githubusercontent.com/Biskus0/VolleyBomb/refs/heads/main/",
    UIC  = "https://raw.githubusercontent.com/Biskus0/UIConstructor/refs/heads/main/",
}

--==================== utilidades basicas =========================--
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local Teleport     = game:GetService("TeleportService")
local HttpService  = game:GetService("HttpService")
local VirtualUser  = game:GetService("VirtualUser")
local Lighting     = game:GetService("Lighting")
local Workspace    = game:GetService("Workspace")

local LP = Players.LocalPlayer
local IS_MOBILE = UserInput.TouchEnabled and not UserInput.KeyboardEnabled
local PLATFORM = IS_MOBILE and "Mobile" or "PC"

local genv = getgenv or function() return _G end

local function rnd(n)
    local s = {}
    for i = 1, n do s[i] = string.char(math.random(97, 122)) end
    return table.concat(s)
end

-- estado escondido sob chave aleatoria (nao fica em _G.VolleyBomb)
local STATE_KEY = "__vb_" .. rnd(10)
local S = {
    dead = false, conns = {}, hooks = {},
    remotes = 0, remoteWindow = os.clock(),
    lastKick = nil, reverted = 0, snaps = {},
    antiKickMode = "soft", -- soft | hard | off
    ui = nil, hud = nil, logBox = nil, status = nil, bar = nil,
}
genv()[STATE_KEY] = S

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
            l.Text = ("%s  %s"):format(os.date("%H:%M:%S"), msg)
            l.Parent = S.logBox
            S.logBox.CanvasSize = UDim2.new(0, 0, 0, #S.logBox:GetChildren() * 15)
            local sc = S.logBox.Parent
            if sc then task.defer(function() pcall(function() sc.CanvasPosition = Vector2.new(0, 1e5) end) end) end
        end)
    end
    print("[VolleyBomb]", msg)
end

local function progress(a)
    if S.bar then
        TweenService:Create(S.bar, TweenInfo.new(0.25), {Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0)}):Play()
    end
end

local function bind(signal, fn)
    local c = signal:Connect(fn)
    table.insert(S.conns, c)
    return c
end

local function new(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if parent then i.Parent = parent end
    return i
end

local function corner(p, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, p) end

local function tween(obj, time, props)
    local t = TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quad), props)
    t:Play()
    return t
end--==================== stealth de montagem ========================--
local function mount(gui)
    -- gethui() tira a GUI da PlayerGui: enumeracao de PlayerGui nao acha
    if gethui then
        pcall(function() gui.Parent = gethui() end)
    end
    if not gui.Parent then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
    -- protect_gui (Synapse/Fluxus/Aquarium) esconde de getinstances/debug.getregistry
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui) end
        if getgenv().protect_gui then getgenv().protect_gui(gui) end
        if fluxus and fluxus.protect_gui then fluxus.protect_gui(gui) end
    end)
end

--==================== rede =======================================--
local function cachePath(url)
    return CONFIG.CacheDir .. (url:gsub("[^%w]", "_"):sub(-120)) .. ".lua"
end

local function httpGet(url)
    local lastErr
    for a = 1, CONFIG.RetryCount do
        local ok, body = pcall(function()
            if CONFIG.UseCache and isfile and readfile and isfile(cachePath(url)) then
                local c = readfile(cachePath(url))
                if #c > 64 then return c end
            end
            local r
            if syn and syn.request then
                r = syn.request({Url = url, Method = "GET", Timeout = CONFIG.Timeout}).Body
            elseif http_request then
                r = http_request({Url = url, Method = "GET"}).Body
            elseif request then
                r = request({Url = url, Method = "GET"}).Body
            else
                r = game:HttpGet(url, true)
            end
            if CONFIG.UseCache and writefile then
                if makefolder and not isfolder(CONFIG.CacheDir) then pcall(makefolder, CONFIG.CacheDir) end
                pcall(writefile, cachePath(url), r)
            end
            return r
        end)
        if ok and type(body) == "string" and #body > 0 then return body end
        lastErr = body
        log(("Retry %d/%d -> %s"):format(a, CONFIG.RetryCount, url:match("[^/]+$")))
        task.wait(CONFIG.RetryDelay * a)
    end
    return nil, lastErr
end

--==================== rate limiter de remotes ====================--
local function installRateLimiter()
    if not hookmetamethod or not getnamecallmethod then return end
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local oldName = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            if checkcaller and checkcaller() then return oldName(self, ...) end
            local m = getnamecallmethod()
            if m == "FireServer" or m == "InvokeServer" then
                local now = os.clock()
                if now - S.remoteWindow >= 1 then
                    S.remoteWindow, S.remotes = now, 0
                end
                S.remotes = S.remotes + 1
                if S.remotes > CONFIG.RemoteBudgetPerSec then
                    S.reverted = S.reverted + 1
                    task.wait(0.035)
                end
            end
            return oldName(self, ...)
        end)
        setreadonly(mt, true)
        S.hooks.namecall = oldName
    end)
    if ok then log("Rate limiter de remotes ativo") end
end--==================== anti-kick ==================================--
local function installAntiKick()
    if not CONFIG.AntiKick or not getrawmetatable then return end
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local oldIdx = mt.__index
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, k)
            local v = oldIdx(self, k)
            if self == LP and k == "Kick" and type(v) == "function" and not S.hooks.kickWrapped then
                S.hooks.kickWrapped = true
                return newcclosure(function(_, reason)
                    S.lastKick = tostring(reason)
                    log("KICK: " .. tostring(reason))
                    if S.antiKickMode == "hard" then
                        if CONFIG.AutoRejoin then
                            task.delay(0.4, function()
                                pcall(Teleport.TeleportToPlaceInstance, Teleport, game.PlaceId, game.JobId, LP)
                            end)
                        end
                        return
                    end
                    if CONFIG.AutoRejoin then
                        task.delay(0.8, function()
                            pcall(Teleport.TeleportToPlaceInstance, Teleport, game.PlaceId, game.JobId, LP)
                        end)
                    end
                    return v(LP, reason)
                end)
            end
            return v
        end)
        setreadonly(mt, true)
    end)
    if ok then log("Anti-Kick armado (soft)") end
end

--==================== snapshot / restore =========================--
local function snapshot()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    S.snaps = {
        walk = hum and hum.WalkSpeed,
        jump = hum and hum.JumpPower,
        hip  = hum and hum.HipHeight,
        fov  = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView,
        grav = Workspace.Gravity,
        fog  = Lighting.FogEnd,
        bright = Lighting.Brightness,
    }
end

local function restore()
    local ch = LP.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    pcall(function()
        if hum then
            if S.snaps.walk then hum.WalkSpeed = S.snaps.walk end
            if S.snaps.jump then hum.JumpPower = S.snaps.jump end
            if S.snaps.hip then hum.HipHeight = S.snaps.hip end
        end
        if Workspace.CurrentCamera and S.snaps.fov then Workspace.CurrentCamera.FieldOfView = S.snaps.fov end
        if S.snaps.grav then Workspace.Gravity = S.snaps.grav end
        if S.snaps.fog then Lighting.FogEnd = S.snaps.fog end
        if S.snaps.bright then Lighting.Brightness = S.snaps.bright end
        Lighting.FogStart = S.snaps.fog and (S.snaps.fog * 0.8) or 0
    end)
end

--==================== anti-fling / anti-tp =======================--
local function installCharacterWatch()
    local function hookChar(ch)
        local hrp = ch:WaitForChild("HumanoidRootPart", 6)
        local hum = ch:WaitForChildOfClass and ch:WaitForChildOfClass("Humanoid") or ch:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        local lastPos = hrp.Position
        local lastT = os.clock()

        local loop = RunService.Heartbeat:Connect(function()
            if S.dead then return end
            local p = hrp.Position
            local now = os.clock()
            local dt = now - lastT

            -- anti-fling
            if CONFIG.AntiFling and hrp.AssemblyLinearVelocity.Magnitude > CONFIG.FlingVelocityCap then
                pcall(function()
                    hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity.Unit * CONFIG.FlingVelocityCap
                    S.reverted = S.reverted + 1
                end)
            end

            -- anti-teleport-back (snap do servidor)
            if CONFIG.AntiTP and dt > 0.1 then
                local moved = (p - lastPos).Magnitude
                if moved > CONFIG.TPThreshold and hrp.AssemblyLinearVelocity.Magnitude < 5 then
                    S.reverted = S.reverted + 1
                end
            end

            lastPos, lastT = p, now
        end)
        table.insert(S.conns, loop)

        bind(hum.Died, function()
            pcall(function() loop:Disconnect() end)
        end)
    end

    if LP.Character then hookChar(LP.Character) end
    bind(LP.CharacterAdded, hookChar)
end

--==================== anti-afk ===================================--
local function installAntiAFK()
    if not CONFIG.AntiAFK then return end
    bind(LP.Idled, function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end--==================== bypass de key ==============================--
local function installKeyBypass()
    if not CONFIG.DisableKeySystem then return end
    genv().Key, _G.Key = true, true
    _G.KeyValid, _G.KeyVerified, _G.HasKey = true, true, true

    local PAT = {key = true, login = true, auth = true, verif = true, whitelist = true}
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return end

    local function isKey(g)
        if not g:IsA("ScreenGui") then return false end
        local n = g.Name:lower():gsub("[^%w]", "")
        for k in pairs(PAT) do if n:find(k, 1, true) then return true end end
        return g:FindFirstChildWhichIsA("TextBox", true) ~= nil
            and g:FindFirstChildWhichIsA("TextButton", true) ~= nil
    end

    local function kill(g)
        if not isKey(g) then return end
        log("Key GUI neutralizada: " .. g.Name)
        pcall(function()
            local box = g:FindFirstChildWhichIsA("TextBox", true)
            if box then box.Text = "BYPASS" end
            for _, b in ipairs(g:GetDescendants()) do
                if b:IsA("TextButton") then
                    local t = b.Text:lower()
                    if t:find("key") or t:find("entr") or t:find("continu") or t:find("verif") then
                        b:Activate()
                        break
                    end
                end
            end
        end)
        task.delay(1.2, function() pcall(function() g:Destroy() end) end)
    end

    for _, g in ipairs(pg:GetChildren()) do kill(g) end
    local c = pg.ChildAdded:Connect(kill)
    task.delay(20, function() pcall(function() c:Disconnect() end) end)
end

--==================== HUD ========================================--
local function buildHUD()
    local gui = new("ScreenGui", {
        Name = rnd(9), ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 998,
    })
    mount(gui)
    S.hud = gui

    local box = new("Frame", {
        Size = UDim2.new(0, 176, 0, 20),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Color3.fromRGB(14, 14, 17),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, gui)
    corner(box, 5)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -8, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = Color3.fromRGB(170, 215, 180),
        Text = "fps -- | ping -- | net --",
    }, box)

    local frames, acc, t0, ping = 0, 0, os.clock(), 0
    local Stats = game:GetService("Stats")
    task.spawn(function()
        while S.hud and S.hud.Parent do
            pcall(function()
                ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            task.wait(1)
        end
    end)

    bind(RunService.RenderStepped, function()
        frames = frames + 1
        local now = os.clock()
        if now - t0 >= 0.5 then
            acc = math.floor(frames / (now - t0))
            frames, t0 = 0, now
            lbl.Text = ("fps %d | ping %d | net %d"):format(acc, ping, S.remotes)
            lbl.TextColor3 = acc < 30 and Color3.fromRGB(255, 130, 130) or Color3.fromRGB(170, 215, 180)
        end
    end)
end--==================== UI =========================================--
local function buildUI()
    local gui = new("ScreenGui", {
        Name = rnd(11), ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    mount(gui)
    S.ui = gui

    local panel = new("Frame", {
        Size = UDim2.new(0, 460, 0, 400),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(16, 16, 20),
        BorderSizePixel = 0,
    }, gui)
    corner(panel, 12)
    new("UIStroke", {Color = Color3.fromRGB(42, 42, 52), Thickness = 1}, panel)

    local top = new("Frame", {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.fromRGB(120, 90, 255),
        BorderSizePixel = 0,
    }, panel)
    new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(120, 90, 255), Color3.fromRGB(60, 200, 255))}, top)

    new("TextLabel", {
        Size = UDim2.new(1, -120, 0, 24),
        Position = UDim2.new(0, 16, 0, 12),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold, TextSize = 16,
        TextColor3 = Color3.fromRGB(240, 240, 245),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = ("VolleyBomb  v%s"):format(VERSION),
    }, panel)

    new("TextLabel", {
        Size = UDim2.new(1, -120, 0, 14),
        Position = UDim2.new(0, 16, 0, 36),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 11,
        TextColor3 = Color3.fromRGB(115, 120, 135),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = ("%s  ·  stealth on  ·  key off"):format(PLATFORM),
    }, panel)

    -- barra de progresso
    local bg = new("Frame", {
        Size = UDim2.new(1, -32, 0, 4),
        Position = UDim2.new(0, 16, 0, 56),
        BackgroundColor3 = Color3.fromRGB(32, 32, 40),
        BorderSizePixel = 0,
    }, panel)
    corner(bg, 2)
    S.bar = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(120, 90, 255), BorderSizePixel = 0}, bg)
    corner(S.bar, 2)

    S.status = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 14),
        Position = UDim2.new(0, 16, 0, 64),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code, TextSize = 11,
        TextColor3 = Color3.fromRGB(155, 160, 175),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Iniciando...",
    }, panel)

    -- abas
    local tabBar = new("Frame", {
        Size = UDim2.new(1, -32, 0, 26),
        Position = UDim2.new(0, 16, 0, 84),
        BackgroundTransparency = 1,
    }, panel)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5)}, tabBar)

    local content = new("Frame", {
        Size = UDim2.new(1, -32, 1, -186),
        Position = UDim2.new(0, 16, 0, 116),
        BackgroundColor3 = Color3.fromRGB(11, 11, 14),
        BorderSizePixel = 0,
    }, panel)
    corner(content, 8)

    local pages = {}
    local function page(name, order)
        local b = new("TextButton", {
            Size = UDim2.new(0, 66, 1, 0), LayoutOrder = order,
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
        new("UIPadding", {PaddingTop = UDim.new(0, 7), PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7)}, f)
        pages[name] = f

        b.MouseButton1Click:Connect(function()
            for k, p in pairs(pages) do p.Visible = (k == name) end
            for _, c in ipairs(tabBar:GetChildren()) do
                if c:IsA("TextButton") then
                    tween(c, 0.15, {BackgroundColor3 = c.Text == name and Color3.fromRGB(70, 55, 140) or Color3.fromRGB(28, 28, 36)})
                end
            end
        end)
        return f
end

local function btn(parent, text, cb, w)
        local b = new("TextButton", {
            Size = UDim2.new(w or 1, 0, 0, 26), LayoutOrder = #parent:GetChildren(),
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

    local function input(parent, label, default, apply)
        local row = new("Frame", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = #parent:GetChildren()}, parent)
        new("TextLabel", {
            Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = Color3.fromRGB(180, 185, 200),
            TextXAlignment = Enum.TextXAlignment.Left, Text = label,
        }, row)
        local tb = new("TextBox", {
            Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.new(0.55, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(22, 22, 28), BorderSizePixel = 0,
            Font = Enum.Font.Code, TextSize = 11, TextColor3 = Color3.fromRGB(230, 230, 240),
            Text = tostring(default), ClearTextOnFocus = false,
        }, row)
        corner(tb, 5)
        local ab = new("TextButton", {
            Size = UDim2.new(0.15, -4, 1, 0), Position = UDim2.new(0.85, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(55, 45, 110), BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = Color3.fromRGB(225, 225, 240),
            Text = "set", AutoButtonColor = false,
        }, row)
        corner(ab, 5)
        ab.MouseButton1Click:Connect(function() pcall(function() apply(tonumber(tb.Text) or tb.Text) end) end)
    end

    -- ===== Home =====
    local home = page("Home", 1)
    btn(home, "Rejoin", function()
        pcall(Teleport.TeleportToPlaceInstance, Teleport, game.PlaceId, game.JobId, LP)
    end)
    btn(home, "Server Hop", function()
        task.spawn(function()
            local ok, res = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(
                    ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)))
            end)
            if not ok or not res or not res.data then return log("Hop: sem resposta") end
            local pool = {}
            for _, s in ipairs(res.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(pool, s.id) end
            end
            if #pool == 0 then return log("Hop: nenhum livre") end
            log(("Hop: %d candidatos"):format(#pool))
            pcall(Teleport.TeleportToPlaceInstance, Teleport, game.PlaceId, pool[math.random(#pool)], LP)
        end)
    end)
    btn(home, "Copiar Discord", function()
        if setclipboard then setclipboard(CONFIG.Discord) end
        log("Discord copiado")
    end)
    btn(home, "Recarregar script", function()
        local src = httpGet(CONFIG.REPO .. "Loading.lua")
        panic(true)
        task.wait(0.4)
        if src then loadstring(src)() end
    end)
    btn(home, "Limpar cache", function()
        if not (isfolder and listfiles and delfile) then return log("Sem file I/O") end
        for _, f in ipairs(listfiles(CONFIG.CacheDir) or {}) do pcall(delfile, f) end
        log("Cache limpo")
    end)
    btn(home, "PANIC — desfazer tudo", function() panic() end)

    -- ===== Player =====
    local pl = page("Player", 2)
    input(pl, "WalkSpeed", 16, function(v)
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h and type(v) == "number" then h.WalkSpeed = v; log("WS = " .. v) end
    end)
    input(pl, "JumpPower", 50, function(v)
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h and type(v) == "number" then
            h.UseJumpPower = true
            h.JumpPower = v
            log("JP = " .. v)
        end
    end)
    input(pl, "HipHeight", 2, function(v)
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h and type(v) == "number" then h.HipHeight = v; log("Hip = " .. v) end
    end)
    btn(pl, "Resetar personagem", function()
        local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if h then h.Health = 0 end
    end)
    btn(pl, "Ir para o spawn", function()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local sp = Workspace:FindFirstChildOfClass("SpawnLocation")
            if sp then hrp.CFrame = sp.CFrame + Vector3.new(0, 4, 0) end
        end
    end)
    btn(pl, "Anti-fling: alternar", function()
        CONFIG.AntiFling = not CONFIG.AntiFling
        log("Anti-fling " .. (CONFIG.AntiFling and "ON" or "OFF"))
    end)-- ===== Visual =====
    local vis = page("Visual", 3)
    input(vis, "Field of View", 70, function(v)
        if Workspace.CurrentCamera and type(v) == "number" then
            Workspace.CurrentCamera.FieldOfView = v
            log("FOV = " .. v)
        end
    end)
    btn(vis, "Fullbright: alternar", function()
        if Lighting.Brightness > 2 then
            restore()
            log("Fullbright OFF")
        else
            Lighting.Brightness = 3
            Lighting.FogEnd = 1e5
            log("Fullbright ON")
        end
    end)
    btn(vis, "Sem fog: alternar", function()
        Lighting.FogEnd = Lighting.FogEnd > 5000 and 400 or 1e5
        log("FogEnd = " .. math.floor(Lighting.FogEnd))
    end)
    btn(vis, "HUD FPS/Ping: alternar", function()
        if S.hud then S.hud:Destroy(); S.hud = nil; log("HUD OFF")
        else buildHUD(); log("HUD ON") end
    end)
    btn(vis, "Desbloquear FPS", function()
        if setfpscap then setfpscap(240); log("fpscap = 240")
        else log("Executor sem setfpscap") end
    end)

    -- ===== Proteção =====
    local pr = page("Proteção", 4)
    btn(pr, "Anti-Kick: soft / hard / off", function()
        local m = S.antiKickMode
        S.antiKickMode = (m == "soft" and "hard") or (m == "hard" and "off") or "soft"
        log("Anti-Kick = " .. S.antiKickMode)
    end)
    btn(pr, "Auto-Rejoin: alternar", function()
        CONFIG.AutoRejoin = not CONFIG.AutoRejoin
        log("Auto-Rejoin " .. (CONFIG.AutoRejoin and "ON" or "OFF"))
    end)
    btn(pr, "Safe Mode (rate limit): alternar", function()
        CONFIG.SafeMode = not CONFIG.SafeMode
        log("Safe Mode " .. (CONFIG.SafeMode and "ON" or "OFF"))
    end)
    btn(pr, "Anti-AFK: alternar", function()
        CONFIG.AntiAFK = not CONFIG.AntiAFK
        log("Anti-AFK " .. (CONFIG.AntiAFK and "ON" or "OFF"))
    end)
    btn(pr, "Snapshot do estado", function() snapshot(); log("Snapshot salvo") end)
    btn(pr, "Restaurar estado", function() restore(); log("Estado restaurado") end)
    new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
        Font = Enum.Font.Gotham, TextSize = 10, TextWrapped = true,
        TextColor3 = Color3.fromRGB(130, 135, 150),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Safe Mode espaca FireServer/InvokeServer para reduzir flag em anti-cheat por volume. Anti-Kick hard bloqueia a chamada local (o servidor ainda pode derrubar).",
        LayoutOrder = 99,
    }, pr)

    -- ===== Sessão =====
    local se = page("Sessão", 5)
    local function info(label, fn)
        local row = new("Frame", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = #se:GetChildren()}, se)
        new("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1,
            Font = Enum.Font.Code, TextSize = 10, TextColor3 = Color3.fromRGB(120, 125, 140),
            TextXAlignment = Enum.TextXAlignment.Left, Text = label,
        }, row)
        local v = new("TextLabel", {
            Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
            BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10,
            TextColor3 = Color3.fromRGB(200, 205, 220),
            TextXAlignment = Enum.TextXAlignment.Left, Text = tostring(fn()),
        }, row)
        task.spawn(function()
            while row.Parent do task.wait(1); pcall(function() v.Text = tostring(fn()) end) end
        end)
    end
    info("usuario", function() return LP.Name end)
    info("userId", function() return LP.UserId end)
    info("placeId", function() return game.PlaceId end)
    info("jobId", function() return (game.JobId ~= "" and game.JobId:sub(1, 13)) or "-" end)
    info("uptime", function() return math.floor(os.clock()) .. "s" end)
    info("revertidos", function() return S.reverted end)
    info("ultimo kick", function() return S.lastKick or "-" end)
    btn(se, "Copiar JobId", function()
        if setclipboard then setclipboard(game.JobId) end
        log("JobId copiado")
    end)

    -- ===== Debug =====
    local db = page("Debug", 6)
    btn(db, "Rodar modulo UI", function()
        local url = CONFIG.UIC .. (IS_MOBILE and "Mobile.lua" or "PC.lua")
        log("Testando UI...")
        local src = httpGet(url)
        if src and loadstring(src) then log("UI ok (" .. #src .. " bytes)") else log("UI falhou") end
    end)
    btn(db, "Verificar atualizacao", function()
        task.spawn(function()
            local src = httpGet(CONFIG.REPO .. "Loading.lua")
            if not src then return log("Sem conexao") end
            local v = src:match('VERSION%s*=%s*"([%d%.]+)"')
            log(v and (v == VERSION and "Atualizado" or ("Nova versao: " .. v)) or "Versao nao detectada")
        end)
    end)
    btn(db, "Dump do ambiente", function()
        local ok, res = pcall(function()
            local t = {}
            for k, v in pairs(genv()) do
                if type(k) == "string" and #t < 40 then table.insert(t, k) end
            end
            return table.concat(t, ", ")
        end)
        log(ok and res or "dump falhou")
    end)
    btn(db, "Destruir HUD", function()
        if S.hud then S.hud:Destroy(); S.hud = nil end
        log("HUD removido")
    end)

    -- ===== log =====
    if CONFIG.ShowLog then
        local sc = new("ScrollingFrame", {
            Size = UDim2.new(1, -32, 0, 52),
            Position = UDim2.new(0, 16, 1, -60),
            BackgroundColor3 = Color3.fromRGB(10, 10, 13),
            BorderSizePixel = 0, ScrollBarThickness = 3,
            CanvasSize = UDim2.new(0, 0, 0, 0),
        }, panel)
        corner(sc, 6)
        S.logBox = new("Frame", {Size = UDim2.new(1, -6, 1, 0), BackgroundTransparency = 1}, sc)
        new("UIListLayout", {Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder}, S.logBox)
    end

    -- ===== minimizar =====
    local min = new("TextButton", {
        Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(1, -34, 0, 10),
        BackgroundColor3 = Color3.fromRGB(30, 30, 38), BorderSizePixel = 0,
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(205, 205, 215),
        Text = "-", AutoButtonColor = false,
    }, panel)
    corner(min, 5)

    local minimized = false
    min.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            tween(panel, 0.2, {Size = UDim2.new(0, 150, 0, 34), Position = UDim2.new(0, 16, 0, 16), AnchorPoint = Vector2.zero})
            for _, c in ipairs(panel:GetDescendants()) do
                if c:IsA("Frame") or c:IsA("ScrollingFrame") or c:IsA("TextLabel") or c:IsA("TextButton") then
                    if c ~= panel then c.Visible = false end
                end
            end
            min.Text, min.Visible = "+", true
        else
            tween(panel, 0.2, {Size = UDim2.new(0, 460, 0, 400), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5)})
            for _, c in ipairs(panel:GetDescendants()) do
                if c:IsA("Frame") or c:IsA("ScrollingFrame") or c:IsA("TextLabel") or c:IsA("TextButton") then c.Visible = true end
            end
            min.Text = "-"
            for k, p in pairs(pages) do p.Visible = (k == "Home") end
        end
    end)

    -- drag
    local dragging, dragStart, startPos
    panel.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, panel.Position
        end
    end)
    panel.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    bind(UserInput.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)

    pages.Home.Visible = true
    return gui
end

--==================== panic =====================================--
function panic(silent)
    if S.dead then return end
    S.dead = true
    log("PANIC — desfazendo")
    restore()
    if setfpscap then pcall(setfpscap, 60) end
    for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
    S.conns = {}
    pcall(function()
        if S.hooks.namecall and getrawmetatable then
            local mt = getrawmetatable(game)
            setreadonly(mt, false)
            mt.__namecall = S.hooks.namecall
            setreadonly(mt, true)
        end
    end)
    if S.hud then pcall(function() S.hud:Destroy() end) end
    if S.ui then pcall(function() S.ui:Destroy() end) end
    genv()[STATE_KEY] = nil
    if not silent then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "VolleyBomb", Text = "Descarregado e estado restaurado.", Duration = 4,
            })
        end)
    end
end
_G.VolleyBombPanic = panic

--==================== main =======================================--
local function loadModule(url, label)
    local src = httpGet(url)
    if not src then log("FALHA: " .. label); return nil end
    local chunk = loadstring(src, "=" .. label)
    if not chunk then log("Sintaxe invalida: " .. label); return nil end
    local ok, res = pcall(chunk)
    if not ok then log("Erro em " .. label .. ": " .. tostring(res)); return nil end
    log("OK: " .. label)
    return res
end

local function run()
    if CONFIG.UnlockFPS and setfpscap then pcall(setfpscap, 240) end
    buildUI()
    progress(0.05)

    task.spawn(function()
        snapshot()
        installAntiAFK()
        installCharacterWatch()
        installAntiKick()
        if CONFIG.SafeMode then installRateLimiter() end
        log("Camadas ativas | " .. PLATFORM)
        progress(0.18)

        local uiUrl  = CONFIG.UIC  .. (IS_MOBILE and "Mobile.lua" or "PC.lua")
        local scrUrl = CONFIG.REPO .. (IS_MOBILE and "Mobile%20Script.lua" or "PC%20Script.lua")

        progress(0.3)
        local okUI = loadModule(uiUrl, "UI/" .. PLATFORM)
        progress(0.55)

        if okUI then
            task.wait(0.4)
            installKeyBypass()
            progress(0.7)
            loadModule(scrUrl, "Script/" .. PLATFORM)
            progress(0.95)
        else
            log("UI falhou")
        end

        if CONFIG.ShowHUD then buildHUD() end
        progress(1)
        log("Pronto")

        task.wait(CONFIG.CloseDelay)
        if S.ui and S.ui.Parent then S.ui:Destroy(); S.ui = nil end
    end)
end

local ok, err = pcall(run)
if not ok then
    warn("[VolleyBomb] " .. tostring(err))
    if S.status then S.status.Text = "Erro: " .. tostring(err) end
end
