-- CritterMotion: makes the herd look alive on each client. Every critter's visible body hangs off
-- its anchored root by a Motor6D named Gait; this module sets that joint's Transform each frame from
-- the critter's Gait attribute: a bouncing trot on the Cattle Drive, breathing, swaying and the odd
-- happy hop in the pens, a frantic wriggle while carried by a rustler, and a tumble on the lasso.
-- Nothing here replicates: the server only moves roots, the client adds the wiggle.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CritterMotion = {}

CritterMotion.RANGE = 220 -- studs from the camera beyond which critters stand still

type Tracked = { model: Model, gait: Motor6D, phase: number, size: number }

local tracked: { [Model]: Tracked } = {}

local function track(model: Instance, tries: number?)
	if not model:IsA("Model") or not model:IsDescendantOf(Workspace) then
		return
	end
	local root = model.PrimaryPart
	local gait = root and root:FindFirstChild("Gait")
	if not gait or not gait:IsA("Motor6D") then
		-- its parts may still be on their way from the server
		if (tries or 0) < 5 then
			task.delay(0.4, track, model, (tries or 0) + 1)
		end
		return
	end
	tracked[model] = { model = model, gait = gait, phase = math.random() * 10, size = model:GetScale() }
end

-- Where the body sits relative to the root this frame, for one gait.
function CritterMotion.pose(gaitName: string, t: number, phase: number, size: number): CFrame
	if gaitName == "trot" then
		local stride = t * 9 + phase
		local hop = math.abs(math.sin(stride)) * 0.6 * size
		return CFrame.new(0, hop, 0) * CFrame.Angles(math.sin(stride) * 0.08, 0, math.sin(stride * 0.5) * 0.06)
	elseif gaitName == "idle" then
		local breathe = (math.sin(t * 2.2 + phase) + 1) * 0.07 * size
		local look = math.sin(t * 0.55 + phase) * 0.35
		local k = (t + phase * 3) % 7
		local hop = if k < 0.5 then math.sin(k / 0.5 * math.pi) * 1.3 * size else 0
		local wiggle = if k < 0.5 then math.sin(k * 40) * 0.12 else 0
		return CFrame.new(0, breathe + hop, 0) * CFrame.Angles(0, look, wiggle)
	elseif gaitName == "carried" then
		return CFrame.Angles(math.sin(t * 13 + phase) * 0.25, math.sin(t * 11) * 0.4, math.sin(t * 16 + phase) * 0.35)
	elseif gaitName == "fly" then
		return CFrame.new(0, 0, 0) * CFrame.Angles(0, t * 5, math.sin(t * 7) * 0.5)
	end
	return CFrame.identity
end

local function animate()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local t = os.clock()
	for model, entry in tracked do
		local root = model.PrimaryPart
		if not root or not model.Parent or not entry.gait.Parent then
			tracked[model] = nil
		elseif (root.Position - eye).Magnitude < CritterMotion.RANGE then
			entry.gait.Transform = CritterMotion.pose(model:GetAttribute("Gait") or "idle", t, entry.phase, entry.size)
		end
	end
end

function CritterMotion.startCritterMotion()
	for _, model in CollectionService:GetTagged("Critter") do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Critter"):Connect(track)
	CollectionService:GetInstanceRemovedSignal("Critter"):Connect(function(model)
		tracked[model :: Model] = nil
	end)
	-- A critter rescaled while carried gets its new size the next time it is tracked.
	RunService.RenderStepped:Connect(animate)
	task.spawn(function()
		while true do
			task.wait(2)
			for model, entry in tracked do
				entry.size = model:GetScale()
			end
		end
	end)
end

return CritterMotion
