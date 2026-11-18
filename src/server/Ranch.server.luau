-- Ranch: boots Rot Ranch on the server. Lights the sky, builds the world, opens the rival ranches,
-- starts the Cattle Drive, the payday clock, the rustling watch, the event calendar (stampede,
-- Golden Hour, Dust Devil), the contract board and the guide, and wires each player in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CattleDrive = require(ServerStorage:WaitForChild("CattleDrive"))
local Contracts = require(ServerStorage:WaitForChild("Contracts"))
local DustDevil = require(ServerStorage:WaitForChild("DustDevil"))
local Events = require(ServerStorage:WaitForChild("Events"))
local Guide = require(ServerStorage:WaitForChild("Guide"))
local Income = require(ServerStorage:WaitForChild("Income"))
local Ledger = require(ServerStorage:WaitForChild("Ledger"))
local Pens = require(ServerStorage:WaitForChild("Pens"))
local Rebirth = require(ServerStorage:WaitForChild("Rebirth"))
local Rustling = require(ServerStorage:WaitForChild("Rustling"))
local Showcase = require(ServerStorage:WaitForChild("Showcase"))
local Workshop = ServerStorage:WaitForChild("Workshop")
local Mood = require(Workshop:WaitForChild("Mood"))
local World = require(Workshop:WaitForChild("World"))
-- The event modules register themselves with the calendar when required.
require(ServerStorage:WaitForChild("Stampede"))
require(ServerStorage:WaitForChild("GoldenHour"))

local action = ReplicatedStorage:WaitForChild("RanchAction") :: RemoteEvent
local lastAction: { [Player]: number } = {}

local function welcomeRancher(player: Player)
	local account = Ledger.openAccount(player)
	if not Pens.claimRanch(account) then
		Ledger.toast(account, "Every ranch is taken - you can still rustle!", Color3.fromRGB(255, 160, 80))
	end
	Contracts.dealBoard(account)
	player.CharacterAdded:Connect(function(character)
		Pens.sendRancherHome(player, character)
	end)
	if player.Character then
		task.spawn(Pens.sendRancherHome, player, player.Character)
	end
	Ledger.toast(account, "Howdy, " .. player.DisplayName .. "! Welcome to ROT RANCH.", Color3.fromRGB(255, 240, 160))
	Ledger.cue(account, "welcome")
	Ledger.toastAll(player.DisplayName .. " rode into town.", Color3.fromRGB(255, 220, 170))
end

local function farewellRancher(player: Player)
	local account = Ledger.accountOf(player)
	if account then
		Pens.releaseRanch(account)
		Contracts.forget(account)
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

Mood.lightTheRanch()
Pens.setup(World.buildRanchPlots())
World.decorateRanchland()
World.startRanchlandMotion()
Pens.openRivalRanches()
Showcase.bind()
Contracts.startContractBoard()
Guide.startGuide()
Players.PlayerAdded:Connect(welcomeRancher)
Players.PlayerRemoving:Connect(farewellRancher)
for _, player in Players:GetPlayers() do
	task.spawn(welcomeRancher, player)
end
CattleDrive.startCattleDrive()
Income.startIncomeClock()
Rustling.startRustlingWatch()
DustDevil.startCoinSpinner()
Events.startEventClock()
