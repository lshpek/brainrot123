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

-- ============================== FART JUMP (signature ability) =============
-- Server-authoritative burst jump. Strength (power) scales the impulse with
-- diminishing returns up to a hard cap, so upgrades feel meaningful but never
-- become unbounded. All values are tunable here; the server recomputes from
-- the player's real power and ignores any client-supplied velocity.
Config.FartJump = {
	enabled = true,
	cooldown = 1.6, -- seconds between jumps (server-enforced)
	baseImpulse = 55, -- upward impulse at strength 0
	maxImpulse = 140, -- hard cap on vertical impulse (asymptotic)
	scaleK = 2500, -- soft-cap parameter: at power=scaleK, impulse is ~50% of max delta
	maxForwardImpulse = 70, -- hard cap on horizontal impulse
	forwardFactor = 0.8, -- horizontal impulse relative to upward
	groundedOnly = true, -- must be on the ground to launch
	cooldownAttribute = "FartJumpReadyAt", -- os.clock() timestamp, client-side hint only
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

-- ============================== ZONES / WORLD GEOMETRY ==============================
-- Zones are the five regions, laid out west-to-east by MapBuilder. Standing on a
-- zone's floor multiplies your training punches, but only if you meet the power
-- requirement (validated server-side so walking through a gate exploit gains nothing).
-- These values are the single source of truth for zone geometry properties;
-- WorldLayouts provides the world IDs and positions.
Config.Zones = {
	{
		name = "Settlement",
		worldId = "settlement",
		powerRequired = 0,
		multiplier = 1,
		floorColor = Color3.fromRGB(238, 214, 160),
		accentColor = Color3.fromRGB(60, 170, 90),
		floorMaterial = Enum.Material.Sand,
	},
	{
		name = "Village",
		worldId = "village",
		powerRequired = 0,
		multiplier = 1,
		floorColor = Color3.fromRGB(140, 180, 100),
		accentColor = Color3.fromRGB(90, 150, 60),
		floorMaterial = Enum.Material.Grass,
	},
	{
		name = "City",
		worldId = "city",
		powerRequired = 5_000,
		multiplier = 3,
		floorColor = Color3.fromRGB(112, 112, 118),
		accentColor = Color3.fromRGB(80, 140, 210),
		floorMaterial = Enum.Material.Concrete,
	},
	{
		name = "Megacity",
		worldId = "megacity",
		powerRequired = 50_000,
		multiplier = 8,
		floorColor = Color3.fromRGB(60, 60, 80),
		accentColor = Color3.fromRGB(120, 60, 220),
		floorMaterial = Enum.Material.Slate,
	},
	{
		name = "Space City",
		worldId = "space_city",
		powerRequired = 500_000,
		multiplier = 20,
		floorColor = Color3.fromRGB(42, 38, 62),
		accentColor = Color3.fromRGB(90, 220, 255),
		floorMaterial = Enum.Material.Slate,
	},
}

-- The VIP island hangs off the Settlement and requires the VIP gamepass instead of power.
Config.VipZone = {
	name = "VIP Island",
	worldId = "vip_island",
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
		role = "Balanced",
		roleDamageBonus = 0.00,
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
		role = "Combo",
		roleDamageBonus = 0.10,
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
		role = "Area",
		roleDamageBonus = 0.00,
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
		role = "Heavy",
		roleDamageBonus = 0.25,
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
		role = "Tank",
		roleDamageBonus = 0.00,
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
		role = "Support",
		roleDamageBonus = 0.00,
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

-- ============================== SKINS (COSMETICS) ==============================
-- Skins visibly change a Brainrot's appearance (color / material / effect).
-- A skin is tied to a specific Brainrot id. Ownership and equipped state are
-- server-owned; rarity labels are presentation only, never a security boundary.
-- Visual model integration is pending real asset import (docs/ASSET_MANIFEST.md).

Config.Skins = {
	{
		id = "toxic_titan_default",
		name = "Standard",
		brainrotId = "toxic_titan",
		rarity = "Common",
		color = Color3.fromRGB(160, 160, 160),
		material = Enum.Material.Plastic,
		ownedByDefault = true,
		description = "The classic Toxic Titan look.",
	},
	{
		id = "toxic_titan_neo",
		name = "Neon Sludge",
		brainrotId = "toxic_titan",
		rarity = "Rare",
		color = Color3.fromRGB(0, 255, 120),
		material = Enum.Material.Neon,
		ownedByDefault = false,
		description = "Glowing green variant.",
	},
	{
		id = "skibidi_slayer_default",
		name = "Standard",
		brainrotId = "skibidi_slayer",
		rarity = "Common",
		color = Color3.fromRGB(60, 130, 255),
		material = Enum.Material.Plastic,
		ownedByDefault = true,
		description = "Classic Skibidi Slayer.",
	},
	{
		id = "sigma_smasher_default",
		name = "Standard",
		brainrotId = "sigma_smasher",
		rarity = "Common",
		color = Color3.fromRGB(255, 215, 0),
		material = Enum.Material.Plastic,
		ownedByDefault = true,
		description = "Classic Sigma Smasher.",
	},
	{
		id = "meme_mogul_gold",
		name = "Gold Plated",
		brainrotId = "meme_mogul",
		rarity = "Epic",
		color = Color3.fromRGB(255, 215, 0),
		material = Enum.Material.Metal,
		ownedByDefault = false,
		description = "Gilded Meme Mogul.",
	},
}

Config.SkinById = {}
for _, s in ipairs(Config.Skins) do
	Config.SkinById[s.id] = s
end
-- Index skins by brainrotId for the collection UI.
Config.SkinsByBrainrot = {}
for _, s in ipairs(Config.Skins) do
	if not Config.SkinsByBrainrot[s.brainrotId] then
		Config.SkinsByBrainrot[s.brainrotId] = {}
	end
	table.insert(Config.SkinsByBrainrot[s.brainrotId], s)
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
		hatchChance = 3,
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
if basicChance ~= 100 then
	warn("[Config] Pet hatch chances do not total 100%: " .. basicChance)
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

-- Validate egg definitions.
for _, egg in ipairs(Config.Eggs) do
	for _, petId in ipairs(egg.petIds) do
		local found = false
		for _, pet in ipairs(Config.Pets) do
			if pet.id == petId then
				found = true
				break
			end
		end
		if not found then
			warn("[Config] Egg '" .. tostring(egg.id) .. "' references unknown pet: " .. tostring(petId))
		end
	end
	if type(egg.cost) ~= "number" or egg.cost < 0 then
		warn("[Config] Egg '" .. tostring(egg.id) .. "' has invalid cost")
	end
end

-- Pet bonus caps (prevent infinite stacking).
Config.PetBonusCaps = {
	damage = 3.0, -- max 300% damage bonus
	coins = 2.0, -- max 200% coin bonus
	xp = 2.0, -- max 200% XP bonus
}

Config.MaxEquippedPets = 3

-- ============================== COMBAT ==============================
Config.Combat = {
	attackCooldown = 0.6, -- seconds between attacks
	attackRange = 24, -- studs, max distance to hit a building
	maxAttackRange = 24, -- hard cap to prevent exploit range extension
	xpPerCoinReward = 0.1, -- bonus XP from coin rewards
}

-- ============================== ZONE BUILDINGS ==============================
-- Building pools per world ID. Used by BuildingService.spawnWorldBuildings.
Config.ZoneBuildings = {
	["settlement"] = { "mailbox", "fence", "shack", "house" },
	["village"] = { "shack", "house", "fence" },
	["city"] = { "house", "town_hall", "shack" },
	["megacity"] = { "town_hall", "house" },
	["space_city"] = { "town_hall" },
}

-- ============================== QUESTS ==============================
Config.Quests = {
	{
		id = "first_hit",
		name = "First Strike",
		description = "Hit a building once.",
		type = "milestone",
		target = 1,
		rewardCoins = 25,
		rewardXp = 5,
		world = "settlement",
	},
	{
		id = "first_destroy",
		name = "Demolition Rookie",
		description = "Destroy your first building.",
		type = "milestone",
		target = 1,
		rewardCoins = 50,
		rewardXp = 10,
		world = "settlement",
	},
	{
		id = "destroy_10",
		name = "Wrecking Crew",
		description = "Destroy 10 buildings.",
		type = "counter",
		eventType = "destroy_building",
		target = 10,
		rewardCoins = 200,
		rewardXp = 40,
		world = "settlement",
	},
	{
		id = "first_fartjump",
		name = "Blast Off",
		description = "Perform your first Fart Jump.",
		type = "milestone",
		target = 1,
		rewardCoins = 30,
		rewardXp = 5,
		world = "settlement",
	},
	{
		id = "first_pet",
		name = "Pet Pal",
		description = "Hatch your first pet.",
		type = "milestone",
		target = 1,
		rewardCoins = 40,
		rewardXp = 8,
		world = "settlement",
	},
	{
		id = "first_rebirth",
		name = "Reborn",
		description = "Complete your first rebirth.",
		type = "milestone",
		target = 1,
		rewardCoins = 500,
		rewardXp = 100,
		world = "settlement",
	},
	{
		id = "reach_power_1k",
		name = "Getting Strong",
		description = "Reach 1,000 power.",
		type = "threshold",
		stat = "power",
		target = 1000,
		rewardCoins = 100,
		rewardXp = 20,
		world = "settlement",
	},
	{
		id = "equip_rare_brainrot",
		name = "Brainrot Collector",
		description = "Equip a Rare or better Brainrot.",
		type = "milestone",
		target = 1,
		rewardCoins = 75,
		rewardXp = 15,
		world = "settlement",
	},
}
Config.QuestById = {}
for i, q in ipairs(Config.Quests) do
	Config.QuestById[q.id] = i
end

-- ============================== BOSSES ==============================
Config.Bosses = {
	{
		id = "settlement_boss",
		name = "Slime Overlord",
		world = "settlement",
		maxHealth = 5000,
		rewardCoins = 1000,
		rewardXp = 200,
		color = Color3.fromRGB(80, 200, 80),
		size = Vector3.new(8, 10, 8),
		respawnTime = 300,
	},
	{
		id = "village_boss",
		name = "Scarecrow King",
		world = "village",
		maxHealth = 15000,
		rewardCoins = 3000,
		rewardXp = 600,
		color = Color3.fromRGB(180, 140, 60),
		size = Vector3.new(9, 12, 9),
		respawnTime = 300,
	},
	{
		id = "city_boss",
		name = "Traffic Titan",
		world = "city",
		maxHealth = 40000,
		rewardCoins = 8000,
		rewardXp = 1600,
		color = Color3.fromRGB(60, 120, 200),
		size = Vector3.new(10, 14, 10),
		respawnTime = 300,
	},
	{
		id = "megacity_boss",
		name = "Neon Colossus",
		world = "megacity",
		maxHealth = 100000,
		rewardCoins = 20000,
		rewardXp = 4000,
		color = Color3.fromRGB(120, 60, 220),
		size = Vector3.new(12, 16, 12),
		respawnTime = 300,
	},
	{
		id = "space_city_boss",
		name = "Void Leviathan",
		world = "space_city",
		maxHealth = 250000,
		rewardCoins = 50000,
		rewardXp = 10000,
		color = Color3.fromRGB(40, 40, 80),
		size = Vector3.new(14, 18, 14),
		respawnTime = 300,
	},
}
Config.BossById = {}
for i, b in ipairs(Config.Bosses) do
	Config.BossById[b.id] = i
end

-- ============================== WORLDS ==============================
-- Five separate Roblox Places inside one Experience. Place IDs are 0 until
-- real Places are created and configured in the Creator Dashboard.
Config.Worlds = {
	{
		id = "settlement",
		name = "Settlement",
		rebirthRequired = 0,
		placeId = 0,
		description = "Starting world: Spawn Square, Main Street, Residential Block.",
	},
	{
		id = "village",
		name = "Village",
		rebirthRequired = 10,
		placeId = 0,
		description = "Farms, windmill hill, waterway and bridges.",
	},
	{
		id = "city",
		name = "City",
		rebirthRequired = 25,
		placeId = 0,
		description = "Central Plaza, commercial and residential districts.",
	},
	{
		id = "megacity",
		name = "Megacity",
		rebirthRequired = 50,
		placeId = 0,
		description = "Skyline, financial district, elevated transit.",
	},
	{
		id = "space_city",
		name = "Space City",
		rebirthRequired = 100,
		placeId = 0,
		description = "Orbital arrival, gravity research, floating platforms.",
	},
}

Config.WorldById = {}
for i, w in ipairs(Config.Worlds) do
	Config.WorldById[w.id] = i
end

-- ============================== WORLD LAYOUTS ==============================
-- One distinct layout per world. Positions are in studs relative to each
-- world's zone center (X = (index-1) * ZONE_SIZE in MapBuilder). These are
-- code-generated placeholders until real imported models are integrated.
-- Each world keeps its own spawn, boss district, dedicated PvP arena and
-- building distribution so worlds never silently fall back to Settlement.

Config.WorldLayouts = {
	{
		id = "settlement",
		name = "Settlement",
		themeColor = Color3.fromRGB(238, 214, 160),
		themeMaterial = Enum.Material.Sand,
		spawn = Vector3.new(0, 0.5, 52),
		bossPosition = Vector3.new(0, 0, 80),
		bossId = "settlement_boss",
		arenaPosition = Vector3.new(0, 0, -50),
		arenaRadius = 30,
		districts = {
			{ name = "Spawn Square", offset = Vector3.new(0, 0, 40) },
			{ name = "Main Street", offset = Vector3.new(0, 0, 0) },
			{ name = "Residential Block", offset = Vector3.new(-40, 0, 0) },
			{ name = "Construction Yard", offset = Vector3.new(40, 0, 0) },
			{ name = "Park and Rooftop Route", offset = Vector3.new(0, 0, -40) },
			{ name = "Boss District", offset = Vector3.new(0, 0, 80) },
		},
		buildings = { "mailbox", "fence", "shack", "house" },
	},
	{
		id = "village",
		name = "Village",
		themeColor = Color3.fromRGB(140, 180, 100),
		themeMaterial = Enum.Material.Grass,
		spawn = Vector3.new(0, 0.5, 40),
		bossPosition = Vector3.new(0, 0, 80),
		bossId = "village_boss",
		arenaPosition = Vector3.new(0, 0, -50),
		arenaRadius = 30,
		districts = {
			{ name = "Market", offset = Vector3.new(0, 0, 40) },
			{ name = "Farms and Crop Fields", offset = Vector3.new(-50, 0, 0) },
			{ name = "Windmill Hill", offset = Vector3.new(50, 0, -20) },
			{ name = "Waterway and Bridges", offset = Vector3.new(0, 0, -40) },
			{ name = "Barn Boss District", offset = Vector3.new(0, 0, 80) },
		},
		buildings = { "shack", "house", "fence" },
	},
	{
		id = "city",
		name = "City",
		themeColor = Color3.fromRGB(112, 112, 118),
		themeMaterial = Enum.Material.Concrete,
		spawn = Vector3.new(280, 0.5, 40),
		bossPosition = Vector3.new(280, 0, 90),
		bossId = "city_boss",
		arenaPosition = Vector3.new(280, 0, -60),
		arenaRadius = 30,
		districts = {
			{ name = "Central Plaza", offset = Vector3.new(0, 0, 40) },
			{ name = "Commercial District", offset = Vector3.new(-50, 0, 0) },
			{ name = "Residential Towers", offset = Vector3.new(50, 0, 0) },
			{ name = "Parking Complex", offset = Vector3.new(0, 0, -40) },
			{ name = "Construction District", offset = Vector3.new(0, 0, -90) },
			{ name = "Boss District", offset = Vector3.new(0, 0, 90) },
		},
		buildings = { "house", "town_hall", "shack" },
	},
	{
		id = "megacity",
		name = "Megacity",
		themeColor = Color3.fromRGB(60, 60, 80),
		themeMaterial = Enum.Material.Slate,
		spawn = Vector3.new(420, 0.5, 40),
		bossPosition = Vector3.new(420, 0, 100),
		bossId = "megacity_boss",
		arenaPosition = Vector3.new(420, 0, -70),
		arenaRadius = 30,
		districts = {
			{ name = "Central Skyline", offset = Vector3.new(0, 0, 40) },
			{ name = "Financial District", offset = Vector3.new(-60, 0, 0) },
			{ name = "Elevated Transit", offset = Vector3.new(60, 0, -30) },
			{ name = "Energy Infrastructure", offset = Vector3.new(0, 0, -80) },
			{ name = "Entertainment Complex", offset = Vector3.new(60, 0, 40) },
			{ name = "Boss District", offset = Vector3.new(0, 0, 100) },
		},
		buildings = { "town_hall", "house" },
	},
	{
		id = "space_city",
		name = "Space City",
		themeColor = Color3.fromRGB(42, 38, 62),
		themeMaterial = Enum.Material.Slate,
		spawn = Vector3.new(560, 0.5, 40),
		bossPosition = Vector3.new(560, 0, 110),
		bossId = "space_city_boss",
		arenaPosition = Vector3.new(560, 0, -80),
		arenaRadius = 30,
		districts = {
			{ name = "Orbital Arrival", offset = Vector3.new(0, 0, 40) },
			{ name = "Alien Residential District", offset = Vector3.new(-60, 0, 0) },
			{ name = "Gravity Research Facility", offset = Vector3.new(60, 0, -40) },
			{ name = "Floating Platform Network", offset = Vector3.new(0, 0, -100) },
			{ name = "Energy Core District", offset = Vector3.new(0, 0, 110) },
		},
		buildings = { "town_hall" },
	},
}

-- World unlock thresholds (lifetime rebirths) are authoritative on the server.
-- These mirror Config.Worlds.rebirthRequired and are validated by Data.isWorldUnlocked.
Config.WorldUnlockThresholds = {
	settlement = 0,
	village = 10,
	city = 25,
	megacity = 50,
	space_city = 100,
}

-- Map each world layout to its zone region (used by Training zone validation).
Config.WorldZoneIndex = {}
for i, layout in ipairs(Config.WorldLayouts) do
	Config.WorldZoneIndex[layout.id] = i
end

-- Building distribution per world (arena/boss buildings excluded).
Config.WorldBuildings = {}
for _, layout in ipairs(Config.WorldLayouts) do
	Config.WorldBuildings[layout.id] = layout.buildings
end
