require "LastHomeRolePicker"
require "LastHomeRoles"
require "LastHomeShared"

LastHomeClient = LastHomeClient or {}

print("[LastHome] LastHomeClient charge")

local roleRequestSent = false
local soloPickerFallbackAt = nil
local soloFallbackTickRegistered = false
local getNowSeconds = LastHomeShared.getNowSeconds

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

local ALERT_COLORS = {
    info = {r = 0.9, g = 0.9, b = 0.9, a = 1},
    success = {r = 0.35, g = 0.95, b = 0.45, a = 1},
    warning = {r = 1, g = 0.85, b = 0.25, a = 1},
    danger = {r = 1, g = 0.45, b = 0.45, a = 1},
}

local function ensureSoloFallbackTickRegistered()
    if soloFallbackTickRegistered then return end
    Events.OnTick.Add(LastHomeClient.TickRolePickerFallback)
    soloFallbackTickRegistered = true
end

local function unregisterSoloFallbackTick()
    if not soloFallbackTickRegistered then return end
    Events.OnTick.Remove(LastHomeClient.TickRolePickerFallback)
    soloFallbackTickRegistered = false
end

LastHomeClient.TickRolePickerFallback = function()
    if soloPickerFallbackAt == nil then
        unregisterSoloFallbackTick()
        return
    end

    if not isSinglePlayerRuntime() then
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

local function equipRoleItems(player, inv, equipped)
    if player == nil or inv == nil or equipped == nil then return end

    if equipped.primary then
        local primary = inv:FindAndReturn(equipped.primary)
        if primary then player:setPrimaryHandItem(primary) end
    end

    if equipped.secondary then
        local secondary = inv:FindAndReturn(equipped.secondary)
        if secondary then player:setSecondaryHandItem(secondary) end
    end

    if equipped.bag then
        local bag = inv:FindAndReturn(equipped.bag)
        if bag then player:setClothingItem_Back(bag) end
    end

    if equipped.clothes then
        for _, clothId in ipairs(equipped.clothes) do
            local cloth = inv:FindAndReturn(clothId)
            if cloth and cloth:getBodyLocation() ~= nil then
                player:setWornItem(cloth:getBodyLocation(), cloth)
            end
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

function LastHomeClient.applyRoleLocally(player, roleKey)
    if player == nil or roleKey == nil then return false end

    local def = ROLE_DEFS[roleKey]
    if def == nil then return false end

    local modData = player:getModData()
    if modData.LH_role ~= nil then return false end

    local inv = player:getInventory()
    local roleBag = nil

    if def.equipped and def.equipped.bag then
        roleBag = inv:AddItem(def.equipped.bag)
    end

    addRoleItems(inv, roleBag, def.equipped and def.equipped.bag or nil, def.items, def.bagContents)

    for _, skillDef in ipairs(def.skills or {}) do
        applyPerkLevel(player, skillDef[1], skillDef[2])
    end

    equipRoleItems(player, inv, def.equipped)
    applyRoleStats(player, def.stats)

    if player.setUnlimitedCarry ~= nil then
        player:setUnlimitedCarry(roleKey == "builder")
    end

    modData.LH_role = roleKey
    modData.LH_localRoleApplied = roleKey

    print("[LastHome] Role applique localement (solo): " .. tostring(roleKey))
    return true
end

local function requestRolePicker()
    local player = getPlayer()
    if player == nil then return end

    local modData = player:getModData()
    if modData.LH_role ~= nil then return end
    if roleRequestSent then return end

    roleRequestSent = true

    if isSinglePlayerRuntime() and soloPickerFallbackAt == nil then
        soloPickerFallbackAt = getNowSeconds() + 3
        ensureSoloFallbackTickRegistered()
    end

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
        house = data.house,
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
            print("[LastHome] Client: role recu - " .. tostring(data.roleName or data.role))
        end
    elseif command == "RoleDenied" or command == "RoleUnavailable" then
        roleRequestSent = false
        print("[LastHome] Client: role refuse/indisponible - " .. tostring(data and data.text or "?"))
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
            print("[LastHome] Client: SpectatorState - isSpectator=" .. tostring(LastHomeClient.isSpectator) .. ", spawnUsed=" .. tostring(LastHomeClient.spectatorSpawnUsed))
        end
    elseif command == "GameOver" then
        if LastHomeClient.waveState ~= nil then
            LastHomeClient.waveState.phase = "gameover"
            LastHomeClient.waveState.score = data and data.score or LastHomeClient.waveState.score
            print("[LastHome] Client: GameOver recu - score=" .. tostring(LastHomeClient.waveState.score))
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)
print("[LastHome] LastHomeClient pret - handlers: OnCreatePlayer, OnGameStart, OnPostUIDraw, OnFillWorldObjectContextMenu, OnPlayerDeath, OnServerCommand")
