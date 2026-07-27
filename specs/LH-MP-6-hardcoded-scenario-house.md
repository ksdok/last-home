# LH-MP-6 (M) — MP-only mod: hardcoded scenario house, drop cfg, drop picker, drop Challenges menu

## Context

Last Home shipped with two house-selection paths:

1. **Solo Challenges menu** — 4 entries (Hospital, Villa, Prison, School) in
   PZ's Challenges menu via `media/lua/client/LastStand/LastHome*.lua`
   (`Events.OnChallengeQuery.Add()`). Each challenge forces its house
   client-side (`SetHouse`) and injects sandbox vars.
2. **MP sandbox / Host** — `LastHomeBootstrap.lua` reads
   `Zomboid/Server/LastHomeHouse.cfg` and calls `setSelectedHouse(id,
   "scenario")`.

Three problems emerged:

1. **The cfg file was never reliably read.** In the SERVER VM, `fileExists`
   returns false and `getFileReader("Server/LastHomeHouse.cfg")` does not
   resolve the relative path at `OnServerStarted` (the file-I/O env / `getCore()`
   is not ready yet). The bootstrap silently fell back to `random` every
   session since LH-MP-2; the forced house (and the LH-MP-5 `picker` token)
   were ignored.
2. **The interactive picker (LH-MP-5) is not needed.** The host is the
   developer, who is happy to edit one Lua line to force a house. The picker's
   server state machine (chooser claim/release, re-election, command fan-out)
   and client UI are dead weight.
3. **The Challenges menu is not the target delivery.** The mod is meant to be
   played co-op in MP (Host/sandbox), not as a solo Challenge. The 4 challenge
   files, their `SetHouse` client command, and the challenge house-selection race
   fix are all challenge-specific scaffolding.

The two-VM fix from the `feat/lh-mp-5-house-picker` branch (`OnServerStarted`
bootstrap, server-VM reset, solo-only `OnGameStart` fallback) is **kept** — it is
independent of the selection mechanism and fixed the real zombie-spawn bug (the
bootstrap now runs in the authoritative server VM).

## Goal

Make Last Home an **MP mod** (Host/sandbox), with the scenario house selected by
a single **hardcoded Lua constant** (forced to `elementary_school` for now). Drop
the cfg file, drop the interactive house picker, and drop the Challenges menu.
Solo sandbox stays supported via the `OnGameStart` fallback.

## Non-goals

- Keeping `LastHomeHouse.cfg` support.
- Keeping the interactive house picker (LH-MP-5 is cancelled).
- Keeping the 4 Challenges menu entries.
- Supporting dedicated/headless hosting without a code edit (the host edits one
  line and relaunches).

## Architecture

### 1. Hardcoded constant

`media/lua/shared/LastHomeShared.lua`:

```lua
-- hospital | villa | prison | elementary_school | random
LastHomeShared.SCENARIO_HOUSE = "elementary_school"
```

`LastHomeShared.getScenarioHouseId()` returns the validated constant (default
`"random"` if invalid/missing). No file I/O. All `fileExists`/`getFileReader`/
`openFirstExisting`/cfg-path/`OnTick` retry code is removed.

### 2. Bootstrap simplified

`LastHomeBootstrap.lua`:

- Still hooks `Events.OnServerStarted` (SERVER VM, authoritative) + `OnGameStart`
  (solo-sandbox fallback, `isClient()` guard).
- Still registers AFTER `LastHomeServer` (reset → bootstrap ordering preserved).
- Reads `getScenarioHouseId()` (the constant). `random` → `getRandomHouse()`;
  otherwise `setSelectedHouse(id, "scenario")`.
- No `picker` branch, no `enterHousePickerMode`, no `GameServer` check, no
  `OnTick` retry, no nil-deferral.
- Idempotency: `if LastHomeServer.hasSelectedHouse() then return end`.

### 3. Challenges menu dropped

- Delete `media/lua/client/LastStand/LastHomeHospital.lua`,
  `LastHomeVilla.lua`, `LastHomePrison.lua`, `LastHomeSchool.lua`
  (the `Events.OnChallengeQuery.Add()` entries).
- Remove the `SetHouse` `OnClientCommand` handler in `LastHomeServer.lua`
  (no client sends it anymore). `setSelectedHouse` keeps accepting
  `source == "challenge"` defensively, but no caller uses it.
- The `isChallenge()` guard in the bootstrap stays as a safety (the mod must not
  bootstrap if some other challenge is running).

### 4. Picker removed (server)

`LastHomeServer.lua`:

- Remove `Server.housePickerMode`, `Server.houseChooserUsername`.
- Remove `enterHousePickerMode`, `isHousePickerMode`, the chooser helpers
  (`isEligibleChooser`, `isPlayerOnline`, `sendHousePickerOpen`,
  `sendHouseSelectionWaiting`, `broadcastHouseChosen`, `openRolePickerFor`,
  `fanOutRolePickersExceptChooser`, `electHouseChooser`,
  `notifyHouseSelectionWaitingToOthers`, `maintainHousePicker`,
  `routeRolePickerReadyIntoHousePicker`, `handleChooseHouse`).
- `RolePickerReady`: original flow (`ensureSelectedHouse` →
  `restoreAssignedRole` | `OpenRolePicker`).
- `ChooseRole`: remove the picker-mode gate.
- `ChooseHouse` command handler: removed.
- `ensureSelectedHouse`: remove the `housePickerMode` gate.
- Reset (`OnServerStarted` + `OnGameStart`): drop picker fields.

### 5. Picker removed (client)

- Delete `media/lua/client/LastHomeHousePicker.lua`.
- `LastHomeClient.lua`: remove `require "LastHomeHousePicker"`,
  `cancelRolePickerRetry`, and the `OpenHousePicker` / `HouseSelectionWaiting` /
  `HouseChosen` / `HousePickerError` handlers.

### 6. Waves cleanup gate

`LastHomeWaves.lua`: `isScenarioHouse()` reverts to
`source == "challenge" | "scenario"` (drop `"scenario-picker"`).

## Files impacted

- `media/lua/shared/LastHomeShared.lua` — `SCENARIO_HOUSE` constant (forced to
  `elementary_school`); `getScenarioHouseId` returns it; remove file-I/O helpers
  and `getHousePickerEntries`.
- `media/lua/server/LastHomeBootstrap.lua` — read the constant; remove
  `picker`/`GameServer`/`OnTick`/nil-deferral.
- `media/lua/server/LastHomeServer.lua` — remove all picker state/helpers/commands
  and the `SetHouse` handler; simplify `RolePickerReady`/`ChooseRole`/reset/
  `ensureSelectedHouse`.
- `media/lua/server/LastHomeWaves.lua` — `isScenarioHouse` reverts to
  `challenge | scenario`.
- `media/lua/client/LastHomeClient.lua` — remove picker require/handlers/
  `cancelRolePickerRetry`.
- `media/lua/client/LastHomeHousePicker.lua` — **deleted**.
- `media/lua/client/LastStand/LastHomeHospital.lua` — **deleted**.
- `media/lua/client/LastStand/LastHomeVilla.lua` — **deleted**.
- `media/lua/client/LastStand/LastHomePrison.lua` — **deleted**.
- `media/lua/client/LastStand/LastHomeSchool.lua` — **deleted**.
- `specs/LH-MP-6-hardcoded-scenario-house.md` **(new)**.
- `README.md`, `project-state.md` — mark LH-MP-5 cancelled, LH-MP-6 implemented,
  drop the Challenges mention.

## Acceptance criteria

1. No `LastHomeHouse.cfg` file is read or required.
2. `LastHomeShared.SCENARIO_HOUSE` selects the house; the default commit forces
   `elementary_school`. Setting it to `villa`/`random`/etc. forces that house.
3. The interactive house picker never appears; `LastHomeHousePicker.lua` is
   gone; no `ChooseHouse` / `OpenHousePicker` / `HouseChosen` /
   `HouseSelectionWaiting` / `HousePickerError` commands exist.
4. The Challenges menu has no Last Home entries; the 4 `LastStand/LastHome*.lua`
   files are gone; the server no longer handles `SetHouse`.
5. The bootstrap runs in the SERVER VM via `OnServerStarted`
   (`applyDefaultSandboxVars` suppresses vanilla zombies at the initial MP
   spawn; the selected house is authoritative server-side).
6. Solo sandbox still works: launching a solo sandbox game with the mod active
   selects the house via the `OnGameStart` fallback (the single VM is
   authoritative in solo).
7. Re-host in the same process re-bootstraps (reset clears `selectedHouse`, the
   idempotency guard lets the bootstrap re-run).
8. An invalid `SCENARIO_HOUSE` value falls back to `random` with a server log.

## Pitfalls

- Do not reintroduce the cfg file read (it was never reliable in the server VM).
- Do not remove the `OnServerStarted` hook or the solo `OnGameStart` fallback
  (`isClient()` guard) — those are the two-VM fix and must stay.
- Do not remove the server-VM reset on `OnServerStarted` (re-host safety).
- Keep `setSelectedHouse(id, "scenario")` so `isScenarioHouse()` still gates the
  LH-13 periodic cleanup.
- The `isChallenge()` guard in the bootstrap stays (defensive; some other
  challenge could be running while the mod is loaded).

## Dependencies

- The two-VM fix from `feat/lh-mp-5-house-picker` (`OnServerStarted` bootstrap +
  server-VM reset + solo `OnGameStart` fallback).
- `LH-MP-1` (`LastHomeServer.setSelectedHouse`).

## Supersedes

- **LH-MP-5** (house picker before the role picker) — cancelled; the picker is
  removed.
- The solo Challenges menu delivery — cancelled; the mod is MP-only (with solo
  sandbox kept).

## Size estimate

**M** — removal across server/client/shared + 5 file deletions + one constant;
the bootstrap gets simpler.