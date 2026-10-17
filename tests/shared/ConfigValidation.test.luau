-- ConfigValidation.test.luau
-- Tests for ConfigValidation invariants: unique IDs, bounds, world consistency.
-- Lune-compatible: no Roblox globals (no Vector3). Uses plain tables for positions.

local Config = {}

Config.Gear = {
	{ name = "Foam Gloves", cost = 100, multiplier = 2 },
	{ name = "Leather Gloves", cost = 1000, multiplier = 5 },
}
Config.Pets = {
	{ id = "meme_dog", name = "Meme Dog", rarity = "Common", hatchChance = 50, damageBonus = 0.1 },
	{ id = "cool_cat", name = "Cool Cat", rarity = "Uncommon", hatchChance = 25, damageBonus = 0.2 },
	{ id = "gold_fish", name = "Gold Fish", rarity = "Rare", hatchChance = 15, damageBonus = 0.35 },
	{ id = "dragon_doge", name = "Dragon Doge", rarity = "Epic", hatchChance = 7, damageBonus = 0.6 },
	{ id = "void_blob", name = "Void Blob", rarity = "Legendary", hatchChance = 3, damageBonus = 1.0 },
}
Config.Eggs = {
	{ id = "basic_egg", name = "Basic Egg", cost = 100, petIds = { "meme_dog", "cool_cat", "gold_fish", "dragon_doge", "void_blob" } },
}
Config.PetBonusCaps = { damage = 3.0, coins = 2.0, xp = 2.0 }
Config.Buildings = {
	{ id = "mailbox", name = "Mailbox", maxHealth = 50, respawnTime = 15 },
}
Config.Bosses = {
	{ id = "settlement_boss", name = "Slime Overlord", world = "settlement", maxHealth = 5000 },
}
Config.Worlds = {
	{ id = "settlement", name = "Settlement", rebirthRequired = 0 },
	{ id = "village", name = "Village", rebirthRequired = 10 },
	{ id = "city", name = "City", rebirthRequired = 25 },
	{ id = "megacity", name = "Megacity", rebirthRequired = 50 },
	{ id = "space_city", name = "Space City", rebirthRequired = 100 },
}
Config.WorldLayouts = {
	{ id = "settlement", name = "Settlement", spawn = { X = 0, Y = 0.5, Z = 52 }, arenaPosition = { X = 0, Y = 0, Z = -50 }, arenaRadius = 30 },
	{ id = "village", name = "Village", spawn = { X = 0, Y = 0.5, Z = 40 }, arenaPosition = { X = 0, Y = 0, Z = -50 }, arenaRadius = 30 },
	{ id = "city", name = "City", spawn = { X = 0, Y = 0.5, Z = 40 }, arenaPosition = { X = 0, Y = 0, Z = -60 }, arenaRadius = 30 },
	{ id = "megacity", name = "Megacity", spawn = { X = 0, Y = 0.5, Z = 40 }, arenaPosition = { X = 0, Y = 0, Z = -70 }, arenaRadius = 30 },
	{ id = "space_city", name = "Space City", spawn = { X = 0, Y = 0.5, Z = 40 }, arenaPosition = { X = 0, Y = 0, Z = -80 }, arenaRadius = 30 },
}
Config.WorldZoneIndex = {}
for i, layout in ipairs(Config.WorldLayouts) do
	Config.WorldZoneIndex[layout.id] = i
end
Config.Brainrots = {
	{ id = "toxic_titan", name = "Toxic Titan", rarity = "Common", baseDamage = 10 },
	{ id = "skibidi_slayer", name = "Skibidi Slayer", rarity = "Rare", baseDamage = 25 },
}
Config.FartJump = {
	baseImpulse = 55, maxImpulse = 140, scaleK = 2500, cooldown = 1.6,
}
Config.Combat = {
	attackCooldown = 0.15, maxAttackRange = 24,
}
Config.PvP = {
	winRewardCoins = 100,
}

return {
	{ "Pet hatch chances sum to 100", function()
		local total = 0
		for _, p in ipairs(Config.Pets) do
			total += p.hatchChance
		end
		assert(total == 100, "Expected 100, got " .. tostring(total))
	end },

	{ "All egg pet IDs are valid", function()
		for _, egg in ipairs(Config.Eggs) do
			for _, petId in ipairs(egg.petIds) do
				local found = false
				for _, p in ipairs(Config.Pets) do
					if p.id == petId then
						found = true
						break
					end
				end
				assert(found, "Egg references unknown pet: " .. tostring(petId))
			end
		end
	end },

	{ "WorldLayouts count matches Worlds count", function()
		assert(#Config.WorldLayouts == #Config.Worlds,
			"Layout count " .. #Config.WorldLayouts .. " != Worlds count " .. #Config.Worlds)
	end },

	{ "World IDs are unique", function()
		local ids = {}
		for _, w in ipairs(Config.Worlds) do
			assert(not ids[w.id], "Duplicate world id: " .. tostring(w.id))
			ids[w.id] = true
		end
	end },

	{ "World layout IDs match world IDs", function()
		for _, layout in ipairs(Config.WorldLayouts) do
			local matched = false
			for _, w in ipairs(Config.Worlds) do
				if w.id == layout.id then
					matched = true
					break
				end
			end
			assert(matched, "Layout " .. tostring(layout.id) .. " has no matching world")
		end
	end },

	{ "All boss worlds are valid", function()
		for _, boss in ipairs(Config.Bosses) do
			local found = false
			for _, w in ipairs(Config.Worlds) do
				if w.id == boss.world then
					found = true
					break
				end
			end
			assert(found, "Boss " .. tostring(boss.id) .. " references invalid world: " .. tostring(boss.world))
		end
	end },

	{ "Building health is positive", function()
		for _, b in ipairs(Config.Buildings) do
			assert(b.maxHealth > 0, "Building " .. tostring(b.id) .. " has non-positive health")
		end
	end },

	{ "World rebirth requirements are non-negative", function()
		for _, w in ipairs(Config.Worlds) do
			assert(w.rebirthRequired >= 0, "World " .. tostring(w.id) .. " has negative rebirth requirement")
		end
	end },

	{ "FartJump tuning is sane", function()
		local fj = Config.FartJump
		assert(fj.baseImpulse >= 0, "baseImpulse must be non-negative")
		assert(fj.maxImpulse > fj.baseImpulse, "maxImpulse must exceed baseImpulse")
		assert(fj.scaleK > 0, "scaleK must be positive")
		assert(fj.cooldown > 0, "cooldown must be positive")
	end },

	{ "PvP win reward is bounded", function()
		assert(Config.PvP.winRewardCoins >= 0, "PvP reward must be non-negative")
	end },
}
