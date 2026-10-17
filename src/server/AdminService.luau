-- AdminService.luau
-- Server-authoritative staff roles and validated admin commands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AdminService = {}

local Data
local ownerUserId = nil

local VALID_ROLES = { Owner = true, Admin = true, Moderator = true, Tester = true }
local ROLE_RANK = { Owner = 4, Admin = 3, Moderator = 2, Tester = 1 }

local function resolveOwner()
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync("kiill290")
	end)
	if ok and type(userId) == "number" then
		ownerUserId = userId
	end
end

local function getRole(player)
	if ownerUserId and player.UserId == ownerUserId then
		return "Owner"
	end
	local profile = Data and Data.get(player)
	if profile and type(profile.staffRole) == "string" and VALID_ROLES[profile.staffRole] then
		return profile.staffRole
	end
	return nil
end

local function hasRole(player, minRole)
	local role = getRole(player)
	if not role then
		return false
	end
	return (ROLE_RANK[role] or 0) >= (ROLE_RANK[minRole] or 0)
end

local function isSandbox(player)
	return Data and Data.isSandbox(player) == true
end

local function notify(player, kind, msg)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local n = remotes and remotes:FindFirstChild("Notify")
	if n then
		n:FireClient(player, kind, msg)
	end
end

function AdminService.start(dataService)
	Data = dataService
	resolveOwner()

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local role = getRole(player)
			player:SetAttribute("StaffRole", role or "")
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local role = getRole(player)
			player:SetAttribute("StaffRole", role or "")
		end)
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local commandRemote = remotes:FindFirstChild("AdminCommand")
	if not commandRemote then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "AdminCommand"
		remote.Parent = remotes
		commandRemote = remote
	end

	commandRemote.OnServerEvent:Connect(function(player, command, payload)
		if type(command) ~= "string" then
			return
		end
		payload = (type(payload) == "table") and payload or {}

		if command == "diagnostics" then
			if not hasRole(player, "Tester") then
				return
			end
			notify(player, "success", "Diagnostics: server running.")
			print("[Admin] diagnostics by", player.Name)
			return
		end

		if command == "toggleSandbox" then
			if not hasRole(player, "Tester") then
				return
			end
			if Data then
				Data.setSandboxMode(player, not isSandbox(player))
			end
			player:SetAttribute("SandboxMode", isSandbox(player))
			notify(player, "success", "Sandbox: " .. tostring(isSandbox(player)))
			return
		end

		if command == "grantCoins" then
			if not hasRole(player, "Admin") then
				return
			end
			local targetId = tonumber(payload.userId)
			local amount = tonumber(payload.amount)
			if not targetId or not amount or amount <= 0 or amount > 1000000 then
				return
			end
			local target = Players:GetPlayerByUserId(targetId)
			if target and Data.get(target) then
				Data.addCoins(target, math.floor(amount))
				notify(player, "success", "Granted coins to " .. target.Name)
			end
			return
		end

		if command == "grantBrainrot" then
			if not hasRole(player, "Admin") then
				return
			end
			local targetId = tonumber(payload.userId)
			local brainrotId = payload.brainrotId
			if type(brainrotId) ~= "string" then
				return
			end
			local target = Players:GetPlayerByUserId(targetId)
			if target and Data.get(target) then
				Data.ownBrainrot(target, brainrotId)
				notify(player, "success", "Granted Brainrot " .. brainrotId)
			end
			return
		end

		if command == "grantPet" then
			if not hasRole(player, "Admin") then
				return
			end
			local targetId = tonumber(payload.userId)
			local petId = payload.petId
			if type(petId) ~= "string" then
				return
			end
			local target = Players:GetPlayerByUserId(targetId)
			if target and Data.get(target) then
				Data.ownPet(target, petId)
				notify(player, "success", "Granted pet " .. petId)
			end
			return
		end

		if command == "setPower" then
			if not hasRole(player, "Admin") then
				return
			end
			if not isSandbox(player) then
				notify(player, "error", "setPower only in sandbox mode")
				return
			end
			local targetId = tonumber(payload.userId)
			local amount = tonumber(payload.amount)
			if not targetId or not amount or amount < 0 then
				return
			end
			local target = Players:GetPlayerByUserId(targetId)
			local profile = target and Data.get(target)
			if profile then
				profile.power = math.floor(amount)
				Data.syncProfile(target)
				notify(player, "success", "Set power (sandbox)")
			end
			return
		end

		if command == "spawnTestBuilding" then
			if not hasRole(player, "Tester") then
				return
			end
			local BuildingService = require(script.Parent.BuildingService)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local mapFolder = workspace:FindFirstChild("Map")
				local zoneFolder = mapFolder and mapFolder:FindFirstChild("Beach")
				if zoneFolder then
					local BuildingService = require(script.Parent.BuildingService)
					BuildingService.spawnBuilding("shack", zoneFolder, root.Position + Vector3.new(0, 0, 8))
					notify(player, "success", "Spawned test building")
				end
			end
			return
		end

		if command == "resetBoss" then
			if not hasRole(player, "Admin") then
				return
			end
			local BossService = require(script.Parent.BossService)
			local mapFolder = workspace:FindFirstChild("Map")
			if mapFolder then
				BossService.spawnBoss("settlement_boss", Vector3.new(0, 0, 80), mapFolder)
				notify(player, "success", "Boss respawned")
			end
			return
		end

		if command == "kick" then
			if not hasRole(player, "Moderator") then
				return
			end
			local targetId = tonumber(payload.userId)
			local reason = tostring(payload.reason or "Moderation")
			local target = Players:GetPlayerByUserId(targetId)
			if target then
				target:Kick(reason)
			end
			return
		end

		if command == "setRole" then
			if not hasRole(player, "Owner") then
				return
			end
			local targetId = tonumber(payload.userId)
			local role = payload.role
			if not targetId or type(role) ~= "string" or not VALID_ROLES[role] or role == "Owner" then
				return
			end
			-- Prevent modifying bootstrap owner.
			if ownerUserId and targetId == ownerUserId then
				notify(player, "error", "Cannot modify bootstrap Owner.")
				return
			end
			local target = Players:GetPlayerByUserId(targetId)
			if target then
				local profile = Data.get(target)
				if profile then
					profile.staffRole = role
					Data.save(target)
					target:SetAttribute("StaffRole", role)
					notify(player, "success", "Set role " .. role .. " for " .. target.Name)
				end
			else
				-- offline: store in profile via DataStore? skip for now
				notify(player, "error", "Target must be online.")
			end
			return
		end

		if command == "inspect" then
			if not hasRole(player, "Moderator") then
				return
			end
			local targetId = tonumber(payload.userId)
			local target = Players:GetPlayerByUserId(targetId)
			local profile = target and Data.get(target)
			if profile then
				notify(
					player,
					"info",
					target.Name
						.. " power="
						.. tostring(profile.power)
						.. " coins="
						.. tostring(profile.coins)
						.. " rebirths="
						.. tostring(profile.rebirths)
				)
			end
			return
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- sandbox cleanup handled by Data
	end)
end

function AdminService.getRole(player)
	return getRole(player)
end

function AdminService.isSandbox(player)
	return Data and Data.isSandbox(player) == true
end

return AdminService
