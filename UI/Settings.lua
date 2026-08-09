-- DoF/UI/Settings.lua
-- Панель настроек аддона в игровом меню (Интерфейс -> Модификации)

local ADDON_NAME, DoF = ...

-- ═══════════════════════════════════════════════════════════
-- ПЕРЕМЕННЫЕ НАСТРОЕК
-- ═══════════════════════════════════════════════════════════

DoF.Settings = DoF.Settings or {}

-- Настройки по умолчанию
local defaults = {
    combatLogEnabled = true, -- Включен ли журнал боя (true = только журнал, false = только чат)
    uiScale = 1.0, -- Масштаб главного окна (0.5 - 2.0)
    statsCollapsed = false, -- Свёрнута ли панель характеристик
}

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ НАСТРОЕК
-- ═══════════════════════════════════════════════════════════

function DoF.Settings:Init()
    -- Инициализируем SavedVariables если их нет
    if not DoF_DB then
        DoF_DB = {}
    end
    if not DoF_DB.settings then
        DoF_DB.settings = {}
    end

    -- Применяем значения по умолчанию для отсутствующих настроек
    for key, value in pairs(defaults) do
        if DoF_DB.settings[key] == nil then
            DoF_DB.settings[key] = value
        end
    end
end

-- Получить значение настройки
function DoF.Settings:Get(key)
    if not DoF_DB or not DoF_DB.settings then
        return defaults[key]
    end
    local value = DoF_DB.settings[key]
    if value == nil then
        return defaults[key]
    end
    return value
end

-- Установить значение настройки
function DoF.Settings:Set(key, value)
    if not DoF_DB then
        DoF_DB = {}
    end
    if not DoF_DB.settings then
        DoF_DB.settings = {}
    end
    DoF_DB.settings[key] = value

    -- Применяем изменения
    if key == "combatLogEnabled" then
        self:ApplyCombatLogSetting()
    elseif key == "uiScale" then
        self:ApplyUIScale()
    end
end

-- Применить настройку журнала боя
function DoF.Settings:ApplyCombatLogSetting()
    local enabled = self:Get("combatLogEnabled")

    -- Если журнал выключен, скрываем его окно
    if not enabled then
        if DoF.CombatLog and DoF.CombatLog.Frame and DoF.CombatLog.Frame:IsShown() then
            DoF.CombatLog.Frame:Hide()
        end
    end
end

-- Применить настройку масштаба UI
function DoF.Settings:ApplyUIScale()
    -- Главное окно DoF_MainFrame удалено; масштабирование других панелей аддона
    -- теперь делает Utils:ApplyUIScale (см. Core/Utils.lua). Этот метод оставлен
    -- как точка вызова из внешнего кода (Settings-панель, Init) — без тела.
end

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ ПАНЕЛИ НАСТРОЕК
-- ═══════════════════════════════════════════════════════════

local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "DoF_SettingsPanel")
    panel.name = "DoF"

    -- Заголовок
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cFFFFA500DoF - Dice of Fate|r")

    -- Версия
    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    version:SetText(DoF.Locale:Format("ui.opt.version", DoF.Config.VERSION))

    -- Описание
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -16)
    desc:SetText(DoF.L["ui.opt.desc"])
    desc:SetWidth(500)
    desc:SetJustifyH("LEFT")

    -- ═══════════════════════════════════════════════════════════
    -- ЯЗЫК АДДОНА
    -- ═══════════════════════════════════════════════════════════

    local langHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    langHeader:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -24)
    langHeader:SetText(DoF.L["ui.opt.lang_header"])

    local langLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    langLabel:SetPoint("TOPLEFT", langHeader, "BOTTOMLEFT", 4, -10)
    langLabel:SetText(DoF.L["ui.opt.lang_label"])

    local langDropdown = CreateFrame("Frame", "DoF_Settings_LanguageDropdown", panel, "UIDropDownMenuTemplate")
    langDropdown:SetPoint("TOPLEFT", langLabel, "BOTTOMLEFT", -16, -4)

    -- Название языка показываем на нём самом («Русский», «English»), а не в
    -- переводе на текущий: так строку узнаёт тот, кто текущего языка не знает.
    local function LanguageName(lang)
        return DoF.Locale:GetIn(lang, "locale.name")
    end

    local function OnLanguageSelected(_, lang)
        CloseDropDownMenus()
        DoF.Settings:SwitchLanguage(lang)
    end

    UIDropDownMenu_Initialize(langDropdown, function()
        for _, lang in ipairs(DoF.Locale.order) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = LanguageName(lang)
            info.arg1 = lang
            info.func = OnLanguageSelected
            -- Галочка отражает СОХРАНЁННЫЙ выбор, а не активный язык: после
            -- смены и до /reload это разные вещи, и пользователю важнее видеть,
            -- что его выбор принят.
            info.checked = (DoF.Locale:GetSaved() == lang)
            UIDropDownMenu_AddButton(info)
        end
    end)

    UIDropDownMenu_SetWidth(langDropdown, 160)
    UIDropDownMenu_SetText(langDropdown, LanguageName(DoF.Locale:GetSaved()))

    local langDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    langDesc:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 20, -2)
    langDesc:SetWidth(480)
    langDesc:SetJustifyH("LEFT")
    langDesc:SetTextColor(0.7, 0.7, 0.7)
    langDesc:SetText(DoF.L["ui.opt.lang_desc"])

    -- ═══════════════════════════════════════════════════════════
    -- НАСТРОЙКИ ЖУРНАЛА БОЯ
    -- ═══════════════════════════════════════════════════════════

    local logHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    logHeader:SetPoint("TOPLEFT", langDesc, "BOTTOMLEFT", -20, -24)
    logHeader:SetText(DoF.L["ui.opt.log_header"])

    -- Чекбокс: Включить журнал боя
    local logCheckbox = CreateFrame("CheckButton", "DoF_Settings_LogCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    logCheckbox:SetPoint("TOPLEFT", logHeader, "BOTTOMLEFT", 0, -8)
    logCheckbox.Text:SetText(DoF.L["ui.opt.log_enable"])

    logCheckbox.tooltipText = DoF.L["ui.opt.log_tooltip"]

    logCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        DoF.Settings:Set("combatLogEnabled", checked)

        if checked then
            DoF.Utils:Info(DoF.L["ui.opt.log_on"])
        else
            DoF.Utils:Info(DoF.L["ui.opt.log_off"])
        end
    end)

    -- Описание настройки
    local logDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    logDesc:SetPoint("TOPLEFT", logCheckbox, "BOTTOMLEFT", 24, -4)
    logDesc:SetWidth(480)
    logDesc:SetJustifyH("LEFT")
    logDesc:SetTextColor(0.7, 0.7, 0.7)
    logDesc:SetText(DoF.L["ui.opt.log_desc"])

    -- ═══════════════════════════════════════════════════════════
    -- НАСТРОЙКИ МАСШТАБА ОКНА
    -- ═══════════════════════════════════════════════════════════

    local scaleHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scaleHeader:SetPoint("TOPLEFT", logDesc, "BOTTOMLEFT", -24, -24)
    scaleHeader:SetText(DoF.L["ui.opt.scale_header"])

    -- Слайдер масштаба
    local scaleSlider = CreateFrame("Slider", "DoF_Settings_ScaleSlider", panel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleHeader, "BOTTOMLEFT", 4, -16)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.05)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetWidth(300)

    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    _G[scaleSlider:GetName() .. "Text"]:SetText(DoF.L["ui.opt.scale_slider"])

    -- Значение слайдера
    local scaleValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100 + 0.5) / 100 -- Округляем до 2 знаков
        scaleValue:SetText(string.format("%.0f%%", value * 100))
        DoF.Settings:Set("uiScale", value)
    end)

    -- Описание настройки
    local scaleDesc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    scaleDesc:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -8)
    scaleDesc:SetWidth(480)
    scaleDesc:SetJustifyH("LEFT")
    scaleDesc:SetTextColor(0.7, 0.7, 0.7)
    scaleDesc:SetText(DoF.L["ui.opt.scale_desc"])

    -- ═══════════════════════════════════════════════════════════
    -- НАСТРОЙКИ UNIT FRAMES
    -- ═══════════════════════════════════════════════════════════

    local ufHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ufHeader:SetPoint("TOPLEFT", scaleDesc, "BOTTOMLEFT", -4, -24)
    ufHeader:SetText(DoF.L["ui.opt.frames_header"])

    -- Чекбокс: Показывать фрейм игрока
    local playerFrameCheckbox = CreateFrame("CheckButton", "DoF_Settings_PlayerFrameCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    playerFrameCheckbox:SetPoint("TOPLEFT", ufHeader, "BOTTOMLEFT", 0, -8)
    playerFrameCheckbox.Text:SetText(DoF.L["ui.opt.player_frame"])
    playerFrameCheckbox.tooltipText = DoF.L["ui.opt.player_frame_tooltip"]

    playerFrameCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if DoF.db and DoF.db.profile and DoF.db.profile.unitFrames then
            DoF.db.profile.unitFrames.player.enabled = checked
            if DoF.UI and DoF.UI.UnitFrames then
                if checked then
                    DoF.UI.UnitFrames.PlayerFrame:Show()
                    DoF.UI.UnitFrames:UpdatePlayerFrame()
                else
                    DoF.UI.UnitFrames.PlayerFrame:Hide()
                end
                DoF.UI.UnitFrames:UpdateControlButtons()
            end
        end
    end)

    -- Чекбокс: Показывать фрейм цели
    local targetFrameCheckbox = CreateFrame("CheckButton", "DoF_Settings_TargetFrameCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    targetFrameCheckbox:SetPoint("TOPLEFT", playerFrameCheckbox, "BOTTOMLEFT", 0, -4)
    targetFrameCheckbox.Text:SetText(DoF.L["ui.opt.target_frame"])
    targetFrameCheckbox.tooltipText = DoF.L["ui.opt.target_frame_tooltip"]

    targetFrameCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if DoF.db and DoF.db.profile and DoF.db.profile.unitFrames then
            DoF.db.profile.unitFrames.target.enabled = checked
            if DoF.UI and DoF.UI.UnitFrames then
                DoF.UI.UnitFrames:UpdateControlButtons()
                DoF.UI.UnitFrames:UpdateTargetFrame()
            end
        end
    end)

    -- Чекбокс: Заблокировать перемещение
    local lockFramesCheckbox = CreateFrame("CheckButton", "DoF_Settings_LockFramesCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    lockFramesCheckbox:SetPoint("TOPLEFT", targetFrameCheckbox, "BOTTOMLEFT", 0, -4)
    lockFramesCheckbox.Text:SetText(DoF.L["ui.opt.lock_frames"])
    lockFramesCheckbox.tooltipText = DoF.L["ui.opt.lock_frames_tooltip"]

    lockFramesCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if DoF.db and DoF.db.profile and DoF.db.profile.unitFrames then
            DoF.db.profile.unitFrames.player.locked = checked
            DoF.db.profile.unitFrames.target.locked = checked
            if DoF.UI and DoF.UI.UnitFrames then
                DoF.UI.UnitFrames:UpdateControlButtons()
            end
        end
    end)

    -- Слайдер масштаба Unit Frames
    local ufScaleSlider = CreateFrame("Slider", "DoF_Settings_UFScaleSlider", panel, "OptionsSliderTemplate")
    ufScaleSlider:SetPoint("TOPLEFT", lockFramesCheckbox, "BOTTOMLEFT", 4, -20)
    ufScaleSlider:SetMinMaxValues(0.5, 2.0)
    ufScaleSlider:SetValueStep(0.05)
    ufScaleSlider:SetObeyStepOnDrag(true)
    ufScaleSlider:SetWidth(200)

    _G[ufScaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[ufScaleSlider:GetName() .. "High"]:SetText("200%")
    _G[ufScaleSlider:GetName() .. "Text"]:SetText(DoF.L["ui.opt.frames_scale"])

    local ufScaleValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    ufScaleValue:SetPoint("LEFT", ufScaleSlider, "RIGHT", 10, 0)

    ufScaleSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 100 + 0.5) / 100
        ufScaleValue:SetText(string.format("%.0f%%", value * 100))
        if DoF.db and DoF.db.profile and DoF.db.profile.unitFrames then
            DoF.db.profile.unitFrames.player.scale = value
            DoF.db.profile.unitFrames.target.scale = value
            if DoF.UI and DoF.UI.UnitFrames then
                DoF.UI.UnitFrames:ApplyScale("player")
                DoF.UI.UnitFrames:ApplyScale("target")
            end
        end
    end)

    -- Кнопка сброса позиций
    local resetPosBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetPosBtn:SetPoint("TOPLEFT", ufScaleSlider, "BOTTOMLEFT", -4, -12)
    resetPosBtn:SetSize(150, 22)
    resetPosBtn:SetText(DoF.L["ui.opt.reset_positions"])
    resetPosBtn:SetScript("OnClick", function()
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:ResetPosition("player")
            DoF.UI.UnitFrames:ResetPosition("target")
            DoF.Utils:Info(DoF.L["ui.opt.positions_reset"])
        end
    end)

    -- ═══════════════════════════════════════════════════════════
    -- НАСТРОЙКИ ПАНЕЛИ ДЕЙСТВИЙ (ACTION BAR)
    -- ═══════════════════════════════════════════════════════════

    local abHeader = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    abHeader:SetPoint("TOPLEFT", resetPosBtn, "BOTTOMLEFT", 4, -24)
    abHeader:SetText(DoF.L["ui.opt.actionbar_header"])

    -- Чекбокс: Показывать панель действий
    local actionBarCheckbox = CreateFrame("CheckButton", "DoF_Settings_ActionBarCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    actionBarCheckbox:SetPoint("TOPLEFT", abHeader, "BOTTOMLEFT", 0, -8)
    actionBarCheckbox.Text:SetText(DoF.L["ui.opt.actionbar_show"])
    actionBarCheckbox.tooltipText = DoF.L["ui.opt.actionbar_tooltip"]

    actionBarCheckbox:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if DoF.db and DoF.db.profile and DoF.db.profile.actionBar then
            DoF.db.profile.actionBar.enabled = checked
            if DoF.ActionBar then
                if checked then
                    DoF.ActionBar:Show()
                else
                    DoF.ActionBar:Hide()
                end
            end
        end
    end)

    -- ═══════════════════════════════════════════════════════════
    -- КНОПКИ
    -- ═══════════════════════════════════════════════════════════

    -- Кнопка сброса настроек
    local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetBtn:SetPoint("BOTTOMLEFT", 16, 16)
    resetBtn:SetSize(150, 25)
    resetBtn:SetText(DoF.L["ui.opt.reset_settings"])
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("DoF_RESET_SETTINGS")
    end)

    -- Функция обновления UI при открытии панели
    panel.refresh = function()
        -- Показываем сохранённый выбор: после сброса настроек он исчезает,
        -- и подпись должна вернуться к языку клиента, а не залипнуть на старом.
        UIDropDownMenu_SetText(langDropdown, LanguageName(DoF.Locale:GetSaved()))

        logCheckbox:SetChecked(DoF.Settings:Get("combatLogEnabled"))

        local scale = DoF.Settings:Get("uiScale")
        scaleSlider:SetValue(scale)
        scaleValue:SetText(string.format("%.0f%%", scale * 100))

        -- Unit Frames settings
        if DoF.db and DoF.db.profile and DoF.db.profile.unitFrames then
            playerFrameCheckbox:SetChecked(DoF.db.profile.unitFrames.player.enabled)
            targetFrameCheckbox:SetChecked(DoF.db.profile.unitFrames.target.enabled)
            lockFramesCheckbox:SetChecked(DoF.db.profile.unitFrames.player.locked)
            local ufScale = DoF.db.profile.unitFrames.player.scale or 1.0
            ufScaleSlider:SetValue(ufScale)
            ufScaleValue:SetText(string.format("%.0f%%", ufScale * 100))
        end

        -- Action Bar settings
        if DoF.db and DoF.db.profile and DoF.db.profile.actionBar then
            actionBarCheckbox:SetChecked(DoF.db.profile.actionBar.enabled)
        end
    end

    return panel
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ПОДТВЕРЖДЕНИЯ СБРОСА
-- ═══════════════════════════════════════════════════════════

-- ═══════════════════════════════════════════════════════════
-- СМЕНА ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Единая точка переключения для всех мест интерфейса: выпадающего списка
-- в этой панели и кнопки в боковой панели персонажа. Возвращает true, если
-- язык действительно сменился.
function DoF.Settings:SwitchLanguage(lang)
    if lang == DoF.Locale:GetSaved() then return false end
    if not DoF.Locale:SetLanguage(lang) then return false end

    -- Сообщение собирается на ВЫБРАННОМ языке: DoF.L до /reload отдаёт старый.
    StaticPopup_Show("DoF_LANGUAGE_RELOAD",
        string.format(DoF.Locale:GetIn(lang, "ui.opt.lang_reload_confirm"),
            DoF.Locale:GetIn(lang, "locale.name")))

    local panel = _G["DoF_SettingsPanel"]
    if panel and panel.refresh then panel.refresh() end
    if DoF.UI and DoF.UI.CharacterSidebar and DoF.UI.CharacterSidebar.UpdateLanguageButton then
        DoF.UI.CharacterSidebar:UpdateLanguageButton()
    end

    return true
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ПЕРЕЗАГРУЗКИ ПОСЛЕ СМЕНЫ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Диалог собирается на НОВОМ языке: пользователь только что его выбрал,
-- а DoF.L до /reload продолжает отдавать старый. Текст и подписи кнопок
-- проставляются в OnShow, потому что StaticPopupDialogs создаётся один раз
-- при загрузке и статичные строки в нём остались бы от языка загрузки.
StaticPopupDialogs["DoF_LANGUAGE_RELOAD"] = {
    text = "%s",
    button1 = "",
    button2 = "",
    OnShow = function(self)
        local lang = (DoF_DB and DoF_DB.settings and DoF_DB.settings.locale) or DoF.Locale.current
        self.button1:SetText(DoF.Locale:GetIn(lang, "ui.opt.lang_reload_now"))
        self.button2:SetText(DoF.Locale:GetIn(lang, "ui.opt.lang_reload_later"))
    end,
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ПОДТВЕРЖДЕНИЯ СБРОСА
-- ═══════════════════════════════════════════════════════════

StaticPopupDialogs["DoF_RESET_SETTINGS"] = {
    text = DoF.L["ui.opt.reset_confirm"],
    button1 = DoF.L["ui.common.yes"],
    button2 = DoF.L["ui.common.no"],
    OnAccept = function()
        -- Сбрасываем настройки
        DoF_DB.settings = {}
        DoF.Settings:Init()

        -- Обновляем UI если панель открыта
        local panel = _G["DoF_SettingsPanel"]
        if panel and panel.refresh then
            panel.refresh()
        end

        -- Применяем настройки
        DoF.Settings:ApplyCombatLogSetting()

        DoF.Utils:Info(DoF.L["ui.opt.settings_reset"])
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ═══════════════════════════════════════════════════════════
-- РЕГИСТРАЦИЯ ПАНЕЛИ
-- ═══════════════════════════════════════════════════════════

local function RegisterSettings()
    -- Проверяем, доступен ли новый API (Dragonflight+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Новый API (10.0+)
        local panel = CreateSettingsPanel()
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        -- Старый API (9.x)
        local panel = CreateSettingsPanel()
        InterfaceOptions_AddCategory(panel)
    else
        -- Fallback для очень старых версий
        print("|cFFFFA500[DoF]|r " .. DoF.L["errors.settings_panel_failed"])
    end
end

-- Регистрация панели вызывается из DoF.Settings:Init() (Init.lua → OnEnable)
DoF.Settings.RegisterPanel = RegisterSettings
