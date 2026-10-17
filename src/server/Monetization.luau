-- Monetization.luau
-- Gamepass ownership (cached per player, exposed as attributes for the UI)
-- and developer product receipt processing. All grants happen server-side.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage.Shared.Config)

local RECEIPT_STORE_NAME = "Receipts_v1"

local Monetization = {}

local ownership = {} -- [Player] = { [passKey] = boolean }
local Data

-- Durable, retry-safe receipt processing. The in-memory cache is only a fast
-- path; the source of truth is a DataStore keyed by PurchaseId so a repeated
-- receipt (Roblox retries until PurchaseGranted) can never grant twice, even
-- across server restarts within the same processing window.
local receiptStore
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(RECEIPT_STORE_NAME)
	end)
	if ok then
		receiptStore = result
	else
		warn("[Monetization] Receipt store unavailable; falling back to in-memory dedupe only.")
	end
end

local handledReceipts = {} -- [PurchaseId] = true, session fast path

-- Returns true if this PurchaseId was already durably granted.
local function receiptAlreadyGranted(purchaseId: number): boolean
	if handledReceipts[purchaseId] then
		return true
	end
	if not receiptStore then
		return false
	end
	local ok, marked = pcall(function()
		return receiptStore:GetAsync("r_" .. tostring(purchaseId))
	end)
	if ok and marked then
		handledReceipts[purchaseId] = true
		return true
	end
	return false
end

-- Durably mark a receipt as granted BEFORE returning PurchaseGranted. If this
-- write fails we still return PurchaseGranted to avoid Roblox re-prompting an
-- already-delivered product; the fast-path cache keeps the session consistent.
local function markReceiptGranted(purchaseId: number)
	handledReceipts[purchaseId] = true
	if receiptStore then
		pcall(function()
			receiptStore:SetAsync("r_" .. tostring(purchaseId), true)
		end)
	end
end

local function refreshPasses(player: Player)
	local owned = {}
	for key, passId in Config.GamePasses do
		local owns = false
		if passId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			owns = ok and result == true
		end
		owned[key] = owns
		player:SetAttribute("Owns" .. key, owns)
	end
	ownership[player] = owned
end

local function processReceipt(receiptInfo)
	if type(receiptInfo) ~= "table" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if
		type(receiptInfo.PurchaseId) ~= "number"
		or type(receiptInfo.PlayerId) ~= "number"
		or type(receiptInfo.ProductId) ~= "number"
	then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receiptAlreadyGranted(receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not Data.get(player) then
		-- Player left or their data hasn't loaded; Roblox will retry later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Data.get(player)

	-- Sandbox: never grant real Robux purchases into the isolated test profile.
	if Data.isSandbox(player) then
		warn(`[Monetization] Ignoring receipt {receiptInfo.PurchaseId} for sandbox player {player.Name}`)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Recovery: if a previous attempt recorded the receipt in the profile but
	-- failed to mark the receipt store, do not grant again.
	if profile.receipts and profile.receipts[tostring(receiptInfo.PurchaseId)] then
		markReceiptGranted(receiptInfo.PurchaseId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	for _, product in Config.DevProducts do
		if product.id == receiptInfo.ProductId and product.id ~= 0 then
			-- Durable grant: record the receipt and add coins in the profile,
			-- then save in ONE UpdateAsync. Only acknowledge once the save is
			-- durable. The receipt store marker is written only after a
			-- successful save so a failed save is never acknowledged as granted.
			if not profile.receipts then
				profile.receipts = {}
			end
			profile.receipts[tostring(receiptInfo.PurchaseId)] = true
			profile.coins = (profile.coins or 0) + (product.coins or 0)
			Data.syncProfile(player)
			local saved = Data.save(player)
			if saved then
				markReceiptGranted(receiptInfo.PurchaseId)
				local notify = ReplicatedStorage:FindFirstChild("Remotes")
				notify = notify and notify:FindFirstChild("Notify")
				if notify then
					notify:FireClient(player, "success", `Purchased {product.label}!`)
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			-- Save failed: roll back the in-memory grant so a Roblox retry does
			-- not duplicate coins, and do NOT acknowledge (Roblox retries).
			profile.receipts[tostring(receiptInfo.PurchaseId)] = nil
			profile.coins = (profile.coins or 0) - (product.coins or 0)
			Data.syncProfile(player)
			warn(`[Monetization] Profile save failed for receipt {receiptInfo.PurchaseId}; not acknowledged, will retry.`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	warn(`[Monetization] Receipt for unknown or unconfigured product id {receiptInfo.ProductId}`)
	-- Unknown/unconfigured product: never ack it as granted.
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- ============================== PUBLIC API ==============================

function Monetization.ownsPass(player: Player, passKey: string): boolean
	local owned = ownership[player]
	return owned ~= nil and owned[passKey] == true
end

function Monetization.start(dataService)
	Data = dataService

	Players.PlayerAdded:Connect(function(player)
		task.spawn(refreshPasses, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(refreshPasses, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownership[player] = nil
	end)

	-- Update the cache instantly when a pass is bought in-game.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, id in Config.GamePasses do
			if id == passId then
				local owned = ownership[player]
				if owned then
					owned[key] = true
				end
				player:SetAttribute("Owns" .. key, true)
				local notify = ReplicatedStorage.Remotes:FindFirstChild("Notify")
				if notify then
					notify:FireClient(player, "success", `{Config.GamePassInfo[key].title} unlocked!`)
				end
			end
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt
end

return Monetization
