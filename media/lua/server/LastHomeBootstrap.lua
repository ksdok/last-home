-- Last Home - LH-MP-2: server bootstrap for multiplayer sandbox hosting.
--
-- In solo Challenges mode, the challenge runtime calls setSandBoxVars() and
-- the challenge's client OnGameStart sends SetHouse. Neither runs in a
-- multiplayer sandbox server. This bootstrap performs the equivalent from
-- the server side, at OnGameStart, so the mod is launchable from the
-- multiplayer Host menu (Map = Muldraugh, KY + Mods = LastHome).
--
-- Event choice: OnGameStart (NOT OnServerStarted).
--   - The existing LastHomeServer.onGameStart resets Server.selectedHouse = nil
--     on OnGameStart.
--   - OnServerStarted fires BEFORE OnGameStart, so a bootstrap on
--     OnServerStarted would have its selected house wiped by the reset.
--   - `require "LastHomeServer"` (below) executes LastHomeServer.lua
--     top-to-bottom and registers its reset handler BEFORE this file
--     registers its own OnGameStart handler, guaranteeing: reset -> bootstrap
--     sets house -> no wipe.
--   - Fallback (validated in LH-MP-4): if OnGameStart does not fire on a
--     dedicated server, move BOTH the reset and this bootstrap to
--     OnServerStarted (reset before bootstrap).

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