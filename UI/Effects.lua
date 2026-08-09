-- DoF/UI/Effects.lua
-- UI для отображения статус-эффектов

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer

DoF.UI = DoF.UI or {}
DoF.UI.Effects = {
    PlayerFrames = {},      -- Иконки на игроке (в PlayerHeader)
    MAX_ICONS = 8,          -- Макс иконок в ряд
    ICON_SIZE = 32,
    ICON_SPACING = 4,
}

local TEX_PATH = "Interface\\AddOns\\DoF\\texture\\"

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ ИКОНКИ ЭФФЕКТА
-- ═══════════════════════════════════════════════════════════

function DoF.UI.Effects:CreateIcon(parent, index)
    local size = self.ICON_SIZE
    local spacing = self.ICON_SPACING
    
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(size, size)
    frame:SetPoint("LEFT", (index - 1) * (size + spacing), 0)
    
    -- Фон
    frame:SetBackdrop(DoF.Utils.Backdrops.Standard)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    
    -- Иконка
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size - 4, size - 4)
    icon:SetPoint("CENTER")
    frame.icon = icon
    
    -- Счётчик раундов (справа внизу)
    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("BOTTOMRIGHT", 2, -2)
    countText:SetFont(DoF.Config.FONT, 11, "OUTLINE")
    countText:SetTextColor(1, 1, 1)
    frame.count = countText

    -- Счётчик стаков (слева вверху)
    local stackText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stackText:SetPoint("TOPLEFT", -2, 2)
    stackText:SetFont(DoF.Config.FONT, 11, "OUTLINE")
    stackText:SetTextColor(0.3, 1, 0.3)
    frame.stacks = stackText
    
    -- Тултип
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self.effectData then
            DoF.UI.Effects:ShowTooltip(self)
        end
    end)
    frame:SetScript("OnLeave", function()
        DoF.Utils:HideTooltip()
    end)
    
    frame:Hide()
    return frame
end

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ КОНТЕЙНЕРОВ
-- ═══════════════════════════════════════════════════════════

function DoF.UI.Effects:Init()
    -- Эффекты показываются только в UnitFrames
    -- TargetFrame удалён из главного окна

    -- Регистрируем события
    DoF.Events:Register("EFFECT_APPLIED", function(targetType, targetId, effectId)
        self:UpdateAll()
    end)
    
    DoF.Events:Register("EFFECT_REMOVED", function(targetType, targetId, effectId)
        self:UpdateAll()
    end)
    
    DoF.Events:Register("EFFECTS_CLEARED", function()
        self:UpdateAll()
    end)
    
    DoF.Events:Register("EFFECTS_SYNCED", function()
        self:UpdateAll()
    end)
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.UI.Effects:UpdateAll()
    -- Эффекты показываются только в UnitFrames
    -- TargetFrame удалён, поэтому UpdateTarget/UpdatePlayer не нужны
end

function DoF.UI.Effects:UpdatePlayer()
    -- Эффекты игрока показываются только в UnitFrames
end

function DoF.UI.Effects:UpdateTarget()
    -- TargetFrame удалён из главного окна
    -- Эффекты на целях показываются через UnitFrames
end

function DoF.UI.Effects:UpdateContainer(frames, effects)
    if not frames then return end
    -- Скрываем все иконки
    self:HideAll(frames)

    -- Отображаем активные эффекты
    local index = 1
    for effectId, effectData in pairs(effects) do
        if index > self.MAX_ICONS then break end

        local frame = frames[index]
        if frame then
            local def = DoF.Effects.Definitions[effectId]
            if def then
                self:SetupIcon(frame, def, effectData)
                frame:Show()
                index = index + 1
            end
        end
    end
end

function DoF.UI.Effects:SetupIcon(frame, def, effectData)
    -- Иконка
    frame.icon:SetTexture(def.icon)
    
    -- Цвет рамки по типу эффекта
    local borderColor
    if def.type == "buff" then
        borderColor = {0.2, 0.8, 0.2, 1}  -- Зелёный
    elseif def.type == "debuff" then
        borderColor = {0.8, 0.2, 0.2, 1}  -- Красный
    elseif def.type == "dot" then
        borderColor = {0.9, 0.5, 0.1, 1}  -- Оранжевый
    else
        borderColor = {0.5, 0.5, 0.5, 1}  -- Серый
    end
    frame:SetBackdropBorderColor(unpack(borderColor))
    
    -- Счётчик раундов
    frame.count:SetText(effectData.remainingRounds)
    
    -- Счётчик стаков (показываем только если > 1)
    local stacks = effectData.stacks or 1
    if stacks > 1 then
        frame.stacks:SetText("x" .. stacks)
        frame.stacks:Show()
    else
        frame.stacks:SetText("")
        frame.stacks:Hide()
    end
    
    -- Данные для тултипа
    frame.effectData = effectData
    frame.effectDef = def
end

function DoF.UI.Effects:HideAll(frames)
    if not frames then return end
    for _, frame in ipairs(frames) do
        frame:Hide()
        frame.effectData = nil
        frame.effectDef = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- ТУЛТИП
-- ═══════════════════════════════════════════════════════════

function DoF.UI.Effects:ShowTooltip(frame)
    local def = frame.effectDef
    local data = frame.effectData

    if not def or not data then return end

    local lines = {}

    -- Название с цветом
    local color = def.color or {1, 1, 1}
    local r, g, b = color[1] or 1, color[2] or 1, color[3] or 1
    local nameText = def.name
    if data.stacks and data.stacks > 1 then
        nameText = nameText .. " (x" .. data.stacks .. ")"
    end
    lines[#lines + 1] = {nameText, r, g, b, 14}

    -- Тип
    if def.type == "buff" then
        lines[#lines + 1] = {DoF.L["ui.common.buff"], 0, 1, 0, 13}
    elseif def.type == "debuff" then
        lines[#lines + 1] = {DoF.L["ui.common.debuff"], 1, 0, 0, 13}
    elseif def.type == "dot" then
        lines[#lines + 1] = {DoF.L["ui.common.dot"], 1, 0.53, 0, 13}
    end

    -- Описание
    lines[#lines + 1] = {def.description, 0.8, 0.8, 0.8, 13}

    -- Значение
    if data.value and data.value > 0 then
        if def.type == "dot" or def.isHoT then
            local actionText = def.isHoT and DoF.L["ui.effect.heals"] or DoF.L["ui.common.damage"]
            lines[#lines + 1] = {DoF.Locale:Format("ui.effect.per_round", actionText, data.value), 1, 0.82, 0, 13}
        elseif def.statMod then
            local modText = def.modType == "increase" and "+" or "-"
            lines[#lines + 1] = {DoF.Locale:Format("ui.effect.modifier", modText .. data.value), 1, 0.82, 0, 13}
        end
    end

    -- Длительность
    local remaining = data.remainingRounds or 0
    lines[#lines + 1] = {DoF.Locale:Format("ui.effect.remaining", remaining,
        DoF.Locale:Plural(remaining, DoF.L["ui.rounds_one"], DoF.L["ui.rounds_few"], DoF.L["ui.rounds_many"])),
        0.7, 0.7, 0.7, 13}

    -- Кто наложил
    if data.casters and #data.casters > 0 then
        local castersText
        if #data.casters == 1 then
            castersText = DoF.Locale:Format("ui.effect.caster_one", data.casters[1])
        else
            castersText = DoF.Locale:Format("ui.effect.caster_many", table.concat(data.casters, ", "))
        end
        lines[#lines + 1] = {castersText, 0.5, 0.5, 0.5, 11}
    elseif data.caster then
        lines[#lines + 1] = {DoF.Locale:Format("ui.effect.caster_one", data.caster), 0.5, 0.5, 0.5, 11}
    end

    DoF.Utils:ShowTooltip(frame, lines, "RIGHT")
end

-- NB: ранее здесь жил DoF.UI:InitEffectsUI() — обёртка вокруг DoF.UI.Effects:Init,
-- дёргавшаяся из удалённого InitMainFrameUI. После удаления главного окна иконки
-- эффектов показываются только в UnitFrames, у которых свой update-путь;
-- обёртка стала мёртвой и удалена. Сам модуль DoF.UI.Effects оставлен на случай
-- возврата иконок эффектов в будущем UI.
