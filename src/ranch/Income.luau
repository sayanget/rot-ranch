-- Income: the ranch's payday. Once a second every rancher is paid the $/s of every critter standing
-- in their stalls (mutations and rebirths multiplied in), and the HUD's cash ticks up.
local Ledger = require(script.Parent:WaitForChild("Ledger"))

local Income = {}

Income.PAY_EVERY = 1

-- Pays each player rancher one tick of their pens' income; returns what was paid in all.
function Income.payRanchIncome(): number
	local paid = 0
	for _, account in Ledger.players() do
		local amount = Ledger.incomeOf(account) * Income.PAY_EVERY
		if amount > 0 then
			Ledger.addCash(account, amount)
			paid += amount
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
