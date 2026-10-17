-- Analytics.luau
-- Privacy-respecting best-effort analytics. Never blocks gameplay.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = {}

local analyticsService = nil
pcall(function()
	analyticsService = game:GetService("AnalyticsService")
end)

function Analytics.track(player, eventName, value)
	if type(eventName) ~= "string" then
		return
	end
	pcall(function()
		if analyticsService and analyticsService.LogCustomEvent then
			analyticsService:LogCustomEvent(player, "gameplay", eventName, value)
		end
	end)
end

function Analytics.start()
	-- No background loops; event-driven only.
end

return Analytics
