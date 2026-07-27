LastHomeShared = LastHomeShared or {}

if LastHomeShared.DEBUG == nil then
    LastHomeShared.DEBUG = true
end

function LastHomeShared.log(module, message)
    if LastHomeShared.DEBUG ~= true then return end
    print("[LastHome][" .. tostring(module) .. "] " .. tostring(message))
end

local NOW_SOURCE = nil

print("[LastHome] LastHomeShared charge, maisons: " .. tostring(4))

local HOUSE_DEFS = {
    {
        id = "hospital",
        name = "Hopital",
        centerX = 12380,
        centerY = 3682,
        centerZ = 0,
        boundary = {
            minX = 12345,
            maxX = 12474,
            minY = 3597,
            maxY = 3724,
        },
        spawn = {
            type = "radius",
            radius = 4,
        },
        supply = {
            x = 12420,
            y = 3699,
            z = 0,
        },
        stockSpawn = {
            x = 12420,
            y = 3699,
            z = 0,
        },
    },
    {
        id = "villa",
        name = "Villa",
        centerX = 13532,
        centerY = 2842,
        centerZ = 1,
        boundary = {
            minX = 13524,
            maxX = 13545,
            minY = 2830,
            maxY = 2858,
        },
        forcedDirections = {"S"},
        ambientCleanupRadius = 120,
        alarm = {
            x = 13532,
            y = 2842,
            z = 0,
            radius = 220,
            volume = 220,
            pulseSeconds = 3,
        },
        spawn = {
            type = "box",
            minX = 13532,
            maxX = 13533,
            minY = 2839,
            maxY = 2843,
            z = 1,
        },
        supply = {
            x = 13540,
            y = 2836,
            z = 0,
        },
        stockSpawn = {
            x = 13540,
            y = 2836,
            z = 0,
        },
    },
    {
        id = "prison",
        name = "Prison",
        centerX = 7693,
        centerY = 11862,
        centerZ = 0,
        boundary = {
            minX = 7585,
            maxX = 7781,
            minY = 11761,
            maxY = 11978,
        },
        spawn = {
            type = "radius",
            radius = 4,
        },
        supply = {
            x = 7690,
            y = 11865,
            z = 0,
        },
        stockSpawn = {
            x = 7690,
            y = 11865,
            z = 0,
        },
    },
    {
        id = "elementary_school",
        name = "Ecole elementaire",
        centerX = 10613,
        centerY = 9974,
        centerZ = 0,
        boundary = {
            minX = 10602,
            maxX = 10636,
            minY = 9949,
            maxY = 9991,
        },
        spawn = {
            type = "radius",
            radius = 3,
        },
        supply = {
            x = 10616,
            y = 9971,
            z = 0,
        },
        stockSpawn = {
            x = 10616,
            y = 9972,
            z = 0,
        },
    },
}

local function cloneTable(value)
    if type(value) ~= "table" then return value end

    local copy = {}
    for key, entry in pairs(value) do
        copy[key] = cloneTable(entry)
    end

    return copy
end

function LastHomeShared.round(value)
    if value == nil then return 0 end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function buildBoundsFromSpawn(house)
    if house == nil then return nil end

    local spawn = house.spawn or {}
    local centerX = LastHomeShared.round(house.centerX)
    local centerY = LastHomeShared.round(house.centerY)
    local centerZ = LastHomeShared.round(house.centerZ or 0)

    if spawn.type == "box" then
        return {
            min = {
                x = LastHomeShared.round(spawn.minX or centerX),
                y = LastHomeShared.round(spawn.minY or centerY),
                z = LastHomeShared.round(spawn.z or centerZ),
            },
            max = {
                x = LastHomeShared.round(spawn.maxX or centerX),
                y = LastHomeShared.round(spawn.maxY or centerY),
                z = LastHomeShared.round(spawn.z or centerZ),
            },
        }
    end

    local radius = LastHomeShared.round(spawn.radius or 0)
    return {
        min = {x = centerX - radius, y = centerY - radius, z = centerZ},
        max = {x = centerX + radius, y = centerY + radius, z = centerZ},
    }
end

local function normalizeBoundary(boundary, house)
    if boundary == nil or house == nil then return nil end

    local copy = cloneTable(boundary)
    copy.minX = LastHomeShared.round(copy.minX or house.centerX)
    copy.maxX = LastHomeShared.round(copy.maxX or house.centerX)
    copy.minY = LastHomeShared.round(copy.minY or house.centerY)
    copy.maxY = LastHomeShared.round(copy.maxY or house.centerY)

    if copy.minX > copy.maxX then
        copy.minX, copy.maxX = copy.maxX, copy.minX
    end
    if copy.minY > copy.maxY then
        copy.minY, copy.maxY = copy.maxY, copy.minY
    end

    if copy.minZ ~= nil then
        copy.minZ = LastHomeShared.round(copy.minZ)
    end
    if copy.maxZ ~= nil then
        copy.maxZ = LastHomeShared.round(copy.maxZ)
    end
    if copy.minZ ~= nil and copy.maxZ ~= nil and copy.minZ > copy.maxZ then
        copy.minZ, copy.maxZ = copy.maxZ, copy.minZ
    end

    return copy
end

function LastHomeShared.cloneHouse(house)
    if house == nil then return nil end

    local copy = cloneTable(house)
    copy.centerX = LastHomeShared.round(copy.centerX)
    copy.centerY = LastHomeShared.round(copy.centerY)
    copy.centerZ = LastHomeShared.round(copy.centerZ or 0)
    copy.boundary = normalizeBoundary(copy.boundary, copy)
    if copy.boundaryRadius ~= nil then
        copy.boundaryRadius = math.max(0, LastHomeShared.round(copy.boundaryRadius))
    end
    if copy.supply ~= nil then
        copy.supply.x = LastHomeShared.round(copy.supply.x or copy.centerX)
        copy.supply.y = LastHomeShared.round(copy.supply.y or copy.centerY)
        copy.supply.z = LastHomeShared.round(copy.supply.z or copy.centerZ)
    end
    copy.bounds = LastHomeShared.getHouseBounds(copy)
    return copy
end

function LastHomeShared.getHouseBounds(house)
    if house == nil then return nil end

    local bounds = house.bounds
    if bounds ~= nil and bounds.min ~= nil and bounds.max ~= nil then
        return {
            min = {
                x = LastHomeShared.round(bounds.min.x or house.centerX),
                y = LastHomeShared.round(bounds.min.y or house.centerY),
                z = LastHomeShared.round(bounds.min.z or house.centerZ or 0),
            },
            max = {
                x = LastHomeShared.round(bounds.max.x or house.centerX),
                y = LastHomeShared.round(bounds.max.y or house.centerY),
                z = LastHomeShared.round(bounds.max.z or house.centerZ or 0),
            },
        }
    end

    return buildBoundsFromSpawn(house)
end

function LastHomeShared.getBoundaryRadius(house)
    if house == nil or house.boundaryRadius == nil then
        return 0
    end
    return math.max(0, LastHomeShared.round(house.boundaryRadius))
end

function LastHomeShared.hasBoundary(house)
    if house == nil then return false end
    if house.boundary ~= nil then return true end
    return LastHomeShared.getBoundaryRadius(house) > 0
end

function LastHomeShared.isInsideBoundary(playerOrX, house, y, z)
    if house == nil then return true end

    local x = playerOrX
    if playerOrX ~= nil and playerOrX.getX ~= nil and playerOrX.getY ~= nil then
        x = playerOrX:getX()
        y = playerOrX:getY()
        z = playerOrX.getZ ~= nil and playerOrX:getZ() or z
    end

    if x == nil or y == nil then return true end

    local boundary = house.boundary
    if boundary ~= nil then
        local insideXY = x >= boundary.minX and x <= boundary.maxX and y >= boundary.minY and y <= boundary.maxY
        if not insideXY then
            return false
        end

        if boundary.minZ ~= nil and boundary.maxZ ~= nil and z ~= nil then
            return z >= boundary.minZ and z <= boundary.maxZ
        end

        return true
    end

    local boundaryRadius = LastHomeShared.getBoundaryRadius(house)
    if boundaryRadius <= 0 then return true end

    local centerX = LastHomeShared.round(house.centerX)
    local centerY = LastHomeShared.round(house.centerY)
    local dx = x - centerX
    local dy = y - centerY
    return (dx * dx) + (dy * dy) <= (boundaryRadius * boundaryRadius)
end

local ROLE_CARRY_CAPACITY = {
    builder = 90,
    demolisseur = 60,
    invincible = 90,
}

function LastHomeShared.applyCarryProfile(player, roleKey)
    if player == nil then return end

    local carryCapacity = ROLE_CARRY_CAPACITY[roleKey]
    local unlimitedCarry = carryCapacity ~= nil

    if player.setUnlimitedCarry ~= nil then
        player:setUnlimitedCarry(unlimitedCarry)
    end

    if not unlimitedCarry then return end

    if player.getMaxWeightBase ~= nil and player.setMaxWeightBase ~= nil then
        local baseWeight = player:getMaxWeightBase() or 0
        if baseWeight < carryCapacity then
            player:setMaxWeightBase(carryCapacity)
        end
    end

    if player.getMaxWeight ~= nil and player.setMaxWeight ~= nil then
        local maxWeight = player:getMaxWeight() or 0
        if maxWeight < carryCapacity then
            player:setMaxWeight(carryCapacity)
        end
    end

    if player.setMaxWeightDelta ~= nil then
        player:setMaxWeightDelta(0)
    end
end

function LastHomeShared.addItemsToContainer(container, itemId, count)
    if container == nil or itemId == nil or count == nil or count <= 0 then return end
    for _ = 1, count do
        container:AddItem(itemId)
    end
end

function LastHomeShared.buildItemCounts(items)
    local counts = {}
    if items == nil then return counts end
    for _, itemDef in ipairs(items) do
        local itemId = itemDef[1]
        local count = itemDef[2] or 1
        counts[itemId] = (counts[itemId] or 0) + count
    end
    return counts
end

function LastHomeShared.addRoleItems(inv, bagItem, bagItemId, items, bagContents)
    if inv == nil or items == nil then return end
    local bagContainer = bagItem and bagItem:getItemContainer() or nil
    local bagCounts = LastHomeShared.buildItemCounts(bagContents)
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
            LastHomeShared.addItemsToContainer(bagContainer, itemId, bagCount)
        end
    end
end

function LastHomeShared.applyRoleStats(player, stats)
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

function LastHomeShared.isPassivePerk(perk)
    return perk == Perks.Strength or perk == Perks.Fitness
end

function LastHomeShared.applyPerkLevel(player, perk, level)
    if player == nil or perk == nil or level == nil then return end
    local xp = player:getXp()
    xp:setXPToLevel(perk, level)
    if LastHomeShared.isPassivePerk(perk) and player.setPerkLevelDebug ~= nil then
        player:setPerkLevelDebug(perk, level)
    end
    if player.getPerkLevel ~= nil then
        local currentLevel = player:getPerkLevel(perk)
        if currentLevel ~= nil and player.LevelPerk ~= nil then
            while currentLevel < level do
                player:LevelPerk(perk, false)
                local newLevel = player:getPerkLevel(perk)
                if newLevel == nil or newLevel <= currentLevel then break end
                currentLevel = newLevel
            end
        end
        if currentLevel ~= nil and player.LoseLevel ~= nil then
            while currentLevel > level do
                player:LoseLevel(perk)
                local newLevel = player:getPerkLevel(perk)
                if newLevel == nil or newLevel >= currentLevel then break end
                currentLevel = newLevel
            end
        end
    end
    xp:setXPToLevel(perk, level)
end

function LastHomeShared.applyManualTeleportState(player, x, y, z)
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

local function forEachContainerItemRecursive(container, callback)
    if container == nil or callback == nil or container.getItems == nil then return end

    local items = container:getItems()
    if items == nil then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item ~= nil then
            callback(item)

            local childContainer = item.getItemContainer and item:getItemContainer() or nil
            if childContainer ~= nil then
                forEachContainerItemRecursive(childContainer, callback)
            end
        end
    end
end

local function fillAmmoItem(item)
    if item == nil then return end

    -- Pre-loading firearms: replicate the official engine pattern
    -- (HandWeapon:randomizeBullets). The gun stores currentAmmoCount
    -- directly - no need to fill/insert a magazine item.
    if item.isRanged ~= nil and item:isRanged() then
        local maxAmmo = 0
        if item.getMaxAmmo ~= nil then maxAmmo = item:getMaxAmmo() or 0 end
        if maxAmmo > 0 and item.setCurrentAmmoCount ~= nil then
            item:setCurrentAmmoCount(maxAmmo)
        end
        if item.getMagazineType ~= nil and item.setContainsClip ~= nil then
            local magazineType = item:getMagazineType()
            if magazineType ~= nil and magazineType ~= "" then
                item:setContainsClip(true)
            end
        end
        if item.haveChamber ~= nil and item:haveChamber() and item.setRoundChambered ~= nil then
            item:setRoundChambered(true)
        elseif item.setRoundChambered ~= nil and item.getCurrentAmmoCount ~= nil then
            item:setRoundChambered((item:getCurrentAmmoCount() or 0) > 0)
        end
        if item.setSpentRoundChambered ~= nil then
            item:setSpentRoundChambered(false)
        end
        local cc = (item.isContainsClip ~= nil) and tostring(item:isContainsClip()) or "?"
        local rc = (item.isRoundChambered ~= nil) and tostring(item:isRoundChambered()) or "?"
        local hc = (item.haveChamber ~= nil) and tostring(item:haveChamber()) or "?"
        print("[LastHome] fillAmmoItem arme=" .. tostring(item:getType())
            .. " maxAmmo=" .. tostring(maxAmmo)
            .. " ammo=" .. tostring(item:getCurrentAmmoCount())
            .. " containsClip=" .. cc
            .. " roundChambered=" .. rc
            .. " haveChamber=" .. hc)
        return
    end

    -- Spare magazine (non-weapon item, e.g. Base.556Clip): fill to MaxAmmo.
    if item.getMaxAmmo ~= nil and item.setCurrentAmmoCount ~= nil then
        local maxAmmo = item:getMaxAmmo() or 0
        if maxAmmo > 0 then
            item:setCurrentAmmoCount(maxAmmo)
        end
    end
end

function LastHomeShared.primeRoleLoadout(inv)
    if inv == nil then return end
    forEachContainerItemRecursive(inv, fillAmmoItem)
end

function LastHomeShared.resolveSecondaryEquipItem(inv, equipped, primary)
    if inv == nil or equipped == nil then return nil end

    if equipped.secondary then
        if primary ~= nil and equipped.secondary == equipped.primary then
            return primary
        end
        return inv:FindAndReturn(equipped.secondary)
    end

    if primary ~= nil and primary.isTwoHandWeapon ~= nil and primary:isTwoHandWeapon() then
        return primary
    end

    return nil
end

function LastHomeShared.equipRoleItems(player, inv, equipped)
    if player == nil or inv == nil or equipped == nil then return end

    local primary = nil
    if equipped.primary then
        primary = inv:FindAndReturn(equipped.primary)
        if primary then player:setPrimaryHandItem(primary) end
    end

    local secondary = LastHomeShared.resolveSecondaryEquipItem(inv, equipped, primary)
    if secondary ~= nil then
        player:setSecondaryHandItem(secondary)
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

function LastHomeShared.getHouseDefinitions()
    local result = {}

    for _, house in ipairs(HOUSE_DEFS) do
        result[#result + 1] = LastHomeShared.cloneHouse(house)
    end

    return result
end

function LastHomeShared.getHouseById(houseId)
    if houseId == nil then return nil end

    for _, house in ipairs(HOUSE_DEFS) do
        if house.id == houseId then
            return LastHomeShared.cloneHouse(house)
        end
    end

    return nil
end

function LastHomeShared.getRandomHouse()
    if #HOUSE_DEFS <= 0 then return nil end

    local index = 1
    if ZombRand ~= nil then
        index = ZombRand(#HOUSE_DEFS) + 1
    elseif math ~= nil and math.random ~= nil then
        index = math.random(#HOUSE_DEFS)
    end

    return LastHomeShared.cloneHouse(HOUSE_DEFS[index])
end

function LastHomeShared.getHouseStockSpawn(house)
    if house == nil then return nil end

    local stockSpawn = house.stockSpawn or house.supply
    if stockSpawn == nil then return nil end

    return {
        x = stockSpawn.x or house.centerX,
        y = stockSpawn.y or house.centerY,
        z = stockSpawn.z or house.centerZ or 0,
    }
end

function LastHomeShared.getHouseSpawnCandidates(house)
    local result = {}
    if house == nil then return result end

    local spawn = house.spawn or {}
    local centerX = LastHomeShared.round(house.centerX)
    local centerY = LastHomeShared.round(house.centerY)
    local centerZ = LastHomeShared.round(house.centerZ or 0)

    if spawn.type == "box" then
        local minX = LastHomeShared.round(spawn.minX or centerX)
        local maxX = LastHomeShared.round(spawn.maxX or centerX)
        local minY = LastHomeShared.round(spawn.minY or centerY)
        local maxY = LastHomeShared.round(spawn.maxY or centerY)
        local z = LastHomeShared.round(spawn.z or centerZ)

        for x = minX, maxX do
            for y = minY, maxY do
                result[#result + 1] = {x = x, y = y, z = z}
            end
        end

        return result
    end

    local radius = LastHomeShared.round(spawn.radius or 0)
    for dx = -radius, radius do
        for dy = -radius, radius do
            if (dx * dx) + (dy * dy) <= (radius * radius) then
                result[#result + 1] = {
                    x = centerX + dx,
                    y = centerY + dy,
                    z = centerZ,
                }
            end
        end
    end

    if #result == 0 then
        result[1] = {x = centerX, y = centerY, z = centerZ}
    end

    return result
end

function LastHomeShared.formatCoords(x, y, z)
    return "(" .. tostring(x) .. ", " .. tostring(y) .. ", " .. tostring(z or 0) .. ")"
end

function LastHomeShared.formatPlayerCoords(player)
    if player == nil or player.getX == nil or player.getY == nil then
        return "(?, ?, ?)"
    end
    return LastHomeShared.formatCoords(player:getX(), player:getY(), player.getZ ~= nil and player:getZ() or 0)
end

function LastHomeShared.formatHouseLabel(house)
    if house == nil then return "nil" end
    return tostring(house.name or house.id or "?") .. "@" .. LastHomeShared.formatCoords(house.centerX, house.centerY, house.centerZ or 0)
end

function LastHomeShared.formatBoundaryLabel(house)
    if house == nil then return "house=nil" end
    if house.boundary ~= nil then
        return tostring(house.name or house.id or "?")
            .. " rect[x=" .. tostring(house.boundary.minX) .. ".." .. tostring(house.boundary.maxX)
            .. ", y=" .. tostring(house.boundary.minY) .. ".." .. tostring(house.boundary.maxY) .. "]"
    end
    local radius = LastHomeShared.getBoundaryRadius(house)
    return tostring(house.name or house.id or "?") .. " radius=" .. tostring(radius) .. " center=" .. LastHomeShared.formatCoords(house.centerX, house.centerY, house.centerZ or 0)
end

function LastHomeShared.getScenarioPlayers()
    local result = {}

    if getOnlinePlayers ~= nil then
        local onlinePlayers = getOnlinePlayers()
        if onlinePlayers ~= nil and onlinePlayers:size() > 0 then
            for i = 0, onlinePlayers:size() - 1 do
                result[#result + 1] = onlinePlayers:get(i)
            end
            return result
        end
    end

    if getPlayer ~= nil then
        local singlePlayer = getPlayer()
        if singlePlayer ~= nil then
            result[#result + 1] = singlePlayer
        end
    end

    return result
end

function LastHomeShared.getNowSeconds()
    if getTimestamp ~= nil then
        local timestamp = getTimestamp()
        if timestamp ~= nil then
            if NOW_SOURCE ~= "getTimestamp" then
                NOW_SOURCE = "getTimestamp"
                print("[LastHome] getNowSeconds -> getTimestamp")
            end
            return math.floor(timestamp)
        end
    end

    if os ~= nil and os.time ~= nil then
        if NOW_SOURCE ~= "os.time" then
            NOW_SOURCE = "os.time"
            print("[LastHome] getNowSeconds -> os.time")
        end
        return os.time()
    end

    if getGameTime ~= nil then
        local gameTime = getGameTime()
        if gameTime ~= nil and gameTime.getWorldAgeHours ~= nil then
            if NOW_SOURCE ~= "getGameTime" then
                NOW_SOURCE = "getGameTime"
                print("[LastHome] getNowSeconds -> getGameTime:getWorldAgeHours")
            end
            return math.floor(gameTime:getWorldAgeHours() * 3600)
        end
    end

    if NOW_SOURCE ~= "zero" then
        NOW_SOURCE = "zero"
        print("[LastHome] WARN: getNowSeconds aucun timer disponible, retourne 0")
    end
    return 0
end

-- ============================================================
-- LH-MP-2: scenario bootstrap helpers (MP sandbox hosting)
-- ============================================================

-- Default SandboxVars for Last Home scenarios: disable vanilla zombie
-- population and story spawns so only LH wave/spectator zombies remain.
-- Best-effort on a dedicated server (LH-13 periodic cleanup compensates).
-- Extracted from the 4 challenge setSandBoxVars() bodies (dedup).
function LastHomeShared.applyDefaultSandboxVars()
    if SandboxVars == nil then return end

    SandboxVars.Zombies = 6
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

-- ============================================================
-- LH-MP-6: hardcoded scenario house (replaces the cfg file)
-- ============================================================

-- Scenario house for MP sandbox / Host mode. Edit this line and relaunch
-- to force a house. No cfg file (the file-I/O was never reliable in the
-- SERVER VM: fileExists/getFileReader did not resolve the cfg at
-- OnServerStarted, so the token was silently ignored since LH-MP-2).
--
-- Valid: hospital | villa | prison | elementary_school | random
--   - random = pick one of the 4 at random each server start.
--   - a concrete id forces that building.
LastHomeShared.SCENARIO_HOUSE = "elementary_school"

-- Returns the validated scenario house token (default "random" if the
-- constant is invalid/missing). No file I/O. One source of truth for the
-- bootstrap.
function LastHomeShared.getScenarioHouseId()
    local validIds = { hospital = true, villa = true, prison = true,
                       elementary_school = true }
    local defaultId = "random"

    local value = LastHomeShared.SCENARIO_HOUSE
    if value == nil then
        print("[LastHome] SCENARIO_HOUSE non defini -> random")
        return defaultId
    end

    if value == "random" or validIds[value] then
        print("[LastHome] SCENARIO_HOUSE=" .. tostring(value))
        return value
    end

    print("[LastHome] SCENARIO_HOUSE valeur invalide: " .. tostring(value) .. " -> random")
    return defaultId
end
