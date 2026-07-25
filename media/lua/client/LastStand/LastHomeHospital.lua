-- Last Home - Challenge: Hopital
-- Defendez l'hopital contre des vagues croissantes de zombies.

LastHomeHospital = {}
LastHomeHospital._gameStartRegistered = LastHomeHospital._gameStartRegistered or false
LastHomeHospital._houseSelectionSent = false

LastHomeHospital.Add = function()
    addChallenge(LastHomeHospital)
end

LastHomeHospital.SendHouseSelection = function()
    if LastHomeHospital._houseSelectionSent then return end

    -- Guard against OnGameStart handlers leaking from a previously-played
    -- challenge (PZ doesn't reset Events.OnGameStart between launches in the
    -- same process): only send SetHouse if this challenge is the active one.
    local currentChallengeId = getCore() ~= nil and getCore().getChallengeID ~= nil and getCore():getChallengeID() or nil
    if currentChallengeId ~= nil and currentChallengeId ~= LastHomeHospital.id then return end

    LastHomeHospital._houseSelectionSent = true
    sendClientCommand("LastHome", "SetHouse", { houseId = "hospital" })
end

LastHomeHospital.OnGameStart = function()
    LastHomeHospital.SendHouseSelection()
end

LastHomeHospital.OnInitWorld = function()
    LastHomeHospital._houseSelectionSent = false

    if not LastHomeHospital._gameStartRegistered then
        Events.OnGameStart.Add(LastHomeHospital.OnGameStart)
        LastHomeHospital._gameStartRegistered = true
    end
end

LastHomeHospital.setSandBoxVars = function()
    LastHomeShared.applyDefaultSandboxVars()
end
LastHomeHospital.RemovePlayer = function(p) end
LastHomeHospital.AddPlayer = function(p) end
LastHomeHospital.Render = function() end

LastHomeHospital.id = "LastHomeHospital"
LastHomeHospital.image = "media/lua/client/LastStand/LastHomeHospital.png"
LastHomeHospital.gameMode = "Last Home: Hopital"
LastHomeHospital.world = "Muldraugh, KY"
LastHomeHospital.xcell = 41
LastHomeHospital.ycell = 12
LastHomeHospital.x = 80
LastHomeHospital.y = 82
LastHomeHospital.z = 0
LastHomeHospital.enableSandbox = true

Events.OnChallengeQuery.Add(LastHomeHospital.Add)