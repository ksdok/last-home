-- Last Home - Challenge: Villa
-- Defendez la villa contre des vagues croissantes de zombies.

LastHomeVilla = {}
LastHomeVilla._gameStartRegistered = LastHomeVilla._gameStartRegistered or false
LastHomeVilla._houseSelectionSent = false

LastHomeVilla.Add = function()
    addChallenge(LastHomeVilla)
end

LastHomeVilla.SendHouseSelection = function()
    if LastHomeVilla._houseSelectionSent then return end

    LastHomeVilla._houseSelectionSent = true
    sendClientCommand("LastHome", "SetHouse", { houseId = "villa" })
end

LastHomeVilla.OnGameStart = function()
    LastHomeVilla.SendHouseSelection()
end

LastHomeVilla.OnInitWorld = function()
    LastHomeVilla._houseSelectionSent = false

    if not LastHomeVilla._gameStartRegistered then
        Events.OnGameStart.Add(LastHomeVilla.OnGameStart)
        LastHomeVilla._gameStartRegistered = true
    end
end

LastHomeVilla.setSandBoxVars = function()
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