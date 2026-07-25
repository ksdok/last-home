-- Last Home - Challenge: Prison
-- Defendez la prison contre des vagues croissantes de zombies.

LastHomePrison = {}
LastHomePrison._gameStartRegistered = LastHomePrison._gameStartRegistered or false
LastHomePrison._houseSelectionSent = false

LastHomePrison.Add = function()
    addChallenge(LastHomePrison)
end

LastHomePrison.SendHouseSelection = function()
    if LastHomePrison._houseSelectionSent then return end

    -- Guard against OnGameStart handlers leaking from a previously-played
    -- challenge (PZ doesn't reset Events.OnGameStart between launches in the
    -- same process): only send SetHouse if this challenge is the active one.
    local currentChallengeId = getCore() ~= nil and getCore().getChallengeID ~= nil and getCore():getChallengeID() or nil
    if currentChallengeId ~= nil and currentChallengeId ~= LastHomePrison.id then return end

    LastHomePrison._houseSelectionSent = true
    sendClientCommand("LastHome", "SetHouse", { houseId = "prison" })
end

LastHomePrison.OnGameStart = function()
    LastHomePrison.SendHouseSelection()
end

LastHomePrison.OnInitWorld = function()
    LastHomePrison._houseSelectionSent = false

    if not LastHomePrison._gameStartRegistered then
        Events.OnGameStart.Add(LastHomePrison.OnGameStart)
        LastHomePrison._gameStartRegistered = true
    end
end

LastHomePrison.setSandBoxVars = function()
    LastHomeShared.applyDefaultSandboxVars()
end
LastHomePrison.RemovePlayer = function(p) end
LastHomePrison.AddPlayer = function(p) end
LastHomePrison.Render = function() end

LastHomePrison.id = "LastHomePrison"
LastHomePrison.image = "media/lua/client/LastStand/LastHomePrison.png"
LastHomePrison.gameMode = "Last Home: Prison"
LastHomePrison.world = "Muldraugh, KY"
LastHomePrison.xcell = 25
LastHomePrison.ycell = 39
LastHomePrison.x = 183
LastHomePrison.y = 163
LastHomePrison.z = 0
LastHomePrison.enableSandbox = true

Events.OnChallengeQuery.Add(LastHomePrison.Add)