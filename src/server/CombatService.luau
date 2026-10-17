-- CombatService.luau
-- Server-authoritative combat: attack buildings, validate damage, reward + XP.
-- Client sends intent; server recomputes damage from equipped Brainrot + pets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = {}

local Data
local BrainrotService
local BuildingService

-- Track attack remotes per player to prevent duplicate firing.
local lastAttackRequest = {}
local lastEquipRequest = {}

function CombatService.start(dataService, brainrotService, buildingService)
	Data = dataService
	BrainrotService = brainrotService
	BuildingService = buildingService

	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	-- Attack remote: client passes the building part it wants to hit.
	-- Server validates ownership/distance/cooldown and applies damage.
	-- NOTE: The "Attack" RemoteEvent is created exactly once in init.server.luau;
	-- reuse it here so no duplicate remote is introduced.
	local attackRemote = remotes:FindFirstChild("Attack")
	assert(attackRemote, "[CombatService] Missing 'Attack' RemoteEvent (expected from init.server.luau)")

	attackRemote.OnServerEvent:Connect(function(player, buildingPart)
		if typeof(buildingPart) ~= "Instance" or not buildingPart:IsA("BasePart") then
			return
		end

		-- Rate-limit remote requests.
		local now = os.clock()
		local last = lastAttackRequest[player] or 0
		if now - last < Config.Combat.attackCooldown * 0.5 then
			return
		end
		lastAttackRequest[player] = now

		-- Determine damage from equipped Brainrot (+ pet bonuses).
		local damage = BrainrotService.getEquippedDamage(player)
		if damage <= 0 then
			return
		end

		-- Boss target?
		local bossData = nil
		pcall(function()
			bossData = require(script.Parent.BossService).resolve(buildingPart)
		end)
		if bossData then
			local okBoss = false
			pcall(function()
				okBoss = require(script.Parent.BossService).damageBoss(player, buildingPart, damage)
			end)
			if okBoss then
				local attackResult = remotes:FindFirstChild("AttackResult")
				if attackResult then
					attackResult:FireClient(
						player,
						{ destroyed = false, boss = true, health = bossData.health, maxHealth = bossData.maxHealth }
					)
				end
				return
			end
		end

		-- Validate the player is near the building (range checked in damageBuilding too).
		local result = BuildingService.damageBuilding(player, buildingPart, damage)
		if not result then
			-- Attack rejected (out of range, cooldown, or dead building).
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", "Out of range or target invalid.")
			end
			return
		end

		-- Tell the client the outcome.
		local attackResult = remotes:FindFirstChild("AttackResult")
		if attackResult then
			attackResult:FireClient(player, result)
		end

		-- Onboarding milestones: first successful hit, first destruction.
		Data.setMilestone(player, "first_hit")
		pcall(function()
			require(script.Parent.QuestService).completeMilestone(player, "first_hit")
		end)

		if result.destroyed then
			Data.setMilestone(player, "first_destroy")
			pcall(function()
				local QS = require(script.Parent.QuestService)
				QS.completeMilestone(player, "first_destroy")
				QS.onEvent(player, "destroy_building", 1)
			end)
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(
					player,
					"success",
					`Destroyed {result.buildingId}! +{result.coins} 🪙 +{result.xp} XP`
				)
			end
		end
	end)

	-- EquipBrainrot remote: client requests to equip a specific Brainrot.
	local equipBrainrotRemote = remotes:FindFirstChild("EquipBrainrot")
	equipBrainrotRemote.OnServerEvent:Connect(function(player, brainrotId)
		if type(brainrotId) ~= "string" then
			return
		end
		local now = os.clock()
		local last = lastEquipRequest[player] or 0
		if now - last < 0.5 then
			return
		end
		lastEquipRequest[player] = now
		local ok = Data.equipBrainrot(player, brainrotId)
		if not ok then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", "Cannot equip that Brainrot.")
			end
		else
			pcall(function()
				local Config = require(ReplicatedStorage.Shared.Config)
				for _, b in ipairs(Config.Brainrots) do
					if b.id == brainrotId then
						local rarityRank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }
						if (rarityRank[b.rarity] or 0) >= 3 then
							require(script.Parent.QuestService).completeMilestone(player, "equip_rare_brainrot")
						end
					end
				end
			end)
		end
	end)

	-- EquipPet remote.
	local equipPetRemote = remotes:FindFirstChild("EquipPet")
	equipPetRemote.OnServerEvent:Connect(function(player, petId)
		if type(petId) ~= "string" then
			return
		end
		local now = os.clock()
		local last = lastEquipRequest[player] or 0
		if now - last < 0.5 then
			return
		end
		lastEquipRequest[player] = now
		local ok = Data.equipPet(player, petId)
		if not ok then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", "Cannot equip that pet.")
			end
		end
	end)

	-- HatchEgg remote.
	local hatchEggRemote = remotes:FindFirstChild("HatchEgg")
	hatchEggRemote.OnServerEvent:Connect(function(player, eggId)
		if type(eggId) ~= "string" then
			return
		end
		local now = os.clock()
		local last = lastEquipRequest[player] or 0
		if now - last < 1 then
			return
		end
		lastEquipRequest[player] = now

		-- Find the egg config.
		local eggConfig = nil
		for _, e in ipairs(Config.Eggs) do
			if e.id == eggId then
				eggConfig = e
				break
			end
		end
		if not eggConfig or type(eggConfig.petIds) ~= "table" then
			return
		end

		-- Validate every configured pet id exists.
		local validPets = {}
		for _, petId in ipairs(eggConfig.petIds) do
			for _, p in ipairs(Config.Pets) do
				if p.id == petId then
					table.insert(validPets, { id = petId, config = p })
					break
				end
			end
		end
		if #validPets == 0 then
			return
		end

		-- Validate cost.
		if type(eggConfig.cost) ~= "number" or eggConfig.cost < 0 then
			return
		end
		if not Data.trySpendCoins(player, eggConfig.cost) then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", "Not enough coins to hatch!")
			end
			return
		end

		-- Server determines hatch result (weighted random by hatchChance).
		local rng = Random.new()
		local roll = rng:NextNumber(0, 100)
		local cumulative = 0
		local selectedPet = nil
		for _, entry in ipairs(validPets) do
			cumulative += entry.config.hatchChance or 0
			if roll <= cumulative then
				selectedPet = entry.id
				break
			end
		end
		-- Safety: if rounding/precision leaves no selection, pick the last valid pet
		-- so every paid hatch has an explicit outcome (no silent loss).
		if not selectedPet and #validPets > 0 then
			selectedPet = validPets[#validPets].id
		end

		if selectedPet then
			local granted = Data.ownPet(player, selectedPet)
			pcall(function()
				require(script.Parent.QuestService).completeMilestone(player, "first_pet")
			end)
			local petConfig = nil
			for _, p in ipairs(Config.Pets) do
				if p.id == selectedPet then
					petConfig = p
					break
				end
			end
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "success", `Hatched a {petConfig.rarity} {petConfig.name}! {petConfig.emoji}`)
			end
			local hatchResult = remotes:FindFirstChild("HatchResult")
			if hatchResult then
				hatchResult:FireClient(player, selectedPet)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAttackRequest[player] = nil
		lastEquipRequest[player] = nil
	end)
end

return CombatService
