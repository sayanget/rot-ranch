-- DustDevil: the ranch's second hazard, and not another stampede. The sky bruises purple, a twister
-- spins up at the edge of the map and snakes along a ROW OF RANCHES (not the drive), swinging in and
-- out of the paddocks. Anyone it catches is flung skyward and spills a cut of their cash as coins;
-- only a rancher standing inside a LOCKED ranch is sheltered. It also spits lucky coins along its
-- path: brave ranchers chase it to grab them, at the risk of being swept up.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Events = require(script.Parent:WaitForChild("Events"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Pens = require(script.Parent:WaitForChild("Pens"))
local Stampede = require(script.Parent:WaitForChild("Stampede"))
local Mood = require(script.Parent:WaitForChild("Workshop"):WaitForChild("Mood"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(ReplicatedStorage:WaitForChild("Critters"))

local DustDevil = {}

DustDevil.WARNING = 7
DustDevil.SPEED = 17
DustDevil.REACH = 9 -- how close (horizontally) the funnel has to be to sweep you up
DustDevil.COIN_EVERY = 0.55
DustDevil.COIN_LIFE = 24

local PURPLE = Color3.fromRGB(190, 140, 255)
local rng = Random.new()

type Twister = { model: Model, core: BasePart, rings: { BasePart }, junk: { BasePart } }
type Coin = { part: BasePart, value: number, born: number, base: Vector3 }

local coins: { Coin } = {}
local coinFolder: Folder? = nil

local function part(parent: Instance, size: Vector3, color: Color3, material: Enum.Material, transparency: number, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Size = size
	p.Color = color
	p.Material = material
	p.Transparency = transparency
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

-- The funnel: stacked spinning rings that widen as they rise, a vortex of dust and orbiting junk.
local function buildTwister(at: Vector3): Twister
	local model = Instance.new("Model")
	model.Name = "DustDevil"
	local core = part(model, Vector3.new(4, 4, 4), PURPLE, Enum.Material.SmoothPlastic, 1)
	core.Position = at
	local rings = {}
	for i = 1, 11 do
		local d = 5 + i * 3.4
		local ring = part(model, Vector3.new(4.2, d, d), Color3.fromRGB(120 + i * 6, 80 + i * 5, 165 + i * 6),
			if i % 3 == 0 then Enum.Material.ForceField else Enum.Material.SmoothPlastic, 0.12 + i * 0.03, Enum.PartType.Cylinder)
		table.insert(rings, ring)
	end
	-- a glowing core up the middle of the funnel
	local spine = part(model, Vector3.new(48, 3.5, 3.5), Color3.fromRGB(220, 160, 255), Enum.Material.Neon, 0.35, Enum.PartType.Cylinder)
	spine.Name = "Spine"
	local junk = {}
	for i = 1, 6 do
		local bit = if i % 3 == 0
			then part(model, Vector3.new(3, 1.6, 1.6), Color3.fromRGB(226, 190, 100), Enum.Material.Fabric, 0)
			else part(model, Vector3.new(2.4, 2.4, 2.4), Color3.fromRGB(150, 110, 70), Enum.Material.Grass, 0.1, Enum.PartType.Ball)
		table.insert(junk, bit)
	end
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/forcefield_vortex_main.dds"
	swirl.Rate = 30
	swirl.Lifetime = NumberRange.new(1.2, 2)
	swirl.Speed = NumberRange.new(10, 18)
	swirl.EmissionDirection = Enum.NormalId.Top
	swirl.SpreadAngle = Vector2.new(20, 20)
	swirl.RotSpeed = NumberRange.new(200, 400)
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 22) })
	swirl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	swirl.Color = ColorSequence.new(PURPLE, Color3.fromRGB(120, 90, 140))
	swirl.LightEmission = 0.4
	swirl.Parent = core
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Rate = 40
	dust.Lifetime = NumberRange.new(1.5, 2.5)
	dust.Speed = NumberRange.new(8, 14)
	dust.SpreadAngle = Vector2.new(80, 80)
	dust.Size = NumberSequence.new(4, 12)
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.Color = ColorSequence.new(Color3.fromRGB(170, 140, 160))
	dust.Parent = core
	local light = Instance.new("PointLight")
	light.Color = PURPLE
	light.Range = 40
	light.Brightness = 3
	light.Parent = core
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(16, 60, 3, 14)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 46, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "DUST DEVIL!"
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = Color3.fromRGB(230, 200, 255)
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.fromRGB(60, 20, 80)
	label.Parent = gui
	gui.Parent = core
	model.PrimaryPart = core
	model.Parent = Workspace
	return { model = model, core = core, rings = rings, junk = junk }
end

-- Poses the funnel around a ground point; grow (0..1) lets it spin up during the warning.
local function spinTwister(twister: Twister, at: Vector3, t: number, grow: number)
	twister.core.Position = at + Vector3.new(0, 2, 0)
	local spine = twister.model:FindFirstChild("Spine") :: BasePart?
	if spine then
		spine.CFrame = CFrame.new(at + Vector3.new(0, 24 * grow, 0)) * CFrame.Angles(0, t * 6, math.pi / 2)
		spine.Size = Vector3.new(48 * grow + 1, 3.5, 3.5)
	end
	for i, ring in twister.rings do
		local sway = Vector3.new(math.sin(t * 1.7 + i * 0.6), 0, math.cos(t * 1.3 + i * 0.5)) * i * 0.45
		local y = 1.5 + i * 4.4 * grow
		ring.CFrame = CFrame.new(at + sway + Vector3.new(0, y, 0)) * CFrame.Angles(0, t * (4 + i * 0.3), 0) * CFrame.Angles(0, 0, math.pi / 2)
	end
	for i, bit in twister.junk do
		local a = t * (2.6 - i * 0.15) + i * 1.05
		local r = 9 + (i % 3) * 3
		bit.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, (8 + i * 5) * grow, math.sin(a) * r)) * CFrame.Angles(t * 3, t * 2, i)
	end
end

local function coinValue(): number
	local best = 0
	for _, account in Ledger.players() do
		best = math.max(best, Ledger.incomeOf(account))
	end
	return math.max(20, math.floor(best * 2.5))
end

-- A spinning gold coin on the ground; whoever touches it first banks its value.
function DustDevil.dropCoin(at: Vector3, value: number, fling: Vector3?)
	if not coinFolder then
		local folder = Instance.new("Folder")
		folder.Name = "TwisterCoins"
		folder.Parent = Workspace
		coinFolder = folder
	end
	local coin = part(coinFolder :: Folder, Vector3.new(0.5, 2.8, 2.8), Color3.fromRGB(255, 205, 50), Enum.Material.Metal, 0, Enum.PartType.Cylinder)
	coin.Reflectance = 0.35
	coin.CanTouch = true
	local landing = Vector3.new(at.X, 2.2, at.Z) + (fling or Vector3.zero)
	coin.Position = landing
	local shine = Instance.new("ParticleEmitter")
	shine.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	shine.Rate = 3
	shine.Lifetime = NumberRange.new(0.6, 1)
	shine.Speed = NumberRange.new(1, 2)
	shine.Size = NumberSequence.new(0.6)
	shine.LightEmission = 1
	shine.Color = ColorSequence.new(Color3.fromRGB(255, 230, 120))
	shine.Parent = coin
	local entry: Coin = { part = coin, value = value, born = os.clock(), base = landing }
	table.insert(coins, entry)
	coin.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local account = player and Ledger.accountOf(player)
		if not account or not coin.Parent then
			return
		end
		coin:Destroy()
		Ledger.addCash(account, entry.value)
		Ledger.cue(account, "coin", entry.value)
		Ledger.deed(account, { kind = "coin", amount = entry.value })
	end)
end

-- Spins every coin and clears the old ones (runs for as long as the server does).
local function tickCoins(t: number)
	for i = #coins, 1, -1 do
		local c = coins[i]
		if not c.part.Parent or os.clock() - c.born > DustDevil.COIN_LIFE then
			if c.part.Parent then
				c.part:Destroy()
			end
			table.remove(coins, i)
		else
			c.part.CFrame = CFrame.new(c.base + Vector3.new(0, math.sin(t * 3 + i) * 0.4, 0)) * CFrame.Angles(0, t * 3 + i, 0)
		end
	end
end

-- Is this rancher sheltered from the twister (inside a ranch whose gate is locked)?
local function sheltered(position: Vector3): boolean
	local _, owner = Pens.ranchAt(position)
	return owner ~= nil and Ledger.isLocked(owner)
end

function DustDevil.startDustDevil(_arg: any?)
	local row = if rng:NextNumber() < 0.5 then -42 else 42
	local westToEast = rng:NextNumber() < 0.5
	local fromX, toX = if westToEast then -175 else 175, if westToEast then 175 else -175
	local function pathAt(x: number): Vector3
		return Vector3.new(x, 0, row + math.sin(x / 23) * 16)
	end
	local now = Workspace:GetServerTimeNow()
	Events.setPhase("dustdevil", "warning", now + DustDevil.WARNING)
	Mood.set("dust", DustDevil.WARNING)
	Ledger.cueAll("dustWarn", DustDevil.WARNING)
	local side = if row < 0 then "NORTH" else "SOUTH"
	Ledger.toastAll("A DUST DEVIL is spinning up on the " .. side .. " ranches! Lock your gate or keep clear!", PURPLE)
	local twister = buildTwister(pathAt(fromX))
	local t = 0
	while t < DustDevil.WARNING do
		t += RunService.Heartbeat:Wait()
		spinTwister(twister, pathAt(fromX), t, math.clamp(t / DustDevil.WARNING, 0.15, 1))
	end

	local travel = math.abs(toX - fromX) / DustDevil.SPEED
	Events.setPhase("dustdevil", "active", Workspace:GetServerTimeNow() + travel)
	Ledger.cueAll("dustDevil", travel)
	local x = fromX
	local step = if toX > fromX then 1 else -1
	local nextCoin = 0
	while (toX - x) * step > 0 do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		x += step * DustDevil.SPEED * dt
		local at = pathAt(x)
		spinTwister(twister, at, t, 1)
		nextCoin -= dt
		if nextCoin <= 0 then
			nextCoin = DustDevil.COIN_EVERY
			local a = rng:NextNumber() * math.pi * 2
			DustDevil.dropCoin(at, coinValue(), Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(10, 18))
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
				if flat.Magnitude < DustDevil.REACH and not sheltered(root.Position) then
					local lost = Stampede.trampleRancher(player, Cast.DUST_DEVIL_CASH_SPILLED, "twister")
					local pieces = math.clamp(math.floor(lost / 25), 0, 6)
					for i = 1, pieces do
						local a = i * math.pi * 2 / pieces
						DustDevil.dropCoin(root.Position, math.floor(lost / pieces), Vector3.new(math.cos(a), 0, math.sin(a)) * 12)
					end
				end
			end
		end
	end
	Critters.poof(twister.core.Position + Vector3.new(0, 6, 0), PURPLE, 40)
	twister.model:Destroy()
	Mood.set("normal", 5)
	Ledger.cueAll("allClear")
	Ledger.toastAll("The Dust Devil blew itself out. Grab the coins it left behind!", Color3.fromRGB(230, 200, 255))
end

-- Keeps the coins spinning and registers the twister with the calendar.
function DustDevil.startCoinSpinner()
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		if #coins > 0 then
			tickCoins(t)
		end
	end)
end

Events.register("dustdevil", DustDevil.startDustDevil)

return DustDevil
