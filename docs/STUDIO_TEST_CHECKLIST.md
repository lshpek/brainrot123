# Roblox Studio Manual Test Checklist

Runtime tests were not executed in this environment. Use this checklist in Studio.

## Setup
1. Enable Studio Access to API Services for DataStore tests.
2. Run `rojo build default.project.json -o build/FartBrainrotSimulator.rbxl`.
3. Open the `.rbxl` in Studio and press Play (or use Rojo serve).

## Spawn and map
- Player spawns on Beach without errors.
- No console errors during startup.
- Buildings appear in zones.

## Building attacks
- Clicking Body, window, roof, door, foundation resolves to same building.
- Out-of-range clicks are rejected.
- Rapid clicks respect cooldown.
- Health bar updates after hits.
- Damage stages visually change.

## Destruction and rewards
- Building reaches 0 health and becomes destroyed.
- Reward toast shows coins/XP.
- Destroyed building cannot be attacked for reward again.
- Concurrent attacks by two players do not double-pay.
- Building respawns after configured time with full health and restored visuals.

## Pets
- Hatch Basic Egg deducts coins.
- Hatch result always appears.
- Newly hatched pet appears immediately in inventory.
- Odds sum to 100% (meme_dog 50, cool_cat 25, gold_fish 15, dragon_doge 7, void_blob 3).
- Equip/unequip works up to 3 pets.
- Bonus caps enforced.

## Brainrot
- Starter Toxic Titan owned/equipped initially.
- Unowned Brainrots show LOCKED and cannot be equipped.
- Equipping owned Brainrot updates damage.
- XP/level persists per character.

## Fart Jump
- F key and button activate jump.
- Cooldown works.
- Mobile button visible on touch devices.
- Cannot spam infinite flight.
- Milestone first_fartjump recorded.

## Upgrades and rebirth
- Gear purchase order enforced.
- Rebirth requires enough power.
- Rebirth resets power/coins/gear but preserves collection/pets/milestones.
- Character respawns after rebirth.

## Save/rejoin
- Rejoin retains coins/power/gear/brainrots/pets/milestones.
- Failed DataStore load does not overwrite data.
- Autosave runs without errors.

## Monetization
- Products with ID 0 remain hidden.
- No live purchase tested (IDs unconfigured).
