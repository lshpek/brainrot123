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
	local attackRemote = Instance.new("RemoteEvent")
	attackRemote.Name = "Attack"
	attackRemote.Parent = remotes

	attackRemote.OnServerEvent:Connect(function(player, buildingPart)
		if type(buildingPart) ~= "Instance" or not buildingPart:IsA("BasePart") then
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

		if result.destroyed then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "success", `Destroyed {result.buildingId}! +{result.coins} 🪙 +{result.xp} XP`)
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
		if not eggConfig then
			return
		end

		-- Validate cost.
		if not Data.trySpendCoins(player, eggConfig.cost) then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", "Not enough coins to hatch!")
			end
			return
		end

		-- Server determines hatch result (weighted random by hatchChance).
		local roll = Random.new():NextNumber(0, 100)
		local cumulative = 0
		local selectedPet = nil
		for _, petId in ipairs(eggConfig.petIds) do
			local petConfig = nil
			for _, p in ipairs(Config.Pets) do
				if p.id == petId then
					petConfig = p
					break
				end
			end
			if petConfig then
				cumulative += petConfig.hatchChance
				if roll <= cumulative then
					selectedPet = petId
					break
				end
			end
		end

		if selectedPet then
			Data.ownPet(player, selectedPet)
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