--!nocheck
--[[==================================================================
    VolleyBomb :: Loading.lua  (v2)
    - Key system totalmente removido (bypass em runtime + auto-click)
    - Loader com cache, retry exponencial e fallback de CDN
    - Painel com progresso, log e botoes utilitarios
    - HUD de FPS/Ping, Anti-AFK, FPS unlock, Server Hop, Rejoin
==================================================================]]--

local CONFIG = {
    -- Rede / carregamento
    RetryCount      = 3,      -- tentativas por arquivo
    RetryDelay      = 0.6,    -- base do backoff (segundos)
    UseCache        = true,   -- cacheia os .lua no disco (executores com file I/O)
    CacheDir        = "VolleyBomb/cache/",
    Timeout         = 20,

    -- Recursos
    DisableKeySystem = true,  -- mata qualquer UI de key apos carregar
    ExtraButtons     = true,  -- botoes utilitarios no painel
    ShowLog          = true,  -- console de log no painel
    ShowHUD          = true,  -- HUD de FPS/Ping
    UnlockFPS        = true,  -- remove o cap de 60 FPS
    AntiAFK          = true,  -- anti-kick por inatividade
    AutoCleanup      = true,  -- destroi o painel ao terminar
    CloseDelay       = 1.2,

    -- Links
    Discord          = "https://discord.gg/volleybomb", -- ajuste se necessario
    REPO             = "https://raw.githubusercontent.com/Biskus0/VolleyBomb/refs/heads/main/",
    UIC              = "https://raw.githubusercontent.com/Biskus0/UIConstructor/refs/heads/main/",
}

--====================== guarda de instancia ======================--
if getgenv()._VB_LOADING then
    pcall(function() getgenv()._VB_LOADING:Destroy() end)
end

--=========================== servicos ============================--
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInput    = game:GetService("UserInputService")
local GuiService   = game:GetService("GuiService")
local RunService   = game:GetService("RunService")
local Teleport     = game:GetService("TeleportService")
local HttpService  = game:GetService("HttpService")
local VirtualUser  = game:GetService("VirtualUser")
local StarterGui   = game:GetService("StarterGui")

local LP       = Players.LocalPlayer
local IS_MOBILE = UserInput.TouchEnabled and not UserInput.KeyboardEnabled
local PLATFORM  = IS_MOBILE and "Mobile" or "PC"

--=========================== helpers ============================--
local genv = getgenv or function() return _G end

local function log(...)
    local msg = table.concat({...}, " ")
    if CONFIG.ShowLog and genv()._VB_LOG then
        pcall(function()
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -8, 0, 14)
            lbl.BackgroundTransparency = 1
            lbl.Font = Enum.Font.Code
            lbl.TextSize = 11
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.TextColor3 = Color3.fromRGB(150, 155, 165)
            lbl.Text = ("[%s] %s"):format(os.date("%H:%M:%S"), msg)
            lbl.Parent = genv()._VB_LOG
            genv()._VB_LOG.CanvasSize = UDim2.new(0, 0, 0, #genv()._VB_LOG:GetChildren() * 15)
            local sc = genv()._VB_LOG.Parent
            if sc then task.defer(function() sc.CanvasPosition = Vector2.new(0, 99999) end) end
        end)
    end
    if genv()._VB_STATUS then
        pcall(function() genv()._VB_STATUS.Text = msg end)
    end
end

local function setProgress(alpha)
    if genv()._VB_BAR then
        TweenService:Create(genv()._VB_BAR, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
            Size = UDim2.new(math.clamp(alpha, 0, 1), 0, 1, 0)
        }):Play()
    end
end

local function cachePath(url)
    return CONFIG.CacheDir .. (url:gsub("[^%w]", "_"):sub(-120)) .. ".lua"
end

local function httpGet(url)
    local lastErr
    for attempt = 1, CONFIG.RetryCount do
        local ok, body = pcall(function()
            if CONFIG.UseCache and isfile and readfile and isfile(cachePath(url)) then
                local cached = readfile(cachePath(url))
                if #cached > 64 then return cached end
            end
            local res
            if syn and syn.request then
                res = syn.request({Url = url, Method = "GET", Timeout = CONFIG.Timeout}).Body
            elseif http_request then
                res = http_request({Url = url, Method = "GET"}).Body
            elseif request then
                res = request({Url = url, Method = "GET"}).Body
            else
                res = game:HttpGet(url, true)
            end
            if CONFIG.UseCache and writefile then
                if makefolder and not isfolder(CONFIG.CacheDir) then pcall(makefolder, CONFIG.CacheDir) end
                pcall(writefile, cachePath(url), res)
            end
            return res
        end)

        if ok and type(body) == "string" and #body > 0 then
            return body
        end
        lastErr = body
        log(("Retry %d/%d: %s"):format(attempt, CONFIG.RetryCount, url:match("[^/]+$")))
        task.wait(CONFIG.RetryDelay * attempt)
    end
    return nil, lastErr
end

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(parent, radius)
    return new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, parent)
end

--============================= UI ===============================--
local function buildUI()
    local gui = new("ScreenGui", {
        Name = "VolleyBombLoader",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
    genv()._VB_LOADING = gui

    local panel = new("Frame", {
        Size = UDim2.new(0, 420, 0, 250),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(18, 18, 22),
        BorderSizePixel = 0,
    }, gui)
    corner(panel, 12)
    new("UIStroke", {Color = Color3.fromRGB(45, 45, 55), Thickness = 1}, panel)

    local accent = new("Frame", {
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = Color3.fromRGB(120, 90, 255),
        BorderSizePixel = 0,
    }, panel)
    new("UIGradient", {
        Color = ColorSequence.new(Color3.fromRGB(120, 90, 255), Color3.fromRGB(60, 200, 255)),
    }, accent)

    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 26),
        Position = UDim2.new(0, 16, 0, 14),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        TextSize = 17,
        TextColor3 = Color3.fromRGB(240, 240, 245),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "VolleyBomb",
    }, panel)

    new("TextLabel", {
        Size = UDim2.new(1, -24, 0, 14),
        Position = UDim2.new(0, 16, 0, 40),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(120, 125, 140),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = ("Plataforma: %s  |  Key: removida"):format(PLATFORM),
    }, panel)

    local barBg = new("Frame", {
        Size = UDim2.new(1, -32, 0, 5),
        Position = UDim2.new(0, 16, 0, 62),
        BackgroundColor3 = Color3.fromRGB(35, 35, 42),
        BorderSizePixel = 0,
    }, panel)
    corner(barBg, 3)
    genv()._VB_BAR = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(120, 90, 255),
        BorderSizePixel = 0,
    }, barBg)
    corner(genv()._VB_BAR, 3)

    genv()._VB_STATUS = new("TextLabel", {
        Size = UDim2.new(1, -32, 0, 16),
        Position = UDim2.new(0, 16, 0, 72),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(160, 165, 180),
        TextXAlignment = Enum.TextXAlignment.Left,
        Text = "Iniciando...",
    }, panel)

    if CONFIG.ShowLog then
        local scroll = new("ScrollingFrame", {
            Size = UDim2.new(1, -32, 0, 78),
            Position = UDim2.new(0, 16, 0, 92),
            BackgroundColor3 = Color3.fromRGB(13, 13, 16),
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            CanvasSize = UDim2.new(0, 0, 0, 0),
        }, panel)
        corner(scroll, 6)
        genv()._VB_LOG = new("Frame", {
            Size = UDim2.new(1, -6, 1, 0),
            BackgroundTransparency = 1,
        }, scroll)
        new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1)}, genv()._VB_LOG)
    end

    -- barra de botoes
    local grid = new("Frame", {
        Size = UDim2.new(1, -32, 0, 34),
        Position = UDim2.new(0, 16, 1, -46),
        BackgroundTransparency = 1,
    }, panel)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, grid)

    local function button(text, order, color, cb)
        local b = new("TextButton", {
            Size = UDim2.new(0, 74, 1, 0),
            LayoutOrder = order,
            BackgroundColor3 = color or Color3.fromRGB(32, 32, 40),
            BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium,
            TextSize = 11,
            TextColor3 = Color3.fromRGB(225, 225, 235),
            Text = text,
            AutoButtonColor = false,
        }, grid)
        corner(b, 6)
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = (color or Color3.fromRGB(32, 32, 40)):Lerp(Color3.new(1, 1, 1), 0.15)}):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = color or Color3.fromRGB(32, 32, 40)}):Play()
        end)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    if CONFIG.ExtraButtons then
        button("Rejoin", 1, nil, function()
            Teleport:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
        end)
        button("Server Hop", 2, nil, function()
            task.spawn(function()
                local ok, res = pcall(function()
                    local body = game:HttpGet(("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId))
                    return HttpService:JSONDecode(body)
                end)
                if not ok or not res or not res.data then return log("Server Hop: sem servidores") end
                local pool = {}
                for _, s in ipairs(res.data) do
                    if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(pool, s.id) end
                end
                if #pool == 0 then return log("Server Hop: nenhum servidor livre") end
                log(("Server Hop -> %d opcoes"):format(#pool))
                pcall(Teleport.TeleportToPlaceInstance, Teleport, game.PlaceId, pool[math.random(#pool)], LP)
            end)
        end)
        button("Discord", 3, nil, function()
            if setclipboard then setclipboard(CONFIG.Discord) end
            log("Discord copiado")
        end)
        button("Recarregar", 4, nil, function()
            pcall(function() genv()._VB_LOADING:Destroy() end)
            task.wait(0.3)
            local src = httpGet(CONFIG.REPO .. "Loading.lua")
            if src then loadstring(src)() end
        end)
        button("Limpar Cache", 5, nil, function()
            if not (isfolder and listfiles and delfile) then return log("Sem file I/O") end
            for _, f in ipairs(listfiles(CONFIG.CacheDir) or {}) do pcall(delfile, f) end
            log("Cache limpo")
        end)
    end

    -- minimizar
    local min = new("TextButton", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = UDim2.new(1, -58, 0, 12),
        BackgroundColor3 = Color3.fromRGB(32, 32, 40),
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Color3.fromRGB(200, 200, 210),
        Text = "-",
        AutoButtonColor = false,
    }, panel)
    corner(min, 6)

    local closed = false
    min.MouseButton1Click:Connect(function()
        if closed then return end
        closed = true
        TweenService:Create(panel, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 150, 0, 34),
            Position = UDim2.new(0, 16, 0, 16),
            AnchorPoint = Vector2.zero,
        }):Play()
        for _, c in ipairs(panel:GetDescendants()) do
            if c:IsA("Frame") or c:IsA("ScrollingFrame") or c:IsA("TextLabel") then
                if c ~= panel then c.Visible = false end
            end
        end
        min.Text = "+"
        task.delay(0.25, function()
            min.MouseButton1Click:Connect(function()
                closed = false
                TweenService:Create(panel, TweenInfo.new(0.2), {
                    Size = UDim2.new(0, 420, 0, 250),
                    Position = UDim2.fromScale(0.5, 0.5),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                }):Play()
                for _, c in ipairs(panel:GetDescendants()) do
                    if c:IsA("Frame") or c:IsA("ScrollingFrame") or c:IsA("TextLabel") then c.Visible = true end
                end
                min.Text = "-"
            end)
        end)
    end)

    return gui
end

--============================ HUD ===============================--
local function buildHUD()
    local hud = new("ScreenGui", {
        Name = "VolleyBombHUD",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 998,
    })
    pcall(function() hud.Parent = game:GetService("CoreGui") end)
    if not hud.Parent then hud.Parent = LP:WaitForChild("PlayerGui") end
    genv()._VB_HUD = hud

    local box = new("Frame", {
        Size = UDim2.new(0, 130, 0, 22),
        Position = UDim2.new(0, 12, 0, 12),
        BackgroundColor3 = Color3.fromRGB(15, 15, 18),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
    }, hud)
    corner(box, 5)
    local label = new("TextLabel", {
        Size = UDim2.new(1, -8, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Color3.fromRGB(180, 220, 190),
        Text = "FPS -- | PING --",
    }, box)

    local frames, acc, t0 = 0, 0, os.clock()
    local ping = 0
    task.spawn(function()
        while hud.Parent do
            local ok, p = pcall(function() return Stats and Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if ok and p then ping = math.floor(p) end
            task.wait(1)
        end
    end)

    RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - t0 >= 0.5 then
            acc = math.floor(frames / (now - t0))
            frames, t0 = 0, now
            label.Text = ("FPS %d | PING %d"):format(acc, ping)
            label.TextColor3 = acc < 30 and Color3.fromRGB(255, 130, 130) or Color3.fromRGB(180, 220, 190)
        end
    end)
end

--====================== bypass do key system ====================--
local function installKeyBypass()
    if not CONFIG.DisableKeySystem then return end

    genv().VolleyBomb = genv().VolleyBomb or {}
    genv().VolleyBomb.KeyValid = true
    _G.Key, _G.KeyValid, _G.KeyVerified, _G.HasKey = true, true, true, true

    local PATTERN = {key = true, keysystem = true, login = true, auth = true, verif = true, whitelist = true}
    local PlayerGui = LP:FindFirstChild("PlayerGui")
    if not PlayerGui then return end

    local function isKeyGui(inst)
        if not inst:IsA("ScreenGui") or inst.Name == "VolleyBombLoader" or inst.Name == "VolleyBombHUD" then return false end
        local n = inst.Name:lower():gsub("[^%w]", "")
        for k in pairs(PATTERN) do
            if n:find(k, 1, true) then return true end
        end
        -- heuristica: gui com caixa de texto + botao
        local box = inst:FindFirstChildWhichIsA("TextBox", true)
        return box ~= nil and inst:FindFirstChildWhichIsA("TextButton", true) ~= nil
    end

    local function kill(gui)
        if not isKeyGui(gui) then return end
        log("Key GUI removida: " .. gui.Name)
        -- tenta preencher e confirmar antes de matar
        pcall(function()
            local box = gui:FindFirstChildWhichIsA("TextBox", true)
            if box then box.Text = "BYPASS" end
            for _, b in ipairs(gui:GetDescendants()) do
                if b:IsA("TextButton") then
                    local t = b.Text:lower()
                    if t:find("key") or t:find("entr") or t:find("continu") or t:find("verif") then
                        for _, c in ipairs(getconnections or {} ) do end
                        b:Activate()
                        break
                    end
                end
            end
        end)
        task.delay(1.2, function() pcall(function() gui:Destroy() end) end)
    end

    for _, g in ipairs(PlayerGui:GetChildren()) do kill(g) end
    local conn = PlayerGui.ChildAdded:Connect(kill)
    task.delay(20, function() pcall(function() conn:Disconnect() end) end)
end

--========================= anti-AFK ==============================--
local function startAntiAFK()
    if not CONFIG.AntiAFK then return end
    LP.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

--============================ main ==============================--
local function loadModule(url, label)
    local src, err = httpGet(url)
    if not src then
        log("FALHA: " .. label)
        return nil
    end
    local chunk, perr = loadstring(src, "=" .. label)
    if not chunk then
        log("ERRO de sintaxe: " .. label)
        return nil
    end
    local ok, res = pcall(chunk)
    if not ok then
        log("ERRO ao executar " .. label .. ": " .. tostring(res))
        return nil
    end
    log("OK: " .. label)
    return res
end

local function run()
    if CONFIG.UnlockFPS and setfpscap then pcall(setfpscap, 240) end

    local gui = buildUI()
    setProgress(0.05)

    task.spawn(function()
        startAntiAFK()

        log("Detectado: " .. PLATFORM)
        setProgress(0.15)

        local uiUrl  = CONFIG.UIC  .. (IS_MOBILE and "Mobile.lua" or "PC.lua")
        local scrUrl = CONFIG.REPO .. (IS_MOBILE and "Mobile%20Script.lua" or "PC%20Script.lua")

        setProgress(0.3)
        local okUI = loadModule(uiUrl, "UI/" .. PLATFORM)
        setProgress(0.55)

        if okUI then
            task.wait(0.4)
            installKeyBypass()
            setProgress(0.7)
            loadModule(scrUrl, "Script/" .. PLATFORM)
            setProgress(0.95)
        else
            log("UI falhou — abortando")
            setProgress(0.95)
        end

        if CONFIG.ShowHUD then buildHUD() end
        setProgress(1)
        log("Concluido")

        if CONFIG.AutoCleanup then
            task.wait(CONFIG.CloseDelay)
            pcall(function() gui:Destroy() end)
        end
    end)
end

--===================== protecao contra erro ====================--
local ok, err = pcall(run)
if not ok then
    warn("[VolleyBomb] erro no loader: " .. tostring(err))
    if genv()._VB_STATUS then genv()._VB_STATUS.Text = "Erro: " .. tostring(err) end
end
