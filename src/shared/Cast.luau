--!strict
-- Cast: the Rot Ranch menagerie and the money rules every other module reads. Twenty-three original
-- critters on a seven-rung rarity ladder, five mutations (Golden, Moldy, Spicy, Crystal, Ghost), and
-- the economy: prices, $/s, rebirth cost, stalls, gate lock time and how luck tilts the Cattle Drive.
local Cast = {}

export type Rarity = { id: string, color: Color3, weight: number, scale: number, rank: number }
export type Critter = {
	id: string, name: string, rarity: string, shape: string,
	income: number, price: number, body: Color3, accent: Color3, quip: string,
}
export type Mutation = { id: string, mult: number, chance: number, tint: Color3, blurb: string }

-- weight is the rung's share of the drive, split evenly between that rung's critters.
Cast.RARITIES = {
	Common = { id = "Common", color = Color3.fromRGB(235, 230, 215), weight = 40, scale = 1.0, rank = 1 },
	Uncommon = { id = "Uncommon", color = Color3.fromRGB(110, 230, 90), weight = 26, scale = 1.1, rank = 2 },
	Rare = { id = "Rare", color = Color3.fromRGB(80, 170, 255), weight = 17, scale = 1.2, rank = 3 },
	Epic = { id = "Epic", color = Color3.fromRGB(190, 100, 255), weight = 9.5, scale = 1.3, rank = 4 },
	Legendary = { id = "Legendary", color = Color3.fromRGB(255, 200, 40), weight = 5, scale = 1.45, rank = 5 },
	Mythic = { id = "Mythic", color = Color3.fromRGB(255, 70, 120), weight = 2, scale = 1.6, rank = 6 },
	RottenGod = { id = "Rotten God", color = Color3.fromRGB(150, 255, 60), weight = 0.5, scale = 1.9, rank = 7 },
} :: { [string]: Rarity }

Cast.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "RottenGod" }

local C = Color3.fromRGB
Cast.CRITTERS = {
	-- Common
	{ id = "spudmoo", name = "Spudmoo", rarity = "Common", shape = "cow", income = 2, price = 25,
		body = C(176, 132, 82), accent = C(120, 84, 48), quip = "a potato that learned to moo" },
	{ id = "cluckaroni", name = "Cluckaroni", rarity = "Common", shape = "chicken", income = 3, price = 45,
		body = C(255, 206, 84), accent = C(230, 60, 40), quip = "lays elbow macaroni" },
	{ id = "tumbleweasel", name = "Tumbleweasel", rarity = "Common", shape = "tumble", income = 4, price = 70,
		body = C(190, 150, 95), accent = C(150, 95, 60), quip = "rolls in, never leaves" },
	-- Uncommon
	{ id = "hamwich", name = "Hamwich Hog", rarity = "Uncommon", shape = "pig", income = 9, price = 160,
		body = C(255, 160, 170), accent = C(222, 178, 110), quip = "pig, but a sandwich" },
	{ id = "baagel", name = "Baagel Bleatski", rarity = "Uncommon", shape = "sheep", income = 14, price = 280,
		body = C(214, 160, 92), accent = C(250, 248, 240), quip = "a sheep with a hole in it" },
	{ id = "beanburro", name = "Beanburro", rarity = "Uncommon", shape = "burro", income = 18, price = 380,
		body = C(236, 214, 160), accent = C(150, 110, 80), quip = "a donkey wrapped to go" },
	{ id = "cactopus", name = "Cactopus Rex", rarity = "Uncommon", shape = "cactopus", income = 24, price = 520,
		body = C(90, 160, 80), accent = C(255, 120, 170), quip = "eight arms, zero hugs" },
	-- Rare
	{ id = "goatcho", name = "Goatcho Supremo", rarity = "Rare", shape = "goat", income = 35, price = 950,
		body = C(245, 190, 60), accent = C(255, 140, 20), quip = "extra cheese, extra horns" },
	{ id = "toastallion", name = "Toastallion", rarity = "Rare", shape = "horse", income = 55, price = 1600,
		body = C(190, 196, 204), accent = C(200, 130, 60), quip = "gallops at 4 slices/s" },
	{ id = "jackalope", name = "Jalapeño Jackalope", rarity = "Rare", shape = "jackalope", income = 70, price = 2100,
		body = C(70, 170, 60), accent = C(140, 95, 55), quip = "antlers rated 9000 scoville" },
	{ id = "wienerbago", name = "Wienerbago", rarity = "Rare", shape = "wiener", income = 90, price = 2900,
		body = C(205, 95, 70), accent = C(240, 200, 130), quip = "a hot dog with a camper on it" },
	-- Epic
	{ id = "llamplighter", name = "Llamplighter", rarity = "Epic", shape = "llama", income = 140, price = 5200,
		body = C(240, 228, 200), accent = C(255, 236, 120), quip = "its head is a lamp. why." },
	{ id = "duckwaffle", name = "Duckwaffle Deluxe", rarity = "Epic", shape = "duck", income = 210, price = 8400,
		body = C(255, 225, 70), accent = C(214, 150, 60), quip = "syrup sold separately" },
	{ id = "banjobuzzard", name = "Banjo Buzzard", rarity = "Epic", shape = "buzzard", income = 260, price = 11000,
		body = C(70, 50, 45), accent = C(230, 200, 150), quip = "only knows one song. it's loud." },
	{ id = "rattlesnack", name = "Rattlesnack", rarity = "Epic", shape = "snake", income = 330, price = 14500,
		body = C(200, 140, 70), accent = C(250, 240, 220), quip = "a pretzel that bites back" },
	-- Legendary
	{ id = "tractortoise", name = "Tractortoise", rarity = "Legendary", shape = "tortoise", income = 560, price = 26000,
		body = C(70, 150, 70), accent = C(40, 40, 40), quip = "0 to 3 mph in 40 minutes" },
	{ id = "scarecrowbar", name = "Sheriff Scarecrowbar", rarity = "Legendary", shape = "scarecrow", income = 820, price = 42000,
		body = C(200, 170, 110), accent = C(140, 40, 30), quip = "the law west of the hay" },
	{ id = "haybalehydra", name = "Haybale Hydra", rarity = "Legendary", shape = "hydra", income = 1100, price = 60000,
		body = C(226, 190, 100), accent = C(110, 160, 60), quip = "three heads, one braincell" },
	-- Mythic
	{ id = "udderlord", name = "Disco Udderlord", rarity = "Mythic", shape = "disco", income = 2600, price = 160000,
		body = C(120, 70, 220), accent = C(255, 120, 230), quip = "milks the dance floor" },
	{ id = "brisketbronco", name = "Brisket Bronco", rarity = "Mythic", shape = "smoker", income = 3400, price = 220000,
		body = C(45, 42, 45), accent = C(255, 120, 40), quip = "low and slow, then very fast" },
	{ id = "moothership", name = "The Moothership", rarity = "Mythic", shape = "saucer", income = 4200, price = 290000,
		body = C(170, 180, 195), accent = C(120, 255, 200), quip = "came for the cows, stayed as one" },
	-- Rotten God
	{ id = "rotfather", name = "The Grand Rotfather", rarity = "RottenGod", shape = "bull", income = 11000, price = 800000,
		body = C(60, 46, 40), accent = C(140, 255, 60), quip = "makes you an offer you can't refuse" },
	{ id = "skelecow", name = "Skelecow Supreme", rarity = "RottenGod", shape = "skelecow", income = 15000, price = 1200000,
		body = C(240, 236, 220), accent = C(170, 80, 255), quip = "died at the rodeo, kept riding" },
} :: { Critter }

-- Mutations, rarest last. chance is per critter rolled onto the drive.
Cast.MUTATIONS = {
	{ id = "Moldy", mult = 2, chance = 0.08, tint = C(120, 190, 70), blurb = "fuzzy and proud" },
	{ id = "Golden", mult = 3, chance = 0.05, tint = C(255, 205, 50), blurb = "solid gold, sparkles" },
	{ id = "Spicy", mult = 4, chance = 0.04, tint = C(255, 90, 40), blurb = "literally on fire" },
	{ id = "Crystal", mult = 6, chance = 0.02, tint = C(140, 225, 255), blurb = "see-through, shines" },
	{ id = "Ghost", mult = 10, chance = 0.01, tint = C(200, 255, 245), blurb = "haunts its own stall" },
} :: { Mutation }

-- Economy: tuned so the first lasso lands in the first minute (Spudmoo $25, you hold $150), a
-- full pen of Rares/Epics is the mid-game goal, and the first rebirth comes after ~10 minutes.
Cast.START_CASH = 150
Cast.BASE_STALLS = 6
Cast.MAX_STALLS = 10
Cast.STAMPEDE_CASH_LOST = 0.12
Cast.DUST_DEVIL_CASH_SPILLED = 0.08

local byId: { [string]: Critter } = {}
local rungSize: { [string]: number } = {}
for _, critter in Cast.CRITTERS do
	byId[critter.id] = critter
	rungSize[critter.rarity] = (rungSize[critter.rarity] or 0) + 1
end
local mutationById: { [string]: Mutation } = {}
for _, m in Cast.MUTATIONS do
	mutationById[m.id] = m
end

-- How likely one critter is to be rolled, before luck: its rung's weight split over the rung.
function Cast.driveWeightOf(critter: Critter, luck: number): number
	local rarity = Cast.RARITIES[critter.rarity]
	return rarity.weight / rungSize[critter.rarity] * (1 + luck * 0.25 * (rarity.rank - 1))
end

-- Rolls a mutation; goldenBoost multiplies the Golden chance (Golden Hour sets it to 4).
function Cast.rollMutation(rng: Random, goldenBoost: number?): string?
	local roll = rng:NextNumber()
	for _, mutation in Cast.MUTATIONS do
		local chance = mutation.chance * (if mutation.id == "Golden" then goldenBoost or 1 else 1)
		if roll < chance then
			return mutation.id
		end
		roll -= chance
	end
	return nil
end

-- Rolls the next critter for the Cattle Drive; luck (rebirths, horseshoes) tilts toward rarer rungs.
function Cast.rollDriveCritter(rng: Random, luck: number, goldenBoost: number?): (Critter, string?)
	local total = 0
	local weights = {}
	for i, critter in Cast.CRITTERS do
		local w = Cast.driveWeightOf(critter, luck)
		weights[i] = w
		total += w
	end
	local pick = rng:NextNumber() * total
	local chosen = Cast.CRITTERS[1]
	for i, w in weights do
		pick -= w
		if pick <= 0 then
			chosen = Cast.CRITTERS[i]
			break
		end
	end
	return chosen, Cast.rollMutation(rng, goldenBoost)
end

function Cast.critterById(id: string): Critter
	return byId[id]
end

function Cast.mutationById(id: string?): Mutation?
	return if id then mutationById[id] else nil
end

function Cast.mutationMult(mutation: string?): number
	local m = Cast.mutationById(mutation)
	return if m then m.mult else 1
end

function Cast.mutationTint(mutation: string?): Color3?
	local m = Cast.mutationById(mutation)
	return if m then m.tint else nil
end

-- Money a second one critter earns in a pen, after its mutation and its rancher's rebirths.
function Cast.incomeOf(id: string, mutation: string?, rebirths: number): number
	return math.floor(byId[id].income * Cast.mutationMult(mutation) * Cast.rebirthMultiplier(rebirths))
end

-- What the lasso costs on the Cattle Drive (a mutation costs its multiplier, less a little).
function Cast.priceOf(id: string, mutation: string?): number
	local mult = Cast.mutationMult(mutation)
	return math.floor(byId[id].price * (if mult > 1 then mult * 0.8 else 1))
end

function Cast.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * 0.5
end

function Cast.rebirthCost(rebirths: number): number
	return 20000 * 4 ^ rebirths
end

function Cast.stallsFor(rebirths: number): number
	return math.min(Cast.MAX_STALLS, Cast.BASE_STALLS + rebirths * 2)
end

function Cast.lockSeconds(rebirths: number): number
	return 45 + rebirths * 10
end

function Cast.rarityColor(rarityKey: string): Color3
	return Cast.RARITIES[rarityKey].color
end

function Cast.rarityLabel(rarityKey: string): string
	return Cast.RARITIES[rarityKey].id
end

function Cast.rankOf(id: string): number
	return Cast.RARITIES[byId[id].rarity].rank
end

-- 1234 -> "$1.2K", 2500000 -> "$2.5M": short enough for a label over a critter's head.
function Cast.formatCash(n: number): string
	local abs = math.abs(n)
	local suffixes = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, s in suffixes do
		if abs >= s[1] then
			local v = n / s[1]
			local text = if v >= 100 then string.format("%d", math.floor(v)) else string.format("%.1f", v)
			return "$" .. (text:gsub("%.0$", "")) .. s[2]
		end
	end
	return "$" .. tostring(math.floor(n))
end

return Cast
