-- Ledger: the one place ranch state lives. Every rancher (a Player or a rival bot) has an account:
-- cash, rebirths, their ranch plot, the critters in their stalls, the gate lock, what they carry,
-- their RanchDex, their contracts, their guide step and any luck charm. Other modules change state
-- only through here; syncRancher pushes it to the attributes the HUD reads, cue() plays a sound on a
-- rancher's client, and deed() tells the contract board, the guide and the dex what just happened.
local HttpService = game:GetService("HttpService")
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

export type Contract = { kind: string, text: string, goal: number, progress: number, reward: string, cash: number }

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
	luckUntil: number,
	dex: { [string]: { [string]: boolean } },
	contracts: { Contract },
	guideStep: number,
	earned: number,
}

-- What a deed tells its listeners: lasso, pen, lock, rustle, tag, survive, coin, rebirth, home...
export type Deed = { kind: string, id: string?, mutation: string?, amount: number? }

local accounts: { [string]: Account } = {}
local deedListeners: { (Account, Deed) -> () } = {}
local toastRemote: RemoteEvent = ReplicatedStorage:WaitForChild("RanchToast") :: RemoteEvent
local cueRemote: RemoteEvent = ReplicatedStorage:WaitForChild("RanchCue") :: RemoteEvent
local keyOf: (Player | string) -> string

Ledger.LUCK_CHARM = 2 -- a horseshoe counts as two rebirths' worth of luck while it lasts

local function newAccount(key: string, name: string, player: Player?, cash: number, rebirths: number): Account
	return {
		key = key, name = name, player = player, isBot = player == nil,
		cash = cash, rebirths = rebirths, plot = nil, stalls = {},
		lockedUntil = 0, carrying = nil, trampledUntil = 0, luckUntil = 0,
		dex = {}, contracts = {}, guideStep = 1, earned = 0,
	}
end

-- Opens an account with starting cash and a leaderstats board for a joining player.
function Ledger.openAccount(player: Player)
	local account = newAccount(keyOf(player), player.DisplayName, player, Cast.START_CASH, 0)
	accounts[account.key] = account
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = stats
	local found = Instance.new("StringValue")
	found.Name = "Dex"
	found.Parent = stats
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
	local account = newAccount(keyOf(name), name, nil, cash, rebirths)
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

-- Income a second of everything in the account's stalls (before any event boost).
function Ledger.incomeOf(account: Account): number
	local total = 0
	for _, record in account.stalls do
		total += Cast.incomeOf(record.id, record.mutation, account.rebirths)
	end
	return total
end

-- Luck tilts the Cattle Drive toward rarer rungs: one point a rebirth, more with a horseshoe.
function Ledger.luckOf(account: Account): number
	local charm = if account.luckUntil > workspace:GetServerTimeNow() then Ledger.LUCK_CHARM else 0
	return account.rebirths + charm
end

function Ledger.addCash(account: Account, amount: number)
	account.cash += amount
	if amount > 0 then
		account.earned += amount
	end
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

function Ledger.herdSize(account: Account): number
	local n = 0
	for _ in account.stalls do
		n += 1
	end
	return n
end

-- Marks a critter (and its mutation, or "Normal") as found in the account's RanchDex.
-- Returns true when this is the first time this critter or this mutation of it was found.
function Ledger.discover(account: Account, id: string, mutation: string?): boolean
	local entry = account.dex[id]
	local isNew = entry == nil
	if not entry then
		entry = {}
		account.dex[id] = entry
	end
	local key = mutation or "Normal"
	local newMutation = not entry[key]
	entry[key] = true
	return isNew or (mutation ~= nil and newMutation)
end

function Ledger.dexCount(account: Account): number
	local n = 0
	for _ in account.dex do
		n += 1
	end
	return n
end

-- Pushes an account to its player's attributes and leaderstats, the only state the client sees.
function Ledger.syncRancher(account: Account)
	local player = account.player
	if not player then
		return
	end
	player:SetAttribute("Cash", account.cash)
	player:SetAttribute("Income", Ledger.incomeOf(account))
	player:SetAttribute("Rebirths", account.rebirths)
	player:SetAttribute("RebirthCost", Cast.rebirthCost(account.rebirths))
	player:SetAttribute("Multiplier", Cast.rebirthMultiplier(account.rebirths))
	player:SetAttribute("StallsUsed", Ledger.herdSize(account))
	player:SetAttribute("StallsOpen", Cast.stallsFor(account.rebirths))
	player:SetAttribute("LockedUntil", account.lockedUntil)
	player:SetAttribute("LuckUntil", account.luckUntil)
	player:SetAttribute("Luck", Ledger.luckOf(account))
	player:SetAttribute("GuideStep", account.guideStep)
	player:SetAttribute("Carrying", if account.carrying then Cast.critterById(account.carrying.id).name else "")
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		(stats :: any).Cash.Value = Cast.formatCash(account.cash);
		(stats :: any).Rebirths.Value = account.rebirths;
		(stats :: any).Dex.Value = Ledger.dexCount(account) .. "/" .. #Cast.CRITTERS
	end
end

-- The board and the dex change less often than cash: sent as JSON only when they change.
function Ledger.syncBoard(account: Account)
	local player = account.player
	if not player then
		return
	end
	player:SetAttribute("Contracts", HttpService:JSONEncode(account.contracts))
	local dex = {}
	for id, found in account.dex do
		local list = {}
		for key in found do
			table.insert(list, key)
		end
		dex[id] = list
	end
	player:SetAttribute("Dex", HttpService:JSONEncode(dex))
	Ledger.syncRancher(account)
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

-- A sound (and sometimes a flourish) on one rancher's client: RanchAudio plays the named cue.
function Ledger.cue(account: Account?, name: string, data: any?)
	if account and account.player then
		cueRemote:FireClient(account.player, name, data)
	end
end

function Ledger.cueAll(name: string, data: any?)
	cueRemote:FireAllClients(name, data)
end

-- Something worth counting happened to a rancher: contracts, the guide and the dex listen.
function Ledger.deed(account: Account?, deed: Deed)
	if not account or account.isBot then
		return
	end
	for _, listener in deedListeners do
		task.spawn(listener, account, deed)
	end
end

function Ledger.onDeed(listener: (Account, Deed) -> ())
	table.insert(deedListeners, listener)
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
