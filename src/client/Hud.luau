-- Hud: the rancher's ScreenGui over the 3D ranch. A cash panel at the top centre (clear of Roblox's
-- top-left menu) with the $/s and any Golden Hour boost, a next-event timer under it, event banners,
-- the gate / rebirth / RanchDex buttons and the contract board down the right, the trail guide at the
-- bottom, toasts on the left, and the juice: a punching cash counter, "+$" pops over the herd and
-- big reward pops for contracts, bounties and coins.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))

local Hud = {}

local player = Players.LocalPlayer
local CREAM = Color3.fromRGB(255, 246, 225)
local WOOD = Color3.fromRGB(92, 58, 34)
local PANEL = Color3.fromRGB(70, 42, 22)
local BRASS = Color3.fromRGB(240, 190, 90)
local GREEN = Color3.fromRGB(120, 255, 110)
local GOLD = Color3.fromRGB(255, 215, 70)
local RED = Color3.fromRGB(255, 80, 70)
local INK = Color3.fromRGB(40, 20, 8)

-- How each ranch event looks on the HUD.
Hud.EVENTS = {
	stampede = { name = "STAMPEDE", color = Color3.fromRGB(170, 50, 30), icon = "!!",
		warn = "STAMPEDE IN %d - GET OFF THE DRIVE!", active = "THE ROT HERD IS LOOSE! STAY BEHIND A FENCE!" },
	goldenhour = { name = "GOLDEN HOUR", color = Color3.fromRGB(200, 140, 20), icon = "$$",
		warn = "GOLDEN HOUR IN %d - HEAD FOR THE DRIVE!", active = "GOLDEN HOUR! PENS PAY x2 - %ds" },
	dustdevil = { name = "DUST DEVIL", color = Color3.fromRGB(110, 60, 150), icon = "@@",
		warn = "DUST DEVIL IN %d - LOCK UP OR KEEP CLEAR!", active = "DUST DEVIL! GRAB COINS, DON'T GET SWEPT - %ds" },
}

-- The trail guide's four steps (the server ticks them off).
Hud.GUIDE = {
	{ title = "LASSO A CRITTER", hint = "Walk to the Cattle Drive and hold E on a critter you can afford." },
	{ title = "GET IT HOME", hint = "Walk back into your ranch: penned critters pay $/s every second." },
	{ title = "LOCK YOUR GATE", hint = "Press L or stand on the LOCK pad so rustlers can't steal your herd." },
	{ title = "SURVIVE AN EVENT", hint = "When a warning goes up, get off the drive or shelter in your locked ranch." },
}

export type ContractRow = { frame: Frame, text: TextLabel, reward: TextLabel, bar: Frame, done: boolean }

export type View = {
	gui: ScreenGui, area: Frame, cash: TextLabel, cashScale: UIScale, income: TextLabel, rebirths: TextLabel,
	eventPill: TextLabel, banner: TextLabel, carry: TextLabel,
	gateButton: TextButton, rebirthButton: TextButton, dexButton: TextButton, rebirthBar: Frame,
	pens: TextLabel, luck: TextLabel, contracts: { ContractRow }, guide: Frame, guideTitle: TextLabel,
	guideHint: TextLabel, guideDots: { Frame }, toasts: Frame, pops: Frame, shownCash: number,
	lastCash: number, lastBoard: string,
}

local function round(inst: GuiObject, radius: number, stroke: Color3?, thickness: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = stroke
		s.Thickness = thickness or 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
	end
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = CREAM
	label.TextStrokeTransparency = 0.1
	label.TextStrokeColor3 = INK
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

local function pad(inst: GuiObject, x: number, y: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, y)
	p.PaddingBottom = UDim.new(0, y)
	p.PaddingLeft = UDim.new(0, x)
	p.PaddingRight = UDim.new(0, x)
	p.Parent = inst
end

local function button(parent: Instance, y: number, height: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -14, 0.22, y)
	b.Size = UDim2.fromOffset(300, height)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.LuckiestGuy
	b.TextScaled = true
	b.TextColor3 = CREAM
	b.TextStrokeTransparency = 0.1
	b.Parent = parent
	round(b, 14, WOOD, 4)
	pad(b, 10, 8)
	return b
end

local function bar(parent: Instance, position: UDim2, size: UDim2, back: Color3, fill: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Position = position
	holder.Size = size
	holder.BackgroundColor3 = back
	holder.BorderSizePixel = 0
	holder.Parent = parent
	round(holder, 6)
	local inner = Instance.new("Frame")
	inner.Name = "Fill"
	inner.Size = UDim2.fromScale(0, 1)
	inner.BackgroundColor3 = fill
	inner.BorderSizePixel = 0
	inner.Parent = holder
	round(inner, 6)
	return inner
end

-- The contract board: three rows of goal, progress bar and reward.
local function buildContractBoard(gui: Instance): { ContractRow }
	local board = Instance.new("Frame")
	board.Name = "ContractBoard"
	board.AnchorPoint = Vector2.new(1, 0)
	board.Position = UDim2.new(1, -14, 0.22, 268)
	board.Size = UDim2.fromOffset(300, 228)
	board.BackgroundColor3 = Color3.fromRGB(205, 160, 100)
	board.Parent = gui
	round(board, 12, WOOD, 4)
	text(board, {
		Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), Text = "CONTRACTS",
		TextColor3 = Color3.fromRGB(120, 40, 20), TextStrokeTransparency = 1,
	})
	local rows = {}
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(8, 38 + (i - 1) * 62)
		row.Size = UDim2.new(1, -16, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(250, 236, 205)
		row.Parent = board
		round(row, 8, Color3.fromRGB(150, 100, 60), 2)
		local label = text(row, {
			Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 24), Text = "",
			Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(60, 34, 16), TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local reward = text(row, {
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 31), Size = UDim2.fromOffset(110, 18), Text = "",
			Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(30, 120, 30), TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local fill = bar(row, UDim2.fromOffset(8, 34), UDim2.new(1, -130, 0, 12), Color3.fromRGB(190, 160, 120), Color3.fromRGB(90, 190, 70))
		table.insert(rows, { frame = row, text = label, reward = reward, bar = fill, done = false })
	end
	return rows
end

-- The trail guide card at the bottom centre: step title, hint and four progress dots.
local function buildGuide(gui: Instance): (Frame, TextLabel, TextLabel, { Frame })
	local card = Instance.new("Frame")
	card.Name = "TrailGuide"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -12)
	card.Size = UDim2.fromOffset(700, 96)
	card.BackgroundColor3 = Color3.fromRGB(50, 30, 15)
	card.BackgroundTransparency = 0.08
	card.Parent = gui
	round(card, 14, BRASS, 3)
	local title = text(card, {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -150, 0, 40), Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD,
	})
	local hint = text(card, {
		Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -32, 0, 30), Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne,
	})
	local dots = {}
	for i = 1, 4 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -16 - (4 - i) * 30, 0, 16)
		dot.Size = UDim2.fromOffset(22, 22)
		dot.BackgroundColor3 = Color3.fromRGB(110, 80, 50)
		dot.Parent = card
		round(dot, 11, BRASS, 2)
		table.insert(dots, dot)
	end
	return card, title, hint, dots
end

-- Builds the whole HUD once (it survives respawns) and returns its parts for the update loop.
function Hud.mountRanchHud(): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "RanchHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	-- Everything sits in a centred 16:9 safe area, so a tall or very wide screen keeps the layout.
	-- Inside it, a canvas laid out in "820-pixel-high" units is scaled to fit (see fitToScreen).
	local safe = Instance.new("Frame")
	safe.Name = "SafeArea"
	safe.AnchorPoint = Vector2.new(0.5, 0.5)
	safe.Position = UDim2.fromScale(0.5, 0.5)
	safe.Size = UDim2.fromScale(1, 1)
	safe.BackgroundTransparency = 1
	safe.Parent = gui
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 16 / 9
	aspect.AspectType = Enum.AspectType.FitWithinMaxSize
	aspect.Parent = safe
	local area = Instance.new("Frame")
	area.Name = "Canvas"
	area.AnchorPoint = Vector2.new(0.5, 0.5)
	area.Position = UDim2.fromScale(0.5, 0.5)
	area.Size = UDim2.fromScale(1, 1)
	area.BackgroundTransparency = 1
	area.Parent = safe

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 6)
	panel.Size = UDim2.fromOffset(620, 96)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.06
	panel.Parent = area
	round(panel, 18, BRASS, 4)
	local cash = text(panel, {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0), Size = UDim2.fromOffset(330, 76),
		Text = "$0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD,
	})
	local cashScale = Instance.new("UIScale")
	cashScale.Parent = cash
	local income = text(panel, { Position = UDim2.fromOffset(350, 8), Size = UDim2.fromOffset(254, 44), Text = "+$0/s", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GREEN })
	local rebirths = text(panel, { Position = UDim2.fromOffset(350, 56), Size = UDim2.fromOffset(254, 28), Text = "REBIRTHS 0  x1.0", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 200, 120) })

	local eventPill = text(area, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(460, 38),
		BackgroundTransparency = 0.1, BackgroundColor3 = PANEL, Text = "", Font = Enum.Font.LuckiestGuy,
	})
	round(eventPill, 19, BRASS, 3)
	pad(eventPill, 14, 5)

	local banner = text(area, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 156), Size = UDim2.fromOffset(860, 72),
		BackgroundTransparency = 0.08, BackgroundColor3 = Color3.fromRGB(150, 30, 20), Visible = false, Text = "",
	})
	round(banner, 14, Color3.fromRGB(255, 210, 80), 4)
	pad(banner, 16, 8)
	local carry = text(area, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(640, 48),
		BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(60, 40, 10), Visible = false,
		TextColor3 = GOLD, Text = "",
	})
	round(carry, 12)

	local gateButton = button(area, 0, 60, Color3.fromRGB(60, 150, 70))
	gateButton.Text = "LOCK GATE [L]"
	local rebirthButton = button(area, 68, 60, Color3.fromRGB(150, 70, 190))
	rebirthButton.Text = "REBIRTH [R]"
	local rebirthBar = bar(area, UDim2.new(1, -302, 0.22, 134), UDim2.fromOffset(276, 10), Color3.fromRGB(40, 25, 15), Color3.fromRGB(230, 170, 255))
	local barHolder = rebirthBar.Parent :: Frame
	barHolder.AnchorPoint = Vector2.new(0, 0)
	local dexButton = button(area, 152, 50, Color3.fromRGB(190, 120, 40))
	dexButton.Text = "RANCHDEX [B]"
	local pens = text(area, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0.22, 208), Size = UDim2.fromOffset(300, 28),
		Text = "PENS 0/6", TextColor3 = Color3.fromRGB(255, 236, 190),
	})
	local luck = text(area, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0.22, 238), Size = UDim2.fromOffset(300, 24),
		Text = "", Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(170, 255, 140),
	})
	local contracts = buildContractBoard(area)
	local guide, guideTitle, guideHint, guideDots = buildGuide(area)

	local logo = text(area, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14), Size = UDim2.fromOffset(230, 54),
		Text = "ROT RANCH", TextColor3 = Color3.fromRGB(170, 240, 90), TextStrokeColor3 = Color3.fromRGB(60, 30, 10),
		BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromRGB(120, 40, 25), Rotation = -3,
	})
	round(logo, 12, BRASS, 4)
	pad(logo, 8, 4)

	local toasts = Instance.new("Frame")
	toasts.BackgroundTransparency = 1
	toasts.Position = UDim2.new(0, 14, 0.22, 0)
	toasts.Size = UDim2.fromOffset(470, 330)
	toasts.Parent = area
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = toasts

	local pops = Instance.new("Frame")
	pops.Name = "Pops"
	pops.BackgroundTransparency = 1
	pops.Size = UDim2.fromScale(1, 1)
	pops.Parent = area

	-- One scale for the whole HUD, from the screen's height, so it reads the same on a laptop or a 4K monitor.
	local scale = Instance.new("UIScale")
	scale.Parent = area
	local function fitToScreen()
		local camera = Workspace.CurrentCamera
		if camera then
			local size = camera.ViewportSize
			local s = math.clamp(math.min(size.Y, size.X * 9 / 16) / 820, 0.62, 1.3)
			-- the canvas is 1/s of the safe area, then scaled by s about its centre: it fills it exactly
			area.Size = UDim2.fromScale(1 / s, 1 / s)
			scale.Scale = s
		end
	end
	fitToScreen()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		gui = gui, area = area, cash = cash, cashScale = cashScale, income = income, rebirths = rebirths,
		eventPill = eventPill, banner = banner, carry = carry,
		gateButton = gateButton, rebirthButton = rebirthButton, dexButton = dexButton, rebirthBar = rebirthBar,
		pens = pens, luck = luck, contracts = contracts, guide = guide, guideTitle = guideTitle,
		guideHint = guideHint, guideDots = guideDots, toasts = toasts, pops = pops, shownCash = 0,
		lastCash = -1, lastBoard = "",
	}
end

local toastCount = 0
-- A message slides in on the left and fades after a few seconds.
function Hud.showToast(view: View, message: string, color: Color3)
	toastCount += 1
	local label = text(view.toasts, {
		LayoutOrder = toastCount, Size = UDim2.new(1, 0, 0, 38), Text = message, TextColor3 = color,
		BackgroundTransparency = 0.2, BackgroundColor3 = Color3.fromRGB(45, 28, 14), Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	round(label, 10)
	pad(label, 10, 4)
	local slide = Instance.new("UIScale")
	slide.Scale = 0.6
	slide.Parent = label
	TweenService:Create(slide, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local shown = view.toasts:GetChildren()
	if #shown > 7 then
		for _, c in shown do
			if c:IsA("TextLabel") and c ~= label then
				c:Destroy()
				break
			end
		end
	end
	task.delay(5, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, BackgroundTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.wait(0.5)
			label:Destroy()
		end
	end)
end

local function attr(name: string, default: any): any
	local v = player:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The next-event pill and the event banner, from the calendar's Workspace attributes.
local function refreshEvents(view: View, now: number)
	local kind = Workspace:GetAttribute("EventKind") or ""
	local phase = Workspace:GetAttribute("EventPhase") or "calm"
	local endsAt = Workspace:GetAttribute("EventEndsAt") or now
	local raidEta = attr("RaidEta", 0)
	local look = Hud.EVENTS[kind]
	if look and phase ~= "calm" then
		view.eventPill.Text = look.icon .. "  " .. look.name .. (if phase == "warning" then " INCOMING" else " NOW") .. "  " .. look.icon
		view.eventPill.BackgroundColor3 = look.color
		view.banner.Visible = true
		view.banner.BackgroundColor3 = look.color
		local left = math.max(0, math.ceil(endsAt - now))
		view.banner.Text = string.format(if phase == "warning" then look.warn else look.active, left)
		-- the banner throbs while it counts down
		view.banner.Rotation = if phase == "warning" then math.sin(now * 8) * 1.2 else 0
	else
		local nextKind = Workspace:GetAttribute("NextEventKind") or ""
		local nextAt = Workspace:GetAttribute("NextEventAt") or 0
		local nextLook = Hud.EVENTS[nextKind]
		if nextLook and nextAt > now then
			view.eventPill.Text = "NEXT: " .. nextLook.name .. "  " .. clock(nextAt - now)
			view.eventPill.BackgroundColor3 = if nextAt - now < 10 then nextLook.color else PANEL
		else
			view.eventPill.Text = "THE PRAIRIE IS QUIET"
			view.eventPill.BackgroundColor3 = PANEL
		end
		view.banner.Rotation = 0
		if raidEta > now then
			view.banner.Visible = true
			view.banner.BackgroundColor3 = Color3.fromRGB(120, 20, 40)
			view.banner.Text = string.format("RUSTLER INCOMING %ds - LOCK YOUR GATE!", math.ceil(raidEta - now))
		else
			view.banner.Visible = false
		end
	end
end

-- "2/3", or "$1.2K/$5K" for an earnings contract.
local function progressText(c: { [string]: any }): string
	if c.kind == "earn" then
		return Cast.formatCash(c.progress) .. "/" .. Cast.formatCash(c.goal)
	end
	return c.progress .. "/" .. c.goal
end

-- Re-reads the contract board when the server sends a new one.
local function refreshContracts(view: View)
	local raw = attr("Contracts", "[]")
	if raw == view.lastBoard then
		return
	end
	view.lastBoard = raw
	local ok, board = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return
	end
	for i, row in view.contracts do
		local c = board[i]
		row.frame.Visible = c ~= nil
		if c then
			local done = c.progress >= c.goal
			row.text.Text = (if done then "DONE! " else "") .. c.text .. (if c.goal > 1 and not done then "  (" .. progressText(c) .. ")" else "")
			row.reward.Text = c.reward
			row.reward.TextColor3 = if c.cash == 0 then Color3.fromRGB(40, 130, 40) else Color3.fromRGB(150, 90, 10)
			TweenService:Create(row.bar, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.clamp(c.progress / c.goal, 0, 1), 1) }):Play()
			row.frame.BackgroundColor3 = if done then Color3.fromRGB(200, 255, 170) else Color3.fromRGB(250, 236, 205)
			if done and not row.done then
				local pulse = Instance.new("UIScale")
				pulse.Parent = row.frame
				pulse.Scale = 1.12
				TweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
				task.delay(0.6, pulse.Destroy, pulse)
			end
			row.done = done
		end
	end
end

local function refreshGuide(view: View)
	local step = attr("GuideStep", 1)
	local info = Hud.GUIDE[step]
	view.guide.Visible = info ~= nil
	if info then
		view.guideTitle.Text = string.format("TRAIL %d/4 - %s", step, info.title)
		view.guideHint.Text = info.hint
		for i, dot in view.guideDots do
			dot.BackgroundColor3 = if i < step then GREEN elseif i == step then GOLD else Color3.fromRGB(110, 80, 50)
		end
	end
end

-- Per frame: rolls the cash counter toward the real value and refreshes every readout.
function Hud.refreshRanchHud(view: View, dt: number)
	local now = Workspace:GetServerTimeNow()
	local cash = attr("Cash", 0)
	if view.lastCash >= 0 and cash > view.lastCash then
		view.cashScale.Scale = math.min(1.25, view.cashScale.Scale + 0.12)
	end
	view.lastCash = cash
	view.cashScale.Scale += (1 - view.cashScale.Scale) * math.min(1, dt * 10)
	view.shownCash += (cash - view.shownCash) * math.min(1, dt * 8)
	if math.abs(cash - view.shownCash) < 1 then
		view.shownCash = cash
	end
	view.cash.Text = Cast.formatCash(view.shownCash)
	local boost = attr("Boost", 1)
	local perSecond = attr("Income", 0) * boost
	view.income.Text = "+" .. Cast.formatCash(perSecond) .. "/s" .. (if boost > 1 then "  x" .. boost else "")
	view.income.TextColor3 = if boost > 1 then GOLD else GREEN
	view.rebirths.Text = string.format("REBIRTHS %d  x%.1f", attr("Rebirths", 0), attr("Multiplier", 1))

	local lockedUntil = attr("LockedUntil", 0)
	if lockedUntil > now then
		view.gateButton.Text = string.format("GATE LOCKED %ds", math.ceil(lockedUntil - now))
		view.gateButton.BackgroundColor3 = Color3.fromRGB(170, 50, 40)
	else
		view.gateButton.Text = "LOCK GATE [L]"
		view.gateButton.BackgroundColor3 = Color3.fromRGB(60, 150, 70)
	end
	local cost = attr("RebirthCost", 20000)
	local ready = cash >= cost
	view.rebirthButton.Text = if ready then "REBIRTH NOW! [R]" else "REBIRTH " .. Cast.formatCash(cost) .. " [R]"
	view.rebirthButton.BackgroundColor3 = if ready then Color3.fromRGB(200, 90, 230) else Color3.fromRGB(150, 70, 190)
	view.rebirthButton.Rotation = if ready then math.sin(now * 6) * 2 else 0
	view.rebirthBar.Size = UDim2.fromScale(math.clamp(cash / cost, 0, 1), 1)
	view.pens.Text = string.format("PENS %d/%d", attr("StallsUsed", 0), attr("StallsOpen", Cast.BASE_STALLS))
	local luckUntil = attr("LuckUntil", 0)
	view.luck.Text = if luckUntil > now then "LUCKY HORSESHOE " .. clock(luckUntil - now) else (if attr("Luck", 0) > 0 then "DRIVE LUCK +" .. attr("Luck", 0) else "")

	refreshEvents(view, now)
	refreshContracts(view)
	refreshGuide(view)

	local carrying = attr("Carrying", "")
	view.carry.Visible = carrying ~= ""
	view.carry.Text = "CARRYING " .. string.upper(carrying) .. " - RUN IT HOME!"
end

-- A big reward pop from the middle of the screen ("+$500 BOUNTY!", "LUCKY HORSESHOE!").
function Hud.bigPop(view: View, message: string, color: Color3)
	local label = text(view.pops, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(620, 70),
		Text = message, TextColor3 = color, Rotation = math.random(-4, 4),
	})
	local s = Instance.new("UIScale")
	s.Scale = 0.2
	s.Parent = label
	TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9), {
		Position = UDim2.fromScale(0.5, 0.3), TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	task.delay(2.1, label.Destroy, label)
end

-- Floats "+$N" over each critter in your own stalls: the money you see ticking up. Pops bounce in,
-- take the critter's mutation or rarity colour, and turn gold with a "x2" during Golden Hour.
function Hud.popIncome(view: View)
	local rebirths = attr("Rebirths", 0)
	local boost = attr("Boost", 1)
	for _, ranch in Workspace:GetChildren() do
		if ranch:IsA("Model") and string.sub(ranch.Name, 1, 5) == "Ranch" then
			for _, critter in ranch:GetChildren() do
				if critter:IsA("Model") and critter:GetAttribute("OwnerUserId") == player.UserId and critter.PrimaryPart then
					local id = critter:GetAttribute("CritterId")
					local mutation = critter:GetAttribute("Mutation")
					mutation = if mutation == "" then nil else mutation
					local amount = Cast.incomeOf(id, mutation, rebirths) * boost
					local color = if boost > 1 then GOLD else Cast.mutationTint(mutation) or GREEN
					local height = critter:GetExtentsSize().Y
					local pop = Instance.new("BillboardGui")
					pop.Size = UDim2.new(3, 36, 1.2, 14)
					pop.StudsOffsetWorldSpace = Vector3.new(0, height * 0.75, 0)
					pop.StudsOffset = Vector3.new(2.5, 0, 4)
					pop.AlwaysOnTop = false
					pop.LightInfluence = 0
					pop.MaxDistance = 140
					pop.Adornee = critter.PrimaryPart
					local label = text(pop, {
						Size = UDim2.fromScale(1, 1), Text = "+" .. Cast.formatCash(amount) .. (if boost > 1 then " x" .. boost else ""),
						TextColor3 = color, Rotation = math.random(-8, 8),
					})
					local bounce = Instance.new("UIScale")
					bounce.Scale = 0.3
					bounce.Parent = label
					pop.Parent = view.gui.Parent
					TweenService:Create(bounce, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 }):Play()
					TweenService:Create(pop, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, height * 0.75 + 5, 0) }):Play()
					TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
					task.delay(1.05, pop.Destroy, pop)
				end
			end
		end
	end
end

-- The ranch's own ProximityPrompt look: a wooden tag with the key, the action ("Lasso $25",
-- "Rustle!") and the critter, and a rope bar that fills while you hold the key.
function Hud.showRanchPrompt(prompt: ProximityPrompt): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "RanchPrompt"
	gui.Adornee = prompt.Parent :: Instance
	gui.Size = UDim2.fromOffset(260, 78)
	gui.StudsOffset = Vector3.new(0, -0.5, 5)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = PANEL
	card.BackgroundTransparency = 0.05
	card.Parent = gui
	round(card, 12, BRASS, 3)
	local key = text(card, {
		Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(52, 52), Text = prompt.KeyboardKeyCode.Name,
		BackgroundTransparency = 0, BackgroundColor3 = CREAM, TextColor3 = WOOD, TextStrokeTransparency = 1,
	})
	round(key, 10)
	local isRustle = prompt:GetAttribute("Rustle") == true
	text(card, {
		Position = UDim2.fromOffset(68, 6), Size = UDim2.fromOffset(184, 38), Text = prompt.ActionText,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if isRustle then RED else GOLD,
	})
	text(card, {
		Position = UDim2.fromOffset(68, 44), Size = UDim2.fromOffset(184, 22), Text = prompt.ObjectText,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne,
	})
	local rope = Instance.new("Frame")
	rope.Name = "Hold"
	rope.Position = UDim2.new(0, 8, 1, -9)
	rope.Size = UDim2.new(0, 0, 0, 5)
	rope.BackgroundColor3 = Color3.fromRGB(196, 150, 90)
	rope.BorderSizePixel = 0
	rope.Parent = card
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function Hud.fillRanchPrompt(gui: BillboardGui, seconds: number)
	local rope = gui:FindFirstChild("Hold", true) :: Frame?
	if rope then
		rope.Size = UDim2.new(0, 0, 0, 5)
		if seconds > 0 then
			TweenService:Create(rope, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(1, -16, 0, 5) }):Play()
		end
	end
end

Hud.RED = RED
Hud.GOLD = GOLD
return Hud
