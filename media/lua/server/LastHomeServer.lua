require "LastHomeRoles"
require "LastHomeShared"
require "LastHomeWaves"

local Server = {
    assignedRoles = {},
    roleLoadouts = {},
    selectedHouse = nil,
    nextBuilderRefillAt = nil,
    lastBuilderTickSecond = nil,
    lastHouseSupplyRefillAt = nil,
}

local ROLE_DEFS = LastHomeRoles.ROLE_DEFS
local ROLE_NAMES = LastHomeRoles.ROLE_NAMES
local BUILDER_REFILL_ITEMS = LastHomeRoles.BUILDER_REFILL_ITEMS
local HOUSE_SUPPLY_MULTIPLIER = 8
local HOUSE_SUPPLY_REFILL_GUARD_SECONDS = 30

local getScenarioPlayers = LastHomeShared.getScenarioPlayers
local getNowSeconds = LastHomeShared.getNowSeconds
local getRandomHouse = LastHomeShared.getRandomHouse
local getHouseSpawnCandidates = LastHomeShared.getHouseSpawnCandidates

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
    if house == nil then return nil end

    house.source = "rotation"
    Server.selectedHouse = house
    syncSelectedHouse()

    print("[LastHome] Maison choisie: " .. tostring(house.name or house.id or "?") .. " (" .. tostring(house.centerX) .. ", " .. tostring(house.centerY) .. ", " .. tostring(house.centerZ or 0) .. ")")
    return Server.selectedHouse
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
    if candidates == nil or #candidates == 0 then
        return house.centerX, house.centerY, house.centerZ or 0
    end

    local startIndex = 1
    if ZombRand ~= nil then
        startIndex = ZombRand(#candidates) + 1
    elseif math ~= nil and math.random ~= nil then
        startIndex = math.random(#candidates)
    end

    local cell = getCell ~= nil and getCell() or nil
    if cell == nil then
        local fallback = candidates[startIndex]
        return fallback.x, fallback.y, fallback.z or house.centerZ or 0
    end

    for offset = 0, #candidates - 1 do
        local index = ((startIndex + offset - 1) % #candidates) + 1
        local candidate = candidates[index]
        local square = cell:getGridSquare(candidate.x, candidate.y, candidate.z or house.centerZ or 0)
        if isUsableSpawnSquare(square) then
            return square:getX(), square:getY(), square:getZ()
        end
    end

    return nil, nil, nil
end

local function teleportPlayerToHouse(player)
    if player == nil then return false end

    local modData = player:getModData()
    if modData ~= nil and (modData.LH_dead or modData.LH_spectator) then
        return false
    end

    local house = ensureSelectedHouse()
    if house == nil then return false end
    if modData ~= nil and modData.LH_houseSpawnId == house.id then
        return false
    end

    local x, y, z = pickHouseSpawnPoint(house)
    if x == nil or y == nil or z == nil then return false end

    player:setX(x)
    player:setY(y)
    player:setZ(z)

    if modData ~= nil then
        modData.LH_houseSpawnId = house.id
    end

    return true
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

local function applyRole(player, roleKey)
    if player == nil or roleKey == nil then return false end

    local def = ROLE_DEFS[roleKey]
    if def == nil then return false end

    local username = player:getUsername()
    local modData = player:getModData()
    modData.LH_role = roleKey

    if username ~= nil and Server.roleLoadouts[username] == roleKey then
        if player.setUnlimitedCarry ~= nil then
            player:setUnlimitedCarry(roleKey == "builder")
        end
        return false
    end

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

local function getPrimaryHouseSupplyContainer()
    local house = ensureSelectedHouse()
    if house == nil then return nil end

    local bounds = house.bounds
    if bounds == nil or bounds.min == nil or bounds.max == nil then return nil end

    local cell = getCell ~= nil and getCell() or nil
    if cell == nil then return nil end

    if house.supply ~= nil then
        local configuredSquare = cell:getGridSquare(house.supply.x, house.supply.y, house.supply.z or house.centerZ or 0)
        local configuredContainer = getFirstObjectContainer(configuredSquare)
        if configuredContainer ~= nil then
            return configuredContainer
        end
    end

    local centerX = house.centerX or bounds.min.x or 0
    local centerY = house.centerY or bounds.min.y or 0
    local minZ = bounds.min.z or house.centerZ or 0
    local maxZ = bounds.max.z or house.centerZ or minZ
    local bestContainer = nil
    local bestDistance = nil

    for z = minZ, maxZ do
        for x = bounds.min.x, bounds.max.x do
            for y = bounds.min.y, bounds.max.y do
                local square = cell:getGridSquare(x, y, z)
                local container = getFirstObjectContainer(square)
                if container ~= nil then
                    local dx = centerX - x
                    local dy = centerY - y
                    local distance = (dx * dx) + (dy * dy)
                    if bestDistance == nil or distance < bestDistance then
                        bestDistance = distance
                        bestContainer = container
                    end
                end
            end
        end
    end

    return bestContainer
end

local function refillHouseSupplies()
    local supplyContainer = getPrimaryHouseSupplyContainer()
    if supplyContainer == nil then return false end

    for _, refillDef in ipairs(BUILDER_REFILL_ITEMS) do
        local itemId = refillDef[1]
        local baseTargetCount = refillDef[2] or 0
        local targetCount = baseTargetCount * HOUSE_SUPPLY_MULTIPLIER
        local currentCount = countContainerItemsRecursive(supplyContainer, itemId)
        local needed = targetCount - currentCount

        if needed > 1 then
            supplyContainer:AddItems(itemId, needed)
        elseif needed == 1 then
            supplyContainer:AddItem(itemId)
        end
    end

    Server.lastHouseSupplyRefillAt = getNowSeconds()
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

    if Server.nextBuilderRefillAt == nil then
        refillHouseSuppliesIfNeeded()
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

local function sendRoleAssigned(username, roleKey)
    sendServerCommand("LastHome", "RoleAssigned", {
        username = username,
        role = roleKey,
        roleName = ROLE_NAMES[roleKey] or roleKey,
    })
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
    if player == nil then return nil end

    local username = player:getUsername()
    if username == nil then return nil end

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
        if not teleportPlayerToHouse(player) then
            warnTeleportFailure(player, "restoreAssignedRole")
        end
        return roleKey
    end

    return nil
end

local function onClientCommand(module, command, player, data)
    if module ~= "LastHome" then return end

    local username = player and player:getUsername() or nil
    if username == nil then return end

    if command == "RolePickerReady" then
        ensureSelectedHouse()

        local roleKey = restoreAssignedRole(player)
        if roleKey ~= nil then
            sendRoleAssigned(username, roleKey)
            notifyWavesRoleAssigned()
            return
        end

        sendServerCommand("LastHome", "OpenRolePicker", {
            username = username,
        })
        return
    end

    if command ~= "ChooseRole" then return end

    local existingRole = restoreAssignedRole(player)
    if existingRole ~= nil then
        sendRoleAssigned(username, existingRole)
        notifyWavesRoleAssigned()
        return
    end

    local roleKey = data and data.roleKey or nil
    if roleKey == nil or ROLE_DEFS[roleKey] == nil then
        sendRoleUnavailable(username, "Role invalide.")
        return
    end

    local granted = applyRole(player, roleKey)
    if not teleportPlayerToHouse(player) then
        warnTeleportFailure(player, "ChooseRole")
    end

    if granted then
        print("[LastHome] Role assigne: " .. tostring(username) .. " = " .. tostring(ROLE_NAMES[roleKey] or roleKey))
    else
        print("[LastHome] Role resynchronise: " .. tostring(username) .. " = " .. tostring(ROLE_NAMES[roleKey] or roleKey))
    end

    sendRoleAssigned(username, roleKey)
    notifyWavesRoleAssigned()
end
Events.OnClientCommand.Add(onClientCommand)

local function onGameStart()
    Server.assignedRoles = {}
    Server.roleLoadouts = {}
    Server.selectedHouse = nil
    Server.nextBuilderRefillAt = nil
    Server.lastBuilderTickSecond = nil
    Server.lastHouseSupplyRefillAt = nil

    ensureSelectedHouse()
    refillHouseSuppliesIfNeeded()
end
Events.OnGameStart.Add(onGameStart)
