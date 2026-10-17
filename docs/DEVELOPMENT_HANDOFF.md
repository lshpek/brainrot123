# Development Handoff

## Current task
Stage B (Data Integrity, Sandbox Isolation, Idempotent Rewards, Server Security) complete.
- Verified Stage A `Data.luau` lexical-scoping fix is in place: all shared local state declared before public methods; `Data.get`/`Data.save` use correct locals; active-profile abstraction routes sandbox vs production.
- Added session-lock / stale-write protection to `Data.luau` (per-session lease token stored as `profile.sessionToken`, enforced in `UpdateAsync`, released on `PlayerRemoving` and `BindToClose`).
- `QuestService.luau`: `completeQuest` grants reward once, persists claim+reward together via one `Data.save`, rolls back in-memory grant on save failure (idempotent, retryable; non-atomic across DataStores — documented).
- `Monetization.luau`: receipt flow already safe — validates product IDs, rejects id==0/unknown, never trusts client amounts, dedupes by PurchaseId, rolls back on save failure, never acks before durable save, sandbox returns PurchaseGranted without granting.
- `AdminService.luau`: added per-player per-command rate limiting (`ADMIN_COMMAND_COOLDOWN = 1.0s`).
- Confirmed all damage routes (building, boss, PvP) are server-authoritative: range from actual character position, cooldowns, registry membership, dead-target rejection, one-time rewards, no client-trusted damage.
- Confirmed PvP attack flow wired end-to-end (PvPUi attack button -> PvPAttack remote -> server-validated match attack).
- Confirmed no profile-mutating code outside `Data.luau` bypasses `activeProfile` (all `profiles[]` accesses are internal to Data.luau).

## Files changed (this pass)
- `src/server/Data.luau` — added `SESSION_LEASE`, `sessionTokens` table; load rejects profiles with live session locks; save enforces lock + renews lease; PlayerRemoving/BindToClose release locks.
- `src/server/QuestService.luau` — `grantQuestReward` returns granted amounts; `completeQuest` persists via `Data.save` then notifies; save failure rolls back grant (coins + XP) so retry is safe.
- `src/server/AdminService.luau` — added `lastAdminCommand` rate-limit table + cooldown enforcement; cleanup on PlayerRemoving.

## Last verified
- rojo build: exit 0 (`./rojo.exe build default.project.json -o build/FartBrainrotSimulator.rbxl`) — PASS.
- stylua --check src: NOT available (Stylua not installed on this machine) — UNTESTED/tooling gap.
- Studio runtime tests: UNTESTED (no Roblox Studio / Luau runtime in this environment).

## Next actions
1. Install Stylua and run `stylua --check src` (lint).
2. Execute `docs/STUDIO_TEST_CHECKLIST.md` in Roblox Studio; record PASS/FAIL/BLOCKED per item.
3. Create 5 Places in Creator Dashboard; fill `Config.Worlds[].placeId`; test travel both ways + persistence.
4. Import real Brainrot/pet/boss 3D models; update `docs/ASSET_MANIFEST.md`; mark integration INTEGRATED.
5. Run automated unit tests (weighted selection, reward idempotency, migrations, receipt abstraction, sandbox routing, world unlock rules) once a Luau test runner is available.

## Open items (not part of Stage B)
- Five distinct world Place IDs are 0 until created in Creator Dashboard (BLOCKED on external action).
- Real 3D Brainrot/pet/boss models are code-generated placeholders (PARTIAL/BLOCKED).
- Admin 12-tab panel visual build-out (future stage).
