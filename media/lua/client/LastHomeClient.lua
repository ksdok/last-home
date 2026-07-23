require "LastHomeRolePicker"
require "LastHomeRoles"
require "LastHomeShared"

LastHomeClient = LastHomeClient or {}

print("[LastHome] LastHomeClient charge")

local roleRequestSent = false
local soloPickerFallbackAt = nil
local soloFallbackTickRegistered = false
local soloStateLastSyncSecond = nil
local getNowSeconds = LastHomeShared.getNowSeconds
local isInsideBoundary = LastHomeShared.isInsideBoundary
local applyCarryProfile = LastHomeShared.applyCarryProfile
local primeRoleLoadout = LastHomeShared.primeRoleLoadout
local equipRoleItems = LastHomeShared.equipRoleItems
local DEBUG_ENABLED = LastHomeShared.DEBUG == true

local showRoleAssigned -- forward declaration (définie plus bas)

local function isSinglePlayerRuntime()
    if isClient ~= nil then
        return not isClient()
    end
    if getOnlinePlayers ~= nil then
        local onlinePlayers = getOnlinePlayers()
        return onlinePlayers == nil or onlinePlayers:size() == 0
    end
    return true
end

local function logClient(message)
    if not DEBUG_ENABLED then return end
    print("[LastHome][Client] " .. tostring(message))
end

local function logBoundaryClient(message)
    print("[LastHome][Boundary][Client] " .. tostring(message))
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

local function formatHouseLabel(house)
    if house == nil then return "nil" end
    return tostring(house.name or house.id or "?") .. "@" .. formatCoords(house.centerX, house.centerY, house.centerZ or 0)
end

local function formatBoundaryLabel(house)
    if house == nil then return "house=nil" end

    if house.boundary ~= nil then
        return tostring(house.name or house.id or "?")
            .. " rect[x=" .. tostring(house.boundary.minX) .. ".." .. tostring(house.boundary.maxX)
            .. ", y=" .. tostring(house.boundary.minY) .. ".." .. tostring(house.boundary.maxY) .. "]"
    end

    return tostring(house.name or house.id or "?") .. " radius=" .. tostring(house.boundaryRadius or 0) .. " center=" .. formatCoords(house.centerX, house.centerY, house.centerZ or 0)
end

LastHomeClient.waveState = LastHomeClient.waveState or {
    phase = "idle",
    currentWave = 0,
    nextWave = 1,
    waveActive = false,
    remainingSeconds = 0,
    phaseEndsAt = 0,
    durationSeconds = 0,
    directionsText = "",
    estimatedCount = 0,
    zombieCount = 0,
    score = 0,
    house = nil,
}
LastHomeClient.alertText = nil
LastHomeClient.alertType = "info"
LastHomeClient.alertExpiresAt = nil
LastHomeClient.isSpectator = false
LastHomeClient.spectatorSpawnUsed = false
LastHomeClient.boundaryState = LastHomeClient.boundaryState or {
    status = "inside",
    countdownEndsAt = 0,
}
LastHomeClient.localBoundaryStatus = LastHomeClient.localBoundaryStatus or "inactive"
LastHomeClient.boundaryReturnedAt = 0

local ALERT_COLORS = {
    info = {r = 0.9, g = 0.9, b = 0.9, a = 1},
    success = {r = 0.35, g = 0.95, b = 0.45, a = 1},
    warning = {r = 1, g = 0.85, b = 0.25, a = 1},
    danger = {r = 1, g = 0.45, b = 0.45, a = 1},
}

local function ensureSoloFallbackTickRegistered()
    if soloFallbackTickRegistered then return end
    logClient("Activation du tick de fallback solo pour le role picker")
    Events.OnTick.Add(LastHomeClient.TickRolePickerFallback)
    soloFallbackTickRegistered = true
end

local function unregisterSoloFallbackTick()
    if not soloFallbackTickRegistered then return end
    logClient("Desactivation du tick de fallback solo pour le role picker")
    Events.OnTick.Remove(LastHomeClient.TickRolePickerFallback)
    soloFallbackTickRegistered = false
end

LastHomeClient.TickRolePickerFallback = function()
    if soloPickerFallbackAt == nil then
        unregisterSoloFallbackTick()
        return
    end

    if not isSinglePlayerRuntime() then
        logClient("Fallback solo annule: runtime reseau detecte")
        soloPickerFallbackAt = nil
        unregisterSoloFallbackTick()
        return
    end

    local player = getPlayer()
    if player == nil then return end
    if player:getModData().LH_role ~= nil then
        soloPickerFallbackAt = nil
        unregisterSoloFallbackTick()
        return
    end

    if LastHomeRolePicker.isVisible() then
        soloPickerFallbackAt = nil
        unregisterSoloFallbackTick()
        return
    end

    if getNowSeconds() >= soloPickerFallbackAt then
        logClient("Fallback solo declenche -> ouverture locale du role picker")
        soloPickerFallbackAt = nil
        unregisterSoloFallbackTick()
        LastHomeRolePicker.openLocal()
    end
end

-- ============================================================
-- SOLO: application locale du role (sans serveur)
-- ============================================================

local ROLE_DEFS = LastHomeRoles.ROLE_DEFS

local function addItemsToContainer(container, itemId, count)
    if container == nil or itemId == nil or count == nil or count <= 0 then return end
    for _ = 1, count do
        container:AddItem(itemId)
    end
end

local function buildItemCounts(items)
    local counts = {}
    if items == nil then return counts end
    for _, itemDef in ipairs(items) do
        local itemId = itemDef[1]
        local count = itemDef[2] or 1
        counts[itemId] = (counts[itemId] or 0) + count
    end
    return counts
end

local function addRoleItems(inv, bagItem, bagItemId, items, bagContents)
    if inv == nil or items == nil then return end

    local bagContainer = bagItem and bagItem:getItemContainer() or nil
    local bagCounts = buildItemCounts(bagContents)

    for _, itemDef in ipairs(items) do
        local itemId = itemDef[1]
        local totalCount = itemDef[2] or 1

        if itemId ~= bagItemId then
            local bagCount = 0
            if bagContainer ~= nil and bagCounts[itemId] ~= nil then
                bagCount = math.min(totalCount, bagCounts[itemId])
            end
            local invCount = totalCount - bagCount

            if invCount > 1 then
                inv:AddItems(itemId, invCount)
            elseif invCount == 1 then
                inv:AddItem(itemId)
            end

            addItemsToContainer(bagContainer, itemId, bagCount)
        end
    end
end

local function applyRoleStats(player, stats)
    if player == nil then return end

    local playerStats = player:getStats()
    playerStats:setPanic(30)
    playerStats:setHunger(0.2)
    playerStats:setThirst(0.2)
    playerStats:setFatigue(0)

    if stats == nil then return end
    if stats.endurance ~= nil then playerStats:setEndurance(stats.endurance) end
    if stats.panic ~= nil then playerStats:setPanic(stats.panic) end
    if stats.fatigue ~= nil then playerStats:setFatigue(stats.fatigue) end
    if stats.hunger ~= nil then playerStats:setHunger(stats.hunger) end
    if stats.thirst ~= nil then playerStats:setThirst(stats.thirst) end
end

local function isPassivePerk(perk)
    return perk == Perks.Strength or perk == Perks.Fitness
end

local function applyPerkLevel(player, perk, level)
    if player == nil or perk == nil or level == nil then return end

    local xp = player:getXp()
    xp:setXPToLevel(perk, level)

    if isPassivePerk(perk) and player.setPerkLevelDebug ~= nil then
        player:setPerkLevelDebug(perk, level)
    end

    if player.getPerkLevel ~= nil then
        local currentLevel = player:getPerkLevel(perk)

        if currentLevel ~= nil and player.LevelPerk ~= nil then
            while currentLevel < level do
                player:LevelPerk(perk, false)
                local newLevel = player:getPerkLevel(perk)
                if newLevel == nil or newLevel <= currentLevel then
                    break
                end
                currentLevel = newLevel
            end
        end

        if currentLevel ~= nil and player.LoseLevel ~= nil then
            while currentLevel > level do
                player:LoseLevel(perk)
                local newLevel = player:getPerkLevel(perk)
                if newLevel == nil or newLevel >= currentLevel then
                    break
                end
                currentLevel = newLevel
            end
        end
    end

    xp:setXPToLevel(perk, level)
end

-- Fallback legacy solo: conserve intentionnellement comme filet de securite si le flux serveur
-- du mode Challenge / solo regressait. Cette voie n'est pas le chemin nominal.
function LastHomeClient.applyRoleLocally(player, roleKey)
    if player == nil or roleKey == nil then return false end

    local def = ROLE_DEFS[roleKey]
    if def == nil then return false end

    local modData = player:getModData()
    if modData.LH_role ~= nil then return false end

    logClient("applyRoleLocally start - role=" .. tostring(roleKey) .. ", joueur=" .. tostring(player:getUsername() or "?") .. ", coords=" .. formatPlayerCoords(player))

    local inv = player:getInventory()
    local roleBag = nil

    if def.equipped and def.equipped.bag then
        roleBag = inv:AddItem(def.equipped.bag)
    end

    addRoleItems(inv, roleBag, def.equipped and def.equipped.bag or nil, def.items, def.bagContents)
    primeRoleLoadout(inv)

    for _, skillDef in ipairs(def.skills or {}) do
        applyPerkLevel(player, skillDef[1], skillDef[2])
    end

    equipRoleItems(player, inv, def.equipped)
    applyRoleStats(player, def.stats)
    applyCarryProfile(player, roleKey)

    modData.LH_role = roleKey
    modData.LH_localRoleApplied = roleKey

    local roleName = LastHomeRoles.ROLE_NAMES[roleKey] or roleKey
    showRoleAssigned(roleName)

    print("[LastHome] Role applique localement (solo): " .. tostring(roleKey))
    logClient("applyRoleLocally termine - role=" .. tostring(roleKey) .. ", coords=" .. formatPlayerCoords(player))
    return true
end

local function requestRolePicker()
    local player = getPlayer()
    if player == nil then return end

    local modData = player:getModData()
    if modData.LH_role ~= nil then
        logClient("requestRolePicker ignore - role deja choisi: " .. tostring(modData.LH_role))
        return
    end
    if roleRequestSent then return end

    roleRequestSent = true

    if isSinglePlayerRuntime() and soloPickerFallbackAt == nil then
        soloPickerFallbackAt = getNowSeconds() + 3
        logClient("requestRolePicker - fallback solo arme pour t=" .. tostring(soloPickerFallbackAt))
        ensureSoloFallbackTickRegistered()
    end

    logClient("requestRolePicker -> RolePickerReady (solo=" .. tostring(isSinglePlayerRuntime()) .. ", joueur=" .. tostring(player:getUsername() or "?") .. ", coords=" .. formatPlayerCoords(player) .. ")")
    sendClientCommand("LastHome", "RolePickerReady", {
        username = player:getUsername(),
    })
end

local function onCreatePlayer()
    logClient("OnCreatePlayer")
    requestRolePicker()
end
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onGameStart()
    logClient("OnGameStart")
    roleRequestSent = false
    requestRolePicker()
end
Events.OnGameStart.Add(onGameStart)

showRoleAssigned = function(roleName)
    if HaloTextHelper ~= nil and HaloTextHelper.addTextWithArrow ~= nil and HaloTextHelper.getColorGreen ~= nil then
        HaloTextHelper.addTextWithArrow(getPlayer(), "Role: " .. tostring(roleName), true, HaloTextHelper.getColorGreen())
    end
end

local function isLocalUser(data)
    local player = getPlayer()
    return player ~= nil and data ~= nil and data.username == player:getUsername()
end

local function showAlert(data)
    if data == nil or data.text == nil then return end
    if data.username ~= nil and not isLocalUser(data) then return end

    LastHomeClient.alertText = string.gsub(data.text, "\n", " | ")
    LastHomeClient.alertType = data.type or "info"
    LastHomeClient.alertExpiresAt = getNowSeconds() + (data.durationSeconds or 8)
    logBoundaryClient("AlertMessage recu - username=" .. tostring(data.username or "broadcast") .. ", type=" .. tostring(data.type or "info") .. ", text=" .. tostring(LastHomeClient.alertText))
end

local function resetBoundaryState()
    LastHomeClient.boundaryState = {
        status = "inside",
        countdownEndsAt = 0,
    }
    LastHomeClient.boundaryReturnedAt = 0
end

local function updateBoundaryState(data)
    if data == nil then return end
    if data.username ~= nil and not isLocalUser(data) then return end

    local previousState = LastHomeClient.boundaryState or {}
    local prevStatus = previousState.status
    local prevCountdownEndsAt = previousState.countdownEndsAt or 0
    local newStatus = data.status or "inside"
    local newCountdownEndsAt = data.countdownEndsAt or 0

    LastHomeClient.boundaryState = {
        status = newStatus,
        countdownEndsAt = newCountdownEndsAt,
    }

    if prevStatus ~= newStatus or prevCountdownEndsAt ~= newCountdownEndsAt then
        local player = getPlayer()
        logClient("BoundaryState recu - " .. tostring(prevStatus) .. " -> " .. tostring(newStatus) .. ", fin=" .. tostring(newCountdownEndsAt))
        logBoundaryClient("BoundaryState recu - " .. tostring(prevStatus) .. " -> " .. tostring(newStatus) .. ", fin=" .. tostring(newCountdownEndsAt) .. ", phase=" .. tostring((LastHomeClient.waveState or {}).phase) .. ", coords=" .. formatPlayerCoords(player))
    end

    if newStatus == "inside" and (prevStatus == "countdown" or prevStatus == "damaging") then
        LastHomeClient.boundaryReturnedAt = getNowSeconds() + 3
    end
end

local function updateWaveState(data)
    if data == nil then return end

    local previousState = LastHomeClient.waveState or {}
    local previousPhase = previousState.phase or "nil"
    local newPhase = data.phase or "idle"
    local previousHouseLabel = formatHouseLabel(previousState.house)
    local newHouseLabel = formatHouseLabel(data.house)

    LastHomeClient.waveState = {
        phase = newPhase,
        currentWave = data.currentWave or 0,
        nextWave = data.nextWave or 1,
        waveActive = data.waveActive == true,
        remainingSeconds = data.remainingSeconds or 0,
        phaseEndsAt = data.phaseEndsAt or 0,
        durationSeconds = data.durationSeconds or 0,
        directionsText = data.directionsText or "",
        estimatedCount = data.estimatedCount or 0,
        zombieCount = data.zombieCount or 0,
        score = data.score or 0,
        house = data.house,
    }

    if previousPhase ~= newPhase
        or (previousState.currentWave or 0) ~= (data.currentWave or 0)
        or (previousState.nextWave or 0) ~= (data.nextWave or 0)
        or (previousState.waveActive == true) ~= (data.waveActive == true)
        or (previousState.zombieCount or 0) ~= (data.zombieCount or 0)
        or previousHouseLabel ~= newHouseLabel then
        logClient("WaveState recu - phase=" .. tostring(previousPhase) .. " -> " .. tostring(newPhase) .. ", wave=" .. tostring(data.currentWave or 0) .. ", next=" .. tostring(data.nextWave or 1) .. ", house=" .. newHouseLabel)
    end

    local hasBoundary = data.house ~= nil and (data.house.boundary ~= nil or (data.house.boundaryRadius or 0) > 0)
    if newPhase == "idle" or newPhase == "gameover" or not hasBoundary then
        resetBoundaryState()
    end
end

local function drawLine(x, y, text, color)
    local c = color or ALERT_COLORS.info
    getTextManager():DrawString(UIFont.Small, x, y, text, 0, 0, 0, 1)
    getTextManager():DrawString(UIFont.Small, x + 1, y + 1, text, c.r, c.g, c.b, c.a or 1)
end

local function formatClock(totalSeconds)
    totalSeconds = math.max(0, math.floor(totalSeconds or 0))
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return string.format("%02d:%02d", minutes, seconds)
end

local function getRemainingSeconds(state)
    if state == nil then return 0 end
    if state.phaseEndsAt ~= nil and state.phaseEndsAt > 0 then
        return math.max(0, state.phaseEndsAt - getNowSeconds())
    end
    return math.max(0, state.remainingSeconds or 0)
end

local function getLocalBoundaryStatus()
    local player = getPlayer()
    if player == nil then return "inactive", nil, nil end

    local state = LastHomeClient.waveState or {}
    local house = state.house
    local modData = player:getModData()
    local hasRole = modData ~= nil and modData.LH_role ~= nil
    local isDead = modData ~= nil and modData.LH_dead == true
    local isSpectator = LastHomeClient.isSpectator or (modData ~= nil and modData.LH_spectator == true)
    local hasBoundary = house ~= nil and (house.boundary ~= nil or (house.boundaryRadius or 0) > 0)
    local phaseActive = state.phase ~= "idle" and state.phase ~= "gameover"

    if not hasRole or isDead or isSpectator or not hasBoundary or not phaseActive then
        return "inactive", player, house
    end

    local inside = isInsideBoundary == nil or isInsideBoundary(player, house)
    return inside and "inside" or "outside", player, house
end

local function updateLocalBoundaryCheck()
    local newStatus, player, house = getLocalBoundaryStatus()
    local previousStatus = LastHomeClient.localBoundaryStatus or "inactive"
    local now = getNowSeconds()

    if previousStatus ~= newStatus then
        logBoundaryClient("LocalBoundary " .. tostring(previousStatus) .. " -> " .. tostring(newStatus) .. ", coords=" .. formatPlayerCoords(player) .. ", house=" .. formatBoundaryLabel(house) .. ", phase=" .. tostring((LastHomeClient.waveState or {}).phase))
        if newStatus == "inside" and previousStatus == "outside" then
            LastHomeClient.boundaryReturnedAt = now + 3
        end
    end

    LastHomeClient.localBoundaryStatus = newStatus
end

local function syncSoloState()
    if not isSinglePlayerRuntime() then return end

    local now = getNowSeconds()
    if soloStateLastSyncSecond == now then return end
    soloStateLastSyncSecond = now

    local player = getPlayer()
    if player == nil then return end
    if LastHomeWaves == nil or LastHomeWaves.getClientState == nil then return end

    local username = player:getUsername()
    local snapshot = LastHomeWaves.getClientState(username)
    if snapshot == nil then return end

    if snapshot.waveState ~= nil then
        updateWaveState(snapshot.waveState)
    end

    if snapshot.boundaryState ~= nil then
        updateBoundaryState(snapshot.boundaryState)
    end

    if snapshot.spectatorState ~= nil then
        local isSpectator = snapshot.spectatorState.isSpectator == true
        local spawnedThisWave = snapshot.spectatorState.spawnedThisWave == true

        if LastHomeClient.isSpectator ~= isSpectator or LastHomeClient.spectatorSpawnUsed ~= spawnedThisWave then
            logClient("Solo spectator sync - isSpectator=" .. tostring(isSpectator) .. ", spawnUsed=" .. tostring(spawnedThisWave))
        end

        LastHomeClient.isSpectator = isSpectator
        LastHomeClient.spectatorSpawnUsed = spawnedThisWave

        local modData = player:getModData()
        if modData ~= nil then
            modData.LH_spectator = isSpectator
            modData.LH_dead = isSpectator
        end

        if LastHomeClient.isSpectator then
            resetBoundaryState()
        end
    end
end

local function onTickSyncSoloState()
    syncSoloState()
    updateLocalBoundaryCheck()
end
Events.OnTick.Add(onTickSyncSoloState)

local function drawWaveHud()
    local player = getPlayer()
    if player == nil then return end

    if LastHomeClient.alertExpiresAt ~= nil and getNowSeconds() >= LastHomeClient.alertExpiresAt then
        LastHomeClient.alertText = nil
        LastHomeClient.alertExpiresAt = nil
    end

    local state = LastHomeClient.waveState or {}
    local shouldDraw = state.phase ~= "idle" or LastHomeClient.isSpectator or LastHomeClient.alertText ~= nil
    if not shouldDraw then
        local hiddenState = "hidden|" .. tostring(state.phase) .. "|" .. tostring(LastHomeClient.isSpectator) .. "|" .. tostring(LastHomeClient.alertText ~= nil)
        if LastHomeClient._hudTraceState ~= hiddenState then
            LastHomeClient._hudTraceState = hiddenState
            logClient("HUD masque - phase=" .. tostring(state.phase) .. ", spectator=" .. tostring(LastHomeClient.isSpectator) .. ", alert=" .. tostring(LastHomeClient.alertText ~= nil))
        end
        return
    end

    local houseLabel = formatHouseLabel(state.house)
    local visibleState = "visible|" .. tostring(state.phase) .. "|" .. tostring(LastHomeClient.isSpectator) .. "|" .. tostring(LastHomeClient.alertText ~= nil) .. "|" .. houseLabel
    if LastHomeClient._hudTraceState ~= visibleState then
        LastHomeClient._hudTraceState = visibleState
        logClient("HUD visible - phase=" .. tostring(state.phase) .. ", spectator=" .. tostring(LastHomeClient.isSpectator) .. ", alert=" .. tostring(LastHomeClient.alertText ~= nil) .. ", house=" .. houseLabel)
    end

    local HUD_WIDTH = 280
    local screenW = getCore():getScreenWidth()
    local x = screenW - HUD_WIDTH - 20
    local y = 120
    local remainingSeconds = getRemainingSeconds(state)

    drawLine(x, y, "[Last Home]", ALERT_COLORS.info)
    y = y + 18

    if state.house ~= nil and state.house.name ~= nil then
        drawLine(x, y, "Base: " .. tostring(state.house.name), ALERT_COLORS.info)
        y = y + 16
    end

    if state.phase == "prep" then
        drawLine(x, y, string.format("Preparation - Vague %d dans %s", state.nextWave or 1, formatClock(remainingSeconds)), ALERT_COLORS.info)
        y = y + 16
        drawLine(x, y, "Direction: " .. tostring(state.directionsText or "?"), ALERT_COLORS.info)
        y = y + 16
        drawLine(x, y, "Taille estimee: ~" .. tostring(state.estimatedCount or 0) .. " zombies", ALERT_COLORS.info)
        y = y + 16
    elseif state.phase == "wave" then
        drawLine(x, y, string.format("Vague %d active - %s restantes", state.currentWave or 0, formatClock(remainingSeconds)), ALERT_COLORS.warning)
        y = y + 16
        drawLine(x, y, "Directions: " .. tostring(state.directionsText or "?"), ALERT_COLORS.info)
        y = y + 16
        drawLine(x, y, "Zombies restants: " .. tostring(state.zombieCount or 0), ALERT_COLORS.info)
        y = y + 16
    elseif state.phase == "gameover" then
        drawLine(x, y, "Game over - score: " .. tostring(state.score or 0) .. " vague(s)", ALERT_COLORS.danger)
        y = y + 16
    end

    if LastHomeClient.isSpectator then
        drawLine(x, y, "Mode spectateur", ALERT_COLORS.danger)
        y = y + 16

        if state.waveActive then
            local message = LastHomeClient.spectatorSpawnUsed and "Spawn zombie utilise pour cette vague" or "Clique droit dehors pour spawner 1 zombie"
            drawLine(x, y, message, ALERT_COLORS.warning)
            y = y + 16
        else
            drawLine(x, y, "Le spawn spectateur revient a la prochaine vague", ALERT_COLORS.info)
            y = y + 16
        end
    else
        local boundaryState = LastHomeClient.boundaryState or {}
        if LastHomeClient.localBoundaryStatus == "inside" then
            drawLine(x, y, "Zone: IN", ALERT_COLORS.success)
            y = y + 16
        elseif LastHomeClient.localBoundaryStatus == "outside" then
            drawLine(x, y, "Zone: OUT", ALERT_COLORS.danger)
            y = y + 16
        end

        if boundaryState.status == "countdown" then
            local boundaryRemaining = math.ceil(math.max(0, (boundaryState.countdownEndsAt or 0) - getNowSeconds()))
            drawLine(x, y, string.format("Hors zone ! Revenez dans %ds", boundaryRemaining), ALERT_COLORS.danger)
            y = y + 16
        elseif boundaryState.status == "damaging" then
            local blink = math.floor(getNowSeconds() * 2) % 2 == 0
            if blink then
                drawLine(x, y, "Hors zone ! Degats actifs", ALERT_COLORS.danger)
            end
            y = y + 16
        elseif LastHomeClient.localBoundaryStatus == "outside" then
            drawLine(x, y, "Hors zone ! Retournez vers la base", ALERT_COLORS.danger)
            y = y + 16
        end

        local now = getNowSeconds()
        if LastHomeClient.boundaryReturnedAt > 0 and now < LastHomeClient.boundaryReturnedAt then
            drawLine(x, y, "De retour dans la zone", ALERT_COLORS.success)
            y = y + 16
        elseif LastHomeClient.boundaryReturnedAt > 0 and now >= LastHomeClient.boundaryReturnedAt then
            LastHomeClient.boundaryReturnedAt = 0
        end
    end

    if LastHomeClient.alertText ~= nil then
        local color = ALERT_COLORS[LastHomeClient.alertType] or ALERT_COLORS.info
        drawLine(x, y + 8, LastHomeClient.alertText, color)
    end
end
Events.OnPostUIDraw.Add(drawWaveHud)

local function getContextSquare(worldobjects)
    if worldobjects == nil then return nil end

    if worldobjects.size ~= nil and worldobjects.get ~= nil then
        for index = 0, worldobjects:size() - 1 do
            local object = worldobjects:get(index)
            if object ~= nil and object.getSquare ~= nil then
                local square = object:getSquare()
                if square ~= nil then
                    return square
                end
            end
        end
        return nil
    end

    for _, object in ipairs(worldobjects) do
        if object ~= nil and object.getSquare ~= nil then
            local square = object:getSquare()
            if square ~= nil then
                return square
            end
        end
    end

    return nil
end

local function requestSpectatorSpawn(square)
    if square == nil then return end

    sendClientCommand("LastHome", "SpectatorSpawnZombie", {
        x = square:getX(),
        y = square:getY(),
        z = square:getZ(),
    })
end

local function onFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    if test then return end
    if context == nil or not LastHomeClient.isSpectator then return end

    local state = LastHomeClient.waveState or {}
    local square = getContextSquare(worldobjects)
    if square == nil then return end

    local option = context:addOption("Spawner un zombie ici", square, requestSpectatorSpawn)
    if not state.waveActive or LastHomeClient.spectatorSpawnUsed then
        option.notAvailable = true
        return
    end

    if square.isOutside ~= nil and not square:isOutside() then
        option.notAvailable = true
    end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

local function onPlayerDeath(player)
    if player == nil then return end

    local localPlayer = getPlayer()
    if localPlayer == nil or player ~= localPlayer then return end

    local modData = player:getModData()
    if modData.LH_deathReported then return end

    modData.LH_deathReported = true
    sendClientCommand("LastHome", "PlayerDied", {
        x = player:getX(),
        y = player:getY(),
        z = player:getZ(),
    })
end
Events.OnPlayerDeath.Add(onPlayerDeath)

local function onServerCommand(module, command, data)
    if module ~= "LastHome" then return end

    logClient("OnServerCommand - " .. tostring(command) .. ", username=" .. tostring(data and data.username or "broadcast"))

    if command == "OpenRolePicker" then
        roleRequestSent = false
    elseif command == "RoleAssigned" then
        local player = getPlayer()
        if player ~= nil and data ~= nil and data.username == player:getUsername() then
            player:getModData().LH_role = data.role
            showRoleAssigned(data.roleName or data.role)
            print("[LastHome] Client: role recu - " .. tostring(data.roleName or data.role))
        end
    elseif command == "RoleDenied" or command == "RoleUnavailable" then
        roleRequestSent = false
        print("[LastHome] Client: role refuse/indisponible - " .. tostring(data and data.text or "?"))
    elseif command == "WaveState" then
        updateWaveState(data)
    elseif command == "BoundaryState" then
        logBoundaryClient("OnServerCommand BoundaryState - username=" .. tostring(data and data.username or "broadcast") .. ", status=" .. tostring(data and data.status or "nil") .. ", fin=" .. tostring(data and data.countdownEndsAt or 0))
        updateBoundaryState(data)
    elseif command == "AlertMessage" then
        logBoundaryClient("OnServerCommand AlertMessage - username=" .. tostring(data and data.username or "broadcast") .. ", type=" .. tostring(data and data.type or "info") .. ", text=" .. tostring(data and data.text or "nil"))
        showAlert(data)
    elseif command == "SpectatorState" then
        if isLocalUser(data) then
            LastHomeClient.isSpectator = data.isSpectator == true
            LastHomeClient.spectatorSpawnUsed = data.spawnedThisWave == true

            local player = getPlayer()
            if player ~= nil then
                local modData = player:getModData()
                modData.LH_spectator = LastHomeClient.isSpectator
                modData.LH_dead = LastHomeClient.isSpectator
            end
            if LastHomeClient.isSpectator then
                resetBoundaryState()
            end
            print("[LastHome] Client: SpectatorState - isSpectator=" .. tostring(LastHomeClient.isSpectator) .. ", spawnUsed=" .. tostring(LastHomeClient.spectatorSpawnUsed))
        end
    elseif command == "GameOver" then
        if LastHomeClient.waveState ~= nil then
            LastHomeClient.waveState.phase = "gameover"
            LastHomeClient.waveState.score = data and data.score or LastHomeClient.waveState.score
            resetBoundaryState()
            print("[LastHome] Client: GameOver recu - score=" .. tostring(LastHomeClient.waveState.score))
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)
print("[LastHome] LastHomeClient pret - handlers: OnCreatePlayer, OnGameStart, OnTick(sync solo), OnPostUIDraw, OnFillWorldObjectContextMenu, OnPlayerDeath, OnServerCommand")
