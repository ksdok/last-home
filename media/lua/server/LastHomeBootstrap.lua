-- Last Home - LH-MP-6: server bootstrap for multiplayer sandbox hosting.
--
-- The scenario house is hardcoded via LastHomeShared.SCENARIO_HOUSE (no cfg
-- file -- the file-I/O was never reliable in the SERVER VM, so the cfg was
-- silently ignored since LH-MP-2). This bootstrap applies the sandbox vars and
-- selects the house from the server side so the mod is launchable from the
-- multiplayer Host menu (Map = Muldraugh, KY + Mods = LastHome) and in solo
-- sandbox.
--
-- ============================================================
-- CRITICAL: two Lua VMs in Host mode (verified in-game 27-07-26)
-- ============================================================
-- In MP Host (and dedicated) mode, Project Zomboid runs TWO separate Lua VMs
-- in the same process:
--   - the CLIENT VM (logs to Console.txt / client DebugLog.txt)
--   - the SERVER VM (logs to DebugLog-server.txt)
-- `media/lua/server/` files load in BOTH VMs, but the events they receive
-- differ per VM:
--   - Events.OnGameStart        -> CLIENT VM only (does NOT fire in server VM)
--   - Events.OnServerStarted    -> SERVER VM only
--   - Events.OnClientCommand     -> SERVER VM only  (authoritative game state)
--   - Events.OnTick (server)     -> SERVER VM
-- The authoritative LastHomeServer.Server.* state lives in the SERVER VM.
--
-- A previous revision registered this bootstrap on OnGameStart, claiming
-- "OnGameStart fires on the MP Host integrated server". That was a
-- misdiagnosis: OnGameStart fires in the CLIENT VM, where it set
-- Server.selectedHouse / applyDefaultSandboxVars -- all in the CLIENT VM's
-- copy, which the SERVER VM's OnClientCommand never reads. Result
-- (27-07-26 session): the server fell back to a random house
-- (ensureSelectedHouse rotation) and SandboxVars.Zombies was never suppressed
-- server-side -> vanilla zombies at the initial MP spawn before
-- role/teleport.
--
-- Fix: register on Events.OnServerStarted (fires in the SERVER VM, verified
-- in-game on 25-07-26: "LastHomeBootstrap OnServerStarted" -> "Selection
-- scenario house=..." -> "Maison selectionnee (source=scenario)" all in
-- DebugLog-server.txt). We ALSO keep Events.OnGameStart as a fallback for SOLO
-- sandbox (no server VM exists in solo, so OnServerStarted does not fire and
-- OnGameStart in the single VM is authoritative). The OnGameStart path is
-- gated by isClient() so the Host client VM does NOT run a divergent bootstrap.
--
-- Ordering: `require "LastHomeServer"` (below) loads LastHomeServer.lua first,
-- which registers its reset handler on OnServerStarted (and OnGameStart). This
-- file then registers its bootstrap handler on the same events. PZ fires
-- same-event handlers in registration order, so in each VM: reset -> bootstrap
-- -> no wipe of the bootstrap's selection.

require "LastHomeShared"
require "LastHomeServer"

print("[LastHome] LastHomeBootstrap charge")

local function isChallengeMode()
    local core = getCore()
    -- Defensive: the mod is MP-only now, but if some other challenge is running
    -- while the mod is loaded, do not compete with it.
    return core ~= nil and core.isChallenge ~= nil and core:isChallenge()
end

-- True in the MP client VM (connected to a server, including the Host's own
-- integrated client). False in solo and on the server VM. Used to restrict the
-- OnGameStart fallback to solo only, so the Host client VM does NOT run a
-- divergent bootstrap (the authoritative bootstrap runs in the server VM via
-- OnServerStarted).
local function isClientVM()
    return isClient ~= nil and isClient() == true
end

local function runBootstrap(eventName)
    -- Idempotency guard based on authoritative server state (cleared by
    -- LastHomeServer.resetState, so a re-host in the same process re-bootstraps).
    if LastHomeServer.hasSelectedHouse() then
        print("[LastHome] LastHomeBootstrap " .. tostring(eventName) .. " ignore (maison deja selectionnee)")
        return
    end

    print("[LastHome] LastHomeBootstrap " .. tostring(eventName))

    if isChallengeMode() then
        print("[LastHome] Mode Challenge detecte -> bootstrap inactif")
        return
    end

    -- Best-effort sandbox injection (LH-13 periodic cleanup compensates).
    -- Must run in the SERVER VM so it affects server-side zombie spawning.
    LastHomeShared.applyDefaultSandboxVars()

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

local function onServerStarted()
    -- SERVER VM (authoritative) and dedicated server.
    runBootstrap("OnServerStarted")
end

local function onGameStart()
    -- Solo-sandbox fallback ONLY. In Host/MP the client VM also receives
    -- OnGameStart, but the authoritative bootstrap already ran (or will run) in
    -- the server VM via OnServerStarted; skip the client VM to avoid a
    -- divergent local state.
    if isClientVM() then
        return
    end
    runBootstrap("OnGameStart")
end

Events.OnServerStarted.Add(onServerStarted)
Events.OnGameStart.Add(onGameStart)