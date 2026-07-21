-- Last Home - Challenge: Ecole elementaire
-- Defendez l'ecole elementaire contre des vagues croissantes de zombies.

LastHomeSchool = {}
LastHomeSchool._gameStartRegistered = LastHomeSchool._gameStartRegistered or false
LastHomeSchool._houseSelectionSent = false

LastHomeSchool.Add = function()
    addChallenge(LastHomeSchool)
end

LastHomeSchool.SendHouseSelection = function()
    if LastHomeSchool._houseSelectionSent then return end

    LastHomeSchool._houseSelectionSent = true
    sendClientCommand("LastHome", "SetHouse", { houseId = "elementary_school" })
end

LastHomeSchool.OnGameStart = function()
    LastHomeSchool.SendHouseSelection()
end

LastHomeSchool.OnInitWorld = function()
    LastHomeSchool._houseSelectionSent = false

    if not LastHomeSchool._gameStartRegistered then
        Events.OnGameStart.Add(LastHomeSchool.OnGameStart)
        LastHomeSchool._gameStartRegistered = true
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