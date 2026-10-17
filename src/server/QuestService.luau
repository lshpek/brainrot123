-- QuestService.luau
-- Server-authoritative quest tracking and rewards.
--
-- IDEMPOTENT COMPLETION MODEL (single source of truth):
--   profile.quests[questId] = { progress, completed, claimed }
--   completeQuest(player, quest) is the ONLY place a reward is granted.
--   It grants the reward exactly once: if state.claimed is already true it
--   returns immediately. A quest is marked claimed only AFTER the reward is
--   granted, so a crash between grant and persist cannot lose or duplicate a
--   reward (the grant is re-attempted on the next completion path because
--   claimed is still false).
--
-- Progress is server-owned; clients never supply reward values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local QuestService = {}

local Data
local BrainrotService -- injected via start for XP grants
local questProgress = {} -- [Player] = { [questId] = progress number }

local function getQuestConfig(questId)
	for _, q in ipairs(Config.Quests) do
		if q.id == questId then
			return q
		end
	end
	return nil
end

local function ensureProfileQuests(profile)
	if not profile.quests then
		profile.quests = {}
	end
	return profile.quests
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

-- Forward declaration for analytics so grantQuestReward can call it.
local AnalyticsTrack

AnalyticsTrack = function(player, eventName, value)
	local ok, analytics = pcall(function()
		return require(script.Parent.Analytics)
	end)
	if ok and analytics and analytics.track then
		pcall(function()
			analytics.track(player, eventName, value)
		end)
	end
end

-- Grant the quest reward from trusted config only. Client values are never trusted.
-- Returns {coins=..., xp=...} granted, or nil if the profile is unavailable.
-- The grant is applied to the active (sandbox or production) profile in memory;
-- the caller is responsible for persisting via Data.save.
local function grantQuestReward(player, quest)
	local profile = Data and Data.get(player)
	if not profile then
		return nil
	end
	local granted = { coins = 0, xp = 0 }
	if quest.rewardCoins and quest.rewardCoins > 0 then
		Data.addCoins(player, quest.rewardCoins)
		granted.coins = quest.rewardCoins
	end
	if quest.rewardXp and quest.rewardXp > 0 then
		if BrainrotService and BrainrotService.addXpToEquipped then
			BrainrotService.addXpToEquipped(player, quest.rewardXp)
		end
		granted.xp = quest.rewardXp
	end
	AnalyticsTrack(player, "quest_complete", quest.id)
	return granted
end

-- Complete a quest and grant its reward exactly once.
-- Idempotent: safe to call repeatedly; the reward is granted only the first time.
-- The claim state and the reward mutation are persisted together through one
-- Data.save (one authoritative profile update). A save failure rolls back the
-- in-memory grant so a retry does not duplicate the reward; atomicity across
-- DataStores is NOT claimed.
local function completeQuest(player, quest)
	if type(quest) ~= "table" or type(quest.id) ~= "string" then
		return false
	end
	local profile = Data and Data.get(player)
	if not profile then
		return false
	end
	local states = ensureProfileQuests(profile)
	local state = states[quest.id]
	if not state then
		state = { progress = 0, completed = false, claimed = false }
		states[quest.id] = state
	end
	-- Already fully completed and rewarded: nothing to do.
	if state.claimed then
		pushUpdate(player, quest.id, state.progress, true)
		return true
	end
	state.progress = quest.target
	state.completed = true

	-- Snapshot pre-grant Brainrot state so a save failure can fully restore it
	-- (not just XP — level changes from the grant must also be rolled back).
	local snapshot = nil
	local equippedId = profile.equippedBrainrot
	if quest.rewardXp and quest.rewardXp > 0 and equippedId then
		local entry = profile.brainrots and profile.brainrots[equippedId]
		if entry then
			snapshot = { level = entry.level, xp = entry.xp }
		end
	end

	-- Grant the reward exactly once, then persist claim + reward together.
	local granted = grantQuestReward(player, quest)
	if not granted then
		state.completed = false
		pushUpdate(player, quest.id, state.progress, false)
		return false
	end
	state.claimed = true
	local saved = Data.save(player)
	if not saved then
		-- Roll back the in-memory grant so a retry can re-attempt safely.
		state.claimed = false
		state.completed = false
		if granted.coins and granted.coins > 0 then
			Data.addCoins(player, -granted.coins)
		end
		if granted.xp and granted.xp > 0 and snapshot and equippedId then
			local entry = profile.brainrots and profile.brainrots[equippedId]
			if entry then
				entry.level = snapshot.level
				entry.xp = snapshot.xp
			end
		end
		Data.syncProfile(player)
		pushUpdate(player, quest.id, state.progress, false)
		warn(`[QuestService] Save failed for quest {quest.id}; reward rolled back, retryable.`)
		return false
	end
	pushUpdate(player, quest.id, state.progress, true)
	local notify = ReplicatedStorage.Remotes:FindFirstChild("Notify")
	if notify then
		notify:FireClient(player, "success", "Quest complete: " .. tostring(quest.name))
	end
	return true
end

function QuestService.start(dataService, brainrotService)
	Data = dataService
	BrainrotService = brainrotService

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claimRemote = remotes:FindFirstChild("ClaimQuest")
	if not claimRemote then
		local r = Instance.new("RemoteEvent")
		r.Name = "ClaimQuest"
		r.Parent = remotes
		claimRemote = r
	end
	-- Claiming is an acknowledgement. Rewards auto-grant on completion, so this
	-- is a no-op that just re-syncs the client (no double reward).
	claimRemote.OnServerEvent:Connect(function(player, questId)
		if type(questId) ~= "string" then
			return
		end
		local q = getQuestConfig(questId)
		if not q then
			return
		end
		local profile = Data and Data.get(player)
		if not profile then
			return
		end
		local states = ensureProfileQuests(profile)
		local state = states[questId]
		if state and state.completed then
			pushUpdate(player, questId, state.progress, true)
		end
	end)

	local function initPlayerQuests(player)
		local profile = Data and Data.get(player)
		if not profile then
			return
		end
		ensureProfileQuests(profile)
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
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			initPlayerQuests(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			initPlayerQuests(player)
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
	ensureProfileQuests(profile)
	amount = amount or 1
	for _, q in ipairs(Config.Quests) do
		if q.type == "counter" and q.eventType == eventType then
			local state = profile.quests[q.id]
			if state and state.completed then
				-- already done
			else
				local cur = (progress[q.id] or 0) + amount
				if cur > q.target then
					cur = q.target
				end
				progress[q.id] = cur
				if not state then
					state = { progress = cur, completed = false, claimed = false }
					profile.quests[q.id] = state
				else
					state.progress = cur
				end
				pushUpdate(player, q.id, cur, cur >= q.target)
				if cur >= q.target and not state.completed then
					state.completed = true
					completeQuest(player, q)
				end
			end
		end
		if q.type == "threshold" and q.stat == "power" then
			local state = profile.quests[q.id]
			if not (state and state.completed) then
				local val = profile.power or 0
				if val >= q.target then
					progress[q.id] = q.target
					if not state then
						state = { progress = q.target, completed = false, claimed = false }
						profile.quests[q.id] = state
					end
					state.completed = true
					completeQuest(player, q)
				else
					progress[q.id] = val
					pushUpdate(player, q.id, val, false)
				end
			end
		end
	end
end

-- Mark a milestone quest complete (used by first-hit, first-destroy, etc.).
-- Grants the reward exactly once via completeQuest.
function QuestService.completeMilestone(player, questId)
	local q = getQuestConfig(questId)
	if not q then
		return
	end
	local profile = Data and Data.get(player)
	if not profile then
		return
	end
	ensureProfileQuests(profile)
	local state = profile.quests[questId]
	if not state then
		state = { progress = q.target, completed = true, claimed = false }
		profile.quests[questId] = state
	else
		state.progress = q.target
		state.completed = true
	end
	-- completeQuest grants the reward once and marks claimed.
	completeQuest(player, q)
end

function QuestService.getQuests(player)
	return Config.Quests
end

function QuestService.getProgress(player, questId)
	local progress = questProgress[player]
	if not progress then
		return 0
	end
	return progress[questId] or 0
end

return QuestService
