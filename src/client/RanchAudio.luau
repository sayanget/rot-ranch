-- RanchAudio: every sound in Rot Ranch, made in-game. There are no uploaded audio assets: the ranch
-- plays Roblox's own built-in samples (a short tuned pluck, a thud, a boom, wind) at different
-- PlaybackSpeeds, so a pluck pitched by semitones becomes a banjo, a bass and a bell. On top of that
-- it sequences an original boom-chick western soundtrack (bass, banjo rolls, a lead tune, hoof
-- clip-clops), plays the short cues the server sends (lasso, cash, lock, rustle, rebirth, mutation
-- sparkle, rustler whistle, trampled sting...), loops the stampede rumble and the Dust Devil's wind,
-- and ducks the music under every warning.
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RanchAudio = {}

-- The built-in samples. "pluck" is a clean tone at G4 (392 Hz) that decays in a fifth of a second.
local SAMPLES = {
	pluck = "rbxasset://sounds/volume_slider.ogg",
	thud = "rbxasset://sounds/action_jump_land.mp3",
	boom = "rbxasset://sounds/impact_explosion_03.mp3",
	wind = "rbxasset://sounds/action_falling.ogg",
	whoosh = "rbxasset://sounds/action_jump.mp3",
	oof = "rbxasset://sounds/oof.ogg",
	splash = "rbxasset://sounds/impact_water.mp3",
}
local POOL_SIZE = { pluck = 24, thud = 8, boom = 3, whoosh = 4, oof = 2, splash = 2 }

RanchAudio.TEMPO = 118 -- beats a minute; the sequencer steps in eighth notes
RanchAudio.MUSIC_VOLUME = 0.55
RanchAudio.SFX_VOLUME = 0.9

local pools: { [string]: { Sound } } = {}
local cursor: { [string]: number } = {}
local musicGroup: SoundGroup
local sfxGroup: SoundGroup
local loops: { [string]: Sound } = {}
local musicOn = true
local ducked = false

local function semis(n: number): number
	return 2 ^ (n / 12)
end

local function makeGroup(name: string, volume: number): SoundGroup
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Volume = volume
	group.Parent = SoundService
	return group
end

local function makeSound(sample: string, group: SoundGroup): Sound
	local s = Instance.new("Sound")
	s.SoundId = SAMPLES[sample]
	s.SoundGroup = group
	s.Parent = group
	return s
end

-- Plays one note of a sample: n semitones from its own pitch, at a volume, in the music or sfx group.
function RanchAudio.note(sample: string, n: number, volume: number, music: boolean?)
	local pool = pools[(if music then "m:" else "s:") .. sample]
	if not pool then
		return
	end
	local key = (if music then "m:" else "s:") .. sample
	local i = (cursor[key] or 0) % #pool + 1
	cursor[key] = i
	local s = pool[i]
	s.PlaybackSpeed = semis(n)
	s.Volume = volume
	s.TimePosition = 0
	s:Play()
end

-- Plays a little phrase: a list of { delay, sample, semitone, volume } steps.
local function phrase(steps: { { any } })
	for _, step in steps do
		local at, sample, n, vol = step[1], step[2], step[3], step[4]
		if at <= 0 then
			RanchAudio.note(sample, n, vol)
		else
			task.delay(at, RanchAudio.note, sample, n, vol)
		end
	end
end

local function arpeggio(notes: { number }, gap: number, vol: number, start: number?): { { any } }
	local steps = {}
	for i, n in notes do
		table.insert(steps, { (start or 0) + (i - 1) * gap, "pluck", n, vol })
	end
	return steps
end

local function join(...: { { any } }): { { any } }
	local all = {}
	for _, list in { ... } do
		for _, step in list do
			table.insert(all, step)
		end
	end
	return all
end

---------------------------------------------------------------------------------------------------
-- The soundtrack: "Rot Ranch Reel", in G. Semitones are counted from G4 (0).
---------------------------------------------------------------------------------------------------
local CHORDS = {
	G = { root = -24, fifth = -17, tones = { 0, 4, 7 } },
	C = { root = -19, fifth = -12, tones = { 5, 9, 12 } },
	D = { root = -17, fifth = -10, tones = { 2, 7, 11 } },
	Em = { root = -15, fifth = -8, tones = { 4, 7, 11 } },
}
-- Four-bar phrases; each bar is one chord, eight eighth-note steps long.
local PHRASES = {
	{ chords = { "G", "C", "D", "G" }, lead = nil },
	{ chords = { "G", "C", "D", "G" }, lead = {
		{ 7, nil, 4, 7, 12, nil, 11, nil }, { 9, nil, 12, 9, 5, nil, nil, nil },
		{ 7, nil, 11, 14, 11, 7, nil, nil }, { 4, 2, 0, nil, nil, nil, -5, -1 },
	} },
	{ chords = { "Em", "C", "G", "D" }, lead = nil },
	{ chords = { "Em", "C", "G", "D" }, lead = {
		{ 16, nil, 14, 12, 11, nil, 7, nil }, { 9, 12, 16, nil, 14, nil, 12, nil },
		{ 11, nil, 7, 4, 7, nil, 12, nil }, { 14, nil, nil, 11, 9, nil, 7, nil },
	} },
}
local ROLL = { 1, 2, 3, 4, 2, 3, 4, 3 } -- a forward banjo roll over the chord (4 = root an octave up)

local step = 0
local nextStepAt = 0
local twinkle = false

-- Plays one eighth-note step of the reel.
local function playStep()
	local barIndex = step // 8
	local beat = step % 8
	local phraseIndex = (barIndex // 4) % #PHRASES + 1
	local bar = barIndex % 4 + 1
	local p = PHRASES[phraseIndex]
	local chord = CHORDS[p.chords[bar]]
	local lead = p.lead and p.lead[bar][beat + 1]
	-- boom: bass on 1 and 5, alternating root and fifth
	if beat == 0 then
		RanchAudio.note("pluck", chord.root, 0.9, true)
	elseif beat == 4 then
		RanchAudio.note("pluck", chord.fifth, 0.75, true)
	end
	-- chick: a quick strum on the off-beats
	if beat == 2 or beat == 6 then
		for i, n in chord.tones do
			task.delay(i * 0.012, RanchAudio.note, "pluck", n - 12, 0.22, true)
		end
	end
	-- the banjo roll (softer under the lead)
	local t = chord.tones
	local rollTone = ROLL[beat + 1]
	local n = if rollTone == 4 then t[1] + 12 else t[rollTone]
	RanchAudio.note("pluck", n + 12, if lead then 0.12 else 0.26, true)
	if lead then
		RanchAudio.note("pluck", lead + 12, 0.42, true)
	end
	-- hooves: a clip-clop on every step
	RanchAudio.note("thud", if beat % 2 == 0 then 9 else 13, if beat % 2 == 0 then 0.22 else 0.14, true)
	-- Golden Hour: bells sparkle on top
	if twinkle and (beat == 1 or beat == 5) then
		RanchAudio.note("pluck", t[(beat // 2) % 3 + 1] + 24, 0.25, true)
	end
	step += 1
end

local function startSoundtrack()
	local eighth = 60 / RanchAudio.TEMPO / 2
	nextStepAt = os.clock() + 0.5
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextStepAt then
			return
		end
		-- if we fell far behind (window dragged), skip ahead instead of machine-gunning notes
		if now - nextStepAt > 0.5 then
			nextStepAt = now
		end
		nextStepAt += eighth
		if musicOn then
			playStep()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Loops and ducking
---------------------------------------------------------------------------------------------------
local function loop(name: string, sample: string, speed: number, volume: number)
	local s = loops[name]
	if not s then
		s = makeSound(sample, sfxGroup)
		s.Looped = true
		loops[name] = s
	end
	s.PlaybackSpeed = speed
	if not s.IsPlaying then
		s.Volume = 0
		s:Play()
	end
	TweenService:Create(s, TweenInfo.new(0.8), { Volume = volume }):Play()
end

local function stopLoop(name: string)
	local s = loops[name]
	if s and s.IsPlaying then
		local fade = TweenService:Create(s, TweenInfo.new(1.2), { Volume = 0 })
		fade:Play()
		fade.Completed:Once(function()
			if s.Volume < 0.01 then
				s:Stop()
			end
		end)
	end
end

local function duck(on: boolean)
	if on == ducked then
		return
	end
	ducked = on
	local target = if not musicOn then 0 elseif on then RanchAudio.MUSIC_VOLUME * 0.22 else RanchAudio.MUSIC_VOLUME
	TweenService:Create(musicGroup, TweenInfo.new(if on then 0.4 else 1.5), { Volume = target }):Play()
end

-- Watches the event calendar: ducks under warnings, rumbles for the stampede, howls for the twister.
local function followEvents()
	local lastSiren = 0
	RunService.Heartbeat:Connect(function()
		local kind = Workspace:GetAttribute("EventKind") or ""
		local phase = Workspace:GetAttribute("EventPhase") or "calm"
		local raid = (game:GetService("Players").LocalPlayer:GetAttribute("RaidEta") or 0) > Workspace:GetServerTimeNow()
		local danger = (phase ~= "calm" and kind ~= "goldenhour") or raid
		duck(danger)
		twinkle = kind == "goldenhour" and phase == "active"
		local now = os.clock()
		if kind == "stampede" and phase == "warning" then
			loop("rumble", "boom", 0.32, 0.35)
			if now - lastSiren > 0.5 then
				lastSiren = now
				local high = math.floor(now * 2) % 2 == 0
				RanchAudio.note("pluck", if high then 12 else 7, 0.55)
				RanchAudio.note("pluck", if high then 0 else -5, 0.4)
			end
		elseif kind == "stampede" and phase == "active" then
			loop("rumble", "boom", 0.42, 0.9)
			if now - lastSiren > 0.11 then
				lastSiren = now
				RanchAudio.note("thud", math.random(-6, -2), 0.7)
			end
		else
			stopLoop("rumble")
		end
		if kind == "dustdevil" and phase ~= "calm" then
			local wobble = 0.55 + math.sin(now * 1.3) * 0.08 + (if phase == "active" then 0.12 else 0)
			loop("wind", "wind", wobble, if phase == "active" then 1 else 0.55)
		else
			stopLoop("wind")
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Cues from the server
---------------------------------------------------------------------------------------------------
local lastRare = 0
local CUES: { [string]: (any) -> () } = {}

CUES.welcome = function()
	phrase(arpeggio({ 0, 4, 7, 4, 12 }, 0.11, 0.5))
end
CUES.lasso = function(data)
	local rank = if type(data) == "table" then data.rank or 1 else 1
	phrase(join({ { 0, "whoosh", -2, 0.7 } }, arpeggio({ 0, 4, 7, 12 }, 0.06, 0.45, 0.05)))
	if rank >= 4 then
		phrase(arpeggio({ 16, 19, 24 }, 0.06, 0.4, 0.3))
	end
	if type(data) == "table" and data.mutation then
		RanchAudio.mutationSparkle()
	end
	if type(data) == "table" and data.fresh then
		phrase(arpeggio({ 12, 16, 19, 24, 28 }, 0.05, 0.3, 0.55))
	end
end
CUES.land = function(rank)
	phrase({ { 0, "thud", -4, 0.9 }, { 0.02, "pluck", 12, 0.35 }, { 0.12, "pluck", 19, 0.3 } })
	if type(rank) == "number" and rank >= 5 then
		phrase({ { 0, "boom", 8, 0.35 } })
	end
end
CUES.cash = function()
	phrase({ { 0, "pluck", 24, 0.1 }, { 0.05, "pluck", 28, 0.08 } })
end
CUES.coin = function()
	phrase(arpeggio({ 19, 24, 31 }, 0.045, 0.45))
end
CUES.lock = function()
	phrase({ { 0, "thud", -8, 1 }, { 0.09, "thud", -2, 0.8 }, { 0.12, "pluck", -5, 0.5 }, { 0.2, "pluck", 0, 0.5 } })
end
CUES.lockHeld = function()
	phrase(join({ { 0, "thud", -6, 0.9 } }, arpeggio({ 0, 7, 12 }, 0.1, 0.45, 0.05)))
end
CUES.rustle = function()
	phrase(join({ { 0, "whoosh", -5, 0.7 } }, arpeggio({ -12, -11, -8, -12 }, 0.09, 0.45, 0.05)))
end
CUES.alarm = function()
	phrase(arpeggio({ 12, 7, 12, 7, 12, 7 }, 0.12, 0.5))
end
CUES.delivered = function()
	phrase(join({ { 0, "thud", -4, 0.8 } }, arpeggio({ 0, 4, 7, 12, 16 }, 0.07, 0.5)))
end
CUES.rebirth = function()
	phrase(join({ { 0, "boom", -3, 0.6 } }, arpeggio({ -12, -5, 0, 4, 7, 12, 16, 19, 24 }, 0.07, 0.5)))
	task.delay(0.7, function()
		for _, n in { 12, 16, 19, 24 } do
			RanchAudio.note("pluck", n, 0.4)
		end
		RanchAudio.mutationSparkle()
	end)
end
-- The rustler's whistle: a fast slide up and a falling tail, "fweee-oo".
CUES.whistle = function()
	local steps = {}
	for i = 0, 12 do
		table.insert(steps, { i * 0.022, "pluck", 12 + i, 0.32 })
	end
	for i = 0, 7 do
		table.insert(steps, { 0.4 + i * 0.03, "pluck", 24 - i, 0.3 })
	end
	phrase(steps)
end
CUES.tag = function()
	phrase(join({ { 0, "thud", -6, 1 }, { 0, "oof", 4, 0.6 } }, arpeggio({ 0, 7, 12, 19 }, 0.08, 0.5, 0.08)))
end
-- The fail sting: a sad "wah-wah-wah-waaah" (repeated notes so the last one hangs).
local function sadTrombone(start: number)
	local steps = {}
	for i, n in { 4, 3, 2 } do
		table.insert(steps, { start + (i - 1) * 0.32, "pluck", n - 12, 0.6 })
	end
	for i = 0, 9 do
		table.insert(steps, { start + 0.96 + i * 0.06, "pluck", 1 - 12 - (i % 2) * 0.4, 0.5 - i * 0.03 })
	end
	phrase(steps)
end
CUES.trampled = function()
	phrase({ { 0, "oof", 0, 0.9 }, { 0, "thud", -10, 1 } })
	sadTrombone(0.25)
end
CUES.fail = function()
	sadTrombone(0)
end
CUES.deny = function()
	phrase({ { 0, "pluck", -12, 0.45 }, { 0, "pluck", -11, 0.45 }, { 0.09, "pluck", -12, 0.35 }, { 0.09, "pluck", -11, 0.35 } })
end
CUES.stampedeWarn = function()
	phrase({ { 0, "boom", -8, 0.8 } })
end
CUES.stampede = function()
	phrase({ { 0, "boom", -4, 1 }, { 0.3, "boom", -7, 0.8 } })
end
CUES.goldenWarn = function()
	phrase(join(arpeggio({ 0, 4, 7, 12, 16, 19, 24 }, 0.07, 0.35), arpeggio({ 7, 12, 16, 19, 24, 28, 31 }, 0.07, 0.3, 0.7)))
end
CUES.golden = function()
	phrase(join({ { 0, "pluck", -24, 0.8 }, { 0, "pluck", -12, 0.7 } }, arpeggio({ 0, 4, 7, 12, 16, 19, 24, 28 }, 0.05, 0.45)))
	RanchAudio.mutationSparkle()
end
CUES.dustWarn = function()
	phrase(join({ { 0, "boom", -12, 0.5 } }, arpeggio({ 1, 0, -1, 0, 1, 0 }, 0.18, 0.3)))
end
CUES.dustDevil = function()
	phrase({ { 0, "whoosh", -10, 0.9 }, { 0.15, "whoosh", -12, 0.8 } })
end
CUES.allClear = function()
	phrase(arpeggio({ 0, 4, 7 }, 0.12, 0.35))
end
CUES.contract = function()
	phrase(join({ { 0, "thud", -4, 0.7 } }, arpeggio({ 7, 12, 16, 19 }, 0.08, 0.5), arpeggio({ 24, 28, 31 }, 0.05, 0.35, 0.36)))
end
CUES.guide = function()
	phrase(arpeggio({ 12, 16, 19 }, 0.09, 0.4))
end
CUES.rareOnDrive = function()
	if os.clock() - lastRare > 3 then
		lastRare = os.clock()
		phrase(arpeggio({ 24, 28, 31 }, 0.06, 0.18))
	end
end

-- A quick high glitter: mutations, rebirths, Golden Hour.
function RanchAudio.mutationSparkle()
	local steps = {}
	for i = 0, 9 do
		table.insert(steps, { i * 0.035, "pluck", 24 + ({ 0, 4, 7, 12, 16 })[i % 5 + 1], 0.22 })
	end
	phrase(steps)
end

-- Plays a named cue (unknown names are ignored).
function RanchAudio.play(name: string, data: any?)
	local cue = CUES[name]
	if cue then
		cue(data)
	end
end

-- M toggles the soundtrack (sound effects stay on).
function RanchAudio.toggleMusic(): boolean
	musicOn = not musicOn
	local target = if not musicOn then 0 elseif ducked then RanchAudio.MUSIC_VOLUME * 0.22 else RanchAudio.MUSIC_VOLUME
	TweenService:Create(musicGroup, TweenInfo.new(0.5), { Volume = target }):Play()
	return musicOn
end

-- Builds the sample pools, starts the reel and the event watcher. Call once per client.
function RanchAudio.startRanchAudio()
	musicGroup = makeGroup("RanchMusic", RanchAudio.MUSIC_VOLUME)
	sfxGroup = makeGroup("RanchSfx", RanchAudio.SFX_VOLUME)
	for sample, size in POOL_SIZE do
		local sfx, music = {}, {}
		for _ = 1, size do
			table.insert(sfx, makeSound(sample, sfxGroup))
		end
		if sample == "pluck" or sample == "thud" then
			for _ = 1, size do
				table.insert(music, makeSound(sample, musicGroup))
			end
			pools["m:" .. sample] = music
		end
		pools["s:" .. sample] = sfx
	end
	startSoundtrack()
	followEvents()
end

return RanchAudio
