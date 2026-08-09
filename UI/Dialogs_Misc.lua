-- DoF/UI/Dialogs_Misc.lua
-- Разные диалоги: настройки, окно помощи

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame

-- ═══════════════════════════════════════════════════════════
-- ОКНО НАСТРОЕК
-- ═══════════════════════════════════════════════════════════

local SettingsFrame = nil

function DoF.Dialogs:ShowSettings()
    if SettingsFrame then
        SettingsFrame:Show()
        return
    end

    -- Создаём окно на DoF_DialogTemplate (стиль главного меню игры)
    local f = CreateFrame("Frame", "DoF_SettingsFrame", UIParent, "DoF_DialogTemplate")
    f:SetSize(300, 180)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f.Header:Setup(DoF.L["ui.settings.title"])

    -- Метка слайдера
    local scaleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", 18, -50)
    scaleLabel:SetText(DoF.L["ui.settings.ui_scale"])

    -- Текущее значение
    local scaleValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValue:SetPoint("TOPRIGHT", -18, -50)

    -- Слайдер
    local slider = CreateFrame("Slider", "DoF_ScaleSlider", f, "OptionsSliderTemplate")
    slider:SetWidth(260)
    slider:SetHeight(17)
    slider:SetPoint("TOP", 0, -82)
    slider:SetMinMaxValues(0.5, 1.5)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)

    -- Убираем стандартные надписи
    _G[slider:GetName().."Low"]:SetText("50%")
    _G[slider:GetName().."High"]:SetText("150%")
    _G[slider:GetName().."Text"]:SetText("")

    -- Обновление значения
    local function UpdateScaleDisplay(value)
        scaleValue:SetText(string.format("%d%%", value * 100))
    end

    -- Загружаем текущее значение
    local currentScale = DoF.db and DoF.db.profile and DoF.db.profile.uiScale or 1.0
    slider:SetValue(currentScale)
    UpdateScaleDisplay(currentScale)

    -- При изменении слайдера
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value * 20 + 0.5) / 20  -- Округляем до 0.05
        UpdateScaleDisplay(value)

        -- Применяем масштаб
        if DoF.db and DoF.db.profile then
            DoF.db.profile.uiScale = value
            DoF.Utils:ApplyUIScale()
        end
    end)

    -- Кнопка сброса
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 26)
    resetBtn:SetPoint("BOTTOM", 0, 18)
    resetBtn:SetText(DoF.L["ui.settings.reset_100"])
    resetBtn:SetScript("OnClick", function()
        slider:SetValue(1.0)
    end)

    SettingsFrame = f
    f:Show()
end

function DoF.Dialogs:HideSettings()
    if SettingsFrame then
        SettingsFrame:Hide()
    end
end

function DoF.Dialogs:ToggleSettings()
    if SettingsFrame and SettingsFrame:IsShown() then
        SettingsFrame:Hide()
    else
        self:ShowSettings()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОКНО ПОМОЩИ (/dofhelp)
-- ═══════════════════════════════════════════════════════════

local HelpWindow = nil

function DoF.Dialogs:ShowHelpWindow()
    if HelpWindow and HelpWindow:IsShown() then
        HelpWindow:Hide()
        return
    end

    if not HelpWindow then
        local f = CreateFrame("Frame", "DoF_HelpWindow", UIParent, "DoF_DialogTemplate")
        f:SetSize(540, 540)
        f:SetPoint("CENTER")
        f:SetFrameStrata("HIGH")
        f:SetClampedToScreen(true)
        f.Header:Setup(DoF.L["ui.help.title"])

        -- Закрытие по Escape
        table.insert(UISpecialFrames, "DoF_HelpWindow")

        -- ScrollFrame с штатным скроллбаром
        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 14, -36)
        scrollFrame:SetPoint("BOTTOMRIGHT", -34, 14)

        -- Контент (EditBox readonly)
        local content = CreateFrame("EditBox", nil, scrollFrame)
        content:SetMultiLine(true)
        content:SetAutoFocus(false)
        content:SetFontObject(GameFontNormal)
        content:SetWidth(480)
        content:EnableMouse(true)
        content:SetScript("OnEscapePressed", function() f:Hide() end)
        -- Readonly: запрещаем ввод
        content:SetScript("OnChar", function(self) end)
        content:SetScript("OnKeyDown", function(self, key)
            if key == "BACKSPACE" or key == "DELETE" then
                -- Блокируем удаление
            end
        end)
        scrollFrame:SetScrollChild(content)

        f.content = content
        HelpWindow = f
    end

    -- Справка целиком лежит одним блоком в локали: разбивать её на 60 ключей
    -- бессмысленно — переводится и правится она всегда целиком.
    -- Заголовок отделён, потому что в него подставляется версия: тело справки
    -- через string.format прогонять нельзя, в нём есть "%t" из /dofnpcattack.
    local header = DoF.Locale:Format("ui.help.header", DoF.Config.VERSION)

    HelpWindow.content:SetText(header .. "\n\n" .. DoF.L["ui.help.body"])
    HelpWindow:Show()
end
