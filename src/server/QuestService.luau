-- QuestService.luau
-- Server-authoritative quest tracking and rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local QuestService = {}

local Data
local questProgress = {} -- [Player] = { [questId] = progress number }

local function getQuestConfig(questId)
	for _, q in ipairs(Config.Quests) do
		if q.id == questId then
			return q
		end
	end
	return nil
end

local function ensureProgress(player)
	if not questProgress[player] then
		questProgress[player] = {}
	end
	return questProgress[player]
end

local function pushUpdate(player, questId, progress, completed)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("QuestUpdate")
	if remote then
		remote:FireClient(player, questId, progress, completed)
	end
end

local function completeQuest(player, quest)
	local profile = Data and Data.get(player)
	if not profile then
		return
	end
	if not profile.quests then
		profile.quests = {}
	end
	if profile.quests[quest.id] and profile.quests[quest.id].claimed then
		return
	end
	profile.quests[quest.id] = { progress = quest.target, completed = true, claimed = false }
	-- Auto-claim reward.
	if quest.rewardCoins then
		Data.addCoins(player, quest.rewardCoins)
	end
	if quest.rewardXp then
		-- grant to equipped brainrot via BrainrotService if available
	end
	if quest.rewardXp then
		local bs = nil
		pcall(function()
			bs = require(script.Parent.BrainrotService)
		end)
		if bs and bs.addXpToEquipped then
			bs.addXpToEquipped(player, quest.rewardXp)
		end
	end
	pushUpdate(player, quest.id, quest.target, true)
	local notify = ReplicatedStorage.Remotes:FindFirstChild("Notify")
	if notify then
		notify:FireClient(player, "success", "Quest complete: " .. quest.name)
	end
	Data.save(player)
end

function QuestService.start(dataService)
	Data = dataService

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claimRemote = remotes:FindFirstChild("ClaimQuest")
	if not claimRemote then
		local r = Instance.new("RemoteEvent")
		r.Name = "ClaimQuest"
		r.Parent = remotes
		claimRemote = r
	end
	claimRemote.OnServerEvent:Connect(function(player, questId)
		-- Rewards are auto-claimed; this is a no-op ack.
		pushUpdate(player, questId, questProgress[player] and questProgress[player][questId] or 0, true)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- init progress from profile
			local profile = Data.get(player)
			if not profile then
				return
			end
			if not profile.quests then
				profile.quests = {}
			end
			ensureProgress(player)
			for _, q in ipairs(Config.Quests) do
				local saved = profile.quests[q.id]
				if saved then
					questProgress[player][q.id] = saved.progress or 0
					if saved.completed then
						pushUpdate(player, q.id, saved.progress or q.target, true)
					end
				else
					questProgress[player][q.id] = 0
				end
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local profile = Data.get(player)
			if not profile then
				return
			end
			if not profile.quests then
				profile.quests = {}
			end
			ensureProgress(player)
			for _, q in ipairs(Config.Quests) do
				local saved = profile.quests[q.id]
				if saved then
					questProgress[player][q.id] = saved.progress or 0
				else
					questProgress[player][q.id] = 0
				end
			end
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		questProgress[player] = nil
	end)
end

-- Called by other services when a quest-relevant event occurs.
function QuestService.onEvent(player, eventType, amount)
	local progress = ensureProgress(player)
	local profile = Data and Data.get(player)
	if not profile then
		return
	end
	if not profile.quests then
		profile.quests = {}
	end
	amount = amount or 1
	for _, q in ipairs(Config.Quests) do
		if q.type == "counter" and q.eventType == eventType then
			if profile.quests[q.id] and profile.quests[q.id].completed then
				-- already done
			else
				local cur = progress[q.id] or 0
				cur += amount
				if cur > q.target then
					cur = q.target
				end
				progress[q.id] = cur
				if not profile.quests[q.id] then
					profile.quests[q.id] = { progress = cur, completed = false, claimed = false }
				else
					profile.quests[q.id].progress = cur
				end
				pushUpdate(player, q.id, cur, cur >= q.target)
				if cur >= q.target and not profile.quests[q.id].completed then
					profile.quests[q.id].completed = true
					completeQuest(player, q)
				end
			end
		end
		if q.type == "threshold" and q.stat == "power" then
			if not (profile.quests[q.id] and profile.quests[q.id].completed) then
				local val = profile.power or 0
				if val >= q.target then
					progress[q.id] = q.target
					completeQuest(player, q)
				else
					progress[q.id] = val
					pushUpdate(player, q.id, val, false)
				end
			end
		end
	end
end

-- Mark a milestone quest complete.
function QuestService.completeMilestone(player, questId)
	local q = getQuestConfig(questId)
	if not q or q.type ~= "milestone" then
		-- allow any quest id that exists
		if not q then
			return
		end
	end
	local profile = Data and Data.get(player)
	if not profile then
		return
	end
	if not profile.quests then
		profile.quests = {}
	end
	if profile.quests[questId] and profile.quests[questId].completed then
		return
	end
	local progress = ensureProgress(player)
	progress[questId] = q.target
	profile.quests[questId] = { progress = q.target, completed = true, claimed = true }
	completeQuest(player, q)
end

function QuestService.getQuests(player)
	return Config.Quests
end

return QuestService
