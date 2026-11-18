-- Critters: builds every Rot Ranch critter as its own 3D silhouette from parts, gives it its
-- mutation finish (Golden, Moldy, Spicy, Crystal, Ghost), hangs the name / rarity / $-a-second label
-- over its head, and draws the lasso rope. Shared by the server (the drive, the pens) and the client
-- (RanchDex portraits). Every visible piece hangs off a "Body" part joined to the anchored root by
-- a Motor6D named Gait, so CritterMotion on each client can make the herd trot, breathe and wriggle.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))

local Critters = {}

type Ctx = { model: Model, root: BasePart, body: BasePart, scale: number }

local BLACK = Color3.fromRGB(25, 20, 20)
local WHITE = Color3.fromRGB(250, 248, 240)
local PINK = Color3.fromRGB(255, 150, 160)
local ORANGE = Color3.fromRGB(255, 140, 30)
local HAY = Color3.fromRGB(226, 190, 100)
local BONE = Color3.fromRGB(240, 236, 220)
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local EMBERS = "rbxasset://textures/particles/fire_sparks_main.dds"
local GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds"

-- Height of each silhouette at scale 1, so labels and prompts sit just above the head.
local HEIGHTS = {
	cow = 6.2, chicken = 7.4, pig = 6.6, sheep = 6.2, goat = 7, horse = 9.4,
	llama = 13, duck = 6.6, tortoise = 6.8, scarecrow = 10.6, disco = 8.6, bull = 8.4,
	tumble = 5.6, burro = 7, cactopus = 7.6, jackalope = 8.6, wiener = 6.4, buzzard = 8.6,
	snake = 7.6, hydra = 9.6, smoker = 9.6, saucer = 9.4, skelecow = 9.8,
}

-- One welded piece of a critter; kind is nil (block), "blob" (ellipsoid), "ball", "cyl" or "wedge".
local function piece(ctx: Ctx, size: Vector3, at: Vector3 | CFrame, color: Color3, material: Enum.Material?, kind: string?): BasePart
	local s = ctx.scale
	local local_ = if typeof(at) == "Vector3" then CFrame.new(at) else at
	local_ = CFrame.new(local_.Position * s) * local_.Rotation
	local p: BasePart = if kind == "wedge" then Instance.new("WedgePart") else Instance.new("Part")
	if kind == "ball" then
		(p :: Part).Shape = Enum.PartType.Ball
	elseif kind == "cyl" then
		(p :: Part).Shape = Enum.PartType.Cylinder
	end
	p.Size = size * s
	p.CFrame = ctx.body.CFrame * local_
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	if kind == "blob" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = ctx.body, p
	weld.Parent = p
	p.Parent = ctx.model
	return p
end

-- A piece that keeps its own colour and material through every mutation (eyes, lights, neon).
local function keep(p: BasePart): BasePart
	p:SetAttribute("Keep", true)
	return p
end

local function eyes(ctx: Ctx, y: number, z: number, spread: number, size: number, color: Color3?)
	for _, x in { -spread, spread } do
		keep(piece(ctx, Vector3.one * size, Vector3.new(x, y, z), color or BLACK, if color then Enum.Material.Neon else nil, "ball"))
	end
end

-- Cartoon eyes: a white ball with a black pupil looking forward.
local function googly(ctx: Ctx, y: number, z: number, spread: number, size: number)
	for _, x in { -spread, spread } do
		keep(piece(ctx, Vector3.one * size, Vector3.new(x, y, z), WHITE, nil, "ball"))
		keep(piece(ctx, Vector3.one * size * 0.5, Vector3.new(x, y, z - size * 0.4), BLACK, nil, "ball"))
	end
end

local function legs(ctx: Ctx, w: number, h: number, x: number, zFront: number, zBack: number, color: Color3, material: Enum.Material?)
	for _, lx in { -x, x } do
		for _, lz in { zFront, zBack } do
			piece(ctx, Vector3.new(w, h, w), Vector3.new(lx, h / 2, lz), color, material)
		end
	end
end

local function emitter(parent: Instance, texture: string, color: Color3, rate: number, size: number, speed: number): ParticleEmitter
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = texture
	fx.Rate = rate
	fx.Lifetime = NumberRange.new(1, 1.8)
	fx.Speed = NumberRange.new(speed * 0.5, speed)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Size = NumberSequence.new(size)
	fx.Transparency = NumberSequence.new(0.2, 1)
	fx.Color = ColorSequence.new(color)
	fx.LightEmission = 0.6
	fx.Parent = parent
	return fx
end

local function glow(parent: Instance, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = parent
end

local function cowBody(ctx: Ctx, body: Color3, accent: Color3, material: Enum.Material)
	piece(ctx, Vector3.new(4.4, 3.2, 5.8), Vector3.new(0, 3.2, 0), body, material, "blob")
	for _, spot in { Vector3.new(2, 3.6, 0.8), Vector3.new(-2, 2.9, -0.9), Vector3.new(1.1, 4.5, -1.4), Vector3.new(-0.8, 4.5, 1.6) } do
		piece(ctx, Vector3.new(1, 0.8, 1.1), spot, accent, material, "blob")
	end
	legs(ctx, 0.9, 2.1, 1.3, -1.8, 1.8, accent)
	piece(ctx, Vector3.new(2.5, 2.3, 2.3), Vector3.new(0, 4.4, -3.5), body, material)
	piece(ctx, Vector3.new(2, 1.1, 0.8), Vector3.new(0, 3.7, -4.7), PINK)
	for _, x in { -1, 1 } do
		piece(ctx, Vector3.new(0.4, 1.2, 0.4), Vector3.new(x, 6, -3.4), WHITE)
		piece(ctx, Vector3.new(0.9, 0.4, 0.5), Vector3.new(x * 1.6, 5, -3.3), accent)
	end
	eyes(ctx, 4.9, -4.65, 0.65, 0.55)
	piece(ctx, Vector3.new(0.3, 1.9, 0.3), Vector3.new(0, 3.4, 3), accent)
end

local BUILDERS: { [string]: (Ctx, Color3, Color3) -> () } = {}

-- Spudmoo: a lumpy potato cow.
BUILDERS.cow = function(ctx, body, accent)
	cowBody(ctx, body, accent, Enum.Material.Sand)
end

-- Cluckaroni: a round chicken feathered with elbow macaroni.
BUILDERS.chicken = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.2, 3.6, 3.8), Vector3.new(0, 3.4, 0), body, nil, "blob")
	for i = 0, 7 do
		local a = i * math.pi / 4
		piece(ctx, Vector3.new(0.6, 1.4, 0.6), CFrame.new(math.cos(a) * 1.6, 3.4 + math.sin(a) * 1.5, 0.6) * CFrame.Angles(0, 0, a), Color3.fromRGB(255, 225, 120), nil, "cyl")
	end
	piece(ctx, Vector3.new(1.9, 2.1, 1.9), Vector3.new(0, 5.9, -1.2), body, nil, "blob")
	piece(ctx, Vector3.new(0.4, 1.1, 1.4), Vector3.new(0, 7.1, -1.2), accent, nil, "blob")
	piece(ctx, Vector3.new(0.9, 0.6, 1), CFrame.new(0, 5.8, -2.4) * CFrame.Angles(0, math.pi, 0), ORANGE, nil, "wedge")
	piece(ctx, Vector3.new(0.4, 0.7, 0.3), Vector3.new(0, 5.1, -2.15), accent, nil, "blob")
	eyes(ctx, 6.3, -2.05, 0.5, 0.4)
	for _, x in { -0.6, 0.6 } do
		piece(ctx, Vector3.new(0.3, 1.7, 0.3), Vector3.new(x, 0.85, 0), ORANGE)
		piece(ctx, Vector3.new(1, 0.2, 1.2), Vector3.new(x, 0.1, -0.2), ORANGE)
	end
end

-- Tumbleweasel: a rolling ball of twigs with a weasel poking out of the front.
BUILDERS.tumble = function(ctx, body, accent)
	piece(ctx, Vector3.new(4.2, 4.2, 4.2), Vector3.new(0, 2.4, 0.4), body, Enum.Material.Grass, "ball")
	for i = 0, 9 do
		piece(ctx, Vector3.new(5, 0.22, 0.22), CFrame.new(0, 2.4, 0.4) * CFrame.Angles(i * 0.7, i * 1.3, i * 0.45), Color3.fromRGB(120, 85, 50), Enum.Material.Wood, "cyl")
	end
	piece(ctx, Vector3.new(1.7, 1.6, 2.6), Vector3.new(0, 3.5, -2.2), accent, Enum.Material.Fabric, "blob")
	piece(ctx, Vector3.new(1.1, 0.9, 1.2), Vector3.new(0, 3.2, -3.4), Color3.fromRGB(245, 225, 200), Enum.Material.Fabric, "blob")
	keep(piece(ctx, Vector3.new(0.4, 0.35, 0.3), Vector3.new(0, 3.35, -4), BLACK, nil, "ball"))
	for _, x in { -0.6, 0.6 } do
		piece(ctx, Vector3.new(0.6, 0.7, 0.3), Vector3.new(x, 4.4, -2.2), accent, Enum.Material.Fabric, "blob")
	end
	googly(ctx, 3.95, -3.2, 0.45, 0.5)
	piece(ctx, Vector3.new(0.8, 0.8, 3), CFrame.new(0, 3.6, 3) * CFrame.Angles(0.7, 0, 0), accent, Enum.Material.Fabric, "blob")
end

-- Hamwich Hog: a pig whose body is a club sandwich, toothpick and olive included.
BUILDERS.pig = function(ctx, body, accent)
	local bread = accent
	piece(ctx, Vector3.new(4, 0.9, 5.4), Vector3.new(0, 2, 0), bread, Enum.Material.Sand)
	piece(ctx, Vector3.new(4.4, 0.55, 5.8), Vector3.new(0, 2.7, 0), body)
	piece(ctx, Vector3.new(4.7, 0.3, 6.1), Vector3.new(0, 3.1, 0), Color3.fromRGB(110, 200, 70), Enum.Material.Grass)
	piece(ctx, Vector3.new(4.4, 0.3, 4.4), CFrame.new(0, 3.35, 0) * CFrame.Angles(0, math.pi / 4, 0), Color3.fromRGB(255, 210, 60))
	piece(ctx, Vector3.new(4, 1.5, 5.4), Vector3.new(0, 3.9, 0), bread, Enum.Material.Sand, "blob")
	legs(ctx, 0.9, 1.6, 1.3, -1.8, 1.8, body)
	piece(ctx, Vector3.new(2.6, 2.4, 2.4), Vector3.new(0, 3.2, -3.5), body, nil, "blob")
	piece(ctx, Vector3.new(0.7, 1.3, 1.3), CFrame.new(0, 3, -4.75) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(240, 120, 135), nil, "cyl")
	for _, x in { -0.9, 0.9 } do
		piece(ctx, Vector3.new(0.3, 0.8, 0.8), CFrame.new(x, 4.6, -3.3) * CFrame.Angles(0, math.pi, 0), body, nil, "wedge")
	end
	eyes(ctx, 3.8, -4.55, 0.6, 0.45)
	piece(ctx, Vector3.new(0.15, 2, 0.15), Vector3.new(0.4, 5, 0.4), Color3.fromRGB(230, 210, 170))
	piece(ctx, Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.4, 6.1, 0.4), Color3.fromRGB(90, 130, 40), nil, "ball")
end

-- Baagel Bleatski: a sesame bagel standing on its edge, with a woolly sheep head on the front.
BUILDERS.sheep = function(ctx, body, accent)
	for i = 0, 11 do
		local a = i * math.pi / 6
		piece(ctx, Vector3.new(1.9, 1.9, 1.9), Vector3.new(0, 3.6 + math.sin(a) * 1.8, math.cos(a) * 1.8), body, Enum.Material.Sand, "blob")
	end
	for i = 0, 5 do
		local a = i * math.pi / 3 + 0.3
		piece(ctx, Vector3.new(0.2, 0.15, 0.35), Vector3.new(0.95, 3.6 + math.sin(a) * 1.8, math.cos(a) * 1.8), WHITE)
		piece(ctx, Vector3.new(0.2, 0.15, 0.35), Vector3.new(-0.95, 3.6 + math.sin(a + 0.5) * 1.8, math.cos(a + 0.5) * 1.8), WHITE)
	end
	piece(ctx, Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 4.6, -3.2), accent, Enum.Material.Fabric, "blob")
	piece(ctx, Vector3.new(1.3, 1.6, 1), Vector3.new(0, 4.1, -4.1), BLACK)
	for _, x in { -1, 1 } do
		piece(ctx, Vector3.new(1.1, 0.4, 0.5), Vector3.new(x * 1.2, 4.7, -3.7), BLACK)
	end
	eyes(ctx, 4.5, -4.62, 0.35, 0.35, Color3.fromRGB(255, 255, 255))
	legs(ctx, 0.5, 1.9, 0.6, -1.6, 1.6, BLACK)
end

-- Beanburro: a donkey whose body is a fat burrito, beans and lettuce spilling out of both ends.
BUILDERS.burro = function(ctx, body, accent)
	piece(ctx, Vector3.new(5.6, 3.2, 3.2), CFrame.new(0, 3.6, 0.3) * CFrame.Angles(0, math.pi / 2, 0), body, Enum.Material.Sand, "cyl")
	for i, z in { -2.55, 3.15 } do
		piece(ctx, Vector3.new(0.4, 2.7, 2.7), CFrame.new(0, 3.6, z) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(110, 60, 40), Enum.Material.Sand, "cyl")
		piece(ctx, Vector3.new(0.3, 1.2, 1.2), CFrame.new(0.6, 4.1, z + (if i == 1 then -0.2 else 0.2)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(110, 200, 70), Enum.Material.Grass, "cyl")
		piece(ctx, Vector3.new(0.3, 0.9, 0.9), CFrame.new(-0.7, 3.2, z + (if i == 1 then -0.2 else 0.2)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(230, 60, 50), nil, "cyl")
	end
	for _, z in { -1, 0.6, 2.2 } do
		piece(ctx, Vector3.new(3.3, 0.25, 0.4), Vector3.new(0, 5.15, z), Color3.fromRGB(200, 170, 120), Enum.Material.Sand)
	end
	legs(ctx, 0.7, 2.2, 1.1, -1.4, 2, accent)
	piece(ctx, Vector3.new(1.3, 2.4, 1.3), CFrame.new(0, 5.2, -2.6) * CFrame.Angles(0.35, 0, 0), accent, Enum.Material.Fabric)
	piece(ctx, Vector3.new(1.6, 1.6, 2.6), Vector3.new(0, 6.2, -3.4), accent, Enum.Material.Fabric, "blob")
	piece(ctx, Vector3.new(1.4, 1.1, 1.2), Vector3.new(0, 5.8, -4.5), Color3.fromRGB(215, 200, 185), Enum.Material.Fabric, "blob")
	for _, x in { -0.5, 0.5 } do
		piece(ctx, Vector3.new(0.45, 2.4, 0.35), CFrame.new(x, 7.6, -3) * CFrame.Angles(0.2, 0, x * 0.5), accent, Enum.Material.Fabric)
	end
	googly(ctx, 6.6, -4.2, 0.5, 0.5)
	piece(ctx, Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 4.4, 3.6) * CFrame.Angles(0.9, 0, 0), BLACK, Enum.Material.Fabric)
end

-- Cactopus Rex: a saguaro octopus with a pink desert flower on its head.
BUILDERS.cactopus = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.6, 4.4, 3.6), Vector3.new(0, 4.2, 0), body, Enum.Material.Grass, "blob")
	for i = 0, 7 do
		local a = i * math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		piece(ctx, Vector3.new(3, 0.9, 0.9), CFrame.lookAt(dir * 2.2 + Vector3.new(0, 1.2, 0), dir * 6 + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.pi / 2, 0), body, Enum.Material.Grass, "cyl")
		piece(ctx, Vector3.new(0.75, 1.5, 0.75), CFrame.new(dir * 3.8 + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, 0.3 * math.cos(a)), body, Enum.Material.Grass, "blob")
	end
	for i = 0, 11 do
		local a = i * 0.9
		piece(ctx, Vector3.new(0.12, 0.6, 0.12), CFrame.new(math.cos(a) * 1.75, 3.2 + (i % 4) * 0.7, math.sin(a) * 1.75) * CFrame.Angles(0, -a, math.pi / 2), WHITE)
	end
	for i = 0, 4 do
		local a = i * math.pi * 2 / 5
		keep(piece(ctx, Vector3.new(0.9, 0.3, 0.9), Vector3.new(math.cos(a) * 0.55, 6.5, math.sin(a) * 0.55), accent, nil, "blob"))
	end
	keep(piece(ctx, Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 6.65, 0), Color3.fromRGB(255, 230, 80), Enum.Material.Neon, "ball"))
	googly(ctx, 4.8, -1.55, 0.7, 0.8)
	piece(ctx, Vector3.new(1, 0.25, 0.2), Vector3.new(0, 3.7, -1.75), BLACK)
end

-- Goatcho Supremo: a goat bristling with tortilla-chip wedges and dripping cheese.
BUILDERS.goat = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.4, 2.8, 4.8), Vector3.new(0, 3.6, 0), accent, nil, "blob")
	for i = 0, 9 do
		local a = i * math.pi / 5
		piece(ctx, Vector3.new(0.25, 1.8, 1.8), CFrame.new(math.cos(a) * 1.5, 3.6 + math.sin(a) * 1.3, (i % 3 - 1) * 1.4) * CFrame.Angles(a, 0.3 * i, a), body, Enum.Material.Sand, "wedge")
	end
	for _, x in { -1.2, 0.3, 1.4 } do
		piece(ctx, Vector3.new(0.6, 1.2, 0.6), Vector3.new(x, 2.4, x * 0.8), ORANGE, nil, "blob")
	end
	legs(ctx, 0.6, 2.4, 1, -1.5, 1.5, Color3.fromRGB(150, 110, 70))
	piece(ctx, Vector3.new(1.6, 1.8, 2.4), Vector3.new(0, 5.2, -2.8), Color3.fromRGB(200, 160, 110))
	for _, x in { -1, 1 } do
		piece(ctx, Vector3.new(0.4, 1.8, 0.4), CFrame.new(x * 0.7, 6.8, -2.4) * CFrame.Angles(-0.5, 0, x * 0.4), Color3.fromRGB(90, 70, 60))
		piece(ctx, Vector3.new(0.35, 1.2, 0.35), CFrame.new(x * 1.1, 7.6, -1.6) * CFrame.Angles(-1.4, 0, x * 0.4), Color3.fromRGB(90, 70, 60))
	end
	piece(ctx, Vector3.new(0.7, 1.4, 0.5), Vector3.new(0, 3.9, -3.9), Color3.fromRGB(250, 240, 210))
	eyes(ctx, 5.6, -4.05, 0.5, 0.4)
end

-- Toastallion: a chrome toaster on four long legs, two slices popping out of its back.
BUILDERS.horse = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.4, 3, 5.2), Vector3.new(0, 4.6, 0), body, Enum.Material.Metal)
	for _, x in { -0.8, 0.8 } do
		piece(ctx, Vector3.new(0.7, 0.12, 3.8), Vector3.new(x, 6.12, 0), BLACK)
		piece(ctx, Vector3.new(0.45, 2.2, 3.3), Vector3.new(x, 6.8, 0), accent, Enum.Material.Sand)
	end
	piece(ctx, Vector3.new(0.4, 0.5, 1), Vector3.new(1.85, 5, 1.2), BLACK)
	legs(ctx, 0.8, 3.1, 1.1, -1.8, 1.8, Color3.fromRGB(120, 125, 135))
	piece(ctx, Vector3.new(1.3, 3.2, 1.3), CFrame.new(0, 6.6, -2.8) * CFrame.Angles(-0.45, 0, 0), body, Enum.Material.Metal)
	piece(ctx, Vector3.new(1.5, 1.7, 3.2), Vector3.new(0, 8, -4), body, Enum.Material.Metal)
	piece(ctx, Vector3.new(0.5, 2.6, 0.6), CFrame.new(0, 8.1, -2.4) * CFrame.Angles(-0.45, 0, 0), accent, Enum.Material.Sand)
	eyes(ctx, 8.4, -5.1, 0.45, 0.35)
	piece(ctx, Vector3.new(0.4, 0.4, 2.6), CFrame.new(0, 4, 3.4) * CFrame.Angles(0.8, 0, 0), BLACK)
end

-- Jalapeño Jackalope: a chili-pepper rabbit with deer antlers and a stem for a tail.
BUILDERS.jackalope = function(ctx, body, accent)
	piece(ctx, Vector3.new(2.8, 3.6, 4.2), CFrame.new(0, 2.8, 0.4) * CFrame.Angles(0.35, 0, 0), body, Enum.Material.Glass, "blob")
	piece(ctx, Vector3.new(2.2, 2.2, 2.4), Vector3.new(0, 4.8, -1.4), body, Enum.Material.Glass, "blob")
	piece(ctx, Vector3.new(1.2, 1, 1), Vector3.new(0, 4.4, -2.6), Color3.fromRGB(110, 200, 90), Enum.Material.Glass, "blob")
	keep(piece(ctx, Vector3.new(0.45, 0.35, 0.3), Vector3.new(0, 4.6, -3.1), PINK, nil, "ball"))
	for _, x in { -0.55, 0.55 } do
		piece(ctx, Vector3.new(0.6, 2.6, 0.3), CFrame.new(x, 6.6, -1) * CFrame.Angles(0.15, 0, x * 0.35), body, Enum.Material.Glass, "blob")
		-- antlers: a main tine and two branches each side
		piece(ctx, Vector3.new(0.25, 1.8, 0.25), CFrame.new(x * 1.8, 6.2, -1.3) * CFrame.Angles(0, 0, x * 1.1), accent, Enum.Material.Wood)
		piece(ctx, Vector3.new(0.22, 1.2, 0.22), CFrame.new(x * 2.4, 7.1, -1.3) * CFrame.Angles(0, 0, x * 0.2), accent, Enum.Material.Wood)
		piece(ctx, Vector3.new(0.22, 1, 0.22), CFrame.new(x * 1.8, 7.1, -1.3) * CFrame.Angles(0, 0, -x * 0.4), accent, Enum.Material.Wood)
		piece(ctx, Vector3.new(0.9, 0.6, 2.4), Vector3.new(x * 1.1, 0.4, 0.4), body, Enum.Material.Glass, "blob")
		piece(ctx, Vector3.new(0.5, 1.4, 0.5), Vector3.new(x * 0.8, 1, -1.4), body, Enum.Material.Glass)
	end
	googly(ctx, 5.2, -2.45, 0.6, 0.6)
	piece(ctx, Vector3.new(0.5, 1.4, 0.5), CFrame.new(0, 3.8, 2.6) * CFrame.Angles(-0.8, 0, 0), Color3.fromRGB(80, 120, 40), Enum.Material.Grass, "cyl")
end

-- Wienerbago: a long dachshund-shaped hot dog in a bun, with a tiny camper van on its back.
BUILDERS.wiener = function(ctx, body, accent)
	piece(ctx, Vector3.new(7.4, 1.8, 1.8), CFrame.new(0, 2.4, 0) * CFrame.Angles(0, math.pi / 2, 0), body, nil, "cyl")
	for _, x in { -1, 1 } do
		piece(ctx, Vector3.new(1.1, 1.5, 7), Vector3.new(x * 1.1, 2.1, 0), accent, Enum.Material.Sand, "blob")
	end
	for i = 0, 6 do
		keep(piece(ctx, Vector3.new(0.9, 0.2, 0.25), CFrame.new(0, 3.35, -2.7 + i * 0.9) * CFrame.Angles(0, if i % 2 == 0 then 0.6 else -0.6, 0), Color3.fromRGB(255, 220, 40)))
	end
	legs(ctx, 0.5, 1.5, 0.6, -2.6, 2.6, body)
	piece(ctx, Vector3.new(1.6, 1.6, 2.4), Vector3.new(0, 3.4, -4.2), body, nil, "blob")
	piece(ctx, Vector3.new(0.9, 0.7, 1), Vector3.new(0, 3.1, -5.3), body, nil, "blob")
	keep(piece(ctx, Vector3.new(0.4, 0.35, 0.3), Vector3.new(0, 3.25, -5.8), BLACK, nil, "ball"))
	for _, x in { -0.85, 0.85 } do
		piece(ctx, Vector3.new(0.3, 1.6, 0.9), CFrame.new(x, 3, -3.9) * CFrame.Angles(0, 0, x * 0.3), Color3.fromRGB(150, 60, 45), nil, "blob")
	end
	googly(ctx, 3.9, -5.1, 0.45, 0.45)
	-- the camper
	piece(ctx, Vector3.new(2.2, 1.7, 3), Vector3.new(0, 4.4, 0.6), WHITE)
	piece(ctx, Vector3.new(2.25, 0.35, 3.05), Vector3.new(0, 4.1, 0.6), Color3.fromRGB(230, 70, 60))
	for _, z in { -0.2, 1.2 } do
		keep(piece(ctx, Vector3.new(2.3, 0.6, 0.7), Vector3.new(0, 4.75, z), Color3.fromRGB(120, 200, 255), Enum.Material.Glass))
	end
	piece(ctx, Vector3.new(0.4, 0.4, 2.2), CFrame.new(0, 2.6, 4.4) * CFrame.Angles(-0.5, 0, 0), body, nil, "blob")
end

-- Llamplighter: a long-necked llama whose head is a glowing table lamp.
BUILDERS.llama = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.2, 3.2, 4.6), Vector3.new(0, 4.2, 0), body, Enum.Material.Fabric, "blob")
	legs(ctx, 0.75, 2.8, 1, -1.6, 1.6, body)
	piece(ctx, Vector3.new(1.3, 5.6, 1.3), Vector3.new(0, 7.6, -1.7), body, Enum.Material.Fabric)
	piece(ctx, Vector3.new(1.5, 1.6, 2.2), Vector3.new(0, 10.4, -2.1), body, Enum.Material.Fabric)
	eyes(ctx, 10.7, -3.2, 0.4, 0.35)
	local bulb = keep(piece(ctx, Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 11.6, -1.9), Color3.fromRGB(255, 250, 200), Enum.Material.Neon, "ball"))
	glow(bulb, Color3.fromRGB(255, 220, 140), 14, 2)
	piece(ctx, Vector3.new(2.4, 3.6, 3.6), CFrame.new(0, 12.4, -1.9) * CFrame.Angles(0, 0, math.pi / 2), accent, Enum.Material.Fabric, "cyl").Transparency = 0.15
	for _, x in { -0.5, 0.5 } do
		piece(ctx, Vector3.new(0.3, 1, 0.3), Vector3.new(x, 14.4, -1.9), body, Enum.Material.Fabric)
	end
end

-- Duckwaffle Deluxe: a duck with waffle wings, a butter pat and a syrup hat.
BUILDERS.duck = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.3, 2.9, 4.6), Vector3.new(0, 2.7, 0), body, nil, "blob")
	piece(ctx, Vector3.new(2.1, 2.1, 2.1), Vector3.new(0, 5, -1.8), body, nil, "blob")
	piece(ctx, Vector3.new(1.5, 0.5, 1.5), Vector3.new(0, 4.8, -3), ORANGE)
	eyes(ctx, 5.4, -2.7, 0.55, 0.4)
	for _, x in { -1.95, 1.95 } do
		piece(ctx, Vector3.new(0.4, 2.6, 3.2), Vector3.new(x, 3.1, 0.2), accent, Enum.Material.Sand)
		for _, y in { 2.3, 3.1, 3.9 } do
			piece(ctx, Vector3.new(0.5, 0.16, 3.2), Vector3.new(x, y, 0.2), Color3.fromRGB(160, 100, 40))
		end
		for _, z in { -0.8, 0.2, 1.2 } do
			piece(ctx, Vector3.new(0.5, 2.6, 0.16), Vector3.new(x, 3.1, z), Color3.fromRGB(160, 100, 40))
		end
	end
	piece(ctx, Vector3.new(1.6, 0.5, 1.6), Vector3.new(0, 6.05, -1.8), Color3.fromRGB(130, 60, 20), Enum.Material.Glass, "blob")
	piece(ctx, Vector3.new(0.8, 0.35, 0.8), Vector3.new(0, 6.4, -1.8), Color3.fromRGB(255, 240, 150))
	for _, x in { -0.7, 0.7 } do
		piece(ctx, Vector3.new(0.3, 1.2, 0.3), Vector3.new(x, 0.6, 0), ORANGE)
		piece(ctx, Vector3.new(1, 0.2, 1.3), Vector3.new(x, 0.1, -0.3), ORANGE)
	end
end

-- Banjo Buzzard: a bald vulture whose belly is a banjo, wings spread like it's mid-solo.
BUILDERS.buzzard = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.4, 4, 3), Vector3.new(0, 3.9, 0.3), body, Enum.Material.Fabric, "blob")
	piece(ctx, Vector3.new(0.6, 3.6, 3.6), CFrame.new(0, 3.6, -1.2) * CFrame.Angles(0, math.pi / 2, 0), accent, nil, "cyl")
	piece(ctx, Vector3.new(0.5, 3.75, 3.75), CFrame.new(0, 3.6, -1) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(190, 190, 200), Enum.Material.Metal, "cyl")
	piece(ctx, Vector3.new(0.5, 4.6, 0.35), CFrame.new(1.2, 6.2, -1.6) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(120, 75, 40), Enum.Material.Wood)
	for _, dx in { -0.12, 0, 0.12 } do
		keep(piece(ctx, Vector3.new(0.05, 4.4, 0.05), CFrame.new(0.6 + dx, 5.4, -1.85) * CFrame.Angles(0, 0, -0.5), WHITE, Enum.Material.Neon))
	end
	for _, x in { -1, 1 } do
		piece(ctx, Vector3.new(4.2, 0.4, 2.6), CFrame.new(x * 3.4, 5.2, 0.8) * CFrame.Angles(0, 0, x * 0.45), body, Enum.Material.Fabric)
		piece(ctx, Vector3.new(2.2, 0.35, 1.8), CFrame.new(x * 5.6, 6.4, 1.2) * CFrame.Angles(0, 0, x * 0.75), body, Enum.Material.Fabric)
		piece(ctx, Vector3.new(0.35, 1.8, 0.35), Vector3.new(x * 0.7, 0.9, 0.4), ORANGE)
	end
	piece(ctx, Vector3.new(1.4, 0.7, 1.4), Vector3.new(0, 6, 0), Color3.fromRGB(240, 235, 225), Enum.Material.Fabric, "blob")
	piece(ctx, Vector3.new(0.6, 1.7, 0.6), CFrame.new(0, 6.9, -0.4) * CFrame.Angles(-0.3, 0, 0), PINK)
	piece(ctx, Vector3.new(1.5, 1.4, 1.7), Vector3.new(0, 8, -0.9), PINK, nil, "blob")
	piece(ctx, Vector3.new(0.5, 0.6, 1), CFrame.new(0, 7.7, -2) * CFrame.Angles(0.4, 0, 0), Color3.fromRGB(240, 200, 60), nil, "wedge")
	googly(ctx, 8.3, -1.6, 0.45, 0.5)
end

-- Rattlesnack: a coiled rattlesnake made of soft pretzel, salted, in a tiny cowboy hat.
BUILDERS.snake = function(ctx, body, accent)
	for i = 0, 29 do
		local a = i * 0.55
		local r = 2.4 - i * 0.05
		local y = 0.8 + i * 0.12
		piece(ctx, Vector3.new(1.4, 1.2, 1.4), Vector3.new(math.cos(a) * r, y, math.sin(a) * r + 0.6), body, Enum.Material.Sand, "ball")
		if i % 3 == 0 then
			piece(ctx, Vector3.new(0.25, 0.2, 0.25), Vector3.new(math.cos(a) * r, y + 0.6, math.sin(a) * r + 0.6), accent)
		end
	end
	for j = 1, 4 do
		piece(ctx, Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 4.4 + j * 0.45, -0.6 - j * 0.35), body, Enum.Material.Sand, "ball")
	end
	piece(ctx, Vector3.new(1.8, 1.2, 2.2), Vector3.new(0, 6.6, -2.4), body, Enum.Material.Sand, "blob")
	keep(piece(ctx, Vector3.new(0.12, 0.12, 1), CFrame.new(0, 6.3, -3.8), Color3.fromRGB(230, 40, 50), Enum.Material.Neon))
	googly(ctx, 7, -3.2, 0.5, 0.5)
	piece(ctx, Vector3.new(2.8, 0.15, 2.6), Vector3.new(0, 7.3, -2.2), Color3.fromRGB(90, 55, 30))
	piece(ctx, Vector3.new(1.5, 0.9, 1.4), Vector3.new(0, 7.75, -2.2), Color3.fromRGB(90, 55, 30))
	for k = 0, 3 do
		piece(ctx, Vector3.new(0.7 - k * 0.1, 0.45, 0.7 - k * 0.1), Vector3.new(2.6, 1.2 + k * 0.45, 1.6), Color3.fromRGB(220, 200, 150), Enum.Material.Sand, "blob")
	end
end

-- Tractortoise: a tortoise shell on tractor wheels with a smoking exhaust stack.
BUILDERS.tortoise = function(ctx, body, accent)
	piece(ctx, Vector3.new(5.2, 3.8, 6.2), Vector3.new(0, 3.2, 0), body, Enum.Material.Slate, "blob")
	for _, spot in { Vector3.new(0, 5, 0), Vector3.new(1.6, 4.2, 1.4), Vector3.new(-1.6, 4.2, -1.4), Vector3.new(1.5, 4.3, -1.6), Vector3.new(-1.5, 4.3, 1.5) } do
		piece(ctx, Vector3.new(1.4, 0.5, 1.4), spot, Color3.fromRGB(40, 100, 45), Enum.Material.Slate, "blob")
	end
	piece(ctx, Vector3.new(5.6, 0.7, 6.6), Vector3.new(0, 1.8, 0), Color3.fromRGB(240, 200, 40))
	for _, x in { -2.9, 2.9 } do
		for _, z in { -2, 2 } do
			local big = z > 0
			local d = if big then 3.4 else 2.4
			piece(ctx, Vector3.new(1, d, d), Vector3.new(x, d / 2, z), accent, Enum.Material.Rubber, "cyl")
			piece(ctx, Vector3.new(1.1, d * 0.45, d * 0.45), Vector3.new(x, d / 2, z), Color3.fromRGB(240, 200, 40), nil, "cyl")
		end
	end
	piece(ctx, Vector3.new(1.7, 1.5, 2.2), Vector3.new(0, 2.3, -3.8), Color3.fromRGB(130, 160, 80), nil, "blob")
	eyes(ctx, 2.7, -4.8, 0.4, 0.35)
	local stack = piece(ctx, Vector3.new(0.5, 2.6, 0.5), Vector3.new(1.3, 6, 1.2), Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
	local smoke = emitter(stack, SMOKE, Color3.fromRGB(90, 90, 90), 4, 1.4, 3)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.EmissionDirection = Enum.NormalId.Top
end

-- Sheriff Scarecrowbar: a straw scarecrow in a sheriff's star and hat, crowbar in hand.
BUILDERS.scarecrow = function(ctx, body, accent)
	piece(ctx, Vector3.new(0.6, 7.6, 0.6), Vector3.new(0, 3.8, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	piece(ctx, Vector3.new(2.8, 3.2, 1.5), Vector3.new(0, 5.4, 0), accent, Enum.Material.Fabric)
	piece(ctx, Vector3.new(6.4, 0.8, 0.8), Vector3.new(0, 6.3, 0), accent, Enum.Material.Fabric)
	for _, x in { -3.4, 3.4 } do
		piece(ctx, Vector3.new(0.9, 1, 1), Vector3.new(x, 6.2, 0), HAY, Enum.Material.Fabric, "blob")
	end
	piece(ctx, Vector3.new(2.2, 0.9, 1.6), Vector3.new(0, 3.5, 0), HAY, Enum.Material.Fabric, "blob")
	piece(ctx, Vector3.new(2.2, 2.4, 2.1), Vector3.new(0, 8.2, 0), body, Enum.Material.Fabric, "blob")
	eyes(ctx, 8.5, -0.95, 0.45, 0.4)
	piece(ctx, Vector3.new(1.2, 0.15, 0.1), Vector3.new(0, 7.6, -1.02), BLACK)
	piece(ctx, Vector3.new(3.8, 0.25, 3.4), Vector3.new(0, 9.35, 0), Color3.fromRGB(90, 60, 35))
	piece(ctx, Vector3.new(2, 1.4, 1.9), Vector3.new(0, 10.1, 0), Color3.fromRGB(90, 60, 35))
	keep(piece(ctx, Vector3.new(0.8, 0.8, 0.12), CFrame.new(0.7, 5.9, -0.8) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 210, 60), Enum.Material.Neon))
	piece(ctx, Vector3.new(0.25, 3.6, 0.25), Vector3.new(3.4, 5, -0.4), Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
	piece(ctx, Vector3.new(0.25, 0.25, 0.9), Vector3.new(3.4, 6.7, -0.75), Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
end

-- Haybale Hydra: a square hay bale with three green serpent necks, one chewing a straw.
BUILDERS.hydra = function(ctx, body, accent)
	piece(ctx, Vector3.new(6, 3.6, 4.4), Vector3.new(0, 1.9, 0.6), body, Enum.Material.Fabric)
	for _, x in { -1.6, 1.6 } do
		piece(ctx, Vector3.new(0.25, 3.7, 4.5), Vector3.new(x, 1.9, 0.6), Color3.fromRGB(120, 80, 40), Enum.Material.Fabric)
	end
	for i = 0, 9 do
		piece(ctx, Vector3.new(0.1, 0.6, 0.1), CFrame.new(-2.6 + i * 0.6, 3.9, -1.5 + (i % 3)) * CFrame.Angles(0.4, 0, (i % 2 - 0.5)), Color3.fromRGB(240, 210, 120), Enum.Material.Fabric)
	end
	for k = -1, 1 do
		local lean = k * 0.8
		local tall = if k == 0 then 1.25 else 1
		for j = 1, 6 do
			piece(ctx, Vector3.new(1.2, 1.2, 1.2), Vector3.new(k * 1.6 + lean * j * 0.35, 3.6 + j * 0.85 * tall, 0.2 - j * 0.3), accent, Enum.Material.Grass, "ball")
		end
		local head = Vector3.new(k * 1.6 + lean * 2.4, 3.6 + 6.3 * tall, -1.9)
		piece(ctx, Vector3.new(1.6, 1.2, 2.2), head, accent, Enum.Material.Grass, "blob")
		googly(ctx, head.Y + 0.45, head.Z - 0.6, 0.45, 0.45)
		if k == 0 then
			piece(ctx, Vector3.new(0.12, 0.12, 2), CFrame.new(head + Vector3.new(0.5, -0.3, -1)) * CFrame.Angles(0, 0.6, 0), Color3.fromRGB(240, 210, 120))
		end
	end
end

-- Disco Udderlord: a glitter cow with a mirror ball on its head and a neon udder.
BUILDERS.disco = function(ctx, body, accent)
	cowBody(ctx, body, accent, Enum.Material.Glass)
	piece(ctx, Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 6, -3.5), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	local ball = keep(piece(ctx, Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 7.6, -3.5), Color3.fromRGB(220, 225, 235), Enum.Material.Foil, "ball"))
	ball.Reflectance = 0.5
	keep(piece(ctx, Vector3.new(1.4, 0.9, 1.4), Vector3.new(0, 1.8, 0.8), accent, Enum.Material.Neon, "blob"))
	glow(ball, accent, 16, 3)
	local sparkle = emitter(ball, SPARKLES, Color3.fromRGB(255, 120, 230), 10, 0.5, 6)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 120, 230), Color3.fromRGB(120, 220, 255))
end

-- Brisket Bronco: a horse built from a barbecue smoker barrel, mane of flame, grill-grate ribs.
BUILDERS.smoker = function(ctx, body, accent)
	piece(ctx, Vector3.new(6, 3.6, 3.6), CFrame.new(0, 4.6, 0.2) * CFrame.Angles(0, math.pi / 2, 0), body, Enum.Material.DiamondPlate, "cyl")
	for _, z in { -1.6, -0.6, 0.4, 1.4, 2.4 } do
		keep(piece(ctx, Vector3.new(3.75, 0.25, 0.25), CFrame.new(0, 4.6, z) * CFrame.Angles(0, 0, 0), accent, Enum.Material.Neon))
	end
	piece(ctx, Vector3.new(2.6, 2.2, 2.2), Vector3.new(0, 4.2, 3.6), Color3.fromRGB(70, 65, 70), Enum.Material.Metal)
	local chimney = piece(ctx, Vector3.new(0.7, 3.2, 0.7), Vector3.new(0.8, 7.2, 3.6), Color3.fromRGB(60, 58, 60), Enum.Material.Metal)
	local smoke = emitter(chimney, SMOKE, Color3.fromRGB(120, 110, 110), 6, 2, 4)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.EmissionDirection = Enum.NormalId.Top
	legs(ctx, 0.7, 3, 1.3, -1.6, 2.2, Color3.fromRGB(80, 78, 82), Enum.Material.Metal)
	piece(ctx, Vector3.new(1.4, 3.4, 1.4), CFrame.new(0, 7, -2.6) * CFrame.Angles(-0.45, 0, 0), body, Enum.Material.Metal)
	piece(ctx, Vector3.new(1.7, 1.8, 3.4), Vector3.new(0, 8.4, -3.9), body, Enum.Material.Metal)
	eyes(ctx, 8.8, -5.2, 0.55, 0.4, accent)
	local mane = keep(piece(ctx, Vector3.new(0.5, 0.6, 3), CFrame.new(0, 8.6, -2.2) * CFrame.Angles(-0.45, 0, 0), accent, Enum.Material.Neon))
	local flame = Instance.new("Fire")
	flame.Color = Color3.fromRGB(255, 140, 40)
	flame.SecondaryColor = Color3.fromRGB(255, 60, 20)
	flame.Size = 4 * ctx.scale
	flame.Heat = 8
	flame.Parent = mane
	glow(mane, accent, 14, 2)
end

-- The Moothership: a flying saucer piloted by a cow, hovering on its own tractor beam.
BUILDERS.saucer = function(ctx, body, accent)
	local beam = keep(piece(ctx, Vector3.new(4.2, 4.6, 4.6), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.pi / 2), accent, Enum.Material.Neon, "cyl"))
	beam.Transparency = 0.72
	piece(ctx, Vector3.new(1.2, 8, 8), CFrame.new(0, 4.8, 0) * CFrame.Angles(0, 0, math.pi / 2), body, Enum.Material.Metal, "cyl")
	piece(ctx, Vector3.new(1.6, 6, 6), CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 125, 140), Enum.Material.Metal, "cyl")
	for i = 0, 9 do
		local a = i * math.pi / 5
		keep(piece(ctx, Vector3.new(0.6, 0.6, 0.6), Vector3.new(math.cos(a) * 3.7, 4.8, math.sin(a) * 3.7), if i % 2 == 0 then accent else Color3.fromRGB(255, 240, 120), Enum.Material.Neon, "ball"))
	end
	-- the pilot, under a glass dome
	piece(ctx, Vector3.new(2.6, 1.8, 2.4), Vector3.new(0, 6.3, 0.3), WHITE, nil, "blob")
	piece(ctx, Vector3.new(1.8, 1.6, 1.6), Vector3.new(0, 7.1, -0.7), WHITE)
	piece(ctx, Vector3.new(0.7, 0.5, 0.6), Vector3.new(0.5, 7.5, -0.6), BLACK)
	piece(ctx, Vector3.new(1.4, 0.7, 0.4), Vector3.new(0, 6.7, -1.5), PINK)
	eyes(ctx, 7.4, -1.5, 0.45, 0.35)
	for _, x in { -0.6, 0.6 } do
		piece(ctx, Vector3.new(0.3, 0.8, 0.3), Vector3.new(x, 8.1, -0.6), WHITE)
	end
	local dome = keep(piece(ctx, Vector3.new(4.4, 4.4, 4.4), Vector3.new(0, 5.6, 0), Color3.fromRGB(180, 240, 255), Enum.Material.Glass, "ball"))
	dome.Transparency = 0.6
	glow(beam, accent, 16, 2.5)
end

-- A rot bull: the Grand Rotfather wears a crown; the stampede's bulls do not.
local function bullBody(ctx: Ctx, body: Color3, accent: Color3, crowned: boolean)
	piece(ctx, Vector3.new(5, 4, 7), Vector3.new(0, 4.4, 0.4), body, Enum.Material.Slate, "blob")
	piece(ctx, Vector3.new(4.4, 3, 3.6), Vector3.new(0, 5.6, -1.8), body, Enum.Material.Slate, "blob")
	legs(ctx, 1.2, 2.6, 1.5, -2.2, 2.4, Color3.fromRGB(40, 30, 26))
	piece(ctx, Vector3.new(3, 2.7, 2.8), Vector3.new(0, 4.9, -4.3), body, Enum.Material.Slate)
	piece(ctx, Vector3.new(2.4, 1.3, 0.8), Vector3.new(0, 4.1, -5.7), Color3.fromRGB(120, 80, 70))
	for _, x in { -1, 1 } do
		piece(ctx, Vector3.new(2.6, 0.6, 0.6), Vector3.new(x * 2.6, 6, -4.3), WHITE)
		piece(ctx, Vector3.new(0.6, 1.6, 0.6), Vector3.new(x * 3.6, 6.9, -4.3), WHITE)
	end
	eyes(ctx, 5.6, -5.75, 0.8, 0.6, accent)
	keep(piece(ctx, Vector3.new(0.3, 0.9, 0.9), Vector3.new(0, 3.5, -6.1), Color3.fromRGB(255, 200, 40), Enum.Material.Metal, "cyl"))
	if crowned then
		keep(piece(ctx, Vector3.new(2.6, 0.8, 2.4), Vector3.new(0, 6.7, -4.3), Color3.fromRGB(255, 205, 40), Enum.Material.Foil))
		for _, x in { -1, 0, 1 } do
			keep(piece(ctx, Vector3.new(0.5, 1.2, 0.5), CFrame.new(x * 0.9, 7.6, -4.3) * CFrame.Angles(0, math.pi / 4, 0), Color3.fromRGB(255, 205, 40), Enum.Material.Foil))
		end
	end
	for _, drip in { Vector3.new(2.2, 3, -1), Vector3.new(-2.3, 3.6, 1.5), Vector3.new(0.8, 2.4, 3) } do
		keep(piece(ctx, Vector3.new(0.7, 1.2, 0.7), drip, accent, Enum.Material.Neon, "blob"))
	end
	local fumes = emitter(ctx.root, SMOKE, accent, 6, 2, 2)
	fumes.Transparency = NumberSequence.new(0.5, 1)
end

BUILDERS.bull = function(ctx, body, accent)
	bullBody(ctx, body, accent, true)
end

-- Skelecow Supreme: a cow skeleton in a sheriff's hat, a purple soul-heart glowing in its ribs.
BUILDERS.skelecow = function(ctx, body, accent)
	for i = 0, 7 do
		piece(ctx, Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 5.6 - math.abs(i - 3.5) * 0.08, -2.6 + i * 0.75), body, nil, "ball")
	end
	for i = 0, 4 do
		local z = -2 + i * 0.85
		for _, x in { -1, 1 } do
			piece(ctx, Vector3.new(0.3, 2.8, 0.3), CFrame.new(x * 1.4, 4.4, z) * CFrame.Angles(0, 0, x * 0.35), body)
			piece(ctx, Vector3.new(0.3, 1.4, 0.3), CFrame.new(x * 1.05, 2.9, z) * CFrame.Angles(0, 0, -x * 0.5), body)
		end
	end
	local heart = keep(piece(ctx, Vector3.new(1.4, 1.3, 1.2), Vector3.new(0, 4.1, -0.4), accent, Enum.Material.Neon, "blob"))
	glow(heart, accent, 18, 3)
	piece(ctx, Vector3.new(3, 1.3, 1.6), Vector3.new(0, 4.6, 2.5), body, nil, "blob")
	for _, x in { -1, 1 } do
		for _, z in { -2, 2.4 } do
			piece(ctx, Vector3.new(0.4, 3.6, 0.4), Vector3.new(x * 1.2, 1.8, z), body, nil)
			piece(ctx, Vector3.new(0.7, 0.6, 0.7), Vector3.new(x * 1.2, 1.9, z), body, nil, "ball")
		end
	end
	piece(ctx, Vector3.new(2.4, 2.2, 2.8), Vector3.new(0, 6, -3.8), body)
	piece(ctx, Vector3.new(1.9, 1.3, 1.2), Vector3.new(0, 5.3, -5.4), body)
	for _, x in { -0.55, 0.55 } do
		keep(piece(ctx, Vector3.new(0.8, 0.8, 0.2), Vector3.new(x, 6.2, -5.22), BLACK))
		keep(piece(ctx, Vector3.new(0.35, 0.35, 0.3), Vector3.new(x, 6.2, -5.3), accent, Enum.Material.Neon, "ball"))
		piece(ctx, Vector3.new(2.2, 0.5, 0.5), Vector3.new(x * 3.4, 6.8, -3.6), body)
		piece(ctx, Vector3.new(0.5, 1.4, 0.5), Vector3.new(x * 4.3, 7.6, -3.6), body)
	end
	piece(ctx, Vector3.new(4, 0.25, 3.6), Vector3.new(0, 7.25, -3.8), BLACK)
	piece(ctx, Vector3.new(2.2, 1.3, 2.2), Vector3.new(0, 7.9, -3.8), BLACK)
	keep(piece(ctx, Vector3.new(2.25, 0.3, 2.25), Vector3.new(0, 7.45, -3.8), accent, Enum.Material.Neon))
	local wisps = emitter(heart, FIRE, accent, 12, 1.2, 3)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.SpreadAngle = Vector2.new(25, 25)
end

-- The finishes: each mutation is obvious from across the ranch, even in a screenshot.
local MUTATION_FX: { [string]: (Ctx, Color3) -> () } = {}

MUTATION_FX.Golden = function(ctx, tint)
	for _, p in ctx.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= ctx.root and p ~= ctx.body and not p:GetAttribute("Keep") then
			p.Color = p.Color:Lerp(tint, 0.8)
			p.Material = Enum.Material.Metal
			p.Reflectance = 0.25
		end
	end
	emitter(ctx.body, SPARKLES, tint, 8, 0.6 * ctx.scale, 3)
	glow(ctx.body, tint, 12 * ctx.scale, 1.5)
end

MUTATION_FX.Moldy = function(ctx, tint)
	for _, p in ctx.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= ctx.root and p ~= ctx.body and not p:GetAttribute("Keep") then
			p.Color = p.Color:Lerp(tint, 0.5)
		end
	end
	for i = 1, 7 do
		local a = i * 1.7
		piece(ctx, Vector3.new(0.9, 0.5, 0.9), Vector3.new(math.cos(a) * 1.6, 3 + (i % 3) * 0.8, math.sin(a) * 1.8), Color3.fromRGB(150, 220, 90), Enum.Material.Grass, "blob")
	end
	emitter(ctx.body, SMOKE, tint, 6, 1.4 * ctx.scale, 2)
end

MUTATION_FX.Spicy = function(ctx, tint)
	for _, p in ctx.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= ctx.root and p ~= ctx.body and not p:GetAttribute("Keep") then
			p.Color = p.Color:Lerp(tint, 0.45)
		end
	end
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 150, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 50, 20)
	fire.Size = 5 * ctx.scale
	fire.Heat = 12
	fire.Parent = ctx.body
	local embers = emitter(ctx.body, EMBERS, Color3.fromRGB(255, 160, 60), 16, 0.4 * ctx.scale, 6)
	embers.EmissionDirection = Enum.NormalId.Top
	glow(ctx.body, tint, 14 * ctx.scale, 2.5)
end

MUTATION_FX.Crystal = function(ctx, tint)
	for _, p in ctx.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= ctx.root and p ~= ctx.body and not p:GetAttribute("Keep") then
			p.Color = p.Color:Lerp(tint, 0.65)
			p.Material = Enum.Material.Glass
			p.Transparency = math.max(p.Transparency, 0.2)
			p.Reflectance = 0.35
		end
	end
	for i = 0, 4 do
		local a = i * 1.25
		keep(piece(ctx, Vector3.new(0.6, 2.2, 0.6), CFrame.new(math.cos(a) * 1.2, 5.4 + (i % 2) * 0.5, math.sin(a) * 1.2) * CFrame.Angles(0.3 * math.cos(a), a, 0.3 * math.sin(a)), Color3.fromRGB(200, 245, 255), Enum.Material.Neon))
	end
	emitter(ctx.body, SPARKLES, Color3.fromRGB(220, 250, 255), 12, 0.7 * ctx.scale, 4)
	glow(ctx.body, tint, 16 * ctx.scale, 3)
end

MUTATION_FX.Ghost = function(ctx, tint)
	for _, p in ctx.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= ctx.root and p ~= ctx.body and not p:GetAttribute("Keep") then
			p.Color = p.Color:Lerp(tint, 0.75)
			p.Material = Enum.Material.ForceField
			p.Transparency = 0
		end
	end
	local wisps = emitter(ctx.body, GLOW, tint, 10, 1.6 * ctx.scale, 2)
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.SpreadAngle = Vector2.new(30, 30)
	wisps.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.4), NumberSequenceKeypoint.new(1, 1) })
	glow(ctx.body, tint, 18 * ctx.scale, 2)
end

local function applyMutation(ctx: Ctx, mutation: string?)
	local tint = Cast.mutationTint(mutation)
	local fx = mutation and MUTATION_FX[mutation]
	if tint and fx then
		fx(ctx, tint)
	end
end

-- A model with an invisible anchored Root on the ground and a Body on a Motor6D ("Gait") above it.
local function newCtx(name: string, scale: number, at: CFrame): Ctx
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 0.4, 2) * scale
	root.CFrame = at
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.one * 0.2
	body.CFrame = at
	body.Anchored = false
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Massless = true
	body.Transparency = 1
	body.Parent = model
	local gait = Instance.new("Motor6D")
	gait.Name = "Gait"
	gait.Part0, gait.Part1 = root, body
	gait.Parent = root
	return { model = model, root = root, body = body, scale = scale }
end

function Critters.heightOf(id: string): number
	local critter = Cast.critterById(id)
	return HEIGHTS[critter.shape] * Cast.RARITIES[critter.rarity].scale
end

-- Builds a critter model of a cast id and mutation at a ground-level CFrame (it faces -Z).
function Critters.buildCritter(id: string, mutation: string?, at: CFrame): Model
	local critter = Cast.critterById(id)
	local ctx = newCtx(critter.name, Cast.RARITIES[critter.rarity].scale, at)
	BUILDERS[critter.shape](ctx, critter.body, critter.accent)
	applyMutation(ctx, mutation)
	ctx.model:SetAttribute("CritterId", id)
	ctx.model:SetAttribute("Mutation", mutation or "")
	ctx.model:SetAttribute("Gait", "trot")
	local point = Instance.new("Attachment")
	point.Name = "PromptPoint"
	point.Position = Vector3.new(0, Critters.heightOf(id) * 0.5, 0)
	point.Parent = ctx.root
	CollectionService:AddTag(ctx.model, "Critter")
	return ctx.model
end

-- A RanchDex portrait: the same critter, or an all-black silhouette when it is still undiscovered.
function Critters.buildPortrait(id: string, mutation: string?, silhouette: boolean): Model
	local critter = Cast.critterById(id)
	local ctx = newCtx(critter.name, 1, CFrame.new())
	BUILDERS[critter.shape](ctx, critter.body, critter.accent)
	if silhouette then
		for _, p in ctx.model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(28, 20, 16)
				p.Material = Enum.Material.SmoothPlastic
				p.Reflectance = 0
			end
		end
	elseif mutation then
		-- ViewportFrames draw neither ForceField nor reflections, so a portrait gets a plain tint.
		local tint = Cast.mutationTint(mutation) :: Color3
		for _, p in ctx.model:GetDescendants() do
			if p:IsA("BasePart") and p ~= ctx.root and p ~= ctx.body and not p:GetAttribute("Keep") then
				p.Color = p.Color:Lerp(tint, if mutation == "Moldy" then 0.45 else 0.65)
				if mutation == "Crystal" or mutation == "Ghost" then
					p.Transparency = math.max(p.Transparency, if mutation == "Ghost" then 0.35 else 0.2)
				end
			end
		end
	end
	return ctx.model
end

-- A charging bull for the stampede: big, dark, glowing-eyed, no crown.
function Critters.buildRotbull(at: CFrame): Model
	local ctx = newCtx("Rotbull", 1.9, at)
	bullBody(ctx, Color3.fromRGB(80, 56, 44), Color3.fromRGB(170, 255, 70), false)
	return ctx.model
end

-- A masked rustler: denim, a vest, a bandana and a black hat, built from parts on a moving root.
function Critters.buildRustler(at: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Rustler"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(3, 6, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = true
	root.CFrame = at * CFrame.new(0, 3, 0)
	root.Parent = model
	model.PrimaryPart = root
	local function limb(size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?, ball: boolean?)
		local p = Instance.new("Part")
		if ball then
			p.Shape = Enum.PartType.Ball
		end
		p.Size = size
		p.CFrame = root.CFrame * CFrame.new(offset)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, p
		weld.Parent = p
		p.Parent = model
	end
	local denim, vest, skin = Color3.fromRGB(50, 70, 120), Color3.fromRGB(90, 55, 30), Color3.fromRGB(230, 180, 140)
	limb(Vector3.new(0.9, 2.8, 0.9), Vector3.new(-0.5, -1.6, 0), denim, Enum.Material.Fabric)
	limb(Vector3.new(0.9, 2.8, 0.9), Vector3.new(0.5, -1.6, 0), denim, Enum.Material.Fabric)
	limb(Vector3.new(1, 0.6, 1.4), Vector3.new(-0.5, -2.9, -0.2), Color3.fromRGB(60, 35, 20))
	limb(Vector3.new(1, 0.6, 1.4), Vector3.new(0.5, -2.9, -0.2), Color3.fromRGB(60, 35, 20))
	limb(Vector3.new(2.2, 2.4, 1.1), Vector3.new(0, 0.8, 0), vest, Enum.Material.Fabric)
	limb(Vector3.new(0.8, 2.2, 0.8), Vector3.new(-1.5, 0.9, 0), Color3.fromRGB(200, 60, 50), Enum.Material.Fabric)
	limb(Vector3.new(0.8, 2.2, 0.8), Vector3.new(1.5, 0.9, 0), Color3.fromRGB(200, 60, 50), Enum.Material.Fabric)
	limb(Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 2.8, 0), skin, nil, true)
	limb(Vector3.new(1.6, 0.6, 1.6), Vector3.new(0, 2.5, 0), Color3.fromRGB(20, 20, 20), Enum.Material.Fabric)
	limb(Vector3.new(3, 0.2, 3), Vector3.new(0, 3.5, 0), Color3.fromRGB(25, 20, 18))
	limb(Vector3.new(1.6, 1, 1.6), Vector3.new(0, 4, 0), Color3.fromRGB(25, 20, 18))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(9, 2.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "RUSTLER!"
	label.TextColor3 = Color3.fromRGB(255, 90, 80)
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = root
	return model, root
end

-- The floating label: name, rarity (and mutation with its multiplier), money a second, and the
-- price while the critter is still on the drive.
function Critters.labelCritter(model: Model, id: string, mutation: string?, rebirths: number, price: number?)
	local old = model:FindFirstChild("CritterLabel")
	if old then
		old:Destroy()
	end
	local critter = Cast.critterById(id)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CritterLabel"
	gui.Adornee = model.PrimaryPart
	-- Studs plus a few pixels: big up close, still legible across the ranch.
	gui.Size = if price then UDim2.new(7, 40, 4, 22) else UDim2.new(6, 52, 3, 28)
	gui.StudsOffsetWorldSpace = Vector3.new(0, Critters.heightOf(id) + (if price then 3.4 else 2.6), 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = if price then 110 else 150
	gui.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui
	local function line(order: number, text: string, color: Color3, height: number, font: Enum.Font?)
		local label = Instance.new("TextLabel")
		label.LayoutOrder = order
		label.Size = UDim2.fromScale(1, height)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = font or Enum.Font.FredokaOne
		label.TextStrokeTransparency = 0
		label.Parent = gui
		return label
	end
	local total = if price then 5.6 else 4.4
	line(1, critter.name, Color3.fromRGB(255, 255, 255), 1.5 / total, Enum.Font.LuckiestGuy)
	local tag = Cast.rarityLabel(critter.rarity)
	if mutation then
		tag = string.upper(mutation) .. " x" .. Cast.mutationMult(mutation) .. "  " .. tag
	end
	line(2, tag, Cast.mutationTint(mutation) or Cast.rarityColor(critter.rarity), 1.2 / total, Enum.Font.LuckiestGuy)
	line(3, Cast.formatCash(Cast.incomeOf(id, mutation, rebirths)) .. "/s", Color3.fromRGB(120, 255, 110), 1.2 / total, Enum.Font.LuckiestGuy)
	if price then
		local tagLabel = line(4, Cast.formatCash(price), Color3.fromRGB(255, 225, 80), 1.6 / total, Enum.Font.LuckiestGuy)
		tagLabel.BackgroundTransparency = 0.35
		tagLabel.BackgroundColor3 = Color3.fromRGB(50, 30, 15)
	end
	gui.Parent = model
end

-- The lasso: a rope from the rancher's hand to a loop around the critter, left up while it flies
-- home. Returns a cleanup function.
function Critters.throwLasso(hand: BasePart, model: Model): () -> ()
	local root = model.PrimaryPart :: BasePart
	local height = Critters.heightOf(model:GetAttribute("CritterId") :: string)
	local rope = Instance.new("Folder")
	rope.Name = "LassoRope"
	local from = Instance.new("Attachment")
	from.Name = "LassoHand"
	from.Parent = hand
	local loopCenter = Instance.new("Attachment")
	loopCenter.Name = "LassoLoop"
	loopCenter.Position = Vector3.new(0, height * 0.55, 0)
	loopCenter.Parent = root
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = from, loopCenter
	beam.Color = ColorSequence.new(Color3.fromRGB(225, 175, 105))
	beam.Width0, beam.Width1 = 0.7, 0.6
	beam.Segments = 24
	beam.CurveSize0, beam.CurveSize1 = 6, -3
	beam.FaceCamera = true
	beam.LightInfluence = 0.2
	beam.LightEmission = 0.15
	beam.Parent = rope
	-- the loop: a ring of rope segments around the critter's middle
	local radius = math.max(2.2, height * 0.32)
	local parts = {}
	for i = 0, 13 do
		local a = i * math.pi * 2 / 14
		local seg = Instance.new("Part")
		seg.Name = "LoopSegment"
		seg.Size = Vector3.new(0.5, 0.5, radius * 0.5)
		seg.Color = Color3.fromRGB(225, 175, 105)
		seg.Material = Enum.Material.Fabric
		seg.CanCollide, seg.CanQuery, seg.CanTouch, seg.Massless = false, false, false, true
		seg.Anchored = false
		seg.CFrame = root.CFrame * CFrame.new(0, height * 0.55, 0) * CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, seg
		weld.Parent = seg
		seg.Parent = model
		table.insert(parts, seg)
	end
	rope.Parent = hand
	return function()
		rope:Destroy()
		from:Destroy()
		loopCenter:Destroy()
		for _, seg in parts do
			seg:Destroy()
		end
	end
end

-- A burst of dust or sparkle where a critter appears or vanishes.
function Critters.poof(position: Vector3, color: Color3, count: number?, texture: string?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = texture or SMOKE
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(1.5, 4)
	burst.Transparency = NumberSequence.new(0.2, 1)
	burst.Color = ColorSequence.new(color)
	burst.LightEmission = if texture then 0.8 else 0
	burst.Parent = anchor
	anchor.Parent = workspace
	burst:Emit(count or 24)
	Debris:AddItem(anchor, 2)
end

-- A bright sparkle shower (mutated lasso, rebirth, contracts).
function Critters.sparkle(position: Vector3, color: Color3, count: number?)
	Critters.poof(position, color, count, SPARKLES)
end

return Critters
