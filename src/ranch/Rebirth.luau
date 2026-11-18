-- Rebirth: trade the whole herd and your cash for a permanent cash multiplier, two more stalls,
-- a longer gate lock and better luck on the Cattle Drive. The price quadruples every time. Your
-- RanchDex and your contract board survive it; the ranch goes up in a golden shockwave.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(ReplicatedStorage:WaitForChild("Critters"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Pens = require(script.Parent:WaitForChild("Pens"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Rebirth = {}

local GOLD = Color3.fromRGB(255, 220, 90)

-- A ring of golden light that sweeps out across the ranch from its centre.
local function shockwave(at: CFrame)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide, ring.CanQuery, ring.CanTouch = false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = GOLD
	ring.Size = Vector3.new(0.6, 4, 4)
	ring.CFrame = at * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.1
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.3, 70, 70), Transparency = 1,
	}):Play()
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide, beam.CanQuery, beam.CanTouch = false, false, false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 240, 170)
	beam.Size = Vector3.new(6, 120, 6)
	beam.CFrame = at * CFrame.new(0, 60, 0)
	beam.Transparency = 0.3
	beam.Parent = workspace
	TweenService:Create(beam, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(0.2, 160, 0.2), Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1.3)
	Debris:AddItem(beam, 1.8)
end

-- Rebirths a player if they can pay: herd released, cash reset, multiplier and stalls raised.
function Rebirth.rebirthRancher(player: Player): boolean
	local account = Ledger.accountOf(player)
	if not account or not account.plot then
		return false
	end
	local cost = Cast.rebirthCost(account.rebirths)
	if account.cash < cost then
		Ledger.toast(account, "Rebirth costs " .. Cast.formatCash(cost) .. " - " .. Cast.formatCash(cost - account.cash) .. " to go. Keep ranching!", Color3.fromRGB(255, 160, 80))
		Ledger.cue(account, "deny")
		return false
	end
	if account.carrying then
		Ledger.toast(account, "Put down what you're carrying first!", Color3.fromRGB(255, 160, 80))
		Ledger.cue(account, "deny")
		return false
	end
	for stall, record in account.stalls do
		Critters.sparkle((record.model.PrimaryPart :: BasePart).Position + Vector3.new(0, 3, 0), GOLD, 14)
		record.model:Destroy()
		account.stalls[stall] = nil
	end
	account.rebirths += 1
	account.cash = Cast.START_CASH
	Pens.paintRanch(account)
	World.paintStallLocks(account.plot, Cast.stallsFor(account.rebirths))
	shockwave(account.plot.cf)
	Critters.sparkle(account.plot.cf.Position + Vector3.new(0, 6, 0), GOLD, 80)
	Ledger.syncRancher(account)
	Ledger.cue(account, "rebirth", account.rebirths)
	Ledger.deed(account, { kind = "rebirth", amount = account.rebirths })
	local mult = Cast.rebirthMultiplier(account.rebirths)
	Ledger.toast(account, string.format("REBIRTH %d! Cash x%.1f forever, %d stalls, rarer critters on the drive.", account.rebirths, mult, Cast.stallsFor(account.rebirths)), GOLD)
	Ledger.toastAll(account.name .. " was REBORN as a x" .. string.format("%.1f", mult) .. " rancher!", GOLD)
	return true
end

return Rebirth
