-- Effects.luau
-- Juice: floating "+power" popups on every punch, toast notifications from
-- the server, and lightweight sounds (built-in rbxasset sounds, no uploads).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local UI = require(script.Parent.UI)

local Effects = {}

local gui: ScreenGui
local toastContainer: Frame
local rng = Random.new()

local function makeSound(id: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local punchSound = makeSound("rbxasset://sounds/swoosh.wav", 0.35)
local successSound = makeSound("rbxasset://sounds/electronicpingshort.wav", 0.5)
local errorSound = makeSound("rbxasset://sounds/snap.mp3", 0.5)
local fartSound = makeSound("rbxasset://sounds/fart.mp3", 0.6) -- built-in rbxasset; may be a placeholder id
local warnSound = makeSound("rbxasset://sounds/electronicpingshort.wav", 0.4)
local critSound = makeSound("rbxasset://sounds/snap.mp3", 0.55)
local destroySound = makeSound("rbxasset://sounds/swoosh.wav", 0.7)

-- Lightweight visual for the signature fart-jump: a quick burst emoji near the
-- character + the dedicated sound. Deliberately restrained (no screen shake).
function Effects.fartBurst()
	if fartSound then
		pcall(function()
			fartSound.PlaybackSpeed = rng:NextNumber(0.9, 1.1)
			fartSound:Play()
		end)
	end
	local popup = UI.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 40),
		Size = UDim2.fromOffset(120, 48),
		BackgroundTransparency = 1,
		Text = "💨",
		TextColor3 = Color3.fromRGB(210, 255, 180),
		Font = Enum.Font.FredokaOne,
		TextSize = 40,
		TextStrokeTransparency = 0.3,
		Parent = gui,
	})
	local tween = TweenService:Create(popup, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position + UDim2.fromOffset(0, -70),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end

-- Restrained "close to destruction" cue (≤40% health): short warn sound + a
-- subtle red flash tint cue. No screen shake, no spam.
function Effects.dangerCue()
	if warnSound then
		pcall(function()
			warnSound:Play()
		end)
	end
end

-- Final-hit cue: a slightly punchier sound when the last blow lands.
function Effects.critCue()
	if critSound then
		pcall(function()
			critSound:Play()
		end)
	end
end

-- Stronger final-destruction effect: reward-flavored burst + sound. Still
-- bounded (one small popup, no debris/particles) so it works at low graphics.
function Effects.destructionBurst()
	if destroySound then
		pcall(function()
			destroySound:Play()
		end)
	end
	local popup = UI.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.44, 0),
		Size = UDim2.fromOffset(300, 64),
		BackgroundTransparency = 1,
		Text = "💥 BOOM! 💨",
		TextColor3 = Color3.fromRGB(255, 176, 32),
		Font = Enum.Font.FredokaOne,
		TextSize = 44,
		TextStrokeTransparency = 0.2,
		Parent = gui,
	})
	local tween = TweenService:Create(popup, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = popup.Position + UDim2.fromOffset(0, -50),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end

function Effects.punchPopup(power: number, coins: number)
	punchSound.PlaybackSpeed = rng:NextNumber(0.9, 1.15)
	punchSound:Play()

	local popup = UI.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, rng:NextInteger(-120, 120), 0.62, rng:NextInteger(-20, 20)),
		Size = UDim2.fromOffset(220, 40),
		BackgroundTransparency = 1,
		Text = `+{Formulas.abbreviate(power)} 💪  +{Formulas.abbreviate(coins)} 🪙`,
		TextColor3 = UI.Palette.accent,
		Font = Enum.Font.FredokaOne,
		TextSize = 26,
		TextStrokeTransparency = 0.3,
		Parent = gui,
	})

	local tween = TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position + UDim2.fromOffset(0, -90),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
	tween:Play()
end

function Effects.toast(kind: string, message: string)
	local isError = kind == "error"
	if isError then
		errorSound:Play()
	else
		successSound:Play()
	end

	local toast = UI.create("Frame", {
		Size = UDim2.fromOffset(340, 44),
		BackgroundColor3 = isError and UI.Palette.bad or UI.Palette.good,
		BackgroundTransparency = 0.1,
		Parent = toastContainer,
	}, {
		UI.corner(12),
		UI.create("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = message,
			TextColor3 = Color3.fromRGB(25, 25, 25),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			Parent = nil,
		}, {
			UI.create("UITextSizeConstraint", { MaxTextSize = 18 }),
			UI.padding(8),
		}),
	})

	task.delay(2.5, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		local label = toast:FindFirstChildOfClass("TextLabel")
		if label then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		fade.Completed:Connect(function()
			toast:Destroy()
		end)
		fade:Play()
	end)
end

function Effects.start()
	gui = UI.create("ScreenGui", {
		Name = "Effects",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	toastContainer = UI.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(340, 300),
		BackgroundTransparency = 1,
		Parent = gui,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Notify").OnClientEvent:Connect(Effects.toast)
	remotes:WaitForChild("Punch").OnClientEvent:Connect(Effects.punchPopup)
end

return Effects
