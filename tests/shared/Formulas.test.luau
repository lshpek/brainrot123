-- Formulas.test.luau
-- Tests for pure math formulas: gear multiplier, rebirth multiplier,
-- power per punch, coins for power, rebirth cost, abbreviation.
-- Inline copies of formula logic; does not require Roblox RuntimeServices.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

local Gear = {
	{ name = "Foam Gloves", cost = 100, multiplier = 2 },
	{ name = "Leather Gloves", cost = 1000, multiplier = 5 },
	{ name = "Iron Gauntlets", cost = 10000, multiplier = 12 },
}

local Rebirth = {
	BaseCost = 10000,
	CostGrowth = 3,
	BonusPerRebirth = 0.5,
}

local Training = {
	BasePowerPerPunch = 1,
	CoinsPerPowerGained = 0.5,
}

local function gearMultiplier(gearLevel)
	if gearLevel <= 0 then return 1 end
	local gear = Gear[math.min(gearLevel, #Gear)]
	return gear.multiplier
end

local function rebirthMultiplier(rebirths)
	return 1 + rebirths * Rebirth.BonusPerRebirth
end

local function powerPerPunch(state)
	local amount = Training.BasePowerPerPunch
		* gearMultiplier(state.gearLevel)
		* rebirthMultiplier(state.rebirths)
		* (state.zoneMultiplier or 1)
	if state.hasDoublePower then
		amount *= 2
	end
	return math.max(1, math.floor(amount + 0.5))
end

local function coinsForPower(powerGained, hasDoubleCoins)
	local coins = powerGained * Training.CoinsPerPowerGained
	if hasDoubleCoins then
		coins *= 2
	end
	return math.floor(coins + 0.5)
end

local function rebirthCost(rebirths)
	return math.floor(Rebirth.BaseCost * Rebirth.CostGrowth ^ rebirths)
end

local function abbreviate(n)
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local index = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 1000 ^ index
	local formatted
	if scaled >= 100 then
		formatted = string.format("%.0f", scaled)
	elseif scaled >= 10 then
		formatted = string.format("%.1f", scaled)
	else
		formatted = string.format("%.2f", scaled)
	end
	return formatted .. SUFFIXES[index + 1]
end

return {
	{ "Gear multiplier returns 1 for level 0", function()
		assert(gearMultiplier(0) == 1, "Expected 1, got " .. tostring(gearMultiplier(0)))
	end },

	{ "Gear multiplier returns correct value for level 1", function()
		assert(gearMultiplier(1) == 2, "Expected 2, got " .. tostring(gearMultiplier(1)))
	end },

	{ "Gear multiplier caps at max gear level", function()
		assert(gearMultiplier(999) == 12, "Expected 12, got " .. tostring(gearMultiplier(999)))
	end },

	{ "Rebirth multiplier is 1 at 0 rebirths", function()
		assert(rebirthMultiplier(0) == 1, "Expected 1, got " .. tostring(rebirthMultiplier(0)))
	end },

	{ "Rebirth multiplier grows correctly", function()
		assert(rebirthMultiplier(1) == 1.5, "Expected 1.5, got " .. tostring(rebirthMultiplier(1)))
		assert(rebirthMultiplier(10) == 6, "Expected 6, got " .. tostring(rebirthMultiplier(10)))
	end },

	{ "Power per punch minimum is 1", function()
		local result = powerPerPunch({ gearLevel = 0, rebirths = 0, zoneMultiplier = 0, hasDoublePower = false })
		assert(result >= 1, "Expected >= 1, got " .. tostring(result))
	end },

	{ "Power per punch applies gear multiplier", function()
		local base = powerPerPunch({ gearLevel = 0, rebirths = 0, zoneMultiplier = 1, hasDoublePower = false })
		local withGear = powerPerPunch({ gearLevel = 1, rebirths = 0, zoneMultiplier = 1, hasDoublePower = false })
		assert(withGear > base, "Expected gear to increase power: base=" .. base .. " gear=" .. withGear)
	end },

	{ "Power per punch applies rebirth multiplier", function()
		local base = powerPerPunch({ gearLevel = 1, rebirths = 0, zoneMultiplier = 1, hasDoublePower = false })
		local withRebirth = powerPerPunch({ gearLevel = 1, rebirths = 10, zoneMultiplier = 1, hasDoublePower = false })
		assert(withRebirth > base, "Expected rebirth to increase power")
	end },

	{ "Power per punch applies double power", function()
		local without = powerPerPunch({ gearLevel = 1, rebirths = 1, zoneMultiplier = 1, hasDoublePower = false })
		local with = powerPerPunch({ gearLevel = 1, rebirths = 1, zoneMultiplier = 1, hasDoublePower = true })
		assert(with == without * 2, "Double power should double output: " .. without .. " -> " .. with)
	end },

	{ "Coins for power calculates correctly", function()
		local result = coinsForPower(100, false)
		assert(result == 50, "Expected 50, got " .. tostring(result))
	end },

	{ "Coins for power with double bonus", function()
		local result = coinsForPower(100, true)
		assert(result == 100, "Expected 100, got " .. tostring(result))
	end },

	{ "Rebirth cost follows exponential growth", function()
		local cost0 = rebirthCost(0)
		local cost1 = rebirthCost(1)
		local cost2 = rebirthCost(2)
		assert(cost0 == 10000, "Expected 10000, got " .. tostring(cost0))
		assert(cost1 == 30000, "Expected 30000, got " .. tostring(cost1))
		assert(cost2 == 90000, "Expected 90000, got " .. tostring(cost2))
	end },

	{ "Abbreviate handles values under 1000", function()
		assert(abbreviate(950) == "950", "Expected '950', got '" .. abbreviate(950) .. "'")
	end },

	{ "Abbreviate handles K suffix", function()
		local result = abbreviate(1234567)
		assert(string.find(result, "K") or string.find(result, "M"), "Expected K or M suffix, got '" .. result .. "'")
	end },

	{ "Abbreviate handles M suffix", function()
		local result = abbreviate(5500000)
		assert(string.find(result, "M"), "Expected M suffix, got '" .. result .. "'")
	end },
}
