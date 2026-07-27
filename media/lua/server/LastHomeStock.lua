-- Last Home - LH-19: stock ground spawn and post-spawn maintenance extracted from
-- LastHomeServer. Spawns the community stock items on the ground at the house's
-- stockSpawn location and retries over several ticks in case the chunk isn't loaded.

LastHomeStock = LastHomeStock or {}

local HOUSE_SUPPLY_MULTIPLIER = 4
local POST_SPAWN_MAINTENANCE_RETRY_SECONDS = 2
local POST_SPAWN_MAINTENANCE_MAX_ATTEMPTS = 8
local STOCK_WORLD_ITEM_OFFSETS = {
    {0.2, 0.2}, {0.5, 0.2}, {0.8, 0.2},
    {0.2, 0.5}, {0.5, 0.5}, {0.8, 0.5},
    {0.2, 0.8}, {0.5, 0.8}, {0.8, 0.8},
}

-- Injected dependencies (set via attach).
local Server = nil
local deps = {}

function LastHomeStock.attach(serverTable, dependencies)
    Server = serverTable
    deps = dependencies or {}
end

-- ------------------------------------------------------------------
-- Internal helpers
-- ------------------------------------------------------------------

local function getStockWorldItemOffset(index)
    local offsets = STOCK_WORLD_ITEM_OFFSETS
    local entry = offsets[((index - 1) % #offsets) + 1]
    return entry[1], entry[2]
end

local function getStockGroundSquares(house)
    local getStockSpawn = deps.getHouseStockSpawn
    local stockSpawn = getStockSpawn ~= nil and getStockSpawn(house) or nil
    if stockSpawn == nil then return nil, nil end

    local cell = getCell ~= nil and getCell() or nil
    if cell == nil or cell.getGridSquare == nil then return nil, stockSpawn end

    local round = deps.round or math.floor
    local sx = round(stockSpawn.x)
    local sy = round(stockSpawn.y)
    local sz = round(stockSpawn.z or house.centerZ or 0)
    local centerSquare = cell:getGridSquare(sx, sy, sz)
    if centerSquare == nil then
        return nil, { x = sx, y = sy, z = sz }
    end

    local squares = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            local square = cell:getGridSquare(sx + dx, sy + dy, sz)
            if square ~= nil then
                squares[#squares + 1] = square
            end
        end
    end

    return squares, { x = sx, y = sy, z = sz }
end

-- ------------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------------

function LastHomeStock.spawnOnGround(house, communityStockItems)
    if house == nil then return false end
    if Server == nil then return false end
    if Server.stockGroundSpawned then return true end

    local stockSquares, stockSpawn = getStockGroundSquares(house)
    if stockSquares == nil or stockSpawn == nil then
        return false
    end

    local totalAdded = 0
    local totalTypes = 0
    local failedTypes = 0
    local partialFailures = 0
    local fmtCoords = deps.formatCoords or tostring

    for typeIndex, refillDef in ipairs(communityStockItems) do
        local itemId = refillDef[1]
        local baseTargetCount = refillDef[2] or 0
        local targetCount = baseTargetCount * HOUSE_SUPPLY_MULTIPLIER

        if itemId ~= nil and targetCount > 0 then
            totalTypes = totalTypes + 1
            local targetSquare = stockSquares[((typeIndex - 1) % #stockSquares) + 1]
            local spawnedForType = 0

            for itemIndex = 1, targetCount do
                local offX, offY = getStockWorldItemOffset(itemIndex)
                local ok, err = pcall(function()
                    targetSquare:AddWorldInventoryItem(itemId, offX, offY, 0)
                end)

                if ok then
                    spawnedForType = spawnedForType + 1
                    totalAdded = totalAdded + 1
                elseif spawnedForType == 0 then
                    failedTypes = failedTypes + 1
                    print("[LastHome] WARN: stock au sol - spawn echec pour " .. tostring(itemId) .. " sur " .. tostring(house.name or house.id or "?") .. " a " .. fmtCoords(stockSpawn.x, stockSpawn.y, stockSpawn.z) .. " err=" .. tostring(err))
                    break
                else
                    partialFailures = partialFailures + 1
                    print("[LastHome] WARN: stock au sol - spawn partiel pour " .. tostring(itemId) .. " sur " .. tostring(house.name or house.id or "?") .. " a " .. fmtCoords(stockSpawn.x, stockSpawn.y, stockSpawn.z) .. " (" .. tostring(spawnedForType) .. "/" .. tostring(targetCount) .. " spawnes) err=" .. tostring(err))
                    break
                end
            end
        end
    end

    Server.stockGroundSpawned = true
    print("[LastHome] Stock au sol spawn: " .. tostring(totalTypes) .. " types, " .. tostring(totalAdded) .. " items sur " .. tostring(#stockSquares) .. " carres a " .. fmtCoords(stockSpawn.x, stockSpawn.y, stockSpawn.z) .. " pour " .. tostring(house.name or house.id or "?") .. " (types en echec=" .. tostring(failedTypes) .. ", echec partiel=" .. tostring(partialFailures) .. ")")
    return true
end

function LastHomeStock.ensureOnGround(house, communityStockItems)
    if Server == nil then return true end
    if Server.stockGroundSpawned then return true end
    return LastHomeStock.spawnOnGround(house, communityStockItems) == true
end

function LastHomeStock.scheduleMaintenance(house, spawnData, username)
    if house == nil or spawnData == nil then
        if Server ~= nil then Server.pendingPostSpawnMaintenance = nil end
        return
    end

    local getNow = deps.getNowSeconds or os.time
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
        nextAttemptAt = getNow(),
        stockReady = false,
    }
end

function LastHomeStock.processMaintenance(now, communityStockItems, ensureSelectedHouse, clearAmbientZombiesNearSpawn)
    if Server == nil then return end
    local pending = Server.pendingPostSpawnMaintenance
    if pending == nil then return end
    if now < (pending.nextAttemptAt or 0) then return end

    local house = ensureSelectedHouse ~= nil and ensureSelectedHouse() or nil
    if house == nil or house.id ~= pending.houseId then
        Server.pendingPostSpawnMaintenance = nil
        return
    end

    pending.attempts = (pending.attempts or 0) + 1
    local attemptLabel = "role-spawn#" .. tostring(pending.attempts)
    if clearAmbientZombiesNearSpawn ~= nil then
        clearAmbientZombiesNearSpawn(house, pending.spawnData, attemptLabel)
    end

    if not pending.stockReady then
        pending.stockReady = LastHomeStock.ensureOnGround(house, communityStockItems) == true
    end

    if pending.stockReady or pending.attempts >= (pending.maxAttempts or POST_SPAWN_MAINTENANCE_MAX_ATTEMPTS) then
        if not pending.stockReady then
            print("[LastHome] WARN: postSpawnMaintenance - stock au sol toujours indisponible (chunk non charge ou spawn echec) pour " .. tostring(pending.houseName) .. " apres " .. tostring(pending.attempts) .. " tentatives")
        end
        Server.pendingPostSpawnMaintenance = nil
        return
    end

    pending.nextAttemptAt = now + POST_SPAWN_MAINTENANCE_RETRY_SECONDS
end
