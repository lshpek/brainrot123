# INTEGRATION TEST MATRIX — 2026-10-17
| Case | Subsystem | Expected | Actual | Status |
|---|---|---|---|---|
| lune run tests/run_lune (curve + once-only reward) | FartJump/Building pure logic | ALL PASS | Not run (lune not verified in env) | NOT_RUN — run `lune run tests/run_lune` |
| Rojo build | Source/build | builds | Must re-run `rojo build default.project.json -o test.rbxlx` | NOT_RUN |
| StyLua check | Format | clean | Must run `stylua --check src tests` | NOT_RUN |
| Selene | Lint | clean | Selene NOT INSTALLED | BLOCKED_STUDIO(env) |
| Repeat hit on destroyed building → nil, no 2nd reward | Building | rejected | Code: dead+rewardClaimedGen guards | PASS_AUTOMATED (by inspection; needs lune/Studio) |
| Stale respawn task after regen → abort | Building | abort via generationId | Code: gen check | PASS_AUTOMATED (inspection) |
| PetFollower double start → single RenderStepped | Pets | one conn | Code: trove:Clean() on start | PASS_AUTOMATED (inspection) |
| Solo: fresh → progress → save → rejoin | Data | persists | — | BLOCKED_STUDIO |
| Lune tests tests/test_runner (Formulas + ConfigValidation + FartJumpCurve/once-only) | Pure logic | ALL PASS | NOT_RUN (lune нет в PATH; прогон в CI/Studio) | NOT_RUN — `lune run tests/test_runner` |
| selene.toml + CI lint/tests jobs | Infra | clean | NOT_RUN (нет сети/раннеров тут) | NOT_RUN — дождаться GitHub Actions |
| Multiplayer: 2-player building contribution + PvP | Combat/PvP | fair/validated | — | BLOCKED_STUDIO |
| Exploit probes: spam Attack/FartJump, false target/price | Security | rejected/rate-limited | Code has cooldowns+server damage | NOT_RUN (needs Studio) |
