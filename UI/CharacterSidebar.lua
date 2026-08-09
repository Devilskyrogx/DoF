-- DoF/UI/CharacterSidebar.lua
-- Добавление четвёртого таба "DiceOfFate" в боковую панель окна персонажа.

local ADDON_NAME, DoF = ...

DoF.UI = DoF.UI or {}
DoF.UI.CharacterSidebar = {}

local Module = DoF.UI.CharacterSidebar

-- Параметры таба
local TAB_NAME  = "DiceOfFate"
local TAB_ICON  = "Interface\\Icons\\inv_sword_2h_artifactashbringerpurified_d_02"
local PANE_NAME = "DoF_CharacterCustomPane"

-- Текстуры полосок (те же, что в UI/UnitFrames.lua и MainFrame.lua)
local HP_TEX_GREEN  = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_green"
local HP_TEX_YELLOW = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_yellow"
local HP_TEX_RED    = "Interface\\AddOns\\DoF\\texture\\bars\\Health_bar_red"
local ENERGY_TEX    = "Interface\\AddOns\\DoF\\texture\\bars\\Energy_bar"

-- Рамка для полосок: только edge, без bgFile. Фон рисуется отдельной BACKGROUND-
-- текстурой внутри самого StatusBar, а эта рамка — отдельный Frame ПОВЕРХ бара
-- (иначе bar texture перекроет рамку). Паттерн из OriginsSBS.
local BAR_BORDER = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
}

-- Описания, цвета и имена статов берём из единого источника UI/MainFrame.lua
-- (DoF.UI.StatConfig) — чтобы редактирование в одном месте влияло и сюда.

-- ═══════════════════════════════════════════════════════════
-- Переключатель языка
-- ═══════════════════════════════════════════════════════════

-- Показывает СОХРАНЁННЫЙ язык, а не активный: между нажатием и /reload аддон
-- ещё говорит на старом, но подпись должна подтверждать выбор пользователя.
function Module:UpdateLanguageButton()
    if not self.pane or not self.pane.langBtn then return end
    self.pane.langBtn.text:SetText(DoF.Locale:GetIn(DoF.Locale:GetSaved(), "locale.short"))
end

-- ═══════════════════════════════════════════════════════════
-- Создание пустой панели-контейнера
-- ═══════════════════════════════════════════════════════════

function Module:CreatePane()
    if _G[PANE_NAME] then
        self.pane = _G[PANE_NAME]
        return
    end
    -- Имя обязательно глобальное: Blizzard вызовет _G[frame]:Show/Hide из SetSidebar
    local pane = CreateFrame("Frame", PANE_NAME, PaperDollFrame)
    -- Те же отступы, что у Blizzard-ного CharacterStatsPane (3,-3 / -3,2 от InsetRight) —
    -- чтобы фон ложился ровно по рамке, а не прилипал к её бортику.
    pane:SetPoint("TOPLEFT", CharacterFrameInsetRight, "TOPLEFT", 3, -3)
    pane:SetPoint("BOTTOMRIGHT", CharacterFrameInsetRight, "BOTTOMRIGHT", -3, 2)
    pane:Hide()

    -- Классовый фон. Blizzard хранит эти текстуры в атласах вида
    -- UI-Character-Info-<CLASS>-BG, которые резолвятся в файлы
    -- Interface\PaperDollInfoFrame\PaperDollInfoPart1/2. SetAtlas сам выбирает
    -- нужный Part-файл и координаты.
    local bg = pane:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 0, 0)
    local _, class = UnitClass("player")
    if class then
        bg:SetAtlas("UI-Character-Info-" .. class .. "-BG", true)
    end
    pane.classBg = bg

    -- ScrollFrame занимает всю область pane — содержимое внутри обрезается по
    -- границам рамки и скроллится колесом мыши. Классовый фон (classBg) остаётся
    -- на pane, чтобы он НЕ скроллился вместе с контентом.
    local scrollFrame = CreateFrame("ScrollFrame", nil, pane)
    scrollFrame:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    scrollFrame:EnableMouseWheel(true)
    pane.scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(190, 600)  -- ширина = pane, высота подгоняется в конце под контент
    scrollFrame:SetScrollChild(scrollChild)
    pane.scrollChild = scrollChild

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local offset = self:GetVerticalScroll() - delta * 30
        if offset < 0 then offset = 0 end
        local maxScroll = scrollChild:GetHeight() - self:GetHeight()
        if maxScroll < 0 then maxScroll = 0 end
        if offset > maxScroll then offset = maxScroll end
        self:SetVerticalScroll(offset)
    end)

    -- Синхронизация ширины scrollChild с шириной ScrollFrame — чтобы контент
    -- занимал всю доступную ширину pane и центровка элементов работала корректно.
    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        if w and w > 0 then
            scrollChild:SetWidth(w)
        end
    end)

    -- Все дочерние элементы теперь принадлежат scrollChild.
    local content = scrollChild

    -- RP-имя сверху по центру (тот же шрифт и размер, что в главном меню DoF).
    local nameText = content:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(DoF.Config.FONT_TITLE, 16)
    nameText:SetPoint("TOP", content, "TOP", 0, -10)
    nameText:SetTextColor(1, 0.82, 0)
    pane.nameText = nameText

    -- Инфо-кнопка (правый верхний угол) — та же иконка и tooltip, что в главном
    -- окне аддона (UI/Frames.xml:315-335).
    local infoBtn = CreateFrame("Button", nil, content)
    infoBtn:SetSize(20, 20)
    infoBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -10)
    infoBtn:SetNormalTexture("Interface\\AddOns\\DoF\\texture\\informationicon")
    infoBtn:SetHighlightTexture("Interface\\AddOns\\DoF\\texture\\informationicon", "ADD")
    infoBtn:SetScript("OnEnter", function(self)
        if DoF.ShowAddonInfoTooltip then
            DoF:ShowAddonInfoTooltip(self)
        end
    end)
    infoBtn:SetScript("OnLeave", function()
        if DoF.Utils and DoF.Utils.HideTooltip then DoF.Utils:HideTooltip() end
    end)
    pane.infoBtn = infoBtn

    -- ─── Переключатель языка (под инфо-кнопкой) ────────────────
    -- Двухбуквенный код вместо иконки: флаг обозначал бы страну, а не язык,
    -- и для русского пришлось бы выбирать между несколькими странами.
    local langBtn = CreateFrame("Button", nil, content)
    langBtn:SetSize(22, 16)
    langBtn:SetPoint("TOPRIGHT", infoBtn, "BOTTOMRIGHT", 0, -4)

    langBtn.text = langBtn:CreateFontString(nil, "OVERLAY")
    langBtn.text:SetFont(DoF.Config.FONT, 11, "OUTLINE")
    langBtn.text:SetPoint("CENTER")
    langBtn.text:SetTextColor(0.7, 0.7, 0.7)

    langBtn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 0.82, 0)
        if DoF.Utils and DoF.Utils.ShowTooltip then
            DoF.Utils:ShowTooltip(self, {
                { DoF.Locale:Format("ui.sidebar.lang_tooltip",
                    DoF.Locale:GetIn(DoF.Locale:GetSaved(), "locale.name")), 1, 1, 1, 13 },
                { DoF.L["ui.sidebar.lang_hint"], 0.6, 0.6, 0.6, 11 },
            }, "LEFT")
        end
    end)
    langBtn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(0.7, 0.7, 0.7)
        if DoF.Utils and DoF.Utils.HideTooltip then DoF.Utils:HideTooltip() end
    end)

    -- Переключение идёт через DoF.Settings:SwitchLanguage — там же живёт запрос
    -- на /reload, общий с выпадающим списком в панели настроек.
    langBtn:SetScript("OnClick", function()
        if DoF.Settings and DoF.Settings.SwitchLanguage then
            DoF.Settings:SwitchLanguage(DoF.Locale:GetNext())
        end
    end)

    pane.langBtn = langBtn
    -- Подпись ставим здесь напрямую, а не через UpdateLanguageButton():
    -- self.pane присваивается только в конце CreatePane, и метод сейчас
    -- вышел бы вхолостую по своей же проверке.
    langBtn.text:SetText(DoF.Locale:GetIn(DoF.Locale:GetSaved(), "locale.short"))

    -- Портрет игрока с круглой маской (чтобы обрезаться в рамке).
    local portrait = content:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(58, 58)
    portrait:SetPoint("TOP", nameText, "BOTTOM", 0, -14)
    portrait:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    SetPortraitTexture(portrait, "player")
    pane.portrait = portrait

    -- Кольцо вокруг портрета (атлас Blizzard hud-PlayerFrame).
    local ring = content:CreateTexture(nil, "OVERLAY")
    ring:SetSize(72, 72)
    ring:SetAtlas("hud-PlayerFrame-portraitring-large", false)
    ring:SetPoint("CENTER", portrait, "CENTER", 0, 0)
    pane.ring = ring

    -- Маленькое кольцо для уровня — по центру снизу рамки.
    local levelRing = content:CreateTexture(nil, "OVERLAY", nil, 1)
    levelRing:SetSize(30, 30)
    levelRing:SetAtlas("hud-PlayerFrame-levelring", false)
    levelRing:SetPoint("CENTER", ring, "BOTTOM", 0, 2)
    pane.levelRing = levelRing

    -- Текст уровня (DoF-уровень, как в главном меню аддона).
    local levelText = content:CreateFontString(nil, "OVERLAY")
    levelText:SetFont(DoF.Config.FONT, 13, "OUTLINE")
    levelText:SetPoint("CENTER", levelRing, "CENTER", 0, 0)
    levelText:SetTextColor(1, 1, 1)
    pane.levelText = levelText

    -- ─── Кнопка «Меню ведущего» (слева снизу от портрета) ──────
    -- Иконка та же, что у GM-шестерёнки в главном окне (Frames.xml:456).
    -- Видна только мастеру или вне группы (соло-режим) — управляется UpdateGMButton.
    local gmBtn = CreateFrame("Button", nil, content)
    gmBtn:SetSize(24, 24)
    gmBtn:SetPoint("RIGHT", levelRing, "LEFT", -20, 0)
    -- Атлас Mobile-Engineering (Blizzard, доступен в 9.2.7).
    if gmBtn.SetNormalAtlas then
        gmBtn:SetNormalAtlas("worldquest-icon-engineering")
        gmBtn:SetHighlightAtlas("worldquest-icon-engineering")
    else
        local nt = gmBtn:CreateTexture(nil, "ARTWORK")
        nt:SetAllPoints()
        nt:SetAtlas("worldquest-icon-engineering")
        gmBtn:SetNormalTexture(nt)
        local ht = gmBtn:CreateTexture(nil, "HIGHLIGHT")
        ht:SetAllPoints()
        ht:SetAtlas("worldquest-icon-engineering")
        ht:SetBlendMode("ADD")
        gmBtn:SetHighlightTexture(ht)
    end
    gmBtn:SetScript("OnClick", function()
        if DoF.UI and DoF.UI.ToggleGMPanel then
            DoF.UI:ToggleGMPanel()
        end
    end)
    gmBtn:SetScript("OnEnter", function(self)
        if DoF.Utils and DoF.Utils.ShowTooltip then
            DoF.Utils:ShowTooltip(self, {
                { text = DoF.L["ui.sidebar.gm_menu"], r = 1, g = 0.82, b = 0, size = 14 },
                { text = DoF.L["ui.sidebar.gm_menu_hint"], r = 0.7, g = 0.7, b = 0.7 },
            }, "RIGHT")
        end
    end)
    gmBtn:SetScript("OnLeave", function()
        if DoF.Utils and DoF.Utils.HideTooltip then DoF.Utils:HideTooltip() end
    end)
    pane.gmBtn = gmBtn

    -- ─── Кнопка «Выбор роли» (справа снизу от портрета) ────────
    -- Иконка = текущая роль из Config.Roles[role].icon, либо "?" если роль не выбрана.
    local roleBtn = CreateFrame("Button", nil, content)
    roleBtn:SetSize(24, 24)
    roleBtn:SetPoint("LEFT", levelRing, "RIGHT", 20, 0)
    roleBtn:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    roleBtn:SetHighlightTexture("Interface\\Icons\\INV_Misc_QuestionMark", "ADD")
    roleBtn:SetScript("OnClick", function(self)
        if DoF.Dialogs and DoF.Dialogs.ShowSpecDialog then
            DoF.Dialogs:ShowSpecDialog(self)
        end
    end)
    roleBtn:SetScript("OnEnter", function(self)
        if DoF.UI and DoF.UI.ShowRoleTooltip then
            DoF.UI:ShowRoleTooltip(self)
        end
    end)
    roleBtn:SetScript("OnLeave", function()
        if DoF.Utils and DoF.Utils.HideTooltip then DoF.Utils:HideTooltip() end
    end)
    pane.roleBtn = roleBtn

    -- ─── Плашка-заголовок «Здоровье/Энергия» ───────────────────
    local titleBg = content:CreateTexture(nil, "ARTWORK")
    titleBg:SetAtlas("UI-Character-Info-Title", false)
    titleBg:SetSize(190, 30)
    titleBg:SetPoint("TOP", levelRing, "BOTTOM", 0, -8)
    pane.titleBg = titleBg

    local titleText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    titleText:SetText(DoF.L["ui.sidebar.health_energy"])
    pane.titleText = titleText

    -- ─── HP-полоска (тонкая, стиль OriginsSBS + трёхцветная логика DoF) ───
    local hpBar = CreateFrame("StatusBar", nil, content)
    hpBar:SetSize(174, 13)
    hpBar:SetPoint("TOP", titleBg, "BOTTOM", 0, -6)
    hpBar:SetStatusBarTexture(HP_TEX_GREEN)
    hpBar:SetStatusBarColor(1, 1, 1)
    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.067, 0.067, 0.067, 1)
    pane.hpBar = hpBar

    local hpBorder = CreateFrame("Frame", nil, hpBar, "BackdropTemplate")
    hpBorder:SetPoint("TOPLEFT", hpBar, "TOPLEFT", -3, 3)
    hpBorder:SetPoint("BOTTOMRIGHT", hpBar, "BOTTOMRIGHT", 3, -3)
    hpBorder:SetBackdrop(BAR_BORDER)
    hpBorder:SetBackdropBorderColor(0.8, 0.8, 0.9, 1)
    hpBorder:SetFrameLevel(hpBar:GetFrameLevel() + 5)
    pane.hpBorder = hpBorder

    local hpText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hpText:SetPoint("CENTER", 0, 0)
    hpText:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    hpText:SetTextColor(1, 1, 1)
    pane.hpText = hpText

    -- Shield overlay поверх hpBar (синий, alpha 0.6) + текст «Щит» справа.
    -- Ровно та же логика, что в главном окне (UI/MainFrame.lua:580-599).
    local shieldBar = CreateFrame("StatusBar", nil, hpBar)
    shieldBar:SetPoint("TOPLEFT", hpBar, "TOPLEFT", 2, -2)
    shieldBar:SetPoint("BOTTOMRIGHT", hpBar, "BOTTOMRIGHT", -2, 2)
    shieldBar:SetStatusBarTexture("Interface\\AddOns\\DoF\\texture\\bar_texture")
    shieldBar:SetStatusBarColor(0.3, 0.6, 0.9, 0.6)
    shieldBar:SetFrameLevel(hpBar:GetFrameLevel() + 2)
    shieldBar:Hide()
    pane.shieldBar = shieldBar

    local shieldText = hpBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    shieldText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    shieldText:SetPoint("RIGHT", hpBar, "RIGHT", -4, 0)
    shieldText:SetTextColor(0.5, 0.8, 1)
    shieldText:Hide()
    pane.shieldText = shieldText

    -- Бэйдж ран — слева на hpBar (иконка раны + число).
    -- Иконка texture\Wound.blp уже используется в главном окне.
    local woundsBadge = CreateFrame("Frame", nil, hpBar)
    woundsBadge:SetSize(28, 12)
    woundsBadge:SetPoint("LEFT", hpBar, "LEFT", 2, 0)
    woundsBadge:SetFrameLevel(hpBar:GetFrameLevel() + 5)
    woundsBadge:Hide()
    local woundIcon = woundsBadge:CreateTexture(nil, "OVERLAY")
    woundIcon:SetTexture("Interface\\AddOns\\DoF\\texture\\Wound")
    woundIcon:SetSize(11, 11)
    woundIcon:SetPoint("LEFT", woundsBadge, "LEFT", 0, 0)
    woundsBadge.icon = woundIcon
    local woundText = woundsBadge:CreateFontString(nil, "OVERLAY")
    woundText:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    woundText:SetPoint("LEFT", woundIcon, "RIGHT", 1, 0)
    woundText:SetTextColor(1, 0.5, 0.5)
    woundsBadge.text = woundText
    pane.woundsBadge = woundsBadge

    -- ─── Energy-полоска ────────────────────────────────────────
    local energyBar = CreateFrame("StatusBar", nil, content)
    energyBar:SetSize(174, 13)
    energyBar:SetPoint("TOP", hpBar, "BOTTOM", 0, -4)
    energyBar:SetStatusBarTexture(ENERGY_TEX)
    energyBar:SetStatusBarColor(1, 1, 1)
    local energyBg = energyBar:CreateTexture(nil, "BACKGROUND")
    energyBg:SetAllPoints()
    energyBg:SetColorTexture(0.067, 0.067, 0.067, 1)
    pane.energyBar = energyBar

    local energyBorder = CreateFrame("Frame", nil, energyBar, "BackdropTemplate")
    energyBorder:SetPoint("TOPLEFT", energyBar, "TOPLEFT", -3, 3)
    energyBorder:SetPoint("BOTTOMRIGHT", energyBar, "BOTTOMRIGHT", 3, -3)
    energyBorder:SetBackdrop(BAR_BORDER)
    energyBorder:SetBackdropBorderColor(0.8, 0.8, 0.9, 1)
    energyBorder:SetFrameLevel(energyBar:GetFrameLevel() + 5)
    pane.energyBorder = energyBorder

    local energyText = energyBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    energyText:SetPoint("CENTER", 0, 0)
    energyText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    energyText:SetTextColor(0.9, 0.9, 1)
    pane.energyText = energyText

    -- ─── XP/Level-бар (фиолетовый, под Energy) ─────────────────
    -- Информационная полоска: показывает игровой уровень от MIN_LEVEL до MAX_LEVEL
    -- + текст «Уровень N | M очков». Логика из UI/MainFrame.lua:511-528.
    local xpBar = CreateFrame("StatusBar", nil, content)
    xpBar:SetSize(174, 11)
    xpBar:SetPoint("TOP", energyBar, "BOTTOM", 0, -6)
    xpBar:SetStatusBarTexture("Interface\\AddOns\\DoF\\texture\\bar_texture")
    -- Стандартный фиолетовый XP-бара WoW (FrameXML/ExpBar.lua:25)
    xpBar:SetStatusBarColor(0.58, 0.0, 0.55)
    local xpBg = xpBar:CreateTexture(nil, "BACKGROUND")
    xpBg:SetAllPoints()
    xpBg:SetColorTexture(0.067, 0.067, 0.067, 1)
    pane.xpBar = xpBar

    local xpBorder = CreateFrame("Frame", nil, xpBar, "BackdropTemplate")
    xpBorder:SetPoint("TOPLEFT", xpBar, "TOPLEFT", -3, 3)
    xpBorder:SetPoint("BOTTOMRIGHT", xpBar, "BOTTOMRIGHT", 3, -3)
    xpBorder:SetBackdrop(BAR_BORDER)
    xpBorder:SetBackdropBorderColor(0.8, 0.8, 0.9, 1)
    xpBorder:SetFrameLevel(xpBar:GetFrameLevel() + 5)
    pane.xpBorder = xpBorder

    local xpText = xpBar:CreateFontString(nil, "OVERLAY")
    xpText:SetPoint("CENTER", 0, 0)
    xpText:SetFont(DoF.Config.FONT, 9, "OUTLINE")
    xpText:SetTextColor(1, 1, 1)
    pane.xpText = xpText

    -- ─── Плашка-заголовок «Характеристики» ─────────────────────
    local titleBg2 = content:CreateTexture(nil, "ARTWORK")
    titleBg2:SetAtlas("UI-Character-Info-Title", false)
    titleBg2:SetSize(190, 30)
    titleBg2:SetPoint("TOP", xpBar, "BOTTOM", 0, -10)
    pane.titleBg2 = titleBg2

    local titleText2 = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText2:SetPoint("CENTER", titleBg2, "CENTER", 0, 0)
    titleText2:SetText(DoF.L["ui.sidebar.stats"])
    pane.titleText2 = titleText2

    -- Бэйдж нераспределённых очков — отдельной строкой под заголовком «Характеристики».
    -- Когда показан — первая строка статов переякоривается к низу бэйджа
    -- (см. UpdatePointsBadge). Когда скрыт — статы прилегают к заголовку.
    local pointsBadge = CreateFrame("Frame", nil, content)
    pointsBadge:SetSize(160, 18)
    pointsBadge:SetPoint("TOP", titleBg2, "BOTTOM", 0, -2)
    pointsBadge:Hide()
    local pointsText = pointsBadge:CreateFontString(nil, "OVERLAY")
    pointsText:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    pointsText:SetPoint("CENTER", pointsBadge, "CENTER", 0, 0)
    pointsText:SetTextColor(1, 0.82, 0)
    pointsBadge.text = pointsText
    pane.pointsBadge = pointsBadge

    -- ─── Строки статов: Line-Bounce как полупрозрачный ФОН через одну ───
    pane.statRows = {}
    local stats = (DoF.Config and DoF.Config.AllStats) or {}
    local statNames = (DoF.Config and DoF.Config.StatNames) or {}
    local lastRow
    for i, stat in ipairs(stats) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(190, 20)
        if i == 1 then
            -- Якорь первой строки переключается в UpdatePointsBadge: при показанном
            -- бэйдже очков — к его нижней кромке; при скрытом — к низу заголовка.
            row:SetPoint("TOP", titleBg2, "BOTTOM", 0, -2)
            pane.firstStatRow = row
        else
            row:SetPoint("TOP", lastRow, "BOTTOM", 0, 0)
        end

        -- Через одну (на нечётных — 1, 3, 5, 7) — фоновая Line-Bounce полоска
        -- на слое BACKGROUND под label/value, alpha = 0.5.
        if i % 2 == 1 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAtlas("UI-Character-Info-Line-Bounce", false)
            bg:SetAllPoints(row)
            bg:SetAlpha(0.2)
            row.bg = bg
        end

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, "LEFT", 10, 0)
        label:SetText(statNames[stat] or stat)
        row.label = label

        local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.value = value

        -- +/- кнопки распределения. По умолчанию скрыты, показываются только когда
        -- есть очки/откатываемые staged-изменения (логика из UI/MainFrame.lua:285-301).
        -- Используем стандартные Blizzard-текстуры UI-PlusButton-* / UI-MinusButton-*
        -- (те же, что в QuestLog, AuctionHouse и т.п.).
        local addBtn = CreateFrame("Button", nil, row)
        addBtn:SetSize(16, 16)
        addBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        addBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP")
        addBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN")
        addBtn:SetDisabledTexture("Interface\\Buttons\\UI-PlusButton-DISABLED")
        addBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        addBtn:SetScript("OnClick", function()
            if DoF.Stats and DoF.Stats.StagedAdd then
                DoF.Stats:StagedAdd(stat)
                Module:UpdateStats()
                Module:UpdatePointsBadge()
                Module:UpdateXP()
                Module:UpdateDistributeBtn()
            end
        end)
        addBtn:Hide()
        row.addBtn = addBtn

        local subBtn = CreateFrame("Button", nil, row)
        subBtn:SetSize(16, 16)
        subBtn:SetPoint("RIGHT", addBtn, "LEFT", -1, 0)
        subBtn:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
        subBtn:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
        subBtn:SetDisabledTexture("Interface\\Buttons\\UI-MinusButton-DISABLED")
        -- У minus-кнопки Blizzard собственного Hilight-файла нет (в старых клиентах
        -- он зелёный/битый), поэтому используем общий UI-PlusButton-Hilight — тот же
        -- жёлтый highlight, что Blizzard применяет к обеим кнопкам в QuestLog/AH.
        subBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
        subBtn:SetScript("OnClick", function()
            if DoF.Stats and DoF.Stats.StagedRemove then
                DoF.Stats:StagedRemove(stat)
                Module:UpdateStats()
                Module:UpdatePointsBadge()
                Module:UpdateXP()
                Module:UpdateDistributeBtn()
            end
        end)
        subBtn:Hide()
        row.subBtn = subBtn

        -- Tooltip с описанием статa (паттерн из UI/MainFrame.lua:305-313),
        -- данные (label/color/desc) — из DoF.UI.StatConfig, как в главном меню.
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            local cfg = DoF.UI and DoF.UI.StatConfig and DoF.UI.StatConfig[stat]
            if not cfg or not DoF.Utils or not DoF.Utils.ShowTooltip then return end
            DoF.Utils:ShowTooltip(self, {
                { text = cfg.label, r = cfg.color[1], g = cfg.color[2], b = cfg.color[3], size = 14 },
                { text = cfg.desc or "", r = 1, g = 1, b = 1 },
            }, "RIGHT")
        end)
        row:SetScript("OnLeave", function()
            if DoF.Utils and DoF.Utils.HideTooltip then
                DoF.Utils:HideTooltip()
            end
        end)

        pane.statRows[stat] = row
        lastRow = row
    end

    -- ─── Кнопка «Распределить» (между статами и Урон/Исцеление) ─
    -- Видна только при наличии staged-изменений (логика из UI/MainFrame.lua:855-864).
    -- Стандартная Blizzard-кнопка UIPanelButtonTemplate (см. UI/Settings.lua).
    local distributeBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    distributeBtn:SetSize(120, 22)
    distributeBtn:SetPoint("TOP", lastRow or titleBg2, "BOTTOM", 0, -4)
    distributeBtn:SetText(DoF.L["ui.sidebar.distribute"])
    distributeBtn:SetScript("OnClick", function()
        if DoF.DistributeStats then
            DoF:DistributeStats()
            Module:UpdateStats()
            Module:UpdatePointsBadge()
            Module:UpdateXP()
            Module:UpdateDistributeBtn()
        end
    end)
    distributeBtn:Hide()
    pane.distributeBtn = distributeBtn

    -- ─── Плашка-заголовок «Урон/Исцеление» ─────────────────────
    local titleBg3 = content:CreateTexture(nil, "ARTWORK")
    titleBg3:SetAtlas("UI-Character-Info-Title", false)
    titleBg3:SetSize(190, 30)
    titleBg3:SetPoint("TOP", distributeBtn, "BOTTOM", 0, -4)
    pane.titleBg3 = titleBg3

    local titleText3 = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText3:SetPoint("CENTER", titleBg3, "CENTER", 0, 0)
    titleText3:SetText(DoF.L["ui.sidebar.damage_healing"])
    pane.titleText3 = titleText3

    -- ─── Строки Урон/Исцеление (тот же стиль, что строки статов) ───
    pane.dmgHealRows = {}
    local dmgHealItems = {
        { key = "damage",  label = DoF.L["ui.common.damage"] },
        { key = "healing", label = DoF.L["ui.common.healing"] },
    }
    local lastDhRow
    for i, item in ipairs(dmgHealItems) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(190, 20)
        if i == 1 then
            row:SetPoint("TOP", titleBg3, "BOTTOM", 0, -2)
        else
            row:SetPoint("TOP", lastDhRow, "BOTTOM", 0, 0)
        end

        -- Через одну — alpha 0.2 как и у статов
        if i % 2 == 1 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAtlas("UI-Character-Info-Line-Bounce", false)
            bg:SetAllPoints(row)
            bg:SetAlpha(0.2)
            row.bg = bg
        end

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, "LEFT", 10, 0)
        label:SetText(item.label)
        row.label = label

        local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.value = value

        pane.dmgHealRows[item.key] = row
        lastDhRow = row
    end

    -- Подогнать высоту scrollChild под фактический контент.
    -- Блоки: 10(top)+22(name)+14(gap)+72(portrait)+16+8+30(titleHP)+6+13(hp)+4+13(energy)+6+11(xp)+10+30(titleStats)+2+N*20(stats)+4+20(distribute)+4+30(titleDmg)+2+2*20(dmgheal)+8(bottom)
    -- Если бэйдж нераспр. очков виден — добавляется 20 px (см. _ApplyContentHeight).
    pane._statsCount = #stats
    self:_ApplyContentHeight()

    -- Обновляем данные при каждом показе панели —
    -- подхватывает смену RP-имени, уровня, смену модели игрока и т.п. без /reload.
    pane:SetScript("OnShow", function()
        Module:UpdateName()
        Module:UpdatePortrait()
        Module:UpdateLevel()
        Module:UpdateHP()
        Module:UpdateEnergy()
        Module:UpdateXP()
        Module:UpdateWounds()
        Module:UpdateShield()
        Module:UpdatePointsBadge()
        Module:UpdateStats()
        Module:UpdateDamageHealing()
        Module:UpdateRoleButton()
        Module:UpdateGMButton()
        Module:UpdateDistributeBtn()
    end)

    self.pane = pane
end

-- ═══════════════════════════════════════════════════════════
-- Обновление RP-имени (та же логика, что в UI/MainFrame.lua:491-506)
-- ═══════════════════════════════════════════════════════════

function Module:UpdateName()
    if not self.pane or not self.pane.nameText then return end

    local name = UnitName("player")
    if TRP3_API and TRP3_API.profile and TRP3_API.profile.getData then
        local ok, data = pcall(TRP3_API.profile.getData, "player/characteristics")
        if ok and data then
            local fn = data.FN
            local ln = data.LN
            if fn and fn ~= "" then
                name = ln and ln ~= "" and (fn .. " " .. ln) or fn
            end
        end
    end
    self.pane.nameText:SetText(name)
end

-- ═══════════════════════════════════════════════════════════
-- Обновление портрета и уровня
-- ═══════════════════════════════════════════════════════════

function Module:UpdatePortrait()
    if self.pane and self.pane.portrait then
        SetPortraitTexture(self.pane.portrait, "player")
    end
end

function Module:UpdateLevel()
    if not self.pane or not self.pane.levelText then return end
    -- Фолбэка на UnitLevel здесь быть не должно: игровой уровень зафиксирован
    -- на 60, и подстановка молча показала бы чужое число вместо уровня DoF.
    local level = (DoF.Stats and DoF.Stats.GetLevel)
        and DoF.Stats:GetLevel()
        or DoF.Config.MIN_LEVEL
    self.pane.levelText:SetText(level)
end

-- ═══════════════════════════════════════════════════════════
-- Обновление HP/Energy (трёхцветная HP-логика из UI/MainFrame.lua:555-570)
-- ═══════════════════════════════════════════════════════════

function Module:UpdateHP()
    if not self.pane or not self.pane.hpBar then return end
    if not (DoF.Stats and DoF.Stats.GetCurrentHP and DoF.Stats.GetMaxHP) then return end
    local cur = DoF.Stats:GetCurrentHP() or 0
    local max = DoF.Stats:GetMaxHP() or 1
    if max < 1 then max = 1 end
    self.pane.hpBar:SetMinMaxValues(0, max)
    self.pane.hpBar:SetValue(cur)
    local pct = cur / max
    local tex = HP_TEX_GREEN
    if pct <= 0.25 then
        tex = HP_TEX_RED
    elseif pct <= 0.5 then
        tex = HP_TEX_YELLOW
    end
    self.pane.hpBar:SetStatusBarTexture(tex)
    if self.pane.hpText then
        self.pane.hpText:SetText(cur .. " / " .. max)
    end
end

function Module:UpdateEnergy()
    if not self.pane or not self.pane.energyBar then return end
    if not (DoF.Stats and DoF.Stats.GetEnergy and DoF.Stats.GetMaxEnergy) then return end
    local cur = DoF.Stats:GetEnergy() or 0
    local max = DoF.Stats:GetMaxEnergy() or 1
    if max < 1 then max = 1 end
    self.pane.energyBar:SetMinMaxValues(0, max)
    self.pane.energyBar:SetValue(cur)
    if self.pane.energyText then
        self.pane.energyText:SetText(cur .. " / " .. max)
    end
end

function Module:UpdateStats()
    if not self.pane or not self.pane.statRows then return end
    if not (DoF.Stats and DoF.Stats.GetTotal and DoF.Config and DoF.Config.AllStats) then return end
    local playerName = UnitName("player")
    local hasPending = DoF.Stats.HasPendingChanges and DoF.Stats:HasPendingChanges()
    local pointsLeft = hasPending and DoF.Stats:GetStagedPointsLeft() or DoF.Stats:GetPointsLeft()
    local maxStat = DoF.Stats.GetMaxStat and DoF.Stats:GetMaxStat() or 30
    local woundPenalty = DoF.Stats.GetWoundPenalty and DoF.Stats:GetWoundPenalty() or 0

    for _, stat in ipairs(DoF.Config.AllStats) do
        local row = self.pane.statRows[stat]
        if row and row.value then
            local base = DoF.Stats:Get(stat)
            local stagedValue = DoF.Stats.GetStagedValue and DoF.Stats:GetStagedValue(stat) or base
            local stagedDelta = DoF.Stats.GetStagedDelta and DoF.Stats:GetStagedDelta(stat) or 0
            local displayBase = hasPending and stagedValue or base

            -- Total с учётом staged + ран + эффектов (логика из UI/MainFrame.lua:769-781)
            local effectMod = 0
            if DoF.Effects and DoF.Effects.GetModifier then
                effectMod = DoF.Effects:GetModifier("player", playerName, string.lower(stat))
            end
            local total
            if hasPending then
                total = math.min(stagedValue + woundPenalty + effectMod, DoF.Config.MAX_STAT_TOTAL)
            else
                total = DoF.Stats:GetTotal(stat)
            end

            local buffPlus, debuffMinus = 0, 0
            if DoF.Effects and DoF.Effects.GetModifierSplit then
                buffPlus, debuffMinus = DoF.Effects:GetModifierSplit("player", playerName, string.lower(stat))
            end

            -- Базовое число с подсветкой staged жёлтым/красным.
            local baseStr = tostring(displayBase)
            if stagedDelta > 0 then
                baseStr = "|cFFFFD700" .. displayBase .. "|r"
            elseif stagedDelta < 0 then
                baseStr = "|cFFFF6666" .. displayBase .. "|r"
            end

            local text = baseStr
            local hasMods = woundPenalty < 0 or buffPlus > 0 or debuffMinus > 0
            if hasMods then
                if woundPenalty < 0 then
                    text = text .. "|cFFFF6666" .. woundPenalty .. "|r"
                end
                if buffPlus > 0 then
                    text = text .. "|cFF33FF66+" .. buffPlus .. "|r"
                end
                if debuffMinus > 0 then
                    text = text .. "|cFFFF6666-" .. debuffMinus .. "|r"
                end
                text = text .. "=" .. total
            end
            row.value:SetText(text)

            -- +/- кнопки: AddBtn виден если есть очки и стат не на максимуме;
            -- SubBtn виден только если есть staged-прирост.
            if row.addBtn then
                if displayBase < maxStat and pointsLeft > 0 then
                    row.addBtn:Show(); row.addBtn:Enable()
                else
                    row.addBtn:Hide()
                end
            end
            if row.subBtn then
                if stagedDelta > 0 then
                    row.subBtn:Show(); row.subBtn:Enable()
                else
                    row.subBtn:Hide()
                end
            end

            -- Сдвиг value влево если хотя бы одна кнопка видна.
            local btnVisible = (row.addBtn and row.addBtn:IsShown()) or (row.subBtn and row.subBtn:IsShown())
            row.value:ClearAllPoints()
            if btnVisible then
                row.value:SetPoint("RIGHT", row, "RIGHT", -38, 0)
            else
                row.value:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            end
        end
    end
end

-- Урон/Исцеление: та же логика, что в UI/MainFrame.lua:651-687.
-- Диапазон берётся из Config:GetDamage/HealingRange(level, role), плюс
-- модификаторы баффов/дебаффов через Effects:GetModifier.
function Module:UpdateDamageHealing()
    if not self.pane or not self.pane.dmgHealRows then return end
    if not (DoF.Stats and DoF.Config and DoF.Config.GetDamageRange and DoF.Config.GetHealingRange) then
        return
    end
    local level = DoF.Stats:GetLevel() or 1
    local role  = DoF.Stats:GetRole()
    local dmg   = DoF.Config:GetDamageRange(level, role)
    local heal  = DoF.Config:GetHealingRange(level, role)

    local dmgMod, healMod = 0, 0
    if DoF.Effects and DoF.Effects.GetModifier then
        local playerName = UnitName("player")
        dmgMod  = DoF.Effects:GetModifier("player", playerName, "damage")  or 0
        healMod = DoF.Effects:GetModifier("player", playerName, "healing") or 0
    end

    local dmgMin  = (dmg.min  or 1) + dmgMod
    local dmgMax  = (dmg.max  or 1) + dmgMod
    local healMin = math.max(1, (heal.min or 1) + healMod)
    local healMax = math.max(1, (heal.max or 1) + healMod)

    local dmgRow = self.pane.dmgHealRows.damage
    if dmgRow and dmgRow.value then
        local text = dmgMin .. "-" .. dmgMax
        if dmgMod ~= 0 then
            text = text .. " |cFF33FF66(" .. (dmgMod > 0 and "+" or "") .. dmgMod .. ")|r"
        end
        dmgRow.value:SetText(text)
    end
    local healRow = self.pane.dmgHealRows.healing
    if healRow and healRow.value then
        local text = healMin .. "-" .. healMax
        if healMod ~= 0 then
            text = text .. " |cFF33FF66(" .. (healMod > 0 and "+" or "") .. healMod .. ")|r"
        end
        healRow.value:SetText(text)
    end
end

-- ═══════════════════════════════════════════════════════════
-- XP/уровень, бэйдж очков, раны, щит, кнопка «Распределить»
-- ═══════════════════════════════════════════════════════════

function Module:UpdateXP()
    if not self.pane or not self.pane.xpBar then return end
    if not (DoF.Config and DoF.Stats) then return end
    local level = (DoF.Stats.GetLevel and DoF.Stats:GetLevel()) or DoF.Config.MIN_LEVEL
    local pointsLeft = DoF.Stats.GetPointsLeft and DoF.Stats:GetPointsLeft() or 0
    local minL, maxL = DoF.Config.MIN_LEVEL or 1, DoF.Config.MAX_LEVEL or 60
    self.pane.xpBar:SetMinMaxValues(minL, maxL)
    self.pane.xpBar:SetValue(level)
    if level >= maxL then
        self.pane.xpBar:SetStatusBarColor(1.0, 0.8, 0.3)
        self.pane.xpText:SetText(DoF.Locale:Format("ui.sidebar.max_level", level))
    else
        -- Стандартный фиолетовый XP-бара WoW (FrameXML/ExpBar.lua:25)
        self.pane.xpBar:SetStatusBarColor(0.58, 0.0, 0.55)
        if pointsLeft > 0 then
            self.pane.xpText:SetText(DoF.Locale:Format("ui.sidebar.level_points", level, pointsLeft,
                DoF.Locale:Plural(pointsLeft, DoF.L["ui.sidebar.points_one"],
                    DoF.L["ui.sidebar.points_few"], DoF.L["ui.sidebar.points_many"])))
        else
            self.pane.xpText:SetText(DoF.Locale:Format("ui.sidebar.level", level))
        end
    end
end

-- Пересчёт высоты scrollChild. Когда бэйдж очков виден — +20 px, чтобы
-- сдвинутые вниз строки статов не уехали за нижнюю кромку pane.
function Module:_ApplyContentHeight()
    if not self.pane or not self.pane.scrollChild then return end
    local n = self.pane._statsCount or 7
    local base = 10 + 22 + 14 + 72 + 16 + 8 + 30 + 6 + 13 + 4 + 13 + 6 + 11 + 10 + 30 + 2
               + (n * 20) + 4 + 22 + 4 + 30 + 2 + (2 * 20) + 8
    local extra = (self.pane.pointsBadge and self.pane.pointsBadge:IsShown()) and 20 or 0
    self.pane.scrollChild:SetHeight(base + extra)
end

function Module:UpdatePointsBadge()
    if not self.pane or not self.pane.pointsBadge then return end
    if not DoF.Stats then return end
    local hasPending = DoF.Stats.HasPendingChanges and DoF.Stats:HasPendingChanges()
    local left = hasPending and DoF.Stats:GetStagedPointsLeft() or DoF.Stats:GetPointsLeft()
    local badge = self.pane.pointsBadge
    if left and left > 0 then
        badge.text:SetText(DoF.Locale:Format("ui.sidebar.points_badge", left,
            DoF.Locale:Plural(left, DoF.L["ui.sidebar.points_one"],
                DoF.L["ui.sidebar.points_few"], DoF.L["ui.sidebar.points_many"])))
        badge:Show()
    else
        badge:Hide()
    end
    -- Переякорить первую строку статов: при показанном бэйдже — под него,
    -- при скрытом — прилепить обратно под заголовок.
    local firstRow = self.pane.firstStatRow
    local titleBg2 = self.pane.titleBg2
    if firstRow and titleBg2 then
        firstRow:ClearAllPoints()
        if badge:IsShown() then
            firstRow:SetPoint("TOP", badge, "BOTTOM", 0, -2)
        else
            firstRow:SetPoint("TOP", titleBg2, "BOTTOM", 0, -2)
        end
    end
    self:_ApplyContentHeight()
end

function Module:UpdateWounds()
    if not self.pane or not self.pane.woundsBadge then return end
    local wounds = DoF.Stats and DoF.Stats.GetWounds and DoF.Stats:GetWounds() or 0
    if wounds > 0 then
        self.pane.woundsBadge.text:SetText(wounds)
        self.pane.woundsBadge:Show()
    else
        self.pane.woundsBadge:Hide()
    end
end

function Module:UpdateShield()
    if not self.pane or not self.pane.shieldBar then return end
    local shield = DoF.Stats and DoF.Stats.GetShield and DoF.Stats:GetShield() or 0
    if shield > 0 then
        self.pane.shieldBar:SetMinMaxValues(0, 1)
        self.pane.shieldBar:SetValue(1)
        self.pane.shieldBar:Show()
        self.pane.shieldText:SetText(DoF.L["ui.common.shield"])
        self.pane.shieldText:Show()
    else
        self.pane.shieldBar:Hide()
        self.pane.shieldText:Hide()
    end
end

function Module:UpdateDistributeBtn()
    if not self.pane or not self.pane.distributeBtn then return end
    local hasPending = DoF.Stats and DoF.Stats.HasPendingChanges and DoF.Stats:HasPendingChanges()
    self.pane.distributeBtn:SetShown(hasPending and true or false)
end

-- ═══════════════════════════════════════════════════════════
-- Обновление кнопок роли и меню ведущего
-- ═══════════════════════════════════════════════════════════

-- Иконка роли = текущая роль игрока (из Config.Roles[role].icon).
-- Если роль не выбрана — "?". Если уровня недостаточно — серый "?" + кнопка отключена.
function Module:UpdateRoleButton()
    if not self.pane or not self.pane.roleBtn then return end
    local btn = self.pane.roleBtn
    local role = DoF.Stats and DoF.Stats:GetRole()
    local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
    if role and DoF.Config and DoF.Config.Roles and DoF.Config.Roles[role] then
        icon = DoF.Config.Roles[role].icon or icon
    end
    btn:SetNormalTexture(icon)
    btn:SetHighlightTexture(icon, "ADD")

    local canChoose = DoF.Stats and DoF.Stats:CanChooseRole()
    if role or canChoose then
        btn:Enable()
        local nt = btn:GetNormalTexture()
        if nt then nt:SetDesaturated(false) end
    else
        btn:Disable()
        local nt = btn:GetNormalTexture()
        if nt then nt:SetDesaturated(true) end
    end
end

-- Кнопка меню ведущего видна только мастеру или вне группы (соло-режим) —
-- та же логика, что у GM-шестерёнки в главном окне (UI/MainFrame.lua:357).
function Module:UpdateGMButton()
    if not self.pane or not self.pane.gmBtn then return end
    local canShow = not IsInGroup() or (DoF.Sync and DoF.Sync:IsMaster())
    self.pane.gmBtn:SetShown(canShow and true or false)
end

-- ═══════════════════════════════════════════════════════════
-- Регистрация записи в PAPERDOLL_SIDEBARS
-- ═══════════════════════════════════════════════════════════

function Module:RegisterSidebar()
    -- Idempotency: если уже добавлена, возвращаем её индекс (после /reload tinsert
    -- не выполнялся, но таблица PAPERDOLL_SIDEBARS создаётся заново — scan-guard
    -- не навредит, а защитит от случайного повторного вызова Init).
    for i, entry in ipairs(PAPERDOLL_SIDEBARS) do
        if entry.frame == PANE_NAME then
            return i
        end
    end

    tinsert(PAPERDOLL_SIDEBARS, {
        name            = TAB_NAME,
        frame           = PANE_NAME,
        icon            = TAB_ICON,
        texCoords       = { 0, 1, 0, 1 },
        disabledTooltip = nil,
        IsActive        = function() return true end,
    })
    return #PAPERDOLL_SIDEBARS
end

-- ═══════════════════════════════════════════════════════════
-- Создание кнопки-таба
-- ═══════════════════════════════════════════════════════════

function Module:CreateTab(index)
    local tabName = "PaperDollSidebarTab" .. index

    -- Idempotency: если кнопка уже существует (после /reload template сам её
    -- пересоздать не может, но другой аддон мог занять имя)
    if _G[tabName] then
        self.tab = _G[tabName]
        return
    end

    -- Пятый аргумент CreateFrame задаёт :GetID() ДО вызова OnLoad шаблона.
    -- Это критично: OnLoad шаблона читает PAPERDOLL_SIDEBARS[self:GetID()].icon
    -- без nil-check — без id=index получим обращение к PAPERDOLL_SIDEBARS[0] = nil.
    local tab = CreateFrame(
        "Button",
        tabName,
        PaperDollSidebarTabs,
        "PaperDollSidebarTabTemplate",
        index
    )

    -- Defensive повтор: если по какой-то причине пятый аргумент не сработал
    -- в текущем клиенте, принудительно ставим id и иконку ещё раз (идемпотентно).
    tab:SetID(index)
    if tab.Icon then
        tab.Icon:SetTexture(TAB_ICON)
        tab.Icon:SetTexCoord(0, 1, 0, 1)
    end

    -- Golden glow для активного состояния. Используем тот же файл и texCoords,
    -- что Blizzard использует для hover-Highlight табов (из PaperDollFrame.xml):
    --   file="Interface\PaperDollInfoFrame\PaperDollSidebarTabs"
    --   TexCoords(0.0156, 0.5, 0.1953, 0.3164)   Size(31x31)   Anchor(TOPLEFT 2,-3)
    -- Blizzard показывает Highlight только при hover (layer HIGHLIGHT). Мы кладём
    -- копию на OVERLAY и включаем её постоянно для активного таба — визуал 1-в-1.
    local glow = tab:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs")
    glow:SetTexCoord(0.01562500, 0.50000000, 0.19531250, 0.31640625)
    glow:SetSize(31, 31)
    glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -3)
    glow:Hide()
    tab.selectedGlow = glow

    self.tab = tab
end

-- ═══════════════════════════════════════════════════════════
-- Переякорение кнопок: наш таб справа, Tab3 сдвигается влево
-- ═══════════════════════════════════════════════════════════

function Module:ReanchorTabs(index)
    if not self.tab then return end

    self.tab:ClearAllPoints()

    -- Геометрия: PaperDollSidebarTabs = 168px, 4 кнопки = 4*33 + 3*4 = 144px,
    -- свободных 24px => по 12px с каждой стороны для центрирования группы.
    -- (У Blizzard с 3 кнопками было offset=-30; с 4 кнопками это бы выдавило
    -- Tab1 за левую границу, поэтому пересчитываем.)
    local RIGHT_OFFSET = -12

    if index == 4 then
        -- Обычный случай: мы занимаем правое место, Tab3 сдвигается влево
        self.tab:SetPoint("BOTTOMRIGHT", PaperDollSidebarTabs, "BOTTOMRIGHT", RIGHT_OFFSET, 0)
        if PaperDollSidebarTab3 then
            PaperDollSidebarTab3:ClearAllPoints()
            PaperDollSidebarTab3:SetPoint("RIGHT", self.tab, "LEFT", -4, 0)
        end
        -- Tab2/Tab1 заякорены цепочкой относительно Tab3 — сдвинутся сами
    else
        -- Если другой аддон уже вставил свой таб раньше нас (index > 4),
        -- правое место занято — якоримся слева от предыдущей кнопки
        local prev = _G["PaperDollSidebarTab" .. (index - 1)]
        if prev then
            self.tab:SetPoint("RIGHT", prev, "LEFT", -4, 0)
        else
            -- На всякий случай: если предыдущей нет — ставим правее
            self.tab:SetPoint("BOTTOMRIGHT", PaperDollSidebarTabs, "BOTTOMRIGHT", RIGHT_OFFSET, 0)
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- Публичные геттеры (для будущих этапов)
-- ═══════════════════════════════════════════════════════════

function Module:GetPane()
    return self.pane
end

function Module:GetTab()
    return self.tab
end

-- ═══════════════════════════════════════════════════════════
-- Точка входа
-- ═══════════════════════════════════════════════════════════

function Module:Init()
    if self._initialized then return end

    -- В 9.2.7 PaperDollSidebarTabs существует к моменту OnEnable, но страхуемся
    if not _G.PaperDollSidebarTabs or not _G.CharacterFrameInsetRight then
        if DoF.Utils and DoF.Utils.Warn then
            DoF.Utils:Warn(DoF.L["errors.sidebar_paperdoll_missing"])
        end
        return
    end

    -- Порядок критичен:
    -- 1. Панель — потому что SetSidebar делает _G[frame]:Hide/Show
    -- 2. Запись в PAPERDOLL_SIDEBARS — потому что OnLoad шаблона читает её по id
    -- 3. Кнопка — с 5-м аргументом id
    -- 4. Якоря
    -- 5. Обновление визуального состояния табов
    self:CreatePane()
    local myIndex = self:RegisterSidebar()
    self.tabIndex = myIndex  -- используется DoF.UI:ToggleCharacterSidebar (LMB миникарты / /dof)
    self:CreateTab(myIndex)
    self:ReanchorTabs(myIndex)

    if PaperDollFrame_UpdateSidebarTabs then
        PaperDollFrame_UpdateSidebarTabs()
    end

    -- Переключаем golden glow Tab4 в зависимости от того, активна ли наша панель.
    if not self._glowHookInstalled then
        hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
            if Module.tab and Module.tab.selectedGlow and Module.pane then
                Module.tab.selectedGlow:SetShown(Module.pane:IsShown())
            end
        end)
        self._glowHookInstalled = true
    end
    -- Синхронизируем состояние прямо сейчас
    if self.tab and self.tab.selectedGlow and self.pane then
        self.tab.selectedGlow:SetShown(self.pane:IsShown())
    end

    -- Подписка на внутренние события DoF — обновляем полоски и статы немедленно
    -- при изменениях, даже если панель сейчас скрыта (безопасно).
    if not self._eventsRegistered and DoF.Events and DoF.Events.Register then
        DoF.Events:Register("PLAYER_HP_CHANGED", function()
            Module:UpdateHP()
        end, "CharacterSidebar_HP")
        DoF.Events:Register("PLAYER_ENERGY_CHANGED", function()
            Module:UpdateEnergy()
        end, "CharacterSidebar_Energy")
        DoF.Events:Register("PLAYER_STATS_CHANGED", function()
            Module:UpdateStats()
            Module:UpdateDamageHealing()
            Module:UpdatePointsBadge()
            Module:UpdateXP()
            Module:UpdateDistributeBtn()
        end, "CharacterSidebar_Stats")
        DoF.Events:Register("PLAYER_WOUND_CHANGED", function()
            Module:UpdateWounds()
            Module:UpdateStats()
        end, "CharacterSidebar_Wounds")
        DoF.Events:Register("PLAYER_SHIELD_CHANGED", function()
            Module:UpdateShield()
        end, "CharacterSidebar_Shield")
        DoF.Events:Register("EFFECT_APPLIED", function()
            Module:UpdateStats()
            Module:UpdateDamageHealing()
        end, "CharacterSidebar_EffectsApplied")
        DoF.Events:Register("EFFECT_REMOVED", function()
            Module:UpdateStats()
            Module:UpdateDamageHealing()
        end, "CharacterSidebar_EffectsRemoved")
        DoF.Events:Register("PLAYER_SPEC_CHANGED", function()
            Module:UpdateRoleButton()
        end, "CharacterSidebar_Role")
        DoF.Events:Register("PLAYER_LEVEL_CHANGED", function()
            Module:UpdateLevel()
            Module:UpdateRoleButton()
            Module:UpdateXP()
            Module:UpdatePointsBadge()
            Module:UpdateStats()
        end, "CharacterSidebar_Level")
        DoF.Events:Register("MASTER_CHANGED", function()
            Module:UpdateGMButton()
        end, "CharacterSidebar_Master")
        self._eventsRegistered = true
    end

    self._initialized = true
end
