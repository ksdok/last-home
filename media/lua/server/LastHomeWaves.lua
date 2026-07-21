require "LastHomeShared"

LastHomeWaves = LastHomeWaves or {}

local Server = LastHomeWaves

local PREP_DURATION_SECONDS = 10 * 60
local WAVE_DURATION_SECONDS = 10 * 60
local ONE_MINUTE_WARNING_SECONDS = 60
local PRESSURE_PULSE_SECONDS = 15
local SPAWN_DISTANCE = 40
local SPAWN_SPREAD = 8
local ZOMBIE_MODULE = "LastHome"

local CARDINALS = {"N", "E", "S", "W"}
local DIRECTION_NAMES = {
    N = "NORD",
    E = "EST",
    S = "SUD",
    W = "OUEST",
    ALL = "TOUTES LES DIRECTIONS",
}

local ADJACENT_DIRECTION_SETS = {
    {"N", "E"},
    {"E", "S"},
    {"S", "W"},
    {"W", "N"},
}

local round = LastHomeShared.round
local getScenarioPlayers = LastHomeShared.getScenarioPlayers
local getNowSeconds = LastHomeShared.getNowSeconds
local getHouseBounds = LastHomeShared.getHouseBounds
local getRandomHouse = LastHomeShared.getRandomHouse
local cloneHouse = LastHomeShared.cloneHouse

local function isPlayerAlive(player)
    if player == nil then return false end

    local modData = player:getModData()
    if modData ~= nil and modData.LH_dead then
        return false
    end

    if player.isDead ~= nil and player:isDead() then
        return false
    end

    if player.getHealth ~= nil and player:getHealth() <= 0 then
        return false
    end

    return true
end

local function getAlivePlayers()
    local result = {}

    for _, player in ipairs(getScenarioPlayers()) do
        if isPlayerAlive(player) then
            result[#result + 1] = player
        end
    end

    return result
end

local function getAlivePlayerCount()
    return #getAlivePlayers()
end

local function getClosestAlivePlayer(x, y)
    local bestPlayer = nil
    local bestDistance = nil

    for _, player in ipairs(getAlivePlayers()) do
        local dx = player:getX() - x
        local dy = player:getY() - y
        local distance = (dx * dx) + (dy * dy)
        if bestDistance == nil or distance < bestDistance then
            bestDistance = distance
            bestPlayer = player
        end
    end

    return bestPlayer
end

local function joinLabels(labels)
    if labels == nil or #labels == 0 then return "" end
    if #labels == 1 then return labels[1] end
    if #labels == 2 then return labels[1] .. " et " .. labels[2] end

    local text = ""
    for index, label in ipairs(labels) do
        if index == #labels then
            text = text .. "et " .. label
        else
            text = text .. label .. ", "
        end
    end
    return text
end

local function formatDirections(directions)
    if directions == nil or #directions == 0 then return DIRECTION_NAMES.ALL end
    if directions[1] == "ALL" then return DIRECTION_NAMES.ALL end

    local labels = {}
    for _, direction in ipairs(directions) do
        labels[#labels + 1] = DIRECTION_NAMES[direction] or tostring(direction)
    end

    return joinLabels(labels)
end

local function getSpeedMultiplier(wave)
    return 0.8 + (wave * 0.05)
end

local function getAggression(wave)
    return 0.3 + (wave * 0.03)
end

local function getDetectionRange(wave)
    return 8 + (wave * 0.5)
end

local function getPhaseRemainingSeconds(now)
    if Server.phaseEndsAt == nil or Server.phaseEndsAt <= 0 then
        return 0
    end

    now = now or getNowSeconds()
    return math.max(0, Server.phaseEndsAt - now)
end

local function getDisplayedScore()
    return Server.wavesSurvived or 0
end

local function resetSpectatorWaveUsage()
    for _, spectator in pairs(Server.spectators) do
        spectator.spawnedThisWave = false
    end
end

local function resetState()
    Server.started = false
    Server.gameOver = false
    Server.currentWave = 0
    Server.wavesSurvived = 0
    Server.waveActive = false
    Server.phase = "idle"
    Server.phaseEndsAt = 0
    Server.phaseDurationSeconds = 0
    Server.oneMinuteWarningSent = false
    Server.pendingDirections = {}
    Server.pendingEstimate = 0
    Server.directions = {}
    Server.zombieCount = 0
    Server.spectators = {}
    Server.house = nil
    Server.lastTickSecond = nil
    Server.nextPressurePulseAt = nil
end

resetState()

local function syncWaveState()
    local now = getNowSeconds()

    sendServerCommand(ZOMBIE_MODULE, "WaveState", {
        started = Server.started,
        phase = Server.phase,
        currentWave = Server.currentWave,
        nextWave = Server.waveActive and Server.currentWave or (Server.currentWave + 1),
        waveActive = Server.waveActive,
        remainingSeconds = getPhaseRemainingSeconds(now),
        phaseEndsAt = Server.phaseEndsAt,
        durationSeconds = Server.phaseDurationSeconds,
        directions = Server.waveActive and Server.directions or Server.pendingDirections,
        directionsText = formatDirections(Server.waveActive and Server.directions or Server.pendingDirections),
        estimatedCount = Server.pendingEstimate,
        zombieCount = Server.zombieCount,
        score = getDisplayedScore(),
        house = Server.house,
    })
end

local function syncSpectatorState(username)
    local spectator = username ~= nil and Server.spectators[username] or nil
    sendServerCommand(ZOMBIE_MODULE, "SpectatorState", {
        username = username,
        isSpectator = spectator ~= nil,
        canSpawn = spectator ~= nil and Server.waveActive and not spectator.spawnedThisWave,
        spawnedThisWave = spectator ~= nil and spectator.spawnedThisWave or false,
        waveActive = Server.waveActive,
    })
end

local function sendAlert(text, alertType, username)
    sendServerCommand(ZOMBIE_MODULE, "AlertMessage", {
        text = text,
        type = alertType,
        username = username,
    })
end

local function broadcastAlert(text, alertType)
    sendAlert(text, alertType, nil)
end

local function notifyPlayer(username, text, alertType)
    if username == nil then return end
    sendAlert(text, alertType or "warning", username)
end

local function normalizeHouseData(houseOrX, centerY, centerZ, bounds)
    if type(houseOrX) == "table" then
        local house = cloneHouse ~= nil and cloneHouse(houseOrX) or houseOrX
        if house == nil then return nil end

        house.centerX = round(house.centerX)
        house.centerY = round(house.centerY)
        house.centerZ = round(house.centerZ or 0)
        house.bounds = getHouseBounds ~= nil and getHouseBounds(house) or house.bounds
        house.source = house.source or "configured"
        return house
    end

    return {
        centerX = round(houseOrX),
        centerY = round(centerY),
        centerZ = round(centerZ or 0),
        bounds = bounds,
        source = "configured",
    }
end

local function ensureHouse()
    if Server.house ~= nil then return true end

    local randomHouse = getRandomHouse ~= nil and getRandomHouse() or nil
    if randomHouse ~= nil then
        randomHouse.source = "shared-random-fallback"
        Server.house = normalizeHouseData(randomHouse)
        return Server.house ~= nil
    end

    local anchor = getAlivePlayers()[1]
    if anchor == nil then return false end

    Server.house = {
        centerX = round(anchor:getX()),
        centerY = round(anchor:getY()),
        centerZ = round(anchor:getZ()),
        source = "player-fallback",
    }

    return true
end

function LastHomeWaves.setHouse(houseOrX, centerY, centerZ, bounds)
    Server.house = normalizeHouseData(houseOrX, centerY, centerZ, bounds)
    syncWaveState()
end

function LastHomeWaves.getHouse()
    return Server.house
end

local function calculateZombieCount(wave, alivePlayers)
    local baseCount = 10 + (wave * 5)
    local scaledByPlayers = baseCount * ((alivePlayers or 0) / 4)
    return math.max(1, round(scaledByPlayers))
end

local function calculateDirections(wave)
    if wave <= 3 then
        return {CARDINALS[ZombRand(#CARDINALS) + 1]}
    end

    if wave <= 6 then
        local pair = ADJACENT_DIRECTION_SETS[ZombRand(#ADJACENT_DIRECTION_SETS) + 1]
        return {pair[1], pair[2]}
    end

    if wave <= 9 then
        local excluded = CARDINALS[ZombRand(#CARDINALS) + 1]
        local result = {}
        for _, direction in ipairs(CARDINALS) do
            if direction ~= excluded then
                result[#result + 1] = direction
            end
        end
        return result
    end

    return {"ALL"}
end

local function getSpawnPointsForDirection(direction, centerX, centerY)
    if direction == "N" then
        return {
            {x = centerX - SPAWN_SPREAD, y = centerY - SPAWN_DISTANCE},
            {x = centerX, y = centerY - SPAWN_DISTANCE},
            {x = centerX + SPAWN_SPREAD, y = centerY - SPAWN_DISTANCE},
        }
    elseif direction == "S" then
        return {
            {x = centerX - SPAWN_SPREAD, y = centerY + SPAWN_DISTANCE},
            {x = centerX, y = centerY + SPAWN_DISTANCE},
            {x = centerX + SPAWN_SPREAD, y = centerY + SPAWN_DISTANCE},
        }
    elseif direction == "E" then
        return {
            {x = centerX + SPAWN_DISTANCE, y = centerY - SPAWN_SPREAD},
            {x = centerX + SPAWN_DISTANCE, y = centerY},
            {x = centerX + SPAWN_DISTANCE, y = centerY + SPAWN_SPREAD},
        }
    elseif direction == "W" then
        return {
            {x = centerX - SPAWN_DISTANCE, y = centerY - SPAWN_SPREAD},
            {x = centerX - SPAWN_DISTANCE, y = centerY},
            {x = centerX - SPAWN_DISTANCE, y = centerY + SPAWN_SPREAD},
        }
    end

    return {}
end

local function getSpawnPoints(directions)
    local points = {}
    if Server.house == nil then return points end

    local centerX = Server.house.centerX
    local centerY = Server.house.centerY
    local centerZ = Server.house.centerZ or 0

    if directions ~= nil and directions[1] == "ALL" then
        local segments = 12
        for i = 1, segments do
            local angle = ((i - 1) / segments) * (math.pi * 2)
            points[#points + 1] = {
                x = round(centerX + (math.cos(angle) * SPAWN_DISTANCE)),
                y = round(centerY + (math.sin(angle) * SPAWN_DISTANCE)),
                z = centerZ,
            }
        end
        return points
    end

    for _, direction in ipairs(directions or {}) do
        local directionPoints = getSpawnPointsForDirection(direction, centerX, centerY)
        for _, point in ipairs(directionPoints) do
            points[#points + 1] = {
                x = point.x,
                y = point.y,
                z = centerZ,
            }
        end
    end

    return points
end

local function refreshZombiePressure()
    if Server.house == nil or not Server.waveActive then return end

    local sourcePlayer = getClosestAlivePlayer(Server.house.centerX, Server.house.centerY)
    if sourcePlayer == nil then return end

    addSound(sourcePlayer, Server.house.centerX, Server.house.centerY, Server.house.centerZ or 0, 100, round(getDetectionRange(Server.currentWave) + 20))
end

local function scaleZombieStats(zombie, wave)
    if zombie == nil then return end

    local speedMultiplier = getSpeedMultiplier(wave)
    local aggression = getAggression(wave)
    local detectionRange = getDetectionRange(wave)
    local modData = zombie:getModData()

    modData.LH_waveZombie = true
    modData.LH_waveNumber = wave
    modData.LH_countedDead = false
    modData.LH_speedMultiplier = speedMultiplier
    modData.LH_aggression = aggression
    modData.LH_detectionRange = detectionRange

    if zombie.setSpeedMod ~= nil then
        zombie:setSpeedMod(speedMultiplier)
    end

    if zombie.setCanWalk ~= nil then
        zombie:setCanWalk(true)
    end

    if Server.house ~= nil and zombie.setTurnAlertedValues ~= nil then
        zombie:setTurnAlertedValues(Server.house.centerX, Server.house.centerY)
    end

    local target = getClosestAlivePlayer(zombie:getX(), zombie:getY())
    if target ~= nil then
        if zombie.addAggro ~= nil then
            zombie:addAggro(target, aggression * 100)
        end

        if zombie.spotted ~= nil then
            pcall(function()
                zombie:spotted(target, true)
            end)
        end
    end
end

local function tagSpawnedZombies(spawned, wave)
    if spawned == nil then return 0 end

    local added = 0
    if spawned.size ~= nil and spawned.get ~= nil then
        for i = 0, spawned:size() - 1 do
            local zombie = spawned:get(i)
            if zombie ~= nil then
                scaleZombieStats(zombie, wave)
                added = added + 1
            end
        end
    end

    return added
end

local function spawnWaveZombies(count)
    if count == nil or count <= 0 then return 0 end

    local points = getSpawnPoints(Server.directions)
    if #points == 0 then return 0 end

    local spawnedCount = 0
    local basePerPoint = math.floor(count / #points)
    local remainder = count % #points

    for index, point in ipairs(points) do
        local zombiesHere = basePerPoint
        if index <= remainder then
            zombiesHere = zombiesHere + 1
        end

        if zombiesHere > 0 then
            local spawned = addZombiesInOutfit(point.x, point.y, point.z, zombiesHere, nil, 0)
            spawnedCount = spawnedCount + tagSpawnedZombies(spawned, Server.currentWave)
        end
    end

    Server.zombieCount = Server.zombieCount + spawnedCount
    refreshZombiePressure()
    return spawnedCount
end

local function triggerGameOver()
    if Server.gameOver then return end

    local finalScore = getDisplayedScore()

    Server.gameOver = true
    Server.waveActive = false
    Server.phase = "gameover"
    Server.phaseEndsAt = 0
    Server.phaseDurationSeconds = 0
    Server.nextPressurePulseAt = nil

    syncWaveState()
    sendServerCommand(ZOMBIE_MODULE, "GameOver", {
        score = finalScore,
    })
    broadcastAlert("[Last Home] Game over! Score final: " .. tostring(finalScore) .. " vague(s).", "danger")
end

local function startPrepPhase()
    if Server.gameOver then return false end
    if getAlivePlayerCount() <= 0 then
        triggerGameOver()
        return false
    end
    if not ensureHouse() then return false end

    Server.started = true
    Server.waveActive = false
    Server.phase = "prep"
    Server.phaseDurationSeconds = PREP_DURATION_SECONDS
    Server.phaseEndsAt = getNowSeconds() + PREP_DURATION_SECONDS
    Server.oneMinuteWarningSent = false
    Server.pendingDirections = calculateDirections(Server.currentWave + 1)
    Server.pendingEstimate = calculateZombieCount(Server.currentWave + 1, getAlivePlayerCount())
    Server.zombieCount = 0
    Server.nextPressurePulseAt = nil

    resetSpectatorWaveUsage()
    syncWaveState()

    local houseLabel = ""
    if Server.house ~= nil and Server.house.name ~= nil then
        houseLabel = "\nBase: " .. tostring(Server.house.name)
    end

    broadcastAlert(string.format("[Last Home] Vague %d dans 10 min%s\nDirection: %s\nTaille estimee: ~%d zombies", Server.currentWave + 1, houseLabel, formatDirections(Server.pendingDirections), Server.pendingEstimate), "info")
    return true
end

local function startWave(immediate)
    if Server.gameOver then return false end
    if getAlivePlayerCount() <= 0 then
        triggerGameOver()
        return false
    end
    if not ensureHouse() then return false end

    Server.started = true
    Server.waveActive = true
    Server.phase = "wave"
    Server.phaseDurationSeconds = WAVE_DURATION_SECONDS
    Server.phaseEndsAt = getNowSeconds() + WAVE_DURATION_SECONDS
    Server.oneMinuteWarningSent = false
    Server.currentWave = Server.currentWave + 1
    Server.directions = immediate and calculateDirections(Server.currentWave) or Server.pendingDirections
    Server.pendingDirections = {}
    Server.pendingEstimate = 0
    Server.nextPressurePulseAt = getNowSeconds() + PRESSURE_PULSE_SECONDS

    resetSpectatorWaveUsage()
    spawnWaveZombies(calculateZombieCount(Server.currentWave, getAlivePlayerCount()))
    syncWaveState()
    broadcastAlert(string.format("[Last Home] Vague %d! Les zombies arrivent par %s!", Server.currentWave, formatDirections(Server.directions)), "warning")

    for username, _ in pairs(Server.spectators) do
        syncSpectatorState(username)
    end

    return true
end

local function endWaveCleared()
    if not Server.waveActive then return end

    Server.waveActive = false
    Server.zombieCount = 0
    Server.wavesSurvived = Server.currentWave
    broadcastAlert(string.format("[Last Home] Vague %d eliminee! Prochaine vague dans 10 min.", Server.currentWave), "success")
    startPrepPhase()
end

function LastHomeWaves.ensureScenarioStarted()
    if Server.started or Server.gameOver then
        return false
    end
    return startPrepPhase()
end

local function handlePlayerDeath(player, x, y, z)
    if player == nil or Server.gameOver then return end

    local username = player:getUsername()
    if username == nil then return end

    local modData = player:getModData()
    if modData.LH_dead then return end

    modData.LH_dead = true
    modData.LH_spectator = true
    modData.LH_deathX = x ~= nil and x or player:getX()
    modData.LH_deathY = y ~= nil and y or player:getY()
    modData.LH_deathZ = z ~= nil and z or player:getZ()

    Server.spectators[username] = Server.spectators[username] or {}
    Server.spectators[username].spawnedThisWave = not Server.waveActive

    syncSpectatorState(username)
    syncWaveState()
    broadcastAlert("[Last Home] " .. tostring(username) .. " est mort et devient spectateur.", "danger")

    if getAlivePlayerCount() <= 0 then
        triggerGameOver()
    end
end

local function checkDeadPlayers()
    for _, player in ipairs(getScenarioPlayers()) do
        local modData = player:getModData()
        if modData ~= nil and not modData.LH_dead then
            local dead = false

            if player.isDead ~= nil and player:isDead() then
                dead = true
            elseif player.getHealth ~= nil and player:getHealth() <= 0 then
                dead = true
            end

            if dead then
                handlePlayerDeath(player)
            end
        end
    end
end

local function isValidSpectatorSpawnSquare(square)
    if square == nil then return false, "Case invalide." end
    if square.isOutside ~= nil and not square:isOutside() then
        return false, "Le zombie doit etre place a l'exterieur."
    end

    for _, player in ipairs(getAlivePlayers()) do
        local dx = player:getX() - square:getX()
        local dy = player:getY() - square:getY()
        local distance = math.sqrt((dx * dx) + (dy * dy))
        if distance < 10 then
            return false, "Trop proche d'un joueur vivant."
        end
    end

    return true, nil
end

local function onSpectatorSpawnZombie(player, x, y, z)
    if player == nil then return end

    local username = player:getUsername()
    local spectator = username ~= nil and Server.spectators[username] or nil
    if spectator == nil then return end

    if not Server.waveActive then
        notifyPlayer(username, "Le spawn spectateur n'est actif que pendant les vagues.", "warning")
        return
    end

    if spectator.spawnedThisWave then
        notifyPlayer(username, "Tu as deja utilise ton spawn pour cette vague.", "warning")
        return
    end

    local square = getCell():getGridSquare(round(x), round(y), round(z or 0))
    local valid, message = isValidSpectatorSpawnSquare(square)
    if not valid then
        notifyPlayer(username, "[Last Home] " .. tostring(message or "Spawn invalide."), "warning")
        return
    end

    local spawned = addZombiesInOutfit(square:getX(), square:getY(), square:getZ(), 1, nil, 0)
    local added = tagSpawnedZombies(spawned, Server.currentWave)
    if added <= 0 then
        notifyPlayer(username, "[Last Home] Impossible de spawner un zombie ici.", "warning")
        return
    end

    spectator.spawnedThisWave = true
    Server.zombieCount = Server.zombieCount + added

    syncSpectatorState(username)
    syncWaveState()
end

local function onZombieDead(zombie)
    if zombie == nil then return end

    local modData = zombie:getModData()
    if modData == nil or not modData.LH_waveZombie or modData.LH_countedDead then
        return
    end

    modData.LH_countedDead = true

    if Server.zombieCount > 0 then
        Server.zombieCount = Server.zombieCount - 1
    end

    if Server.waveActive and Server.zombieCount <= 0 then
        Server.zombieCount = 0
        endWaveCleared()
        return
    end

    if Server.waveActive and (Server.zombieCount <= 5 or Server.zombieCount % 10 == 0) then
        syncWaveState()
    end
end

local function updatePhaseState(now)
    if not Server.started or Server.gameOver then return end

    local remaining = getPhaseRemainingSeconds(now)

    if not Server.oneMinuteWarningSent and Server.phaseEndsAt > 0 and remaining <= ONE_MINUTE_WARNING_SECONDS then
        Server.oneMinuteWarningSent = true
        if Server.phase == "prep" then
            broadcastAlert(string.format("[Last Home] Vague %d dans 1 min! Preparez-vous!", Server.currentWave + 1), "warning")
        elseif Server.phase == "wave" then
            broadcastAlert(string.format("[Last Home] Vague %d: plus qu'1 min avant la prochaine horde!", Server.currentWave), "warning")
        end
    end

    if Server.phase == "prep" and remaining <= 0 then
        startWave(false)
        return
    end

    if Server.phase == "wave" then
        if Server.nextPressurePulseAt ~= nil and now >= Server.nextPressurePulseAt then
            refreshZombiePressure()
            Server.nextPressurePulseAt = now + PRESSURE_PULSE_SECONDS
        end

        if remaining <= 0 then
            broadcastAlert(string.format("[Last Home] Temps ecoule! La vague %d arrive... les zombies restants s'ajoutent a la horde!", Server.currentWave + 1), "danger")
            startWave(true)
        end
    end
end

local function onTick()
    local now = getNowSeconds()
    if now == Server.lastTickSecond then return end
    Server.lastTickSecond = now

    checkDeadPlayers()
    updatePhaseState(now)
end

local function onGameStart()
    resetState()
end
Events.OnGameStart.Add(onGameStart)

Events.OnTick.Add(onTick)
Events.OnZombieDead.Add(onZombieDead)

local function onClientCommand(module, command, player, data)
    if module ~= ZOMBIE_MODULE then return end

    if command == "RolePickerReady" then
        syncWaveState()
        if player ~= nil then
            local username = player:getUsername()
            if username ~= nil then
                syncSpectatorState(username)
            end
        end
        return
    end

    if command == "PlayerDied" then
        handlePlayerDeath(player, data and data.x or nil, data and data.y or nil, data and data.z or nil)
        return
    end

    if command == "SpectatorSpawnZombie" then
        onSpectatorSpawnZombie(player, data and data.x or nil, data and data.y or nil, data and data.z or nil)
    end
end
Events.OnClientCommand.Add(onClientCommand)
