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
    if SandboxVars == nil then return end

    SandboxVars.Zombies = 5
    SandboxVars.Distribution = 1
    SandboxVars.MetaEvent = 1
    SandboxVars.SurvivorHouseChance = 1
    SandboxVars.ZoneStoryChance = 1
    SandboxVars.VehicleStoryChance = 1

    local zombieConfig = ZombieConfig or SandboxVars.ZombieConfig
    if zombieConfig ~= nil then
        zombieConfig.PopulationMultiplier = 0
        zombieConfig.PopulationStartMultiplier = 0
        zombieConfig.PopulationPeakMultiplier = 0
        zombieConfig.RespawnHours = 0
        zombieConfig.RespawnUnseenHours = 0
        zombieConfig.RespawnMultiplier = 0
        zombieConfig.RedistributeHours = 0
        zombieConfig.RallyGroupSize = 0
    end
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