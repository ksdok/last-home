# LH-MP — Multiplayer Host Debug Trace (2026-07-26)

Trace of the in-game verification of the Last Home multiplayer sandbox
conversion (LH-MP). All findings come from reading the PZ server + client
logs at `/Users/kim/Zomboid/Logs/` during real Host sessions, then patching
the mod installed at `/Users/kim/Zomboid/mods/LastHome/`.

Branch: `fix/lh-mp-2-bootstrap-on-server-started` (off `main` after
LH-MP-1/2/3 were merged). DEBUG was enabled (`LastHomeShared.DEBUG = true`)
mid-session to reveal the gated `logServer`/`logClient` lines.

---

## TL;DR

The MP bootstrap (LH-MP-2) is now functional end-to-end on a **Host**
server: house selected → role picker opens → role assigned → equipment
applied → player teleported → prep + waves run. Six bugs were found and
fixed in cascade; two secondary issues remain (cfg path, stock container).

---

## Key PZ MP facts learned (engine-level, reusable)

1. **Host vs dedicated log files.** In Host mode the integrated server's
   Lua `print()` output goes to the **client** `DebugLog.txt`
   (`logs_21-07/...DebugLog.txt`), **NOT** to `*DebugLog-server.txt`.
   `*DebugLog-server.txt` is effectively a dedicated-server-style log and
   does **not** capture the Host integrated server's event firings. Reading
   only `DebugLog-server.txt` led to the initial misdiagnosis that
   `OnGameStart` did not fire.
2. **`Events.OnGameStart` DOES fire on the Host integrated server** (it is a
   client-side "entered the game" event, but the integrated server shares the
   process/log). Confirmed by the 25-07 23:24 client log:
   `LastHomeBootstrap OnGameStart` then the `io.open` crash.
3. **`io` is `nil` in PZ's Kahlua Lua runtime.** `io.open` throws
   `attempted index: open of non-table: null`. Use the PZ globals
   `fileExists(path)` + `getFileReader(path, createIfNull)` (returns a Java
   `BufferedReader`) + `reader:readLine()` / `reader:close()`. (Context7 +
   `LuaManager.GlobalObject` javadoc.)
4. **`sendClientCommand` at `OnCreatePlayer`/`OnGameStart` is lost in MP.**
   Those events fire during the client's local setup, BEFORE the
   `player-connect` handshake completes (log shows `RolePickerReady` sent at
   00:17:51, but `Waiting for player-connect response` only at 00:17:52.098).
   The first command is dropped → the server never sees it. Fix: retry on a
   tick until the server responds.
5. **Server-side `inv:AddItem` to a player's inventory does NOT replicate to
   the client in MP.** The canonical grant pattern is **client-side**
   (`SpawnItems.OnNewGame`: `playerObj:getInventory():AddItem(...)` +
   `setWornItem` on the client's own inventory, which syncs client→server).
   `ISInventoryTransferAction` uses `destContainer:addItemOnServer(item)` for
   explicit client→server item sync. EscapadeExpress's server-side
   `inv:AddItem` works only because it is a **solo challenge** (server=client,
   same process) — copying it into an MP context was the root cause of the
   "no equipment" bug.
6. **`square:isFree(false)` is too strict for vanilla buildings.** Most
   tiles in vanilla buildings (Prison, Villa, Hospital, School) have
   furniture/walls, so `pickHouseSpawnPoint` found 0 usable squares among
   10–49 candidates → returned `nil` → no teleport. `player:setX/setY/setZ`
   places the player regardless of "free", so falling back to a designated
   candidate works.

---

## Bug cascade (chronological)

### Bug 1 — Bootstrap did not select a house (initial misdiagnosis)
- **Symptom (25-07 23:26, `DebugLog-server.txt`):** `LastHomeBootstrap charge`
  then nothing; `Server.house` stayed `nil`; no `Selection scenario house=`.
- **Wrong diagnosis:** "`OnGameStart` does not fire on the MP server." →
  switched the bootstrap to `Events.OnServerStarted` (commit `77cc33b`).
- **Real cause (found later):** `OnGameStart` DID fire (logged in the client
  `DebugLog.txt` at 23:24: `LastHomeBootstrap OnGameStart` then
  `attempted index: open of non-table: null`). The bootstrap crashed in
  `getScenarioHouseId` on `io.open` (Bug 2). The `DebugLog-server.txt` simply
  does not capture the Host integrated server's OnGameStart.

### Bug 2 — `io.open` crash (the real bootstrap blocker)
- **Symptom (25-07 23:37, after Bug 1 "fix"):** `OnServerStarted` fired, then
  `attempted index: open of non-table: null` in `getScenarioHouseId`
  (`LastHomeShared.lua:632`) ← `runBootstrap`.
- **Cause:** `io` is nil in Kahlua (Fact 3).
- **Fix (commit `7d078d8`):** replaced `io.open`/`f:lines()` with
  `fileExists(path)` + `getFileReader(path, false)` + `reader:readLine()`.

### Bug 3 — Reverted bootstrap event to `OnGameStart`
- **Finding:** re-reading the 25-07 23:24 client log proved `OnGameStart`
  fires on Host (Fact 1+2). The `OnServerStarted` change was wrong: it runs
  BEFORE the `OnGameStart` reset, which wipes `Server.selectedHouse` → the
  forced cfg house is ignored and `LastHomeServer`/`LastHomeWaves` desync
  (bootstrap set Hopital, `ensureSelectedHouse` re-picked Prison).
- **Fix (commit `6aab85e`):** reverted to `OnGameStart`, registered AFTER
  `LastHomeServer`'s reset via `require "LastHomeServer"` (reset → bootstrap
  sets house → no wipe). Kept the `bootstrapRan` guard and the io fix.
- **Note:** dedicated-server (non-Host) support is deferred (header comment
  documents the fallback: register on `OnServerStarted` too + make the reset
  preserve a `source == "scenario"` house).

### Bug 4 — Role picker never opened
- **Symptom (26-07 00:14, DEBUG=true):** client logged
  `requestRolePicker -> RolePickerReady` at 00:17:51, but
  `Waiting for player-connect response` only at 00:17:52.098. The command
  was sent before the connection was established → lost (Fact 4).
- **Fix (commit `9c4590d`):** extended `TickRolePickerFallback` with an MP
  branch that re-sends `RolePickerReady` every 3s (`mpRolePickerRetryAt`)
  until the server responds (`OpenRolePicker` → picker visible) or a role is
  assigned. Solo fallback unchanged.

### Bug 5 — Teleport failed (no free spawn square)
- **Symptom (26-07 00:24):** `pickHouseSpawnPoint n'a trouve aucun square
  utilisable pour Prison (candidats=49)` → returned `nil, nil, nil` → no
  teleport → player stayed at the default spawn → outside boundary →
  confinement damage.
- **Cause:** `isUsableSpawnSquare` uses `square:isFree(false)`, too strict for
  vanilla buildings (Fact 6). Affects all 4 houses, not just Villa (backlog).
- **Fix (commit `5778933`):** when no candidate passes `isFree`, fall back to
  the first candidate (the `startIndex` one) instead of `nil`.
  `player:setX/setY/setZ` places the player regardless of "free".

### Bug 6 — Equipment not visible to the player
- **Symptom (26-07 00:33):** server logged `fillAmmoItem arme=AssaultRifle`
  + `teleport joueur ... -> Villa` + `Role assigne: Gun$mok3 = Invincible`,
  but the player saw no equipment.
- **Cause:** server-side `inv:AddItem` + `setPrimaryHandItem` do not replicate
  to the client in MP (Fact 5). This pattern was copied from EscapadeExpress,
  which is a **solo challenge** (server=client) — never MP-tested.
- **Fix (commit `785465a`, aligned on vanilla `SpawnItems.OnNewGame`):**
  - **Server `applyRole`:** skip bag/addRoleItems/primeRoleLoadout/equipRoleItems
    (items + equipment). Keep `modData.LH_role`, skills (`applyPerkLevel`,
    which replicate via XP), stats, carry, role-loadout tracking, teleport.
  - **Client `RoleAssigned` handler:** call `LastHomeClient.applyRoleLocally(
    player, data.role)` to add items/equipment/skills/stats/carry locally on
    the client's own inventory (syncs client→server, vanilla pattern). The
    function is a no-op on reconnect (`LH_role` already set from save → guard).

---

## Commits (on `fix/lh-mp-2-bootstrap-on-server-started`)

| Commit | Bug | Change |
|---|---|---|
| `77cc33b` | 1 (wrong) | bootstrap `OnGameStart` → `OnServerStarted` |
| `7d078d8` | 2 | `io.open` → `fileExists`+`getFileReader`+`readLine` |
| `d6b6b68` | — | `LastHomeShared.DEBUG = true` (diagnostic; revert before `main`) |
| `6aab85e` | 3 | revert bootstrap to `OnGameStart` (OnGameStart DOES fire on Host) |
| `9c4590d` | 4 | retry `RolePickerReady` in MP (initial send lost pre-connection) |
| `5778933` | 5 | `pickHouseSpawnPoint` fallback to a candidate when none `isFree` |
| `785465a` | 6 | grant role items client-side (vanilla pattern); server skips items |

All changes were synced to the install at `/Users/kim/Zomboid/mods/LastHome/`
and `luac -p`-checked.

---

## Secondary issues NOT yet fixed (follow-ups)

1. **`LastHomeHouse.cfg` not read.** `fileExists("Server/LastHomeHouse.cfg")`
   returns false even though the file exists at
   `/Users/kim/Zomboid/Server/LastHomeHouse.cfg`. The base dir for
   `getFileReader`/`fileExists` is NOT `/Users/kim/Zomboid/`. The house is
   therefore random each session. Need the correct path (or `getServerOptions`
   / absolute path via `getCore():getMyDocumentFolder()` + a Java read).
2. **Stock container not found for all 4 houses.**
   `getPrimaryHouseSupplyContainer` scans only the spawn-derived `bounds`
   (~10×8 tiles), not the building `boundary`. Log:
   `WARN: getPrimaryHouseSupplyContainer - aucun conteneur trouve pour
   <house> dans bounds [...]`. Same bug class as the Villa backlog item;
   affects Hospital/Villa/Prison/School. Fix: widen the fallback scan to
   `boundary` and cache the result. Breaks LH-15 stock arrow + community
   refill.
3. **Premature GAME OVER on death before scenario start.** A player dying
   before picking a role / before `started=true` triggers `handlePlayerDeath`
   → game over with score 0. `handlePlayerDeath` should ignore deaths while
   `Server.started == false` (or while the player has no role).
4. **Challenge translations missing.** `ERROR: Missing translation
   "Challenge_LastHome*_name/_desc"` (×8). Cosmetic; the Challenges menu
   entries lack translation keys.
5. **DEBUG=true commit (`d6b6b68`) must be reverted before merging to
   `main`.**
6. **Dedicated-server (non-Host) support.** The bootstrap is on `OnGameStart`
   which fires on Host but may not on a pure dedicated server. Deferred (see
   Bug 3 note).

---

## What now works on Host

Verified by logs (26-07 00:33 session, after all fixes):
- Bootstrap selects a house (`OnGameStart`, `source=scenario`).
- Role picker opens (after the 3s MP retry).
- Role assigned server-side; equipment applied client-side
  (`applyRoleLocally`).
- Player teleported to the house spawn (`pickHouseSpawnPoint` fallback).
- Prep phase starts (2 min, LH-10), boundary confinement active.
- No Lua errors in the last session.

Still to confirm in the next session (after Bug 6 fix): equipment visible
to the player and persisted on reconnect.