# Asset Manifest — FART BRAINROT SIMULATOR

Status conventions:
- INTEGRATED: real imported model wired into the game, tested in Studio.
- PLACEHOLDER: code-generated visual (Part/emoji/texture); not a real 3D model.
- BLOCKED: real asset not imported; adapter/code exists, manual Studio import required.
- NONE: no asset configured.

No proprietary code, maps, branding, or asset bundles were ripped from another game. All gameplay patterns are original code.

## 1. Brainrots

| Brainrot id | Name | Asset ID | Source / provenance | Usage rights | Model structure | Pivot/scale | Integration status | Notes |
|---|---|---|---|---|---|---|---|---|
| toxic_titan | Toxic Titan | NONE | code-generated placeholder | original | N/A | N/A | PLACEHOLDER | Emoji + color only |
| skibidi_slayer | Skibidi Slayer | NONE | code-generated placeholder | original | N/A | N/A | PLACEHOLDER | Emoji + color only |
| grimace_gulp | Grimace Gulp | NONE | code-generated placeholder | original | N/A | N/A | PLACEHOLDER | Emoji + color only |
| sigma_smasher | Sigma Smasher | NONE | code-generated placeholder | original | N/A | N/A | PLACEHOLDER | Emoji + color only |
| giant_giant | Giant Giant | NONE | code-generated placeholder | original | N/A | N/A | PLACEHOLDER | Emoji + color only |
| meme_mogul | Meme Mogul | NONE | code-generated placeholder | original | N/A | N/A | PLACEHOLDER | Emoji + color only |

## 2. Pets

| Pet id | Name | Asset ID | Source / provenance | Usage rights | Integration status | Notes |
|---|---|---|---|---|---|---|
| meme_dog | Meme Dog | NONE | code-generated placeholder | original | PLACEHOLDER | Sphere/emoji follower |
| cool_cat | Cool Cat | NONE | code-generated placeholder | original | PLACEHOLDER | Sphere/emoji follower |
| gold_fish | Gold Fish | NONE | code-generated placeholder | original | PLACEHOLDER | Sphere/emoji follower |
| dragon_doge | Dragon Doge | NONE | code-generated placeholder | original | PLACEHOLDER | Sphere/emoji follower |
| void_blob | Void Blob | NONE | code-generated placeholder | original | PLACEHOLDER | Sphere/emoji follower |

## 3. Bosses

| Boss id | Name | Asset ID | Source | Integration status | Notes |
|---|---|---|---|---|---|
| settlement_boss | Slime Overlord | NONE | code-generated colored block | PLACEHOLDER | No real model |
| village_boss | Scarecrow King | NONE | code-generated colored block | PLACEHOLDER | No real model |
| city_boss | Traffic Titan | NONE | code-generated colored block | PLACEHOLDER | No real model |
| megacity_boss | Neon Colossus | NONE | code-generated colored block | PLACEHOLDER | No real model |
| space_city_boss | Void Leviathan | NONE | code-generated colored block | PLACEHOLDER | No real model |

## 4. Buildings

| Building id | Name | Asset ID | Source | Integration status | Notes |
|---|---|---|---|---|---|
| mailbox | Mailbox | NONE | code-generated multi-part | PLACEHOLDER | Procedural parts |
| fence | Fence Segment | NONE | code-generated multi-part | PLACEHOLDER | Procedural parts |
| shack | Wooden Shack | NONE | code-generated multi-part | PLACEHOLDER | Procedural parts |
| house | Brick House | NONE | code-generated multi-part | PLACEHOLDER | Procedural parts |
| town_hall | Town Hall | NONE | code-generated multi-part | PLACEHOLDER | Procedural parts |

## 5. VFX / SFX

| Asset | ID | Source | Status | Notes |
|---|---|---|---|---|
| punchSound | rbxasset://sounds/swoosh.wav | Roblox built-in | INTEGRATED | built-in |
| fartSound | rbxasset://sounds/fart.mp3 | Roblox built-in | INTEGRATED | built-in (may be placeholder id) |
| successSound | rbxasset://sounds/electronicpingshort.wav | Roblox built-in | INTEGRATED | built-in |
| errorSound | rbxasset://sounds/snap.mp3 | Roblox built-in | INTEGRATED | built-in |
| destroySound | rbxasset://sounds/swoosh.wav | Roblox built-in | INTEGRATED | built-in |

## 6. Cosmetics / Skins

| Skin id | Name | Asset ID | Source | Integration status | Notes |
|---|---|---|---|---|---|
| toxic_titan_default | Standard | NONE | original code config | INTEGRATED (data only) | color/material config |
| toxic_titan_neo | Neon Sludge | NONE | original code config | INTEGRATED (data only) | no model change yet |
| skibidi_slayer_default | Standard | NONE | original code config | INTEGRATED (data only) | |
| sigma_smasher_default | Standard | NONE | original code config | INTEGRATED (data only) | |
| meme_mogul_gold | Gold Plated | NONE | original code config | INTEGRATED (data only) | |

Skins are registered and server-validated but do not yet visually change an imported model.

## Manual import steps (when assets are available)

1. Obtain the model from the Roblox Creator Store or your own original work; confirm permitted usage.
2. Insert the model into Studio (Toolbox -> My Models / published asset ID).
3. Inspect all descendants for scripts; remove any unexpected/unwanted scripts.
4. Normalize scale (studs) and set PivotOffset to the model's base center.
5. Set CanCollide on structural parts; CanCollide = false on decorative/VFX parts.
6. Anchor static building/boss parts; leave followers/pets unanchored (client CFrame-follow).
7. Name the primary hit part `Body` and add a `BillboardGui` named `HealthBar` for damage display.
8. Parent under the appropriate world folder in workspace.Map.
9. Register the real Asset ID in this manifest and the relevant config.
10. Update the integration status from PLACEHOLDER/BLOCKED to INTEGRATED after a Studio playtest.

## Blockers

- No real 3D Brainrot, pet, boss, or building models are imported. All are code-generated placeholders.
- Real model integration is BLOCKED pending Creator Studio access and asset selection/procurement.
- Until real models are imported, mark all model-related acceptance items as PARTIAL/BLOCKED.
