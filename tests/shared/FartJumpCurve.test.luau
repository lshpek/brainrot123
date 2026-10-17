-- FartJumpCurve.test.luau — lune-compatible (inline copy of src/shared/FartJumpCurve.luau logic).
local function upwardImpulse(power, cfg)
	local base = cfg.baseImpulse or 0
	local maxImpulse = cfg.maxImpulse or 140
	local scaleK = cfg.scaleK or 2500
	if power <= 0 then
		return math.clamp(base, 0, maxImpulse)
	end
	return math.clamp(base + (maxImpulse - base) * power / (power + scaleK), 0, maxImpulse)
end
local function forwardImpulse(up, cfg)
	return math.min(up * (cfg.forwardFactor or 0.8), cfg.maxForwardImpulse or 70)
end

local cfg = { baseImpulse = 55, maxImpulse = 140, scaleK = 2500, maxForwardImpulse = 70, forwardFactor = 0.8 }

return {
	{ "base at 0 power", function() assert(upwardImpulse(0, cfg) == 55) end },
	{ "half delta at k", function()
		assert(math.abs(upwardImpulse(2500, cfg) - 97.5) < 0.01, tostring(upwardImpulse(2500, cfg)))
	end },
	{ "monotonic and capped", function()
		local a = upwardImpulse(0, cfg)
		local b = upwardImpulse(2500, cfg)
		local c = upwardImpulse(100000, cfg)
		assert(a < b and b < c and c <= 140)
	end },
	{ "negative power returns base", function() assert(upwardImpulse(-5, cfg) == 55) end },
	{ "forward capped at 70", function() assert(forwardImpulse(140, cfg) == 70) end },
	{ "once-only reward per generation", function()
		local d = { generationId = 0, rewardClaimedGen = -1, dead = false }
		local function try(x)
			if x.dead or x.rewardClaimedGen == x.generationId then
				return false
			end
			x.rewardClaimedGen = x.generationId
			x.dead = true
			return true
		end
		assert(try(d) == true)
		assert(try(d) == false)
		d.dead = false
		d.generationId += 1
		assert(try(d) == true)
	end },
}
