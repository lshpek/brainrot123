-- test_runner.luau — lune entry: lune run tests/test_runner
local TESTS = {
	"./shared/ConfigValidation.test",
	"./shared/Formulas.test",
	"./shared/FartJumpCurve.test",
	"./shared/Brainrot.test",
}

local passed = 0
local failed = 0

for _, path in ipairs(TESTS) do
	local ok, mod = pcall(require, path)
	if not ok then
		print("FAIL " .. path .. " (load): " .. tostring(mod))
		failed += 1
	else
		for _, case in ipairs(mod) do
			local name, fn = case[1], case[2]
			local okCase, err = pcall(fn)
			if okCase then
				print("PASS " .. path .. " :: " .. name)
				passed += 1
			else
				print("FAIL " .. path .. " :: " .. name .. " — " .. tostring(err))
				failed += 1
			end
		end
	end
end

print("========================================")
print("passed: " .. passed .. " failed: " .. failed)
print("========================================")
if failed > 0 then
	error("Test failures detected")
end
