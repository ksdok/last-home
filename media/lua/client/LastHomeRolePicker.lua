require "ISUI/ISPanel"
require "ISUI/ISButton"
require "LastHomeRoles"

LastHomeRolePicker = LastHomeRolePicker or {}

local RolePickerPanel = ISPanel:derive("LastHomeRolePickerPanel")

local ROLE_ORDER = LastHomeRoles.ROLE_ORDER
local ROLE_INFO = LastHomeRoles.ROLE_INFO

local COLOR_BG = {r = 0.05, g = 0.05, b = 0.05, a = 0.92}
local COLOR_BORDER = {r = 0.7, g = 0.7, b = 0.7, a = 1}
local COLOR_ROW = {r = 0.14, g = 0.14, b = 0.14, a = 0.85}
local COLOR_AVAILABLE = {r = 0.2, g = 0.85, b = 0.3, a = 1}
local COLOR_PENDING = {r = 1, g = 0.85, b = 0.2, a = 1}
local COLOR_WHITE = {r = 1, g = 1, b = 1, a = 1}
local COLOR_RED = {r = 0.9, g = 0.35, b = 0.35, a = 1}

LastHomeRolePicker.panel = nil
LastHomeRolePicker.pendingRole = nil
LastHomeRolePicker.statusText = nil
LastHomeRolePicker.statusColor = COLOR_WHITE

local function setButtonEnabled(button, enabled)
    if button == nil then return end
    if button.setEnable ~= nil then
        button:setEnable(enabled)
    else
        button.enable = enabled
    end
end

local function setButtonTitle(button, title)
    if button == nil then return end
    if button.setTitle ~= nil then
        button:setTitle(title)
    else
        button.title = title
    end
end

function RolePickerPanel:initialise()
    ISPanel.initialise(self)
end

function RolePickerPanel:createChildren()
    ISPanel.createChildren(self)

    if self.roleButtons ~= nil then return end

    self.roleButtons = {}
    self.cardLayouts = {}
    self.rowTop = 92
    self.rowHeight = 74
    self.cardHeight = 68
    self.columns = 3
    self.rowsPerColumn = 6
    self.columnGap = 16
    self.buttonWidth = 118
    self.buttonHeight = 24

    local contentWidth = self.width - 32
    self.cardWidth = math.floor((contentWidth - self.columnGap) / self.columns)

    for index, roleKey in ipairs(ROLE_ORDER) do
        local column = math.floor((index - 1) / self.rowsPerColumn)
        local row = (index - 1) % self.rowsPerColumn
        local x = 16 + (column * (self.cardWidth + self.columnGap))
        local y = self.rowTop + (row * self.rowHeight)

        self.cardLayouts[roleKey] = {
            x = x,
            y = y,
            width = self.cardWidth,
            height = self.cardHeight,
        }

        local buttonX = x + self.cardWidth - self.buttonWidth - 10
        local buttonY = y + self.cardHeight - self.buttonHeight - 8
        local button = ISButton:new(buttonX, buttonY, self.buttonWidth, self.buttonHeight, "Choisir", self, RolePickerPanel.onChooseRole)
        button.internal = roleKey
        button:initialise()
        button:instantiate()
        self:addChild(button)
        self.roleButtons[roleKey] = button
    end

    self:updateButtons()
end

function RolePickerPanel:onChooseRole(button)
    local roleKey = button and button.internal or nil
    if roleKey == nil then return end

    LastHomeRolePicker.pendingRole = roleKey
    LastHomeRolePicker.statusText = "Validation du role en cours..."
    LastHomeRolePicker.statusColor = COLOR_PENDING
    self:updateButtons()

    sendClientCommand("LastHome", "ChooseRole", {
        roleKey = roleKey,
    })
end

function RolePickerPanel:updateButtons()
    for _, roleKey in ipairs(ROLE_ORDER) do
        local button = self.roleButtons[roleKey]
        local enabled = LastHomeRolePicker.pendingRole == nil
        local title = "Choisir"

        if LastHomeRolePicker.pendingRole == roleKey then
            enabled = false
            title = "Validation..."
        elseif LastHomeRolePicker.pendingRole ~= nil then
            enabled = false
        end

        setButtonTitle(button, title)
        setButtonEnabled(button, enabled)
    end
end

function RolePickerPanel:prerender()
    ISPanel.prerender(self)

    self:drawTextCentre("Choisis ton role", self.width / 2, 12, 1, 1, 1, 1, UIFont.Medium)
    self:drawText("17 roles disponibles. Les doublons sont autorises et le choix est definitif pour la partie.", 16, 40, 0.9, 0.9, 0.9, 1, UIFont.Small)
    self:drawText("Le Builder conserve son refill automatique. Le Mecanicien est retire pour Last Home.", 16, 58, 0.9, 0.9, 0.9, 1, UIFont.Small)
end

function RolePickerPanel:render()
    ISPanel.render(self)

    for _, roleKey in ipairs(ROLE_ORDER) do
        local info = ROLE_INFO[roleKey]
        local layout = self.cardLayouts[roleKey]
        local rowX = layout.x
        local rowY = layout.y
        local rowWidth = layout.width
        local rowHeight = layout.height

        self:drawRect(rowX, rowY, rowWidth, rowHeight, COLOR_ROW.a, COLOR_ROW.r, COLOR_ROW.g, COLOR_ROW.b)
        self:drawRectBorder(rowX, rowY, rowWidth, rowHeight, 0.8, 0.35, 0.35, 0.35)

        self:drawText(info.name, rowX + 10, rowY + 8, 1, 1, 1, 1, UIFont.Medium)
        self:drawText(info.summary, rowX + 10, rowY + 28, 0.86, 0.86, 0.86, 1, UIFont.Small)
        self:drawText(info.strengths, rowX + 10, rowY + 44, 0.72, 0.72, 0.72, 1, UIFont.Small)

        local statusText = "Disponible"
        local statusColor = COLOR_AVAILABLE
        if LastHomeRolePicker.pendingRole == roleKey then
            statusText = "Validation en cours..."
            statusColor = COLOR_PENDING
        end

        self:drawText(statusText, rowX + 10, rowY + 58, statusColor.r, statusColor.g, statusColor.b, statusColor.a, UIFont.Small)
    end

    if LastHomeRolePicker.statusText ~= nil then
        local c = LastHomeRolePicker.statusColor or COLOR_WHITE
        self:drawTextCentre(LastHomeRolePicker.statusText, self.width / 2, self.height - 24, c.r, c.g, c.b, c.a, UIFont.Small)
    end
end

function LastHomeRolePicker.isVisible()
    return LastHomeRolePicker.panel ~= nil
end

function LastHomeRolePicker.setStatus(text, color)
    LastHomeRolePicker.statusText = text
    LastHomeRolePicker.statusColor = color or COLOR_WHITE
    if LastHomeRolePicker.panel ~= nil then
        LastHomeRolePicker.panel:updateButtons()
    end
end

function LastHomeRolePicker.open()
    LastHomeRolePicker.pendingRole = nil
    LastHomeRolePicker.statusText = nil
    LastHomeRolePicker.statusColor = COLOR_WHITE

    if LastHomeRolePicker.panel ~= nil then
        LastHomeRolePicker.panel:updateButtons()
        return LastHomeRolePicker.panel
    end

    local width = math.min(1040, getCore():getScreenWidth() - 20)
    local height = math.min(620, getCore():getScreenHeight() - 20)
    local x = math.max(10, math.floor((getCore():getScreenWidth() - width) / 2))
    local y = math.max(10, math.floor((getCore():getScreenHeight() - height) / 2))

    local panel = RolePickerPanel:new(x, y, width, height)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = COLOR_BG
    panel.borderColor = COLOR_BORDER
    panel.moveWithMouse = false
    panel:createChildren()
    panel:addToUIManager()

    LastHomeRolePicker.panel = panel
    return panel
end

function LastHomeRolePicker.close()
    LastHomeRolePicker.pendingRole = nil
    if LastHomeRolePicker.panel ~= nil then
        LastHomeRolePicker.panel:removeFromUIManager()
        LastHomeRolePicker.panel = nil
    end
end

local function isLocalUser(data)
    local player = getPlayer()
    return player ~= nil and data ~= nil and data.username == player:getUsername()
end

local function onServerCommand(module, command, data)
    if module ~= "LastHome" then return end

    if command == "OpenRolePicker" then
        if isLocalUser(data) then
            local player = getPlayer()
            if player ~= nil and player:getModData().LH_role == nil then
                LastHomeRolePicker.open()
            end
        end
    elseif command == "RoleAssigned" then
        if isLocalUser(data) then
            local player = getPlayer()
            if player ~= nil then
                player:getModData().LH_role = data.role
            end
            LastHomeRolePicker.close()
        end
    elseif command == "RoleUnavailable" then
        if isLocalUser(data) then
            LastHomeRolePicker.pendingRole = nil
            LastHomeRolePicker.setStatus(data.text or "Role indisponible.", COLOR_RED)
        end
    elseif command == "RoleDenied" then
        if isLocalUser(data) then
            LastHomeRolePicker.pendingRole = nil
            LastHomeRolePicker.setStatus(data.text or "Choix refuse.", COLOR_RED)
        end
    end
end
Events.OnServerCommand.Add(onServerCommand)
