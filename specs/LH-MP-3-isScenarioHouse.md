# LH-MP-3 (S) - Generalize periodic cleanup to scenario houses

> Parent: `specs/LH-MP-multiplayer-sandbox-conversion.md`

## Context

LH-13 added a **periodic** server-side cleanup of ambient (non-`LH_waveZombie`)
zombies around the base, gated on `isChallengeHouse()`:

```lua
local function isChallengeHouse()
    return Server.house ~= nil and Server.house.source == "challenge"
end
```

In multiplayer sandbox mode the house is selected by the bootstrap with
`source == "scenario"` (LH-MP-2). The periodic cleanup must also run for
scenario houses, otherwise ambient vanilla zombies accumulate around the base
in MP (the exact problem LH-13 solved for solo Challenges).

The **immediate** cleanup at phase transitions (prep start / wave start) is
already unconditional and is not affected by this ticket.

## Goal

Rename/generalize the gate so the periodic cleanup runs for both
`source == "challenge"` and `source == "scenario"`, with a single source of
truth and clear logs.

## Changes

### 1. `media/lua/server/LastHomeWaves.lua`

Replace:

```lua
local function isChallengeHouse()
    return Server.house ~= nil and Server.house.source == "challenge"
end
```

with:

```lua
-- True when the house was selected by an LH scenario (solo Challenge or MP
-- sandbox). Used to gate the LH-13 periodic ambient cleanup, which must not
-- alter vanilla population in a normal Last Home sandbox game without a
-- selected house.
local function isScenarioHouse()
    return Server.house ~= nil
        and (Server.house.source == "challenge"
          or Server.house.source == "scenario")
end
```

### 2. Update the call site

In the `OnTick` periodic-cleanup block, replace the `isChallengeHouse()`
guard with `isScenarioHouse()`:

```lua
if Server.started and not Server.gameOver and isScenarioHouse() then
    if Server.nextAmbientCleanupAt ~= nil and now >= Server.nextAmbientCleanupAt then
        clearAmbientZombiesNearHouse("periodic")
        Server.nextAmbientCleanupAt = now + AMBIENT_CLEANUP_INTERVAL_SECONDS
    end
end
```

### 3. (Optional) Expose for tests

Expose `LastHomeWaves.isScenarioHouse = isScenarioHouse` so a test/debug
command can confirm the gate state.

## Files impacted

- `media/lua/server/LastHomeWaves.lua`
  - Rename `isChallengeHouse` -> `isScenarioHouse` (or keep the name and widen
    the check; implementer's choice, but the check must accept both sources).
  - Update the one `OnTick` call site that gates the periodic cleanup.

## Acceptance criteria

1. With `Server.house.source == "scenario"`, the periodic ambient cleanup
   runs every `AMBIENT_CLEANUP_INTERVAL_SECONDS` while
   `Server.started and not Server.gameOver`.
2. With `Server.house.source == "challenge"`, behavior is unchanged from
   LH-13 (no regression for solo Challenges).
3. With no house or `source == "player-fallback"` / `source == "rotation"`,
   the periodic cleanup does **not** run (unchanged).
4. The immediate phase-transition cleanups (`prep` / `wave` reasons) still
   run unconditionally regardless of `source`.
5. `LH_waveZombie`-tagged zombies and spectator-spawned zombies are never
   removed by the periodic cleanup (unchanged).

## Pitfalls (for the implementer)

- Do not widen the gate to `source == "player-fallback"` or
  `source == "rotation"`; those are non-scenario paths and must keep vanilla
  population intact.
- Keep the exclusion of `LH_waveZombie` zombies in
  `clearAmbientZombiesNearHouse` unchanged (only the *gate* changes here).

## Dependencies

- LH-13 (`clearAmbientZombiesNearHouse`, `AMBIENT_CLEANUP_INTERVAL_SECONDS`,
  `Server.nextAmbientCleanupAt`).
- LH-MP-2 (the bootstrap sets `source == "scenario"`).

## Size estimate

Small (S) — one renamed/expanded guard + one call-site update; no logic
change to the cleanup itself.