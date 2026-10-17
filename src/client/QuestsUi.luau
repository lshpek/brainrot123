-- QuestsUi.luau
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.Parent.UI)

local QuestsUi = {}

local player = Players.LocalPlayer
local progress = {} -- [questId] = progress
local completed = {}

function QuestsUi.build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	local questRemote = remotes and remotes:WaitForChild("QuestUpdate", 10)
	if questRemote then
		questRemote.OnClientEvent:Connect(function(questId, prog, done)
			progress[questId] = prog
			if done then
				completed[questId] = true
			end
		end)
	end

	local content = UI.window("Quests", "📜 Quests", UDim2.fromOffset(460, 420))
	local list = UI.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, {
		UI.create("UIListLayout", { Padding = UDim.new(0, 8) }),
	})

	for _, q in ipairs(Config.Quests) do
		local row = UI.create("Frame", {
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = UI.Palette.panelLight,
			Parent = list,
		}, { UI.corner(10) })
		UI.create("TextLabel", {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -24, 0, 22),
			BackgroundTransparency = 1,
			Text = q.name,
			TextColor3 = UI.Palette.text,
			Font = Enum.Font.FredokaOne,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 18 }) })
		local desc = UI.create("TextLabel", {
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 28),
			BackgroundTransparency = 1,
			Text = q.description,
			TextColor3 = UI.Palette.subtext,
			Font = Enum.Font.Gotham,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 12 }) })
		-- update text periodically
		task.spawn(function()
			while row.Parent do
				local p = progress[q.id] or 0
				local done = completed[q.id]
				desc.Text = q.description
					.. " ("
					.. tostring(p)
					.. "/"
					.. tostring(q.target)
					.. ")"
					.. (done and " ✅" or "")
				task.wait(1)
			end
		end)
	end
end

return QuestsUi
