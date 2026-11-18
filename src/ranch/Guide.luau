-- Guide: the first-time trail boss. A new rancher gets four steps, one at a time, each ticked off by
-- doing it: LASSO a critter off the drive, get it HOME to your pens, LOCK your gate, and SURVIVE a
-- ranch event. The HUD shows the current step; finishing the trail pays a bonus and a horseshoe.
local Ledger = require(script.Parent:WaitForChild("Ledger"))
local World = require(script.Parent:WaitForChild("Workshop"):WaitForChild("World"))

local Guide = {}

Guide.STEPS = { "lasso", "home", "lock", "survive" }
Guide.DONE = #Guide.STEPS + 1
Guide.BONUS = 300

local GOLD = Color3.fromRGB(255, 225, 90)

local function advance(account: Ledger.Account)
	account.guideStep += 1
	Ledger.syncRancher(account)
	Ledger.cue(account, "guide", account.guideStep)
	if account.guideStep == Guide.DONE then
		Ledger.addCash(account, Guide.BONUS)
		account.luckUntil = math.max(workspace:GetServerTimeNow(), account.luckUntil) + 60
		Ledger.syncRancher(account)
		Ledger.toast(account, "TRAIL COMPLETE! +$" .. Guide.BONUS .. " and a Lucky Horseshoe. You're a real rancher now.", GOLD)
	end
end

-- Ticks the current step when the matching deed happens.
function Guide.recordDeed(account: Ledger.Account, deed: Ledger.Deed)
	local step = Guide.STEPS[account.guideStep]
	if not step then
		return
	end
	if (step == "lasso" and (deed.kind == "lasso" or deed.kind == "rustle"))
		or (step == "lock" and deed.kind == "lock")
		or (step == "survive" and deed.kind == "survive") then
		advance(account)
	end
end

-- "home" has no deed: it is done when you stand in your own ranch with a critter in a stall.
local function checkHome()
	for _, account in Ledger.players() do
		if Guide.STEPS[account.guideStep] == "home" and account.plot and Ledger.herdSize(account) > 0 then
			local character = account.player and account.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and World.ranchContains(account.plot, root.Position) then
				advance(account)
			end
		end
	end
end

-- A rancher who already owns a herd (the Showcase, a returning tester) skips what they've done.
function Guide.skipTo(account: Ledger.Account, step: number)
	account.guideStep = math.clamp(step, 1, Guide.DONE)
	Ledger.syncRancher(account)
end

function Guide.startGuide()
	Ledger.onDeed(Guide.recordDeed)
	task.spawn(function()
		while true do
			task.wait(0.5)
			checkHome()
		end
	end)
end

return Guide
