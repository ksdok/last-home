# LH-MP-4 (M) - MP server setup documentation + multiplayer verification

> Parent: `specs/LH-MP-multiplayer-sandbox-conversion.md`
> Depends on: LH-MP-1, LH-MP-2, LH-MP-3 (must be implemented first).

## Context

After the bootstrap refactor, Last Home is launchable in multiplayer, but it
has never been tested in MP (see `project-state.md` backlog: "In-game
multiplayer verification ... is pending"). This ticket delivers:

1. A server setup guide so an admin (or an LLM) can host Last Home in MP.
2. A structured MP verification checklist covering the gameplay systems that
   have only been validated in solo so far.

No code change is expected here; this is documentation + test. If a bug is
found during verification, it becomes a follow-up ticket.

## Goal

A reproducible multiplayer setup + a verified checklist that the wave loop,
roles, teleport, confinement, spectators, and the ambient cleanup all behave
in MP as they do in solo Challenges mode.

## Part 1 - Server setup documentation

Add `docs/MULTIPLAYER_SETUP.md` (new) with the following content (keep it
accurate to PZ B41 dedicated-server / Host config):

### Required mods (server config) — to be confirmed by this ticket

The code references **no** Pillow/Xonic content; the dependency is purely at
the map-content level (the 4 buildings must exist in the loaded map). Whether
the buildings are vanilla `Muldraugh, KY` or come from Xonic's Mega Mall is
**unverified**. This ticket determines the minimal required `Mods=` / `Map=`
line by testing two configurations:

```ini
# Minimal configuration (to validate):
Mods=LastHome
Map=Muldraugh, KY

# Full configuration (matches README.md, fallback):
Mods=LastHome;<PillowRandomScenarios>;<XonicMegaMall>
Map=Muldraugh, KY            # or the map Xonic's Mega Mall provides
WorkshopItems=<LastHome workshop id>;2106657533;1713269594
```

- `2106657533` = Pillow's Random Scenarios (host mod, challenge framework).
- `1713269594` = Xonic's Mega Mall (map dependency, per `README.md`).
- Replace `<...>` placeholders with the exact Workshop IDs once published (or
  use the local mod folder during dev).

The final documented `Mods=` / `Map=` line is whatever lets all 4 houses
load and spawn correctly. If the minimal config works for all 4 houses,
Pillow/Xonic are **not** required for MP and the doc reflects that. If any
house fails to load without Xonic's map, the doc requires it and a follow-up
ticket adds the dependency to `mod.info` (see LH-MP open questions).

### Recommended sandbox settings (server)

Set in the server's sandbox config (or `<ServerName>_SandboxVars.lua`):

```ini
Zombies = 0            # "None" — disables vanilla population
```

The mod also injects `SandboxVars.Zombies = 6` + multipliers `0` best-effort
on `OnGameStart` (LH-MP-2), but the admin-set value is the reliable source.
The LH-13 periodic cleanup compensates for any residual ambient spawns.

### House selection (optional)

Create `Zomboid/Server/LastHomeHouse.cfg` with one token:

```
# Choose one: hospital | villa | prison | elementary_school | random
villa
```

If absent/invalid, the mod defaults to `random`.

### Spawn point (optional)

Not required. Players spawn at the server default (Muldraugh) and are
teleported to the house when they pick a role. To reduce the brief pre-role
spawn, optionally set in `world.ini`:

```ini
SpawnPoint=<Cx>,<Cy>,<Rx>,<Ry>   # near the chosen house; see house coords
```

House centers (from the challenge definitions) for reference:

| House | Cell (X,Y) | Rel (X,Y) | Z |
|---|---|---|---|
| Hospital | 41,12 | 80,82 | 0 |
| Villa | 45,9 | 32,142 | 1 |
| Prison | 25,39 | 183,163 | 0 |
| School | 35,33 | 113,74 | 0 |

### Launch

1. Start the server with the config above.
2. Players join via **Join** (or Steam invite for a Host server).
3. Each player opens the role picker, picks a role, and is teleported to the
   house.
4. The first prep phase begins (2 min, per LH-10); `K` skips to the wave.

## Part 2 - MP verification checklist

Each item must be verified on a **dedicated server** (or Host) with **>= 2
players**. Record pass/fail + server log evidence. A failing item spawns a
follow-up ticket (do not mark this ticket complete with failures).

### A. Bootstrap / house selection

- [ ] A1. With no `LastHomeHouse.cfg`, server logs `Selection scenario
      house=random` and picks one of the 4 houses.
- [ ] A2. With `LastHomeHouse.cfg = villa`, server logs `house=villa` and
      `Maison selectionnee (source=scenario): Villa`.
- [ ] A3. `Server.house.source == "scenario"` after the bootstrap runs (check
      via a debug log).
- [x] A4. **Bootstrap event confirmation (resolved 25-07-26):** `OnGameStart`
      does **not** fire on the MP server process (confirmed by server log
      `25-07-26_23-26-48`: bootstrap loads but never runs, `Server.house` stays
      nil). Fix applied on `fix/lh-mp-2-bootstrap-on-server-started`: the
      bootstrap now hooks `Events.OnServerStarted` (with a `bootstrapRan`
      one-shot guard). Re-verify A1-A3 with the fix: the server log must show
      `LastHomeBootstrap OnServerStarted` then `Selection scenario house=...`
      then `Maison selectionnee (source=scenario): ...`.
- [ ] A5. Solo Challenges mode still works: launching "Last Home: Hopital"
      from the Challenges menu selects the hospital with `source=challenge`,
      and the bootstrap does not double-select (logs `Mode Challenge
      detecte -> bootstrap inactif`).
- [ ] A6. **Config path resolution:** placing `LastHomeHouse.cfg` at the
      absolute path returned by `getCore():getMyDocumentFolder()` +
      `/Server/LastHomeHouse.cfg` is read correctly; the resolved path is
      logged.
- [ ] A7. **Map dependency:** verify, per house, whether the building loads
      with `Mods=LastHome` alone or requires the map dependency (Xonic's Mega
      Mall). Record the minimal `Mods=` / `Map=` line that loads all 4
      houses; update `docs/MULTIPLAYER_SETUP.md` accordingly.

### B. Roles + teleport

- [ ] B1. Each joining player gets the role picker within a few seconds.
- [ ] B2. Picking a role assigns the equipment, skills, stats, carry profile,
      and primes firearms (LH-08/LH-14).
- [ ] B3. After picking a role, the player is teleported to the house spawn.
- [ ] B4. A second player picking a role is also teleported (independent
      spawn squares, no overlap/stack error).
- [ ] B5. Disconnect + reconnect with an existing role: role is restored and
      the player is re-teleported (`restoreAssignedRole`).

### C. Wave loop (LH-03 / LH-10)

- [ ] C1. First prep is 2 min; subsequent preps and waves are 5 min.
- [ ] C2. `K` skips the current prep (any player); server validates
      (`SkipToNextWave`).
- [ ] C3. Wave zombies spawn with `addZombiesInOutfit` and are visible to all
      clients (replication).
- [ ] C4. Zombie count scales with wave number and living player count.
- [ ] C5. Directions escalate (1 -> 2 -> 3 -> 360) across waves.
- [ ] C6. Leftover zombies overflow to the next wave.
- [ ] C7. Score (`wavesSurvived`) increments on each cleared wave and is
      announced.

### D. Confinement (LH-05)

- [ ] D1. A player walking out of the boundary gets a 10s countdown HUD on
      all clients.
- [ ] D2. After the countdown, the player takes progressive server-side
      damage while outside.
- [ ] D3. Re-entering the zone stops the damage and clears the countdown.
- [ ] D4. Spectators and dead players are exempt from confinement.
- [ ] D5. The boundary applies to each player independently (no shared
      countdown leak between players).

### E. Spectators (LH-03)

- [ ] E1. A dead player becomes a spectator and cannot pick a new role.
- [ ] E2. Spectators can spawn exactly 1 zombie per active wave.
- [ ] E3. A spectator-spawned zombie is not removed by the periodic cleanup.

### F. Ambient cleanup (LH-13 / LH-MP-3)

- [ ] F1. With `source=scenario`, the periodic cleanup runs every ~5s while
      the game is active (log `Nettoyage zombies ambiants (periodic)`).
- [ ] F2. Non-`LH_waveZombie` zombies within the cleanup radius are removed.
- [ ] F3. `LH_waveZombie` zombies and spectator zombies are preserved.
- [ ] F4. Cleanup stops after game over.

### G. Late joiners

- [ ] G1. A player joining mid-prep gets the picker and is teleported.
- [ ] G2. A player joining mid-wave gets the picker and is teleported; the
      wave count is not reset.
- [ ] G3. A late joiner with a role is confined like any other player.

### H. HUD / sync (LH-06 / LH-07)

- [ ] H1. The wave HUD (phase, timer MM:SS, score) is correct on all clients.
- [ ] H2. The stock arrow (LH-15) points to the community container on all
      clients.
- [ ] H3. Server/client announcements broadcast to all players.

## Files impacted

- `docs/MULTIPLAYER_SETUP.md` **(new)** — server setup guide.
- `project-state.md` — check off the "In-game multiplayer verification"
  backlog item (only if all checklist items pass; otherwise list failures as
  follow-up tickets).
- `README.md` — add a short "Multiplayer" section pointing to
  `docs/MULTIPLAYER_SETUP.md`.

## Acceptance criteria

1. `docs/MULTIPLAYER_SETUP.md` exists and lets an admin (or another LLM) host
   the mod in MP with only the documented config.
2. Every checklist item A-H is verified pass on a dedicated/Host server with
   >= 2 players, with log evidence recorded.
3. Any failure is filed as a follow-up ticket and referenced from
   `project-state.md`; this ticket is not marked complete while a failure is
   unresolved.
4. `README.md` references the multiplayer setup doc.

## Pitfalls (for the implementer / tester)

- Use a dedicated server (or a real Host server), **not** solo, for these
  checks — solo is covered by LH-07.
- Confirm `WorkshopItems`/`Mods` IDs match the published Workshop entries
  (or local dev paths) before documenting them.
- The Villa `pickHouseSpawnPoint` failure (known backlog bug, `isFree(false)`
  on the 10 candidates) may block B3 for Villa; if so, test Hospital/Prison/
  School first and file the Villa spawn fix as a separate ticket.

## Dependencies

- LH-MP-1, LH-MP-2, LH-MP-3 (bootstrap must work before verification).
- LH-03, LH-04, LH-05, LH-06, LH-07, LH-08, LH-10, LH-13, LH-14, LH-15
  (the systems under verification).

## Size estimate

Medium (M) — documentation + a thorough multi-system verification pass on a
real server. No code change expected; the cost is testing and iterating on
any discovered defects.