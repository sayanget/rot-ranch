-- Ranch: boots Rot Ranch on the server. Builds the world, opens the rival ranches, starts the Cattle
-- Drive, the payday clock, the rustling watch and the stampede clock, and wires each player in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CattleDrive = require(ServerStorage:WaitForChild("CattleDrive"))
local Income = require(ServerStorage:WaitForChild("Income"))
local Ledger = require(ServerStorage:WaitForChild("Ledger"))
local Pens = require(ServerStorage:WaitForChild("Pens"))
local Rebirth = require(ServerStorage:WaitForChild("Rebirth"))
local Rustling = require(ServerStorage:WaitForChild("Rustling"))
local Stampede = require(ServerStorage:WaitForChild("Stampede"))
local World = require(ServerStorage:WaitForChild("Workshop"):WaitForChild("World"))

local action = ReplicatedStorage:WaitForChild("RanchAction") :: RemoteEvent
local lastAction: { [Player]: number } = {}

local function welcomeRancher(player: Player)
	local account = Ledger.openAccount(player)
	if not Pens.claimRanch(account) then
		Ledger.toast(account, "Every ranch is taken - you can still rustle!", Color3.fromRGB(255, 160, 80))
	end
	player.CharacterAdded:Connect(function(character)
		Pens.sendRancherHome(player, character)
	end)
	if player.Character then
		task.spawn(Pens.sendRancherHome, player, player.Character)
	end
	Ledger.toast(account, "Welcome to ROT RANCH! Lasso critters off the Cattle Drive (hold E).", Color3.fromRGB(255, 240, 160))
end

local function farewellRancher(player: Player)
	local account = Ledger.accountOf(player)
	if account then
		Pens.releaseRanch(account)
		Ledger.closeAccount(account)
	end
	lastAction[player] = nil
end

-- What the HUD buttons and keys ask for: "lock" the gate or "rebirth".
action.OnServerEvent:Connect(function(player, kind)
	local now = os.clock()
	if (lastAction[player] or 0) > now - 0.4 then
		return
	end
	lastAction[player] = now
	local account = Ledger.accountOf(player)
	if not account then
		return
	end
	if kind == "lock" then
		Rustling.lockGate(account)
	elseif kind == "rebirth" then
		Rebirth.rebirthRancher(player)
	end
end)

-- Showcase: a server-only BindableFunction a Studio play-test (or a reviewer) invokes to reach each
-- screen quickly: "herd" stocks the first player's ranch, "cash" pays them, "stampede", "raid".
local SHOWCASE_HERD = {
	{ "udderlord" }, { "tractortoise", "Golden" }, { "llamplighter" }, { "scarecrowbar" }, { "toastallion", "Moldy" },
	{ "duckwaffle" }, { "goatcho" }, { "hamwich", "Golden" }, { "baagel" }, { "rotfather" },
}
local showcase = Instance.new("BindableFunction")
showcase.Name = "RanchShowcase"
showcase.OnInvoke = function(command: string, arg: any)
	local player = Players:GetPlayers()[1]
	local account = player and Ledger.accountOf(player)
	if command == "stampede" then
		task.spawn(Stampede.startStampede)
	elseif command == "raid" and player then
		task.spawn(Rustling.sendRustlerRaid, player)
	elseif account and command == "rebirths" then
		account.rebirths = tonumber(arg) or 0
		Pens.paintRanch(account)
		Ledger.syncRancher(account)
	elseif account and command == "cash" then
		Ledger.addCash(account, tonumber(arg) or 1000)
	elseif account and command == "herd" then
		for i = 1, math.min(tonumber(arg) or #SHOWCASE_HERD, #SHOWCASE_HERD) do
			Pens.stockCritter(account, SHOWCASE_HERD[i][1], SHOWCASE_HERD[i][2])
		end
	elseif account and command == "lock" then
		account.lockedUntil = workspace:GetServerTimeNow() + (tonumber(arg) or 40)
		Ledger.syncRancher(account)
	end
	return true
end
showcase.Parent = ServerStorage

Pens.setup(World.buildRanchPlots())
World.decorateRanchland()
Pens.openRivalRanches()
Players.PlayerAdded:Connect(welcomeRancher)
Players.PlayerRemoving:Connect(farewellRancher)
for _, player in Players:GetPlayers() do
	task.spawn(welcomeRancher, player)
end
CattleDrive.startCattleDrive()
Income.startIncomeClock()
Rustling.startRustlingWatch()
Stampede.startStampedeClock()
