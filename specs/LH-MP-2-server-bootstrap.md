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

### Bootstrap event decision: `OnServerStarted` (not `OnGameStart`) — VERIFIED in-game

The bootstrap hooks `Events.OnServerStarted`, **not** `Events.OnGameStart`.

**Verified on 25-07-26 (MP Host server):** `Events.OnGameStart` is a
**client-side** "entered the game" event. It does **not** fire on the MP
server process (Host or dedicated). The server log
(`25-07-26_23-26-48_DebugLog-server.txt`) shows `LastHomeBootstrap.lua`
loads and prints `LastHomeBootstrap charge`, but the `OnGameStart` handler
never runs — no `LastHomeBootstrap OnGameStart` / `Selection scenario
house=` / `Maison selectionnee` lines, and `Server.house` stays `nil`
(`[LastHome][Boundary] ... house=house=nil`). Meanwhile `Events.OnTick`
fires correctly on the server.

`Events.OnServerStarted` fires on the MP server once it has finished
starting up (before players connect) — the correct hook for server-side
house selection.

The former `OnGameStart` ordering concern (the `LastHomeServer.onGameStart`
reset wiping `Server.selectedHouse`) is **moot in MP**: that reset is
registered on `OnGameStart`, which does not fire on the MP server, so there
is no wipe. The `Server` table starts clean on a fresh server process.

Solo Challenges mode is unaffected: `isChallenge()` guard returns true and
the bootstrap is dormant; the challenge runtime + client `SetHouse` drive
house selection as before.

A `bootstrapRan` one-shot guard protects against double execution if the
event were to fire more than once.

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

    -- PZ's getFileReader / fileExists resolve relative to the user Zomboid
    -- data folder, so "Server/LastHomeHouse.cfg" maps to
    -- <userDir>/Server/LastHomeHouse.cfg. Do NOT use `io` (nil in Kahlua).
    local relPath = "Server/LastHomeHouse.cfg"

    if fileExists == nil or not fileExists(relPath) then
        print("[LastHome] LastHomeHouse.cfg introuvable (path=" .. tostring(relPath) .. ") -> random")
        return defaultId
    end

    local reader = getFileReader(relPath, false)
    if reader == nil then
        print("[LastHome] LastHomeHouse.cfg non lisible (path=" .. tostring(relPath) .. ") -> random")
        return defaultId
    end

    local result = defaultId
    local found = false
    local line = reader:readLine()
    while line ~= nil do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= nil and trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
            if trimmed == "random" then
                result = defaultId
            elseif validIds[trimmed] then
                result = trimmed
            else
                print("[LastHome] LastHomeHouse.cfg valeur invalide: " .. tostring(trimmed) .. " -> random")
                result = defaultId
            end
            found = true
            break
        end
        line = reader:readLine()
    end
    reader:close()

    if not found then
        print("[LastHome] LastHomeHouse.cfg vide (path=" .. tostring(relPath) .. ") -> random")
    end
    return result
end
```

> Implementer note: PZ's Kahlua Lua runtime has **no `io` library** (`io` is
> nil -> `io.open` throws "attempted index: open of non-table: null",
> confirmed in-game 25-07-26). Use the PZ-native globals `fileExists(path)` and
> `getFileReader(path, createIfNull)` (returns a Java `BufferedReader`), then
> `reader:readLine()` / `reader:close()`. These resolve `path` **relative to the
> user Zomboid data folder**, so `"Server/LastHomeHouse.cfg"` maps to
> `<userDir>/Server/LastHomeHouse.cfg` (the same dir as `LastHome.ini`). The
> `random` fallback is the contract if the file is absent, unreadable, or
> contains an invalid token. This path strategy is an **acceptance
> criterion**, not best-effort (see below).

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

local bootstrapRan = false

local function isChallengeMode()
    local core = getCore()
    return core ~= nil and core.isChallenge ~= nil and core:isChallenge()
end

local function runBootstrap()
    if bootstrapRan then return end
    bootstrapRan = true

    print("[LastHome] LastHomeBootstrap OnServerStarted")
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

Events.OnServerStarted.Add(runBootstrap)
```

> Note: the bootstrap uses `OnServerStarted` (not `OnGameStart`) because
> `OnGameStart` is a client-side event that does not fire on the MP server
> process — verified in-game on 25-07-26. See the "Bootstrap event decision"
> section above.

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
   `getScenarioHouseId()` uses PZ-native `fileExists` + `getFileReader` (NOT
   `io`, which is nil in Kahlua) with the relative path `Server/LastHomeHouse.cfg`,
   which resolves to `<userDir>/Server/LastHomeHouse.cfg`; the resolved path is
   logged on every read attempt (missing, unreadable, or invalid). A test
   placing the file at that path is documented in LH-MP-4 and passes.
5. `LastHomeShared.applyDefaultSandboxVars()` sets `SandboxVars.Zombies = 6`
   and all `ZombieConfig` multipliers to 0 when called.
6. In solo Challenges mode, `isChallengeMode()` is true and the bootstrap
   returns early without calling `setSelectedHouse` (no double-selection,
   no regression). The log line `Mode Challenge detecte -> bootstrap inactif`
   confirms the early return.
7. The 4 challenge entries in the Challenges menu still launch and select
   the correct house.
8. The bootstrap hooks `Events.OnServerStarted` (verified: `OnGameStart` does
   not fire on the MP server process). A `bootstrapRan` guard prevents double
   execution. The `LastHomeServer` reset on `OnGameStart` is moot in MP (it
   does not fire on the server) and does not wipe the selected house.

## Pitfalls (for the implementer)

- **Do NOT use `io`** -- it is nil in PZ's Kahlua Lua; `io.open` throws
  `attempted index: open of non-table: null` (confirmed in-game 25-07-26).
  Use PZ's `fileExists(path)` + `getFileReader(path, false)` + `reader:readLine()`.
  The path is relative to the user Zomboid data folder, so
  `"Server/LastHomeHouse.cfg"` maps to `<userDir>/Server/LastHomeHouse.cfg`.
  Keep the `random` fallback robust.
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