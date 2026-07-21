-- Last Home - Challenge: Ecole elementaire
-- Defendez l'ecole elementaire contre des vagues croissantes de zombies.

LastHomeSchool = {}

LastHomeSchool.Add = function()
    addChallenge(LastHomeSchool)
end

LastHomeSchool.OnGameStart = function()
    sendClientCommand("LastHome", "SetHouse", { houseId = "elementary_school" })
end

LastHomeSchool.OnInitWorld = function()
    if not LastHomeSchool._registered then
        Events.OnGameStart.Add(LastHomeSchool.OnGameStart)
        LastHomeSchool._registered = true
    end
end

LastHomeSchool.setSandBoxVars = function() end
LastHomeSchool.RemovePlayer = function(p) end
LastHomeSchool.AddPlayer = function(p) end
LastHomeSchool.Render = function() end

LastHomeSchool.id = "LastHomeSchool"
LastHomeSchool.image = "media/lua/client/LastStand/LastHomeSchool.png"
LastHomeSchool.gameMode = "Last Home: Ecole elementaire"
LastHomeSchool.world = "Muldraugh, KY"
LastHomeSchool.xcell = 35
LastHomeSchool.ycell = 33
LastHomeSchool.x = 113
LastHomeSchool.y = 74
LastHomeSchool.z = 0
LastHomeSchool.enableSandbox = true

Events.OnChallengeQuery.Add(LastHomeSchool.Add)