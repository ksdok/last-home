require "LastHomeRolePicker"
require "LastHomeRoles"
require "LastHomeShared"

LastHomeClient = LastHomeClient or {}

local roleRequestSent = false
local getNowSeconds = LastHomeShared.getNowSeconds

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
}
LastHomeClient.alertText = nil
LastHomeClient.alertType = "info"
LastHomeClient.alertExpiresAt = nil
LastHomeClient.isSpectator = false
LastHomeClient.spectatorSpawnUsed = false

local ALERT_COLORS = {
    info = {r = 0.9, g = 0.9, b = 0.9, a = 1},
    success = {r = 0.35, g = 0.95, b = 0.45, a = 1},
    warning = {r = 1, g = 0.85, b = 0.25, a = 1},
    danger = {r = 1, g = 0.45, b = 0.45, a = 1},
}

local function requestRolePicker()
    local player = getPlayer()
    if player == nil then return end

    local modData = player:getModData()
    if modData.LH_role ~= nil then return end
    if roleRequestSent then return end

    roleRequestSent = true
    sendClientCommand("LastHome", "RolePickerReady", {
        username = player:getUsername(),
    })
end

local function onCreatePlayer()
    requestRolePicker()
end
Events.OnCreatePlayer.Add(onCreatePlayer)

local function onGameStart()
    requestRolePicker()
end
Events.OnGameStart.Add(onGameStart)

local function showRoleAssigned(roleName)
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
end

local function updateWaveState(data)
    if data == nil then return end

    LastHomeClient.waveState = {
        phase = data.phase or "idle",
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
    }
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

local function drawWaveHud()
    local player = getPlayer()
    if player == nil then return end

    if LastHomeClient.alertExpiresAt ~= nil and getNowSeconds() >= LastHomeClient.alertExpiresAt then
        LastHomeClient.alertText = nil
        LastHomeClient.alertExpiresAt = nil
    end

    local state = LastHomeClient.waveState or {}
    local shouldDraw = state.phase ~= "idle" or LastHomeClient.isSpectator or LastHomeClient.alertText ~= nil
    if not shouldDraw then return end

    local x = 20
    local y = 120
    local remainingSeconds = getRemainingSeconds(state)

    drawLine(x, y, "[Last Home]", ALERT_COLORS.info)
    y = y + 18

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

    if command == "OpenRolePicker" then
        roleRequestSent = false
    elseif command == "RoleAssigned" then
        local player = getPlayer()
        if player ~= nil and data ~= nil and data.username == player:getUsername() then
            player:getModData().LH_role = data.role
            showRoleAssigned(data.roleName or data.role)
        end
    elseif command == "RoleDenied" or command == "RoleUnavailable" then
        roleRequestSent = false
    elseif command == "WaveState" then
        updateWaveState(data)
    elseif command == "AlertMessage" then
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
        end
    elseif command == "GameOver" then
        if LastHomeClient.waveState ~= nil then
            LastHomeClient.waveState.phase = "gameover"
            LastHomeClient.waveState.score = data and data.score or LastHomeClient.waveState.score
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)
