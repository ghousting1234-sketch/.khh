--=============================================================
-- VolleyBomb Loader v2
-- camadas: key bypass | stealth | otimizacoes | anti-kick
--          anti-ban | anti-fling | painel proprio
--=============================================================

local START = os.clock()
local RUN   = game:GetService("RunService")
local UIS   = game:GetService("UserInputService")
local PLR   = game:GetService("Players")
local TS    = game:GetService("TweenService")
local LIGHT = game:GetService("Lighting")
local STATS = game:GetService("Stats")

local LP = PLR.LocalPlayer
if not LP then pcall(function() LP = PLR:WaitForChild("LocalPlayer", 20) end) end

local CONFIG = {
	discord = "https://discord.gg/askvenice", -- troque pelo convite do projeto
	fpsCap = 240,
	rateLimit = 45,
	clampVelocity = 900,
	keyWindow = 20,
	httpTimeout = 10,
	retries = 3,
	cacheMin = 64,
	gh = "https://raw.githubusercontent.com/Biskus0/",
}

local VOL = CONFIG.gh .. "VolleyBomb/refs/heads/main/"
local UIC = CONFIG.gh .. "UIConstructor/refs/heads/main/"

local function rand(n)
	local pool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local out = {}
	for i = 1, n do
		local k = math.random(1, #pool)
		out[i] = pool:sub(k, k)
	end
	return table.concat(out)
end

local SKEY = "__vb_" .. rand(6)
local GENV = getgenv()

-- guarda de instancia contra execucao dupla
if GENV[SKEY] and GENV[SKEY].alive then
	pcall(function() GENV[SKEY].destroy() end)
end

local S = {
	alive = true,
	guiName = rand(math.random(9, 14)),
	logs = {},
	restored = false,
	reversals = 0,
	kills = 0,
	kickMode = "soft",
	frames = 0,
	fps = 0,
	win = os.clock(),
	snapshot = nil,
	cacheHits = 0,
	cacheWrites = 0,
	hudOn = true,
	flingOn = true,
}
GENV[SKEY] = S

local function stamp()
	local ok, d = pcall(os.date, "*t")
	if ok and d then
		return string.format("%02d:%02d:%02d", d.hour, d.min, d.sec)
	end
	return tostring(math.floor(os.clock()))
end

local function log(tag, msg)
	local line = stamp() .. "  " .. tag .. "  " .. tostring(msg)
	table.insert(S.logs, line)
	if #S.logs > 200 then table.remove(S.logs, 1) end
	if S.console and S.console.Parent then
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextSize = 11
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.fromRGB(160, 170, 190)
		l.Size = UDim2.new(1, -8, 0, 14)
		l.Text = line
		l.Parent = S.console
		task.defer(function()
			if S.console then
				S.console.CanvasPosition = Vector2.new(0, S.console.AbsoluteCanvasSize.Y)
			end
		end)
	end
end

local function notify(txt)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "VolleyBomb",
			Text = tostring(txt),
			Duration = 3,
		})
	end)
end

local function hash(str)
	local h = 2166136261
	for i = 1, #str do
		h = bit32.bxor(h, str:byte(i))
		h = bit32.bmul(h, 16777619)
	end
	return string.format("%x", h)
end

local httpReq = (syn and syn.request) or (http and http.request) or http_request or request

local function fetch(url)
	local cacheFile = "vb_" .. hash(url) .. ".lua"

	if isfile and readfile then
		local okS, size = pcall(getfilesize, cacheFile)
		if okS and size and size >= CONFIG.cacheMin then
			local okR, data = pcall(readfile, cacheFile)
			if okR and type(data) == "string" and #data >= CONFIG.cacheMin then
				S.cacheHits = S.cacheHits + 1
				log("cache", url:sub(-26))
				return data
			end
		end
	end

	local last
	for attempt = 1, CONFIG.retries do
		local ok, res = pcall(function()
			if httpReq then
				local r = httpReq({ Url = url, Method = "GET", Timeout = CONFIG.httpTimeout })
				if not r then error("sem resposta") end
				if r.StatusCode and r.StatusCode >= 400 then
					error("HTTP " .. r.StatusCode)
				end
				return r.Body
			end
			return game:HttpGetAsync(url)
		end)
		if ok and type(res) == "string" and #res > 0 then
			if writefile then
				pcall(writefile, cacheFile, res)
				S.cacheWrites = S.cacheWrites + 1
			end
			return res
		end
		last = res
		log("http", "retry " .. attempt .. " falhou")
		task.wait(0.5 * (2 ^ (attempt - 1)))
	end
	error("falha ao baixar " .. url .. " -> " .. tostring(last))
end

local function loadChunk(src, name)
	local fn, err = loadstring(src, name)
	if not fn then
		log("load", "sintaxe em " .. name .. ": " .. tostring(err))
		return nil
	end
	local ok, res = pcall(fn)
	if not ok then
		log("load", "erro em " .. name .. ": " .. tostring(res))
		return nil
	end
	return res
end
	
--==== 1. KEY SYSTEM: REMOVIDO =================================
_G.Key = rand(16)
_G.KeyValid = true
_G.KeyVerified = true
_G.HasKey = true

local KEYWORDS = { "key", "login", "auth", "verif", "whitelist" }

local function isKeyName(name)
	local n = tostring(name):lower()
	for _, p in ipairs(KEYWORDS) do
		if n:find(p, 1, true) then return true end
	end
	return false
end

local function looksLikeKey(gui)
	local box, btn
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextBox") and not box then
			box = d
		elseif d:IsA("TextButton") and not btn then
			btn = d
		end
	end
	return (box and btn) and true or false, box, btn
end

local function fillAndConfirm(box, btn)
	if box then
		pcall(function()
			if box.Text == "" then box.Text = rand(12) end
			if firesignal then
				pcall(firesignal, box.FocusLost)
				pcall(firesignal, box.TextChanged, box.Text)
			end
		end)
	end
	task.wait(0.15)
	if btn and firesignal then
		pcall(firesignal, btn.MouseButton1Click)
		pcall(firesignal, btn.Activated)
	end
end

local function sweepKeys()
	local pg = LP and LP:FindFirstChild("PlayerGui")
	if not pg then return end
	local n = 0
	for _, gui in ipairs(pg:GetChildren()) do
		if gui:IsA("ScreenGui") then
			local byName = isKeyName(gui.Name)
			local heur, box, btn = looksLikeKey(gui)
			if byName or heur then
				fillAndConfirm(box, btn)
				task.wait(0.2)
				if gui.Parent then gui:Destroy() end
				n = n + 1
				log("key", "removido " .. gui.Name)
			end
		end
	end
	S.kills = S.kills + n
	log("key", "varredura inicial: " .. n)
end

local function watchKeys()
	local pg = LP and LP:FindFirstChild("PlayerGui")
	if not pg then return end
	local conn = pg.ChildAdded:Connect(function(c)
		if not S.alive or not c then return end
		task.wait(0.4)
		if not c.Parent or not c:IsA("ScreenGui") then return end
		local byName = isKeyName(c.Name)
		local heur, box, btn = looksLikeKey(c)
		if byName or heur then
			fillAndConfirm(box, btn)
			task.wait(0.2)
			if c.Parent then c:Destroy() end
			S.kills = S.kills + 1
			log("key", "capturado " .. c.Name)
		end
	end)
	task.delay(CONFIG.keyWindow, function()
		if conn then conn:Disconnect() end
		log("key", "monitor encerrado (" .. S.kills .. " total)")
	end)
end

--==== 2. STEALTH ==============================================
local function hiddenParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	return game:GetService("CoreGui")
end

--==== 3. RATE LIMITER =========================================
local lastCall = 0
local checkcallerSafe = checkcaller or function() return true end

local function pace()
	local gap = 1 / CONFIG.rateLimit
	local now = os.clock()
	local d = lastCall + gap - now
	if d > 0 then task.wait(d) end
	lastCall = os.clock()
end

local function hookNamecall()
	if not getrawmetatable or not setreadonly then return end
	local ok, mt = pcall(getrawmetatable, game)
	if not ok or not mt or not mt.__namecall then return end
	local old = mt.__namecall
	setreadonly(mt, false)
	mt.__namecall = newcclosure(function(self, ...)
		local m = getnamecallmethod()
		if (m == "FireServer" or m == "InvokeServer") and checkcallerSafe() then
			pace()
		end
		return old(self, ...)
	end)
	setreadonly(mt, true)
	log("rate", "limite " .. CONFIG.rateLimit .. "/s ativo")
end

--==== 4. ANTI-KICK ============================================
local function rejoin()
	pcall(function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, LP)
	end)
end

local kickHooked = {}

local function wrapKick(player)
	if kickHooked[player] then return end
	if not getrawmetatable or not setreadonly then return end
	local ok, pmt = pcall(getrawmetatable, player)
	if not ok or not pmt or not pmt.__index or kickHooked[pmt] then return end
	kickHooked[player] = true
	kickHooked[pmt] = true
	local old = pmt.__index
	setreadonly(pmt, false)
	pmt.__index = newcclosure(function(self, key)
		local v = old(self, key)
		if key == "Kick" and type(v) == "function" and self == LP then
			return function(...)
				if S.kickMode == "off" then return v(...) end
				local args = { ... }
				log("kick", "chamado: " .. tostring(args[1]))
				S.reversals = S.reversals + 1
				if S.kickMode == "hard" then
					notify("Kick bloqueado")
					return
				end
				pcall(v, ...)
				notify("Kick soft: reconectando")
				task.delay(0.8, rejoin)
			end
		end
		return v
	end)
	setreadonly(pmt, true)
end

local function hookGameIndex()
	if not getrawmetatable or not setreadonly then return end
	local ok, mt = pcall(getrawmetatable, game)
	if not ok or not mt or not mt.__index then return end
	local old = mt.__index
	setreadonly(mt, false)
	mt.__index = newcclosure(function(self, key)
		local v = old(self, key)
		if key == "LocalPlayer" and self == game and typeof(v) == "Instance" then
			pcall(wrapKick, v)
		end
		return v
	end)
	setreadonly(mt, true)
	if LP then pcall(wrapKick, LP) end
end

--==== 5. ANTI-BAN =============================================
local function snap()
	local ch = LP and LP.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	S.snapshot = {
		ws = hum and hum.WalkSpeed or 16,
		jp = hum and hum.JumpPower or 50,
		hip = hum and hum.HipHeight or 0,
		fov = cam and cam.FieldOfView or 70,
		grav = workspace.Gravity,
		fogE = LIGHT.FogEnd,
		fogS = LIGHT.FogStart,
		fogC = LIGHT.FogColor,
		bright = LIGHT.Brightness,
	}
end

local function restore()
	if S.restored or not S.snapshot then return end
	S.restored = true
	local s = S.snapshot
	local ch = LP and LP.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function() hum.WalkSpeed = s.ws end)
		pcall(function() hum.JumpPower = s.jp end)
		pcall(function() hum.HipHeight = s.hip end)
	end
	if workspace.CurrentCamera then
		pcall(function() workspace.CurrentCamera.FieldOfView = s.fov end)
	end
	pcall(function() workspace.Gravity = s.grav end)
	pcall(function()
		LIGHT.FogEnd = s.fogE
		LIGHT.FogStart = s.fogS
		LIGHT.FogColor = s.fogC
		LIGHT.Brightness = s.bright
	end)
	log("ban", "estado restaurado")
end

--==== 6. ANTI-FLING / ANTI-TP-BACK =============================
local flingConn
local lastPos

local function bindFling(char)
	if flingConn then flingConn:Disconnect() end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp = char:WaitForChild("HumanoidRootPart", 10)
	end
	if not hrp then return end
	lastPos = hrp.Position
	flingConn = RUN.Heartbeat:Connect(function()
		if not S.alive or not S.flingOn or not hrp.Parent then return end
		local v = hrp.AssemblyLinearVelocity
		if v.Magnitude > CONFIG.clampVelocity then
			hrp.AssemblyLinearVelocity = v.Unit * CONFIG.clampVelocity
		end
		local p = hrp.Position
		local jump = (p - lastPos).Magnitude
		if jump > 60 and v.Magnitude < 5 then
			log("fling", "snap detectado " .. math.floor(jump))
		end
		lastPos = p
	end)
end

local function hookFling()
	PLR.CharacterAdded:Connect(function(c)
		task.wait(0.5)
		bindFling(c)
	end)
	if LP and LP.Character then bindFling(LP.Character) end
	end
	
--==== 7. INTERFACE ============================================
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = parent
	return o
end

local BG      = Color3.fromRGB(16, 16, 20)
local PANEL   = Color3.fromRGB(24, 24, 30)
local SOFT    = Color3.fromRGB(34, 34, 42)
local TXT     = Color3.fromRGB(235, 235, 242)
local SUB     = Color3.fromRGB(140, 142, 158)
local ACC1    = Color3.fromRGB(126, 92, 255)
local ACC2    = Color3.fromRGB(0, 198, 255)

local gui = new("ScreenGui", {
	Name = S.guiName,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 10000,
}, hiddenParent())

if protect_gui then pcall(protect_gui, gui) end

local panel = new("Frame", {
	Name = "P",
	Size = UDim2.fromOffset(342, 452),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundColor3 = BG,
	BorderSizePixel = 0,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
new("UIStroke", { Thickness = 1, Color = ACC1, Transparency = 0.4 }, panel)

local topbar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = SOFT,
	BorderSizePixel = 0,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, topbar)
new("UIGradient", {
	Color = ColorSequence.new(ACC1, ACC2),
	Rotation = 90,
	Transparency = NumberSequence.new(0.55),
}, topbar)

local title = new("TextLabel", {
	Size = UDim2.new(1, -80, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = TXT,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "VOLLEYBOMB  //  v2",
}, topbar)

local minBtn = new("TextButton", {
	Size = UDim2.fromOffset(26, 22),
	Position = UDim2.new(1, -62, 0, 6),
	BackgroundColor3 = SOFT,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextColor3 = SUB,
	Text = "-",
}, topbar)
new("UICorner", { CornerRadius = UDim.new(0, 5) }, minBtn)

local closeBtn = new("TextButton", {
	Size = UDim2.fromOffset(26, 22),
	Position = UDim2.new(1, -32, 0, 6),
	BackgroundColor3 = SOFT,
	BorderSizePixel = 0,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(255, 110, 110),
	Text = "x",
}, topbar)
new("UICorner", { CornerRadius = UDim.new(0, 5) }, closeBtn)

local barBg = new("Frame", {
	Size = UDim2.new(1, -24, 0, 4),
	Position = UDim2.fromOffset(12, 40),
	BackgroundColor3 = SOFT,
	BorderSizePixel = 0,
}, panel)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, barBg)

local barFill = new("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = ACC2,
	BorderSizePixel = 0,
}, barBg)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, barFill)
new("UIGradient", { Color = ColorSequence.new(ACC1, ACC2) }, barFill)

local status = new("TextLabel", {
	Size = UDim2.new(1, -24, 0, 16),
	Position = UDim2.fromOffset(12, 48),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "iniciando",
}, panel)

local function setProgress(p, txt)
	TS:Create(barFill, TweenInfo.new(0.25), {
		Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0),
	}):Play()
	if txt then status.Text = txt end
end

local tabBar = new("Frame", {
	Size = UDim2.new(1, -24, 0, 24),
	Position = UDim2.fromOffset(12, 68),
	BackgroundTransparency = 1,
}, panel)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local content = new("Frame", {
	Size = UDim2.new(1, -24, 0, 246),
	Position = UDim2.fromOffset(12, 98),
	BackgroundTransparency = 1,
}, panel)

local consoleBg = new("Frame", {
	Size = UDim2.new(1, -24, 0, 62),
	Position = UDim2.new(0, 12, 1, -74),
	BackgroundColor3 = Color3.fromRGB(12, 12, 15),
	BorderSizePixel = 0,
}, panel)
new("UICorner", { CornerRadius = UDim.new(0, 6) }, consoleBg)

S.console = new("ScrollingFrame", {
	Size = UDim2.new(1, -8, 1, -8),
	Position = UDim2.fromOffset(4, 4),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, consoleBg)
new("UIListLayout", { Padding = UDim.new(0, 1) }, S.console)

-- HUD
local hud = new("TextLabel", {
	Name = "HUD",
	Size = UDim2.fromOffset(160, 20),
	Position = UDim2.fromOffset(10, 10),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 13,
	TextColor3 = Color3.fromRGB(90, 240, 140),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "FPS --  PING --",
}, gui)

-- abas
local TABS = { "Home", "Player", "Visual", "Protecao", "Sessao", "Debug" }
local pages = {}
local activeTab

local function openTab(name)
	activeTab = name
	for n, f in pairs(pages) do
		f.Visible = (n == name)
	end
	for _, b in ipairs(tabBar:GetChildren()) do
		if b:IsA("TextButton") then
			b.BackgroundColor3 = (b.Text == name) and ACC1 or SOFT
		end
	end
end

for i, name in ipairs(TABS) do
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(49, 24),
		BackgroundColor3 = SOFT,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = TXT,
		Text = name,
		LayoutOrder = i,
	}, tabBar)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, btn)
	btn.MouseButton1Click:Connect(function() openTab(name) end)

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 5) }, page)
	pages[name] = page
end

-- drag
local drag, dragStart
topbar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		drag = true
		dragStart = i.Position
	end
end)
UIS.InputChanged:Connect(function(i)
	if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
	or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		dragStart = i.Position
		panel.Position = UDim2.new(
			panel.Position.X.Scale, panel.Position.X.Offset + d.X,
			panel.Position.Y.Scale, panel.Position.Y.Offset + d.Y
		)
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
	or i.UserInputType == Enum.UserInputType.Touch then
		drag = false
	end
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	barBg.Visible = not minimized
	status.Visible = not minimized
	tabBar.Visible = not minimized
	content.Visible = not minimized
	consoleBg.Visible = not minimized
	panel.Size = minimized and UDim2.fromOffset(342, 34) or UDim2.fromOffset(342, 452)
	minBtn.Text = minimized and "+" or "-"
end)

local function destroy()
	if not S.alive then return end
	S.alive = false
	pcall(function() restore() end)
	pcall(function() if flingConn then flingConn:Disconnect() end end)
	pcall(function() gui:Destroy() end)
end
S.destroy = destroy
closeBtn.MouseButton1Click:Connect(destroy)

-- HUD loop: fps por janela de 0.5s
S.frames = 0
RUN.RenderStepped:Connect(function()
	S.frames = S.frames + 1
end)
task.spawn(function()
	while S.alive do
		task.wait(0.5)
		local now = os.clock()
		S.fps = math.floor(S.frames / math.max(now - S.win, 0.001))
		S.frames = 0
		S.win = now
		local ping = 0
		pcall(function()
			ping = math.floor(STATS.Network.ServerStatsItem["Data Ping"]:GetValue())
		end)
		if S.hudOn then
			hud.Visible = true
			hud.Text = "FPS " .. S.fps .. "  PING " .. ping
			hud.TextColor3 = (S.fps < 30)
				and Color3.fromRGB(255, 90, 90)
				or Color3.fromRGB(90, 240, 140)
		else
			hud.Visible = false
		end
	end
end)

log("gui", "painel em " .. gui.Parent.Name .. " / " .. gui.Name)--==== 8. COMPONENTES ==========================================
local function row(parent, label)
	local f = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, f)
	new("TextLabel", {
		Size = UDim2.new(1, -90, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = SUB,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = label,
	}, f)
	return f
end

local function button(parent, label, color, cb)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = color or SOFT,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = TXT,
		Text = label,
		AutoButtonColor = false,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 5) }, b)
	b.MouseEnter:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = ACC1 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TS:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color or SOFT }):Play()
	end)
	b.MouseButton1Click:Connect(function()
		log("ui", label)
		local ok, err = pcall(cb)
		if not ok then log("ui", "erro: " .. tostring(err)) end
	end)
	return b
end

local function input(parent, label, default, cb)
	local f = row(parent, label)
	local box = new("TextBox", {
		Size = UDim2.fromOffset(66, 20),
		Position = UDim2.new(1, -72, 0, 3),
		BackgroundColor3 = BG,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = TXT,
		Text = tostring(default),
		PlaceholderText = "...",
		ClearTextOnFocus = false,
	}, f)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, box)
	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then
			local ok, err = pcall(cb, n)
			if not ok then log("ui", "erro: " .. tostring(err)) end
		else
			log("ui", label .. ": valor invalido")
		end
	end)
	return box
end

--==== 9. HOME =================================================
local home = pages.Home

local info = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = SUB,
	TextWrapped = true,
	Text = "loader ativo\nstealth: " .. gui.Parent.Name .. " / " .. gui.Name,
}, home)
new("UICorner", { CornerRadius = UDim.new(0, 5) }, info)

button(home, "Verificar atualizacao", SOFT, function()
	local ok, err = pcall(function()
		local remote = fetch(VOL .. "Loading.lua")
		local ok2, cur = pcall(function() return game:HttpGetAsync(VOL .. "Loading.lua") end)
		log("update", "remoto " .. #remote .. " bytes")
		if ok2 and type(cur) == "string" then
			log("update", (#cur == #remote) and "sem mudanca" or "divergente")
		end
	end)
	if not ok then log("update", err) end
end)

button(home, "Discord (copiar)", SOFT, function()
	setclipboard(CONFIG.discord)
	notify("Convite copiado")
end)

button(home, "Recarregar loader", ACC1, function()
	log("reload", "re-baixando")
	local ok, src = pcall(fetch, VOL .. "Loading.lua")
	if not ok then
		log("reload", src)
		return
	end
	destroy()
	task.wait(0.4)
	local fn = loadstring(src, "vb_reload")
	if fn then
		local ok2, err = pcall(fn)
		if not ok2 then notify("falhou: " .. tostring(err)) end
	end
end)

button(home, "Limpar cache", SOFT, function()
	if not listfiles then
		log("cache", "executor sem listfiles")
		return
	end
	local n = 0
	for _, f in ipairs(listfiles()) do
		if f:match("vb_%w+%.lua$") and isfile(f) then
			pcall(delfile, f)
			n = n + 1
		end
	end
	log("cache", n .. " arquivos removidos")
end)

button(home, "Panic (restaurar tudo)", Color3.fromRGB(150, 60, 60), function()
	restore()
	S.flingOn = false
	log("panic", "reversao aplicada (" .. S.reversals .. ")")
end)

--==== 10. PLAYER ==============================================
local player = pages.Player

local function hum()
	local c = LP and LP.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

input(player, "WalkSpeed", 16, function(n)
	snap()
	local h = hum()
	if h then h.WalkSpeed = math.clamp(n, 0, 2000) end
end)

input(player, "JumpPower", 50, function(n)
	snap()
	local h = hum()
	if h then h.JumpPower = math.clamp(n, 0, 2000) end
end)

input(player, "HipHeight", 0, function(n)
	snap()
	local h = hum()
	if h then h.HipHeight = math.clamp(n, -50, 500) end
end)

button(player, "Reset", SOFT, function()
	local h = hum()
	if h then h.Health = 0 end
end)

button(player, "Spawn (LoadCharacter)", SOFT, function()
	LP:LoadCharacter()
end)

button(player, "Restaurar defaults", SOFT, function()
	restore()
	S.restored = false
end)

--==== 11. VISUAL ==============================================
local visual = pages.Visual

input(visual, "FieldOfView", 70, function(n)
	snap()
	if workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = math.clamp(n, 1, 120)
	end
end)

button(visual, "Fullbright", SOFT, function()
	snap()
	LIGHT.Brightness = 3
	LIGHT.ClockTime = 14
	LIGHT.FogEnd = 100000
	log("visual", "fullbright on")
end)

button(visual, "No-Fog", SOFT, function()
	snap()
	LIGHT.FogEnd = 100000
	LIGHT.FogStart = 100000
end)

button(visual, "HUD on/off", SOFT, function()
	S.hudOn = not S.hudOn
	log("visual", "hud " .. tostring(S.hudOn))
end)

button(visual, "FPS unlock (" .. CONFIG.fpsCap .. ")", SOFT, function()
	if setfpscap then
		setfpscap(CONFIG.fpsCap)
		log("visual", "cap " .. CONFIG.fpsCap)
	else
		log("visual", "setfpscap indisponivel")
	end
end)

--==== 12. PROTECAO ============================================
local protec = pages.Protecao

local kickLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "anti-kick: " .. S.kickMode,
}, protec)

button(protec, "Ciclar modo anti-kick", SOFT, function()
	local order = { "soft", "hard", "off" }
	local idx = 1
	for i, v in ipairs(order) do
		if v == S.kickMode then idx = i end
	end
	S.kickMode = order[(idx % #order) + 1]
	kickLabel.Text = "anti-kick: " .. S.kickMode
	log("kick", "modo " .. S.kickMode)
end)

local flingLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "anti-fling: ativo (clamp " .. CONFIG.clampVelocity .. ")",
}, protec)

button(protec, "Ligar/desligar anti-fling", SOFT, function()
	S.flingOn = not S.flingOn
	flingLabel.Text = "anti-fling: " .. (S.flingOn and "ativo" or "desligado")
end)

button(protec, "Re-verificar keys agora", SOFT, function()
	sweepKeys()
end)

button(protec, "Snapshot manual", SOFT, function()
	snap()
	S.restored = false
	log("ban", "snapshot salvo")
end)

button(protec, "Restaurar snapshot", SOFT, function()
	restore()
	S.restored = false
end)

local revLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = Color3.fromRGB(255, 190, 90),
	TextXAlignment = Enum.TextXAlignment.Left,
	Text = "reversoes: 0",
}, protec)

task.spawn(function()
	while S.alive do
		revLabel.Text = "reversoes: " .. S.reversals .. "  |  keys: " .. S.kills
		task.wait(0.5)
	end
end)

--==== 13. SESSAO ==============================================
local sess = pages.Sessao

local function uptime()
	local s = math.floor(os.clock() - START)
	return string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
end

local sessLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true,
	Text = "",
}, sess)
new("UICorner", { CornerRadius = UDim.new(0, 5) }, sess)

task.spawn(function()
	while S.alive do
		sessLabel.Text = "uptime: " .. uptime()
			.. "\njobId: " .. tostring(game.JobId)
			.. "\nplace: " .. tostring(game.PlaceId)
			.. "\nreversoes: " .. S.reversals
			.. "\ncache: " .. S.cacheHits .. " hit / " .. S.cacheWrites .. " write"
		task.wait(1)
	end
end)

button(sess, "Copiar JobId", SOFT, function()
	setclipboard(tostring(game.JobId))
	notify("JobId copiado")
end)

button(sess, "Server Hop", ACC1, function()
	if not httpReq and not game.HttpGetAsync then
		log("hop", "sem HTTP")
		return
	end
	local url = "https://games.roblox.com/v1/games/"
		.. game.PlaceId
		.. "/servers/Public?sortOrder=Asc&limit=100"
	local ok, body = pcall(function()
		if httpReq then
			local r = httpReq({ Url = url, Method = "GET", Timeout = 10 })
			return r and r.Body
		end
		return game:HttpGetAsync(url)
	end)
	if not ok or not body then
		log("hop", "falha na API")
		return
	end
	local dec = (syn and syn.json and syn.json.decode)
		or (HttpService and HttpService.JSONDecode)
		or (http and http.json and http.json.decode)
		or function() return nil end
	local data
	pcall(function()
		if HttpService then
			data = game:GetService("HttpService"):JSONDecode(body)
		else
			data = dec(body)
		end
	end)
	if not data or not data.data then
		log("hop", "resposta invalida")
		return
	end
	local pool = {}
	for _, srv in ipairs(data.data) do
		if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
			table.insert(pool, srv.id)
		end
	end
	if #pool == 0 then
		log("hop", "nenhum servidor livre")
		notify("Nenhum servidor disponivel")
		return
	end
	local pick = pool[math.random(1, #pool)]
	log("hop", "indo para " .. pick:sub(1, 8) .. " (" .. #pool .. " opcoes)")
	pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, pick, LP)
	end)
end)

--==== 14. DEBUG ===============================================
local dbg = pages.Debug

local function envDump()
	local lines = {
		"executor: " .. tostring(identifyexecutor and identifyexecutor() or "?"),
		"versao: " .. tostring(getexecutorname and getexecutorname() or "?"),
		"uptime: " .. uptime(),
		"fps: " .. S.fps,
		"place: " .. tostring(game.PlaceId),
		"jobId: " .. tostring(game.JobId),
		"gethui: " .. tostring(gethui ~= nil),
		"protect_gui: " .. tostring(protect_gui ~= nil),
		"setfpscap: " .. tostring(setfpscap ~= nil),
		"getrawmetatable: " .. tostring(getrawmetatable ~= nil),
		"firesignal: " .. tostring(firesignal ~= nil),
		"writefile: " .. tostring(writefile ~= nil),
		"state key: " .. SKEY,
		"gui name: " .. S.guiName,
	}
	return table.concat(lines, "\n")
end

local dumpLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 190),
	BackgroundColor3 = PANEL,
	BorderSizePixel = 0,
	Font = Enum.Font.Code,
	TextSize = 10,
	TextColor3 = SUB,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextWrapped = true,
	Text = "",
}, dbg)
new("UICorner", { CornerRadius = UDim.new(0, 5) }, dumpLabel)

button(dbg, "Dump ambiente", SOFT, function()
	dumpLabel.Text = envDump()
end)

button(dbg, "Copiar dump", SOFT, function()
	setclipboard(envDump())
	notify("Dump copiado")
end)

button(dbg, "Log completo", SOFT, function()
	setclipboard(table.concat(S.logs, "\n"))
	notify(#S.logs .. " linhas copiadas")
end)

button(dbg, "Destruir instancia", Color3.fromRGB(150, 60, 60), function()
	destroy()
end)

openTab("Home")

--==== 15. BOOT ================================================
local function boot()
	setProgress(0.05, "setando flags de key")
	log("boot", "flags _G setadas")

	task.wait(0.2)
	setProgress(0.15, "varrendo PlayerGui")
	sweepKeys()
	watchKeys()

	setProgress(0.3, "instalando hooks")
	pcall(hookNamecall)
	pcall(hookGameIndex)
	pcall(hookFling)
	snap()
	log("boot", "hooks instalados")

	if setfpscap then pcall(setfpscap, CONFIG.fpsCap) end

	setProgress(0.45, "baixando Loader.lua")
	local okL, loaderSrc = pcall(fetch, VOL .. "Loader.lua")
	local platform = "PC"
	if okL then
		local out = loadChunk(loaderSrc, "vb_loader")
		if out == "Mobile" then
			platform = "Mobile"
		end
		log("boot", "plataforma: " .. platform)
	else
		log("boot", "Loader.lua falhou, assumindo PC")
	end

	setProgress(0.6, "carregando interface original")
	local uiUrl = (platform == "Mobile") and (UIC .. "Mobile.lua") or (UIC .. "PC.lua")
	local okU, uiSrc = pcall(fetch, uiUrl)
	if okU then
		loadChunk(uiSrc, "vb_ui")
	else
		log("boot", uiSrc)
	end

	setProgress(0.8, "carregando script original")
	local scUrl = (platform == "Mobile") and (VOL .. "Mobile%20Script.lua") or (VOL .. "PC%20Script.lua")
	local okS, scSrc = pcall(fetch, scUrl)
	if okS then
		loadChunk(scSrc, "vb_script")
	else
		log("boot", scSrc)
	end

	setProgress(1, "pronto")
	log("boot", "concluido em " .. string.format("%.2fs", os.clock() - START))
	notify("VolleyBomb carregado (" .. platform .. ")")
end

task.spawn(function()
	local ok, err = pcall(boot)
	if not ok then
		log("boot", "falha geral: " .. tostring(err))
		setProgress(1, "falhou - veja o console")
	end
end)
