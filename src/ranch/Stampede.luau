-- Stampede: the ranch's hazard. Every couple of minutes the dust rises over Dust Canyon, a ten-second
-- countdown goes up ("STAMPEDE IN 8 - GET OFF THE DRIVE!") and a herd of glowing-eyed rot bulls
-- thunders down the whole drive. Anyone caught out in the open is flung, drops what they carry and
-- loses some cash; critters still on the drive are flattened. Behind a fence you are safe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CattleDrive = require(script.Parent:WaitForChild("CattleDrive"))
local Critters = require(script.Parent:WaitForChild("Workshop"):WaitForChild("Critters"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Rustling = require(script.Parent:WaitForChild("Rustling"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Stampede = {}

Stampede.EVERY = 110
Stampede.WARNING = 10
Stampede.HERD_SPEED = 36
Stampede.CASH_LOST = 0.15
Stampede.running = false

local HERD_ROWS = { -14, -6, 2, 10, 16 }
local HERD_DEPTH = 34
local dustCloud: (Vector3, Vector3) -> (Part, ParticleEmitter)
local chargeHerd: () -> ()

-- One full stampede: warning countdown with rising dust, the charge, then the all-clear.
function Stampede.startStampede(_arg: any?)
	if Stampede.running then
		return
	end
	Stampede.running = true
	local now = Workspace:GetServerTimeNow()
	Workspace:SetAttribute("StampedeAt", now + Stampede.WARNING)
	Workspace:SetAttribute("StampedePhase", "warning")
	Ledger.toastAll("The ground is shaking... STAMPEDE INCOMING! Get off the drive!", Color3.fromRGB(255, 170, 60))
	local cloud, dust = dustCloud(Vector3.new(150, 6, 0), Vector3.new(20, 4, 40))
	for i = 1, Stampede.WARNING * 4 do
		dust:Emit(4 + i)
		task.wait(0.25)
	end
	Workspace:SetAttribute("StampedeFront", World.DRIVE_END_X + 40)
	Workspace:SetAttribute("StampedePhase", "charging")
	CattleDrive.paused = true
	chargeHerd()
	cloud:Destroy()
	CattleDrive.paused = false
	Workspace:SetAttribute("StampedePhase", "calm")
	Workspace:SetAttribute("StampedeAt", Workspace:GetServerTimeNow() + Stampede.EVERY)
	Ledger.toastAll("The dust settles. The drive is open again.", Color3.fromRGB(200, 255, 170))
	Stampede.running = false
end

-- Flings a rancher caught on the drive: they drop what they carry and lose a cut of their cash.
function Stampede.trampleRancher(player: Player)
	local account = Ledger.accountOf(player)
	if not account then
		return
	end
	local now = Workspace:GetServerTimeNow()
	if account.trampledUntil > now then
		return
	end
	account.trampledUntil = now + 4
	if account.carrying then
		Rustling.returnCarried(account, account.carrying)
	end
	local lost = math.floor(account.cash * Stampede.CASH_LOST)
	account.cash -= lost
	Ledger.syncRancher(account)
	player:SetAttribute("TrampledAt", now)
	Ledger.toast(account, "TRAMPLED! The herd knocked " .. string.format("$%d", lost) .. " out of your pockets.", Color3.fromRGB(255, 90, 80))
end


function dustCloud(at: Vector3, size: Vector3): (Part, ParticleEmitter)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Transparency = 1
	p.Size = size
	p.Position = at
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Rate = 0
	dust.Lifetime = NumberRange.new(2, 3.5)
	dust.Speed = NumberRange.new(4, 10)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 12) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 150, 100))
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Parent = p
	p.Parent = Workspace
	return p, dust
end

-- Runs the herd from Dust Canyon to the Rot Corral, trampling whoever and whatever is on the drive.
function chargeHerd()
	local herd = {}
	for i, z in HERD_ROWS do
		for j = 0, 1 do
			local offset = j * 16 + (i % 2) * 7
			local bull = Critters.buildRotbull(CFrame.lookAt(Vector3.new(170, 0, z), Vector3.new(0, 0, z)))
			local trail = Instance.new("ParticleEmitter")
			trail.Texture = "rbxasset://textures/particles/smoke_main.dds"
			trail.Rate = 70
			trail.Lifetime = NumberRange.new(1.4, 2.6)
			trail.Speed = NumberRange.new(3, 8)
			trail.SpreadAngle = Vector2.new(40, 40)
			trail.Size = NumberSequence.new(5, 14)
			trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.45), NumberSequenceKeypoint.new(1, 1) })
			trail.Color = ColorSequence.new(Color3.fromRGB(160, 118, 78))
			trail.Parent = bull.PrimaryPart
			bull.Parent = Workspace
			table.insert(herd, { model = bull, z = z, offset = offset, phase = i + j })
		end
	end
	local front = World.DRIVE_END_X + 40
	local stopAt = World.DRIVE_START_X - 60
	local t = 0
	while front > stopAt do
		local dt = RunService.Heartbeat:Wait()
		t += dt
		front -= Stampede.HERD_SPEED * dt
		Workspace:SetAttribute("StampedeFront", front)
		for _, bull in herd do
			local x = front + bull.offset
			local hop = math.abs(math.sin(t * 9 + bull.phase)) * 1.4
			bull.model:PivotTo(CFrame.lookAt(Vector3.new(x, hop, bull.z), Vector3.new(x - 10, hop, bull.z)))
		end
		CattleDrive.trampleDriveCritters(front - 4, front + HERD_DEPTH)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and World.isOnTheDrive(root.Position) and root.Position.X > front - 5 and root.Position.X < front + HERD_DEPTH then
				Stampede.trampleRancher(player)
			end
		end
	end
	for _, bull in herd do
		bull.model:Destroy()
	end
end

function Stampede.startStampedeClock()
	Workspace:SetAttribute("StampedePhase", "calm")
	Workspace:SetAttribute("StampedeAt", Workspace:GetServerTimeNow() + Stampede.EVERY)
	task.spawn(function()
		while true do
			task.wait(1)
			local at = Workspace:GetAttribute("StampedeAt") :: number
			if not Stampede.running and Workspace:GetAttribute("StampedePhase") == "calm" and Workspace:GetServerTimeNow() >= at - Stampede.WARNING then
				task.spawn(Stampede.startStampede)
			end
		end
	end)
end

return Stampede
