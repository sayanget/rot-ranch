-- Income: the ranch's payday. Once a second every rancher is paid the $/s of every critter standing
-- in their stalls (mutations and rebirths multiplied in, doubled during Golden Hour), the HUD's
-- cash ticks up, and the payday is counted toward "earn" contracts.
local Events = require(script.Parent:WaitForChild("Events"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))

local Income = {}

Income.PAY_EVERY = 1

-- What one rancher earns this tick, with the running event's boost.
function Income.paydayOf(account: Ledger.Account): number
	return math.floor(Ledger.incomeOf(account) * Events.incomeBoost * Income.PAY_EVERY)
end

-- Pays each player rancher one tick of their pens' income; returns what was paid in all.
function Income.payRanchIncome(): number
	local paid = 0
	for _, account in Ledger.players() do
		local amount = Income.paydayOf(account)
		if amount > 0 then
			Ledger.addCash(account, amount)
			Ledger.deed(account, { kind = "earn", amount = amount })
			paid += amount
		end
		if account.player then
			account.player:SetAttribute("Boost", Events.incomeBoost)
		end
	end
	return paid
end

function Income.startIncomeClock()
	task.spawn(function()
		while true do
			task.wait(Income.PAY_EVERY)
			Income.payRanchIncome()
		end
	end)
end

return Income
