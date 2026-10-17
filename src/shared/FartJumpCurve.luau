-- FartJumpCurve.luau — pure impulse curve (testable without Roblox Instances).
-- Mirrors Config.FartJump tuning; server remains authoritative.
local FartJumpCurve = {}

function FartJumpCurve.upwardImpulse(power: number, cfg: { [string]: any }): number
	local base = cfg.baseImpulse or 0
	local maxImpulse = cfg.maxImpulse or 140
	local scaleK = cfg.scaleK or 2500
	if power <= 0 then
		return math.clamp(base, 0, maxImpulse)
	end
	local maxDelta = maxImpulse - base
	local scaled = maxDelta * power / (power + scaleK)
	return math.clamp(base + scaled, 0, maxImpulse)
end

function FartJumpCurve.forwardImpulse(up: number, cfg: { [string]: any }): number
	return math.min(up * (cfg.forwardFactor or 0.8), cfg.maxForwardImpulse or 70)
end

return FartJumpCurve
