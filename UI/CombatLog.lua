-- DoF/UI/CombatLog.lua
-- Журнал боя и журнал мастера

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local ipairs = ipairs
local CreateFrame = CreateFrame
local date = date

DoF.CombatLog = {
    CurrentTab = "battle",
    MasterLog = {},
    Frame = nil,
}

-- ═══════════════════════════════════════════════════════════
-- ДОБАВЛЕНИЕ ЗАПИСЕЙ
-- ═══════════════════════════════════════════════════════════

function DoF.CombatLog:Add(text, sender)
    -- Проверяем настройку журнала боя
    local logEnabled = DoF.Settings and DoF.Settings:Get("combatLogEnabled")
    if logEnabled == nil then
        logEnabled = true -- По умолчанию включен
    end

    if logEnabled then
        -- Режим журнала: записываем в журнал
        local entry = {
            time = date("%H:%M:%S"),
            sender = sender or UnitName("player"),
            text = text,
        }

        table.insert(DoF.db.global.combatLog, entry)

        -- Ограничиваем размер лога
        while #DoF.db.global.combatLog > DoF.Config.COMBAT_LOG_MAX do
            table.remove(DoF.db.global.combatLog, 1)
        end

        -- Обновляем окно если открыто
        if self.Frame and self.Frame:IsShown() and self.CurrentTab == "battle" then
            self:UpdateFrame()
        end
    else
        -- Режим чата: выводим в чат (две строки без timestamp)
        -- Разделяем text по слову-маркеру результата броска.
        --
        -- Это разбор уже собранной боевой строки, а не подпись в интерфейсе:
        -- маркер обязан совпадать с началом combat.roll_result, иначе разбиение
        -- молча перестанет срабатывать. Поэтому он берётся из локали тем же
        -- ключом, а не зашит строкой. Символы экранируются: в другом языке
        -- маркер может содержать спецсимволы Lua-паттернов.
        local marker = DoF.L["ui.combatlog.result_marker"]:gsub("(%W)", "%%%1")
        local line1, line2 = text:match("^(.-)( " .. marker .. ".+)$")
        if line1 and line2 then
            print("|cFFFFA500[DoF]|r " .. line1)
            print("|cFFFFA500[DoF]|r" .. line2)
        else
            -- Если не удалось разделить, выводим как есть
            print("|cFFFFA500[DoF]|r " .. text)
        end
    end
end

function DoF.CombatLog:AddMasterLog(text, category)
    if not DoF.Sync:IsMaster() then return end
    
    local entry = {
        time = date("%H:%M:%S"),
        text = text,
        category = category or "system",
    }
    
    table.insert(self.MasterLog, entry)
    
    while #self.MasterLog > DoF.Config.MASTER_LOG_MAX do
        table.remove(self.MasterLog, 1)
    end
    
    if self.Frame and self.Frame:IsShown() and self.CurrentTab == "master" then
        self:UpdateFrame()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ХЕЛПЕРЫ ДЛЯ ТЕМНОГО СТИЛЯ
-- ═══════════════════════════════════════════════════════════

local function CreateDarkButton(parent, width, height, text, textColor)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetText(text)
    btn.text = btn:GetFontString()  -- алиас для совместимости со старым кодом
    return btn
end

local function SetButtonActive(btn, active)
    btn.isActive = active
    if active then
        btn:LockHighlight()
    else
        btn:UnlockHighlight()
    end
end

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ ОКНА
-- ═══════════════════════════════════════════════════════════

function DoF.CombatLog:CreateFrame()
    if self.Frame then return end

    -- Главный фрейм на DoF_DialogTemplate (стиль главного меню игры)
    local f = CreateFrame("Frame", "DoF_CombatLogFrame", UIParent, "DoF_DialogTemplate")
    f:SetSize(420, 320)
    f:SetPoint("CENTER", 300, 0)
    f:SetResizable(true)
    f:SetResizeBounds(340, 220, 620, 520)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:Hide()
    f.Header:Setup(DoF.L["ui.combatlog.title_battle"])

    -- Панель вкладок (без backdrop — просто контейнер)
    local tabBar = CreateFrame("Frame", nil, f)
    tabBar:SetHeight(28)
    tabBar:SetPoint("TOPLEFT", 14, -36)
    tabBar:SetPoint("TOPRIGHT", -14, -36)

    -- Вкладка "Бой"
    f.tabBattle = CreateDarkButton(tabBar, 80, 22, DoF.L["ui.combatlog.tab_battle"])
    f.tabBattle:SetPoint("LEFT", 0, 0)
    f.tabBattle:SetScript("OnClick", function()
        self.CurrentTab = "battle"
        self:UpdateTabs()
        self:UpdateFrame()
    end)

    -- Вкладка "Мастер"
    f.tabMaster = CreateDarkButton(tabBar, 80, 22, DoF.L["ui.combatlog.tab_master"])
    f.tabMaster:SetPoint("LEFT", f.tabBattle, "RIGHT", 4, 0)
    f.tabMaster:SetScript("OnClick", function()
        if not DoF.Sync:IsMaster() then
            DoF.Utils:Error(DoF.L["errors.gm_only"])
            return
        end
        self.CurrentTab = "master"
        self:UpdateTabs()
        self:UpdateFrame()
    end)

    -- Кнопка очистки
    f.clearBtn = CreateDarkButton(tabBar, 80, 22, DoF.L["ui.combatlog.clear"])
    f.clearBtn:SetPoint("RIGHT", 0, 0)
    f.clearBtn:SetScript("OnClick", function()
        if self.CurrentTab == "battle" then
            DoF.db.global.combatLog = {}
        else
            self.MasterLog = {}
        end
        self:UpdateFrame()
    end)

    -- Контейнер для лога (штатный InsetFrameTemplate)
    local logContainer = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    logContainer:SetPoint("TOPLEFT", 14, -68)
    logContainer:SetPoint("BOTTOMRIGHT", -14, 30)
    
    -- Скролл-область
    local scroll = CreateFrame("ScrollFrame", "DoF_LogScroll", logContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    
    -- Стилизация скроллбара
    local scrollBar = _G["DoF_LogScrollScrollBar"]
    if scrollBar then
        scrollBar:SetWidth(12)
    end
    
    f.content = CreateFrame("Frame", "DoF_LogContent", scroll)
    f.content:SetWidth(scroll:GetWidth())
    f.content:SetHeight(400)
    scroll:SetScrollChild(f.content)
    
    f.logText = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.logText:SetPoint("TOPLEFT", 4, -4)
    f.logText:SetWidth(scroll:GetWidth() - 8)
    f.logText:SetJustifyH("LEFT")
    f.logText:SetJustifyV("TOP")
    f.logText:SetSpacing(3)
    f.logText:SetWordWrap(true)
    
    f.scrollFrame = scroll
    f.logContainer = logContainer
    
    -- Ресайз — стандартная иконка чата в правом нижнем углу
    local resizer = CreateFrame("Button", nil, f)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -4, 4)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizer:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        self:UpdateFrame()
    end)

    f:SetScript("OnSizeChanged", function(_, w)
        f.content:SetWidth(w - 50)
        f.logText:SetWidth(w - 58)
    end)

    self.Frame = f
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ
-- ═══════════════════════════════════════════════════════════

function DoF.CombatLog:UpdateTabs()
    if not self.Frame then return end
    
    local isBattle = self.CurrentTab == "battle"
    
    SetButtonActive(self.Frame.tabBattle, isBattle)
    SetButtonActive(self.Frame.tabMaster, not isBattle)

    self.Frame.Header:Setup(isBattle and DoF.L["ui.combatlog.title_battle"] or DoF.L["ui.combatlog.title_master"])

    if DoF.Sync:IsMaster() then
        self.Frame.tabMaster:Show()
    else
        self.Frame.tabMaster:Hide()
        self.CurrentTab = "battle"
    end
end

function DoF.CombatLog:UpdateFrame()
    if not self.Frame or not self.Frame:IsShown() then return end
    
    local f = self.Frame
    f.content:SetWidth(f:GetWidth() - 50)
    f.logText:SetWidth(f:GetWidth() - 58)
    
    local lines = {}
    local log = self.CurrentTab == "battle" and DoF.db.global.combatLog or self.MasterLog
    
    for _, entry in ipairs(log) do
        if self.CurrentTab == "battle" then
            table.insert(lines,
                "|cFF666666[" .. entry.time .. "]|r " .. entry.text)
        else
            local categoryColor = entry.category == "hp_change" and "FF9966" or
                                  (entry.category == "master_action" and "A06AF1" or "888888")
            table.insert(lines,
                "|cFF666666[" .. entry.time .. "]|r " ..
                "|cFF" .. categoryColor .. entry.text .. "|r")
        end
    end
    
    f.logText:SetText(#lines > 0 and table.concat(lines, "\n") or DoF.L["ui.combatlog.empty"])
    f.content:SetHeight(math.max(f.logText:GetStringHeight() + 10, 100))
    
    -- Скролл вниз
    DoF.Addon:ScheduleTimer(function()
        if f.scrollFrame then
            f.scrollFrame:SetVerticalScroll(f.scrollFrame:GetVerticalScrollRange())
        end
    end, 0.01)
end

-- ═══════════════════════════════════════════════════════════
-- ПЕРЕКЛЮЧЕНИЕ
-- ═══════════════════════════════════════════════════════════

function DoF.CombatLog:Toggle()
    -- Проверяем настройку журнала боя
    local logEnabled = DoF.Settings and DoF.Settings:Get("combatLogEnabled")
    if logEnabled == nil then
        logEnabled = true -- По умолчанию включен
    end

    if not logEnabled then
        DoF.Utils:Error(DoF.L["errors.combatlog_disabled"])
        return
    end

    if not self.Frame then
        self:CreateFrame()
    end

    if self.Frame:IsShown() then
        self.Frame:Hide()
    else
        self.Frame:Show()
        self:UpdateTabs()
        self:UpdateFrame()
    end
end

-- Алиасы перенесены в Core/Aliases.lua
