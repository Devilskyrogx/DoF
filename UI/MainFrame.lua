-- DoF/UI/MainFrame.lua
-- Общие UI-хелперы. Старое главное окно DoF_MainFrame удалено — его функционал
-- живёт в UI/CharacterSidebar.lua (таб «DiceOfFate» в окне персонажа) и в меню
-- ПКМ на иконке миникарты. Этот файл держит:
--   • конфиг статов (единый источник для CharacterSidebar),
--   • точку входа DoF.UI:Init + регистрацию внутренних событий → неймплейты,
--   • ToggleCharacterSidebar (LMB миникарты, `/dof`),
--   • ShowRoleTooltip (используется CharacterSidebar),
--   • управление DoF_GMPanel (ToggleGMPanel / SetGMPanelTab),
--   • общие тултип-хелперы (ShowModernTooltip / HideTooltip).

local ADDON_NAME, DoF = ...

local CreateFrame = CreateFrame
local C_Timer = C_Timer
local ipairs = ipairs
local tonumber = tonumber
local IsInGroup = IsInGroup
local HideUIPanel = HideUIPanel
local ToggleCharacter = ToggleCharacter
local PaperDollFrame_SetSidebar = PaperDollFrame_SetSidebar

DoF.UI = DoF.UI or {}

-- Троттлинг обновлений неймплейтов (таблица неймплейтов — в UI/Nameplates.lua).
local pendingNameplateUpdate = false
local THROTTLE_DELAY = 0

-- ═══════════════════════════════════════════════════════════
-- КОНФИГ СТАТОВ (единый источник для CharacterSidebar и др.)
-- ═══════════════════════════════════════════════════════════

local STAT_CONFIG = {
    Strength = {
        label = DoF.L["stats.strength.label"],
        icon = "Interface\\Icons\\ability_warrior_secondwind",
        color = {0.77, 0.12, 0.23},
        desc = DoF.L["stats.strength.desc"],
    },
    Dexterity = {
        label = DoF.L["stats.dexterity.label"],
        icon = "Interface\\Icons\\ability_rogue_quickrecovery",
        color = {0, 1, 0.59},
        desc = DoF.L["stats.dexterity.desc"],
    },
    Intelligence = {
        label = DoF.L["stats.intelligence.label"],
        icon = "Interface\\Icons\\spell_holy_arcaneintellect",
        color = {0, 0.44, 0.87},
        desc = DoF.L["stats.intelligence.desc"],
    },
    Spirit = {
        label = DoF.L["stats.spirit.label"],
        icon = "Interface\\Icons\\spell_holy_divinespirit",
        color = {1, 1, 1},
        desc = DoF.L["stats.spirit.desc"],
    },
    Fortitude = {
        label = DoF.L["stats.fortitude.label"],
        icon = "Interface\\Icons\\spell_holy_devotionaura",
        color = {0.64, 0.19, 0.79},
        desc = DoF.L["stats.fortitude.desc"],
    },
    Reflex = {
        label = DoF.L["stats.reflex.label"],
        icon = "Interface\\Icons\\spell_holy_blessingofagility",
        color = {1, 0.49, 0.04},
        desc = DoF.L["stats.reflex.desc"],
    },
    Will = {
        label = DoF.L["stats.will.label"],
        icon = "Interface\\Icons\\spell_arcane_mindmastery",
        color = {0.53, 0.53, 0.93},
        desc = DoF.L["stats.will.desc"],
    },
}
DoF.UI.StatConfig = STAT_CONFIG

local STAT_ORDER = { "Strength", "Dexterity", "Intelligence", "Spirit", "Fortitude", "Reflex", "Will" }
DoF.UI.StatOrder = STAT_ORDER

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ И СОБЫТИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.UI:Init()
    self:CreateMinimapButton()
    self:RegisterEvents()
    if self.CharacterSidebar and self.CharacterSidebar.Init then
        self.CharacterSidebar:Init()
    end
end

function DoF.UI:RegisterEvents()
    local UI = self

    local function QueueNameplateUpdate()
        if pendingNameplateUpdate then return end
        pendingNameplateUpdate = true
        C_Timer.After(THROTTLE_DELAY, function()
            pendingNameplateUpdate = false
            UI:UpdateAllNameplates()
        end)
    end

    -- HP игрока → неймплейт (у CharacterSidebar своя подписка).
    DoF.Events:Register("PLAYER_HP_CHANGED", function()
        QueueNameplateUpdate()
    end, UI)

    -- События NPC → только неймплейты.
    for _, ev in ipairs({ "UNIT_HP_CHANGED", "UNIT_CREATED", "UNIT_REMOVED", "UNITS_CLEARED", "UNITS_IMPORTED" }) do
        DoF.Events:Register(ev, function() QueueNameplateUpdate() end, UI)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОТКРЫТИЕ ТАБА «DiceOfFate»
-- ═══════════════════════════════════════════════════════════

-- ЛКМ на иконке миникарты и `/dof` → открыть/закрыть окно персонажа на нашем табе.
-- Если окно уже открыто и активен наш таб — закрыть. Иначе открыть/переключить.
function DoF.UI:ToggleCharacterSidebar()
    local cs = self.CharacterSidebar
    if not cs or not cs.pane or not cs.tabIndex then
        return
    end
    local frameOpen   = CharacterFrame and CharacterFrame:IsShown()
    local onPaperDoll = PaperDollFrame and PaperDollFrame:IsShown()
    local onOurTab    = cs.pane:IsShown()
    if frameOpen and onPaperDoll and onOurTab then
        HideUIPanel(CharacterFrame)
    else
        -- onlyShow=true: не тогглить, только показать/переключить subframe
        ToggleCharacter("PaperDollFrame", true)
        if PaperDollFrame_SetSidebar then
            PaperDollFrame_SetSidebar(nil, cs.tabIndex)
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ТУЛТИП ВЫБОРА РОЛИ (используется CharacterSidebar.roleBtn)
-- ═══════════════════════════════════════════════════════════

function DoF.UI:ShowRoleTooltip(frame)
    local role = DoF.Stats and DoF.Stats:GetRole()
    local lines = {}
    if role then
        local data = DoF.Config.Roles[role]
        if data then
            local r = tonumber(data.color:sub(1, 2), 16) / 255
            local g = tonumber(data.color:sub(3, 4), 16) / 255
            local b = tonumber(data.color:sub(5, 6), 16) / 255
            lines[#lines + 1] = { text = data.name, r = r, g = g, b = b, size = 14 }
            lines[#lines + 1] = { text = data.description, r = 0.8, g = 0.8, b = 0.8 }
        end
    else
        lines[#lines + 1] = { text = DoF.L["ui.role.choose_title"], r = 1, g = 0.82, b = 0, size = 14 }
        lines[#lines + 1] = { text = DoF.L["ui.role.choose_hint"], r = 0.7, g = 0.7, b = 0.7 }
    end
    DoF.Utils:ShowTooltip(frame, lines, "TOP")
end

-- ═══════════════════════════════════════════════════════════
-- GM-ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════

-- Центрируем группу из 4 вкладок снизу панели (CharacterFrameTabButtonTemplate
-- сам не центрируется — первая вкладка якорится жёстко по BOTTOMLEFT).
local function CenterTabs()
    if not DoF_GMPanel then return end
    local t1 = DoF_GMPanel_Tab1
    local t2 = DoF_GMPanel_Tab2
    local t3 = DoF_GMPanel_Tab3
    local t4 = DoF_GMPanel_Tab4
    if not (t1 and t2 and t3 and t4) then return end
    if PanelTemplates_TabResize then
        for _, t in ipairs({ t1, t2, t3, t4 }) do
            PanelTemplates_TabResize(t, 0)
        end
    end
    local overlap = 16  -- Anchor X=-16 между соседними вкладками
    local total = t1:GetWidth() + t2:GetWidth() + t3:GetWidth() + t4:GetWidth() - overlap * 3
    local startX = math.floor((DoF_GMPanel:GetWidth() - total) / 2)
    t1:ClearAllPoints()
    t1:SetPoint("TOPLEFT", DoF_GMPanel, "BOTTOMLEFT", startX, 2)
end

-- Компактный шрифт на узких кнопках Tab3. Меняем только размер,
-- сам файл шрифта берём из текущего font object — он уже подобран клиентом
-- и кириллицу отображает. Явно подставлять _CYR-шрифт нельзя: его нет
-- в нерусских клиентах (см. блок ШРИФТЫ в Core/Config.lua).
local function ApplyCompactFonts()
    if not DoF_GMPanel or DoF_GMPanel._compactFontsApplied then return end
    local names = {
        "DoF_GMPanel_SkipTurnBtn",
        "DoF_GMPanel_NPCTurnBtn",
        "DoF_GMPanel_FreeActionBtn",
    }
    for _, n in ipairs(names) do
        local b = _G[n]
        if b then
            local fs = b:GetFontString()
            if fs then
                local _, _, flags = fs:GetFont()
                -- Путь берём из Config, а не из самого FontString: он наследует
                -- шрифт клиента, в котором на нерусских сборках нет кириллицы,
                -- а явное назначение убирает автоподбор символов.
                fs:SetFont(DoF.Config.FONT, 9, flags or "")
            end
        end
    end
    DoF_GMPanel._compactFontsApplied = true
end

function DoF.UI:ToggleGMPanel()
    if not DoF_GMPanel then return end
    if not DoF.Sync:IsMaster() and IsInGroup() then
        DoF.Utils:Error(DoF.L["errors.gm_panel_only"])
        return
    end
    if DoF_GMPanel:IsShown() then
        DoF_GMPanel:Hide()
    else
        ApplyCompactFonts()
        DoF_GMPanel:Show()
        self:SetGMPanelTab(1)
        CenterTabs()
        -- Повторяем после кадра отрисовки: PanelTemplates_TabResize обмеряет
        -- FontString только когда он реально нарисован, поэтому первый вызов
        -- при холодном открытии может посчитать ширины по default-значению.
        C_Timer.After(0, CenterTabs)
        if self.UpdateGMCombatButtons then
            self:UpdateGMCombatButtons()
        end
    end
end

-- Базовая высота = top inset + bottom inset + отступы (для ButtonFrameTemplate с вкладками снизу)
local GM_PANEL_BASE_HEIGHT = 94
local GM_PANEL_MAX_HEIGHT = 500  -- лимит чтобы не вылетать за экран

-- Подгонка высоты GM-панели под активную вкладку, авто-скрытие скроллбара
function DoF.UI:UpdateGMPanelSize()
    if not DoF_GMPanel or not DoF_GMPanel.currentTab then return end

    local contents = {
        DoF_GMPanel_TabContent1,
        DoF_GMPanel_TabContent2,
        DoF_GMPanel_TabContent3,
        DoF_GMPanel_TabContent4,
    }

    local current = contents[DoF_GMPanel.currentTab]
    if not current then return end

    local contentHeight = current:GetHeight() or 240
    local desired = GM_PANEL_BASE_HEIGHT + contentHeight + 8
    local panelHeight = math.min(desired, GM_PANEL_MAX_HEIGHT)
    DoF_GMPanel:SetHeight(panelHeight)

    local scroll = DoF_GMPanel.Scroll
    local scrollChild = DoF_GMPanel.ScrollChild
    if scrollChild then
        scrollChild:SetWidth(scroll and scroll:GetWidth() or 220)
        scrollChild:SetHeight(contentHeight)
    end

    -- Скроллбар UIPanelScrollFrameTemplate: автоскрытие если контент влезает
    local scrollBar = scroll and (scroll.ScrollBar or _G[scroll:GetName() and scroll:GetName() .. "ScrollBar"])
    if scroll and scrollBar then
        local viewport = panelHeight - GM_PANEL_BASE_HEIGHT
        if contentHeight <= viewport then
            scrollBar:Hide()
            scroll:SetVerticalScroll(0)
        else
            scrollBar:Show()
        end
    end
end

function DoF.UI:SetGMPanelTab(tabIndex)
    if not DoF_GMPanel then return end

    DoF_GMPanel.currentTab = tabIndex

    local contents = {
        DoF_GMPanel_TabContent1,
        DoF_GMPanel_TabContent2,
        DoF_GMPanel_TabContent3,
        DoF_GMPanel_TabContent4,
    }

    -- Штатное переключение вкладок CharacterFrameTabButtonTemplate.
    -- PanelTemplates_UpdateTabs ищет вкладки через frame.Tabs или _G[name.."Tab"..i],
    -- у нас имена с подчёркиванием — заполняем frame.Tabs.
    if not DoF_GMPanel.Tabs then
        DoF_GMPanel.Tabs = {
            DoF_GMPanel_Tab1,
            DoF_GMPanel_Tab2,
            DoF_GMPanel_Tab3,
            DoF_GMPanel_Tab4,
        }
    end
    if PanelTemplates_SetNumTabs then
        PanelTemplates_SetNumTabs(DoF_GMPanel, 4)
    end
    if PanelTemplates_SetTab then
        PanelTemplates_SetTab(DoF_GMPanel, tabIndex)
    end

    -- Репарент TabContent'ов в общий ScrollChild (один раз на каждый).
    -- Якорим по TOP (центр по горизонтали) — чтобы кнопки TOP/x=0 стояли
    -- ровно по центру окна, а не прилипали к левому краю scrollChild.
    local scrollChild = DoF_GMPanel.ScrollChild
    if scrollChild then
        for _, content in ipairs(contents) do
            if content and content:GetParent() ~= scrollChild then
                content:SetParent(scrollChild)
                content:ClearAllPoints()
                content:SetPoint("TOP", scrollChild, "TOP", 0, 0)
            end
        end
    end

    for i, content in ipairs(contents) do
        if content then
            if i == tabIndex then content:Show() else content:Hide() end
        end
    end

    if tabIndex == 4 and DoF.UI.BuildTab4 then
        DoF.UI:BuildTab4()
    end

    self:UpdateGMPanelSize()
end

-- ═══════════════════════════════════════════════════════════
-- ТУЛТИПЫ (тонкие обёртки над DoF.Utils — для совместимости с Aliases)
-- ═══════════════════════════════════════════════════════════

function DoF.UI:ShowModernTooltip(frame, title, text, r, g, b)
    local lines = { { text = title, r = r or 1, g = g or 0.82, b = b or 0, size = 14 } }
    if text then
        lines[#lines + 1] = { text = text, r = 1, g = 1, b = 1 }
    end
    DoF.Utils:ShowTooltip(frame, lines, "RIGHT")
end

function DoF.UI:HideTooltip()
    DoF.Utils:HideTooltip()
end

-- Функции мастера и GM-панель вынесены в UI/MainFrame_GM.lua

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- STAT_CONFIG — единый источник подписей и описаний статов для боковой панели
-- и главного окна. Собирается на этапе загрузки файла, поэтому после смены
-- языка его нужно перечитать: ключи выводятся из имени стата.
DoF.Locale:RegisterRelocalizer(function()
    for stat, cfg in pairs(DoF.UI.StatConfig) do
        cfg.label = DoF.L["stats." .. stat:lower() .. ".label"]
        cfg.desc = DoF.L["stats." .. stat:lower() .. ".desc"]
    end
end)
