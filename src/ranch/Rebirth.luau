-- Rebirth: trade the whole herd and your cash for a permanent cash multiplier, two more stalls,
-- a longer gate lock and better luck on the Cattle Drive. The price quadruples every time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(script.Parent:WaitForChild("Workshop"):WaitForChild("Critters"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Pens = require(script.Parent:WaitForChild("Pens"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Rebirth = {}

-- Rebirths a player if they can pay: herd released, cash reset, multiplier and stalls raised.
function Rebirth.rebirthRancher(player: Player): boolean
	local account = Ledger.accountOf(player)
	if not account or not account.plot then
		return false
	end
	local cost = Cast.rebirthCost(account.rebirths)
	if account.cash < cost then
		Ledger.toast(account, "Rebirth costs " .. Cast.formatCash(cost) .. " - keep ranching!", Color3.fromRGB(255, 160, 80))
		return false
	end
	if account.carrying then
		Ledger.toast(account, "Put down what you're carrying first!", Color3.fromRGB(255, 160, 80))
		return false
	end
	for stall, record in account.stalls do
		Critters.poof((record.model.PrimaryPart :: BasePart).Position, Color3.fromRGB(255, 230, 120), 10)
		record.model:Destroy()
		account.stalls[stall] = nil
	end
	account.rebirths += 1
	account.cash = Cast.START_CASH
	Pens.paintRanch(account)
	World.paintStallLocks(account.plot, Cast.stallsFor(account.rebirths))
	Critters.poof(account.plot.cf.Position + Vector3.new(0, 6, 0), Color3.fromRGB(255, 220, 90), 60)
	Ledger.syncRancher(account)
	local mult = Cast.rebirthMultiplier(account.rebirths)
	Ledger.toast(account, string.format("REBIRTH %d! Cash x%.1f forever, %d stalls, rarer critters on the drive.", account.rebirths, mult, Cast.stallsFor(account.rebirths)), Color3.fromRGB(255, 220, 90))
	Ledger.toastAll(account.name .. " was REBORN as a x" .. string.format("%.1f", mult) .. " rancher!", Color3.fromRGB(255, 220, 90))
	return true
end

return Rebirth
