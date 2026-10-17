-- BossService.luau
-- Server-authoritative boss encounters.
--
-- BOSS DAMAGE VALIDATION IS CENTRALIZED HERE: `damageBoss(player, target,
-- damageAmount)` is the only path that can reduce boss health. Both the
-- `BossAttack` remote and the building `Attack` remote route through it, so no
-- combat path bypasses range, cooldown, aliveness, or contribution checks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BossService = {}

local Data
local BrainrotService

local bosses = {} -- instance -> bossData
local lastAttack = {} -- [Player] = os.clock() of last accepted boss attack

local BOSS_ATTACK_RANGE = 30
local BOSS_ATTACK_COOLDOWN = 0.6

local function getBossConfig(bossId)
	for _, b in ipairs(Config.Bosses) do
		if b.id == bossId then
			return b
		end
	end
	return nil
end

local function resolve(target)
	if not target then
		return nil
	end
	local direct = bosses[target]
	if direct then
		return direct
	end
	local node = target
	while node do
		local found = bosses[node]
		if found then
			return found
		end
		node = node.Parent
	end
	return nil
end

local function spawnBoss(bossConfig, position, parent)
	if not bossConfig then
		return nil
	end
	local size = bossConfig.size or Vector3.new(8, 10, 8)
	local model = Instance.new("Model")
	model.Name = bossConfig.name
	model.Parent = parent

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = size
	body.CFrame = CFrame.new(position + Vector3.new(0, size.Y / 2, 0))
	body.Anchored = true
	body.Color = bossConfig.color or Color3.fromRGB(200, 80, 80)
	body.Material = Enum.Material.SmoothPlastic
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	-- Health bar hosted on the body part (clients click/resolve via this).
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.LightInfluence = 0
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromOffset(220, 18)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromOffset(220, 22)
	label.Position = UDim2.fromOffset(0, 20)
	label.BackgroundTransparency = 1
	label.Text = bossConfig.name
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = body

	local data = {
		config = bossConfig,
		bossId = bossConfig.id,
		maxHealth = bossConfig.maxHealth,
		health = bossConfig.maxHealth,
		body = body,
		model = model,
		barFill = fill,
		label = label,
		dead = false,
		deadUntil = 0,
		contributions = {},
		lastTelegraph = 0,
	}
	bosses[model] = data
	bosses[body] = data
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			bosses[d] = data
		end
	end
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			bosses[model] = nil
			bosses[body] = nil
		end
	end)
	return model, data
end

local function rewardContributors(data)
	for userId in pairs(data.contributions) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local profile = Data and Data.get(player)
			if profile then
				local rewardCoins = data.config.rewardCoins or 0
				local rewardXp = data.config.rewardXp or 0
				if rewardCoins > 0 then
					Data.addCoins(player, rewardCoins)
				end
				if rewardXp > 0 and BrainrotService and BrainrotService.addXpToEquipped then
					BrainrotService.addXpToEquipped(player, rewardXp)
				end
			end
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local notify = remotes and remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "success", "Defeated " .. data.config.name .. "!")
			end
			local bossUpdate = remotes and remotes:FindFirstChild("BossUpdate")
			if bossUpdate then
				bossUpdate:FireClient(player, "defeated", data.bossId)
			end
		end
	end
end

local function destroyBoss(data)
	if data.dead then
		return
	end
	data.dead = true
	data.deadUntil = os.clock() + (data.config.respawnTime or 300)
	data.health = 0
	data.barFill.Size = UDim2.fromScale(0, 1)
	data.label.Text = data.config.name .. " (defeated)"
	rewardContributors(data)
	for _, p in data.model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Transparency = 1
			p.CanCollide = false
		end
	end
	task.delay(data.config.respawnTime or 300, function()
		if not data.model or not data.model.Parent then
			return
		end
		data.dead = false
		data.health = data.maxHealth
		data.contributions = {}
		data.barFill.Size = UDim2.fromScale(1, 1)
		data.label.Text = data.config.name
		for _, p in data.model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 0
				p.CanCollide = true
			end
		end
	end)
end

-- Central, validated boss damage. damageAmount is always computed server-side
-- (never trusted from the client). Returns true if damage was applied.
function BossService.damageBoss(player, target, damageAmount)
	if type(damageAmount) ~= "number" or damageAmount <= 0 then
		return false
	end
	local data = resolve(target)
	if not data or data.dead then
		return false
	end
	-- Range check from the attacker's actual character position.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local hitPart = (typeof(target) == "Instance" and target:IsA("BasePart")) and target or data.body
	if not hitPart or not hitPart.Parent then
		return false
	end
	if (root.Position - hitPart.Position).Magnitude > BOSS_ATTACK_RANGE then
		return false
	end
	-- Cooldown / anti-spam.
	local now = os.clock()
	if now - (lastAttack[player] or 0) < BOSS_ATTACK_COOLDOWN then
		return false
	end
	lastAttack[player] = now

	data.health -= damageAmount
	if data.health < 0 then
		data.health = 0
	end
	data.barFill.Size = UDim2.fromScale(data.health / data.maxHealth, 1)
	data.contributions[player.UserId] = true

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local bossUpdate = remotes and remotes:FindFirstChild("BossUpdate")
	if bossUpdate then
		bossUpdate:FireClient(player, "health", {
			bossId = data.bossId,
			health = data.health,
			maxHealth = data.maxHealth,
		})
	end

	if data.health <= 0 then
		destroyBoss(data)
	end
	return true
end

function BossService.start(dataService, brainrotService)
	Data = dataService
	BrainrotService = brainrotService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local bossRemote = remotes:FindFirstChild("BossAttack")
	if not bossRemote then
		local r = Instance.new("RemoteEvent")
		r.Name = "BossAttack"
		r.Parent = remotes
		bossRemote = r
	end
	bossRemote.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" or not target:IsA("BasePart") then
			return
		end
		local bs = nil
		local okB, resB = pcall(function()
			bs = require(script.Parent.BrainrotService)
		end)
		local damage = 10
		if okB and bs and bs.getEquippedDamage then
			damage = bs.getEquippedDamage(player)
		end
		if damage <= 0 then
			return
		end
		BossService.damageBoss(player, target, damage)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

function BossService.spawnBoss(bossId, position, parent)
	local cfg = getBossConfig(bossId)
	if not cfg then
		return nil
	end
	return spawnBoss(cfg, position, parent)
end

function BossService.resolve(target)
	return resolve(target)
end

function BossService.getBoss(bossId)
	local cfg = getBossConfig(bossId)
	if not cfg then
		return nil
	end
	return {
		bossId = cfg.id,
		name = cfg.name,
		world = cfg.world,
		maxHealth = cfg.maxHealth,
		rewardCoins = cfg.rewardCoins,
		rewardXp = cfg.rewardXp,
	}
end

return BossService
