-- Onboarding.luau
-- First-session objective card. Shows ONE short objective at a time and
-- advances when the server records the corresponding milestone (MS.* player
-- attribute). Completed steps never repeat (milestones are persisted by the
-- server), and the card disappears once every step is done. Survives respawn
-- because the ScreenGui uses ResetOnSpawn = false.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UI = require(script.Parent.UI)

local Onboarding = {}

local player = Players.LocalPlayer

-- Ordered first-session steps. `milestone` is set server-side when done.
-- `hint` tells the player exactly what to do, in one short line.
local STEPS = {
	{ milestone = "first_hit", title = "Smash a building", hint = "Walk up to a house and CLICK it to attack." },
	{
		milestone = "first_destroy",
		title = "Destroy a building",
		hint = "Keep hitting it until it collapses for coins + XP.",
	},
	{
		milestone = "first_upgrade",
		title = "Buy your first gear",
		hint = "Open 🛒 Shop → Gear and buy Foam Gloves.",
	},
	{
		milestone = "first_fartjump",
		title = "Try the Fart Jump",
		hint = "Press F (or tap 💨 JUMP) to launch into the air.",
	},
}

local card: Frame? = nil
local titleLabel: TextLabel? = nil
local hintLabel: TextLabel? = nil
local progressLabel: TextLabel? = nil

local function isDone(step): boolean
	return player:GetAttribute("MS." .. step.milestone) == true
end

local function firstPending(): number?
	for i, step in ipairs(STEPS) do
		if not isDone(step) then
			return i
		end
	end
	return nil
end

local function completedCount(): number
	local n = 0
	for _, step in ipairs(STEPS) do
		if isDone(step) then
			n += 1
		end
	end
	return n
end

local function refresh()
	if not card or not titleLabel then
		return
	end
	local idx = firstPending()
	if not idx then
		-- All steps complete: fade the card out and stop showing it.
		card.Visible = false
		return
	end
	local step = STEPS[idx]
	titleLabel.Text = `🎯 {step.title}`
	if hintLabel then
		hintLabel.Text = step.hint
	end
	if progressLabel then
		progressLabel.Text = `Step {idx} / {#STEPS}`
	end
	card.Visible = true
end

function Onboarding.build()
	local gui = UI.create("ScreenGui", {
		Name = "Onboarding",
		ResetOnSpawn = false,
		DisplayOrder = 6,
		Parent = player:WaitForChild("PlayerGui"),
	})

	card = UI.create("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 100),
		Size = UDim2.fromOffset(340, 96),
		BackgroundColor3 = UI.Palette.panel,
		BackgroundTransparency = 0.08,
		Parent = gui,
	}, {
		UI.corner(14),
		UI.stroke(UI.Palette.accent, 2),
	})

	titleLabel = UI.create("TextLabel", {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 26),
		BackgroundTransparency = 1,
		TextColor3 = UI.Palette.text,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 20 }) })

	hintLabel = UI.create("TextLabel", {
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.new(1, -28, 0, 36),
		BackgroundTransparency = 1,
		TextColor3 = UI.Palette.subtext,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	}, { UI.create("UITextSizeConstraint", { MaxTextSize = 14 }) })

	progressLabel = UI.create("TextLabel", {
		Position = UDim2.fromOffset(14, 76),
		Size = UDim2.new(1, -28, 0, 16),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = UI.Palette.accent,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	-- Advance whenever the server records any milestone.
	for _, step in ipairs(STEPS) do
		player:GetAttributeChangedSignal("MS." .. step.milestone):Connect(function()
			if isDone(step) then
				-- Little confirm nudge, then move to the next objective.
				if card then
					TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.fromOffset(328, 88),
					}):Play()
					task.delay(0.18, function()
						if card then
							TweenService
								:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
									Size = UDim2.fromOffset(340, 96),
								})
								:Play()
						end
					end)
				end
			end
			refresh()
		end)
	end

	refresh()
end

return Onboarding
