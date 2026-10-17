-- BuildingService.luau
-- Server-authoritative building destruction: health, damage, rewards, respawn.
-- Buildings are rendered as modular multi-part Models (foundation, walls, roof,
-- windows, door) driven by archetype, while a single authoritative registry maps
-- every part (and the Model) back to one health/damage/reward data table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BuildingService = {}

local Data
local BrainrotService

-- Registry: maps every building part AND the building Model -> its data table.
local buildings = {}
local lastAttack = {}
local spawnedZones = {} -- zones that already spawned buildings (prevents duplicates)

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

function BuildingService.getBuildingConfig(buildingId: string): { [string]: any }?
	return getBuildingConfig(buildingId)
end

-- ============================== GEOMETRY HELPERS =============================

local ROOF_COLORS = {
	house = Color3.fromRGB(96, 62, 48),
	shop = Color3.fromRGB(70, 74, 84),
	civic = Color3.fromRGB(58, 66, 82),
	shed = Color3.fromRGB(84, 70, 54),
}
local TRIM_COLOR = Color3.fromRGB(232, 228, 220)
local WINDOW_COLOR = Color3.fromRGB(168, 208, 232)

-- Collidable structural part names; everything else is decorative (non-colliding).
local SOLID_NAMES = {
	Body = true,
	Foundation = true,
	Roof = true,
	RoofSlope = true,
	RoofRidge = true,
	RoofTier = true,
	Steeple = true,
	Chimney = true,
}

local function addPart(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	collide: boolean,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = collide
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if transparency then
		p.Transparency = transparency
	end
	p.CastShadow = collide
	p.Parent = model
	return p
end

-- Detect a building archetype from its config id, defaulting to a house-like
-- structure so unknown ids still build something coherent instead of crashing.
local function archetypeFor(config): string
	local id = string.lower(config.id or "")
	local dur = config.durability or 1
	if id:find("town", 1, true) or id:find("hall", 1, true) or id:find("plaza", 1, true) then
		return "civic"
	elseif id:find("shop", 1, true) or id:find("store", 1, true) or id:find("market", 1, true) then
		return "shop"
	elseif
		id:find("fence", 1, true)
		or id:find("shed", 1, true)
		or id:find("shack", 1, true)
		or id:find("mail", 1, true)
	then
		return "shed"
	elseif dur >= 3 then
		return "shop"
	end
	return "house"
end

-- A recessed window: glass pane seated in a trim frame.
local function addWindow(model: Model, cf: CFrame, w: number, h: number, faceZ: number)
	local trim = addPart(
		model,
		"WindowTrim",
		Vector3.new(w + 0.4, h + 0.4, 0.3),
		cf * CFrame.new(0, 0, -faceZ * 0.15),
		TRIM_COLOR,
		Enum.Material.SmoothPlastic,
		false
	)
	trim.CastShadow = false
	local glass = addPart(model, "Window", Vector3.new(w, h, 0.3), cf, WINDOW_COLOR, Enum.Material.Glass, false, 0.35)
	glass.CastShadow = false
end

-- A recessed doorway: wood door seated in a trim frame.
local function addDoor(model: Model, cf: CFrame, w: number, h: number, faceZ: number)
	addPart(
		model,
		"DoorFrame",
		Vector3.new(w + 0.5, h + 0.5, 0.35),
		cf * CFrame.new(0, 0, -faceZ * 0.15),
		TRIM_COLOR,
		Enum.Material.SmoothPlastic,
		false
	)
	local door =
		addPart(model, "Door", Vector3.new(w, h, 0.3), cf, Color3.fromRGB(116, 74, 46), Enum.Material.Wood, false)
	door.CastShadow = false
end
-- ============================== BUILD STRUCTURE =============================
-- Builds a coherent multi-part building Model from config.size + archetype.
local function buildStructure(zoneFolder: Folder, buildingId: string, position: Vector3)
	local config = getBuildingConfig(buildingId)
	if not config then
		warn("[BuildingService] Unknown building id: " .. tostring(buildingId))
		return nil, nil
	end

	local size = config.size
	local w, h, d = size.X, size.Y, size.Z
	local hw, hh, hd = w / 2, h / 2, d / 2
	local archetype = archetypeFor(config)
	local roofColor = ROOF_COLORS[archetype] or ROOF_COLORS.house

	-- `position` is the ground surface (floor top = y 0 in MapBuilder); build upward.
	local groundY = position.Y

	local model = Instance.new("Model")
	model.Name = config.name
	model.Parent = zoneFolder

	-- Foundation slab.
	addPart(
		model,
		"Foundation",
		Vector3.new(w * 1.14, 0.6, d * 1.14),
		CFrame.new(position + Vector3.new(0, 0.3, 0)),
		Color3.fromRGB(118, 112, 104),
		Enum.Material.Concrete,
		true
	)

	-- Solid walls block: the authoritative hitbox (facade layers onto it).
	local body = addPart(
		model,
		"Body",
		Vector3.new(w, h, d),
		CFrame.new(position + Vector3.new(0, hh + 0.6, 0)),
		config.color,
		Enum.Material.Brick,
		true
	)

	local topY = groundY + 0.6 + h

	-- ================================ ROOF ================================
	if archetype == "house" or archetype == "shed" then
		-- Gabled roof: two slanted slabs meeting at a ridge.
		local pitch = math.rad(archetype == "shed" and 20 or 28)
		local slopeLen = (d / 2) / math.cos(pitch) + 1.5
		local ridgeH = math.tan(pitch) * (d / 2)
		for _, side in { 1, -1 } do
			addPart(
				model,
				"RoofSlope",
				Vector3.new(w * 1.08, 0.6, slopeLen),
				CFrame.new(position + Vector3.new(0, topY + ridgeH / 2 + 0.4, side * d / 4))
					* CFrame.Angles(side * pitch, 0, 0),
				roofColor,
				Enum.Material.Slate,
				true
			)
		end
		addPart(
			model,
			"RoofRidge",
			Vector3.new(w * 1.1, 0.5, 1.0),
			CFrame.new(position + Vector3.new(0, topY + ridgeH + 0.4, 0)),
			Color3.new(roofColor.R * 0.8, roofColor.G * 0.8, roofColor.B * 0.8),
			Enum.Material.Slate,
			false
		)
		if archetype == "house" and w >= 8 then
			addPart(
				model,
				"Chimney",
				Vector3.new(1.6, 3.2, 1.6),
				CFrame.new(position + Vector3.new(hw * 0.5, topY + ridgeH * 0.6 + 1.4, -hd * 0.3)),
				Color3.fromRGB(140, 84, 66),
				Enum.Material.Brick,
				true
			)
		end
	elseif archetype == "shop" then
		-- Flat roof with a parapet and a storefront awning.
		addPart(
			model,
			"Roof",
			Vector3.new(w * 1.06, 0.7, d * 1.06),
			CFrame.new(position + Vector3.new(0, topY + 0.35, 0)),
			roofColor,
			Enum.Material.Concrete,
			true
		)
		local parapetColor = Color3.new(roofColor.R * 0.9, roofColor.G * 0.9, roofColor.B * 0.9)
		addPart(
			model,
			"Parapet",
			Vector3.new(w * 1.06, 1.1, 0.5),
			CFrame.new(position + Vector3.new(0, topY + 1.1, hd * 1.03)),
			parapetColor,
			Enum.Material.SmoothPlastic,
			false
		)
		addPart(
			model,
			"Parapet",
			Vector3.new(w * 1.06, 1.1, 0.5),
			CFrame.new(position + Vector3.new(0, topY + 1.1, -hd * 1.03)),
			parapetColor,
			Enum.Material.SmoothPlastic,
			false
		)
		addPart(
			model,
			"Parapet",
			Vector3.new(0.5, 1.1, d * 1.06),
			CFrame.new(position + Vector3.new(hw * 1.03, topY + 1.1, 0)),
			parapetColor,
			Enum.Material.SmoothPlastic,
			false
		)
		addPart(
			model,
			"Parapet",
			Vector3.new(0.5, 1.1, d * 1.06),
			CFrame.new(position + Vector3.new(-hw * 1.03, topY + 1.1, 0)),
			parapetColor,
			Enum.Material.SmoothPlastic,
			false
		)
		addPart(
			model,
			"Awning",
			Vector3.new(w * 0.7, 0.4, 2.4),
			CFrame.new(position + Vector3.new(0, hh * 1.1 + 0.6, hd + 1.0)),
			config.accentColor or Color3.fromRGB(200, 90, 90),
			Enum.Material.Fabric,
			false
		)
	else -- civic
		-- Tiered flat roof with a steeple block.
		addPart(
			model,
			"Roof",
			Vector3.new(w * 1.04, 0.8, d * 1.04),
			CFrame.new(position + Vector3.new(0, topY + 0.4, 0)),
			roofColor,
			Enum.Material.Slate,
			true
		)
		addPart(
			model,
			"RoofTier",
			Vector3.new(w * 0.7, 1.4, d * 0.7),
			CFrame.new(position + Vector3.new(0, topY + 1.5, 0)),
			Color3.new(roofColor.R * 0.85, roofColor.G * 0.85, roofColor.B * 0.85),
			Enum.Material.Slate,
			false
		)
		addPart(
			model,
			"Steeple",
			Vector3.new(2.4, 4.0, 2.4),
			CFrame.new(position + Vector3.new(0, topY + 4.2, 0)),
			TRIM_COLOR,
			Enum.Material.SmoothPlastic,
			true
		)
		addPart(
			model,
			"SteepleCap",
			Vector3.new(3.0, 0.6, 3.0),
			CFrame.new(position + Vector3.new(0, topY + 6.5, 0)),
			roofColor,
			Enum.Material.Slate,
			false
		)
	end
	-- ============================ FACADE DETAILS ============================
	local doorW = math.min(w * 0.3, 3.2)
	local doorH = math.min(h * 0.55, 5.0)
	addDoor(model, CFrame.new(position + Vector3.new(0, 0.6 + doorH / 2, hd + 0.16)), doorW, doorH, 1)

	local winH = math.min(h * 0.3, 2.6)
	local winW = math.min(w * 0.2, 2.4)
	local winY = 0.6 + h * 0.55
	local columns = math.max(2, math.floor(w / 4))
	for i = 1, columns do
		local x = (i - (columns + 1) / 2) * (w / (columns + 0.4))
		-- Skip the front column the door occupies; always add the back.
		if math.abs(x) >= doorW / 2 + winW / 2 + 0.3 then
			addWindow(model, CFrame.new(position + Vector3.new(x, winY, hd + 0.16)), winW, winH, 1)
		end
		addWindow(model, CFrame.new(position + Vector3.new(x, winY, -hd - 0.16)), winW, winH, -1)
		-- Side windows on the left/right walls for wider buildings.
		if w >= 10 then
			addWindow(
				model,
				CFrame.new(position + Vector3.new(hw + 0.16, winY, 0)) * CFrame.Angles(0, math.rad(90), 0),
				winW,
				winH,
				1
			)
			addWindow(
				model,
				CFrame.new(position + Vector3.new(-hw - 0.16, winY, 0)) * CFrame.Angles(0, math.rad(90), 0),
				winW,
				winH,
				1
			)
		end
	end

	-- ============================= HEALTH BAR =============================
	-- Hosted on the solid Body hitbox so it always sits above the structure.
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(150, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, hh + 3.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	gui.LightInfluence = 0

	local barBack = Instance.new("Frame")
	barBack.Name = "Back"
	barBack.Size = UDim2.fromOffset(150, 14)
	barBack.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	Instance.new("UICorner", barBack).CornerRadius = UDim.new(0, 4)

	local barFill = Instance.new("Frame")
	barFill.Name = "Fill"
	barFill.Size = UDim2.fromScale(1, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(240, 76, 76)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(150, 18)
	label.Position = UDim2.fromOffset(0, 16)
	label.BackgroundTransparency = 1
	label.Text = config.name
	label.TextColor3 = Color3.fromRGB(240, 243, 250)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Parent = gui

	gui.Parent = body
	model.PrimaryPart = body

	-- Collect every part once for registry + damage/destruction restyling.
	local allParts = {}
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(allParts, desc)
		end
	end

	local data = {
		configId = buildingId,
		config = config,
		zoneName = zoneFolder.Name,
		maxHealth = config.maxHealth,
		health = config.maxHealth,
		respawnTime = config.respawnTime,
		part = body, -- authoritative hit part (also the health-bar host)
		model = model,
		parts = allParts, -- every part that maps back to this building
		barFill = barFill,
		label = label,
		dead = false,
		deadUntil = 0,
		visuals = { body = body },
		generationId = 0, -- bumped every respawn; stale callbacks must abort
		rewardClaimedGen = -1, -- generation already rewarded (exactly-once per gen)
	}

	-- Map EVERY part (and the Model) so attacks on any valid part resolve to
	-- the same authoritative data table.
	buildings[model] = data
	for _, p in allParts do
		buildings[p] = data
	end

	-- Clean up registry entries if the model is ever removed from the world.
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			buildings[model] = nil
			for _, p in allParts do
				buildings[p] = nil
			end
		end
	end)

	return model, data
end

-- Apply damage stage visuals (color darken / health bar fill).
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
	local v = data.visuals
	if v and v.body then
		v.body.Color = darkened
		-- Darken all solid structural parts consistently.
		for _, p in data.parts do
			if p.Parent and (p.Name == "Body" or p.Name == "Foundation") then
				p.Color = darkened
			end
			if p.Parent and p.Name == "Window" and stage >= 2 then
				p.Transparency = math.max(p.Transparency, 0.6)
			end
		end
	end
	data.barFill.Size = UDim2.fromScale(math.max(0, healthPct), 1)
end

-- Destroy the building visually and schedule respawn.
local function destroyBuilding(data)
	if data.dead then
		return
	end
	data.dead = true
	data.deadUntil = os.clock() + data.respawnTime
	local gen = data.generationId

	-- Collapse every part to a faint, non-colliding rubble state.
	for _, p in data.parts do
		if p.Parent then
			p.CanCollide = false
			p.Transparency = math.max(p.Transparency, 0.7)
		end
	end

	data.barFill.Size = UDim2.fromScale(0, 1)
	data.label.Text = data.config.name .. " (destroyed)"

	-- Notify all clients via the single BuildingDestroyed remote (created once
	-- in init.server.luau); fire once per connected player.
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
		if gen ~= data.generationId then
			return -- stale respawn from a previous generation; abort
		end
		if not data.model or not data.model.Parent then
			return
		end
		data.dead = false
		data.generationId += 1
		data.health = data.maxHealth
		for _, p in data.parts do
			if p.Parent then
				p.Transparency = if p.Name == "Window" then 0.35 else 0
				p.CanCollide = SOLID_NAMES[p.Name] == true
			end
		end
		data.barFill.Size = UDim2.fromScale(1, 1)
		data.label.Text = data.config.name
		applyDamageStage(data)
	end)
end

-- Resolve any instance (part OR model) to its authoritative building data.
local function resolveBuilding(target: Instance?): { [string]: any }?
	if not target then
		return nil
	end
	local direct = buildings[target]
	if direct then
		return direct
	end
	local node = target
	while node do
		local found = buildings[node]
		if found then
			return found
		end
		node = node.Parent
	end
	if target:IsA("Model") and target.PrimaryPart then
		return buildings[target.PrimaryPart]
	end
	return nil
end

-- Deal damage to a building (server-authoritative). Accepts the struck part or
-- the building Model; both resolve to the same authoritative data table.
function BuildingService.damageBuilding(player: Player, target: Instance, damageAmount: number): { [string]: any }?
	local data = resolveBuilding(target)
	if not data then
		return nil
	end
	if data.dead then
		return nil
	end

	-- The struck part (for range checks); fall back to the primary hit part if
	-- only the Model was supplied.
	local hitPart = (typeof(target) == "Instance" and target:IsA("BasePart")) and target or data.part
	if not hitPart or not hitPart.Parent then
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
	local distance = (root.Position - hitPart.Position).Magnitude
	if distance > Config.Combat.maxAttackRange then
		return nil
	end

	data.health -= damageAmount
	if data.health < 0 then
		data.health = 0
	end
	applyDamageStage(data)

	if data.health <= 0 then
		-- Exactly-once reward per generation: set the claim BEFORE any yield
		-- (Data/Brainrot calls below may yield) so two simultaneous lethal
		-- hits cannot both grant. Second hit sees dead=true and is rejected.
		if data.rewardClaimedGen == data.generationId then
			return nil
		end
		data.rewardClaimedGen = data.generationId
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
					local petEntry = profile.pets and profile.pets[petId]
					if petEntry and petEntry.owned then
						for _, p in ipairs(Config.Pets) do
							if p.id == petId then
								coinBonus += p.coinsBonus or 0
								xpBonus += p.xpBonus or 0
								break
							end
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

function BuildingService.getBuildingHealth(target: Instance?): (number?, number?)
	local data = resolveBuilding(target)
	if not data then
		return nil, nil
	end
	return data.health, data.maxHealth
end

function BuildingService.spawnZoneBuildings(zoneName: string, zoneFolder: Folder)
	-- Legacy compat: spawn buildings for a zone by name.
	local buildingIds = Config.ZoneBuildings[zoneName]
	if not buildingIds then
		return
	end
	if spawnedZones[zoneName] then
		return
	end
	spawnedZones[zoneName] = true

	local floor = zoneFolder:FindFirstChild("Floor")
	local origin = floor and (floor.Position + Vector3.new(0, floor.Size.Y / 2, 0)) or Vector3.new(0, 0, 0)

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
		buildStructure(zoneFolder, buildingId, origin + offset)
	end
end

-- Spawn destructible buildings for a world using its own building distribution.
-- Positions are spread across the world's floor around its center.
function BuildingService.spawnWorldBuildings(worldId: string, worldFolder: Folder, center: Vector3)
	local buildingIds = Config.WorldBuildings and Config.WorldBuildings[worldId]
	if not buildingIds or #buildingIds == 0 then
		return
	end
	if spawnedZones[worldId .. "_world"] then
		return
	end
	spawnedZones[worldId .. "_world"] = true

	local floor = worldFolder:FindFirstChild("Floor")
	local origin = floor and (floor.Position + Vector3.new(0, floor.Size.Y / 2, 0)) or center or Vector3.new(0, 0, 0)

	-- Distribute buildings in a rough arc across the world floor.
	local radius = 40
	for i, buildingId in ipairs(buildingIds) do
		local angle = (i - 1) * (math.pi * 2 / #buildingIds)
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		buildStructure(worldFolder, buildingId, origin + offset)
	end
end

function BuildingService.spawnBuilding(buildingId: string, zoneFolder: Folder, position: Vector3)
	local model, data = buildStructure(zoneFolder, buildingId, position)
	return model, data
end
