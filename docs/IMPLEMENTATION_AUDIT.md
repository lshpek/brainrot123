# Implementation Audit — FART BRAINROT SIMULATOR

Last updated: 2026-10-17 (Stage B complete)

## Verified commands
- `rojo build default.project.json -o build/FartBrainrotSimulator.rbxl` -> exit 0 (PASS, run).
- `stylua --check src` -> NOT RUN (Stylua not installed on this machine; tooling gap).

## Defects found and fixed (Stage B)

| Defect | Files | Fix |
|---|---|---|
| Stale-session overwrite: `UpdateAsync` returned the in-memory profile unconditionally, so a displaced/expired session could overwrite newer saved values | `src/server/Data.luau` | Added per-session lease token (`profile.sessionToken`); `UpdateAsync` refuses to overwrite when another session holds a live lock; lease renewed on every save; released on `PlayerRemoving`/`BindToClose`. |
| Load could clobber a profile owned by another active server session | `src/server/Data.luau` | `loadProfile` checks `data.sessionToken.expiresAt`; returns `STATE_FAILED` (no load, no save) when a live lock exists. |
| Quest reward could be granted but not persisted; `claimed` set without save | `src/server/QuestService.luau` | `completeQuest` grants reward in memory, sets `completed`+`claimed=true`, then calls `Data.save` once (claim+reward persisted together); save failure rolls back the in-memory grant so retry is safe and no duplicate reward is durable. |
| AdminCommand remote had no rate limiting (remote-spam vector) | `src/server/AdminService.luau` | Added per-player per-command cooldown (`ADMIN_COMMAND_COOLDOWN = 1.0s`); table cleaned on `PlayerRemoving`. |

## Previously fixed (Stage A) — retained
| Defect | Files | Fix |
|---|---|---|
| `Data.get`/`Data.save` referenced locals declared later (globals fallback) | `src/server/Data.luau` | Moved all shared local state (`profiles`, `sandboxProfiles`, `sandboxEnabled`, `store`, `saveProfile`) before public methods; added `activeProfile()` accessor. |
| `Data.save` not defined / sandbox could persist to production | `src/server/Data.luau` | `saveProfile` skips sandbox players; `Data.get` returns sandbox profile when sandbox active; `sync()` reads active profile. |

## Feature status (code-level; Studio runtime NOT executed)

| Feature | Status | Notes |
|---|---|---|
| Data loading/saving + migrations | PARTIAL | Schema v2, idempotent migration, fail-closed on failed load; Studio untested |
| Session lock / stale-write protection | PARTIAL | Lease enforced in `UpdateAsync`; cross-server untested |
| Sandbox isolation | PARTIAL | Isolated in-memory copy, never persisted, sandbox-aware mutators; Studio untested |
| Core attack/destruction loop | PARTIAL | Server-authoritative damage, range, cooldown, registry; Studio untested |
| Multi-part buildings / damage stages | PARTIAL | Code-generated structures; visual staging; Studio untested |
| Brainrot collection & progression | PARTIAL | Ownership/levels/XP/roles server-computed; skins data-only; Studio untested |
| Pets & eggs | PARTIAL | Server-rolled hatch, weighted odds, equip limit; code-generated models; Studio untested |
| Fart jump | PARTIAL | Server-authoritative bounded impulse; Studio untested |
| Five worlds (Places) | MISSING/BLOCKED | Registry + safe teleport; Place IDs = 0 (Creator Dashboard needed) |
| Rebirth/upgrades | PARTIAL | Resets power/coins/gear; preserves rebirths, Brainrots, pets, milestones |
| Bosses | PARTIAL | Framework + all 5 configured; spawned per-world at startup; Studio untested |
| Quests | PARTIAL | Idempotent completion, 8 quests, reward-once; Studio untested |
| PvP 1v1 | PARTIAL | Challenge/accept/expiry, server-validated attack, per-world arenas, cleanup; Studio untested |
| Admin panel | PARTIAL | Roles + rate limit + sandbox enforcement; UI basic; 12-tab build-out pending |
| Monetization | PARTIAL | IDs = 0 (disabled); safe receipt flow; not atomic across stores (documented) |
| Analytics | PARTIAL | Best-effort; milestones tracked |
| Performance | UNTESTED | No measurements |

## Remaining failure boundaries
- Receipt processing: profile save + receipt-store marker are separate DataStore writes; not atomic. If profile saves but receipt-store marker write fails, profile is source of truth (receipt recorded in profile) so no double-grant; recovery path reconciles on next `processReceipt`.
- Cross-server session lease: lease-based, expires after `SESSION_LEASE` (90s) if a server crashes; a new server cannot load while a live lock exists.
- Place IDs 0: separate Places cannot be teleported to until created in Creator Dashboard and IDs filled in `Config.Worlds`.
- No real 3D Brainrot/pet/boss models integrated (code-generated placeholders only).
- Studio runtime tests UNTESTED.
