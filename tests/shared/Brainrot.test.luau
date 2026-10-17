-- Brainrot.test.luau — lune-compatible (NO Roblox globals: no Color3/Vector3).
local Brainrots = {
	{ id = "toxic_titan", baseDamage = 10, damagePerLevel = 2, xpPerLevel = 100, xpGrowth = 1.5 },
	{ id = "skibidi_slayer", baseDamage = 25, damagePerLevel = 4, xpPerLevel = 150, xpGrowth = 1.55 },
	{ id = "grimace_gulp", baseDamage = 50, damagePerLevel = 7, xpPerLevel = 250, xpGrowth = 1.6 },
}
local CAP = 3.0

local function getConfig(id)
	for _, b in ipairs(Brainrots) do
		if b.id == id then
			return b
		end
	end
	return nil
end
local function xpForNextLevel(config, level)
	if level < 1 then
		level = 1
	end
	local cost = config.xpPerLevel
	for _ = 2, level do
		cost = math.floor(cost * config.xpGrowth + 0.5)
	end
	return cost
end
local function damageAtLevel(config, level)
	if level < 1 then
		level = 1
	end
	return config.baseDamage + (level - 1) * config.damagePerLevel
end
local function totalDamage(config, level, bonus)
	return damageAtLevel(config, level) * (1 + math.clamp(bonus or 0, 0, CAP))
end

return {
	{ "xp level1 costs base", function()
		assert(xpForNextLevel(getConfig("toxic_titan"), 1) == 100)
	end },
	{ "xp grows per level", function()
		local c = getConfig("toxic_titan")
		local a = xpForNextLevel(c, 1)
		local b = xpForNextLevel(c, 2)
		local d = xpForNextLevel(c, 3)
		assert(a > 0 and b > a and d > b, a .. " " .. b .. " " .. d)
	end },
	{ "damage linear per level", function()
		local c = getConfig("skibidi_slayer")
		assert(damageAtLevel(c, 1) == 25, tostring(damageAtLevel(c, 1)))
		assert(damageAtLevel(c, 5) == 25 + 4 * 4, tostring(damageAtLevel(c, 5)))
		assert(damageAtLevel(c, 10) > damageAtLevel(c, 5))
	end },
	{ "pet bonus multiplies", function()
		local c = getConfig("grimace_gulp")
		assert(totalDamage(c, 1, 0) == 50)
		assert(totalDamage(c, 1, 0.5) == 75)
	end },
	{ "pet bonus clamped to cap", function()
		local c = getConfig("toxic_titan")
		assert(totalDamage(c, 1, 5.0) == totalDamage(c, 1, CAP))
	end },
	{ "unknown id returns nil", function()
		assert(getConfig("nope") == nil)
	end },
}
