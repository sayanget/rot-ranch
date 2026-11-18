-- RanchDex: the rancher's field book of every critter in the cast. A grid of cards, one per critter,
-- each with a slowly turning 3D portrait (a black ??? silhouette until you have caught one), its
-- rarity, its $/s and five mutation pips that light up as you find Moldy, Golden, Spicy, Crystal and
-- Ghost ones. Opens with B or the HUD button; reads the "Dex" attribute the server keeps.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(ReplicatedStorage:WaitForChild("Critters"))

local RanchDex = {}

local player = Players.LocalPlayer
local CREAM = Color3.fromRGB(255, 246, 225)
local INK = Color3.fromRGB(40, 20, 8)

type Card = {
	critter: Cast.Critter, frame: Frame, viewport: ViewportFrame, camera: Camera, name: TextLabel,
	rate: TextLabel, pips: { Frame }, model: Model?, shownAs: string, center: Vector3, radius: number,
}

local cards: { Card } = {}
local panel: Frame? = nil
local counter: TextLabel? = nil
local lastDex = ""
local open = false
local spin = 0

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.Font = Enum.Font.LuckiestGuy
	l.TextColor3 = CREAM
	l.TextStrokeTransparency = 0.2
	l.TextStrokeColor3 = INK
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function corner(inst: GuiObject, radius: number, stroke: Color3?, thickness: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	if stroke then
		local s = Instance.new("UIStroke")
		s.Color = stroke
		s.Thickness = thickness or 2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = inst
	end
end

-- The rarest mutation found of a critter (the portrait wears it), or "Normal", or "" if unseen.
local function bestFound(found: { string }?): string
	if not found or #found == 0 then
		return ""
	end
	local best, bestMult = "Normal", 1
	for _, key in found do
		local mult = Cast.mutationMult(key)
		if mult > bestMult then
			best, bestMult = key, mult
		end
	end
	return best
end

-- Swaps a card's portrait: the critter in its best-found finish, or a silhouette.
local function paintPortrait(card: Card, shownAs: string)
	if card.shownAs == shownAs and card.model then
		return
	end
	card.shownAs = shownAs
	if card.model then
		card.model:Destroy()
	end
	local mutation = if shownAs ~= "" and shownAs ~= "Normal" then shownAs else nil
	local model = Critters.buildPortrait(card.critter.id, mutation, shownAs == "")
	local cf, size = model:GetBoundingBox()
	card.center = cf.Position
	card.radius = math.max(size.X, size.Y, size.Z)
	model.Parent = card.viewport
	card.model = model
end

local function buildCard(grid: Instance, critter: Cast.Critter, order: number): Card
	local rarity = Cast.RARITIES[critter.rarity]
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Color3.fromRGB(70, 44, 26)
	frame.Parent = grid
	corner(frame, 10, rarity.color, 3)
	local viewport = Instance.new("ViewportFrame")
	viewport.Position = UDim2.fromOffset(6, 6)
	viewport.Size = UDim2.new(1, -12, 0, 92)
	viewport.BackgroundColor3 = Color3.fromRGB(250, 226, 180)
	viewport.Ambient = Color3.fromRGB(170, 150, 130)
	viewport.LightColor = Color3.fromRGB(255, 240, 210)
	viewport.LightDirection = Vector3.new(-1, -1.5, -1)
	viewport.Parent = frame
	corner(viewport, 8)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local name = label(frame, { Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, -8, 0, 22), Text = "???" })
	label(frame, {
		Position = UDim2.fromOffset(4, 122), Size = UDim2.new(1, -8, 0, 16), Text = string.upper(rarity.id),
		TextColor3 = rarity.color, Font = Enum.Font.FredokaOne,
	})
	local rate = label(frame, {
		Position = UDim2.fromOffset(4, 139), Size = UDim2.new(1, -8, 0, 16), Text = "",
		TextColor3 = Color3.fromRGB(130, 255, 120), Font = Enum.Font.FredokaOne,
	})
	local pips = {}
	for i, m in Cast.MUTATIONS do
		local pip = Instance.new("Frame")
		pip.AnchorPoint = Vector2.new(0.5, 0)
		pip.Position = UDim2.new(0.5, (i - 3) * 20, 0, 158)
		pip.Size = UDim2.fromOffset(14, 14)
		pip.BackgroundColor3 = Color3.fromRGB(50, 34, 22)
		pip.Parent = frame
		corner(pip, 7, m.tint, 2)
		table.insert(pips, pip)
	end
	return {
		critter = critter, frame = frame, viewport = viewport, camera = camera, name = name, rate = rate,
		pips = pips, model = nil, shownAs = "?", center = Vector3.zero, radius = 8,
	}
end

-- Builds the book once: a wooden panel, a header with the count, the grid, and the mutation legend.
function RanchDex.mountRanchDex(gui: Instance)
	local book = Instance.new("Frame")
	book.Name = "RanchDex"
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.53)
	book.Size = UDim2.fromOffset(1010, 640)
	book.BackgroundColor3 = Color3.fromRGB(120, 76, 42)
	book.Visible = false
	book.ZIndex = 5
	book.Parent = gui
	corner(book, 18, Color3.fromRGB(240, 190, 90), 5)
	label(book, {
		Position = UDim2.fromOffset(20, 8), Size = UDim2.fromOffset(420, 52), Text = "RANCHDEX",
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 215, 70),
	})
	counter = label(book, {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(360, 38),
		Text = "0 / " .. #Cast.CRITTERS .. " FOUND", Font = Enum.Font.FredokaOne,
	})
	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 12)
	close.Size = UDim2.fromOffset(150, 44)
	close.BackgroundColor3 = Color3.fromRGB(170, 50, 40)
	close.Text = "CLOSE [B]"
	close.Font = Enum.Font.LuckiestGuy
	close.TextScaled = true
	close.TextColor3 = CREAM
	close.Parent = book
	corner(close, 10)
	close.Activated:Connect(function()
		RanchDex.setOpen(false)
	end)

	local scroller = Instance.new("ScrollingFrame")
	scroller.Position = UDim2.fromOffset(14, 66)
	scroller.Size = UDim2.new(1, -28, 1, -126)
	scroller.BackgroundTransparency = 1
	scroller.ScrollBarThickness = 8
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.CanvasSize = UDim2.new()
	scroller.Parent = book
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(132, 176)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroller
	for i, critter in Cast.CRITTERS do
		table.insert(cards, buildCard(scroller, critter, i))
	end

	-- The mutation legend along the bottom.
	local legend = Instance.new("Frame")
	legend.AnchorPoint = Vector2.new(0.5, 1)
	legend.Position = UDim2.new(0.5, 0, 1, -10)
	legend.Size = UDim2.new(1, -28, 0, 44)
	legend.BackgroundColor3 = Color3.fromRGB(70, 44, 26)
	legend.Parent = book
	corner(legend, 10)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 14)
	row.Parent = legend
	label(legend, { Size = UDim2.fromOffset(130, 30), Text = "MUTATIONS", TextColor3 = Color3.fromRGB(255, 215, 70) })
	for _, m in Cast.MUTATIONS do
		label(legend, {
			Size = UDim2.fromOffset(150, 30), Text = string.upper(m.id) .. " x" .. m.mult,
			TextColor3 = m.tint, Font = Enum.Font.LuckiestGuy,
		})
	end
	panel = book

	RunService.RenderStepped:Connect(function(dt)
		if not open then
			return
		end
		spin += dt * 0.6
		for i, card in cards do
			local angle = spin + i * 0.4
			local dist = card.radius * 1.75
			local eye = card.center + Vector3.new(math.sin(angle) * dist, card.radius * 0.45, -math.cos(angle) * dist)
			card.camera.CFrame = CFrame.lookAt(eye, card.center)
		end
	end)
end

-- Repaints every card from the server's Dex attribute (only when it changed).
function RanchDex.refresh()
	local raw = player:GetAttribute("Dex") or "{}"
	if raw == lastDex and #cards > 0 and cards[1].model then
		return
	end
	lastDex = raw
	local ok, dex = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(dex) ~= "table" then
		dex = {}
	end
	local count = 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	for _, card in cards do
		local found = dex[card.critter.id]
		local best = bestFound(found)
		paintPortrait(card, best)
		if best ~= "" then
			count += 1
			card.name.Text = card.critter.name
			card.rate.Text = Cast.formatCash(Cast.incomeOf(card.critter.id, nil, rebirths)) .. "/s"
			card.frame.BackgroundColor3 = Color3.fromRGB(96, 60, 32)
		else
			card.name.Text = "???"
			card.rate.Text = "lasso one to find out"
			card.frame.BackgroundColor3 = Color3.fromRGB(56, 36, 22)
		end
		for i, m in Cast.MUTATIONS do
			local has = found ~= nil and table.find(found, m.id) ~= nil
			card.pips[i].BackgroundColor3 = if has then m.tint else Color3.fromRGB(50, 34, 22)
		end
	end
	if counter then
		counter.Text = count .. " / " .. #Cast.CRITTERS .. " FOUND"
	end
end

function RanchDex.setOpen(want: boolean)
	local book = panel
	if not book then
		return
	end
	open = want
	if want then
		RanchDex.refresh()
		book.Visible = true
		local pop = book:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		pop.Scale = 0.85
		pop.Parent = book
		TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		book.Visible = false
	end
end

function RanchDex.toggle()
	RanchDex.setOpen(not open)
end

function RanchDex.isOpen(): boolean
	return open
end

return RanchDex
