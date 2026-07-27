# Last Home

Co-op mod for Project Zomboid (B41). Players defend a building against growing waves of zombies. Between each wave, they craft, repair, and prepare their defenses. Survive as long as possible.

MP mod (Host / sandbox). The scenario building is hardcoded via a single Lua constant (`LastHomeShared.SCENARIO_HOUSE`), currently forced to **Ecole elementaire**. Edit that line and relaunch to play another building.

## Concept

- **Co-op** up to 8 players (duplicate roles allowed)
- **Real-time waves**: 2 min prep for wave 1, then 5 min; each wave lasts 5 min
- **Building** among 4 (Hospital, Villa, Prison, Elementary School), selected by `LastHomeShared.SCENARIO_HOUSE` (`hospital | villa | prison | elementary_school | random`)
- **Increasing horde directions**: 1 direction at first, then 2, 3, up to 360° — with per-location gameplay exceptions if needed
- **Permadeath**: dead players become spectators and can spawn 1 zombie during subsequent waves
- **17 roles** taken from Escapade Express (without Mechanic, with Builder)
- **Unlimited survival**: score = number of waves survived

## How to run (MP Host)

1. Enable the mod in a multiplayer Host game (`Mods = LastHome`, `Map = Muldraugh, KY`).
2. To force a building, edit `media/lua/shared/LastHomeShared.lua`:

   ```lua
   LastHomeShared.SCENARIO_HOUSE = "elementary_school"  -- hospital|villa|prison|elementary_school|random
   ```

3. Relaunch. The server bootstrap (`OnServerStarted`) applies the sandbox vars (vanilla zombies disabled) and locks the chosen building.

A solo sandbox game (single player, mod active) also works via the `OnGameStart` fallback.

## Specifications

| Spec | Description | Status |
|------|-------------|--------|
| [LH-01](specs/LH-01-concept.md) | Concept and validated questions | ✅ |
| [LH-02](specs/LH-02-roles.md) | 17 rebalanced roles | ✅ |
| [LH-03](specs/LH-03-vagues.md) | Waves, scaling, directions, spectator | ✅ |
| [LH-04](specs/LH-04-maison.md) | Building, repairs, defense | ✅ |
| [LH-05](specs/LH-05-zone-confinement.md) | Confinement zone around the house | ✅ |
| [LH-06](specs/LH-06-hud.md) | HUD overhaul and positioning | ✅ |
| [LH-07](specs/LH-07-fix-sync-solo.md) | Fix solo sync / confinement | ✅ |
| [LH-08](specs/LH-08-equipement-roles.md) | Role equipment and shared helpers | ✅ |
| [LH-10](specs/LH-10-timers-skip.md) | Reduced timers + wave skip | ✅ |
| [LH-12](specs/LH-12-create-horde-from-to.md) | Track A aggro via `createHordeFromTo` | 📝 |
| [LH-13](specs/LH-13-suppression-spawns-vanilla.md) | Continuous vanilla/story spawn suppression | ✅ |
| [LH-14](specs/LH-14-firearm-loadout-priming.md) | Firearm priming on role assignment | ✅ |
| [LH-15](specs/LH-15-stock-locator-arrow.md) | On-screen stock arrow | ❌ removed by LH-21 |
| [LH-17](specs/LH-17-deduplication-role-equipment.md) | Single source of truth for role application (dedup) | ✅ |
| [LH-MP](specs/LH-MP-multiplayer-sandbox-conversion.md) | Host Last Home in multiplayer (sandbox conversion) | 📝 |
| └ [LH-MP-1](specs/LH-MP-1-server-setSelectedHouse.md) | Expose `LastHomeServer.setSelectedHouse(houseId, source)` | ✅ |
| └ [LH-MP-2](specs/LH-MP-2-server-bootstrap.md) | Server bootstrap `LastHomeBootstrap.lua` + house config | ✅ |
| └ [LH-MP-3](specs/LH-MP-3-isScenarioHouse.md) | Generalize periodic cleanup to scenario houses | ✅ |
| └ [LH-MP-4](specs/LH-MP-4-mp-verification-docs.md) | MP server setup docs + verification checklist | 📝 |
| └ [LH-MP-5](specs/LH-MP-5-house-picker-before-role-picker.md) | House picker before the role picker | ❌ cancelled (LH-MP-6) |
| └ [LH-MP-6](specs/LH-MP-6-hardcoded-scenario-house.md) | MP-only mod: hardcoded scenario house, drop cfg/picker/Challenges | ✅ |
| [LH-18](specs/LH-18-stock-spawn-analysis.md) | Stock communautaire : spawn dédié vs spawn au sol (analyse) | ✅ |
| [LH-19](specs/LH-19-stock-ground-spawn.md) | Stock communautaire : spawn au sol (nourriture/eau/munitions) | ✅ |
| [LH-20](specs/LH-20-cleanup-pas-pendant-vague.md) | Suspendre le nettoyage périodique pendant la vague | ✅ |
| [LH-21](specs/LH-21-suppression-fleche-stock.md) | Supprimer la flèche du stock communautaire | ✅ |

## Status

- ✅ Versioned specs complete for **LH-01** through **LH-08** and **LH-10**
- 📝 Exploration spec written: **LH-12** (aggro via `createHordeFromTo`)
- ✅ Implementation of **LH-02** through **LH-08**, **LH-10**, **LH-13**, **LH-14**, **LH-19**, **LH-20** and **LH-21** complete (**LH-15** removed by **LH-21**)
- ✅ MP-only delivery (LH-MP-6): the Challenges menu entries were removed; the mod runs from the multiplayer Host menu / solo sandbox, with the building hardcoded via `LastHomeShared.SCENARIO_HOUSE` (currently `elementary_school`)
- ✅ Two-VM bootstrap fix: `OnServerStarted` runs the bootstrap in the SERVER VM (authoritative); `OnGameStart` is the solo-sandbox fallback (gated by `isClient()`). `applyDefaultSandboxVars` runs server-side so vanilla zombies are suppressed at the initial MP spawn
- ✅ LH-10 timers: prep wave 1 = 2 min, subsequent prep = 5 min, wave = 5 min, skip via `K` key
- ✅ Wave attraction refocused on alarm-like sound pulses toward the base to make zombie pressure reliable
- ✅ Continuous vanilla/story spawn suppression around the base (periodic cleanup every 5s, `LH_waveZombie` tagging preserved)
- ✅ LH-19 ground stock: the community stock now spawns once on the ground near `stockSpawn` / `supply`, limited to food, water bottles, and ammunition
- ❌ On-screen stock arrow removed by LH-21
- 📋 Backlog and current tracking in [project-state.md](project-state.md)

## Mod Structure

```text
last-home/
  mod.info
  poster.png
  README.md
  project-state.md
  media/
    lua/
      server/
        LastHomeServer.lua      -- roles, assignment, Builder refill, setSelectedHouse
        LastHomeWaves.lua       -- waves, scaling, directions, spectator, phases
        LastHomeBootstrap.lua    -- OnServerStarted bootstrap (sandbox vars + house)
        LastHomeBoundary.lua    -- confinement zone (countdown, damage, sync)
        LastHomeStock.lua       -- ground stock spawn + post-spawn maintenance
      client/
        LastHomeClient.lua      -- client bootstrap / HUD / solo sync / role flow
        LastHomeRolePicker.lua  -- role picker
      shared/
        LastHomeRoles.lua       -- definitions of the 18 roles
        LastHomeShared.lua      -- houses, coords, timers, boundary, logger, shared utils
  specs/
    LH-01-concept.md
    ...
    LH-MP-6-hardcoded-scenario-house.md
```

## Dependencies

### Required mods

- **Xonic's Mega Mall** (Workshop ID: `1713269594`) — map (the 4 buildings live on this map)
- **Brita's Weapon Pack** (Workshop ID: `2200148440`, `Mod ID: Brita`) — weapon assets (models/textures/sounds)
- **Brita's Armor Pack** (Workshop ID: `2460154811`, `Mod ID: Brita_2`) — tactical clothing (module `Base`, e.g. `Base.Suit_Wick`, `Base.Glove_Mechanix`)
- **Arsenal(26) GunFighter** (Workshop ID: `2297098490`, `Mod ID: Arsenal(26)GunFighter[MAIN MOD 2.0]`) — functional weapon items (module `Base`, e.g. `Base.PPK`, `Base.MP5SD6_Fixed`)

> Brita's Weapon Pack alone is assets-only; the functional gun items are defined by Arsenal(26) GunFighter (module `Base`), while Brita's Armor Pack provides the clothing. The three mods are required together by `mod.info` (see LH-22).

### Note

- **Pillow's Random Scenarios** (Workshop ID: `2106657533`) was the host mod for the now-removed Challenges menu flow. It is no longer required for MP Host / solo sandbox (to re-confirm in LH-MP-4 verification).

### Other

- Inspiration from Escapade Express for the role system (github.com/ksdok/escapade-express)

## License

MIT