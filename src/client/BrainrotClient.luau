-- BrainrotClient.luau
-- Client UI for Brainrot inventory, equip, level, and XP display.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Brainrot = require(ReplicatedStorage.Shared.Brainrot)
local UI = require(script.Parent.UI)

local BrainrotClient = {}

local player = Players.LocalPlayer
local equipRemote: RemoteEvent?

local inventoryList: Frame? = nil

function BrainrotClient.refresh()
	if not inventoryList then
		return
	end
	for _, child in inventoryList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local equippedId = player:GetAttribute("EquippedBrainrot") or "toxic_titan"

	local order = 0
	for _, config in ipairs(Config.Brainrots) do
		order += 1
		local container = UI.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 60),
			BackgroundColor3 = UI.Palette.panelLight,
			Parent = inventoryList,
		}, { UI.corner(10) })

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(40, 44),
			BackgroundTransparency = 1,
			Text = config.emoji,
			TextColor3 = Color3.fromRGB(240, 243, 250),
			Font = Enum.Font.FredokaOne,
			TextSize = 28,
			Parent = container,
		})

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(58, 6),
			Size = UDim2.new(1, -230, 0, 22),
			BackgroundTransparency = 1,
			Text = config.name,
			TextColor3 = UI.Palette.text,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 18 }) })

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(58, 30),
			Size = UDim2.new(1, -230, 0, 18),
			BackgroundTransparency = 1,
			Text = config.rarity .. "  •  " .. config.description,
			TextColor3 = Brainrot.rarityColor(config.rarity),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 14 }) })

		local btn = UI.button({
			Text = "EQUIP",
			Size = UDim2.fromOffset(90, 36),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Parent = container,
		})
		btn.Activated:Connect(function()
			if equipRemote then
				equipRemote:FireServer(config.id)
			end
			BrainrotClient.refresh()
		end)

		if config.id == equippedId then
			btn.Text = "EQUIPPED"
			btn.BackgroundColor3 = UI.Palette.good
			btn.Active = false
		end
	end
end

function BrainrotClient.build()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		equipRemote = remotes:FindFirstChild("EquipBrainrot")
		if not equipRemote then
			equipRemote = Instance.new("RemoteEvent")
			equipRemote.Name = "EquipBrainrot"
			equipRemote.Parent = remotes
		end
	end

	local content = UI.window("Brainrots", "🧠 Brainrots", UDim2.fromOffset(520, 420))

	UI.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = content,
	})

	UI.create("TextLabel", {
		Size = UDim2.new(1, -24, 0, 28),
		BackgroundTransparency = 1,
		Text = "Click a Brainrot to equip it. Attack buildings to gain XP.",
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		Parent = content,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 16 }) })

	inventoryList = UI.create("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -60),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = inventoryList,
		}),
	})

	BrainrotClient.refresh()

	player:GetAttributeChangedSignal("EquippedBrainrot"):Connect(function()
		BrainrotClient.refresh()
	end)
end

return BrainrotClient