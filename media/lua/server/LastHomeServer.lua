require "LastHomeRoles"
require "LastHomeShared"
require "LastHomeWaves"

LastHomeServer = LastHomeServer or {}

print("[LastHome] LastHomeServer charge")

local Server = {
    assignedRoles = {},
    roleLoadouts = {},
    selectedHouse = nil,
    houseSelectionLocked = false,
    nextBuilderRefillAt = nil,
    lastBuilderTickSecond = nil,
    lastHouseSupplyRefillAt = nil,
    pendingPostSpawnMaintenance = nil,
}

local ROLE_DEFS = LastHomeRoles.ROLE_DEFS
local ROLE_NAMES = LastHomeRoles.ROLE_NAMES
local BUILDER_REFILL_ITEMS = LastHomeRoles.BUILDER_REFILL_ITEMS
local HOUSE_SUPPLY_MULTIPLIER = 8
local HOUSE_SUPPLY_REFILL_GUARD_SECONDS = 30
local SPAWN_AMBIENT_CLEANUP_PADDING = 8
local POST_SPAWN_MAINTENANCE_RETRY_SECONDS = 2
local POST_SPAWN_MAINTENANCE_MAX_ATTEMPTS = 8

local getScenarioPlayers = LastHomeShared.getScenarioPlayers
local getNowSeconds = LastHomeShared.getNowSeconds
local getRandomHouse = LastHomeShared.getRandomHouse
local getHouseSpawnCandidates = LastHomeShared.getHouseSpawnCandidates
local applyCarryProfile = LastHomeShared.applyCarryProfile
local primeRoleLoadout = LastHomeShared.primeRoleLoadout
local equipRoleItems = LastHomeShared.equipRoleItems
local DEBUG_ENABLED = LastHomeShared.DEBUG == true

local function logServer(message)
    if not DEBUG_ENABLED then return end
    print("[LastHome][Server] " .. tostring(message))
end

local function formatCoords(x, y, z)
    return "(" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z or 0) .. ")"
end

local function formatHouseLabel(house)
    if house == nil then return "nil" end
    return tostring(house.name or house.id or "?") .. "@" .. formatCoords(house.centerX, house.centerY, house.centerZ or 0)
end

local function formatPlayerCoords(player)
    if player == nil or player.getX == nil or player.getY == nil then
        return "(?, ?, ?)"
    end
    return formatCoords(player:getX(), player:getY(), player.getZ ~= nil and player:getZ() or 0)
end

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

local function applyManualTeleportState(player, x, y, z)
    player:setX(x)
    player:setY(y)
    player:setZ(z)

    if player.setLx ~= nil then player:setLx(x) end
    if player.setLy ~= nil then player:setLy(y) end
    if player.setLz ~= nil then player:setLz(z) end
    if player.setNx ~= nil then player:setNx(x) end
    if player.setNy ~= nil then player:setNy(y) end
    if player.setScriptnx ~= nil then player:setScriptnx(x) end
    if player.setScriptny ~= nil then player:setScriptny(y) end

    local cell = getCell ~= nil and getCell() or nil
    local square = cell ~= nil and cell.getGridSquare ~= nil and cell:getGridSquare(x, y, z) or nil
    if square ~= nil then
        if player.setCurrent ~= nil then player:setCurrent(square) end
        if player.setLast ~= nil then player:setLast(square) end
    end

    if player.setMovingSquareNow ~= nil then player:setMovingSquareNow() end
    if player.ensureOnTile ~= nil then player:ensureOnTile() end
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

local refillHouseSupplies

local function schedulePostSpawnMaintenance(house, spawnData, username)
    if house == nil or spawnData == nil then
        Server.pendingPostSpawnMaintenance = nil
        return
    end

    Server.pendingPostSpawnMaintenance = {
        houseId = house.id,
        houseName = house.name or house.id or "?",
        username = username,
        spawnData = {
            x = spawnData.x,
            y = spawnData.y,
            z = spawnData.z,
            houseId = spawnData.houseId,
        },
        attempts = 0,
        maxAttempts = POST_SPAWN_MAINTENANCE_MAX_ATTEMPTS,
        nextAttemptAt = getNowSeconds(),
        supplyReady = false,
    }
end

local function processPostSpawnMaintenance(now)
    local pending = Server.pendingPostSpawnMaintenance
    if pending == nil then return end
    if now < (pending.nextAttemptAt or 0) then return end

    local house = ensureSelectedHouse()
    if house == nil or house.id ~= pending.houseId then
        Server.pendingPostSpawnMaintenance = nil
        return
    end

    pending.attempts = (pending.attempts or 0) + 1
    local attemptLabel = "role-spawn#" .. tostring(pending.attempts)
    clearAmbientZombiesNearSpawn(house, pending.spawnData, attemptLabel)

    if not pending.supplyReady then
        pending.supplyReady = refillHouseSupplies() == true
    end

    if pending.supplyReady or pending.attempts >= (pending.maxAttempts or POST_SPAWN_MAINTENANCE_MAX_ATTEMPTS) then
        if not pending.supplyReady then
            print("[LastHome] WARN: postSpawnMaintenance - stock toujours introuvable pour " .. tostring(pending.houseName) .. " apres " .. tostring(pending.attempts) .. " tentatives")
        end
        Server.pendingPostSpawnMaintenance = nil
        return
    end

    pending.nextAttemptAt = now + POST_SPAWN_MAINTENANCE_RETRY_SECONDS
end

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
    schedulePostSpawnMaintenance(house, spawnData, username)
    logServer("teleport joueur " .. tostring(username) .. " : " .. beforeCoords .. " -> " .. formatCoords(x, y, z) .. " pour " .. formatHouseLabel(house) .. " via " .. tostring(teleportMode))
    return teleported, spawnData
end

local function warnTeleportFailure(player, context)
    local username = player and player.getUsername and player:getUsername() or "?"
    print("[LastHome] WARN: teleport vers la maison echoue pour " .. tostring(username) .. " (" .. tostring(context or "unknown") .. ")")
end

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

local function getFirstObjectContainer(square)
    if square == nil or square.getObjects == nil then return nil end

    local objects = square:getObjects()
    if objects == nil then return nil end

    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local container = object and object.getContainer and object:getContainer() or nil
        if container ~= nil then
            return container
        end
    end

    return nil
end

local function getSupplySearchArea(house)
    if house == nil then return nil, "?" end

    local boundary = house.boundary
    if boundary ~= nil and boundary.minX ~= nil and boundary.maxX ~= nil and boundary.minY ~= nil and boundary.maxY ~= nil then
        return {
            min = {
                x = boundary.minX,
                y = boundary.minY,
                z = boundary.minZ,
            },
            max = {
                x = boundary.maxX,
                y = boundary.maxY,
                z = boundary.maxZ,
            },
        }, "boundary"
    end

    local bounds = house.bounds
    if bounds ~= nil and bounds.min ~= nil and bounds.max ~= nil then
        return bounds, "bounds"
    end

    return nil, "?"
end

local function getSupplySearchZRange(house, area)
    local minZ = nil
    local maxZ = nil

    local function include(value)
        if value == nil then return end
        if minZ == nil or value < minZ then minZ = value end
        if maxZ == nil or value > maxZ then maxZ = value end
    end

    if area ~= nil then
        include(area.min ~= nil and area.min.z or nil)
        include(area.max ~= nil and area.max.z or nil)
    end
    if house ~= nil then
        include(house.centerZ)
        include(house.supply ~= nil and house.supply.z or nil)
    end

    if minZ == nil then minZ = 0 end
    if maxZ == nil then maxZ = minZ end

    minZ = math.max(0, minZ - 1)
    maxZ = math.max(minZ, maxZ + 2)
    return minZ, maxZ
end

local function getPrimaryHouseSupplyContainer()
    local house = ensureSelectedHouse()
    if house == nil then return nil end

    local searchArea, searchAreaLabel = getSupplySearchArea(house)
    if searchArea == nil or searchArea.min == nil or searchArea.max == nil then
        print("[LastHome] WARN: getPrimaryHouseSupplyContainer - pas de zone de recherche pour " .. tostring(house.name or house.id or "?"))
        return nil
    end

    local cell = getCell ~= nil and getCell() or nil
    if cell == nil then
        print("[LastHome] WARN: getPrimaryHouseSupplyContainer - getCell() est nil")
        return nil
    end

    if house.supply ~= nil then
        local configuredSquare = cell:getGridSquare(house.supply.x, house.supply.y, house.supply.z or house.centerZ or 0)
        local configuredContainer = getFirstObjectContainer(configuredSquare)
        if configuredContainer ~= nil then
            return configuredContainer
        end
    end

    local anchorX = house.supply ~= nil and house.supply.x or (house.centerX or searchArea.min.x or 0)
    local anchorY = house.supply ~= nil and house.supply.y or (house.centerY or searchArea.min.y or 0)
    local minZ, maxZ = getSupplySearchZRange(house, searchArea)
    local bestContainer = nil
    local bestX, bestY, bestZ
    local bestDistance = nil

    for z = minZ, maxZ do
        for x = searchArea.min.x, searchArea.max.x do
            for y = searchArea.min.y, searchArea.max.y do
                local square = cell:getGridSquare(x, y, z)
                local container = getFirstObjectContainer(square)
                if container ~= nil then
                    local dx = anchorX - x
                    local dy = anchorY - y
                    local distance = (dx * dx) + (dy * dy)
                    if bestDistance == nil or distance < bestDistance then
                        bestDistance = distance
                        bestContainer = container
                        bestX, bestY, bestZ = x, y, z
                    end
                end
            end
        end
    end

    if bestContainer ~= nil then
        -- Fallback: the configured square (house.supply) had no container.
        -- Rewrite house.supply with the actual square of the chosen container so
        -- the client arrow (LH-15) points to the right location, then resync the client.
        local cur = house.supply or {}
        if cur.x ~= bestX or cur.y ~= bestY or (cur.z or 0) ~= (bestZ or 0) then
            house.supply = { x = bestX, y = bestY, z = bestZ }
            print("[LastHome] getPrimaryHouseSupplyContainer - fallback supply via " .. tostring(searchAreaLabel) .. " pour " .. tostring(house.name or house.id or "?") .. " -> (" .. tostring(bestX) .. "," .. tostring(bestY) .. "," .. tostring(bestZ or 0) .. ")")
            syncSelectedHouse()
        end
    else
        local houseName = house.name or house.id or "?"
        print("[LastHome] WARN: getPrimaryHouseSupplyContainer - aucun conteneur trouve pour " .. tostring(houseName) .. " dans " .. tostring(searchAreaLabel) .. " [" .. tostring(searchArea.min.x) .. "," .. tostring(searchArea.min.y) .. "," .. tostring(minZ) .. "] -> [" .. tostring(searchArea.max.x) .. "," .. tostring(searchArea.max.y) .. "," .. tostring(maxZ) .. "]")
    end

    return bestContainer
end

refillHouseSupplies = function()
    local supplyContainer = getPrimaryHouseSupplyContainer()
    if supplyContainer == nil then
        print("[LastHome] WARN: refillHouseSupplies - aucun conteneur de ravitaillement")
        return false
    end

    local totalAdded = 0
    local totalItems = 0

    for _, refillDef in ipairs(BUILDER_REFILL_ITEMS) do
        local itemId = refillDef[1]
        local baseTargetCount = refillDef[2] or 0
        local targetCount = baseTargetCount * HOUSE_SUPPLY_MULTIPLIER
        local currentCount = countContainerItemsRecursive(supplyContainer, itemId)
        local needed = targetCount - currentCount

        if needed > 1 then
            supplyContainer:AddItems(itemId, needed)
            totalAdded = totalAdded + needed
            totalItems = totalItems + 1
        elseif needed == 1 then
            supplyContainer:AddItem(itemId)
            totalAdded = totalAdded + 1
            totalItems = totalItems + 1
        end
    end

    Server.lastHouseSupplyRefillAt = getNowSeconds()
    if totalAdded > 0 then
        print("[LastHome] refillHouseSupplies: " .. tostring(totalItems) .. " types, " .. tostring(totalAdded) .. " items ajoutes")
    end
    return true
end

local function refillHouseSuppliesIfNeeded(minIntervalSeconds)
    local now = getNowSeconds()
    local minInterval = minIntervalSeconds or 0

    if Server.lastHouseSupplyRefillAt ~= nil and now < (Server.lastHouseSupplyRefillAt + minInterval) then
        return false
    end

    return refillHouseSupplies()
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
            refillHouseSuppliesIfNeeded()
        end
        Server.nextBuilderRefillAt = now + 600
        return
    end

    if now < Server.nextBuilderRefillAt then return end

    refillBuilderResources()
    refillHouseSuppliesIfNeeded()
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
    ensureSelectedHouse()
    refillHouseSuppliesIfNeeded(HOUSE_SUPPLY_REFILL_GUARD_SECONDS)

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
    local challengeActor = actorUsername ~= nil and tostring(actorUsername) or "?"
    local teleportContext = selectionSource == "challenge"
        and "SetHouse"
        or ("setSelectedHouse:" .. tostring(selectionSource))
    local wavesStarted = LastHomeWaves ~= nil
        and LastHomeWaves.hasStarted ~= nil
        and LastHomeWaves.hasStarted() == true

    if wavesStarted then
        if Server.selectedHouse ~= nil and Server.selectedHouse.id == houseId then
            if selectionSource == "challenge" then
                print("[LastHome] SetHouse ignore pour " .. challengeActor .. " (houseId=" .. tostring(houseId) .. ") car la maison est deja selectionnee")
            else
                print("[LastHome] setSelectedHouse ignore (source=" .. tostring(selectionSource) .. ", houseId=" .. tostring(houseId) .. ") car la maison est deja selectionnee")
            end
            return false
        end

        if selectionSource == "challenge" then
            print("[LastHome] WARN: SetHouse ignore pour " .. challengeActor .. " (houseId=" .. tostring(houseId) .. ") car les vagues ont demarree")
        else
            print("[LastHome] WARN: setSelectedHouse ignore (source=" .. tostring(selectionSource) .. ", houseId=" .. tostring(houseId) .. ") car les vagues ont demarree")
        end
        return false
    end

    if Server.selectedHouse ~= nil
        and Server.selectedHouse.id == houseId
        and Server.selectedHouse.source == selectionSource then
        if selectionSource == "challenge" then
            print("[LastHome] SetHouse ignore pour " .. challengeActor .. " (houseId=" .. tostring(houseId) .. ") car la maison est deja selectionnee")
        else
            print("[LastHome] setSelectedHouse ignore (source=" .. tostring(selectionSource) .. ", houseId=" .. tostring(houseId) .. ") car la maison est deja selectionnee")
        end
        return false
    end

    local house = LastHomeShared.getHouseById(houseId)
    if house == nil then
        if selectionSource == "challenge" then
            print("[LastHome] WARN: SetHouse ignore pour " .. challengeActor .. " (houseId inconnu=" .. tostring(houseId) .. ")")
        else
            print("[LastHome] WARN: setSelectedHouse ignore (source=" .. tostring(selectionSource) .. ", houseId inconnu=" .. tostring(houseId) .. ")")
        end
        return false
    end

    local previousHouse = Server.selectedHouse
    house.source = selectionSource
    Server.selectedHouse = house
    Server.houseSelectionLocked = true
    Server.lastHouseSupplyRefillAt = nil
    syncSelectedHouse()
    refillHouseSuppliesIfNeeded()

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
        if selectionSource == "challenge" then
            print("[LastHome] Maison challenge remplace la rotation: " .. tostring(previousHouse.id) .. " -> " .. tostring(house.id))
        else
            print("[LastHome] Maison remplacee: " .. tostring(previousHouse.id) .. " -> " .. tostring(house.id))
        end
    end

    if selectionSource == "challenge" then
        print("[LastHome] Maison forcee par challenge: " .. tostring(house.name or house.id))
    else
        print("[LastHome] Maison selectionnee (source=" .. tostring(selectionSource) .. "): " .. tostring(house.name or house.id))
    end

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
    Server.lastHouseSupplyRefillAt = nil
    Server.pendingPostSpawnMaintenance = nil

    print("[LastHome] Attente de la selection du lieu (scenario) avant initialisation finale")
end
-- LH-MP-2/LH-MP-6: register the reset on BOTH OnServerStarted (SERVER VM,
-- authoritative) and OnGameStart (CLIENT VM / solo). LastHomeServer.lua loads
-- before LastHomeBootstrap.lua (which `require`s it), so in each VM the
-- reset handler runs BEFORE the bootstrap handler on the same event.
Events.OnServerStarted.Add(function() resetState("OnServerStarted") end)
Events.OnGameStart.Add(function() resetState("OnGameStart") end)
print("[LastHome] LastHomeServer pret - handlers: OnServerStarted, OnGameStart, OnClientCommand, OnTick")
