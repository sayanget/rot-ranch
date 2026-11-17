-- CattleDrive: the conveyor of the ranch. Critters trot out of the Rot Corral in two lanes, down the
-- dirt drive past every ranch gate, and into Dust Canyon. Each wears its price; hold E to lasso it
-- and it flies into a free stall of yours. A stampede tramples whatever is still on the drive.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Cast = require(ReplicatedStorage:WaitForChild("Cast"))
local Critters = require(script.Parent:WaitForChild("Workshop"):WaitForChild("Critters"))
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local Pens = require(script.Parent:WaitForChild("Pens"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local CattleDrive = {}

CattleDrive.SPAWN_EVERY = 2.4
CattleDrive.TROT_SPEED = 6.5
CattleDrive.LANES = { -3.6, 3.6 }
CattleDrive.paused = false

type DriveEntry = { record: Ledger.CritterRecord, price: number, tween: Tween?, sold: boolean }

local onDrive: { DriveEntry } = {}
local rng = Random.new()
local folder: Folder
local laneTurn = 0
local luckOfRanchers: () -> number
local leaveDrive: (DriveEntry) -> ()


-- Lasso: pay the price, the critter leaves the drive and flies to your first free stall.
function CattleDrive.lassoCritter(player: Player, entry: DriveEntry)
	local account = Ledger.accountOf(player)
	if entry.sold or not account or not account.plot then
		return
	end
	local critter = Cast.critterById(entry.record.id)
	local stall = Pens.freeStallOf(account)
	if not stall then
		Ledger.toast(account, "Your pens are full! Rebirth for more stalls.", Color3.fromRGB(255, 160, 80))
		return
	end
	if not Ledger.spendCash(account, entry.price) then
		Ledger.toast(account, "Need " .. Cast.formatCash(entry.price) .. " to lasso " .. critter.name, Color3.fromRGB(255, 120, 100))
		return
	end
	entry.sold = true
	leaveDrive(entry)
	if entry.tween then
		entry.tween:Cancel()
	end
	local prompt = entry.record.model:FindFirstChild("LassoPrompt", true)
	if prompt then
		prompt:Destroy()
	end
	local rate = Cast.formatCash(Cast.incomeOf(entry.record.id, entry.record.mutation, account.rebirths))
	Ledger.toast(account, "YEEHAW! Lassoed " .. critter.name .. "  +" .. rate .. "/s", Cast.rarityColor(critter.rarity))
	if Cast.RARITIES[critter.rarity].rank >= 5 then
		Ledger.toastAll(account.name .. " lassoed a " .. string.upper(Cast.rarityLabel(critter.rarity)) .. " " .. critter.name .. "!", Cast.rarityColor(critter.rarity))
	end
	Pens.placeCritterInPen(account, entry.record, stall, true)
end

function luckOfRanchers(): number
	local best = 0
	for _, account in Ledger.players() do
		best = math.max(best, account.rebirths)
	end
	return best
end

function leaveDrive(entry: DriveEntry)
	local i = table.find(onDrive, entry)
	if i then
		table.remove(onDrive, i)
	end
end

-- Sends one rolled critter trotting down the drive with its price tag and Lasso prompt.
function CattleDrive.spawnDriveCritter(forceId: string?, forceMutation: string?): DriveEntry
	local critter, mutation = Cast.rollDriveCritter(rng, luckOfRanchers())
	if forceId then
		critter, mutation = Cast.critterById(forceId), forceMutation
	end
	laneTurn += 1
	local z = CattleDrive.LANES[laneTurn % #CattleDrive.LANES + 1]
	local start = Vector3.new(World.DRIVE_START_X, 0.45, z)
	local finish = Vector3.new(World.DRIVE_END_X, 0.45, z)
	local facing = CFrame.lookAt(start, finish)
	local model = Critters.buildCritter(critter.id, mutation, facing)
	local price = Cast.priceOf(critter.id, mutation)
	Critters.labelCritter(model, critter.id, mutation, 0, price)
	local record: Ledger.CritterRecord = { id = critter.id, mutation = mutation, model = model, owner = nil, stall = nil, carrier = nil }
	local entry: DriveEntry = { record = record, price = price, tween = nil, sold = false }

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LassoPrompt"
	prompt.ActionText = "Lasso " .. Cast.formatCash(price)
	prompt.ObjectText = critter.name .. " (" .. Cast.rarityLabel(critter.rarity) .. ")"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 13
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = (model.PrimaryPart :: BasePart):FindFirstChild("PromptPoint")
	prompt.Triggered:Connect(function(player)
		CattleDrive.lassoCritter(player, entry)
	end)

	model.Parent = folder
	Critters.poof(start + Vector3.new(0, 2, 0), Color3.fromRGB(140, 230, 90), 14)
	local trot = TweenService:Create(model.PrimaryPart :: BasePart, TweenInfo.new((finish - start).Magnitude / CattleDrive.TROT_SPEED, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(finish, finish + (finish - start).Unit),
	})
	entry.tween = trot
	trot.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not entry.sold then
			leaveDrive(entry)
			Critters.poof(finish + Vector3.new(0, 2, 0), Color3.fromRGB(200, 150, 100), 12)
			model:Destroy()
		end
	end)
	trot:Play()
	table.insert(onDrive, entry)
	return entry
end

-- Puts a critter partway down the drive at once (used to fill the drive when the server starts).
function CattleDrive.fastForward(entry: DriveEntry, fraction: number)
	if not entry.tween then
		return
	end
	local root = entry.record.model.PrimaryPart :: BasePart
	entry.tween:Cancel()
	local z = root.Position.Z
	local start = Vector3.new(World.DRIVE_START_X + (World.DRIVE_END_X - World.DRIVE_START_X) * fraction, 0.45, z)
	local finish = Vector3.new(World.DRIVE_END_X, 0.45, z)
	root.CFrame = CFrame.lookAt(start, finish)
	local trot = TweenService:Create(root, TweenInfo.new((finish - start).Magnitude / CattleDrive.TROT_SPEED, Enum.EasingStyle.Linear), {
		CFrame = CFrame.lookAt(finish, finish + Vector3.xAxis),
	})
	entry.tween = trot
	trot.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and not entry.sold then
			leaveDrive(entry)
			entry.record.model:Destroy()
		end
	end)
	trot:Play()
end

-- The stampede flattens every unsold critter between two x positions on the drive.
function CattleDrive.trampleDriveCritters(fromX: number, toX: number): number
	local count = 0
	for i = #onDrive, 1, -1 do
		local entry = onDrive[i]
		local root = entry.record.model.PrimaryPart
		if root and root.Position.X >= fromX and root.Position.X <= toX then
			entry.sold = true
			if entry.tween then
				entry.tween:Cancel()
			end
			table.remove(onDrive, i)
			Critters.poof(root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(170, 130, 90), 18)
			entry.record.model:Destroy()
			count += 1
		end
	end
	return count
end

function CattleDrive.startCattleDrive()
	folder = Instance.new("Folder")
	folder.Name = "CattleDrive"
	folder.Parent = workspace
	-- Fill the drive so the first player sees a full line, then keep it coming.
	local warm = 18
	for i = 1, warm do
		local entry = CattleDrive.spawnDriveCritter()
		CattleDrive.fastForward(entry, (warm - i) / warm * 0.95)
	end
	task.spawn(function()
		while true do
			task.wait(CattleDrive.SPAWN_EVERY)
			if not CattleDrive.paused then
				CattleDrive.spawnDriveCritter()
			end
		end
	end)
end

return CattleDrive
