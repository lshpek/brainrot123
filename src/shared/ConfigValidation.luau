-- ConfigValidation.luau
-- Lightweight startup validation for configuration invariants.
-- Returns a list of error strings; empty list means valid.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local ConfigValidation = {}

function ConfigValidation.validate(): { string }
	local errors = {}

	-- Unique brainrot ids.
	local brainrotIds = {}
	for _, b in ipairs(Config.Brainrots) do
		if brainrotIds[b.id] then
			table.insert(errors, "Duplicate Brainrot id: " .. tostring(b.id))
		end
		brainrotIds[b.id] = true
	end

	-- Unique pet ids.
	local petIds = {}
	for _, p in ipairs(Config.Pets) do
		if petIds[p.id] then
			table.insert(errors, "Duplicate pet id: " .. tostring(p.id))
		end
		petIds[p.id] = true
		if type(p.hatchChance) ~= "number" or p.hatchChance < 0 then
			table.insert(errors, "Invalid hatchChance for pet: " .. tostring(p.id))
		end
	end

	-- Hatch odds total 100.
	local totalChance = 0
	for _, p in ipairs(Config.Pets) do
		totalChance += p.hatchChance or 0
	end
	if totalChance ~= 100 then
		table.insert(errors, "Pet hatch chances total " .. tostring(totalChance) .. ", expected 100")
	end

	-- Eggs reference valid pets and costs.
	for _, egg in ipairs(Config.Eggs) do
		if type(egg.cost) ~= "number" or egg.cost < 0 then
			table.insert(errors, "Invalid egg cost: " .. tostring(egg.id))
		end
		for _, petId in ipairs(egg.petIds) do
			if not petIds[petId] then
				table.insert(errors, "Egg " .. tostring(egg.id) .. " references unknown pet " .. tostring(petId))
			end
		end
	end

	-- Pet bonus caps.
	for key, value in pairs(Config.PetBonusCaps) do
		if type(value) ~= "number" or value < 0 then
			table.insert(errors, "Invalid pet bonus cap: " .. tostring(key))
		end
	end

	-- Gear levels sequential.
	for i, gear in ipairs(Config.Gear) do
		if gear.cost < 0 then
			table.insert(errors, "Invalid gear cost at level " .. tostring(i))
		end
	end

	-- Buildings.
	for _, building in ipairs(Config.Buildings) do
		if type(building.maxHealth) ~= "number" or building.maxHealth <= 0 then
			table.insert(errors, "Invalid building health: " .. tostring(building.id))
		end
		if type(building.respawnTime) ~= "number" or building.respawnTime < 0 then
			table.insert(errors, "Invalid respawn time: " .. tostring(building.id))
		end
	end

	return errors
end

function ConfigValidation.assertValid()
	local errors = ConfigValidation.validate()
	for _, err in ipairs(errors) do
		warn("[ConfigValidation] " .. err)
	end
	if #errors > 0 then
		warn("[ConfigValidation] " .. tostring(#errors) .. " configuration issue(s) found")
	end
	return #errors == 0
end

return ConfigValidation
