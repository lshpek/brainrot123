-- PetUi.luau
-- Two-tab window: Eggs (buy/hatch) and Pets (owned inventory + equip).
-- Ownership/equipped state is read from replicated player attributes set by
-- the server (Data.sync); purchases and equip go through the server remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local UI = require(script.Parent.UI)

local PetUi = {}

local player = Players.LocalPlayer

local hatchRemote: RemoteEvent? = nil
local equipRemote: RemoteEvent? = nil

local inventoryList: Frame? = nil

local RARITY_COLORS = {
	Common = Color3.fromRGB(160, 160, 160),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(60, 130, 255),
	Epic = Color3.fromRGB(160, 60, 255),
	Legendary = Color3.fromRGB(255, 215, 0),
	Mythic = Color3.fromRGB(255, 0, 120),
}
local function rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or Color3.fromRGB(160, 160, 160)
end

local function isEquipped(petId: string): boolean
	local list = player:GetAttribute("EquippedPets") or ""
	if list == "" then
		return false
	end
	for id in list:gmatch("[^,]+") do
		if id == petId then
			return true
		end
	end
	return false
end

local function ownsPet(petId: string): boolean
	return player:GetAttribute("PetOwned." .. petId) == true
end

local function scrollList(parent: Frame): ScrollingFrame
	return UI.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = parent,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

local function row(parent: Instance, order: number, height: number): Frame
	return UI.create("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = UI.Palette.panelLight,
		Parent = parent,
	}, { UI.corner(10) })
end

-- ============================== PETS TAB (inventory) ==============================

local function rebuildInventory()
	if not inventoryList then
		return
	end
	for _, child in inventoryList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local order = 0
	for _, pet in ipairs(Config.Pets) do
		order += 1
		local owned = ownsPet(pet.id)
		local equipped = isEquipped(pet.id)

		local container = row(inventoryList, order, 58)
		container.BackgroundColor3 = if equipped then Color3.fromRGB(64, 96, 74) else UI.Palette.panelLight

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
			Text = pet.emoji,
			TextColor3 = Color3.fromRGB(240, 243, 250),
			Font = Enum.Font.FredokaOne,
			TextSize = 28,
			Parent = container,
		})

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(56, 6),
			Size = UDim2.new(1, -170, 0, 22),
			BackgroundTransparency = 1,
			Text = if owned then pet.name else "??? " .. pet.name,
			TextColor3 = if owned then UI.Palette.text else UI.Palette.subtext,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 18 }) })

		local bonusText = string.format(
			"%s  •  +%.0f%% dmg  +%.0f%% coins  +%.0f%% xp",
			pet.rarity,
			(pet.damageBonus or 0) * 100,
			(pet.coinsBonus or 0) * 100,
			(pet.xpBonus or 0) * 100
		)
		UI.create("TextLabel", {
			Position = UDim2.fromOffset(56, 30),
			Size = UDim2.new(1, -170, 0, 18),
			BackgroundTransparency = 1,
			Text = if owned then bonusText else "Hatch the Basic Egg to discover",
			TextColor3 = rarityColor(pet.rarity),
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 13 }) })

		local btn = UI.button({
			Text = if not owned then "LOCKED" elseif equipped then "EQUIPPED" else "EQUIP",
			Size = UDim2.fromOffset(92, 36),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Color = if not owned then UI.Palette.locked elseif equipped then UI.Palette.good else UI.Palette.accent,
			Parent = container,
		})
		btn.Active = owned and not equipped
		btn.Activated:Connect(function()
			if owned and not equipped and equipRemote then
				equipRemote:FireServer(pet.id)
				task.defer(rebuildInventory)
			end
		end)
	end
end

-- ============================== EGGS TAB ==============================

local function buildEggsTab(parent: Frame)
	local list = scrollList(parent)
	local order = 0
	local anyVisible = false

	for _, egg in ipairs(Config.Eggs) do
		anyVisible = true
		order += 1
		local container = row(list, order, 78)

		UI.create("TextLabel", {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -130, 0, 26),
			BackgroundTransparency = 1,
			Text = egg.emoji .. " " .. egg.name,
			TextColor3 = UI.Palette.accent,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 20 }) })

		-- Odds line: show real configured hatch chances.
		local oddsParts = {}
		for _, petId in ipairs(egg.petIds) do
			for _, pet in ipairs(Config.Pets) do
				if pet.id == petId then
					table.insert(oddsParts, string.format("%s %.0f%%", pet.name, pet.hatchChance))
					break
				end
			end
		end
		UI.create("TextLabel", {
			Position = UDim2.fromOffset(12, 34),
			Size = UDim2.new(1, -130, 0, 34),
			BackgroundTransparency = 1,
			Text = "Odds: " .. table.concat(oddsParts, "  •  "),
			TextColor3 = UI.Palette.subtext,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = container,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 13 }) })

		UI.button({
			Text = string.format("HATCH 🪙%s", Formulas.abbreviate(egg.cost)),
			Size = UDim2.fromOffset(104, 44),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Color = UI.Palette.good,
			MaxTextSize = 16,
			Parent = container,
		}).Activated
			:Connect(function()
				if hatchRemote then
					hatchRemote:FireServer(egg.id)
				end
			end)
	end

	if not anyVisible then
		UI.create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundTransparency = 1,
			Text = "No eggs available yet.",
			TextColor3 = UI.Palette.subtext,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			Parent = list,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 22 }) })
	end
end

-- ============================== WINDOW ==============================

function PetUi.build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		hatchRemote = remotes:WaitForChild("HatchEgg", 10)
		equipRemote = remotes:WaitForChild("EquipPet", 10)
	end

	local content = UI.window("Pets", "🐾 Pets & Eggs", UDim2.fromOffset(520, 440))

	local tabBar = UI.create("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = content,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
		}),
	})

	local pages = UI.create("Frame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		Parent = content,
	})

	local eggsPage = UI.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = pages })
	local petsPage = UI.create(
		"Frame",
		{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = pages }
	)

	inventoryList = UI.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = petsPage,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = inventoryList,
		}),
	})

	buildEggsTab(eggsPage)

	local eggsTab, petsTab
	local function selectTab(showEggs: boolean)
		eggsPage.Visible = showEggs
		petsPage.Visible = not showEggs
		eggsTab.BackgroundColor3 = if showEggs then UI.Palette.accent else UI.Palette.panelLight
		eggsTab.TextColor3 = if showEggs then Color3.fromRGB(30, 30, 30) else UI.Palette.text
		petsTab.BackgroundColor3 = if showEggs then UI.Palette.panelLight else UI.Palette.accent
		petsTab.TextColor3 = if showEggs then UI.Palette.text else Color3.fromRGB(30, 30, 30)
		if not showEggs then
			rebuildInventory()
		end
	end

	eggsTab = UI.button({ Text = "🥚 Eggs", Size = UDim2.fromOffset(120, 40), LayoutOrder = 1, Parent = tabBar })
	petsTab = UI.button({
		Text = "🐾 Pets",
		Size = UDim2.fromOffset(120, 40),
		LayoutOrder = 2,
		Color = UI.Palette.panelLight,
		TextColor = UI.Palette.text,
		Parent = tabBar,
	})
	eggsTab.Activated:Connect(function()
		selectTab(true)
	end)
	petsTab.Activated:Connect(function()
		selectTab(false)
	end)
	selectTab(true)

	-- Refresh inventory when ownership/equipped state changes (server-driven).
	player:GetAttributeChangedSignal("EquippedPets"):Connect(rebuildInventory)
	for _, pet in ipairs(Config.Pets) do
		player:GetAttributeChangedSignal("PetOwned." .. pet.id):Connect(rebuildInventory)
	end

	-- Refresh after a hatch result is confirmed by the server.
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local hatchResult = remotes and remotes:FindFirstChild("HatchResult")
	if hatchResult then
		hatchResult.OnClientEvent:Connect(function()
			rebuildInventory()
		end)
	end
end

return PetUi
