require "LastHomeRolePicker"
require "LastHomeRoles"

LastHomeClient = LastHomeClient or {}

local roleRequestSent = false

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
    end
end
Events.OnServerCommand.Add(onServerCommand)
