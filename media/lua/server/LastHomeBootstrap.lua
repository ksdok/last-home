-- Last Home - LH-MP-2 / LH-MP-5: server bootstrap for multiplayer sandbox
-- hosting.
--
-- In solo Challenges mode, the challenge runtime calls setSandBoxVars() and
-- the challenge's client OnGameStart sends SetHouse. Neither runs on an MP
-- server. This bootstrap performs the equivalent from the server side so the
-- mod is launchable from the multiplayer Host menu
-- (Map = Muldraugh, KY + Mods = LastHome).
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
-- A previous revision (commit 6aab85e) registered this bootstrap on
-- OnGameStart, claiming "OnGameStart fires on the MP Host integrated server".
-- That was a misdiagnosis: OnGameStart fires in the CLIENT VM, where it set
-- Server.selectedHouse / applyDefaultSandboxVars / enterHousePickerMode -- all
-- in the CLIENT VM's copy, which the SERVER VM's OnClientCommand never reads.
-- Result (27-07-26 session): the server fell back to a random house
-- (ensureSelectedHouse rotation), the house picker never opened, and
-- SandboxVars.Zombies was never suppressed server-side -> vanilla zombies at
-- the initial MP spawn before role/teleport.
--
-- Fix: register on Events.OnServerStarted (fires in the SERVER VM, verified
-- in-game on 25-07-26: "LastHomeBootstrap OnServerStarted" -> "Selection
-- scenario house=..." -> "Maison selectionnee (source=scenario)" all in
-- DebugLog-server.txt). We ALSO keep Events.OnGameStart as a fallback for SOLO
-- sandbox (no server VM exists in solo, so OnServerStarted does not fire and
-- OnGameStart in the single VM is authoritative). A per-VM `bootstrapRan`
-- guard prevents double execution within a VM.
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
    -- Within a single launch only one of OnServerStarted/OnGameStart fires in a
    -- given VM, so this does not mask a needed run; it only skips a redundant
    -- re-run if the event were to fire twice.
    if LastHomeServer.hasSelectedHouse() or LastHomeServer.isHousePickerMode() then
        print("[LastHome] LastHomeBootstrap " .. tostring(eventName) .. " ignore (maison deja selectionnee / picker deja actif)")
        return
    end

    print("[LastHome] LastHomeBootstrap " .. tostring(eventName))

    -- Never compete with the challenge runtime (solo Challenges mode).
    if isChallengeMode() then
        print("[LastHome] Mode Challenge detecte -> bootstrap inactif")
        return
    end

    -- Best-effort sandbox injection (LH-13 periodic cleanup compensates).
    -- Must run in the SERVER VM so it affects server-side zombie spawning.
    LastHomeShared.applyDefaultSandboxVars()

    -- Select the house from config (random fallback).
    local houseId = LastHomeShared.getScenarioHouseId()
    print("[LastHome] Selection scenario house=" .. tostring(houseId))

    -- LH-MP-5: `picker` defers house selection to an interactive in-game
    -- choice. Only meaningful on an MP server (Host/dedicated); in solo the
    -- house picker UI has no server command transport, so fall back to random.
    if houseId == "picker" then
        if GameServer ~= nil then
            LastHomeServer.enterHousePickerMode()
            return
        end
        print("[LastHome] picker cfg ignore en solo -> random")
        houseId = "random"
    end

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
    -- the server VM via OnServerStarted; skip the client VM here to avoid a
    -- divergent local state and misleading logs (e.g. the picker branch's
    -- "GameServer == nil -> random" would otherwise fire in the client VM).
    if isClientVM() then
        return
    end
    runBootstrap("OnGameStart")
end

Events.OnServerStarted.Add(onServerStarted)
Events.OnGameStart.Add(onGameStart)