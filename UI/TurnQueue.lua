-- DoF/UI/TurnQueue.lua
-- Окно очереди пошагового боя (v2 — полная переделка)

local ADDON_NAME, DoF = ...

-- ═══════════════════════════════════════════════════════════
-- КЭШИРОВАНИЕ ГЛОБАЛЬНЫХ ФУНКЦИЙ
-- ═══════════════════════════════════════════════════════════
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local string_format = string.format
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local wipe = wipe
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local UnitIsPlayer = UnitIsPlayer
local IsInRaid = IsInRaid
local InCombatLockdown = InCombatLockdown
local PlaySound = PlaySound
local C_Timer = C_Timer
local GetCursorPosition = GetCursorPosition

-- ═══════════════════════════════════════════════════════════
-- КОНСТАНТЫ
-- ═══════════════════════════════════════════════════════════

local ROW_HEIGHT = 64
local WINDOW_WIDTH = 300
local FOOTER_HEIGHT = 36
local FIXED_HEIGHT = 400         -- Зафиксированная высота окна
local BORDER_INSET = 26          -- Вертикальный отступ контента от края бордера
local BORDER_INSET_H = 26       -- Горизонтальный отступ (контент уже рамки)
local SCROLL_STEP = 30           -- Шаг скролла колесом
local MAX_VISIBLE_ROWS = 5
local SCROLL_BAR_WIDTH = 10
local SCROLL_THUMB_HEIGHT = 30
local MAX_EFFECTS = 12

-- Цвета (централизованная таблица)
local COLORS = {
    -- Подсветка строк
    rowSelf        = { 0.12, 0.12, 0.22, 0.8 },
    rowSelfBorder  = { 0.2, 0.2, 0.4, 0.8 },
    rowDefault     = { 0.08, 0.08, 0.08, 0.7 },
    rowDefaultBord = { 0.15, 0.15, 0.15, 0.5 },
    rowCurrent     = { 0.15, 0.35, 0.15, 0.9 },
    rowCurrentBord = { 0.3, 0.6, 0.3, 1 },
    rowFreeAction  = { 0.25, 0.2, 0.05, 0.9 },
    rowFreeActBord = { 0.9, 0.7, 0.2, 1 },

    -- Имя
    nameSelf       = "66CCFF",
    nameOther      = "FFFFFF",

    -- Статус бейджи
    statusOK       = { 0.1, 0.3, 0.1, 0.9 },
    statusOKBord   = { 0.2, 0.6, 0.2, 1 },
    statusCurrent  = { 0.3, 0.3, 0.1, 0.9 },
    statusCurBord  = { 0.6, 0.6, 0.2, 1 },
    statusFreeAct  = { 0.3, 0.25, 0.05, 0.9 },
    statusFABord   = { 0.8, 0.6, 0.1, 1 },

    -- HP бар
    hpGreen        = { 1, 1, 1 },
    hpYellow       = { 1, 1, 1 },
    hpRed          = { 1, 1, 1 },

    -- Щит
    shield         = { 0.4, 0.7, 1, 0.5 },
    shieldText     = { 0.4, 0.78, 1 },

    -- Энергия
    energyFull     = { 0.5, 0.3, 0.8 },
    energyEmpty    = { 0.15, 0.15, 0.15 },

    -- Эффекты рамка
    effectBuff     = { 0.2, 0.7, 0.2, 1 },
    effectDebuff   = { 0.7, 0.2, 0.2, 1 },
    effectNeutral  = { 0.4, 0.4, 0.4, 1 },

    -- Раны
    woundText      = { 1, 0.3, 0.3 },

    -- Таймер
    timerSafe      = "FFFFFF",
    timerWarn      = "FFFF00",
    timerDanger    = "FF6666",

    -- Скроллбар
    scrollBg       = { 0.1, 0.1, 0.1, 0.8 },
    scrollThumb    = { 0.4, 0.4, 0.4, 1 },
    scrollHover    = { 0.6, 0.6, 0.6, 1 },
    scrollDrag     = { 0.7, 0.7, 0.7, 1 },

    -- Кнопки
    btnDefault     = { 0.15, 0.15, 0.15, 1 },
    btnDefaultBord = { 0.3, 0.3, 0.3, 1 },
    btnHover       = { 0.25, 0.25, 0.25, 1 },
    btnHoverBord   = { 0.4, 0.4, 0.4, 1 },
    btnGreen       = { 0.1, 0.2, 0.1, 1 },
    btnGreenBord   = { 0.2, 0.4, 0.2, 1 },
    btnGreenHover  = { 0.15, 0.3, 0.15, 1 },
    btnGreenHBord  = { 0.3, 0.5, 0.3, 1 },
    btnRed         = { 0.3, 0.1, 0.1, 1 },
    btnRedBord     = { 0.5, 0.2, 0.2, 1 },
    btnRedHover    = { 0.5, 0.15, 0.15, 1 },
    btnSkip        = { 0.2, 0.15, 0.1, 1 },
    btnSkipBord    = { 0.4, 0.3, 0.2, 1 },
    btnSkipHover   = { 0.3, 0.25, 0.15, 1 },

    -- Прогресс текст
    progressText   = { 0.7, 0.7, 0.7 },
}

-- Текстуры (легко заменить позже)
local TEXTURES = {
    -- HP бары (существующие)
    hpGreen    = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_green",
    hpYellow   = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_yellow",
    hpRed      = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_red",
    barTexture = "Interface\\AddOns\\DoF\\texture\\bar_texture",

    -- Роли (существующие)
    roleTank   = "Interface\\AddOns\\DoF\\texture\\roles\\tank",
    roleDD     = "Interface\\AddOns\\DoF\\texture\\roles\\damage",
    roleHeal   = "Interface\\AddOns\\DoF\\texture\\roles\\heal",

    -- Иконки (существующие)
    skull      = "Interface\\AddOns\\DoF\\texture\\skull",
    white8x8   = "Interface\\Buttons\\WHITE8x8",

    -- Атлас рамки окна
    frameBg          = "talenttree-alliance-background",
}

-- Карта ролей → текстура
local ROLE_ICONS = {
    tank   = TEXTURES.roleTank,
    dd     = TEXTURES.roleDD,
    healer = TEXTURES.roleHeal,
}

-- Локальные ссылки
local TurnQueueFrame = nil

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

local function GetUnitIdByName(name)
    if UnitName("player") == name then return "player" end
    if IsInRaid() then
        for i = 1, 40 do
            if UnitName("raid" .. i) == name then return "raid" .. i end
        end
    else
        for i = 1, 4 do
            if UnitName("party" .. i) == name then return "party" .. i end
        end
    end
    return nil
end

local function GetHPTexture(percent)
    if percent > 0.5 then
        return TEXTURES.hpGreen
    elseif percent > 0.25 then
        return TEXTURES.hpYellow
    else
        return TEXTURES.hpRed
    end
end

local function GetRoleIcon(role)
    return ROLE_ICONS[role] or TEXTURES.roleDD
end

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ РАМКИ ОКНА
-- ═══════════════════════════════════════════════════════════

local BORDER_WIDTH = 2  -- Толщина линии рамки

local function CreateFrameBorder(f)
    -- Фон (тёмный)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", BORDER_WIDTH, -BORDER_WIDTH)
    bg:SetPoint("BOTTOMRIGHT", -BORDER_WIDTH, BORDER_WIDTH)
    bg:SetAtlas(TEXTURES.frameBg)
    f.bg = bg

    -- ═══ Золотая рамка (кастомная, из линий) ═══

    -- Внешняя обводка (тёмно-золотая)
    local outerTop = f:CreateTexture(nil, "OVERLAY", nil, 1)
    outerTop:SetHeight(1)
    outerTop:SetPoint("TOPLEFT", 0, 0)
    outerTop:SetPoint("TOPRIGHT", 0, 0)
    outerTop:SetColorTexture(0.35, 0.28, 0.10, 1)

    local outerBottom = f:CreateTexture(nil, "OVERLAY", nil, 1)
    outerBottom:SetHeight(1)
    outerBottom:SetPoint("BOTTOMLEFT", 0, 0)
    outerBottom:SetPoint("BOTTOMRIGHT", 0, 0)
    outerBottom:SetColorTexture(0.35, 0.28, 0.10, 1)

    local outerLeft = f:CreateTexture(nil, "OVERLAY", nil, 1)
    outerLeft:SetWidth(1)
    outerLeft:SetPoint("TOPLEFT", 0, 0)
    outerLeft:SetPoint("BOTTOMLEFT", 0, 0)
    outerLeft:SetColorTexture(0.35, 0.28, 0.10, 1)

    local outerRight = f:CreateTexture(nil, "OVERLAY", nil, 1)
    outerRight:SetWidth(1)
    outerRight:SetPoint("TOPRIGHT", 0, 0)
    outerRight:SetPoint("BOTTOMRIGHT", 0, 0)
    outerRight:SetColorTexture(0.35, 0.28, 0.10, 1)

    -- Основная линия (золотая, яркая)
    local goldTop = f:CreateTexture(nil, "OVERLAY", nil, 2)
    goldTop:SetHeight(BORDER_WIDTH)
    goldTop:SetPoint("TOPLEFT", 1, -1)
    goldTop:SetPoint("TOPRIGHT", -1, -1)
    goldTop:SetColorTexture(0.65, 0.53, 0.20, 1)

    local goldBottom = f:CreateTexture(nil, "OVERLAY", nil, 2)
    goldBottom:SetHeight(BORDER_WIDTH)
    goldBottom:SetPoint("BOTTOMLEFT", 1, 1)
    goldBottom:SetPoint("BOTTOMRIGHT", -1, 1)
    goldBottom:SetColorTexture(0.50, 0.40, 0.15, 1)

    local goldLeft = f:CreateTexture(nil, "OVERLAY", nil, 2)
    goldLeft:SetWidth(BORDER_WIDTH)
    goldLeft:SetPoint("TOPLEFT", 1, -1)
    goldLeft:SetPoint("BOTTOMLEFT", 1, 1)
    goldLeft:SetColorTexture(0.55, 0.45, 0.18, 1)

    local goldRight = f:CreateTexture(nil, "OVERLAY", nil, 2)
    goldRight:SetWidth(BORDER_WIDTH)
    goldRight:SetPoint("TOPRIGHT", -1, -1)
    goldRight:SetPoint("BOTTOMRIGHT", -1, 1)
    goldRight:SetColorTexture(0.55, 0.45, 0.18, 1)

    -- Внутренняя обводка (тёмная, глубина)
    local innerTop = f:CreateTexture(nil, "OVERLAY", nil, 3)
    innerTop:SetHeight(1)
    innerTop:SetPoint("TOPLEFT", BORDER_WIDTH + 1, -(BORDER_WIDTH + 1))
    innerTop:SetPoint("TOPRIGHT", -(BORDER_WIDTH + 1), -(BORDER_WIDTH + 1))
    innerTop:SetColorTexture(0.20, 0.16, 0.06, 1)

    local innerBottom = f:CreateTexture(nil, "OVERLAY", nil, 3)
    innerBottom:SetHeight(1)
    innerBottom:SetPoint("BOTTOMLEFT", BORDER_WIDTH + 1, BORDER_WIDTH + 1)
    innerBottom:SetPoint("BOTTOMRIGHT", -(BORDER_WIDTH + 1), BORDER_WIDTH + 1)
    innerBottom:SetColorTexture(0.20, 0.16, 0.06, 1)

    local innerLeft = f:CreateTexture(nil, "OVERLAY", nil, 3)
    innerLeft:SetWidth(1)
    innerLeft:SetPoint("TOPLEFT", BORDER_WIDTH + 1, -(BORDER_WIDTH + 1))
    innerLeft:SetPoint("BOTTOMLEFT", BORDER_WIDTH + 1, BORDER_WIDTH + 1)
    innerLeft:SetColorTexture(0.20, 0.16, 0.06, 1)

    local innerRight = f:CreateTexture(nil, "OVERLAY", nil, 3)
    innerRight:SetWidth(1)
    innerRight:SetPoint("TOPRIGHT", -(BORDER_WIDTH + 1), -(BORDER_WIDTH + 1))
    innerRight:SetPoint("BOTTOMRIGHT", -(BORDER_WIDTH + 1), BORDER_WIDTH + 1)
    innerRight:SetColorTexture(0.20, 0.16, 0.06, 1)
end

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ ОКНА ОЧЕРЕДИ
-- ═══════════════════════════════════════════════════════════

local function CreateTurnQueueFrame()
    if TurnQueueFrame then return TurnQueueFrame end

    local f = CreateFrame("Frame", "DoF_TurnQueueFrame", UIParent)
    f:SetSize(WINDOW_WIDTH, FIXED_HEIGHT)
    f:SetPoint("TOP", 0, -100)  -- Фолбэк, перезаписывается в ShowTurnQueue
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:Hide()

    -- ═══ РАМКА (атлас-текстуры) ═══
    CreateFrameBorder(f)

    -- ═══ РЕСАЙЗЕР (масштаб 0.7–1.5) ═══
    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", 0, 0)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:EnableMouse(true)
    resizer:SetFrameLevel(f:GetFrameLevel() + 10)

    resizer:SetScript("OnMouseDown", function(self)
        self.startX = GetCursorPosition()
        self.startScale = f:GetScale()
        self:SetScript("OnUpdate", function(self)
            local cx = GetCursorPosition()
            local dx = (cx - self.startX) / UIParent:GetEffectiveScale()
            local newScale = DoF.Utils:Clamp(self.startScale + dx / 300, 0.7, 1.5)
            f:SetScale(newScale)
            local tracker = _G["DoF_TrackerHeader"]
            if tracker then tracker:SetScale(newScale) end
        end)
    end)

    resizer:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        local newScale = f:GetScale()
        if DoF.db and DoF.db.profile then
            DoF.db.profile.turnQueueScale = newScale
        end
    end)

    -- ═══ КНОПКА СВЕРНУТЬ/РАЗВЕРНУТЬ ═══
    f.isCollapsed = false

    local collapseBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    collapseBtn:SetSize(28, 20)
    collapseBtn:SetPoint("TOPRIGHT", -4, -4)
    collapseBtn:SetBackdrop(DoF.Utils.Backdrops.Standard)
    collapseBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
    collapseBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    collapseBtn:SetFrameLevel(f:GetFrameLevel() + 5)

    collapseBtn.label = collapseBtn:CreateFontString(nil, "OVERLAY")
    collapseBtn.label:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    collapseBtn.label:SetPoint("CENTER", 0, 1)
    collapseBtn.label:SetText("-")
    collapseBtn.label:SetTextColor(0.7, 0.7, 0.7)
    f.collapseBtn = collapseBtn

    collapseBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 1)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        self.label:SetTextColor(1, 1, 1)
    end)
    collapseBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.15, 0.15, 0.9)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        self.label:SetTextColor(0.7, 0.7, 0.7)
    end)
    collapseBtn:SetScript("OnClick", function()
        if f.isCollapsed then
            -- Развернуть
            f.isCollapsed = false
            f:Show()
            DoF.UI:UpdateTurnQueue()
            -- Скрыть индикатор на трекере
            DoF.UI:HideTrackerCollapseIndicator()
        else
            -- Свернуть — скрываем весь фрейм
            f.isCollapsed = true
            f:Hide()
            -- Показать индикатор на трекере (число не сходивших)
            local ts = DoF.TurnSystem
            if ts and ts:IsActive() then
                local notActed = 0
                for _, p in ipairs(ts.participants) do
                    if not p.acted then notActed = notActed + 1 end
                end
                DoF.UI:ShowTrackerCollapseIndicator(notActed, ts.phase)
            end
        end
    end)

    -- ═══ КОНТЕЙНЕР СПИСКА (привязан к верху рамки — таймер перенесён на трекер) ═══
    local listContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    listContainer:SetPoint("TOPLEFT", BORDER_INSET_H, -BORDER_INSET)
    listContainer:SetPoint("TOPRIGHT", -BORDER_INSET_H, -BORDER_INSET)
    listContainer:SetPoint("BOTTOM", 0, BORDER_INSET + FOOTER_HEIGHT + 4)
    listContainer:SetBackdrop(DoF.Utils.Backdrops.Standard)
    listContainer:SetBackdropColor(0.05, 0.05, 0.05, 0.7)
    listContainer:SetBackdropBorderColor(0.12, 0.12, 0.12, 1)
    f.listContainer = listContainer

    -- Скролл
    local scroll = CreateFrame("ScrollFrame", "DoF_TurnQueueScroll", listContainer)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -(4 + SCROLL_BAR_WIDTH + 2), 4)
    f.scrollFrame = scroll

    f.content = CreateFrame("Frame", "DoF_TurnQueueContent", scroll)
    f.content:SetWidth(scroll:GetWidth())
    f.content:SetHeight(200)
    scroll:SetScrollChild(f.content)

    -- Кастомный скроллбар
    local scrollBar = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    scrollBar:SetWidth(SCROLL_BAR_WIDTH)
    scrollBar:SetPoint("TOPRIGHT", -4, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", -4, 4)
    scrollBar:SetBackdrop({ bgFile = TEXTURES.white8x8 })
    scrollBar:SetBackdropColor(unpack(COLORS.scrollBg))
    scrollBar:Hide()
    f.scrollBar = scrollBar

    -- Ползунок
    local scrollThumb = CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
    scrollThumb:SetWidth(SCROLL_BAR_WIDTH)
    scrollThumb:SetHeight(SCROLL_THUMB_HEIGHT)
    scrollThumb:SetBackdrop({ bgFile = TEXTURES.white8x8 })
    scrollThumb:SetBackdropColor(unpack(COLORS.scrollThumb))
    scrollThumb:EnableMouse(true)
    scrollThumb:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    f.scrollThumb = scrollThumb

    scrollThumb:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.scrollHover))
    end)
    scrollThumb:SetScript("OnLeave", function(self)
        if not self.isDragging then
            self:SetBackdropColor(unpack(COLORS.scrollThumb))
        end
    end)

    -- Драг ползунка
    scrollThumb:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self.isDragging = true
            self.startY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
            self:SetBackdropColor(unpack(COLORS.scrollDrag))
        end
    end)
    scrollThumb:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self.isDragging = false
            if self:IsMouseOver() then
                self:SetBackdropColor(unpack(COLORS.scrollHover))
            else
                self:SetBackdropColor(unpack(COLORS.scrollThumb))
            end
        end
    end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local curY = select(2, GetCursorPosition()) / UIParent:GetEffectiveScale()
            local delta = self.startY - curY
            self.startY = curY

            local maxScroll = f.content:GetHeight() - scroll:GetHeight()
            if maxScroll > 0 then
                local scrollBarHeight = scrollBar:GetHeight()
                local thumbHeight = self:GetHeight()
                local scrollRatio = delta / (scrollBarHeight - thumbHeight) * maxScroll
                local newScroll = math_max(0, math_min(maxScroll, scroll:GetVerticalScroll() + scrollRatio))
                scroll:SetVerticalScroll(newScroll)
            end
        end
    end)

    -- Обновление позиции ползунка при скролле
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        local maxScroll = f.content:GetHeight() - self:GetHeight()
        if maxScroll > 0 then
            local scrollRatio = offset / maxScroll
            local scrollBarHeight = scrollBar:GetHeight()
            local thumbHeight = scrollThumb:GetHeight()
            local maxThumbOffset = scrollBarHeight - thumbHeight
            scrollThumb:SetPoint("TOP", scrollBar, "TOP", 0, -scrollRatio * maxThumbOffset)
        end
    end)

    -- Скролл колесом
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = f.content:GetHeight() - self:GetHeight()
        if maxScroll > 0 then
            local current = self:GetVerticalScroll()
            local newScroll = math_max(0, math_min(maxScroll, current - delta * SCROLL_STEP))
            self:SetVerticalScroll(newScroll)
        end
    end)

    f.rows = {}

    -- ═══ FOOTER (36px) ═══
    local footer = CreateFrame("Frame", nil, f)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", BORDER_INSET_H, BORDER_INSET)
    footer:SetPoint("BOTTOMRIGHT", -BORDER_INSET_H, BORDER_INSET)
    f.footer = footer

    -- Кнопка Пропуск
    f.skipBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    f.skipBtn:SetSize(60, 26)
    f.skipBtn:SetPoint("RIGHT", footer, "CENTER", -2, 0)
    f.skipBtn:SetBackdrop(DoF.Utils.Backdrops.Standard)
    f.skipBtn:SetBackdropColor(unpack(COLORS.btnDefault))
    f.skipBtn:SetBackdropBorderColor(unpack(COLORS.btnDefaultBord))

    f.skipBtn.text = f.skipBtn:CreateFontString(nil, "OVERLAY")
    f.skipBtn.text:SetFont(DoF.Config.FONT, 10, "")
    f.skipBtn.text:SetPoint("CENTER")
    f.skipBtn.text:SetText(DoF.L["ui.common.skip"])
    f.skipBtn.text:SetTextColor(0.8, 0.8, 0.8)

    f.skipBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.btnHover))
        self:SetBackdropBorderColor(unpack(COLORS.btnHoverBord))
    end)
    f.skipBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.btnDefault))
        self:SetBackdropBorderColor(unpack(COLORS.btnDefaultBord))
    end)
    f.skipBtn:SetScript("OnClick", function(self)
        -- Защита от двойного клика
        self:Disable()
        C_Timer.After(0.1, function()
            if self:IsShown() then self:Enable() end
        end)
        if DoF.Sync:IsMaster() then
            DoF.TurnSystem:SkipTurn()
        else
            DoF.TurnSystem:PlayerSkipTurn()
        end
    end)

    -- Кнопка +Игрок (мастер)
    f.addBtn = CreateFrame("Button", nil, footer, "BackdropTemplate")
    f.addBtn:SetSize(64, 26)
    f.addBtn:SetPoint("LEFT", footer, "CENTER", 2, 0)
    f.addBtn:SetBackdrop(DoF.Utils.Backdrops.Standard)
    f.addBtn:SetBackdropColor(unpack(COLORS.btnGreen))
    f.addBtn:SetBackdropBorderColor(unpack(COLORS.btnGreenBord))

    f.addBtn.text = f.addBtn:CreateFontString(nil, "OVERLAY")
    f.addBtn.text:SetFont(DoF.Config.FONT, 10, "")
    f.addBtn.text:SetPoint("CENTER")
    f.addBtn.text:SetText(DoF.L["ui.queue.add_player"])

    f.addBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.btnGreenHover))
        self:SetBackdropBorderColor(unpack(COLORS.btnGreenHBord))
    end)
    f.addBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.btnGreen))
        self:SetBackdropBorderColor(unpack(COLORS.btnGreenBord))
    end)
    f.addBtn:SetScript("OnClick", function()
        local target = UnitName("target")
        if not target then
            DoF.Utils:Error(DoF.L["errors.select_player"])
            return
        end
        if not UnitIsPlayer("target") then
            DoF.Utils:Error(DoF.L["errors.target_must_be_player"])
            return
        end
        DoF.TurnSystem:AddParticipant(target)
    end)
    f.addBtn:Hide()

    -- Прогресс текст
    f.progressText = footer:CreateFontString(nil, "OVERLAY")
    f.progressText:SetFont(DoF.Config.FONT, 10, "")
    f.progressText:SetPoint("LEFT", f.addBtn, "RIGHT", 6, 0)
    f.progressText:SetTextColor(unpack(COLORS.progressText))

    TurnQueueFrame = f
    return f
end

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ СТРОКИ УЧАСТНИКА (КАРТОЧКА 64px)
-- ═══════════════════════════════════════════════════════════

local function CreateParticipantRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate, BackdropTemplate")
    row:RegisterForClicks("LeftButtonUp")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop(DoF.Utils.Backdrops.Standard)
    row:SetBackdropColor(unpack(COLORS.rowDefault))
    row:SetBackdropBorderColor(unpack(COLORS.rowDefaultBord))

    -- ═══ ЛЕВАЯ СЕКЦИЯ: Иконка роли + индикатор хода ═══
    local leftSection = CreateFrame("Frame", nil, row)
    leftSection:SetSize(28, ROW_HEIGHT)
    leftSection:SetPoint("TOPLEFT", 2, -2)

    -- Иконка роли
    row.roleIcon = leftSection:CreateTexture(nil, "ARTWORK")
    row.roleIcon:SetSize(20, 20)
    row.roleIcon:SetPoint("TOP", 4, -4)
    row.roleIcon:SetTexture(TEXTURES.roleDD)

    -- Индикатор текущего хода (стрелка)
    row.turnArrow = leftSection:CreateFontString(nil, "OVERLAY")
    row.turnArrow:SetFont(DoF.Config.FONT, 14, "OUTLINE")
    row.turnArrow:SetPoint("TOP", row.roleIcon, "BOTTOM", 0, -2)
    row.turnArrow:SetText("")
    row.turnArrow:SetTextColor(0, 1, 0.59)

    -- ═══ ЦЕНТРАЛЬНАЯ СЕКЦИЯ ═══
    local centerLeft = 30  -- Начало центра (после левой секции)

    -- Верхняя линия: Имя + Уровень + Roll + Статус
    local topLine = CreateFrame("Frame", nil, row)
    topLine:SetHeight(20)
    topLine:SetPoint("TOPLEFT", centerLeft, -2)
    topLine:SetPoint("TOPRIGHT", -26, -2)

    row.nameText = topLine:CreateFontString(nil, "OVERLAY")
    row.nameText:SetFont(DoF.Config.FONT, 11, "OUTLINE")
    row.nameText:SetPoint("LEFT", 0, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWidth(120)

    row.levelText = topLine:CreateFontString(nil, "OVERLAY")
    row.levelText:SetFont(DoF.Config.FONT, 9, "")
    row.levelText:SetPoint("LEFT", row.nameText, "RIGHT", 2, 0)
    row.levelText:SetTextColor(0.5, 0.5, 0.5)

    row.rollText = topLine:CreateFontString(nil, "OVERLAY")
    row.rollText:SetFont(DoF.Config.FONT, 9, "")
    row.rollText:SetPoint("RIGHT", -30, 0)
    row.rollText:SetJustifyH("RIGHT")
    row.rollText:SetTextColor(0.6, 0.6, 0.6)

    -- Статус бейдж (OK / >> / Вн.ход)
    row.statusBadge = CreateFrame("Frame", nil, topLine, "BackdropTemplate")
    row.statusBadge:SetSize(36, 14)
    row.statusBadge:SetPoint("RIGHT", 0, 0)
    row.statusBadge:SetBackdrop(DoF.Utils.Backdrops.Standard)
    row.statusBadge:SetBackdropColor(0, 0, 0, 0)
    row.statusBadge:SetBackdropBorderColor(0, 0, 0, 0)

    row.statusText = row.statusBadge:CreateFontString(nil, "OVERLAY")
    row.statusText:SetFont(DoF.Config.FONT, 8, "OUTLINE")
    row.statusText:SetPoint("CENTER")

    -- Средняя линия: HP бар + Раны
    local midLine = CreateFrame("Frame", nil, row)
    midLine:SetHeight(14)
    midLine:SetPoint("TOPLEFT", centerLeft, -22)
    midLine:SetPoint("TOPRIGHT", -26, -22)

    -- HP Bar
    row.hpBar = CreateFrame("StatusBar", nil, midLine, "BackdropTemplate")
    row.hpBar:SetHeight(12)
    row.hpBar:SetPoint("LEFT", 0, 0)
    row.hpBar:SetPoint("RIGHT", 0, 0)
    row.hpBar:SetMinMaxValues(0, 10)
    row.hpBar:SetValue(10)
    row.hpBar:SetStatusBarTexture(TEXTURES.hpGreen)
    row.hpBar:SetStatusBarColor(1, 1, 1)
    row.hpBar:SetBackdrop(DoF.Utils.Backdrops.Standard)
    row.hpBar:SetBackdropColor(0.04, 0.04, 0.04, 1)
    row.hpBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    -- HP текст
    row.hpText = row.hpBar:CreateFontString(nil, "OVERLAY")
    row.hpText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    row.hpText:SetPoint("CENTER")
    row.hpText:SetTextColor(1, 1, 1)

    -- Щит поверх HP
    row.shieldBar = CreateFrame("StatusBar", nil, row.hpBar)
    row.shieldBar:SetAllPoints()
    row.shieldBar:SetMinMaxValues(0, 10)
    row.shieldBar:SetValue(0)
    row.shieldBar:SetStatusBarTexture(TEXTURES.barTexture)
    row.shieldBar:SetStatusBarColor(unpack(COLORS.shield))
    row.shieldBar:SetFrameLevel(row.hpBar:GetFrameLevel() + 1)

    -- Текст щита (справа от HP)
    row.shieldText = row.hpBar:CreateFontString(nil, "OVERLAY")
    row.shieldText:SetFont(DoF.Config.FONT, 8, "OUTLINE")
    row.shieldText:SetPoint("RIGHT", -2, 0)
    row.shieldText:SetTextColor(unpack(COLORS.shieldText))

    -- Иконка ран (череп)
    row.woundIcon = row.hpBar:CreateTexture(nil, "OVERLAY")
    row.woundIcon:SetSize(12, 12)
    row.woundIcon:SetPoint("RIGHT", row.shieldText, "LEFT", -2, 0)
    row.woundIcon:SetTexture(TEXTURES.skull)
    row.woundIcon:Hide()

    row.woundText = row.hpBar:CreateFontString(nil, "OVERLAY")
    row.woundText:SetFont(DoF.Config.FONT, 8, "OUTLINE")
    row.woundText:SetPoint("RIGHT", row.woundIcon, "LEFT", -1, 0)
    row.woundText:SetTextColor(unpack(COLORS.woundText))

    -- Нижняя линия: Энергия + Эффекты
    local bottomLine = CreateFrame("Frame", nil, row)
    bottomLine:SetHeight(20)
    bottomLine:SetPoint("TOPLEFT", centerLeft, -38)
    bottomLine:SetPoint("TOPRIGHT", -26, -38)

    -- Энергия (StatusBar с текстурой, как в главном меню)
    row.energyBar = CreateFrame("StatusBar", nil, bottomLine, "BackdropTemplate")
    row.energyBar:SetSize(55, 10)
    row.energyBar:SetPoint("LEFT", 0, 0)
    row.energyBar:SetMinMaxValues(0, 5)
    row.energyBar:SetValue(0)
    row.energyBar:SetStatusBarTexture("Interface\\AddOns\\DoF\\texture\\bars\\Energy_bar")
    row.energyBar:SetStatusBarColor(1, 1, 1)
    row.energyBar:SetBackdrop(DoF.Utils.Backdrops.Standard)
    row.energyBar:SetBackdropColor(0.04, 0.04, 0.04, 1)
    row.energyBar:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

    row.energyText = row.energyBar:CreateFontString(nil, "OVERLAY")
    row.energyText:SetFont(DoF.Config.FONT, 8, "OUTLINE")
    row.energyText:SetPoint("CENTER")
    row.energyText:SetTextColor(1, 1, 1)

    -- Иконки эффектов
    row.effectIcons = {}
    for i = 1, MAX_EFFECTS do
        local icon = CreateFrame("Frame", nil, bottomLine, "BackdropTemplate")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", 60 + (i - 1) * 20, 0)
        icon:SetBackdrop({
            bgFile = TEXTURES.white8x8,
            edgeFile = TEXTURES.white8x8,
            edgeSize = 1,
        })
        icon:SetBackdropColor(0.1, 0.1, 0.1, 1)
        icon:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        icon:Hide()

        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetPoint("TOPLEFT", 1, -1)
        icon.texture:SetPoint("BOTTOMRIGHT", -1, 1)

        icon.stacks = icon:CreateFontString(nil, "OVERLAY")
        icon.stacks:SetFont(DoF.Config.FONT, 8, "OUTLINE")
        icon.stacks:SetPoint("BOTTOMRIGHT", 2, -2)
        icon.stacks:SetTextColor(1, 1, 1)

        icon:EnableMouse(true)
        icon:SetScript("OnEnter", function(self)
            if self.effectId and self.effectData then
                local def = DoF.Effects.Definitions[self.effectId]
                if def then
                    local tc = def.type == "buff" and {0, 1, 0} or {1, 0.27, 0.27}
                    local lines = {
                        {def.name, tc[1], tc[2], tc[3], 14},
                    }
                    if def.description then
                        lines[#lines + 1] = {def.description, 1, 1, 1, 13}
                    end
                    lines[#lines + 1] = {DoF.Locale:Format("ui.queue.rounds_left", self.effectData.remainingRounds or 0), 0.7, 0.7, 0.7, 13}
                    local val = self.effectData.value or 0
                    if val > 0 then
                        lines[#lines + 1] = {DoF.Locale:Format("ui.queue.value", val), 0.7, 0.7, 0.7, 13}
                    end
                    DoF.Utils:ShowTooltip(self, lines, "RIGHT")
                end
            end
        end)
        icon:SetScript("OnLeave", function() DoF.Utils:HideTooltip() end)

        row.effectIcons[i] = icon
    end

    -- ═══ ПРАВАЯ СЕКЦИЯ: Кнопки мастера ═══
    local rightSection = CreateFrame("Frame", nil, row)
    rightSection:SetSize(24, ROW_HEIGHT)
    rightSection:SetPoint("TOPRIGHT", -2, -2)

    -- Кнопка пропуска (только мастер, свободный режим)
    row.skipBtn = CreateFrame("Button", nil, rightSection, "BackdropTemplate")
    row.skipBtn:SetSize(20, 20)
    row.skipBtn:SetPoint("TOP", 0, -2)
    row.skipBtn:SetBackdrop(DoF.Utils.Backdrops.Standard)
    row.skipBtn:SetBackdropColor(unpack(COLORS.btnSkip))
    row.skipBtn:SetBackdropBorderColor(unpack(COLORS.btnSkipBord))
    row.skipBtn:Hide()

    row.skipBtn.icon = row.skipBtn:CreateFontString(nil, "OVERLAY")
    row.skipBtn.icon:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    row.skipBtn.icon:SetPoint("CENTER", 0, 1)
    row.skipBtn.icon:SetText(">>")
    row.skipBtn.icon:SetTextColor(0.8, 0.7, 0.6)

    row.skipBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.btnSkipHover))
        DoF.Utils:ShowTooltip(self, { {DoF.L["ui.queue.skip_turn"], 1, 1, 1, 13} }, "RIGHT")
    end)
    row.skipBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.btnSkip))
        DoF.Utils:HideTooltip()
    end)
    row.skipBtn:SetScript("OnClick", function(self)
        if self.playerGUID and DoF.TurnSystem then
            DoF.TurnSystem:SkipPlayerTurn(self.playerGUID)
        end
    end)

    -- Кнопка удаления (только мастер)
    row.removeBtn = CreateFrame("Button", nil, rightSection, "BackdropTemplate")
    row.removeBtn:SetSize(20, 20)
    row.removeBtn:SetPoint("TOP", row.skipBtn, "BOTTOM", 0, -2)
    row.removeBtn:SetBackdrop(DoF.Utils.Backdrops.Standard)
    row.removeBtn:SetBackdropColor(unpack(COLORS.btnRed))
    row.removeBtn:SetBackdropBorderColor(unpack(COLORS.btnRedBord))
    row.removeBtn:Hide()

    row.removeBtn.icon = row.removeBtn:CreateFontString(nil, "OVERLAY")
    row.removeBtn.icon:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    row.removeBtn.icon:SetPoint("CENTER", 0, 1)
    row.removeBtn.icon:SetText("X")
    row.removeBtn.icon:SetTextColor(1, 0.4, 0.4)

    row.removeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.btnRedHover))
        self.icon:SetTextColor(1, 1, 1)
        DoF.Utils:ShowTooltip(self, { {DoF.L["ui.queue.remove_from_combat"], 1, 1, 1, 13} }, "RIGHT")
    end)
    row.removeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLORS.btnRed))
        self.icon:SetTextColor(1, 0.4, 0.4)
        DoF.Utils:HideTooltip()
    end)
    row.removeBtn:SetScript("OnClick", function(self)
        if self.playerName and DoF.TurnSystem then
            DoF.TurnSystem:RemoveParticipant(self.playerName)
        end
    end)

    return row
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ ОДНОЙ СТРОКИ УЧАСТНИКА
-- ═══════════════════════════════════════════════════════════

local function UpdateParticipantRow(row, p, i, ctx)
    local isMe = (p.guid == ctx.myGUID)
    local isCurrent = (i == ctx.currentIndex)
    local hasFreeAction = (ctx.freeActionGUID and ctx.freeActionGUID == p.guid)

    -- ═══ ПОДСВЕТКА СТРОКИ ═══
    if ctx.isNPCPhase then
        row.turnArrow:SetText("")
        if isMe then
            row:SetBackdropColor(unpack(COLORS.rowSelf))
            row:SetBackdropBorderColor(unpack(COLORS.rowSelfBorder))
        else
            row:SetBackdropColor(unpack(COLORS.rowDefault))
            row:SetBackdropBorderColor(unpack(COLORS.rowDefaultBord))
        end
    elseif ctx.isQueueMode then
        if isCurrent then
            row:SetBackdropColor(unpack(COLORS.rowCurrent))
            row:SetBackdropBorderColor(unpack(COLORS.rowCurrentBord))
            row.turnArrow:SetText(">")
        else
            row.turnArrow:SetText("")
            if isMe then
                row:SetBackdropColor(unpack(COLORS.rowSelf))
                row:SetBackdropBorderColor(unpack(COLORS.rowSelfBorder))
            else
                row:SetBackdropColor(unpack(COLORS.rowDefault))
                row:SetBackdropBorderColor(unpack(COLORS.rowDefaultBord))
            end
        end
    else
        row.turnArrow:SetText("")
        if isMe then
            row:SetBackdropColor(unpack(COLORS.rowSelf))
            row:SetBackdropBorderColor(unpack(COLORS.rowSelfBorder))
        else
            row:SetBackdropColor(unpack(COLORS.rowDefault))
            row:SetBackdropBorderColor(unpack(COLORS.rowDefaultBord))
        end
    end

    -- Внеочередной ход перекрывает остальные подсветки (не в фазе NPC)
    if hasFreeAction and not ctx.isNPCPhase then
        row:SetBackdropColor(unpack(COLORS.rowFreeAction))
        row:SetBackdropBorderColor(unpack(COLORS.rowFreeActBord))
    end

    -- ═══ ТАРГЕТ ПО КЛИКУ ═══
    if not InCombatLockdown() then
        local unitId = GetUnitIdByName(p.name)
        if unitId then
            row:SetAttribute("type", "target")
            row:SetAttribute("unit", unitId)
        else
            row:SetAttribute("type", nil)
            row:SetAttribute("unit", nil)
        end
    end

    -- ═══ ПОЛУЧЕНИЕ ДАННЫХ ИГРОКА ═══
    local hp, maxHp, shield, energy, maxEnergy, role, wounds, level = 0, 10, 0, 0, 2, nil, 0, 1

    if isMe then
        hp = DoF.Stats:GetCurrentHP()
        maxHp = DoF.Stats:GetMaxHP()
        shield = DoF.Stats:GetShield()
        energy = DoF.Stats:GetEnergy()
        maxEnergy = DoF.Stats:GetMaxEnergy()
        role = DoF.Stats:GetRole()
        wounds = DoF.Stats.GetWounds and DoF.Stats:GetWounds() or 0
        level = DoF.Stats.GetLevel and DoF.Stats:GetLevel() or 1
    else
        local pd = DoF.Sync.RaidData[p.name]
        if pd then
            hp = pd.hp or 0
            maxHp = pd.maxHp or 10
            shield = pd.shield or 0
            energy = pd.energy or 0
            maxEnergy = pd.maxEnergy or 2
            role = pd.role
            wounds = pd.wounds or 0
            level = pd.level or 1
        end
    end

    -- ═══ ИКОНКА РОЛИ ═══
    if role and ROLE_ICONS[role] then
        row.roleIcon:SetTexture(GetRoleIcon(role))
        row.roleIcon:Show()
    else
        row.roleIcon:Hide()
    end

    -- ═══ ИМЯ ═══
    local nameColor = isMe and COLORS.nameSelf or COLORS.nameOther
    row.nameText:SetText("|cFF" .. nameColor .. p.name .. "|r")

    -- ═══ УРОВЕНЬ ═══
    if level and level > 0 then
        row.levelText:SetText(DoF.Locale:Format("ui.queue.level_short", level))
        row.levelText:Show()
    else
        row.levelText:Hide()
    end

    -- ═══ ИНИЦИАТИВА ═══
    if ctx.isQueueMode and not ctx.isNPCPhase then
        row.rollText:SetText("[" .. p.roll .. "]")
        row.rollText:Show()
    else
        row.rollText:Hide()
    end

    -- ═══ СТАТУС БЕЙДЖ ═══
    if ctx.isNPCPhase then
        row.statusText:SetText("")
        row.statusBadge:SetBackdropColor(0, 0, 0, 0)
        row.statusBadge:SetBackdropBorderColor(0, 0, 0, 0)
    elseif hasFreeAction then
        row.statusText:SetText(DoF.L["ui.queue.extra_turn_short"])
        row.statusText:SetTextColor(1, 0.82, 0)
        row.statusBadge:SetBackdropColor(unpack(COLORS.statusFreeAct))
        row.statusBadge:SetBackdropBorderColor(unpack(COLORS.statusFABord))
    elseif p.acted then
        row.statusText:SetText("OK")
        row.statusText:SetTextColor(0.4, 1, 0.4)
        row.statusBadge:SetBackdropColor(unpack(COLORS.statusOK))
        row.statusBadge:SetBackdropBorderColor(unpack(COLORS.statusOKBord))
    elseif ctx.isQueueMode and isCurrent then
        row.statusText:SetText(">>")
        row.statusText:SetTextColor(1, 1, 0)
        row.statusBadge:SetBackdropColor(unpack(COLORS.statusCurrent))
        row.statusBadge:SetBackdropBorderColor(unpack(COLORS.statusCurBord))
    else
        row.statusText:SetText("")
        row.statusBadge:SetBackdropColor(0, 0, 0, 0)
        row.statusBadge:SetBackdropBorderColor(0, 0, 0, 0)
    end

    -- ═══ HP BAR ═══
    row.hpBar:SetMinMaxValues(0, maxHp)
    row.hpBar:SetValue(hp)

    local hpPercent = maxHp > 0 and (hp / maxHp) or 0
    row.hpBar:SetStatusBarTexture(GetHPTexture(hpPercent))

    row.hpText:SetText(hp .. "/" .. maxHp)

    -- Щит
    if shield > 0 then
        row.shieldBar:SetMinMaxValues(0, maxHp)
        row.shieldBar:SetValue(maxHp)
        row.shieldBar:Show()
        row.shieldText:SetText("+" .. shield)
        row.shieldText:Show()
    else
        row.shieldBar:Hide()
        row.shieldText:SetText("")
        row.shieldText:Hide()
    end

    -- Раны
    if wounds > 0 then
        row.woundIcon:Show()
        if wounds >= DoF.Config.MAX_WOUNDS then
            -- Критическое: вместо цифры показываем "!!!", ярко-красным
            row.woundText:SetText("!!!")
            row.woundText:SetTextColor(1, 0.1, 0.1)
            row.woundIcon:SetVertexColor(1, 0.3, 0.3)
        else
            row.woundText:SetText(wounds)
            row.woundText:SetTextColor(unpack(COLORS.woundText))
            row.woundIcon:SetVertexColor(1, 1, 1)
        end
        row.woundText:Show()
    else
        row.woundIcon:Hide()
        row.woundText:SetText("")
        row.woundText:Hide()
    end

    -- ═══ ЭНЕРГИЯ (StatusBar) ═══
    row.energyBar:SetMinMaxValues(0, maxEnergy)
    row.energyBar:SetValue(energy)
    row.energyText:SetText(energy .. "/" .. maxEnergy)

    -- ═══ ЭФФЕКТЫ ═══
    local effects = DoF.Effects:GetAll("player", p.name)
    local effectIndex = 1

    for effectId, effectData in pairs(effects) do
        if effectIndex <= MAX_EFFECTS then
            local icon = row.effectIcons[effectIndex]
            local def = DoF.Effects.Definitions[effectId]

            if def then
                icon:Show()
                icon.texture:SetTexture(def.icon)
                icon.effectId = effectId
                icon.effectData = effectData

                if def.type == "buff" then
                    icon:SetBackdropBorderColor(unpack(COLORS.effectBuff))
                elseif def.type == "debuff" or def.type == "dot" then
                    icon:SetBackdropBorderColor(unpack(COLORS.effectDebuff))
                else
                    icon:SetBackdropBorderColor(unpack(COLORS.effectNeutral))
                end

                if effectData.stacks and effectData.stacks > 1 then
                    icon.stacks:SetText(effectData.stacks)
                    icon.stacks:Show()
                else
                    icon.stacks:Hide()
                end

                effectIndex = effectIndex + 1
            end
        end
    end

    -- Скрываем неиспользуемые иконки
    for e = effectIndex, MAX_EFFECTS do
        row.effectIcons[e]:Hide()
    end

    -- ═══ КНОПКИ МАСТЕРА ═══
    if ctx.isMaster and not ctx.isNPCPhase then
        row.removeBtn:Show()
        row.removeBtn.playerName = p.name
    else
        row.removeBtn:Hide()
    end

    if not ctx.isQueueMode and ctx.isMaster and not p.acted and not ctx.isNPCPhase then
        row.skipBtn:Show()
        row.skipBtn.playerGUID = p.guid
    else
        row.skipBtn:Hide()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ ОКНА ОЧЕРЕДИ (ГЛАВНЫЙ ЦИКЛ)
-- ═══════════════════════════════════════════════════════════

function DoF.UI:UpdateTurnQueue()
    -- Обновляем кнопки смежных панелей
    if self.UpdateGMCombatButtons then
        self:UpdateGMCombatButtons()
    end
    if self.UpdateActionButtons then
        self:UpdateActionButtons()
    end

    local f = TurnQueueFrame
    if not f then return end

    local ts = DoF.TurnSystem
    if not ts then f:Hide() return end

    -- Скрываем если бой не активен
    if not ts:IsActive() then
        f:Hide()
        return
    end

    local isNPCPhase = (ts.phase == "npc")

    -- ═══ СВЁРНУТОЕ СОСТОЯНИЕ — обновляем трекер и индикатор ═══
    if f.isCollapsed then
        -- Обновляем индикатор на трекере
        local notActed = 0
        for _, p in ipairs(ts.participants) do
            if not p.acted then notActed = notActed + 1 end
        end
        DoF.UI:ShowTrackerCollapseIndicator(notActed, ts.phase)
        -- Трекер всё равно обновляем
        if DoF.UI.UpdateTrackerHeader then
            DoF.UI:UpdateTrackerHeader(ts.round, isNPCPhase, ts.mode)
        end
        return
    end

    -- ═══ ВИДИМОСТЬ ЭЛЕМЕНТОВ ПО ФАЗЕ ═══
    if isNPCPhase then
        f.scrollFrame:Show()
        f.listContainer:Show()

        f.footer:Hide()

    else

        f.scrollFrame:Show()
        f.listContainer:Show()
        f.footer:Show()

    end

    f.lastRound = ts.round

    -- ═══ ТРЕКЕР (раунд + фаза + режим + таймер — всё на TrackerHeader) ═══
    if DoF.UI.UpdateTrackerHeader then
        DoF.UI:UpdateTrackerHeader(ts.round, isNPCPhase, ts.mode)
    end

    -- Таймер → на трекер
    if ts.useTimer and not isNPCPhase then
        local remaining = ts.mode == "queue" and ts:GetTimeRemaining() or ts:GetRoundTimeRemaining()
        if DoF.UI.UpdateTrackerTimer then
            DoF.UI:UpdateTrackerTimer(remaining, ts.mode)
        end
    else
        if DoF.UI.UpdateTrackerTimer then
            DoF.UI:UpdateTrackerTimer(nil)
        end
    end

    -- Привязка listContainer — напрямую к верху рамки (таймер и header убраны)
    f.listContainer:ClearAllPoints()
    f.listContainer:SetPoint("TOPLEFT", BORDER_INSET_H, -BORDER_INSET)
    f.listContainer:SetPoint("TOPRIGHT", -BORDER_INSET_H, -BORDER_INSET)
    if isNPCPhase then
        f.listContainer:SetPoint("BOTTOM", 0, BORDER_INSET + 4)
    else
        f.listContainer:SetPoint("BOTTOM", 0, BORDER_INSET + FOOTER_HEIGHT + 4)
    end

    -- ═══ КОНТЕКСТ ДЛЯ СТРОК ═══
    local ctx = {
        isNPCPhase = isNPCPhase,
        isQueueMode = (ts.mode == "queue"),
        isMaster = DoF.Sync:IsMaster(),
        myGUID = UnitGUID("player"),
        myName = UnitName("player"),
        freeActionGUID = ts.freeActionGUID,
        currentIndex = ts.currentIndex,
        round = ts.round,
    }

    -- ═══ СОЗДАЁМ/ОБНОВЛЯЕМ СТРОКИ ═══
    -- Обновляем ширину content по реальной ширине scroll
    local scrollWidth = f.scrollFrame:GetWidth()
    if scrollWidth > 0 then
        f.content:SetWidth(scrollWidth)
    end

    local yOffset = 0
    local participantCount = #ts.participants

    for i, p in ipairs(ts.participants) do
        local row = f.rows[i]
        if not row then
            row = CreateParticipantRow(f.content, i)
            f.rows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 8, -yOffset)
        row:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -8, -yOffset)
        row:Show()

        UpdateParticipantRow(row, p, i, ctx)

        yOffset = yOffset + ROW_HEIGHT + 2
    end

    -- Скрываем лишние строки
    for i = participantCount + 1, #f.rows do
        f.rows[i]:Hide()
    end

    f.content:SetHeight(math_max(yOffset, 50))

    -- Скроллбар + динамический anchor скролла для центрирования
    local scroll = f.scrollFrame
    scroll:ClearAllPoints()
    if participantCount > 3 then
        f.scrollBar:Show()
        scroll:SetPoint("TOPLEFT", f.listContainer, "TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", f.listContainer, "BOTTOMRIGHT", -(4 + SCROLL_BAR_WIDTH + 2), 4)
    else
        f.scrollBar:Hide()
        scroll:SetPoint("TOPLEFT", f.listContainer, "TOPLEFT", 4, -4)
        scroll:SetPoint("BOTTOMRIGHT", f.listContainer, "BOTTOMRIGHT", -4, 4)
    end
    -- Пересчитываем ширину content после смены anchor
    local newScrollWidth = scroll:GetWidth()
    if newScrollWidth > 0 then
        f.content:SetWidth(newScrollWidth)
    end

    -- Фиксированная высота — авто-высота отключена
    f:SetSize(WINDOW_WIDTH, FIXED_HEIGHT)

    -- ═══ КНОПКИ ДЕЙСТВИЙ ═══
    local canAct = false
    local myGUID = ctx.myGUID

    if ctx.isQueueMode then
        canAct = ts:IsMyTurn()
        if ctx.isMaster and participantCount > 0 then
            canAct = true
        end
    else
        local myActed = false
        local isParticipant = false
        for _, participant in ipairs(ts.participants) do
            if participant.guid == myGUID then
                myActed = participant.acted
                isParticipant = true
                break
            end
        end
        canAct = (not myActed) and isParticipant
        if ctx.isMaster and participantCount > 0 then
            canAct = true
        end
    end

    -- Блокировка для оглушённых
    if canAct and DoF.Effects and DoF.Effects:IsStunned(UnitName("player")) then
        canAct = false
    end

    -- Блокировка при выборе крит-бонуса
    if canAct and DoF.Combat and DoF.Combat.CritChoicePending then
        canAct = false
    end

    if ts.phase == "players" then
        f.skipBtn:Show()
        if canAct then
            f.skipBtn:Enable()
            f.skipBtn:SetAlpha(1)
        else
            f.skipBtn:Disable()
            f.skipBtn:SetAlpha(0.5)
        end
    else
        f.skipBtn:Hide()
    end

    -- Кнопка добавления (мастер)
    if ctx.isMaster then
        f.addBtn:Show()
    else
        f.addBtn:Hide()
    end

    -- ═══ ПРОГРЕСС ═══
    if not isNPCPhase then
        local actedCount = 0
        for _, participant in ipairs(ts.participants) do
            if participant.acted then actedCount = actedCount + 1 end
        end

        if ctx.isQueueMode then
            local currentIdx = math_max(1, math_min(ts.currentIndex, participantCount))
            f.progressText:SetText(DoF.Locale:Format("ui.queue.turn_progress", currentIdx, participantCount))
        else
            f.progressText:SetText(DoF.Locale:Format("ui.queue.acted_progress", actedCount, participantCount))
        end
        f.progressText:Show()
    else
        f.progressText:Hide()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ ТАЙМЕРА
-- ═══════════════════════════════════════════════════════════

function DoF.UI:UpdateTurnTimer(remaining)
    -- Таймер теперь отображается на TrackerHeader
    local ts = DoF.TurnSystem
    if not ts or not ts.useTimer then
        if DoF.UI.UpdateTrackerTimer then
            DoF.UI:UpdateTrackerTimer(nil)
        end
        return
    end

    if DoF.UI.UpdateTrackerTimer then
        DoF.UI:UpdateTrackerTimer(remaining, ts.mode)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПОКАЗАТЬ / СКРЫТЬ / ПЕРЕКЛЮЧИТЬ
-- ═══════════════════════════════════════════════════════════

function DoF.UI:ShowTurnQueue()
    local f = CreateTurnQueueFrame()
    local tracker = _G["DoF_TrackerHeader"]
    f:ClearAllPoints()
    if tracker then
        f:SetPoint("TOP", tracker, "BOTTOM", 0, -6)
        f:SetWidth(WINDOW_WIDTH)
    else
        f:SetPoint("TOP", 0, -100)
        f:SetWidth(WINDOW_WIDTH)
    end
    -- Применить сохранённый масштаб очереди
    local savedScale = DoF.db and DoF.db.profile and DoF.db.profile.turnQueueScale or 1.0
    f:SetScale(savedScale)

    f:Show()
    self:UpdateTurnQueue()
end

function DoF.UI:HideTurnQueue()
    if TurnQueueFrame then
        TurnQueueFrame.isCollapsed = false
        TurnQueueFrame:Hide()
    end
    self:HideTrackerCollapseIndicator()
end

function DoF.UI:ToggleTurnQueue()
    local f = CreateTurnQueueFrame()
    if f:IsShown() or f.isCollapsed then
        f.isCollapsed = false
        f:Hide()
        self:HideTrackerCollapseIndicator()
    else
        f:Show()
        self:UpdateTurnQueue()
    end
end

-- Панели уведомлений (алерты, AoE, контратака, танк) — в UI/TurnQueue_Panels.lua
