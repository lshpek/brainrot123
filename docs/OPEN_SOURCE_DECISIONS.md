# OPEN SOURCE DECISIONS — 2026-10-17
| Subsystem | Decision | Why | Scope |
|---|---|---|---|
| Destruction lifecycle | KEEP_AND_FIX | DemolitionSimulator has NO LICENSE → cannot copy; own BuildingService already server-authoritative | Add generationId + once-only reward token, stale-respawn guard |
| Combat/PvP validation | KEEP_AND_FIX (+ PATTERN_ONLY from kpackk MIT + precision-framework MIT) | Own PvP validates membership/range/cooldown; kpackk (MIT, 0★, 2 commits) confirms pattern — time-injected pure combat rules + facing-cone target select; prototype precision-framework 1-commit/0★ | Server damage kept; sweep already present; no vendor |
| Pets follow/sell | PATTERN_ONLY (Tristan886 MIT + HaloAndHorns MIT) | Tristan886/Pet-System MIT (0★, 7 commits): equip/unequip/sell + tail formation — exploit vectors (sell equipped/duplicate ids) noted; HaloAndHorns MIT (5★, 1712 commits): config-as-code + headless lune pyramid — too large to vendor | Tail-formation idea applied to own PetFollower; sell/equip validation stays server-side in Data/CombatService |
| Helpers (Trove/Net/StateMachine) | PATTERN_ONLY (luaukit MIT + RbxUtil MIT) | luaukit MIT (1★): Trove/Signal/StateMachine/Promise/DataStore/Net/RateLimiter, standalone lua5.1 tests; RbxUtil MIT (467★). Rule: no framework-for-framework | Only local Trove.luau reimplemented; rate-limit stays per-endpoint os.clock checks |
| FartJump curve | KEEP_AND_FIX | Asymptotic curve already correct (base55/max140/k2500); no framework needed | Add pure-function tests via Formulas-style module |
| Pets follow | PATTERN_ONLY (RbxUtil/Trove) | Client follow OK but leaks connections; no vendor | Local Trove.luau + wire PetFollower/Effects cleanup |
| Persistence | PATTERN_ONLY (ProfileStore Apache-2.0) | Data.luau already has wipe-guard/session lease; full migration too risky | Backport release-on-leave + BindToClose flush (already present) — no migration |
| Config/economy | KEEP_AND_FIX | ConfigValidation already checks dup ids/hatch 100/egg refs | Extend validation: negative prices, world ordering |
| PvP challenge sweep | KEEP (уже есть) | Экспайр-челленджи уже чистятся каждые 5с в PvPService.start | sweep проверен чтением кода |
| CI: lint+tests | ADAPT (infra) | К Rojo-build добавлены StyLua-check, Selene, Lune tests/test_runner | selene.toml создан; CI ждёт прогона в GitHub Actions |
| VFX | REJECT forge-vfx copy (custom VFX-DL-1.1 copyleft-ish) | Use native ParticleEmitter/Trail + own Effects.luau | No new dependency |
P0 first: reward-duplication guard + data-wipe guard + remote spam limits.
