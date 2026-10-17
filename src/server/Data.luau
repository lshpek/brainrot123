-- Data.luau
-- Player data: loading with retries, session cache, leaderstats, autosave,
-- and graceful fallback to in-memory data when DataStores are unavailable
-- (which is normal in unpublished Studio playtests).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local DATASTORE_NAME = "PlayerData_v2"
local AUTOSAVE_INTERVAL = 60
local LOAD_RETRIES = 3

local CURRENT_SCHEMA = 2

local DEFAULT_DATA = {
	version = CURRENT_SCHEMA,
	power = 0,
	coins = 0,
	rebirths = 0,
	gearLevel = 0,
	-- Brainrot collection (independent per character).
	brainrots = {}, -- [brainrotId] = { level, xp, owned, equipped }
	equippedBrainrot = "toxic_titan", -- starter Brainrot id
	-- Pet collection.
	pets = {}, -- [petId] = { owned, equipped }
	equippedPets = {}, -- [petId] = true, max 3
	-- Zone progression.
	zoneUnlocks = { Beach = true }, -- starting hub unlocked by default
}

local Data = {}

local profiles = {} -- [Player] = profile table
local store = nil -- nil when DataStores are unavailable

local function deepCopy(source)
	local copy = {}
	for key, value in source do
		copy[key] = if type(value) == "table" then deepCopy(value) else value
	end
	return copy
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Push the profile into leaderstats (auto-replicates to everyone's player list)
-- and attributes (used by the client UI).
local function sync(player: Player)
	local profile = profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	if not profile or not stats then
		return
	end
	stats.Power.Value = profile.power
	stats.Coins.Value = profile.coins
	stats.Rebirths.Value = profile.rebirths
	player:SetAttribute("GearLevel", profile.gearLevel)
	player:SetAttribute("EquippedBrainrot", profile.equippedBrainrot or "")
end

local function migrateData(data: { [string]: any }): { [string]: any }
	local version = data.version or 0
	if version >= CURRENT_SCHEMA then
		return data
	end
	-- v1 -> v2: add Brainrot, pet, and zone progression fields.
	if version == 1 then
		data.brainrots = {
			toxic_titan = { level = 1, xp = 0, owned = true, equipped = true },
		}
		data.equippedBrainrot = "toxic_titan"
		data.pets = {}
		data.equippedPets = {}
		data.zoneUnlocks = { Beach = true }
		data.version = CURRENT_SCHEMA
	end
	return data
end

local function loadProfile(player: Player)
	local data
	if store then
		for attempt = 1, LOAD_RETRIES do
			local ok, result = pcall(function()
				return store:GetAsync(keyFor(player))
			end)
			if ok then
				data = result
				break
			end
			warn(`[Data] Load attempt {attempt} failed for {player.Name}: {result}`)
			task.wait(2 ^ attempt)
		end
	end
	data = data or deepCopy(DEFAULT_DATA)
	-- Fill in any fields added since this profile was saved.
	for key, value in DEFAULT_DATA do
		if data[key] == nil then
			data[key] = value
		end
	end
	-- Apply schema migration (never replace valid saved progress with defaults).
	data = migrateData(data)
	return data
end

local function saveProfile(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return profile
		end)
	end)
	if not ok then
		warn(`[Data] Save failed for {player.Name}: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	local profile = loadProfile(player)
	if not player.Parent then
		return -- left while loading
	end
	profiles[player] = profile

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, statName in { "Power", "Coins", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Parent = stats
	end
	stats.Parent = player

	sync(player)

	-- Grant starter Brainrot if the player owns none.
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Config = require(ReplicatedStorage.Shared.Config)
	local starterId = nil
	for _, b in ipairs(Config.Brainrots) do
		if b.rarity == "Common" then
			starterId = b.id
			break
		end
	end
	if starterId then
		Data.ownBrainrot(player, starterId)
		if not profile.equippedBrainrot then
			Data.equipBrainrot(player, starterId)
		end
	end
end

-- ============================== PUBLIC API ==============================

function Data.get(player: Player)
	return profiles[player]
end

function Data.addPower(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.power += amount
		sync(player)
	end
end

function Data.addCoins(player: Player, amount: number)
	local profile = profiles[player]
	if profile then
		profile.coins += amount
		sync(player)
	end
end

function Data.trySpendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile or profile.coins < amount then
		return false
	end
	profile.coins -= amount
	sync(player)
	return true
end

function Data.setGearLevel(player: Player, level: number)
	local profile = profiles[player]
	if profile then
		profile.gearLevel = level
		sync(player)
	end
end

-- Reset progress in exchange for a permanent rebirth multiplier.
function Data.applyRebirth(player: Player)
	local profile = profiles[player]
	if profile then
		profile.power = 0
		profile.coins = 0
		profile.gearLevel = 0
		profile.rebirths += 1
		sync(player)
	end
end

-- ============================== BRAINROT DATA API ==============================

function Data.getBrainrot(player: Player, brainrotId: string): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return profile.brainrots[brainrotId]
end

function Data.getEquippedBrainrot(player: Player): string?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return profile.equippedBrainrot
end

function Data.getAllBrainrots(player: Player): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return profile.brainrots
end

-- Ensure a Brainrot entry exists with sane defaults (level 1).
local function ensureBrainrotEntry(profile, brainrotId: string)
	if not profile.brainrots[brainrotId] then
		profile.brainrots[brainrotId] = {
			level = 1,
			xp = 0,
			owned = false,
			equipped = false,
		}
	end
	return profile.brainrots[brainrotId]
end

-- Grant ownership of a Brainrot to a player.
function Data.ownBrainrot(player: Player, brainrotId: string)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local entry = ensureBrainrotEntry(profile, brainrotId)
	if entry.owned then
		return true -- already owned
	end
	entry.owned = true
	entry.level = 1
	entry.xp = 0
	-- Equip it if nothing is equipped yet.
	if not profile.equippedBrainrot then
		profile.equippedBrainrot = brainrotId
		entry.equipped = true
	end
	sync(player)
	return true
end

-- Equip a Brainrot (unequips the previously equipped one).
function Data.equipBrainrot(player: Player, brainrotId: string): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local entry = profile.brainrots[brainrotId]
	if not entry or not entry.owned then
		return false -- don't equip what you don't own
	end
	-- Unequip current.
	local current = profile.equippedBrainrot
	if current then
		local currentEntry = profile.brainrots[current]
		if currentEntry then
			currentEntry.equipped = false
		end
	end
	profile.equippedBrainrot = brainrotId
	entry.equipped = true
	sync(player)
	return true
end

-- Add XP to a specific Brainrot (does NOT affect other Brainrots).
-- Returns true if a level-up occurred.
function Data.addBrainrotXp(player: Player, brainrotId: string, xpAmount: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local entry = ensureBrainrotEntry(profile, brainrotId)
	if not entry.owned then
		return false
	end
	entry.xp += xpAmount
	-- Level-up detection is handled by BrainrotService, which reads config
	-- from the shared Brainrot module. Data only persists raw XP/level.
	return true
end

function Data.setBrainrotLevel(player: Player, brainrotId: string, level: number, xp: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	local entry = ensureBrainrotEntry(profile, brainrotId)
	if not entry.owned then
		return
	end
	entry.level = level
	entry.xp = xp
	sync(player)
end

-- ============================== PET DATA API ==============================

function Data.getPet(player: Player, petId: string): { [string]: any }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return profile.pets[petId]
end

function Data.getEquippedPets(player: Player): { [string]: boolean }?
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return profile.equippedPets
end

function Data.ownPet(player: Player, petId: string)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not profile.pets[petId] then
		profile.pets[petId] = { owned = true, equipped = false }
	else
		profile.pets[petId].owned = true
	end
	return true
end

function Data.equipPet(player: Player, petId: string): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local petEntry = profile.pets[petId]
	if not petEntry or not petEntry.owned then
		return false
	end
	local equipped = profile.equippedPets
	local maxPets = require(game:GetService("ReplicatedStorage").Shared.Config).MaxEquippedPets
	-- Count currently equipped.
	local count = 0
	for _, v in equipped do
		if v then
			count += 1
		end
	end
	if equipped[petId] then
		-- Already equipped: unequip it.
		equipped[petId] = nil
		petEntry.equipped = false
		sync(player)
		return true
	end
	if count >= maxPets then
		return false -- at limit
	end
	equipped[petId] = true
	petEntry.equipped = true
	sync(player)
	return true
end

-- ============================== ZONE DATA API ==============================

function Data.isZoneUnlocked(player: Player, zoneName: string): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	return profile.zoneUnlocks[zoneName] == true
end

function Data.unlockZone(player: Player, zoneName: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.zoneUnlocks[zoneName] = true
	sync(player)
end

function Data.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Data] DataStores unavailable — using in-memory data. "
			.. "This is expected in unpublished Studio playtests.")
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			saveProfile(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				saveProfile(player)
			end
		end
	end)
end

return Data
