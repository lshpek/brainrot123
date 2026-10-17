-- BuildingService.luau
-- Server-authoritative building destruction: health, damage, rewards, respawn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BuildingService = {}

local Data
local BrainrotService

local buildings = {}
local buildingData = {}
local lastAttack = {}

local function getBuildingConfig(buildingId: string): { [string]: any }?
	for _, b in ipairs(Config.Buildings) do
		if b.id == buildingId then
			return b
		end
	end
	return nil
end

function BuildingService.start(dataService, brainrotService)
	Data = dataService
	BrainrotService = brainrotService
end

-- Spawn a single building placeholder part in the given zone folder.
local function spawnBuilding(zoneFolder: Folder, buildingId: string, position: Vector3)
	local config = getBuildingConfig(buildingId)
	if not config then
		warn("[BuildingService] Unknown building id: " .. tostring(buildingId))
		return nil
	end

	local part = Instance.new("Part")
	part.Name = config.name .. " [PLACEHOLDER]"
	part.Size = config.size
	part.CFrame = CFrame.new(position)
	part.Anchored = true
	part.CanCollide = true
	part.Color = config.color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = zoneFolder

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = part
	gui.Size = UDim2.fromOffset(120, 16)
	gui.StudsOffsetWorldSpace = Vector3.new(0, config.size.Y / 2 + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200

	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.fromScale(1, 1)
	barBack.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	barBack.BorderSizePixel = 0
	barBack.Parent = gui

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(120, 16)
	label.Position = UDim2.fromOffset(0, 18)
	label.BackgroundTransparency = 1
	label.Text = config.name
	label.TextColor3 = Color3.fromRGB(240, 243, 250)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = gui

	gui.Parent = part

	local data = {
		configId = buildingId,
		config = config,
		zoneName = zoneFolder.Name,
		maxHealth = config.maxHealth,
		health = config.maxHealth,
		respawnTime = config.respawnTime,
		part = part,
		barFill = barFill,
		label = label,
		dead = false,
		deadUntil = 0,
		lastDamageTime = 0,
	}
	buildings[part] = data
	buildingData[part] = data

	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			buildings[part] = nil
			buildingData[part] = nil
		end
	end)

	return part
end

function BuildingService.getBuildingConfig(buildingId: string): { [string]: any }?
	return getBuildingConfig(buildingId)
end

-- Apply damage stage visuals (color darken / health bar).
local function applyDamageStage(data)
	local healthPct = data.health / data.maxHealth
	local thresholds = data.config.stageThresholds or { 0.66, 0.33 }
	local stage = 0
	for _, t in ipairs(thresholds) do
		if healthPct <= t then
			stage += 1
		end
	end
	local base = data.config.color
	local darkened = Color3.new(
		math.clamp(base.R - stage * 0.15, 0, 1),
		math.clamp(base.G - stage * 0.15, 0, 1),
		math.clamp(base.B - stage * 0.15, 0, 1)
	)
	data.part.Color = darkened
	data.barFill.Size = UDim2.fromScale(math.max(0, healthPct), 1)
end

-- Destroy the building visually and schedule respawn.
local function destroyBuilding(data)
	if data.dead then
		return
	end
	data.dead = true
	data.deadUntil = os.clock() + data.respawnTime
	data.part.CanCollide = false
	data.part.Transparency = 0.8
	data.barFill.Size = UDim2.fromScale(0, 1)
	data.label.Text = data.config.name .. " (destroyed)"

	-- Notify all clients.
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local destroyed = remotes:FindFirstChild("BuildingDestroyed")
		if destroyed then
			for _, player in Players:GetPlayers() do
				destroyed:FireClient(player, data.part)
			end
		end
	end

	task.delay(data.respawnTime, function()
		if not data.part or not data.part.Parent then
			return
		end
		data.dead = false
		data.health = data.maxHealth
		data.part.CanCollide = true
		data.part.Transparency = 0
		data.barFill.Size = UDim2.fromScale(1, 1)
		data.label.Text = data.config.name
		applyDamageStage(data)
	end)
end

-- Deal damage to a building (server-authoritative). Returns result table or nil.
function BuildingService.damageBuilding(player: Player, buildingPart: BasePart, damageAmount: number): { [string]: any }?
	if not buildingPart or not buildingPart.Parent then
		return nil
	end
	local data = buildings[buildingPart]
	if not data then
		return nil
	end
	if data.dead then
		return nil
	end

	-- Cooldown / anti-spam.
	local now = os.clock()
	local last = lastAttack[player] or 0
	if now - last < Config.Combat.attackCooldown then
		return nil
	end
	lastAttack[player] = now

	-- Range validation.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local distance = (root.Position - buildingPart.Position).Magnitude
	if distance > Config.Combat.maxAttackRange then
		return nil
	end

	data.health -= damageAmount
	if data.health < 0 then
		data.health = 0
	end
	applyDamageStage(data)

	if data.health <= 0 then
		-- Reward (server-owned).
		local reward = {
			coins = data.config.rewardCoins,
			xp = data.config.rewardXp,
		}
		local profile = Data.get(player)
		if profile then
			local equippedPets = profile.equippedPets or {}
			local coinBonus = 0
			local xpBonus = 0
			for petId, equipped in pairs(equippedPets) do
				if equipped then
					for _, p in ipairs(Config.Pets) do
						if p.id == petId then
							coinBonus += p.coinsBonus or 0
							xpBonus += p.xpBonus or 0
							break
						end
					end
				end
			end
			coinBonus = math.clamp(coinBonus, 0, Config.PetBonusCaps.coins)
			xpBonus = math.clamp(xpBonus, 0, Config.PetBonusCaps.xp)
			reward.coins = math.floor(reward.coins * (1 + coinBonus) + 0.5)
			reward.xp = math.floor(reward.xp * (1 + xpBonus) + 0.5)
		end

		if profile then
			Data.addCoins(player, reward.coins)
			BrainrotService.addXpToEquipped(player, reward.xp)
		end

		destroyBuilding(data)

		return {
			destroyed = true,
			coins = reward.coins,
			xp = reward.xp,
			buildingId = data.configId,
		}
	end

	return {
		destroyed = false,
		health = data.health,
		maxHealth = data.maxHealth,
		damage = damageAmount,
	}
end

function BuildingService.getBuildingHealth(buildingPart: BasePart): (number?, number?)
	local data = buildings[buildingPart]
	if not data then
		return nil, nil
	end
	return data.health, data.maxHealth
end

function BuildingService.spawnZoneBuildings(zoneName: string, zoneFolder: Folder)
	local buildingIds = Config.ZoneBuildings[zoneName]
	if not buildingIds then
		return
	end
	local center = zoneFolder:FindFirstChild("Floor")
	local origin = center and center.Position or Vector3.new(0, 0, 0)

	local offsets = {
		Vector3.new(-12, 0, -12),
		Vector3.new(12, 0, -12),
		Vector3.new(-12, 0, 12),
		Vector3.new(12, 0, 12),
		Vector3.new(0, 0, 0),
		Vector3.new(-24, 0, 0),
		Vector3.new(24, 0, 0),
	}

	for i, buildingId in ipairs(buildingIds) do
		local offset = offsets[i] or Vector3.new((i - 1) * 14, 0, 0)
		spawnBuilding(zoneFolder, buildingId, origin + offset)
	end
end

return BuildingService