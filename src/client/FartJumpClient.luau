-- FartJumpClient.luau
-- Client input + feedback for the signature fart-jump. Sends ONLY an intent
-- (movement direction) to the server; the server validates cooldown, grounded
-- state, and computes the actual bounded impulse. Provides a PC key, a mobile
-- touch button, and a cooldown indicator.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)
local Effects = require(script.Parent.Effects)

local FartJumpClient = {}

local player = Players.LocalPlayer
local FJ = Config.FartJump

local jumpRemote: RemoteEvent? = nil
local lastLocalFire = 0

local cooldownFill: Frame? = nil
local cooldownLabel: TextLabel? = nil
local buttonLabel: TextLabel? = nil
local touchButton: TextButton? = nil

local function getMoveDirection(): Vector3
	-- Horizontal facing/move direction from the camera, so the jump launches
	-- where the player is looking/steering. Server re-sanitizes anyway.
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 0, -1)
	end
	local look = camera.CFrame.LookVector
	return Vector3.new(look.X, 0, look.Z)
end

local function tryFire()
	if not jumpRemote then
		return
	end
	local now = os.clock()
	if now - lastLocalFire < FJ.cooldown * 0.9 then
		return -- local pre-throttle to avoid obvious spam; server is authority
	end
	lastLocalFire = now
	jumpRemote:FireServer(getMoveDirection())
	-- Immediate local visual so it feels responsive; server may still reject.
	if Effects and Effects.fartBurst then
		Effects.fartBurst()
	end
end

local function updateCooldownVisual()
	local readyAt = player:GetAttribute("FartJumpReadyAt") or 0
	local now = os.clock()
	local remain = math.max(0, readyAt - now)
	local pct = if FJ.cooldown > 0 then math.clamp(remain / FJ.cooldown, 0, 1) else 0

	if cooldownFill then
		cooldownFill.Size = UDim2.fromScale(1 - pct, 1)
		-- Dim/grey out while cooling down, brighten when ready.
		cooldownFill.BackgroundColor3 = if remain > 0 then Color3.fromRGB(90, 97, 115) else UI.Palette.accent
	end
	local ready = remain <= 0
	if buttonLabel then
		buttonLabel.Text = if ready then "💨 JUMP" else string.format("%.1fs", remain)
	end
	if cooldownLabel then
		cooldownLabel.Text = if ready then "Fart Jump ready — press F" else string.format("Fart Jump: %.1fs", remain)
	end
end

function FartJumpClient.start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		jumpRemote = remotes:WaitForChild("FartJump", 10)
	end

	local gui = UI.create("ScreenGui", {
		Name = "FartJump",
		ResetOnSpawn = false,
		DisplayOrder = 5,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Cooldown hint label (above the jump control).
	cooldownLabel = UI.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.fromOffset(260, 20),
		BackgroundTransparency = 1,
		Text = "Fart Jump ready — press F",
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = gui,
	})

	-- Desktop jump button (bottom-center), also click/tap-able.
	local button = UI.button({
		Text = "💨 JUMP",
		Size = UDim2.fromOffset(150, 60),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Color = UI.Palette.accent,
		MaxTextSize = 24,
		CornerRadius = 16,
		Parent = gui,
	})
	buttonLabel = button:FindFirstChildOfClass("TextLabel")
	cooldownFill = UI.create("Frame", {
		Name = "CooldownFill",
		Size = UDim2.fromScale(1, 1),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(0, 0),
		BackgroundColor3 = UI.Palette.accent,
		BackgroundTransparency = 0.65,
		ZIndex = 0,
		Parent = button,
	})
	-- Ensure the fill sits behind the text label.
	if buttonLabel then
		buttonLabel.ZIndex = 2
	end

	button.Activated:Connect(tryFire)

	-- Mobile: a dedicated touch button that only shows on touch devices.
	if UserInputService.TouchEnabled then
		touchButton = button -- reuse the same button as the touch control
	end

	-- PC dedicated key: F (fallback to Space only if not gameProcessed).
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonA then
			tryFire()
		end
	end)

	-- Keep the cooldown indicator in sync with the server hint.
	RunService.RenderStepped:Connect(updateCooldownVisual)
	player:GetAttributeChangedSignal("FartJumpReadyAt"):Connect(updateCooldownVisual)
	updateCooldownVisual()
end

return FartJumpClient
