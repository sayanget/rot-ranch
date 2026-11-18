-- Events: the ranch's calendar. Between calm spells it runs one set-piece at a time, in a rotation:
-- the STAMPEDE (rot bulls down the drive), GOLDEN HOUR (double income, golden light, more Golden
-- critters) and the DUST DEVIL (a purple twister through the ranch rows that flings ranchers and
-- spits coins). Each event registers a runner here; this module publishes what is on now and what
-- is next (Workspace attributes the HUD's timer reads) and rewards everyone who came through unhurt.
local Workspace = game:GetService("Workspace")

local Ledger = require(script.Parent:WaitForChild("Ledger"))

local Events = {}

Events.GAP = { 55, 75 } -- seconds of calm between two events
Events.FIRST_GAP = 70 -- a new server gives the first players time to lasso before anything happens
Events.ORDER = { "stampede", "goldenhour", "dustdevil", "stampede", "dustdevil", "goldenhour" }
Events.NAMES = { stampede = "STAMPEDE", goldenhour = "GOLDEN HOUR", dustdevil = "DUST DEVIL" }

-- What the running event does to the economy (Income and the Cattle Drive read these).
Events.incomeBoost = 1
Events.goldenBoost = 1

local runners: { [string]: () -> () } = {}
local running: string? = nil
local turn = 0
local rng = Random.new()

function Events.register(kind: string, runner: () -> ())
	runners[kind] = runner
end

function Events.current(): string?
	return running
end

-- Publishes the running event's phase; endsAt is the server time the phase ends (0 if unknown).
function Events.setPhase(kind: string, phase: string, endsAt: number)
	Workspace:SetAttribute("EventKind", kind)
	Workspace:SetAttribute("EventPhase", phase)
	Workspace:SetAttribute("EventEndsAt", endsAt)
end

local function scheduleNext(delay: number)
	turn = turn % #Events.ORDER + 1
	Workspace:SetAttribute("NextEventKind", Events.ORDER[turn])
	Workspace:SetAttribute("NextEventAt", Workspace:GetServerTimeNow() + delay)
end

-- Runs one event now (a scheduled one, or one the Showcase asks for). Returns false if one is on.
function Events.trigger(kind: string): boolean
	local runner = runners[kind]
	if running or not runner then
		return false
	end
	running = kind
	local startedAt = Workspace:GetServerTimeNow()
	Workspace:SetAttribute("NextEventAt", 0)
	local ok, err = pcall(runner)
	if not ok then
		warn("Event " .. kind .. " failed: " .. tostring(err))
	end
	Events.incomeBoost = 1
	Events.goldenBoost = 1
	Events.setPhase("", "calm", 0)
	-- Everyone who was not trampled or flung during it survived the event.
	for _, account in Ledger.players() do
		if account.trampledUntil < startedAt + 4 then
			Ledger.deed(account, { kind = "survive", id = kind })
		end
	end
	running = nil
	scheduleNext(rng:NextInteger(Events.GAP[1], Events.GAP[2]))
	return true
end

-- The calendar loop: wait for the next event's time, then run it.
function Events.startEventClock()
	Events.setPhase("", "calm", 0)
	turn = 0
	scheduleNext(Events.FIRST_GAP)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local at = Workspace:GetAttribute("NextEventAt") :: number?
			if not running and at and at > 0 and Workspace:GetServerTimeNow() >= at then
				Events.trigger(Workspace:GetAttribute("NextEventKind") :: string)
			end
		end
	end)
end

return Events
