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