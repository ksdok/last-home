require "ISUI/ISPanel"
require "ISUI/ISButton"
require "LastHomeShared"

LastHomeHousePicker = LastHomeHousePicker or {}

print("[LastHome] LastHomeHousePicker charge")

local DEBUG_ENABLED = LastHomeShared.DEBUG == true

local function logHousePicker(message)
    if not DEBUG_ENABLED then return end
    print("[LastHome][HousePicker] " .. tostring(message))
end

local HousePickerPanel = ISPanel:derive("LastHomeHousePickerPanel")

local COLOR_BG = {r = 0.05, g = 0.05, b = 0.05, a = 0.92}
local COLOR_BORDER = {r = 0.7, g = 0.7, b = 0.7, a = 1}
local COLOR_ROW = {r = 0.14, g = 0.14, b = 0.14, a = 0.85}
local COLOR_AVAILABLE = {r = 0.2, g = 0.85, b = 0.3, a = 1}
local COLOR_PENDING = {r = 1, g = 0.85, b = 0.2, a = 1}
local COLOR_WHITE = {r = 1, g = 1, b = 1, a = 1}
local COLOR_RED = {r = 0.9, g = 0.35, b = 0.35, a = 1}

LastHomeHousePicker.panel = nil
LastHomeHousePicker.entries = {}
LastHomeHousePicker.pendingHouse = nil
LastHomeHousePicker.statusText = nil
LastHomeHousePicker.statusColor = COLOR_WHITE

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

function HousePickerPanel:initialise()
    ISPanel.initialise(self)
end

function HousePickerPanel:createChildren()
    ISPanel.createChildren(self)

    if self.houseButtons ~= nil then return end

    self.houseButtons = {}
    self.rowLayouts = {}

    local entries = LastHomeHousePicker.entries or {}
    local count = #entries
    if count == 0 then
        -- Fallback to the shared ordered list if the server payload was empty.
        entries = LastHomeShared.getHousePickerEntries()
        LastHomeHousePicker.entries = entries
        count = #entries
    end

    local rowHeight = 56
    local rowGap = 8
    local top = 92
    local contentWidth = self.width - 32
    local rowWidth = contentWidth

    for index, entry in ipairs(entries) do
        local y = top + (index - 1) * (rowHeight + rowGap)
        self.rowLayouts[entry.id] = {
            x = 16,
            y = y,
            width = rowWidth,
            height = rowHeight,
        }

        local buttonWidth = 130
        local buttonHeight = 26
        local buttonX = 16 + rowWidth - buttonWidth - 12
        local buttonY = y + rowHeight - buttonHeight - 8
        local button = ISButton:new(buttonX, buttonY, buttonWidth, buttonHeight, "Choisir", self, HousePickerPanel.onChooseHouse)
        button.internal = entry.id
        button:initialise()
        button:instantiate()
        self:addChild(button)
        self.houseButtons[entry.id] = button
    end

    self:updateButtons()
end

function HousePickerPanel:onChooseHouse(button)
    local houseId = button and button.internal or nil
    if houseId == nil then return end

    LastHomeHousePicker.pendingHouse = houseId
    LastHomeHousePicker.statusText = "Validation du lieu en cours..."
    LastHomeHousePicker.statusColor = COLOR_PENDING
    self:updateButtons()

    logHousePicker("Choix lieu demande: " .. tostring(houseId))
    sendClientCommand("LastHome", "ChooseHouse", {
        houseId = houseId,
    })
end

function HousePickerPanel:updateButtons()
    for _, entry in ipairs(LastHomeHousePicker.entries) do
        local button = self.houseButtons[entry.id]
        if button ~= nil then
            local enabled = LastHomeHousePicker.pendingHouse == nil
            local title = "Choisir"

            if LastHomeHousePicker.pendingHouse == entry.id then
                enabled = false
                title = "Validation..."
            elseif LastHomeHousePicker.pendingHouse ~= nil then
                enabled = false
            end

            setButtonTitle(button, title)
            setButtonEnabled(button, enabled)
        end
    end
end

function HousePickerPanel:prerender()
    ISPanel.prerender(self)

    self:drawTextCentre("Choisissez le lieu", self.width / 2, 16, 1, 1, 1, 1, UIFont.Medium)
    self:drawText("Le choix du lieu est definitif pour la partie. Les autres joueurs attendent votre selection.", 16, 44, 0.9, 0.9, 0.9, 1, UIFont.Small)
    self:drawText("Une fois le lieu choisi, le choix des roles s'ouvrira.", 16, 62, 0.9, 0.9, 0.9, 1, UIFont.Small)
end

function HousePickerPanel:render()
    ISPanel.render(self)

    for _, entry in ipairs(LastHomeHousePicker.entries) do
        local layout = self.rowLayouts[entry.id]
        if layout ~= nil then
            local rowX = layout.x
            local rowY = layout.y
            local rowWidth = layout.width
            local rowHeight = layout.height

            self:drawRect(rowX, rowY, rowWidth, rowHeight, COLOR_ROW.a, COLOR_ROW.r, COLOR_ROW.g, COLOR_ROW.b)
            self:drawRectBorder(rowX, rowY, rowWidth, rowHeight, 0.8, 0.35, 0.35, 0.35)

            self:drawText(entry.name or entry.id or "?", rowX + 12, rowY + 10, 1, 1, 1, 1, UIFont.Medium)

            local statusText = "Disponible"
            local statusColor = COLOR_AVAILABLE
            if LastHomeHousePicker.pendingHouse == entry.id then
                statusText = "Validation en cours..."
                statusColor = COLOR_PENDING
            end
            self:drawText(statusText, rowX + 12, rowY + 34, statusColor.r, statusColor.g, statusColor.b, statusColor.a, UIFont.Small)
        end
    end

    if LastHomeHousePicker.statusText ~= nil then
        local c = LastHomeHousePicker.statusColor or COLOR_WHITE
        self:drawTextCentre(LastHomeHousePicker.statusText, self.width / 2, self.height - 26, c.r, c.g, c.b, c.a, UIFont.Small)
    end
end

function LastHomeHousePicker.isVisible()
    return LastHomeHousePicker.panel ~= nil
end

function LastHomeHousePicker.setStatus(text, color)
    LastHomeHousePicker.statusText = text
    LastHomeHousePicker.statusColor = color or COLOR_WHITE
    if LastHomeHousePicker.panel ~= nil then
        LastHomeHousePicker.panel:updateButtons()
    end
end

function LastHomeHousePicker.open(availableHouses)
    LastHomeHousePicker.entries = availableHouses or LastHomeShared.getHousePickerEntries()
    LastHomeHousePicker.pendingHouse = nil
    LastHomeHousePicker.statusText = nil
    LastHomeHousePicker.statusColor = COLOR_WHITE

    logHousePicker("Ouverture du picker (" .. tostring(#LastHomeHousePicker.entries) .. " lieux)")

    if LastHomeHousePicker.panel ~= nil then
        -- Idempotent: already open. Refresh button state only.
        LastHomeHousePicker.panel:updateButtons()
        return LastHomeHousePicker.panel
    end

    local width = math.min(520, getCore():getScreenWidth() - 40)
    local entryCount = #LastHomeHousePicker.entries
    local height = math.min(92 + entryCount * 64 + 40, getCore():getScreenHeight() - 40)
    local x = math.max(10, math.floor((getCore():getScreenWidth() - width) / 2))
    local y = math.max(10, math.floor((getCore():getScreenHeight() - height) / 2))

    local panel = HousePickerPanel:new(x, y, width, height)
    panel:initialise()
    panel:instantiate()
    panel.backgroundColor = COLOR_BG
    panel.borderColor = COLOR_BORDER
    panel.moveWithMouse = false
    panel:createChildren()
    panel:addToUIManager()

    LastHomeHousePicker.panel = panel
    return panel
end

function LastHomeHousePicker.close()
    logHousePicker("Fermeture du picker")
    LastHomeHousePicker.pendingHouse = nil
    if LastHomeHousePicker.panel ~= nil then
        LastHomeHousePicker.panel:removeFromUIManager()
        LastHomeHousePicker.panel = nil
    end
end