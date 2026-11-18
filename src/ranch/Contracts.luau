-- Contracts: the ranch's job board. Every rancher holds three short contracts at a time ("Pen a
-- GOLDEN critter", "Tag a rustler", "Survive 2 events", "Rebirth once"...). Deeds from the rest of
-- the ranch fill them in; a finished one pays cash or a Lucky Horseshoe (extra drive luck for two
-- minutes) with a jingle, and a fresh contract is posted in its place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))

local Contracts = {}

Contracts.BOARD_SIZE = 3
Contracts.HORSESHOE_SECONDS = 120

type Job = {
	id: string,
	weight: number,
	reward: "cash" | "luck",
	goal: (Ledger.Account) -> number,
	text: (number) -> string,
	counts: (Ledger.Deed, Ledger.Account) -> number,
	pay: ((Ledger.Account) -> number)?,
}

local function rankOf(deed: Ledger.Deed): number
	return if deed.id then Cast.rankOf(deed.id) else 0
end

local function caught(deed: Ledger.Deed): boolean
	return deed.kind == "lasso" or deed.kind == "rustle"
end

-- Pays in proportion to how the ranch is doing, never less than a floor.
local function scaledPay(floor: number, seconds: number): (Ledger.Account) -> number
	return function(account)
		return math.max(floor, math.floor(Ledger.incomeOf(account) * seconds))
	end
end

local JOBS: { Job } = {
	{ id = "lasso", weight = 3, reward = "cash",
		goal = function(a) return if Ledger.herdSize(a) < 3 then 3 else 5 end,
		text = function(n) return "Lasso " .. n .. " critters" end,
		counts = function(d) return if d.kind == "lasso" then 1 else 0 end,
		pay = scaledPay(120, 25) },
	{ id = "rare", weight = 2, reward = "cash",
		goal = function() return 1 end,
		text = function() return "Pen a RARE or better" end,
		counts = function(d) return if caught(d) and rankOf(d) >= 3 then 1 else 0 end,
		pay = scaledPay(400, 40) },
	{ id = "epic", weight = 1, reward = "luck",
		goal = function() return 1 end,
		text = function() return "Pen an EPIC or better" end,
		counts = function(d) return if caught(d) and rankOf(d) >= 4 then 1 else 0 end },
	{ id = "mutant", weight = 2, reward = "cash",
		goal = function() return 1 end,
		text = function() return "Pen a MUTATED critter" end,
		counts = function(d) return if caught(d) and d.mutation then 1 else 0 end,
		pay = scaledPay(300, 45) },
	{ id = "golden", weight = 1.5, reward = "luck",
		goal = function() return 1 end,
		text = function() return "Pen a GOLDEN critter" end,
		counts = function(d) return if caught(d) and d.mutation == "Golden" then 1 else 0 end },
	{ id = "tag", weight = 1.5, reward = "cash",
		goal = function() return 1 end,
		text = function() return "Tag a rustler" end,
		counts = function(d) return if d.kind == "tag" then 1 else 0 end,
		pay = scaledPay(500, 60) },
	{ id = "rustle", weight = 1.5, reward = "cash",
		goal = function() return 1 end,
		text = function() return "Rustle a critter home" end,
		counts = function(d) return if d.kind == "rustle" then 1 else 0 end,
		pay = scaledPay(350, 40) },
	{ id = "lock", weight = 1.5, reward = "cash",
		goal = function() return 2 end,
		text = function(n) return if n == 1 then "Lock your gate" else "Lock your gate " .. n .. " times" end,
		counts = function(d) return if d.kind == "lock" then 1 else 0 end,
		pay = scaledPay(150, 20) },
	{ id = "survive", weight = 2, reward = "luck",
		goal = function() return 2 end,
		text = function(n) return "Survive " .. n .. " ranch events" end,
		counts = function(d) return if d.kind == "survive" then 1 else 0 end },
	{ id = "coin", weight = 1, reward = "cash",
		goal = function() return 4 end,
		text = function(n) return "Grab " .. n .. " Dust Devil coins" end,
		counts = function(d) return if d.kind == "coin" then 1 else 0 end,
		pay = scaledPay(300, 30) },
	{ id = "earn", weight = 2, reward = "cash",
		goal = function(a) return math.max(500, math.floor(Ledger.incomeOf(a) * 90 / 100) * 100) end,
		text = function(n) return "Earn " .. Cast.formatCash(n) .. " from your pens" end,
		counts = function(d) return if d.kind == "earn" then d.amount or 0 else 0 end,
		pay = scaledPay(200, 30) },
	{ id = "dex", weight = 2, reward = "luck",
		goal = function() return 3 end,
		text = function(n) return "Find " .. n .. " new RanchDex entries" end,
		counts = function(d) return if d.kind == "discover" then 1 else 0 end },
	{ id = "rebirth", weight = 0.8, reward = "luck",
		goal = function() return 1 end,
		text = function() return "Rebirth once" end,
		counts = function(d) return if d.kind == "rebirth" then 1 else 0 end },
}

local jobById: { [string]: Job } = {}
for _, job in JOBS do
	jobById[job.id] = job
end
local rng = Random.new()
local lastEarnSync: { [Ledger.Account]: number } = {}

local function rewardText(job: Job, account: Ledger.Account): (string, number)
	if job.reward == "luck" then
		return "Lucky Horseshoe", 0
	end
	local cash = (job.pay :: (Ledger.Account) -> number)(account)
	return Cast.formatCash(cash), cash
end

-- Posts a new contract the board does not already hold (rebirth only once a rebirth is in sight).
function Contracts.postContract(account: Ledger.Account): Ledger.Contract
	local held: { [string]: boolean } = {}
	for _, c in account.contracts do
		held[c.kind] = true
	end
	local total = 0
	local open = {}
	for _, job in JOBS do
		local fits = not held[job.id] and (job.id ~= "rebirth" or account.cash >= Cast.rebirthCost(account.rebirths) * 0.25)
		if fits then
			table.insert(open, job)
			total += job.weight
		end
	end
	local pick = rng:NextNumber() * total
	local chosen = open[1]
	for _, job in open do
		pick -= job.weight
		if pick <= 0 then
			chosen = job
			break
		end
	end
	local goal = chosen.goal(account)
	local reward, cash = rewardText(chosen, account)
	local contract: Ledger.Contract = { kind = chosen.id, text = chosen.text(goal), goal = goal, progress = 0, reward = reward, cash = cash }
	table.insert(account.contracts, contract)
	return contract
end

-- Fills a new rancher's board: the first one always starts with the easiest jobs.
function Contracts.dealBoard(account: Ledger.Account)
	account.contracts = {}
	local lasso = jobById.lasso
	table.insert(account.contracts, { kind = "lasso", text = lasso.text(3), goal = 3, progress = 0, reward = Cast.formatCash(150), cash = 150 })
	local lock = jobById.lock
	table.insert(account.contracts, { kind = "lock", text = lock.text(1), goal = 1, progress = 0, reward = Cast.formatCash(100), cash = 100 })
	Contracts.postContract(account)
	Ledger.syncBoard(account)
end

local function payContract(account: Ledger.Account, contract: Ledger.Contract)
	if contract.cash > 0 then
		Ledger.addCash(account, contract.cash)
	else
		local now = workspace:GetServerTimeNow()
		account.luckUntil = math.max(now, account.luckUntil) + Contracts.HORSESHOE_SECONDS
	end
	Ledger.cue(account, "contract", contract.reward)
	Ledger.toast(account, "CONTRACT DONE: " .. contract.text .. "  >  " .. contract.reward .. "!", Color3.fromRGB(255, 225, 90))
	if contract.cash == 0 then
		Ledger.toast(account, "Lucky Horseshoe! Rarer critters on the drive for 2 minutes.", Color3.fromRGB(170, 255, 140))
	end
end

-- A deed moves every contract it counts for; finished ones pay and are replaced a moment later.
function Contracts.recordDeed(account: Ledger.Account, deed: Ledger.Deed)
	local changed = false
	for _, contract in account.contracts do
		local job = jobById[contract.kind]
		if job and contract.progress < contract.goal then
			local n = job.counts(deed, account)
			if n > 0 then
				contract.progress = math.min(contract.goal, contract.progress + n)
				changed = true
				if contract.progress >= contract.goal then
					payContract(account, contract)
					task.delay(3, function()
						local i = table.find(account.contracts, contract)
						if i then
							table.remove(account.contracts, i)
							Contracts.postContract(account)
							Ledger.syncBoard(account)
						end
					end)
				end
			end
		end
	end
	-- "earn" ticks every second: re-send the board for it at most every 2 seconds.
	if changed then
		local now = os.clock()
		if deed.kind ~= "earn" or now - (lastEarnSync[account] or 0) >= 2 then
			lastEarnSync[account] = now
			Ledger.syncBoard(account)
		end
	end
end

function Contracts.forget(account: Ledger.Account)
	lastEarnSync[account] = nil
end

function Contracts.startContractBoard()
	Ledger.onDeed(Contracts.recordDeed)
end

return Contracts
