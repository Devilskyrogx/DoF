-- DoF/Core/Utils.lua
-- Утилитарные функции

local ADDON_NAME, DoF = ...

-- ═══════════════════════════════════════════════════════════
-- КЭШИРОВАНИЕ ГЛОБАЛЬНЫХ ФУНКЦИЙ
-- ═══════════════════════════════════════════════════════════
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local string_format = string.format

DoF.Utils = {}

-- ═══════════════════════════════════════════════════════════
-- ОБЩИЕ BACKDROP ШАБЛОНЫ (для переиспользования)
-- ═══════════════════════════════════════════════════════════
DoF.Utils.Backdrops = {
    Standard = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    },
}

-- ═══════════════════════════════════════════════════════════
-- ВЫВОД СООБЩЕНИЙ
-- ═══════════════════════════════════════════════════════════

function DoF.Utils:Print(color, text)
    print("|cFF" .. color .. "[DoF]|r " .. text)
end

function DoF.Utils:Info(text)
    self:Print("00FF00", text)
end

function DoF.Utils:Warn(text)
    self:Print("FFFF00", text)
end

function DoF.Utils:Error(text)
    self:Print("FF0000", text)
end

-- ═══════════════════════════════════════════════════════════
-- ФОРМАТИРОВАНИЕ ТЕКСТА
-- ═══════════════════════════════════════════════════════════

function DoF.Utils:Color(color, text)
    return "|cFF" .. color .. text .. "|r"
end

function DoF.Utils:ColorStat(stat, text)
    local color = DoF.Config.StatColors[stat] or "FFFFFF"
    return self:Color(color, text or DoF.Config.StatNames[stat])
end

-- ═══════════════════════════════════════════════════════════
-- РАБОТА С ЦЕЛЬЮ
-- ═══════════════════════════════════════════════════════════

function DoF.Utils:GetTargetGUID()
    if not UnitExists("target") then
        return nil, nil
    end
    return UnitGUID("target"), UnitName("target")
end


function DoF.Utils:IsTargetPlayer()
    return UnitExists("target") and UnitIsPlayer("target")
end

function DoF.Utils:RequireTarget(allowPlayer)
    local guid, name = self:GetTargetGUID()
    if not guid then
        self:Error(DoF.L["errors.no_target"])
        return nil, nil
    end
    if not allowPlayer and UnitIsPlayer("target") then
        self:Error(DoF.L["errors.not_for_players"])
        return nil, nil
    end
    return guid, name
end

-- ═══════════════════════════════════════════════════════════
-- ПРОВЕРКА МАСТЕРА
-- ═══════════════════════════════════════════════════════════

function DoF.Utils:IsMaster()
    return DoF.Sync and DoF.Sync:IsMaster()
end

-- Только мастер (или соло-режим вне группы) может выполнять master-only действия.
function DoF.Utils:RequireMaster(silent)
    if not IsInGroup() then return true end
    if DoF.Sync and DoF.Sync:IsMaster() then return true end
    if not silent then
        self:Error(DoF.L["errors.gm_only_action"])
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ ВАЛИДАЦИИ (с контекстом действия)
-- ═══════════════════════════════════════════════════════════

--- Проверка: сейчас ход игрока? Возвращает true если можно действовать.
function DoF.Utils:RequireTurn(actionName)
    if DoF.TurnSystem and not DoF.TurnSystem:CanAct() then
        if actionName then
            self:Error(DoF.Locale:Format("core.util.not_your_turn_action", actionName))
        else
            self:Error(DoF.L["errors.not_your_turn"])
        end
        return false
    end
    return true
end

--- Проверка энергии. Возвращает true если хватает.
function DoF.Utils:RequireEnergy(cost, actionName)
    local current = DoF.Stats:GetEnergy()
    if current < cost then
        local prefix = actionName and (actionName .. ": ") or ""
        self:Error(DoF.Locale:Format("core.util.not_enough_energy_detail", prefix, cost, current))
        return false
    end
    return true
end

--- Проверка: цель — игрок? Возвращает name или nil.
function DoF.Utils:RequirePlayerTarget(actionName)
    local guid, name = self:GetTargetGUID()
    if not guid or not UnitIsPlayer("target") then
        local prefix = actionName and (actionName .. ": ") or ""
        self:Error(DoF.Locale:Format("core.util.select_player_prefixed", prefix))
        return nil
    end
    return name
end

-- ═══════════════════════════════════════════════════════════
-- МАСШТАБИРОВАНИЕ UI
-- ═══════════════════════════════════════════════════════════

-- Базовое разрешение для которого UI выглядит оптимально
local BASE_HEIGHT = 768  -- Базовая высота экрана

-- Получить оптимальный масштаб для текущего разрешения
function DoF.Utils:GetUIScale()
    -- Если есть сохранённый пользовательский масштаб, используем его
    if DoF.db and DoF.db.profile and DoF.db.profile.uiScale then
        return DoF.db.profile.uiScale
    end
    
    -- Автоматический расчёт масштаба
    local screenHeight = GetScreenHeight()
    local uiScale = UIParent:GetEffectiveScale()
    
    -- Реальная высота в пикселях
    local realHeight = screenHeight * uiScale
    
    -- Масштаб относительно базового разрешения
    local scale = BASE_HEIGHT / realHeight
    
    -- Ограничиваем масштаб разумными пределами (0.6 - 1.2)
    return self:Clamp(scale, 0.6, 1.2)
end

-- Установить пользовательский масштаб
function DoF.Utils:SetUIScale(scale)
    if not DoF.db or not DoF.db.profile then return end
    
    scale = self:Clamp(scale or 1, 0.5, 1.5)
    DoF.db.profile.uiScale = scale
    
    -- Применить ко всем окнам
    self:ApplyUIScale()
    self:Info(DoF.Locale:Format("core.util.ui_scale_set", string.format("%.1f", scale)))
end

-- Сбросить масштаб на автоматический
function DoF.Utils:ResetUIScale()
    if DoF.db and DoF.db.profile then
        DoF.db.profile.uiScale = nil
    end
    self:ApplyUIScale()
    self:Info(DoF.L["core.util.ui_scale_reset"])
end

-- Применить масштаб ко всем окнам аддона
function DoF.Utils:ApplyUIScale()
    local scale = self:GetUIScale()
    
    -- Список всех окон для масштабирования
    local frames = {
        DoF_GMPanel,
        -- DoF_TurnQueueFrame — масштабируется отдельно через turnQueueScale
        DoF_AoEPanel,
        DoF_CounterattackPanel,
        DoF_TankHPBuffPanel,
        DoF_ModifyNPCHPDialog,
        DoF_NPCAttackDialog,
        DoF_ModifyPlayerHPDialog,
        DoF_SpecialActionFrame,
        DoF_SettingsFrame,
    }
    
    for _, frame in ipairs(frames) do
        if frame then
            frame:SetScale(scale)
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПРОЧЕЕ
-- ═══════════════════════════════════════════════════════════

function DoF.Utils:Roll(min, max)
    return math.random(min or 1, max or 20)
end

function DoF.Utils:Clamp(value, min, max)
    return math_max(min, math_min(max, value))
end

-- Обновить все UI компоненты
function DoF.Utils:UpdateAllUI()
    if DoF.UI then
        DoF.UI:UpdateAllNameplates()
        DoF.UI:UpdateAoEPanel()
    end
end

-- ═══════════════════════════════════════════════════════════
-- КАСТОМНЫЙ ТУЛТИП (стиль DoF)
-- ═══════════════════════════════════════════════════════════

local TOOLTIP_WIDTH = 230
local TOOLTIP_PAD = 10
local TOOLTIP_LINE_GAP = 4
-- НЕ GameFontNormal:GetFont(). Пока FontString наследует шрифт от объекта
-- Blizzard, клиент сам подбирает начертание для символов, которых в основном
-- файле нет. Как только путь к шрифту проставлен явно, эта подстраховка
-- пропадает: на английском клиенте FRIZQT__.TTF кириллицы не содержит, и
-- русский текст выводится квадратами. Поэтому берём шрифт, про который точно
-- известно, что кириллица в нём есть (см. блок ШРИФТЫ в Core/Config.lua).
local TOOLTIP_FONT = DoF.Config.FONT

local tooltipFrame = nil
local tooltipLines = {}

local ANCHOR_OFFSETS = {
    TOP    = { point = "BOTTOM", rel = "TOP",    x = 0,   y = 10  },
    RIGHT  = { point = "LEFT",   rel = "RIGHT",  x = 10,  y = 0   },
    BOTTOM = { point = "TOP",    rel = "BOTTOM", x = 0,   y = -10 },
    LEFT   = { point = "RIGHT",  rel = "LEFT",   x = -10, y = 0   },
}

function DoF.Utils:ShowTooltip(anchor, lines, anchorSide)
    if not tooltipFrame then
        tooltipFrame = CreateFrame("Frame", "DoF_Tooltip", UIParent, "BackdropTemplate")
        tooltipFrame:SetBackdrop(DoF.Utils.Backdrops.Standard)
        tooltipFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
        tooltipFrame:SetBackdropBorderColor(0.3, 0.25, 0.1, 1)
        tooltipFrame:SetFrameStrata("TOOLTIP")
        tooltipFrame:EnableMouse(false)
    end

    for i = 1, #tooltipLines do
        tooltipLines[i]:Hide()
    end

    local y = -TOOLTIP_PAD
    local fsIndex = 0
    for _, line in ipairs(lines) do
        if line.spacer then
            y = y - (line.height or 6)
        else
            fsIndex = fsIndex + 1
            local fs = tooltipLines[fsIndex]
            if not fs then
                fs = tooltipFrame:CreateFontString(nil, "OVERLAY")
                tooltipLines[fsIndex] = fs
            end

            -- Поддержка обоих форматов: {text, r, g, b, size} и {text=..., r=..., g=..., b=..., size=...}
            local lineText = line.text or line[1]
            local lineR = line.r or line[2] or 1
            local lineG = line.g or line[3] or 1
            local lineB = line.b or line[4] or 1
            local size = line.size or line[5] or 13
            local flags = line.outline and "OUTLINE" or ""
            fs:SetFont(TOOLTIP_FONT, size, flags)
            fs:SetTextColor(lineR, lineG, lineB)
            fs:SetText(lineText)
            fs:SetWidth(TOOLTIP_WIDTH - TOOLTIP_PAD * 2)
            fs:SetWordWrap(true)
            fs:SetJustifyH(line.justify or "LEFT")
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", TOOLTIP_PAD, y)
            fs:Show()

            y = y - fs:GetStringHeight() - TOOLTIP_LINE_GAP
        end
    end

    local totalHeight = -y + TOOLTIP_PAD - TOOLTIP_LINE_GAP
    tooltipFrame:SetSize(TOOLTIP_WIDTH, totalHeight)
    tooltipFrame:ClearAllPoints()

    local a = ANCHOR_OFFSETS[anchorSide or "TOP"]
    tooltipFrame:SetPoint(a.point, anchor, a.rel, a.x, a.y)
    tooltipFrame:Show()
end

function DoF.Utils:HideTooltip()
    if tooltipFrame then
        tooltipFrame:Hide()
    end
end
