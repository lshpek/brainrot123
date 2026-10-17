-- Server entry point. Creates the remotes, then wires services together in
-- dependency order. Services receive their dependencies explicitly instead of
-- requiring each other, which keeps the graph flat and easy to follow.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local ConfigValidation = require(ReplicatedStorage.Shared.ConfigValidation)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in
	{
		"Punch",
		"BuyGear",
		"Rebirth",
		"Notify",
		"ToggleAutoTrain",
		"Attack",
		"AttackResult",
		"BuildingDestroyed",
		"EquipBrainrot",
		"EquipPet",
		"HatchEgg",
		"HatchResult",
		"FartJump",
		"TeleportWorld",
		"AdminCommand",
		"QuestUpdate",
		"ClaimQuest",
		"BossUpdate",
		"BossAttack",
		"PvPChallenge",
		"PvPAccept",
		"PvPAttack",
		"PvPUpdate",
	}
do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local Data = require(script.Data)
local Monetization = require(script.Monetization)
local Training = require(script.Training)
local Shop = require(script.Shop)
local MapBuilder = require(script.MapBuilder)
local GlobalLeaderboard = require(script.GlobalLeaderboard)
local BrainrotService = require(script.BrainrotService)
local BuildingService = require(script.BuildingService)
local CombatService = require(script.CombatService)
local FartJumpService = require(script.FartJumpService)
local WorldService = require(script.WorldService)
local AdminService = require(script.AdminService)
local Analytics = require(script.Analytics)
local QuestService = require(script.QuestService)
local BossService = require(script.BossService)
local PvPService = require(script.PvPService)

local mapHandles = MapBuilder.build()

ConfigValidation.assertValid()

-- Spawn destructible buildings in each world (after map built).
local worldHandles = mapHandles.worldHandles
for _, layout in ipairs(Config.WorldLayouts) do
	local worldFolder = workspace.Map:FindFirstChild(layout.name)
	local handle = worldHandles and worldHandles[layout.id]
	if worldFolder and handle then
		BuildingService.spawnWorldBuildings(layout.id, worldFolder, handle.spawn)
	end
end

Data.start()
Monetization.start(Data)
Training.start(Data, Monetization, MapBuilder)
Shop.start(Data)
BrainrotService.start(Data)
BuildingService.start(Data, BrainrotService)
CombatService.start(Data, BrainrotService, BuildingService, BossService)
FartJumpService.start(Data)
WorldService.start(Data)
AdminService.start(Data)
Analytics.start()
QuestService.start(Data, BrainrotService)
BossService.start(Data, BrainrotService)

-- Spawn one configured boss per world at its boss district.
local mapFolder = workspace:FindFirstChild("Map")
if mapFolder then
	for _, layout in ipairs(Config.WorldLayouts) do
		local worldFolder = mapFolder:FindFirstChild(layout.name)
		local handle = worldHandles and worldHandles[layout.id]
		if worldFolder and handle and layout.bossId then
			BossService.spawnBoss(layout.bossId, handle.boss, worldFolder)
		end
	end
end
PvPService.start(Data)

-- Wire world identity into PvP so matches use the correct per-world arena.
-- WorldService.start was already called above. Teleport-to-Place is disabled
-- until real Place IDs are configured (WorldService guards placeId == 0), so
-- the local dev world defaults to Settlement (handled in PvPService).
GlobalLeaderboard.start(Data, mapHandles.leaderboardPart)

print("[Server] FART BRAINROT SIMULATOR ready 💨")
