-- Brainrot.luau
-- Shared formulas and data helpers for Brainrot characters.
-- Pure functions, no state. Used by server (authority) and client (display).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Brainrot = {}

-- Get the config table for a Brainrot by id.
function Brainrot.getConfig(brainrotId: string): { [string]: any }?
	local index = Config.BrainrotById[brainrotId]
	if not index then
		return nil
	end
	return Config.Brainrots[index]
end

-- Get all Brainrot configs.
function Brainrot.getAll(): { { [string]: any } }
	return Config.Brainrots
end

-- Rarity color for UI.
local RARITY_COLORS = {
	Common = Color3.fromRGB(160, 160, 160),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(60, 130, 255),
	Epic = Color3.fromRGB(160, 60, 255),
	Legendary = Color3.fromRGB(255, 215, 0),
	Mythic = Color3.fromRGB(255, 0, 120),
}

function Brainrot.rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or Color3.fromRGB(160, 160, 160)
end

-- XP required to reach the given level (1-based). Level 1 costs 0 (already owned).
function Brainrot.xpForLevel(config: { [string]: any }, level: number): number
	if level <= 1 then
		return 0
	end
	local total = 0
	local cost = config.xpPerLevel
	for l = 2, level do
		total += cost
		cost = math.floor(cost * config.xpGrowth + 0.5)
	end
	return total
end

-- XP required to go from currentLevel to currentLevel + 1.
function Brainrot.xpForNextLevel(config: { [string]: any }, currentLevel: number): number
	if currentLevel < 1 then
		currentLevel = 1
	end
	local cost = config.xpPerLevel
	for l = 2, currentLevel do
		cost = math.floor(cost * config.xpGrowth + 0.5)
	end
	return cost
end

-- Damage at a given level.
function Brainrot.damageAtLevel(config: { [string]: any }, level: number): number
	if level < 1 then
		level = 1
	end
	return config.baseDamage + (level - 1) * config.damagePerLevel
end

-- Total damage including equipped pet bonuses (bounded by caps).
-- petDamageBonus is the summed pet damage multiplier (e.g. 0.5 = +50%).
function Brainrot.totalDamage(config: { [string]: any }, level: number, petDamageBonus: number): number
	local base = Brainrot.damageAtLevel(config, level)
	local bonus = math.clamp(petDamageBonus, 0, Config.PetBonusCaps.damage)
	return base * (1 + bonus)
end

return Brainrot
