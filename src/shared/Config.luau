-- Config.luau
-- Every tunable number in the game lives here: balance, zones, gear, monetization.
-- Change values here and the whole game (map, shop, formulas, UI) follows.

local Config = {}

Config.GameName = "FART BRAINROT SIMULATOR"

Config.Training = {
	BasePowerPerPunch = 1,
	PunchCooldown = 0.15, -- seconds between punches, enforced server-side
	CoinsPerPowerGained = 0.5, -- every punch also pays out coins at this ratio
	AutoTrainInterval = 0.6, -- punch rate for the Auto Train gamepass
}

Config.Rebirth = {
	BaseCost = 10_000, -- power needed for the first rebirth
	CostGrowth = 3, -- each rebirth costs 3x the previous one
	BonusPerRebirth = 0.5, -- +50% power per punch, permanently, per rebirth
}

-- Gear must be bought in order; your multiplier is the last gear you bought.
Config.Gear = {
	{ name = "Foam Gloves", cost = 100, multiplier = 2, color = Color3.fromRGB(240, 200, 80) },
	{ name = "Leather Gloves", cost = 1_000, multiplier = 5, color = Color3.fromRGB(160, 100, 50) },
	{ name = "Iron Gauntlets", cost = 10_000, multiplier = 12, color = Color3.fromRGB(180, 180, 190) },
	{ name = "Golden Fists", cost = 100_000, multiplier = 30, color = Color3.fromRGB(255, 200, 40) },
	{ name = "Diamond Crushers", cost = 1_000_000, multiplier = 75, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Void Knuckles", cost = 10_000_000, multiplier = 200, color = Color3.fromRGB(140, 60, 220) },
}

-- Zones are laid out west-to-east by MapBuilder. Standing on a zone's training
-- pads multiplies your punches, but only if you meet the power requirement
-- (validated on the server -- walking through a gate exploit gains nothing).
Config.Zones = {
	{
		name = "Beach",
		powerRequired = 0,
		multiplier = 1,
		floorColor = Color3.fromRGB(238, 214, 160),
		accentColor = Color3.fromRGB(60, 170, 90),
		floorMaterial = Enum.Material.Sand,
	},
	{
		name = "City",
		powerRequired = 5_000,
		multiplier = 3,
		floorColor = Color3.fromRGB(112, 112, 118),
		accentColor = Color3.fromRGB(80, 140, 210),
		floorMaterial = Enum.Material.Concrete,
	},
	{
		name = "Volcano",
		powerRequired = 50_000,
		multiplier = 8,
		floorColor = Color3.fromRGB(62, 48, 46),
		accentColor = Color3.fromRGB(255, 100, 30),
		floorMaterial = Enum.Material.Basalt,
	},
	{
		name = "Space",
		powerRequired = 500_000,
		multiplier = 20,
		floorColor = Color3.fromRGB(42, 38, 62),
		accentColor = Color3.fromRGB(90, 220, 255),
		floorMaterial = Enum.Material.Slate,
	},
}

-- The VIP island hangs off the Beach and requires the VIP gamepass instead of power.
Config.VipZone = {
	name = "VIP Island",
	multiplier = 50,
	floorColor = Color3.fromRGB(235, 225, 180),
	accentColor = Color3.fromRGB(255, 215, 0),
	floorMaterial = Enum.Material.Marble,
}

-- ============================== MONETIZATION ==============================
-- Fill these IDs in from the Creator Dashboard after publishing the game
-- (Creator Dashboard -> your experience -> Monetization -> Passes / Developer Products).
-- With an ID of 0 the item is hidden from the shop and the game runs fine without it.

Config.GamePasses = {
	DoublePower = 0, -- suggested price: 199 R$
	DoubleCoins = 0, -- suggested price: 199 R$
	AutoTrain = 0, -- suggested price: 349 R$
	VIP = 0, -- suggested price: 499 R$
}

Config.GamePassInfo = {
	DoublePower = { title = "2x Power", desc = "Every punch gives double power, forever." },
	DoubleCoins = { title = "2x Coins", desc = "Every punch pays out double coins, forever." },
	AutoTrain = { title = "Auto Train", desc = "Hands-free training: punch automatically while you chill." },
	VIP = { title = "VIP Island", desc = "Unlock the exclusive x50 VIP training island." },
}

Config.DevProducts = {
	{ key = "SmallCoins", id = 0, coins = 25_000, label = "25K Coins" }, -- suggested: 49 R$
	{ key = "MediumCoins", id = 0, coins = 150_000, label = "150K Coins" }, -- suggested: 199 R$
	{ key = "LargeCoins", id = 0, coins = 1_000_000, label = "1M Coins" }, -- suggested: 799 R$
}

-- ============================== BRAINROTS ==============================
-- Six initial Brainrots with individual levels, XP, damage, rarity.
-- Each is independent: leveling one does NOT level the others.
-- Placeholder visuals: code-generated parts labeled "[PLACEHOLDER]".

Config.Brainrots = {
	{
		id = "toxic_titan",
		name = "Toxic Titan",
		rarity = "Common",
		baseDamage = 10,
		baseHealth = 100,
		xpPerLevel = 100,
		xpGrowth = 1.5,
		damagePerLevel = 2,
		color = Color3.fromRGB(160, 160, 160),
		emoji = "💨",
		description = "A smelly starter with modest punch power.",
	},
	{
		id = "skibidi_slayer",
		name = "Skibidi Slayer",
		rarity = "Rare",
		baseDamage = 25,
		baseHealth = 140,
		xpPerLevel = 150,
		xpGrowth = 1.55,
		damagePerLevel = 4,
		color = Color3.fromRGB(60, 130, 255),
		emoji = "📺",
		description = "Camera-headed warrior, faster and harder-hitting.",
	},
	{
		id = "grimace_gulp",
		name = "Grimace Gulp",
		rarity = "Epic",
		baseDamage = 50,
		baseHealth = 200,
		xpPerLevel = 250,
		xpGrowth = 1.6,
		damagePerLevel = 7,
		color = Color3.fromRGB(160, 60, 255),
		emoji = "😬",
		description = "Purple powerhouse with devastating area attacks.",
	},
	{
		id = "sigma_smasher",
		name = "Sigma Smasher",
		rarity = "Legendary",
		baseDamage = 90,
		baseHealth = 300,
		xpPerLevel = 400,
		xpGrowth = 1.7,
		damagePerLevel = 12,
		color = Color3.fromRGB(255, 215, 0),
		emoji = "🐺",
		description = "Lone wolf striker, massive single-target damage.",
	},
	{
		id = "giant_giant",
		name = "Giant Giant",
		rarity = "Legendary",
		baseDamage = 120,
		baseHealth = 400,
		xpPerLevel = 500,
		xpGrowth = 1.75,
		damagePerLevel = 15,
		color = Color3.fromRGB(0, 255, 100),
		emoji = "🧟",
		description = "Titan of destruction, slow but unstoppable.",
	},
	{
		id = "meme_mogul",
		name = "Meme Mogul",
		rarity = "Mythic",
		baseDamage = 160,
		baseHealth = 500,
		xpPerLevel = 800,
		xpGrowth = 1.8,
		damagePerLevel = 22,
		color = Color3.fromRGB(255, 0, 120),
		emoji = "🤑",
		description = "The ultimate brainrot. Earns bonus coins too.",
	},
}

-- Map brainrot id -> index for fast lookup.
Config.BrainrotById = {}
for i, b in ipairs(Config.Brainrots) do
	Config.BrainrotById[b.id] = i
end

-- How much XP a destroyed building grants, scaled by zone.
Config.BrainrotXpPerCoin = 0.1 -- 1 coin = 0.1 XP (tunable)

-- ============================== BUILDINGS ==============================
-- Destructible structures. Server owns health, damage, rewards, respawn.
-- Staged destruction: health thresholds where visuals change.
-- Placeholder: simple parts with BillboardGui health bars.

Config.Buildings = {
	{
		id = "mailbox",
		name = "Mailbox",
		maxHealth = 50,
		rewardCoins = 5,
		rewardXp = 1,
		durability = 1, -- relative difficulty tier
		color = Color3.fromRGB(140, 80, 40),
		size = Vector3.new(2, 4, 2),
		stageThresholds = { 0.66, 0.33 }, -- visual damage stages
		respawnTime = 15,
	},
	{
		id = "fence",
		name = "Fence Segment",
		maxHealth = 120,
		rewardCoins = 12,
		rewardXp = 2,
		durability = 1,
		color = Color3.fromRGB(120, 100, 80),
		size = Vector3.new(6, 4, 1),
		stageThresholds = { 0.66, 0.33 },
		respawnTime = 20,
	},
	{
		id = "shack",
		name = "Wooden Shack",
		maxHealth = 500,
		rewardCoins = 50,
		rewardXp = 10,
		durability = 2,
		color = Color3.fromRGB(160, 100, 60),
		size = Vector3.new(10, 8, 10),
		stageThresholds = { 0.7, 0.4 },
		respawnTime = 30,
	},
	{
		id = "house",
		name = "Brick House",
		maxHealth = 1500,
		rewardCoins = 160,
		rewardXp = 30,
		durability = 3,
		color = Color3.fromRGB(180, 90, 70),
		size = Vector3.new(14, 12, 14),
		stageThresholds = { 0.7, 0.4 },
		respawnTime = 45,
	},
	{
		id = "town_hall",
		name = "Town Hall",
		maxHealth = 4000,
		rewardCoins = 450,
		rewardXp = 90,
		durability = 4,
		color = Color3.fromRGB(120, 140, 160),
		size = Vector3.new(22, 18, 22),
		stageThresholds = { 0.7, 0.4 },
		respawnTime = 60,
	},
}

-- ============================== PETS ==============================
-- Independent collection system: eggs, hatching, rarity, bonuses.
-- Max 3 equipped pets per player. Bonuses are bounded.

Config.Pets = {
	{
		id = "meme_dog",
		name = "Meme Dog",
		rarity = "Common",
		hatchChance = 50, -- percent in basic egg
		damageBonus = 0.10,
		coinsBonus = 0.00,
		xpBonus = 0.05,
		color = Color3.fromRGB(160, 160, 160),
		emoji = "🐶",
	},
	{
		id = "cool_cat",
		name = "Cool Cat",
		rarity = "Uncommon",
		hatchChance = 25,
		damageBonus = 0.20,
		coinsBonus = 0.10,
		xpBonus = 0.00,
		color = Color3.fromRGB(100, 140, 255),
		emoji = "😎",
	},
	{
		id = "gold_fish",
		name = "Gold Fish",
		rarity = "Rare",
		hatchChance = 15,
		damageBonus = 0.35,
		coinsBonus = 0.20,
		xpBonus = 0.10,
		color = Color3.fromRGB(255, 215, 0),
		emoji = "🐟",
	},
	{
		id = "dragon_doge",
		name = "Dragon Doge",
		rarity = "Epic",
		hatchChance = 7,
		damageBonus = 0.60,
		coinsBonus = 0.30,
		xpBonus = 0.20,
		color = Color3.fromRGB(160, 60, 255),
		emoji = "🐉",
	},
	{
		id = "void_blob",
		name = "Void Blob",
		rarity = "Legendary",
		hatchChance = 2,
		damageBonus = 1.00,
		coinsBonus = 0.50,
		xpBonus = 0.30,
		color = Color3.fromRGB(60, 60, 100),
		emoji = "🕳️",
	},
}

-- Verify hatch chances sum to <= 100 for basic egg.
local basicChance = 0
for _, pet in ipairs(Config.Pets) do
	basicChance += pet.hatchChance
end
if basicChance > 100 then
	warn("[Config] Pet hatch chances exceed 100%: " .. basicChance)
end

Config.Eggs = {
	{
		id = "basic_egg",
		name = "Basic Egg",
		cost = 100,
		petIds = { "meme_dog", "cool_cat", "gold_fish", "dragon_doge", "void_blob" },
		emoji = "🥚",
		color = Color3.fromRGB(255, 240, 200),
	},
}

-- Max equipped pets per player.
Config.MaxEquippedPets = 3

-- Pet bonus caps (prevent infinite stacking).
Config.PetBonusCaps = {
	damage = 3.0, -- max 300% damage bonus
	coins = 2.0, -- max 200% coin bonus
	xp = 2.0, -- max 200% XP bonus
}

-- ============================== COMBAT ==============================
Config.Combat = {
	attackCooldown = 0.6, -- seconds between attacks
	attackRange = 24, -- studs, max distance to hit a building
	maxAttackRange = 24, -- hard cap to prevent exploit range extension
	xpPerCoinReward = 0.1, -- bonus XP from coin rewards
}

-- ============================== ZONES ==============================
-- Extended with building lists and egg availability per zone.
-- Starting hub is index 1 (Beach). Village is index 2 (City).

Config.ZoneBuildings = {
	["Beach"] = { "mailbox", "fence", "shack" },
	["City"] = { "shack", "house", "town_hall" },
	["Volcano"] = { "house", "town_hall" },
	["Space"] = { "town_hall" },
}

return Config
