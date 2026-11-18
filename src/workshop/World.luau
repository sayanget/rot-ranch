-- World: builds the six fenced ranch plots along the Cattle Drive (dirt paddock, ten hay stalls, a
-- gate with a lock pad, an owner's sign), dresses the prairie (a neon ROT RANCH arch over the drive,
-- a chuckwagon camp, pines, dead trees, cacti, rocks, flowers, lantern posts, a windmill and a water
-- tower with a spinning vane), keeps it moving (tumbleweeds, twinkling arch lights), and answers
-- where things are: which ranch holds a point, and whether a point is out on the open drive.
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
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

-- Moving bits of the ranchland, animated by startRanchlandMotion.
local archLights: { BasePart } = {}
local vane: BasePart? = nil
local tumbleFolder: Folder? = nil

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

-- Painted lettering on a part's face. TextScaled stops at 100 px, so the canvas is kept coarse
-- (20 pixels a stud, fewer for a big sign) for the words to fill the board.
local function signText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, pixelsPerStud: number?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 20
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

-- Rolls one tumbleweed across the open prairie behind a row of ranches.
local function rollTumbleweed(t: number)
	local folder = tumbleFolder
	if not folder then
		return
	end
	local side = if math.random() < 0.5 then -1 else 1
	local z = side * (78 + math.random() * 50)
	local ball = block(folder, "Tumbleweed", Vector3.one * 3, CFrame.new(-190, 1.5, z), Color3.fromRGB(170, 130, 80), Enum.Material.Grass)
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.25
	ball.CanCollide = false
	ball:SetAttribute("Born", t)
	ball:SetAttribute("Z", z)
	ball:SetAttribute("Speed", 14 + math.random() * 10)
end

-- Keeps the ranchland alive: tumbleweeds bounce by, the arch's bulbs chase, the weathervane turns.
function World.startRanchlandMotion()
	local folder = Instance.new("Folder")
	folder.Name = "Tumbleweeds"
	folder.Parent = Workspace
	tumbleFolder = folder
	local t, nextWeed = 0, 2
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		nextWeed -= dt
		if nextWeed <= 0 then
			nextWeed = 6 + math.random() * 6
			rollTumbleweed(t)
		end
		for _, weed in folder:GetChildren() do
			local born = weed:GetAttribute("Born") :: number
			local x = -190 + (t - born) * (weed:GetAttribute("Speed") :: number)
			if x > 200 then
				weed:Destroy()
			else
				local hop = math.abs(math.sin((t - born) * 3)) * 2.4
				local z = weed:GetAttribute("Z") :: number;
				(weed :: BasePart).CFrame = CFrame.new(x, 1.5 + hop, z) * CFrame.Angles(0, 0, -(t - born) * 5)
			end
		end
		for i, bulb in archLights do
			local on = math.floor(t * 4 + i) % 3 ~= 0
			bulb.Color = if on then Color3.fromRGB(255, 220, 120) else Color3.fromRGB(120, 80, 50)
		end
		local turning = vane
		if turning then
			turning.CFrame = CFrame.new(turning.Position) * CFrame.Angles(0, math.sin(t * 0.4) * 2.5, 0)
		end
	end)
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

local function pine(parent: Instance, at: Vector3, height: number)
	block(parent, "PineTrunk", Vector3.new(1.4, height * 0.4, 1.4), CFrame.new(at + Vector3.new(0, height * 0.2, 0)), Color3.fromRGB(90, 62, 40))
	for i = 0, 3 do
		local w = height * (0.62 - i * 0.13)
		block(parent, "PineTier", Vector3.new(w, height * 0.2, w), CFrame.new(at + Vector3.new(0, height * (0.32 + i * 0.17), 0)) * CFrame.Angles(0, i * 0.4, 0), Color3.fromRGB(56 + i * 6, 104 + i * 8, 58), Enum.Material.LeafyGrass)
	end
end

local function deadTree(parent: Instance, at: Vector3, height: number)
	local bark = Color3.fromRGB(110, 90, 76)
	block(parent, "DeadTrunk", Vector3.new(1.4, height, 1.4), CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, 0.06), bark)
	for i, a in { 0.7, -0.8, 0.5, -0.4 } do
		local y = height * (0.45 + i * 0.12)
		block(parent, "Branch", Vector3.new(0.6, height * 0.35, 0.6), CFrame.new(at + Vector3.new(0, y, 0)) * CFrame.Angles(i * 1.3, 0, a) * CFrame.new(0, height * 0.17, 0), bark)
	end
end

local function rocks(parent: Instance, at: Vector3, size: number)
	for i = 0, 2 do
		local r = block(parent, "Rock", Vector3.one * size * (1 - i * 0.25), CFrame.new(at + Vector3.new(i * size * 0.6, size * 0.3, (i % 2) * size * 0.5)) * CFrame.Angles(i, i * 2, 0), Color3.fromRGB(150 - i * 12, 128 - i * 10, 110), Enum.Material.Slate)
		r.Shape = Enum.PartType.Ball
		r.Size = Vector3.one * size * (1 - i * 0.25)
	end
end

local function flowers(parent: Instance, at: Vector3)
	local colors = { Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 120, 160), Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 255, 240) }
	for i = 0, 6 do
		local a = i * 2.4
		local spot = at + Vector3.new(math.cos(a) * (1 + i * 0.5), 0, math.sin(a) * (1 + i * 0.5))
		block(parent, "Stem", Vector3.new(0.15, 1, 0.15), CFrame.new(spot + Vector3.new(0, 0.5, 0)), Color3.fromRGB(80, 140, 60), Enum.Material.Grass)
		local bloom = block(parent, "Bloom", Vector3.one * 0.6, CFrame.new(spot + Vector3.new(0, 1.1, 0)), colors[i % #colors + 1], Enum.Material.Neon)
		bloom.Shape = Enum.PartType.Ball
		bloom.CanCollide = false
	end
end

-- A lantern on a post, its lamp hung out over the drive: lights the trail at dusk.
local function lanternPost(parent: Instance, at: Vector3)
	local toward = if at.Z < 0 then 1 else -1
	block(parent, "LanternPost", Vector3.new(0.8, 9, 0.8), CFrame.new(at + Vector3.new(0, 4.5, 0)), DARK_WOOD)
	block(parent, "LanternArm", Vector3.new(0.4, 0.4, 2.6), CFrame.new(at + Vector3.new(0, 8.6, toward * 1.1)), DARK_WOOD)
	local lamp = block(parent, "Lantern", Vector3.new(1.1, 1.4, 1.1), CFrame.new(at + Vector3.new(0, 7.8, toward * 2.2)), Color3.fromRGB(255, 200, 110), Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 110)
	light.Range = 20
	light.Brightness = 1.6
	light.Parent = lamp
end

-- The neon ROT RANCH arch over the Cattle Drive, string lights along its beam and a cow skull on top.
local function neonArch(parent: Instance, x: number)
	local logs = Color3.fromRGB(96, 64, 40)
	for _, z in { -21, 21 } do
		block(parent, "ArchPost", Vector3.new(2.4, 28, 2.4), CFrame.new(x, 14, z), logs)
		block(parent, "ArchFoot", Vector3.new(4, 2, 4), CFrame.new(x, 1, z), Color3.fromRGB(130, 118, 104), Enum.Material.Slate)
	end
	block(parent, "ArchBeam", Vector3.new(2.6, 2.2, 48), CFrame.new(x, 27.4, 0), logs)
	local board = block(parent, "ArchBoard", Vector3.new(1, 8, 34), CFrame.new(x, 21.6, 0), Color3.fromRGB(70, 40, 24), Enum.Material.WoodPlanks)
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local label = signText(board, face, "ROT RANCH", Color3.fromRGB(180, 255, 80), Enum.Font.LuckiestGuy, 11)
		label.TextStrokeColor3 = Color3.fromRGB(30, 60, 10)
		label.TextStrokeTransparency = 0
		local gui = label.Parent :: SurfaceGui
		gui.LightInfluence = 0
		gui.Brightness = 2.5
	end
	-- neon tube frame around the board
	for _, y in { 17.4, 25.8 } do
		block(parent, "NeonTube", Vector3.new(1.2, 0.4, 34.4), CFrame.new(x, y, 0), Color3.fromRGB(255, 120, 200), Enum.Material.Neon)
	end
	for _, z in { -17.2, 17.2 } do
		block(parent, "NeonTube", Vector3.new(1.2, 8.8, 0.4), CFrame.new(x, 21.6, z), Color3.fromRGB(255, 120, 200), Enum.Material.Neon)
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(190, 255, 120)
	glow.Range = 34
	glow.Brightness = 2
	glow.Parent = board
	for i = 0, 15 do
		local bulb = block(parent, "ArchBulb", Vector3.one * 0.8, CFrame.new(x, 28.8, -22 + i * 44 / 15), Color3.fromRGB(255, 220, 120), Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
		bulb.CanCollide = false
		table.insert(archLights, bulb)
	end
	-- the skull
	local bone = Color3.fromRGB(240, 232, 214)
	block(parent, "Skull", Vector3.new(3.2, 3, 3.4), CFrame.new(x, 30.4, 0), bone, Enum.Material.SmoothPlastic)
	block(parent, "Snout", Vector3.new(2.2, 2, 1.6), CFrame.new(x - 1.4, 29.6, 0) * CFrame.Angles(0, math.pi / 2, 0), bone, Enum.Material.SmoothPlastic)
	for _, z in { -1, 1 } do
		block(parent, "Horn", Vector3.new(0.8, 0.8, 3.6), CFrame.new(x, 31.2, z * 3), bone, Enum.Material.SmoothPlastic)
		block(parent, "HornTip", Vector3.new(0.7, 2.4, 0.7), CFrame.new(x, 32.4, z * 4.6), bone, Enum.Material.SmoothPlastic)
		local eye = block(parent, "SkullEye", Vector3.new(0.4, 0.8, 0.8), CFrame.new(x - 1.6, 30.8, z * 0.8), Color3.fromRGB(170, 255, 70), Enum.Material.Neon)
		eye.CanCollide = false
	end
end

-- The chuckwagon camp: a covered wagon, a crackling campfire with a pot on a tripod, log benches.
local function chuckwagon(parent: Instance, at: CFrame)
	local wood = Color3.fromRGB(140, 96, 58)
	block(parent, "WagonBed", Vector3.new(11, 2.4, 5.4), at * CFrame.new(0, 3.4, 0), wood, Enum.Material.WoodPlanks)
	local cover = block(parent, "WagonCover", Vector3.new(10, 6.4, 5.8), at * CFrame.new(0, 4.8, 0), Color3.fromRGB(245, 238, 220), Enum.Material.Fabric)
	cover.Shape = Enum.PartType.Cylinder
	for _, x in { -3.6, 3.6 } do
		for _, z in { -3.1, 3.1 } do
			local d = if x > 0 then 4.4 else 3.6
			local wheel = block(parent, "WagonWheel", Vector3.new(0.5, d, d), at * CFrame.new(x, d / 2, z) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(80, 54, 34))
			wheel.Shape = Enum.PartType.Cylinder
			local hub = block(parent, "WheelHub", Vector3.new(0.7, 1, 1), at * CFrame.new(x, d / 2, z) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
			hub.Shape = Enum.PartType.Cylinder
		end
	end
	block(parent, "WagonTongue", Vector3.new(6, 0.5, 0.5), at * CFrame.new(-8, 1.6, 0) * CFrame.Angles(0, 0, -0.2), wood)
	local sign = block(parent, "ChuckSign", Vector3.new(5, 1.6, 0.3), at * CFrame.new(0, 3.4, -2.9), Color3.fromRGB(210, 170, 110))
	signText(sign, Enum.NormalId.Front, "CHUCK", Color3.fromRGB(150, 40, 25))
	-- campfire
	local fireAt = at * CFrame.new(1, 0, -9)
	for i = 0, 3 do
		block(parent, "FireLog", Vector3.new(0.7, 0.7, 3.4), fireAt * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0.4, 0), Color3.fromRGB(80, 50, 30))
	end
	local embers = block(parent, "Embers", Vector3.new(1.6, 0.4, 1.6), fireAt * CFrame.new(0, 0.6, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	embers.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 160, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = embers
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 70)
	light.Range = 22
	light.Brightness = 2.4
	light.Shadows = true
	light.Parent = embers
	for _, a in { 0, 2.1, 4.2 } do
		block(parent, "Tripod", Vector3.new(0.3, 6, 0.3), fireAt * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.9, 1.2) * CFrame.Angles(-0.38, 0, 0), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
	end
	local pot = block(parent, "Pot", Vector3.new(1.8, 1.6, 1.8), fireAt * CFrame.new(0, 2.6, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	pot.Shape = Enum.PartType.Ball
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 5
	steam.Lifetime = NumberRange.new(1.5, 2.5)
	steam.Speed = NumberRange.new(2, 3)
	steam.Size = NumberSequence.new(0.8, 2.5)
	steam.Transparency = NumberSequence.new(0.5, 1)
	steam.Parent = pot
	for _, a in { 0.6, 2.4, 4.4 } do
		local bench = block(parent, "LogBench", Vector3.new(4.4, 1.2, 1.2), fireAt * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.6, 5) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(110, 76, 48))
		bench.Shape = Enum.PartType.Cylinder
	end
end

-- The water tower gets a turning rooster weathervane, a neon band, a sign and a dripping leak.
local function dressWaterTower()
	local tower = Workspace:FindFirstChild("WaterTower")
	local cap = tower and tower:FindFirstChild("TankCap") :: BasePart?
	local tank = tower and tower:FindFirstChild("Tank") :: BasePart?
	if not tower or not cap or not tank then
		return
	end
	local top = cap.Position + Vector3.new(0, 6, 0)
	block(tower, "VaneRod", Vector3.new(0.3, 4, 0.3), CFrame.new(top + Vector3.new(0, 1, 0)), Color3.fromRGB(70, 70, 70), Enum.Material.Metal)
	vane = block(tower, "Vane", Vector3.new(0.3, 2.4, 4.4), CFrame.new(top + Vector3.new(0, 3.6, 0)), Color3.fromRGB(40, 36, 34), Enum.Material.Metal)
	local band = block(tower, "TankBand", Vector3.new(1.2, 12.6, 12.6), tank.CFrame * CFrame.new(1.5, 0, 0), Color3.fromRGB(150, 255, 70), Enum.Material.Neon)
	band.Shape = Enum.PartType.Cylinder
	band.CanCollide = false
	local sign = block(tower, "TankSign", Vector3.new(8, 2.6, 0.3), CFrame.new(tank.Position + Vector3.new(0, -1.8, -6.3)), Color3.fromRGB(110, 70, 40))
	signText(sign, Enum.NormalId.Front, "ROT WATER", Color3.fromRGB(190, 255, 120))
	local drip = Instance.new("Attachment")
	drip.Position = Vector3.new(-4.6, 0, -2)
	drip.Parent = tank
	local leak = Instance.new("ParticleEmitter")
	leak.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	leak.Rate = 14
	leak.Lifetime = NumberRange.new(1, 1.4)
	leak.Speed = NumberRange.new(0, 1)
	leak.Acceleration = Vector3.new(0, -30, 0)
	leak.Size = NumberSequence.new(0.35)
	leak.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	leak.EmissionDirection = Enum.NormalId.Bottom
	leak.Parent = drip
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
	for _, spot in { Vector3.new(-160, 0, -110), Vector3.new(150, 0, -130), Vector3.new(160, 0, 120), Vector3.new(-170, 0, 100),
		Vector3.new(70, 0, 150), Vector3.new(-50, 0, 160), Vector3.new(10, 0, -160), Vector3.new(-130, 0, 150), Vector3.new(130, 0, 160) } do
		pine(decor, spot, 16 + math.abs(spot.X) % 9)
	end
	for _, spot in { Vector3.new(140, 0, -78), Vector3.new(-90, 0, -90), Vector3.new(96, 0, 96), Vector3.new(-160, 0, 70) } do
		deadTree(decor, spot, 13)
	end
	for _, spot in { Vector3.new(-126, 0, -60), Vector3.new(132, 0, 64), Vector3.new(60, 0, -96), Vector3.new(-64, 0, 96), Vector3.new(100, 0, -150), Vector3.new(-20, 0, 120) } do
		rocks(decor, spot, 3.4)
	end
	for _, spot in { Vector3.new(-40, 0, -70), Vector3.new(44, 0, 70), Vector3.new(-110, 0, 76), Vector3.new(108, 0, -74), Vector3.new(-10, 0, -78), Vector3.new(12, 0, 82) } do
		flowers(decor, spot)
	end
	for _, x in { -118, -36, 36, 110 } do
		lanternPost(decor, Vector3.new(x + 4, 0, -19))
		lanternPost(decor, Vector3.new(x - 4, 0, 19))
	end
	neonArch(decor, -36)
	chuckwagon(decor, CFrame.new(62, 0, -84) * CFrame.Angles(0, 0.35, 0))
	decor.Parent = Workspace
	dressWaterTower()

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
