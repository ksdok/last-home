require "LastHomeShared"

LastHomeWaves = LastHomeWaves or {}

print("[LastHome] LastHomeWaves charge")

local Server = LastHomeWaves

local FIRST_PREP_DURATION_SECONDS = 2 * 60
local PREP_DURATION_SECONDS = 5 * 60
local WAVE_DURATION_SECONDS = 5 * 60
local ONE_MINUTE_WARNING_SECONDS = 60
local PRESSURE_PULSE_SECONDS = 15
local SPAWN_DISTANCE = 40
local SPAWN_SPREAD = 8
local BOUNDARY_COUNTDOWN_SECONDS = 10
local BOUNDARY_DAMAGE_AMOUNT = 5
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

local function getPrepDurationSeconds(nextWave)
    if (nextWave or 1) <= 1 then
        return FIRST_PREP_DURATION_SECONDS
    end
    return PREP_DURATION_SECONDS
end

local function formatDurationLabel(durationSeconds)
    local totalSeconds = math.max(0, math.floor(durationSeconds or 0))
    if totalSeconds > 0 and totalSeconds % 60 == 0 then
        return tostring(math.floor(totalSeconds / 60)) .. " min"
    end
    return tostring(totalSeconds) .. " s"
end

local round = LastHomeShared.round
local getScenarioPlayers = LastHomeShared.getScenarioPlayers
local getNowSeconds = LastHomeShared.getNowSeconds
local getHouseBounds = LastHomeShared.getHouseBounds
local hasBoundary = LastHomeShared.hasBoundary
local isInsideBoundary = LastHomeShared.isInsideBoundary
local getRandomHouse = LastHomeShared.getRandomHouse
local cloneHouse = LastHomeShared.cloneHouse

local function logBoundary(message)
    print("[LastHome][Boundary] " .. tostring(message))
end

local function formatCoords(x, y, z)
    return "(" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z or 0) .. ")"
end

local function formatPlayerCoords(player)
    if player == nil or player.getX == nil or player.getY == nil then
        return "(?, ?, ?)"
    end
    return formatCoords(player:getX(), player:getY(), player.getZ ~= nil and player:getZ() or 0)
end

local function formatBoundaryLabel(house)
    if house == nil then return "house=nil" end

    if house.boundary ~= nil then
        return tostring(house.name or house.id or "?")
            .. " rect[x=" .. tostring(house.boundary.minX) .. ".." .. tostring(house.boundary.maxX)
            .. ", y=" .. tostring(house.boundary.minY) .. ".." .. tostring(house.boundary.maxY) .. "]"
    end

    local radius = LastHomeShared.getBoundaryRadius ~= nil and LastHomeShared.getBoundaryRadius(house) or 0
    return tostring(house.name or house.id or "?") .. " radius=" .. tostring(radius) .. " center=" .. formatCoords(house.centerX, house.centerY, house.centerZ or 0)
end

local function updateBoundaryDebugTrace(username, key, message)
    if username == nil then return end

    Server.boundaryDebugTrace = Server.boundaryDebugTrace or {}
    if Server.boundaryDebugTrace[username] == key then return end

    Server.boundaryDebugTrace[username] = key
    logBoundary(message)
end

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

local function getAggroTarget(x, y)
    local target = getClosestAlivePlayer(x, y)
    if target == nil then return nil end

    return {
        player = target,
        x = target:getX(),
        y = target:getY(),
        z = target:getZ(),
    }
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
    Server.boundaryStates = {}
    Server.boundaryDebugTrace = {}
    Server.lastBoundaryEnabledDebugKey = nil
    Server.house = nil
    Server.lastTickSecond = nil
    Server.nextPressurePulseAt = nil
    print("[LastHome] LastHomeWaves resetState - etat reinitialise")
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

local function sendAlert(text, alertType, username, durationSeconds)
    sendServerCommand(ZOMBIE_MODULE, "AlertMessage", {
        text = text,
        type = alertType,
        username = username,
        durationSeconds = durationSeconds,
    })
end

local function broadcastAlert(text, alertType, durationSeconds)
    sendAlert(text, alertType, nil, durationSeconds)
end

local function notifyPlayer(username, text, alertType, durationSeconds)
    if username == nil then return end
    sendAlert(text, alertType or "warning", username, durationSeconds)
end

local function syncBoundaryState(username)
    if username == nil then return end

    local state = Server.boundaryStates[username]
    logBoundary("Sync BoundaryState -> " .. tostring(username) .. " status=" .. tostring(state ~= nil and state.status or "inside") .. ", fin=" .. tostring(state ~= nil and state.countdownEndsAt or 0))
    sendServerCommand(ZOMBIE_MODULE, "BoundaryState", {
        username = username,
        status = state ~= nil and state.status or "inside",
        countdownEndsAt = state ~= nil and state.countdownEndsAt or 0,
    })
end

local function resetBoundaryState(username)
    if username == nil then return false end

    local state = Server.boundaryStates[username]
    if state == nil then return false end

    logBoundary("Reset BoundaryState pour " .. tostring(username) .. " (ancien status=" .. tostring(state.status) .. ", fin=" .. tostring(state.countdownEndsAt or 0) .. ")")
    Server.boundaryStates[username] = nil
    syncBoundaryState(username)
    return true
end

local function resetAllBoundaryStates()
    if Server.boundaryStates == nil then return end

    local usernames = {}
    for username, _ in pairs(Server.boundaryStates) do
        usernames[#usernames + 1] = username
    end

    if #usernames <= 0 then return end

    Server.boundaryStates = {}
    for _, username in ipairs(usernames) do
        syncBoundaryState(username)
    end
end

local function getOrCreateBoundaryState(username)
    if username == nil then return nil end

    local state = Server.boundaryStates[username]
    if state == nil then
        state = {
            status = "inside",
            countdownEndsAt = 0,
            lastDamageAt = 0,
        }
        Server.boundaryStates[username] = state
    end
    return state
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
        print("[LastHome] LastHomeWaves ensureHouse - fallback maison aleatoire: " .. tostring(Server.house.name or Server.house.id or "?"))
        return Server.house ~= nil
    end

    local anchor = getAlivePlayers()[1]
    if anchor == nil then
        print("[LastHome] WARN: LastHomeWaves ensureHouse - aucun joueur ni maison disponible")
        return false
    end

    Server.house = {
        centerX = round(anchor:getX()),
        centerY = round(anchor:getY()),
        centerZ = round(anchor:getZ()),
        source = "player-fallback",
    }

    print("[LastHome] LastHomeWaves ensureHouse - fallback joueur: (" .. tostring(Server.house.centerX) .. ", " .. tostring(Server.house.centerY) .. ", " .. tostring(Server.house.centerZ) .. ")")
    return true
end

function LastHomeWaves.setHouse(houseOrX, centerY, centerZ, bounds)
    Server.house = normalizeHouseData(houseOrX, centerY, centerZ, bounds)
    syncWaveState()
end

function LastHomeWaves.getHouse()
    return Server.house
end

function LastHomeWaves.getClientState(username)
    local now = getNowSeconds()
    local spectator = username ~= nil and Server.spectators[username] or nil
    local boundary = username ~= nil and Server.boundaryStates[username] or nil

    return {
        waveState = {
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
        },
        boundaryState = {
            status = boundary ~= nil and boundary.status or "inside",
            countdownEndsAt = boundary ~= nil and boundary.countdownEndsAt or 0,
        },
        spectatorState = {
            isSpectator = spectator ~= nil,
            canSpawn = spectator ~= nil and Server.waveActive and not spectator.spawnedThisWave,
            spawnedThisWave = spectator ~= nil and spectator.spawnedThisWave or false,
            waveActive = Server.waveActive,
        },
    }
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
    local spawnZ = 0

    if directions ~= nil and directions[1] == "ALL" then
        local segments = 12
        for i = 1, segments do
            local angle = ((i - 1) / segments) * (math.pi * 2)
            points[#points + 1] = {
                x = round(centerX + (math.cos(angle) * SPAWN_DISTANCE)),
                y = round(centerY + (math.sin(angle) * SPAWN_DISTANCE)),
                z = spawnZ,
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
                z = spawnZ,
            }
        end
    end

    return points
end

local function applyZombieAggro(zombie, wave, targetData)
    if zombie == nil or targetData == nil or targetData.player == nil then return end

    local aggression = getAggression(wave)

    if zombie.setTurnAlertedValues ~= nil then
        zombie:setTurnAlertedValues(targetData.x, targetData.y)
    end

    if zombie.pathToCharacter ~= nil then
        pcall(function()
            zombie:pathToCharacter(targetData.player)
        end)
    end

    if zombie.addAggro ~= nil then
        zombie:addAggro(targetData.player, aggression * 100)
    end

    if zombie.spotted ~= nil then
        pcall(function()
            zombie:spotted(targetData.player, true)
        end)
    end
end

local function refreshZombiePressure()
    if Server.house == nil or not Server.waveActive then return end

    local targetData = getAggroTarget(Server.house.centerX, Server.house.centerY)
    if targetData == nil then return end

    addSound(targetData.player, targetData.x, targetData.y, targetData.z or 0, 100, round(getDetectionRange(Server.currentWave) + 20))

    local cell = getCell()
    if cell == nil or cell.getZombieList == nil then return end

    local zombies = cell:getZombieList()
    if zombies == nil then return end

    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie ~= nil then
            local modData = zombie:getModData()
            if modData ~= nil and modData.LH_waveZombie and not modData.LH_countedDead then
                applyZombieAggro(zombie, modData.LH_waveNumber or Server.currentWave, targetData)
            end
        end
    end
end

local function scaleZombieStats(zombie, wave)
    if zombie == nil then return end

    local speedMultiplier = getSpeedMultiplier(wave)
    local detectionRange = getDetectionRange(wave)
    local modData = zombie:getModData()

    modData.LH_waveZombie = true
    modData.LH_waveNumber = wave
    modData.LH_countedDead = false
    modData.LH_detectionRange = detectionRange

    if zombie.setSpeedMod ~= nil then
        zombie:setSpeedMod(speedMultiplier)
    end

    if zombie.setCanWalk ~= nil then
        zombie:setCanWalk(true)
    end

    applyZombieAggro(zombie, wave, getAggroTarget(zombie:getX(), zombie:getY()))
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

local function clearAmbientZombiesNearHouse()
    if Server.house == nil then return 0 end

    local cell = getCell()
    if cell == nil or cell.getZombieList == nil then
        return 0
    end

    local zombies = cell:getZombieList()
    if zombies == nil then
        return 0
    end

    local radius = SPAWN_DISTANCE + 30
    local radiusSquared = radius * radius
    local centerX = Server.house.centerX
    local centerY = Server.house.centerY
    local removed = 0

    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie ~= nil and zombie:getSquare() ~= nil then
            local modData = zombie:getModData()
            local isWaveZombie = modData ~= nil and modData.LH_waveZombie == true and modData.LH_countedDead ~= true
            if not isWaveZombie then
                local dx = zombie:getX() - centerX
                local dy = zombie:getY() - centerY
                if (dx * dx) + (dy * dy) <= radiusSquared then
                    zombie:removeFromWorld()
                    zombie:removeFromSquare()
                    removed = removed + 1
                end
            end
        end
    end

    if removed > 0 then
        print("[LastHome] Nettoyage zombies ambiants pres de la base: " .. tostring(removed) .. " supprimes")
    end

    return removed
end

local function spawnWaveZombies(count)
    if count == nil or count <= 0 then return 0 end

    local points = getSpawnPoints(Server.directions)
    if #points == 0 then
        print("[LastHome] WARN: spawnWaveZombies - aucun point de spawn (directions=" .. tostring(formatDirections(Server.directions)) .. ", house=" .. tostring(Server.house ~= nil) .. ")")
        return 0
    end

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
    print("[LastHome] Vague " .. tostring(Server.currentWave) .. ": " .. tostring(spawnedCount) .. "/" .. tostring(count) .. " zombies spawnes, total restants=" .. tostring(Server.zombieCount))
    return spawnedCount
end

local function countSpectators()
    local count = 0
    for _ in pairs(Server.spectators) do count = count + 1 end
    return count
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
    print("[LastHome] GAME OVER - score final: " .. tostring(finalScore) .. " vague(s), " .. tostring(#getAlivePlayers()) .. " survivants, " .. tostring(countSpectators()) .. " spectateurs")
end

local function startPrepPhase()
    if Server.gameOver then return false end
    if getAlivePlayerCount() <= 0 then
        triggerGameOver()
        return false
    end
    if not ensureHouse() then return false end

    local nextWave = Server.currentWave + 1
    local prepDurationSeconds = getPrepDurationSeconds(nextWave)

    clearAmbientZombiesNearHouse()

    Server.started = true
    Server.waveActive = false
    Server.phase = "prep"
    Server.phaseDurationSeconds = prepDurationSeconds
    Server.phaseEndsAt = getNowSeconds() + prepDurationSeconds
    Server.oneMinuteWarningSent = false
    Server.pendingDirections = calculateDirections(nextWave)
    Server.pendingEstimate = calculateZombieCount(nextWave, getAlivePlayerCount())
    Server.zombieCount = 0
    Server.nextPressurePulseAt = nil

    resetSpectatorWaveUsage()
    syncWaveState()

    print("[LastHome] Phase PREP - vague " .. tostring(nextWave) .. ", " .. tostring(getAlivePlayerCount()) .. " joueurs, " .. tostring(Server.pendingEstimate) .. " zombies estimes, direction(s): " .. formatDirections(Server.pendingDirections) .. ", duree=" .. tostring(prepDurationSeconds) .. "s")

    local houseLabel = ""
    if Server.house ~= nil and Server.house.name ~= nil then
        houseLabel = "\nBase: " .. tostring(Server.house.name)
    end

    broadcastAlert(string.format("[Last Home] Vague %d dans %s%s\nDirection: %s\nTaille estimee: ~%d zombies", nextWave, formatDurationLabel(prepDurationSeconds), houseLabel, formatDirections(Server.pendingDirections), Server.pendingEstimate), "info")
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
    print("[LastHome] VAGUE " .. tostring(Server.currentWave) .. " demarree - " .. tostring(getAlivePlayerCount()) .. " joueurs, direction(s): " .. formatDirections(Server.directions))
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
    print("[LastHome] Vague " .. tostring(Server.currentWave) .. " eliminee - " .. tostring(Server.wavesSurvived) .. " vagues survecces")
    broadcastAlert(string.format("[Last Home] Vague %d eliminee! Prochaine vague dans %s.", Server.currentWave, formatDurationLabel(getPrepDurationSeconds(Server.currentWave + 1))), "success")
    startPrepPhase()
end

function LastHomeWaves.hasStarted()
    return Server.started == true
end

function LastHomeWaves.ensureScenarioStarted()
    if Server.started or Server.gameOver then
        return false
    end
    return startPrepPhase()
end

function LastHomeWaves.skipToNextWave(player)
    if Server.gameOver or not Server.started or Server.phase ~= "prep" then
        return false
    end

    local username = "solo"
    if player ~= nil and player.getUsername ~= nil then
        username = player:getUsername() or username
    end

    print("[LastHome] SkipToNextWave - demande par " .. tostring(username) .. " pour la vague " .. tostring(Server.currentWave + 1))
    broadcastAlert("[Last Home] La prochaine vague est lancee immediatement!", "warning")
    return startWave(false)
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
    resetBoundaryState(username)

    print("[LastHome] Joueur mort: " .. tostring(username) .. " -> spectateur (vague active=" .. tostring(Server.waveActive) .. ", spawns cette vague=" .. tostring(Server.spectators[username].spawnedThisWave) .. ")")

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

local function applyBoundaryDamage(player)
    if player == nil then return end

    local bodyDamage = player.getBodyDamage ~= nil and player:getBodyDamage() or nil
    if bodyDamage ~= nil and bodyDamage.ReduceGeneralHealth ~= nil then
        bodyDamage:ReduceGeneralHealth(BOUNDARY_DAMAGE_AMOUNT)
        return
    end

    if player.getHealth ~= nil and player.setHealth ~= nil then
        player:setHealth(math.max(0, player:getHealth() - BOUNDARY_DAMAGE_AMOUNT))
    end
end

local function updateBoundaryStates(now)
    local boundaryEnabled = Server.started and not Server.gameOver and Server.phase ~= "idle" and Server.phase ~= "gameover" and Server.house ~= nil and hasBoundary ~= nil and hasBoundary(Server.house)
    local boundaryEnabledDebugKey = tostring(boundaryEnabled) .. "|" .. tostring(Server.started) .. "|" .. tostring(Server.gameOver) .. "|" .. tostring(Server.phase) .. "|" .. formatBoundaryLabel(Server.house)

    if Server.lastBoundaryEnabledDebugKey ~= boundaryEnabledDebugKey then
        Server.lastBoundaryEnabledDebugKey = boundaryEnabledDebugKey
        logBoundary("Confinement actif=" .. tostring(boundaryEnabled) .. ", started=" .. tostring(Server.started) .. ", gameOver=" .. tostring(Server.gameOver) .. ", phase=" .. tostring(Server.phase) .. ", house=" .. formatBoundaryLabel(Server.house))
    end

    if not boundaryEnabled then
        resetAllBoundaryStates()
        return
    end

    for _, player in ipairs(getScenarioPlayers()) do
        if player ~= nil then
            local username = player:getUsername()
            if username ~= nil then
                local modData = player:getModData()
                local roleKey = modData ~= nil and modData.LH_role or nil
                local isDead = modData ~= nil and modData.LH_dead == true
                local isSpectator = modData ~= nil and modData.LH_spectator == true
                local alive = isPlayerAlive(player)
                local shouldCheck = roleKey ~= nil and not isDead and not isSpectator and alive

                if not shouldCheck then
                    updateBoundaryDebugTrace(username, "skip|" .. tostring(roleKey) .. "|" .. tostring(isDead) .. "|" .. tostring(isSpectator) .. "|" .. tostring(alive), "Skip confinement pour " .. tostring(username) .. " - role=" .. tostring(roleKey) .. ", dead=" .. tostring(isDead) .. ", spectator=" .. tostring(isSpectator) .. ", alive=" .. tostring(alive) .. ", coords=" .. formatPlayerCoords(player))
                    resetBoundaryState(username)
                else
                    local insideBoundary = isInsideBoundary == nil or isInsideBoundary(player, Server.house)
                    local state = Server.boundaryStates[username]

                    if insideBoundary then
                        if state ~= nil then
                            updateBoundaryDebugTrace(username, "inside", "Retour dans la zone pour " .. tostring(username) .. " - coords=" .. formatPlayerCoords(player) .. ", house=" .. formatBoundaryLabel(Server.house))
                        else
                            updateBoundaryDebugTrace(username, "inside", "Dans la zone pour " .. tostring(username) .. " - coords=" .. formatPlayerCoords(player) .. ", house=" .. formatBoundaryLabel(Server.house))
                        end

                        if resetBoundaryState(username) then
                            notifyPlayer(username, "[Last Home] De retour dans la zone.", "success", 4)
                        end
                    else
                        if state == nil then
                            state = getOrCreateBoundaryState(username)
                            state.status = "countdown"
                            state.countdownEndsAt = now + BOUNDARY_COUNTDOWN_SECONDS
                            state.lastDamageAt = 0
                            updateBoundaryDebugTrace(username, "countdown|" .. tostring(state.countdownEndsAt), "Sortie de zone detectee pour " .. tostring(username) .. " - coords=" .. formatPlayerCoords(player) .. ", countdownFin=" .. tostring(state.countdownEndsAt) .. ", house=" .. formatBoundaryLabel(Server.house))
                            syncBoundaryState(username)
                            notifyPlayer(username, "[Last Home] Hors zone ! Revenez dans 10s.", "danger", 4)
                        elseif state.status == "countdown" and now >= (state.countdownEndsAt or 0) then
                            state.status = "damaging"
                            state.lastDamageAt = 0
                            updateBoundaryDebugTrace(username, "damaging", "Degats de confinement actifs pour " .. tostring(username) .. " - coords=" .. formatPlayerCoords(player) .. ", house=" .. formatBoundaryLabel(Server.house))
                            syncBoundaryState(username)
                            notifyPlayer(username, "[Last Home] Hors zone ! Degats actifs.", "danger", 4)
                        end

                        if state.status == "damaging" and (state.lastDamageAt == nil or now > state.lastDamageAt) then
                            state.lastDamageAt = now
                            applyBoundaryDamage(player)
                            logBoundary("Tick degats confinement pour " .. tostring(username) .. " - coords=" .. formatPlayerCoords(player) .. ", amount=" .. tostring(BOUNDARY_DAMAGE_AMOUNT))
                        end
                    end
                end
            end
        end
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
    updateBoundaryStates(now)
    updatePhaseState(now)
end

local function onGameStart()
    print("[LastHome] LastHomeWaves OnGameStart")
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
                syncBoundaryState(username)
            end
        end
        return
    end

    if command == "PlayerDied" then
        handlePlayerDeath(player, data and data.x or nil, data and data.y or nil, data and data.z or nil)
        return
    end

    if command == "SkipToNextWave" then
        LastHomeWaves.skipToNextWave(player)
        return
    end

    if command == "SpectatorSpawnZombie" then
        onSpectatorSpawnZombie(player, data and data.x or nil, data and data.y or nil, data and data.z or nil)
    end
end
Events.OnClientCommand.Add(onClientCommand)
print("[LastHome] LastHomeWaves pret - handlers: OnGameStart, OnTick, OnZombieDead, OnClientCommand")
