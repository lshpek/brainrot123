-- Data.luau
-- Player data: loading with retries, session cache, leaderstats, autosave,
-- and graceful fallback to in-memory data when DataStores are unavailable
-- (which is normal in unpublished Studio playtests).

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = nil
pcall(function()
	Analytics = require(script.Analytics)
end)

local DATASTORE_NAME = "PlayerData_v2"
local AUTOSAVE_INTERVAL = 60
local LOAD_RETRIES = 3

local CURRENT_SCHEMA = 2

-- Distinct profile lifecycle states. An unknown/unloadable profile is NEVER
-- treated as a brand-new player, so we can't save default data over real
-- progress after a failed load.
local STATE_LOADING = "loading"
local STATE_LOADED = "loaded" -- existing or confirmed-new profile, safe to save
local STATE_NEW = "new" -- confirmed no saved profile on first join
local STATE_FAILED = "failed" -- temporary storage failure: do not save
local STATE_UNAVAILABLE = "unavailable" -- DataStores off (local playtest): in-memory only, never persisted

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
	-- First-session onboarding milestones (persisted so the tutorial does not
	-- repeat after rejoin/respawn). Keys are milestone ids.
	milestones = {}, -- [milestoneId] = true
	receipts = {}, -- [PurchaseId] = true (monetization idempotency)
	staffRole = nil, -- server-assigned staff role (owner resolved at runtime)
}

local Data = {}

-- Public accessor for the in-memory profile cache. Returns nil when the
-- profile failed to load or is unavailable, so callers can guard safely.
-- In sandbox mode, returns the isolated sandbox profile instead of the
-- production profile.
function Data.get(player: Player): { [string]: any }?
	if sandboxEnabled[player] then
		return sandboxProfiles[player]
	end
	return profiles[player]
end

-- Public save entry point used by monetization/admin flows.
function Data.save(player: Player): boolean
	return saveProfile(player)
end

-- Sandbox mode: isolate a separate in-memory profile so test actions do not
-- touch production data or persistence. Never saves sandbox state.
function Data.setSandboxMode(player: Player, enabled: boolean)
	if enabled then
		if not sandboxProfiles[player] then
			local base = profiles[player]
			sandboxProfiles[player] = base and deepCopy(base) or deepCopy(DEFAULT_DATA)
		end
		sandboxEnabled[player] = true
	else
		sandboxEnabled[player] = false
		-- discard sandbox copy so next enable starts fresh
		sandboxProfiles[player] = nil
	end
	player:SetAttribute("SandboxMode", enabled == true)
end

function Data.isSandbox(player: Player): boolean
	return sandboxEnabled[player] == true
end
local profiles = {} -- [Player] = profile table
local states = {} -- [Player] = STATE_* (lifecycle; unknown ~= new player)
local loadTokens = {} -- [Player] = token, so stale/replaced sessions can't clobber
local store = nil -- nil when DataStores are unavailable
local dataStoresEnabled = false -- true only when we can actually read/write
local sandboxProfiles = {} -- [Player] = isolated sandbox profile
local sandboxEnabled = {} -- [Player] = boolean

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
	local profile = (sandboxEnabled[player] and sandboxProfiles[player]) or profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	if not profile or not stats then
		return
	end
	stats.Power.Value = profile.power
	stats.Coins.Value = profile.coins
	stats.Rebirths.Value = profile.rebirths
	player:SetAttribute("GearLevel", profile.gearLevel)
	player:SetAttribute("EquippedBrainrot", profile.equippedBrainrot or "")

	-- Replicate pet ownership + equipped set for the client UI. Equipped pets
	-- are a comma-joined list; ownership is a per-pet boolean attribute.
	local equippedList = {}
	if profile.equippedPets then
		for petId, on in pairs(profile.equippedPets) do
			if on then
				table.insert(equippedList, petId)
			end
		end
	end
	player:SetAttribute("EquippedPets", table.concat(equippedList, ","))
	if profile.pets then
		for petId, entry in pairs(profile.pets) do
			player:SetAttribute("PetOwned." .. petId, entry and entry.owned == true)
		end
	end
	-- Replicate Brainrot ownership/equipped state for the client collection UI.
	if profile.brainrots then
		for brainrotId, entry in pairs(profile.brainrots) do
			player:SetAttribute("BrainrotOwned." .. brainrotId, entry and entry.owned == true)
			player:SetAttribute("BrainrotLevel." .. brainrotId, entry and entry.level or 1)
		end
	end
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

-- Load a profile. Returns (data, state, existing):
--   data      : the profile table to use for this session (nil only on failure)
--   state     : STATE_LOADED (saved profile), STATE_NEW (confirmed none), or
--               STATE_FAILED (temporary storage failure -- NOT a new player)
--   existing  : true if a saved profile was actually read from the store
-- A temporary read failure is never converted into default data here, so a
-- later save can't overwrite real progress with a fresh profile.
local function loadProfile(player: Player)
	-- DataStores unavailable (unpublished Studio playtest): run purely in memory
	-- and never mark the profile as persisted.
	if not store then
		return deepCopy(DEFAULT_DATA), STATE_UNAVAILABLE, false
	end

	local data
	local readOk = false
	for attempt = 1, LOAD_RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			readOk = true
			data = result -- may be nil: genuinely a new player
			break
		end
		warn(`[Data] Load attempt {attempt} failed for {player.Name}: {result}`)
		if attempt < LOAD_RETRIES then
			task.wait(2 ^ attempt)
		end
	end

	if not readOk then
		-- Temporary storage failure. Do NOT fabricate a new profile that could
		-- later be saved over the player's real progress.
		return nil, STATE_FAILED, false
	end

	if data == nil then
		-- Confirmed: no saved profile for this key -> brand-new player.
		return deepCopy(DEFAULT_DATA), STATE_NEW, false
	end

	-- Fill in any fields added since this profile was saved.
	for key, value in DEFAULT_DATA do
		if data[key] == nil then
			data[key] = deepCopy(value)
		end
	end
	-- Apply schema migration (never replace valid saved progress with defaults).
	data = migrateData(data)
	return data, STATE_LOADED, true
end

-- Save only when it is safe to do so. Never write when the profile failed to
-- load (that would persist default/unknown data over real progress) or when
-- DataStores are off.
local function saveProfile(player: Player): boolean
	if sandboxEnabled[player] then
		return false -- never persist sandbox state
	end
	local profile = profiles[player]
	local state = states[player]
	if not profile or not store then
		return false
	end
	if state ~= STATE_LOADED and state ~= STATE_NEW then
		-- FAILED / UNAVAILABLE / LOADING: refuse to overwrite stored data.
		return false
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function(old)
			-- Defensive: never clobber a profile that appeared under this key
			-- while we were offline/failed (stale-session protection).
			if old ~= nil and state == STATE_NEW then
				-- A saved profile now exists that we didn't load; keep it.
				return old
			end
			return profile
		end)
	end)
	if not ok then
		warn(`[Data] Save failed for {player.Name}: {err}`)
		return false
	end
	return true
end

local function onPlayerAdded(player: Player)
	-- Guard against a duplicate PlayerAdded for the same player and ensure a
	-- stale session for the same UserId can't leak into the new one.
	if states[player] == STATE_LOADING or states[player] == STATE_LOADED then
		return
	end
	local token = {}
	loadTokens[player] = token
	states[player] = STATE_LOADING

	local profile, state = loadProfile(player)
	if loadTokens[player] ~= token then
		return -- a newer session for this player replaced us
	end
	if not player.Parent then
		-- Left while loading; drop the state so nothing tries to save a
		-- profile that never became active.
		states[player] = nil
		loadTokens[player] = nil
		return
	end

	if state == STATE_FAILED then
		-- Fail safely: tell the player, do NOT grant a live progression
		-- profile that could later be saved over their real data.
		states[player] = STATE_FAILED
		profiles[player] = nil
		player:SetAttribute("DataLoadFailed", true)
		warn(
			`[Data] {player.Name} could not load after {LOAD_RETRIES} attempts; progression disabled this session (no save will occur).`
		)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local notify = remotes and remotes:FindFirstChild("Notify")
		if notify then
			notify:FireClient(
				player,
				"error",
				"Couldn't load your save data. Progress is paused this session to protect it."
			)
		end
		return
	end

	profiles[player] = profile
	states[player] = state -- STATE_LOADED or STATE_NEW (or UNAVAILABLE locally)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, statName in { "Power", "Coins", "Rebirths" } do
		local value = Instance.new("IntValue")
		value.Name = statName
		value.Parent = stats
	end
	stats.Parent = player

	sync(player)

	-- Grant starter Brainrot if the player owns none. (Config is already
	-- required at module scope; use it here instead of re-requiring.)
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

	-- Push persisted onboarding milestones to attributes so the client can
	-- skip already-completed tutorial steps.
	Data.publishMilestones(player)
end

-- ============================== PUBLIC API ==============================

function Data.syncProfile(player: Player)
	sync(player)
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

function Data.ownPet(player: Player, petId: string): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	-- Validate pet id exists in trusted config.
	local valid = false
	for _, p in ipairs(Config.Pets) do
		if p.id == petId then
			valid = true
			break
		end
	end
	if not valid then
		return false
	end
	if not profile.pets[petId] then
		profile.pets[petId] = { owned = true, equipped = false }
	else
		profile.pets[petId].owned = true
	end
	sync(player)
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

-- ============================== MILESTONE API =============================
-- Records a first-session milestone and replicates it to an attribute so the
-- client onboarding UI can advance. Persisted in the profile (milestones) so
-- completed steps never reappear after rejoin/respawn.

function Data.setMilestone(player: Player, milestoneId: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	if not profile.milestones then
		profile.milestones = {}
	end
	if profile.milestones[milestoneId] then
		return -- already recorded
	end
	profile.milestones[milestoneId] = true
	player:SetAttribute("MS." .. milestoneId, true)
	if Analytics then
		Analytics.track(player, milestoneId, 1)
	end
end

function Data.hasMilestone(player: Player, milestoneId: string): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.milestones ~= nil and profile.milestones[milestoneId] == true
end

-- Called once after load to push all persisted milestones to attributes.
function Data.publishMilestones(player: Player)
	local profile = profiles[player]
	if not profile or not profile.milestones then
		return
	end
	for milestoneId in profile.milestones do
		player:SetAttribute("MS." .. milestoneId, true)
	end
end

function Data.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(
			"[Data] DataStores unavailable — using in-memory data. "
				.. "This is expected in unpublished Studio playtests."
		)
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
		states[player] = nil
		loadTokens[player] = nil
		sandboxProfiles[player] = nil
		sandboxEnabled[player] = nil
	end)

	game:BindToClose(function()
		-- Best-effort flush of every safe profile on shutdown. saveProfile
		-- skips FAILED/UNAVAILABLE/LOADING entries, so we never persist
		-- default data over a real save.
		for _, player in Players:GetPlayers() do
			saveProfile(player)
		end
		-- Give UpdateAsync calls a moment to finish before the server dies.
		task.wait(3)
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
