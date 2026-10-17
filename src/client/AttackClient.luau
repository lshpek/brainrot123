-- AttackClient.luau
-- Client-side attack input: click a building to attack it.
-- The server is authoritative; this only sends intent and renders feedback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)
local Effects = require(script.Effects)

local AttackClient = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local userInputService = UserInputService

local attackRemote: RemoteEvent?
local attackResult: RemoteEvent?
local buildingDestroyed: RemoteEvent?
local notify: RemoteEvent?

local currentTarget: BasePart? = nil
local highlight: BoxHandleAdornment? = nil

-- Max distance for the client to even attempt an attack (early reject).
local MAX_CLIENT_RANGE = Config.Combat.maxAttackRange + 4

local function getRemotes()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then
		return
	end
	attackRemote = remotes:WaitForChild("Attack")
	attackResult = remotes:WaitForChild("AttackResult")
	buildingDestroyed = remotes:WaitForChild("BuildingDestroyed")
	notify = remotes:WaitForChild("Notify")
end

-- Flash a model's parts white briefly for hit feedback.
local function flashModel(model: Model?, duration: number)
	if not model then
		return
	end
	local originals = {} -- [part] = originalColor
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			originals[part] = part.Color
			part.Color = Color3.fromRGB(255, 255, 255)
		end
	end
	task.delay(duration, function()
		for part, color in originals do
			if part and part.Parent then
				part.Color = color
			end
		end
	end)
end

-- Highlight the building under the cursor when in range.
local function updateHighlight()
	if not highlight then
		highlight = Instance.new("BoxHandleAdornment")
		highlight.AlwaysOnTop = false
		highlight.ZIndex = 10
		highlight.Parent = workspace
	end

	local target = mouse.Target
	if not target then
		highlight.Adornee = nil
		currentTarget = nil
		return
	end

	-- Walk up to find a building part (a part with a HealthBar BillboardGui).
	local building = target
	while building and building ~= workspace do
		if building:IsA("BasePart") and building:FindFirstChild("HealthBar") then
			break
		end
		building = building.Parent
	end

	if not building or not building:IsA("BasePart") then
		highlight.Adornee = nil
		currentTarget = nil
		return
	end

	-- Range check.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and (root.Position - building.Position).Magnitude <= MAX_CLIENT_RANGE then
		highlight.Adornee = building
		highlight.Size = building.Size + Vector3.new(0.2, 0.2, 0.2)
		highlight.CFrame = building.CFrame
		highlight.Color3 = Color3.fromRGB(255, 170, 60)
		currentTarget = building
	else
		highlight.Adornee = nil
		currentTarget = nil
	end
end

local function onAttackResult(result: { [string]: any })
	if not result then
		return
	end
	if result.destroyed then
		Effects.toast("success", `Destroyed! +{result.coins} 🪙 +{result.xp} XP`)
		Effects.destructionBurst()
		return
	end

	-- Damage popup at screen center.
	local popup = UI.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.4, 0),
		Size = UDim2.fromOffset(200, 36),
		BackgroundTransparency = 1,
		Text = `-{result.damage} 💥`,
		TextColor3 = Color3.fromRGB(255, 90, 90),
		Font = Enum.Font.FredokaOne,
		TextSize = 28,
		TextStrokeTransparency = 0.3,
		Parent = Effects.gui,
	})
	task.delay(0.8, function()
		popup:Destroy()
	end)

	-- Threshold cues: when the building crosses into a damage stage or gets
	-- close to destruction, give a distinct, restrained audio/visual signal.
	if result.health and result.maxHealth and result.maxHealth > 0 then
		local pct = result.health / result.maxHealth
		if pct <= 0 and Effects.critCue then
			Effects.critCue() -- last hit before destroy
		elseif pct <= 0.4 and Effects.dangerCue then
			Effects.dangerCue() -- "close to destruction"
		end
	end
end

local function onBuildingDestroyed(part: BasePart)
	-- Visual feedback: flash the whole building model briefly.
	if not part then
		return
	end
	local model = part.Parent
	if model:IsA("Model") then
		flashModel(model, 0.3)
	end
	part.Color = Color3.fromRGB(90, 90, 90)
end

function AttackClient.start()
	getRemotes()

	-- Highlight on mouse move.
	RunService.RenderStepped:Connect(updateHighlight)

	-- Attack on click (mouse1 or tap).
	local lastClick = 0
	userInputService = UserInputService
	userInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			local now = os.clock()
			if now - lastClick < Config.Combat.attackCooldown * 0.5 then
				return
			end
			lastClick = now
			if currentTarget and attackRemote then
				-- Flash the target briefly for hit feedback.
				local model = currentTarget.Parent
				if model and model:IsA("Model") then
					flashModel(model, 0.15)
				end
				attackRemote:FireServer(currentTarget)
			end
		end
	end)

	attackResult.OnClientEvent:Connect(onAttackResult)
	buildingDestroyed.OnClientEvent:Connect(onBuildingDestroyed)
end

return AttackClient
