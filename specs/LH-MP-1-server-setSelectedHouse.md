# LH-MP-1 (S) - Expose LastHomeServer.setSelectedHouse(houseId, source)

> Parent: `specs/LH-MP-multiplayer-sandbox-conversion.md`

## Context

Today the only way to set the Last Home house is the client command
`SetHouse`, received in `LastHomeServer.onClientCommand` and handled inline.
That handler does several things:

1. Validates `houseId` via `LastHomeShared.getHouseById`.
2. Guards against mid-game changes once waves have started.
3. Sets `Server.selectedHouse`, `house.source`, `Server.houseSelectionLocked`.
4. Calls `syncSelectedHouse()` and `refillHouseSuppliesIfNeeded()`.
5. Re-teleports already-roled players to the new house.

The new MP bootstrap (LH-MP-2) must perform the **same** actions but from a
server-side `OnGameStart` hook, without a client round-trip. To avoid
duplicating this logic, extract it into a reusable server function.

## Goal

A single server-side function `LastHomeServer.setSelectedHouse(houseId,
source)` performs all house-selection side effects. The existing `SetHouse`
client-command handler calls it. The new bootstrap (LH-MP-2) calls it too.

### Symmetry requirement

The function must behave **identically** for the `"challenge"` and
`"scenario"` paths. In particular, when called **before waves have started**
with one or more players already role-assigned, it MUST:

- reset `modData.LH_houseSpawnId = nil` for each roled player (so the next
  teleport is not skipped as a "same house" no-op),
- call `teleportPlayerToHouse(player)` for each roled player,
- emit a `warnTeleportFailure` log on failure (same context string as today).

This mirrors the current `SetHouse` challenge behavior exactly, so the
scenario path is not a thinner/symmetrical-broken variant. No caller should
need to re-teleport players manually after calling `setSelectedHouse`.

## Changes

### 1. New function in `media/lua/server/LastHomeServer.lua`

```lua
-- Reusable house selection. Returns true on success, false on rejection.
-- `source` is "challenge" (client command path) or "scenario" (MP bootstrap).
function LastHomeServer.setSelectedHouse(houseId, source)
    if houseId == nil then return false end

    local wavesStarted = LastHomeWaves ~= nil
        and LastHomeWaves.hasStarted ~= nil
        and LastHomeWaves.hasStarted() == true

    if wavesStarted then
        -- Once waves have started the house is frozen.
        if Server.selectedHouse ~= nil and Server.selectedHouse.id == houseId then
            return false -- no-op, same house
        end
        print("[LastHome] setSelectedHouse ignore: vagues demarrees")
        return false
    end

    -- Before waves start: the last selection wins (tolerates stale handlers).
    if Server.selectedHouse ~= nil
        and Server.selectedHouse.id == houseId
        and Server.selectedHouse.source == source then
        return false -- no-op, identical
    end

    local house = LastHomeShared.getHouseById(houseId)
    if house == nil then
        print("[LastHome] setSelectedHouse: houseId inconnu=" .. tostring(houseId))
        return false
    end

    local previousHouse = Server.selectedHouse
    house.source = source
    Server.selectedHouse = house
    Server.houseSelectionLocked = true
    Server.lastHouseSupplyRefillAt = nil
    syncSelectedHouse()
    refillHouseSuppliesIfNeeded()

    for _, scenarioPlayer in ipairs(getScenarioPlayers()) do
        local modData = scenarioPlayer:getModData()
        if modData ~= nil and modData.LH_role ~= nil then
            modData.LH_houseSpawnId = nil
            if not teleportPlayerToHouse(scenarioPlayer) then
                warnTeleportFailure(scenarioPlayer, "setSelectedHouse")
            end
        end
    end

    if previousHouse ~= nil and previousHouse.id ~= nil and previousHouse.id ~= house.id then
        print("[LastHome] Maison remplacee: "
            .. tostring(previousHouse.id) .. " -> " .. tostring(house.id))
    end
    print("[LastHome] Maison selectionnee (source=" .. tostring(source)
        .. "): " .. tostring(house.name or house.id))
    return true
end
```

### 2. Refactor the existing `SetHouse` handler

In `onClientCommand`, replace the inline body of the `command == "SetHouse"`
branch with:

```lua
if command == "SetHouse" then
    local houseId = data and data.houseId or nil
    logServer("Commande SetHouse recue de " .. tostring(username) .. " -> " .. tostring(houseId))
    if houseId == nil then return end
    LastHomeServer.setSelectedHouse(houseId, "challenge")
    return
end
```

Keep the existing log lines for the "ignored" cases inside
`setSelectedHouse` (or keep a thin debug log in the handler — implementer's
choice, but behavior must be identical to today for the challenge path).

## Files impacted

- `media/lua/server/LastHomeServer.lua`
  - Add `LastHomeServer.setSelectedHouse(houseId, source)`.
  - Slim the `SetHouse` branch of `onClientCommand` to delegate to it.

## Acceptance criteria

1. `LastHomeServer.setSelectedHouse(houseId, "challenge")` exists and is
   exported on the `LastHomeServer` table.
2. The solo Challenges path still selects the house identically (same logs,
   same lock, same teleport of roled players).
3. Calling `setSelectedHouse("villa", "scenario")` from server-side code
   (no client command) sets `Server.selectedHouse` with
   `source == "scenario"`, locks selection, syncs to waves, and refills
   supplies.
4. Calling `setSelectedHouse` after waves have started is a no-op and
   returns `false`.
5. Calling `setSelectedHouse` with an unknown `houseId` is a no-op and
   returns `false`.
6. **Re-teleport symmetry:** calling `setSelectedHouse` before waves start
   with >= 1 roled player resets that player's `LH_houseSpawnId` to `nil` and
   teleports them to the new house, for **both** `source = "challenge"` and
   `source = "scenario"`. This is verified for both paths, not only the
   challenge path.
7. No behavior change for any existing challenge (Hospital/Villa/Prison/
   School) when launched from the Challenges menu.

## Dependencies

- LH-04 (`getHouseById`, `syncSelectedHouse`, `refillHouseSuppliesIfNeeded`,
  `teleportPlayerToHouse`, `getScenarioPlayers`).
- Required by LH-MP-2 (the bootstrap calls this function).

## Size estimate

Small (S) — pure refactor extracting an existing inline handler into a
reusable function; no logic change.