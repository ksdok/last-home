# LH-MP-2 (S) - Server bootstrap: LastHomeBootstrap.lua

> Parent: `specs/LH-MP-multiplayer-sandbox-conversion.md`
> Depends on: LH-MP-1 (`LastHomeServer.setSelectedHouse`).

## Context

In solo Challenges mode, the challenge runtime calls `setSandBoxVars()` and
the challenge's client `OnGameStart` sends `SetHouse`. Neither runs in a
multiplayer sandbox server. We need a server-side bootstrap that:

1. Reads the chosen house from a config file (dedicated-server-safe).
2. Calls `LastHomeServer.setSelectedHouse(houseId, "scenario")` directly.
3. Injects the same `SandboxVars`/`ZombieConfig` values the challenge used,
   as a best-effort guard (LH-13 cleanup compensates if mutation is partial).

This bootstrap must **not** run when the game is a Challenge
(`getCore():isChallenge()`), to avoid double-selecting the house against the
challenge path.

### Bootstrap event decision: `OnGameStart` (not `OnServerStarted`)

The bootstrap hooks `Events.OnGameStart`, registered **after** the existing
`LastHomeServer.onGameStart` reset handler (PZ fires `OnGameStart` handlers in
registration order). Rationale:

- The existing reset wipes `Server.selectedHouse = nil` on `OnGameStart`.
- `OnServerStarted` fires **before** `OnGameStart`, so a bootstrap on
  `OnServerStarted` would have its selected house wiped by the subsequent
  reset.
- Registering the bootstrap on `OnGameStart` after the reset gives the
  correct sequence: reset -> bootstrap sets house -> no wipe.

Fallback (validated in LH-MP-4): if `OnGameStart` turns out not to fire on a
dedicated server, move **both** the reset (from `LastHomeServer.lua`) and this
bootstrap to `OnServerStarted`, keeping the reset-before-bootstrap order.

Implementation note: to guarantee registration order, this file's
`Events.OnGameStart.Add(...)` must execute after `LastHomeServer.lua`'s
`Events.OnGameStart.Add(...)`. PZ loads `media/lua/server/` files in
alphabetical order, and `LastHomeBootstrap.lua` sorts after
`LastHomeServer.lua`, so the bootstrap registers after the reset by default.
The implementer must verify this load order and, if not guaranteed, force it
with a `require "LastHomeServer"` at the top of the bootstrap file (already
present) so the reset handler is registered first.

## Goal

A new file `media/lua/server/LastHomeBootstrap.lua` that, on server
`OnGameStart`, performs house selection + sandbox injection for sandbox MP
servers, and stays dormant in solo Challenges mode.

## Changes

### 1. `LastHomeShared.getScenarioHouseId()` in `media/lua/shared/LastHomeShared.lua`

Reads and validates the house id from a config file. One source of truth.

```lua
function LastHomeShared.getScenarioHouseId()
    local validIds = { hospital = true, villa = true, prison = true,
                       elementary_school = true }
    local defaultId = "random"

    -- Resolve the PZ user-data dir, then Zomboid/Server/LastHomeHouse.cfg.
    -- Preferred: getCore():getMyDocumentFolder() (PZ B41) returns the user
    -- data root, e.g. "<user>/Zomboid". Build the absolute path:
    --   <myDocumentFolder> .. "/Server/LastHomeHouse.cfg"
    -- If that API is unavailable, fall back to a relative path
    -- "Zomboid/Server/LastHomeHouse.cfg" (works when the server CWD is the
    -- PZ user-data dir, which is the common dedicated-server case).
    local base = nil
    local core = getCore()
    if core ~= nil and core.getMyDocumentFolder ~= nil then
        base = core:getMyDocumentFolder()
    end
    local path = (base ~= nil and (base .. "/Server/LastHomeHouse.cfg")
                or "Zomboid/Server/LastHomeHouse.cfg")

    local f = io.open(path, "r")  -- io is available server-side in PZ B41
    if f ~= nil then
        for line in f:lines() do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed ~= nil and trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
                f:close()
                if trimmed == "random" then return defaultId end
                if validIds[trimmed] then return trimmed end
                print("[LastHome] LastHomeHouse.cfg valeur invalide: " .. tostring(trimmed) .. " -> random")
                return defaultId
            end
        end
        f:close()
    else
        print("[LastHome] LastHomeHouse.cfg introuvable (path=" .. tostring(path) .. ") -> random")
    end
    return defaultId
end
```

> Implementer note: `io.open` works in PZ server Lua. Resolve the path via
> `getCore():getMyDocumentFolder()` first (absolute, dedicated-server-safe),
> then fall back to the relative path. The `random` fallback is the contract if
> the file is absent, unreadable, or contains an invalid token. This path
> strategy is an **acceptance criterion**, not best-effort (see below).

### 2. `LastHomeShared.applyDefaultSandboxVars()` in `media/lua/shared/LastHomeShared.lua`

Move the body currently duplicated in the 4 challenge `setSandBoxVars()`
functions into one shared function.

```lua
function LastHomeShared.applyDefaultSandboxVars()
    if SandboxVars == nil then return end

    SandboxVars.Zombies = 6
    SandboxVars.Distribution = 1
    SandboxVars.MetaEvent = 1
    SandboxVars.SurvivorHouseChance = 1
    SandboxVars.ZoneStoryChance = 1
    SandboxVars.VehicleStoryChance = 1

    local zombieConfig = ZombieConfig or SandboxVars.ZombieConfig
    if zombieConfig ~= nil then
        zombieConfig.PopulationMultiplier = 0
        zombieConfig.PopulationStartMultiplier = 0
        zombieConfig.PopulationPeakMultiplier = 0
        zombieConfig.RespawnHours = 0
        zombieConfig.RespawnUnseenHours = 0
        zombieConfig.RespawnMultiplier = 0
        zombieConfig.RedistributeHours = 0
        zombieConfig.RallyGroupSize = 0
    end
end
```

The 4 challenge files should then call `LastHomeShared.applyDefaultSandboxVars()`
inside their `setSandBoxVars()` (optional cleanup in this ticket; keeps solo
behavior identical).

### 3. New file `media/lua/server/LastHomeBootstrap.lua`

```lua
require "LastHomeShared"
require "LastHomeServer"

print("[LastHome] LastHomeBootstrap charge")

local function isChallengeMode()
    local core = getCore()
    return core ~= nil and core.isChallenge ~= nil and core:isChallenge()
end

local function onGameStart()
    print("[LastHome] LastHomeBootstrap OnGameStart")
    -- Never compete with the challenge runtime (solo Challenges mode).
    if isChallengeMode() then
        print("[LastHome] Mode Challenge detecte -> bootstrap inactif")
        return
    end

    -- Best-effort sandbox injection (LH-13 cleanup compensates).
    LastHomeShared.applyDefaultSandboxVars()

    -- Select the house from config (random fallback).
    local houseId = LastHomeShared.getScenarioHouseId()
    print("[LastHome] Selection scenario house=" .. tostring(houseId))

    local resolvedId = houseId
    if houseId == "random" then
        local house = LastHomeShared.getRandomHouse()
        resolvedId = house and house.id or nil
    end
    if resolvedId == nil then
        print("[LastHome] WARN: aucune maison resolue (getRandomHouse a echoue)")
        return
    end

    LastHomeServer.setSelectedHouse(resolvedId, "scenario")
end

Events.OnGameStart.Add(onGameStart)
```

## Files impacted

- `media/lua/shared/LastHomeShared.lua`
  - Add `LastHomeShared.getScenarioHouseId()`.
  - Add `LastHomeShared.applyDefaultSandboxVars()`.
- `media/lua/server/LastHomeBootstrap.lua` **(new)**
  - `Events.OnGameStart` bootstrap calling the two functions above and
    `LastHomeServer.setSelectedHouse(resolvedId, "scenario")`.
- `media/lua/client/LastStand/LastHomeHospital.lua` (and Villa/Prison/School)
  - Optional: replace the inline `setSandBoxVars` body with a call to
    `LastHomeShared.applyDefaultSandboxVars()` (dedup; no behavior change).

## Acceptance criteria

1. On a sandbox MP server (`Map = Muldraugh, KY`, `Mods = LastHome`), the
   server `OnGameStart` selects a house without any client command.
2. With `Zomboid/Server/LastHomeHouse.cfg` containing `villa`, the server
   logs `Selection scenario house=villa` and `setSelectedHouse` resolves to
   the Villa (`source == "scenario"`).
3. With the file absent or containing an invalid token, the server falls
   back to `random` and selects one of the 4 houses, logging the resolved
   path and the fallback reason.
4. **Config path resolution is deterministic (not best-effort):**
   `getScenarioHouseId()` resolves the file via `getCore():getMyDocumentFolder()`
   first and falls back to the relative `Zomboid/Server/LastHomeHouse.cfg`;
   the resolved path is logged on every read attempt (success, missing, or
   invalid). A test placing the file at the absolute path is documented in
   LH-MP-4 and passes.
5. `LastHomeShared.applyDefaultSandboxVars()` sets `SandboxVars.Zombies = 6`
   and all `ZombieConfig` multipliers to 0 when called.
6. In solo Challenges mode, `isChallengeMode()` is true and the bootstrap
   returns early without calling `setSelectedHouse` (no double-selection,
   no regression). The log line `Mode Challenge detecte -> bootstrap inactif`
   confirms the early return.
7. The 4 challenge entries in the Challenges menu still launch and select
   the correct house.
8. The bootstrap's `OnGameStart` handler is registered after the existing
   `LastHomeServer.onGameStart` reset handler (verified by load order or by
   `require "LastHomeServer"` at the top of the bootstrap file), so the reset
   does not wipe the selected house.

## Pitfalls (for the implementer)

- `io.open` path must resolve to the PZ user data dir. If `Zomboid/Server/`
  is relative to the working dir, confirm against an existing PZ server
  install; otherwise use the PZ file API. Keep the `random` fallback robust.
- `getCore():isChallenge()` may be `isChallenge()` (method) or a field;
  guard with nil-checks as in the example.
- Do **not** call `setSelectedHouse` after waves have started (the guard
  inside LH-MP-1 handles it, but the bootstrap runs only at `OnGameStart`,
  so this is naturally safe).
- The bootstrap runs only once per server start (PZ `OnGameStart` semantics).

## Dependencies

- LH-MP-1 (`LastHomeServer.setSelectedHouse`).
- LH-04 (`getRandomHouse`, `getHouseById`).

## Size estimate

Small (S) — one new file + two shared helpers; no gameplay change.