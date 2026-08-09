-- DoF/UI/Dialogs.lua
-- Диалоговые окна и выпадающие меню

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local type = type
local wipe = wipe
local table_insert = table.insert
local table_remove = table.remove
local UnitName = UnitName
local C_Timer = C_Timer

DoF.Dialogs = {}

-- ═══════════════════════════════════════════════════════════
-- КАСТОМНОЕ ВЫПАДАЮЩЕЕ МЕНЮ С ПЕРЕИСПОЛЬЗОВАНИЕМ ФРЕЙМОВ
-- ═══════════════════════════════════════════════════════════

local activeMenu = nil

-- Состояние свёрнутых категорий (сохраняется между показами)
local CollapsedCategories = {}

-- Пул виджетов для переиспользования
local WidgetPool = {
    buttons = {},   -- Обычные кнопки
    titles = {},    -- Заголовки
}

-- Получить или создать кнопку из пула
local function AcquireButton(parent)
    local btn = table_remove(WidgetPool.buttons)
    if not btn then
        btn = CreateFrame("Button", nil, parent)
        btn.icon = btn:CreateTexture(nil, "OVERLAY")
        btn.icon:SetSize(16, 16)
        btn.icon:SetPoint("LEFT", 8, 0)
        btn.icon:Hide()
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 8, 0)
        -- Highlight texture для hover (игровой стиль вместо SetBackdropColor)
        btn.hl = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        btn.hl:SetBlendMode("ADD")
        btn.hl:SetAllPoints(btn)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")
    end
    btn:SetParent(parent)
    btn:Show()
    btn:EnableMouse(true)  -- Убеждаемся что мышь включена при каждом использовании
    return btn
end

-- Получить или создать заголовок из пула
local function AcquireTitle(parent)
    local title = table_remove(WidgetPool.titles)
    if not title then
        title = CreateFrame("Button", nil, parent)
        title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title.text:SetPoint("LEFT", 14, 0)
        title.text:SetTextColor(0.5, 0.5, 0.5)
        title.arrow = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title.arrow:SetPoint("LEFT", 3, 0)
        title.arrow:SetTextColor(0.6, 0.6, 0.6)
        title.isTitle = true
        title:EnableMouse(true)
        title:RegisterForClicks("LeftButtonUp")
    end
    title:SetParent(parent)
    title:Show()
    title:EnableMouse(true)  -- Убеждаемся что мышь включена при каждом использовании
    return title
end

-- Вернуть виджет в пул
local function ReleaseWidget(widget)
    widget:Hide()
    widget:ClearAllPoints()
    widget:SetParent(nil)

    -- Сбрасываем скрипты
    widget:SetScript("OnEnter", nil)
    widget:SetScript("OnLeave", nil)
    widget:SetScript("OnClick", nil)

    -- Скрываем иконку при возврате в пул
    if widget.icon then
        widget.icon:Hide()
    end

    if widget.isTitle then
        table_insert(WidgetPool.titles, widget)
    else
        table_insert(WidgetPool.buttons, widget)
    end
end

local function CreateCustomMenu(name, width)
    local menu = CreateFrame("Frame", name, UIParent, "TooltipBackdropTemplate")
    menu:SetSize(width or 180, 20)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:EnableMouse(true)
    menu:Hide()
    menu.widgets = {}
    menu.menuWidth = width or 180

    menu:SetScript("OnShow", function(self)
        if activeMenu and activeMenu ~= self then
            activeMenu:Hide()
        end
        activeMenu = self
    end)

    menu:SetScript("OnHide", function(self)
        DoF.Utils:HideTooltip()
        if activeMenu == self then
            activeMenu = nil
        end
        -- Возвращаем виджеты в пул
        for _, w in ipairs(self.widgets) do
            ReleaseWidget(w)
        end
        wipe(self.widgets)
    end)

    return menu
end

local function SetupButton(btn, menu, text, onClick, color, tooltip, tooltipDesc, icon)
    btn:SetSize(menu.menuWidth - 10, 22)
    btn.text:SetText(text)

    -- Иконка
    if icon and btn.icon then
        btn.icon:SetTexture(icon)
        btn.icon:Show()
        btn.text:ClearAllPoints()
        btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
    else
        if btn.icon then btn.icon:Hide() end
        btn.text:ClearAllPoints()
        btn.text:SetPoint("LEFT", 8, 0)
    end

    -- Цвет текста
    if color then
        if type(color) == "string" then
            -- Hex строка
            local r = tonumber(color:sub(1,2), 16) / 255
            local g = tonumber(color:sub(3,4), 16) / 255
            local b = tonumber(color:sub(5,6), 16) / 255
            btn.text:SetTextColor(r, g, b)
        elseif type(color) == "table" then
            btn.text:SetTextColor(color.r or color[1] or 1, color.g or color[2] or 1, color.b or color[3] or 1)
        end
    else
        btn.text:SetTextColor(1, 1, 1)
    end

    btn:SetScript("OnEnter", function(self)
        if tooltip then
            local lines = { {text = tooltip, r = 1, g = 0.82, b = 0, size = 14} }
            if tooltipDesc then
                lines[#lines + 1] = {text = tooltipDesc, r = 1, g = 1, b = 1, size = 13}
            end
            DoF.Utils:ShowTooltip(self, lines, "RIGHT")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        DoF.Utils:HideTooltip()
    end)
    btn:SetScript("OnClick", function(self)
        -- Закрываем меню после клика (это работает для sticky меню тоже)
        menu:Hide()
        if onClick then onClick() end
    end)
end

local function SetupTitle(title, menu, text, categoryId, isCollapsed, onToggle)
    title:SetSize(menu.menuWidth - 10, 18)
    title.text:SetText(text)
    title.arrow:SetText(isCollapsed and ">" or "v")

    title:SetScript("OnEnter", function(self)
        self.text:SetTextColor(0.7, 0.7, 0.7)
        self.arrow:SetTextColor(0.8, 0.8, 0.8)
    end)
    title:SetScript("OnLeave", function(self)
        self.text:SetTextColor(0.5, 0.5, 0.5)
        self.arrow:SetTextColor(0.6, 0.6, 0.6)
    end)
    title:SetScript("OnClick", function(self)
        if onToggle then onToggle(categoryId) end
    end)
end

-- Показать меню с поддержкой сворачиваемых категорий
-- options: { position = "left" | "bottom" | "top", collapsible = true/false, sticky = true/false }
local function ShowMenu(menu, anchor, items, options)
    options = options or {}

    -- Сохраняем sticky режим для меню
    menu.isSticky = options.sticky or false
    menu.anchorButton = anchor

    -- Возвращаем старые виджеты в пул
    for _, w in ipairs(menu.widgets) do
        ReleaseWidget(w)
    end
    wipe(menu.widgets)

    -- Функция перестроения меню
    local function RebuildMenu()
        -- Очищаем
        for _, w in ipairs(menu.widgets) do
            ReleaseWidget(w)
        end
        wipe(menu.widgets)

        local y = -8
        local currentCategory = nil
        local skipUntilNextCategory = false

        for _, item in ipairs(items) do
            if item.isTitle then
                currentCategory = item.categoryId or item.text

                local widget = AcquireTitle(menu)
                if options.collapsible then
                    -- По умолчанию категории развёрнуты (свёрнуты только если явно true)
                    local isCollapsed = (CollapsedCategories[currentCategory] == true)
                    skipUntilNextCategory = isCollapsed

                    SetupTitle(widget, menu, item.text, currentCategory, isCollapsed, function(catId)
                        CollapsedCategories[catId] = not CollapsedCategories[catId]
                        RebuildMenu()
                    end)
                else
                    -- Категории не сворачиваются - показываем все кнопки
                    skipUntilNextCategory = false
                    widget:SetSize(menu.menuWidth - 10, 18)
                    widget.text:SetText(item.text)
                    widget.arrow:SetText("")
                end
                y = y - 18
                widget:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, y + 18)
                table.insert(menu.widgets, widget)
            else
                if not skipUntilNextCategory then
                    local widget = AcquireButton(menu)
                    SetupButton(widget, menu, item.text, item.func, item.color, item.tooltip, item.tooltipDesc, item.icon)
                    y = y - 24
                    widget:SetPoint("TOPLEFT", menu, "TOPLEFT", 5, y + 24)
                    table.insert(menu.widgets, widget)
                end
            end
        end

        -- Установить размер
        menu:SetHeight(math.abs(y) + 8)
    end

    RebuildMenu()

    -- Позиционировать
    menu:ClearAllPoints()
    if anchor then
        if options.position == "left" then
            -- Слева от anchor (для главного меню)
            menu:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -4, 0)
        elseif options.position == "top" then
            -- Сверху от anchor (раскрытие вверх)
            menu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
        else
            -- Снизу от anchor (по умолчанию)
            menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
        end
    else
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x/scale, y/scale)
    end

    menu:Show()
end

-- Закрытие меню при клике вне
local menuCloseFrame = CreateFrame("Frame", "DoF_MenuCloseFrame", UIParent)
menuCloseFrame:SetFrameStrata("FULLSCREEN")
menuCloseFrame:SetAllPoints()
menuCloseFrame:EnableMouse(false)
menuCloseFrame:SetScript("OnMouseDown", function()
    if activeMenu then
        activeMenu:Hide()
    end
    menuCloseFrame:EnableMouse(false)
end)

local origShowMenu = ShowMenu
ShowMenu = function(menu, anchor, items, options)
    origShowMenu(menu, anchor, items, options)

    -- Если sticky режим, не включаем автозакрытие при клике вне
    if not menu.isSticky then
        -- Сбрасываем предыдущий OnUpdate чтобы он не закрыл новое меню
        menuCloseFrame:SetScript("OnUpdate", nil)
        menuCloseFrame:EnableMouse(true)
        C_Timer.After(0.15, function()
            if not activeMenu then return end
            menuCloseFrame:SetScript("OnUpdate", function()
                if activeMenu and not activeMenu:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                    activeMenu:Hide()
                    menuCloseFrame:EnableMouse(false)
                    menuCloseFrame:SetScript("OnUpdate", nil)
                end
            end)
        end)
    end
end

-- Создаём меню (только контейнеры, виджеты берутся из пула)
local AttackMenu = CreateCustomMenu("DoF_CustomAttackMenu", 180)
local CheckMenu = CreateCustomMenu("DoF_CustomCheckMenu", 180)
local SpecMenu = CreateCustomMenu("DoF_CustomSpecMenu", 200)
local MasterSpecMenu = CreateCustomMenu("DoF_MasterSpecMenu", 200)
local MasterLevelMenu = CreateCustomMenu("DoF_MasterLevelMenu", 200)
local HealMenu = CreateCustomMenu("DoF_CustomHealMenu", 160)

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ АТАКИ
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowAttackMenu(button)
    -- Если AoE активно, показываем специальное меню
    if DoF.Combat:IsAoEActive() then
        self:ShowAoEActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEHealActive() then
        self:ShowAoEHealActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEBuffActive() then
        self:ShowAoEBuffActionMenu(button)
        return
    end
    
    local guid, name = DoF.Utils:GetTargetGUID()
    local hasTarget = guid ~= nil
    
    local isPlayer = false
    local hasNPCData = false
    local npcAlive = false
    
    if hasTarget then
        isPlayer = DoF.Utils:IsTargetPlayer()
        if not isPlayer then
            local data = DoF.Units:Get(guid)
            hasNPCData = data ~= nil
            npcAlive = hasNPCData and data.hp > 0
        end
    end
    
    local items = {}
    local energy = DoF.Stats:GetEnergy()
    local maxEnergy = DoF.Stats:GetMaxEnergy()
    local role = DoF.Stats:GetRole()

    -- Обычные атаки (только если есть живой NPC)
    if hasTarget and not isPlayer and hasNPCData and npcAlive then
        table.insert(items, { text = DoF.L["ui.menu.attack_header"], isTitle = true, categoryId = "attack" })
        for _, stat in ipairs(DoF.Config.AttackStats) do
            local cfg = DoF.Config.StatColors[stat]
            local statName = DoF.Config.StatNames[stat] or stat
            local desc = ""
            if stat == "Strength" then desc = DoF.L["ui.action.attack_str_desc"]
            elseif stat == "Dexterity" then desc = DoF.L["ui.action.attack_dex_desc"]
            elseif stat == "Intelligence" then desc = DoF.L["ui.action.attack_int_desc"]
            end
            table.insert(items, {
                text = statName,
                color = cfg,
                tooltip = DoF.Locale:Format("ui.action.attack_of", statName),
                tooltipDesc = desc,
                func = function() DoF.Combat:Attack(stat) end
            })
        end
    end

    -- AoE атаки (требуют энергию)
    local aoeCost = DoF.Config.ENERGY_COST_AOE
    local aoeAvailable = energy >= aoeCost
    local aoeColorSuffix = aoeAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]

    table.insert(items, { text = DoF.Locale:Format("ui.menu.aoe_header_short", aoeCost), isTitle = true, categoryId = "aoe" })
    for _, stat in ipairs(DoF.Config.AttackStats) do
        local cfg = DoF.Config.StatColors[stat]
        local statName = DoF.Config.StatNames[stat] or stat
        table.insert(items, {
            text = "AoE " .. statName .. aoeColorSuffix,
            color = aoeAvailable and cfg or "666666",
            tooltip = "AoE " .. statName,
            tooltipDesc = DoF.Locale:Format("ui.aoe.attack_desc", DoF.Config.AOE_MIN_TARGETS, DoF.Config.AOE_MAX_TARGETS, aoeCost),
            func = function()
                if not aoeAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Combat:StartAoEAttack(stat)
            end
        })
    end

    -- Особое действие
    table.insert(items, { text = DoF.L["ui.menu.special_header"], isTitle = true, categoryId = "special" })
    table.insert(items, {
        text = DoF.L["ui.action.special_colored"],
        tooltip = DoF.L["ui.action.special"],
        tooltipDesc = DoF.L["ui.action.special_desc"],
        func = function()
            DoF.Combat:SpecialAction()
        end
    })

    -- Исцеление
    table.insert(items, { text = DoF.L["ui.menu.heal_header"], isTitle = true, categoryId = "heal" })
    table.insert(items, {
        text = DoF.Config.StatNames["Spirit"] or DoF.L["stats.spirit.label"],
        color = DoF.Config.StatColors["Spirit"],
        tooltip = DoF.L["ui.common.healing"],
        tooltipDesc = DoF.L["ui.action.heal_desc"],
        func = function() DoF.Combat:Heal() end
    })

    -- Щит только для хилов
    if role == "healer" then
        table.insert(items, { text = DoF.L["ui.menu.shield_header"], isTitle = true, categoryId = "shield" })
        table.insert(items, {
            text = DoF.L["ui.action.shield"],
            color = {r = 0.4, g = 0.8, b = 1},
            tooltip = DoF.L["ui.common.shield"],
            tooltipDesc = DoF.L["ui.action.shield_desc"],
            func = function() DoF.Combat:Shield() end
        })
    end

    -- Снятие раны (только для целителя)
    if role == "healer" then
        if hasTarget and isPlayer then
            table.insert(items, { text = DoF.L["ui.menu.wounds_header"], isTitle = true, categoryId = "wounds" })
            table.insert(items, {
                text = DoF.L["ui.action.remove_wound"],
                color = {r = 1, g = 0.5, b = 0.5},
                tooltip = DoF.L["ui.action.remove_wound_title"],
                tooltipDesc = DoF.L["ui.action.remove_wound_desc"],
                func = function() DoF.Combat:RemoveWound() end
            })
        end
    end

    -- ══════════ ЭФФЕКТЫ ══════════
    local effectsCost = 1
    local effectsAvailable = energy >= effectsCost
    local effectsColorSuffix = effectsAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]

    table.insert(items, { text = DoF.Locale:Format("ui.menu.effects_header_short", effectsCost), isTitle = true, categoryId = "effects" })

    -- DoT на NPC (если цель - живой NPC)
    if hasTarget and not isPlayer and hasNPCData and npcAlive then
        table.insert(items, {
            text = DoF.L["ui.action.apply_dot"] .. effectsColorSuffix,
            icon = DoF.Effects.Definitions["bleeding"] and DoF.Effects.Definitions["bleeding"].icon,
            color = effectsAvailable and {r = 0.8, g = 0.3, b = 0.1} or {r = 0.4, g = 0.4, b = 0.4},
            tooltip = DoF.L["ui.common.dot"],
            tooltipDesc = DoF.L["ui.action.apply_dot_desc"],
            func = function()
                if not effectsAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Dialogs:ShowEffectMenu(button, "npc", guid)
            end
        })
    end

    -- Дебафф на NPC (Ослабление - доступно всем)
    if hasTarget and not isPlayer and hasNPCData and npcAlive then
        table.insert(items, {
            text = DoF.L["ui.action.weaken_npc"] .. effectsColorSuffix,
            icon = DoF.Effects.Definitions["weakness_fortitude"] and DoF.Effects.Definitions["weakness_fortitude"].icon,
            color = effectsAvailable and {r = 0.6, g = 0.4, b = 0.4} or {r = 0.4, g = 0.4, b = 0.4},
            tooltip = DoF.L["ui.action.weaken"],
            tooltipDesc = DoF.L["ui.action.weaken_desc"],
            func = function()
                if not effectsAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Dialogs:ShowPlayerWeakenNPCDialog(guid, name)
            end
        })
    end

    -- Если меню уже открыто от этой кнопки, закрываем его
    if AttackMenu:IsShown() and AttackMenu.anchorButton == button then
        AttackMenu:Hide()
        return
    end

    -- Используем кнопку как якорь для sticky меню
    ShowMenu(AttackMenu, button, items, { position = "top", sticky = true, collapsible = true })
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ АТАКИ (урезанное для панели очереди)
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowAttackOnlyMenu(button)
    -- Если AoE активно, показываем специальное меню
    if DoF.Combat:IsAoEActive() then
        self:ShowAoEActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEHealActive() then
        self:ShowAoEHealActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEBuffActive() then
        self:ShowAoEBuffActionMenu(button)
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    local hasTarget = guid ~= nil

    local isPlayer = false
    local hasNPCData = false
    local npcAlive = false

    if hasTarget then
        isPlayer = DoF.Utils:IsTargetPlayer()
        if not isPlayer then
            local data = DoF.Units:Get(guid)
            hasNPCData = data ~= nil
            npcAlive = hasNPCData and data.hp > 0
        end
    end

    local items = {}
    local energy = DoF.Stats:GetEnergy()

    -- Проверка наличия корректной цели
    if not hasTarget then
        DoF.Utils:Error(DoF.L["errors.no_attack_target"])
        return
    end

    if isPlayer then
        DoF.Utils:Error(DoF.L["errors.cannot_attack_player"])
        return
    end

    if not hasNPCData then
        DoF.Utils:Error(DoF.L["errors.target_has_no_hp"])
        return
    end

    if not npcAlive then
        DoF.Utils:Error(DoF.L["ui.common.target_dead"])
        return
    end

    -- Обычные атаки
    table.insert(items, { text = DoF.L["ui.menu.attack_header"], isTitle = true })
    for _, stat in ipairs(DoF.Config.AttackStats) do
        local cfg = DoF.Config.StatColors[stat]
        local statName = DoF.Config.StatNames[stat] or stat
        local desc = ""
        if stat == "Strength" then desc = DoF.L["ui.action.attack_str_desc"]
        elseif stat == "Dexterity" then desc = DoF.L["ui.action.attack_dex_desc"]
        elseif stat == "Intelligence" then desc = DoF.L["ui.action.attack_int_desc"]
        end
        table.insert(items, {
            text = statName,
            color = cfg,
            tooltip = DoF.Locale:Format("ui.action.attack_of", statName),
            tooltipDesc = desc,
            func = function() DoF.Combat:Attack(stat) end
        })
    end

    -- AoE атаки (требуют энергию)
    local aoeCost = DoF.Config.ENERGY_COST_AOE
    local aoeAvailable = energy >= aoeCost
    local aoeColorSuffix = aoeAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]

    table.insert(items, { text = DoF.Locale:Format("ui.menu.aoe_attack_header", aoeCost), isTitle = true })
    for _, stat in ipairs(DoF.Config.AttackStats) do
        local cfg = DoF.Config.StatColors[stat]
        local statName = DoF.Config.StatNames[stat] or stat
        table.insert(items, {
            text = "AoE " .. statName .. aoeColorSuffix,
            color = aoeAvailable and cfg or "666666",
            tooltip = "AoE " .. statName,
            tooltipDesc = DoF.Locale:Format("ui.aoe.attack_desc", DoF.Config.AOE_MIN_TARGETS, DoF.Config.AOE_MAX_TARGETS, aoeCost),
            func = function()
                if not aoeAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Combat:StartAoEAttack(stat)
            end
        })
    end

    -- Особое действие
    table.insert(items, { text = DoF.L["ui.menu.special_header"], isTitle = true })
    table.insert(items, {
        text = DoF.L["ui.action.special_colored"],
        tooltip = DoF.L["ui.action.special"],
        tooltipDesc = DoF.L["ui.action.special_desc"],
        func = function()
            DoF.Combat:SpecialAction()
        end
    })

    ShowMenu(AttackMenu, button, items)
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ ЭФФЕКТОВ (для кнопки "Эффект" в очереди ходов)
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowEffectsMenu(button)
    -- Если AoE режим активен, перенаправляем на соответствующее меню
    if DoF.Combat:IsAoEActive() then
        self:ShowAoEActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEHealActive() then
        self:ShowAoEHealActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEBuffActive() then
        self:ShowAoEBuffActionMenu(button)
        return
    end
    
    local guid, name = DoF.Utils:GetTargetGUID()
    local hasTarget = guid ~= nil
    local isPlayer = hasTarget and DoF.Utils:IsTargetPlayer()
    local role = DoF.Stats:GetRole()
    local energy = DoF.Stats:GetEnergy()

    local hasNPCData = false
    local npcAlive = false
    if hasTarget and not isPlayer then
        local data = DoF.Units:Get(guid)
        hasNPCData = data ~= nil
        npcAlive = hasNPCData and data.hp > 0
    end

    local items = {}
    local effectsCost = 1
    local effectsAvailable = energy >= effectsCost
    local effectsColorSuffix = effectsAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]

    local aoeCost = DoF.Config.ENERGY_COST_AOE
    local aoeAvailable = energy >= aoeCost
    local aoeColorSuffix = aoeAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]

    table.insert(items, { text = DoF.Locale:Format("ui.menu.effects_header", effectsCost), isTitle = true })

    -- DoT на NPC (если цель - живой NPC)
    if hasTarget and not isPlayer and hasNPCData and npcAlive then
        table.insert(items, {
            text = DoF.L["ui.action.apply_dot"] .. effectsColorSuffix,
            icon = DoF.Effects.Definitions["bleeding"] and DoF.Effects.Definitions["bleeding"].icon,
            color = effectsAvailable and {r = 0.8, g = 0.3, b = 0.1} or {r = 0.4, g = 0.4, b = 0.4},
            tooltip = DoF.L["ui.common.dot"],
            tooltipDesc = DoF.L["ui.action.apply_dot_desc"],
            func = function()
                if not effectsAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Dialogs:ShowEffectMenu(button, "npc", guid)
            end
        })
    end

    -- Дебафф на NPC (Ослабление - доступно всем)
    if hasTarget and not isPlayer and hasNPCData and npcAlive then
        table.insert(items, {
            text = DoF.L["ui.action.weaken_npc"] .. effectsColorSuffix,
            icon = DoF.Effects.Definitions["weakness_fortitude"] and DoF.Effects.Definitions["weakness_fortitude"].icon,
            color = effectsAvailable and {r = 0.6, g = 0.4, b = 0.4} or {r = 0.4, g = 0.4, b = 0.4},
            tooltip = DoF.L["ui.action.weaken"],
            tooltipDesc = DoF.L["ui.action.weaken_desc"],
            func = function()
                if not effectsAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Dialogs:ShowPlayerWeakenNPCDialog(guid, name)
            end
        })
    end

    -- Если меню пустое (кроме заголовка)
    if #items == 1 then
        table.insert(items, {
            text = DoF.L["ui.menu.no_actions"],
            color = {r = 0.5, g = 0.5, b = 0.5},
            func = function() end
        })
    end

    ShowMenu(AttackMenu, button, items)
end

-- Меню для активного AoE режима
function DoF.Dialogs:ShowAoEActionMenu(button)
    local stat = DoF.Combat:GetAoEStat()
    local hitsLeft = DoF.Combat:GetAoEHitsLeft()
    local statColor = DoF.Config.StatColors[stat] or {r=1,g=1,b=1}
    local statName = DoF.Config.StatNames[stat] or stat
    
    local items = {
        { text = "- AoE " .. statName .. " -", isTitle = true },
        { text = DoF.Locale:Format("ui.aoe.remaining", hitsLeft), isTitle = true },
        {
            text = DoF.L["ui.aoe.hit_target"],
            color = {r = 1, g = 0.4, b = 0.4},
            tooltip = DoF.L["ui.aoe.hit_title"],
            tooltipDesc = DoF.L["ui.aoe.hit_desc"],
            func = function() DoF.Combat:AoEHit() end
        },
        {
            text = DoF.L["ui.aoe.finish_attack"],
            color = {r = 0.6, g = 0.6, b = 0.6},
            tooltip = DoF.L["ui.common.cancel_verb"],
            tooltipDesc = DoF.L["ui.aoe.finish_attack_desc"],
            func = function() DoF.Combat:CancelAoE() end
        },
    }
    
    ShowMenu(AttackMenu, button, items)
end

function DoF.Dialogs:ShowAoEHealActionMenu(button)
    local healsLeft = DoF.Combat:GetAoEHealsLeft()
    
    local items = {
        { text = DoF.L["ui.aoe.heal_header"], isTitle = true },
        { text = DoF.Locale:Format("ui.aoe.remaining", healsLeft), isTitle = true },
        {
            text = DoF.L["ui.aoe.heal_target"],
            color = {r = 0.4, g = 1, b = 0.4},
            tooltip = DoF.L["ui.aoe.heal_label"],
            tooltipDesc = DoF.L["ui.aoe.heal_desc"],
            func = function() DoF.Combat:AoEHealTarget() end
        },
        {
            text = DoF.L["ui.common.finish"],
            color = {r = 0.6, g = 0.6, b = 0.6},
            tooltip = DoF.L["ui.common.cancel_verb"],
            tooltipDesc = DoF.L["ui.aoe.finish_heal_desc"],
            func = function() DoF.Combat:CancelAoEHeal() end
        },
    }
    
    ShowMenu(AttackMenu, button, items)
end

-- Списки баффов по группам
local EMPOWER_IDS = {
    "empower_strength", "empower_dexterity", "empower_intelligence",
    "empower_spirit", "empower_damage", "empower_healing",
}
local FORTIFY_IDS = {
    "fortify_fortitude", "fortify_reflex", "fortify_will", "fortify_hp",
}
local HEALER_IDS = {
}

-- Короткие названия для кнопок диалога
local BUFF_SHORT_NAMES = {
    empower_strength = DoF.L["stats.strength.label"],
    empower_dexterity = DoF.L["stats.dexterity.label"],
    empower_intelligence = DoF.L["stats.intelligence.label"],
    empower_spirit = DoF.L["stats.spirit.label"],
    empower_damage = DoF.L["ui.effect.stat_damage"],
    empower_healing = DoF.L["ui.common.healing"],
    fortify_fortitude = DoF.L["stats.fortitude.label"],
    fortify_reflex = DoF.L["stats.reflex.label"],
    fortify_will = DoF.L["stats.will.label"],
    fortify_hp = "HP",
}

local PlayerBuffDialog = nil

-- Диалог выбора баффа (кнопка "Бафф" ЛКМ, по принципу Ослабить NPC)
function DoF.Dialogs:ShowBuffSelectMenu(button)
    if PlayerBuffDialog then
        PlayerBuffDialog:Hide()
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    local isPlayer = guid and DoF.Utils:IsTargetPlayer()
    local targetName = (isPlayer and name) or UnitName("player")
    local casterName = UnitName("player")
    local role = DoF.Stats and DoF.Stats:GetRole()

    if not DoF.Utils:RequireEnergy(1, DoF.L["ui.common.buff"]) then return end

    if not DoF.Utils:RequireTurn(DoF.L["ui.common.buff"]) then return end

    -- Определяем доступные баффы
    local sections = {}
    if role == "dd" then
        sections[#sections + 1] = { title = DoF.L["ui.buff.section_empower"], ids = EMPOWER_IDS, cols = 3 }
    elseif role == "tank" then
        sections[#sections + 1] = { title = DoF.L["ui.buff.section_fortify"], ids = FORTIFY_IDS, cols = 2 }
    elseif role == "healer" then
        sections[#sections + 1] = { title = DoF.L["ui.buff.section_empower"], ids = EMPOWER_IDS, cols = 3 }
        sections[#sections + 1] = { title = DoF.L["ui.buff.section_fortify"], ids = FORTIFY_IDS, cols = 2 }
    else
        DoF.Utils:Error(DoF.L["errors.buff_role_locked"])
        return
    end

    -- Подсчитываем размер
    local dialogWidth = 290
    local yOffset = -55
    local rowsTotal = 0
    for _, sec in ipairs(sections) do
        rowsTotal = rowsTotal + 1 -- заголовок секции
        rowsTotal = rowsTotal + math.ceil(#sec.ids / sec.cols)
    end
    local dialogHeight = 55 + rowsTotal * 30 + 10

    -- Создаём диалог
    local f = CreateFrame("Frame", "DoF_PlayerBuffDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(dialogWidth, dialogHeight + 25)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(DoF.L["ui.common.buff"])

    -- Имя цели
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetText:SetPoint("TOP", 0, -30)
    targetText:SetText(DoF.Locale:Format("ui.buff.target", targetName))

    -- Подсказка
    local hintText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintText:SetPoint("TOP", 0, -46)
    hintText:SetTextColor(0.7, 0.7, 0.7)
    hintText:SetText(DoF.L["ui.buff.hint"])

    -- Генерируем кнопки по секциям
    local curY = -55
    for _, sec in ipairs(sections) do
        -- Заголовок секции (если более одной секции)
        if #sections > 1 then
            local secTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            secTitle:SetPoint("TOP", 0, curY)
            secTitle:SetText("|cFFAAAAAA" .. sec.title .. "|r")
            curY = curY - 16
        end

        local cols = sec.cols
        local btnWidth = math.floor((dialogWidth - 16 - (cols - 1) * 4) / cols)
        local startX = 8

        for i, effectId in ipairs(sec.ids) do
            local def = DoF.Effects.Definitions[effectId]
            if def then
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local bx = startX + col * (btnWidth + 4)
                local by = curY - row * 28

                local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                btn:SetSize(btnWidth, 24)
                btn:SetPoint("TOPLEFT", bx, by)

                local icon = btn:CreateTexture(nil, "OVERLAY")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", 4, 0)
                icon:SetTexture(def.icon)

                local shortName = BUFF_SHORT_NAMES[effectId] or def.name
                btn:SetText(shortName)
                local txt = btn:GetFontString()
                if txt then
                    txt:ClearAllPoints()
                    txt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
                    txt:SetPoint("RIGHT", -4, 0)
                    txt:SetJustifyH("LEFT")
                end

                -- Проверка кулдауна
                local cdKey = DoF.Effects:GetCooldownKey(def, effectId)
                local onCooldown = DoF.Effects:IsOnCooldown(casterName, cdKey)
                if onCooldown then
                    btn:SetAlpha(0.4)
                end

                local capturedId = effectId
                local capturedTargetName = targetName
                local capturedOnCD = onCooldown

                btn:SetScript("OnEnter", function(self)
                    local lines = {
                        {text = def.name, r = 1, g = 0.82, b = 0, size = 14},
                        {text = def.description, r = 1, g = 1, b = 1, size = 13},
                    }
                    if capturedOnCD then
                        local cdRem = DoF.Effects:GetCooldown(casterName, cdKey)
                        lines[#lines + 1] = {text = DoF.Locale:Format("ui.effect.cooldown", cdRem, DoF.Locale:Rounds(cdRem)), r = 1, g = 0.3, b = 0.3, size = 13}
                    end
                    DoF.Utils:ShowTooltip(self, lines, "TOP")
                end)
                btn:SetScript("OnLeave", function(self)
                    DoF.Utils:HideTooltip()
                end)
                btn:SetScript("OnClick", function()
                    if capturedOnCD then
                        DoF.Utils:Error(DoF.L["errors.effect_on_cooldown"])
                        return
                    end
                    DoF.Effects:PlayerApply("player", capturedTargetName, capturedId)
                    f:Hide()
                end)
            end
        end

        local rowCount = math.ceil(#sec.ids / cols)
        curY = curY - rowCount * 28 - 4
    end

    PlayerBuffDialog = f
    f:Show()
end

-- Диалог AoE баффа (только для целителя, по принципу Ослабить NPC)
local PlayerAoEBuffDialog = nil

function DoF.Dialogs:ShowAoEBuffSelectMenu(button)
    if PlayerAoEBuffDialog then
        PlayerAoEBuffDialog:Hide()
    end

    local casterName = UnitName("player")

    local aoeCost = DoF.Config.ENERGY_COST_AOE
    if not DoF.Utils:RequireEnergy(aoeCost, DoF.L["ui.aoe.buff_title"]) then return end

    if not DoF.Utils:RequireTurn(DoF.L["ui.aoe.buff_title"]) then return end

    local sections = {
        { title = DoF.L["ui.buff.section_empower"], ids = EMPOWER_IDS, cols = 3 },
        { title = DoF.L["ui.buff.section_fortify"], ids = FORTIFY_IDS, cols = 2 },
        { title = DoF.L["ui.buff.section_healer"], ids = HEALER_IDS, cols = 1 },
    }

    local dialogWidth = 290
    local rowsTotal = 0
    for _, sec in ipairs(sections) do
        rowsTotal = rowsTotal + 1
        rowsTotal = rowsTotal + math.ceil(#sec.ids / sec.cols)
    end
    local dialogHeight = 55 + rowsTotal * 30 + 10

    local f = CreateFrame("Frame", "DoF_PlayerAoEBuffDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(dialogWidth, dialogHeight + 25)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(DoF.L["ui.aoe.buff_title"])

    local hintText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintText:SetPoint("TOP", 0, -32)
    hintText:SetTextColor(0.7, 0.7, 0.7)
    hintText:SetText(DoF.Locale:Format("ui.aoe.buff_hint", DoF.Config.ENERGY_COST_AOE_BUFF, DoF.Config.AOE_MAX_TARGETS))

    local curY = -50
    for _, sec in ipairs(sections) do
        local secTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        secTitle:SetPoint("TOP", 0, curY)
        secTitle:SetText("|cFFAAAAAA" .. sec.title .. "|r")
        curY = curY - 16

        local cols = sec.cols
        local btnWidth = math.floor((dialogWidth - 16 - (cols - 1) * 4) / cols)
        local startX = 8

        for i, effectId in ipairs(sec.ids) do
            local def = DoF.Effects.Definitions[effectId]
            if def then
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local bx = startX + col * (btnWidth + 4)
                local by = curY - row * 28

                local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                btn:SetSize(btnWidth, 24)
                btn:SetPoint("TOPLEFT", bx, by)

                local icon = btn:CreateTexture(nil, "OVERLAY")
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", 4, 0)
                icon:SetTexture(def.icon)

                local shortName = BUFF_SHORT_NAMES[effectId] or def.name
                btn:SetText(shortName)
                local txt = btn:GetFontString()
                if txt then
                    txt:ClearAllPoints()
                    txt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
                    txt:SetPoint("RIGHT", -4, 0)
                    txt:SetJustifyH("LEFT")
                end

                local cdKey = DoF.Effects:GetCooldownKey(def, effectId)
                local onCooldown = DoF.Effects:IsOnCooldown(casterName, cdKey)
                if onCooldown then
                    btn:SetAlpha(0.4)
                end

                local capturedId = effectId
                local capturedOnCD = onCooldown

                btn:SetScript("OnEnter", function(self)
                    local lines = {
                        {text = "AoE " .. def.name, r = 1, g = 0.82, b = 0, size = 14},
                        {text = def.description, r = 1, g = 1, b = 1, size = 13},
                    }
                    if capturedOnCD then
                        local cdRem = DoF.Effects:GetCooldown(casterName, cdKey)
                        lines[#lines + 1] = {text = DoF.Locale:Format("ui.effect.cooldown", cdRem, DoF.Locale:Rounds(cdRem)), r = 1, g = 0.3, b = 0.3, size = 13}
                    end
                    DoF.Utils:ShowTooltip(self, lines, "TOP")
                end)
                btn:SetScript("OnLeave", function(self)
                    DoF.Utils:HideTooltip()
                end)
                btn:SetScript("OnClick", function()
                    if capturedOnCD then
                        DoF.Utils:Error(DoF.L["errors.effect_on_cooldown"])
                        return
                    end
                    DoF.Combat:StartAoEBuff(capturedId)
                    f:Hide()
                end)
            end
        end

        local rowCount = math.ceil(#sec.ids / cols)
        curY = curY - rowCount * 28 - 4
    end

    PlayerAoEBuffDialog = f
    f:Show()
end

-- Меню для активного AoE баффа
function DoF.Dialogs:ShowAoEBuffActionMenu(button)
    local buffsLeft = DoF.Combat:GetAoEBuffsLeft()
    local effectId = DoF.Combat:GetAoEBuffEffectId()
    local def = DoF.Effects.Definitions[effectId]
    local buffName = def and def.name or DoF.L["ui.common.buff"]
    local buffColor = def and DoF.Effects:GetColorHex(def.color) or "66FF66"
    
    local items = {
        { text = "- AoE " .. buffName .. " -", isTitle = true },
        { text = DoF.Locale:Format("ui.aoe.remaining", buffsLeft), isTitle = true },
        {
            text = DoF.L["ui.aoe.buff_target"],
            color = {r = 0.3, g = 0.9, b = 0.5},
            tooltip = DoF.L["ui.aoe.buff_title"],
            tooltipDesc = DoF.Locale:Format("ui.aoe.buff_desc", buffName),
            func = function() DoF.Combat:AoEBuffTarget() end
        },
        {
            text = DoF.L["ui.common.finish"],
            color = {r = 0.6, g = 0.6, b = 0.6},
            tooltip = DoF.L["ui.common.cancel_verb"],
            tooltipDesc = DoF.L["ui.aoe.finish_buff_desc"],
            func = function() DoF.Combat:CancelAoEBuff() end
        },
    }
    
    ShowMenu(AttackMenu, button, items)
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ ЭФФЕКТОВ (для игроков)
-- ═══════════════════════════════════════════════════════════

local EffectMenu = CreateCustomMenu("DoF_CustomEffectMenu", 220)

function DoF.Dialogs:ShowEffectMenu(button, targetType, targetId)
    local role = DoF.Stats:GetRole()
    local casterName = UnitName("player")
    
    -- Определяем какие эффекты показывать
    local effectsToShow = {}
    
    if targetType == "npc" then
        -- Только DoT эффекты для NPC (исключаем мастерские и дебаффы типа "ослабление")
        local allEffects = DoF.Effects:GetAvailable(role, "npc")
        for _, effectInfo in ipairs(allEffects) do
            -- Показываем только DoT и не мастерские
            if effectInfo.def.type == "dot" and effectInfo.def.category ~= "master" then
                table.insert(effectsToShow, effectInfo)
            end
        end
    else
        -- Баффы для игроков (исключаем мастерские)
        local allEffects = DoF.Effects:GetAvailable(role, "player")
        for _, effectInfo in ipairs(allEffects) do
            if effectInfo.def.type == "buff" and effectInfo.def.category ~= "master" then
                table.insert(effectsToShow, effectInfo)
            end
        end
    end
    
    local items = {}
    local targetName = targetType == "npc" 
        and (DoF.Units:Get(targetId) and DoF.Units:Get(targetId).name or "NPC") 
        or targetId
    
    table.insert(items, { text = DoF.Locale:Format("ui.menu.effects_on", targetName), isTitle = true })
    
    if #effectsToShow == 0 then
        table.insert(items, { 
            text = DoF.L["ui.menu.no_effects"], 
            isTitle = true 
        })
    else
        for _, effectInfo in ipairs(effectsToShow) do
            local def = effectInfo.def
            local onCooldown = effectInfo.onCooldown
            local cdRemaining = effectInfo.cooldownRemaining
            
            -- Проверяем, висит ли уже эффект на цели
            local alreadyActive = DoF.Effects:HasEffect(targetType, targetId, def.id)
            
            local colorHex = DoF.Effects:GetColorHex(def.color)
            local text = def.name
            local canUse = true
            local reason = ""
            
            if alreadyActive then
                text = text .. DoF.L["ui.effect.active_suffix"]
                canUse = false
                reason = DoF.L["ui.effect.already_active"]
            elseif onCooldown then
                text = text .. DoF.Locale:Format("ui.effect.cd_suffix", cdRemaining)
                canUse = false
                reason = DoF.Locale:Format("ui.effect.cooldown", cdRemaining, DoF.Locale:Rounds(cdRemaining))
            end
            
            -- Описание с параметрами
            local valueText = ""
            if def.type == "dot" then
                valueText = DoF.Locale:Format("ui.effect.dot_value", def.fixedValue, def.fixedDuration, DoF.Locale:Rounds(def.fixedDuration))
            elseif def.type == "buff" then
                if def.isHoT then
                    valueText = DoF.Locale:Format("ui.effect.hot_value", def.fixedValue, def.fixedDuration, DoF.Locale:Rounds(def.fixedDuration))
                elseif def.statMod then
                    local modText = def.modType == "increase" and "+" or "-"
                    -- Локализация имени стата
                    local statDisplayName = def.statMod
                    for key, name in pairs(DoF.Config.StatNames) do
                        if string.lower(key) == def.statMod then
                            statDisplayName = name
                            break
                        end
                    end
                    if def.statMod == "damage" then statDisplayName = DoF.L["ui.effect.stat_damage"]
                    elseif def.statMod == "healing" then statDisplayName = DoF.L["ui.common.healing"] end
                    valueText = DoF.Locale:Format("ui.effect.stat_mod_value", modText, def.fixedValue, statDisplayName, def.fixedDuration, DoF.Locale:Rounds(def.fixedDuration))
                end
            end
            
            table.insert(items, {
                text = "|cFF" .. colorHex .. text .. "|r",
                icon = def.icon,
                color = canUse and {r = def.color[1], g = def.color[2], b = def.color[3]} or {r = 0.4, g = 0.4, b = 0.4},
                tooltip = def.name,
                tooltipDesc = DoF.Locale:Format("ui.effect.tooltip_desc", def.description, valueText, def.energyCost or 1)
                    .. (reason ~= "" and ("\n|cFFFF6666" .. reason .. "|r") or ""),
                func = function()
                    if not canUse then
                        DoF.Utils:Error(reason)
                        return
                    end
                    DoF.Effects:PlayerApply(targetType, targetId, def.id)
                end
            })
        end
    end
    
    -- Кнопка отмены
    table.insert(items, {
        text = DoF.L["ui.common.cancel_colored"],
        func = function() end
    })
    
    ShowMenu(EffectMenu, button, items)
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ ЛЕЧЕНИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowHealMenu(button)
    -- Если AoE исцеление активно, показываем специальное меню
    if DoF.Combat:IsAoEHealActive() then
        self:ShowAoEHealActionMenu(button)
        return
    end
    if DoF.Combat:IsAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end
    if DoF.Combat:IsAoEBuffActive() then
        self:ShowAoEBuffActionMenu(button)
        return
    end
    
    local guid, name = DoF.Utils:GetTargetGUID()
    local hasTarget = guid ~= nil
    local isPlayer = hasTarget and DoF.Utils:IsTargetPlayer()
    local role = DoF.Stats:GetRole()
    local isHealer = (role == "healer" or role == "Healer")
    local canShield = isHealer
    local canRemoveWound = isHealer
    
    local items = {}
    
    -- Исцеление (Дух) - всегда доступно
    table.insert(items, { text = DoF.L["ui.menu.heal_header"], isTitle = true })
    table.insert(items, {
        text = DoF.L["ui.common.healing"],
        color = "66FF66",
        tooltip = DoF.L["ui.common.healing"],
        tooltipDesc = DoF.L["ui.action.heal_desc"],
        func = function() DoF.Combat:Heal() end
    })
    
    -- AoE Исцеление (только целитель, требует энергию)
    if isHealer then
        local aoeCost = DoF.Config.ENERGY_COST_AOE
        local energy = DoF.Stats:GetEnergy()
        local aoeAvailable = energy >= aoeCost
        local aoeColorSuffix = aoeAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]
        
        table.insert(items, { text = DoF.Locale:Format("ui.menu.aoe_heal_header", aoeCost), isTitle = true })
        table.insert(items, {
            text = DoF.L["ui.aoe.heal_label"] .. aoeColorSuffix,
            color = aoeAvailable and "66FF66" or "666666",
            tooltip = DoF.L["ui.aoe.heal_label"],
            tooltipDesc = DoF.Locale:Format("ui.aoe.heal_desc_full", DoF.Config.AOE_MIN_TARGETS, DoF.Config.AOE_MAX_TARGETS, aoeCost),
            func = function()
                if not aoeAvailable then
                    DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                    return
                end
                DoF.Combat:StartAoEHeal()
            end
        })
    end
    
    -- Щит (целитель и универсал)
    if canShield then
        table.insert(items, { text = DoF.L["ui.menu.shield_header"], isTitle = true })
        table.insert(items, {
            text = DoF.L["ui.action.shield"],
            color = "66CCFF",
            tooltip = DoF.L["ui.common.shield"],
            tooltipDesc = DoF.L["ui.action.shield_desc"],
            func = function() DoF.Combat:Shield() end
        })
    end
    
    -- Снятие раны (только целитель)
    if canRemoveWound then
        if hasTarget and isPlayer then
            table.insert(items, { text = DoF.L["ui.menu.wounds_header"], isTitle = true })
            table.insert(items, {
                text = DoF.L["ui.action.remove_wound"],
                color = "FF6666",
                tooltip = DoF.L["ui.action.remove_wound_title"],
                tooltipDesc = DoF.L["ui.action.remove_wound_desc"],
                func = function() DoF.Combat:RemoveWound() end
            })
        end
    end

    -- Диспел (только целитель, цель-игрок с дебаффами)
    if canRemoveWound then
        if hasTarget and isPlayer then
            local effectsCost = 1
            local energy = DoF.Stats:GetEnergy()
            local effectsAvailable = energy >= effectsCost
            local hasDebuffs = false
            local targetEffects = DoF.Effects:GetAll("player", name)
            for effectId, _ in pairs(targetEffects) do
                local def = DoF.Effects.Definitions[effectId]
                if def and (def.type == "debuff" or (def.type == "dot" and def.category == "master")) then
                    hasDebuffs = true
                    break
                end
            end
            if hasDebuffs then
                table.insert(items, { text = DoF.L["ui.menu.dispel_header"], isTitle = true })
                table.insert(items, {
                    text = DoF.L["ui.action.dispel"] .. (effectsAvailable and "" or DoF.L["ui.menu.no_energy_suffix"]),
                    color = effectsAvailable and "66B3FF" or "666666",
                    tooltip = DoF.L["ui.action.dispel_title"],
                    tooltipDesc = DoF.L["ui.action.dispel_desc"],
                    func = function()
                        if not effectsAvailable then
                            DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                            return
                        end
                        DoF.Effects:Dispel(name, "healer")
                    end
                })
            end
        end
    end

    ShowMenu(HealMenu, button, items)
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ ПРОВЕРКИ
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowCheckMenu(button)
    local items = {
        { text = DoF.L["ui.menu.offensive_header"], isTitle = true },
    }
    
    local attackDescs = {
        Strength = DoF.L["ui.check.strength"],
        Dexterity = DoF.L["ui.check.dexterity"],
        Intelligence = DoF.L["ui.check.intelligence"],
        Spirit = DoF.L["ui.check.spirit"],
    }
    
    for _, stat in ipairs({"Strength", "Dexterity", "Intelligence", "Spirit"}) do
        local cfg = DoF.Config.StatColors[stat]
        local statName = DoF.Config.StatNames[stat] or stat
        table.insert(items, {
            text = statName,
            color = cfg,
            tooltip = DoF.Locale:Format("ui.check.of", statName),
            tooltipDesc = attackDescs[stat],
            func = function() DoF.Combat:Check(stat) end
        })
    end
    
    table.insert(items, { text = DoF.L["ui.menu.defensive_header"], isTitle = true })
    
    local defenseDescs = {
        Fortitude = DoF.L["ui.check.fortitude"],
        Reflex = DoF.L["ui.check.reflex"],
        Will = DoF.L["ui.check.will"],
    }
    
    for _, stat in ipairs(DoF.Config.DefenseStats) do
        local cfg = DoF.Config.StatColors[stat]
        local statName = DoF.Config.StatNames[stat] or stat
        table.insert(items, {
            text = statName,
            color = cfg,
            tooltip = DoF.Locale:Format("ui.check.of", statName),
            tooltipDesc = defenseDescs[stat],
            func = function() DoF.Combat:Check(stat) end
        })
    end

    -- Липкое меню, открывается вверх, как у "Действие"
    if CheckMenu:IsShown() and CheckMenu.anchorButton == button then
        CheckMenu:Hide()
        return
    end
    ShowMenu(CheckMenu, button, items, { position = "top", sticky = true, collapsible = true })
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ВЫБОРА РОЛИ
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowSpecDialog(anchor)
    if not DoF.Stats:CanChooseRole() then
        DoF.Utils:Error(DoF.Locale:Format("errors.role_level_required", DoF.Config.ROLE_REQUIRED_LEVEL))
        return
    end
    
    if DoF.Stats:GetRole() then
        DoF.Utils:Error(DoF.L["errors.role_already_chosen"])
        return
    end
    
    local items = {
        { text = DoF.L["ui.role.select"], isTitle = true },
    }
    
    for key, data in pairs(DoF.Config.Roles) do
        local r = tonumber(data.color:sub(1,2), 16)/255
        local g = tonumber(data.color:sub(3,4), 16)/255
        local b = tonumber(data.color:sub(5,6), 16)/255
        table.insert(items, {
            text = data.name,
            color = {r = r, g = g, b = b},
            tooltip = data.name,
            tooltipDesc = data.description,
            func = function()
                DoF.Stats:SetRole(key)
            end
        })
    end
    
    ShowMenu(SpecMenu, anchor or "cursor", items)
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ СМЕНЫ РОЛИ (МАСТЕР)
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowSetSpecMenu(targetName)
    local items = {
        { text = DoF.Locale:Format("ui.role.of", targetName), isTitle = true },
    }
    
    table.insert(items, {
        text = DoF.L["ui.role.reset"],
        color = {r = 0.5, g = 0.5, b = 0.5},
        tooltip = DoF.L["ui.role.reset_title"],
        tooltipDesc = DoF.L["ui.role.reset_desc"],
        func = function() DoF.Sync:SetSpec(targetName, nil) end
    })
    
    for key, data in pairs(DoF.Config.Roles) do
        local r = tonumber(data.color:sub(1,2), 16)/255
        local g = tonumber(data.color:sub(3,4), 16)/255
        local b = tonumber(data.color:sub(5,6), 16)/255
        table.insert(items, {
            text = data.name,
            color = {r = r, g = g, b = b},
            tooltip = data.name,
            tooltipDesc = data.description,
            func = function() DoF.Sync:SetSpec(targetName, key) end
        })
    end
    
    ShowMenu(MasterSpecMenu, nil, items)
end

-- Меню выдачи уровня. Уровней всего 20, поэтому список нагляднее поля ввода:
-- мастер сразу видит, что даёт очередная ступень, и не может промахнуться.
function DoF.Dialogs:ShowSetLevelMenu(targetName)
    local items = {
        { text = DoF.Locale:Format("ui.level.of", targetName), isTitle = true },
    }

    local current = DoF.Sync and DoF.Sync:GetPlayerLevel(targetName)

    for level = DoF.Config.MIN_LEVEL, DoF.Config.MAX_LEVEL do
        local row = DoF.Config:GetLevelRow(level)
        local label = tostring(level)
        if level == current then
            -- Текущий уровень помечаем, иначе в списке из 20 строк не найти.
            label = label .. "  " .. DoF.L["ui.level.current_mark"]
        end

        table.insert(items, {
            text = label,
            color = (level == current) and {r = 1, g = 0.84, b = 0} or nil,
            tooltip = DoF.Locale:Format("ui.level.tooltip_title", level),
            tooltipDesc = DoF.Locale:Format("ui.level.tooltip_desc", row.points, row.hp, row.energy),
            func = function() DoF.Sync:SetPlayerLevel(targetName, level) end
        })
    end

    ShowMenu(MasterLevelMenu, nil, items)
end

-- Меню выбора своей роли
function DoF.Dialogs:ShowRoleMenu(button)
    if not DoF.Stats:CanChooseRole() then
        DoF.Utils:Error(DoF.Locale:Format("errors.level_required", DoF.Config.ROLE_REQUIRED_LEVEL))
        return
    end
    
    local items = {
        { text = DoF.L["ui.role.select"], isTitle = true },
    }
    
    for key, data in pairs(DoF.Config.Roles) do
        local r = tonumber(data.color:sub(1,2), 16)/255
        local g = tonumber(data.color:sub(3,4), 16)/255
        local b = tonumber(data.color:sub(5,6), 16)/255
        table.insert(items, {
            text = data.name,
            color = {r = r, g = g, b = b},
            tooltip = data.name,
            tooltipDesc = data.description,
            func = function()
                DoF.Stats:SetRole(key)
            end
        })
    end

    -- Липкое меню, открывается вверх (без collapsible)
    if SpecMenu:IsShown() and SpecMenu.anchorButton == button then
        SpecMenu:Hide()
        return
    end
    ShowMenu(SpecMenu, button, items, { position = "top", sticky = true })
end

-- Алиас для совместимости
function DoF.Dialogs:ShowSpecMenu(button)
    self:ShowRoleMenu(button)
end


-- NPC диалоги вынесены в UI/Dialogs_NPC.lua
-- Боевые диалоги вынесены в UI/Dialogs_Combat.lua
-- Мастер-эффекты вынесены в UI/Dialogs_Effects.lua
-- Настройки и помощь вынесены в UI/Dialogs_Misc.lua
