-- Last Home - LH-05: boundary/confinement system extracted from LastHomeWaves.
--
-- Players with an assigned role who leave the house boundary during an active
-- phase (prep/wave) receive a 10-second countdown, then take periodic damage
-- until they return. Spectators and dead players are exempt.

require "LastHomeShared"

LastHomeBoundary = LastHomeBoundary or {}

local getRoleKey = LastHomeShared.getRoleKey

local COUNTDOWN_SECONDS = 10
local DAMAGE_AMOUNT = 5

local Server = nil          -- set via attach()

-- Dependencies injected from the parent module (LastHomeWaves).
local deps = {}

function LastHomeBoundary.attach(serverTable, dependencies)
    Server = serverTable
    deps = dependencies or {}
end

-- ------------------------------------------------------------------
-- State helpers
-- ------------------------------------------------------------------

local function log(msg)
    if deps.log then deps.log(msg) end
end

local function syncOne(username)
    LastHomeBoundary.syncTo(username)
end

local function notify(username, text, alertType, duration)
    if deps.notifyPlayer then deps.notifyPlayer(username, text, alertType, duration) end
end

local function isEnabled()
    if Server == nil then return false end
    local hasB = deps.hasBoundary
    return Server.started and not Server.gameOver
        and Server.phase ~= "idle" and Server.phase ~= "gameover"
        and Server.house ~= nil and hasB ~= nil and hasB(Server.house)
end

-- ------------------------------------------------------------------
-- Public API
-- ------------------------------------------------------------------

function LastHomeBoundary.init()
    if Server == nil then return end
    Server.boundaryStates = {}
    Server.boundaryDebugTrace = {}
    Server.lastBoundaryEnabledDebugKey = nil
end

function LastHomeBoundary.syncTo(username)
    if username == nil then return end
    local state = Server.boundaryStates[username]
    log("Sync BoundaryState -> " .. tostring(username) .. " status=" .. tostring(state ~= nil and state.status or "inside") .. ", fin=" .. tostring(state ~= nil and state.countdownEndsAt or 0))
    sendServerCommand("LastHome", "BoundaryState", {
        username = username,
        status = state ~= nil and state.status or "inside",
        countdownEndsAt = state ~= nil and state.countdownEndsAt or 0,
    })
end

function LastHomeBoundary.resetOne(username)
    if username == nil then return false end
    local state = Server.boundaryStates[username]
    if state == nil then return false end
    log("Reset BoundaryState pour " .. tostring(username) .. " (ancien status=" .. tostring(state.status) .. ", fin=" .. tostring(state.countdownEndsAt or 0) .. ")")
    Server.boundaryStates[username] = nil
    syncOne(username)
    return true
end

function LastHomeBoundary.resetAll()
    if Server.boundaryStates == nil then return end
    local usernames = {}
    for username, _ in pairs(Server.boundaryStates) do
        usernames[#usernames + 1] = username
    end
    if #usernames <= 0 then return end
    Server.boundaryStates = {}
    for _, username in ipairs(usernames) do
        syncOne(username)
    end
end

function LastHomeBoundary.getOrCreateState(username)
    if username == nil then return nil end
    local state = Server.boundaryStates[username]
    if state == nil then
        state = { status = "inside", countdownEndsAt = 0, lastDamageAt = 0 }
        Server.boundaryStates[username] = state
    end
    return state
end

function LastHomeBoundary.applyDamage(player)
    if player == nil then return end
    local bodyDamage = player.getBodyDamage ~= nil and player:getBodyDamage() or nil
    if bodyDamage ~= nil and bodyDamage.ReduceGeneralHealth ~= nil then
        bodyDamage:ReduceGeneralHealth(DAMAGE_AMOUNT)
        return
    end
    if player.getHealth ~= nil and player.setHealth ~= nil then
        player:setHealth(math.max(0, player:getHealth() - DAMAGE_AMOUNT))
    end
end

-- ------------------------------------------------------------------
-- Per-tick update (called from LastHomeWaves.OnTick)
-- ------------------------------------------------------------------

local function debugTrace(username, key, message)
    if username == nil then return end
    Server.boundaryDebugTrace = Server.boundaryDebugTrace or {}
    if Server.boundaryDebugTrace[username] == key then return end
    Server.boundaryDebugTrace[username] = key
    log(message)
end

function LastHomeBoundary.updateAll(now)
    if Server == nil then return end

    local fmtHouse = deps.formatBoundaryLabel or tostring
    local fmtCoords = deps.formatPlayerCoords or tostring
    local isInside = deps.isInsideBoundary
    local isAlive = deps.isPlayerAlive
    local players = deps.getScenarioPlayers ~= nil and deps.getScenarioPlayers() or {}

    local enabled = isEnabled()
    local debugKey = tostring(enabled) .. "|" .. tostring(Server.started) .. "|" .. tostring(Server.gameOver) .. "|" .. tostring(Server.phase) .. "|" .. fmtHouse(Server.house)

    if Server.lastBoundaryEnabledDebugKey ~= debugKey then
        Server.lastBoundaryEnabledDebugKey = debugKey
        log("Confinement actif=" .. tostring(enabled) .. ", started=" .. tostring(Server.started) .. ", gameOver=" .. tostring(Server.gameOver) .. ", phase=" .. tostring(Server.phase) .. ", house=" .. fmtHouse(Server.house))
    end

    if not enabled then
        LastHomeBoundary.resetAll()
        return
    end

    for _, player in ipairs(players) do
        if player ~= nil then
            local username = player:getUsername()
            if username ~= nil then
                local modData = player:getModData()
                local roleKey = getRoleKey ~= nil and getRoleKey(modData) or (modData ~= nil and modData.LH_role or nil)
                local isDead = modData ~= nil and modData.LH_dead == true
                local isSpectator = modData ~= nil and modData.LH_spectator == true
                local alive = isAlive ~= nil and isAlive(player)
                local shouldCheck = roleKey ~= nil and not isDead and not isSpectator and alive

                if not shouldCheck then
                    debugTrace(username, "skip|" .. tostring(roleKey) .. "|" .. tostring(isDead) .. "|" .. tostring(isSpectator) .. "|" .. tostring(alive),
                        "Skip confinement pour " .. tostring(username) .. " - role=" .. tostring(roleKey) .. ", dead=" .. tostring(isDead) .. ", spectator=" .. tostring(isSpectator) .. ", alive=" .. tostring(alive) .. ", coords=" .. fmtCoords(player))
                    LastHomeBoundary.resetOne(username)
                else
                    local inside = isInside == nil or isInside(player, Server.house)
                    local state = Server.boundaryStates[username]

                    if inside then
                        if state ~= nil then
                            debugTrace(username, "inside", "Retour dans la zone pour " .. tostring(username) .. " - coords=" .. fmtCoords(player) .. ", house=" .. fmtHouse(Server.house))
                        else
                            debugTrace(username, "inside", "Dans la zone pour " .. tostring(username) .. " - coords=" .. fmtCoords(player) .. ", house=" .. fmtHouse(Server.house))
                        end
                        if LastHomeBoundary.resetOne(username) then
                            notify(username, "[Last Home] De retour dans la zone.", "success", 4)
                        end
                    else
                        if state == nil then
                            state = LastHomeBoundary.getOrCreateState(username)
                            state.status = "countdown"
                            state.countdownEndsAt = now + COUNTDOWN_SECONDS
                            state.lastDamageAt = 0
                            debugTrace(username, "countdown|" .. tostring(state.countdownEndsAt), "Sortie de zone detectee pour " .. tostring(username) .. " - coords=" .. fmtCoords(player) .. ", countdownFin=" .. tostring(state.countdownEndsAt) .. ", house=" .. fmtHouse(Server.house))
                            syncOne(username)
                            notify(username, "[Last Home] Hors zone ! Revenez dans 10s.", "danger", 4)
                        elseif state.status == "countdown" and now >= (state.countdownEndsAt or 0) then
                            state.status = "damaging"
                            state.lastDamageAt = 0
                            debugTrace(username, "damaging", "Degats de confinement actifs pour " .. tostring(username) .. " - coords=" .. fmtCoords(player) .. ", house=" .. fmtHouse(Server.house))
                            syncOne(username)
                            notify(username, "[Last Home] Hors zone ! Degats actifs.", "danger", 4)
                        end

                        if state.status == "damaging" and (state.lastDamageAt == nil or now > state.lastDamageAt) then
                            state.lastDamageAt = now
                            LastHomeBoundary.applyDamage(player)
                            log("Tick degats confinement pour " .. tostring(username) .. " - coords=" .. fmtCoords(player) .. ", amount=" .. tostring(DAMAGE_AMOUNT))
                        end
                    end
                end
            end
        end
    end
end
