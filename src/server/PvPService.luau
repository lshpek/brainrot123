-- PvPService.luau
-- Server-authoritative 1v1 PvP matches.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PvPService = {}

local Data
local matches = {} -- [matchId] = match
local playerMatch = {} -- [Player] = matchId
local pendingChallenges = {} -- [targetUserId] = challengerUserId
local lastAttack = {}

local ARENAS = {
	settlement = { center = Vector3.new(0, 0, -50), radius = 30 },
}

local function getArena(worldId)
	return ARENAS[worldId] or ARENAS.settlement
end

local function currentWorld(player)
	-- Best-effort: use profile rebirths? Default settlement.
	return "settlement"
end

local function endMatch(match, winner)
	match.active = false
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local notify = remotes and remotes:FindFirstChild("Notify")
	local update = remotes and remotes:FindFirstChild("PvPUpdate")
	if winner then
		local profile = Data and Data.get(winner)
		if profile then
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
		update:FireClient(match.playerA, "ended", winner and winner.Name or "none")
		update:FireClient(match.playerB, "ended", winner and winner.Name or "none")
	end
	-- cleanup
	playerMatch[match.playerA] = nil
	playerMatch[match.playerB] = nil
	-- respawn
	task.delay(2, function()
		if match.playerA and match.playerA.Parent then
			match.playerA:LoadCharacter()
		end
		if match.playerB and match.playerB.Parent then
			match.playerB:LoadCharacter()
		end
	end)
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

	challengeRemote.OnServerEvent:Connect(function(player, targetUserId)
		targetUserId = tonumber(targetUserId)
		if not targetUserId then
			return
		end
		if playerMatch[player] then
			return
		end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target or target == player then
			return
		end
		if playerMatch[target] then
			return
		end
		pendingChallenges[target.UserId] = player.UserId
		local notify = remotes:FindFirstChild("Notify")
		if notify then
			notify:FireClient(target, "info", player.Name .. " challenged you to PvP! (accept via menu)")
		end
	end)

	acceptRemote.OnServerEvent:Connect(function(player)
		local challengerId = pendingChallenges[player.UserId]
		if not challengerId then
			return
		end
		pendingChallenges[player.UserId] = nil
		local challenger = Players:GetPlayerByUserId(challengerId)
		if not challenger or playerMatch[challenger] or playerMatch[player] then
			return
		end
		-- create match
		local matchId = tostring(os.clock()) .. "_" .. tostring(player.UserId)
		local arena = getArena(currentWorld(player))
		local center = arena.center
		local match = {
			id = matchId,
			playerA = challenger,
			playerB = player,
			healthA = 100,
			healthB = 100,
			maxHealth = 100,
			arena = arena,
			active = true,
		}
		-- scale health by power
		local pa = Data and Data.get(challenger)
		local pb = Data and Data.get(player)
		match.healthA = 100 + math.floor(((pa and pa.power) or 0) / 100)
		match.healthB = 100 + math.floor(((pb and pb.power) or 0) / 100)
		match.maxHealthA = match.healthA
		match.maxHealthB = match.healthB
		matches[matchId] = match
		playerMatch[challenger] = matchId
		playerMatch[player] = matchId

		-- teleport
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
		end
	end)

	attackRemote.OnServerEvent:Connect(function(player, targetUserId)
		targetUserId = tonumber(targetUserId)
		if not targetUserId then
			return
		end
		local matchId = playerMatch[player]
		if not matchId then
			return
		end
		local match = matches[matchId]
		if not match or not match.active then
			return
		end
		local opponent = (player == match.playerA) and match.playerB or match.playerA
		if not opponent or opponent.UserId ~= targetUserId then
			return
		end
		-- range check
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local oroot = opponent.Character and opponent.Character:FindFirstChild("HumanoidRootPart")
		if not root or not oroot then
			return
		end
		if (root.Position - oroot.Position).Magnitude > 20 then
			return
		end
		-- cooldown
		local now = os.clock()
		if now - (lastAttack[player] or 0) < 0.8 then
			return
		end
		lastAttack[player] = now

		local bs = nil
		pcall(function()
			bs = require(script.Parent.BrainrotService)
		end)
		local damage = bs and bs.getEquippedDamage(player) or 10

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
			update:FireClient(
				match.playerA,
				"health",
				{ a = match.healthA, b = match.healthB, maxA = match.maxHealthA, maxB = match.maxHealthB }
			)
			update:FireClient(
				match.playerB,
				"health",
				{ a = match.healthA, b = match.healthB, maxA = match.maxHealthA, maxB = match.maxHealthB }
			)
		end

		if match.healthA <= 0 or match.healthB <= 0 then
			local winner = (match.healthA <= 0) and match.playerB or match.playerA
			endMatch(match, winner)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local matchId = playerMatch[player]
		if matchId then
			local match = matches[matchId]
			if match and match.active then
				local winner = (player == match.playerA) and match.playerB or match.playerA
				endMatch(match, winner)
			end
		end
		lastAttack[player] = nil
	end)
end

function PvPService.getMatch(player)
	return playerMatch[player]
end

return PvPService
