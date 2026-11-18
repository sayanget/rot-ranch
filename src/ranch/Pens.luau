-- Pens: who owns which ranch, which critter stands in which stall. Claims a ranch for each
-- rancher, flies a lassoed critter on its rope into a free stall (where it settles into an idle
-- sway), hangs a Rustle prompt on every penned critter, stocks the three rival ranches with
-- mutated herds worth rustling, and sends a rancher home when they spawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(ReplicatedStorage:WaitForChild("Critters"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Pens = {}

local plots: { World.Plot } = {}
local plotOwner: { [number]: Ledger.Account } = {}
-- Ranch claim order (indices into World's plot centres): players start in the middle north ranch
-- and then fill the south row; rival bots take the remaining north ranches and the south middle.
local PLAYER_ORDER = { 1, 5, 6, 2, 4, 3 }
local BOT_ORDER = { 3, 4, 2 }
local addRustlePrompt: (Ledger.CritterRecord) -> ()

-- Set by Rustling: what a Rustle prompt does when another rancher holds it.
Pens.rustleHandler = nil :: ((Player, Ledger.CritterRecord) -> ())?

-- The rival ranchers: each herd shows off a different corner of the cast and a mutation or two,
-- so a walk past the open gates is a preview of what the drive can roll.
local RIVALS = {
	{ name = "Dusty Dolores", color = Color3.fromRGB(255, 190, 120), rebirths = 1,
		herd = { { "toastallion" }, { "baagel", "Moldy" }, { "jackalope", "Spicy" }, { "cactopus" }, { "llamplighter" }, { "spudmoo", "Golden" } } },
	{ name = "Clem Two-Spurs", color = Color3.fromRGB(150, 210, 255), rebirths = 2,
		herd = { { "tractortoise" }, { "banjobuzzard" }, { "hamwich", "Golden" }, { "wienerbago", "Crystal" }, { "beanburro" }, { "rattlesnack" }, { "tumbleweasel" } } },
	{ name = "Granny Gristle", color = Color3.fromRGB(230, 160, 255), rebirths = 0,
		herd = { { "haybalehydra" }, { "goatcho", "Ghost" }, { "tumbleweasel" }, { "cluckaroni", "Moldy" }, { "duckwaffle" } } },
}

-- Puts a critter in a stall: it flies there on a lasso arc when `fly` (over `flight` seconds), then
-- settles into its idle sway and earns for its owner.
function Pens.placeCritterInPen(account, record, stall: number, fly: boolean?, flight: number?)
	local plot = account.plot :: World.Plot
	record.owner = account
	record.stall = stall
	record.carrier = nil
	account.stalls[stall] = record
	local model = record.model
	model:SetAttribute("OwnerKey", account.key)
	model:SetAttribute("OwnerUserId", if account.player then account.player.UserId else 0)
	model:SetAttribute("Stall", stall)
	model.Parent = plot.folder
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	local target = plot.stallCFrames[stall]
	if fly then
		local seconds = flight or 1
		local from = root.CFrame
		local apex = CFrame.new(from.Position:Lerp(target.Position, 0.5) + Vector3.new(0, 26, 0)) * target.Rotation * CFrame.Angles(0.5, 0, 0.3)
		local up = TweenService:Create(root, TweenInfo.new(seconds * 0.56, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = apex })
		up:Play()
		up.Completed:Wait()
		if record.owner ~= account or record.stall ~= stall then
			return
		end
		local down = TweenService:Create(root, TweenInfo.new(seconds * 0.44, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = target })
		down:Play()
		down.Completed:Wait()
		Critters.poof(target.Position, Color3.fromRGB(230, 200, 140), 16)
	else
		root.CFrame = target
	end
	model:SetAttribute("Gait", "idle")
	Critters.labelCritter(model, record.id, record.mutation, account.rebirths, nil)
	if not model:FindFirstChild("RustlePrompt", true) then
		addRustlePrompt(record)
	end
	Ledger.syncRancher(account)
end

function Pens.setup(builtPlots: { World.Plot })
	plots = builtPlots
	for _, plot in plots do
		World.paintStallLocks(plot, Cast.BASE_STALLS)
		World.paintGate(plot, false, 0)
	end
end

function Pens.plots(): { World.Plot }
	return plots
end

-- Paints a ranch's sign, stall locks and gate for whoever owns it now.
function Pens.paintRanch(account: Ledger.Account)
	local plot = account.plot
	if not plot then
		return
	end
	local sign = if account.isBot then string.upper(account.name) else string.upper(account.name) .. "'S RANCH"
	World.paintRanchSign(plot, sign, if account.isBot then Color3.fromRGB(255, 220, 170) else Color3.fromRGB(255, 255, 140))
	World.paintStallLocks(plot, Cast.stallsFor(account.rebirths))
end

function Pens.releaseRanch(account: Ledger.Account)
	for stall, record in account.stalls do
		record.model:Destroy()
		account.stalls[stall] = nil
	end
	if account.carrying then
		account.carrying.model:Destroy()
		account.carrying = nil
	end
	local plot = account.plot
	if plot then
		plotOwner[plot.index] = nil
		World.paintRanchSign(plot, "FOR SALE", Color3.fromRGB(255, 250, 235))
		World.paintStallLocks(plot, Cast.BASE_STALLS)
		World.paintGate(plot, false, 0)
	end
	account.plot = nil
end

-- Gives an account the first free ranch; a player evicts a rival bot when every ranch is taken.
function Pens.claimRanch(account: Ledger.Account): World.Plot?
	local order = if account.isBot then BOT_ORDER else PLAYER_ORDER
	for _, index in order do
		if plots[index] and not plotOwner[index] then
			plotOwner[index] = account
			account.plot = plots[index]
			Pens.paintRanch(account)
			return plots[index]
		end
	end
	if not account.isBot then
		for _, index in BOT_ORDER do
			local bot = plotOwner[index]
			if bot and bot.isBot then
				Pens.releaseRanch(bot)
				Ledger.closeAccount(bot)
				return Pens.claimRanch(account)
			end
		end
	end
	return nil
end

function Pens.freeStallOf(account: Ledger.Account): number?
	for i = 1, Cast.stallsFor(account.rebirths) do
		if not account.stalls[i] then
			return i
		end
	end
	return nil
end

function Pens.ownerOfPlot(index: number): Ledger.Account?
	return plotOwner[index]
end

-- Which ranch (and owner) a world position is inside, if any.
function Pens.ranchAt(position: Vector3): (World.Plot?, Ledger.Account?)
	for _, plot in plots do
		if World.ranchContains(plot, position) then
			return plot, plotOwner[plot.index]
		end
	end
	return nil, nil
end

-- Lifts a critter out of its stall (for a rustler or a rebirth); it stops earning at once.
function Pens.takeCritterFromPen(record: Ledger.CritterRecord): Ledger.Account?
	local owner = record.owner
	if owner and record.stall and owner.stalls[record.stall] == record then
		owner.stalls[record.stall] = nil
		Ledger.syncRancher(owner)
	end
	return owner
end

function addRustlePrompt(record: Ledger.CritterRecord)
	local root = record.model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RustlePrompt"
	prompt.ActionText = "Rustle!"
	-- Name the mutation too, the same way the drive's Lasso prompt does, so a Golden one stands out.
	prompt.ObjectText = (if record.mutation then record.mutation .. " " else "") .. Cast.critterById(record.id).name
	prompt.HoldDuration = 1.2
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Rustle", true)
	prompt.Parent = root:FindFirstChild("PromptPoint") or root
	prompt.Triggered:Connect(function(player)
		local handler = Pens.rustleHandler
		if handler and record.owner and record.owner.player ~= player then
			handler(player, record)
		end
	end)
end

-- Builds a critter record already standing in an account's stall (rival herds, Showcase stocking):
-- no lasso flight, but a player's stocked critter still lands in their RanchDex.
function Pens.stockCritter(account: Ledger.Account, id: string, mutation: string?, stall: number?): Ledger.CritterRecord?
	local slot = stall or Pens.freeStallOf(account)
	if not slot or not account.plot then
		return nil
	end
	local model = Critters.buildCritter(id, mutation, account.plot.stallCFrames[slot])
	local record: Ledger.CritterRecord = { id = id, mutation = mutation, model = model, owner = nil, stall = nil, carrier = nil }
	Pens.placeCritterInPen(account, record, slot, false)
	if not account.isBot then
		Ledger.discover(account, id, mutation)
		Ledger.syncBoard(account)
	end
	return record
end

-- The three rival ranchers: bots with herds worth rustling and gates that open and close.
function Pens.openRivalRanches()
	for _, rival in RIVALS do
		local account = Ledger.openBotAccount(rival.name, 0, rival.rebirths)
		if Pens.claimRanch(account) then
			for _, entry in rival.herd do
				Pens.stockCritter(account, entry[1], entry[2])
			end
		else
			Ledger.closeAccount(account)
		end
	end
end

-- Puts a character's parts in its ranch's rancher group (so its own locked gate lets it through)
-- and drops it in the middle of its ranch.
function Pens.sendRancherHome(player: Player, character: Model)
	local account = Ledger.accountOf(player)
	if not account or not account.plot then
		return
	end
	local plot = account.plot
	local function group(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = plot.rancherGroup
		end
	end
	for _, d in character:GetDescendants() do
		group(d)
	end
	character.DescendantAdded:Connect(group)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root then
		task.wait()
		character:PivotTo(plot.cf * CFrame.new(0, 4, 2))
	end
end

function Pens.playerOfRecord(record: Ledger.CritterRecord): Player?
	return record.owner and record.owner.player or nil
end

function Pens.anyPlayer(): Player?
	return Players:GetPlayers()[1]
end

return Pens
