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

LastHomeSchool.setSandBoxVars = function()
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