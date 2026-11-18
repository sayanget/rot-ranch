-- Rustling: the steal-and-lock half of the ranch. Hold E on a critter behind an OPEN gate to rustle
-- it and carry it home over your head; lock your own gate from inside your ranch (L, the HUD button
-- or the LOCK pad). Rival ranchers' gates open and shut on a clock, and masked rustlers ride in to
-- raid an open ranch, whistling as they come: tag one before it reaches the edge of the map and you
-- get your critter back plus a bounty. Every lock, rustle and tag counts toward the contract board.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(ReplicatedStorage:WaitForChild("Critters"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Pens = require(script.Parent:WaitForChild("Pens"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Rustling = {}

Rustling.CARRY_SCALE = 0.55
Rustling.RAID_EVERY = { 55, 85 }
Rustling.RUSTLER_SPEED = 15

local RED = Color3.fromRGB(255, 90, 80)
local GREEN = Color3.fromRGB(130, 255, 120)
local activeRaids: { [Ledger.Account]: boolean } = {}
local rng = Random.new()
local rootOf: (Player) -> BasePart?
local setCarryScale: (Ledger.CritterRecord, number) -> ()

-- Rustle: lift a critter out of an unlocked rival's stall and carry it over your head.
function Rustling.stealFromUnlockedPen(thief: Player, record)
	local thiefAccount = Ledger.accountOf(thief)
	local owner = record.owner
	local root = rootOf(thief)
	if not thiefAccount or not owner or owner == thiefAccount or not root or record.carrier then
		return
	end
	if Ledger.isLocked(owner) then
		Ledger.toast(thiefAccount, owner.name .. "'s gate is LOCKED. Wait for it to open!", RED)
		return
	end
	if thiefAccount.carrying then
		Ledger.toast(thiefAccount, "Your hands are full - run that one home first!", RED)
		return
	end
	if not Pens.freeStallOf(thiefAccount) then
		Ledger.toast(thiefAccount, "No free stall at home for it!", RED)
		return
	end
	Pens.takeCritterFromPen(record)
	record.carrier = thief
	thiefAccount.carrying = record
	local model = record.model
	local prompt = model:FindFirstChild("RustlePrompt", true) :: ProximityPrompt?
	if prompt then
		prompt.Enabled = false
	end
	setCarryScale(record, Rustling.CARRY_SCALE)
	model:SetAttribute("Gait", "carried")
	local critterRoot = model.PrimaryPart :: BasePart
	critterRoot.CFrame = root.CFrame * CFrame.new(0, 3.2, 0)
	critterRoot.Anchored = false
	critterRoot.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, critterRoot
	weld.Parent = critterRoot
	model.Parent = workspace
	Ledger.syncRancher(thiefAccount)
	local name = Cast.critterById(record.id).name
	Ledger.toast(thiefAccount, "Rustled " .. name .. "! Run it home to YOUR ranch!", Color3.fromRGB(255, 220, 90))
	Ledger.toast(owner, thief.DisplayName .. " is rustling your " .. name .. "! Lock your gate!", RED)
	Ledger.cue(thiefAccount, "rustle")
	Ledger.cue(owner, "alarm")
end

function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function setCarryScale(record: Ledger.CritterRecord, scale: number)
	record.model:ScaleTo(scale)
end

-- Locks a rancher's gate for its lock time; a player must be standing inside their own ranch.
function Rustling.lockGate(account: Ledger.Account): boolean
	local plot = account.plot
	if not plot then
		return false
	end
	if account.player then
		local root = rootOf(account.player)
		if not root or not World.ranchContains(plot, root.Position) then
			Ledger.toast(account, "Get inside your ranch to lock the gate!", RED)
			return false
		end
	end
	local now = workspace:GetServerTimeNow()
	if account.lockedUntil > now then
		Ledger.toast(account, string.format("Gate already locked (%ds left)", math.ceil(account.lockedUntil - now)), GREEN)
		return false
	end
	account.lockedUntil = now + Cast.lockSeconds(account.rebirths)
	Ledger.syncRancher(account)
	Ledger.toast(account, "GATE LOCKED for " .. Cast.lockSeconds(account.rebirths) .. "s - your herd is safe", GREEN)
	Ledger.cue(account, "lock")
	Ledger.deed(account, { kind = "lock" })
	return true
end

-- Puts a carried critter back where it came from (or anywhere free in its owner's ranch).
function Rustling.returnCarried(thief: Ledger.Account?, record: Ledger.CritterRecord)
	if thief and thief.carrying == record then
		thief.carrying = nil
		Ledger.syncRancher(thief)
	end
	record.carrier = nil
	local root = record.model.PrimaryPart :: BasePart
	for _, d in root:GetChildren() do
		if d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	root.Anchored = true
	setCarryScale(record, 1)
	local owner = record.owner
	if owner and owner.plot and (owner.isBot or (owner.player and owner.player.Parent)) then
		local stall = if record.stall and not owner.stalls[record.stall] then record.stall else Pens.freeStallOf(owner)
		if stall then
			Pens.placeCritterInPen(owner, record, stall, false)
			Critters.poof(root.Position, Color3.fromRGB(230, 200, 140), 12)
			return
		end
	end
	Critters.poof(root.Position, Color3.fromRGB(170, 130, 90), 12)
	record.model:Destroy()
end

-- Every few frames: a carried critter that reaches its thief's ranch moves into a free stall there.
function Rustling.deliverCarriedCritters()
	for _, account in Ledger.players() do
		local record = account.carrying
		if record and account.player then
			local root = rootOf(account.player)
			if not root then
				Rustling.returnCarried(account, record)
			elseif account.plot and World.ranchContains(account.plot, root.Position) then
				local stall = Pens.freeStallOf(account)
				if stall then
					account.carrying = nil
					local critterRoot = record.model.PrimaryPart :: BasePart
					for _, d in critterRoot:GetChildren() do
						if d:IsA("WeldConstraint") then
							d:Destroy()
						end
					end
					setCarryScale(record, 1)
					critterRoot.Anchored = true
					local victim = record.owner
					local name = Cast.critterById(record.id).name
					local rescueRoot = critterRoot.Position
					local prompt = record.model:FindFirstChild("RustlePrompt", true) :: ProximityPrompt?
					if prompt then
						prompt.Enabled = true
					end
					task.spawn(Pens.placeCritterInPen, account, record, stall, true)
					Critters.poof(rescueRoot, Color3.fromRGB(255, 220, 90), 16)
					Ledger.toast(account, "Rustled " .. name .. " home! It earns for YOU now.", GREEN)
					Ledger.cue(account, "delivered")
					if Ledger.discover(account, record.id, record.mutation) then
						Ledger.toast(account, "NEW in your RanchDex: " .. name .. "!", Color3.fromRGB(255, 236, 150))
						Ledger.deed(account, { kind = "discover", id = record.id, mutation = record.mutation })
					end
					Ledger.syncBoard(account)
					Ledger.deed(account, { kind = "rustle", id = record.id, mutation = record.mutation })
					if victim and victim ~= account then
						Ledger.toast(victim, account.name .. " got away with your " .. name .. "!", RED)
					end
				end
			end
		end
	end
end

-- Repaints every gate (bars + countdown) and switches Rustle prompts off behind locked gates.
function Rustling.tickGates()
	local now = workspace:GetServerTimeNow()
	for _, plot in Pens.plots() do
		local owner = Pens.ownerOfPlot(plot.index)
		local locked = owner ~= nil and owner.lockedUntil > now
		World.paintGate(plot, locked, if owner then owner.lockedUntil - now else 0)
		if owner then
			for _, record in owner.stalls do
				local prompt = record.model:FindFirstChild("RustlePrompt", true) :: ProximityPrompt?
				if prompt then
					prompt.Enabled = not locked
				end
			end
		end
	end
end

-- Rival bots lock for a while, then leave the gate open long enough to be rustled from. Each rival
-- (by account order i) gets its own lock and open lengths, so their gates drift out of step.
function Rustling.cycleRivalGates()
	local now = workspace:GetServerTimeNow()
	for i, account in Ledger.allAccounts() do
		if account.isBot and account.lockedUntil < now - 14 - i * 3 then
			account.lockedUntil = now + 18 + i * 4
		end
	end
end

local function rideTo(root: BasePart, target: Vector3, speed: number): Tween
	local from = root.Position
	local goal = Vector3.new(target.X, from.Y, target.Z)
	local heading = if (goal - from).Magnitude > 0.5 then (goal - from).Unit else root.CFrame.LookVector
	local tween = TweenService:Create(root, TweenInfo.new(math.max(0.2, (goal - from).Magnitude / speed), Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(goal, goal + heading),
	})
	tween:Play()
	return tween
end

-- A rustler raid on a player's ranch: warns, rides to the gate, bounces off a locked one, or grabs
-- the best earner and flees for the map edge. Touching the rustler wins the critter back.
function Rustling.sendRustlerRaid(target: Player?)
	local player = target or Players:GetPlayers()[1]
	local account = player and Ledger.accountOf(player)
	if not account or not account.plot or activeRaids[account] then
		return
	end
	local plot = account.plot
	activeRaids[account] = true
	local fromEast = rng:NextNumber() < 0.5
	local edgeX = if fromEast then World.DRIVE_END_X + 20 else World.DRIVE_START_X - 20
	Ledger.toast(account, "A RUSTLER is riding for your ranch! Get home and LOCK your gate (L)!", RED)
	Ledger.cue(account, "whistle")
	player:SetAttribute("RaidEta", workspace:GetServerTimeNow() + 9)

	local model, root = Critters.buildRustler(CFrame.new(edgeX, 0, 0))
	model.Parent = workspace
	local outside = (plot.cf * CFrame.new(0, 0, -World.PLOT_HALF_D - 6)).Position
	local gate = (plot.cf * CFrame.new(0, 0, -World.PLOT_HALF_D + 2)).Position
	local carried: Ledger.CritterRecord? = nil
	local caught = false
	local touch = root.Touched:Connect(function(hit)
		local character = player.Character
		if carried and not caught and character and hit:IsDescendantOf(character) then
			caught = true
		end
	end)

	local function finish(text: string, color: Color3)
		touch:Disconnect()
		player:SetAttribute("RaidEta", 0)
		Ledger.toast(account, text, color)
		Critters.poof(root.Position, Color3.fromRGB(170, 130, 90), 20)
		model:Destroy()
		activeRaids[account] = nil
	end

	rideTo(root, outside, Rustling.RUSTLER_SPEED).Completed:Wait()
	if Ledger.isLocked(account) or not account.plot then
		root.CFrame *= CFrame.Angles(0, math.pi, 0)
		rideTo(root, Vector3.new(edgeX, 0, 0), Rustling.RUSTLER_SPEED * 1.4).Completed:Wait()
		Ledger.cue(account, "lockHeld")
		Ledger.deed(account, { kind = "repel" })
		finish("Your locked gate held! The rustler rode off empty-handed.", GREEN)
		return
	end
	local best: Ledger.CritterRecord? = nil
	for _, record in account.stalls do
		if not best or Cast.incomeOf(record.id, record.mutation, 0) > Cast.incomeOf(best.id, best.mutation, 0) then
			best = record
		end
	end
	if not best then
		rideTo(root, Vector3.new(edgeX, 0, 0), Rustling.RUSTLER_SPEED).Completed:Wait()
		finish("The rustler found nothing worth taking.", GREEN)
		return
	end
	local victim = best :: Ledger.CritterRecord
	rideTo(root, gate, Rustling.RUSTLER_SPEED).Completed:Wait()
	rideTo(root, (victim.model.PrimaryPart :: BasePart).Position, Rustling.RUSTLER_SPEED).Completed:Wait()
	if victim.owner ~= account or account.stalls[victim.stall or 0] ~= victim then
		rideTo(root, Vector3.new(edgeX, 0, 0), Rustling.RUSTLER_SPEED).Completed:Wait()
		finish("The rustler came up empty.", GREEN)
		return
	end
	Pens.takeCritterFromPen(victim)
	carried = victim
	victim.carrier = nil
	setCarryScale(victim, Rustling.CARRY_SCALE)
	victim.model:SetAttribute("Gait", "carried")
	local critterRoot = victim.model.PrimaryPart :: BasePart
	critterRoot.CFrame = root.CFrame * CFrame.new(0, 5.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, critterRoot
	weld.Parent = critterRoot
	critterRoot.Anchored = false
	victim.model.Parent = workspace
	local name = Cast.critterById(victim.id).name
	Ledger.toast(account, "The rustler grabbed your " .. name .. "! Tag them before they reach the edge!", RED)
	Ledger.cue(account, "alarm")
	for _, waypoint in { gate, outside, Vector3.new(edgeX + (if fromEast then 40 else -40), 0, 0) } do
		local ride = rideTo(root, waypoint, Rustling.RUSTLER_SPEED * 0.8)
		while ride.PlaybackState == Enum.PlaybackState.Playing and not caught do
			local chaser = rootOf(player)
			if chaser and (chaser.Position - root.Position).Magnitude < 5.5 then
				caught = true
			end
			task.wait(0.05)
		end
		if caught then
			ride:Cancel()
			break
		end
	end
	if caught then
		Rustling.returnCarried(nil, victim)
		-- the bounty: eight seconds of your herd's income, at least $80, at most a quarter of your cash
		local bounty = math.max(80, math.min(math.floor(Ledger.incomeOf(account) * 8), math.floor(account.cash * 0.25)))
		Ledger.addCash(account, bounty)
		Ledger.cue(account, "tag", bounty)
		Ledger.deed(account, { kind = "tag", amount = bounty })
		finish("You tackled the rustler! " .. name .. " is home, plus a " .. Cast.formatCash(bounty) .. " bounty.", GREEN)
	else
		victim.model:Destroy()
		Ledger.cue(account, "fail")
		finish("The rustler got away with your " .. name .. "...", RED)
	end
end

function Rustling.startRustlingWatch()
	Pens.rustleHandler = Rustling.stealFromUnlockedPen
	for _, plot in Pens.plots() do
		plot.lockPad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local owner = Pens.ownerOfPlot(plot.index)
			if player and owner and owner.player == player and not Ledger.isLocked(owner) then
				Rustling.lockGate(owner)
			end
		end)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			Rustling.deliverCarriedCritters()
			Rustling.tickGates()
			Rustling.cycleRivalGates()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(rng:NextInteger(Rustling.RAID_EVERY[1], Rustling.RAID_EVERY[2]))
			for _, account in Ledger.players() do
				local herd = 0
				for _ in account.stalls do
					herd += 1
				end
				if herd >= 2 and account.player then
					task.spawn(Rustling.sendRustlerRaid, account.player)
				end
			end
		end
	end)
end

return Rustling
