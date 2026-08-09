-- DoF/UI/UnitFrames.lua
-- Компактные Unit Frames для игрока и цели

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitIsGroupLeader = UnitIsGroupLeader
local SetPortraitTexture = SetPortraitTexture
local MouseIsOver = MouseIsOver
local C_Timer = C_Timer
local IsInGroup = IsInGroup

DoF.UI = DoF.UI or {}
DoF.UI.UnitFrames = {
    PlayerFrame = nil,
    TargetFrame = nil,
    EffectFrames = {
        Player = {},
        Target = {},
    },
    MAX_EFFECT_ICONS = 8,
    EFFECT_ICON_SIZE = 22,
}

local UF = DoF.UI.UnitFrames

-- Может ли менять статы игроков/NPC — разрешено только мастеру (или соло-режим)
local function CanModifyPlayers()
    if not IsInGroup() then return true end
    return DoF.Sync and DoF.Sync:IsMaster() or false
end

local CanModifyNPCs = CanModifyPlayers

-- ═══════════════════════════════════════════════════════════
-- КОНСТАНТЫ
-- ═══════════════════════════════════════════════════════════

local TEX_PATH = "Interface\\AddOns\\DoF\\texture\\"
local BAR_TEXTURE = "Interface\\AddOns\\DoF\\texture\\bar_texture"

local HP_TEX_GREEN  = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_green"
local HP_TEX_YELLOW = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_yellow"
local HP_TEX_RED    = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_red"
local ENERGY_TEX    = "Interface\\AddOns\\DoF\\texture\\bars\\Energy_bar"

local CLASS_BG_PATH = "Interface\\AddOns\\DoF\\texture\\Unitframes\\Unitframe_back_"
local CLASS_BG_MAP = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    DEATHKNIGHT = "Deathknight",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    MONK = "Monk",
    DRUID = "Druid",
    DEMONHUNTER = "Demonhunter",
}

local COLORS = {
    -- Фон и рамки
    bg = { 0.08, 0.08, 0.08, 0.95 },
    border = { 0.2, 0.2, 0.2, 1 },
    borderHover = { 0.4, 0.4, 0.4, 1 },

    -- HP бар
    hpHigh = { 0.07, 0.56, 0.27 },    -- Зелёный (>50%)
    hpMid = { 0.8, 0.6, 0.1 },        -- Жёлтый (25-50%)
    hpLow = { 0.7, 0.15, 0.1 },       -- Красный (<25%)
    hpNPC = { 0.55, 0, 0 },           -- Красный для NPC

    -- Щит
    shield = { 0.4, 0.78, 1.0, 0.7 },

    -- Энергия
    energy = { 0.13, 0.5, 0.69 },

    -- Эффекты
    buffBorder = { 0.18, 0.54, 0.18, 1 },
    debuffBorder = { 0.54, 0.18, 0.18, 1 },
    woundBorder = { 0.8, 0, 0, 1 },

    -- Пороги защиты NPC
    fortitude = { 0.64, 0.19, 0.79 },  -- #a330c9
    reflex = { 1.0, 0.49, 0.04 },      -- #ff7d0a
    will = { 0.53, 0.53, 0.93 },       -- #8787ed

    -- Кнопки управления
    btnActive = { 0.2, 0.8, 0.2, 1 },
    btnInactive = { 0.25, 0.25, 0.25, 1 },
    btnLocked = { 0.8, 0.8, 0.2, 1 },
}

local BACKDROP = DoF.Utils.Backdrops.Standard

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

function UF:Init()
    -- Создаём фреймы
    self:CreatePlayerFrame()
    self:CreateTargetFrame()

    -- Регистрируем события
    self:RegisterEvents()

    -- Загружаем позиции
    self:LoadPosition("player")
    self:LoadPosition("target")

    -- Применяем масштаб
    self:ApplyScale("player")
    self:ApplyScale("target")

    -- Показываем фрейм игрока если включён
    if DoF.db.profile.unitFrames.player.enabled then
        self.PlayerFrame:Show()
        self:UpdatePlayerFrame()
    end

    -- Начальное состояние secure кнопки для таргета себя
    if DoF.db.profile.unitFrames.player.locked and self.PlayerFrame.secureTargetBtn then
        self.PlayerFrame.secureTargetBtn:Show()
    end

    -- Обновляем кнопки управления
    self:UpdateControlButtons()
end

-- ═══════════════════════════════════════════════════════════
-- PLAYER FRAME
-- ═══════════════════════════════════════════════════════════

function UF:CreatePlayerFrame()
    local frame = CreateFrame("Frame", "DoF_PlayerUnitFrame", UIParent, "BackdropTemplate")
    frame:SetSize(240, 115)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()

    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(unpack(COLORS.bg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))

    -- Классовый фон
    local classBg = frame:CreateTexture("$parent_ClassBG", "ARTWORK", nil, -8)
    classBg:SetAllPoints()
    classBg:SetAlpha(0.45)
    local _, classToken = UnitClass("player")
    local classKey = CLASS_BG_MAP[classToken]
    if classKey then
        classBg:SetTexture(CLASS_BG_PATH .. classKey)
    end
    frame.classBg = classBg

    -- Перетаскивание
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not DoF.db.profile.unitFrames.player.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        UF:SavePosition("player")
    end)

    -- Создаём компоненты
    self:CreatePlayerPortrait(frame)
    self:CreatePlayerInfo(frame)
    self:CreatePlayerBars(frame)
    self:CreatePlayerEffectsRow(frame)

    -- Показывать кнопки +/- только при наведении (мастер, соло или делегат с stats)
    frame:HookScript("OnEnter", function(self)
        if CanModifyPlayers() then
            if self.bars and self.bars.hpBar and self.bars.energyBar then
                -- Отменяем таймер скрытия если он есть
                if self.bars.hideTimer then
                    self.bars.hideTimer:Cancel()
                    self.bars.hideTimer = nil
                end
                self.bars.hpBar.minusBtn:Show()
                self.bars.hpBar.plusBtn:Show()
                self.bars.energyBar.minusBtn:Show()
                self.bars.energyBar.plusBtn:Show()
            end
        end
    end)
    frame:HookScript("OnLeave", function(self)
        if self.bars and self.bars.hpBar and self.bars.energyBar then
            -- Прячем кнопки с задержкой
            UF:HideModifyButtonsDelayed(self.bars)
        end
    end)

    -- Безопасная кнопка для таргета себя (показывается только при locked)
    local secureBtn = CreateFrame("Button", "DoF_PlayerFrame_TargetBtn", frame, "SecureActionButtonTemplate")
    secureBtn:SetAllPoints()
    secureBtn:SetAttribute("type", "target")
    secureBtn:SetAttribute("unit", "player")
    secureBtn:RegisterForClicks("LeftButtonDown")
    secureBtn:SetFrameLevel(frame:GetFrameLevel() + 2)
    secureBtn:Hide()
    -- Проброс hover-событий на родительский фрейм для показа +/- кнопок
    secureBtn:HookScript("OnEnter", function()
        local scripts = frame:GetScript("OnEnter")
        if scripts then scripts(frame) end
    end)
    secureBtn:HookScript("OnLeave", function()
        local scripts = frame:GetScript("OnLeave")
        if scripts then scripts(frame) end
    end)
    frame.secureTargetBtn = secureBtn

    self.PlayerFrame = frame
    return frame
end

function UF:CreatePlayerPortrait(parent)
    -- Контейнер портрета
    local container = CreateFrame("Frame", "$parent_Portrait", parent, "BackdropTemplate")
    container:SetSize(48, 48)
    container:SetPoint("TOPLEFT", 8, -8)

    container:SetBackdrop(BACKDROP)
    container:SetBackdropColor(0.05, 0.05, 0.05, 1)
    container:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Текстура портрета
    local texture = container:CreateTexture("$parent_Texture", "ARTWORK")
    texture:SetSize(44, 44)
    texture:SetPoint("CENTER")
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Обрезка для круглого вида
    container.texture = texture

    -- Маска для круглого портрета
    local mask = container:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)

    -- Бейдж уровня
    local levelBadge = CreateFrame("Frame", "$parent_LevelBadge", container, "BackdropTemplate")
    levelBadge:SetSize(24, 16)
    levelBadge:SetPoint("BOTTOM", 0, -6)
    levelBadge:SetBackdrop(BACKDROP)
    levelBadge:SetBackdropColor(0.15, 0.15, 0.15, 1)
    levelBadge:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local levelText = levelBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("CENTER")
    levelText:SetTextColor(1, 0.82, 0)
    levelBadge.text = levelText

    parent.portrait = container
    parent.levelBadge = levelBadge
end

function UF:CreatePlayerInfo(parent)
    -- Контейнер для имени и иконок
    local info = CreateFrame("Frame", "$parent_Info", parent)
    info:SetSize(170, 20)
    info:SetPoint("TOPLEFT", parent.portrait, "TOPRIGHT", 8, -2)

    -- Имя игрока
    local name = info:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("LEFT", 0, 0)
    name:SetTextColor(1, 0.82, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    info.name = name

    -- Иконка роли
    local roleIcon = info:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(20, 20)
    roleIcon:SetPoint("LEFT", name, "RIGHT", 2, 0)
    info.roleIcon = roleIcon

    -- Кнопка информации (показывает статы)
    local infoBtn = CreateFrame("Button", "$parent_InfoBtn", info, "BackdropTemplate")
    infoBtn:SetSize(20, 20)
    infoBtn:SetPoint("RIGHT", 0, 0)
    infoBtn:SetBackdrop(BACKDROP)
    infoBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    infoBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    infoBtn:SetFrameLevel(parent:GetFrameLevel() + 10)

    local infoIcon = infoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoIcon:SetPoint("CENTER")
    infoIcon:SetText("i")
    infoIcon:SetTextColor(0.7, 0.7, 0.7)

    infoBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        infoIcon:SetTextColor(1, 1, 1)
        UF:ShowPlayerStatsTooltip(self)
    end)
    infoBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        infoIcon:SetTextColor(0.7, 0.7, 0.7)
        DoF.Utils:HideTooltip()
    end)

    info.infoBtn = infoBtn
    parent.info = info
end

function UF:CreatePlayerBars(parent)
    -- Контейнер для баров
    local barsContainer = CreateFrame("Frame", "$parent_Bars", parent)
    barsContainer:SetSize(170, 36)
    barsContainer:SetPoint("TOPLEFT", parent.portrait, "TOPRIGHT", 8, -24)

    -- HP бар
    local hpBar = CreateFrame("StatusBar", "$parent_HPBar", barsContainer, "BackdropTemplate")
    hpBar:SetSize(170, 18)
    hpBar:SetPoint("TOP")
    hpBar:SetStatusBarTexture(HP_TEX_GREEN)
    hpBar:SetStatusBarColor(1, 1, 1)
    hpBar:SetBackdrop(BACKDROP)
    hpBar:SetBackdropColor(0.04, 0.04, 0.04, 1)
    hpBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Щит (overlay)
    local shieldBar = CreateFrame("StatusBar", "$parent_ShieldBar", hpBar)
    shieldBar:SetSize(166, 14)
    shieldBar:SetPoint("LEFT", 2, 0)
    shieldBar:SetStatusBarTexture(BAR_TEXTURE)
    shieldBar:SetStatusBarColor(unpack(COLORS.shield))
    shieldBar:SetFrameLevel(hpBar:GetFrameLevel() + 1)
    shieldBar:Hide()
    hpBar.shieldBar = shieldBar

    -- HP текст
    local hpText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpText:SetPoint("CENTER")
    hpText:SetTextColor(1, 1, 1)
    hpText:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    hpBar.text = hpText

    -- Текст щита (справа)
    local shieldText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shieldText:SetPoint("RIGHT", -4, 0)
    shieldText:SetTextColor(0.4, 0.78, 1)
    shieldText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    shieldText:Hide()
    hpBar.shieldText = shieldText

    -- HP кнопки +/-
    local hpMinusBtn = CreateFrame("Button", "$parent_HPMinusBtn", hpBar, "BackdropTemplate")
    hpMinusBtn:SetSize(16, 16)
    hpMinusBtn:SetPoint("LEFT", 2, 0)
    hpMinusBtn:SetBackdrop(BACKDROP)
    hpMinusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    hpMinusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    hpMinusBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
    hpMinusBtn:Hide()

    local hpMinusText = hpMinusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hpMinusText:SetPoint("CENTER")
    hpMinusText:SetText("-")
    hpMinusText:SetTextColor(0.8, 0.3, 0.3)

    hpMinusBtn:SetScript("OnClick", function()
        if DoF.Stats and DoF.Stats.ModifyHP then
            DoF.Stats:ModifyHP(-1)
        end
    end)
    hpMinusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
        -- Отменяем скрытие кнопок
        if barsContainer.hideTimer then
            barsContainer.hideTimer:Cancel()
            barsContainer.hideTimer = nil
        end
    end)
    hpMinusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        -- Прячем кнопки с задержкой
        UF:HideModifyButtonsDelayed(barsContainer)
    end)
    hpBar.minusBtn = hpMinusBtn

    local hpPlusBtn = CreateFrame("Button", "$parent_HPPlusBtn", hpBar, "BackdropTemplate")
    hpPlusBtn:SetSize(16, 16)
    hpPlusBtn:SetPoint("RIGHT", -2, 0)
    hpPlusBtn:SetBackdrop(BACKDROP)
    hpPlusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    hpPlusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    hpPlusBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
    hpPlusBtn:Hide()

    local hpPlusText = hpPlusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hpPlusText:SetPoint("CENTER")
    hpPlusText:SetText("+")
    hpPlusText:SetTextColor(0.3, 0.8, 0.3)

    hpPlusBtn:SetScript("OnClick", function()
        if DoF.Stats and DoF.Stats.ModifyHP then
            DoF.Stats:ModifyHP(1)
        end
    end)
    hpPlusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
        -- Отменяем скрытие кнопок
        if barsContainer.hideTimer then
            barsContainer.hideTimer:Cancel()
            barsContainer.hideTimer = nil
        end
    end)
    hpPlusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        -- Прячем кнопки с задержкой
        UF:HideModifyButtonsDelayed(barsContainer)
    end)
    hpBar.plusBtn = hpPlusBtn

    barsContainer.hpBar = hpBar

    -- Энергия бар
    local energyBar = CreateFrame("StatusBar", "$parent_EnergyBar", barsContainer, "BackdropTemplate")
    energyBar:SetSize(170, 14)
    energyBar:SetPoint("TOP", hpBar, "BOTTOM", 0, -2)
    energyBar:SetStatusBarTexture(ENERGY_TEX)
    energyBar:SetStatusBarColor(1, 1, 1)
    energyBar:SetBackdrop(BACKDROP)
    energyBar:SetBackdropColor(0.04, 0.04, 0.04, 1)
    energyBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Энергия текст
    local energyText = energyBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyText:SetPoint("CENTER")
    energyText:SetTextColor(0.9, 0.9, 1)
    energyText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    energyBar.text = energyText

    -- Energy кнопки +/-
    local energyMinusBtn = CreateFrame("Button", "$parent_EnergyMinusBtn", energyBar, "BackdropTemplate")
    energyMinusBtn:SetSize(14, 12)
    energyMinusBtn:SetPoint("LEFT", 2, 0)
    energyMinusBtn:SetBackdrop(BACKDROP)
    energyMinusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    energyMinusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    energyMinusBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
    energyMinusBtn:Hide()

    local energyMinusText = energyMinusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyMinusText:SetPoint("CENTER")
    energyMinusText:SetText("-")
    energyMinusText:SetTextColor(0.8, 0.3, 0.3)

    energyMinusBtn:SetScript("OnClick", function()
        if DoF.Stats and DoF.Stats.ModifyEnergy then
            DoF.Stats:ModifyEnergy(-1)
        end
    end)
    energyMinusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
        -- Отменяем скрытие кнопок
        if barsContainer.hideTimer then
            barsContainer.hideTimer:Cancel()
            barsContainer.hideTimer = nil
        end
    end)
    energyMinusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        -- Прячем кнопки с задержкой
        UF:HideModifyButtonsDelayed(barsContainer)
    end)
    energyBar.minusBtn = energyMinusBtn

    local energyPlusBtn = CreateFrame("Button", "$parent_EnergyPlusBtn", energyBar, "BackdropTemplate")
    energyPlusBtn:SetSize(14, 12)
    energyPlusBtn:SetPoint("RIGHT", -2, 0)
    energyPlusBtn:SetBackdrop(BACKDROP)
    energyPlusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    energyPlusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    energyPlusBtn:SetFrameLevel(parent:GetFrameLevel() + 10)
    energyPlusBtn:Hide()

    local energyPlusText = energyPlusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyPlusText:SetPoint("CENTER")
    energyPlusText:SetText("+")
    energyPlusText:SetTextColor(0.3, 0.8, 0.3)

    energyPlusBtn:SetScript("OnClick", function()
        if DoF.Stats and DoF.Stats.ModifyEnergy then
            DoF.Stats:ModifyEnergy(1)
        end
    end)
    energyPlusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
        -- Отменяем скрытие кнопок
        if barsContainer.hideTimer then
            barsContainer.hideTimer:Cancel()
            barsContainer.hideTimer = nil
        end
    end)
    energyPlusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        -- Прячем кнопки с задержкой
        UF:HideModifyButtonsDelayed(barsContainer)
    end)
    energyBar.plusBtn = energyPlusBtn

    barsContainer.energyBar = energyBar
    parent.bars = barsContainer
end

function UF:CreatePlayerEffectsRow(parent)
    local row = CreateFrame("Frame", "$parent_EffectsRow", parent)
    row:SetSize(220, 24)
    row:SetPoint("BOTTOMLEFT", 8, 8)

    for i = 1, self.MAX_EFFECT_ICONS do
        self.EffectFrames.Player[i] = self:CreateEffectIcon(row, i)
    end

    parent.effectsRow = row
end

-- ═══════════════════════════════════════════════════════════
-- TARGET FRAME
-- ═══════════════════════════════════════════════════════════

function UF:CreateTargetFrame()
    local frame = CreateFrame("Frame", "DoF_TargetUnitFrame", UIParent, "BackdropTemplate")
    frame:SetSize(240, 115)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:Hide()

    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(unpack(COLORS.bg))
    frame:SetBackdropBorderColor(unpack(COLORS.border))

    -- Классовый фон (обновляется динамически при смене таргета)
    local classBg = frame:CreateTexture("$parent_ClassBG", "ARTWORK", nil, -8)
    classBg:SetAllPoints()
    classBg:SetAlpha(0.45)
    classBg:Hide()
    frame.classBg = classBg

    -- Перетаскивание
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not DoF.db.profile.unitFrames.target.locked then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
        UF:SavePosition("target")
    end)

    -- Создаём компоненты
    self:CreateTargetPortrait(frame)
    self:CreateTargetInfo(frame)
    self:CreateTargetHPBar(frame)
    self:CreateTargetEnergyBar(frame)  -- Новый энергия бар
    self:CreateTargetDefenseRow(frame)
    self:CreateTargetEffectsRow(frame)
    self:CreateTargetNoDataText(frame)  -- Текст "Нет данных"

    -- Показывать кнопки +/- только при наведении (проверяем право по типу цели)
    frame:HookScript("OnEnter", function(self)
        if UnitExists("target") then
            if UnitIsPlayer("target") then
                if CanModifyPlayers() then UF:ShowTargetModifyButtons() end
            else
                if CanModifyNPCs() then UF:ShowTargetModifyButtons() end
            end
        end
    end)
    frame:HookScript("OnLeave", function(self)
        UF:HideTargetModifyButtonsDelayed()
    end)

    self.TargetFrame = frame
    return frame
end

function UF:CreateTargetPortrait(parent)
    local container = CreateFrame("Frame", "$parent_Portrait", parent, "BackdropTemplate")
    container:SetSize(40, 40)
    container:SetPoint("TOPLEFT", 8, -8)

    container:SetBackdrop(BACKDROP)
    container:SetBackdropColor(0.05, 0.05, 0.05, 1)
    container:SetBackdropBorderColor(0.5, 0.2, 0.2, 1)

    -- Текстура портрета
    local texture = container:CreateTexture("$parent_Texture", "ARTWORK")
    texture:SetSize(36, 36)
    texture:SetPoint("CENTER")
    container.texture = texture

    -- Череп (для NPC)
    local skull = container:CreateTexture("$parent_Skull", "OVERLAY")
    skull:SetSize(14, 14)
    skull:SetPoint("BOTTOMRIGHT", 4, -4)
    skull:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
    skull:SetVertexColor(0.8, 0.2, 0.2)
    container.skull = skull

    -- Бейдж уровня
    local levelBadge = CreateFrame("Frame", "$parent_LevelBadge", container, "BackdropTemplate")
    levelBadge:SetSize(24, 16)
    levelBadge:SetPoint("BOTTOM", 0, -6)
    levelBadge:SetBackdrop(BACKDROP)
    levelBadge:SetBackdropColor(0.15, 0.15, 0.15, 1)
    levelBadge:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local levelText = levelBadge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelText:SetPoint("CENTER")
    levelText:SetTextColor(1, 0.82, 0)
    levelBadge.text = levelText
    levelBadge:Hide()

    parent.portrait = container
    parent.levelBadge = levelBadge
end

function UF:CreateTargetInfo(parent)
    local info = CreateFrame("Frame", "$parent_Info", parent)
    info:SetSize(160, 20)
    info:SetPoint("TOPLEFT", parent.portrait, "TOPRIGHT", 8, 0)

    -- Имя
    local name = info:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    name:SetPoint("LEFT", 0, 0)
    name:SetTextColor(1, 0.4, 0.4)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    info.name = name

    -- Иконка роли
    local roleIcon = info:CreateTexture(nil, "ARTWORK")
    roleIcon:SetSize(20, 20)
    roleIcon:SetPoint("LEFT", name, "RIGHT", 2, 0)
    info.roleIcon = roleIcon

    -- Кнопка информации (показывает статы игрока)
    local infoBtn = CreateFrame("Button", "$parent_InfoBtn", info, "BackdropTemplate")
    infoBtn:SetSize(20, 20)
    infoBtn:SetPoint("RIGHT", 0, 0)
    infoBtn:SetBackdrop(BACKDROP)
    infoBtn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    infoBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local infoIcon = infoBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    infoIcon:SetPoint("CENTER")
    infoIcon:SetText("i")
    infoIcon:SetTextColor(0.7, 0.7, 0.7)

    infoBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        infoIcon:SetTextColor(1, 1, 1)
        UF:ShowTargetPlayerStatsTooltip(self)
    end)
    infoBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        infoIcon:SetTextColor(0.7, 0.7, 0.7)
        DoF.Utils:HideTooltip()
    end)
    infoBtn:Hide()  -- Скрыта по умолчанию, показывается только для игроков

    info.infoBtn = infoBtn
    parent.info = info
end

function UF:CreateTargetHPBar(parent)
    local hpBar = CreateFrame("StatusBar", "$parent_HPBar", parent, "BackdropTemplate")
    hpBar:SetSize(160, 16)
    hpBar:SetPoint("TOPLEFT", parent.portrait, "TOPRIGHT", 8, -22)
    hpBar:SetStatusBarTexture(HP_TEX_RED)
    hpBar:SetStatusBarColor(1, 1, 1)
    hpBar:SetBackdrop(BACKDROP)
    hpBar:SetBackdropColor(0.04, 0.04, 0.04, 1)
    hpBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- Щит (overlay)
    local shieldBar = CreateFrame("StatusBar", "$parent_ShieldBar", hpBar)
    shieldBar:SetSize(156, 12)
    shieldBar:SetPoint("LEFT", 2, 0)
    shieldBar:SetStatusBarTexture(BAR_TEXTURE)
    shieldBar:SetStatusBarColor(unpack(COLORS.shield))
    shieldBar:SetFrameLevel(hpBar:GetFrameLevel() + 1)
    shieldBar:Hide()
    hpBar.shieldBar = shieldBar

    local hpText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpText:SetPoint("CENTER")
    hpText:SetTextColor(1, 1, 1)
    hpText:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    hpBar.text = hpText

    -- Текст щита (справа)
    local shieldText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shieldText:SetPoint("RIGHT", -4, 0)
    shieldText:SetTextColor(0.4, 0.78, 1)
    shieldText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    shieldText:Hide()
    hpBar.shieldText = shieldText

    -- HP кнопки +/- (только для мастера)
    local hpMinusBtn = CreateFrame("Button", "$parent_HPMinusBtn", hpBar, "BackdropTemplate")
    hpMinusBtn:SetSize(16, 16)
    hpMinusBtn:SetPoint("LEFT", 2, 0)
    hpMinusBtn:SetBackdrop(BACKDROP)
    hpMinusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    hpMinusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    hpMinusBtn:SetFrameLevel(hpBar:GetFrameLevel() + 2)
    hpMinusBtn:Hide()

    local hpMinusText = hpMinusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hpMinusText:SetPoint("CENTER")
    hpMinusText:SetText("-")
    hpMinusText:SetTextColor(0.8, 0.3, 0.3)

    hpMinusBtn:SetScript("OnClick", function()
        UF:ModifyTargetHP(-1)
    end)
    hpMinusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
        if UF.TargetFrame and UF.TargetFrame.hideTimer then
            UF.TargetFrame.hideTimer:Cancel()
            UF.TargetFrame.hideTimer = nil
        end
    end)
    hpMinusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        UF:HideTargetModifyButtonsDelayed()
    end)
    hpBar.minusBtn = hpMinusBtn

    local hpPlusBtn = CreateFrame("Button", "$parent_HPPlusBtn", hpBar, "BackdropTemplate")
    hpPlusBtn:SetSize(16, 16)
    hpPlusBtn:SetPoint("RIGHT", -2, 0)
    hpPlusBtn:SetBackdrop(BACKDROP)
    hpPlusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    hpPlusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    hpPlusBtn:SetFrameLevel(hpBar:GetFrameLevel() + 2)
    hpPlusBtn:Hide()

    local hpPlusText = hpPlusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hpPlusText:SetPoint("CENTER")
    hpPlusText:SetText("+")
    hpPlusText:SetTextColor(0.3, 0.8, 0.3)

    hpPlusBtn:SetScript("OnClick", function()
        UF:ModifyTargetHP(1)
    end)
    hpPlusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
        if UF.TargetFrame and UF.TargetFrame.hideTimer then
            UF.TargetFrame.hideTimer:Cancel()
            UF.TargetFrame.hideTimer = nil
        end
    end)
    hpPlusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        UF:HideTargetModifyButtonsDelayed()
    end)
    hpBar.plusBtn = hpPlusBtn

    parent.hpBar = hpBar
end

function UF:CreateTargetEnergyBar(parent)
    local energyBar = CreateFrame("StatusBar", "$parent_EnergyBar", parent, "BackdropTemplate")
    energyBar:SetSize(160, 12)
    energyBar:SetPoint("TOPLEFT", parent.hpBar, "BOTTOMLEFT", 0, -2)
    energyBar:SetStatusBarTexture(ENERGY_TEX)
    energyBar:SetStatusBarColor(1, 1, 1)
    energyBar:SetBackdrop(BACKDROP)
    energyBar:SetBackdropColor(0.04, 0.04, 0.04, 1)
    energyBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    local energyText = energyBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyText:SetPoint("CENTER")
    energyText:SetTextColor(0.9, 0.9, 1)
    energyText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    energyBar.text = energyText

    -- Energy кнопки +/- (только для мастера)
    local energyMinusBtn = CreateFrame("Button", "$parent_EnergyMinusBtn", energyBar, "BackdropTemplate")
    energyMinusBtn:SetSize(14, 12)
    energyMinusBtn:SetPoint("LEFT", 2, 0)
    energyMinusBtn:SetBackdrop(BACKDROP)
    energyMinusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    energyMinusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    energyMinusBtn:SetFrameLevel(energyBar:GetFrameLevel() + 2)
    energyMinusBtn:Hide()

    local energyMinusText = energyMinusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyMinusText:SetPoint("CENTER")
    energyMinusText:SetText("-")
    energyMinusText:SetTextColor(0.8, 0.3, 0.3)

    energyMinusBtn:SetScript("OnClick", function()
        UF:ModifyTargetEnergy(-1)
    end)
    energyMinusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1)
        if UF.TargetFrame and UF.TargetFrame.hideTimer then
            UF.TargetFrame.hideTimer:Cancel()
            UF.TargetFrame.hideTimer = nil
        end
    end)
    energyMinusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        UF:HideTargetModifyButtonsDelayed()
    end)
    energyBar.minusBtn = energyMinusBtn

    local energyPlusBtn = CreateFrame("Button", "$parent_EnergyPlusBtn", energyBar, "BackdropTemplate")
    energyPlusBtn:SetSize(14, 12)
    energyPlusBtn:SetPoint("RIGHT", -2, 0)
    energyPlusBtn:SetBackdrop(BACKDROP)
    energyPlusBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.9)
    energyPlusBtn:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
    energyPlusBtn:SetFrameLevel(energyBar:GetFrameLevel() + 2)
    energyPlusBtn:Hide()

    local energyPlusText = energyPlusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyPlusText:SetPoint("CENTER")
    energyPlusText:SetText("+")
    energyPlusText:SetTextColor(0.3, 0.8, 0.3)

    energyPlusBtn:SetScript("OnClick", function()
        UF:ModifyTargetEnergy(1)
    end)
    energyPlusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.3, 0.8, 0.3, 1)
        if UF.TargetFrame and UF.TargetFrame.hideTimer then
            UF.TargetFrame.hideTimer:Cancel()
            UF.TargetFrame.hideTimer = nil
        end
    end)
    energyPlusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        UF:HideTargetModifyButtonsDelayed()
    end)
    energyBar.plusBtn = energyPlusBtn

    parent.energyBar = energyBar
end

function UF:CreateTargetNoDataText(parent)
    local noData = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noData:SetPoint("CENTER", 10, 0)
    noData:SetText(DoF.L["ui.uf.no_data"])
    noData:Hide()
    parent.noDataText = noData
end

function UF:CreateTargetDefenseRow(parent)
    local row = CreateFrame("Frame", "$parent_DefenseRow", parent)
    row:SetSize(200, 18)
    row:SetPoint("TOPLEFT", parent.hpBar, "BOTTOMLEFT", 0, -4)

    -- Стойкость
    local fort = self:CreateDefenseStat(row, "fort", DoF.L["stats.fortitude.label"], COLORS.fortitude, 0)
    -- Сноровка
    local reflex = self:CreateDefenseStat(row, "reflex", DoF.L["stats.reflex.label"], COLORS.reflex, 55)
    -- Воля
    local will = self:CreateDefenseStat(row, "will", DoF.L["stats.will.label"], COLORS.will, 110)

    row.fortitude = fort
    row.reflex = reflex
    row.will = will

    parent.defenseRow = row
end

function UF:CreateDefenseStat(parent, statType, statName, color, xOffset)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(50, 18)
    container:SetPoint("LEFT", xOffset, 0)

    -- Иконка
    local icon = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTextColor(unpack(color))

    if statType == "fort" then
        icon:SetText(DoF.L["ui.uf.fort_short"])
    elseif statType == "reflex" then
        icon:SetText(DoF.L["ui.uf.reflex_short"])
    else
        icon:SetText(DoF.L["ui.uf.will_short"])
    end

    -- Значение
    local value = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    value:SetPoint("LEFT", icon, "RIGHT", 2, 0)
    value:SetTextColor(unpack(color))
    container.value = value

    -- Тултип
    container:EnableMouse(true)
    container:SetScript("OnEnter", function(self)
        local desc
        if statType == "fort" then
            desc = DoF.L["ui.uf.fort_desc"]
        elseif statType == "reflex" then
            desc = DoF.L["ui.uf.reflex_desc"]
        else
            desc = DoF.L["ui.uf.will_desc"]
        end
        DoF.Utils:ShowTooltip(self, {
            { text = statName, r = color[1], g = color[2], b = color[3], size = 14 },
            { text = desc, r = 0.7, g = 0.7, b = 0.7 },
        }, "BOTTOM")
    end)
    container:SetScript("OnLeave", function()
        DoF.Utils:HideTooltip()
    end)

    return container
end

function UF:CreateTargetEffectsRow(parent)
    local row = CreateFrame("Frame", "$parent_EffectsRow", parent)
    row:SetSize(200, 24)
    row:SetPoint("BOTTOMLEFT", 8, 8)

    for i = 1, self.MAX_EFFECT_ICONS do
        self.EffectFrames.Target[i] = self:CreateEffectIcon(row, i)
    end

    parent.effectsRow = row
end

-- ═══════════════════════════════════════════════════════════
-- ИКОНКИ ЭФФЕКТОВ
-- ═══════════════════════════════════════════════════════════

function UF:CreateEffectIcon(parent, index)
    local size = self.EFFECT_ICON_SIZE
    local spacing = 2

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(size, size)
    frame:SetPoint("LEFT", (index - 1) * (size + spacing), 0)

    frame:SetBackdrop(BACKDROP)
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Иконка
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size - 4, size - 4)
    icon:SetPoint("CENTER")
    frame.icon = icon

    -- Длительность (снизу справа)
    local duration = frame:CreateFontString(nil, "OVERLAY")
    duration:SetFont(DoF.Config.FONT, 8, "OUTLINE")
    duration:SetPoint("BOTTOMRIGHT", 2, -2)
    duration:SetTextColor(1, 1, 1)
    frame.duration = duration

    -- Стаки (сверху слева)
    local stacks = frame:CreateFontString(nil, "OVERLAY")
    stacks:SetFont(DoF.Config.FONT, 8, "OUTLINE")
    stacks:SetPoint("TOPLEFT", -2, 2)
    stacks:SetTextColor(0.3, 1, 0.3)
    stacks:Hide()
    frame.stacks = stacks

    -- Тултип
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        if self.effectData then
            UF:ShowEffectTooltip(self)
        end
    end)
    frame:SetScript("OnLeave", function()
        DoF.Utils:HideTooltip()
    end)

    frame:Hide()
    return frame
end

function UF:SetupEffectIcon(frame, effectDef, effectData)
    if not effectDef then return end

    -- Иконка
    if effectDef.icon then
        frame.icon:SetTexture(effectDef.icon)
    else
        frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end

    -- Цвет рамки по типу
    local borderColor = COLORS.buffBorder
    if effectDef.type == "debuff" then
        borderColor = COLORS.debuffBorder
    elseif effectDef.type == "dot" then
        borderColor = COLORS.woundBorder
    end
    frame:SetBackdropBorderColor(unpack(borderColor))

    -- Длительность
    if effectData.remainingRounds and effectData.remainingRounds > 0 then
        frame.duration:SetText(effectData.remainingRounds)
        frame.duration:Show()
    else
        frame.duration:Hide()
    end

    -- Стаки
    if effectData.stacks and effectData.stacks > 1 then
        frame.stacks:SetText("x" .. effectData.stacks)
        frame.stacks:Show()
    else
        frame.stacks:Hide()
    end

    frame.effectData = effectData
    frame.effectDef = effectDef
    frame:Show()
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ ФРЕЙМОВ
-- ═══════════════════════════════════════════════════════════

function UF:UpdatePlayerFrame()
    local frame = self.PlayerFrame
    if not frame or not frame:IsShown() then return end

    -- Портрет
    SetPortraitTexture(frame.portrait.texture, "player")

    -- Уровень
    local level = DoF.Stats and DoF.Stats:GetLevel() or DoF.Config.MIN_LEVEL
    frame.levelBadge.text:SetText(level)

    -- Имя
    frame.info.name:SetText(UnitName("player"))

    -- Иконка роли
    local role = DoF.Stats and DoF.Stats:GetRole()
    if role and DoF.Config.Roles[role] then
        frame.info.roleIcon:SetTexture(DoF.Config.Roles[role].icon)
        frame.info.roleIcon:Show()
    else
        frame.info.roleIcon:Hide()
    end

    -- HP бар
    local currentHP = DoF.Stats and DoF.Stats:GetCurrentHP() or 5
    local maxHP = DoF.Stats and DoF.Stats:GetMaxHP() or 5
    frame.bars.hpBar:SetMinMaxValues(0, maxHP)
    frame.bars.hpBar:SetValue(currentHP)
    frame.bars.hpBar.text:SetText(currentHP .. "/" .. maxHP)

    -- Текстура HP по проценту
    local pct = currentHP / maxHP
    if pct > 0.5 then
        frame.bars.hpBar:SetStatusBarTexture(HP_TEX_GREEN)
    elseif pct > 0.25 then
        frame.bars.hpBar:SetStatusBarTexture(HP_TEX_YELLOW)
    else
        frame.bars.hpBar:SetStatusBarTexture(HP_TEX_RED)
    end

    -- Щит (бинарный)
    local shield = DoF.Stats and DoF.Stats:GetShield() or 0
    if shield > 0 then
        frame.bars.hpBar.shieldBar:SetMinMaxValues(0, maxHP)
        frame.bars.hpBar.shieldBar:SetValue(maxHP)
        frame.bars.hpBar.shieldBar:Show()
        frame.bars.hpBar.shieldText:SetText(DoF.L["ui.common.shield"])
        frame.bars.hpBar.shieldText:Show()
    else
        frame.bars.hpBar.shieldBar:Hide()
        frame.bars.hpBar.shieldText:Hide()
    end

    -- Энергия бар
    local energy = DoF.Stats and DoF.Stats:GetEnergy() or 2
    local maxEnergy = DoF.Stats and DoF.Stats:GetMaxEnergy() or 2
    frame.bars.energyBar:SetMinMaxValues(0, maxEnergy)
    frame.bars.energyBar:SetValue(energy)
    frame.bars.energyBar.text:SetText(energy .. "/" .. maxEnergy)

    -- Обновляем эффекты
    self:UpdatePlayerEffects()
end

function UF:UpdateTargetFrame()
    local frame = self.TargetFrame
    if not frame then return end

    -- Проверяем включён ли фрейм
    if not DoF.db.profile.unitFrames.target.enabled then
        frame:Hide()
        return
    end

    -- Проверяем есть ли цель
    if not UnitExists("target") then
        frame:Hide()
        return
    end

    local isPlayer = UnitIsPlayer("target")
    local targetName = UnitName("target")
    local guid = UnitGUID("target")

    -- Определяем тип цели и получаем данные
    local playerData, npcData
    if isPlayer then
        -- Если таргетим себя - берём данные напрямую из DoF.Stats (всегда актуальные)
        if UnitIsUnit("target", "player") then
            playerData = {
                hp = DoF.Stats:GetCurrentHP(),
                maxHp = DoF.Stats:GetMaxHP(),
                level = DoF.Stats:GetLevel(),
                wounds = DoF.Stats:GetWounds(),
                shield = DoF.Stats:GetShield(),
                energy = DoF.Stats:GetEnergy(),
                maxEnergy = DoF.Stats:GetMaxEnergy(),
                role = DoF.Stats:GetRole(),
            }
        else
            playerData = DoF.Sync and DoF.Sync:GetPlayerData(targetName)
        end
    else
        npcData = DoF.Units and DoF.Units:Get(guid)
    end

    -- Если нет данных ни для игрока ни для NPC - показываем "Нет данных"
    if not playerData and not npcData then
        -- Запрашиваем данные у игрока если ещё не запрашивали недавно
        if isPlayer and DoF.Sync and targetName ~= UnitName("player") then
            local now = GetTime()
            if not self._lastDataRequest
               or self._lastDataRequest.name ~= targetName
               or (now - self._lastDataRequest.time) > 3 then
                self._lastDataRequest = { name = targetName, time = now }
                DoF.Sync:RequestPlayerData(targetName)
            end
        end
        frame:Show()
        frame.classBg:Hide()
        SetPortraitTexture(frame.portrait.texture, "target")
        frame.info.name:SetText(targetName)
        frame.info.infoBtn:Hide()
        frame.info.roleIcon:Hide()
        frame.hpBar:Hide()
        frame.energyBar:Hide()
        frame.defenseRow:Hide()
        frame.effectsRow:Hide()
        frame.noDataText:Show()
        frame.levelBadge:Hide()
        self:HideTargetModifyButtons()
        return
    end

    frame:Show()
    frame.noDataText:Hide()

    -- Портрет
    SetPortraitTexture(frame.portrait.texture, "target")

    -- === ИГРОК С АДДОНОМ ===
    if playerData then
        -- Классовый фон
        local _, targetClass = UnitClass("target")
        local classKey = CLASS_BG_MAP[targetClass]
        if classKey then
            frame.classBg:SetTexture(CLASS_BG_PATH .. classKey)
            frame.classBg:Show()
        else
            frame.classBg:Hide()
        end

        frame.info.name:SetText(targetName)
        frame.info.name:SetTextColor(1, 1, 1)  -- Белый для игроков
        frame.info.infoBtn:Show()  -- Показываем кнопку статов

        -- Бейдж уровня
        if playerData.level then
            frame.levelBadge.text:SetText(playerData.level)
            frame.levelBadge:Show()
        else
            frame.levelBadge:Hide()
        end

        -- Иконка роли
        local role = playerData.role
        if role and DoF.Config.Roles[role] then
            frame.info.roleIcon:SetTexture(DoF.Config.Roles[role].icon)
            frame.info.roleIcon:Show()
        else
            frame.info.roleIcon:Hide()
        end

        -- HP бар
        frame.hpBar:Show()
        local tPct = (playerData.maxHp or 1) > 0 and ((playerData.hp or 0) / (playerData.maxHp or 1)) or 0
        if tPct > 0.5 then
            frame.hpBar:SetStatusBarTexture(HP_TEX_GREEN)
        elseif tPct > 0.25 then
            frame.hpBar:SetStatusBarTexture(HP_TEX_YELLOW)
        else
            frame.hpBar:SetStatusBarTexture(HP_TEX_RED)
        end
        frame.hpBar:SetStatusBarColor(1, 1, 1)
        frame.hpBar:SetMinMaxValues(0, playerData.maxHp or 1)
        frame.hpBar:SetValue(playerData.hp or 0)
        frame.hpBar.text:SetText((playerData.hp or 0) .. "/" .. (playerData.maxHp or 0))

        -- Щит игрока (бинарный)
        local playerShield = playerData.shield or 0
        if playerShield > 0 then
            frame.hpBar.shieldBar:SetMinMaxValues(0, playerData.maxHp or 1)
            frame.hpBar.shieldBar:SetValue(playerData.maxHp or 1)
            frame.hpBar.shieldBar:Show()
            frame.hpBar.shieldText:SetText(DoF.L["ui.common.shield"])
            frame.hpBar.shieldText:Show()
        else
            frame.hpBar.shieldBar:Hide()
            frame.hpBar.shieldText:Hide()
        end

        -- Энергия бар
        frame.energyBar:Show()
        frame.energyBar:SetMinMaxValues(0, playerData.maxEnergy or 1)
        frame.energyBar:SetValue(playerData.energy or 0)
        frame.energyBar.text:SetText((playerData.energy or 0) .. "/" .. (playerData.maxEnergy or 0))

        -- Скрываем пороги защиты (для игроков)
        frame.defenseRow:Hide()

        -- Показываем эффекты
        frame.effectsRow:Show()
        self:UpdateTargetEffects()

    -- === NPC С ДАННЫМИ ===
    else
        frame.classBg:Hide()
        frame.info.name:SetText(npcData.name or targetName)
        frame.info.name:SetTextColor(1, 0.4, 0.4)  -- Красный для NPC
        frame.info.infoBtn:Hide()  -- Скрываем кнопку статов для NPC
        frame.info.roleIcon:Hide()  -- Скрываем иконку роли для NPC
        frame.levelBadge:Hide()  -- Скрываем уровень для NPC

        -- HP бар
        frame.hpBar:Show()
        frame.hpBar:SetStatusBarTexture(HP_TEX_RED)
        frame.hpBar:SetStatusBarColor(1, 1, 1)
        frame.hpBar:SetMinMaxValues(0, npcData.maxHp or 1)
        frame.hpBar:SetValue(npcData.hp or 0)

        if (npcData.hp or 0) <= 0 then
            frame.hpBar.text:SetText("|cFFFF0000DEAD|r")
        else
            frame.hpBar.text:SetText((npcData.hp or 0) .. "/" .. (npcData.maxHp or 0))
        end

        -- Щит NPC (бинарный)
        local npcShield = npcData.shield or 0
        if npcShield > 0 then
            frame.hpBar.shieldBar:SetMinMaxValues(0, npcData.maxHp or 1)
            frame.hpBar.shieldBar:SetValue(npcData.maxHp or 1)
            frame.hpBar.shieldBar:Show()
            frame.hpBar.shieldText:SetText(DoF.L["ui.common.shield"])
            frame.hpBar.shieldText:Show()
        else
            frame.hpBar.shieldBar:Hide()
            frame.hpBar.shieldText:Hide()
        end

        -- Скрываем энергия бар и кнопки энергии (для NPC)
        frame.energyBar:Hide()
        if frame.energyBar.minusBtn then
            frame.energyBar.minusBtn:Hide()
            frame.energyBar.plusBtn:Hide()
        end

        -- Пороги защиты
        frame.defenseRow:Show()
        local fortMod = DoF.Effects and DoF.Effects:GetModifier("npc", guid, "fort") or 0
        local reflexMod = DoF.Effects and DoF.Effects:GetModifier("npc", guid, "reflex") or 0
        local willMod = DoF.Effects and DoF.Effects:GetModifier("npc", guid, "will") or 0

        local effectiveFort = math.max(1, (npcData.fort or 10) + fortMod)
        local effectiveReflex = math.max(1, (npcData.reflex or 10) + reflexMod)
        local effectiveWill = math.max(1, (npcData.will or 10) + willMod)

        frame.defenseRow.fortitude.value:SetText(effectiveFort)
        frame.defenseRow.reflex.value:SetText(effectiveReflex)
        frame.defenseRow.will.value:SetText(effectiveWill)

        -- Показываем эффекты
        frame.effectsRow:Show()
        self:UpdateTargetEffects()
    end
end

function UF:UpdatePlayerEffects()
    self:HideAllEffects(self.EffectFrames.Player)

    local index = 1

    -- Обычные эффекты
    if DoF.Effects then
        local myName = UnitName("player")
        local effects = DoF.Effects:GetAll("player", myName)
        if effects then
            for effectId, effectData in pairs(effects) do
                if index > self.MAX_EFFECT_ICONS then break end
                local def = DoF.Effects.Definitions and DoF.Effects.Definitions[effectId]
                if def then
                    self:SetupEffectIcon(self.EffectFrames.Player[index], def, effectData)
                    index = index + 1
                end
            end
        end
    end

    -- Иконка ранений
    local wounds = DoF.Stats and DoF.Stats:GetWounds() or 0
    if wounds > 0 and index <= self.MAX_EFFECT_ICONS then
        local isCrit = wounds >= DoF.Config.MAX_WOUNDS
        local penalty = DoF.Config and DoF.Config.GetWoundPenalty and DoF.Config:GetWoundPenalty(wounds) or wounds
        local woundDef = {
            name = isCrit and DoF.L["ui.uf.critical_wound"] or DoF.L["ui.uf.wound"],
            icon = isCrit and "Interface\\Icons\\ability_creature_cursed_05" or "Interface\\Icons\\spell_shadow_lifedrain",
            type = "debuff",
            description = isCrit
                and DoF.L["ui.uf.critical_wound_desc_full"]
                or DoF.Locale:Format("ui.uf.wound_penalty", penalty),
        }
        local woundData = { stacks = 0, remainingRounds = 0 }
        self:SetupEffectIcon(self.EffectFrames.Player[index], woundDef, woundData)
    end
end

function UF:UpdateTargetEffects()
    self:HideAllEffects(self.EffectFrames.Target)

    if not UnitExists("target") then return end

    local guid = UnitGUID("target")
    local name = UnitName("target")
    local isPlayer = UnitIsPlayer("target")

    local index = 1

    -- Обычные эффекты
    if DoF.Effects then
        local effects
        if isPlayer then
            effects = DoF.Effects:GetAll("player", name)
        else
            effects = DoF.Effects:GetAll("npc", guid)
        end

        if effects then
            for effectId, effectData in pairs(effects) do
                if index > self.MAX_EFFECT_ICONS then break end
                local def = DoF.Effects.Definitions and DoF.Effects.Definitions[effectId]
                if def then
                    self:SetupEffectIcon(self.EffectFrames.Target[index], def, effectData)
                    index = index + 1
                end
            end
        end
    end

    -- Иконки пассивок NPC
    if not isPlayer and DoF.Passives and index <= self.MAX_EFFECT_ICONS then
        local passives = DoF.Passives:GetAll(guid)
        if passives then
            for passiveId, passiveData in pairs(passives) do
                if index > self.MAX_EFFECT_ICONS then break end
                local pdef = DoF.Passives.Definitions[passiveId]
                if pdef then
                    -- Отображаем как эффект с особой рамкой (золотая = пассивка)
                    local fakeDef = {
                        name = pdef.name,
                        icon = pdef.icon,
                        type = "passive",
                        description = pdef.description,
                    }
                    local fakeData = { remainingRounds = 0, stacks = 0 }
                    local frame = self.EffectFrames.Target[index]
                    self:SetupEffectIcon(frame, fakeDef, fakeData)
                    -- Перекрашиваем рамку в золотой для пассивок
                    if frame.border then
                        frame.border:SetVertexColor(0.8, 0.6, 0.0, 1)
                    end
                    index = index + 1
                end
            end
        end
    end

    -- Иконка ранений (только для игроков)
    if isPlayer and index <= self.MAX_EFFECT_ICONS then
        local wounds = 0
        if UnitIsUnit("target", "player") then
            wounds = DoF.Stats and DoF.Stats:GetWounds() or 0
        else
            local pData = DoF.Sync and DoF.Sync:GetPlayerData(name)
            wounds = pData and pData.wounds or 0
        end
        if wounds > 0 then
            local isCrit = wounds >= DoF.Config.MAX_WOUNDS
            local woundDef = {
                name = isCrit and DoF.L["ui.uf.critical_wound"] or DoF.L["ui.uf.wound"],
                icon = isCrit and "Interface\\Icons\\ability_creature_cursed_05" or "Interface\\Icons\\spell_shadow_lifedrain",
                type = "debuff",
                description = isCrit
                    and DoF.L["ui.uf.critical_wound_desc_short"]
                    or DoF.L["ui.uf.wound_penalty_generic"],
            }
            local woundData = { stacks = 0, remainingRounds = 0 }
            self:SetupEffectIcon(self.EffectFrames.Target[index], woundDef, woundData)
        end
    end
end

function UF:HideAllEffects(frames)
    for _, frame in ipairs(frames) do
        frame:Hide()
        frame.effectData = nil
        frame.effectDef = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- ТУЛТИПЫ
-- ═══════════════════════════════════════════════════════════

function UF:ShowPlayerStatsTooltip(frame)
    local lines = {}
    lines[#lines + 1] = { text = UnitName("player"), r = 1, g = 0.82, b = 0, size = 14 }

    local role = DoF.Stats and DoF.Stats:GetRole()
    if role and DoF.Config.Roles[role] then
        lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.role", DoF.Config.Roles[role].name), r = 0.7, g = 0.7, b = 0.7 }
    end

    if DoF.Stats and DoF.Config.AllStats then
        lines[#lines + 1] = { spacer = true }
        local count = 0
        for _, stat in ipairs(DoF.Config.AllStats) do
            count = count + 1
            -- Разделитель между атакующими (4) и защитными (3) статами
            if count == 5 then
                lines[#lines + 1] = { spacer = true }
            end
            local value = DoF.Stats:GetTotal(stat) or 0
            local name = DoF.Config.StatNames[stat] or stat
            local colorHex = DoF.Config.StatColors[stat] or "FFFFFF"
            local r = tonumber(colorHex:sub(1,2), 16) / 255
            local g = tonumber(colorHex:sub(3,4), 16) / 255
            local b = tonumber(colorHex:sub(5,6), 16) / 255
            lines[#lines + 1] = { text = name .. ": " .. value, r = r, g = g, b = b }
        end
    end

    local wounds = DoF.Stats and DoF.Stats:GetWounds() or 0
    if wounds > 0 then
        lines[#lines + 1] = { spacer = true }
        if wounds >= DoF.Config.MAX_WOUNDS then
            lines[#lines + 1] = { text = DoF.L["ui.uf.critical_wound_line"], r = 1, g = 0.1, b = 0.1 }
        else
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.wound_line", DoF.Config:GetWoundPenalty(wounds)), r = 1, g = 0.3, b = 0.3 }
        end
    end

    local level = DoF.Stats and DoF.Stats:GetLevel() or 1
    if role then
        local dmg = DoF.Config:GetDamageRange(level, role)
        local heal = DoF.Config:GetHealingRange(level, role)
        local playerName = UnitName("player")
        local dmgMod = DoF.Effects and DoF.Effects:GetModifier("player", playerName, "damage") or 0
        local healMod = DoF.Effects and DoF.Effects:GetModifier("player", playerName, "healing") or 0

        -- HealingFatigue хранит только count (счётчик исцелений до следующего стака);
        -- сами стаки лежат в эффекте healing_fatigue (см. Combat:SaveHealingFatigue).
        local fatigueThreshold = 0
        if DoF.Effects then
            local eff = DoF.Effects:Get("player", playerName, "healing_fatigue")
            local stacks = eff and eff.stacks or 0
            if stacks > 0 then
                fatigueThreshold = stacks * DoF.Config.HEALING_FATIGUE_THRESHOLD_PER_STACK
            end
        end

        lines[#lines + 1] = { spacer = true }

        if dmg then
            local dMin = dmg.min + dmgMod
            local dMax = dmg.max + dmgMod
            local dmgStr = DoF.Locale:Format("ui.uf.damage_range", dMin, dMax)
            if dmgMod ~= 0 then dmgStr = dmgStr .. " (+" .. dmgMod .. ")" end
            lines[#lines + 1] = { text = dmgStr, r = 1, g = 0.4, b = 0.4 }
        end
        if heal then
            local hMin = math.max(1, heal.min + healMod)
            local hMax = math.max(1, heal.max + healMod)
            local healStr = DoF.Locale:Format("ui.uf.healing_range", hMin, hMax)
            if healMod ~= 0 then healStr = healStr .. " (+" .. healMod .. ")" end
            if fatigueThreshold > 0 then healStr = healStr .. DoF.Locale:Format("ui.uf.fatigue_threshold", fatigueThreshold) end
            lines[#lines + 1] = { text = healStr, r = 0.4, g = 1, b = 0.4 }
        end
    end

    DoF.Utils:ShowTooltip(frame, lines, "BOTTOM")
end

function UF:ShowTargetPlayerStatsTooltip(frame)
    if not UnitExists("target") or not UnitIsPlayer("target") then return end

    local targetName = UnitName("target")
    local playerData = DoF.Sync and DoF.Sync:GetPlayerData(targetName)

    -- Показываем базовый тултип даже если данные ещё не синкнулись
    if not playerData then
        local lines = {}
        lines[#lines + 1] = { text = targetName, r = 1, g = 0.82, b = 0, size = 14 }
        lines[#lines + 1] = { text = DoF.L["ui.uf.loading"], r = 0.5, g = 0.5, b = 0.5 }
        DoF.Utils:ShowTooltip(frame, lines, "BOTTOM")
        return
    end

    local lines = {}
    lines[#lines + 1] = { text = targetName, r = 1, g = 0.82, b = 0, size = 14 }

    if playerData.role and DoF.Config.Roles[playerData.role] then
        lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.role", DoF.Config.Roles[playerData.role].name), r = 0.7, g = 0.7, b = 0.7 }
    end

    if DoF.Config.AllStats then
        lines[#lines + 1] = { spacer = true }
        local count = 0
        for _, stat in ipairs(DoF.Config.AllStats) do
            count = count + 1
            if count == 5 then
                lines[#lines + 1] = { spacer = true }
            end
            local statKey = stat:lower()
            local value = playerData[statKey] or 0
            local name = DoF.Config.StatNames[stat] or stat
            local colorHex = DoF.Config.StatColors[stat] or "FFFFFF"
            local r = tonumber(colorHex:sub(1,2), 16) / 255
            local g = tonumber(colorHex:sub(3,4), 16) / 255
            local b = tonumber(colorHex:sub(5,6), 16) / 255
            lines[#lines + 1] = { text = name .. ": " .. value, r = r, g = g, b = b }
        end
    end

    if playerData.level and playerData.role then
        local dmg = DoF.Config:GetDamageRange(playerData.level, playerData.role)
        local heal = DoF.Config:GetHealingRange(playerData.level, playerData.role)
        local dmgMod = DoF.Effects and DoF.Effects:GetModifier("player", targetName, "damage") or 0
        local healMod = DoF.Effects and DoF.Effects:GetModifier("player", targetName, "healing") or 0

        -- См. ShowPlayerStatsTooltip: stacks живут в эффекте, не в HealingFatigue.
        local fatigueThreshold = 0
        if DoF.Effects then
            local eff = DoF.Effects:Get("player", targetName, "healing_fatigue")
            local stacks = eff and eff.stacks or 0
            if stacks > 0 then
                fatigueThreshold = stacks * DoF.Config.HEALING_FATIGUE_THRESHOLD_PER_STACK
            end
        end

        lines[#lines + 1] = { spacer = true }

        if dmg then
            local dMin = dmg.min + dmgMod
            local dMax = dmg.max + dmgMod
            local dmgStr = DoF.Locale:Format("ui.uf.damage_range", dMin, dMax)
            if dmgMod ~= 0 then dmgStr = dmgStr .. " (+" .. dmgMod .. ")" end
            lines[#lines + 1] = { text = dmgStr, r = 1, g = 0.4, b = 0.4 }
        end
        if heal then
            local hMin = math.max(1, heal.min + healMod)
            local hMax = math.max(1, heal.max + healMod)
            local healStr = DoF.Locale:Format("ui.uf.healing_range", hMin, hMax)
            if healMod ~= 0 then healStr = healStr .. " (+" .. healMod .. ")" end
            if fatigueThreshold > 0 then healStr = healStr .. DoF.Locale:Format("ui.uf.fatigue_threshold", fatigueThreshold) end
            lines[#lines + 1] = { text = healStr, r = 0.4, g = 1, b = 0.4 }
        end
    end

    if playerData.wounds and playerData.wounds > 0 then
        lines[#lines + 1] = { spacer = true }
        if playerData.wounds >= DoF.Config.MAX_WOUNDS then
            lines[#lines + 1] = { text = DoF.L["ui.uf.critical_wound_line"], r = 1, g = 0.1, b = 0.1 }
        else
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.wound_line", DoF.Config:GetWoundPenalty(playerData.wounds)), r = 1, g = 0.3, b = 0.3 }
        end
    end

    DoF.Utils:ShowTooltip(frame, lines, "BOTTOM")
end

function UF:ShowEffectTooltip(frame)
    local def = frame.effectDef
    local data = frame.effectData

    if not def or not data then return end

    local lines = {}

    -- Название (с количеством стаков)
    local nameText = def.name or "Unknown"
    if data.stacks and data.stacks > 1 then
        nameText = nameText .. " (x" .. data.stacks .. ")"
    end
    lines[#lines + 1] = { text = nameText, r = 1, g = 0.82, b = 0, size = 14 }

    -- Тип
    local typeText, tr, tg, tb = DoF.L["ui.uf.effect"], 0.7, 0.7, 0.7
    if def.type == "buff" then
        typeText, tr, tg, tb = DoF.L["ui.common.buff"], 0.2, 0.8, 0.2
    elseif def.type == "debuff" then
        typeText, tr, tg, tb = DoF.L["ui.common.debuff"], 0.8, 0.2, 0.2
    elseif def.type == "dot" then
        typeText, tr, tg, tb = DoF.L["ui.common.dot"], 1, 0.5, 0
    end
    lines[#lines + 1] = { text = typeText, r = tr, g = tg, b = tb }

    -- Описание
    if def.description then
        lines[#lines + 1] = { text = def.description, r = 0.8, g = 0.8, b = 0.8 }
    end

    -- Значение (модификатор стата / урон за тик / HP бафф)
    if data.value and data.value > 0 then
        if def.type == "dot" or def.isHoT then
            local actionText = def.isHoT and DoF.L["ui.effect.heals"] or DoF.L["ui.common.damage"]
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.effect.per_round", actionText, data.value), r = 1, g = 0.82, b = 0 }
        elseif def.statMod then
            local modText = def.modType == "increase" and "+" or "-"
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.effect.modifier", modText .. data.value), r = 1, g = 0.82, b = 0 }
        elseif def.isHPBuff then
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.hp_bonus", data.value), r = 1, g = 0.82, b = 0 }
        end
    end

    -- Длительность
    if data.remainingRounds and data.remainingRounds > 0 then
        lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.remaining_turns", data.remainingRounds, DoF.Locale:Plural(data.remainingRounds, DoF.L["ui.turns_one"], DoF.L["ui.turns_few"], DoF.L["ui.turns_many"])), r = 0.7, g = 0.7, b = 0.7 }
    end

    -- Провокация: выделяем имя танка для мастера
    if def.id == "tank_taunt" then
        if data.casters and #data.casters > 0 then
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.tank", data.casters[1]), r = 1, g = 0.5, b = 0.1, size = 13 }
        elseif data.caster then
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.uf.tank", data.caster), r = 1, g = 0.5, b = 0.1, size = 13 }
        end
    else
        -- Кто наложил (общий случай)
        if data.casters and #data.casters > 0 then
            local castersText
            if #data.casters == 1 then
                castersText = DoF.Locale:Format("ui.effect.caster_one", data.casters[1])
            else
                castersText = DoF.Locale:Format("ui.effect.caster_many", table.concat(data.casters, ", "))
            end
            lines[#lines + 1] = { text = castersText, r = 0.5, g = 0.5, b = 0.5 }
        elseif data.caster then
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.effect.caster_one", data.caster), r = 0.5, g = 0.5, b = 0.5 }
        end
    end

    DoF.Utils:ShowTooltip(frame, lines, "RIGHT")
end

-- ═══════════════════════════════════════════════════════════
-- ПОЗИЦИИ И МАСШТАБ
-- ═══════════════════════════════════════════════════════════

function UF:SavePosition(frameType)
    local frame = frameType == "player" and self.PlayerFrame or self.TargetFrame
    if not frame then return end

    local point, _, relPoint, x, y = frame:GetPoint()
    DoF.db.profile.unitFrames[frameType].position = {
        point = point,
        relPoint = relPoint or point,
        x = x,
        y = y,
    }
end

function UF:LoadPosition(frameType)
    local frame = frameType == "player" and self.PlayerFrame or self.TargetFrame
    if not frame then return end

    local pos = DoF.db.profile.unitFrames[frameType].position
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    end
end

function UF:ResetPosition(frameType)
    local defaults = {
        player = { point = "CENTER", relPoint = "CENTER", x = -400, y = -200 },
        target = { point = "CENTER", relPoint = "CENTER", x = -400, y = -300 },
    }

    DoF.db.profile.unitFrames[frameType].position = defaults[frameType]
    self:LoadPosition(frameType)
end

function UF:ApplyScale(frameType)
    local frame = frameType == "player" and self.PlayerFrame or self.TargetFrame
    if not frame then return end

    local scale = DoF.db.profile.unitFrames[frameType].scale or 1.0
    frame:SetScale(scale)
end

-- ═══════════════════════════════════════════════════════════
-- КНОПКИ УПРАВЛЕНИЯ
-- ═══════════════════════════════════════════════════════════

function UF:TogglePlayerFrame()
    local enabled = not DoF.db.profile.unitFrames.player.enabled
    DoF.db.profile.unitFrames.player.enabled = enabled

    if enabled then
        self.PlayerFrame:Show()
        self:UpdatePlayerFrame()
    else
        self.PlayerFrame:Hide()
    end

    self:UpdateControlButtons()
end

function UF:ToggleTargetFrame()
    local enabled = not DoF.db.profile.unitFrames.target.enabled
    DoF.db.profile.unitFrames.target.enabled = enabled

    self:UpdateControlButtons()
    self:UpdateTargetFrame()
end

function UF:ToggleLock()
    local locked = not DoF.db.profile.unitFrames.player.locked
    DoF.db.profile.unitFrames.player.locked = locked
    DoF.db.profile.unitFrames.target.locked = locked

    -- Блокируем и ActionBar
    if DoF.ActionBar and DoF.db.profile.actionBar then
        DoF.db.profile.actionBar.locked = locked
    end

    -- Показываем/скрываем secure кнопку для таргета себя
    if self.PlayerFrame and self.PlayerFrame.secureTargetBtn then
        if locked then
            self.PlayerFrame.secureTargetBtn:Show()
        else
            self.PlayerFrame.secureTargetBtn:Hide()
        end
    end

    self:UpdateControlButtons()

    if DoF.Utils then
        DoF.Utils:Info(DoF.L[locked and "ui.uf.frames_locked" or "ui.uf.frames_unlocked"])
    end
end

-- Точка совместимости: кнопки TopBar_PlayerFrameBtn/TargetFrameBtn/LockFramesBtn
-- жили в удалённом DoF_MainFrame. Соответствующие тогглы теперь в контекстном
-- меню ПКМ иконки миникарты (UI/MinimapButton.lua) и не нуждаются в ручной
-- подсветке. Функция оставлена пустой — вызывается из Toggle*/ToggleLock.
function UF:UpdateControlButtons()
end

function UF:HideModifyButtonsDelayed(barsContainer)
    -- Отменяем существующий таймер, если он есть
    if barsContainer.hideTimer then
        barsContainer.hideTimer:Cancel()
        barsContainer.hideTimer = nil
    end

    -- Создаём новый таймер с задержкой 0.2 секунды
    barsContainer.hideTimer = C_Timer.NewTimer(0.2, function()
        -- Проверяем, находится ли курсор на фрейме или кнопках
        local mouseOver = MouseIsOver(UF.PlayerFrame)
        if not mouseOver and barsContainer.hpBar and barsContainer.energyBar then
            -- Также проверяем, не на кнопках ли мышь
            local onButton = MouseIsOver(barsContainer.hpBar.minusBtn) or
                           MouseIsOver(barsContainer.hpBar.plusBtn) or
                           MouseIsOver(barsContainer.energyBar.minusBtn) or
                           MouseIsOver(barsContainer.energyBar.plusBtn)

            if not onButton then
                -- Скрываем все кнопки
                barsContainer.hpBar.minusBtn:Hide()
                barsContainer.hpBar.plusBtn:Hide()
                barsContainer.energyBar.minusBtn:Hide()
                barsContainer.energyBar.plusBtn:Hide()
            end
        end
        barsContainer.hideTimer = nil
    end)
end

-- ═══════════════════════════════════════════════════════════
-- КНОПКИ +/- ТАРГЕТ ФРЕЙМА (ТОЛЬКО МАСТЕР)
-- ═══════════════════════════════════════════════════════════

function UF:ShowTargetModifyButtons()
    local frame = self.TargetFrame
    if not frame or not frame:IsShown() then return end

    -- Отменяем таймер скрытия если он есть
    if frame.hideTimer then
        frame.hideTimer:Cancel()
        frame.hideTimer = nil
    end

    -- HP кнопки показываем всегда (для игроков и NPC)
    if frame.hpBar and frame.hpBar:IsShown() and frame.hpBar.minusBtn then
        frame.hpBar.minusBtn:Show()
        frame.hpBar.plusBtn:Show()
    end

    -- Energy кнопки показываем только если энергия бар виден (только для игроков)
    if frame.energyBar and frame.energyBar:IsShown() and frame.energyBar.minusBtn then
        frame.energyBar.minusBtn:Show()
        frame.energyBar.plusBtn:Show()
    end
end

function UF:HideTargetModifyButtons()
    local frame = self.TargetFrame
    if not frame then return end

    if frame.hpBar and frame.hpBar.minusBtn then
        frame.hpBar.minusBtn:Hide()
        frame.hpBar.plusBtn:Hide()
    end
    if frame.energyBar and frame.energyBar.minusBtn then
        frame.energyBar.minusBtn:Hide()
        frame.energyBar.plusBtn:Hide()
    end
end

function UF:HideTargetModifyButtonsDelayed()
    local frame = self.TargetFrame
    if not frame then return end

    -- Отменяем существующий таймер
    if frame.hideTimer then
        frame.hideTimer:Cancel()
        frame.hideTimer = nil
    end

    frame.hideTimer = C_Timer.NewTimer(0.2, function()
        if not frame:IsShown() then
            frame.hideTimer = nil
            return
        end

        local mouseOver = MouseIsOver(frame)
        if not mouseOver then
            -- Проверяем, не на кнопках ли мышь
            local onButton = false
            if frame.hpBar and frame.hpBar.minusBtn then
                onButton = onButton or MouseIsOver(frame.hpBar.minusBtn) or MouseIsOver(frame.hpBar.plusBtn)
            end
            if frame.energyBar and frame.energyBar.minusBtn then
                onButton = onButton or MouseIsOver(frame.energyBar.minusBtn) or MouseIsOver(frame.energyBar.plusBtn)
            end

            if not onButton then
                UF:HideTargetModifyButtons()
            end
        end
        frame.hideTimer = nil
    end)
end

-- Тротлинг кнопок +/- (не чаще 0.2 сек)
local lastModifyHP = 0
local lastModifyEnergy = 0
local MODIFY_THROTTLE = 0.2

function UF:ModifyTargetHP(delta)
    if not UnitExists("target") then return end

    local targetName = UnitName("target")
    local isPlayer = UnitIsPlayer("target")

    if isPlayer then
        if not CanModifyPlayers() then return end
        if UnitIsUnit("target", "player") then
            DoF.Stats:ModifyHP(delta)
        else
            DoF.Sync:ModifyPlayerHP(targetName, delta)
        end
    else
        -- Throttle только для NPC (нет сетевой защиты как у игроков)
        local now = GetTime()
        if (now - lastModifyHP) < MODIFY_THROTTLE then return end
        lastModifyHP = now

        if not CanModifyNPCs() then return end
        local guid = UnitGUID("target")
        local npcData = DoF.Units and DoF.Units:Get(guid)
        if npcData then
            if delta < 0 then
                DoF.Units:Damage(guid, -delta)
            else
                DoF.Units:Heal(guid, delta)
            end
        end
    end

    UF:UpdateTargetFrame()
end

function UF:ModifyTargetEnergy(delta)
    if not CanModifyPlayers() then return end
    if not UnitExists("target") then return end
    if not UnitIsPlayer("target") then return end

    local targetName = UnitName("target")

    if UnitIsUnit("target", "player") then
        DoF.Stats:ModifyEnergy(delta)
    else
        if delta > 0 then
            DoF.Sync:GiveEnergy(targetName, delta)
        elseif delta < 0 then
            DoF.Sync:TakeEnergy(targetName, math.abs(delta))
        end
    end

    UF:UpdateTargetFrame()
end

-- ═══════════════════════════════════════════════════════════
-- РЕГИСТРАЦИЯ СОБЫТИЙ
-- ═══════════════════════════════════════════════════════════

function UF:RegisterEvents()
    if not DoF.Events then return end

    -- Хелпер: обновить TargetFrame если таргетим себя
    local function UpdateTargetIfSelf()
        if UnitIsUnit("target", "player") then
            UF:UpdateTargetFrame()
            UF:UpdateTargetEffects()
        end
    end

    -- WoW-события (PLAYER_ENTERING_WORLD, PLAYER_TARGET_CHANGED, UNIT_PORTRAIT_UPDATE)
    -- зарегистрированы через AceEvent в Core/Init.lua

    -- HP игрока изменилось
    DoF.Events:Register("PLAYER_HP_CHANGED", function(currentHP, maxHP)
        UF:UpdatePlayerFrame()
        UpdateTargetIfSelf()
    end, UF)

    -- Щит игрока изменился
    DoF.Events:Register("PLAYER_SHIELD_CHANGED", function(shield)
        UF:UpdatePlayerFrame()
        UpdateTargetIfSelf()
    end, UF)

    -- Энергия игрока изменилась
    DoF.Events:Register("PLAYER_ENERGY_CHANGED", function(currentEnergy, maxEnergy)
        UF:UpdatePlayerFrame()
        UpdateTargetIfSelf()
    end, UF)

    -- Статы игрока изменились
    DoF.Events:Register("PLAYER_STATS_CHANGED", function()
        UF:UpdatePlayerFrame()
        UpdateTargetIfSelf()
    end, UF)

    -- Уровень изменился
    DoF.Events:Register("PLAYER_LEVEL_CHANGED", function(newLevel, oldLevel)
        UF:UpdatePlayerFrame()
        UpdateTargetIfSelf()
    end, UF)

    -- Ранения изменились (меняется и maxHP из-за штрафа, и currentHP при AddWound)
    DoF.Events:Register("PLAYER_WOUND_CHANGED", function(wounds)
        UF:UpdatePlayerFrame()
        UF:UpdatePlayerEffects()
        UpdateTargetIfSelf()
    end, UF)

    -- Роль изменилась
    DoF.Events:Register("PLAYER_SPEC_CHANGED", function(newSpec, oldSpec)
        UF:UpdatePlayerFrame()
    end, UF)

    -- HP юнита (NPC) изменилось
    DoF.Events:Register("UNIT_HP_CHANGED", function(guid, currentHP, maxHP)
        UF:UpdateTargetFrame()
    end, UF)

    -- Щит юнита (NPC) изменился
    DoF.Events:Register("UNIT_SHIELD_CHANGED", function(guid, shield)
        UF:UpdateTargetFrame()
    end, UF)

    -- Юнит создан
    DoF.Events:Register("UNIT_CREATED", function(guid, data)
        UF:UpdateTargetFrame()
        UF:UpdateTargetEffects()
    end, UF)

    -- Юнит удалён
    DoF.Events:Register("UNIT_REMOVED", function(guid)
        UF:UpdateTargetFrame()
    end, UF)

    -- Эффект применён
    DoF.Events:Register("EFFECT_APPLIED", function(targetType, targetId, effectId)
        -- Обновляем свои эффекты и HP бар если применён на себя
        if targetType == "player" and targetId == UnitName("player") then
            UF:UpdatePlayerEffects()
            UF:UpdatePlayerFrame()
        end
        -- Обновляем фрейм цели если применён на текущую цель (включая пороги защиты)
        if UnitExists("target") then
            local isTargetPlayer = UnitIsPlayer("target")
            local targetName = UnitName("target")
            local targetGuid = UnitGUID("target")
            if (targetType == "player" and isTargetPlayer and targetId == targetName) or
               (targetType == "npc" and not isTargetPlayer and targetId == targetGuid) then
                UF:UpdateTargetFrame()
            end
        end
    end, UF)

    -- Эффект удалён
    DoF.Events:Register("EFFECT_REMOVED", function(targetType, targetId, effectId)
        -- Обновляем свои эффекты и HP бар если удалён с себя
        if targetType == "player" and targetId == UnitName("player") then
            UF:UpdatePlayerEffects()
            UF:UpdatePlayerFrame()
        end
        -- Обновляем фрейм цели если удалён с текущей цели (включая пороги защиты)
        if UnitExists("target") then
            local isTargetPlayer = UnitIsPlayer("target")
            local targetName = UnitName("target")
            local targetGuid = UnitGUID("target")
            if (targetType == "player" and isTargetPlayer and targetId == targetName) or
               (targetType == "npc" and not isTargetPlayer and targetId == targetGuid) then
                UF:UpdateTargetFrame()
            end
        end
    end, UF)

    -- Данные другого игрока обновились (мастер изменил HP/Energy)
    DoF.Events:Register("PLAYER_DATA_RECEIVED", function(playerName)
        if UnitExists("target") and UnitIsPlayer("target") then
            local targetName = UnitName("target")
            if targetName == playerName then
                UF:UpdateTargetFrame()
                UF:UpdateTargetEffects()
            end
        end
    end, UF)

    -- Эффекты синхронизированы
    DoF.Events:Register("EFFECTS_SYNCED", function()
        UF:UpdatePlayerEffects()
        UF:UpdateTargetEffects()
    end, UF)

    -- Шаблон NPC применён — обновить пассивки на фрейме цели
    DoF.Events:Register("NPC_TEMPLATE_APPLIED", function(templateId, guid)
        if UnitExists("target") and not UnitIsPlayer("target") then
            local targetGuid = UnitGUID("target")
            if targetGuid == guid then
                UF:UpdateTargetFrame()
                UF:UpdateTargetEffects()
            end
        end
    end, UF)

    -- Принудительное обновление портрета после инициализации
    -- (на случай если PLAYER_ENTERING_WORLD уже произошёл до регистрации)
    C_Timer.After(0.1, function()
        UF:UpdatePlayerFrame()
        UF:UpdateTargetFrame()
    end)
end
