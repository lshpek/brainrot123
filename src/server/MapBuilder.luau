-- MapBuilder.luau
-- Builds five distinct world layouts from Config.WorldLayouts: zone platforms,
-- district markers, spawn locations, boss districts, dedicated PvP arenas,
-- destructible buildings, connecting paths and a kill plane. All geometry is
-- code-generated placeholders pending real imported model integration
-- (see docs/ASSET_MANIFEST.md).
--
-- Each world is its own folder under workspace.Map. World identity is driven
-- by Config.WorldLayouts / Config.Worlds, never by a hard-coded Settlement
-- fallback.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)

local ZONE_SIZE = 140
local WALL_HEIGHT = 24

-- Build a lookup from zone name to its config (powerRequired, multiplier, etc.)
-- so MapBuilder has a single source of truth from Config.Zones.
local ZoneConfigByName = {}
for _, zone in ipairs(Config.Zones) do
	ZoneConfigByName[zone.name] = zone
end

local MapBuilder = {}

-- Axis-aligned regions used by Training to validate zone bonuses server-side.
local zoneRegions = {}

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function billboard(adornee: BasePart, text: string, color: Color3, offsetY: number, size: UDim2)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = size
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 400

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 0.4
	label.Parent = gui

	gui.Parent = adornee
	return gui, label
end

local function buildDistrictMarker(parent: Folder, center: Vector3, name: string, accent: Color3)
	local sign = part({
		Name = "District_" .. name,
		Size = Vector3.new(12, 4, 0.4),
		CFrame = CFrame.new(center + Vector3.new(0, 3, 0)),
		Color = accent,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	billboard(sign, name, Color3.fromRGB(240, 243, 250), 4, UDim2.fromScale(12, 2))
end

local function buildSpawnLocation(parent: Folder, position: Vector3, name: string)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0))
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(90, 210, 120)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent
	return spawn
end

-- Builds one complete world layout.
local function buildWorld(worldIndex: number, layout: { [string]: any }): Folder
	local worldFolder = Instance.new("Folder")
	worldFolder.Name = layout.name -- e.g. "Settlement", "Village"
	worldFolder.Parent = workspace:FindFirstChild("Map") or workspace

	local centerX = (worldIndex - 1) * ZONE_SIZE
	local center = Vector3.new(centerX, 0, 0)
	local accent = layout.themeColor or Color3.fromRGB(160, 160, 160)
	local material = layout.themeMaterial or Enum.Material.SmoothPlastic

	-- World floor platform.
	part({
		Name = "Floor",
		Size = Vector3.new(ZONE_SIZE, 4, ZONE_SIZE),
		CFrame = CFrame.new(centerX, -2, 0),
		Color = layout.themeColor or Color3.fromRGB(160, 160, 160),
		Material = material,
		Parent = worldFolder,
	})

	-- World name sign at the near edge.
	local sign = part({
		Name = "WorldSign",
		Size = Vector3.new(14, 5, 0.4),
		CFrame = CFrame.new(centerX, 4, -ZONE_SIZE / 2 - 3),
		Color = accent,
		Material = Enum.Material.SmoothPlastic,
		Parent = worldFolder,
	})
	billboard(
		sign,
		layout.name .. "  •  " .. (layout.description or ""),
		Color3.fromRGB(240, 243, 250),
		4,
		UDim2.fromScale(14, 2)
	)

	-- Spawn location.
	local spawn = buildSpawnLocation(worldFolder, center + layout.spawn, layout.name .. "_Spawn")

	-- District markers.
	for _, district in ipairs(layout.districts or {}) do
		buildDistrictMarker(worldFolder, center + district.offset, district.name, accent)
	end

	-- Boss district marker (distinct visual).
	local bossPos = center + layout.bossPosition
	local bossMarker = part({
		Name = "BossDistrict",
		Size = Vector3.new(20, 1, 20),
		CFrame = CFrame.new(bossPos + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(235, 87, 87),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		CanCollide = false,
		Parent = worldFolder,
	})
	billboard(bossMarker, "BOSS: " .. layout.name .. " Boss", Color3.fromRGB(255, 255, 255), 6, UDim2.fromScale(20, 2))

	-- Dedicated PvP arena marker.
	local arenaPos = center + layout.arenaPosition
	local arenaMarker = part({
		Name = "PvPArena",
		Size = Vector3.new(layout.arenaRadius * 2, 1, layout.arenaRadius * 2),
		CFrame = CFrame.new(arenaPos + Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(90, 170, 255),
		Material = Enum.Material.ForceField,
		Transparency = 0.6,
		CanCollide = false,
		Parent = worldFolder,
	})
	billboard(
		arenaMarker,
		"PvP Arena — " .. layout.name,
		Color3.fromRGB(240, 243, 250),
		6,
		UDim2.fromScale(layout.arenaRadius * 2 / 10, 2)
	)

	-- Region for Training zone validation. Uses Config.Zones as the single
	-- source of truth for powerRequired and multiplier.
	local zoneCfg = ZoneConfigByName[layout.name] or { powerRequired = 0, multiplier = 1 }
	table.insert(zoneRegions, {
		minX = centerX - ZONE_SIZE / 2,
		maxX = centerX + ZONE_SIZE / 2,
		minZ = -ZONE_SIZE / 2,
		maxZ = ZONE_SIZE / 2,
		info = {
			name = layout.name,
			worldId = layout.id,
			powerRequired = zoneCfg.powerRequired or 0,
			multiplier = zoneCfg.multiplier or 1,
		},
	})

	return worldFolder, { spawn = spawn.Position, boss = bossPos, arena = arenaPos }
end

function MapBuilder.getZoneAt(position: Vector3)
	for _, region in zoneRegions do
		if
			position.X >= region.minX
			and position.X <= region.maxX
			and position.Z >= region.minZ
			and position.Z <= region.maxZ
		then
			return region.info
		end
	end
	return nil
end

function MapBuilder.build()
	print("[MapBuilder] build started")
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	print("[MapBuilder] Map folder created")

	-- Create ZoneGates folder for client gate system.
	local zoneGatesFolder = Instance.new("Folder")
	zoneGatesFolder.Name = "ZoneGates"
	zoneGatesFolder.Parent = workspace

	local worldHandles = {}

	for index, layout in ipairs(Config.WorldLayouts) do
		local ok, result = pcall(function()
			return { buildWorld(index, layout) }
		end)
		if ok and result then
			worldHandles[layout.id] = result[2]
			worldHandles[layout.name] = result[2]
		else
			warn("[MapBuilder] Failed to build world '" .. tostring(layout.name) .. "': " .. tostring(result))
		end
	end
	print("[MapBuilder] built " .. tostring(#Config.WorldLayouts) .. " worlds")

	-- Connect worlds with paved paths between their spawns and create gates.
	-- Skip any world whose handle is missing (that world failed to build).
	local spawnPoints = {}
	for _, layout in ipairs(Config.WorldLayouts) do
		local handle = worldHandles[layout.id]
		if handle then
			table.insert(spawnPoints, handle.spawn)
		else
			warn("[MapBuilder] No spawn handle for '" .. tostring(layout.name) .. "'; skipping path/gate")
		end
	end
	for i = 2, #spawnPoints do
		local from = spawnPoints[i - 1]
		local to = spawnPoints[i]
		local direction = (to - from)
		local length = direction.Magnitude
		if length > 0 then
			local mid = (from + to) / 2
			local cf = CFrame.lookAt(mid, to)
			-- Create the paved path.
			part({
				Name = "InterWorldPath_" .. i,
				Size = Vector3.new(10, 0.6, length),
				CFrame = cf * CFrame.new(0, 0.31, 0),
				Color = Color3.fromRGB(150, 140, 120),
				Material = Enum.Material.Concrete,
				Parent = map,
			})
			-- Create a gate at the midpoint.
			local gate = part({
				Name = "Gate_" .. tostring(i - 1) .. "_to_" .. tostring(i),
				Size = Vector3.new(4, 20, 1), -- width, height, thickness
				CFrame = cf * CFrame.new(0, 10, -0.5), -- lift the gate up by half its height and move it back by half thickness so it's centered on the path.
				Color = Color3.fromRGB(100, 100, 100),
				Material = Enum.Material.Metal,
				Parent = zoneGatesFolder,
			})
			-- Add a BillboardGui with a TextLabel for the gate's zone name.
			local gui, label = billboard(gate, "", Color3.fromRGB(240, 243, 250), 10, UDim2.fromScale(4, 2))
			label.Text = "" -- Will be set by client based on lock state.
			-- Set gate attributes using the entering world's config.
			local enteringLayout = Config.WorldLayouts[i]
			local enteringZone = ZoneConfigByName[enteringLayout.name]
			gate:SetAttribute("ZoneName", enteringLayout.name)
			gate:SetAttribute("PowerRequired", (enteringZone and enteringZone.powerRequired) or 0)
			gate:SetAttribute("Multiplier", (enteringZone and enteringZone.multiplier) or 1)
			gate:SetAttribute("VipOnly", false)
		end
	end

	-- Leaderboard board near the first world's spawn.
	local firstHandle = worldHandles[Config.WorldLayouts[1].id]
	local firstSpawn = (firstHandle and firstHandle.spawn) or Vector3.new(0, 5, 0)
	if not firstHandle then
		warn("[MapBuilder] First world missing handle; leaderboard placed at fallback position")
	end
	local board = part({
		Name = "LeaderboardBoard",
		Size = Vector3.new(26, 14, 2),
		CFrame = CFrame.new(firstSpawn.X, 9, firstSpawn.Z + 12),
		Color = Color3.fromRGB(34, 39, 54),
		Material = Enum.Material.SmoothPlastic,
		Parent = map,
	})

	-- Kill plane: fast respawn instead of a long fall to the void.
	local killPlane = part({
		Name = "KillPlane",
		Size = Vector3.new(6000, 1, 6000),
		CFrame = CFrame.new(200, -45, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = map,
	})
	killPlane.Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting

	-- Count generated floor parts for diagnostics.
	local floorCount = #workspace.Map:GetDescendants()
	print("[MapBuilder] build completed — " .. tostring(floorCount) .. " total instances in Map, " .. tostring(#zoneRegions) .. " zone regions")

	return { worldHandles = worldHandles, leaderboardPart = board }
end

return MapBuilder
