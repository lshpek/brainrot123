-- PvPUi.luau
-- Client UI for 1v1 PvP: challenges, accept/decline, active match with both
-- health bars, a real attack control bound to the server match, and results.
-- All combat decisions are made server-side; this UI only sends intent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local PvPUi = {}

local player = Players.LocalPlayer
local challengeRemote, acceptRemote, attackRemote, updateRemote

local content: Frame? = nil
local list: ScrollingFrame? = nil
local status: TextLabel? = nil
local matchFrame: Frame? = nil
local attackBtn: TextButton? = nil
local healthBarA: Frame? = nil
local healthBarB: Frame? = nil
local oppLabel: TextLabel? = nil

local matchActive = false
local opponentName = "none"

local function setStatus(text: string, color: Color3)
	if status then
		status.Text = text
		status.TextColor3 = color or UI.Palette.subtext
	end
end

local function showMatch(show: boolean)
	if matchFrame then
		matchFrame.Visible = show
	end
	if attackBtn then
		attackBtn.Visible = show
	end
end

local function refreshHealth(a: number, b: number, maxA: number, maxB: number)
	if healthBarA and maxA and maxA > 0 then
		healthBarA.Size = UDim2.fromScale(math.clamp(a / maxA, 0, 1), 1)
	end
	if healthBarB and maxB and maxB > 0 then
		healthBarB.Size = UDim2.fromScale(math.clamp(b / maxB, 0, 1), 1)
	end
end

local function buildPlayerRow(parent, target: Player)
	local row = UI.create("Frame", {
		Size = UDim2.new(1, -8, 0, 36),
		BackgroundColor3 = UI.Palette.panelLight,
		Parent = parent,
	}, { UI.corner(8) })
	UI.create("TextLabel", {
		Size = UDim2.new(1, -150, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Text = target.Name,
		TextColor3 = UI.Palette.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 18 }) })
	local btn = UI.button({
		Text = "Challenge",
		Size = UDim2.fromOffset(80, 28),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Parent = row,
	})
	btn.Activated:Connect(function()
		if challengeRemote then
			challengeRemote:FireServer(target.UserId)
		end
	end)
	return row
end

local function refreshList()
	if not list then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for _, p in Players:GetPlayers() do
		if p ~= player then
			buildPlayerRow(list, p)
		end
	end
end

function PvPUi.build()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if remotes then
		challengeRemote = remotes:WaitForChild("PvPChallenge", 10)
		acceptRemote = remotes:WaitForChild("PvPAccept", 10)
		attackRemote = remotes:WaitForChild("PvPAttack", 10)
		updateRemote = remotes:WaitForChild("PvPUpdate", 10)
	end

	content = UI.window("PvP", "⚔ PvP 1v1", UDim2.fromOffset(460, 520))

	local header = UI.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "Challenge another player to a 1v1 match.",
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextWrapped = true,
		Parent = content,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 16 }) })

	list = UI.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 0.42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = content,
	}, { UI.create("UIListLayout", { Padding = UDim.new(0, 6) }) })

	status = UI.create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Text = "Waiting...",
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Parent = content,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 16 }) })

	-- Incoming-challenge accept row (shown when challenged).
	local acceptBtn = UI.button({
		Text = "Accept Challenge",
		Size = UDim2.fromOffset(150, 34),
		Visible = false,
		Parent = content,
	})
	acceptBtn.Activated:Connect(function()
		if acceptRemote then
			acceptRemote:FireServer()
		end
		acceptBtn.Visible = false
	end)

	-- ============================== ACTIVE MATCH VIEW ==============================
	matchFrame = UI.create("Frame", {
		Size = UDim2.new(1, 0, 0, 170),
		BackgroundColor3 = UI.Palette.panelLight,
		Visible = false,
		Parent = content,
	}, { UI.corner(12) })

	UI.create("TextLabel", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 22),
		BackgroundTransparency = 1,
		Text = "MATCH ACTIVE",
		TextColor3 = UI.Palette.accent,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		Parent = matchFrame,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 18 }) })

	oppLabel = UI.create("TextLabel", {
		Position = UDim2.fromOffset(12, 34),
		Size = UDim2.new(1, -24, 0, 20),
		BackgroundTransparency = 1,
		Text = "Opponent: none",
		TextColor3 = UI.Palette.text,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		Parent = matchFrame,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 16 }) })

	local function healthBarRow(order, labelText, barColor)
		local row = UI.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -24, 0, 26),
			BackgroundTransparency = 1,
			Parent = matchFrame,
		})
		UI.create("TextLabel", {
			Size = UDim2.fromOffset(120, 20),
			BackgroundTransparency = 1,
			Text = labelText,
			TextColor3 = UI.Palette.subtext,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		}, { UI.create("UITextSizeConstraint", { MaxTextSize = 14 }) })
		local back = UI.create("Frame", {
			Position = UDim2.new(1, -140, 0, 2),
			Size = UDim2.fromOffset(128, 14),
			BackgroundColor3 = Color3.fromRGB(28, 28, 32),
			Parent = row,
		}, { UI.corner(6) })
		local fill = UI.create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = barColor,
			BorderSizePixel = 0,
			Parent = back,
		}, { UI.corner(6) })
		return fill
	end
	healthBarA = healthBarRow(1, "You", UI.Palette.good)
	healthBarB = healthBarRow(2, "Opponent", UI.Palette.bad)

	attackBtn = UI.button({
		Text = "⚔ ATTACK",
		Size = UDim2.fromOffset(120, 40),
		Position = UDim2.new(0.5, -60, 0, 118),
		Color = UI.Palette.bad,
		Parent = matchFrame,
	})
	attackBtn.Visible = false
	attackBtn.Activated:Connect(function()
		if attackRemote and matchActive and opponentName ~= "none" then
			-- Find opponent player object by name to get UserId.
			local target = Players:FindFirstChild(opponentName)
			if target then
				attackRemote:FireServer(target.UserId)
			end
		end
	end)

	-- ============================== WIRE REMOTES ==============================
	Players.PlayerAdded:Connect(refreshList)
	Players.PlayerRemoving:Connect(refreshList)
	refreshList()

	if updateRemote then
		updateRemote.OnClientEvent:Connect(function(state, payload)
			if state == "started" then
				matchActive = true
				opponentName = tostring(payload)
				setStatus("Match started vs " .. opponentName, UI.Palette.text)
				showMatch(true)
				if oppLabel then
					oppLabel.Text = "Opponent: " .. opponentName
				end
				attackBtn.Visible = true
				refreshHealth(100, 100, 100, 100)
			elseif state == "health" then
				if type(payload) == "table" then
					refreshHealth(payload.a, payload.b, payload.maxA, payload.maxB)
				end
			elseif state == "ended" then
				matchActive = false
				setStatus("Match ended. Winner: " .. tostring(payload), UI.Palette.accent)
				showMatch(false)
				attackBtn.Visible = false
				opponentName = "none"
			end
		end)
	end

	-- Surface incoming challenges from the server (Notify carries info).
	local remotes2 = ReplicatedStorage:FindFirstChild("Remotes")
	local notify = remotes2 and remotes2:FindFirstChild("Notify")
	if notify then
		notify.OnClientEvent:Connect(function(kind, message)
			if kind == "info" and type(message) == "string" and message:find("challenged you", 1, true) then
				setStatus(message, UI.Palette.accent)
				acceptBtn.Visible = true
			end
		end)
	end

	Players.PlayerAdded:Connect(refreshList)
	Players.PlayerRemoving:Connect(refreshList)
end

return PvPUi
