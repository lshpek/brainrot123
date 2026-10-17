-- BossService.luau
-- Server-authoritative boss encounters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BossService = {}

local Data
local bosses = {} -- instance -> bossData
local lastAttack = {}

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
	body.Parent = model
	model.PrimaryPart = body

	-- Health bar
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	local back = Instance.new("Frame")
	back.Size = UDim2.fromOffset(200, 16)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 4)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(200, 20)
	label.Position = UDim2.fromOffset(0, 18)
	label.BackgroundTransparency = 1
	label.Text = bossConfig.name
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
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

local function destroyBoss(data)
	if data.dead then
		return
	end
	data.dead = true
	data.deadUntil = os.clock() + (data.config.respawnTime or 300)
	data.health = 0
	data.barFill.Size = UDim2.fromScale(0, 1)
	data.label.Text = data.config.name .. " (defeated)"
	-- Reward contributors once.
	for userId, contributed in pairs(data.contributions) do
		if contributed then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				local profile = Data and Data.get(player)
				if profile then
					Data.addCoins(player, data.config.rewardCoins)
					local bs = nil
					pcall(function()
						bs = require(script.Parent.BrainrotService)
					end)
					if bs and bs.addXpToEquipped then
						bs.addXpToEquipped(player, data.config.rewardXp)
					end
				end
				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
				local notify = remotes and remotes:FindFirstChild("Notify")
				if notify then
					notify:FireClient(player, "success", "Defeated " .. data.config.name .. "!")
				end
			end
		end
	end
	-- hide model
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
		for _, p in data.model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 0
				p.CanCollide = true
			end
		end
		data.barFill.Size = UDim2.fromScale(1, 1)
		data.label.Text = data.config.name
	end)
end

function BossService.start(dataService)
	Data = dataService
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
		local data = resolve(target)
		if not data or data.dead then
			return
		end
		-- range check
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		if (root.Position - target.Position).Magnitude > 30 then
			return
		end
		-- cooldown
		local now = os.clock()
		if now - (lastAttack[player] or 0) < 0.6 then
			return
		end
		lastAttack[player] = now

		local bs = nil
		pcall(function()
			bs = require(script.Parent.BrainrotService)
		end)
		local damage = bs and bs.getEquippedDamage(player) or 10
		data.health -= damage
		if data.health < 0 then
			data.health = 0
		end
		data.barFill.Size = UDim2.fromScale(data.health / data.maxHealth, 1)
		-- track contribution
		local uid = player.UserId
		data.contributions[uid] = true
		if data.health <= 0 then
			destroyBoss(data)
		end
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

function BossService.damageBoss(player, target, damage)
	local data = resolve(target)
	if not data or data.dead then
		return false
	end
	data.health -= damage
	if data.health < 0 then
		data.health = 0
	end
	data.barFill.Size = UDim2.fromScale(data.health / data.maxHealth, 1)
	data.contributions[player.UserId] = true
	if data.health <= 0 then
		destroyBoss(data)
	end
	return true
end

return BossService
