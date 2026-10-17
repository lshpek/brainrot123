-- PetFollower.luau
-- Client-side visual follower presentation for equipped pets.
--
-- Pets follow their owner with non-overlapping formation offsets, are
-- non-colliding (do not push or obstruct the character), and are cleaned up
-- on unequip, character respawn, or player leaving. Visuals are code-generated
-- placeholders pending real imported pet models (docs/ASSET_MANIFEST.md).
--
-- This runs entirely on the client; ownership/equipped state is authoritative
-- on the server and replicated via player attributes.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Trove = require(game:GetService("ReplicatedStorage").Shared.Trove)

local PetFollower = {}

local player = Players.LocalPlayer

local followers = {} -- [petId] = { model = Model, offset = Vector3 }
local followerGui: ScreenGui? = nil
local trove: any = nil

local MAX_PETS = Config.MaxEquippedPets or 3

-- Formation offsets so multiple pets don't overlap.
local FORMATION_OFFSETS = {
	Vector3.new(0, 3, -4),
	Vector3.new(-2.5, 3, -4),
	Vector3.new(2.5, 3, -4),
	Vector3.new(-4, 3, 0),
	Vector3.new(4, 3, 0),
}

local function petConfig(petId: string)
	for _, p in ipairs(Config.Pets) do
		if p.id == petId then
			return p
		end
	end
	return nil
end

local function createFollower(petId: string): Model?
	local config = petConfig(petId)
	if not config then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Pet_" .. petId

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2, 2, 2)
	body.Shape = Enum.PartType.Ball
	body.Anchored = false
	body.CanCollide = false -- never push or obstruct the character
	body.Color = config.color or Color3.fromRGB(160, 160, 160)
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	local label = Instance.new("BillboardGui")
	label.Adornee = body
	label.Size = UDim2.fromOffset(60, 24)
	label.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 100
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = config.emoji or "🐾"
	text.TextColor3 = Color3.fromRGB(240, 243, 250)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Parent = label
	label.Parent = body

	model.PrimaryPart = body
	return model
end

local function equippedList(): { string }
	local list = player:GetAttribute("EquippedPets") or ""
	local out = {}
	for id in list:gmatch("[^,]+") do
		table.insert(out, id)
	end
	return out
end

local function spawnFollower(petId: string, index: number)
	if followers[petId] then
		return
	end
	local model = createFollower(petId)
	if not model then
		return
	end
	model.Parent = workspace
	local offset = FORMATION_OFFSETS[index] or Vector3.new(0, 3, -4 - index * 3)
	followers[petId] = { model = model, offset = offset }
end

local function despawnFollower(petId: string)
	local entry = followers[petId]
	if entry and entry.model then
		entry.model:Destroy()
	end
	followers[petId] = nil
end

local function clearAllFollowers()
	for petId in pairs(followers) do
		despawnFollower(petId)
	end
end

local function rootPart(): BasePart?
	local char = player.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function updateFollowers()
	local equipped = equippedList()
	-- Spawn followers for newly equipped pets.
	for index, petId in ipairs(equipped) do
		if index <= MAX_PETS then
			spawnFollower(petId, index - 1)
		end
	end
	-- Despawn followers for unequipped pets.
	for petId in pairs(followers) do
		local stillEquipped = false
		for _, id in ipairs(equipped) do
			if id == petId then
				stillEquipped = true
				break
			end
		end
		if not stillEquipped then
			despawnFollower(petId)
		end
	end

	-- Smoothly follow the owner (non-physics, CFrame-based to avoid pushing).
	local root = rootPart()
	if not root then
		return
	end
	for petId, entry in pairs(followers) do
		local model = entry.model
		local body = model and model:FindFirstChild("Body")
		if not body or not body.Parent then
			continue
		end
		local target = root.CFrame * CFrame.new(entry.offset)
		-- Lerp toward target for smooth movement.
		body.CFrame = body.CFrame:Lerp(target, 0.25)
		-- Keep follower upright and non-colliding.
		body.CanCollide = false
		body.Anchored = false
	end
end

function PetFollower.start()
	clearAllFollowers()
	if trove then
		trove:Clean()
	end
	trove = Trove.new()

	-- Rebuild followers whenever equipped-pet state changes.
	trove:Connect(player:GetAttributeChangedSignal("EquippedPets"), function()
		clearAllFollowers()
		task.defer(function()
			updateFollowers()
		end)
	end)

	-- Respawn followers on character respawn (avoid duplicates/strays).
	trove:Connect(player.CharacterAdded, function()
		clearAllFollowers()
		task.defer(function()
			updateFollowers()
		end)
	end)

	trove:Add(RunService.RenderStepped:Connect(updateFollowers))
	updateFollowers()
end

function PetFollower.stop()
	if trove then
		trove:Clean()
		trove = nil
	end
	clearAllFollowers()
end

return PetFollower
