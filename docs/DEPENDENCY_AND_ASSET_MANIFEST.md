# DEPENDENCY AND ASSET MANIFEST — 2026-10-17
| Item | Source | License | Used where | Notes |
|---|---|---|---|---|
| Trove.luau (local) | Independently reimplemented; pattern from Sleitnick/RbxUtil MIT (https://github.com/Sleitnick/RbxUtil) | Project-owned (no vendor) | src/shared/Trove.luau → PetFollower | No external package; attribution in header |
| ProfileStore patterns (lease/release/wipe-guard) | MadStudioRoblox/ProfileStore Apache-2.0 (https://github.com/MadStudioRoblox/ProfileStore) | Not vendored — ideas only | src/server/Data.luau (already had guards) | No migration; no NOTICE needed |
| Roblox API patterns | Roblox/creator-docs LICENSE-CODE MIT (https://github.com/Roblox/creator-docs/blob/main/LICENSE-CODE) | MIT code samples | General API usage | Include copyright notice if pasting samples |
| kpackk patterns (save-wipe guard, UpdateAsync+retries, time-injected combat rules, server-confirmed cooldown UI) | kpackk/roblox-gameplay-systems MIT (https://github.com/kpackk/roblox-gameplay-systems), 0★/2 commits | Not vendored — ideas only (already implemented) | CombatService/Data.luau review | No copying; README claims verified against our code |
| Tristan886 Pet-System patterns (equip/sell validation, tail formation) | Tristan886/Pet-System MIT (https://github.com/Tristan886/Pet-System), 0★/7 commits | Not vendored — ideas only | PetFollower formation; no sell endpoint in our game (nothing to patch) | Sell-equipped/duplicate-id vectors checked: N/A (no sell API) |
| HaloAndHorns patterns (config-as-code, headless lune pyramid, CommandBus) | sploithunter/HaloAndHorns MIT (https://github.com/sploithunter/HaloAndHorns), 5★/1712 commits | Not vendored — too large; ideas only | tests/test_runner + ConfigValidation-at-startup | Assets (models/sounds) NOT used — separate rights unconfirmed |
| luaukit patterns (Get: no-data vs read-failed; Set vs Update; per-player RateLimiter) | Hinikaa/luaukit MIT (https://github.com/Hinikaa/luaukit), 1★/branch master | Not vendored — ideas only | Data.luau STATE_FAILED guard confirmed; Update-semantics TODO | No copying |
| forge-vfx | zilibobi/forge-vfx CUSTOM source-available copyleft (https://github.com/zilibobi/forge-vfx), 18★ | REJECTED — not vendored | N/A | Custom license forbids free vendoring |
| DemolitionSimulator | https://github.com/dariyed/DemolitionSimulator — NO LICENSE found | DO NOT COPY | Concepts only | |
| Sounds (rbxasset://) | Built-in Roblox ids in Effects.luau | Roblox-owned | Client SFX | Replace fart.mp3 placeholder; see ASSET_MANIFEST.md |
No new Wally/Rokit packages added. No Toolbox models added.
