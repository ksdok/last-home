# Project State

## Summary

- Project: **Last Home**
- Repo: `/Users/kim/Documents/Zomboid/last-home`
- Reference branch: `main`
- Source branch for delivered ticket: `feat/lh-mp-1-set-selected-house`
- Reference used: `/Users/kim/Documents/Zomboid/EscapadeExpress`

## Current Status

- ✅ Versioned specs **LH-01** through **LH-08** and **LH-10** are written and validated
- ✅ **LH-02** through **LH-08** are implemented and fixed after review/debug
- ✅ **LH-10** is implemented: shortened timers, wave skip, skip HUD, client debounce
- ✅ 4 challenges registered in PZ's Challenges menu (Hospital, Villa, Prison, School)
- ✅ Last Home challenges now disable vanilla pop (`SandboxVars.Zombies = 6` + multipliers at 0) and clean ambient zombies around the base
- ✅ Villa stabilized: waves forced to **South**, ground-level spawns, wave attraction refocused on alarm-like sound pulses toward the base
- ✅ Spec **LH-12** written to test Track A on wave aggro via `createHordeFromTo` — resolved in-game (god mode was blocking the zombie AI)
- 📝 Spec **LH-17** written: deduplication of role-application logic into `LastHomeShared`
- ✅ Spec **LH-13** written and implemented: continuous vanilla/story spawn suppression around the base in Challenge mode
- ✅ LH-MP-1 implemented: `LastHomeServer.setSelectedHouse(...)` now centralizes server-side house selection for both challenge and future scenario/bootstrap paths (validation, lock, sync, refill, roled-player re-teleport)
- ✅ LH-MP-2 implemented: `media/lua/server/LastHomeBootstrap.lua` selects the scenario house from `Zomboid/Server/LastHomeHouse.cfg` at server `OnGameStart` and calls `LastHomeServer.setSelectedHouse(id, "scenario")`; `LastHomeShared.applyDefaultSandboxVars()` dedups the challenge sandbox injection (4 `setSandBoxVars` bodies replaced by the shared call); bootstrap dormant in solo Challenges mode via `isChallenge()` guard; hooks `OnGameStart` (not `OnServerStarted`) registered after `LastHomeServer`'s reset via `require "LastHomeServer"` so the reset does not wipe the selected house
- ✅ LH-MP-3 implemented: `isChallengeHouse()` renamed to `isScenarioHouse()` accepting `source == "challenge" | "scenario"`; all 3 call sites (prep-schedule L700, wave-schedule L751, OnTick periodic L1059) updated so the LH-13 periodic ambient cleanup actually runs in MP sandbox mode (spec mentioned only the OnTick site; all 3 arm/execute the periodic cleanup)
- ✅ LH-MP-2 fix (verified in-game 25-07-26): bootstrap event switched from `OnGameStart` to `OnServerStarted`. `OnGameStart` is a **client-side** event that does **not** fire on the MP server process (Host or dedicated) — confirmed by server log `25-07-26_23-26-48_DebugLog-server.txt`: `LastHomeBootstrap.lua` loads but the `OnGameStart` handler never runs, `Server.house` stays `nil`, no `Selection scenario house=` / `Maison selectionnee` lines. The bootstrap now hooks `Events.OnServerStarted` (one-shot `bootstrapRan` guard); the `LastHomeServer` reset on `OnGameStart` is moot in MP (doesn't fire on the server, no wipe) and solo Challenges is unaffected (`isChallenge()` guard)
- ✅ LH-MP-2 fix #2 (verified in-game 25-07-26): `getScenarioHouseId()` used `io.open` which is **nil in PZ's Kahlua Lua** (`attempted index: open of non-table: null`, server log `25-07-26_23-37-01`). Replaced with PZ-native `fileExists(path)` + `getFileReader(path, false)` + `reader:readLine()`; path `Server/LastHomeHouse.cfg` resolves relative to the user Zomboid data folder (`<userDir>/Server/LastHomeHouse.cfg`). `OnServerStarted` now fires and reaches `getScenarioHouseId` without crashing
- ✅ Fixed challenge house-selection race: stale `OnGameStart` handlers from a previously-played challenge leaked into the next launch and could lock the wrong house before the real challenge's `SetHouse` arrived. The client now guards `SendHouseSelection` with `getCore():getChallengeID() == self.id`, and the server lets the last `SetHouse` win as long as waves haven't started.
- ⏳ Next steps: write `docs/MULTIPLAYER_SETUP.md` + run **in-game MP verification** (LH-MP-4) on a dedicated/Host server — bootstrap event confirmation (does `OnGameStart` fire on a dedicated server?), map-dep minimal set (`Mods=LastHome` alone vs `+Pillow/Xonic`), roles, teleport, confinement, waves, spectators, late joiners, HUD, ambient cleanup; then Villa attraction, LH-10 pacing, Track A testing, and validation of parasite spawn suppression

## Completed

### Specs
- [x] LH-01 — Concept and specification
- [x] LH-02 — Rebalanced roles
- [x] LH-03 — Waves
- [x] LH-04 — House, repairs, and defense
- [x] LH-05 — Confinement zone
- [x] LH-06 — HUD overhaul and positioning
- [x] LH-07 — Fix solo sync state via dedicated OnTick
- [x] LH-08 — Role equipment
- [x] LH-10 — Reduced timers and wave skip
- [x] LH-12 — Track A aggro via createHordeFromTo
- [x] LH-13 — Vanilla/story parasite spawn suppression
- [x] LH-14 — Firearm priming on role assignment
- [x] LH-15 — On-screen stock arrow
- [x] LH-MP-1 — Expose `LastHomeServer.setSelectedHouse(houseId, source)`
- [x] LH-MP-2 — Server bootstrap `LastHomeBootstrap.lua` + house config
- [x] LH-MP-3 — Generalize periodic cleanup to scenario houses
- [ ] LH-MP-4 — MP server setup docs + verification checklist
- [ ] LH-17 — Deduplication of role application (single source of truth in `LastHomeShared`)

### Implementation
- [x] LH-02 — Last Home role system
  - `media/lua/shared/LastHomeRoles.lua`
  - `media/lua/client/LastHomeRolePicker.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `mod.info`
  - Post-review fixes applied:
    - reliable role picker opening on client side
    - `applyPerkLevel()` made more robust
    - picker text made more durable
    - `version=0.1.0` added to `mod.info`

- [x] LH-03 — Last Home wave system
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `mod.info`
  - Implemented features:
    - prep 10 min / wave 10 min real-time cycle
    - zombie scaling based on wave + living players
    - increasing directions 1 / 2 / 3 / 360
    - server/client announcements + MM:SS HUD timer
    - leftover zombies overflow to next wave
    - spectator mode with 1 zombie spawn per wave
    - score = number of waves survived
  - Post-review fixes applied:
    - score stabilized via `wavesSurvived`
    - timers migrated to shared real-time tracking
    - server-side robustness on player death detection
    - targeted feedback if a spectator spawn is denied
    - `version=0.2.0` added to `mod.info`

- [x] LH-04 — House, repairs, and defense
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `mod.info`
  - Implemented features:
    - random vanilla building selection among 4 (Hospital, Villa, Prison, Elementary School)
    - player spawn zones per building (radius or box depending on house)
    - house center synced to wave system and client HUD
    - community stock in a dedicated vanilla container per house
    - fallback to nearest vanilla container if dedicated container is missing
    - Builder refill preserved + house stock refilled every 10 minutes
  - Post-review fixes applied:
    - stricter validation of player spawn squares
    - anti-spam guard on house stock refill during reconnections/assignments
    - server warning if player teleport to house fails
    - `version=0.3.0` added to `mod.info`

- [x] LH-05 — Confinement zone around the house
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `specs/LH-05-zone-confinement.md`
  - `README.md`
  - `mod.info`
  - Implemented features:
    - configurable 2D rectangular `boundary` per house (coordinates validated in-game)
    - server-side zone exit detection for alive players with a role
    - 10s countdown synced to client HUD via `BoundaryState`
    - authoritative progressive damage server-side after countdown expiration
    - spectator exemption and immediate confinement stop on re-entry
  - Notes:
    - spec architecture corrected to an **authoritative server** model for multiplayer
    - 2D rectangular `X/Y` confinement zones without `Z` constraint for all 4 locations
    - post-review fixes: removed unnecessary `boundary` re-normalization every tick, aligned damage fallback with `BOUNDARY_DAMAGE_AMOUNT`
    - `version=0.5.0` added to `mod.info`

- [x] LH-06 — HUD overhaul and positioning
  - `media/lua/client/LastHomeClient.lua`
  - `specs/LH-06-hud.md`
  - `mod.info`
  - Implemented features:
    - HUD anchored top-right with dynamic calculation (`getCore():getScreenWidth()`)
    - confinement countdown seconds displayed as integers (`math.ceil()`)
    - "Damage active" line blinking (toggle every 0.5s)
    - "Back in the zone" message (green, disappears after 3s) via `boundaryReturnedAt`
  - Post-review fixes applied:
    - zone re-entry detection in `updateBoundaryState()` (countdown/damaging → inside transition)
    - `version=0.6.0` added to `mod.info`

- [x] LH-07 — Fix sync solo / confinement
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/shared/LastHomeShared.lua`
  - `specs/LH-07-fix-sync-solo.md`
  - Implemented features:
    - solo sync moved from HUD rendering to a dedicated `Events.OnTick`
    - solo resync of `waveState` and `boundaryState` independent of draw UI
    - local HUD indicator `Zone: IN/OUT` to visualize confinement state client-side
    - targeted server/client logs for debugging boundary detection in solo
  - Post-debug fixes applied:
    - `LastHomeShared.isInsideBoundary()` fixed to handle PZ player objects via `getX()/getY()` instead of a `type(...) == "table"` check
    - local client warning "Out of zone! Return to base" added as visual fallback
    - periodic player coordinate log spam removed after validation

- [x] LH-08 — Role equipment
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `specs/LH-08-equipement-roles.md`
  - Implemented features:
    - more robust inventory, bag, and equipped item distribution per role
    - automatic 2-handed weapon detection
    - pre-loaded ammunition on spawn
    - shared helpers `applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`
  - Fixes applied:
    - reduced client/server duplication for equipment and loadout
    - compatibility preserved with existing roles and Builder refill

- [x] LH-10 — Reduced timers, wave skip, and Villa stabilization
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/client/LastStand/LastHomeHospital.lua`
  - `media/lua/client/LastStand/LastHomePrison.lua`
  - `media/lua/client/LastStand/LastHomeSchool.lua`
  - `media/lua/client/LastStand/LastHomeVilla.lua`
  - `specs/LH-10-timers-skip.md`
  - Implemented features:
    - prep wave 1 = `2 * 60`, subsequent prep = `5 * 60`, wave = `5 * 60`
    - skip prep via `K` key, direct solo or network command depending on runtime
    - skip HUD + client debounce to prevent double requests
    - ground-level wave spawns for Villa
    - vanilla zombies disabled in all 4 challenges (`SandboxVars.Zombies = 6`, multipliers/respawn/rally at 0)
    - ambient zombie cleanup around base at prep start and wave start
    - Villa forced to **South** and wave attraction refocused on alarm-like sound pulses toward the base
  - Associated commits:
    - `9da0397` — `LH-10: add wave skip and reduce timers`
    - `5e0335d` — `LH-10: debounce wave skip request`
    - `b3dc132` — `fix: wave aggro and vanilla zombies in challenges`

- [x] PZ Challenges (Challenges menu)
  - `media/lua/client/LastStand/LastHomeHospital.lua`
  - `media/lua/client/LastStand/LastHomeVilla.lua`
  - `media/lua/client/LastStand/LastHomePrison.lua`
  - `media/lua/client/LastStand/LastHomeSchool.lua`
  - `media/lua/server/LastHomeServer.lua` (handler `SetHouse`)
  - `media/lua/server/LastHomeWaves.lua` (`hasStarted()`)
  - `mod.info` (`poster=poster.png`, `version=0.4.0`)
  - Implemented features:
    - 4 challenges registered via `Events.OnChallengeQuery.Add()`
    - each challenge forces the corresponding house server-side
    - 200x200 preview images + 256x256 poster
  - Post-review fixes applied:
    - server-side challenge house lock via `houseSelectionLocked`
    - initial rotation override allowed as long as waves haven't started
    - re-teleport of already assigned players + immediate refill if `SetHouse` fixes an initial rotation
    - client guard `_houseSelectionSent` to prevent duplicate `SetHouse`
    - explicit API `LastHomeWaves.hasStarted()` + debug log on no-op `SetHouse` with same house

- [x] Solo role picker fallback (Challenge mode)
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/client/LastHomeRolePicker.lua`
  - Implemented features:
    - `isSinglePlayerRuntime()` detects solo (isClient + getOnlinePlayers)
    - `TickRolePickerFallback` opens the picker locally after 3s if the server doesn't respond
    - `applyRoleLocally()` duplicates applyRole logic client-side (items, skills, stats, equip, unlimitedCarry)
    - `openLocal()` + "solo" mode in `onChooseRole` of RolePicker
    - `showRoleAssigned` triggered in solo via forward declaration
    - `roleRequestSent` reset in `onGameStart` to allow Retry in Challenge mode

- [x] LH-13 — Continuous vanilla/story spawn suppression in Challenge mode
  - `media/lua/server/LastHomeWaves.lua`
  - `specs/LH-13-suppression-spawns-vanilla.md`
  - Implemented features:
    - `clearAmbientZombiesNearHouse(reason)` accepts a reason (`prep`, `wave`, `periodic`) and logs it
    - immediate cleanup preserved at phase transitions (prep start / wave start)
    - periodic server cleanup every `AMBIENT_CLEANUP_INTERVAL_SECONDS` (5s) as long as `started` and `house` are set **in Challenge mode** (`house.source == "challenge"`)
    - exclusion of tagged `LH_waveZombie` zombies preserved (waves + spectators)
    - `Server.nextAmbientCleanupAt` scheduled after each cleanup and reset in `resetState()`
    - distinct server logs per cleanup type with removed zombie count

- [x] LH-14 — Firearm priming on role assignment
  - `media/lua/shared/LastHomeShared.lua` (`fillAmmoItem`)
  - `specs/LH-14-firearm-loadout-priming.md`
  - Implemented features:
    - magazine-fed weapon detection via non-empty `getMagazineType()` (AssaultRifle, HuntingRifle)
    - capacity calculated primarily from `getMaxAmmo()` for magazine-fed weapons, then `getClipSize()` if > 0, then `getMaxAmmo()` as fallback (spare magazines, bullet-by-bullet weapons)
    - `setContainsClip(true)` applied only to magazine-fed weapons
    - replicates the engine's official pattern `HandWeapon:randomizeBullets()`: `setCurrentAmmoCount(getMaxAmmo())` + `setContainsClip(true)` if magazine-fed + `setRoundChambered(true)` if `haveChamber()`
    - `isRanged()` guard to only process firearms; spare magazines (non-weapons) filled to `MaxAmmo`
    - debug log `fillAmmoItem weapon=...` to validate priming in-game (useful for diagnosing potential MP sync or Lua cache issues)
  - Bug fixed: `getClipSize()` returns 0 on weapons without scripted `ClipSize` (AssaultRifle, HuntingRifle, Shotgun), which blocked the `elseif getMaxAmmo` and left the gun at 0 bullets. Pistol (`ClipSize=15`) remained functional.

- [x] LH-15 — On-screen stock arrow
  - `media/lua/client/LastHomeClient.lua` (`drawStockArrow`)
  - `specs/LH-15-stock-locator-arrow.md`
  - Implemented features:
    - on-screen arrow pointing to the stock container (`house.supply`) with distance in meters, visible through walls
    - world-to-screen projection via `IsoUtils.XToScreenExact/YToScreenExact` (camera-adjusted)
    - `v <dist>m` marker above the container if stock is on-screen; otherwise cardinal arrow (`^ v < >`) clamped to screen edge
    - centered text via `TextManager:DrawStringCentre(UIFont.Medium, ...)` black shadow + yellow
    - disabled in `idle`/`gameover` phase, without a house, or within 3 tiles of the stock
  - Note: PZ bitmap fonts don't contain unicode arrow glyphs; ASCII cardinal arrow (4 directions) used for rendering reliability
  - Fallback fix: `getPrimaryHouseSupplyContainer` rewrites `house.supply` with the actual fallback container square and calls `syncSelectedHouse()` to re-propagate to the client (otherwise the arrow pointed to an empty square on houses where the configured square has no container)

- [x] Challenge house-selection race fix
  - `media/lua/client/LastStand/LastHomeHospital.lua`
  - `media/lua/client/LastStand/LastHomeVilla.lua`
  - `media/lua/client/LastStand/LastHomePrison.lua`
  - `media/lua/client/LastStand/LastHomeSchool.lua`
  - `media/lua/server/LastHomeServer.lua` (`SetHouse` handler)
  - Symptom: at spawn the player was "out of zone" and the LH-15 arrow pointed very far away
  - Root cause: the 4 challenge files register their `OnGameStart` via a `_gameStartRegistered` guard that prevents re-registration but never removes the handler. PZ doesn't reset `Events.OnGameStart` between challenge launches in the same process, so a previously-played challenge (e.g. Villa) left its `OnGameStart` registered. When launching another challenge (e.g. School), both handlers fired: `SetHouse("villa")` first, then `SetHouse("elementary_school")`. The server locked Villa on the first challenge `SetHouse` and rejected the real one ("car la maison est deja verrouillee"). The player stayed at the School spawn while the server house was Villa → boundary + arrow pointed ~3000 tiles away.
  - Fixes applied:
    - client: each `SendHouseSelection` now guards with `getCore():getChallengeID() == self.id`, so a stale handler from another challenge no longer sends a wrong `SetHouse`
    - server: the `SetHouse` handler now lets the last `SetHouse` win as long as waves haven't started (defense in depth); it only rejects once `LastHomeWaves.hasStarted()` is true

- [x] LH-MP-1 — Reusable server-side `setSelectedHouse`
  - `media/lua/server/LastHomeServer.lua`
  - Implemented features:
    - exported API `LastHomeServer.setSelectedHouse(houseId, source[, actorUsername])`
    - extracted the former inline `SetHouse` logic into a reusable server function for challenge and scenario/bootstrap callers
    - preserved pre-wave "last selection wins" behavior and post-wave freeze behavior
    - preserved side effects: `house.source`, `Server.houseSelectionLocked`, `Server.lastHouseSupplyRefillAt = nil`, `syncSelectedHouse()`, `refillHouseSuppliesIfNeeded()`
    - preserved re-teleport symmetry for already-roled players by resetting `modData.LH_houseSpawnId = nil` before `teleportPlayerToHouse(player)`
    - challenge path keeps actor-aware ignore logs; scenario path gets distinct `warnTeleportFailure` context (`setSelectedHouse:<source>`)
  - Associated commit:
    - `879c0c8` — `refactor(LH-MP-1): extract setSelectedHouse`

- [x] LH-MP-2 — Server bootstrap + scenario house config
  - `media/lua/server/LastHomeBootstrap.lua` (new)
  - `media/lua/shared/LastHomeShared.lua` (`getScenarioHouseId`, `applyDefaultSandboxVars`)
  - `media/lua/client/LastStand/LastHomeHospital.lua` (and Villa/Prison/School) — dedup
  - `specs/LH-MP-2-server-bootstrap.md`
  - Implemented features:
    - `LastHomeBootstrap.lua` hooks server `OnGameStart`; dormant in solo Challenges mode (`getCore():isChallenge()` guard, logs `Mode Challenge detecte -> bootstrap inactif`)
    - `LastHomeShared.getScenarioHouseId()` reads `Zomboid/Server/LastHomeHouse.cfg` (first non-empty/non-comment token), resolves the path via `getCore():getMyDocumentFolder()` with a relative fallback, logs the resolved path, validates against the 4 house ids + `random`, defaults to `random`
    - `LastHomeShared.applyDefaultSandboxVars()` = shared body of the former challenge `setSandBoxVars` (`SandboxVars.Zombies = 6`, `ZombieConfig` multipliers/respawn/rally = 0); best-effort on a dedicated server, LH-13 cleanup compensates
    - bootstrap resolves `random` via `getRandomHouse()`, then calls `LastHomeServer.setSelectedHouse(resolvedId, "scenario")`
    - event choice `OnGameStart` (not `OnServerStarted`): `require "LastHomeServer"` registers the reset handler before the bootstrap's `OnGameStart`, so `Server.selectedHouse` reset does not wipe the bootstrap's selection (reset -> bootstrap sets house -> no wipe)
    - 4 challenge `setSandBoxVars` bodies replaced by the shared call (dedup, behavior unchanged)
  - Associated commits:
    - `2d53a06` — `feat(LH-MP-2): server bootstrap + scenario house config`
    - `8f00c01` — `refactor(LH-MP-2): dedup challenge setSandBoxVars via applyDefaultSandboxVars`

- [x] LH-MP-3 — Generalize periodic cleanup to scenario houses
  - `media/lua/server/LastHomeWaves.lua`
  - `specs/LH-MP-3-isScenarioHouse.md`
  - Implemented features:
    - `isChallengeHouse()` renamed to `isScenarioHouse()`; accepts `source == "challenge"` or `source == "scenario"`
    - all 3 call sites updated (prep-schedule L700, wave-schedule L751, OnTick periodic execution L1059) — the spec mentioned only the OnTick site, but `nextAmbientCleanupAt` is armed at prep/wave start too, so all 3 gates must accept `scenario` for the periodic cleanup to actually run in MP
    - immediate phase-transition cleanups (`prep`/`wave` reasons) remain unconditional and unchanged
    - `player-fallback` / `rotation` sources still excluded (vanilla population intact)
  - Associated commit:
    - `dc3ceae` — `feat(LH-MP-3): generalize periodic cleanup gate to scenario houses`

## Backlog

### High priority
- [x] LH-MP-2 — Server bootstrap / house config using `LastHomeServer.setSelectedHouse(...)` (implemented; pending in-game MP verification in LH-MP-4)
- [x] LH-MP-3 — Generalize periodic cleanup to scenario houses (implemented; pending in-game MP verification)
- [ ] LH-MP-4 — Write `docs/MULTIPLAYER_SETUP.md` + run the A-H verification checklist on a dedicated/Host server (no code change expected; failures become follow-up tickets). Must confirm: (a) `OnGameStart` fires on a dedicated server (fallback: move reset + bootstrap to `OnServerStarted`); (b) minimal `Mods=`/`Map=` line per house (`Mods=LastHome` alone vs `+Pillow/Xonic`); (c) `LastHomeHouse.cfg` absolute path resolution via `getCore():getMyDocumentFolder()`
- [ ] In-game solo/LAN verification of LH-03 through LH-10 (actual timers, skip, spectators, score, house spawn, shared stock, confinement, HUD, solo sync)
- [ ] In-game multiplayer verification of the role picker, spawn teleports, Builder/house refill, server confinement, and wave skip
- [ ] Validate in-game the zombie pressure on Villa with sound pulse attraction (range, frequency, horde feel)
- [ ] Fix Villa playability:
  - `pickHouseSpawnPoint` fails on all 10 spawn candidates (box `[13532..13533, 2839..2843, z=1]` → no `isFree` square); it only checks `isFree(false)` and needs a wider/falling-back scan.
  - No stock container found: `getPrimaryHouseSupplyContainer` first checks the configured `house.supply` square (Villa `(13540, 2836, 0)`); if that square has no container, the fallback scan only covers `house.bounds` (the spawn area, ~10 tiles), **not** the building `boundary`. So either the configured `supply` coord is wrong, or the fallback scan must be widened to `boundary` (130x128 / 197x218 → 16k-43k tiles), in which case the found container must be **cached** to avoid rescanning on every refill/SetHouse/RolePickerReady.
  - Note: there is **no** performance problem today — the fallback scan is only ~10-81 tiles (spawn-derived `bounds`), not the full building. The real issue is coverage, not cost.
- [x] Wave zombie aggro issue (zombies didn't attack) — **resolved in-game**: god mode was blocking the PZ zombie AI. Disabling god mode fixed it (LH-12 Tracks A-D).
- [x] Permanently suppress vanilla/story parasite spawns around the base in Challenge (`RDS*`, `createEatingZombies`, `RBSafehouse`, etc.). Spec written: `specs/LH-13-suppression-spawns-vanilla.md`
- [ ] LH-17 — Deduplication of role application (single source of truth in `LastHomeShared`). Spec written: `specs/LH-17-deduplication-role-equipment.md`

### Later
- [ ] Structured loot in the vicinity of houses if needed
- [ ] More complete HUD / notifications for Last Home
- [ ] Role balance adjustments if needed after testing
- [ ] House-state cleanup (low priority, no longer an active bug in challenge mode): `LastHomeServer.selectedHouse` and `LastHomeWaves.house` are two variables for one concept, synced one-way via `syncSelectedHouse()`. `LastHomeWaves.ensureHouse()` can set the waves house to a fallback without pushing back to the server module (only reachable in sandbox-rotation mode without `SetHouse`). Also `ensureSelectedHouse()` still does a momentary random pick in challenge mode before `SetHouse` overrides it (harmless since the fix, just wasteful); gate it with `getCore():isChallenge()` to skip the random rotation and wait for `SetHouse`. (LH-17 now covers the applyRole/addRoleItems dedup, which was the original 'complementary refactor' item.)
- [ ] Check `Events.OnTick.Remove` in B41 — if the API doesn't exist, the fallback tick runs idle (review point 2, non-blocking)

## Implementation Notes

- Duplicate roles are allowed in Last Home
- The `mechanic` role is removed
- The `builder` retains `setUnlimitedCarry` and its refill every 10 minutes in real time
- LH-03 introduces `LastHomeShared.lua` to share `round()`, `getScenarioPlayers()`, and `getNowSeconds()`
- LH-04 extends `LastHomeShared.lua` with the definition of 4 houses, their spawn zones, and their dedicated stock containers
- LH-05 adds a rectangular `boundary` per house and an **authoritative server-side** confinement, with client-side HUD display
- LH-07 moves solo sync to `Events.OnTick`, fixes `isInsideBoundary()` detection for PZ player objects, and adds a local HUD indicator `Zone: IN/OUT`
- LH-08 extracts common equipment/loadout logic into `LastHomeShared.lua` (`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`) to reduce client/server duplication
- LH-14 aligns `fillAmmoItem` with the engine's `HandWeapon:randomizeBullets()` (Ammo, ContainsClip, RoundChambered) to pre-load firearms on role assignment
- LH-10 reduces wave timers and adds prep skip via `K`, preserving `pendingDirections` through `startWave(false)` on skip
- For Villa, waves are currently forced to the **South** and attraction relies on sound pulses centered on the base rather than zombie-by-zombie aggro targeting
- Last Home challenges now use `SandboxVars.Zombies = 6` to cut vanilla pop; `5` only corresponds to low population in PZ
- Logs however show that `SandboxVars` + `ZombieConfig` aren't enough to prevent certain `RDS*` / `createEatingZombies` spawns in Challenge mode; a continuous server-side cleanup around the base is now specified in LH-13
- The house stock is injected into an existing vanilla container, with fallback to the nearest container in the zone if needed
- `BUILDER_REFILL_ITEMS` (community stock refill, multiplied by `HOUSE_SUPPLY_MULTIPLIER` = 8) contains, besides construction materials, a variety of food/water (canned goods, snacks, dry food, water) available in all 4 locations
- All roles have at minimum `Carpentry` 3 and `Trapping` 3 to be able to create barricades and traps (existing higher levels are preserved, e.g. builder/invincible Carpentry 10, survivalist Trapping 8)
- Water bottles (`WaterBottleFull`) are placed in the main inventory, not the backpack (removed from `bagContents`), to remain accessible and prevent thirst
- The LH-02 implementation draws inspiration from Escapade Express's structure, but without role locking logic
- The current backlog should be maintained here with each completed or fixed ticket