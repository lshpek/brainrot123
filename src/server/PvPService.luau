-- PvPService.luau
-- Server-authoritative 1v1 PvP matches.
--
-- MATCH SECURITY:
--   * challenges expire, self-challenge and multi-match are rejected
--   * a match binds both participants on the server
--   * attacks validate match membership, opponent identity, range, state and cooldown
--   * rewards are granted exactly once to the winner; disconnect/loss cleans up

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PvPService = {}

local Data
local matches = {} -- [matchId] = match
local playerMatch = {} -- [Player] = matchId
local pendingChallenges = {} -- [targetUserId] = { challengerUserId, expiresAt }
local lastAttack = {} -- [Player] = os.clock()

local CHALLENGE_TTL = 30 -- seconds

-- One dedicated arena per world. The local dev world is Settlement; when real
-- Places are configured, WorldService reports the player's current world.
local ARENAS = {
	settlement = { center = Vector3.new(0, 0, -50), radius = 30 },
	village = { center = Vector3.new(0, 0, 260), radius = 30 },
	city = { center = Vector3.new(140, 0, 0), radius = 30 },
	megacity = { center = Vector3.new(280, 0, 0), radius = 30 },
	space_city = { center = Vector3.new(420, 0, 0), radius = 30 },
}

local function getArena(worldId)
	return ARENAS[worldId] or ARENAS.settlement
end

-- Best-effort current world per player. Defaults to Settlement (the local
-- dev world). Updated by WorldService/teleport flow when Places are live.
local playerWorld = {} -- [Player] = worldId

function PvPService.setWorld(player: Player, worldId: string)
	if type(worldId) ~= "string" then
		return
	end
	playerWorld[player] = worldId
end

local function currentWorld(player)
	return playerWorld[player] or "settlement"
end

local function cleanChallenge(targetUserId)
	pendingChallenges[targetUserId] = nil
end

local function endMatch(match, winner)
	if not match or not match.active then
		return -- idempotent: endMatch may be called from multiple paths
	end
	match.active = false
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notify = remotes and remotes:FindFirstChild("Notify")
	local update = remotes and remotes:FindFirstChild("PvPUpdate")

	if winner then
		local profile = Data and Data.get(winner)
		if profile then
			-- Reward exactly once, from server-controlled value only.
			Data.addCoins(winner, 100)
		end
		if notify then
			notify:FireClient(winner, "success", "You won the PvP match!")
		end
		local loser = (winner == match.playerA) and match.playerB or match.playerA
		if loser and notify then
			notify:FireClient(loser, "error", "You lost the PvP match.")
		end
	end
	if update then
		local winnerName = winner and winner.Name or "none"
		update:FireClient(match.playerA, "ended", winnerName)
		update:FireClient(match.playerB, "ended", winnerName)
	end

	-- Unbind players from the match.
	if match.playerA then
		playerMatch[match.playerA] = nil
	end
	if match.playerB then
		playerMatch[match.playerB] = nil
	end

	-- Respawn participants after a short delay so they aren't left in the arena.
	task.delay(2, function()
		if match.playerA and match.playerA.Parent then
			pcall(function()
				match.playerA:LoadCharacter()
			end)
		end
		if match.playerB and match.playerB.Parent then
			pcall(function()
				match.playerB:LoadCharacter()
			end)
		end
	end)

	matches[match.id] = nil
end

function PvPService.start(dataService)
	Data = dataService
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local challengeRemote = remotes:FindFirstChild("PvPChallenge")
	if not challengeRemote then
		local r = Instance.new("RemoteEvent")
		r.Name = "PvPChallenge"
		r.Parent = remotes
		challengeRemote = r
	end
	local acceptRemote = remotes:FindFirstChild("PvPAccept")
	if not acceptRemote then
		local r = Instance.new("RemoteEvent")
		r.Name = "PvPAccept"
		r.Parent = remotes
		acceptRemote = r
	end
	local attackRemote = remotes:FindFirstChild("PvPAttack")
	if not attackRemote then
		local r = Instance.new("RemoteEvent")
		r.Name = "PvPAttack"
		r.Parent = remotes
		attackRemote = r
	end

	-- Challenge expiry sweep.
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for targetUserId, entry in pairs(pendingChallenges) do
				if now > entry.expiresAt then
					cleanChallenge(targetUserId)
					local target = Players:GetPlayerByUserId(targetUserId)
					if target then
						local notify = remotes:FindFirstChild("Notify")
						if notify then
							notify:FireClient(target, "info", "PvP challenge expired.")
						end
					end
				end
			end
		end
	end)

	challengeRemote.OnServerEvent:Connect(function(player, targetUserId)
		targetUserId = tonumber(targetUserId)
		if not targetUserId then
			return
	end
		if playerMatch[player] then
			return -- already in a match
		end
		if player.UserId == targetUserId then
			return -- no self-challenge
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return
		end
		if playerMatch[target] then
			return -- target already in a match
		end
		pendingChallenges[target.UserId] = { challengerUserId = player.UserId, expiresAt = os.clock() + CHALLENGE_TTL }
		local notify = remotes:FindFirstChild("Notify")
		if notify then
			notify:FireClient(target, "info", player.Name .. " challenged you to 1v1! (expires in 30s)")
		end
		if notify then
			notify:FireClient(player, "info", "Challenge sent to " .. target.Name .. ".")
		end
	end)

	acceptRemote.OnServerEvent:Connect(function(player)
		local entry = pendingChallenges[player.UserId]
		if not entry then
			return
		end
		if os.clock() > entry.expiresAt then
			cleanChallenge(player.UserId)
			return
		end
		cleanChallenge(player.UserId)
		local challenger = Players:GetPlayerByUserId(entry.challengerUserId)
		if not challenger or playerMatch[challenger] or playerMatch[player] or challenger == player then
			return
		end
		local matchId = tostring(os.clock()) .. "_" .. tostring(player.UserId)
		local arena = getArena(currentWorld(player))
		local center = arena.center
		local match = {
			id = matchId,
			playerA = challenger,
			playerB = player,
			healthA = 100,
			healthB = 100,
			maxHealthA = 100,
			maxHealthB = 100,
			active = true,
			arena = arena,
		}
		local pa = Data and Data.get(challenger)
		local pb = Data and Data.get(player)
		match.healthA = 100 + math.floor(((pa and pa.power) or 0) / 100)
		match.healthB = 100 + math.floor(((pb and pb.power) or 0) / 100)
		match.maxHealthA = match.healthA
		match.maxHealthB = match.healthB
		matches[matchId] = match
		playerMatch[challenger] = matchId
		playerMatch[player] = matchId

		local function teleport(p, offset)
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(center + offset)
			end
		end
		teleport(challenger, Vector3.new(-10, 0, 0))
		teleport(player, Vector3.new(10, 0, 0))

		local update = remotes:FindFirstChild("PvPUpdate")
		if update then
			update:FireClient(challenger, "started", player.Name)
			update:FireClient(player, "started", challenger.Name)
			update:FireClient(challenger, "health", {
				a = match.healthA, b = match.healthB, maxA = match.maxHealthA, maxB = match.maxHealthB,
			})
			update:FireClient(player, "health", {
				a = match.healthA, b = match.healthB, maxA = match.maxHealthA, maxB = match.maxHealthB,
			})
		end
	end)

	attackRemote.OnServerEvent:Connect(function(player, targetUserId)
		targetUserId = tonumber(targetUserId)
		if not targetUserId then
			return
		end
		local matchId = playerMatch[player]
		if not matchId then
			return -- not in a match
		end
		local match = matches[matchId]
		if not match or not match.active then
			return
		end
		local opponent = (player == match.playerA) and match.playerB or match.playerA
		if not opponent or opponent.UserId ~= targetUserId then
			return -- can only attack your bound opponent
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local oroot = opponent.Character and opponent.Character:FindFirstChild("HumanoidRootPart")
		if not root or not oroot then
			return
		end
		if (root.Position - oroot.Position).Magnitude > 20 then
			return -- range check from actual position
		end
		local now = os.clock()
		if now - (lastAttack[player] or 0) < 0.8 then
			return -- cooldown
		end
		lastAttack[player] = now

		local bs = nil
		pcall(function()
			bs = require(script.Parent.BrainrotService)
		end)
		local damage = bs and bs.getEquippedDamage(player) or 10
		if damage <= 0 then
			damage = 10
		end

		if player == match.playerA then
			match.healthB -= damage
			if match.healthB < 0 then
				match.healthB = 0
			end
		else
			match.healthA -= damage
			if match.healthA < 0 then
				match.healthA = 0
			end
		end

		local update = remotes:FindFirstChild("PvPUpdate")
		if update then
			local payload = { a = match.healthA, b = match.healthB, maxA = match.maxHealthA, maxB = match.maxHealthB }
			update:FireClient(match.playerA, "health", payload)
			update:FireClient(match.playerB, "health", payload)
		end

		if match.healthA <= 0 or match.healthB <= 0 then
			local winner = (match.healthA <= 0) and match.playerB or match.playerA
			endMatch(match, winner)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		playerWorld[player] = nil
		local matchId = playerMatch[player]
		if matchId then
			local match = matches[matchId]
			if match and match.active then
				local winner = (player == match.playerA) and match.playerB or match.playerA
				endMatch(match, winner)
			end
		end
	end)
end

function PvPService.getMatch(player)
	return playerMatch[player]
end

function PvPService.getArena(worldId)
	return getArena(worldId)
end

function PvPService.isInMatch(player)
	return playerMatch[player] ~= nil
end

return PvPService
