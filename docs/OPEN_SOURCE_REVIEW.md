# OPEN SOURCE REVIEW — 2026-10-17 (commit SHAs BLOCKED: no git/curl clone in env; verified via GitHub page fetch)
| Candidate | URL | License observed | Verdict |
|---|---|---|---|
| MadStudioRoblox/ProfileStore | https://github.com/MadStudioRoblox/ProfileStore | Apache-2.0 badge + LICENSE file (345★, session-locking single ModuleScript) | PATTERN_ONLY — keep Data.luau, backport lease/release ideas; no migration without compat plan |
| Sleitnick/RbxUtil (Trove/Signal) | https://github.com/Sleitnick/RbxUtil | MIT badge + LICENSE.md (467★, Trove/Signal/Spring…) | PATTERN_ONLY — reimplement tiny Trove locally with tests; do NOT vendor framework |
| Roblox/creator-docs LICENSE-CODE | https://github.com/Roblox/creator-docs/blob/main/LICENSE-CODE | MIT text confirmed (Copyright 2023 Roblox, full MIT grant) | ADAPT (patterns) — preferred source for API usage |
| lukas-mikalainis/roblox-precision-framework | https://github.com/lukas-mikalainis/roblox-precision-framework | MIT badge + LICENSE file, 1 commit, 0★ prototype | PATTERN_ONLY — server-validates-move/cooldown pattern only; NOT production-proven |
| dariyed/DemolitionSimulator | https://github.com/dariyed/DemolitionSimulator | NO LICENSE file in listing (README/CLAUDE/docs/src/tests only) | REJECT for copy/vendor — concepts only, implement independently |
| kpackk/roblox-gameplay-systems, Tristan886/Pet-System, sploithunter/HaloAndHorns, Hinikaa/luaukit, zilibobi/forge-vfx | (from addendum) | ВЕРИФИЦИРОВАНЫ 3rd pass (см. ниже) | см. A–G ниже |
Notes: stars≠quality. Trove fetch 404 (submodule split to wally packages). DemolitionSimulator has tests/+lune+selene+stylua configs but no license → cannot use.

## 2nd pass (2026-10-17, поздняя проверка): полные поля по §4 addendum
Дата проверки: 2026-10-17, default branch всюду `main`, commit SHA: BLOCKED (нет clone/curl в окружении — только GitHub HTML fetch). Вывод не меняется: копирование целиком запрещено; только PATTERN_ONLY / KEEP_AND_FIX + собственный код с тестами.

### A. kpackk/roblox-gameplay-systems — https://github.com/kpackk/roblox-gameplay-systems
LICENSE: **MIT CONFIRMED 3rd pass** (badge + LICENSE file, 0★, 2 commits, branch main). Server-authoritative inventory (UpdateAsync, 3 retries exp-backoff, BindToClose, save-wipe guard, load-sanitize, mock fallback) + combat (pure rules: HP/damage/cooldown/stun/range/60° cone, time-injected, server-confirmed cooldown UI). Tests in-repo, no live game needed. Score: fit 3, lic 5, sec 4, tests 4, compat 3, read 4, perf 4, docs 3 → ~3.6 < 4 → копировать целиком нельзя (0★, не proven + чужой инвентарь не нужен).
Verdict: **PATTERN_ONLY** (подтверждено: наши CombatService/Data.luau уже реализуют те же инварианты; чужие тесты — образец для наших).

### B. MadStudioRoblox/ProfileStore — https://github.com/MadStudioRoblox/ProfileStore
LICENSE: Apache-2.0 (badge + LICENSE file; коммерция + модификация OK, нужен NOTICE). 345★/66 forks, single-ModuleScript session-locking. Score fit 2 (миграция = риск вайпа) → PATTERN_ONLY, миграции нет.

### C. Tristan886/Pet-System — https://github.com/Tristan886/Pet-System
LICENSE: **MIT CONFIRMED 3rd pass** (badge + LICENSE file, 0★, 7 commits, branch main; файлы InventoryHandler.lua/ServerPetHandler.lua). Equip/unequip/sell (single+bulk), tail-formation follow, secure DataStore. Exploit-векторы для нашего аудита: sell equipped, sell non-owned, duplicate ids — у нас продажа идёт через серверный Data.trySpend/ownPet, владение проверяется. Verdict: **PATTERN_ONLY** (tail-formation идея уже отражена в PetFollower FORMATION_OFFSETS; вендоринга нет).

### D. sploithunter/HaloAndHorns — https://github.com/sploithunter/HaloAndHorns
LICENSE: **MIT CONFIRMED 3rd pass** (badge + LICENSE file, 5★, 1712 commits, branch main; есть selene.toml/stylua.toml/testez.yml/wally.toml, tests/headless lune 1653/1653 по их wiki). Config-as-code (configs/), CommandBus (единый RemoteFunction GameAPICommand), test-pyramid (headless → command-bus → UI sanity), mise run ci. Слишком велик для вендоринга (свой framework + assets с непроверенными правами). Verdict: **PATTERN_ONLY** — взяли: headless-lune пирамиду (наш tests/test_runner), config-validation при старте, архитектура single-remote-bus как референс (наши Remotes уже централизованы в init.server).

### E. Hinikaa/luaukit — https://github.com/Hinikaa/luaukit
LICENSE: **MIT CONFIRMED 3rd pass** (badge + LICENSE file, 1★, 5 commits, branch master; 8 модулей: Trove/Signal/Spring/StateMachine/Promise/DataStore/Net/Bench, standalone lua5.1 tests). Ключевые находки для нас: Get различает "no data" vs "read failed" (не затирать сейв при ошибке чтения — у нас это STATE_FAILED guard уже есть); Set=last-write-wins, для конкурирующих записей нужен Update(read-modify-write, lockOwner=game.JobId per-attempt); RateLimiter per-player-per-endpoint. Verdict: **PATTERN_ONLY** — вендоринга нет, только локальный Trove.luau; Data.luau сверить с Update-семантикой при следующем патче.

### F. lukas-mikalainis/roblox-precision-framework — https://github.com/lukas-mikalainis/roblox-precision-framework
LICENSE: MIT (badge + LICENSE), но 1 commit / 0★ прототип → PATTERN_ONLY (только серверная валидация).

### G. zilibobi/forge-vfx — https://github.com/zilibobi/forge-vfx
LICENSE: **CUSTOM source-available copyleft CONFIRMED 3rd pass** (README: "licensed under a custom source-available copyleft license which only allows usage within Roblox games", 18★, 151 commits, branch main, есть LICENSE file). НЕ MIT → hard gate не пройден для свободного вендоринга. Verdict: **REJECT**; остаёмся на native effects + Effects.luau.

### H. Roblox/creator-docs — LICENSE-CODE https://github.com/Roblox/creator-docs/blob/main/LICENSE-CODE
LICENSE: MIT, полный текст подтверждён (Copyright 2023 Roblox) → ADAPT (patterns), эталон API.

### I. dariyed/DemolitionSimulator — https://github.com/dariyed/DemolitionSimulator
LICENSE: НЕ НАЙДЕН (файлов LICENSE нет) → REJECT для копирования; идеи (generationId + once-only reward) реализованы независимо.

### Доп. Sleitnick/RbxUtil — https://github.com/Sleitnick/RbxUtil
LICENSE: MIT (badge + LICENSE.md, 467★) → PATTERN_ONLY (локальный Trove без зависимости).
