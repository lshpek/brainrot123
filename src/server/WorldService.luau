-- WorldService.luau
-- Server-authoritative world access and teleport requests for the five
-- separate Places. Place IDs of 0 mean "not configured" and never teleport.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = {}

local Data

function WorldService.start(dataService)
	Data = dataService

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:FindFirstChild("TeleportWorld")
	if not request then
		local remote = Instance.new("RemoteEvent")
		remote.Name = "TeleportWorld"
		remote.Parent = remotes
		request = remote
	end

	request.OnServerEvent:Connect(function(player, worldId)
		if type(worldId) ~= "string" then
			return
		end
		local world = nil
		for _, w in ipairs(Config.Worlds) do
			if w.id == worldId then
				world = w
				break
			end
		end
		if not world then
			return
		end

		local profile = Data.get(player)
		if not profile then
			return
		end
		local rebirths = profile.rebirths or 0
		if rebirths < (world.rebirthRequired or 0) then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(
					player,
					"error",
					"World locked: need " .. tostring(world.rebirthRequired) .. " rebirths."
				)
			end
			return
		end
		if not world.placeId or world.placeId == 0 then
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", world.name .. " is not configured yet.")
			end
			return
		end

		local ok, err = pcall(function()
			TeleportService:Teleport(world.placeId, player)
		end)
		if not ok then
			warn("[WorldService] Teleport failed: " .. tostring(err))
			local notify = remotes:FindFirstChild("Notify")
			if notify then
				notify:FireClient(player, "error", "Teleport failed. Try again.")
			end
		end
	end)
end

function WorldService.isUnlocked(player, worldId)
	local profile = Data and Data.get(player)
	if not profile then
		return false
	end
	for _, w in ipairs(Config.Worlds) do
		if w.id == worldId then
			return (profile.rebirths or 0) >= (w.rebirthRequired or 0)
		end
	end
	return false
end

return WorldService
