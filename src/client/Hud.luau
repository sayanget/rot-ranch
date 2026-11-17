-- Hud: the rancher's ScreenGui over the 3D ranch. Big cash / income / rebirth panel at the top
-- centre (clear of Roblox's top-left menu), the gate and rebirth buttons on the right, stampede and
-- rustler banners, a carrying banner, toasts, the one-line tutorial, and "+$" pops over your herd.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))

local Hud = {}

local player = Players.LocalPlayer
local CREAM = Color3.fromRGB(255, 246, 225)
local WOOD = Color3.fromRGB(92, 58, 34)
local GREEN = Color3.fromRGB(120, 255, 110)
local RED = Color3.fromRGB(255, 80, 70)

export type View = {
	gui: ScreenGui, cash: TextLabel, income: TextLabel, rebirths: TextLabel, nextStampede: TextLabel,
	banner: TextLabel, carry: TextLabel, gateButton: TextButton, rebirthButton: TextButton,
	rebirthBar: Frame, pens: TextLabel, toasts: Frame, shownCash: number,
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
	label.TextStrokeColor3 = Color3.fromRGB(40, 20, 8)
	for k, v in props do
		(label :: any)[k] = v
	end
	label.Parent = parent
	return label
end

local function button(parent: Instance, y: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = UDim2.new(1, -14, 0.3, y)
	b.Size = UDim2.fromOffset(270, 74)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.LuckiestGuy
	b.TextScaled = true
	b.TextColor3 = CREAM
	b.TextStrokeTransparency = 0.1
	b.Parent = parent
	round(b, 14, WOOD, 4)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	return b
end

-- Builds the whole HUD once (it survives respawns) and returns its parts for the update loop.
function Hud.mountRanchHud(): View
	local gui = Instance.new("ScreenGui")
	gui.Name = "RanchHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 6)
	panel.Size = UDim2.fromOffset(600, 108)
	panel.BackgroundColor3 = Color3.fromRGB(70, 42, 22)
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	round(panel, 18, Color3.fromRGB(240, 190, 90), 4)
	local cash = text(panel, { Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(320, 72), Text = "$0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 225, 90) })
	local income = text(panel, { Position = UDim2.fromOffset(340, 8), Size = UDim2.fromOffset(250, 44), Text = "+$0/s", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = GREEN })
	local rebirths = text(panel, { Position = UDim2.fromOffset(340, 54), Size = UDim2.fromOffset(250, 28), Text = "REBIRTHS 0  x1.0", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 200, 120) })
	local nextStampede = text(panel, { Position = UDim2.fromOffset(16, 80), Size = UDim2.fromOffset(568, 22), Text = "", Font = Enum.Font.FredokaOne, TextColor3 = Color3.fromRGB(255, 220, 180) })

	local banner = text(gui, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(820, 70),
		BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(150, 30, 20), Visible = false, Text = "",
	})
	round(banner, 14, Color3.fromRGB(255, 210, 80), 4)
	local carry = text(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(640, 48),
		BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(60, 40, 10), Visible = false,
		TextColor3 = Color3.fromRGB(255, 225, 90), Text = "",
	})
	round(carry, 12)

	local gateButton = button(gui, 0, Color3.fromRGB(60, 150, 70))
	gateButton.Text = "LOCK GATE [L]"
	local rebirthButton = button(gui, 86, Color3.fromRGB(150, 70, 190))
	rebirthButton.Text = "REBIRTH [R]"
	local barBack = Instance.new("Frame")
	barBack.AnchorPoint = Vector2.new(1, 0)
	barBack.Position = UDim2.new(1, -24, 0.3, 164)
	barBack.Size = UDim2.fromOffset(250, 12)
	barBack.BackgroundColor3 = Color3.fromRGB(40, 25, 15)
	barBack.Parent = gui
	round(barBack, 6)
	local rebirthBar = Instance.new("Frame")
	rebirthBar.Size = UDim2.fromScale(0, 1)
	rebirthBar.BackgroundColor3 = Color3.fromRGB(230, 170, 255)
	rebirthBar.Parent = barBack
	round(rebirthBar, 6)
	local pens = text(gui, {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0.3, 184), Size = UDim2.fromOffset(270, 36),
		Text = "PENS 0/6", TextColor3 = Color3.fromRGB(255, 236, 190),
	})

	local tutorial = text(gui, {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(0.9, 0, 0, 34),
		BackgroundTransparency = 0.3, BackgroundColor3 = Color3.fromRGB(50, 30, 15), Font = Enum.Font.FredokaOne,
		Text = "LASSO critters off the Cattle Drive (E)  >  they earn $/s in YOUR pens  >  RUSTLE from open gates, LOCK yours (L)  >  STAMPEDE: get off the drive!",
	})
	round(tutorial, 10)
	local tutorialSize = Instance.new("UITextSizeConstraint")
	tutorialSize.MaxTextSize = 22
	tutorialSize.Parent = tutorial

	local logo = text(gui, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -52), Size = UDim2.fromOffset(250, 58),
		Text = "ROT RANCH", TextColor3 = Color3.fromRGB(170, 240, 90), TextStrokeColor3 = Color3.fromRGB(60, 30, 10),
		BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromRGB(120, 40, 25), Rotation = -3,
	})
	round(logo, 12, Color3.fromRGB(240, 190, 90), 4)

	local toasts = Instance.new("Frame")
	toasts.BackgroundTransparency = 1
	toasts.Position = UDim2.new(0, 14, 0.3, 0)
	toasts.Size = UDim2.fromOffset(470, 300)
	toasts.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = toasts

	-- One scale for the whole HUD, from the screen's height, so it reads the same on a laptop or a 4K monitor.
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fitToScreen()
		local camera = Workspace.CurrentCamera
		if camera then
			scale.Scale = math.clamp(camera.ViewportSize.Y / 820, 0.62, 1.3)
		end
	end
	fitToScreen()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return {
		gui = gui, cash = cash, income = income, rebirths = rebirths, nextStampede = nextStampede,
		banner = banner, carry = carry, gateButton = gateButton, rebirthButton = rebirthButton,
		rebirthBar = rebirthBar, pens = pens, toasts = toasts, shownCash = 0,
	}
end

local toastCount = 0
-- A message slides in on the left and fades after a few seconds.
function Hud.showToast(view: View, message: string, color: Color3)
	toastCount += 1
	local label = text(view.toasts, {
		LayoutOrder = toastCount, Size = UDim2.new(1, 0, 0, 40), Text = message, TextColor3 = color,
		BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(45, 28, 14), Font = Enum.Font.FredokaOne,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	round(label, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = label
	local shown = view.toasts:GetChildren()
	if #shown > 7 then
		for _, c in shown do
			if c:IsA("TextLabel") and c ~= label then
				c:Destroy()
				break
			end
		end
	end
	task.delay(4.5, function()
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

-- Per frame: rolls the cash counter toward the real value and refreshes every countdown.
function Hud.refreshRanchHud(view: View, dt: number)
	local now = Workspace:GetServerTimeNow()
	local cash = attr("Cash", 0)
	view.shownCash += (cash - view.shownCash) * math.min(1, dt * 8)
	if math.abs(cash - view.shownCash) < 1 then
		view.shownCash = cash
	end
	view.cash.Text = Cast.formatCash(view.shownCash)
	view.income.Text = "+" .. Cast.formatCash(attr("Income", 0)) .. "/s"
	view.rebirths.Text = string.format("REBIRTHS %d  x%.1f", attr("Rebirths", 0), attr("Multiplier", 1))

	local lockedUntil = attr("LockedUntil", 0)
	if lockedUntil > now then
		view.gateButton.Text = string.format("GATE LOCKED %ds", math.ceil(lockedUntil - now))
		view.gateButton.BackgroundColor3 = Color3.fromRGB(170, 50, 40)
	else
		view.gateButton.Text = "LOCK GATE [L]  READY"
		view.gateButton.BackgroundColor3 = Color3.fromRGB(60, 150, 70)
	end
	local cost = attr("RebirthCost", 25000)
	view.rebirthButton.Text = "REBIRTH " .. Cast.formatCash(cost) .. " [R]"
	view.rebirthBar.Size = UDim2.fromScale(math.clamp(cash / cost, 0, 1), 1)
	view.pens.Text = string.format("PENS %d/%d", attr("StallsUsed", 0), attr("StallsOpen", Cast.BASE_STALLS))

	local phase = Workspace:GetAttribute("StampedePhase")
	local at = Workspace:GetAttribute("StampedeAt") or now
	local raidEta = attr("RaidEta", 0)
	if phase == "warning" then
		view.banner.Visible = true
		view.banner.BackgroundColor3 = Color3.fromRGB(150, 30, 20)
		view.banner.Text = string.format("STAMPEDE IN %d - GET OFF THE DRIVE!", math.max(0, math.ceil(at - now)))
	elseif phase == "charging" then
		view.banner.Visible = true
		view.banner.BackgroundColor3 = Color3.fromRGB(110, 60, 20)
		view.banner.Text = "THE ROT HERD IS LOOSE! STAY BEHIND A FENCE!"
	elseif raidEta > now then
		view.banner.Visible = true
		view.banner.BackgroundColor3 = Color3.fromRGB(120, 20, 40)
		view.banner.Text = string.format("RUSTLER INCOMING %ds - LOCK YOUR GATE!", math.ceil(raidEta - now))
	else
		view.banner.Visible = false
	end
	local left = math.max(0, math.floor(at - now))
	view.nextStampede.Text = if phase == "calm" then string.format("next stampede in %d:%02d", left // 60, left % 60) else "STAMPEDE!"

	local carrying = attr("Carrying", "")
	view.carry.Visible = carrying ~= ""
	view.carry.Text = "CARRYING " .. string.upper(carrying) .. " - RUN IT HOME!"
end

-- Floats "+$N" over each critter in your own stalls: the money you see ticking up.
function Hud.popIncome(view: View)
	local rebirths = attr("Rebirths", 0)
	for _, ranch in Workspace:GetChildren() do
		if ranch:IsA("Model") and string.sub(ranch.Name, 1, 5) == "Ranch" then
			for _, critter in ranch:GetChildren() do
				if critter:IsA("Model") and critter:GetAttribute("OwnerUserId") == player.UserId and critter.PrimaryPart then
					local mutation = critter:GetAttribute("Mutation")
					local amount = Cast.incomeOf(critter:GetAttribute("CritterId"), if mutation == "" then nil else mutation, rebirths)
					local height = critter:GetExtentsSize().Y
					local pop = Instance.new("BillboardGui")
					pop.Size = UDim2.new(4, 40, 1.4, 16)
					pop.StudsOffsetWorldSpace = Vector3.new(0, height * 0.75, 0)
					pop.StudsOffset = Vector3.new(2.5, 0, 4)
					pop.AlwaysOnTop = false
					pop.LightInfluence = 0
					pop.Adornee = critter.PrimaryPart
					local label = text(pop, { Size = UDim2.fromScale(1, 1), Text = "+" .. Cast.formatCash(amount), TextColor3 = GREEN })
					pop.Parent = view.gui.Parent
					TweenService:Create(pop, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, height * 0.75 + 4, 0) }):Play()
					TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.55), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
					task.delay(1, pop.Destroy, pop)
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
	gui.Size = UDim2.fromOffset(250, 78)
	gui.StudsOffset = Vector3.new(0, -0.5, 5)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.fromRGB(70, 42, 22)
	card.BackgroundTransparency = 0.05
	card.Parent = gui
	round(card, 12, Color3.fromRGB(240, 190, 90), 3)
	local key = text(card, {
		Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(52, 52), Text = prompt.KeyboardKeyCode.Name,
		BackgroundTransparency = 0, BackgroundColor3 = CREAM, TextColor3 = WOOD, TextStrokeTransparency = 1,
	})
	round(key, 10)
	local isRustle = prompt:GetAttribute("Rustle") == true
	text(card, {
		Position = UDim2.fromOffset(68, 6), Size = UDim2.fromOffset(176, 38), Text = prompt.ActionText,
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if isRustle then RED else Color3.fromRGB(255, 225, 90),
	})
	text(card, {
		Position = UDim2.fromOffset(68, 44), Size = UDim2.fromOffset(176, 22), Text = prompt.ObjectText,
		TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.FredokaOne,
	})
	local bar = Instance.new("Frame")
	bar.Name = "Hold"
	bar.Position = UDim2.new(0, 8, 1, -9)
	bar.Size = UDim2.new(0, 0, 0, 5)
	bar.BackgroundColor3 = GREEN
	bar.BorderSizePixel = 0
	bar.Parent = card
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function Hud.fillRanchPrompt(gui: BillboardGui, seconds: number)
	local bar = gui:FindFirstChild("Hold", true) :: Frame?
	if bar then
		bar.Size = UDim2.new(0, 0, 0, 5)
		if seconds > 0 then
			TweenService:Create(bar, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(1, -16, 0, 5) }):Play()
		end
	end
end

Hud.RED = RED
return Hud
