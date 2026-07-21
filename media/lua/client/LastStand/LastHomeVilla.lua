-- Last Home - Challenge: Villa
-- Defendez la villa contre des vagues croissantes de zombies.

LastHomeVilla = {}

LastHomeVilla.Add = function()
    addChallenge(LastHomeVilla)
end

LastHomeVilla.OnGameStart = function()
    sendClientCommand("LastHome", "SetHouse", { houseId = "villa" })
end

LastHomeVilla.OnInitWorld = function()
    if not LastHomeVilla._registered then
        Events.OnGameStart.Add(LastHomeVilla.OnGameStart)
        LastHomeVilla._registered = true
    end
end

LastHomeVilla.setSandBoxVars = function() end
LastHomeVilla.RemovePlayer = function(p) end
LastHomeVilla.AddPlayer = function(p) end
LastHomeVilla.Render = function() end

LastHomeVilla.id = "LastHomeVilla"
LastHomeVilla.image = "media/lua/client/LastStand/LastHomeVilla.png"
LastHomeVilla.gameMode = "Last Home: Villa"
LastHomeVilla.world = "Muldraugh, KY"
LastHomeVilla.xcell = 45
LastHomeVilla.ycell = 9
LastHomeVilla.x = 32
LastHomeVilla.y = 142
LastHomeVilla.z = 1
LastHomeVilla.enableSandbox = true

Events.OnChallengeQuery.Add(LastHomeVilla.Add)