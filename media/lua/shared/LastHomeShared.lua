LastHomeShared = LastHomeShared or {}

if LastHomeShared.DEBUG == nil then
    LastHomeShared.DEBUG = false
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
    },
    {
        id = "prison",
        name = "Prison",
        centerX = 7683,
        centerY = 11863,
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
            radius = 4,
        },
        supply = {
            x = 10616,
            y = 9971,
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
    if type(playerOrX) == "table" then
        if playerOrX.getX == nil or playerOrX.getY == nil then return true end
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
