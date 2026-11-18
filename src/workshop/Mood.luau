-- Mood: the ranch's light, built from source. Sets a low golden-hour sun, a sky, a dusty prairie
-- atmosphere, bloom, sun rays and colour grading, then tweens between moods when an event changes
-- the air: warm gold for Golden Hour, brown dust for the stampede, bruised purple for the Dust Devil.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Mood = {}

type MoodSpec = {
	clock: number, brightness: number, shiftTop: Color3, ambient: Color3, outdoor: Color3,
	density: number, haze: number, air: Color3, decay: Color3, glare: number,
	tint: Color3, saturation: number, contrast: number, exposure: number, bloom: number, rays: number,
}

local C = Color3.fromRGB
Mood.MOODS = {
	normal = {
		clock = 16.9, brightness = 2.6, shiftTop = C(255, 222, 170), ambient = C(92, 76, 66), outdoor = C(158, 134, 110),
		density = 0.3, haze = 1.6, air = C(245, 212, 160), decay = C(220, 140, 90), glare = 0.35,
		tint = C(255, 246, 232), saturation = 0.2, contrast = 0.08, exposure = 0.02, bloom = 0.4, rays = 0.06,
	},
	golden = {
		clock = 17.6, brightness = 2.7, shiftTop = C(255, 190, 100), ambient = C(110, 82, 52), outdoor = C(185, 140, 90),
		density = 0.34, haze = 2, air = C(255, 196, 120), decay = C(255, 140, 70), glare = 0.6,
		tint = C(255, 232, 190), saturation = 0.32, contrast = 0.12, exposure = 0, bloom = 0.55, rays = 0.16,
	},
	stampede = {
		clock = 16.4, brightness = 2.2, shiftTop = C(255, 200, 150), ambient = C(90, 66, 50), outdoor = C(140, 104, 80),
		density = 0.5, haze = 3, air = C(200, 150, 100), decay = C(160, 100, 60), glare = 0.2,
		tint = C(255, 225, 200), saturation = -0.05, contrast = 0.22, exposure = -0.02, bloom = 0.35, rays = 0.04,
	},
	dust = {
		clock = 17.5, brightness = 2.3, shiftTop = C(220, 180, 255), ambient = C(112, 92, 124), outdoor = C(170, 142, 182),
		density = 0.42, haze = 2.2, air = C(205, 175, 225), decay = C(160, 110, 175), glare = 0.2,
		tint = C(242, 228, 255), saturation = 0.08, contrast = 0.16, exposure = 0, bloom = 0.5, rays = 0.03,
	},
} :: { [string]: MoodSpec }

local atmosphere: Atmosphere
local bloom: BloomEffect
local rays: SunRaysEffect
local grade: ColorCorrectionEffect
local current = "normal"

local function make(className: string, name: string): Instance
	local old = Lighting:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

-- Builds the sky and the effects once, at the normal mood.
function Mood.lightTheRanch()
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	Lighting.GeographicLatitude = 34
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ColorShift_Bottom = C(80, 50, 30)
	local sky = make("Sky", "PrairieSky") :: Sky
	sky.SunAngularSize = 16
	sky.MoonAngularSize = 9
	sky.StarCount = 1500
	sky.CelestialBodiesShown = true
	atmosphere = make("Atmosphere", "PrairieHaze") :: Atmosphere
	atmosphere.Offset = 0.12
	bloom = make("BloomEffect", "SunGlow") :: BloomEffect
	bloom.Size = 28
	bloom.Threshold = 1.3
	rays = make("SunRaysEffect", "SunRays") :: SunRaysEffect
	rays.Spread = 0.6
	grade = make("ColorCorrectionEffect", "Grade") :: ColorCorrectionEffect
	Mood.set("normal", 0)
end

-- Tweens the whole sky to a mood over `seconds` (0 snaps).
function Mood.set(name: string, seconds: number)
	local spec = Mood.MOODS[name]
	if not spec or not atmosphere then
		return
	end
	current = name
	local info = TweenInfo.new(math.max(seconds, 0.01), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local function to(inst: Instance, goal: { [string]: any })
		if seconds <= 0 then
			for k, v in goal do
				(inst :: any)[k] = v
			end
		else
			TweenService:Create(inst, info, goal):Play()
		end
	end
	to(Lighting, {
		ClockTime = spec.clock, Brightness = spec.brightness, ColorShift_Top = spec.shiftTop,
		Ambient = spec.ambient, OutdoorAmbient = spec.outdoor,
	})
	to(atmosphere, { Density = spec.density, Haze = spec.haze, Color = spec.air, Decay = spec.decay, Glare = spec.glare })
	to(grade, { TintColor = spec.tint, Saturation = spec.saturation, Contrast = spec.contrast, Brightness = spec.exposure })
	to(bloom, { Intensity = spec.bloom })
	to(rays, { Intensity = spec.rays })
end

function Mood.current(): string
	return current
end

return Mood
