-- Trove.luau (local, project-owned)
-- Minimal cleanup tracker inspired by Sleitnick/Trove (MIT) — PATTERN_ONLY:
-- independently reimplemented, no vendored dependency.
-- Tracks RBXScriptConnections, Instances, functions, threads for one-shot cleanup.
local Trove = {}
Trove.__index = Trove

function Trove.new(): any
	return setmetatable({ _items = {} }, Trove)
end

function Trove:Add(item: any): any
	table.insert(self._items, item)
	return item
end

function Trove:Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local c = signal:Connect(fn)
	table.insert(self._items, c)
	return c
end

function Trove:Clean()
	for i = #self._items, 1, -1 do
		local item = self._items[i]
		pcall(function()
			if typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			elseif typeof(item) == "Instance" then
				item:Destroy()
			elseif type(item) == "function" then
				item()
			elseif type(item) == "thread" then
				task.cancel(item)
			end
		end)
		self._items[i] = nil
	end
end

return Trove
