-- Brainrot.test.luau
-- Tests for Brainrot XP progression and damage formulas.
-- Lune-compatible: no Roblox globals (no Color3/Vector3).

local Brainrots = {
	{ id = "toxic_titan", name = "Toxic Titan", baseDamage = 10, damagePerLevel = 2, xpPerLevel = 100, xpGrowth = 1.5, rarity = "Common" },
	{ id = "skibidi_slayer", name = "Skibidi Slayer", baseDamage = 25, damagePerLevel = 4, xpPerLevel = 150, xpGrowth = 1.55, rarity = "Rare" },
	{ id = "grimace_gulp", name = "Grimace Gulp", baseDamage = 50, damagePerLevel = 7, xpPerLevel = 250, xpGrowth = 1.6, rarity = "Epic" },
}

local PetBonusCaps = { damage = 3.0 }

-- Color lookup table uses simple RGB tuples instead of Color3 for Lune compatibility.
local RARITY_COLORS = {
	Common = { r = 160, g = 160, b = 160 },
	Uncommon = { r = 100, g = 200, b = 100 },
	Rare = { r = 60, g = 130, b = 255 },
	Epic = { r = 160, g = 60, b = 255 },
	Legendary = { r = 255, g = 215, b = 0 },
	Mythic = { r = 255, g = 0, b = 120 },
}

local function getConfig(brainrotId)
	for _, b in ipairs(Brainrots) do
		if b.id == brainrotId then
			return b
		end
	end
	return nil
end

local function rarityColor(rarity)
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

local function xpForLevel(config, level)
	if level <= 1 then return 0 end
	local total = 0
	local cost = config.xpPerLevel
	for l = 2, level do
		total += cost
		cost = math.floor(cost * config.xpGrowth + 0.5)
	end
	return total
end

local function xpForNextLevel(config, currentLevel)
	if currentLevel < 1 then currentLevel = 1 end
	local cost = config.xpPerLevel
	for l = 2, currentLevel do
		cost = math.floor(cost * config.xpGrowth + 0.5)
	end
	return cost
end

local function damageAtLevel(config, level)
	if level < 1 then level = 1 end
	return config.baseDamage + (level - 1) * config.damagePerLevel
end

local function totalDamage(config, level, petDamageBonus)
	local base = damageAtLevel(config, level)
	local bonus = math.clamp(petDamageBonus, 0, PetBonusCaps.damage)
	return base * (1 + bonus)
end

return {
	{ "Rarity colors are defined for all rarities", function()
		local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
		for _, r in ipairs(rarities) do
			local color = rarityColor(r)
			assert(color.r >= 0 and color.r <= 255, "Invalid R for " .. r)
			assert(color.g >= 0 and color.g <= 255, "Invalid G for " .. r)
			assert(color.b >= 0 and color.b <= 255, "Invalid B for " .. r)
		end
	end },

	{ "Rarity color defaults to Common for unknown", function()
		local color = rarityColor("Unknown")
		assert(color.r == 160, "Expected r=160, got " .. tostring(color.r))
	end },

	{ "XP for level 1 is 0", function()
		local config = getConfig("toxic_titan")
		assert(xpForLevel(config, 1) == 0, "Expected 0 XP at level 1")
	end },

	{ "XP for next level grows with level", function()
		local config = getConfig("toxic_titan")
		local xp1 = xpForNextLevel(config, 1)
		local xp2 = xpForNextLevel(config, 2)
		local xp3 = xpForNextLevel(config, 3)
		assert(xp1 > 0, "Expected positive XP for next level")
		assert(xp2 > xp1, "XP should grow: " .. tostring(xp1) .. " -> " .. tostring(xp2))
		assert(xp3 > xp2, "XP should grow: " .. tostring(xp2) .. " -> " .. tostring(xp3))
	end },

	{ "Damage increases linearly with level", function()
		local config = getConfig("skibidi_slayer")
		local d1 = damageAtLevel(config, 1)
		local d5 = damageAtLevel(config, 5)
		local d10 = damageAtLevel(config, 10)
		assert(d1 == 25, "Level 1 damage should be base: " .. tostring(d1))
		assert(d5 == 109, "Level 5 damage: " .. tostring(d5))
		assert(d10 > d5, "Level 10 damage should be higher")
	end },

	{ "Total damage includes pet bonus", function()
		local config = getConfig("grimace_gulp")
		local base = totalDamage(config, 1, 0)
		local withBonus = totalDamage(config, 1, 0.5)
		assert(base == 50, "Base damage should be 50, got " .. tostring(base))
		assert(withBonus == 75, "With 50% bonus should be 75, got " .. tostring(withBonus))
	end },

	{ "Pet bonus is clamped to cap", function()
		local config = getConfig("toxic_titan")
		local withinCap = totalDamage(config, 1, 0.5)
		local overCap = totalDamage(config, 1, 5.0)
		assert(overCap == withinCap, "Bonus over cap should be clamped")
	end },

	{ "Damage scales with both level and bonus", function()
		local config = getConfig("skibidi_slayer")
		local baseD1 = totalDamage(config, 1, 0)
		local baseD5 = totalDamage(config, 5, 0)
		local bonusD5 = totalDamage(config, 5, 1.0)
		assert(baseD5 > baseD1, "Level 5 should be stronger than level 1")
		assert(bonusD5 > baseD5, "Bonus should increase damage")
	end },
}
