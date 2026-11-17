-- Critters: builds each Rot Ranch critter as its own 3D silhouette (a potato cow, a macaroni chicken,
-- a sandwich pig, a bagel sheep, a nacho goat, a toaster horse, a lamp llama, a waffle duck, a
-- tractor tortoise, a scarecrow sheriff, a disco cow and a crowned rot bull), gives it a mutation
-- finish, and hangs the name / rarity / $-a-second label over its head.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))

local Critters = {}

type Ctx = { model: Model, root: BasePart, scale: number }

local BLACK = Color3.fromRGB(25, 20, 20)
local WHITE = Color3.fromRGB(250, 248, 240)
local PINK = Color3.fromRGB(255, 150, 160)
local ORANGE = Color3.fromRGB(255, 140, 30)
local HAY = Color3.fromRGB(226, 190, 100)

-- Height of each silhouette at scale 1, so labels and prompts sit just above the head.
local HEIGHTS = {
	cow = 6.2, chicken = 7.4, pig = 6.6, sheep = 6.2, goat = 7, horse = 9.4,
	llama = 13, duck = 6.6, tortoise = 6.8, scarecrow = 10.6, disco = 8.6, bull = 8.4,
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
	p.CFrame = ctx.root.CFrame * local_
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
	weld.Part0, weld.Part1 = ctx.root, p
	weld.Parent = p
	p.Parent = ctx.model
	return p
end

local function eyes(ctx: Ctx, y: number, z: number, spread: number, size: number, color: Color3?)
	for _, x in { -spread, spread } do
		local eye = piece(ctx, Vector3.one * size, Vector3.new(x, y, z), color or BLACK, if color then Enum.Material.Neon else nil, "ball")
		eye:SetAttribute("Keep", true)
	end
end

local function legs(ctx: Ctx, w: number, h: number, x: number, zFront: number, zBack: number, color: Color3)
	for _, lx in { -x, x } do
		for _, lz in { zFront, zBack } do
			piece(ctx, Vector3.new(w, h, w), Vector3.new(lx, h / 2, lz), color)
		end
	end
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

-- Llamplighter: a long-necked llama whose head is a glowing table lamp.
BUILDERS.llama = function(ctx, body, accent)
	piece(ctx, Vector3.new(3.2, 3.2, 4.6), Vector3.new(0, 4.2, 0), body, Enum.Material.Fabric, "blob")
	legs(ctx, 0.75, 2.8, 1, -1.6, 1.6, body)
	piece(ctx, Vector3.new(1.3, 5.6, 1.3), Vector3.new(0, 7.6, -1.7), body, Enum.Material.Fabric)
	piece(ctx, Vector3.new(1.5, 1.6, 2.2), Vector3.new(0, 10.4, -2.1), body, Enum.Material.Fabric)
	eyes(ctx, 10.7, -3.2, 0.4, 0.35)
	local bulb = piece(ctx, Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 11.6, -1.9), Color3.fromRGB(255, 250, 200), Enum.Material.Neon, "ball")
	bulb:SetAttribute("Keep", true)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 14
	light.Brightness = 2
	light.Parent = bulb
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
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.Size = NumberSequence.new(0.6, 2.2)
	smoke.Transparency = NumberSequence.new(0.4, 1)
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 90, 90))
	smoke.EmissionDirection = Enum.NormalId.Top
	smoke.Parent = stack
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
	local star = piece(ctx, Vector3.new(0.8, 0.8, 0.12), CFrame.new(0.7, 5.9, -0.8) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 210, 60), Enum.Material.Neon)
	star:SetAttribute("Keep", true)
	piece(ctx, Vector3.new(0.25, 3.6, 0.25), Vector3.new(3.4, 5, -0.4), Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
	piece(ctx, Vector3.new(0.25, 0.25, 0.9), Vector3.new(3.4, 6.7, -0.75), Color3.fromRGB(200, 30, 30), Enum.Material.Metal)
end

-- Disco Udderlord: a glitter cow with a mirror ball on its head and a neon udder.
BUILDERS.disco = function(ctx, body, accent)
	cowBody(ctx, body, accent, Enum.Material.Glass)
	piece(ctx, Vector3.new(0.3, 1.2, 0.3), Vector3.new(0, 6, -3.5), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
	local ball = piece(ctx, Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 7.6, -3.5), Color3.fromRGB(220, 225, 235), Enum.Material.Foil, "ball")
	ball.Reflectance = 0.5
	ball:SetAttribute("Keep", true)
	local udder = piece(ctx, Vector3.new(1.4, 0.9, 1.4), Vector3.new(0, 1.8, 0.8), accent, Enum.Material.Neon, "blob")
	udder:SetAttribute("Keep", true)
	local glow = Instance.new("PointLight")
	glow.Color = accent
	glow.Range = 16
	glow.Brightness = 3
	glow.Parent = ball
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 10
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(3, 6)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 120, 230), Color3.fromRGB(120, 220, 255))
	sparkle.Size = NumberSequence.new(0.5)
	sparkle.Parent = ball
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
	local ring = piece(ctx, Vector3.new(0.3, 0.9, 0.9), Vector3.new(0, 3.5, -6.1), Color3.fromRGB(255, 200, 40), Enum.Material.Metal, "cyl")
	ring:SetAttribute("Keep", true)
	if crowned then
		local band = piece(ctx, Vector3.new(2.6, 0.8, 2.4), Vector3.new(0, 6.7, -4.3), Color3.fromRGB(255, 205, 40), Enum.Material.Foil)
		band:SetAttribute("Keep", true)
		for _, x in { -1, 0, 1 } do
			local spike = piece(ctx, Vector3.new(0.5, 1.2, 0.5), CFrame.new(x * 0.9, 7.6, -4.3) * CFrame.Angles(0, math.pi / 4, 0), Color3.fromRGB(255, 205, 40), Enum.Material.Foil)
			spike:SetAttribute("Keep", true)
		end
	end
	for _, drip in { Vector3.new(2.2, 3, -1), Vector3.new(-2.3, 3.6, 1.5), Vector3.new(0.8, 2.4, 3) } do
		local slime = piece(ctx, Vector3.new(0.7, 1.2, 0.7), drip, accent, Enum.Material.Neon, "blob")
		slime:SetAttribute("Keep", true)
	end
	local fumes = Instance.new("ParticleEmitter")
	fumes.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fumes.Rate = 6
	fumes.Lifetime = NumberRange.new(1, 2)
	fumes.Speed = NumberRange.new(1, 2)
	fumes.Size = NumberSequence.new(1, 3)
	fumes.Transparency = NumberSequence.new(0.5, 1)
	fumes.Color = ColorSequence.new(accent)
	fumes.Parent = ctx.root
end

BUILDERS.bull = function(ctx, body, accent)
	bullBody(ctx, body, accent, true)
end

-- Golden critters turn to shiny gold; moldy ones go green and grow fuzzy spots.
local function applyMutation(ctx: Ctx, mutation: string?)
	local tint = Cast.mutationTint(mutation)
	if not tint then
		return
	end
	for _, p in ctx.model:GetDescendants() do
		if p:IsA("BasePart") and p ~= ctx.root and not p:GetAttribute("Keep") then
			p.Color = p.Color:Lerp(tint, if mutation == "Golden" then 0.8 else 0.5)
			if mutation == "Golden" then
				p.Material = Enum.Material.Metal
				p.Reflectance = 0.2
			end
		end
	end
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = if mutation == "Golden" then "rbxasset://textures/particles/sparkles_main.dds" else "rbxasset://textures/particles/smoke_main.dds"
	fx.Rate = 6
	fx.Lifetime = NumberRange.new(1, 1.6)
	fx.Speed = NumberRange.new(1, 3)
	fx.SpreadAngle = Vector2.new(180, 180)
	fx.Size = NumberSequence.new(if mutation == "Golden" then 0.5 else 1.2)
	fx.Transparency = NumberSequence.new(0.3, 1)
	fx.Color = ColorSequence.new(tint)
	fx.Parent = ctx.root
	if mutation == "Moldy" then
		for i = 1, 6 do
			local a = i * 1.7
			piece(ctx, Vector3.new(0.9, 0.5, 0.9), Vector3.new(math.cos(a) * 1.6, 3 + (i % 3) * 0.8, math.sin(a) * 1.8), Color3.fromRGB(150, 220, 90), Enum.Material.Grass, "blob")
		end
	end
end

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
	return { model = model, root = root, scale = scale }
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
	local point = Instance.new("Attachment")
	point.Name = "PromptPoint"
	point.Position = Vector3.new(0, Critters.heightOf(id) * 0.5, 0)
	point.Parent = ctx.root
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

-- The floating label: name, rarity (and mutation), money a second, and the price while on the drive.
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
		tag = string.upper(mutation) .. " " .. tag
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

-- A burst of dust or sparkle where a critter appears or vanishes.
function Critters.poof(position: Vector3, color: Color3, count: number?)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	local burst = Instance.new("ParticleEmitter")
	burst.Texture = "rbxasset://textures/particles/smoke_main.dds"
	burst.Rate = 0
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Size = NumberSequence.new(1.5, 4)
	burst.Transparency = NumberSequence.new(0.2, 1)
	burst.Color = ColorSequence.new(color)
	burst.Parent = anchor
	anchor.Parent = workspace
	burst:Emit(count or 24)
	Debris:AddItem(anchor, 2)
end

return Critters
