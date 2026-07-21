-- Last Home - Challenge: Hopital
-- Defendez l'hopital contre des vagues croissantes de zombies.

LastHomeHospital = {}

LastHomeHospital.Add = function()
    addChallenge(LastHomeHospital)
end

LastHomeHospital.OnGameStart = function()
    sendClientCommand("LastHome", "SetHouse", { houseId = "hospital" })
end

LastHomeHospital.OnInitWorld = function()
    if not LastHomeHospital._registered then
        Events.OnGameStart.Add(LastHomeHospital.OnGameStart)
        LastHomeHospital._registered = true
    end
end

LastHomeHospital.setSandBoxVars = function() end
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