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

	-- Gear levels sequential, non-negative, strictly increasing cost/multiplier.
	for i, gear in ipairs(Config.Gear) do
		if gear.cost < 0 then
			table.insert(errors, "Invalid gear cost at level " .. tostring(i))
		end
		if type(gear.multiplier) ~= "number" or gear.multiplier <= 0 then
			table.insert(errors, "Invalid gear multiplier at level " .. tostring(i))
		end
		if i > 1 then
			local prev = Config.Gear[i - 1]
			if gear.cost <= prev.cost then
				table.insert(errors, "Gear cost not increasing at level " .. tostring(i))
			end
			if gear.multiplier <= prev.multiplier then
				table.insert(errors, "Gear multiplier not increasing at level " .. tostring(i))
			end
		end
	end

	-- FartJump tuning sane.
	local FJ = Config.FartJump
	if FJ then
		if type(FJ.baseImpulse) ~= "number" or FJ.baseImpulse < 0 then
			table.insert(errors, "Invalid FartJump.baseImpulse")
		end
		if type(FJ.maxImpulse) ~= "number" or FJ.maxImpulse <= (FJ.baseImpulse or 0) then
			table.insert(errors, "Invalid FartJump.maxImpulse (must exceed base)")
		end
		if type(FJ.scaleK) ~= "number" or FJ.scaleK <= 0 then
			table.insert(errors, "Invalid FartJump.scaleK")
		end
		if type(FJ.cooldown) ~= "number" or FJ.cooldown <= 0 then
			table.insert(errors, "Invalid FartJump.cooldown")
		end
	end

	-- Combat tuning sane.
	if Config.Combat then
		if type(Config.Combat.attackCooldown) ~= "number" or Config.Combat.attackCooldown <= 0 then
			table.insert(errors, "Invalid Combat.attackCooldown")
		end
		if type(Config.Combat.maxAttackRange) ~= "number" or Config.Combat.maxAttackRange <= 0 then
			table.insert(errors, "Invalid Combat.maxAttackRange")
		end
	end

	-- PvP reward bounded (anti runaway economy).
	if Config.PvP and type(Config.PvP.winRewardCoins) == "number" and Config.PvP.winRewardCoins < 0 then
		table.insert(errors, "Invalid PvP.winRewardCoins")
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

	-- Worlds: unique ids, non-negative rebirth requirements.
	local worldIds = {}
	for _, world in ipairs(Config.Worlds) do
		if worldIds[world.id] then
			table.insert(errors, "Duplicate world id: " .. tostring(world.id))
		end
		worldIds[world.id] = true
		if type(world.rebirthRequired) ~= "number" or world.rebirthRequired < 0 then
			table.insert(errors, "Invalid rebirthRequired for world: " .. tostring(world.id))
		end
	end

	-- WorldLayouts: must match Worlds 1:1, unique ids, valid spawn/boss/arena positions.
	local layoutIds = {}
	for i, layout in ipairs(Config.WorldLayouts) do
		if layoutIds[layout.id] then
			table.insert(errors, "Duplicate world layout id: " .. tostring(layout.id))
		end
		layoutIds[layout.id] = true
		-- Each layout's worldId should correspond to a configured world.
		local worldId = layout.id
		local matched = false
		for _, w in ipairs(Config.Worlds) do
			if w.id == worldId then
				matched = true
				break
			end
		end
		if not matched then
			table.insert(errors, "WorldLayout '" .. tostring(layout.id) .. "' has no matching Config.Worlds entry")
		end
		-- Layout count must equal World count.
		if i == #Config.WorldLayouts and i ~= #Config.Worlds then
			table.insert(
				errors,
				"WorldLayouts count ("
					.. tostring(#Config.WorldLayouts)
					.. ") != Worlds count ("
					.. tostring(#Config.Worlds)
					.. ")"
			)
		end
		-- Spawn position must be a Vector3 and have a valid Y (above ground).
		if typeof(layout.spawn) ~= "Vector3" or layout.spawn.Y < 0 then
			table.insert(errors, "WorldLayout '" .. tostring(layout.id) .. "' has invalid spawn position")
		end
		-- Boss position should be within a reasonable range of the world center.
		-- Worlds are spaced ZONE_SIZE apart; positions should be within ±ZONE_SIZE of center.
		local ZONE_SIZE = 140
		local worldIndex = Config.WorldZoneIndex[layout.id]
		if worldIndex and typeof(layout.bossPosition) == "Vector3" then
			local worldCenterX = (worldIndex - 1) * ZONE_SIZE
			if math.abs(layout.bossPosition.X) > ZONE_SIZE or math.abs(layout.bossPosition.Z) > ZONE_SIZE then
				table.insert(errors, "WorldLayout '" .. tostring(layout.id) .. "' boss position outside zone bounds")
			end
		end
	end

	-- Bosses: each boss must reference a valid world.
	for _, boss in ipairs(Config.Bosses) do
		local worldFound = false
		for _, w in ipairs(Config.Worlds) do
			if w.id == boss.world then
				worldFound = true
				break
			end
		end
		if not worldFound then
			table.insert(
				errors,
				"Boss '" .. tostring(boss.id) .. "' references unknown world: " .. tostring(boss.world)
			)
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
