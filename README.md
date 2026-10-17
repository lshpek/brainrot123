# 💨 FART BRAINROT SIMULATOR

A Roblox simulator built **in code** — map, UI, and economy are generated from Luau source and synced with [Rojo](https://rojo.space). You punch destructible **buildings**, collect **Brainrots** and **pets**, upgrade **strength**, rebirth for permanent multipliers, and launch around with the signature **Fart Jump**.

[![CI](https://github.com/lshpek/brainrot123/actions/workflows/ci.yml/badge.svg)](https://github.com/lshpek/brainrot123/actions/workflows/ci.yml)

## The game

Punch and **destroy buildings** for coins + XP → equip and level **Brainrots** (individual progression) and **pets** → buy **gear** that multiplies your power → unlock stronger **zones** → **Rebirth** for a permanent multiplier → climb the cross-server leaderboard — all while chaining the **Fart Jump** to get around faster.

- **Destructible multi-part buildings** (house / shop / civic / shed archetypes) with health bars, damage stages, one-time rewards and respawn — [BuildingService](src/server/BuildingService.luau)
- **Brainrot collection** with per-character levels, XP, damage and rarity — [BrainrotService](src/server/BrainrotService.luau)
- **Pets & eggs**: server-rolled hatching, equip up to 3, bounded bonuses — [PetUi](src/client/PetUi.luau)
- **Fart Jump**: server-authoritative burst leap scaled by strength (diminishing returns + hard caps) — [FartJumpService](src/server/FartJumpService.luau)
- **Five worlds** (Settlement, Village, City, Megacity, Space City) + a VIP island, procedurally built by [MapBuilder](src/server/MapBuilder.luau) from [Config](src/shared/Config.luau)
- **Rebirth** with exponential cost scaling and permanent bonuses
- **First-session onboarding** that tracks real milestones and never repeats — [Onboarding](src/client/Onboarding.luau)
- **Persistent data** with distinct load states (loaded / new / failed), autosave, and graceful Studio fallback — [Data](src/server/Data.luau)
- **Global top-10 leaderboard** on a physical board (OrderedDataStore)
- **Monetization**: 4 gamepasses + 3 coin-pack products with durable, retry-safe receipt handling (IDs still `0` = disabled)
- **Server-authoritative everywhere**: punch/attack rate limits, cooldowns, range checks, zone bonuses validated against real position, receipts granted server-side

## Architecture

```
src/
├── shared/            # replicated to both sides
│   ├── Config.luau    # every tunable number: balance, zones, gear, product IDs
│   └── Formulas.luau  # pure math shared by server (authority) and client (display)
├── server/
│   ├── init.server.luau      # entry: creates remotes, wires services (explicit DI)
│   ├── Data.luau             # profiles, DataStore, leaderstats, autosave
│   ├── Training.luau         # punch loop, rate limiting, zone validation, Auto Train
│   ├── Shop.luau             # gear purchases + rebirths (server-validated)
│   ├── Monetization.luau     # gamepass cache + ProcessReceipt
│   ├── MapBuilder.luau       # builds the entire world from Config
│   └── GlobalLeaderboard.luau
└── client/
    ├── init.client.luau
    ├── UI.luau        # tiny declarative UI toolkit + window manager
    ├── Hud.luau       # stat pills, TRAIN button, menu
    ├── ShopUi.luau    # gear tab + robux tab
    ├── RebirthUi.luau
    ├── Effects.luau   # popups, toasts, sounds
    ├── ZoneGates.luau # client-side gate unlocking (server validates the bonus)
    ├── FartJumpClient.luau
    ├── AttackClient.luau
    ├── BrainrotClient.luau
    ├── PetUi.luau
    ├── PetFollower.luau
    ├── QuestsUi.luau
    ├── PvPUi.luau
    ├── WorldsUi.luau
    ├── Onboarding.luau
    └── AdminUi.luau
```

**Security model:** the client is only ever a *view*. It fires intent ("I punched", "buy gear 3") and renders replicated state (leaderstats + attributes). The server recomputes every multiplier, enforces the punch cooldown, checks gear order and costs, and validates zone bonuses against the character's actual position — so exploiters gain nothing by firing remotes directly.

## Run it locally

1. Install [Roblox Studio](https://create.roblox.com/) and [Rojo](https://rojo.space/docs/v7/getting-started/installation/) (or use `rojo.exe` if present)
2. Build the place file:
   ```
   rojo build default.project.json -o build/FartBrainrotSimulator.rbxl
   ```
3. Open the `.rbxl` in Studio and hit **Play**

For live-sync development instead: `rojo plugin install` once, then `rojo serve` and connect from Studio's Rojo plugin.

> DataStores and gamepasses are silently disabled in unpublished local playtests — the game detects this and runs with in-memory data.

## Enabling monetization

1. Publish the game (File → Publish to Roblox)
2. Creator Dashboard → your experience → **Monetization**:
   - Create 4 **Passes**: 2x Power (199 R$), 2x Coins (199 R$), Auto Train (349 R$), VIP (499 R$)
   - Create 3 **Developer Products**: 25K Coins (49 R$), 150K Coins (199 R$), 1M Coins (799 R$)
3. Paste the IDs into `Config.GamePasses` / `Config.DevProducts` in [Config.luau](src/shared/Config.luau)
4. Game Settings → Security → enable **Studio Access to API Services** (for DataStores in Studio)

Items with an ID of `0` are hidden from the shop automatically, so the game is fully playable before this step.

## License

See [LICENSE](LICENSE).