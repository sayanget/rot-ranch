-- Ledger: the one place ranch state lives. Every rancher (a Player or a rival bot) has an account:
-- cash, rebirths, their ranch plot, the critters in their stalls, the gate lock and what they carry.
-- Other modules change state only through here, and syncRancher pushes it to attributes the HUD reads.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))

local Ledger = {}

export type CritterRecord = {
	id: string,
	mutation: string?,
	model: Model,
	owner: any?, -- the Account that keeps it, nil while on the Cattle Drive
	stall: number?,
	carrier: Player?,
}

export type Account = {
	key: string,
	name: string,
	player: Player?,
	isBot: boolean,
	cash: number,
	rebirths: number,
	plot: any?,
	stalls: { [number]: CritterRecord },
	lockedUntil: number,
	carrying: CritterRecord?,
	trampledUntil: number,
}

local accounts: { [string]: Account } = {}
local toastRemote: RemoteEvent = ReplicatedStorage:WaitForChild("RanchToast") :: RemoteEvent
local keyOf: (Player | string) -> string


-- Opens an account with starting cash and a leaderstats board for a joining player.
function Ledger.openAccount(player: Player)
	local account: Account = {
		key = keyOf(player), name = player.DisplayName, player = player, isBot = false,
		cash = Cast.START_CASH, rebirths = 0, plot = nil, stalls = {},
		lockedUntil = 0, carrying = nil, trampledUntil = 0,
	}
	accounts[account.key] = account
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	stats.Parent = player
	Ledger.syncRancher(account)
	return account
end

function keyOf(who: Player | string): string
	if typeof(who) == "Instance" then
		return "player:" .. who.UserId
	end
	return "bot:" .. who
end

function Ledger.openBotAccount(name: string, cash: number, rebirths: number): Account
	local account: Account = {
		key = keyOf(name), name = name, player = nil, isBot = true,
		cash = cash, rebirths = rebirths, plot = nil, stalls = {},
		lockedUntil = 0, carrying = nil, trampledUntil = 0,
	}
	accounts[account.key] = account
	return account
end

function Ledger.closeAccount(account: Account)
	accounts[account.key] = nil
end

function Ledger.accountOf(player: Player): Account?
	return accounts[keyOf(player)]
end

function Ledger.allAccounts(): { Account }
	local list = {}
	for _, account in accounts do
		table.insert(list, account)
	end
	table.sort(list, function(a, b)
		return a.key < b.key
	end)
	return list
end

-- Income a second of everything in the account's stalls.
function Ledger.incomeOf(account: Account): number
	local total = 0
	for _, record in account.stalls do
		total += Cast.incomeOf(record.id, record.mutation, account.rebirths)
	end
	return total
end

function Ledger.addCash(account: Account, amount: number)
	account.cash += amount
	Ledger.syncRancher(account)
end

function Ledger.spendCash(account: Account, amount: number): boolean
	if account.cash < amount then
		return false
	end
	account.cash -= amount
	Ledger.syncRancher(account)
	return true
end

function Ledger.isLocked(account: Account): boolean
	return account.lockedUntil > workspace:GetServerTimeNow()
end

-- Pushes an account to its player's attributes and leaderstats, the only state the client sees.
function Ledger.syncRancher(account: Account)
	local player = account.player
	if not player then
		return
	end
	local stalls = 0
	for _ in account.stalls do
		stalls += 1
	end
	player:SetAttribute("Cash", account.cash)
	player:SetAttribute("Income", Ledger.incomeOf(account))
	player:SetAttribute("Rebirths", account.rebirths)
	player:SetAttribute("RebirthCost", Cast.rebirthCost(account.rebirths))
	player:SetAttribute("Multiplier", Cast.rebirthMultiplier(account.rebirths))
	player:SetAttribute("StallsUsed", stalls)
	player:SetAttribute("StallsOpen", Cast.stallsFor(account.rebirths))
	player:SetAttribute("LockedUntil", account.lockedUntil)
	player:SetAttribute("Carrying", if account.carrying then Cast.critterById(account.carrying.id).name else "")
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats :: any).Cash.Value = Cast.formatCash(account.cash);
		(stats :: any).Rebirths.Value = account.rebirths
	end
end

-- A one-line message on a rancher's screen (bots have no screen).
function Ledger.toast(account: Account?, text: string, color: Color3?)
	if account and account.player then
		toastRemote:FireClient(account.player, text, color or Color3.fromRGB(255, 240, 200))
	end
end

function Ledger.toastAll(text: string, color: Color3?)
	toastRemote:FireAllClients(text, color or Color3.fromRGB(255, 240, 200))
end

function Ledger.players(): { Account }
	local list = {}
	for _, player in Players:GetPlayers() do
		local account = Ledger.accountOf(player)
		if account then
			table.insert(list, account)
		end
	end
	return list
end

return Ledger
