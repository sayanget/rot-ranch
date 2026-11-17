--!strict
-- Cast: the Rot Ranch menagerie. Twelve original critters on a seven-rung rarity ladder, two
-- mutations, and the money rules every other module reads (price, $/s, rebirth cost, stalls, lock).
local Cast = {}

export type Rarity = { id: string, color: Color3, weight: number, scale: number, rank: number }
export type Critter = {
	id: string, name: string, rarity: string, shape: string,
	income: number, price: number, body: Color3, accent: Color3, quip: string,
}
export type Mutation = { id: string, mult: number, chance: number, tint: Color3? }

Cast.RARITIES = {
	Common = { id = "Common", color = Color3.fromRGB(235, 230, 215), weight = 44, scale = 1.0, rank = 1 },
	Uncommon = { id = "Uncommon", color = Color3.fromRGB(110, 230, 90), weight = 26, scale = 1.1, rank = 2 },
	Rare = { id = "Rare", color = Color3.fromRGB(80, 170, 255), weight = 16, scale = 1.2, rank = 3 },
	Epic = { id = "Epic", color = Color3.fromRGB(190, 100, 255), weight = 8, scale = 1.3, rank = 4 },
	Legendary = { id = "Legendary", color = Color3.fromRGB(255, 200, 40), weight = 4, scale = 1.45, rank = 5 },
	Mythic = { id = "Mythic", color = Color3.fromRGB(255, 70, 120), weight = 1.6, scale = 1.6, rank = 6 },
	RottenGod = { id = "Rotten God", color = Color3.fromRGB(150, 255, 60), weight = 0.4, scale = 1.9, rank = 7 },
} :: { [string]: Rarity }

local C = Color3.fromRGB
Cast.CRITTERS = {
	{ id = "spudmoo", name = "Spudmoo", rarity = "Common", shape = "cow", income = 2, price = 25,
		body = C(176, 132, 82), accent = C(120, 84, 48), quip = "a potato that learned to moo" },
	{ id = "cluckaroni", name = "Cluckaroni", rarity = "Common", shape = "chicken", income = 3, price = 45,
		body = C(255, 206, 84), accent = C(230, 60, 40), quip = "lays elbow macaroni" },
	{ id = "hamwich", name = "Hamwich Hog", rarity = "Uncommon", shape = "pig", income = 9, price = 160,
		body = C(255, 160, 170), accent = C(222, 178, 110), quip = "pig, but a sandwich" },
	{ id = "baagel", name = "Baagel Bleatski", rarity = "Uncommon", shape = "sheep", income = 14, price = 280,
		body = C(214, 160, 92), accent = C(250, 248, 240), quip = "a sheep with a hole in it" },
	{ id = "goatcho", name = "Goatcho Supremo", rarity = "Rare", shape = "goat", income = 35, price = 950,
		body = C(245, 190, 60), accent = C(255, 140, 20), quip = "extra cheese, extra horns" },
	{ id = "toastallion", name = "Toastallion", rarity = "Rare", shape = "horse", income = 55, price = 1600,
		body = C(190, 196, 204), accent = C(200, 130, 60), quip = "gallops at 4 slices/s" },
	{ id = "llamplighter", name = "Llamplighter", rarity = "Epic", shape = "llama", income = 140, price = 5200,
		body = C(240, 228, 200), accent = C(255, 236, 120), quip = "its head is a lamp. why." },
	{ id = "duckwaffle", name = "Duckwaffle Deluxe", rarity = "Epic", shape = "duck", income = 210, price = 8400,
		body = C(255, 225, 70), accent = C(214, 150, 60), quip = "syrup sold separately" },
	{ id = "tractortoise", name = "Tractortoise", rarity = "Legendary", shape = "tortoise", income = 560, price = 26000,
		body = C(70, 150, 70), accent = C(40, 40, 40), quip = "0 to 3 mph in 40 minutes" },
	{ id = "scarecrowbar", name = "Sheriff Scarecrowbar", rarity = "Legendary", shape = "scarecrow", income = 820, price = 42000,
		body = C(200, 170, 110), accent = C(140, 40, 30), quip = "the law west of the hay" },
	{ id = "udderlord", name = "Disco Udderlord", rarity = "Mythic", shape = "disco", income = 2600, price = 160000,
		body = C(120, 70, 220), accent = C(255, 120, 230), quip = "milks the dance floor" },
	{ id = "rotfather", name = "The Grand Rotfather", rarity = "RottenGod", shape = "bull", income = 11000, price = 800000,
		body = C(60, 46, 40), accent = C(140, 255, 60), quip = "makes you an offer you can't refuse" },
} :: { Critter }

Cast.MUTATIONS = {
	{ id = "Golden", mult = 3, chance = 0.05, tint = C(255, 205, 50) },
	{ id = "Moldy", mult = 2, chance = 0.11, tint = C(120, 190, 70) },
} :: { Mutation }

Cast.START_CASH = 100
Cast.BASE_STALLS = 6
Cast.MAX_STALLS = 10

local byId: { [string]: Critter } = {}
for _, critter in Cast.CRITTERS do
	byId[critter.id] = critter
end

-- Rolls the next critter for the Cattle Drive; luck (rebirths) shifts weight toward the rarer rungs.
function Cast.rollDriveCritter(rng: Random, luck: number): (Critter, string?)
	local total = 0
	local weights = {}
	for i, critter in Cast.CRITTERS do
		local rarity = Cast.RARITIES[critter.rarity]
		local w = rarity.weight * (1 + luck * 0.25 * (rarity.rank - 1))
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
	local roll = rng:NextNumber()
	for _, mutation in Cast.MUTATIONS do
		if roll < mutation.chance then
			return chosen, mutation.id
		end
		roll -= mutation.chance
	end
	return chosen, nil
end

function Cast.critterById(id: string): Critter
	return byId[id]
end

function Cast.mutationMult(mutation: string?): number
	for _, m in Cast.MUTATIONS do
		if m.id == mutation then
			return m.mult
		end
	end
	return 1
end

function Cast.mutationTint(mutation: string?): Color3?
	for _, m in Cast.MUTATIONS do
		if m.id == mutation then
			return m.tint
		end
	end
	return nil
end

-- Money a second one critter earns in a pen, after its mutation and its rancher's rebirths.
function Cast.incomeOf(id: string, mutation: string?, rebirths: number): number
	return math.floor(byId[id].income * Cast.mutationMult(mutation) * Cast.rebirthMultiplier(rebirths))
end

-- What the lasso costs on the Cattle Drive.
function Cast.priceOf(id: string, mutation: string?): number
	return byId[id].price * Cast.mutationMult(mutation)
end

function Cast.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * 0.5
end

function Cast.rebirthCost(rebirths: number): number
	return 25000 * 4 ^ rebirths
end

function Cast.stallsFor(rebirths: number): number
	return math.min(Cast.MAX_STALLS, Cast.BASE_STALLS + rebirths * 2)
end

function Cast.lockSeconds(rebirths: number): number
	return 40 + rebirths * 10
end

function Cast.rarityColor(rarityKey: string): Color3
	return Cast.RARITIES[rarityKey].color
end

function Cast.rarityLabel(rarityKey: string): string
	return Cast.RARITIES[rarityKey].id
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
