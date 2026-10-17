-- WorldsUi.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local WorldsUi = {}

local player = Players.LocalPlayer
local teleportRemote = nil

function WorldsUi.build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		teleportRemote = remotes:WaitForChild("TeleportWorld", 10)
	end

	local content = UI.window("Worlds", "🌍 Worlds", UDim2.fromOffset(420, 420))
	local list = UI.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
		}),
	})

	for _, world in ipairs(Config.Worlds) do
		local container = UI.create("Frame", {
			Size = UDim2.new(1, -8, 0, 72),
			BackgroundColor3 = UI.Palette.panelLight,
			Parent = list,
		}, { UI.corner(10) })

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -120, 0, 24),
			BackgroundTransparency = 1,
			Text = world.name,
			TextColor3 = UI.Palette.text,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 20 }) })

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -120, 0, 30),
			BackgroundTransparency = 1,
			Text = world.description .. " • Rebirths: " .. tostring(world.rebirthRequired),
			TextColor3 = UI.Palette.subtext,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 12 }) })

		local rebirths = 0
		pcall(function()
			local ls = player:FindFirstChild("leaderstats")
			if ls and ls:FindFirstChild("Rebirths") then
				rebirths = ls.Rebirths.Value
			end
		end)
		local unlocked = rebirths >= (world.rebirthRequired or 0)
		local configured = world.placeId ~= 0
		local btnText = if not unlocked then "LOCKED" elseif not configured then "SOON" else "TELEPORT"
		local button = UI.button({
			Text = btnText,
			Size = UDim2.fromOffset(96, 40),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = container,
		})
		button.Activated:Connect(function()
			if teleportRemote then
				teleportRemote:FireServer(world.id)
			end
		end)
	end
end

return WorldsUi
