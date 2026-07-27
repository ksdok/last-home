require "LastHomeRoles"
require "LastHomeShared"
require "LastHomeWaves"
require "LastHomeStock"

LastHomeServer = LastHomeServer or {}

print("[LastHome] LastHomeServer charge")

local Server = {
    assignedRoles = {},
    roleLoadouts = {},
    selectedHouse = nil,
    houseSelectionLocked = false,
    nextBuilderRefillAt = nil,
    lastBuilderTickSecond = nil,
    pendingPostSpawnMaintenance = nil,
    stockGroundSpawned = false,
}

local ROLE_DEFS = LastHomeRoles.ROLE_DEFS
local ROLE_NAMES = LastHomeRoles.ROLE_NAMES
local BUILDER_REFILL_ITEMS = LastHomeRoles.BUILDER_REFILL_ITEMS
local COMMUNITY_STOCK_ITEMS = LastHomeRoles.COMMUNITY_STOCK_ITEMS or BUILDER_REFILL_ITEMS
local SPAWN_AMBIENT_CLEANUP_PADDING = 8

-- Stock ground spawn and post-spawn maintenance extracted to LastHomeStock.
local ensureStockOnGround = function(house) return LastHomeStock.ensureOnGround(house, COMMUNITY_STOCK_ITEMS) end
local spawnStockOnGround = function(house) return LastHomeStock.spawnOnGround(house, COMMUNITY_STOCK_ITEMS) end
local schedulePostSpawnMaintenance = LastHomeStock.scheduleMaintenance

local getScenarioPlayers = LastHomeShared.getScenarioPlayers
local getNowSeconds = LastHomeShared.getNowSeconds
local getRandomHouse = LastHomeShared.getRandomHouse
local getHouseSpawnCandidates = LastHomeShared.getHouseSpawnCandidates
local getHouseStockSpawn = LastHomeShared.getHouseStockSpawn
local applyCarryProfile = LastHomeShared.applyCarryProfile
local primeRoleLoadout = LastHomeShared.primeRoleLoadout
local equipRoleItems = LastHomeShared.equipRoleItems

-- Aliases to shared utilities (no local duplication)
local logServer = function(msg) LastHomeShared.log("Server", msg) end
local formatCoords = LastHomeShared.formatCoords
local formatHouseLabel = LastHomeShared.formatHouseLabel
local formatPlayerCoords = LastHomeShared.formatPlayerCoords
local applyManualTeleportState = LastHomeShared.applyManualTeleportState
local addItemsToContainer = LastHomeShared.addItemsToContainer
local buildItemCounts = LastHomeShared.buildItemCounts
local addRoleItems = LastHomeShared.addRoleItems
local applyRoleStats = LastHomeShared.applyRoleStats
local applyPerkLevel = LastHomeShared.applyPerkLevel

-- Wire LastHomeStock into the server state.
LastHomeStock.attach(Server, {
    getHouseStockSpawn = getHouseStockSpawn,
    getNowSeconds = getNowSeconds,
    round = LastHomeShared.round,
    formatCoords = formatCoords,
})

local function syncSelectedHouse()
    if Server.selectedHouse == nil then return end

    if LastHomeWaves ~= nil and LastHomeWaves.setHouse ~= nil then
        LastHomeWaves.setHouse(Server.selectedHouse)
    end
end

local function ensureSelectedHouse()
    if Server.selectedHouse ~= nil then
        syncSelectedHouse()
        return Server.selectedHouse
    end

    local house = getRandomHouse ~= nil and getRandomHouse() or nil
    if house == nil then
        print("[LastHome] ERREUR: aucune maison disponible dans HOUSE_DEFS")
        return nil
    end

    house.source = "rotation"
    Server.selectedHouse = house
    Server.houseSelectionLocked = true
    syncSelectedHouse()

    print("[LastHome] Maison choisie: " .. tostring(house.name or house.id or "?") .. " (" .. tostring(house.centerX) .. ", " .. tostring(house.centerY) .. ", " .. tostring(house.centerZ or 0) .. ")")
    return Server.selectedHouse
end

-- True once a scenario/challenge house has been selected. Used by the bootstrap
-- idempotency guard (cleared by resetState, so a re-host in the same process
-- re-bootstraps).
function LastHomeServer.hasSelectedHouse()
    return Server.selectedHouse ~= nil
end

-- Stock functions (getStockGroundSquares, getStockWorldItemOffset, spawnStockOnGround,
-- ensureStockOnGround) extracted to LastHomeStock. Wrappers defined above.

local function isUsableSpawnSquare(square)
    if square == nil then return false end

    if square.isFree ~= nil then
        local ok, isFree = pcall(function()
            return square:isFree(false)
        end)

        if ok then
            return isFree == true
        end
    end

    return true
end

local function pickHouseSpawnPoint(house)
    if house == nil then return nil, nil, nil end

    local candidates = getHouseSpawnCandidates ~= nil and getHouseSpawnCandidates(house) or nil
    local candidateCount = candidates ~= nil and #candidates or 0
    if candidates == nil or candidateCount == 0 then
        logServer("pickHouseSpawnPoint fallback centre pour " .. formatHouseLabel(house))
        return house.centerX, house.centerY, house.centerZ or 0
    end

    local startIndex = 1
    if ZombRand ~= nil then
        startIndex = ZombRand(candidateCount) + 1
    elseif math ~= nil and math.random ~= nil then
        startIndex = math.random(candidateCount)
    end

    local cell = getCell ~= nil and getCell() or nil
    if cell == nil then
        local fallback = candidates[startIndex]
        logServer("pickHouseSpawnPoint sans cell -> fallback candidat #" .. tostring(startIndex) .. "/" .. tostring(candidateCount) .. " pour " .. formatHouseLabel(house) .. " => " .. formatCoords(fallback.x, fallback.y, fallback.z or house.centerZ or 0))
        return fallback.x, fallback.y, fallback.z or house.centerZ or 0
    end

    for offset = 0, candidateCount - 1 do
        local index = ((startIndex + offset - 1) % candidateCount) + 1
        local candidate = candidates[index]
        local square = cell:getGridSquare(candidate.x, candidate.y, candidate.z or house.centerZ or 0)
        if isUsableSpawnSquare(square) then
            logServer("pickHouseSpawnPoint selectionne candidat #" .. tostring(index) .. "/" .. tostring(candidateCount) .. " pour " .. formatHouseLabel(house) .. " => " .. formatCoords(square:getX(), square:getY(), square:getZ()))
            return square:getX(), square:getY(), square:getZ()
        end
    end

    logServer("pickHouseSpawnPoint aucun candidat libre pour " .. formatHouseLabel(house) .. " (candidats=" .. tostring(candidateCount) .. ") -> fallback candidat #" .. tostring(startIndex))
    -- teleport (setX/setY/setZ) places the player regardless of whether the
    -- square is "free"; PZ resolves overlap. Better to teleport onto a
    -- designated spawn point than leave the player at the default spawn.
    local fallback = candidates[startIndex]
    return fallback.x, fallback.y, fallback.z or house.centerZ or 0
end

local function getSpawnCleanupArea(house, spawnData)
    local padding = house ~= nil and (house.spawnAmbientCleanupPadding or SPAWN_AMBIENT_CLEANUP_PADDING) or SPAWN_AMBIENT_CLEANUP_PADDING

    if house ~= nil and house.boundary ~= nil then
        local boundary = house.boundary
        if boundary.minX ~= nil and boundary.maxX ~= nil and boundary.minY ~= nil and boundary.maxY ~= nil then
            return {
                minX = boundary.minX - padding,
                maxX = boundary.maxX + padding,
                minY = boundary.minY - padding,
                maxY = boundary.maxY + padding,
                label = "boundary",
            }
        end
    end

    local bounds = house ~= nil and house.bounds or nil
    if bounds ~= nil and bounds.min ~= nil and bounds.max ~= nil then
        return {
            minX = bounds.min.x - padding,
            maxX = bounds.max.x + padding,
            minY = bounds.min.y - padding,
            maxY = bounds.max.y + padding,
            label = "bounds",
        }
    end

    local x = spawnData ~= nil and spawnData.x or 0
    local y = spawnData ~= nil and spawnData.y or 0
    return {
        minX = x - padding,
        maxX = x + padding,
        minY = y - padding,
        maxY = y + padding,
        label = "point",
    }
end

local function clearAmbientZombiesNearSpawn(house, spawnData, reason)
    if house == nil or spawnData == nil then return 0 end

    local cell = getCell ~= nil and getCell() or nil
    if cell == nil or cell.getZombieList == nil then
        return 0
    end

    local zombies = cell:getZombieList()
    if zombies == nil then
        return 0
    end

    local area = getSpawnCleanupArea(house, spawnData)
    local removed = 0
    for i = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(i)
        if zombie ~= nil and zombie.getSquare ~= nil and zombie:getSquare() ~= nil then
            local modData = zombie:getModData()
            local isWaveZombie = modData ~= nil and modData.LH_waveZombie == true and modData.LH_countedDead ~= true
            if not isWaveZombie then
                local zx = zombie:getX()
                local zy = zombie:getY()
                if zx >= area.minX and zx <= area.maxX and zy >= area.minY and zy <= area.maxY then
                    zombie:removeFromWorld()
                    zombie:removeFromSquare()
                    removed = removed + 1
                end
            end
        end
    end

    print("[LastHome] Nettoyage zombies spawn (" .. tostring(reason or "unknown") .. ") pour " .. tostring(house.name or house.id or "?") .. " via " .. tostring(area.label) .. " dans [" .. tostring(area.minX) .. "," .. tostring(area.minY) .. "] -> [" .. tostring(area.maxX) .. "," .. tostring(area.maxY) .. "]: " .. tostring(removed) .. " supprimes")
    return removed
end

-- processPostSpawnMaintenance is defined here (after ensureSelectedHouse and
-- clearAmbientZombiesNearSpawn) so the closure captures the real locals, not
-- nil globals. Forward-ref closure bug from the LH-17 refactor (same class as
-- the notifyPlayer bug fixed in 2a0e5c6).
local processPostSpawnMaintenance = function(now) LastHomeStock.processMaintenance(now, COMMUNITY_STOCK_ITEMS, ensureSelectedHouse, clearAmbientZombiesNearSpawn) end

-- schedulePostSpawnMaintenance and processPostSpawnMaintenance extracted to
-- LastHomeStock. Wrappers defined above (ensureStockOnGround/spawnStockOnGround)
-- and below (processPostSpawnMaintenance).

local function teleportPlayerToHouse(player)
    if player == nil then return false, nil end

    local username = player:getUsername() or "?"
    local modData = player:getModData()
    if modData ~= nil and (modData.LH_dead or modData.LH_spectator) then
        logServer("teleport ignore pour " .. tostring(username) .. " (dead=" .. tostring(modData.LH_dead) .. ", spectator=" .. tostring(modData.LH_spectator) .. ")")
        return false, nil
    end

    local house = ensureSelectedHouse()
    if house == nil then return false, nil end
    if modData ~= nil and modData.LH_houseSpawnId == house.id then
        logServer("teleport ignore pour " .. tostring(username) .. " - deja spawne sur " .. formatHouseLabel(house) .. " depuis " .. formatPlayerCoords(player))
        return false, nil
    end

    local beforeCoords = formatPlayerCoords(player)
    local x, y, z = pickHouseSpawnPoint(house)
    if x == nil or y == nil or z == nil then
        print("[LastHome] WARN: pickHouseSpawnPoint a echoue pour " .. tostring(username) .. " (maison=" .. tostring(house.name or house.id or "?") .. ", candidats=" .. tostring(getHouseSpawnCandidates ~= nil and #(getHouseSpawnCandidates(house) or {}) or 0) .. ")")
        return false, nil
    end

    local spawnData = {
        x = x,
        y = y,
        z = z,
        houseId = house.id,
    }

    local teleported = false
    local teleportMode = "manual"
    if GameServer ~= nil and GameServer.sendTeleport ~= nil then
        local ok, err = pcall(function()
            GameServer.sendTeleport(player, x, y, z)
        end)
        if ok then
            teleported = true
            teleportMode = "GameServer.sendTeleport"
        else
            teleportMode = "manual(GameServer.sendTeleport error=" .. tostring(err) .. ")"
        end
    else
        teleportMode = "manual(GameServer.sendTeleport indisponible)"
    end

    if not teleported then
        applyManualTeleportState(player, x, y, z)
        teleported = true
    end

    if modData ~= nil then
        modData.LH_houseSpawnId = house.id
    end

    clearAmbientZombiesNearSpawn(house, spawnData, "role-spawn")
    ensureStockOnGround(house)
    schedulePostSpawnMaintenance(house, spawnData, username)
    logServer("teleport joueur " .. tostring(username) .. " : " .. beforeCoords .. " -> " .. formatCoords(x, y, z) .. " pour " .. formatHouseLabel(house) .. " via " .. tostring(teleportMode))
    return teleported, spawnData
end

local function warnTeleportFailure(player, context)
    local username = player and player.getUsername and player:getUsername() or "?"
    print("[LastHome] WARN: teleport vers la maison echoue pour " .. tostring(username) .. " (" .. tostring(context or "unknown") .. ")")
end

local function applyRole(player, roleKey)
    if player == nil or roleKey == nil then return false end

    local def = ROLE_DEFS[roleKey]
    if def == nil then return false end

    local username = player:getUsername()
    local modData = player:getModData()
    modData.LH_role = roleKey

    if username ~= nil and Server.roleLoadouts[username] == roleKey then
        applyCarryProfile(player, roleKey)
        return false
    end

    -- MP: items + equipment are applied CLIENT-SIDE on RoleAssigned (applyRoleLocally).
    -- Server-side inventory/equipment grants do not reliably replicate to the
    -- client in MP, and adding them on both sides would duplicate. The client's
    -- inventory is the authoritative synced copy (client -> server). The server
    -- keeps the authoritative parts: skills, stats, carry (these replicate),
    -- modData.LH_role, and the role-loadout tracking.
    for _, skillDef in ipairs(def.skills or {}) do
        applyPerkLevel(player, skillDef[1], skillDef[2])
    end
    applyRoleStats(player, def.stats)
    applyCarryProfile(player, roleKey)

    if username ~= nil then
        Server.roleLoadouts[username] = roleKey
        Server.assignedRoles[username] = roleKey
    end

    return true
end

local function countContainerItemsRecursive(container, itemId)
    if container == nil or itemId == nil or container.getItems == nil then return 0 end

    local items = container:getItems()
    if items == nil then return 0 end

    local total = 0
    for i = 0, items:size() - 1 do
        local entry = items:get(i)
        if entry ~= nil and entry.getFullType ~= nil and entry:getFullType() == itemId then
            total = total + 1
        end

        local childContainer = entry and entry.getItemContainer and entry:getItemContainer() or nil
        if childContainer ~= nil then
            total = total + countContainerItemsRecursive(childContainer, itemId)
        end
    end

    return total
end

local function refillBuilderResources()
    for _, player in ipairs(getScenarioPlayers()) do
        local modData = player:getModData()
        if modData.LH_role == "builder" then
            local inv = player:getInventory()

            for _, refillDef in ipairs(BUILDER_REFILL_ITEMS) do
                local itemId = refillDef[1]
                local targetCount = refillDef[2]
                local currentCount = countContainerItemsRecursive(inv, itemId)
                local needed = targetCount - currentCount

                if needed > 1 then
                    inv:AddItems(itemId, needed)
                elseif needed == 1 then
                    inv:AddItem(itemId)
                end
            end
        end
    end
end

local function onBuilderRefillTick()
    local now = getNowSeconds()
    if now == Server.lastBuilderTickSecond then return end
    Server.lastBuilderTickSecond = now

    processPostSpawnMaintenance(now)

    if Server.nextBuilderRefillAt == nil then
        if Server.selectedHouse ~= nil then
            ensureStockOnGround(Server.selectedHouse)
        end
        Server.nextBuilderRefillAt = now + 600
        return
    end

    if now < Server.nextBuilderRefillAt then return end

    refillBuilderResources()
    if Server.selectedHouse ~= nil then
        ensureStockOnGround(Server.selectedHouse)
    end
    repeat
        Server.nextBuilderRefillAt = Server.nextBuilderRefillAt + 600
    until Server.nextBuilderRefillAt > now
end
Events.OnTick.Add(onBuilderRefillTick)

local function sendRoleAssigned(username, roleKey, options)
    local payload = {
        username = username,
        role = roleKey,
        roleName = ROLE_NAMES[roleKey] or roleKey,
        applyItems = options ~= nil and options.applyItems == true,
    }

    local spawn = options ~= nil and options.spawn or nil
    if spawn ~= nil then
        payload.spawnX = spawn.x
        payload.spawnY = spawn.y
        payload.spawnZ = spawn.z
        payload.houseId = spawn.houseId
    end

    sendServerCommand("LastHome", "RoleAssigned", payload)
end

local function notifyWavesRoleAssigned()
    local house = ensureSelectedHouse()
    if house ~= nil then
        ensureStockOnGround(house)
    end

    if LastHomeWaves ~= nil and LastHomeWaves.ensureScenarioStarted ~= nil then
        LastHomeWaves.ensureScenarioStarted()
    end
end

local function sendRoleUnavailable(username, text)
    sendServerCommand("LastHome", "RoleUnavailable", {
        username = username,
        text = text,
    })
end

local function restoreAssignedRole(player)
    if player == nil then return nil, nil end

    local username = player:getUsername()
    if username == nil then return nil, nil end

    local roleKey = Server.assignedRoles[username]
    if roleKey == nil then
        local persistedRole = player:getModData().LH_role
        if persistedRole ~= nil and ROLE_DEFS[persistedRole] ~= nil then
            roleKey = persistedRole
            Server.assignedRoles[username] = persistedRole
        end
    end

    if roleKey ~= nil and ROLE_DEFS[roleKey] ~= nil then
        applyRole(player, roleKey)
        local teleported, spawn = teleportPlayerToHouse(player)
        if not teleported then
            warnTeleportFailure(player, "restoreAssignedRole")
        end
        return roleKey, spawn
    end

    return nil, nil
end

function LastHomeServer.setSelectedHouse(houseId, source, actorUsername)
    if houseId == nil then return false end

    local selectionSource = source or "challenge"
    local teleportContext = selectionSource == "challenge"
        and "SetHouse"
        or ("setSelectedHouse:" .. tostring(selectionSource))
    local ctx = (selectionSource == "challenge")
        and ("actor=" .. tostring(actorUsername or "?"))
        or ("source=" .. tostring(selectionSource))
    local wavesStarted = LastHomeWaves ~= nil
        and LastHomeWaves.hasStarted ~= nil
        and LastHomeWaves.hasStarted() == true

    if wavesStarted then
        local reason = (Server.selectedHouse ~= nil and Server.selectedHouse.id == houseId)
            and "car la maison est deja selectionnee"
            or "car les vagues ont demarree"
        print("[LastHome] WARN: setSelectedHouse ignore (" .. ctx .. ", houseId=" .. tostring(houseId) .. ") " .. reason)
        return false
    end

    if Server.selectedHouse ~= nil
        and Server.selectedHouse.id == houseId
        and Server.selectedHouse.source == selectionSource then
        print("[LastHome] setSelectedHouse ignore (" .. ctx .. ", houseId=" .. tostring(houseId) .. ") car la maison est deja selectionnee")
        return false
    end

    local house = LastHomeShared.getHouseById(houseId)
    if house == nil then
        print("[LastHome] WARN: setSelectedHouse ignore (" .. ctx .. ", houseId inconnu=" .. tostring(houseId) .. ")")
        return false
    end

    local previousHouse = Server.selectedHouse
    house.source = selectionSource
    Server.selectedHouse = house
    Server.houseSelectionLocked = true
    if previousHouse == nil or previousHouse.id ~= house.id then
        Server.stockGroundSpawned = false
    end
    syncSelectedHouse()
    ensureStockOnGround(house)

    for _, scenarioPlayer in ipairs(getScenarioPlayers()) do
        local modData = scenarioPlayer:getModData()
        if modData ~= nil and modData.LH_role ~= nil then
            modData.LH_houseSpawnId = nil
            if not teleportPlayerToHouse(scenarioPlayer) then
                warnTeleportFailure(scenarioPlayer, teleportContext)
            end
        end
    end

    if previousHouse ~= nil and previousHouse.id ~= nil and previousHouse.id ~= house.id then
        print("[LastHome] Maison remplacee: " .. tostring(previousHouse.id) .. " -> " .. tostring(house.id))
    end

    print("[LastHome] Maison selectionnee (" .. ctx .. "): " .. tostring(house.name or house.id))
    return true
end

local function onClientCommand(module, command, player, data)
    if module ~= "LastHome" then return end

    local username = player and player:getUsername() or nil
    if username == nil then return end

    if command == "RolePickerReady" then
        logServer("Commande RolePickerReady recue de " .. tostring(username) .. " depuis " .. formatPlayerCoords(player))
        ensureSelectedHouse()

        local roleKey, spawn = restoreAssignedRole(player)
        if roleKey ~= nil then
            sendRoleAssigned(username, roleKey, {
                applyItems = false,
                spawn = spawn,
            })
            notifyWavesRoleAssigned()
            return
        end

        sendServerCommand("LastHome", "OpenRolePicker", {
            username = username,
        })
        return
    end

    if command ~= "ChooseRole" then return end

    logServer("Commande ChooseRole recue de " .. tostring(username) .. " -> " .. tostring(data and data.roleKey or "nil") .. " depuis " .. formatPlayerCoords(player))

    local existingRole, existingSpawn = restoreAssignedRole(player)
    if existingRole ~= nil then
        sendRoleAssigned(username, existingRole, {
            applyItems = false,
            spawn = existingSpawn,
        })
        notifyWavesRoleAssigned()
        return
    end

    local roleKey = data and data.roleKey or nil
    if roleKey == nil or ROLE_DEFS[roleKey] == nil then
        sendRoleUnavailable(username, "Role invalide.")
        return
    end

    local granted = applyRole(player, roleKey)
    local teleported, spawn = teleportPlayerToHouse(player)
    if not teleported then
        warnTeleportFailure(player, "ChooseRole")
    end

    if granted then
        print("[LastHome] Role assigne: " .. tostring(username) .. " = " .. tostring(ROLE_NAMES[roleKey] or roleKey))
    else
        print("[LastHome] Role resynchronise: " .. tostring(username) .. " = " .. tostring(ROLE_NAMES[roleKey] or roleKey))
    end

    sendRoleAssigned(username, roleKey, {
        applyItems = granted,
        spawn = spawn,
    })
    notifyWavesRoleAssigned()
end
Events.OnClientCommand.Add(onClientCommand)

local function resetState(eventName)
    print("[LastHome] LastHomeServer " .. tostring(eventName) .. " - reset etat serveur")
    Server.assignedRoles = {}
    Server.roleLoadouts = {}
    Server.selectedHouse = nil
    Server.houseSelectionLocked = false
    Server.nextBuilderRefillAt = nil
    Server.lastBuilderTickSecond = nil
    Server.pendingPostSpawnMaintenance = nil
    Server.stockGroundSpawned = false

    print("[LastHome] Attente de la selection du lieu (scenario) avant initialisation finale")
end
-- LH-MP-2/LH-MP-6: register the reset on BOTH OnServerStarted (SERVER VM,
-- authoritative) and OnGameStart (CLIENT VM / solo). LastHomeServer.lua loads
-- before LastHomeBootstrap.lua (which `require`s it), so in each VM the
-- reset handler runs BEFORE the bootstrap handler on the same event.
Events.OnServerStarted.Add(function() resetState("OnServerStarted") end)
Events.OnGameStart.Add(function() resetState("OnGameStart") end)
print("[LastHome] LastHomeServer pret - handlers: OnServerStarted, OnGameStart, OnClientCommand, OnTick")
