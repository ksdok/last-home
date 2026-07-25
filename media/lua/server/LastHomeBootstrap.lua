-- Last Home - LH-MP-2: server bootstrap for multiplayer sandbox hosting.
--
-- In solo Challenges mode, the challenge runtime calls setSandBoxVars() and
-- the challenge's client OnGameStart sends SetHouse. Neither runs on an MP
-- server. This bootstrap performs the equivalent from the server side so the
-- mod is launchable from the multiplayer Host menu
-- (Map = Muldraugh, KY + Mods = LastHome).
--
-- Event choice: OnGameStart -- VERIFIED in-game (Host).
--   - OnGameStart fires on the MP Host integrated server (confirmed by the
--     25-07-26 23:24 client DebugLog: "LastHomeBootstrap OnGameStart" then the
--     io.open crash). It logs to the client DebugLog.txt, NOT to
--     DebugLog-server.txt -- which is why an earlier read of the server log
--     wrongly suggested it did not fire.
--   - `require "LastHomeServer"` (below) executes LastHomeServer.lua
--     top-to-bottom and registers its reset handler (which wipes
--     Server.selectedHouse) BEFORE this file registers its own OnGameStart
--     handler, guaranteeing: reset -> bootstrap sets house -> no further wipe.
--   - A `bootstrapRan` guard protects against double execution.
--   - Solo Challenges mode: isChallenge() guard -> dormant; the challenge
--     runtime + client SetHouse drive house selection as before.
--   - NOTE for dedicated servers (not Host): OnGameStart may NOT fire on a
--     pure dedicated server process. If that case must be supported, register
--     on OnServerStarted too (with the guard) and make the LastHomeServer
--     reset preserve a house already selected with source == "scenario".
--     Out of scope for the current Host-focused fix.

require "LastHomeShared"
require "LastHomeServer"

print("[LastHome] LastHomeBootstrap charge")

local bootstrapRan = false

local function isChallengeMode()
    local core = getCore()
    return core ~= nil and core.isChallenge ~= nil and core:isChallenge()
end

local function onGameStart()
    if bootstrapRan then return end
    bootstrapRan = true

    print("[LastHome] LastHomeBootstrap OnGameStart")

    -- Never compete with the challenge runtime (solo Challenges mode).
    if isChallengeMode() then
        print("[LastHome] Mode Challenge detecte -> bootstrap inactif")
        return
    end

    -- Best-effort sandbox injection (LH-13 periodic cleanup compensates).
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