-- Showcase: shortcuts to each screen of Rot Ranch for a Studio play-test, a reviewer or TOUR.json.
-- Showcase.stage("cover" | "lasso" | "herd" | "stampede" | "goldenhour" | "dustdevil" | "raid") sets
-- the first player's ranch up for that beat; ServerStorage.RanchShowcase (a BindableFunction)
-- takes the finer commands: cash, rebirths, herd, lock, guide, dex, and any event by name.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local CattleDrive = require(script.Parent:WaitForChild("CattleDrive"))
local Events = require(script.Parent:WaitForChild("Events"))
local Guide = require(script.Parent:WaitForChild("Guide"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Pens = require(script.Parent:WaitForChild("Pens"))
local Rustling = require(script.Parent:WaitForChild("Rustling"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Showcase = {}

-- A herd that shows every mutation and the top of the ladder.
Showcase.HERD = {
	{ "udderlord" }, { "haybalehydra", "Golden" }, { "moothership" }, { "jackalope", "Spicy" }, { "wienerbago", "Crystal" },
	{ "brisketbronco" }, { "banjobuzzard", "Ghost" }, { "hamwich", "Golden" }, { "cactopus", "Moldy" }, { "skelecow" },
}

local function firstAccount(): (Player?, Ledger.Account?)
	local player = Players:GetPlayers()[1]
	return player, player and Ledger.accountOf(player)
end

local function clearHerd(account: Ledger.Account)
	for stall, record in account.stalls do
		record.model:Destroy()
		account.stalls[stall] = nil
	end
end

-- Lassoes a critter right next to the first player, with a slow flight so the rope hangs in the air.
local function showLasso(player: Player, account: Ledger.Account)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not account.plot then
		return
	end
	local x = account.plot.cf.Position.X - 8
	local side = if account.plot.cf.Position.Z < 0 then -1 else 1
	character:PivotTo(CFrame.lookAt(Vector3.new(x, 3.2, side * 13), Vector3.new(x + 6, 3.2, 0)))
	task.wait(0.3)
	local entry = CattleDrive.spawnDriveCritter("toastallion", "Golden")
	local span = World.DRIVE_END_X - World.DRIVE_START_X
	CattleDrive.fastForward(entry, math.clamp((x + 7 - World.DRIVE_START_X) / span, 0, 1))
	account.cash = math.max(account.cash, entry.price + 500)
	Ledger.syncRancher(account)
	task.wait(0.2)
	CattleDrive.lassoFlight = 3.2
	task.spawn(CattleDrive.lassoCritter, player, entry)
	task.delay(4, function()
		CattleDrive.lassoFlight = 1
	end)
end

-- Runs one finer command; returns true when it did something.
function Showcase.run(command: string, arg: any?): boolean
	local player, account = firstAccount()
	if command == "stampede" or command == "goldenhour" or command == "dustdevil" then
		task.spawn(Events.trigger, command)
	elseif command == "raid" and player then
		task.spawn(Rustling.sendRustlerRaid, player)
	elseif not (player and account) then
		return false
	elseif command == "rebirths" then
		account.rebirths = tonumber(arg) or 0
		Pens.paintRanch(account)
		Ledger.syncRancher(account)
	elseif command == "cash" then
		Ledger.addCash(account, tonumber(arg) or 1000)
	elseif command == "herd" then
		clearHerd(account)
		for i = 1, math.min(tonumber(arg) or #Showcase.HERD, #Showcase.HERD, Cast.stallsFor(account.rebirths)) do
			Pens.stockCritter(account, Showcase.HERD[i][1], Showcase.HERD[i][2])
		end
	elseif command == "lock" then
		account.lockedUntil = workspace:GetServerTimeNow() + (tonumber(arg) or 40)
		Ledger.syncRancher(account)
	elseif command == "guide" then
		Guide.skipTo(account, tonumber(arg) or Guide.DONE)
	elseif command == "dex" then
		-- Everything but the last few rungs, so the book shows both found and ??? cards.
		for i, critter in Cast.CRITTERS do
			if i <= (tonumber(arg) or 17) then
				Ledger.discover(account, critter.id, nil)
			end
		end
		Ledger.syncBoard(account)
	elseif command == "lasso" then
		task.spawn(showLasso, player, account)
	else
		return false
	end
	return true
end

-- One screen per call, for TOUR.json: "cover", "lasso", "herd", "raid" or an event name.
function Showcase.stage(name: string)
	local _, account = firstAccount()
	if account and (name == "cover" or name == "herd") then
		Showcase.run("rebirths", 2)
		Showcase.run("herd")
		Showcase.run("cash", 45000 - account.cash)
		Showcase.run("dex")
		Showcase.run("guide", Guide.DONE)
	end
	if name == "cover" then
		Showcase.run("goldenhour")
	elseif name == "lasso" or name == "stampede" or name == "goldenhour" or name == "dustdevil" or name == "raid" then
		Showcase.run(name)
	end
end

function Showcase.bind()
	local showcase = Instance.new("BindableFunction")
	showcase.Name = "RanchShowcase"
	showcase.OnInvoke = Showcase.run
	showcase.Parent = ServerStorage
end

return Showcase
