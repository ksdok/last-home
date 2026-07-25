# LH-MP (M) - Last Home: Host the scenario in multiplayer (sandbox conversion)

## Context

Last Home is **architecturally co-op** (README: "Co-op up to 8 players") and the
server-side code is already written multiplayer-first:

- Authoritative server confinement (LH-05).
- `Events.OnClientCommand` handlers using the server-side `player` object
  (`LastHomeServer.lua`, `LastHomeWaves.lua`).
- `getScenarioPlayers()` already branches on `getOnlinePlayers()` (MP) vs
  `getPlayer()` (solo) in `LastHomeShared.lua`.
- Role picker driven by `sendServerCommand("LastHome", "OpenRolePicker", ...)`.
- Wave zombies spawned with `addZombiesInOutfit(x, y, z, count, outfit, 0)`,
  a vanilla server-side API that replicates zombies to clients.
- Periodic ambient-zombie cleanup around the base (LH-13).

**However, the mod cannot be launched in multiplayer.** The 4 scenarios are
registered as **Project Zomboid Challenges** via `addChallenge()` /
`Events.OnChallengeQuery` (in `media/lua/client/LastStand/LastHome*.lua`). The
Challenges menu is **single-player only** in PZ B41; the multiplayer **Host**
flow has no "select challenge" option. The community + Steam discussions
confirm there is no vanilla way to host a challenge in MP.

The only thing blocking multiplayer is therefore the **bootstrapping layer**
that today relies on the challenge runtime:

1. Forcing the house via `sendClientCommand("LastHome", "SetHouse", ...)` from
   the challenge's client `OnGameStart`.
2. Injecting `SandboxVars` (`Zombies = 6`, multipliers `0`) via the challenge's
   `setSandBoxVars()`.
3. Providing the player spawn point (`xcell/ycell/x/y/z`).

None of these involve gameplay logic. The goal of this spec is to add a
**server-side bootstrap** that performs steps 1 and 2 without the challenge
runtime, so the mod becomes launchable from the multiplayer **Host** menu as a
normal sandbox game on `Muldraugh, KY`.

> **Map dependency is unverified.** The code has **zero** references to Pillow's
> Random Scenarios or Xonic's Mega Mall (the deps listed in `README.md`), so the
> dependency is purely at the **map-content** level (the 4 buildings must exist
> in the loaded map). It is currently unknown whether all 4 buildings are vanilla
> Muldraugh or whether some come from Xonic's Mega Mall. This must be confirmed
> in LH-MP-4 before the final `Mods=` / `Map=` line is fixed. See the
> "Map / mod dependencies" open question below.

The solo Challenges mode is **preserved** as-is.

## Goal

A server admin can host Last Home in multiplayer by:

1. Starting a PZ server with `Map = Muldraugh, KY` and `Mods = LastHome`
   (+ required deps).
2. Optionally writing the chosen house to a server config file.
3. Players join, pick a role, are teleported to the house, and the wave loop
   runs identically to solo — including confinement, spectators, and the
   ambient cleanup.

No gameplay code is rewritten. No custom map is shipped.

## Non-goals

- Do **not** rewrite waves, roles, confinement, HUD, or the role picker.
- Do **not** remove the solo Challenges mode.
- Do **not** ship a custom map; reuse the map that already provides the 4
  buildings (vanilla `Muldraugh, KY` and/or the existing map dependency —
  confirmed in LH-MP-4).
- Do **not** add an in-game vote / house-selection UI (out of scope; config
  file is sufficient for v1).

## Architecture

### What is reusable unchanged

| Component | File | Why it is MP-ready |
|---|---|---|
| Waves, scaling, directions, spectator | `media/lua/server/LastHomeWaves.lua` | `OnTick`/`OnZombieDead`/`OnClientCommand`, `addZombiesInOutfit()` replicates to clients |
| Confinement | `media/lua/server/LastHomeWaves.lua` | Authoritative server-side (LH-05) |
| Roles, teleport, refill | `media/lua/server/LastHomeServer.lua` | `OnClientCommand(module, command, player, data)` per-player |
| Houses/coords/boundary helpers | `media/lua/shared/LastHomeShared.lua` | `getScenarioPlayers()` already MP-aware |
| Role definitions | `media/lua/shared/LastHomeRoles.lua` | Pure data |
| Role picker | `media/lua/client/LastHomeRolePicker.lua` | Server-driven via `OpenRolePicker` |
| HUD / sync | `media/lua/client/LastHomeClient.lua` | `sendServerCommand` + dedicated `OnTick` (LH-07) |

### What is naturally inert in MP (no change needed)

The 4 challenge files `media/lua/client/LastStand/LastHome*.lua` are inert in a
sandbox MP game:

- `Events.OnChallengeQuery.Add(X.Add)` only fires in the Challenges menu.
- `X.OnInitWorld` / `X.setSandBoxVars` are called **only by the challenge
  runtime**, which does not run in a sandbox MP server.
- `Events.OnGameStart.Add(X.OnGameStart)` is registered **inside**
  `X.OnInitWorld`, so it is never registered in MP.

Conclusion: these files require **no modification**. They keep working for the
solo Challenges mode and stay dormant in MP.

### What must be added

A single new server bootstrap that replaces the three challenge-runtime
duties (house selection, SandboxVars injection, spawn), without gameplay
changes:

```
Server OnGameStart (new LastHomeBootstrap.lua)
  -> read house id from config (or "random")
  -> LastHomeServer.setSelectedHouse(houseId, "scenario")
  -> inject SandboxVars best-effort (Zombies=6, multipliers 0)
  -> existing teleport-on-role-pick handles spawn
```

### Bootstrap event: `OnGameStart` (decision)

The bootstrap hooks `Events.OnGameStart`, **not** `Events.OnServerStarted`,
for a specific ordering reason:

- The existing `LastHomeServer.onGameStart` resets state on `OnGameStart`,
  including `Server.selectedHouse = nil`.
- `OnServerStarted` fires **before** `OnGameStart`. If the bootstrap ran on
  `OnServerStarted`, the subsequent `OnGameStart` reset would **wipe** the
  house the bootstrap just selected.
- By registering the bootstrap on the same `OnGameStart` event **after** the
  existing reset handler (PZ fires `OnGameStart` handlers in registration
  order), the sequence is: reset -> bootstrap sets house -> no wipe.
- This mirrors the current solo challenge timing: server `OnGameStart` resets,
  then the client `SetHouse` command arrives and sets the house.

Trade-off: `OnGameStart` is documented as a client/"entered the game" event,
but the existing server code already relies on it for state reset, and on a
dedicated server it fires once when the world finishes loading (before players
connect), which is early enough for house selection. **LH-MP-4 must confirm
`OnGameStart` fires on the dedicated server.** If it does not, the fallback is
to move **both** the reset and the bootstrap to `OnServerStarted` (so the
reset still runs before the bootstrap). This decision is detailed in LH-MP-2.

## House selection (config-driven)

A dedicated server has no reliable client-side mod-option channel. House
selection is therefore read from a **plain server config file**, validated,
with a `random` fallback. This is dedicated-server-safe and has no dependency
on uncertain B41 sandbox-option UI APIs.

- File: `Zomboid/Server/LastHomeHouse.cfg`
- Format: a single token on the first non-empty, non-comment line.
- Valid tokens: `hospital`, `villa`, `prison`, `elementary_school`, `random`.
- Lines starting with `#` are comments.
- Missing / unreadable / invalid file -> `random`.

Reading is centralized in `LastHomeShared.getScenarioHouseId()` so the rule
has one source of truth.

## Spawn handling

No new spawn system is required. The existing flow already works in MP:

1. Player joins -> spawns at the server's default spawn (`Muldraugh, KY`).
2. Client `requestRolePicker()` -> `sendClientCommand("LastHome",
   "RolePickerReady")` -> server opens the picker.
3. Player picks a role -> server `ChooseRole` handler ->
   `applyRole()` + `teleportPlayerToHouse()` (already implemented,
   MP-safe per-player).
4. Reconnects with an existing role -> `restoreAssignedRole()` already calls
   `teleportPlayerToHouse()`.

Optional (not required for v1): set `SpawnPoint=` in the server config near
the chosen house to avoid the brief Muldraugh spawn. Not blocking.

## SandboxVars injection

The challenge's `setSandBoxVars()` is duplicated 4x in the challenge files and
only runs in challenge mode. For MP we move the **same body** into a shared
server-callable function and call it from the bootstrap. Because mutating
`SandboxVars` after world init may not retro-apply to the population manager,
this is a **best-effort** guard; the existing LH-13 periodic cleanup already
compensates. The admin is also expected to set `Zombies = 0` (None) in the
server sandbox settings (documented in LH-MP-4).

## Changes summary (by ticket)

| Ticket | Size | Change |
|---|---|---|
| LH-MP-1 | S | Refactor `SetHouse` handler to expose `LastHomeServer.setSelectedHouse(houseId, source)` reusable by challenge + scenario paths. |
| LH-MP-2 | S | Add `LastHomeBootstrap.lua` (server): read house config -> `setSelectedHouse(..., "scenario")`; inject `SandboxVars` best-effort. Extract `setSandBoxVars` body to `LastHomeShared.applyDefaultSandboxVars()`. |
| LH-MP-3 | S | Generalize `isChallengeHouse()` -> `isScenarioHouse()` in `LastHomeWaves.lua` so the LH-13 periodic cleanup runs for `source == "scenario"` too. |
| LH-MP-4 | M | Server setup documentation + multiplayer verification checklist (roles, teleport, confinement, waves, spectators, late joiners). |

## Files impacted

- `media/lua/server/LastHomeServer.lua` (LH-MP-1)
- `media/lua/shared/LastHomeShared.lua` (LH-MP-2: `getScenarioHouseId`,
  `applyDefaultSandboxVars`)
- `media/lua/server/LastHomeBootstrap.lua` **(new)** (LH-MP-2)
- `media/lua/server/LastHomeWaves.lua` (LH-MP-3)
- `specs/LH-MP-multiplayer-sandbox-conversion.md` (this file)
- `specs/LH-MP-1-*.md`, `LH-MP-2-*.md`, `LH-MP-3-*.md`, `LH-MP-4-*.md` (tickets)
- `README.md`, `project-state.md` (status update after LH-MP-4)

## Acceptance criteria (parent)

1. A dedicated server with `Map = Muldraugh, KY` + `Mods = LastHome` (+ the map
   deps confirmed in LH-MP-4) launches Last Home and runs the wave loop without
   the Challenges menu.
2. The house is selectable from `Zomboid/Server/LastHomeHouse.cfg`; an absent
   or invalid file falls back to `random`.
3. Players who join, pick a role, and are teleported to the house; reconnects
   restore the role and re-teleport.
4. Confinement, spectators, wave scaling, and the ambient cleanup behave the
   same as in solo Challenges mode.
5. The solo Challenges mode (4 entries in the Challenges menu) still works
   unchanged.
6. No custom map is shipped; the mod reuses the map that provides the 4
   buildings (vanilla Muldraugh and/or the existing map dependency, confirmed
   in LH-MP-4).
7. `OnGameStart` is confirmed to fire on the dedicated server (LH-MP-4); if
   not, the reset + bootstrap move to `OnServerStarted` (fallback).

## Dependencies

- LH-03 (waves, `LH_waveZombie` tagging, `Server.house`)
- LH-04 (house definitions, `getRandomHouse`, teleport-on-role-pick)
- LH-05 (server confinement)
- LH-07 (solo sync; the MP path uses the same server sync)
- LH-13 (periodic ambient cleanup gated on house source)

## Open questions

- **Map / mod dependencies (to confirm in LH-MP-4).** The code references no
  Pillow/Xonic content. Two configurations must be tested on a dedicated
  server:
  - Minimal: `Mods=LastHome` only, `Map=Muldraugh, KY`.
  - Full (matches `README.md`): `Mods=LastHome;<Pillow>;<Xonic>`, with Xonic's
    Mega Mall as the map.
  LH-MP-4 determines, per house, whether the building exists with the minimal
  set or requires the map dependency. The final `Mods=` / `Map=` line and any
  `mod.info` dependency declaration are fixed from that result.
- **`mod.info` declares no dependencies today.** If the map dependency is
  confirmed as required, add the proper `require=` / workshop dependency in
  `mod.info` as a follow-up (out of scope for the LH-MP code tickets).
- Should v1 also set `SpawnPoint=` per house in the server config, or is the
  teleport-on-role-pick sufficient? Decision: teleport-on-role-pick is
  sufficient for v1; `SpawnPoint=` is documented as optional in LH-MP-4.
- Should we register a proper custom Sandbox option (UI) later? Decision:
  out of scope for v1; config file is the v1 mechanism, upgradeable later.

## Size estimate

Medium (M) overall. The parent spec coordinates 4 tickets (3x S + 1x M) with
no gameplay rewrite; the main runtime risk is verification, not code.