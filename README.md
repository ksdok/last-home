# Last Home

Co-op mod for Project Zomboid (B41). Players defend a building against growing waves of zombies. Between each wave, they craft, repair, and prepare their defenses. Survive as long as possible.

## Concept

- **Co-op** up to 8 players (duplicate roles allowed)
- **Real-time waves**: 2 min prep for wave 1, then 5 min; each wave lasts 5 min
- **Random building** among 4 (Hospital, Villa, Prison, Elementary School), or forced by challenge
- **Increasing horde directions**: 1 direction at first, then 2, 3, up to 360° — with per-location gameplay exceptions if needed
- **Permadeath**: dead players become spectators and can spawn 1 zombie during subsequent waves
- **17 roles** taken from Escapade Express (without Mechanic, with Builder)
- **Unlimited survival**: score = number of waves survived

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
| [LH-15](specs/LH-15-stock-locator-arrow.md) | On-screen stock arrow | ✅ |
| [LH-17](specs/LH-17-deduplication-role-equipment.md) | Single source of truth for role application (dedup) | 📝 |

## Status

- ✅ Versioned specs complete for **LH-01** through **LH-08** and **LH-10**
- 📝 Exploration spec written: **LH-12** (aggro via `createHordeFromTo`)
- ✅ Implementation of **LH-02** through **LH-08**, **LH-10**, **LH-13**, **LH-14** and **LH-15** complete
- ✅ Solo confinement stabilized (dedicated sync, fixed boundary detection, HUD IN/OUT)
- ✅ 4 challenges registered in the menu (Hospital, Villa, Prison, School)
- ✅ LH-10 timers: prep wave 1 = 2 min, subsequent prep = 5 min, wave = 5 min, skip via `K` key
- ✅ Last Home challenges: vanilla zombies disabled, ambient cleanup around base, Villa forced to **South**
- ✅ Wave attraction refocused on alarm-like sound pulses toward the base to make zombie pressure reliable
- ✅ Continuous vanilla/story spawn suppression around the base in Challenge mode (periodic cleanup every 5s, `LH_waveZombie` tagging preserved)
- ✅ On-screen stock arrow pointing to the community container with distance (visible through walls)
- ✅ Fixed challenge house-selection race: stale `OnGameStart` handlers from a previously-played challenge could lock the wrong house before the real challenge's `SetHouse` arrived (arrow + confinement pointed to the wrong building)
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
        LastHomeServer.lua      -- roles, assignment, Builder refill, SetHouse
        LastHomeWaves.lua       -- waves, scaling, directions, spectator, confinement
      client/
        LastStand/
          LastHomeHospital.lua  -- Hospital challenge
          LastHomeVilla.lua     -- Villa challenge
          LastHomePrison.lua    -- Prison challenge
          LastHomeSchool.lua    -- School challenge
          *.png                 -- preview images (200x200)
        LastHomeClient.lua      -- client bootstrap / HUD / solo sync
        LastHomeRolePicker.lua  -- role picker
      shared/
        LastHomeRoles.lua       -- definitions of the 17 roles
        LastHomeShared.lua      -- shared helpers (houses, coords, timers, boundary)
  specs/
    LH-01-concept.md
    LH-02-roles.md
    LH-03-vagues.md
    LH-04-maison.md
    LH-05-zone-confinement.md
    LH-06-hud.md
    LH-07-fix-sync-solo.md
    LH-08-equipement-roles.md
    LH-10-timers-skip.md
```

## Dependencies

### Required mods

- **Pillow's Random Scenarios** (Workshop ID: `2106657533`) — host mod
- **Xonic's Mega Mall** (Workshop ID: `1713269594`) — map

### Other

- Inspiration from Escapade Express for the role system (github.com/ksdok/escapade-express)

## License

MIT