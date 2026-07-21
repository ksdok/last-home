-- Last Home - Challenge: Prison
-- Defendez la prison contre des vagues croissantes de zombies.

LastHomePrison = {}

LastHomePrison.Add = function()
    addChallenge(LastHomePrison)
end

LastHomePrison.OnGameStart = function()
    sendClientCommand("LastHome", "SetHouse", { houseId = "prison" })
end

LastHomePrison.OnInitWorld = function()
    if not LastHomePrison._registered then
        Events.OnGameStart.Add(LastHomePrison.OnGameStart)
        LastHomePrison._registered = true
    end
end

LastHomePrison.setSandBoxVars = function() end
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