-- GoldenHour: the ranch's good-news event. A five-second fanfare, then for thirty seconds the sun
-- sinks gold, glitter falls along the whole Cattle Drive, every pen pays DOUBLE, and critters on the
-- drive come out Golden four times as often. The stake: get out there and lasso while it lasts.
local Workspace = game:GetService("Workspace")

local Events = require(script.Parent:WaitForChild("Events"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Mood = require(script.Parent:WaitForChild("Workshop"):WaitForChild("Mood"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local GoldenHour = {}

GoldenHour.WARNING = 5
GoldenHour.LASTS = 30
GoldenHour.INCOME_BOOST = 2
GoldenHour.GOLDEN_BOOST = 4

local GOLD = Color3.fromRGB(255, 205, 60)

-- Glitter curtains along the drive and a ring of light over the barn, gone when the hour ends.
local function hangGlitter(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "GoldenHourGlitter"
	for x = World.DRIVE_START_X + 10, World.DRIVE_END_X - 10, 26 do
		local cloud = Instance.new("Part")
		cloud.Anchored = true
		cloud.CanCollide, cloud.CanQuery, cloud.CanTouch = false, false, false
		cloud.Transparency = 1
		cloud.Size = Vector3.new(24, 1, 34)
		cloud.Position = Vector3.new(x, 20, 0)
		local glitter = Instance.new("ParticleEmitter")
		glitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		glitter.Rate = 18
		glitter.Lifetime = NumberRange.new(2.5, 4)
		glitter.Speed = NumberRange.new(4, 8)
		glitter.Acceleration = Vector3.new(0, -2, 0)
		glitter.EmissionDirection = Enum.NormalId.Bottom
		glitter.SpreadAngle = Vector2.new(25, 25)
		glitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.15) })
		glitter.Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 250, 200))
		glitter.LightEmission = 0.7
		glitter.Parent = cloud
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 30
		light.Brightness = 1.2
		light.Parent = cloud
		cloud.Parent = folder
	end
	-- A golden ribbon of neon down the middle of the drive
	local ribbon = Instance.new("Part")
	ribbon.Anchored = true
	ribbon.CanCollide, ribbon.CanQuery, ribbon.CanTouch = false, false, false
	ribbon.Material = Enum.Material.Neon
	ribbon.Color = GOLD
	ribbon.Transparency = 0.6
	ribbon.Size = Vector3.new(World.DRIVE_END_X - World.DRIVE_START_X, 0.1, 1.4)
	ribbon.Position = Vector3.new((World.DRIVE_END_X + World.DRIVE_START_X) / 2, 0.46, 0)
	ribbon.Parent = folder
	folder.Parent = Workspace
	return folder
end

function GoldenHour.startGoldenHour(_arg: any?)
	local now = Workspace:GetServerTimeNow()
	Events.setPhase("goldenhour", "warning", now + GoldenHour.WARNING)
	Ledger.toastAll("The sun is turning GOLD... Golden Hour in 5!", GOLD)
	Ledger.cueAll("goldenWarn")
	Mood.set("golden", GoldenHour.WARNING + 1)
	task.wait(GoldenHour.WARNING)

	Events.incomeBoost = GoldenHour.INCOME_BOOST
	Events.goldenBoost = GoldenHour.GOLDEN_BOOST
	Events.setPhase("goldenhour", "active", Workspace:GetServerTimeNow() + GoldenHour.LASTS)
	Ledger.cueAll("golden")
	Ledger.toastAll("GOLDEN HOUR! Pens pay x" .. GoldenHour.INCOME_BOOST .. " and Golden critters roam the drive!", GOLD)
	local glitter = hangGlitter()
	task.wait(GoldenHour.LASTS)
	glitter:Destroy()
	Events.incomeBoost = 1
	Events.goldenBoost = 1
	Mood.set("normal", 5)
	local goldens = 0
	for _, account in Ledger.players() do
		for _, record in account.stalls do
			if record.mutation == "Golden" then
				goldens += 1
			end
		end
	end
	Ledger.toastAll(string.format("The golden hour fades. %d Golden critter%s penned on this ranch.", goldens, if goldens == 1 then "" else "s"), Color3.fromRGB(255, 230, 170))
end

Events.register("goldenhour", GoldenHour.startGoldenHour)

return GoldenHour
