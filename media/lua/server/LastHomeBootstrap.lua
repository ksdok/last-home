-- Last Home - LH-MP-2: server bootstrap for multiplayer sandbox hosting.
--
-- In solo Challenges mode, the challenge runtime calls setSandBoxVars() and
-- the challenge's client OnGameStart sends SetHouse. Neither runs on an MP
-- server. This bootstrap performs the equivalent from the server side so the
-- mod is launchable from the multiplayer Host menu
-- (Map = Muldraugh, KY + Mods = LastHome).
--
-- Event choice: OnServerStarted (NOT OnGameStart) -- VERIFIED in-game.
--   - Events.OnGameStart is a CLIENT-side "entered the game" event. It does
--     NOT fire on the MP server process (Host or dedicated). Confirmed by the
--     25-07-26 server log: LastHomeBootstrap.lua loads and prints
--     "LastHomeBootstrap charge", but the OnGameStart handler never runs
--     (no "LastHomeBootstrap OnGameStart" / "Selection scenario house=" /
--     "Maison selectionnee" lines; Server.house stays nil).
--   - Events.OnServerStarted fires on the MP server once it has finished
--     starting up, before players connect -- the correct hook for server-side
--     house selection.
--   - The former OnGameStart ordering concern (LastHomeServer.onGameStart
--     resetting Server.selectedHouse) is moot in MP: that reset is registered
--     on OnGameStart, which does not fire on the MP server, so there is no
--     wipe. The Server table starts clean on a fresh server process.
--   - Solo Challenges mode is unaffected: isChallenge() guard returns true
--     and the bootstrap is dormant; the challenge runtime + client SetHouse
--     drive house selection as before.

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

Events.OnServerStarted.Add(runBootstrap)