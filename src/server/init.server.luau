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

-- Spawn destructible buildings in each zone (after map built).
for _, zone in Config.Zones do
	local zoneFolder = workspace.Map:FindFirstChild(zone.name)
	if zoneFolder then
		BuildingService.spawnZoneBuildings(zone.name, zoneFolder)
	end
end

Data.start()
Monetization.start(Data)
Training.start(Data, Monetization, MapBuilder)
Shop.start(Data)
BrainrotService.start(Data)
BuildingService.start(Data, BrainrotService)
CombatService.start(Data, BrainrotService, BuildingService)
FartJumpService.start(Data)
WorldService.start(Data)
AdminService.start(Data)
Analytics.start()
QuestService.start(Data)
BossService.start(Data)

-- Spawn Settlement boss near the Beach spawn.
local mapFolder = workspace:FindFirstChild("Map")
if mapFolder then
	BossService.spawnBoss("settlement_boss", Vector3.new(0, 0, 80), mapFolder)
end
PvPService.start(Data)
GlobalLeaderboard.start(Data, mapHandles.leaderboardPart)

print("[Server] FART BRAINROT SIMULATOR ready 💨")
