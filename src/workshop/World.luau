-- World: builds the six fenced ranch plots along the Cattle Drive (dirt paddock, ten hay stalls, a
-- gate with a lock pad, an owner's sign), dresses the prairie (trees, cacti, hay, a windmill), and
-- answers where things are: which ranch holds a point, and whether a point is out on the open drive.
local PhysicsService = game:GetService("PhysicsService")
local Workspace = game:GetService("Workspace")

local World = {}

World.PLOT_HALF_W = 28
World.PLOT_HALF_D = 22
World.DRIVE_HALF_WIDTH = 20 -- |z| below this is the open drive: the stampede's path
World.DRIVE_START_X = -128
World.DRIVE_END_X = 132

-- Plot centres: north row faces south onto the drive, south row faces north.
local PLOT_CENTERS = {
	Vector3.new(0, 0, -42), Vector3.new(0, 0, 42),
	Vector3.new(-72, 0, -42), Vector3.new(72, 0, -42),
	Vector3.new(-72, 0, 42), Vector3.new(72, 0, 42),
}
local STALL_X = { -20, -10, 0, 10, 20 }
local STALL_ROW_Z = { -6, 10 }

local WOOD = Color3.fromRGB(122, 84, 52)
local DARK_WOOD = Color3.fromRGB(86, 58, 36)
local HAY = Color3.fromRGB(222, 186, 98)
local DIRT = Color3.fromRGB(150, 108, 68)

export type Plot = {
	index: number, cf: CFrame, folder: Model,
	stallCFrames: { CFrame }, stallPads: { BasePart }, stallLocks: { BillboardGui },
	gateBars: { BasePart }, gateLabel: TextLabel, lockPad: BasePart, signLabel: TextLabel,
	gateGroup: string, rancherGroup: string,
}

local function block(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function signText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.2
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(40, 22, 10)
	label.Parent = gui
	gui.Parent = part
	return label
end

local function fenceRun(parent: Instance, from: Vector3, to: Vector3, cf: CFrame)
	local span = to - from
	local length = span.Magnitude
	local mid = cf * CFrame.new((from + to) / 2)
	local along = CFrame.lookAt(mid.Position, mid.Position + cf:VectorToWorldSpace(span.Unit))
	for _, y in { 1.8, 3.8 } do
		block(parent, "Rail", Vector3.new(0.5, 0.7, length), along + Vector3.new(0, y, 0), WOOD)
	end
	local posts = math.max(1, math.floor(length / 7))
	for i = 0, posts do
		local p = from:Lerp(to, i / posts)
		block(parent, "Post", Vector3.new(1, 5, 1), cf * CFrame.new(p.X, 2.5, p.Z), DARK_WOOD)
	end
end

-- Builds one fenced ranch at a centre, its stalls facing the gate and the gate facing the drive.
local function buildRanchPlot(index: number, center: Vector3): Plot
	local cf = CFrame.lookAt(center, Vector3.new(center.X, 0, 0))
	local folder = Instance.new("Model")
	folder.Name = "Ranch" .. index
	local hw, hd = World.PLOT_HALF_W, World.PLOT_HALF_D

	block(folder, "Paddock", Vector3.new(hw * 2, 0.4, hd * 2), cf * CFrame.new(0, 0.3, 0), DIRT, Enum.Material.Ground)
	fenceRun(folder, Vector3.new(-hw, 0, hd), Vector3.new(hw, 0, hd), cf)
	fenceRun(folder, Vector3.new(-hw, 0, -hd), Vector3.new(-hw, 0, hd), cf)
	fenceRun(folder, Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd), cf)
	fenceRun(folder, Vector3.new(-hw, 0, -hd), Vector3.new(-6.5, 0, -hd), cf)
	fenceRun(folder, Vector3.new(6.5, 0, -hd), Vector3.new(hw, 0, -hd), cf)

	-- The gate: two tall posts, a beam carrying the owner's sign, and lock bars across the gap.
	for _, x in { -7, 7 } do
		block(folder, "GatePost", Vector3.new(1.6, 13, 1.6), cf * CFrame.new(x, 6.5, -hd), DARK_WOOD)
	end
	block(folder, "GateBeam", Vector3.new(16, 1.2, 1.4), cf * CFrame.new(0, 12.4, -hd), DARK_WOOD)
	local board = block(folder, "RanchBoard", Vector3.new(15, 3.2, 0.5), cf * CFrame.new(0, 10, -hd - 0.4), Color3.fromRGB(210, 170, 110))
	local signLabel = signText(board, Enum.NormalId.Front, "FOR SALE", Color3.fromRGB(255, 250, 235))
	signText(board, Enum.NormalId.Back, "RANCH " .. index, Color3.fromRGB(255, 250, 235))

	local gateGroup, rancherGroup = "Gate" .. index, "Rancher" .. index
	local gateBars = {}
	for i, y in { 1.2, 2.6, 4.0, 5.4 } do
		local bar = block(folder, "GateBar" .. i, Vector3.new(12.4, 0.35, 0.35), cf * CFrame.new(0, y, -hd), Color3.fromRGB(255, 60, 50), Enum.Material.Neon)
		bar.CollisionGroup = gateGroup
		table.insert(gateBars, bar)
	end

	local labelAnchor = block(folder, "GateLabelAnchor", Vector3.new(1, 1, 1), cf * CFrame.new(0, 15.5, -hd), WOOD)
	labelAnchor.Transparency = 1
	labelAnchor.CanCollide = false
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(8, 30, 1.8, 8)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.LightInfluence = 0
	local gateLabel = Instance.new("TextLabel")
	gateLabel.Size = UDim2.fromScale(1, 1)
	gateLabel.BackgroundTransparency = 1
	gateLabel.TextScaled = true
	gateLabel.Font = Enum.Font.LuckiestGuy
	gateLabel.TextStrokeTransparency = 0
	gateLabel.Text = ""
	gateLabel.Parent = billboard
	billboard.Parent = labelAnchor

	local lockPad = block(folder, "LockPad", Vector3.new(6, 0.6, 6), cf * CFrame.new(-14, 0.5, -15), Color3.fromRGB(70, 200, 90), Enum.Material.Neon)
	signText(lockPad, Enum.NormalId.Top, "LOCK", Color3.fromRGB(255, 255, 255))

	-- Ten stalls in two rows, plank partitions between them, a trough at the back of each.
	local stallCFrames, stallPads, stallLocks = {}, {}, {}
	for _, z in STALL_ROW_Z do
		for _, x in STALL_X do
			local stallCf = cf * CFrame.new(x, 0.75, z)
			local pad = block(folder, "Stall", Vector3.new(8.6, 0.5, 8.6), cf * CFrame.new(x, 0.5, z), HAY, Enum.Material.Fabric)
			block(folder, "Trough", Vector3.new(6, 1.2, 1.2), cf * CFrame.new(x, 1.2, z + 3.9), DARK_WOOD)
			local lock = Instance.new("BillboardGui")
			lock.Size = UDim2.fromScale(7, 2.2)
			lock.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
			lock.LightInfluence = 0
			lock.MaxDistance = 90
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.TextScaled = true
			text.Font = Enum.Font.FredokaOne
			text.TextColor3 = Color3.fromRGB(255, 230, 160)
			text.TextStrokeTransparency = 0
			text.Text = "LOCKED: REBIRTH"
			text.Parent = lock
			lock.Parent = pad
			table.insert(stallCFrames, stallCf)
			table.insert(stallPads, pad)
			table.insert(stallLocks, lock)
		end
		for _, x in { -25, -15, -5, 5, 15, 25 } do
			block(folder, "Partition", Vector3.new(0.5, 2.6, 8.6), cf * CFrame.new(x, 1.6, z), WOOD, Enum.Material.WoodPlanks)
		end
	end

	-- A hay corner and a water trough behind the back row.
	block(folder, "HayBale", Vector3.new(5, 3, 3), cf * CFrame.new(-22, 1.9, 18.5), HAY, Enum.Material.Fabric)
	block(folder, "HayBale", Vector3.new(5, 3, 3), cf * CFrame.new(-16.5, 1.9, 18.5), HAY, Enum.Material.Fabric)
	block(folder, "HayBale", Vector3.new(5, 3, 3), cf * CFrame.new(-19.2, 4.9, 18.5), HAY, Enum.Material.Fabric)
	block(folder, "WaterTrough", Vector3.new(10, 2, 3), cf * CFrame.new(16, 1.4, 18.5), Color3.fromRGB(110, 120, 130), Enum.Material.Metal)
	block(folder, "Water", Vector3.new(9.4, 0.2, 2.4), cf * CFrame.new(16, 2.3, 18.5), Color3.fromRGB(70, 150, 200), Enum.Material.Glass)

	folder.Parent = Workspace
	return {
		index = index, cf = cf, folder = folder,
		stallCFrames = stallCFrames, stallPads = stallPads, stallLocks = stallLocks,
		gateBars = gateBars, gateLabel = gateLabel, lockPad = lockPad, signLabel = signLabel,
		gateGroup = gateGroup, rancherGroup = rancherGroup,
	}
end

-- Registers each ranch's gate/rancher collision pair so a locked gate stops everyone but its owner.
local function registerGateGroups()
	for i = 1, #PLOT_CENTERS do
		local gate, rancher = "Gate" .. i, "Rancher" .. i
		PhysicsService:RegisterCollisionGroup(gate)
		PhysicsService:RegisterCollisionGroup(rancher)
		PhysicsService:CollisionGroupSetCollidable(gate, rancher, false)
	end
end

function World.buildRanchPlots(): { Plot }
	registerGateGroups()
	local plots = {}
	for i, center in PLOT_CENTERS do
		plots[i] = buildRanchPlot(i, center)
	end
	return plots
end

-- Greys out the stalls a rancher has not unlocked yet (more open with each rebirth).
function World.paintStallLocks(plot: Plot, openStalls: number)
	for i, pad in plot.stallPads do
		local open = i <= openStalls
		pad.Color = if open then HAY else Color3.fromRGB(110, 100, 90)
		plot.stallLocks[i].Enabled = not open
	end
end

-- Shows a gate as locked (red bars, countdown) or open (bars down, green "OPEN").
function World.paintGate(plot: Plot, locked: boolean, secondsLeft: number)
	for _, bar in plot.gateBars do
		bar.Transparency = if locked then 0.05 else 1
		bar.CanCollide = locked
	end
	if locked then
		plot.gateLabel.Text = string.format("LOCKED %ds", math.ceil(secondsLeft))
		plot.gateLabel.TextColor3 = Color3.fromRGB(255, 80, 70)
		plot.lockPad.Color = Color3.fromRGB(230, 60, 50)
	else
		plot.gateLabel.Text = "GATE OPEN"
		plot.gateLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
		plot.lockPad.Color = Color3.fromRGB(70, 200, 90)
	end
end

function World.paintRanchSign(plot: Plot, text: string, color: Color3)
	plot.signLabel.Text = text
	plot.signLabel.TextColor3 = color
end

function World.ranchContains(plot: Plot, position: Vector3): boolean
	local p = plot.cf:PointToObjectSpace(position)
	return math.abs(p.X) < World.PLOT_HALF_W and math.abs(p.Z) < World.PLOT_HALF_D and p.Y < 40
end

function World.isOnTheDrive(position: Vector3): boolean
	return math.abs(position.Z) < World.DRIVE_HALF_WIDTH and position.X > World.DRIVE_START_X - 30 and position.X < World.DRIVE_END_X + 10
end

local function tree(parent: Instance, at: Vector3, height: number)
	block(parent, "Trunk", Vector3.new(1.8, height, 1.8), CFrame.new(at + Vector3.new(0, height / 2, 0)), Color3.fromRGB(100, 70, 45))
	local crown = block(parent, "Crown", Vector3.new(height * 0.9, height * 0.75, height * 0.9), CFrame.new(at + Vector3.new(0, height + 1, 0)), Color3.fromRGB(96, 140, 60), Enum.Material.LeafyGrass)
	crown.Shape = Enum.PartType.Ball
	crown.Size = Vector3.one * height * 0.85
end

local function cactus(parent: Instance, at: Vector3, height: number)
	local green = Color3.fromRGB(80, 140, 70)
	block(parent, "Cactus", Vector3.new(1.6, height, 1.6), CFrame.new(at + Vector3.new(0, height / 2, 0)), green, Enum.Material.Grass)
	block(parent, "Arm", Vector3.new(2.6, 0.9, 0.9), CFrame.new(at + Vector3.new(1.6, height * 0.5, 0)), green, Enum.Material.Grass)
	block(parent, "Arm", Vector3.new(0.9, 2.6, 0.9), CFrame.new(at + Vector3.new(2.5, height * 0.5 + 1.4, 0)), green, Enum.Material.Grass)
end

-- A windmill whose blades a hinge motor turns, so it spins smoothly for every client.
local function windmill(parent: Instance, at: Vector3)
	block(parent, "WindmillTower", Vector3.new(2, 26, 2), CFrame.new(at + Vector3.new(0, 13, 0)), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
	local hub = block(parent, "WindmillHub", Vector3.new(1.6, 1.6, 1.6), CFrame.new(at + Vector3.new(0, 26, 1.6)), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	local rotor = block(parent, "Rotor", Vector3.new(2, 2, 1), CFrame.new(at + Vector3.new(0, 26, 2.8)), Color3.fromRGB(200, 60, 50), Enum.Material.Metal)
	rotor.Anchored = false
	for i = 0, 5 do
		local blade = block(parent, "Blade", Vector3.new(1.4, 9, 0.2), CFrame.new(at + Vector3.new(0, 26, 2.9)) * CFrame.Angles(0, 0, i * math.pi / 3) * CFrame.new(0, 5, 0), Color3.fromRGB(240, 236, 226), Enum.Material.Metal)
		blade.Anchored = false
		blade.CanCollide = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = rotor, blade
		weld.Parent = blade
	end
	local a0 = Instance.new("Attachment")
	a0.Axis = Vector3.new(0, 0, 1)
	a0.Position = Vector3.new(0, 0, 0.8)
	a0.Parent = hub
	local a1 = Instance.new("Attachment")
	a1.Axis = Vector3.new(0, 0, 1)
	a1.Position = Vector3.new(0, 0, -0.4)
	a1.Parent = rotor
	local hinge = Instance.new("HingeConstraint")
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = 1.2
	hinge.MotorMaxTorque = 1e7
	hinge.Attachment0, hinge.Attachment1 = a0, a1
	hinge.Parent = hub
end

-- Dresses the prairie around the ranches and writes the barn and corral signs.
function World.decorateRanchland()
	local decor = Instance.new("Folder")
	decor.Name = "Ranchland"
	for _, spot in { Vector3.new(-120, 0, -80), Vector3.new(-100, 0, -120), Vector3.new(-140, 0, 60), Vector3.new(110, 0, -100),
		Vector3.new(120, 0, 90), Vector3.new(-110, 0, 110), Vector3.new(60, 0, -130), Vector3.new(-30, 0, -140),
		Vector3.new(30, 0, 120), Vector3.new(90, 0, 130), Vector3.new(-80, 0, 140), Vector3.new(-150, 0, -30) } do
		tree(decor, spot, 12 + (math.abs(spot.X + spot.Z) % 7))
	end
	for _, spot in { Vector3.new(-120, 0, 30), Vector3.new(118, 0, -30), Vector3.new(124, 0, 34), Vector3.new(-118, 0, -34), Vector3.new(36, 0, -24.5), Vector3.new(-36, 0, 24.5) } do
		cactus(decor, spot, 6)
	end
	for i, spot in { Vector3.new(-26, 0, -80), Vector3.new(-22, 0, -82), Vector3.new(26, 0, 80), Vector3.new(40, 0, -76), Vector3.new(-36, 0, 76) } do
		local bale = block(decor, "HayBale", Vector3.new(4, 4, 4), CFrame.new(spot + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), HAY, Enum.Material.Fabric)
		bale.Shape = Enum.PartType.Cylinder
		bale.Size = Vector3.new(4.5, 4 + i % 2, 4 + i % 2)
	end
	windmill(decor, Vector3.new(-60, 0, -104))
	decor.Parent = Workspace

	local barn = Workspace:FindFirstChild("RedBarn")
	if barn and barn:FindFirstChild("RanchSign") then
		signText(barn.RanchSign, Enum.NormalId.Back, "ROT RANCH", Color3.fromRGB(150, 40, 25))
	end
	local corral = Workspace:FindFirstChild("RotCorral")
	if corral and corral:FindFirstChild("ChuteSign") then
		signText(corral.ChuteSign, Enum.NormalId.Right, "ROT CORRAL", Color3.fromRGB(255, 255, 230))
	end
	local canyon = Workspace:FindFirstChild("DustCanyon")
	if canyon and canyon:FindFirstChild("ButteNorth") then
		signText(canyon.ButteNorth, Enum.NormalId.Left, "DUST CANYON", Color3.fromRGB(255, 236, 200))
	end
end

return World
