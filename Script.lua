--[[
	VolleyBomb :: Loading.lua  (reescrita v2.0.0)
	Cole na ordem: 1..9
	Fluxo: guarda -> http/cache -> stealth -> snapshot/limiter/watchdog
	       -> painel -> varredura de key -> bootstrap do payload
]]

local VERSION = "2.0.0"

local RAW     = "https://raw.githubusercontent.com/Biskus0/VolleyBomb/refs/heads/main/"
local SELF    = RAW .. "Loading.lua"
local UI_BASE = "https://raw.githubusercontent.com/Biskus0/UIConstructor/refs/heads/main/"

local CONFIG = {
	httpTimeout       = 12,
	retries           = 4,
	fpsCap            = 240,
	cacheDir          = "VolleyBombCache",
	keyMonitorSeconds = 20,
	rateLimit         = 45,
	maxVelocity       = 900,
	snapStuds         = 45,
	useRemoteLoader   = false,
}

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local Stats        = game:GetService("Stats")
local Teleport     = game:GetService("TeleportService")
local HttpService  = game:GetService("HttpService")
local StarterGui   = game:GetService("StarterGui")

local LP = Players.LocalPlayer

local ALPHA = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local function randStr(n)
	local out = {}
	for i = 1, n do
		local k = math.random(1, #ALPHA)
		out[i] = ALPHA:sub(k, k)
	end
	return table.concat(out)
end

local STATE_KEY = "_" .. randStr(12)
local GUI_NAME  = randStr(math.random(9, 14))

local G     = getgenv and getgenv() or _G
local Api   = {}
local alive = true

local function teardown()
	if not alive then return end
	alive = false
	for i = #Api, 1, -1 do
		pcall(Api[i])
	end
	Api = {}
	if G[STATE_KEY] ~= nil then G[STATE_KEY] = nil end
end

local previous = G[STATE_KEY]
if type(previous) == "table" and previous.teardown then
	pcall(previous.teardown)
end

G[STATE_KEY] = { version = VERSION, teardown = teardown, startedAt = os.time() }

-- log ------------------------------------------------------------
local Log = { buffer = {}, bound = nil, limit = 250 }
local baseClock = os.clock()

local function stamp()
	local ok, v = pcall(os.date, "%H:%M:%S")
	if ok then return v end
	return string.format("%06.2f", os.clock() - baseClock)
end

local function log(level, msg)
	local entry = { t = stamp(), lvl = level, msg = tostring(msg) }
	Log.buffer[#Log.buffer + 1] = entry
	if #Log.buffer > Log.limit then table.remove(Log.buffer, 1) end
	if Log.bound then pcall(Log.bound, entry) end
end

local function notify(title, text, dur)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title), Text = tostring(text), Duration = dur or 4,
		})
	end)
	log("info", title .. " :: " .. text)
end

log("info", "carregando " .. VERSION .. " (" .. GUI_NAME .. ")")-- http -----------------------------------------------------------
local Http = {}

local function fsReady()
	return type(writefile) == "function"
		and type(readfile) == "function"
		and type(isfile) == "function"
end

local function ensureDir()
	if not fsReady() then return false end
	if type(makefolder) == "function" and type(isfolder) == "function" then
		if not isfolder(CONFIG.cacheDir) then pcall(makefolder, CONFIG.cacheDir) end
	end
	return true
end
ensureDir()

local function cachePath(url)
	local h = 5381
	for i = 1, #url do
		h = (h * 33 + url:byte(i)) % 4294967296
	end
	return CONFIG.cacheDir .. "/" .. string.format("%08x", h) .. ".lua"
end

local function looksBad(body)
	if type(body) ~= "string" then return true end
	if #body < 64 then return true end
	local head = body:sub(1, 240):lower()
	if head:find("<!doctype", 1, true) then return true end
	if head:find("<html", 1, true) then return true end
	if head:find("404: not found", 1, true) then return true end
	if head:find("rate limit", 1, true) then return true end
	if head:find("too many requests", 1, true) then return true end
	return false
end

local function rawFetch(url)
	local done, ok, body = false, false, nil
	task.spawn(function()
		local fn = game.HttpGetAsync or game.HttpGet
		local s, r = pcall(fn, game, url)
		ok, body = s, r
		done = true
	end)
	local t0 = os.clock()
	while not done and (os.clock() - t0) < CONFIG.httpTimeout do
		task.wait(0.02)
	end
	if not done then return false, "timeout" end
	if not ok then return false, tostring(body) end
	return true, body
end

function Http.get(url, label, opts)
	opts = opts or {}
	local path = cachePath(url)
	local cached
	if fsReady() and isfile(path) then
		local s, data = pcall(readfile, path)
		if s and not looksBad(data) then cached = data end
	end

	if cached and not opts.bypass then
		log("cache", label .. " do disco (" .. #cached .. "b)")
		return cached
	end

	for attempt = 1, CONFIG.retries do
		local ok, body = rawFetch(url)
		if ok and not looksBad(body) then
			if fsReady() then pcall(writefile, path, body) end
			log("ok", label .. " baixado (" .. #body .. "b)")
			return body
		end
		local reason = ok and "resposta invalida" or body
		log("warn", label .. " falhou " .. attempt .. "/" .. CONFIG.retries .. ": " .. tostring(reason))
		if attempt < CONFIG.retries then
			task.wait(0.5 * (2 ^ (attempt - 1)) + math.random() * 0.25)
		end
	end

	if cached then
		log("warn", label .. " usando cache antigo")
		return cached
	end
	return nil
end

function Http.run(src, name)
	if type(src) ~= "string" or #src == 0 then return false, "fonte vazia" end
	local fn, err = loadstring(src, "=VolleyBomb/" .. name)
	if not fn then
		log("err", "compile " .. name .. ": " .. tostring(err))
		return false, err
	end
	local ok, res = pcall(fn)
	if not ok then
		log("err", "runtime " .. name .. ": " .. tostring(res))
		return false, res
	end
	return true, res
end-- stealth --------------------------------------------------------
local function stealthParent()
	local parent
	if type(gethui) == "function" then
		local ok, r = pcall(gethui)
		if ok and r then parent = r end
	end
	if not parent then
		local ok, cg = pcall(function() return game:GetService("CoreGui") end)
		if ok and cg then parent = cg end
	end
	if not parent then parent = LP:WaitForChild("PlayerGui") end
	return parent
end

local function protect(inst)
	if type(protect_gui) == "function" then pcall(protect_gui, inst) end
	if type(syn) == "table" and type(syn.protect_gui) == "function" then
		pcall(syn.protect_gui, inst)
	end
end

-- snapshot -------------------------------------------------------
local Snap = { data = nil }
local reversals = 0

function Snap.capture()
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	local s = { at = os.time() }
	if hum then
		s.walk = hum.WalkSpeed
		s.jump = hum.JumpPower or hum.JumpHeight
		s.hip  = hum.HipHeight
	end
	if workspace.CurrentCamera then s.fov = workspace.CurrentCamera.FieldOfView end
	s.gravity = workspace.Gravity
	s.fog     = Lighting.FogEnd
	s.bright  = Lighting.Brightness
	Snap.data = s
	log("info", "snapshot capturado")
	return s
end

function Snap.restore()
	local s = Snap.data
	if not s then return end
	local char = LP.Character
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		if s.walk then pcall(function() hum.WalkSpeed = s.walk end) end
		if s.jump then pcall(function()
			if hum.JumpPower then hum.JumpPower = s.jump else hum.JumpHeight = s.jump end
		end) end
		if s.hip then pcall(function() hum.HipHeight = s.hip end) end
	end
	if s.fov and workspace.CurrentCamera then
		pcall(function() workspace.CurrentCamera.FieldOfView = s.fov end)
	end
	if s.gravity then pcall(function() workspace.Gravity = s.gravity end) end
	if s.fog then pcall(function() Lighting.FogEnd = s.fog end) end
	if s.bright then pcall(function() Lighting.Brightness = s.bright end) end
	reversals = reversals + 1
	log("info", "snapshot restaurado")
end

-- rate limiter ---------------------------------------------------
local Rate = { budget = CONFIG.rateLimit, last = os.clock() }
local function rateGate()
	local now = os.clock()
	Rate.budget = math.min(CONFIG.rateLimit, Rate.budget + (now - Rate.last) * CONFIG.rateLimit)
	Rate.last = now
	if Rate.budget >= 1 then
		Rate.budget = Rate.budget - 1
		return
	end
	local waitFor = (1 - Rate.budget) / CONFIG.rateLimit
	Rate.budget = 0
	task.wait(waitFor)
end

-- anti-kick ------------------------------------------------------
local Kick = { mode = 1, names = { "soft", "hard", "off" }, hits = 0 }
local function kickMode() return Kick.names[Kick.mode] end
local function cycleKick()
	Kick.mode = (Kick.mode % #Kick.names) + 1
	log("info", "anti-kick -> " .. kickMode())
	return kickMode()
end

local mt = getrawmetatable and getrawmetatable(game)
if mt then
	local oldIndex    = mt.__index
	local oldNamecall = mt.__namecall
	local busy        = false

	pcall(setreadonly, mt, false)

	mt.__index = function(self, key)
		local value = oldIndex(self, key)
		if self == LP and key == "Kick" then
			return function(inst, ...)
				if Kick.mode == 3 then return value(inst, ...) end
				Kick.hits = Kick.hits + 1
				local msg = tostring((...))
				log("warn", "kick interceptado: " .. msg)
				notify("Kick interceptado", msg, 5)
				if Kick.mode == 2 then return end
				task.delay(1.5, function()
					pcall(function()
						Teleport:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
					end)
				end)
			end
		end
		return value
	end

	mt.__namecall = function(self, ...)
		if not checkcaller() then return oldNamecall(self, ...) end
		local method = getnamecallmethod()
		if busy then return oldNamecall(self, ...) end
		if method == "FireServer" or method == "InvokeServer" then
			busy = true
			rateGate()
			local r = oldNamecall(self, ...)
			busy = false
			return r
		end
		return oldNamecall(self, ...)
	end

	pcall(setreadonly, mt, true)

	Api[#Api + 1] = function()
		pcall(setreadonly, mt, false)
		mt.__index    = oldIndex
		mt.__namecall = oldNamecall
		pcall(setreadonly, mt, true)
	end
	log("info", "hooks instalados")
else
	log("warn", "sem getrawmetatable: anti-kick e limiter desligados")
end

-- watchdog anti-fling --------------------------------------------
local Watch = { on = true, lastPos = nil, conn = nil, charConn = nil }

local function clampVelocity(char)
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local v = hrp.AssemblyLinearVelocity
	if v.Magnitude > CONFIG.maxVelocity then
		hrp.AssemblyLinearVelocity = v.Unit * CONFIG.maxVelocity
		log("warn", string.format("fling clampado: %.0f", v.Magnitude))
	end
	local pos = hrp.Position
	if Watch.lastPos then
		local delta = (pos - Watch.lastPos).Magnitude
		if delta > CONFIG.snapStuds and v.Magnitude < 120 then
			reversals = reversals + 1
			log("warn", string.format("snap de servidor: %.0f studs", delta))
		end
	end
	Watch.lastPos = pos
end

Watch.charConn = LP.CharacterAdded:Connect(function(char)
	Watch.lastPos = nil
	log("info", "watchdog religado no personagem")
	task.spawn(function() char:WaitForChild("HumanoidRootPart", 5) end)
end)

Watch.conn = RunService.Heartbeat:Connect(function()
	if not Watch.on then return end
	clampVelocity(LP.Character)
end)

Api[#Api + 1] = function()
	if Watch.conn then Watch.conn:Disconnect() end
	if Watch.charConn then Watch.charConn:Disconnect() end
    end-- interface ------------------------------------------------------
local UI = { root = nil, main = nil, body = nil, tabFrames = {}, tabButtons = {}, current = nil }
local COL = {
	bg      = Color3.fromRGB(16, 18, 24),
	panel   = Color3.fromRGB(23, 26, 34),
	panel2  = Color3.fromRGB(30, 34, 44),
	stroke  = Color3.fromRGB(45, 50, 62),
	text    = Color3.fromRGB(230, 232, 238),
	dim     = Color3.fromRGB(139, 144, 160),
	accent  = Color3.fromRGB(109, 94, 252),
	accent2 = Color3.fromRGB(34, 211, 238),
	ok      = Color3.fromRGB(52, 211, 153),
	warn    = Color3.fromRGB(251, 191, 36),
	err     = Color3.fromRGB(248, 113, 113),
}

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function corner(inst, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, inst)
end

local function stroke(inst, col)
	new("UIStroke", { Color = col or COL.stroke, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end

local root = new("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 9999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
protect(root)
root.Parent = stealthParent()
UI.root = root

local main = new("Frame", {
	Name = "vb",
	Size = UDim2.fromOffset(430, 330),
	Position = UDim2.new(0, 24, 0, 24),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
}, root)
corner(main, 10)
stroke(main, COL.accent)
UI.main = main

local grad = new("UIGradient", {
	Color = ColorSequence.new(COL.accent, COL.accent2),
	Rotation = 0,
}, main.UIStroke)
main.UIStroke.Thickness = 1.5

if UIS.TouchEnabled and not UIS.MouseEnabled then
	new("UIScale", { Scale = 0.88 }, main)
end

local title = new("Frame", {
	Name = "title",
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = COL.panel,
	BorderSizePixel = 0,
}, main)
corner(title, 10)
new("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = COL.panel,
	BorderSizePixel = 0,
}, title)

new("TextLabel", {
	Size = UDim2.new(1, -84, 1, 0),
	Position = UDim2.fromOffset(12, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COL.text,
	Text = "VOLBOMB  v" .. VERSION,
}, title)

local function titleBtn(txt, x, cb)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(26, 22),
		Position = UDim2.new(1, x, 0, 6),
		BackgroundColor3 = COL.panel2,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = COL.dim,
		Text = txt,
		AutoButtonColor = false,
	}, title)
	corner(b, 5)
	b.MouseEnter:Connect(function() b.TextColor3 = COL.text end)
	b.MouseLeave:Connect(function() b.TextColor3 = COL.dim end)
	b.MouseButton1Click:Connect(cb)
	return b
end

titleBtn("_", -62, function()
	local collapsed = main:GetAttribute("min")
	main:SetAttribute("min", not collapsed)
	UI.body.Visible = collapsed
	main.Size = collapsed and UDim2.fromOffset(430, 330) or UDim2.fromOffset(430, 34)
end)
titleBtn("x", -32, function() teardown() end)

-- arrasto
do
	local dragging, dragStart, startPos = false, nil, nil
	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, dragStart, startPos = true, i.Position, main.Position
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - dragStart
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

-- barra de progresso
local progTrack = new("Frame", {
	Size = UDim2.new(1, -24, 0, 3),
	Position = UDim2.fromOffset(12, 38),
	BackgroundColor3 = COL.panel2,
	BorderSizePixel = 0,
}, main)
corner(progTrack, 2)

local progFill = new("Frame", {
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = COL.accent,
	BorderSizePixel = 0,
}, progTrack)
corner(progFill, 2)
new("UIGradient", { Color = ColorSequence.new(COL.accent, COL.accent2) }, progFill)

local function progress(frac, label)
	TweenService:Create(progFill, TweenInfo.new(0.25), {
		Size = UDim2.new(math.clamp(frac, 0, 1), 0, 1, 0),
	}):Play()
	if label then log("info", label) end
end

local body = new("Frame", {
	Size = UDim2.new(1, 0, 1, -46),
	Position = UDim2.fromOffset(0, 44),
	BackgroundTransparency = 1,
}, main)
UI.body = body

-- abas
local tabBar = new("Frame", {
	Size = UDim2.new(1, -16, 0, 26),
	Position = UDim2.fromOffset(8, 0),
	BackgroundTransparency = 1,
}, body)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 3),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local content = new("Frame", {
	Size = UDim2.new(1, -16, 1, -30),
	Position = UDim2.fromOffset(8, 28),
	BackgroundTransparency = 1,
}, body)

function UI.addTab(name)
	local btn = new("TextButton", {
		Size = UDim2.fromOffset(66, 24),
		BackgroundColor3 = COL.panel,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		TextColor3 = COL.dim,
		Text = name,
		AutoButtonColor = false,
	}, tabBar)
	corner(btn, 5)

	local page = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = COL.stroke,
		Visible = false,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, page)

	local function select()
		for _, b in pairs(UI.tabButtons) do
			b.BackgroundColor3 = COL.panel
			b.TextColor3 = COL.dim
		end
		for _, p in pairs(UI.tabFrames) do p.Visible = false end
		btn.BackgroundColor3 = COL.panel2
		btn.TextColor3 = COL.text
		page.Visible = true
		UI.current = name
	end

	btn.MouseButton1Click:Connect(select)
	btn.MouseEnter:Connect(function() if UI.current ~= name then btn.TextColor3 = COL.text end end)
	btn.MouseLeave:Connect(function() if UI.current ~= name then btn.TextColor3 = COL.dim end end)

	UI.tabButtons[#UI.tabButtons + 1] = btn
	UI.tabFrames[#UI.tabFrames + 1] = page
	return page, select
end

-- console
local consoleWrap = new("Frame", {
	Size = UDim2.new(1, -16, 0, 74),
	Position = UDim2.new(0, 8, 1, -82),
	BackgroundColor3 = COL.panel,
	BorderSizePixel = 0,
}, body)
corner(consoleWrap, 6)
stroke(consoleWrap)

local console = new("ScrollingFrame", {
	Size = UDim2.new(1, -10, 1, -10),
	Position = UDim2.fromOffset(5, 5),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = COL.stroke,
}, consoleWrap)
new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, console)

local consoleCount = 0
local LEVEL_COLOR = { info = COL.dim, ok = COL.ok, warn = COL.warn, err = COL.err, cache = COL.accent2 }

Log.bound = function(entry)
	if consoleCount >= 140 then
		local first = console:GetChildren()[1]
		if first and first:IsA("TextLabel") then first:Destroy() end
	else
		consoleCount = consoleCount + 1
	end
	local line = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = LEVEL_COLOR[entry.lvl] or COL.dim,
		Text = "[" .. entry.t .. "] " .. entry.msg,
	}, console)
	task.defer(function()
		console.CanvasPosition = Vector2.new(0, math.max(0, console.AbsoluteCanvasSize.Y - console.AbsoluteWindowSize.Y))
		line.Size = UDim2.new(1, 0, 0, line.TextBounds.Y)
	end)
end

for _, e in ipairs(Log.buffer) do Log.bound(e) end

-- HUD
local hud = new("Frame", {
	Size = UDim2.fromOffset(112, 24),
	Position = UDim2.new(0, 24, 0, 362),
	BackgroundColor3 = COL.bg,
	BorderSizePixel = 0,
}, root)
corner(hud, 6)
stroke(hud)

local hudFps = new("TextLabel", {
	Size = UDim2.new(0.5, 0, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = COL.ok,
	Text = "FPS --",
}, hud)
local hudPing = new("TextLabel", {
	Size = UDim2.new(0.5, 0, 1, 0),
	Position = UDim2.new(0.5, 0, 0, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 11,
	TextColor3 = COL.dim,
	Text = "PING --",
}, hud)

do
	local frames, acc = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		frames = frames + 1
		acc = acc + dt
		if acc >= 0.5 then
			local fps = math.floor(frames / acc)
			frames, acc = 0, 0
			hudFps.Text = "FPS " .. fps
			hudFps.TextColor3 = fps < 30 and COL.err or (fps < 50 and COL.warn or COL.ok)
		end
	end)

	task.spawn(function()
		while alive do
			task.wait(1)
			local ok, v = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			hudPing.Text = "PING " .. (ok and math.floor(v) or "?")
			hudPing.TextColor3 = (ok and v > 220) and COL.warn or COL.dim
		end
	end)
        end-- widgets --------------------------------------------------------
function UI.section(page, text)
	local l = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = COL.accent2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.upper(text),
	}, page)
	return l
end

function UI.button(page, text, cb)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COL.panel,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		TextColor3 = COL.text,
		Text = text,
		AutoButtonColor = false,
	}, page)
	corner(b, 5)
	stroke(b)

	local function paint(col, txt)
		TweenService:Create(b, TweenInfo.new(0.12), {
			BackgroundColor3 = col, TextColor3 = txt,
		}):Play()
	end

	b.MouseEnter:Connect(function() paint(COL.panel2, COL.accent2) end)
	b.MouseLeave:Connect(function() paint(COL.panel, COL.text) end)
	b.MouseButton1Click:Connect(function()
		paint(COL.accent, COL.text)
		task.delay(0.15, function() paint(COL.panel, COL.text) end)
		task.spawn(cb)
	end)
	return b
end

function UI.row(page, label, default, cb)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COL.panel,
		BorderSizePixel = 0,
	}, page)
	corner(row, 5)
	stroke(row)

	new("TextLabel", {
		Size = UDim2.new(1, -84, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = COL.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = label,
	}, row)

	local box = new("TextBox", {
		Size = UDim2.fromOffset(70, 20),
		Position = UDim2.new(1, -78, 0, 3),
		BackgroundColor3 = COL.panel2,
		BorderSizePixel = 0,
		Font = Enum.Font.Code,
		TextSize = 11,
		TextColor3 = COL.text,
		Text = tostring(default or ""),
		ClearTextOnFocus = false,
	}, row)
	corner(box, 4)

	box.FocusLost:Connect(function()
		local n = tonumber(box.Text)
		if n then task.spawn(cb, n) else box.Text = tostring(default or "") end
	end)
	return box, row
end

function UI.toggle(page, label, default, cb)
	local state = default and true or false
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = COL.panel,
		BorderSizePixel = 0,
	}, page)
	corner(row, 5)
	stroke(row)

	new("TextLabel", {
		Size = UDim2.new(1, -60, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = COL.dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = label,
	}, row)

	local pill = new("Frame", {
		Size = UDim2.fromOffset(38, 18),
		Position = UDim2.new(1, -46, 0, 4),
		BackgroundColor3 = state and COL.ok or COL.panel2,
		BorderSizePixel = 0,
	}, row)
	corner(pill, 9)

	local knob = new("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromOffset(state and 22 or 2, 2),
		BackgroundColor3 = COL.text,
		BorderSizePixel = 0,
	}, pill)
	corner(knob, 7)

	local hit = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
	}, pill)

	hit.MouseButton1Click:Connect(function()
		state = not state
		TweenService:Create(pill, TweenInfo.new(0.15), {
			BackgroundColor3 = state and COL.ok or COL.panel2,
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.15), {
			Position = UDim2.fromOffset(state and 22 or 2, 2),
		}):Play()
		task.spawn(cb, state)
	end)
	return row
            end-- ações ----------------------------------------------------------
local function applySpeed(v) local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.WalkSpeed = v end) end end
local function applyJump(v) local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if h then pcall(function()
	if h.JumpPower then h.JumpPower = v else h.JumpHeight = v end
end) end end
local function applyHip(v) local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid"); if h then pcall(function() h.HipHeight = v end) end end
local function applyFov(v) if workspace.CurrentCamera then pcall(function() workspace.CurrentCamera.FieldOfView = v end) end end

local function fullbright(on)
	pcall(function()
		Lighting.Brightness = on and 2 or Snap.data and Snap.data.bright or 1
		Lighting.Ambient = on and Color3.fromRGB(160, 160, 160) or Color3.fromRGB(70, 70, 70)
	end)
end

local function nofog(on)
	pcall(function()
		Lighting.FogEnd = on and 100000 or (Snap.data and Snap.data.fog or 1000)
	end)
end

local function unlockFps()
	pcall(function() setfpscap(CONFIG.fpsCap) end)
	log("info", "fps cap -> " .. CONFIG.fpsCap)
end

local function rejoin()
	log("info", "rejoin " .. tostring(game.JobId))
	pcall(function() Teleport:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP) end)
end

local function serverHop()
	log("info", "buscando servidores")
	local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
	local ok, raw = pcall(function() return game:HttpGet(url) end)
	if not ok then return notify("Hop", "falha no fetch", 4) end
	local dec = pcall(function() return HttpService:JSONDecode(raw) end)
	if not dec then return notify("Hop", "json invalido", 4) end
	local data = HttpService:JSONDecode(raw)
	local pool = {}
	for _, s in ipairs(data.data or {}) do
		if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) then
			pool[#pool + 1] = s.id
		end
	end
	if #pool == 0 then return notify("Hop", "nenhum servidor livre", 4) end
	local pick = pool[math.random(1, #pool)]
	log("info", "hop -> " .. pick)
	pcall(function() Teleport:TeleportToPlaceInstance(game.PlaceId, pick, LP) end)
end

local function copyJob()
	pcall(function() setclipboard(tostring(game.JobId)) end)
	notify("JobId", tostring(game.JobId), 3)
end

local function copyDiscord()
	pcall(function() setclipboard("https://discord.gg/askvenice") end)
	notify("Discord", "link copiado", 3)
end

local function clearCache()
	if type(isfolder) ~= "function" or type(delfile) ~= "function" then
		return notify("Cache", "sem filesystem", 3)
	end
	if not isfolder(CONFIG.cacheDir) then return notify("Cache", "ja vazio", 3) end
	local n = 0
	local ok, files = pcall(listfiles, CONFIG.cacheDir)
	if ok then
		for _, f in ipairs(files) do
			if pcall(delfile, f) then n = n + 1 end
		end
	end
	log("info", "cache limpo: " .. n .. " arquivo(s)")
end

local function checkUpdate()
	local body = Http.get(SELF, "self", { bypass = true })
	if not body then return notify("Update", "falha no fetch", 4) end
	local remote = body:match("VERSION%s*=%s*[\"']([%d%.]+)[\"']")
	if not remote then return notify("Update", "marcador ausente", 4) end
	if remote == VERSION then
		notify("Update", "atualizado (" .. VERSION .. ")", 4)
	else
		notify("Update", "nova: " .. remote .. " | atual: " .. VERSION, 6)
	end
end

local function dumpEnv()
	local function id()
		if type(identifyexecutor) ~= "function" then return "?" end
		local ok, a, b = pcall(identifyexecutor)
		return ok and (tostring(a) .. " " .. tostring(b)) or "?"
	end
	local lines = {
		"volleybomb " .. VERSION,
		"executor: " .. id(),
		"placeId: " .. tostring(game.PlaceId),
		"jobId: " .. tostring(game.JobId),
		"gethui: " .. tostring(type(gethui) == "function"),
		"protect_gui: " .. tostring(type(protect_gui) == "function"),
		"getrawmetatable: " .. tostring(type(getrawmetatable) == "function"),
		"filesystem: " .. tostring(fsReady()),
		"kick mode: " .. kickMode(),
		"reversals: " .. reversals,
		"uptime: " .. (os.time() - G[STATE_KEY].startedAt) .. "s",
	}
	pcall(function() setclipboard(table.concat(lines, "\n")) end)
	log("info", "ambiente copiado")
	notify("Dump", "copiado para o clipboard", 3)
end

local function reloadSelf()
	log("info", "recarregando loader")
	local src = Http.get(SELF, "self", { bypass = true })
	if not src then return notify("Reload", "falha no fetch", 4) end
	teardown()
	task.wait(0.2)
	local fn = loadstring(src, "=VolleyBomb/reload")
	if fn then pcall(fn) end
end

local function panic()
	Snap.restore()
	Watch.on = false
	notify("Panic", "estado revertido", 3)
                end-- abas -----------------------------------------------------------
local home, selHome = UI.addTab("Home")
UI.section(home, "sessao")
new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30),
	BackgroundTransparency = 1,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COL.dim,
	Text = "Loader independente. O painel do jogo roda abaixo e a varredura de key limpa a tela sozinha.",
}, home)
UI.button(home, "Recarregar loader", reloadSelf)
UI.button(home, "Rejoin", rejoin)
UI.button(home, "Server Hop", serverHop)
UI.button(home, "Discord (clipboard)", copyDiscord)

local player, selPlayer = UI.addTab("Player")
UI.section(player, "corpo")
UI.row(player, "WalkSpeed", 16, applySpeed)
UI.row(player, "JumpPower", 50, applyJump)
UI.row(player, "HipHeight", 2, applyHip)
UI.section(player, "camera")
UI.row(player, "FieldOfView", 70, applyFov)
UI.button(player, "Reset", function()
	local h = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
	if h then pcall(function() h.Health = 0 end) end
end)
UI.button(player, "Spawn (respawn)", function()
	if LP.Character then pcall(function() LP.Character:BreakJoints() end) end
end)

local visual, selVisual = UI.addTab("Visual")
UI.section(visual, "luz")
UI.toggle(visual, "Fullbright", false, fullbright)
UI.toggle(visual, "Sem fog", false, nofog)
UI.section(visual, "desempenho")
UI.toggle(visual, "HUD FPS/Ping", true, function(on) hud.Visible = on end)
UI.button(visual, "Desbloquear FPS (" .. CONFIG.fpsCap .. ")", unlockFps)

local prot, selProt = UI.addTab("Protecao")
UI.section(prot, "anti-kick")
local kickLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamSemibold,
	TextSize = 11,
	TextColor3 = COL.warn,
	Text = "modo: " .. kickMode(),
}, prot)
UI.button(prot, "Ciclar modo de kick", function()
	kickLabel.Text = "modo: " .. cycleKick()
end)
UI.section(prot, "anti-fling")
UI.toggle(prot, "Watchdog de velocidade", true, function(on) Watch.on = on end)
UI.section(prot, "estado")
UI.button(prot, "Capturar snapshot", function() Snap.capture() end)
UI.button(prot, "Panic (restaurar tudo)", panic)

local session, selSession = UI.addTab("Sessao")
UI.section(session, "auditoria")
local sessLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundTransparency = 1,
	Font = Enum.Font.Code,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = COL.dim,
	Text = "",
}, session)
task.spawn(function()
	while alive do
		sessLabel.Text = string.format(
			"uptime   %ds\nreversoes %d\nkicks    %d\nmodo     %s",
			os.time() - G[STATE_KEY].startedAt, reversals, Kick.hits, kickMode()
		)
		task.wait(1)
	end
end)
UI.button(session, "Copiar JobId", copyJob)

local debugTab, selDebug = UI.addTab("Debug")
UI.section(debugTab, "diagnostico")
UI.button(debugTab, "Dump de ambiente", dumpEnv)
UI.button(debugTab, "Verificar update", checkUpdate)
UI.button(debugTab, "Limpar cache", clearCache)
UI.section(debugTab, "perigo")
UI.button(debugTab, "Encerrar loader", function() teardown() end)

selHome()-- key system -----------------------------------------------------
local Key = { kills = 0 }
local KEY_WORDS = { "key", "login", "auth", "verif", "whitelist", "licen" }

local function isKeyName(name)
	local n = tostring(name):lower()
	for _, w in ipairs(KEY_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	return false
end

local function findOfClass(root, class)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA(class) and d.Visible then return d end
	end
	return nil
end

local function fire(sig, ...)
	if not sig then return end
	pcall(function() sig:Fire(...) end)
end

local function candidateKey()
	local v = (getgenv and getgenv().Key) or _G.Key
	if type(v) == "string" and #v > 3 then return v end
	return randStr(24)
end

local function moveOut(gui)
	if not gui or not gui.Parent then return end
	local p = stealthParent()
	if gui.Parent == p then return end
	pcall(function() gui.Name = randStr(math.random(9, 14)) end)
	protect(gui)
	pcall(function() gui.Parent = p end)
end

local function killKey(gui)
	local box = findOfClass(gui, "TextBox")
	local btn = findOfClass(gui, "TextButton")
	local val = candidateKey()

	if box then
		pcall(function()
			box.Text = val
			box:CaptureFocus()
			task.wait(0.06)
			box:ReleaseFocus()
			fire(box.FocusLost, true, "\r")
			fire(box.ReturnPressedFromOnScreenKeyboard)
		end)
	end

	if btn then
		pcall(function()
			fire(btn.MouseButton1Click)
			fire(btn.MouseButton1Down)
			fire(btn.TouchTap)
			fire(btn.Activated)
		end)
	end

	task.wait(0.45)
	Key.kills = Key.kills + 1
	log("warn", "key gui removida: " .. tostring(gui.Name))
	pcall(function() gui:Destroy() end)
end

-- camada 1: flags globais
_G.Key = candidateKey()
_G.KeyValid  = true
_G.KeyVerified = true
_G.HasKey    = true
getgenv().Key = _G.Key
log("info", "flags de key semeadas")

-- camadas 2 e 3: varredura + monitor de 20s
local pg = LP:WaitForChild("PlayerGui")
local seen = {}

local function consider(gui)
	if not gui:IsA("ScreenGui") then return end
	if seen[gui] then return end
	if gui:GetAttribute("VB_Own") or gui.Name == GUI_NAME then return end
	seen[gui] = true

	local keyish = isKeyName(gui.Name)
		or (findOfClass(gui, "TextBox") and findOfClass(gui, "TextButton"))

	if keyish then
		killKey(gui)
	else
		moveOut(gui)
	end
end

for _, g in ipairs(pg:GetChildren()) do
	pcall(consider, g)
end

local monitorConn = pg.DescendantAdded:Connect(function(d)
	pcall(function()
		local gui = d
		while gui and gui.Parent and gui.Parent ~= pg do gui = gui.Parent end
		if gui and gui.Parent == pg then consider(gui) end
	end)
end)

task.delay(CONFIG.keyMonitorSeconds, function()
	if monitorConn then monitorConn:Disconnect() end
	log("info", "monitor de key encerrado (" .. Key.kills .. " removida(s))")
end)

Api[#Api + 1] = function() if monitorConn then monitorConn:Disconnect() end end-- bootstrap ------------------------------------------------------
Snap.capture()
progress(0.05, "snapshot capturado")

local isMobile = UIS.TouchEnabled and not UIS.MouseEnabled
local uiFile, scriptFile

if CONFIG.useRemoteLoader then
	progress(0.1, "detectando plataforma via loader remoto")
	local detected = Http.get(RAW .. "Loader.lua", "loader")
	if detected then
		local ok, res = Http.run(detected, "loader")
		if ok and (res == "PC" or res == "Mobile") then
			isMobile = res == "Mobile"
		end
	end
end

if isMobile then
	uiFile, scriptFile = "Mobile.lua", "Mobile%20Script.lua"
else
	uiFile, scriptFile = "PC.lua", "PC%20Script.lua"
end
log("info", "plataforma: " .. (isMobile and "mobile" or "pc"))

progress(0.2, "baixando interface")
local uiSrc = Http.get(UI_BASE .. uiFile, "ui")
if uiSrc then
	progress(0.5, "executando interface")
	task.spawn(function() Http.run(uiSrc, "ui") end)
else
	log("err", "interface indisponivel")
end

task.wait(0.2)

progress(0.65, "baixando payload")
local payload = Http.get(RAW .. scriptFile, "payload")
if payload then
	progress(0.85, "executando payload")
	task.spawn(function()
		local ok, err = Http.run(payload, "payload")
		progress(1, ok and "payload carregado" or ("falha: " .. tostring(err)))
		if not ok then notify("Payload", "erro na execucao, veja o console", 6) end
	end)
else
	progress(1, "payload indisponivel")
	notify("Payload", "nao foi possivel baixar", 6)
end

task.delay(1.2, function() progress(0) end)

-- encerramento ---------------------------------------------------
Api[#Api + 1] = function()
	if UI.root then pcall(function() UI.root:Destroy() end) end
end

task.spawn(function()
	while alive do
		task.wait(2)
		if UI.root and not UI.root.Parent then
			-- executor limpou a árvore: encerra sem quebrar
			teardown()
			break
		end
	end
end)

notify("VolleyBomb", VERSION .. " pronto | key: " .. kickMode(), 4)
log("ok", "inicializado")
