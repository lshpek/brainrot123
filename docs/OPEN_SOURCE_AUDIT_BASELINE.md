# OPEN SOURCE AUDIT BASELINE — 2026-10-17
Workspace: C:\Users\1\Desktop\power-punch-simulator | Branch: main | Remote: https://github.com/lshpek/brainrot123.git
Uncommitted: M src/client/FartJumpClient,Hud,ZoneGates,init.client + M src/server/Data,FartJumpService,MapBuilder,QuestService,Config + ?? docs/IMPLEMENTATION_STATUS.md (user changes preserved, no reset/clean/commit/push done).

## Function map (DONE_AND_TESTED vs rest)
- DONE (build passes per IMPLEMENTATION_STATUS.md, needs re-verify): boot order fix, zone config fix, Data session token + quest rollback forward-decl fixes, UI/mobile overlap fix, FartJump asymptotic curve (base 55/max 140/k 2500).
- IMPLEMENTED_UNVERIFIED: Data load/save/autosave/sandbox/wipe-guard (src/server/Data.luau), Training/Shop/Rebirth/Monetization, MapBuilder 5 worlds + ZoneGates, BuildingService (server-authoritative damage, but NO generationId, NO contribution split, respawn closure races stale task), CombatService (range+cooldown validate, server damage), BossService (central damageBoss), PvPService (challenge TTL 30s, match bind, range 20/cooldown 0.8, idempotent endMatch), BrainrotService/Pets/Eggs, QuestService idempotent claimed flag + rollback, ConfigValidation (unique ids, hatch 100, egg refs), FartJumpService (intent-only, grounded raycast, cooldown-before-apply).
- PARTIAL: destruction lifecycle (Intact->Damaged->Destroyed->Respawn only; no Critical/CollapseStarted states), PvP (no Countdown/Accepted states, no rematch TTL), pets (client visual follow only, no server update budget), VFX (Effects.luau placeholders).
- MISSING: lune/headless unit tests (no tests/ dir), Selene (NOT INSTALLED), state-machine module, Trove/Janitor cleanup (PetFollower leaks RenderStepped + attribute conns), reward ledger, schema migration beyond v2 defaulting.
- BLOCKED_BY_STUDIO: DataStore live, multiplayer (2-player), touch/gamepad, perf/FPS, animation/VFX playback — all need Studio playtest; NOT_RUN here.

## Local checks baseline
- Rojo build: PASS previously (IMPLEMENTATION_STATUS.md); must re-run after changes.
- StyLua: PASS on sample; Selene: missing; Lune/tests: none; CI: check .github/workflows.
- Rules: no prod DataStore key/name change, no commit/push, sandbox test profile isolated.
