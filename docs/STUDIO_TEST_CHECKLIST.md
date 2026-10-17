# Roblox Studio Manual Test Checklist — FART BRAINROT SIMULATOR

Statuses: PASS / FAIL / BLOCKED / UNTESTED. Studio runtime was NOT executed in this environment; mark all runtime tests UNTESTED until run in Studio.

## Setup
1. Enable Studio Access to API Services for DataStore tests.
2. Run `rojo build default.project.json -o build/FartBrainrotSimulator.rbxl` (expected exit 0).
3. Open `.rbxl` in Studio, press Play (or use Rojo serve).
4. Open Output window; expect no startup errors.

## 1. Startup and player spawn
- Player spawns at Beach spawn without errors.
- No console errors during startup.
- Map zones (Beach, City, Volcano, Space) and buildings appear.
- Leaderstats Power/Coins/Rebirths appear.
Status: UNTESTED

## 2. Attack and building destruction
- Clicking Body/roof/window/door resolves to same building.
- Out-of-range clicks rejected (notify error).
- Rapid clicks respect server cooldown.
- Health bar updates after hits; damage stages change color.
- Building reaches 0 health -> destroyed (reward toast + XP).
- Destroyed building cannot grant reward again.
- Concurrent attacks by two players do not double-pay.
- Building respawns after respawnTime with restored visuals.
Status: UNTESTED

## 3. Brainrot and pet inventory
- Starter Toxic Titan owned/equipped initially.
- Locked Brainrots show LOCKED; cannot be equipped.
- Equipping owned Brainrot updates damage/HUD.
- Hatch Basic Egg deducts coins; result always appears.
- Odds sum to 100% (meme_dog 50, cool_cat 25, gold_fish 15, dragon_doge 7, void_blob 3).
- Equip/unequip up to 3 pets.
- Bonus caps enforced.
Status: UNTESTED

## 4. Fart Jump
- F key / button activates jump.
- Cooldown enforced server-side (no infinite flight).
- Mobile touch button visible on touch devices.
- Cannot spam while airborne (grounded-only).
- First jump records milestone.
Status: UNTESTED

## 5. Shop, upgrades and rebirth
- Gear purchased in order; cost deducted.
- Rebirth requires power; cost formula matches Config.
- Rebirth resets power/coins/gear; rebirth count increments.
- World unlock gates by lifetime rebirths.
Status: UNTESTED

## 6. Save, leave and rejoin
- Rejoin retains coins/power/gear/brainrots/pets/milestones.
- Failed DataStore load does not overwrite real data (fail-safe).
- Autosave runs without errors.
- Shutdown saving flushes profiles.
Status: UNTESTED

## 7. Quests and boss
- Quest list populates; progress updates on destroy/hatch/jump/rebirth.
- Quest reward granted on completion (once).
- Settlement boss spawns with health bar; taking damage reduces it.
- Boss defeat grants coins/XP once; respawns after timer.
Status: UNTESTED

## 8. PvP isolation and rewards
- Challenge sent/received; accept creates match.
- Both players teleported to arena.
- Damage only within range/cooldown; outside-arena attacks blocked.
- Disconnect ends match; winner decided once.
- Winner reward granted exactly once.
Status: UNTESTED

## 9. Admin role permissions and commands
- F4 opens Admin panel only for staff (StaffRole attribute).
- Owner `kiill290` resolved safely; cannot be demoted/removed.
- Commands authorized per role (Tester/Admin/Moderator/Owner).
- grantCoins/grantBrainrot/grantPet/update via server only.
- setPower only in sandbox mode.
- Role changes persisted; caches invalidated.
Status: UNTESTED

## 10. Sandbox isolation
- Toggle sandbox shows TEST MODE indicator.
- Sandbox grants/currency do NOT modify production profile or leaderboard.
- Sandbox state not saved (saveProfile skips sandbox).
Status: UNTESTED

## 11. Multiple-player behavior and exploit resistance
- Two players attacking same building: one reward.
- Client-supplied velocity ignored in Fart Jump (server computes impulse).
- Client cannot equip unowned Brainrot/pet (server validates).
- Teleport to world with placeId=0 rejected ("not configured").
- World teleport below rebirth requirement rejected.
Status: UNTESTED