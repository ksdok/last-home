# Project State

## Summary

- Project: **Last Home**
- Repo: `/Users/kim/Documents/Zomboid/last-home`
- Reference branch: `main`
- Source branch for delivered ticket: `feat/lh-mp-5-house-picker` (LH-MP-6: MP-only mod, hardcoded scenario house)
- Reference used: `/Users/kim/Documents/Zomboid/EscapadeExpress`

## Current Status

- ✅ Specs **LH-01** through **LH-08** and **LH-10** written and validated
- ✅ **LH-02** through **LH-08**, **LH-10**, **LH-13**, **LH-14**, **LH-19**, **LH-20**, **LH-21** and **LH-24** implemented (**LH-15** removed by **LH-21**)
- ✅ **LH-MP-6** delivered: mod is **MP-only** (Host/sandbox + solo fallback). Challenges menu removed; scenario house hardcoded via `LastHomeShared.SCENARIO_HOUSE` (currently `elementary_school`). cfg file and interactive house picker (LH-MP-5) dropped — cfg file-I/O was never reliable in the SERVER VM; host edits one Lua line to force a house
- ✅ Two-VM bootstrap fix preserved: `OnServerStarted` runs the bootstrap in the **SERVER VM** (authoritative); `OnGameStart` is the solo-sandbox fallback (gated by `isClient()`). `applyDefaultSandboxVars` runs server-side so vanilla zombies are suppressed at the initial MP spawn
- ✅ Villa stabilized: waves forced to **South**, ground-level spawns, wave attraction refocused on alarm-like sound pulses toward the base
- ✅ **LH-12** resolved in-game (god mode was blocking the zombie AI)
- ✅ **LH-17** delivered: refactoring completed — 12 duplicated functions centralised in `LastHomeShared.lua`, unified logger `LastHomeShared.log(module, msg)`, confinement extracted to `LastHomeBoundary.lua`, ground stock to `LastHomeStock.lua`, `setSelectedHouse` simplified (12 branches → 1). Commits: `1abb8ed`, `2a0e5c6`.
- ✅ **LH-19** verified in-game on MP Host (elementary_school): the community stock now spawns once on the ground near `stockSpawn`/`supply`, limited to **food + water bottles + ammunition**; `elementary_school.stockSpawn = (10616, 9972, 0)`, `HOUSE_SUPPLY_MULTIPLIER = 4`, and `coop-console.txt` shows `Stock au sol spawn: 38 types, 728 items ... (types en echec=0, echec partiel=0)`
- ✅ **LH-20** was later reverted in code: the periodic ambient cleanup now runs again during **prep and wave**, with a faster **1s** cadence; `startWave()` also re-arms `Server.nextAmbientCleanupAt` so the wave cleanup resumes immediately
- ✅ **LH-21** verified in-game: `drawStockArrow` and `Events.OnPostUIDraw.Add(drawStockArrow)` were removed from `LastHomeClient.lua`; no stock arrow/marker remains on screen, while the ground stock data (`stockSpawn` / `supply` / `getHouseStockSpawn`) and the rest of the HUD stay unchanged
- ✅ **LH-24** delivered: wave 1 prep no longer arms an auto-start timer (`phaseEndsAt = 0` / `phaseDurationSeconds = 0`), `updatePhaseState()` only auto-starts prep when `currentWave > 0`, `skipToNextWave(player)` now requires a living player, and the HUD shows **"Appuyez sur K pour lancer la vague 1"** instead of a `0:00` countdown. Subsequent prep phases remain 5 min with auto-start.
- 🧪 **LH-22/LH-23** remain the validated intermediate Brita steps (007 Agent + 10-role relook), but are now being superseded by **LH-26**.
- 🧪 **LH-26** implementation started: `LastHomeRoles.lua` now ports the **22-role Brita PZRolePlay** roster in place, `civil` is being migrated to `vanilla`, `LastHomeShared.applyCarryProfile` now follows the PZRolePlay carry model (**unlimited carry for all roles except `vanilla`**), the role helpers are being aligned with PZRolePlay, and `mod.info` again requires Brita/Arsenal. In-game validation remains pending.
- ⏳ Next: write `docs/MULTIPLAYER_SETUP.md` + run **in-game MP verification** (LH-MP-4) on a dedicated/Host server — confirm `OnServerStarted` bootstrap fires in the SERVER VM, the hardcoded `SCENARIO_HOUSE` is applied server-side, vanilla zombies suppressed at initial MP spawn, and whether Pillow's Random Scenarios is still a required dep now that the Challenges menu is gone; then roles, teleport, confinement, waves, spectators, late joiners, HUD, ambient cleanup, zombie cleanup around the role spawn, ground-stock visibility/sync, and stock volume tuning; then Villa attraction, LH-10 pacing, Track A testing, parasite spawn suppression validation

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
- [x] LH-15 — On-screen stock arrow (superseded/removed by LH-21)
- [x] LH-19 — Stock communautaire : spawn au sol (food/water/ammo)
- [x] LH-MP-1 — Expose `LastHomeServer.setSelectedHouse(houseId, source)`
- [x] LH-MP-2 — Server bootstrap `LastHomeBootstrap.lua` + house selection
- [x] LH-MP-3 — Generalize periodic cleanup to scenario houses
- [ ] LH-MP-4 — MP server setup docs + verification checklist
- [-] LH-MP-5 — House picker before the role picker (CANCELLED — superseded by LH-MP-6)
- [x] LH-MP-6 — MP-only mod: hardcoded scenario house, drop cfg/picker/Challenges
- [x] LH-17 — Deduplication of role application (single source of truth in `LastHomeShared`)
- [x] LH-20 — Suspendre le nettoyage périodique pendant la vague
- [x] LH-21 — Supprimer la flèche du stock communautaire
- [ ] LH-22 — Rôle 007 Agent + dépendance Brita + tournevis pour tous
- [ ] LH-23 — Relook Brita de 10 rôles (armes + armure tactique)
- [x] LH-24 — Déclenchement manuel de la 1ère vague (pas de timer d'auto-start)
- [x] LH-25 — Mod séparé : choix de rôle seul (role picker standalone) — réalisé via `../PZRolePlay` (`id=PZRolePlaying`)

### Implementation
- [x] LH-02 — Role system. Files: `LastHomeRoles.lua`, `LastHomeRolePicker.lua`, `LastHomeClient.lua`, `LastHomeServer.lua`, `mod.info`. 17 roles (no Mechanic, with Builder); reliable picker opening, robust `applyPerkLevel`, `version=0.1.0`.
- [x] LH-03 — Wave system. Files: `LastHomeWaves.lua`, `LastHomeShared.lua`, `LastHomeServer.lua`, `LastHomeClient.lua`, `mod.info`. Real-time cycle, zombie scaling, increasing directions 1/2/3/360, announcements + MM:SS HUD, leftover overflow, spectator mode (1 zombie/wave), score = waves survived. Stable `wavesSurvived`, shared real-time timers, robust death detection. `version=0.2.0`.
- [x] LH-04 — House, repairs, defense. Files: `LastHomeShared.lua`, `LastHomeServer.lua`, `LastHomeWaves.lua`, `LastHomeClient.lua`, `mod.info`. Random vanilla building selection among 4, per-house spawn zones, house center synced to waves/HUD, community stock location per house, Builder refill, strict spawn-square validation, and teleport-failure warning. The original container-based stock has since been superseded by LH-19 ground spawn. `version=0.3.0`.
- [x] LH-05 — Confinement zone. Files: `LastHomeShared.lua`, `LastHomeWaves.lua`, `LastHomeClient.lua`, `specs/LH-05`. Configurable 2D rectangular `boundary` per house; **authoritative server** model; 10s countdown synced via `BoundaryState`; progressive server-side damage after countdown; spectator exemption + immediate stop on re-entry. `version=0.5.0`.
- [x] LH-06 — HUD overhaul. Files: `LastHomeClient.lua`, `specs/LH-06`. Top-right anchor via `getScreenWidth()`, integer countdown, blinking "Damage active" line, green "Back in the zone" (3s) via `boundaryReturnedAt`; zone re-entry detection in `updateBoundaryState()`. `version=0.6.0`.
- [x] LH-07 — Solo sync / confinement fix. Files: `LastHomeClient.lua`, `LastHomeWaves.lua`, `LastHomeShared.lua`, `specs/LH-07`. Solo sync moved to dedicated `Events.OnTick`; `isInsideBoundary()` fixed for PZ player objects (`getX()/getY()`); local `Zone: IN/OUT` HUD indicator; "Out of zone!" visual fallback.
- [x] LH-08 — Role equipment. Files: `LastHomeShared.lua` (`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`), `LastHomeClient.lua`, `LastHomeServer.lua`, `specs/LH-08`. Robust inventory/bag/equip distribution, 2-handed detection, pre-loaded ammo; reduced client/server duplication.
- [x] LH-10 — Reduced timers, wave skip, Villa stabilization. Files: `LastHomeWaves.lua`, `LastHomeClient.lua`, `LastHomeShared.lua`, `specs/LH-10`. Prep wave 1 = 2 min, later prep = 5 min, wave = 5 min; skip via `K`; skip HUD + client debounce; ground-level Villa spawns; vanilla zombies disabled in all challenges; ambient cleanup at prep/wave start; Villa forced South + alarm-sound attraction. Commits: `9da0397`, `5e0335d`, `b3dc132`.
- [-] PZ Challenges (Challenges menu) — REMOVED in LH-MP-6 (mod MP-only). Deleted the 4 `LastStand/LastHome{Hospital,Villa,Prison,School}.lua` + previews; removed the `SetHouse` `OnClientCommand` handler. Superseded by hardcoded `SCENARIO_HOUSE` + `OnServerStarted` bootstrap.
- [x] Solo role picker fallback (Challenge mode). Files: `LastHomeClient.lua`, `LastHomeRolePicker.lua`. `isSinglePlayerRuntime()` detection; `TickRolePickerFallback` (3s); `applyRoleLocally()`; solo `openLocal()` mode; `roleRequestSent` reset on game start.
- [x] LH-13 — Continuous vanilla/story spawn suppression. Files: `LastHomeWaves.lua`, `specs/LH-13`. `clearAmbientZombiesNearHouse(reason)` with prep/wave/periodic reasons; immediate cleanup at phase transitions; periodic cleanup every 1s while `started` + `house` set in scenario play; `LH_waveZombie` zombies excluded; `Server.nextAmbientCleanupAt` scheduled + reset in `resetState()`.
- [x] LH-14 — Firearm priming on role assignment. Files: `LastHomeShared.lua` (`fillAmmoItem`), `specs/LH-14`. Magazine-fed detection via non-empty `getMagazineType()`; capacity from `getMaxAmmo()` (then `getClipSize()`, then `getMaxAmmo()` fallback); `setContainsClip(true)` only for magazine-fed; replicates engine `randomizeBullets()` (`setCurrentAmmoCount` + `setRoundChambered` if `haveChamber()`); `isRanged()` guard. Fixed: `getClipSize()` returning 0 on AssaultRifle/HuntingRifle/Shotgun left them at 0 bullets.
- [x] LH-15 — On-screen stock arrow. Files: `LastHomeClient.lua` (`drawStockArrow`), `specs/LH-15`. Historical feature later removed by LH-21; it pointed to the community stock location (`house.stockSpawn`, fallback `house.supply`) with distance, visible through walls; `IsoUtils.XToScreenExact/YToScreenExact` projection; on-screen `v <dist>m` marker vs cardinal arrow clamped to edge; disabled in idle/gameover, without house, or within 3 tiles. ASCII cardinal arrow (PZ fonts lack unicode glyphs).
- [x] Challenge house-selection race fix. Files: the 4 `LastStand/*.lua`, `LastHomeServer.lua` (`SetHouse`). Root cause: `_gameStartRegistered` guard never removed stale `OnGameStart` handlers between challenge launches → a previously-played challenge's `SetHouse` fired first and locked the wrong house ("deja verrouillee"), so player stayed at the new spawn while server house was the old one → boundary + arrow ~3000 tiles off. Fix: client guards `SendHouseSelection` with `getChallengeID() == self.id`; server lets the last `SetHouse` win pre-wave, rejects only once `hasStarted()`. (Now moot after LH-MP-6 removed Challenges.)
- [x] LH-MP-1 — Reusable server-side `setSelectedHouse`. Files: `LastHomeServer.lua`. Exported `LastHomeServer.setSelectedHouse(houseId, source[, actorUsername])`; extracted former inline `SetHouse` logic; preserved pre-wave "last wins" + post-wave freeze, side effects (`house.source`, `houseSelectionLocked`, `syncSelectedHouse()`, re-arming the one-shot ground-stock spawn for a house change), roled-player re-teleport symmetry (`LH_houseSpawnId=nil` first). Challenge path actor-aware; scenario path `warnTeleportFailure` context. Commit `879c0c8`.
- [x] LH-MP-2 — Server bootstrap + scenario house config. Files: `LastHomeBootstrap.lua` (new), `LastHomeShared.lua` (`getScenarioHouseId`, `applyDefaultSandboxVars`), `specs/LH-MP-2`. Bootstrap hooks `OnServerStarted` (SERVER VM) + `OnGameStart` (solo fallback); dormant in solo Challenges (`isChallenge()` guard). `getScenarioHouseId()` returns the validated `SCENARIO_HOUSE` constant (no file I/O since LH-MP-6); `random` -> `getRandomHouse()`. `applyDefaultSandboxVars()` = shared body of the former challenge `setSandBoxVars` (`Zombies=6`, multipliers/respawn/rally=0). Event choice verified in-game 25-07-26: `OnServerStarted` is SERVER VM (DebugLog-server.txt), `OnGameStart` is CLIENT VM only (Console.txt); reset handler runs before bootstrap in each VM since `LastHomeServer.lua` loads before `LastHomeBootstrap.lua`. Commits: `2d53a06`, `8f00c01`.
- [x] LH-MP-3 — Generalize periodic cleanup to scenario houses. Files: `LastHomeWaves.lua`, `specs/LH-MP-3`. `isChallengeHouse()` -> `isScenarioHouse()` accepting `challenge | scenario`; all 3 call sites updated (prep-schedule L700, wave-schedule L751, OnTick periodic L1059) — all arm/execute the periodic cleanup; immediate phase-transition cleanups unchanged; `player-fallback`/`rotation` still excluded. Commit `dc3ceae`.
- [-] LH-MP-5 — House picker before role picker (MP sandbox) — CANCELLED in LH-MP-6 (picker removed). Implemented then dropped: cfg `picker` deferred auto-selection; first eligible player became chooser (`houseChooserUsername`); `ChooseHouse` authoritative; `HouseChosen` broadcast then `OpenRolePicker` fan-out; `maintainHousePicker` re-elected chooser on disconnect/spectate to avoid deadlock. Solo Challenges unchanged. Kept for the record only.
- [x] LH-MP-6 — MP-only mod: hardcoded scenario house. Files: `specs/LH-MP-6` (new), `LastHomeShared.lua`, `LastHomeBootstrap.lua`, `LastHomeServer.lua`, `LastHomeWaves.lua`, `LastHomeClient.lua`; deleted `LastHomeHousePicker.lua` + the 4 `LastStand/*.lua` + previews. `LastHomeShared.SCENARIO_HOUSE` constant (forced `elementary_school`); `getScenarioHouseId()` returns validated constant (no file I/O); all picker state/commands removed (`housePickerMode`, chooser helpers, `maintainHousePicker`, `ChooseHouse`/`SetHouse` handlers); `isScenarioHouse()` reverts to `challenge | scenario`. Two-VM bootstrap preserved.
- [x] LH-20 — Suspendre le nettoyage périodique pendant la vague. Files: `LastHomeWaves.lua`, `specs/LH-20-cleanup-pas-pendant-vague.md`. Historical delivery from commit `38b3967`; this behavior was later reverted, and the periodic ambient cleanup now runs again during active waves with a 1s interval, while still preserving the `"prep"`/`"wave"` transition one-shots and excluding `LH_waveZombie` zombies.
- [x] LH-21 — Supprimer la flèche du stock communautaire. Files: `LastHomeClient.lua`, `README.md`, `project-state.md`, `specs/LH-21-suppression-fleche-stock.md`. Removed `drawStockArrow` and `Events.OnPostUIDraw.Add(drawStockArrow)`; kept `house.stockSpawn` / `house.supply` / `getHouseStockSpawn` intact for LH-19; `drawWaveHud` unchanged. Verified in-game.
- [x] LH-22 — Rôle 007 Agent + dépendance Brita + tournevis pour tous. Files: `LastHomeRoles.lua`, `LastHomeShared.lua`, `mod.info`, `README.md`, `project-state.md`, `specs/LH-22-agent-brita-tournevis.md`. Added the 18th role **007 Agent** (PPK + `MP5SD6_Fixed`, tactical belt, Brita clothing), added `Base.Screwdriver` to every applicable existing role, and generalized `equipRoleItems()` so non-back worn containers can be equipped from `equipped.bag`. This intermediate branch state is now superseded by LH-26, which restores required `Brita` / `Brita_2` / `Arsenal(26)GunFighter[MAIN MOD 2.0]` dependencies. Pending in-game validation for Brita/Arsenal priming and suppressor mounting. `version=0.12.0`.
- [x] LH-23 — Relook Brita de 10 rôles (armes + armure tactique). Files: `LastHomeRoles.lua`, `LastHomeShared.lua`, `README.md`, `project-state.md`, `specs/LH-23-relook-brita-10-roles.md`. Rewrote the 10 selected role blocks with their validated Brita/Arsenal loadouts (weapons, magazines/ammo, tactical clothing, D3M/X_Vest/Tactical_Alice rigs, NV for `eclaireur`), preserved the LH-22 screwdriver rule, and enabled `setUnlimitedCarry` for `rambo` and `samourai`. Used `Base.TrapMouse` and `Base.PillsVitamins` as the valid runtime IDs for the spec's uncertain `MouseTrap` / `PillsVitamin`. This intermediate set is now superseded by LH-26's full 22-role PZRolePlay port. Pending in-game validation for priming, attachments, and worn-slot compatibility.
- [x] LH-24 — Déclenchement manuel de la 1ère vague (pas de timer d'auto-start). Files: `LastHomeWaves.lua`, `LastHomeClient.lua`, `README.md`, `project-state.md`, `specs/LH-24-declenchement-manuel-vague-1.md`. Prep wave 1 no longer arms a timer or one-minute warning, the server only auto-starts prep when `currentWave > 0`, `skipToNextWave(player)` now rejects dead/spectator players, and the HUD replaces the `0:00` countdown with **"Appuyez sur K pour lancer la vague 1"**. Also aligned the prep alert/log so wave 1 is announced as manual waiting rather than a countdown.

## Backlog

### High priority
- [x] LH-25 — Mod séparé : choix de rôle seul (role picker standalone). Spec : `specs/LH-25-mod-roles-seul.md`. **Réalisé via le repo `../PZRolePlay` (mod `id=PZRolePlaying`).** Mod standalone qui extrait le sous-système de rôles : picker + application de loadout, SANS maison/TP/vagues/stock/confinement/bootstrap. Set hybride : rôles vanilla par défaut + rôles Brita (LH-22 agent + LH-23 relook) si Brita/Arsenal détectés au runtime. Builder refill 10 min retiré ; `setUnlimitedCarry` conservé. Code dupliqué (pas de `require` vers last-home). Namespace modData `PZRP_role` (+ legacy `LR_role`). **Distinct de LH-26** (qui porte le set Brita dans Last Home en place, sans dépendre de PZRolePlay).
- [ ] LH-26 — Reprise des rôles de PZRolePlay dans Last Home (set Brita uniquement, 22 rôles). Spec : `specs/LH-26-roles-pzroleplay.md`. Remplace les defs embarquées de `LastHomeRoles.lua` par le set Brita de `../PZRolePlay` (rôles, équipements, perks, sacs, vêtements, helpers, profil de port), **en place** (code dupliqué, pas de `require` vers PZRolePlay). Mécaniques Last Home conservées (Builder refill, stock au sol, téléport spawn, confinement, vagues). Décisions validées : PZRolePlay→Last Home, set Brita uniquement ; D1 unlimited-carry pour tous (sauf vanilla) ; D2 min Woodwork3+Trapping3 injecté (sauf vanilla) ; D3 civil→vanilla (no-op, migration sémantique seule) ; D4 namespace LH_role conservé ; D5 require= Brita/Arsenal + livraison Workshop immédiate (échec de chargement clair si manquant) ; D6 pas de reprise du reopen-picker (reporté LH-27).
- [ ] LH-MP-4 — Write `docs/MULTIPLAYER_SETUP.md` + run the A-H verification checklist on a dedicated/Host server (no code change expected; failures become follow-up tickets). Must confirm: (a) `OnServerStarted` fires in the SERVER VM on Host and dedicated (verified Host 25-07-26; dedicated still unconfirmed); (b) minimal `Mods=`/`Map=` line per house (`Mods=LastHome` alone vs `+Pillow/Xonic`) and whether Pillow's Random Scenarios is still required now that the Challenges menu is gone; (c) hardcoded `LastHomeShared.SCENARIO_HOUSE` is honored (elementary_school by default)
- [x] LH-17 — Deduplication of role application (single source of truth in `LastHomeShared`). Spec written: `specs/LH-17-deduplication-role-equipment.md`
- [x] LH-18 — Stock communautaire : analyse A vs B terminée. `specs/LH-18-stock-spawn-analysis.md` confirme que l'approche A (caisse dédiée) échoue en sync MP sur chunk déjà chargé ; LH-19 applique l'approche B (`AddWorldInventoryItem`)
- [ ] LH-19 — Valider les autres maisons en jeu et réajuster `HOUSE_SUPPLY_MULTIPLIER` si le volume reste trop élevé hors cas école/Host déjà vérifié
- [ ] LH-22 — Vérifier en jeu l'intégration Brita/Arsenal : IDs de vêtements, priming de `Base.PPK` / `Base.MP5SD6_Fixed`, chargeurs remplis, montage de `Base.Suppressor_Pistol` avec `Base.Screwdriver`, et présence/port de `Base.Bag_Tactical_Belt_Front`
- [ ] LH-23 — Vérifier en jeu le relook Brita des 10 rôles : priming `Base.M4A1` / `Base.M249` / `Base.MP7` / `Base.M870_MCS` / `Base.M40A3` / `Base.HuntingRifle`, montage des accessoires (suppressors, optics, SureFire), port des rigs `Tail` (`Base.Bag_D3M`, `Base.Bag_X_Vest`, `Base.Bag_Tactical_Alice`) et du NV `Base.Hat_PVS15_ON`, ainsi que l'équilibrage global
- [ ] Fix Villa / house stock playability:
  - `pickHouseSpawnPoint` fails on all 10 spawn candidates (box `[13532..13533, 2839..2843, z=1]` → no `isFree` square); it only checks `isFree(false)` and needs a wider/falling-back scan
  - Validate the configured `stockSpawn`/`supply` square in Villa in-game so the ground stock lands in a practical location
- [ ] In-game solo/LAN verification of LH-03 through LH-10 (actual timers, skip, spectators, score, house spawn, shared stock, confinement, HUD, solo sync)
- [ ] In-game multiplayer verification of the role picker, spawn teleports, Builder/house refill, server confinement, and wave skip
- [ ] Validate / finish the remaining Host MP spawn-area issues: ambient/stray zombies can still remain around the player at/near the role spawn when the scenario starts; add a cleanup pass tied to the selected house / spawn area, not only the existing prep/wave cleanup; also validate that the ground-stock spawn appears quickly and reliably once the chunk is loaded
- [ ] Validate in-game the zombie pressure on Villa with sound pulse attraction (range, frequency, horde feel)

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
- LH-04 extends `LastHomeShared.lua` with the definition of 4 houses, their spawn zones, and their stock locations (`supply` / `stockSpawn`)
- LH-05 adds a rectangular `boundary` per house and an **authoritative server-side** confinement, with client-side HUD display
- LH-07 moves solo sync to `Events.OnTick`, fixes `isInsideBoundary()` for PZ player objects (`getX()/getY()`), and adds a local `Zone: IN/OUT` HUD indicator
- LH-08 extracts common equipment/loadout logic into `LastHomeShared.lua` (`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`) to reduce client/server duplication
- LH-17 completes the dedup: 12 additional utilities centralised (`addItemsToContainer`, `buildItemCounts`, `addRoleItems`, `applyRoleStats`, `applyPerkLevel`, `applyManualTeleportState`, `formatCoords`, `formatPlayerCoords`, `formatHouseLabel`, `formatBoundaryLabel`), unified logger `LastHomeShared.log(module, msg)`, `setSelectedHouse` simplified (12 → 1 branch), two new modules extracted: `LastHomeBoundary.lua` (confinement, ~200 lines) and `LastHomeStock.lua` (ground stock + maintenance, ~180 lines), both following `attach(server, deps)` injectable pattern
- LH-14 aligns `fillAmmoItem` with the engine's `HandWeapon:randomizeBullets()` (Ammo, ContainsClip, RoundChambered) to pre-load firearms on role assignment
- LH-10 reduces wave timers and adds prep skip via `K`, preserving `pendingDirections` through `startWave(false)` on skip
- For Villa, waves are currently forced to **South** and attraction relies on sound pulses centered on the base rather than zombie-by-zombie aggro targeting
- Last Home uses `SandboxVars.Zombies = 6` to cut vanilla pop; `5` only corresponds to low population in PZ
- Logs show `SandboxVars` + `ZombieConfig` aren't enough to prevent certain `RDS*` / `createEatingZombies` spawns in Challenge mode; a continuous server-side cleanup around the base is now specified in LH-13
- LH-19 replaces the old container-based community stock with a one-shot **ground spawn** (`AddWorldInventoryItem`) near `stockSpawn` / `supply`
- `COMMUNITY_STOCK_ITEMS` now contains only **food, water bottles, and ammunition** for the shared ground stock; `BUILDER_REFILL_ITEMS` remains the Builder's 10-minute inventory refill list
- `HOUSE_SUPPLY_MULTIPLIER` is currently **4** for the ground stock (down from 8); verified on MP Host for `elementary_school`, pending validation on the other houses
- All roles have at minimum `Carpentry` 3 and `Trapping` 3 to be able to create barricades and traps (existing higher levels are preserved, e.g. builder/invincible Carpentry 10, survivalist Trapping 8)
- Water bottles (`WaterBottleFull`) are placed in the main inventory, not the backpack (removed from `bagContents`), to remain accessible and prevent thirst
- The LH-02 implementation draws inspiration from Escapade Express's structure, but without role locking logic
- The current backlog should be maintained here with each completed or fixed ticket