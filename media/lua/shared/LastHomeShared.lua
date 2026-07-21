LastHomeShared = LastHomeShared or {}

function LastHomeShared.round(value)
    if value == nil then return 0 end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
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
            return math.floor(timestamp)
        end
    end

    if os ~= nil and os.time ~= nil then
        return os.time()
    end

    if getGameTime ~= nil then
        local gameTime = getGameTime()
        if gameTime ~= nil and gameTime.getWorldAgeHours ~= nil then
            return math.floor(gameTime:getWorldAgeHours() * 3600)
        end
    end

    return 0
end
