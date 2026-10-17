-- BrainrotService.luau
-- Server-authoritative Brainrot collection, leveling, and damage calculation.
-- Each Brainrot levels independently: leveling one does NOT level the others.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Brainrot = require(ReplicatedStorage.Shared.Brainrot)

local BrainrotService = {}

local Data -- injected via start

local function getStarterBrainrotId(): string
	-- The starter is the first Common Brainrot (Toxic Titan).
	for _, b in ipairs(Config.Brainrots) do
		if b.rarity == "Common" then
			return b.id
		end
	end
	return Config.Brainrots[1].id
end

function BrainrotService.start(dataService)
	Data = dataService
end

-- Public API (called by CombatService / other systems).

-- Get the damage the equipped Brainrot deals, including equipped pet bonuses.
function BrainrotService.getEquippedDamage(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 0
	end
	local equippedId = profile.equippedBrainrot
	if not equippedId then
		equippedId = getStarterBrainrotId()
	end
	local entry = profile.brainrots and profile.brainrots[equippedId]
	if not entry or not entry.owned then
		return Config.Brainrots[1].baseDamage -- fallback starter base damage
	end
	local config = Brainrot.getConfig(equippedId)
	if not config then
		return 0
	end
	-- Sum equipped pet damage bonuses.
	local petDamageBonus = 0
	local equippedPets = profile.equippedPets or {}
	for petId, equipped in pairs(equippedPets) do
		if equipped then
			local petConfig = Config.Pets and Config.Pets[1] -- placeholder lookup below
			-- Find the pet config by id.
			for _, p in ipairs(Config.Pets) do
				if p.id == petId then
					petDamageBonus += p.damageBonus or 0
					break
				end
			end
		end
	end
	return Brainrot.totalDamage(config, entry.level, petDamageBonus)
end

-- Get the equipped Brainrot info for UI.
function BrainrotService.getEquippedBrainrotInfo(player: Player): { [string]: any }?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	local equippedId = profile.equippedBrainrot or getStarterBrainrotId()
	local entry = profile.brainrots and profile.brainrots[equippedId]
	local config = Brainrot.getConfig(equippedId)
	if not config then
		return nil
	end
	local level = entry and entry.level or 1
	local xp = entry and entry.xp or 0
	local xpNeeded = Brainrot.xpForNextLevel(config, level)
	return {
		id = equippedId,
		name = config.name,
		rarity = config.rarity,
		level = level,
		xp = xp,
		xpNeeded = xpNeeded,
		damage = BrainrotService.getEquippedDamage(player),
		owned = entry and entry.owned or false,
		emoji = config.emoji,
		color = Brainrot.rarityColor(config.rarity),
		description = config.description,
	}
end

-- Award XP to a specific Brainrot (only the equipped one by default).
-- Handles level-ups independently per Brainrot.
function BrainrotService.addXpToEquipped(player: Player, xpAmount: number): { [string]: any }?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	local equippedId = profile.equippedBrainrot or getStarterBrainrotId()
	return BrainrotService.addXp(player, equippedId, xpAmount)
end

function BrainrotService.addXp(player: Player, brainrotId: string, xpAmount: number): { [string]: any }?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	local entry = profile.brainrots and profile.brainrots[brainrotId]
	if not entry or not entry.owned then
		return nil
	end
	local config = Brainrot.getConfig(brainrotId)
	if not config then
		return nil
	end

	entry.xp += xpAmount

	-- Level up as many times as XP allows (independent per Brainrot).
	local leveledUp = false
	local level = entry.level or 1
	while true do
		local needed = Brainrot.xpForNextLevel(config, level)
		if entry.xp >= needed then
			entry.xp -= needed
			level += 1
			entry.level = level
			leveledUp = true
		else
			break
		end
	end

	Data.setBrainrotLevel(player, brainrotId, level, entry.xp)

	if leveledUp then
		return {
			brainrotId = brainrotId,
			level = level,
			xp = entry.xp,
			leveledUp = true,
			damage = BrainrotService.getEquippedDamage(player),
		}
	end
	return {
		brainrotId = brainrotId,
		level = level,
		xp = entry.xp,
		leveledUp = false,
		damage = BrainrotService.getEquippedDamage(player),
	}
end

return BrainrotService
