-- PvPUi.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require(script.Parent.UI)

local PvPUi = {}

local player = Players.LocalPlayer
local challengeRemote, acceptRemote, attackRemote, updateRemote

function PvPUi.build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		challengeRemote = remotes:WaitForChild("PvPChallenge", 10)
		acceptRemote = remotes:WaitForChild("PvPAccept", 10)
		attackRemote = remotes:WaitForChild("PvPAttack", 10)
		updateRemote = remotes:WaitForChild("PvPUpdate", 10)
	end

	local content = UI.window("PvP", "⚔ PvP", UDim2.fromOffset(400, 360))
	local list = UI.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, { UI.create("UIListLayout", { Padding = UDim.new(0, 6) }) })

	local status = UI.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0.72, 0),
		BackgroundTransparency = 1,
		Text = "Challenge a player to 1v1.",
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextWrapped = true,
		Parent = content,
	})

	local function refresh()
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, p in Players:GetPlayers() do
			if p ~= player then
				local row = UI.create("Frame", {
					Size = UDim2.new(1, -8, 0, 36),
					BackgroundColor3 = UI.Palette.panelLight,
					Parent = list,
				}, { UI.corner(8) })
				UI.create("TextLabel", {
					Size = UDim2.new(1, -90, 1, 0),
					Position = UDim2.fromOffset(8, 0),
					BackgroundTransparency = 1,
					Text = p.Name,
					TextColor3 = UI.Palette.text,
					Font = Enum.Font.GothamBold,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					Parent = row,
				})
				local btn = UI.button({
					Text = "Challenge",
					Size = UDim2.fromOffset(80, 28),
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					Parent = row,
				})
				btn.Activated:Connect(function()
					if challengeRemote then
						challengeRemote:FireServer(p.UserId)
					end
				end)
			end
		end
	end
	Players.PlayerAdded:Connect(refresh)
	Players.PlayerRemoving:Connect(refresh)
	refresh()

	local acceptBtn = UI.button({
		Text = "Accept Challenge",
		Size = UDim2.new(1, 0, 0, 32),
		Position = UDim2.new(0, 0, 0.9, 0),
		Parent = content,
	})
	acceptBtn.Activated:Connect(function()
		if acceptRemote then
			acceptRemote:FireServer()
		end
	end)

	if updateRemote then
		updateRemote.OnClientEvent:Connect(function(state, payload)
			if state == "started" then
				status.Text = "Match started vs " .. tostring(payload)
			elseif state == "health" then
				status.Text = "HP: " .. tostring(payload.a) .. " / " .. tostring(payload.b)
			elseif state == "ended" then
				status.Text = "Match ended. Winner: " .. tostring(payload)
			end
		end)
	end
end

return PvPUi
