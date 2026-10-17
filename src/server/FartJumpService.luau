-- FartJumpService.luau
-- The signature ability, server-authoritative. The client only signals
-- intent; the server validates eligibility (cooldown, alive, grounded) and
-- computes the impulse from the player's real strength (power) with
-- diminishing returns and hard caps. Any client-supplied velocity is ignored.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local FartJumpService = {}

local Data
local lastJump = {} -- [Player] = os.clock() of last accepted jump

local FJ = Config.FartJump

-- Strength -> upward impulse, with diminishing returns past the soft cap and
-- a hard ceiling. Never unbounded regardless of how large power grows.
local function upwardImpulseFor(power: number): number
	local cfg = FJ
	local linear = cfg.basePower + power * cfg.powerPerStrength
	local scaled = linear
	if power > cfg.strengthSoftCap then
		-- Apply square-root scaling to the amount above the soft cap.
		local over = power - cfg.strengthSoftCap
		local linearAtCap = cfg.basePower + cfg.strengthSoftCap * cfg.powerPerStrength
		scaled = linearAtCap + math.sqrt(over) * cfg.powerPerStrength * cfg.diminishingFactor
	end
	return math.clamp(scaled, 0, cfg.maxUpImpulse)
end

-- Grounded check: raycast a short distance down from the root part.
local function isGrounded(root: BasePart): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = root.Parent
	local exclude = {}
	if character then
		for _, d in character:GetDescendants() do
			table.insert(exclude, d)
		end
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(root.Position, Vector3.new(0, -3.5, 0), params)
	return result ~= nil
end

function FartJumpService.start(dataService)
	Data = dataService

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local jumpRemote = remotes:FindFirstChild("FartJump")
	assert(jumpRemote, "[FartJumpService] Missing 'FartJump' RemoteEvent (expected from init.server.luau)")

	-- Client sends ONLY its intended direction (a unit-ish vector). Magnitude
	-- is computed and clamped entirely on the server.
	jumpRemote.OnServerEvent:Connect(function(player, moveDir)
		if not FJ.enabled then
			return
		end
		local profile = Data.get(player)
		if not profile then
			return
		end

		-- Rate limit.
		local now = os.clock()
		if now - (lastJump[player] or 0) < FJ.cooldown then
			return
		end

		local character = player.Character
		if not character then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		if humanoid:GetState() == Enum.HumanoidStateType.Dead then
			return
		end
		if FJ.groundedOnly and not isGrounded(root) then
			return
		end

		-- Direction: sanitize client input to a horizontal unit vector.
		local dir = Vector3.new(0, 0, -1)
		if typeof(moveDir) == "Vector3" then
			local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
			if flat.Magnitude > 0.05 then
				dir = flat.Unit
			end
		end

		-- Compute bounded impulse from server-side strength.
		local up = upwardImpulseFor(profile.power)
		local forward = math.min(up * FJ.forwardFactor, FJ.maxForwardImpulse)
		local velocity = Vector3.new(dir.X * forward, up, dir.Z * forward)

		-- Commit: set cooldown BEFORE applying so a rapid double-fire can't
		-- slip through, then apply the impulse.
		lastJump[player] = now
		root:ApplyImpulse(velocity * root.AssemblyMass)
		Data.setMilestone(player, "first_fartjump")
		pcall(function()
			require(script.Parent.QuestService).completeMilestone(player, "first_fartjump")
		end)

		-- Replicate a cooldown hint so the client can show the indicator
		-- without trusting it for authority.
		player:SetAttribute("FartJumpReadyAt", now + FJ.cooldown)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastJump[player] = nil
	end)
end

return FartJumpService
