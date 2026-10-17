-- AdminUi.luau
-- Minimal server-authoritative admin panel. Only visible to staff.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)

local AdminUi = {}

local player = Players.LocalPlayer
local adminRemote = nil

function AdminUi.build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		adminRemote = remotes:WaitForChild("AdminCommand", 10)
	end

	local gui = UI.create("ScreenGui", {
		Name = "Admin",
		ResetOnSpawn = false,
		DisplayOrder = 30,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local frame = UI.create("Frame", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 260),
		BackgroundColor3 = UI.Palette.panel,
		Visible = false,
		Parent = gui,
	}, { UI.corner(14), UI.stroke(UI.Palette.accent, 2) })

	UI.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "🛠 Admin Panel",
		TextColor3 = UI.Palette.text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Parent = frame,
	})

	local content = UI.create("Frame", {
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 1, -56),
		BackgroundTransparency = 1,
		Parent = frame,
	}, {
		UI.create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
		}),
	})

	local function button(text, command, payload)
		local btn = UI.button({
			Text = text,
			Size = UDim2.new(1, 0, 0, 40),
			Parent = content,
		})
		btn.Activated:Connect(function()
			if adminRemote then
				adminRemote:FireServer(command, payload or {})
			end
		end)
		return btn
	end

	button("Diagnostics", "diagnostics", {})
	button("Toggle Sandbox", "toggleSandbox", {})
	button("Grant 1000 coins (self)", "grantCoins", { userId = player.UserId, amount = 1000 })
	button("Grant Brainrot: skibidi_slayer", "grantBrainrot", { userId = player.UserId, brainrotId = "skibidi_slayer" })
	button("Grant Pet: gold_fish", "grantPet", { userId = player.UserId, petId = "gold_fish" })
	button("Spawn Test Building", "spawnTestBuilding", {})
	button("Reset Boss", "resetBoss", {})
	button("Inspect Self", "inspect", { userId = player.UserId })

	local function updateVisibility()
		local role = player:GetAttribute("StaffRole")
		frame.Visible = false
		gui.Enabled = role ~= nil and role ~= ""
	end
	player:GetAttributeChangedSignal("StaffRole"):Connect(updateVisibility)
	updateVisibility()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F4 then
			local role = player:GetAttribute("StaffRole")
			if role and role ~= "" then
				frame.Visible = not frame.Visible
			end
		end
	end)
end

return AdminUi
